#!/usr/bin/env python3
"""ASG SQS task consumer.

Long-polls an SQS queue for ASG launch/terminate notifications and triggers
ansible-playbook to refresh inventory + Prometheus targets.
"""
import json
import logging
import os
import subprocess
import sys
import time

import boto3

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
)
log = logging.getLogger("asg_consumer")

QUEUE_URL = os.environ["ASG_TASKS_QUEUE_URL"]
ANSIBLE_DIR = os.environ["ANSIBLE_DIR"]
PLAYBOOK = os.environ.get("ANSIBLE_PLAYBOOK", "main.yml")
INVENTORIES = os.environ.get(
    "ANSIBLE_INVENTORIES", "inventory.yml,aws_ec2.yml"
).split(",")

sqs = boto3.client("sqs")


def run_ansible() -> int:
    inv_args = []
    for inv in INVENTORIES:
        inv_args += ["-i", inv]
    cmd = ["ansible-playbook", *inv_args, PLAYBOOK]
    log.info("Running: %s (cwd=%s)", " ".join(cmd), ANSIBLE_DIR)
    res = subprocess.run(cmd, cwd=ANSIBLE_DIR)
    if res.returncode != 0:
        log.error("ansible-playbook returned %d", res.returncode)
    return res.returncode


def main() -> int:
    log.info("ASG consumer started (queue=%s)", QUEUE_URL)
    while True:
        try:
            r = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20,
                VisibilityTimeout=300,
            )
        except Exception as e:
            log.exception("receive_message failed: %s", e)
            time.sleep(10)
            continue

        msgs = r.get("Messages", [])
        if not msgs:
            continue

        for m in msgs:
            try:
                body = json.loads(m["Body"])
                log.info("Event: %s", body)
            except Exception:
                log.exception("Bad message body, skipping")

        # 한 번의 ansible 실행으로 큐에 쌓인 이벤트 일괄 반영
        run_ansible()

        for m in msgs:
            try:
                sqs.delete_message(
                    QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"]
                )
            except Exception:
                log.exception("delete_message failed")


if __name__ == "__main__":
    sys.exit(main())
