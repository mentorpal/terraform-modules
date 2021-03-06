variable "name" {
  type        = string
  description = "A unique name to identify this firewall"
}

variable "scope" {
  type        = string
  description = "either CLOUDFRONT or REGIONAL (default)"
  default     = "REGIONAL"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "tags" {
  type = map(string)
}

variable "rate_limit" {
  type        = number
  default     = 100 # minimum
  description = "calls per minute per IP address"
}

variable "excluded_bot_rules" {
  type        = list(any)
  description = "which bot categories to allow, see https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-bot.html"
  default     = []
}

variable "excluded_common_rules" {
  type        = list(any)
  description = "which rules to allow, see https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-baseline.html#aws-managed-rule-groups-baseline-crs"
  default = [
    "SizeRestrictions_BODY",  # 8kb is not enough
    "CrossSiteScripting_BODY" # flags legit image upload attemts
  ]
}

variable "enable_logging" {
  type        = bool
  default     = false
  description = "create s3 bucket to store firewall logs, and a kinesis stream to deliver them"
}

variable "disable_bot_protection_for_amazon_ips" {
  type        = bool
  default     = false
  description = "should firewall exclude amazon ip range from bot protection rules"
}
