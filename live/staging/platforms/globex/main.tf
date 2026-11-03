# Dedicated platform for a large customer: its own cluster, ASG and ALB, so
# noisy neighbours, scaling and maintenance windows never cross customers.
module "platform" {
  source = "../../../../modules/platform"

  name        = "globex"
  environment = "staging"

  instance_type = "t3.small"
  max_size      = 2
}
