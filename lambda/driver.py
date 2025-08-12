import os
import json
import hmac
import hashlib
import http.client
from urllib.parse import urlparse



# Webhook URLs and secret loaded once at module level
WEBHOOK_URLS = {
    'aws.ec2': os.environ.get('EC2_WEBHOOK_URL'),
    'aws.s3': os.environ.get('S3_WEBHOOK_URL'),
    'aws.rds': os.environ.get('RDS_WEBHOOK_URL'),
    'aws.sqs': os.environ.get('SQS_WEBHOOK_URL'),
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
    port_event = {
        'origin': 'AWS',
        'timestamp': time,
        'region': region
    }
    if source == 'aws.ec2':
        port_event.update({
            'blueprint': 'ec2-instance',
            'action': 'upsert',
            'properties': {
                'instance_id': detail.get('instanceId'),
                'state': detail.get('state'),
                'region': region
            }
        })
    elif source == 'aws.s3':
        port_event.update({
            'blueprint': 's3-bucket',
            'action': 'upsert',
            'properties': {
                'bucket_name': detail.get('bucketName'),
                'region': region
            }
        })
    elif source == 'aws.rds':
        port_event.update({
            'blueprint': 'rds-instance',
            'action': 'upsert',
            'properties': {
                'db_instance_identifier': detail.get('instanceId'),
                'status': detail.get('state'),
                'region': region
            }
        })
    elif source == 'aws.sqs':
        port_event.update({
            'blueprint': 'sqs-queue',
            'action': 'upsert',
            'properties': {
                'queue_name': detail.get('queueName'),
                'region': region
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
