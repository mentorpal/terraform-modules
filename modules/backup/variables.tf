variable "name" {
  description = "backup plan name, should be unique"
  type        = string
}

variable "resources" {
  description = "A list of ARNs for resources to be backed up"
  type        = list(string)
}

variable "alert_topic_arn" {
  type        = string
  description = "sns topic arn used for alerts"
  default     = ""
}

variable "enable_notifications" {
  type        = bool
  default     = false
  description = "send messages to alert topic"
}

variable "tags" {
  description = "A map of tags to apply to the backup plan, vaults etc"
  type        = map(any)
  default = {
    Project = "mentorpal"
    Source  = "terraform"
  }
}
