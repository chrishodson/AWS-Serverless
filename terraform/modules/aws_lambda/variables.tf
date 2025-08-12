/**
 * AWS Lambda Module
 * variables.tf - Input variables
 */

variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_file_path" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "webhook_secret" {
  description = "Secret for Port.io webhooks"
  type        = string
  sensitive   = true
}

variable "webhook_urls" {
  description = "Map of service types to webhook URLs"
  type        = map(string)
  sensitive   = true
}

variable "lambda_execution_role" {
  description = "Name of the Lambda execution role"
  type        = string
}
