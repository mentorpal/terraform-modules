variable "project_name" {
  type = string
}

variable "codestar_connection_arn" {
  type        = string
  description = "Must be manually created by the github org owner"
}

variable "github_repo_name" {
  type = string
}

variable "github_org" {
  default = "mentorpal"
}

variable "github_branch" {
  default     = "main"
  description = "Which github branch will get built and deployed"
}

variable "docker_builds" {
  description = "Allow pipeline to build and deploy docker images"
  default     = false
}

variable "build_image" {
  description = "`aws codebuild list-curated-environment-images`"
  default     = "aws/codebuild/standard:5.0"
}

variable "deploy_image" {
  description = "`aws codebuild list-curated-environment-images`"
  default     = "aws/codebuild/standard:5.0"
}

variable "build_buildspec" {
  default = "cicd/buildspec.yml"
}

variable "deploy_staging_buildspec" {
  default = "cicd/deployspec-qa.yml"
}

variable "deploy_prod_buildspec" {
  default = "cicd/deployspec-prod.yml"
}

variable "builds_privileged_mode" {
  default = false
}

variable "deploys_privileged_mode" {
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "deploys_compute_type" {
  description = "https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_compute_type" {
  description = "https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_cache_type" {
  description = "https://github.com/cloudposse/terraform-aws-codebuild/tree/0.38.0"
  default     = "LOCAL"
}

variable "build_local_cache_modes" {
  description = "CodeBuild settings for build dependencies: https://github.com/cloudposse/terraform-aws-codebuild/tree/0.38.0"
  default     = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
}

variable "deploy_cache_type" {
  description = "Deploy cache: https://github.com/cloudposse/terraform-aws-codebuild/tree/0.38.0"
  default     = "LOCAL"
}

variable "deploy_local_cache_modes" {
  description = "CodeBuild settings for dependencies: https://github.com/cloudposse/terraform-aws-codebuild/tree/0.38.0"
  default     = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
}

variable "export_pipeline_info" {
  type        = bool
  default     = false
  description = "Export CodePipeline name and ARN to SSM"
}
