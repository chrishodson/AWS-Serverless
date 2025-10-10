/*
  NOTE: Lambda resources are managed in the CloudFormation template
  `terraform/AWS.yml` on the feature/CloudFormation branch. To avoid
  creating duplicate AWS resources from both Terraform and CloudFormation,
  this module intentionally does not create the Lambda, IAM roles, or
  event source mapping.

  If you want to re-enable Terraform-managed Lambda resources, restore the
  previous resource definitions here and ensure the CloudFormation stack
  is not applied, or import the existing resources into Terraform state.
*/

// Minimal variable and output stubs so other modules can reference
// attributes without causing Terraform plan/apply errors.

variable "lambda_name" {
  type    = string
  default = ""
}

variable "lambda_file_path" {
  type    = string
  default = ""
}

variable "sqs_queue_arn" {
  type    = string
  default = ""
}

output "lambda_arn" {
  value       = ""
  description = "Deprecated - Lambda managed by terraform/AWS.yml"
}

output "lambda_name" {
  value       = var.lambda_name
  description = "Deprecated - Lambda name; actual resource lives in AWS CloudFormation"
}
