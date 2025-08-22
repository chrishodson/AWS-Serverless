/**
 * Port.io Blueprints Module
 * main.tf - Creates blueprints for AWS resources
 */

# EC2 Instance Blueprint
resource "port_blueprint" "ec2_instance" {
  title      = "EC2 Instance"
  icon       = "EC2"
  identifier = "ec2-instance"
  
  schema = {
    properties = {
      instance_id = {
        title = "Instance ID"
        type  = "string"
      }
      instance_type = {
        title = "Instance Type"
        type  = "string"
      }
      state = {
        title = "State"
        type  = "string"
        enum  = ["pending", "running", "shutting-down", "terminated", "stopping", "stopped"]
        enumColors = {
          pending        = "yellow"
          running        = "green"
          "shutting-down" = "pink"
          stopped        = "purple"
          stopping       = "orange"
          terminated     = "red"
        }
      }
      region = {
        title = "Region"
        type  = "string"
      }
      availability_zone = {
        title = "Availability Zone"
        type  = "string"
      }
      tags = {
        title = "Tags"
        type  = "object"
      }
      launch_time = {
        title = "Launch Time"
        type  = "string"
        format = "date-time"
      }
      image = {
        title = "Image ID"
        type  = "string"
      }
      key_name = {
        title = "Key Name"
        type  = "string"
      }
    }
    required = ["instance_id", "instance_type", "state"]
  }

  relations = {
    account = {
      title   = "Account"
      target  = "awsAccount"
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
  
  schema = {
    properties = {
      bucket_name = {
        title = "Bucket Name"
        type  = "string"
      }
      creation_date = {
        title = "Creation Date"
        type  = "string"
        format = "date-time"
      }
      region = {
        title = "Region"
        type  = "string"
      }
      versioning_enabled = {
        title = "Versioning Enabled"
        type  = "boolean"
      }
      acl = {
        title = "ACL"
        type  = "string"
      }
      tags = {
        title = "Tags"
        type  = "object"
      }
    }
    required = ["bucket_name", "creation_date", "region"]
  }
}

# RDS Instance Blueprint
resource "port_blueprint" "rds_instance" {
  title      = "RDS Instance"
  icon       = "AmazonRDS"
  identifier = "rds-instance"
  
  schema = {
    properties = {
      db_instance_identifier = {
        title = "DB Instance Identifier"
        type  = "string"
      }
      engine = {
        title = "Engine"
        type  = "string"
      }
      engine_version = {
        title = "Engine Version"
        type  = "string"
      }
      status = {
        title = "Status"
        type  = "string"
      }
      instance_class = {
        title = "Instance Class"
        type  = "string"
      }
      region = {
        title = "Region"
        type  = "string"
      }
      availability_zone = {
        title = "Availability Zone"
        type  = "string"
      }
      endpoint = {
        title = "Endpoint"
        type  = "string"
      }
      tags = {
        title = "Tags"
        type  = "object"
      }
    }
    required = ["db_instance_identifier", "engine", "status", "region", "endpoint"]
  }
}

# SQS Queue Blueprint
resource "port_blueprint" "sqs_queue" {
  title      = "SQS Queue"
  icon       = "AWS"
  identifier = "sqs-queue"
  
  schema = {
    properties = {
      queue_url = {
        title = "Queue URL"
        type  = "string"
      }
      queue_name = {
        title = "Queue Name"
        type  = "string"
      }
      region = {
        title = "Region"
        type  = "string"
      }
      visibility_timeout = {
        title = "Visibility Timeout"
        type  = "number"
      }
      message_retention_seconds = {
        title = "Message Retention Seconds"
        type  = "number"
      }
      fifo_queue = {
        title = "FIFO Queue"
        type  = "boolean"
      }
      tags = {
        title = "Tags"
        type  = "object"
      }
    }
    required = ["queue_url", "queue_name", "region"]
  }
}
