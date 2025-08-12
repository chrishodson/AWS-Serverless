/**
 * AWS Serverless Integration with Port.io
 * versions.tf - Version constraints
 */

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    port = {
      source  = "port-labs/port"
      version = ">= 0.1.0"
    }
  }
}
