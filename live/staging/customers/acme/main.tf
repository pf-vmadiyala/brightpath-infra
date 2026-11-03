# Small customer on the pooled platform.
module "customer" {
  source = "../../../../modules/customer"

  name        = "acme"
  environment = "staging"
  platform    = "shared-01"

  hostname               = "acme.staging.brightpath.test"
  listener_rule_priority = 100

  image_tag = "1.0.0"
}
