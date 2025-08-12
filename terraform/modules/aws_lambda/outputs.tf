/**
 * AWS Lambda Module
 * outputs.tf - Outputs for the Lambda function
 */

output "lambda_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.port_event_processor.arn
}

output "lambda_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.port_event_processor.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}
