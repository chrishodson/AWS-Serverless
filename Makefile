# Makefile for AWS-Serverless Terraform deployment
# Provides setup checks, lambda packaging, and terraform workflow

SHELL := /bin/bash
TF_DIR := terraform
LAMBDA_DIR := sqs-handler
LAMBDA_ZIP := $(LAMBDA_DIR)/driver.zip
TFVARS := $(TF_DIR)/terraform.tfvars

# Colors
GREEN=\033[0;32m
RED=\033[0;31m
YELLOW=\033[1;33m
NC=\033[0m

.PHONY: all check tools tfvars lambda package init plan apply destroy clean help

all: check package init plan

help:
	@echo "Targets:"
	@echo "  check    - Verify required tools and env are available"
	@echo "  package  - Build Lambda zip at $(LAMBDA_ZIP)"
	@echo "  init     - Run terraform init in $(TF_DIR)"
	@echo "  plan     - Run terraform plan in $(TF_DIR)"
	@echo "  apply    - Run terraform apply in $(TF_DIR)"
	@echo "  destroy  - Run terraform destroy in $(TF_DIR)"
	@echo "  clean    - Remove built lambda zip"

check: tools tfvars
	@echo -e "$(GREEN)All checks passed.$(NC)"

# Check required CLI tools
tools:
	@command -v terraform >/dev/null 2>&1 || { echo -e "$(RED)Error: terraform not found on PATH.$(NC)"; exit 1; }
	@command -v zip >/dev/null 2>&1 || { echo -e "$(RED)Error: zip not found on PATH.$(NC)"; exit 1; }
	@echo -e "$(GREEN)Tools OK$(NC)"

# Check required variables file exists and required keys are set
# Basic grep checks to ensure keys exist and non-placeholder values are provided
REQUIRED_KEYS := aws_region port_client_id port_client_secret webhook_secret

tfvars:
	@[ -f "$(TFVARS)" ] || { echo -e "$(RED)Error: $(TFVARS) not found. Copy terraform.tfvars.example -> terraform.tfvars and edit values.$(NC)"; exit 1; }
	@missing=0; \
	for k in $(REQUIRED_KEYS); do \
		val=$$(awk -v k="$$k" 'match($$0, "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*\"([^\"]*)\"", a){print a[1]}' "$(TFVARS)"); \
		if [ -z "$$val" ]; then \
			echo -e "$(YELLOW)Warning: Key '$$k' missing in $(TFVARS).$(NC)"; \
			missing=1; \
		elif [[ "$$val" =~ ^YOUR_ ]]; then \
			echo -e "$(YELLOW)Warning: Key '$$k' looks like a placeholder in $(TFVARS).$(NC)"; \
		fi; \
	done; \
	[ $$missing -eq 0 ] || exit 1; \
	echo -e "$(GREEN)tfvars present$(NC)"

# Build lambda zip (expects driver.py in $(LAMBDA_DIR))
package: $(LAMBDA_ZIP)

$(LAMBDA_ZIP):
	@mkdir -p $(LAMBDA_DIR)
	@if [ ! -f "$(LAMBDA_DIR)/driver.py" ]; then \
		echo -e "$(YELLOW)Note: $(LAMBDA_DIR)/driver.py not found. Creating a minimal handler stub.$(NC)"; \
		echo 'def lambda_handler(event, context):\n    return {"statusCode": 200, "body": "ok"}' > $(LAMBDA_DIR)/driver.py; \
	fi
	@cd $(LAMBDA_DIR) && zip -q -r aws_port_handler.zip driver.py
	@echo -e "$(GREEN)Built $(LAMBDA_ZIP)$(NC)"

init:
	@cd $(TF_DIR) && terraform init

plan:
	@cd $(TF_DIR) && terraform plan

apply:
	@cd $(TF_DIR) && terraform apply -auto-approve

destroy:
	@cd $(TF_DIR) && terraform destroy -auto-approve

clean:
	@rm -f $(LAMBDA_ZIP)
	@echo -e "$(GREEN)Cleaned$(NC)"
