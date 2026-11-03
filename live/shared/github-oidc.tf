locals {
  oidc_host        = "token.actions.githubusercontent.com"
  repo             = "${var.github_owner}/${var.github_repo}"
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket}"
}

# Only one provider per URL is allowed per account, and one already exists
# (created by another project), so look it up instead of creating it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.oidc_host}"
}

# ---------------------------------------------------------------------------
# Plan role: assumed by pull_request runs. Read-only, plus state lock writes.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Exact match, no wildcards: only PRs in this one repo.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${local.repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "brightpath-gha-plan"
  description          = "GitHub Actions terraform plan on pull requests (${local.repo})"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan acquires a lock by writing, then deleting, a .tflock object,
# so read-only S3 access is not enough for the state bucket.
data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "ReadWriteStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "state_access" {
  name        = "brightpath-tfstate-access"
  description = "Read/write Terraform state and lock files"
  policy      = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_role_policy_attachment" "plan_state" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.state_access.arn
}

# ---------------------------------------------------------------------------
# Apply roles: one per GitHub environment. The job must declare
# `environment: <name>`, so prod applies go through required reviewers.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "apply_trust" {
  for_each = toset(var.environments)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${local.repo}:environment:${each.key}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  for_each = toset(var.environments)

  name                 = "brightpath-gha-apply-${each.key}"
  description          = "GitHub Actions terraform apply for ${each.key} (${local.repo})"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust[each.key].json
  max_session_duration = 3600
}

# Lab shortcut. In prod: scoped service permissions plus a permissions
# boundary, and a separate AWS account per environment.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  for_each = aws_iam_role.apply

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}