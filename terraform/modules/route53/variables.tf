variable "domain_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "zone_id" {
  type        = string
  description = "Hosted zone ID from the route53-zone module"
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

