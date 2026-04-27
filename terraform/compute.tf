# AWS EC2 인스턴스 생성 및 등록
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

