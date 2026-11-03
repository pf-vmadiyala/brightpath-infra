variable "name" {
  description = "Platform name, e.g. shared-01 (pooled) or globex (dedicated). Customers select it by this name."
  type        = string
}

variable "environment" {
  description = "staging or prod. Used in resource names and SSM paths."
  type        = string
}

variable "instance_type" {
  description = "Container instance type. t3.small allows 2 awsvpc tasks per instance (3 ENIs, one is the primary)."
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "ASG minimum. 0 lets managed scaling remove every instance when no tasks run."
  type        = number
  default     = 0
}

variable "max_size" {
  description = "ASG maximum. Caps cost: managed scaling never goes above this."
  type        = number
  default     = 3
}

variable "target_capacity" {
  description = "Capacity provider target (CapacityProviderReservation %). 100 = no spare instance."
  type        = number
  default     = 100
}

variable "alb_ingress_cidrs" {
  description = "Who may reach the ALB on port 80. Narrow this to your IP for a private lab."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
