# CICD Terraform module for trunk-based projects

This folder contains terraform module that creates a CICD pipeline.
The pipeline builds two long-lived branches (main and release).
It deploys main to the dev environment and release to the staging environment.
There's a manual approval step for production deploys of the release branch.

Created pipeline contains:
  - CodeBuild for Building
  - CodeBuild for Deployment to dev env
  - CodeBuild for Deployment to stage env
  - CodeBuild for end-to-end tests post-stage deploy
  - Step for manual approval of production deployment
  - CodeBuild for Deployment to production env

Buildspec files for CodeBuild steps (in `cicd` folder by default):
  - `buildspec.yml`
  - `deployspec_dev.yml`
  - `deployspec_staging.yml`
  - `deployspec_prod.yml`

# Resources

 - https://alite-international.com/minimal-viable-ci-cd-with-terraform-aws-codepipeline/
 - https://serverlessfirst.com/create-iam-deployer-roles-serverless-app/
 - https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
 - https://aws.amazon.com/blogs/devops/building-a-ci-cd-pipeline-for-cross-account-deployment-of-an-aws-lambda-api-with-the-serverless-framework/
