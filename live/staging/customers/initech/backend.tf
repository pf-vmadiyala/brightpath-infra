terraform {
  backend "s3" {
    bucket       = "brightpath-tfstate-138257835519"
    key          = "staging/customers/initech/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
