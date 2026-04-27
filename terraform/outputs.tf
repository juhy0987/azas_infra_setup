# 생성된 AWS EC2의 공인 IP 주소 출력
output "aws_ec2_public_ip" {
  value       = aws_instance.app_server.public_ip  # 'web_backup'은 본인의 리소스 이름으로 수정하세요
  description = "public IP address"
}

# EC2 인스턴스의 프라이빗 IP 주소 출력 (대역 확인용)
output "aws_ec2_private_ip" {
  value       = aws_instance.app_server.private_ip
  description = "private IP address"
}

# 로드밸런서(ALB)의 DNS 주소: nginx가 설치되었는지 확인하기
output "alb_dns_name" {
  value       = aws_lb.main_alb.dns_name
  description = "ALB DNS name"
}

# Route 53 네임서버 주소 (가장 중요!)
# Cloudflare에 등록하거나 nslookup으로 확인할 때 이 주소 4개가 필요합니다.
output "route53_name_servers" {
  value       = data.aws_route53_zone.main.name_servers
  description = "Route 53 Hosted Zone Name Servers"
}

# VPC ID 확인
# 나중에 피어링을 하거나 다른 리소스를 붙일 때
output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "VPC ID"
}

# Route 53 상태 검사 ID
# 온프레미스 상태 검사가 정상적으로 생성되었는지 식별할 때 씁니다.
output "route53_health_check_id" {
  value       = aws_route53_health_check.onprem_check.id
  description = "Route 53 Health Check ID"
}

# 가용 영역(AZ) 확인
# 현재 인스턴스가 어떤 건물(AZ)에 배치되었는지 확실히 보여줍니다.
output "ec2_availability_zone" {
  value       = aws_instance.app_server.availability_zone
  description = "EC2 Availability Zone"
} 