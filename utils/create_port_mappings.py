#!/usr/bin/env python3
"""Create or update Port webhook mappings idempotently.

This is a relocated copy of scripts/create_port_mappings.py moved into utils/.
"""

import argparse
import json
import os
import sys
from pathlib import Path
from urllib import request, error


def get_env_token():
    token = os.environ.get('PORT_API_TOKEN')
    if not token:
        print("ERROR: PORT_API_TOKEN env var must be set", file=sys.stderr)
        sys.exit(2)
    return token


def api_get(base, path, token):
    # Try the provided token first; if we receive 401, retry with 'Bearer ' prefix
    url = base + path
    req = request.Request(url)
    req.add_header('Authorization', token)
    try:
        with request.urlopen(req) as resp:
            return json.load(resp)
    except error.HTTPError as e:
        if e.code == 401 and not token.lower().startswith('bearer '):
            # Retry with Bearer prefix
            req2 = request.Request(url)
            req2.add_header('Authorization', f'Bearer {token}')
            try:
                with request.urlopen(req2) as resp:
                    return json.load(resp)
            except error.HTTPError:
                # Re-raise original for clarity
                raise
        raise


def api_patch(base, path, token, payload):
    data = json.dumps(payload).encode('utf-8')
    url = base + path
    req = request.Request(url, data=data, method='PATCH')
    req.add_header('Authorization', token)
    req.add_header('Content-Type', 'application/json')
    try:
        with request.urlopen(req) as resp:
            return json.load(resp)
    except error.HTTPError as e:
        # If unauthorized, retry with Bearer prefix if not already present
        if e.code == 401 and not token.lower().startswith('bearer '):
            req2 = request.Request(url, data=data, method='PATCH')
            req2.add_header('Authorization', f'Bearer {token}')
            req2.add_header('Content-Type', 'application/json')
            try:
                with request.urlopen(req2) as resp:
                    return json.load(resp)
            except error.HTTPError as e2:
                body = e2.read().decode('utf-8')
                print(f"HTTP {e2.code}: {body}", file=sys.stderr)
                raise
        body = e.read().decode('utf-8')
        print(f"HTTP {e.code}: {body}", file=sys.stderr)
        raise


def build_mapping(blueprint_identifier, mapping_name):
    # mapping_name is a simple identifier used for the mapped entity
    # Build a doc-style mapping accepted by the Port webhook API
    # Known property mappings per blueprint (align with terraform/module port_blueprints)
    per_blueprint_props = {
        's3-bucket': [
            'bucket_name', 'creation_date', 'region', 'acl', 'versioning_enabled'
        ],
        'ec2-instance': [
            'instance_state', 'instance_type', 'availability_zone', 'public_dns', 'private_dns'
        ],
        'rds-instance': [
            'instance_identifier', 'engine', 'status', 'endpoint'
        ],
        'sqs-queue': [
            'queue_name', 'queue_url', 'visibility_timeout', 'message_retention_seconds', 'fifo_queue', 'region'
        ],
    }

    props = {}
    keys = per_blueprint_props.get(blueprint_identifier, [])
    if keys:
        for k in keys:
            props[k] = f'.body.properties.{k}'
    else:
        # Fallback: include the entire properties object under a single key if blueprint unknown
        props = {'raw': '.body.properties'}

    return {
        "blueprint": blueprint_identifier,
        "operation": "create",
        "filter": f'.body.blueprint == "{blueprint_identifier}"',
        "entity": {
            "identifier": f'"{mapping_name}"',
            "title": f'"Mapped {blueprint_identifier}"',
            "properties": props
        }
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--integration-id', required=True)
    parser.add_argument('--map', action='append', default=[], help='blueprint_identifier:mapping_name')
    parser.add_argument('--port-api-base', default=os.environ.get('PORT_API_BASE', 'https://api.getport.io/v1'))
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    token = get_env_token()
    base = args.port_api_base.rstrip('/')
    integration_path = f"/webhooks/{args.integration_id}"

    # Build desired mappings
    desired = []
    for pair in args.map:
        if ':' not in pair:
            print(f"Invalid --map value: {pair}", file=sys.stderr)
            sys.exit(2)
        blueprint_id, mapping_name = pair.split(':', 1)
        desired.append(build_mapping(blueprint_id, mapping_name))

    # Fetch current integration object
    cur = api_get(base, integration_path, token)
    current_mappings = cur.get('integration', {}).get('mappings') or []

    # Compare normalized JSON
    if json.dumps(current_mappings, sort_keys=True) == json.dumps(desired, sort_keys=True):
        print('Mappings unchanged; nothing to do')
        return

    if args.dry_run:
        print('Would PATCH with:', json.dumps({'mappings': desired}, indent=2))
        return

    # Apply patch
    payload = {'mappings': desired}
    resp = api_patch(base, integration_path, token, payload)
    print('Patched integration; response keys:', list(resp.keys()))


if __name__ == '__main__':
    main()
