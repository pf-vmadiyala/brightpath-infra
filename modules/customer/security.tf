# Per-customer security groups are why tasks use awsvpc mode: acme's tasks can
# reach acme's database and nothing else, even on the shared cluster.
#
#   ALB SG --8080--> task SG --3306--> db SG
resource "aws_security_group" "task" {
  name        = "${local.full_name}-task"
  description = "App tasks for ${var.name}"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-task"
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = local.alb_sg_id
  ip_protocol                  = "tcp"
  from_port                    = local.app_port
  to_port                      = local.app_port
  description                  = "From the platform ALB"
}

resource "aws_vpc_security_group_egress_rule" "task_to_db" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "To this customer's database only"
}

# No egress rules: responses to allowed inbound connections are stateful.
resource "aws_security_group" "db" {
  name        = "${local.full_name}-db"
  description = "RDS for ${var.name}"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_task" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "From ${var.name} app and migrate tasks"
}
