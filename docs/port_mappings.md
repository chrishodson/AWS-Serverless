# Port webhook mappings (AWS → Port blueprints)

This document explains the mapping payload shape that the Port webhook accepts, how this repository implements idempotent mapping creation, how to run the mapping step locally, and verification/troubleshooting tips.

## Summary

- The project uses a single webhook `aws_ingest` to ingest AWS events.
- Terraform creates the webhook and blueprints; mapping creation is performed by a small idempotent helper script to PATCH the webhook's `mappings` array because the provider does not expose mappings as a native resource.
- Mapping script location: `utils/create_port_mappings.py` (called by `terraform/modules/port_mappings/main.tf`).

## Accepted mapping payload shape

The Port webhook expects a document-style `mappings` array on the webhook integration. Each mapping is an object with fields similar to:

- `blueprint` — the target blueprint identifier (string)
- `operation` — e.g. `create`
- `filter` — an expression evaluated against `body` (e.g. `.body.blueprint == "s3-bucket"`)
- `entity` — an object describing the created entity, with fields like `identifier`, `title`, and `properties` (the properties can be expressions into `.body.properties.*`)

Example mapping (excerpt):

```json
{
  "blueprint": "s3-bucket",
  "operation": "create",
  "filter": ".body.blueprint == \"s3-bucket\"",
  "entity": {
    "identifier": "\"mapping-s3-bucket\"",
    "title": "\"S3 mapped\"",
    "properties": {
      "bucket_name": ".body.properties.bucket_name",
      "creation_date": ".body.properties.creation_date",
      "region": ".body.properties.region"
    }
  }
}
```

The actual `terraform/aws_mapping_applied.json` in the repo contains the applied mappings used for this project.

## How this repo applies mappings (contract)

- Input: list of `--map` pairs passed to the script of the form `blueprint_identifier:mapping_entity_identifier`.
- Action: `utils/create_port_mappings.py` builds the `mappings` array (document style), GETs the existing webhook integration, compares mappings (sorted JSON) and PATCHes `/v1/webhooks/<identifier>` only when they differ.
- Output: updated webhook integration object returned by the API.
- Error modes: missing/invalid `PORT_API_TOKEN` (script exits), HTTP errors from Port API, malformed mapping pairs.

## Files changed / relevant paths

- `utils/create_port_mappings.py` — idempotent mapping helper script (must be run where it can access `PORT_API_TOKEN` env var)
- `utils/parse_port_blueprints.py` — helper that extracts blueprint identifiers and properties from `terraform/modules/port_blueprints/main.tf`
- `terraform/modules/port_mappings/main.tf` — Terraform module that uses a `null_resource` + `local-exec` to run the mapping script; it now references `../utils/create_port_mappings.py`.
- `terraform/aws_mapping_applied.json` — snapshot of the applied webhook integration showing the `mappings` array (for review).
- `terraform/README.md` — brief instructions updated to mention `utils/` and mapping step.

## How to run locally

1. Ensure you have a valid Port API token in `PORT_API_TOKEN` (do NOT prefix with `Bearer `). Also set `PORT_API_BASE` if you use a non-standard API endpoint.

2. Dry run (shows what would be PATCHed):

```bash
PORT_API_TOKEN="<token>" python3 utils/create_port_mappings.py --integration-id aws_ingest --map s3-bucket:mapping-s3-bucket --dry-run
```

3. Apply mappings:

```bash
PORT_API_TOKEN="<token>" python3 utils/create_port_mappings.py --integration-id aws_ingest --map s3-bucket:mapping-s3-bucket --map ec2-instance:mapping-ec2-instance
```

4. Terraform provisioning: the module `terraform/modules/port_mappings` calls the script during a `null_resource` provisioner. Ensure `PORT_API_TOKEN` is exported in the shell where you run `terraform apply`, or call `terraform apply` from an environment that has the token set.

## Verification steps

1. Check webhook mappings were applied:

```bash
PORT_API_TOKEN="<token>" curl -s -H "Authorization: $PORT_API_TOKEN" "$PORT_API_BASE/v1/webhooks/aws_ingest" | jq .
```

2. Send a sample payload to the webhook and verify a mapped entity is created in Port (or check webhook logs):

```bash
# Create a small sample event JSON matching the Lambda shape and POST to the ingest URL
curl -s -X POST -H "Content-Type: application/json" -d '{"blueprint":"s3-bucket","properties":{"bucket_name":"my-bucket"}}' https://ingest.getport.io/<webhook_key>
```

3. Alternatively, trigger the Lambda or place an event on SQS (if deployed) and confirm entities appear in Port.

## Troubleshooting

- 422 from Port when PATCHing mappings: confirm mapping object fields match the documented shape (blueprint, operation, filter, entity).
- Authentication issues: ensure `PORT_API_TOKEN` is present and not prefixed with `Bearer ` when calling our helper script.
- If Terraform `null_resource` fails to run the script during provision, verify the working directory and that `path.root` resolves to the repo root (module uses `${path.root}/../utils/...`).

## Next steps / follow-ups

- Consider upstreaming a native Terraform resource for webhook mappings to avoid the `null_resource` local-exec pattern.
- Move the Lambda code out of inline `ZipFile` into a separate deployment package for easier testing and maintenance.
- Add automated unit tests for `utils/parse_port_blueprints.py` and a small integration test that exercises the mapping script (dry-run + live only when token present).

---
If you'd like, I can add a small sample payload file and a short test script that POSTS to the webhook for a one-click smoke test. Would you like that? 
