output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "capacity_provider" {
  value = aws_ecs_capacity_provider.this.name
}

output "alb_dns_name" {
  description = "Test a customer with: curl -H 'Host: <customer hostname>' http://<this>/version"
  value       = aws_lb.this.dns_name
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}
