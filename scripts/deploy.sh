#!/usr/bin/env bash
# Deploy Task Tracker to a target environment via Helm.
# Usage: ./deploy.sh <environment> <image-tag>
# Example: ./deploy.sh prod abc1234

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment> <image-tag>}"
IMAGE_TAG="${2:?Usage: $0 <environment> <image-tag>}"
NAMESPACE="task-tracker-${ENVIRONMENT}"
RELEASE_NAME="task-tracker-${ENVIRONMENT}"

echo "Deploying Task Tracker to ${ENVIRONMENT} (image tag: ${IMAGE_TAG})"

kubectl get namespace "${NAMESPACE}" &>/dev/null || kubectl create namespace "${NAMESPACE}"

helm upgrade --install "${RELEASE_NAME}" ./helm/task-tracker \
  --namespace "${NAMESPACE}" \
  --values "./helm/task-tracker/values.yaml" \
  --values "./helm/task-tracker/values-${ENVIRONMENT}.yaml" \
  --set image.tag="${IMAGE_TAG}" \
  --set backend.image.tag="${IMAGE_TAG}" \
  --set frontend.image.tag="${IMAGE_TAG}" \
  --wait \
  --timeout 5m \
  --atomic

echo "Deployment complete. Verifying rollout..."
kubectl rollout status deployment/"${RELEASE_NAME}-backend" -n "${NAMESPACE}" --timeout=120s
kubectl rollout status deployment/"${RELEASE_NAME}-frontend" -n "${NAMESPACE}" --timeout=120s

echo "✅ Task Tracker deployed successfully to ${ENVIRONMENT}"
