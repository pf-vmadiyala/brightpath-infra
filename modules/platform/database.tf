# ---------------------------------------------------------------------------
# Optional shared RDS for pooled customers ("bridge" data model): one instance,
# one database + one MySQL user per customer. Each customer stack adds its own
# ingress rule to this SG and creates its own database/user with a one-off
# bootstrap task, so customers still can't read each other's data.
# Dedicated customers don't use this; they get their own instance.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "shared" {
  count = var.shared_database ? 1 : 0

  name       = local.full_name
  subnet_ids = local.private_subnet_ids
}

# Ingress rules come from customer stacks (aws_vpc_security_group_ingress_rule
# there), one per pooled customer. No egress: replies are stateful.
resource "aws_security_group" "db" {
  count = var.shared_database ? 1 : 0

  name        = "${local.full_name}-db"
  description = "Shared RDS for pooled customers on ${var.name}"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-db"
  }
}

resource "aws_db_instance" "shared" {
  count = var.shared_database ? 1 : 0

  identifier     = local.full_name
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # No db_name: each customer's bootstrap task creates its own database.
  username                    = "admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.shared[0].name
  vpc_security_group_ids = [aws_security_group.db[0].id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true

  deletion_protection       = var.db_protect
  skip_final_snapshot       = !var.db_protect
  final_snapshot_identifier = var.db_protect ? "${local.full_name}-final" : null
}
