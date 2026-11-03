# Small customer on the pooled platform. Priority must differ from acme (same listener).
module "customer" {
  source = "../../../../modules/customer"

  name        = "initech"
  environment = "staging"
  platform    = "shared-01"

  hostname               = "initech.staging.brightpath.test"
  listener_rule_priority = 110

  image_tag = "1.0.0"
}
