# AWS EC2 인스턴스 생성 및 등록
resource "aws_instance" "app_server" {
  # 사전-bake 된 공통 AMI 사용
  ami                    = local.baked_ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.kp.key_name     #azas-key
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  tags                   = { Name = "azas-ec2" }
}

# 베스천 호스트 EC2 인스턴스 생성
#   - SSH bastion 역할 + Tailscale subnet router 겸용
#   - on-prem 대역(var.onprem_cidr) 트래픽을 IP 포워딩 + Tailscale 터널로 전달
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id # 사용 중인 리전의 최신 Amazon Linux AMI
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.public_subnet_a.id # 반드시 퍼블릭 서브넷에 위치
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.kp.key_name
  associate_public_ip_address = true # 공인 IP 할당
  source_dest_check           = false # subnet router 동작에 필수 (포워딩 트래픽 통과)

  # Tailscale API 매칭에 사용할 안정적인 hostname 고정
  user_data = base64encode(<<-EOF
    #!/bin/bash
    hostnamectl set-hostname azas-bastion
  EOF
  )

  tags = { Name = "azas-bastion" }
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

# 개인키를 ansible 디렉토리로 직접 출력
#   - 인벤토리(ansible_ssh_private_key_file)와 ProxyCommand 가 동일 파일을 참조
#   - var.aws_key_path 기본값과 일치 (variables.tf 참조)
resource "local_file" "ssh_key" {
    filename        = "${path.module}/../ansible/azas-key.pem"
    content         = tls_private_key.pk.private_key_pem
    file_permission = "0600" # 파일 권한 설정
}


