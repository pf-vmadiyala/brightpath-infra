variable "region" {
  description = "AWS region for shared resources"
  type        = string
  default     = "us-east-2"
}

variable "github_owner" {
  description = "GitHub org or user that owns the infra repo"
  type        = string
  default     = "pf-vmadiyala"
}

variable "github_repo" {
  description = "Infra repo allowed to assume the CI roles"
  type        = string
  default     = "brightpath-infra"
}

variable "state_bucket" {
  description = "S3 bucket holding Terraform state (created once via CLI, see README)"
  type        = string
  default     = "brightpath-tfstate-138257835519"
}

variable "environments" {
  description = "GitHub environments that get their own apply role"
  type        = list(string)
  default     = ["staging", "prod"]
}