# Publish outputs to SSM so platform and customer stacks can look them up with
# a data source, without reading this stack's state file. That keeps stacks
# decoupled: consumers only depend on the parameter names.
locals {
  ssm_values = {
    vpc_id             = aws_vpc.this.id
    vpc_cidr           = aws_vpc.this.cidr_block
    azs                = join(",", var.azs)
    public_subnet_ids  = join(",", [for az in var.azs : aws_subnet.public[az].id])
    private_subnet_ids = join(",", [for az in var.azs : aws_subnet.private[az].id])
  }
}

resource "aws_ssm_parameter" "this" {
  for_each = local.ssm_values

  name  = "${var.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}