# AWS-Serverless
Event-driven integration that routes AWS events into Port (getport.io) using serverless primitives.

This repository contains Terraform and CloudFormation artefacts, helper scripts, and a Lambda handler that together implement an AWS → Port ingestion pipeline.

High-level responsibilities

Within Port
- Create a single ingest webhook (`aws_ingest`) that receives routed events
- Create blueprints required for AWS resource types
- Apply mapping rules on the single webhook so each incoming event is translated into the correct blueprint/entity

Within AWS
- Create/validate an SQS queue
- Create an EventBridge rule that captures AWS events and forwards them to SQS
- Deploy a Lambda that reads SQS and forwards enriched events to the single Port webhook (`aws_ingest`)

Supported AWS resource types
- EC2 instances (state changes)
- S3 buckets (events)
- RDS instances (events)
- SQS queues (events)

Shortfalls compared to an Ocean integration
- No Kubernetes inspection support
- Single-account by default (no multi-account orchestration provided)

Design notes / decisions
- Single webhook: this project consolidates events into `aws_ingest` and uses Port-side mapping rules (document-style mappings) to route to blueprints, rather than creating a webhook per AWS type.
- Mapping automation: because the Terraform Port provider used here does not model webhook mappings, a small idempotent helper script (`utils/create_port_mappings.py`) builds and applies the `mappings` array via the Port API. Terraform triggers this script from `terraform/modules/port_mappings` using a `null_resource` + `local-exec`.
- CloudFormation vs Terraform: CloudFormation (see `terraform/AWS.yml`) is used in this branch to own certain AWS resources (inline Lambda, roles). Terraform is still used for blueprint & Port provisioning. See `terraform/README.md` and `docs/port_mappings.md` for details.

---

## Quickstart

Prerequisites
- Terraform >= 1.0.0 on PATH
- zip on PATH (if building a deployment package)
- AWS credentials configured (CLI/profile or env vars)
- `PORT_API_TOKEN` — a Port API token (export this in your shell when you want Terraform to apply mappings). Do NOT prefix this token with `Bearer `.

1) Configure Terraform variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your real values
```

2) (Optional) Build Lambda zip

The repo contains an inline Lambda inside `terraform/AWS.yml` used by CloudFormation in this branch. If you prefer to deploy a zip with Terraform instead, run:

```bash
make package
```

The artifact will be created at `lambda/aws_port_handler.zip` and Terraform may reference it depending on how you deploy.

3) Export Port token (if you want Terraform to run mapping creation)

```bash
export PORT_API_TOKEN="<your-token>"
```

4) Initialize and apply

```bash
make init
make plan
make apply
```

Notes
- You can also run the mapping script manually: `python3 utils/create_port_mappings.py --webhook-id aws_ingest --map s3Bucket:mapping-s3-bucket --dry-run` or run the interactive chooser:

```
export PORT_API_TOKEN="<your-token>"
python3 utils/create_port_mappings.py --choose-webhook --dry-run
```

See `utils/README.md` for more details. (See `docs/port_mappings.md` for full examples.)
- If you prefer CloudFormation for the Lambda + SQS stack, the file `terraform/AWS.yml` contains an embedded inline Lambda and CloudFormation resources.

Other Make targets
- `make check`   – validates required tools and tfvars presence
- `make destroy` – tears down the stack
- `make clean`   – removes the built lambda zip

---

## Mappings (Port webhook)

See `docs/port_mappings.md` for the accepted mapping payload shape, examples, and how the idempotent mapping script works. A sample of the applied mapping is saved in `terraform/aws_mapping_applied.json`.

## Data flow

The pipeline is: EventBridge -> SQS -> Lambda -> Port (single ingest webhook). The per-type routing inside Port is handled by mapping rules on the single `aws_ingest` webhook (the diagram labels are logical per-type mappings rather than separate webhook endpoints).

```mermaid
flowchart LR
  subgraph AWS
    EC2[EC2 Instance State Changes]
    S3[S3 Events]
    RDS[RDS Events]
    SQSRes[SQS Events]
    EB[(EventBridge Bus)]
    Q[SQS Queue]
  end

  subgraph Serverless
    L[Lambda: port-aws-event-processor]
  end

  subgraph Port
    PWH_LOGICAL[Port Webhook - aws_ingest (logical per-type mappings)]
  end

  EC2 -->|Rule: EC2 state-change| EB
  S3 --> EB
  RDS --> EB
  SQSRes --> EB
  EB -->|Target: SQS| Q
  Q -->|Trigger| L
  L -->|POST to| PWH_LOGICAL
```

---

## Troubleshooting and tips

- Authentication issues: ensure `PORT_API_TOKEN` is exported (do not prefix with `Bearer `). The mapping script and verification curl commands assume this token is present in the environment.
- Dry-run first: run the mapping script with `--dry-run` to see the payload before it is PATCHed.
- If Terraform `null_resource` doesn't run the script, check that `${path.root}/../utils/create_port_mappings.py` resolves to the script location (module working directory) and that the environment variable is present where `terraform apply` runs.

---

If you'd like, I can:
- Add a one-shot `scripts/smoke_test.sh` that posts a sample event to the ingest URL (dry-run vs live), or
- Add a small integration test harness under `tests/` that exercises the mapping script (dry-run) and validates JSON shape.

Which would you prefer?
