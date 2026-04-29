# 0. Launch Template
resource "aws_launch_template" "project_lt" {
  name          = "azas-launch-template"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  network_interfaces {
    security_groups = [aws_security_group.ec2_sg.id]
  }

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

# 1. SNS 토픽 생성
resource "aws_sns_topic" "asg_alert" {
  name = "project-asg-alert-topic"
}

# 2. 이메일 구독
resource "aws_sns_topic_subscription" "email_subs" {
  topic_arn = aws_sns_topic.asg_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# 3. 오토 스케일링 그룹 (ASG)
resource "aws_autoscaling_group" "project_asg" {
  name             = "my-project-asg"
  desired_capacity = 1
  max_size         = 4
  min_size         = 1

  vpc_zone_identifier = [aws_subnet.private_subnet_a.id]

  launch_template {
    id      = aws_launch_template.project_lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.aws_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "project-asg-instance"
    propagate_at_launch = true
  }
}

# 4. ASG 스케일링 정책 
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "cpu-70-percent-policy"
  autoscaling_group_name = aws_autoscaling_group.project_asg.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# 5. ASG → SNS 알림 연결
resource "aws_autoscaling_notification" "asg_notify" {
  group_names = [aws_autoscaling_group.project_asg.name]
  topic_arn   = aws_sns_topic.asg_alert.arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}

# 6. 변수
variable "alert_email" {
  description = "ASG 알림 받을 이메일 주소"
  type        = string
}