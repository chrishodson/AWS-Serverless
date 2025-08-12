/**
 * Port.io Webhooks Module
 * main.tf - Creates webhooks for AWS resources
 */

# Create webhook for EC2 events
resource "port_webhook" "ec2_webhook" {
  title       = "AWS EC2 Events"
  identifier  = "aws-ec2-events"
  description = "Webhook for AWS EC2 instance events"
  icon        = "AWS"
  enabled     = true
}

# Create webhook for S3 events
resource "port_webhook" "s3_webhook" {
  title       = "AWS S3 Events"
  identifier  = "aws-s3-events"
  description = "Webhook for AWS S3 bucket events"
  icon        = "AWS"
  enabled     = true
}

# Create webhook for RDS events
resource "port_webhook" "rds_webhook" {
  title       = "AWS RDS Events"
  identifier  = "aws-rds-events"
  description = "Webhook for AWS RDS instance events"
  icon        = "AWS"
  enabled     = true
}

# Create webhook for SQS events
resource "port_webhook" "sqs_webhook" {
  title       = "AWS SQS Events"
  identifier  = "aws-sqs-events"
  description = "Webhook for AWS SQS queue events"
  icon        = "AWS"
  enabled     = true
}
