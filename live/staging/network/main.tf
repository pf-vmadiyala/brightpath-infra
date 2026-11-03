module "network" {
  source = "../../../modules/network"

  name       = "brightpath-staging"
  cidr_block = "10.20.0.0/16" # prod will use 10.30.0.0/16: no overlap, peerable later
  azs        = ["us-east-2a", "us-east-2b"]
  ssm_prefix = "/brightpath/staging/network"
}