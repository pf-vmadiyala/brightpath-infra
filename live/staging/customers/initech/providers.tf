provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "brightpath"
      Environment = "staging"
      Stack       = "customer-initech"
      Customer    = "initech"
      ManagedBy   = "terraform"
      Repo        = "pf-vmadiyala/brightpath-infra"
    }
  }
}
