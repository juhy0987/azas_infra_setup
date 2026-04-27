# 참조
data "aws_route53_zone" "main" {
  name = var.domain_name
}

data "aws_acm_certificate" "cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# 보안 그룹 (ALB & EC2)
resource "aws_security_group" "alb_sg" {
  name           = "azas-alb-sg"
  vpc_id         = aws_vpc.vpc.id
  ingress {
    from_port    = 80
    to_port      = 80
    protocol     = "tcp"
    cidr_blocks  = var.cloudflare_ips # 보안을 위해 Cloudflare IP 대역으로 제한 권장
  }

  # HTTPS 접속 허용
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.cloudflare_ips
  }

  egress {
    from_port    = 0
    to_port      = 0
    protocol     = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name              = "azas-ec2-sg"
  vpc_id            = aws_vpc.vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# ALB 생성
resource "aws_lb" "main_alb" {
  name               = "azas-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_c.id]
}

# 대상 그룹(Target Group) - AWS 인스턴스 전용
resource "aws_lb_target_group" "aws_tg" {
  name        = "azas-aws-tg"
  port        = 80
  protocol    = "HTTP" 
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"
}

# 리스너 및 가중치 설정 (Cloudflare -> ALB -> 온프레미스 전송)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type            = "redirect" # 'forward' 블록 대신 'redirect' 설정을 넣어야 합니다.
    redirect {
      port          = "443"
      protocol      = "HTTPS"
      status_code   = "HTTP_301"
    }
  }
}

# HTTPS 리스너 설정 (443 포트)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main_alb.arn # 식별 주소
  port                 = "443"
  protocol             = "HTTPS"
  certificate_arn      = data.aws_acm_certificate.cert.arn

  default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.aws_tg.arn # EC2 전용 타겟 그룹으로만 전송
    }
}

resource "aws_lb_target_group_attachment" "aws_target" {
  target_group_arn = aws_lb_target_group.aws_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 80
}