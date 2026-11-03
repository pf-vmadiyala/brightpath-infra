data "aws_region" "current" {}

# One /24 per AZ per tier. Public: 10.x.0-9.0/24, private: 10.x.10-19.0/24.
# Keyed by AZ so adding an AZ doesn't renumber existing subnets. Only append
# to var.azs: reordering it changes the CIDRs and forces subnet replacement.
locals {
  public_subnets  = { for i, az in var.azs : az => cidrsubnet(var.cidr_block, 8, i) }
  private_subnets = { for i, az in var.azs : az => cidrsubnet(var.cidr_block, 8, i + 10) }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true # RDS endpoints and ECS service discovery resolve via VPC DNS

  tags = {
    Name = var.name
  }
}

# Nothing should use the default SG, so strip all its rules (CIS benchmark).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-do-not-use"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

# ---------------------------------------------------------------------------
# Public tier: ALB and ECS container instances. Instances get public IPs so the
# ECS agent can reach ECR, Secrets Manager and CloudWatch without a NAT gateway.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Private tier: task ENIs (awsvpc) and RDS. No route to the internet at all.
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# S3 gateway endpoints are free and keep S3 traffic on the AWS network.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = {
    Name = "${var.name}-s3"
  }
}