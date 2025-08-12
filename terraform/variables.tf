/**
 * AWS Serverless Integration with Port.io
 * variables.tf - Variables definition
 */

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "port_client_id" {
  description = "Port.io API client ID"
  type        = string
  sensitive   = true
}

variable "port_client_secret" {
  description = "Port.io API client secret"
  type        = string
  sensitive   = true
}

variable "webhook_secret" {
  description = "Secret for Port.io webhooks"
  type        = string
  sensitive   = true
}

variable "webhook_urls" {
  description = "Map of service types to webhook URLs (if pre-existing)"
  type        = map(string)
  default     = {}
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue for event processing"
  type        = string
  default     = "port-aws-events-queue"
}

variable "event_bridge_name" {
  description = "Name of the EventBridge for AWS events"
  type        = string
  default     = "port-aws-events-bridge"
}

variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "port-aws-event-processor"
}

variable "lambda_execution_role" {
  description = "Name of the Lambda execution role"
  type        = string
  default     = "port-aws-lambda-role"
}
