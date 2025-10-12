/**
 * Port.io Webhooks Module
 * outputs.tf - Outputs for the webhooks module
 */

output "webhook_url" {
  description = "URL for the AWS ingest webhook"
  value       = port_webhook.aws_ingest.url
  sensitive   = true
}

output "aws_ingest_id" {
  description = "ID of the AWS ingest integration"
  value       = port_webhook.aws_ingest.id
}
