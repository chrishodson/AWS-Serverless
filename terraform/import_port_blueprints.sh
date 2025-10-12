#!/usr/bin/env bash
# Import existing Port blueprints into Terraform state for the port_blueprints module
# Usage: ./import_port_blueprints.sh [path/to/terraform.tfvars]

set -euo pipefail
TFDIR=$(pwd)
TFVARS=${1:-terraform.tfvars}
MODULE_FILE="${TFDIR}/modules/port_blueprints/main.tf"
PORT_API_BASE="https://api.getport.io/v1"

# Helper: read value from tfvars (simple grep, supports quoted values)
get_tfvar(){
  local key="$1" file="$2"
  if [ -f "$file" ]; then
    grep -E "^${key}\s*=" "$file" | sed -E "s/^${key}\s*=\s*\"?(.*)\"?$/\1/" | tr -d '\r' || true
  fi
}

# Prefer a bearer token for the Port API. You can set PORT_API_TOKEN env var.
# As a fallback we still read client id/secret from tfvars for user convenience,
# but note many Port installations require an API token (bearer) rather than basic auth.
PORT_API_TOKEN=${PORT_API_TOKEN:-}
PORT_CLIENT_ID=${PORT_CLIENT_ID:-$(get_tfvar port_client_id "$TFVARS")}
PORT_CLIENT_SECRET=${PORT_CLIENT_SECRET:-$(get_tfvar port_client_secret "$TFVARS")}

if [ -z "$PORT_API_TOKEN" ] && { [ -z "$PORT_CLIENT_ID" ] || [ -z "$PORT_CLIENT_SECRET" ]; }; then
  echo "ERROR: No Port API credentials found. Provide PORT_API_TOKEN env var (preferred) or port_client_id/port_client_secret in ${TFVARS}."
  echo "If your Port instance requires a bearer token, set: export PORT_API_TOKEN=\"<token>\""
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed."
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform cli is required but not installed."
  exit 1
fi

if [ ! -f "$MODULE_FILE" ]; then
  echo "ERROR: Terraform module file not found: $MODULE_FILE"
  exit 1
fi

echo "Parsing blueprints defined in $MODULE_FILE..."
# Extract resource names and identifier values
# Looks for lines: resource "port_blueprint" "<name>" { ... identifier = "<id>"
mapfile -t pairs < <(awk '/resource "port_blueprint"/ { name=$3; gsub(/"/,"",name); inres=1 } inres==1 && /identifier/ { gsub(/.*identifier[[:space:]]*=[[:space:]]*/,"",$0); gsub(/[",]/,"",$0); id=$0; gsub(/^[ \t]+|[ \t]+$/,"",id); print name":"id; inres=0 }' "$MODULE_FILE") || true

if [ ${#pairs[@]} -eq 0 ]; then
  echo "No port_blueprint resources found in $MODULE_FILE"
  exit 0
fi

echo "Found ${#pairs[@]} blueprint resource(s):"
for p in "${pairs[@]}"; do
  name=${p%%:*}
  id=${p#*:}
  echo " - tf resource name: $name -> identifier: $id"
done

# Query Port API blueprints
echo "Querying Port API for blueprints..."
if [ -n "$PORT_API_TOKEN" ]; then
  BLUEPRINTS_JSON=$(curl -s -H "Authorization: Bearer ${PORT_API_TOKEN}" "${PORT_API_BASE}/blueprints" || true)
else
  # Try basic auth as a fallback (may fail if Port requires bearer tokens)
  BLUEPRINTS_JSON=$(curl -s -u "${PORT_CLIENT_ID}:${PORT_CLIENT_SECRET}" "${PORT_API_BASE}/blueprints" || true)
fi
if [ -z "$BLUEPRINTS_JSON" ]; then
  echo "ERROR: empty response from Port API. Check credentials and network access."
  exit 1
fi

# Normalise: expect JSON array of blueprint objects
if ! echo "$BLUEPRINTS_JSON" | jq -e . >/dev/null 2>&1; then
  echo "ERROR: Port API returned invalid JSON. Response:\n$BLUEPRINTS_JSON"
  exit 1
fi

# Build a lookup of identifier -> id
declare -A lookup

# Normalize the JSON to an array of blueprints. The API may return either
# a top-level array or an object with a `blueprints` field.
if echo "$BLUEPRINTS_JSON" | jq -e 'type == "array"' >/dev/null 2>&1; then
  BP_ITEMS=$(echo "$BLUEPRINTS_JSON" | jq -c '.[]')
elif echo "$BLUEPRINTS_JSON" | jq -e '.blueprints? | type == "array"' >/dev/null 2>&1; then
  BP_ITEMS=$(echo "$BLUEPRINTS_JSON" | jq -c '.blueprints[]')
else
  echo "ERROR: unexpected blueprints response shape from API"
  echo "$BLUEPRINTS_JSON" | jq . || true
  exit 1
fi

while IFS=$'\n' read -r line; do
  bp_id=$(echo "$line" | jq -r '.id // empty')
  bp_identifier=$(echo "$line" | jq -r '.identifier // .name // empty')
  # If the API does not return an 'id' field, fall back to using the identifier
  if [ -z "$bp_id" ] && [ -n "$bp_identifier" ]; then
    bp_id="$bp_identifier"
  fi
  if [ -n "$bp_id" ] && [ -n "$bp_identifier" ]; then
    lookup["$bp_identifier"]="$bp_id"
  fi
done < <(echo "$BP_ITEMS")

# Ensure Terraform is initialized
echo "Running terraform init (if needed)"
terraform init -input=false >/dev/null

# Import loop
echo
echo "Starting imports..."
for p in "${pairs[@]}"; do
  name=${p%%:*}
  identifier=${p#*:}
  addr="module.port_blueprints.port_blueprint.${name}"

  # Skip if already in state
  if terraform state list | grep -q "^${addr}$"; then
    echo "- ${addr} already exists in state; skipping"
    continue
  fi

  remote_id="${lookup[$identifier]:-}"
  if [ -z "$remote_id" ]; then
    echo "- WARNING: no blueprint with identifier '${identifier}' found in Port API; skipping ${addr}"
    continue
  fi

  echo "- Importing ${addr} -> ${remote_id}"
  if terraform import "$addr" "$remote_id"; then
    echo "  Imported ${addr}"
  else
    echo "  ERROR: import failed for ${addr}. You may need to adjust the remote id format."
  fi
done

echo
echo "Import complete. Run 'terraform plan -var-file=${TFVARS}' to review changes."
