#!/usr/bin/env python3
"""Create or update Port webhook mappings idempotently.
"""

import argparse
import json
from typing import Any, Dict, Optional
import os
import sys
from pathlib import Path
from urllib import request, error
try:
    import yaml
except Exception:  # pragma: no cover - optional dependency
    yaml = None


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


def _normalize_expr(expr: Any) -> Any:
    """Convert a YAML expression into a webhook-expression suitable for the mappings.

    Heuristic: if expression is a string starting with '.' treat it as coming from the
    webhook body and prefix with '.body'. Otherwise leave as-is.
    """
    if not isinstance(expr, str):
        return expr
    expr = expr.strip()
    if expr.startswith('.'):
        return f'.body{expr}'
    return expr


def build_mapping(blueprint_identifier: str, mapping_name: str,
                  identifier_expr: Optional[str] = None,
                  title_expr: Optional[str] = None,
                  properties: Optional[Dict[str, Any]] = None,
                  relations: Optional[Dict[str, Any]] = None):
    """Build a mapping object from provided pieces.

    `identifier_expr` and `title_expr` should be expressions (e.g. .Properties.Arn) or
    literal strings. `properties` and `relations` are dicts mapping target keys to
    expression strings from the port-app-config.yml.
    """
    props: Dict[str, Any] = {}
    if properties:
        for k, v in properties.items():
            props[k] = _normalize_expr(v)
    else:
        props = {'raw': '.body.properties'}

    rels: Dict[str, Any] = {}
    if relations:
        for k, v in relations.items():
            rels[k] = _normalize_expr(v)

    identifier_field = _normalize_expr(identifier_expr) if identifier_expr else f'"{mapping_name}"'
    title_field = _normalize_expr(title_expr) if title_expr else f'"Mapped {blueprint_identifier}"'

    entity = {
        "identifier": identifier_field,
        "title": title_field,
        "properties": props,
    }
    if rels:
        entity['relations'] = rels

    return {
        "blueprint": blueprint_identifier,
        "operation": "create",
        "filter": f'.body.blueprint == "{blueprint_identifier}"',
        "entity": entity
    }


def list_webhooks(base: str, token: str):
    """Return a list of webhook dicts from the Port API.

    The Port API may return the list under a few possible keys; handle common shapes.
    """
    resp = api_get(base, '/webhooks', token)
    # resp may be a dict with keys like 'webhooks', 'items', 'data' or a list directly
    if isinstance(resp, list):
        return resp
    if isinstance(resp, dict):
        for k in ('webhooks', 'items', 'data'):
            v = resp.get(k)
            if isinstance(v, list):
                return v
        # Some APIs return {"integration": [...]} or similar; try to heuristically find a list
        for v in resp.values():
            if isinstance(v, list):
                return v
    # Fallback: return empty list
    return []


