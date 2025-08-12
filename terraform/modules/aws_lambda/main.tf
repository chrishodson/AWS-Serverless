/**
 * AWS Lambda Module
 * main.tf - Creates Lambda function for processing events
 */

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = var.lambda_execution_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda SQS access policy
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${var.lambda_name}-sqs-policy"
  description = "Policy for Lambda to access SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Effect   = "Allow",
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

# Lambda function
resource "aws_lambda_function" "port_event_processor" {
  function_name    = var.lambda_name
  filename         = var.lambda_file_path
  source_code_hash = filebase64sha256(var.lambda_file_path)
  role             = aws_iam_role.lambda_role.arn
  handler          = "driver.lambda_handler"
  runtime          = "python3.13"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      WEBHOOK_SECRET        = var.webhook_secret
      SQS_QUEUE_NAME        = var.sqs_queue_name
      EC2_WEBHOOK_URL       = var.webhook_urls["ec2"]
      S3_WEBHOOK_URL        = var.webhook_urls["s3"]
      RDS_WEBHOOK_URL       = var.webhook_urls["rds"]
      SQS_WEBHOOK_URL       = var.webhook_urls["sqs"]
    }
  }
}

# Lambda SQS trigger
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.port_event_processor.function_name
  batch_size       = 10
  enabled          = true
}
