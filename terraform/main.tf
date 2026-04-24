terraform {
    required_version = "~>1.14.0"
    required_providers {
      aws = {
            source = "hashicorp/aws"
            version = "~> 6.0" 
      }
    }
}

# 최신 Amazon Linux 2023 AMI 데이터 소스
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # x86_64 아키텍처용 패턴입니다. (t3.micro용)
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# cloudflare_ips 변수 선언
variable "cloudflare_ips" {
  type        = list(string)
  description = "Cloudflare IP 리스트를 담는 변수"
}

# cloudflare_endpoint 변수 선언
variable "cloudflare_endpoint" {
  type        = string
  description = "Cloudflare 엔드포인트 변수"
}


# 1. provider 설정
provider "aws" {
    region = "ap-northeast-2" # 서울
}

# 2. vpc 및 네트워크 생성 
resource "aws_vpc" "vpc" {
    cidr_block              = "10.0.0.0/16"
    enable_dns_hostnames    = true
    tags = { Name           = "azas-vpc" }
}

# 인터넷 게이트 웨이
resource "aws_internet_gateway" "igw" {
    # 위에서 만들어진 vpc
    vpc_id          = aws_vpc.vpc.id
    tags = { Name   = "azas-igw" }
}

# 2. 멀티 가용 영역 서브넷 설정 (ALB 필수 조건)
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.8.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = { Name           = "azas-public-2a" }
}

resource "aws_subnet" "public_subnet_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.9.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = { Name           = "azas-public-2c" }
}

# private subnet(ec2)
resource "aws_subnet" "private_subnet_a" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.1.0/24" # 256개의 ip를 이방에 할당
    availability_zone       = "ap-northeast-2a"
    tags = { Name           = "azas_private_subnet" }
}

# 3. NAT 게이트웨이 설정 (프라이빗 서버 외출용)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id # 퍼블릭에 위치
  tags          = { Name = "azas-nat-gw" }
}


# 4. 라우팅 테이블 및 연결
resource "aws_route_table" "public_rt" {
    # 어떤 vpc의 소속인지 설정
    vpc_id = aws_vpc.vpc.id
    # 라우팅 규칙 (0.0.0.0/0)으로 가는 트래픽은 인터넷게이트(igw) 웨이로 보내라
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name       = "azas_route"
    }

}

# public subnet 을  public_rt 라우팅 테이블로 연결
resource "aws_route_table_association" "pub_a" {
    subnet_id       = aws_subnet.public_subnet_a.id # 퍼블릿 서브넷 id
    route_table_id  = aws_route_table.public_rt.id # public_rt 라우팅 테이블로 연결
}

resource "aws_route_table_association" "pub_c" {
  subnet_id      = aws_subnet.public_subnet_c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id           = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

resource "aws_route_table_association" "pri_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

# 5. 보안 그룹 (ALB & EC2)
resource "aws_security_group" "alb_sg" {
  name          = "azas-alb-sg"
  vpc_id        = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.cloudflare_ips # 보안을 위해 Cloudflare IP 대역으로 제한 권장
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 6. ALB 생성
resource "aws_lb" "main_alb" {
  name               = "azas-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_c.id]
}

# 7. 대상 그룹(Target Group) - 온프레미스(Rocky) 전용
resource "aws_lb_target_group" "onprem_tg" {
  name        = "azas-onprem-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip" # Rocky
}

# 8. 대상 그룹(Target Group) - AWS 인스턴스 전용
resource "aws_lb_target_group" "aws_tg" {
  name        = "azas-aws-tg"
  port        = 80
  protocol    = "HTTP" 
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"
}

# 9. 리스너 및 규칙 (Cloudflare -> ALB -> 온프레미스 전송)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type       = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.onprem_tg.arn
        weight = 100 # 기본적으로 온프레미스로 전송
      }
      target_group {
        arn    = aws_lb_target_group.aws_tg.arn
        weight = 0
      }
    }
  }
}


# 10. AWS EC2 인스턴스 생성 및 등록
resource "aws_instance" "app_server" {
  # 데이터 소스에서 가져온 ID를 사용합니다.
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.kp.key_name     #azas-key

  tags                   = { Name = "azas-ec2" }
}


# pem 파일 관련 작업
resource "tls_private_key" "pk" {
    algorithm   = "RSA"
    rsa_bits    = 4096
}

# 공개키 등록
resource "aws_key_pair" "kp" {
    key_name   = "azas-key"
    public_key = tls_private_key.pk.public_key_openssh
}

# 개인키를 가져오기
# 'local_file' resource 를 이용하면 파일을 생성할 수 있다.
resource "local_file" "ssh_key" {
    # ${path.module}은 현재 실행경로를 의미한다.
    filename        = "${path.module}/azas-key.pem"
    content         = tls_private_key.pk.private_key_pem
    file_permission = "0600" # 파일 권한 설정
}


resource "aws_lb_target_group_attachment" "aws_target" {
  target_group_arn = aws_lb_target_group.aws_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 80
}


