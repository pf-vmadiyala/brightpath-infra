# One database per customer (silo data, pooled compute). RDS generates the
# master password and keeps it in Secrets Manager, so it never appears in
# Terraform state or code.
resource "aws_db_subnet_group" "this" {
  name       = local.full_name
  subnet_ids = local.private_subnet_ids
}

resource "aws_db_instance" "this" {
  identifier     = local.full_name
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "brightpath"
  username                    = "brightpath"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true

  deletion_protection       = var.db_protect
  skip_final_snapshot       = !var.db_protect
  final_snapshot_identifier = var.db_protect ? "${local.full_name}-final" : null
}

locals {
  db_secret_arn = aws_db_instance.this.master_user_secret[0].secret_arn
  # sslMode=REQUIRED encrypts the connection. RDS supports TLS out of the box.
  jdbc_url = "jdbc:mysql://${aws_db_instance.this.address}:3306/brightpath?sslMode=REQUIRED"
}
