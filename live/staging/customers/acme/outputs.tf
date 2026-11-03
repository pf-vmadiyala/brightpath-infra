output "database" {
  value = module.customer.database
}

output "test_command" {
  value = module.customer.test_command
}

output "bootstrap_command" {
  value = module.customer.bootstrap_command
}

output "migrate_command" {
  value = module.customer.migrate_command
}
