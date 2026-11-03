provider "aws" {
  region = var.region

  # Applied to every resource: cost reports, ownership, finding orphans.
  default_tags {
    tags = {
      Project   = "brightpath"
      ManagedBy = "terraform"
      Stack     = "shared"
      Repo      = "${var.github_owner}/${var.github_repo}"
    }
  }
}