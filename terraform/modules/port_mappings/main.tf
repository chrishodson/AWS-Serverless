// Creates mapping rules on the Port integration for routing payloads to blueprints
variable "integration_id" {
  description = "Port integration (webhook) id"
  type        = string
}

variable "mappings" {
  description = "List of mapping strings in the form '<identifier>:<blueprint_id>'"
  type        = list(string)
  default     = []
}

resource "null_resource" "create_mappings" {
  triggers = {
    integration_id = var.integration_id
    mappings_sha   = join("|", var.mappings)
  }

  provisioner "local-exec" {
  # Use the repository utils directory (one level above the terraform directory)
  # path.root is the terraform root, so ../utils points to the repository utils/ folder
    command = <<-EOT
      python3 ${path.root}/../utils/create_port_mappings.py --integration-id ${var.integration_id} $(for m in ${join(" ", var.mappings)}; do echo --map $m; done)
    EOT
    # Do not set PORT_API_TOKEN here so the provisioner inherits the caller's environment
    # (this allows users to provide the token via their shell). Provide PORT_API_BASE too.
    environment = {
      PORT_API_BASE = var.port_api_base
    }
  }
}

variable "port_api_token" {
  type = string
}

variable "port_api_base" {
  type    = string
  default = "https://api.getport.io/v1"
}
