# Pooled platform: small customers share this cluster and ALB.
# Each one keeps its own database (on a shared RDS), SGs and IAM roles.
module "platform" {
  source = "../../../../modules/platform"

  name        = "shared-01"
  environment = "staging"

  instance_type = "t3.small"
  max_size      = 3 # 2 awsvpc tasks per t3.small; room for a rolling deploy

  # One RDS for the pooled customers (acme, initech): a database + user each.
  shared_database = true
}
