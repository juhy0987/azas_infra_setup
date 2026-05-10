# ============================================================
# ASG 이벤트 자동화 — SNS → Lambda → SQS → on-prem management 데몬
#   - launch / terminate 시 즉시 ansible-playbook 으로 인벤토리/Prometheus 갱신
# ============================================================

# 1. SNS 토픽 — ASG lifecycle hook 의 notification target
resource "aws_sns_topic" "asg_events" {
  name = "azas-asg-events"
}

# 2. ASG 가 SNS 에 publish 하기 위한 Role
resource "aws_iam_role" "asg_to_sns" {
  name = "azas-asg-to-sns"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "autoscaling.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "asg_to_sns" {
  name = "asg-publish-sns"
  role = aws_iam_role.asg_to_sns.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.asg_events.arn
    }]
  })
}

# 3. Lifecycle Hooks (launch + terminate)
resource "aws_autoscaling_lifecycle_hook" "launching" {
  name                    = "azas-launching"
  autoscaling_group_name  = aws_autoscaling_group.project_asg.name
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 300
  notification_target_arn = aws_sns_topic.asg_events.arn
  role_arn                = aws_iam_role.asg_to_sns.arn
}

resource "aws_autoscaling_lifecycle_hook" "terminating" {
  name                    = "azas-terminating"
  autoscaling_group_name  = aws_autoscaling_group.project_asg.name
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 300
  notification_target_arn = aws_sns_topic.asg_events.arn
  role_arn                = aws_iam_role.asg_to_sns.arn
}

# 4. SQS 큐 — management 서버가 long-poll
resource "aws_sqs_queue" "asg_tasks" {
  name                       = "azas-asg-tasks"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 3600
}

# 5. Lambda 패키지 (asg_handler.py 단일 파일 zip)
data "archive_file" "asg_handler_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/asg_handler.py"
  output_path = "${path.module}/lambda_src/asg_handler.zip"
}

# 6. Lambda 실행 역할
resource "aws_iam_role" "lambda_asg" {
  name = "azas-lambda-asg"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_asg.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_inline" {
  name = "lambda-asg-inline"
  role = aws_iam_role.lambda_asg.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.asg_tasks.arn
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:CompleteLifecycleAction"]
        Resource = aws_autoscaling_group.project_asg.arn
      },
    ]
  })
}

# 7. Lambda 함수
resource "aws_lambda_function" "asg_handler" {
  function_name    = "azas-asg-handler"
  filename         = data.archive_file.asg_handler_zip.output_path
  source_code_hash = data.archive_file.asg_handler_zip.output_base64sha256
  handler          = "asg_handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_asg.arn
  timeout          = 30

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.asg_tasks.url
    }
  }
}

# 8. SNS → Lambda
resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.asg_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.asg_handler.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asg_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.asg_events.arn
}

# 9. management 서버용 IAM user (SQS 폴링 + EC2/ASG describe)
resource "aws_iam_user" "management_consumer" {
  name = "azas-management-consumer"
}

resource "aws_iam_access_key" "management_consumer" {
  user = aws_iam_user.management_consumer.name
}

resource "aws_iam_user_policy" "management_consumer" {
  name = "management-consumer-policy"
  user = aws_iam_user.management_consumer.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = aws_sqs_queue.asg_tasks.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
        ]
        Resource = "*"
      },
    ]
  })
}

# 10. management 서버에 export 할 값들 (terraform output → ansible/.env)
output "management_aws_access_key_id" {
  value     = aws_iam_access_key.management_consumer.id
  sensitive = true
}

output "management_aws_secret_access_key" {
  value     = aws_iam_access_key.management_consumer.secret
  sensitive = true
}

output "asg_tasks_queue_url" {
  value = aws_sqs_queue.asg_tasks.url
}
