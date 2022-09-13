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
    if "controltower" in log_group_to_subscribe.lower():
        print(f"Skipping subscription for AWS managed log group: `{log_group_to_subscribe}`")
        return
    print(f"Subscribing new log group `{log_group_to_subscribe}")

    cloudwatch_logs.put_subscription_filter(
        logGroupName=log_group_to_subscribe,
        filterName=f'{log_group_to_subscribe}-errors-filter',
        filterPattern='?error ?Error ?ERROR ?Exception ?exception ?EXCEPTION ?fail ?Fail ?FAIL ?FATAL',
        destinationArn=os.environ.get('TARGET_ARN'),
    )
