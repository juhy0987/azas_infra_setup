# 0. Launch Template
#    bootstrap + dependency_setup + service_deployment 이 이미 적용된 커스텀 AMI 사용
resource "aws_launch_template" "project_lt" {
  name_prefix   = "azas-launch-template"
  image_id      = "ami-0fccee39d20b9667d"
  instance_type = "t3.micro"

  network_interfaces {
    security_groups = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # ============================================================
    # * 애플리케이션 서비스 구동 (azas_application_server)
    #    - AMI 에 이미 clone 되어 있으면 최신화, 없으면 clone
    #    - user1 로 uv 를 통해 main 서버 기동
    # ============================================================
    APP_USER=user1
    APP_DIR=/home/$APP_USER/azas_application_server
    REPO_URL=https://github.com/juhy0987/azas_application_server
    UV_BIN=/home/$APP_USER/.local/bin/uv
    APP_HOST=0.0.0.0
    APP_PORT=8000
    LOG_FILE=$APP_DIR/app.log
    PID_FILE=$APP_DIR/.app.pid

    if [ ! -d "$APP_DIR/.git" ]; then
      sudo -u "$APP_USER" git clone "$REPO_URL" "$APP_DIR"
    else
      sudo -u "$APP_USER" git -C "$APP_DIR" pull --ff-only
    fi

    sudo -u "$APP_USER" bash -c "cd $APP_DIR && nohup $UV_BIN run uvicorn main:app --host $APP_HOST --port $APP_PORT > $LOG_FILE 2>&1 < /dev/null & echo \$! > $PID_FILE"
  EOF
  )

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

# 1. 오토 스케일링 그룹
resource "aws_autoscaling_group" "project_asg" {
  name_prefix      = "my-project-asg"
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

# 2. ASG 스케일링 정책
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "cpu-70-percent-policy"
  autoscaling_group_name = aws_autoscaling_group.project_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# 3. 보안 그룹 규칙 추가
resource "aws_security_group_rule" "allow_prometheus" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  security_group_id = aws_security_group.ec2_sg.id
  cidr_blocks       = ["172.16.8.200/32"]
}