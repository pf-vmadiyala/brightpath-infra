data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: used by the ECS agent before the container starts, to pull
# the image, write logs and inject this customer's DB secret. Nothing else.
resource "aws_iam_role" "execution" {
  name               = "${local.full_name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "execution_base" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "execution_secret" {
  name   = "db-secret"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secret.json
}

# Task role: what the app's own code may call. Empty today. When the app needs
# AWS access (S3 uploads, SQS), grant it here, scoped to this customer.
resource "aws_iam_role" "task" {
  name               = "${local.full_name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

# Pooled only: the db-bootstrap task needs the shared instance's admin secret.
# It gets its own execution role so the app's role never can read that secret.
resource "aws_iam_role" "bootstrap" {
  count = local.pooled ? 1 : 0

  name               = "${local.full_name}-db-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "bootstrap_base" {
  count = local.pooled ? 1 : 0

  role       = aws_iam_role.bootstrap[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "bootstrap_secrets" {
  count = local.pooled ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.shared_db_secret_arn, local.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "bootstrap_secrets" {
  count = local.pooled ? 1 : 0

  name   = "db-secrets"
  role   = aws_iam_role.bootstrap[0].id
  policy = data.aws_iam_policy_document.bootstrap_secrets[0].json
}
