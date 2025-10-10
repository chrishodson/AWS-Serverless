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

  # Native mappings managed by the Port provider. These map incoming events
  # (the Lambda sets `.body.blueprint`) to Port blueprints and entity properties.
  mappings = [
    {
      blueprint = "s3-bucket"
      operation = { type = "create" }
      filter    = ".body.blueprint == \"s3-bucket\""
      entity = {
        identifier = "\"s3-bucket\""
        title      = "\"Mapped s3-bucket\""
        properties = {
          bucket_name        = ".body.properties.bucket_name"
          creation_date      = ".body.properties.creation_date"
          region             = ".body.properties.region"
          acl                = ".body.properties.acl"
          versioning_enabled = ".body.properties.versioning_enabled"
        }
      }
    },
    {
      blueprint = "ec2-instance"
      operation = { type = "create" }
      filter    = ".body.blueprint == \"ec2-instance\""
      entity = {
        identifier = "\"ec2-instance\""
        title      = "\"Mapped ec2-instance\""
        properties = {
          instance_state    = ".body.properties.instance_state"
          instance_type     = ".body.properties.instance_type"
          availability_zone = ".body.properties.availability_zone"
          public_dns        = ".body.properties.public_dns"
          private_dns       = ".body.properties.private_dns"
        }
      }
    },
    {
      blueprint = "rds-instance"
      operation = { type = "create" }
      filter    = ".body.blueprint == \"rds-instance\""
      entity = {
        identifier = "\"rds-instance\""
        title      = "\"Mapped rds-instance\""
        properties = {
          instance_identifier = ".body.properties.instance_identifier"
          engine              = ".body.properties.engine"
          status              = ".body.properties.status"
          endpoint            = ".body.properties.endpoint"
        }
      }
    },
    {
      blueprint = "sqs-queue"
      operation = { type = "create" }
      filter    = ".body.blueprint == \"sqs-queue\""
      entity = {
        identifier = "\"sqs-queue\""
        title      = "\"Mapped sqs-queue\""
        properties = {
          queue_name                = ".body.properties.queue_name"
          queue_url                 = ".body.properties.queue_url"
          visibility_timeout        = ".body.properties.visibility_timeout"
          message_retention_seconds = ".body.properties.message_retention_seconds"
          fifo_queue                = ".body.properties.fifo_queue"
          region                    = ".body.properties.region"
        }
      }
    }
  ]
}
