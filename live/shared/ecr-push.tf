# ---------------------------------------------------------------------------
# ECR push role: assumed only by pushes to main in the app repo. PR builds run
# without credentials, so untrusted code never gets registry write access.
# ---------------------------------------------------------------------------
variable "app_repo" {
  description = "App repo whose main branch may push images"
  type        = string
  default     = "brightpath-app"
}

variable "app_repo_id" {
  description = "Numeric GitHub ID of the app repo (part of the immutable OIDC subject)"
  type        = string
  default     = "1444553258"
}

locals {
  app_repo_sub = "repo:${var.github_owner}@${var.github_owner_id}/${var.app_repo}@${var.app_repo_id}"
}

data "aws_iam_policy_document" "ecr_push_trust" {
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
      values   = ["${local.app_repo_sub}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "brightpath-gha-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.ecr_push_trust.json
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "Login"
    actions   = ["ecr:GetAuthorizationToken"] # can't be scoped to a repository
    resources = ["*"]
  }

  statement {
    sid = "PushBrightpathImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
    ]
    resources = [for r in aws_ecr_repository.this : r.arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "push-brightpath-images"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
