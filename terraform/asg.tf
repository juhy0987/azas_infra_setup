# 0. Launch Template
resource "aws_launch_template" "project_lt" {
  name_prefix   = "azas-launch-template"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  network_interfaces {
    security_groups = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash

    # 1. nginx 설치
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # 2. node_exporter 설치
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    if [ $? -eq 0 ]; then
      tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
      cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
      printf '[Unit]\nDescription=Node Exporter\nAfter=network.target\n\n[Service]\nUser=root\nExecStart=/usr/local/bin/node_exporter\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/node_exporter.service
      systemctl daemon-reload
      systemctl enable node_exporter
      systemctl start node_exporter
    fi
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