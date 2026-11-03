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
