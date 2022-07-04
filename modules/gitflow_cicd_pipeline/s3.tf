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
