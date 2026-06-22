resource "aws_route53_zone" "this" {
  count = var.manage_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name = var.domain_name
  }
}

data "aws_route53_zone" "existing" {
  count = var.manage_zone ? 0 : 1
  name  = var.domain_name
}
