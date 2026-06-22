locals {
  # prod uses bare subdomains (app., api.); every other environment is
  # prefixed (dev-app., qa-api., staging-app., ...) — matching the Ingress
  # hosts configured in helm values and the ACM SAN lists per environment.
  app_host = var.environment == "prod" ? "app.${var.domain_name}" : "${var.environment}-app.${var.domain_name}"
  api_host = var.environment == "prod" ? "api.${var.domain_name}" : "${var.environment}-api.${var.domain_name}"
}

# ─── {env}-app.rashmidevops.xyz → ALB ─────────────────────────────────────
resource "aws_route53_record" "app" {
  zone_id = var.zone_id
  name    = local.app_host
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ─── {env}-api.rashmidevops.xyz → ALB ─────────────────────────────────────
resource "aws_route53_record" "api" {
  zone_id = var.zone_id
  name    = local.api_host
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ─── grafana.rashmidevops.xyz → ALB (prod only — shared monitoring stack) ──
resource "aws_route53_record" "grafana" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = var.zone_id
  name    = "grafana.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ─── argocd.rashmidevops.xyz → ALB (prod only — shared GitOps tooling) ────
resource "aws_route53_record" "argocd" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = var.zone_id
  name    = "argocd.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ─── Health check for primary app endpoint ──────────────────────────────────────
resource "aws_route53_health_check" "app" {
  fqdn              = local.app_host
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${local.app_host}-health-check"
  }
}
