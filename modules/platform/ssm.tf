# Contract for customer stacks: a customer sets platform = "<name>" and reads
# everything it needs from this path.
locals {
  ssm_values = merge(
    {
      cluster_name      = aws_ecs_cluster.this.name
      cluster_arn       = aws_ecs_cluster.this.arn
      capacity_provider = aws_ecs_capacity_provider.this.name
      listener_arn      = aws_lb_listener.http.arn
      alb_dns_name      = aws_lb.this.dns_name
      alb_sg_id         = aws_security_group.alb.id
    },
    # Only for platforms with a shared database (read by pooled customers).
    var.shared_database ? {
      db_address           = aws_db_instance.shared[0].address
      db_master_secret_arn = aws_db_instance.shared[0].master_user_secret[0].secret_arn
      db_sg_id             = aws_security_group.db[0].id
    } : {},
  )
}

resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_values

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}
