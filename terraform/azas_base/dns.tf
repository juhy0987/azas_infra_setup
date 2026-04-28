# Route 53 호스팅 영역을 직접 생성합니다.(도메인 등록되있어야함)
variable "domain_name" {
  description = "Route 53 호스팅 영역에 사용할 도메인 이름"
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

