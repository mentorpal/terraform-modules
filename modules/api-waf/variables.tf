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

variable "enable_ip_and_origin_whitelisting" {
  type        = bool
  default     = false
  description = "should firewall exclude amazon ip range from bot protection rules"
}

variable "allowed_uri_regex_set" {
  type        = list(string)
  default     = ["^.*"]
  description = "a list of uri regex patterns to allow"
}

variable "secret_header_name" {
  type        = string
  description = "name of passthrough header"
}

variable "secret_header_value" {
  type = string
}

variable "allowed_origins" {
  type = list(string)
}

variable "blocked_headers" {
  description = "Map of headers and their blocked values"
  type        = map(list(string))
  default     = {}
}