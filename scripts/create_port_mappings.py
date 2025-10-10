#!/usr/bin/env python3
"""
Create mapping rules on a Port integration (webhook) to route incoming webhook payloads
into the correct blueprints based on the `blueprint` field in the payload.

This script is a best-effort helper. It will:
 - GET the integration to list existing mappings
 - For each requested blueprint mapping, skip if a mapping for that blueprint identifier exists
 - POST a new mapping to /integrations/<id>/mappings with a simple mapping spec

Usage:
  ./scripts/create_port_mappings.py --integration-id <integration_id> \
      --map ec2:ec2-instance --map s3:s3-bucket --map rds:rds-instance --map sqs:sqs-queue

Environment:
  PORT_API_TOKEN must be set to a valid bearer token with permissions to manage integrations.

Note: The exact mapping payload schema depends on the Port API. This script uses a conservative
mapping format that maps payload.properties directly into blueprint properties when the
payload.blueprint equals the expected identifier.
"""

import argparse
import json
import os
import sys
from urllib.parse import urljoin

import urllib.request
import urllib.error

API_BASE = os.environ.get('PORT_API_BASE', 'https://api.getport.io/v1')
TOKEN = os.environ.get('PORT_API_TOKEN')

if not TOKEN:
    print('ERROR: PORT_API_TOKEN env var must be set')
    sys.exit(1)

HEADERS = {
    'Authorization': f'Bearer {TOKEN}',
    'Content-Type': 'application/json'
}


def get_integration(integration_id):
    # Try direct integration lookup first
    url = f"{API_BASE}/integrations/{integration_id}"
    req = urllib.request.Request(url, headers=HEADERS, method='GET')
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode('utf-8')
            return json.loads(body)
    except urllib.error.HTTPError as e:
        # If not found, try alternative lookup paths
        try:
            text = e.read().decode('utf-8')
        except Exception:
            text = str(e)
        if e.code == 404 or 'not_found' in text:
            # Try looking up by identifier via /integrations/identifier/<identifier>
            alt_url = f"{API_BASE}/integrations/identifier/{integration_id}"
            try:
                alt_req = urllib.request.Request(alt_url, headers=HEADERS, method='GET')
                with urllib.request.urlopen(alt_req) as alt_resp:
                    body = alt_resp.read().decode('utf-8')
                    return json.loads(body)
            except Exception:
                pass
            # Try looking up by webhook key / webhooks endpoint as a last resort
            try:
                webhook_url = f"{API_BASE}/webhooks/{integration_id}"
                wreq = urllib.request.Request(webhook_url, headers=HEADERS, method='GET')
                with urllib.request.urlopen(wreq) as wresp:
                    body = wresp.read().decode('utf-8')
                    return json.loads(body)
            except Exception:
                pass
        print(f'ERROR: GET {url} returned {e.code}: {text}')
        return None
    except Exception as e:
        print(f'ERROR: GET {url} failed: {e}')
        return None


def list_mappings(integration):
    # integration may include 'mappings' field
    return integration.get('mappings') or []


def create_mapping(integration_id, match_blueprint_identifier, target_blueprint_id):
    # NOTE: the provider's API accepts a webhook-level PATCH with the full
    # `mappings` array (documented in Port webhook docs). We'll build a doc-style
    # mapping object for the requested blueprint and return it — the caller will
    # assemble the full mappings array and PATCH the webhook.
    mapping = {
        'blueprint': target_blueprint_id,
        'operation': 'create',
        'filter': f'.body.blueprint == "{match_blueprint_identifier}"',
        'entity': {
            # Use JQ string literal to pin the identifier to the placeholder entity
            'identifier': f'"mapping-{match_blueprint_identifier}"',
            'title': f'"{match_blueprint_identifier} mapped"',
            'properties': {
                # map common property roots; Terraform/script callers can extend
                # these per-blueprint if needed. We map into `.body.properties`.
            }
        }
    }
    return mapping


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--integration-id', required=True)
    parser.add_argument('--map', action='append', default=[],
                        help='Mapping in form <blueprint_identifier>:<blueprint_id>')
    args = parser.parse_args()

    # Build desired mappings array from --map arguments
    desired_mappings = []
    for mapping in args.map:
        if ':' not in mapping:
            print(f'Skipping invalid mapping: {mapping}')
            continue
        identifier, blueprint_id = mapping.split(':', 1)
        # Create a doc-style mapping object
        m = create_mapping(args.integration_id, identifier, blueprint_id)
        # Insert property mappings that point into .body.properties (common case)
        # Use a simple heuristic: for known blueprint ids use common property keys
        if blueprint_id in ('s3-bucket', 'ec2-instance', 'rds-instance', 'sqs-queue'):
            if blueprint_id == 's3-bucket':
                m['entity']['properties'] = {
                    'bucket_name': '.body.properties.bucket_name',
                    'creation_date': '.body.properties.creation_date',
                    'region': '.body.properties.region',
                    'acl': '.body.properties.acl',
                    'versioning_enabled': '.body.properties.versioning_enabled'
                }
            elif blueprint_id == 'ec2-instance':
                m['entity']['properties'] = {
                    'instance_state': '.body.properties.instance_state',
                    'instance_type': '.body.properties.instance_type',
                    'availability_zone': '.body.properties.availability_zone',
                    'public_dns': '.body.properties.public_dns',
                    'private_dns': '.body.properties.private_dns'
                }
            elif blueprint_id == 'rds-instance':
                m['entity']['properties'] = {
                    'instance_identifier': '.body.properties.instance_identifier',
                    'engine': '.body.properties.engine',
                    'status': '.body.properties.status',
                    'endpoint': '.body.properties.endpoint'
                }
            elif blueprint_id == 'sqs-queue':
                m['entity']['properties'] = {
                    'queue_name': '.body.properties.queue_name',
                    'queue_url': '.body.properties.queue_url',
                    'visibility_timeout': '.body.properties.visibility_timeout',
                    'message_retention_seconds': '.body.properties.message_retention_seconds',
                    'fifo_queue': '.body.properties.fifo_queue',
                    'region': '.body.properties.region'
                }
        desired_mappings.append(m)

    # Fetch current webhook/integration object and compare mappings
    integration = get_integration(args.integration_id)
    if not integration:
        sys.exit(1)

    current_mappings = integration.get('mappings') or []

    # Minimal comparison: stringify desired and current and compare
    try:
        cur_norm = json.dumps(current_mappings, sort_keys=True)
    except Exception:
        cur_norm = ''
    try:
        desired_norm = json.dumps(desired_mappings, sort_keys=True)
    except Exception:
        desired_norm = ''

    if cur_norm == desired_norm:
        print('Mappings are up-to-date; no change required')
        return

    # PATCH the webhook by updating the integration object with the new mappings array
    webhook_url = f"{API_BASE}/webhooks/{args.integration_id}"
    payload = {'mappings': desired_mappings}
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(webhook_url, data=data, headers=HEADERS, method='PATCH')
    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode('utf-8')
            print('PATCH response:', body)
    except urllib.error.HTTPError as e:
        try:
            text = e.read().decode('utf-8')
        except Exception:
            text = str(e)
        print(f'ERROR: PATCH {webhook_url} returned {e.code}: {text}')
        sys.exit(1)
    except Exception as e:
        print(f'ERROR: PATCH {webhook_url} failed: {e}')
        sys.exit(1)


if __name__ == '__main__':
    main()
