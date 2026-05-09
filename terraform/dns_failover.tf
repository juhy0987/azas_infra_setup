# Route53 도메인 → ALB
#   - ALB 가 단일 진입점이며, AWS target group / 온프레미스 target group(Tailscale 너머)
#     으로의 분배는 ALB 의 가중치 forward + 각 target group 헬스체크가 담당
#   - 따라서 별도의 Route53 failover / onprem 헬스체크는 불필요
resource "aws_route53_record" "main_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main_alb.dns_name
    zone_id                = aws_lb.main_alb.zone_id
    evaluate_target_health = true
  }
}
