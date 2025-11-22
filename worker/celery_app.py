import os
import logging
from celery import Celery
from kombu.utils.url import safequote

# Configure logging
logging.basicConfig(
    level=os.getenv('LOG_LEVEL', 'INFO'),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# AWS Configuration
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
AWS_ACCOUNT_ID = os.getenv('AWS_ACCOUNT_ID')

# SQS Queue configuration
SQS_QUEUE_NAME = os.getenv('SQS_QUEUE_NAME', 'doc-processor-queue')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL', '')

# Construct broker URL for SQS
# Format: sqs://aws_access_key_id:aws_secret_access_key@
# When using IAM roles (ECS), we can use sqs:// without credentials
broker_url = f'sqs://'

# Extract queue name from URL if available
if SQS_QUEUE_URL:
    # URL format: https://sqs.region.amazonaws.com/account-id/queue-name
    queue_name_from_url = SQS_QUEUE_URL.split('/')[-1]
    logger.info(f"Using SQS queue from URL: {queue_name_from_url}")
else:
    queue_name_from_url = SQS_QUEUE_NAME

broker_transport_options = {
    'region': AWS_REGION,
    'queue_name_prefix': '',
    'visibility_timeout': 3600,  # 1 hour
    'polling_interval': 1,
    'wait_time_seconds': 20,  # Long polling
    'predefined_queues': {
        queue_name_from_url: {
            'url': SQS_QUEUE_URL,
            'access_key_id': None,
            'secret_access_key': None,
        }
    } if SQS_QUEUE_URL else {},
}

# DynamoDB backend configuration
DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE_NAME', 'celery-results')
result_backend = f'dynamodb://@{AWS_REGION}/{DYNAMODB_TABLE}'

# Create Celery app
app = Celery(
    'doc_processor',
    broker=broker_url,
    backend=result_backend,
    include=['worker.tasks']
)

# Celery configuration
app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 1 hour hard limit
    task_soft_time_limit=3300,  # 55 minutes soft limit
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=50,
    broker_transport_options=broker_transport_options,
    result_backend_transport_options={
        'region': AWS_REGION,
    },
    # Task routing
    task_routes={
        'worker.tasks.process_document': {'queue': queue_name_from_url},
        'worker.tasks.extract_text_ocr': {'queue': queue_name_from_url},
        'worker.tasks.generate_thumbnail': {'queue': queue_name_from_url},
        'worker.tasks.extract_metadata': {'queue': queue_name_from_url},
        'worker.tasks.analyze_image': {'queue': queue_name_from_url},
        'worker.tasks.send_notification': {'queue': queue_name_from_url},
    },
    # Default queue
    task_default_queue=queue_name_from_url,
)

logger.info(f"Celery app configured with broker: {broker_url}")
logger.info(f"Result backend: {result_backend}")

if __name__ == '__main__':
    app.start()
