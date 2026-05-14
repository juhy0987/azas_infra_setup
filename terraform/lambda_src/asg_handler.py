"""ASG lifecycle hook handler.

Receives SNS-wrapped ASG lifecycle events, forwards a compact payload to SQS
for the on-prem management daemon, and immediately completes the lifecycle
action so that ASG is not blocked.
"""
import json
import os

import boto3

asg = boto3.client("autoscaling")
sqs = boto3.client("sqs")

QUEUE_URL = os.environ["QUEUE_URL"]


def handler(event, context):
    for record in event.get("Records", []):
        try:
            msg = json.loads(record["Sns"]["Message"])
        except Exception as e:
            print(f"Failed to parse SNS message: {e}")
            continue

        hook = msg.get("LifecycleHookName")
        asg_name = msg.get("AutoScalingGroupName")
        token = msg.get("LifecycleActionToken")
        instance_id = msg.get("EC2InstanceId")
        transition = msg.get("LifecycleTransition")

        # ASG sends a "Test" event when a hook is created. Skip non-lifecycle msgs.
        if not all([hook, asg_name, token, instance_id, transition]):
            print(f"Skipping non-lifecycle message: {msg}")
            continue

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(
                {
                    "instance_id": instance_id,
                    "asg_name": asg_name,
                    "transition": transition,
                }
            ),
        )

        try:
            asg.complete_lifecycle_action(
                LifecycleHookName=hook,
                AutoScalingGroupName=asg_name,
                LifecycleActionToken=token,
                LifecycleActionResult="CONTINUE",
            )
        except Exception as e:
            print(f"complete_lifecycle_action failed: {e}")

    return {"status": "ok"}
