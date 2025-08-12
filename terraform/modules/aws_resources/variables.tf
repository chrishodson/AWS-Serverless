/**
 * AWS Resources Module
 * variables.tf - Input variables
 */

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "event_bridge_name" {
  description = "Name of the EventBridge"
  type        = string
}

variable "webhook_urls" {
  description = "Map of service types to webhook URLs"
  type        = map(string)
}
