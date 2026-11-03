locals {
  log_options = {
    awslogs-group  = aws_cloudwatch_log_group.this.name
    awslogs-region = local.region
  }

  # Same DB credentials for app and migrations; JSON keys from the RDS secret.
  db_user_from     = "${local.db_secret_arn}:username::"
  db_password_from = "${local.db_secret_arn}:password::"
}

# ---------------------------------------------------------------------------
# App: Tomcat on 8080
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.full_name}-app"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name         = "app"
      image        = local.app_image
      essential    = true
      portMappings = [{ containerPort = local.app_port, protocol = "tcp" }]

      environment = [
        { name = "CUSTOMER_NAME", value = var.name },
        { name = "DB_URL", value = local.jdbc_url },
        { name = "JAVA_OPTS", value = "-XX:MaxRAMPercentage=75" },
      ]

      secrets = [
        { name = "DB_USER", valueFrom = local.db_user_from },
        { name = "DB_PASSWORD", valueFrom = local.db_password_from },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "app" })
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# Migrations: Flyway, run as a one-off task BEFORE rolling out a new app
# version (see the migrate_command output). Never part of the service.
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "migrate" {
  family                   = "${local.full_name}-migrate"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "migrate"
      image     = local.migrate_image
      essential = true

      environment = [
        { name = "FLYWAY_URL", value = local.jdbc_url },
      ]

      secrets = [
        { name = "FLYWAY_USER", valueFrom = local.db_user_from },
        { name = "FLYWAY_PASSWORD", valueFrom = local.db_password_from },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "migrate" })
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# Pooled only: db-bootstrap creates this customer's database and MySQL user on
# the shared RDS (admin credentials), granted on that database only. Safe to
# re-run: it also resets the user's password to the one in Secrets Manager.
# Order for a new pooled customer: bootstrap -> migrate -> app is usable.
# ---------------------------------------------------------------------------
locals {
  # $VARS are shell variables (no braces), so Terraform leaves them alone.
  # Identifiers are [a-z0-9_] and the password is alphanumeric: no quoting traps.
  bootstrap_script = <<-EOT
    set -eu
    export MYSQL_PWD="$MASTER_PASSWORD"
    mysql --ssl-mode=REQUIRED -h "$DB_HOST" -u "$MASTER_USER" -e "
      CREATE DATABASE IF NOT EXISTS $DB_NAME;
      CREATE USER IF NOT EXISTS '$APP_USER'@'%' IDENTIFIED BY '$APP_PASSWORD';
      ALTER USER '$APP_USER'@'%' IDENTIFIED BY '$APP_PASSWORD';
      GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$APP_USER'@'%';"
    echo "database $DB_NAME and user $APP_USER are ready"
  EOT
}

resource "aws_ecs_task_definition" "db_bootstrap" {
  count = local.pooled ? 1 : 0

  family                   = "${local.full_name}-db-bootstrap"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 256
  execution_role_arn       = aws_iam_role.bootstrap[0].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name = "db-bootstrap"
      # ECR Public mirror of the official image: no Docker Hub rate limits.
      image      = "public.ecr.aws/docker/library/mysql:8.4"
      essential  = true
      entryPoint = ["sh", "-c"]
      command    = [local.bootstrap_script]

      environment = [
        { name = "DB_HOST", value = local.db_host },
        { name = "DB_NAME", value = local.db_name },
        { name = "APP_USER", value = local.db_user },
      ]

      secrets = [
        { name = "MASTER_USER", valueFrom = "${local.shared_db_secret_arn}:username::" },
        { name = "MASTER_PASSWORD", valueFrom = "${local.shared_db_secret_arn}:password::" },
        { name = "APP_PASSWORD", valueFrom = local.db_password_from },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.log_options, { awslogs-stream-prefix = "db-bootstrap" })
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = var.name
  cluster         = local.cluster_arn
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = local.capacity_provider
    weight            = 1
  }

  # Task ENIs live in the private subnets (no internet route). The ECS agent
  # on the host pulls images and fetches secrets, so the task doesn't need it.
  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [aws_security_group.task.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = local.app_port
  }

  # Tomcat needs time to start before ALB health checks count.
  health_check_grace_period_seconds = 90

  # Rolling deploy: start new tasks before stopping old ones. Roll back
  # automatically if the new version never gets healthy.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  propagate_tags = "SERVICE"

  # The rule must exist before ECS registers targets in the group.
  depends_on = [aws_lb_listener_rule.this]
}
