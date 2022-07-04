locals {
  e2e_tests_stage = var.enable_e2e_tests ? [true] : []
}

module "build" {
  source  = "cloudposse/codebuild/aws"
  version = "0.39.0"

  name      = "build"
  namespace = var.project_name
  stage     = "dev_and_qa"
  tags      = var.tags

  build_image         = var.build_image
  privileged_mode     = var.builds_privileged_mode
  buildspec           = var.build_buildspec
  build_compute_type  = var.build_compute_type
  report_build_status = false
  local_cache_modes   = var.build_local_cache_modes
  cache_type          = var.build_cache_type

  extra_permissions = ["codestar-connections:UseConnection"]
}

module "deploy_dev" {
  source  = "cloudposse/codebuild/aws"
  version = "0.39.0"

  name                = "deploy_dev"
  namespace           = var.project_name
  stage               = "dev"
  build_compute_type  = var.deploys_compute_type
  report_build_status = false
  tags                = var.tags

  build_image       = var.deploy_image
  privileged_mode   = var.deploys_privileged_mode
  buildspec         = var.deploy_dev_buildspec
  local_cache_modes = var.deploy_local_cache_modes
  cache_type        = var.deploy_cache_type
}

module "deploy_qa" {
  source              = "git::https://github.com/cloudposse/terraform-aws-codebuild.git?ref=tags/0.39.0"
  name                = "deploy_qa"
  namespace           = var.project_name
  stage               = "qa"
  build_compute_type  = var.deploys_compute_type
  report_build_status = false
  tags                = var.tags

  build_image       = var.deploy_image
  privileged_mode   = var.deploys_privileged_mode
  buildspec         = var.deploy_qa_buildspec
  local_cache_modes = var.deploy_local_cache_modes
  cache_type        = var.deploy_cache_type
}

module "e2e_tests" {
  source    = "git::https://github.com/cloudposse/terraform-aws-codebuild.git?ref=tags/0.39.0"
  name      = "test"
  namespace = var.project_name
  stage     = "qa"
  tags      = var.tags

  build_image = var.build_image
  buildspec   = var.e2e_tests_buildspec
}

module "deploy_prod" {
  source = "git::https://github.com/cloudposse/terraform-aws-codebuild.git?ref=tags/0.39.0"

  name                = "deploy"
  namespace           = var.project_name
  stage               = "prod"
  build_compute_type  = var.deploys_compute_type
  report_build_status = false
  tags                = var.tags

  build_image     = var.deploy_image
  privileged_mode = var.deploys_privileged_mode
  buildspec       = var.deploy_prod_buildspec
  cache_type      = var.deploy_cache_type
}

resource "aws_codepipeline" "pipeline_dev" {
  name     = "${var.project_name}-dev-cicd-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_s3.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.codestar_connection_arn
        FullRepositoryId     = "${var.github_org}/${var.github_repo_name}"
        BranchName           = var.github_branch_dev
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
        DetectChanges        = true
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_dev"]
      version          = "1"

      configuration = {
        ProjectName   = module.build.project_name
        PrimarySource = "source_output"
      }
    }
  }

  stage {
    name = "DeployDev"

    action {
      category        = "Build"
      name            = "DeployDev"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output_dev"]

      configuration = {
        ProjectName   = module.deploy_dev.project_name
        PrimarySource = "build_output_dev"
      }
    }
  }

  tags = var.tags
}

resource "aws_codepipeline" "pipeline_release" {
  name     = "${var.project_name}-release-cicd-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_s3.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.codestar_connection_arn
        FullRepositoryId     = "${var.github_org}/${var.github_repo_name}"
        BranchName           = var.github_branch_release
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
        DetectChanges        = true
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_release"]
      version          = "1"

      configuration = {
        ProjectName   = module.build.project_name
        PrimarySource = "source_output"
      }
    }
  }

  stage {
    name = "DeployQa"

    action {
      category        = "Build"
      name            = "DeployQa"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output_release"]

      configuration = {
        ProjectName   = module.deploy_qa.project_name
        PrimarySource = "build_output_release"
      }
    }
  }

  dynamic "stage" {
    for_each = local.e2e_tests_stage
    content {

      name = "E2ETests"

      action {
        category        = "Build"
        name            = "E2ETests"
        owner           = "AWS"
        provider        = "CodeBuild"
        version         = "1"
        input_artifacts = ["build_output_release"]

        configuration = {
          ProjectName   = module.e2e_tests.project_name
          PrimarySource = "build_output_release"
        }
      }
    }
  }

  stage {
    name = "Approve"

    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "DeployProd"

    action {
      category        = "Build"
      name            = "DeployProd"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output_release"]

      configuration = {
        ProjectName   = module.deploy_prod.project_name
        PrimarySource = "build_output_release"
      }
    }
  }

  tags = var.tags
}
