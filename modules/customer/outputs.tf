output "service_name" {
  value = aws_ecs_service.app.name
}

output "cluster_name" {
  value = local.cluster_name
}

output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "test_command" {
  description = "Hit this customer through its platform ALB"
  value       = "curl -s -H 'Host: ${var.hostname}' http://${local.alb_dns_name}/version"
}

output "migrate_command" {
  description = "Run migrations as a one-off task before deploying a new app version"
  value = join(" ", [
    "aws ecs run-task",
    "--cluster ${local.cluster_name}",
    "--task-definition ${aws_ecs_task_definition.migrate.family}",
    "--capacity-provider-strategy capacityProvider=${local.capacity_provider}",
    "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", local.private_subnet_ids)}],securityGroups=[${aws_security_group.task.id}]}'",
  ])
}
