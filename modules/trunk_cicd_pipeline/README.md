# CICD Terraform module for trunk-based projects

This folder contains terraform module that creates a CICD pipeline.
The pipeline builds off a single branch (main/master). It deploys all
changes to the staging environment, and has a manual approval step
for production deploys.

Created pipeline contains:
  - CodeBuild for Building
  - CodeBuild for Deployment to staging env
  - Step for manual approval of production deployment
  - CodeBuild for Deployment to production env

Buildspec files for CodeBuild steps (in `cicd` folder by default):
  - `buildspec.yml`
  - `deployspec_staging.yml`
  - `deployspec_prod.yml`

# Resources

 - https://alite-international.com/minimal-viable-ci-cd-with-terraform-aws-codepipeline/
 - https://serverlessfirst.com/create-iam-deployer-roles-serverless-app/
 - https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
 - https://aws.amazon.com/blogs/devops/building-a-ci-cd-pipeline-for-cross-account-deployment-of-an-aws-lambda-api-with-the-serverless-framework/
