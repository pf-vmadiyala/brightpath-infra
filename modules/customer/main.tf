# Everything this customer depends on is looked up from SSM by name:
# the network, the platform it was assigned to, and the shared ECR repos.
locals {
  full_name       = "brightpath-${var.environment}-${var.name}"
  network_prefix  = "/brightpath/${var.environment}/network"
  platform_prefix = "/brightpath/${var.environment}/platforms/${var.platform}"

  vpc_id             = data.aws_ssm_parameter.network["vpc_id"].insecure_value
  private_subnet_ids = split(",", data.aws_ssm_parameter.network["private_subnet_ids"].insecure_value)

  cluster_arn       = data.aws_ssm_parameter.platform["cluster_arn"].insecure_value
  cluster_name      = data.aws_ssm_parameter.platform["cluster_name"].insecure_value
  capacity_provider = data.aws_ssm_parameter.platform["capacity_provider"].insecure_value
  listener_arn      = data.aws_ssm_parameter.platform["listener_arn"].insecure_value
  alb_sg_id         = data.aws_ssm_parameter.platform["alb_sg_id"].insecure_value
  alb_dns_name      = data.aws_ssm_parameter.platform["alb_dns_name"].insecure_value

  app_image     = "${data.aws_ssm_parameter.ecr["app_repository_url"].insecure_value}:${var.image_tag}"
  migrate_image = "${data.aws_ssm_parameter.ecr["migrate_repository_url"].insecure_value}:${var.image_tag}"

  app_port = 8080
  region   = data.aws_region.current.region
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "network" {
  for_each = toset(["vpc_id", "private_subnet_ids"])
  name     = "${local.network_prefix}/${each.key}"
}

data "aws_ssm_parameter" "platform" {
  for_each = toset(["cluster_arn", "cluster_name", "capacity_provider", "listener_arn", "alb_sg_id", "alb_dns_name"])
  name     = "${local.platform_prefix}/${each.key}"
}

data "aws_ssm_parameter" "ecr" {
  for_each = toset(["app_repository_url", "migrate_repository_url"])
  name     = "/brightpath/shared/ecr/${each.key}"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/brightpath/${var.environment}/${var.name}"
  retention_in_days = var.log_retention_days
}
