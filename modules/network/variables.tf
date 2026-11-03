variable "name" {
  description = "Name prefix for all network resources, e.g. brightpath-staging"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR. Use non-overlapping ranges per environment so they can be peered later."
  type        = string
}

variable "azs" {
  description = "Availability zones. The ALB, ASG and task subnets all derive from this one list."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "An ALB needs subnets in at least two AZs."
  }
}

variable "ssm_prefix" {
  description = "SSM path where outputs are published for other stacks, e.g. /brightpath/staging/network"
  type        = string
}