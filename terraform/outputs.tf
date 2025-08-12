/**
 * AWS Serverless Integration with Port.io
 * outputs.tf - Output values
 */

output "port_webhook_urls" {
  description = "URLs for Port.io webhooks"
  value       = module.port_webhooks.webhook_urls
  sensitive   = true
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = module.aws_resources.sqs_queue_url
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.aws_lambda.lambda_arn
}

output "event_bridge_arn" {
  description = "ARN of the EventBridge"
  value       = module.aws_resources.event_bridge_arn
}
