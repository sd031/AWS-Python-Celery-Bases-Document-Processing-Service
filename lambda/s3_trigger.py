import json
import os
import logging
import boto3
from urllib.parse import unquote_plus

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
sqs_client = boto3.client('sqs')
s3_client = boto3.client('s3')

# Configuration
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
UPLOAD_PREFIX = os.environ.get('S3_UPLOAD_PREFIX', 'uploads/')


def lambda_handler(event, context):
    """
    Lambda function triggered by S3 events.
    Enqueues Celery tasks for document processing.
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    processed_count = 0
    
    for record in event.get('Records', []):
        try:
            # Extract S3 event details
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            size = record['s3']['object']['size']
            
            logger.info(f"Processing S3 event: bucket={bucket}, key={key}, size={size}")
            
            # Only process files in the upload prefix
            if not key.startswith(UPLOAD_PREFIX):
                logger.info(f"Skipping file outside upload prefix: {key}")
                continue
            
            # Get object metadata
            try:
                metadata_response = s3_client.head_object(Bucket=bucket, Key=key)
                metadata = metadata_response.get('Metadata', {})
                content_type = metadata_response.get('ContentType', 'application/octet-stream')
                
                job_id = metadata.get('job_id')
                notification_email = metadata.get('notification_email', '')
                
                if not job_id:
                    logger.warning(f"No job_id in metadata for {key}")
                    # Extract job_id from key if possible
                    parts = key.split('/')
                    if len(parts) >= 2:
                        job_id = parts[1]
                    else:
                        logger.error(f"Cannot determine job_id for {key}")
                        continue
                
            except Exception as e:
                logger.error(f"Failed to get object metadata: {e}")
                continue
            
            # Create Celery task message
            task_message = {
                'task': 'worker.tasks.process_document',
                'id': job_id,
                'args': [job_id, key, content_type],
                'kwargs': {},
                'retries': 0,
                'eta': None,
                'expires': None
            }
            
            # Send message to SQS
            if SQS_QUEUE_URL:
                try:
                    response = sqs_client.send_message(
                        QueueUrl=SQS_QUEUE_URL,
                        MessageBody=json.dumps(task_message),
                        MessageAttributes={
                            'job_id': {
                                'StringValue': job_id,
                                'DataType': 'String'
                            },
                            'content_type': {
                                'StringValue': content_type,
                                'DataType': 'String'
                            }
                        }
                    )
                    
                    logger.info(f"Enqueued task for job {job_id}: {response['MessageId']}")
                    processed_count += 1
                    
                except Exception as e:
                    logger.error(f"Failed to send SQS message: {e}")
            else:
                logger.warning("SQS_QUEUE_URL not configured")
        
        except Exception as e:
            logger.error(f"Error processing record: {e}", exc_info=True)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Processed {processed_count} files',
            'processed_count': processed_count
        })
    }
