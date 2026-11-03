locals {
  # One-off tasks (migrate, db-bootstrap) run with the app's network settings:
  # private subnets and the task SG, which is what the database allows in.
  run_task_prefix = join(" ", [
    "aws ecs run-task",
    "--cluster ${local.cluster_name}",
    "--capacity-provider-strategy capacityProvider=${local.capacity_provider}",
    "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", local.private_subnet_ids)}],securityGroups=[${aws_security_group.task.id}]}'",
  ])
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "cluster_name" {
  value = local.cluster_name
}

output "database" {
  description = "dedicated or pooled, and where the data lives"
  value       = "${var.database}: ${local.db_name} on ${local.db_host}"
}

output "test_command" {
  description = "Hit this customer through its platform ALB"
  value       = "curl -s -H 'Host: ${var.hostname}' http://${local.alb_dns_name}/version"
}

output "bootstrap_command" {
  description = "Pooled only: run once (before the first migration) to create the database and user"
  value       = local.pooled ? "${local.run_task_prefix} --task-definition ${aws_ecs_task_definition.db_bootstrap[0].family}" : null
}

output "migrate_command" {
  description = "Run migrations as a one-off task before deploying a new app version"
  value       = "${local.run_task_prefix} --task-definition ${aws_ecs_task_definition.migrate.family}"
}
