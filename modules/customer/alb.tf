# ip targets because tasks use awsvpc: the ALB sends traffic straight to each
# task ENI on 8080, not to an instance port.
resource "aws_lb_target_group" "this" {
  name                 = substr("bp-${var.environment}-${var.name}", 0, 32)
  vpc_id               = local.vpc_id
  port                 = local.app_port
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 30

  # /health is liveness with no DB call, so a database blip doesn't make the
  # ALB pull every task at once.
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = local.listener_arn
  priority     = var.listener_rule_priority

  condition {
    host_header {
      values = [var.hostname]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
