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
        "${module.deploy_qa.project_arn}",
        "${module.deploy_dev.project_arn}",
        "${module.e2e_tests.project_arn}",
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
        "s3:*",
        "cloudfront:Get*",
        "cloudfront:CreateInvalidation",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "execute-api:*",
        "apigateway:*",
        "dynamodb:*",
        "lambda:*",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:PassRole"
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

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_deploy_dev" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.deploy_dev.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_deploy_qa" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.deploy_qa.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_deploy_prod" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.deploy_prod.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_cicd_bucket_by_e2e_tests" {
  policy_arn = aws_iam_policy.s3_pipeline_access.arn
  role       = module.e2e_tests.role_id
}

resource "aws_iam_role_policy_attachment" "deploy_dev" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = module.deploy_dev.role_id
}

resource "aws_iam_role_policy_attachment" "deploy_qa" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = module.deploy_qa.role_id
}

resource "aws_iam_role_policy_attachment" "deploy_prod" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = module.deploy_prod.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_build" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.build.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_deploy_dev" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.deploy_dev.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_deploy_qa" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.deploy_qa.role_id
}

resource "aws_iam_role_policy_attachment" "access_to_ssm_by_deploy_prod" {
  policy_arn = aws_iam_policy.ssm_read_access.arn
  role       = module.deploy_prod.role_id
}

resource "aws_iam_role_policy_attachment" "get_ecr_images_by_deploy_dev" {
  count = var.docker_builds ? 1 : 0

  policy_arn = aws_iam_policy.ecr_get_access[count.index].id
  role       = module.deploy_dev.role_id
}

resource "aws_iam_role_policy_attachment" "get_ecr_images_by_deploy_qa" {
  count = var.docker_builds ? 1 : 0

  policy_arn = aws_iam_policy.ecr_get_access[count.index].id
  role       = module.deploy_qa.role_id
}

resource "aws_iam_role_policy_attachment" "get_ecr_images_by_deploy_prod" {
  count = var.docker_builds ? 1 : 0

  policy_arn = aws_iam_policy.ecr_get_access[count.index].id
  role       = module.deploy_prod.role_id
}
