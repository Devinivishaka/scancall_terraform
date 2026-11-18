#!/usr/bin/env bash
set -eo pipefail

REGION="${AWS_REGION:-eu-west-1}"
ENVIRONMENT="${ENV:-dev}"
REDEPLOY="${REDEPLOY:-true}"

echo "=========================================================="
echo " ScanCall: Build & Push Microservices to AWS ECR"
echo "=========================================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "[✓] AWS Account: ${ACCOUNT_ID} in Region: ${REGION}"

# Authenticate Docker to ECR
echo "--> Authenticating Docker with ECR..."
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SERVICES=(
  "api-gateway:scancall/api-gateway:scancall_api_gateway"
  "core-service:scancall/core-service:scancall_backend_phase1"
  "call-service:scancall/call-service:scancall-call-service"
)

for entry in "${SERVICES[@]}"; do
  IFS=":" read -r NAME REPO_NAME FOLDER <<< "${entry}"
  
  echo "=========================================================="
  echo " Building & Pushing: ${REPO_NAME}"
  echo "=========================================================="
  
  LATEST_TAG="${ECR_REGISTRY}/${REPO_NAME}:latest"
  VERSION_TAG="${ECR_REGISTRY}/${REPO_NAME}:${TIMESTAMP}"
  
  docker build -t "${LATEST_TAG}" -t "${VERSION_TAG}" -f "${ROOT_DIR}/${FOLDER}/Dockerfile" "${ROOT_DIR}/${FOLDER}"
  
  echo "Pushing ${LATEST_TAG}..."
  docker push "${LATEST_TAG}"
  
  echo "Pushing ${VERSION_TAG}..."
  docker push "${VERSION_TAG}"
  
  echo "[✓] Successfully pushed ${REPO_NAME}"
done

if [ "${REDEPLOY}" = "true" ]; then
  echo "--> Triggering ECS Service force new deployments..."
  CLUSTER="scancall-cluster-${ENVIRONMENT}"
  for entry in "${SERVICES[@]}"; do
    IFS=":" read -r NAME REPO_NAME FOLDER <<< "${entry}"
    SERVICE="scancall-${NAME}-${ENVIRONMENT}"
    echo "Updating ECS service ${SERVICE}..."
    aws ecs update-service --cluster "${CLUSTER}" --service "${SERVICE}" --force-new-deployment --region "${REGION}" > /dev/null
  done
  echo "[✓] All ECS services signaled for new deployment!"
fi

echo "=========================================================="
echo " ALL SERVICES SUCCESSFULLY BUILT & DEPLOYED!"
echo "=========================================================="
