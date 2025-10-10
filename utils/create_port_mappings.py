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
    req = request.Request(base + path)
    req.add_header('Authorization', token)
    with request.urlopen(req) as resp:
        return json.load(resp)


def api_patch(base, path, token, payload):
    data = json.dumps(payload).encode('utf-8')
    req = request.Request(base + path, data=data, method='PATCH')
    req.add_header('Authorization', token)
    req.add_header('Content-Type', 'application/json')
    try:
        with request.urlopen(req) as resp:
            return json.load(resp)
    except error.HTTPError as e:
        body = e.read().decode('utf-8')
        print(f"HTTP {e.code}: {body}", file=sys.stderr)
        raise


def build_mapping(blueprint_identifier, mapping_name):
    # mapping_name is a simple identifier used for the mapped entity
    # Build a doc-style mapping accepted by the Port webhook API
    return {
        "blueprint": blueprint_identifier,
        "operation": "create",
        "filter": f'.body.blueprint == "{blueprint_identifier}"',
        "entity": {
            "identifier": f'"{mapping_name}"',
            "title": f'"Mapped {blueprint_identifier}"',
            "properties": {
                "raw": ".body.properties"
            }
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
