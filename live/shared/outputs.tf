output "plan_role_arn" {
  description = "Set as repo variable AWS_PLAN_ROLE_ARN"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "Set each as AWS_APPLY_ROLE_ARN in the matching GitHub environment"
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.github.arn
}

output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
