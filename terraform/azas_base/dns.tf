terraform {
    required_version = "~>1.14.0"
    required_providers {
      aws = {
            source = "hashicorp/aws"
            version = "~> 6.0" 
      }
      cloudflare = {
            source  = "cloudflare/cloudflare"
            version = "~> 4.0"
      }
    }
}
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true # 보안을 위해 값 출력 방지
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Route 53 호스팅 영역을 직접 생성합니다.(도메인 등록되있어야함)
variable "domain_name" {
  description = "Route 53 호스팅 영역에 사용할 도메인 이름"
  type        = string
}
# 도메인 Zone ID
variable "cloudflare_zone_id" {
  description = "팀원 각자의 도메인 존 ID"
  type        = string
}

# 네임서버 4개를 랜덤부여 방지 
resource "aws_route53_zone" "main" {
  name = var.domain_name

  # destory해도 삭제를 방지
  lifecycle {
    prevent_destroy = true 
  }
}

# 루트 도메인을 Route 53 네임서버로 연결 (NS 레코드 위임)
# 이 설정이 있어야 nslookup 시 Route 53 주소가 뜹니다.
resource "cloudflare_record" "route53_ns" {
  for_each  = toset(aws_route53_zone.main.name_servers)

  zone_id   = var.cloudflare_zone_id
  name      = "@"              # 도메인 참조
  content   = each.value       # Route 53 네임서버 주소 (4개 각각 등록)
  type      = "NS"
  ttl       = 3600             # NS 레코드는 보통 1시간 권장
}

# 인증서 생성
resource "aws_acm_certificate" "cert" {
  domain_name             = var.domain_name
  validation_method       = "DNS"

  tags = { Name           = "azas-certificate" }

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53 검증 레코드 생성 (자동)
resource "aws_route53_record" "cert_validation" {
  for_each   = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id # 본인의 호스팅 영역 리소스 이름 확인!
}

# ACM 인증서 검증 리소스 추가
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# 출력 (Output) 설정

output "route53_nameservers" {
  description = "가비아에 등록해야 할 네임서버 주소 4개"
  value       = aws_route53_zone.main.name_servers
}


output "certificate_arn" {
  description = "인증서 ARN (발급 완료 후 확인)"
  value       = aws_acm_certificate_validation.cert.certificate_arn
}

output "route53_zone_id" {
  description = "Route 53 호스팅 영역 ID"
  value       = aws_route53_zone.main.zone_id
}