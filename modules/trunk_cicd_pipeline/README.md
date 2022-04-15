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

## Prerequsities
1. Have AWS provider defined
```hcl
provider "aws" {
  //...
}
```
2. Declare a module and override the defaults as necessary
3. Have present buildspec files for CodeBuild steps. By default they should be in `cicd` folder located in root folder of your projects.
  - `buildspec.yml` - steps for build step of release pipeline
  - `deployspec.yml` - steps for deployment step of release pipeline
