/*
  NOTE: SQS, EventBridge, and related policies are managed in the
  CloudFormation template `terraform/AWS.yml`. To prevent duplicate
  resource creation, this Terraform module no longer creates these
  resources.

  If you need Terraform-managed SQS/EventBridge resources instead of
  CloudFormation, restore the previous resource definitions here and
  ensure the CloudFormation stack is not applied or import the existing
  resources into Terraform state.
*/

variable "sqs_queue_name" {
  type    = string
  default = ""
}

variable "event_bridge_name" {
  type    = string
  default = ""
}

output "sqs_queue_arn" {
  value       = ""
  description = "Deprecated - SQS queue ARN is managed by terraform/AWS.yml"
}

output "sqs_queue_url" {
  value       = ""
  description = "Deprecated - SQS queue URL is managed by terraform/AWS.yml"
}

output "event_bridge_arn" {
  value       = ""
  description = "Deprecated - EventBridge ARN is managed by terraform/AWS.yml"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
