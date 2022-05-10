module "build" {
  source    = "git::https://github.com/cloudposse/terraform-aws-codebuild.git?ref=tags/0.38.0"
  name      = "build"
  namespace = var.project_name
  stage     = "qa"
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

module "deploy_staging" {
  source              = "git::https://github.com/cloudposse/terraform-aws-codebuild.git?ref=tags/0.38.0"
  name                = "deploy"
  namespace           = var.project_name
  stage               = "qa"
  build_compute_type  = var.deploys_compute_type
  report_build_status = false
  tags                = var.tags

  build_image       = var.deploy_image
  privileged_mode   = var.deploys_privileged_mode
  buildspec         = var.deploy_staging_buildspec
  local_cache_modes = var.deploy_local_cache_modes
  cache_type        = var.deploy_cache_type
}

module "deploy_prod" {
  source = "git::https://github.com/cloudposse/terraform-aws-codebuild.git?ref=tags/0.38.0"

  name                = "deploy"
  namespace           = var.project_name
  stage               = "prod"
  build_compute_type  = var.deploys_compute_type
  report_build_status = false
  tags                = var.tags

  build_image       = var.deploy_image
  privileged_mode   = var.deploys_privileged_mode
  buildspec         = var.deploy_prod_buildspec
  local_cache_modes = var.deploy_local_cache_modes
  cache_type        = var.deploy_cache_type

}

resource "aws_s3_bucket" "pipeline_s3" {
  bucket        = "${var.project_name}-cicd-bucket"
  acl           = "private"
  force_destroy = true
  versioning {
    enabled = false
  }
  lifecycle_rule {
    enabled = true
    expiration {
      days = 180
    }
  }
  tags = var.tags
}

resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-cicd-pipeline"
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
        BranchName           = var.github_branch
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
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName   = module.build.project_name
        PrimarySource = "source_output"
      }
    }
  }

  stage {
    name = "DeployStaging"

    action {
      category        = "Build"
      name            = "DeployStaging"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ProjectName   = module.deploy_staging.project_name
        PrimarySource = "build_output"
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
    name = "DeployProduction"

    action {
      category        = "Build"
      name            = "DeployProduction"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ProjectName   = module.deploy_prod.project_name
        PrimarySource = "build_output"
      }
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "codepipeline_role" {
  name        = "${var.project_name}-codepipeline"
  description = "IAM role for CICD codepipeline for project ${var.project_name}"
  tags        = var.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": [
        "${module.deploy_prod.project_arn}",
        "${module.deploy_staging.project_arn}",
        "${module.build.project_arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codestar-connections:UseConnection"
      ],
      "Resource": [
        "${var.codestar_connection_arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_pipeline_access" {
  name        = "${var.project_name}-CicdS3Access"
  description = "Grant access to S3 for CICD pipeline for ${var.project_name}"
  # need to add two resources, bucket itself and objects inside:
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": ["s3:*"],
      "Resource": [
        "${aws_s3_bucket.pipeline_s3.arn}",
        "${aws_s3_bucket.pipeline_s3.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ssm_read_access" {
  name        = "${var.project_name}-CicdSsmReadAccess"
  description = "Grant read only access to SSM for CICD pipeline for ${var.project_name}"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter"
                ],
      "Resource": "arn:aws:ssm:*:*:parameter/*"
    },{
            "Sid": "SSMDescribeAllAccess",
            "Effect": "Allow",
            "Action": "ssm:DescribeParameters",
            "Resource": "*"
        }
  ]
}
EOF
}


resource "aws_iam_policy" "ecr_get_access" {
  count       = var.docker_builds ? 1 : 0
  name        = "${var.project_name}-cicd-ecr-get-access"
  description = "Allows pipeline for ${var.project_name} to download ECR images"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "create_test_report" {
  name        = "${var.project_name}-CicdCreateTestReport"
  description = "Allow CICD pipeline for ${var.project_name} creating test reports"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "codebuild:CreateReportGroup",
        "codebuild:CreateReport",
        "codebuild:UpdateReport",
        "codebuild:BatchPutTestCases"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "deploy" {
  name        = "${var.project_name}-deploy"
  description = "Allow CICD deploy for ${var.project_name} to manage resources"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "cloudformation:*",
        "sns:*",
        "sqs:*",
        "ecr:*",
        "logs:*",
        "execute-api:*",
        "apigateway:*",
        "dynamodb:*",
        "lambda:*",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:PassRole",
        "s3:List*",
        "s3:Get*",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutBucketCORS",
        "s3:PutBucketPolicy",
        "s3:PutBucketAcl",
        "s3:DeleteBucketPolicy",
        "s3:PutEncryptionConfiguration"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_build" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.build.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_pipeline" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = aws_iam_role.codepipeline_role.id
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_deploy_staging" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.deploy_staging.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_deploy_prod" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.deploy_prod.role_id
}

resource "aws_iam_role_policy_attachment" "deploy_staging" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = module.deploy_staging.role_id
}

resource "aws_iam_role_policy_attachment" "deploy_prod" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = module.deploy_prod.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_build" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.build.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_deploy_staging" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.deploy_staging.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_deploy_prod" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.deploy_prod.role_id
}

resource "aws_iam_role_policy_attachment" "get_ecr_images_by_deploy_staging" {
  count = var.docker_builds ? 1 : 0

  policy_arn = aws_iam_policy.ecr_get_access[count.index].id
  role       = module.deploy_staging.role_id
}

resource "aws_iam_role_policy_attachment" "get_ecr_images_by_deploy_prod" {
  count = var.docker_builds ? 1 : 0

  policy_arn = aws_iam_policy.ecr_get_access[count.index].id
  role       = module.deploy_prod.role_id
}

resource "aws_ssm_parameter" "cicd_pipeline_name" {
  count = var.export_pipeline_info ? 1 : 0
  name  = "/${var.github_org}/${var.project_name}/cicd/pipeline/NAME"
  type  = "String"
  value = aws_codepipeline.pipeline.name

  tags = var.tags
}

resource "aws_ssm_parameter" "cicd_pipeline_arn" {
  count = var.export_pipeline_info ? 1 : 0
  name  = "/${var.github_org}/${var.project_name}/cicd/pipeline/ARN"
  type  = "String"
  value = aws_codepipeline.pipeline.arn

  tags = var.tags
}
