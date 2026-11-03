# One app image and one migrations image for every customer and environment:
# build once, promote the same tag. Customers differ only in config.
locals {
  ecr_repos = {
    app     = "brightpath/app"
    migrate = "brightpath/migrate"
  }
}

resource "aws_ecr_repository" "this" {
  for_each = local.ecr_repos

  name = each.value

  # A tag can never be overwritten, so a tag always means the same image.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 20 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

# Customer stacks read the repo URLs from here.
resource "aws_ssm_parameter" "ecr" {
  for_each = aws_ecr_repository.this

  name  = "/brightpath/shared/ecr/${each.key}_repository_url"
  type  = "String"
  value = each.value.repository_url
}
