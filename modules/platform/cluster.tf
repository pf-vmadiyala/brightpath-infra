# ---------------------------------------------------------------------------
# Container instance role: lets the ECS agent register, pull from ECR, fetch
# secrets for tasks and ship logs. SSM core adds Session Manager (no SSH keys).
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${local.full_name}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "instance_ecs" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.full_name}-instance"
  role = aws_iam_role.instance.name
}

# Tasks run in awsvpc mode with their own ENIs and SGs, so the instance itself
# accepts no inbound traffic. Outbound is the ECS agent and Docker reaching
# ECR, Secrets Manager and CloudWatch through the internet gateway.
resource "aws_security_group" "instance" {
  name        = "${local.full_name}-instance"
  description = "ECS container instances: no inbound, agent egress only"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-instance"
  }
}

resource "aws_vpc_security_group_egress_rule" "instance_all" {
  security_group_id = aws_security_group.instance.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "ECS agent, image pulls, secrets, logs"
}

# Latest ECS-optimized Amazon Linux 2023 AMI. A new AMI only reaches running
# instances through an instance refresh, not by itself.
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_launch_template" "this" {
  name_prefix   = "${local.full_name}-"
  image_id      = data.aws_ssm_parameter.ecs_ami.insecure_value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  vpc_security_group_ids = [aws_security_group.instance.id]

  # IMDSv2 only, hop limit 1, and ECS_AWSVPC_BLOCK_IMDS: tasks can't borrow
  # the instance role's credentials. They get their own task role instead.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    cat >> /etc/ecs/ecs.config <<EOF
    ECS_CLUSTER=${local.full_name}
    ECS_AWSVPC_BLOCK_IMDS=true
    ECS_ENABLE_CONTAINER_METADATA=true
    EOF
  EOT
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.full_name}-ecs"
    }
  }
}

# Public subnets: instances get public IPs, so no NAT gateway is needed
# (see network-egress-design). Task ENIs still go in the private subnets.
resource "aws_autoscaling_group" "this" {
  name                = local.full_name
  vpc_zone_identifier = local.public_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size

  # Required by managed termination protection: ECS removes the protection
  # only from instances with no running tasks.
  protect_from_scale_in = true

  # Lets destroy finish even though instances are scale-in protected.
  force_delete = true

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  # ECS managed scaling owns desired capacity.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_cluster" "this" {
  name = local.full_name

  # Container Insights costs extra per metric; off for the lab.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = local.full_name

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = "ENABLED"
    managed_draining               = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.target_capacity
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }
}
