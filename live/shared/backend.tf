
terraform {
  backend "s3" {
    bucket       = "brightpath-tfstate-138257835519"
    key          = "shared/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true # native S3 locking (TF >= 1.10), no DynamoDB table
    encrypt      = true
  }
}