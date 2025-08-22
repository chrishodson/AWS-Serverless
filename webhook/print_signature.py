#!/usr/bin/env python3
import hmac
import hashlib
import json

DEBUG = False

def print_webhook_signature(secret_file, payload_file, webhook_url_file):
    # Read the secret
    with open(secret_file, 'r') as f:
        webhook_secret = f.read().strip()
    # Read the payload
    with open(payload_file, 'r') as f:
        payload = json.loads(f.read())
    # Read the webhook URL (not used for signature, but printed for context)
    with open(webhook_url_file, 'r') as f:
        webhook_url = f.read().strip()
    # Compute HMAC signature
    signature = hmac.new(
        webhook_secret.encode('utf-8'),
        json.dumps(payload).encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    if DEBUG:
      print(f"Webhook URL: {webhook_url}")
      print(f"Payload: {payload}")
      print(f"Signature: {signature}")
    return signature


if __name__ == "__main__":
    DEBUG = True
    import sys
    if len(sys.argv) != 4:
        print("Usage: python print_signature.py <secret_file> <payload_file> <webhook_url_file>")
        sys.exit(1)
    secret_file = sys.argv[1]
    payload_file = sys.argv[2]
    webhook_url_file = sys.argv[3]
    print_webhook_signature(secret_file, payload_file, webhook_url_file)
