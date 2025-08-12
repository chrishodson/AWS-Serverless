/**
 * AWS Resources Module
 * outputs.tf - Outputs for the AWS resources
 */

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.port_events_queue.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.port_events_queue.url
}

output "event_bridge_arn" {
  description = "ARN of the EventBridge"
  value       = aws_cloudwatch_event_bus.port_event_bus.arn
}
