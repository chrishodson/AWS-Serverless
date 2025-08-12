/**
 * Port.io Webhooks Module
 * outputs.tf - Outputs for the webhooks module
 */

output "webhook_urls" {
  description = "Map of service types to webhook URLs"
  value = {
    ec2 = port_webhook.ec2_webhook.url
    s3  = port_webhook.s3_webhook.url
    rds = port_webhook.rds_webhook.url
    sqs = port_webhook.sqs_webhook.url
  }
  sensitive = true
}
