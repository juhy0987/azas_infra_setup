locals {
  # 모든 EC2 / Launch Template 이 공통으로 사용하는 사전-bake 된 AMI
  # bootstrap + dependency_setup + service_deployment 적용 완료 이미지
  baked_ami_id = "ami-0fccee39d20b9667d"
}

# 최신 Amazon Linux 2023 AMI 데이터 소스 (베스천 호스트 용)
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
