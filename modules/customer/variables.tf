variable "name" {
  description = "Customer name, e.g. acme. Lowercase letters, digits and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name))
    error_message = "Use 2-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "staging or prod"
  type        = string
}

variable "platform" {
  description = "Which platform (ECS cluster + ALB) hosts this customer: shared-01 for pooled, or a dedicated one. Changing it moves the service; the database stays."
  type        = string
}

variable "hostname" {
  description = "Host header the ALB routes to this customer, e.g. acme.staging.brightpath.test"
  type        = string
}

variable "listener_rule_priority" {
  description = "Unique per listener. Customers on the same platform must not share a value."
  type        = number
}

variable "image_tag" {
  description = "Tag of both the app and migrate images in ECR (same build)"
  type        = string
}

variable "desired_count" {
  description = "Running app tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "App task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "App task memory in MiB. The JVM gets 75% of it."
  type        = number
  default     = 512
}

variable "db_instance_class" {
  description = "RDS instance class. db.t4g.micro and db.t3.micro are the free-tier classes."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB"
  type        = number
  default     = 20
}

variable "db_protect" {
  description = "Prod: true (deletion protection on, final snapshot taken). Lab/staging: false so destroy is quick."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  type    = number
  default = 7
}
