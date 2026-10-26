#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-1}"
RELEASE="v1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/dev"

# Retrieve the bucket name from Terraform outputs
BUCKET_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw deployment_bucket_name)

echo "Uploading deployment artifacts to s3://${BUCKET_NAME}/releases/${RELEASE}/"

aws s3 cp "$SCRIPT_DIR/deploy.sh" \
  "s3://${BUCKET_NAME}/releases/${RELEASE}/deploy.sh" \
  --region "$AWS_REGION"

aws s3 cp "$SCRIPT_DIR/compose.yaml" \
  "s3://${BUCKET_NAME}/releases/${RELEASE}/compose.yaml" \
  --region "$AWS_REGION"

echo "Deployment artifacts uploaded successfully."