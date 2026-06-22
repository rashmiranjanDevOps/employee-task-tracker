variable "domain_name" {
  type = string
}

variable "manage_zone" {
  description = <<-EOT
    Whether this environment owns and creates the Route53 hosted zone for
    domain_name. Exactly ONE environment across the whole organization should
    set this to true for a given domain_name — all other environments must
    set it to false and will look up the existing zone instead. Creating the
    same hosted zone from multiple independent Terraform states (one per
    environment) results in duplicate zones with different NS records, only
    one of which can ever be delegated at the registrar; the rest silently
    break DNS validation (e.g. ACM) for their environment.
  EOT
  type        = bool
  default     = false
}
