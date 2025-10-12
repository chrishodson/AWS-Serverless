# AWS-Serverless Terraform Scripts

This directory contains Terraform scripts for setting up the AWS Serverless integration with Port.io.

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate credentials
- Port.io API credentials (Client ID and Secret)

## Directory Structure

```
terraform/
├── main.tf               # Main Terraform configuration
├── variables.tf          # Variable definitions
├── outputs.tf            # Output definitions
├── versions.tf           # Version constraints
├── terraform.tfvars      # Your variable values (create from terraform.tfvars.example)
├── modules/
    ├── port_blueprints/  # Port.io blueprints for AWS resources
    ├── port_webhooks/    # Port.io webhooks for receiving AWS events
    ├── aws_resources/    # AWS resources (SQS, EventBridge)
    └── aws_lambda/       # AWS Lambda for processing events
```

## Setup

1. Copy the example variables file and update with your values:
   ```
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` and add your Port.io credentials and AWS region.

3. Prepare the Lambda deployment package:
   ```
   cd ../lambda
   npm install
   zip -r aws_port_handler.zip index.js node_modules
   ```

## Usage

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Plan the deployment:
   ```
   terraform plan
   ```

3. Apply the configuration:
   ```
   terraform apply
   ```

## Combined deploy script

This repository includes a helper script `deploy_cf_and_tf.sh` that will:

- Run Terraform (Port blueprints and webhooks)
- Read the Port webhook URL from Terraform outputs
- Deploy the CloudFormation template `AWS.yml` with the webhook URL and secret

Usage:

```bash
cd /workspaces/AWS-Serverless/terraform
chmod +x deploy_cf_and_tf.sh
./deploy_cf_and_tf.sh terraform.tfvars
```

Note: the script expects `jq` and `aws` CLI to be installed and configured.

## Functionality

These Terraform scripts will:

1. Create/validate webhooks in Port for each AWS resource type supported
2. Set up blueprints and mappings for each supported AWS resource type
3. Create/validate an SQS queue
4. Create an EventBridge in the AWS account
    - For EC2 state changes, events are sent directly to the webhook
    - For all other events, events are put into SQS
5. Create a Lambda that reads SQS and forwards events to the correct Port.io webhook
6. Create a rule to run the Lambda when the SQS queue has messages

## Supported AWS Resources

- EC2 instances
- S3 buckets
- RDS instances
- SQS queues

## Port mapping helper scripts (utils/)

This repo now contains helper scripts under the top-level `utils/` directory. They are used by the Terraform `port_mappings` module to create idempotent webhook mappings in Port.

- `utils/create_port_mappings.py` - builds a document-style mappings array and PATCHes the Port webhook at `/v1/webhooks/<identifier>` when mappings differ. The Terraform module calls this script via a `null_resource` local-exec provisioner. Usage from the repo root:

```bash
# Example (requires PORT_API_TOKEN in env):
PORT_API_TOKEN="<token>" python3 utils/create_port_mappings.py --integration-id aws_ingest --map s3-bucket:mapping-s3-bucket --map ec2-instance:mapping-ec2-instance
```

- `utils/parse_port_blueprints.py` - helper to parse `terraform/modules/port_blueprints/main.tf` and emit a `blueprints_local.json` summary. Useful for auditing blueprint identifiers and properties.

Notes:
- Ensure `PORT_API_TOKEN` is set in the environment (do NOT prefix with "Bearer ") when Terraform runs the mapping step.
- The Terraform module `terraform/modules/port_mappings` now references `../utils/create_port_mappings.py` (was `../scripts`) and will re-run when the `mappings` trigger changes.

