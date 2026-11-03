# Per-customer security groups are why tasks use awsvpc mode: acme's tasks can
# reach acme's database and nothing else, even on the shared cluster.
#
#   ALB SG --8080--> task SG --3306--> db SG
#
# dedicated: db SG belongs to this customer's own RDS (created here).
# pooled:    db SG belongs to the platform's shared RDS; this stack only adds
#            its own ingress rule. Isolation between pooled customers is then
#            enforced by MySQL users/grants, not by the network.
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

# EC2 rule descriptions reject some characters, including apostrophes.
resource "aws_vpc_security_group_egress_rule" "task_to_db" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = local.db_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "To the ${var.database} database for ${var.name}"
}

# Dedicated only. No egress rules: responses are stateful.
resource "aws_security_group" "db" {
  count = local.pooled ? 0 : 1

  name        = "${local.full_name}-db"
  description = "RDS for ${var.name}"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_task" {
  security_group_id            = local.db_sg_id
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "From ${var.name} app, migrate and bootstrap tasks"
}

# Resources that gained count: keep existing dedicated customers in place.
moved {
  from = aws_security_group.db
  to   = aws_security_group.db[0]
}
