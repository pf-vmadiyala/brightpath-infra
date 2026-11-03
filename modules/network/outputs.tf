output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Ordered to match var.azs"
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Ordered to match var.azs"
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}