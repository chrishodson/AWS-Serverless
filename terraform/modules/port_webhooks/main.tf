/**
 * Port.io Webhooks Module
 * main.tf - Creates webhooks for AWS resources
 */

/* Single webhook for all AWS events (ingest)
   We intentionally create one webhook (aws_ingest) which receives all AWS events
   and the Lambda/EventBridge/SQS processing will route events to the right
   blueprint within Port. This avoids managing multiple webhook resources. */

resource "port_webhook" "aws_ingest" {
  title       = "AWS Ingest"
  identifier  = "aws_ingest"
  description = "Single webhook to ingest all AWS events and forward to Port blueprints"
  icon        = "AWS"
  enabled     = true
}
