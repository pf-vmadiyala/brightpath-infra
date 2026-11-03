provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "brightpath"
      Environment = "staging"
      Stack       = "platform-globex"
      ManagedBy   = "terraform"
      Repo        = "pf-vmadiyala/brightpath-infra"
    }
  }
}
