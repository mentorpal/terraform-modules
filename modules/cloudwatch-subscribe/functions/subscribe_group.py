# -*- coding: utf-8 -*-
"""
    Subscribe log group
    ------------

    CloudWatch::CreateLogGroup event handler, creates a subscription filter to the given TARGET_ARN
"""

import json
import os
from typing import Any, Dict
import boto3

cloudwatch_logs = boto3.client('logs')


def should_subscribe(log_group_name: str) -> bool:
    """
    Check if log group should be subscribed

    :param log_group_name: name of log group
    :returns: boolean
    """

    # it must not subscribe itself, otherwise it will go into an infinite loop
    exclude_list = os.environ.get("EXCLUDE").split(",")
    for fn in exclude_list:
        if fn in log_group_name:
            return False
    if 'dev' in log_group_name:
        return False
    if log_group_name.startswith("/aws/lambda/"):
        return True
    if log_group_name.startswith("API-Gateway-Execution-Logs"):
        # this might be redundant, but just in case
        return True
    if log_group_name.startswith("/aws/elasticbeanstalk") and "/containers/" in log_group_name:
        # this cover just the service logs, all other docker logs are excluded:
        # /aws/elasticbeanstalk/mentorpal-dev-sbert/var/log/* are excluded
        # /aws/elasticbeanstalk/mentorpal-*-sbert/containers/sbert-service.log are included
        return True
    return False


def lambda_handler(event: Dict[str, Any], context: Dict[str, Any]) -> str:
    """
    Lambda function to subscribe newly created log groups

    :param event: lambda expected event object
    :param context: lambda expected context object
    :returns: none
    """
    if os.environ.get("LOG_EVENTS", "False") == "True":
        print(f"Event logging enabled: `{json.dumps(event)}`")

    log_group_to_subscribe = event['detail']['requestParameters']['logGroupName']
    print(f"new log group created: `{log_group_to_subscribe}")

    if not should_subscribe(log_group_to_subscribe.lower()):
        print(f"Skipping subscription for AWS managed log group: `{log_group_to_subscribe}`")
        return

    print(f"Subscribing new log group `{log_group_to_subscribe}")

    cloudwatch_logs.put_subscription_filter(
        logGroupName=log_group_to_subscribe,
        filterName=f'{log_group_to_subscribe}-errors-filter',
        filterPattern='?error ?Error ?ERROR ?Exception ?exception ?EXCEPTION ?fail ?Fail ?FAIL ?FATAL',
        destinationArn=os.environ.get('TARGET_ARN'),
    )
