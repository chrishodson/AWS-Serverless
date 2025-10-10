/**
 * AWS Serverless Integration with Port.io
 * main.tf - Main configuration file
 */

provider "aws" {
  region = var.aws_region
}

provider "port" {
  client_id = var.port_client_id
  secret    = var.port_client_secret
}

# Port.io Blueprints for AWS resources (keep)
module "port_blueprints" {
  source = "./modules/port_blueprints"
}

# Port.io Webhooks for receiving AWS events (single ingest webhook)
module "port_webhooks" {
  source       = "./modules/port_webhooks"
  depends_on   = [module.port_blueprints]
  webhook_urls = var.webhook_urls
}

# Create Port mappings (map webhook payloads to blueprints)
module "port_mappings" {
  source = "./modules/port_mappings"
  depends_on = [module.port_webhooks, module.port_blueprints]
  integration_id = module.port_webhooks.aws_ingest_id
  mappings = [
    "ec2-instance:${module.port_blueprints.ec2Instance_blueprint_id}",
    "s3-bucket:${module.port_blueprints.s3_bucket_blueprint_id}",
    "rds-instance:${module.port_blueprints.rds_instance_blueprint_id}",
    "sqs-queue:${module.port_blueprints.sqs_queue_blueprint_id}",
  ]
  port_api_token = var.port_api_token
}

# NOTE: AWS resources such as SQS queues, Lambda functions, EventBridge rules,
# and related IAM policies are managed in the CloudFormation template
# `terraform/AWS.yml`. To avoid duplicate resources we deliberately do NOT
# create the AWS SQS/EventBridge/Lambda resources here with Terraform.
