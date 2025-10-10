/**
 * AWS Serverless Integration with Port.io
 * outputs.tf - Output values
 */

output "port_webhook_url" {
  description = "URL for Port.io AWS ingest webhook"
  value       = module.port_webhooks.webhook_url
  sensitive   = true
}

# The AWS resources (SQS, Lambda, EventBridge) are managed via the
# CloudFormation template `terraform/AWS.yml`. If you need the ARNs/URLs
# exposed as Terraform outputs, enable them by importing the CloudFormation
# stack outputs or re-creating corresponding Terraform data resources.
