/**
 * AWS Resources Module
 * main.tf - Creates AWS resources (SQS, EventBridge)
 */

# Create SQS queue for AWS events
resource "aws_sqs_queue" "port_events_queue" {
  name                       = var.sqs_queue_name
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600  # 4 days
  
  tags = {
    Name        = var.sqs_queue_name
    Environment = "production"
    Managed_by  = "terraform"
  }
}

# Create EventBridge for AWS events
resource "aws_cloudwatch_event_bus" "port_event_bus" {
  name = var.event_bridge_name
}

# Rules for EC2 state changes (direct to webhook)
resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "ec2-state-change-rule"
  description = "Capture EC2 state changes and send to Port"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Instance State-change Notification"]
  })
  
  event_bus_name = aws_cloudwatch_event_bus.port_event_bus.name
}

resource "aws_cloudwatch_event_target" "ec2_webhook" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  target_id = "SendToPortWebhook"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:api-destination/port-ec2-webhook"
  
  event_bus_name = aws_cloudwatch_event_bus.port_event_bus.name
}

# Rules for all other events (to SQS queue)
resource "aws_cloudwatch_event_rule" "all_resources_events" {
  name        = "all-resources-events-rule"
  description = "Capture resource events and send to SQS"
  
  event_pattern = jsonencode({
    source = ["aws.s3", "aws.rds", "aws.sqs"]
  })
  
  event_bus_name = aws_cloudwatch_event_bus.port_event_bus.name
}

resource "aws_cloudwatch_event_target" "events_to_sqs" {
  rule      = aws_cloudwatch_event_rule.all_resources_events.name
  target_id = "SendToSQSQueue"
  arn       = aws_sqs_queue.port_events_queue.arn
  
  event_bus_name = aws_cloudwatch_event_bus.port_event_bus.name
}

# Allow EventBridge to send messages to SQS
resource "aws_sqs_queue_policy" "events_to_sqs" {
  queue_url = aws_sqs_queue.port_events_queue.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.port_events_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.all_resources_events.arn
          }
        }
      }
    ]
  })
}

# Current AWS region and account data
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
