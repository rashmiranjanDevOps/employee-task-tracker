variable "domain_name" {
  type = string
}

variable "subject_alternative_names" {
  type = list(string)
}

variable "route53_zone_id" {
  type = string
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.this.certificate_arn
}
