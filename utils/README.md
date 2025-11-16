# create_port_mappings.py

Helper script to build and apply Port webhook mappings via the Port API.

Usage

- Provide a webhook id explicitly:

```bash
python3 utils/create_port_mappings.py --webhook-id <WEBHOOK_ID> --dry-run
```

- Or run the interactive chooser (will list your webhooks and prompt selection):

```bash
export PORT_API_TOKEN="<your-token>"
python3 utils/create_port_mappings.py --choose-webhook --dry-run
```

Notes

- `PORT_API_TOKEN` must be set in your environment for API calls.
- `--dry-run` prints the PATCH payload instead of applying it.
- If you pass `--map blueprint:mapname` one or more times the script will use those explicit mappings; otherwise it will fetch the default `port-app-config.yml` from the ocean repo and convert resources into mappings automatically.
- PyYAML is required to parse the remote YAML: `pip install pyyaml`.
