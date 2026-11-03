# Two data models, picked per customer with var.database:
#
#   dedicated  own RDS instance. RDS generates the master password and keeps
#              it in Secrets Manager. Strongest isolation; for large customers.
#   pooled     a database + MySQL user on the platform's shared RDS. Terraform
#              writes the user's password straight into Secrets Manager as a
#              write-only value (never stored in state); the db-bootstrap task
#              then creates the database and user (see bootstrap_command).
#
# Both expose the same secret shape ({"username","password"}), so the app and
# migrate task definitions don't care which model a customer uses.

# ---------------------------------------------------------------------------
# dedicated
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  count = local.pooled ? 0 : 1

  name       = local.full_name
  subnet_ids = local.private_subnet_ids
}

resource "aws_db_instance" "this" {
  count = local.pooled ? 0 : 1

  identifier     = local.full_name
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = local.db_name
  username                    = "brightpath"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
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

moved {
  from = aws_db_subnet_group.this
  to   = aws_db_subnet_group.this[0]
}

moved {
  from = aws_db_instance.this
  to   = aws_db_instance.this[0]
}

# ---------------------------------------------------------------------------
# pooled
# ---------------------------------------------------------------------------
# Ephemeral: generated during apply and never written to plan or state.
ephemeral "random_password" "db" {
  count = local.pooled ? 1 : 0

  length  = 32
  special = false # safe to pass through the shell and SQL in the bootstrap task
}

resource "aws_secretsmanager_secret" "db" {
  count = local.pooled ? 1 : 0

  name                    = "${local.full_name}-db"
  description             = "MySQL user for ${var.name} on the shared ${var.platform} database"
  recovery_window_in_days = var.db_protect ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "db" {
  count = local.pooled ? 1 : 0

  secret_id = aws_secretsmanager_secret.db[0].id
  secret_string_wo = jsonencode({
    username = local.db_user
    password = ephemeral.random_password.db[0].result
  })
  # Bump to rotate: Terraform writes a new password, then re-run bootstrap.
  secret_string_wo_version = 1
}

# ---------------------------------------------------------------------------
# What the rest of the module uses, whichever model is active
# ---------------------------------------------------------------------------
locals {
  # MySQL identifiers: hyphens aren't allowed unquoted, so acme-corp -> acme_corp.
  db_user = replace(var.name, "-", "_")
  db_name = local.pooled ? "brightpath_${local.db_user}" : "brightpath"

  db_host       = local.pooled ? local.shared_db_address : one(aws_db_instance.this[*].address)
  db_sg_id      = local.pooled ? local.shared_db_sg_id : one(aws_security_group.db[*].id)
  db_secret_arn = local.pooled ? one(aws_secretsmanager_secret.db[*].arn) : one(aws_db_instance.this[*].master_user_secret[0].secret_arn)

  # sslMode=REQUIRED encrypts the connection. RDS supports TLS out of the box.
  jdbc_url = "jdbc:mysql://${local.db_host}:3306/${local.db_name}?sslMode=REQUIRED"
}
