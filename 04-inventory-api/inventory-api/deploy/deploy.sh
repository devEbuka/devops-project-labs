#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:?AWS_REGION must be provided}"
DB_SECRET_ARN="${DB_SECRET_ARN:?DB_SECRET_ARN must be provided}"
DB_HOST="${DB_HOST:?DB_HOST must be provided}"
JWT_SECRET_ARN="${JWT_SECRET_ARN:?JWT_SECRET_ARN must be provided}"

DB_SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text
)

JWT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$JWT_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

DB_USER=$(printf '%s' "$DB_SECRET_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["username"])')

DB_PASSWORD=$(printf '%s' "$DB_SECRET_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["password"])')
DB_PASSWORD_ENCODED=$(printf '%s' "$DB_PASSWORD" | python3 -c 'import sys; from urllib.parse import quote; print(quote(sys.stdin.read(), safe=""))')
export DATABASE_URL="postgresql+psycopg://${DB_USER}:${DB_PASSWORD_ENCODED}@${DB_HOST}:5432/inventory_db"
export JWT_SECRET

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY="dev-inventory_api"
IMAGE_TAG="v1"
export IMAGE_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS \
  --password-stdin "$ECR_REGISTRY"


docker pull "$IMAGE_URI"
# Initialize database tables
docker compose -f "$SCRIPT_DIR/compose.yaml" run --rm init

# Start the API
docker compose -f "$SCRIPT_DIR/compose.yaml" up -d api