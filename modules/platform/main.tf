# Inputs from the network stack. Read from SSM so this stack never needs the
# network's state file. insecure_value is the non-sensitive copy of a String.
locals {
  full_name          = "brightpath-${var.environment}-${var.name}"
  network_prefix     = "/brightpath/${var.environment}/network"
  ssm_prefix         = "/brightpath/${var.environment}/platforms/${var.name}"
  vpc_id             = data.aws_ssm_parameter.vpc_id.insecure_value
  vpc_cidr           = data.aws_ssm_parameter.vpc_cidr.insecure_value
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.insecure_value)
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.insecure_value)
}

data "aws_ssm_parameter" "vpc_id" {
  name = "${local.network_prefix}/vpc_id"
}

data "aws_ssm_parameter" "vpc_cidr" {
  name = "${local.network_prefix}/vpc_cidr"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "${local.network_prefix}/public_subnet_ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "${local.network_prefix}/private_subnet_ids"
}
