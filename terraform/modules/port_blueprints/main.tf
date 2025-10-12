/**
 * Port.io Blueprints Module
 * main.tf - Creates blueprints for AWS resources
 */

# EC2 Instance Blueprint
resource "port_blueprint" "ec2Instance" {
  title      = "EC2 Instance"
  icon       = "EC2"
  identifier = "ec2-instance"

  properties = {
    string_props = {
      instance_state = {
        title = "Instance State"
        enum  = ["pending", "running", "shutting-down", "terminated", "stopping", "stopped"]
        enum_colors = {
          pending         = "yellow"
          running         = "green"
          "shutting-down" = "pink"
          stopped         = "purple"
          stopping        = "orange"
          terminated      = "red"
        }
      }
      instance_type = { title = "Instance Type" }
      availability_zone = { title = "Availability Zone" }
      public_dns = { title = "Public DNS" }
      private_dns = { title = "Private DNS" }
      key_name = { title = "Key Name" }
      image = { title = "Image ID" }
    }
    array_props = {
      security_group_ids = { title = "Security Group IDs" }
    }
    boolean_props = {
      monitoring = { title = "Monitoring" }
    }
  }

  relations = {
    account = {
      title    = "Account"
      target   = "awsAccount"
      required = false
      many     = false
    }
  }
}

# S3 Bucket Blueprint
resource "port_blueprint" "s3_bucket" {
  title      = "S3 Bucket"
  icon       = "AWS"
  identifier = "s3-bucket"

  properties = {
    string_props = {
      bucket_name = { title = "Bucket Name", required = true }
      creation_date = { title = "Creation Date", format = "date-time", required = true }
      region = { title = "Region", required = true }
      acl = { title = "ACL" }
    }
    boolean_props = {
      versioning_enabled = { title = "Versioning Enabled" }
    }
    object_props = {
      tags = { title = "Tags" }
    }
  }
}

# RDS Instance Blueprint
resource "port_blueprint" "rds_instance" {
  title      = "RDS Instance"
  icon       = "AmazonRDS"
  identifier = "rds-instance"

  properties = {
    string_props = {
      instance_identifier = { title = "Instance Identifier" }
      engine = { title = "Engine" }
      status = { title = "Status" }
      region = { title = "Region" }
      endpoint = { title = "Endpoint" }
    }
  }
}

# SQS Queue Blueprint
resource "port_blueprint" "sqs_queue" {
  title      = "SQS Queue"
  icon       = "AWS"
  identifier = "sqs-queue"

  properties = {
    string_props = {
      queue_url = { title = "Queue URL", required = true }
      queue_name = { title = "Queue Name", required = true }
      region = { title = "Region", required = true }
    }
    number_props = {
      visibility_timeout = { title = "Visibility Timeout" }
      message_retention_seconds = { title = "Message Retention Seconds" }
    }
    boolean_props = {
      fifo_queue = { title = "FIFO Queue" }
    }
    object_props = {
      tags = { title = "Tags" }
    }
  }
}
