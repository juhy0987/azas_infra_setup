
# Cloudflare DNS 레코드를 테라폼으로 제어(AWS 서버 확인용도)
resource "cloudflare_record" "alb_cname" {
  zone_id = var.cloudflare_zone_id #본인의 zone id
  name    = "azas" # 루트 도메인(지정가능)
  content = aws_lb.main_alb.dns_name # ALB 주소를 자동으로 가져옵니다!
  type    = "CNAME"
  proxied = true
}

# 루트 도메인을 Route 53 네임서버로 연결 (NS 레코드 위임)
# 이 설정이 있어야 nslookup 시 Route 53 주소가 뜹니다.
resource "cloudflare_record" "route53_ns" {
  for_each  = toset(data.aws_route53_zone.main.name_servers)

  zone_id   = var.cloudflare_zone_id
  name      = "@"              # 도메인 참조
  content   = each.value       # Route 53 네임서버 주소 (4개 각각 등록)
  type      = "NS"
  ttl       = 3600             # NS 레코드는 보통 1시간 권장
}


# 온프레미스 서버에 대한 상태 검사 생성
resource "aws_route53_health_check" "onprem_check" {
  fqdn        = var.domain_name # 도메인으로 접속하겠다
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3" # 3회에서 2회로 줄임 (60초 만에 감지)
  request_interval  = "30" # 30초에서 10초로 줄임 (빠른 검사 - 추가 비용 발생)

  tags = { Name = "onprem-health-check" }
}



# 기본(Primary) 레코드: 온프레미스 서버
resource "aws_route53_record" "onprem_primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "onprem"
  health_check_id = aws_route53_health_check.onprem_check.id
  records         = [var.onprem_public_ip] # 온프레미스 IP
  ttl             = 60
}

# 보조(Secondary) 레코드: AWS ALB
resource "aws_route53_record" "aws_secondary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "aws"

  alias {
    name                   = aws_lb.main_alb.dns_name
    zone_id                = aws_lb.main_alb.zone_id
    evaluate_target_health = true
  }
} 