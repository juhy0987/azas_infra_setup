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