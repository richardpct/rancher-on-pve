data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "applications" {
  for_each = { for application in var.applications : application.name => application }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = "A"
  ttl     = "300"
  records = [each.value.ip]
}
