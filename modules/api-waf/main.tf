data "aws_ip_ranges" "mentor_us_regions" {
  regions  = ["us-east-1", "us-west-2"]
  services = ["amazon", "codebuild", "ec2"]
}

locals {
  ipwhitelist = var.enable_ip_and_origin_whitelisting ? [true] : []
}

resource "aws_wafv2_ip_set" "amazon_whitelist_ipv4" {
  name               = "${var.name}-amazon-ipv4"
  description        = "Amazon IPv4 addresses"
  scope              = var.scope #REGIONAL or CLOUDFRONT
  ip_address_version = "IPV4"
  addresses          = data.aws_ip_ranges.mentor_us_regions.cidr_blocks
  tags               = var.tags
  count = 1
}

resource "aws_wafv2_ip_set" "amazon_whitelist_ipv6" {
  name               = "${var.name}-amazon-ipv6"
  description        = "Amazon IPv6 addresses"
  scope              = var.scope #REGIONAL or CLOUDFRONT
  ip_address_version = "IPV6"
  addresses          = data.aws_ip_ranges.mentor_us_regions.ipv6_cidr_blocks
  tags               = var.tags
  count = 1
}

resource "aws_wafv2_regex_pattern_set" "uri_regex_set" {
  name  = "${var.name}-uri-regex-set"
  scope = "REGIONAL"
  dynamic "regular_expression" {
    for_each = var.allowed_uri_regex_set
    content {
      regex_string = regular_expression.value
    }
  }
}

resource "aws_wafv2_web_acl" "wafv2_webacl" {
  name  = "${var.name}-wafv2-webacl"
  scope = var.scope
  tags  = var.tags

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-wafv2-webacl"
    sampled_requests_enabled   = true
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
        dynamic "excluded_rule" {
          for_each = var.excluded_common_rules
          content {
            name = excluded_rule.value
          }
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
    name     = "uri-regex-match"
    priority = 3
    action {
      block {}
    }
    statement {
      not_statement {
        statement {
          regex_pattern_set_reference_statement {
            arn = aws_wafv2_regex_pattern_set.uri_regex_set.arn
            field_to_match {
              uri_path {
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.rate_limit}-ip-rate-limit-rule"
      sampled_requests_enabled   = false
    }
  }

  dynamic "rule" {
    for_each = local.ipwhitelist
    content {
      name     = "IpSetRule-Whitelist-Amazon-IPv4-IPv6"
      priority = "5"
      action {
        block {}
      }
      statement {


        not_statement{
          statement{
          or_statement{
            statement{
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.amazon_whitelist_ipv6[0].arn
              }
            }
            statement{
              ip_set_reference_statement {
                arn = aws_wafv2_ip_set.amazon_whitelist_ipv4[0].arn
              }
            }
            statement {
              or_statement {
                dynamic "statement" {
                  for_each = var.allowed_origins
                  content {
                    byte_match_statement {
                      field_to_match {
                        single_header {
                          name = "origin"
                        }
                      }
                      positional_constraint = "CONTAINS"
                      search_string         = statement.value
                      text_transformation {
                        type     = "NONE"
                        priority = 0
                      }
                    }
                  }
                }
              }
            }

            # Scope down
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = var.secret_header_name
                  }
                }
                positional_constraint = "EXACTLY"
                search_string         = var.secret_header_value
                text_transformation {
                  type     = "NONE"
                  priority = 0
                }
              }
            }

            
          }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "AWS-IPv4-IPv6-origin"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "bot-control"
    priority = 10

    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        # see https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-bot.html
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        scope_down_statement {
          not_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = var.secret_header_name
                  }
                }
                positional_constraint = "EXACTLY"
                search_string         = var.secret_header_value
                text_transformation {
                  type     = "NONE"
                  priority = 0
                }
              }
            }
          }
        }

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

  dynamic "rule" {
    for_each = length(var.blocked_headers) > 0 ? [1] : []
    content {
      name     = "block-specific-header-values"
      priority = 15

      action {
        block {}
      }

      statement {
        or_statement {
          dynamic "statement" {
            for_each = flatten([
              for header, values in var.blocked_headers : [
                for value in values : {
                  header = header
                  value  = value
                }
              ]
            ])
            content {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = statement.value.header
                  }
                }
                positional_constraint = "CONTAINS"
                search_string         = statement.value.value
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "block-specific-header-values"
        sampled_requests_enabled   = true
      }
    }
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

resource "aws_wafv2_web_acl_logging_configuration" "waf_logging_conf" {
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
