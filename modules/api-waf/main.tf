resource "aws_wafv2_web_acl" "wafv2_webacl" {
  name  = "${var.name}-wafv2-webacl"
  scope = "CLOUDFRONT"
  tags  = var.tags

  default_action {
    allow {}
  }

  rule {
    name     = "ip-rate-limit-rule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = var.rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.rate_limit}-ip-rate-limit-rule"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "common-control"
    priority = 2

    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        # see https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-crs
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        excluded_rule {
          # 8kb is not enough
          name = "SizeRestrictions_BODY"
        }
        excluded_rule {
          # flags legit image upload attemts
          name = "CrossSiteScripting_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-Common-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "bot-control"
    priority = 3

    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        # see https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-bot.html
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        dynamic "excluded_rule" {
          for_each = var.excluded_bot_rules
          content {
            name = excluded_rule.value
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-BotControl-rule"
      sampled_requests_enabled   = true
    }
  }


  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-wafv2-webacl"
    sampled_requests_enabled   = true
  }
}

resource "aws_s3_bucket" "s3_logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = "aws-waf-logs-${var.aws_region}-${var.name}"
  acl    = "private"
  tags   = var.tags
}

data "aws_iam_policy_document" "policy_assume_kinesis" {
  count = var.enable_logging ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose_role" {
  count              = var.enable_logging ? 1 : 0
  name               = "firehose-aws-waf-logs-${var.aws_region}-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.policy_assume_kinesis[0].json
  tags               = var.tags
}

# https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html#using-iam-s3
data "aws_iam_policy_document" "s3_policy_document" {
  count = var.enable_logging ? 1 : 0

  statement {
    sid = "1"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [
      aws_s3_bucket.s3_logs[0].arn,
    ]
  }

  statement {
    sid = "2"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.s3_logs[0].arn}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_policy" {
  count  = var.enable_logging ? 1 : 0
  name   = "kinesis-s3-waf-write-policy-${var.name}"
  policy = data.aws_iam_policy_document.s3_policy_document[0].json
}

resource "aws_iam_role_policy_attachment" "firehose_s3_policy_attachment" {
  count      = var.enable_logging ? 1 : 0
  role       = aws_iam_role.firehose_role[0].name
  policy_arn = aws_iam_policy.s3_policy[0].arn
}

resource "aws_kinesis_firehose_delivery_stream" "waf_logs_kinesis_stream" {
  count = var.enable_logging ? 1 : 0
  # the name must begin with aws-waf-logs-
  name        = "aws-waf-logs-kinesis-waf-${var.name}"
  destination = "s3"
  s3_configuration {
    role_arn           = aws_iam_role.firehose_role[0].arn
    bucket_arn         = aws_s3_bucket.s3_logs[0].arn
    compression_format = "GZIP"
  }
  tags = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_logging_conf_staging" {
  count                   = var.enable_logging ? 1 : 0
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs_kinesis_stream[0].arn]
  resource_arn            = aws_wafv2_web_acl.wafv2_webacl.arn
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}

output "wafv2_webacl_arn" {
  value = aws_wafv2_web_acl.wafv2_webacl.arn
}
