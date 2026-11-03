# Large customer on its own dedicated platform (separate listener, so priority 100 is fine).
module "customer" {
  source = "../../../../modules/customer"

  name        = "globex"
  environment = "staging"
  platform    = "globex"

  hostname               = "globex.staging.brightpath.test"
  listener_rule_priority = 100

  image_tag = "289fb4e"
}
