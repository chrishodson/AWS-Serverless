/**
 * AWS Serverless Integration with Port.io
 * main.tf - Main configuration file
 */

provider "aws" {
  region = var.aws_region
}

provider "port" {
  client_id = var.port_client_id
  secret    = var.port_client_secret
}

# Port.io Blueprints for AWS resources
module "port_blueprints" {
  source = "./modules/port_blueprints"
}

# Port.io Webhooks for receiving AWS events
module "port_webhooks" {
  source       = "./modules/port_webhooks"
  depends_on   = [module.port_blueprints]
  webhook_urls = var.webhook_urls
}

# AWS SQS Queue for event processing
module "aws_resources" {
  source            = "./modules/aws_resources"
  sqs_queue_name    = var.sqs_queue_name
  event_bridge_name = var.event_bridge_name
  webhook_urls      = module.port_webhooks.webhook_urls
}

# AWS Lambda for processing events and sending to Port.io
module "aws_lambda" {
  source                = "./modules/aws_lambda"
  depends_on            = [module.aws_resources, module.port_webhooks]
  lambda_name           = var.lambda_name
  lambda_file_path      = "${path.root}/../lambda/aws_port_handler.zip"
  sqs_queue_arn         = module.aws_resources.sqs_queue_arn
  sqs_queue_name        = var.sqs_queue_name
  webhook_secret        = var.webhook_secret
  webhook_urls          = module.port_webhooks.webhook_urls
  lambda_execution_role = var.lambda_execution_role
}

# EventBridge Rule to trigger Lambda when SQS has messages
resource "aws_cloudwatch_event_rule" "sqs_not_empty" {
  name        = "sqs-not-empty-rule"
  description = "Trigger when SQS queue has messages"

  event_pattern = jsonencode({
    source      = ["aws.sqs"],
    detail-type = ["SQS Queue Status Change"],
    resources   = [module.aws_resources.sqs_queue_arn],
    detail      = {
      status = ["NOT_EMPTY"]
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.sqs_not_empty.name
  target_id = "InvokeLambda"
  arn       = module.aws_lambda.lambda_arn
}


resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.aws_lambda.lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sqs_not_empty.arn
}

# EventBridge target to send events to SQS
resource "aws_cloudwatch_event_target" "send_to_sqs" {
  rule      = aws_cloudwatch_event_rule.sqs_not_empty.name
  target_id = "SendToSQS"
  arn       = module.aws_resources.sqs_queue_arn
}

# Grant EventBridge permission to send messages to SQS
resource "aws_sqs_queue_policy" "allow_eventbridge" {
  queue_url = module.aws_resources.sqs_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = module.aws_resources.sqs_queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.sqs_not_empty.arn
          }
        }
      }
    ]
  })
}
