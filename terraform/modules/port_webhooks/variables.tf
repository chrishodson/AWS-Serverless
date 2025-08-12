/**
 * Port.io Webhooks Module
 * variables.tf - Input variables
 */

variable "webhook_urls" {
  description = "Map of service types to webhook URLs (if pre-existing)"
  type        = map(string)
  default     = {}
}
