#!/usr/bin/env bash
# pre-deploy-check.sh — Run before every production deployment.
# Verifies required placeholders are replaced and secrets are injected.
set -euo pipefail

ERRORS=0

check() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "❌ UNFILLED PLACEHOLDER: $label in $file"
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ $label"
  fi
}

echo "=== Pre-deploy placeholder check ==="

# GitOps values — all environments
check "gitops/environments/prod/values.yaml"    "REPLACE_WITH_WAF_WEB_ACL_ARN" "WAF ACL ARN (prod)"
check "gitops/environments/prod/values.yaml"    "REPLACE_WITH_IRSA_ROLE_ARN"   "IRSA Role ARN (prod)"
check "gitops/environments/dev/values.yaml"     "REPLACE_WITH_IRSA_ROLE_ARN"   "IRSA Role ARN (dev)"
check "gitops/environments/qa/values.yaml"      "REPLACE_WITH_IRSA_ROLE_ARN"   "IRSA Role ARN (qa)"
check "gitops/environments/staging/values.yaml" "REPLACE_WITH_IRSA_ROLE_ARN"   "IRSA Role ARN (staging)"

# K8s base secret template (should be replaced by ESO/Sealed Secrets before apply)
check "k8s/base/secret.yaml" "REPLACE_WITH_RDS_ENDPOINT" "RDS endpoint in secret.yaml"
check "k8s/base/secret.yaml" "REPLACE_WITH_DB_USER"      "DB user in secret.yaml"
check "k8s/base/secret.yaml" "REPLACE_WITH_DB_PASSWORD"  "DB password in secret.yaml"
check "k8s/base/secret.yaml" "REPLACE_WITH_JWT_SECRET"   "JWT_SECRET in secret.yaml"

# EKS public access CIDR
check "terraform/environments/prod/terraform.tfvars" "REPLACE_WITH_OFFICE_VPN_CIDR" "EKS public_access_cidrs (prod)"

# Ingress cert ARN
check "k8s/base/ingress.yaml" "ACCOUNT_ID" "ACM certificate ARN (ingress.yaml)"

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ $ERRORS placeholder(s) not replaced. Fix before deploying to production."
  exit 1
else
  echo "✅ All placeholders resolved. Safe to deploy."
fi