def main():
    parser = argparse.ArgumentParser()
    # Require an explicit choice: either provide --webhook-id or run interactive chooser
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--webhook-id', dest='webhook_id', required=False,
                       help='ID of the Port webhook to target')
    group.add_argument('--choose-webhook', dest='choose_webhook', action='store_true',
                       help='Interactively choose a webhook from your Port account (requires PORT_API_TOKEN)')
    parser.add_argument('--map', action='append', default=[], help='blueprint_identifier:mapping_name')
    parser.add_argument('--debug', action='store_true', help='Enable debug output (prints raw webhook objects)')
    parser.add_argument('--port-api-base', default=os.environ.get('PORT_API_BASE', 'https://api.getport.io/v1'))
    parser.add_argument('--blueprints-url', default='https://raw.githubusercontent.com/port-labs/ocean/main/integrations/aws-v3/.port/resources/blueprints.json',
                        help='URL to blueprints.json (raw)')
    parser.add_argument('--config-url', default='https://raw.githubusercontent.com/port-labs/ocean/main/integrations/aws-v3/.port/resources/port-app-config.yml',
                        help='URL to port-app-config.yml (raw)')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    base = args.port_api_base.rstrip('/')

    # Only require a Port API token when we need to call the Port API:
    # - interactive chooser needs it, and
    # - non-dry-run runs (we fetch current integration and PATCH).
    token = None
    if args.choose_webhook or not args.dry_run:
        token = get_env_token()

    webhook_id = None
    if args.choose_webhook:
        # Fetch list and prompt the user
        try:
            whs = list_webhooks(base, token)
        except Exception as e:
            print(f"ERROR: could not list webhooks: {e}", file=sys.stderr)
            sys.exit(2)

        if not whs:
            print('No webhooks found in your account.', file=sys.stderr)
            sys.exit(2)

        # Build display list
        choices = []
        for w in whs:
            # Prefer the logical `identifier` (human-facing unique key), then internal id fields,
            # then other common keys. This makes CLI usage friendly while still falling back
            # to a unique value if identifier is not present.
            wid = (
                w.get('identifier') or w.get('_id') or w.get('webhookKey') or w.get('webhookId')
                or w.get('id') or w.get('integrationId') or w.get('name')
            )
            title = w.get('title') or w.get('name') or wid
            choices.append({'id': wid, 'title': title, 'raw': w})

        print('Select a webhook:')
        for i, c in enumerate(choices, start=1):
            print(f"{i}) {c['title']} ({c['id']})")
            if args.debug:
                try:
                    # Print the raw webhook object for inspection when debug is enabled
                    print(json.dumps(c['raw'], indent=2))
                except Exception:
                    # Fallback to string representation if JSON serialization fails
                    print(repr(c['raw']))

        while True:
            sel = input('Enter number (or q to quit): ').strip()
            if sel.lower() in ('q', 'quit', 'exit'):
                sys.exit(0)
            try:
                idx = int(sel) - 1
                if 0 <= idx < len(choices):
                    webhook_id = choices[idx]['id']
                    break
            except ValueError:
                pass
            print('Invalid selection; try again.')

    else:
        webhook_id = args.webhook_id

    if not webhook_id:
        print('ERROR: webhook id not resolved', file=sys.stderr)
        sys.exit(2)

    integration_path = f"/webhooks/{webhook_id}"

    # Build desired mappings
    desired = []
    for pair in args.map:
        if ':' not in pair:
            print(f"Invalid --map value: {pair}", file=sys.stderr)
            sys.exit(2)
        blueprint_id, mapping_name = pair.split(':', 1)
        desired.append(build_mapping(blueprint_id, mapping_name))

    # If no --map arguments provided, fetch the blueprints and port-app-config.yml
    # from the ocean repo and build mappings from the config.
    def fetch_text(url: str) -> str:
        req = request.Request(url)
        with request.urlopen(req) as resp:
            return resp.read().decode('utf-8')

    def fetch_json(url: str):
        req = request.Request(url)
        with request.urlopen(req) as resp:
            return json.load(resp)

    if not args.map:
        if yaml is None:
            print('ERROR: PyYAML is required to parse remote port-app-config.yml. Install with: pip install pyyaml', file=sys.stderr)
            sys.exit(2)

        # Fetch blueprints (not strictly required for building mappings but helpful)
        try:
            blueprints = fetch_json(args.blueprints_url)
        except Exception as e:
            print(f'Warning: could not fetch blueprints.json: {e}', file=sys.stderr)
            blueprints = None

        try:
            cfg_text = fetch_text(args.config_url)
            cfg = yaml.safe_load(cfg_text)
        except Exception as e:
            print(f'ERROR: could not fetch/parse port-app-config.yml: {e}', file=sys.stderr)
            sys.exit(2)

        resources = cfg.get('resources') or []
        for res in resources:
            # resource shape: {kind: ..., selector:..., port: {entity: {mappings: {...}}}}
            port = res.get('port') or {}
            entity = port.get('entity') or {}
            mappings = entity.get('mappings') or {}
            if not mappings:
                continue
            # blueprint may be a quoted string like '"s3Bucket"'
            blueprint_expr = mappings.get('blueprint')
            if not blueprint_expr:
                continue
            if isinstance(blueprint_expr, str):
                bp = blueprint_expr.strip().strip('"').strip("'")
            else:
                bp = str(blueprint_expr)

            identifier_expr = mappings.get('identifier')
            title_expr = mappings.get('title')
            props = mappings.get('properties') or {}
            rels = mappings.get('relations') or {}

            kind = res.get('kind') or bp
            mapping_name = str(kind).replace(':', '-').replace('::', '-').lower()

            desired.append(build_mapping(bp, mapping_name, identifier_expr=identifier_expr,
                                         title_expr=title_expr, properties=props, relations=rels))

    # If dry-run, just show the payload and exit (no token needed for this path).
    if args.dry_run:
        print('Would PATCH with:', json.dumps({'mappings': desired}, indent=2))
        return

    # Non-dry-run: fetch current integration state and apply patch if changed.
    cur = api_get(base, integration_path, token)
    current_mappings = cur.get('integration', {}).get('mappings') or []

    # Compare normalized JSON
    if json.dumps(current_mappings, sort_keys=True) == json.dumps(desired, sort_keys=True):
        print('Mappings unchanged; nothing to do')
        return

    # Apply patch
    payload = {'mappings': desired}
    resp = api_patch(base, integration_path, token, payload)
    print('Patched integration; response keys:', list(resp.keys()))


if __name__ == '__main__':
    main()
