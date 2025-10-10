#!/usr/bin/env bash
# Deploy Port resources via Terraform, then deploy CloudFormation stack for AWS infra
# Usage: ./deploy_cf_and_tf.sh path/to/terraform.tfvars

set -euo pipefail
# Usage:
#   ./deploy_cf_and_tf.sh [--deploy-cf] [path/to/terraform.tfvars]
# By default the script runs only Terraform (Port blueprints/webhooks) and
# prints the CloudFormation deploy command you can run manually. Pass
# --deploy-cf to also run the CloudFormation deployment.

TFVARS=${2:-${1:-terraform.tfvars}}
DEPLOY_CF=0
if [ "${1:-}" = "--deploy-cf" ]; then
  DEPLOY_CF=1
fi

CF_STACK_NAME=${CF_STACK_NAME:-port-aws-integration}
CF_TEMPLATE_FILE="${PWD}/AWS.yml"

echo "Initializing Terraform..."
terraform init

echo "Planning Terraform (Port blueprints/webhooks)..."
terraform plan -var-file="${TFVARS}" -out=tfplan

echo "Applying Terraform..."
terraform apply -auto-approve "tfplan"

# Read outputs (we expect module.port_webhooks.webhook_urls to exist)
WEBHOOK_JSON=$(terraform output -json port_webhook_url 2>/dev/null || true)
if [ -z "$WEBHOOK_JSON" ] || [ "$WEBHOOK_JSON" = "null" ]; then
  echo "ERROR: could not read port_webhook_url from Terraform outputs"
  exit 1
fi

# Extract the webhook URL
WEBHOOK_URL=$(echo "$WEBHOOK_JSON" | jq -r '.value')

if [ -z "$WEBHOOK_URL" ] || [ "$WEBHOOK_URL" = "null" ]; then
  echo "ERROR: webhook URL is empty after extraction"
  exit 1
fi

# Read secret from tfvars if present (do not print it later)
WEBHOOK_SECRET=$(grep -E '^webhook_secret\s*=' "${TFVARS}" | sed -E 's/^webhook_secret\s*=\s*"?(.*)"?$/\1/' || true)
WEBHOOK_SECRET=${WEBHOOK_SECRET:-${WEBHOOK_SECRET}}

if [ "$DEPLOY_CF" -eq 1 ]; then
  if [ -z "$WEBHOOK_SECRET" ]; then
    # try env
    WEBHOOK_SECRET=${WEBHOOK_SECRET:-${WEBHOOK_SECRET_ENV:-}}
  fi
  if [ -z "$WEBHOOK_SECRET" ]; then
    echo "ERROR: webhook secret is required to deploy CloudFormation stack. Set it in ${TFVARS} or as env WEBHOOK_SECRET."
    exit 1
  fi

  echo "Deploying CloudFormation stack $CF_STACK_NAME..."
  aws cloudformation deploy \
    --template-file "$CF_TEMPLATE_FILE" \
    --stack-name "$CF_STACK_NAME" \
    --parameter-overrides WebhookUrl="$WEBHOOK_URL" WebhookSecret="$WEBHOOK_SECRET" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

  echo "Done. CloudFormation stack deployed."
else
  echo
  echo "Terraform apply finished. To deploy AWS resources via CloudFormation run:"
  echo
  echo "aws cloudformation deploy --template-file \"${CF_TEMPLATE_FILE}\" --stack-name ${CF_STACK_NAME} --parameter-overrides WebhookUrl=\"${WEBHOOK_URL}\" WebhookSecret=\"<YOUR_WEBHOOK_SECRET>\" --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM"
  echo
  echo "Notes:"
  echo " - The command above will deploy the SQS, Lambda, EventBridge and IAM resources defined in ${CF_TEMPLATE_FILE}."
  echo " - Replace <YOUR_WEBHOOK_SECRET> with the secret stored in your tfvars or a secure secret manager."
  echo " - If you prefer the script to run CloudFormation automatically, re-run with the --deploy-cf flag:\n     ./deploy_cf_and_tf.sh --deploy-cf ${TFVARS}"
fi
