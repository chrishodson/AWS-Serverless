#!/usr/bin/python3
import os
import json
import hmac
import hashlib
import http.client
from urllib.parse import urlparse



# Webhook URLs and secret loaded once at module level
# Support a single ingest webhook URL or per-service webhook URLs (backwards compat)
INGEST_WEBHOOK_URL = os.environ.get('INGEST_WEBHOOK_URL')
WEBHOOK_URLS = {
    'aws.ec2': os.environ.get('EC2_WEBHOOK_URL') or INGEST_WEBHOOK_URL,
    'aws.s3': os.environ.get('S3_WEBHOOK_URL') or INGEST_WEBHOOK_URL,
    'aws.rds': os.environ.get('RDS_WEBHOOK_URL') or INGEST_WEBHOOK_URL,
    'aws.sqs': os.environ.get('SQS_WEBHOOK_URL') or INGEST_WEBHOOK_URL,
}
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', '')

def lambda_handler(event, context):
    print('Event received:', json.dumps(event, indent=2))
    results = []
    for record in event.get('Records', []):
        try:
            body = json.loads(record['body'])
            print('Processing event:', json.dumps(body, indent=2))
            source = body.get('source')
            webhook_url = WEBHOOK_URLS.get(source)
            if not webhook_url:
                print('Unknown source:', source)
                results.append({'success': False, 'error': f'Unknown source: {source}'})
                continue
            port_event = transform_event(body)
            result = send_to_port_webhook(webhook_url, port_event)
            results.append({'success': True, 'result': result})
        except Exception as e:
            print('Error processing record:', str(e))
            results.append({'success': False, 'error': str(e)})
    print('Processing results:', json.dumps(results, indent=2))
    return {'results': results}

def transform_event(aws_event):
    source = aws_event.get('source')
    detail_type = aws_event.get('detail-type')
    detail = aws_event.get('detail', {})
    region = aws_event.get('region')
    time = aws_event.get('time')
    # helper to safely extract nested paths and several common key variants
    def pick(*keys):
        for k in keys:
            # support nested path expressed with dots
            if isinstance(k, str) and '.' in k:
                cur = detail
                ok = True
                for part in k.split('.'):
                    if isinstance(cur, dict) and part in cur:
                        cur = cur.get(part)
                    else:
                        ok = False
                        break
                if ok and cur is not None:
                    return cur
            else:
                # try top-level detail keys
                if k in detail and detail.get(k) is not None:
                    return detail.get(k)
                # try common variants in event body
                if k.lower() in detail and detail.get(k.lower()) is not None:
                    return detail.get(k.lower())
        return None

    port_event = {
        'origin': 'AWS',
        'timestamp': time,
        'region': region,
        'action': 'upsert'
    }

    if source == 'aws.ec2':
        # EC2 Instance State-change notifications and other EC2 events
        instance_id = pick('instanceId', 'instance-id', 'instanceId.0')
        state = pick('state', 'detail.instanceState', 'instance-state') or pick('detail.state')
        instance_type = pick('instanceType', 'instance.type')
        availability_zone = pick('availabilityZone', 'placement.availabilityZone')
        public_dns = pick('publicDnsName', 'public_dns_name')
        private_dns = pick('privateDnsName', 'private_dns_name')
        key_name = pick('keyName', 'key_name')
        image = pick('imageId', 'image.id')

        port_event.update({
            'blueprint': 'ec2-instance',
            'properties': {
                'instance_state': state,
                'instance_type': instance_type,
                'availability_zone': availability_zone,
                'public_dns': public_dns,
                'private_dns': private_dns,
                'key_name': key_name,
                'image': image,
            }
        })

    elif source == 'aws.s3':
        # S3 event structure varies; try common paths
        bucket_name = pick('bucket.name', 'bucketName', 's3.bucket.name')
        creation_date = pick('creationDate', 'eventTime')
        region_value = pick('awsRegion', 'region', 's3.awsRegion') or region
        acl = pick('acl')
        versioning_enabled = pick('versioning')

        port_event.update({
            'blueprint': 's3-bucket',
            'properties': {
                'bucket_name': bucket_name,
                'creation_date': creation_date,
                'region': region_value,
                'acl': acl,
                'versioning_enabled': versioning_enabled,
            }
        })

    elif source == 'aws.rds':
        instance_identifier = pick('DBInstanceIdentifier', 'dbInstanceIdentifier', 'instanceId')
        engine = pick('engine', 'engineName')
        status = pick('status', 'dbInstanceStatus', 'state')
        endpoint = pick('Endpoint.Address', 'endpoint.address', 'endpoint')

        port_event.update({
            'blueprint': 'rds-instance',
            'properties': {
                'instance_identifier': instance_identifier,
                'engine': engine,
                'status': status,
                'region': region,
                'endpoint': endpoint,
            }
        })

    elif source == 'aws.sqs':
        queue_name = pick('queueName', 'queue.name', 'queue')
        queue_url = pick('queueUrl', 'queue.url')
        visibility_timeout = pick('visibilityTimeout')
        message_retention_seconds = pick('messageRetentionSeconds')
        fifo_queue = pick('fifoQueue')

        port_event.update({
            'blueprint': 'sqs-queue',
            'properties': {
                'queue_name': queue_name,
                'queue_url': queue_url,
                'visibility_timeout': visibility_timeout,
                'message_retention_seconds': message_retention_seconds,
                'fifo_queue': fifo_queue,
                'region': region,
            }
        })

    else:
        # Unknown source: pass through basic info so operator can improve mapping
        port_event.update({
            'blueprint': 'cloudResource',
            'properties': {
                'kind': source,
                'region': region,
                'raw': detail,
            }
        })

    return port_event

def send_to_port_webhook(webhook_url, event):
    body = json.dumps(event)
    signature = hmac.new(WEBHOOK_SECRET.encode('utf-8'), body.encode('utf-8'), hashlib.sha256).hexdigest()
    parsed_url = urlparse(webhook_url)
    conn = http.client.HTTPSConnection(parsed_url.hostname, 443)
    headers = {
        'Content-Type': 'application/json',
        'X-Port-Signature': signature
    }
    try:
        conn.request('POST', parsed_url.path, body, headers)
        response = conn.getresponse()
        response_body = response.read().decode()
        if 200 <= response.status < 300:
            return {'statusCode': response.status, 'body': response_body}
        else:
            raise Exception(f'HTTP Error: {response.status} - {response_body}')
    finally:
        conn.close()
