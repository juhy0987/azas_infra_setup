# Cloudflare IP 리스트 (보안 그룹에서 사용)
variable "cloudflare_ips" {
  description = "Cloudflare IP 리스트를 담는 변수"
  type        = list(string)
}

# 도메인 Zone ID
variable "cloudflare_zone_id" {
  description = "팀원 각자의 도메인 존 ID"
  type        = string
}

# Cloudflare API Token
variable "cloudflare_api_token" {
  description = "팀원 각자의 API 토큰"
  type        = string
  sensitive   = true # 보안을 위해 터미널에 표시되지 않음
}

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