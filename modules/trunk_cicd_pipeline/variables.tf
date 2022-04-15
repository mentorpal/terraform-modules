variable "project_name" {
  type        = string
  description = "The name used for the Github repo, IAM policy, CodeBuild and CodePipeline resources"
}

variable "codestar_connection_arn" {
  type        = string
  description = "Must be manually created by the github org owner"
}

variable "github_repo_name" {
  type        = string
  default     = null
  description = "If a different github repo name should be used instead of the default project name"
}

variable "github_org" {
  default = "mentorpal"
}

variable "github_branch" {
  description = "Specify github branch of the repository that pipeline should track"
  default     = "main"
}

variable "docker_builds" {
  description = "Whether pipeline should be able to build and deploy docker images"
  default     = false
}

variable "build_image" {
  description = "Specify an image ID to be used for build CBs only from `aws codebuild list-curated-environment-images`"
  default     = "aws/codebuild/standard:5.0"
}

variable "deploy_image" {
  description = "Specify an image ID used for deploy CBs from `aws codebuild list-curated-environment-images`"
  default     = "aws/codebuild/standard:5.0"
}

variable "build_buildspec" {
  description = "Buildspec used by the standalone CodeBuild project triggered on every Pull Request"
  type        = string
  default     = "cicd/buildspec.yml"
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
  description = "Please provide a `computeType` value as specified in the official (AWS docs)[https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html}"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_compute_type" {
  description = "Please provide a `computeType` value used for the PR CB project as specified in the official (AWS docs)[https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html}"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_cache_type" {
  description = "The type of storage that will be used for the build project cache. To see more info check https://github.com/cloudposse/terraform-aws-codebuild/tree/0.19.0"
  default     = "LOCAL"
}

variable "build_local_cache_modes" {
  description = "Specifies settings that build CodeBuild uses to store and reuse build dependencies. To see more info check https://github.com/cloudposse/terraform-aws-codebuild/tree/0.19.0"
  default     = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
}

variable "deploy_cache_type" {
  description = "The type of storage that will be used for the deploy project cache. To see more info check https://github.com/cloudposse/terraform-aws-codebuild/tree/0.19.0"
  default     = "LOCAL"
}

variable "deploy_local_cache_modes" {
  description = "Specifies settings that deploy CodeBuild uses to store and reuse build dependencies. To see more info check https://github.com/cloudposse/terraform-aws-codebuild/tree/0.19.0"
  default     = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
}

variable "allow_git_folder_access_in_pipeline_build" {
  type        = bool
  default     = false
  description = "Allow access to .git folder in codepipeline Build step"
}

variable "export_pipeline_info" {
  type        = bool
  default     = false
  description = "If the name and ARN of the CodePipeline should be exported to SSM"
}
