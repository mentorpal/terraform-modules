resource "aws_cloudwatch_event_rule" "pipeline" {
  count       = var.enable_status_notifications ? 1 : 0
  name        = "${var.project_name}-cicd-pipeline"
  description = "${var.project_name} CodePipeline execution status"

  event_pattern = <<PATTERN
{
    "detail-type": ["CodePipeline Action Execution State Change"],
    "source": ["aws.codepipeline"],
    "detail": {
        "pipeline": ["${aws_codepipeline.pipeline.name}"],
        "state":["SUCCEEDED","FAILED"],
        "type": {
          "category": ["Source","Deploy","Build","Test"]
        }
    }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "pipeline" {
  count     = var.enable_status_notifications ? 1 : 0
  rule      = aws_cloudwatch_event_rule.pipeline[0].name
  target_id = "SendToSNS"
  arn       = data.aws_ssm_parameter.sns_topic_arn.value
}

data "aws_ssm_parameter" "sns_topic_arn" {
  name = "/shared/sns_cicd_alert_topic_arn"
}
