data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "applications" {
  for_each = var.dns_record

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.key
  type    = "A"
  ttl     = "300"
  records = [each.value]
}
