# -*- coding: utf-8 -*-
"""
    Notify Slack
    ------------

    Receives event payloads that are parsed and sent to Slack
"""

import base64
import zlib
import json
import logging
import os
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional, Union, cast
from urllib.error import HTTPError

# Set default region if not provided
REGION = os.environ.get("AWS_REGION", "us-east-1")


def format_cloudwatch_filter_event(message: Dict[str, Any], region: str) -> Dict[str, Any]:
    """Format CloudWatch filter event into Slack message format

    :params message: cloudwatch logs message body containing event
    :region: AWS region where the event originated from
    :returns: formatted Slack message payload
    """

    title = f"Error in CloudWatch logGroup {message['logGroup']}"
    event = message['logEvents'][0]
    url = f"https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#logsV2:log-groups"
    url += f"/log-group/{urllib.parse.quote_plus(message['logGroup'])}"
    url += f"/log-events/{urllib.parse.quote_plus(message['logStream'])}"

    return {
        "color": "danger",
        "text": title,
        "fallback": title,
        "fields": [
            {"title": "CloudWatch logGroup error", "value": f"`{message['logGroup']}`", "short": True},
            {
                "title": "Log Group",
                "value": f"`{message['logGroup']}`",
                "short": False,
            },
            {
                "title": "URL",
                "value": url,
                "short": False,
            },
            {
                "title": "Log Stream",
                "value": f"`{message['logStream']}`",
                "short": False,
            },
            {
                "title": "Message",
                "value": f"`{event['message']}`",
                "short": True,
            },
            {
                "title": "AWS Account",
                "value": f"`{message['owner']}`",
                "short": True,
            },
            {
                "title": "AWS Region",
                "value": region,
                "short": True,
            },
        ],
    }


def format_default(
    message: Union[str, Dict], subject: Optional[str] = None
) -> Dict[str, Any]:
    """
    Default formatter, converting event into Slack message format

    :params message: SNS message body containing message/event
    :returns: formatted Slack message payload
    """

    attachments = {
        "fallback": "A new message",
        "text": "AWS notification",
        "title": subject if subject else "Message",
        "mrkdwn_in": ["value"],
    }
    fields = []

    if type(message) is dict:
        for k, v in message.items():
            value = f"{json.dumps(v)}" if isinstance(v, (dict, list)) else str(v)
            fields.append({"title": k, "value": f"`{value}`", "short": len(value) < 25})
    else:
        fields.append({"value": message, "short": False})

    if fields:
        attachments["fields"] = fields  # type: ignore

    return attachments


def get_slack_message_payload(
    message: Union[str, Dict], region: str, subject: Optional[str] = None
) -> Dict:
    """
    Parse notification message and format into Slack message payload

    :params message: SNS message body notification payload
    :params region: AWS region where the event originated from
    :params subject: Optional subject line for Slack notification
    :returns: Slack message payload
    """

    slack_channel = os.environ["SLACK_CHANNEL"]
    slack_username = os.environ["SLACK_USERNAME"]
    slack_emoji = os.environ["SLACK_EMOJI"]

    payload = {
        "channel": slack_channel,
        "username": slack_username,
        "icon_emoji": slack_emoji,
    }
    attachment = None

    if isinstance(message, str):
        try:
            message = json.loads(message)
        except json.JSONDecodeError:
            logging.info("Not a structured payload, just a string message")

    message = cast(Dict[str, Any], message)

    if "logEvents" in message:
        notification = format_cloudwatch_filter_event(message=message, region=region)
        attachment = notification
    elif "attachments" in message or "text" in message:
        payload = {**payload, **message}
    else:
        attachment = format_default(message=message, subject=subject)

    if attachment:
        payload["attachments"] = [attachment]  # type: ignore

    return payload


def send_slack_notification(payload: Dict[str, Any]) -> Dict[str, str]:
    """
    Send notification payload to Slack

    :params payload: formatted Slack message payload
    :returns: response details from sending notification
    """

    slack_url = os.environ["SLACK_WEBHOOK_URL"]

    data = urllib.parse.urlencode({"payload": json.dumps(payload)}).encode("utf-8")
    req = urllib.request.Request(slack_url)

    try:
        result = urllib.request.urlopen(req, data)
        return {"code": result.getcode(), "info": result.info().as_string()}

    except HTTPError as e:
        logging.error(f"{e}: result")
        return {"code": e.getcode(), "info": e.info().as_string()}


def lambda_handler(event: Dict[str, Any], context: Dict[str, Any]) -> str:
    """
    Lambda function to parse notification events and forward to Slack

    :param event: lambda expected event object
    :param context: lambda expected context object
    :returns: none
    """
    if os.environ.get("LOG_EVENTS", "False") == "True":
        logging.info(f"Event logging enabled: `{json.dumps(event)}`")

    if ('awslogs' not in event) or ('data' not in event['awslogs']):
        logging.error(f"No data found in event - `{json.dumps(event)}`")
        payload = get_slack_message_payload(event, os.environ.get("REGION", "us-east-1"), f"Unexpected event received!")
        response = send_slack_notification(payload=payload)

        raise Exception("No data found in event")

    try:
        log_data = zlib.decompress(base64.b64decode(event["awslogs"]["data"]), 16 + zlib.MAX_WBITS)
        # json.loads(zlib.decompress(base64.b64decode(event['awslogs']['data']), zlib.MAX_WBITS | 32))
        log_data = log_data.decode("utf-8")
        logging.info(log_data)
        msg = json.loads(log_data)
    except Exception as e:
        logging.error(f"Error parsing event data - `{e}`")
        payload = get_slack_message_payload(event, os.environ.get("REGION", "us-east-1"), f"Slack notifier failed to parse the event!")
        response = send_slack_notification(payload=payload)
        raise Exception("Error parsing event data")

    payload = get_slack_message_payload(msg, os.environ.get("REGION", "us-east-1"))
    response = send_slack_notification(payload=payload)

    if response["code"] != 200:
        response_info = response["info"]
        logging.error(
            f"Error: received status `{response_info}` using event `{event}` and context `{context}`"
        )

    return json.dumps(response)

# # for local debugging:
# if __name__ == "__main__":
#     with open("modules/cloudwatch-subscribe/functions/awslogs-event.json") as f:
#         event = json.loads(f.read())
#         lambda_handler(event, {})
