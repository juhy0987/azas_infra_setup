# 온프레미스 공인 ip
variable "onprem_public_ip" {
  description = "팀원 각자의 온프레미스 공인 IP (ifconfig.me 결과)"
  type        = string
}

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
}

# AWS EC2 서버 ssh key 경로
variable "aws_key_path" { 
  description = "ansible_ssh_common_args"
  type = string 
}

# DB Server ssh key 경로
variable "db_key_path" { 
  description = "ansible_ssh_private_key_file"
  type = string 
}

# 대상서버에 원격 접속 시도할때 사용하는 로그인 아이디,비밀번호
variable "BOOTSTRAP_USER" { 
  description = "ansible_user, ansible_become_password"
  type = string 
}


