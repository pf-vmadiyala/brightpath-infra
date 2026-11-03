# Small customer on the pooled platform.
module "customer" {
  source = "../../../../modules/customer"

  name        = "acme"
  environment = "staging"
  platform    = "shared-01"
  database    = "pooled" # own database + user on the shared-01 RDS

  hostname               = "acme.staging.brightpath.test"
  listener_rule_priority = 100

  image_tag = "289fb4e"
}
