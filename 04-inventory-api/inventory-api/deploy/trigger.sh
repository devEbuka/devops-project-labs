#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-1}"
RELEASE="v1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/dev"

BUCKET_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw deployment_bucket_name)

INSTANCE_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw instance_id)
DB_SECRET_ARN=$(terraform -chdir="$TERRAFORM_DIR" output -raw db_secret_arn)
JWT_SECRET_ARN=$(terraform -chdir="$TERRAFORM_DIR" output -raw jwt_secret_arn)
DB_HOST=$(terraform -chdir="$TERRAFORM_DIR" output -raw db_host)

COMMAND_ID=$(aws ssm send-command \
  --region "$AWS_REGION" \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"set -eu\",
    \"mkdir -p /opt/inventory-api\",
    \"aws s3 cp s3://${BUCKET_NAME}/releases/${RELEASE}/deploy.sh /opt/inventory-api/deploy.sh --region ${AWS_REGION}\",
    \"aws s3 cp s3://${BUCKET_NAME}/releases/${RELEASE}/compose.yaml /opt/inventory-api/compose.yaml --region ${AWS_REGION}\",
    \"chmod +x /opt/inventory-api/deploy.sh\",
    \"cd /opt/inventory-api && AWS_REGION=${AWS_REGION} DB_SECRET_ARN=${DB_SECRET_ARN} JWT_SECRET_ARN=${JWT_SECRET_ARN} DB_HOST=${DB_HOST} bash deploy.sh\"
  ]" \
  --query "Command.CommandId" \
  --output text)

echo "SSM command submitted: $COMMAND_ID"

echo "Waiting for deployment to complete..."

if aws ssm wait command-executed \
  --region "$AWS_REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID"; then
  echo "SSM command completed successfully."
else
  echo "SSM deployment failed or timed out."
fi

aws ssm get-command-invocation \
  --region "$AWS_REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Details:StatusDetails,Output:StandardOutputContent,Errors:StandardErrorContent}' \
  --output json

  STATUS=$(aws ssm get-command-invocation \
  --region "$AWS_REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query Status \
  --output text)

if [[ "$STATUS" != "Success" ]]; then
  echo "Deployment did not complete successfully. Status: $STATUS"
  exit 1
fi

echo "Deployment completed successfully."