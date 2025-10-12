#!/usr/bin/python3
## take in webhook event.  Write it to S3 and return the name of the object

import json
import hmac
import hashlib
import os
import boto3
import time

webhook_secret = os.environ['WEBHOOK_SECRET']
s3_bucket = os.environ['S3_BUCKET']
prefix = os.environ.get('S3_PREFIX', 'webhooks/')

s3_client = boto3.client('s3')

# get the base of the object url from the bucket


def handler(event, context):

    # Verify the webhook signature
    if not verify_signature(event, webhook_secret):
        return {
            'statusCode': 401,
            'body': json.dumps({'error': 'Invalid signature'})
        }
    
    try:
        # Parse the webhook payload
        payload = json.loads(event['body'])

        #Remove the secret signature to prevent it from being stored
        payload['headers'].pop('x-webhook-signature', None)

        # if objectName is blank, remove it.
        if payload.get('objectName') == '' or str(payload.get('objectName')) == 'None':
            del payload['objectName']

        # If the name is specified use that.  If not, use the current date/time in epoch
        object_name = prefix + payload.get('objectName', 'event_' + str(int(time.time())) + '.html')

        # convert the payload to pretty html and write it to the s3 bucket
        html_content = f"<html><body><h1>Webhook Event</h1><pre>{json.dumps(payload, indent=2)}</pre></body></html>"
        # Write the HTML content to S3.  The object will be deleted in 30 days by a lifecycle policy
        s3_client.put_object(Bucket=s3_bucket, Key=object_name, Body=html_content, ContentType='text/html')

        # Return success response and the url of the new object
        return {
            'statusCode': 200,
            'body': json.dumps({'received': True, 'url': f"https://{s3_bucket}.s3.amazonaws.com/{object_name}"})
        }
        
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON payload'})
        }
    except Exception as e:
        print(f"Error processing webhook: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

def verify_signature(event, webhook_secret):
    """
    Verify the webhook signature using HMAC
    """
    try:
        # Get the signature from headers
        signature = event['headers'].get('x-webhook-signature')

        if not signature:
            print("Error: Missing webhook signature in headers")
            return False
        
        # Get the raw body (return an empty string if the body key doesn't exist)
        body = event.get('body', '')
        
        # Create HMAC using the secret key
        expected_signature = hmac.new(
            webhook_secret.encode('utf-8'),
            body.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        # Compare the expected signature with the received signature to authenticate the message
        is_valid = hmac.compare_digest(signature, expected_signature)
        if not is_valid:
            print(f"Error: Invalid signature. Received: {signature}, Expected: {expected_signature}")
            return False
            
        return True
    except Exception as e:
        print(f"Error verifying signature: {e}")
        return False