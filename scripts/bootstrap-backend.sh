#!/usr/bin/env bash
# Bootstraps the SHARED S3 bucket + DynamoDB table used by Terraform remote
# state for ALL environments (see terraform/environments/*/backend.hcl —
# every environment points at the same bucket/table, differentiated only by
# the `key` path inside the bucket).
#
# Safe to run multiple times / once per environment: bucket and table
# creation are no-ops if the resources already exist.
#
# Usage: ./bootstrap-backend.sh <environment> <aws-region>
# Example: ./bootstrap-backend.sh prod us-east-1
#
# NOTE: <environment> is accepted (and validated) for usage-message
# consistency with the rest of the project's scripts, but it does not affect
# the bucket/table names below — those are shared across all environments,
# matching backend.hcl.

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment> <aws-region>}"
REGION="${2:-us-east-1}"

# Must match the `bucket` / `dynamodb_table` values in
# terraform/environments/*/backend.hcl exactly.
BUCKET_NAME="rashmiranjan-terraform-state-897074277336"
TABLE_NAME="terraform-state-lock"

echo "Bootstrapping shared Terraform backend (triggered for environment: ${ENVIRONMENT}, region: ${REGION})"

# ─── S3 bucket for state ──────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "Bucket ${BUCKET_NAME} already exists, skipping creation."
else
  echo "Creating S3 bucket: ${BUCKET_NAME}"
  if [ "${REGION}" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi

  aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
      "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
    }'

  aws s3api put-public-access-block --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

# ─── DynamoDB table for state locking ─────────────────────────────────────────
if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" &>/dev/null; then
  echo "DynamoDB table ${TABLE_NAME} already exists, skipping creation."
else
  echo "Creating DynamoDB table: ${TABLE_NAME}"
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --region "${REGION}"
fi

echo "Backend bootstrap complete."
echo "Run: terraform init -backend-config=environments/${ENVIRONMENT}/backend.hcl"
