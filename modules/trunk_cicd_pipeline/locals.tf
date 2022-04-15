locals {
  codestar_access_permission = ["codestar-connections:UseConnection"]

  github_repo_name = var.github_repo_name == null ? var.project_name : var.github_repo_name
}
