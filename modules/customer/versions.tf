# Modules declare a minimum provider version; root stacks pin the exact range.
terraform {
  # 1.11+: write-only attributes (secret_string_wo) for the pooled DB password.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7" # ephemeral random_password
    }
  }
}
