###
# All infra for automatically subscribing new cloudwatch log groups a lambda->slack.
# https://aws.amazon.com/blogs/infrastructure-and-automation/how-to-automatically-subscribe-to-amazon-cloudwatch-logs-groups/
###

locals {
  lambda_subscriber_name = "cw-log-groups-auto-subscriber"
  lambda_notifier_name   = "cw-logs-error-slack-notifier"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "AllowWriteToCloudwatchLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [replace("${try(aws_cloudwatch_log_group.lambda_subscriber.arn, "")}:*", ":*:*", ":*")]
  }

  statement {
    sid     = "AllowSubscribeCloudwatchLogs"
    effect  = "Allow"
    actions = ["logs:PutSubscriptionFilter"]
    # resources = ["arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:*:*"]
    resources = ["arn:aws:logs:*:${var.aws_account_id}:log-group:*:*"]
  }
  statement {
    sid       = "AllowLambdaPutSubscriptionFilter"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_event_rule" "log_groups" {
  name        = "capture-new-log-group-created"
  description = "Capture log group creation"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.logs"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
      "eventSource":[
         "logs.amazonaws.com"
      ],
      "eventName":[
         "CreateLogGroup"
      ]
   }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "log_groups_rule" {
  rule      = aws_cloudwatch_event_rule.log_groups.name
  target_id = local.lambda_subscriber_name
  arn       = module.lambda_subscriber.lambda_function_arn
}

resource "aws_cloudwatch_log_group" "lambda_subscriber" {
  name              = "/aws/lambda/${local.lambda_subscriber_name}"
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "slack_notifier" {
  name              = "/aws/lambda/${local.lambda_notifier_name}"
  retention_in_days = 90
}

data "aws_iam_policy_document" "slack_notifier" {
  statement {
    sid       = "AllowWriteToCloudwatchLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [replace("${try(aws_cloudwatch_log_group.slack_notifier.arn, "")}:*", ":*:*", ":*")]
  }
}

module "slack_notifier" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.36.0" # tested also with 4.0

  function_name = local.lambda_notifier_name
  description   = "Fired by CW filter, sends a message to slack."

  handler     = "notify_slack.lambda_handler"
  source_path = "${path.module}/functions/notify_slack.py"
  runtime     = "python3.8"
  timeout     = 30

  # If publish is disabled, there will be "Error adding new Lambda Permission:
  # InvalidParameterValueException: We currently do not support adding policies for $LATEST."
  publish = true

  environment_variables = {
    LOG_EVENTS        = "False"
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    SLACK_CHANNEL     = var.slack_channel
    SLACK_USERNAME    = var.slack_username
    SLACK_EMOJI       = ":aws:"
    REGION            = var.aws_region
  }

  # Do not use Lambda's policy for cloudwatch logs, because we have to add a policy
  # for KMS conditionally. This way attach_policy_json is always true independenty of
  # the value of presense of KMS. Famous "computed values in count" bug...
  attach_cloudwatch_logs_policy = false
  attach_policy_json            = true
  policy_json                   = try(data.aws_iam_policy_document.slack_notifier.json, "")

  use_existing_cloudwatch_log_group = true

  allowed_triggers = {
    AllowExecutionFromCloudWatch = {
      principal  = "logs.${var.aws_region}.amazonaws.com"
      source_arn = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:*"
    }
  }

  store_on_s3 = false

  depends_on = [aws_cloudwatch_log_group.slack_notifier]
}


module "lambda_subscriber" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.36.0" # tested also with 4.0

  function_name = local.lambda_subscriber_name
  description   = "New CloudWatch log group creation handler, subscribes new log groups to a target ARN."

  handler     = "subscribe_group.lambda_handler"
  source_path = "${path.module}/functions/subscribe_group.py"
  runtime     = "python3.8"
  timeout     = 30

  # If publish is disabled, there will be "Error adding new Lambda Permission:
  # InvalidParameterValueException: We currently do not support adding policies for $LATEST."
  publish = true

  environment_variables = {
    LOG_EVENTS = "True" # allow this function to log events for debugging
    TARGET_ARN = module.slack_notifier.lambda_function_arn
  }

  # Do not use Lambda's policy for cloudwatch logs, because we have to add a policy
  # for KMS conditionally. This way attach_policy_json is always true independenty of
  # the value of presense of KMS. Famous "computed values in count" bug...
  attach_cloudwatch_logs_policy = false
  attach_policy_json            = true
  policy_json                   = try(data.aws_iam_policy_document.lambda.json, "")

  use_existing_cloudwatch_log_group = true

  allowed_triggers = {
    AllowExecutionFromCloudWatch = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.log_groups.arn
    }
  }

  store_on_s3 = false

  depends_on = [aws_cloudwatch_log_group.lambda_subscriber]
}
