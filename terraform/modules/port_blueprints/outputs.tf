/**
 * Port.io Blueprints Module
 * outputs.tf - Outputs for the blueprints module
 */

output "ec2_instance_blueprint_id" {
  description = "ID of the EC2 instance blueprint"
  value       = port_blueprint.ec2_instance.id
}

output "s3_bucket_blueprint_id" {
  description = "ID of the S3 bucket blueprint"
  value       = port_blueprint.s3_bucket.id
}

output "rds_instance_blueprint_id" {
  description = "ID of the RDS instance blueprint"
  value       = port_blueprint.rds_instance.id
}

output "sqs_queue_blueprint_id" {
  description = "ID of the SQS queue blueprint"
  value       = port_blueprint.sqs_queue.id
}
