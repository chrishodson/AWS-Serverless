/**
 * Port.io Blueprints Module
 * main.tf - Creates blueprints for AWS resources
 */

# EC2 Instance Blueprint
resource "port_blueprint" "ec2_instance" {
  title      = "EC2 Instance"
  icon       = "EC2"
  identifier = "ec2-instance"

  properties = {
    string_props = {
      instance_id = { title = "Instance ID", required = true }
      instance_type = { title = "Instance Type", required = true }
      state = {
        title = "State"
        enum  = ["pending", "running", "shutting-down", "terminated", "stopping", "stopped"]
        enum_colors = {
          pending         = "yellow"
          running         = "green"
          "shutting-down" = "pink"
          stopped         = "purple"
          stopping        = "orange"
          terminated      = "red"
        }
        required = true
      }
      region = { title = "Region" }
      availability_zone = { title = "Availability Zone" }
      launch_time = { title = "Launch Time", format = "date-time" }
      image = { title = "Image ID" }
      key_name = { title = "Key Name" }
    }
    object_props = {
      tags = { title = "Tags" }
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
      db_instance_identifier = { title = "DB Instance Identifier", required = true }
      engine = { title = "Engine", required = true }
      engine_version = { title = "Engine Version" }
      status = { title = "Status", required = true }
      instance_class = { title = "Instance Class" }
      region = { title = "Region", required = true }
      availability_zone = { title = "Availability Zone" }
      endpoint = { title = "Endpoint", required = true }
    }
    object_props = {
      tags = { title = "Tags" }
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
