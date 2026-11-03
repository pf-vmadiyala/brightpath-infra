# One ALB per platform. Customers on this platform each add a target group and
# a host-header listener rule; anything unmatched gets the fixed 404 below.
resource "aws_security_group" "alb" {
  name        = "${local.full_name}-alb"
  description = "ALB for platform ${var.name}"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
  description       = "HTTP from clients"
}

# Targets are task ENIs inside the VPC. Each customer's task SG allows its own
# port from this SG, so the ALB only needs egress into the VPC.
resource "aws_vpc_security_group_egress_rule" "alb_to_vpc" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = local.vpc_cidr
  description       = "To targets in the VPC"
}

resource "aws_lb" "this" {
  name               = local.full_name
  load_balancer_type = "application"
  internal           = false
  subnets            = local.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown customer"
      status_code  = "404"
    }
  }
}
