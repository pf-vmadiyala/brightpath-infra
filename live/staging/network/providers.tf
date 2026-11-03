provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "brightpath"
      Environment = "staging"
      Stack       = "network"
      ManagedBy   = "terraform"
      Repo        = "pf-vmadiyala/brightpath-infra"
    }
  }
}