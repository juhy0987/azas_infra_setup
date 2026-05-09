# 도메인 네임
variable "domain_name" {
  description = "본인이 소유한 도메인 이름"
  type        = string 
}

# trocky ip
variable "onprem_rocky_ip" { 
  description = "var.onprem_rocky_ip"
  type = string 
}

# tubuntu ip
variable "onprem_ubuntu_ip" { 
  description = "var.onprem_ubuntu_ip"
  type = string 
}

# DB Server ip
variable "db_server_ip" { 
  description = "var.db_server_ip"
  type = string 
}

# 온프레미스 ssh key 경로
variable "onprem_key_path" { 
  description = "ansible_ssh_private_key_file"
  type = string
  default = "~/.ssh/defaultkey.pem"
}

# AWS EC2 서버 ssh key 경로
variable "aws_key_path" { 
  description = "ansible_ssh_common_args"
  type = string
  default = "~/.ssh/azas-key.pem"
}

# DB Server ssh key 경로
variable "db_key_path" { 
  description = "ansible_ssh_private_key_file"
  type = string 
  default = "~/.ssh/defaultkey.pem"
}

# 대상서버에 원격 접속 시도할때 사용하는 로그인 아이디,비밀번호
variable "BOOTSTRAP_USER" {
  description = "ansible_user, ansible_become_password"
  type = string
}

# Tailscale 로 도달할 온프레미스 사설 대역
variable "onprem_cidr" {
  description = "Bastion+Tailscale 을 통해 도달할 온프레미스 사설 네트워크 CIDR"
  type        = string
  default     = "172.16.8.0/24"
}

# ALB 가 var.onprem_cidr 안에서 라우팅할 실제 호스트 IP 목록
variable "onprem_target_ips" {
  description = "ALB onprem target group 에 등록할 IP 주소 목록 (예: 172.16.8.10)"
  type        = list(string)
  default     = ["172.16.8.11", "172.16.8.12"]
}

# ALB 가중치 분배 - AWS / 온프레미스
variable "alb_aws_weight" {
  description = "ALB HTTPS default action 에서 AWS target group 가중치"
  type        = number
  default     = 0
}

variable "alb_onprem_weight" {
  description = "ALB HTTPS default action 에서 온프레미스 target group 가중치"
  type        = number
  default     = 100
}


