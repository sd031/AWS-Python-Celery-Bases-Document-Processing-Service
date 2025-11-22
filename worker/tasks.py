import os
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional
import boto3
from botocore.exceptions import ClientError

from worker.celery_app import app
from worker.processors.ocr_processor import OCRProcessor
from worker.processors.thumbnail_processor import ThumbnailProcessor
from worker.processors.metadata_processor import MetadataProcessor
from worker.processors.image_analyzer import ImageAnalyzer

# Configure logging
logger = logging.getLogger(__name__)

# AWS clients
s3_client = boto3.client('s3', region_name=os.getenv('AWS_REGION', 'us-east-1'))
dynamodb = boto3.resource('dynamodb', region_name=os.getenv('AWS_REGION', 'us-east-1'))
sns_client = boto3.client('sns', region_name=os.getenv('AWS_REGION', 'us-east-1'))

# Configuration
S3_BUCKET = os.getenv('S3_BUCKET_NAME')
S3_PROCESSED_PREFIX = os.getenv('S3_PROCESSED_PREFIX', 'processed/')
SNS_TOPIC_ARN = os.getenv('SNS_TOPIC_ARN')
JOBS_TABLE_NAME = os.getenv('JOBS_TABLE_NAME', 'doc-processor-jobs')

# Initialize processors
ocr_processor = OCRProcessor()
thumbnail_processor = ThumbnailProcessor()
metadata_processor = MetadataProcessor()
image_analyzer = ImageAnalyzer()


def update_job_status(job_id: str, status: str, **kwargs):
    """Update job status in DynamoDB."""
    try:
        table = dynamodb.Table(JOBS_TABLE_NAME)
        update_expr = "SET #status = :status, updated_at = :updated_at"
        expr_values = {
            ':status': status,
            ':updated_at': datetime.utcnow().isoformat()
        }
        expr_names = {'#status': 'status'}
        
        # Reserved keywords in DynamoDB that need attribute name placeholders
        reserved_keywords = ['error', 'message', 'data', 'timestamp']
        
        for key, value in kwargs.items():
            if key.lower() in reserved_keywords:
                # Use attribute name placeholder for reserved keywords
                placeholder = f"#{key}"
                update_expr += f", {placeholder} = :{key}"
                expr_names[placeholder] = key
            else:
                update_expr += f", {key} = :{key}"
            expr_values[f':{key}'] = value
        
        table.update_item(
            Key={'job_id': job_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames=expr_names
        )
        logger.info(f"Updated job {job_id} status to {status}")
    except Exception as e:
        logger.error(f"Failed to update job status: {e}")


def get_job_info(job_id: str) -> Optional[Dict[str, Any]]:
    """Get job information from DynamoDB."""
    try:
        table = dynamodb.Table(JOBS_TABLE_NAME)
        response = table.get_item(Key={'job_id': job_id})
        return response.get('Item')
    except Exception as e:
        logger.error(f"Failed to get job info: {e}")
        return None


def send_sns_notification(email: str, job_id: str, status: str, results: Optional[Dict] = None):
    """Send SNS notification."""
    if not SNS_TOPIC_ARN or not email:
        return
    
    try:
        subject = f"Document Processing {status.title()}: {job_id}"
        message = f"Job ID: {job_id}\nStatus: {status}\n"
        
        if status == "completed" and results:
            message += f"\nResults:\n{json.dumps(results, indent=2)}"
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message,
            MessageAttributes={
                'email': {'DataType': 'String', 'StringValue': email}
            }
        )
        logger.info(f"Sent notification to {email} for job {job_id}")
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")


@app.task(bind=True, name='worker.tasks.process_document')
def process_document(self, job_id: str, s3_key: str, file_type: str):
    """
    Main task to process a document.
    Orchestrates OCR, thumbnail generation, metadata extraction, and image analysis.
    """
    logger.info(f"Processing document: job_id={job_id}, s3_key={s3_key}")
    
    try:
        # Update status to processing
        update_job_status(job_id, 'processing', progress=10)
        
        # Get job info for notification email
        job_info = get_job_info(job_id)
        notification_email = job_info.get('notification_email') if job_info else None
        
        # Download file from S3
        local_path = f"/tmp/{job_id}_{os.path.basename(s3_key)}"
        s3_client.download_file(S3_BUCKET, s3_key, local_path)
        logger.info(f"Downloaded file to {local_path}")
        
        results = {}
        
        # Extract metadata (run directly, not as separate task)
        update_job_status(job_id, 'processing', progress=20, message="Extracting metadata")
        metadata = metadata_processor.extract_metadata(local_path, file_type)
        results['metadata'] = metadata
        logger.info(f"Extracted metadata for {job_id}")
        
        # Process based on file type
        if file_type.startswith('image/'):
            # Generate thumbnail (run directly)
            update_job_status(job_id, 'processing', progress=40, message="Generating thumbnail")
            thumbnail_path = thumbnail_processor.generate_thumbnail(local_path)
            if thumbnail_path:
                thumbnail_key = f"{S3_PROCESSED_PREFIX}{job_id}/thumbnail.jpg"
                s3_client.upload_file(thumbnail_path, S3_BUCKET, thumbnail_key)
                thumbnail_url = f"s3://{S3_BUCKET}/{thumbnail_key}"
                results['thumbnail_url'] = thumbnail_url
                os.remove(thumbnail_path)
                logger.info(f"Generated thumbnail: {thumbnail_key}")
            
            # Analyze image (run directly)
            update_job_status(job_id, 'processing', progress=60, message="Analyzing image")
            analysis = image_analyzer.analyze_image(S3_BUCKET, s3_key)
            results['labels'] = analysis.get('labels', [])
            results['moderation'] = analysis.get('moderation', {})
            logger.info(f"Analyzed image for {job_id}")
            
            # OCR for images (run directly)
            update_job_status(job_id, 'processing', progress=80, message="Extracting text")
            ocr_text = ocr_processor.extract_text(S3_BUCKET, s3_key)
            results['ocr_text'] = ocr_text
            logger.info(f"Extracted {len(ocr_text) if ocr_text else 0} characters from {s3_key}")
            
        elif file_type == 'application/pdf':
            # Generate thumbnail for PDF (run directly)
            update_job_status(job_id, 'processing', progress=40, message="Generating thumbnail")
            thumbnail_path = thumbnail_processor.generate_thumbnail(local_path)
            if thumbnail_path:
                thumbnail_key = f"{S3_PROCESSED_PREFIX}{job_id}/thumbnail.jpg"
                s3_client.upload_file(thumbnail_path, S3_BUCKET, thumbnail_key)
                thumbnail_url = f"s3://{S3_BUCKET}/{thumbnail_key}"
                results['thumbnail_url'] = thumbnail_url
                os.remove(thumbnail_path)
                logger.info(f"Generated thumbnail: {thumbnail_key}")
            
            # OCR for PDF (run directly)
            update_job_status(job_id, 'processing', progress=70, message="Extracting text")
            ocr_text = ocr_processor.extract_text(S3_BUCKET, s3_key)
            results['ocr_text'] = ocr_text
            logger.info(f"Extracted {len(ocr_text) if ocr_text else 0} characters from {s3_key}")
            
        elif file_type.startswith('video/'):
            # Generate video thumbnail (run directly)
            update_job_status(job_id, 'processing', progress=60, message="Generating thumbnail")
            thumbnail_path = thumbnail_processor.generate_thumbnail(local_path)
            if thumbnail_path:
                thumbnail_key = f"{S3_PROCESSED_PREFIX}{job_id}/thumbnail.jpg"
                s3_client.upload_file(thumbnail_path, S3_BUCKET, thumbnail_key)
                thumbnail_url = f"s3://{S3_BUCKET}/{thumbnail_key}"
                results['thumbnail_url'] = thumbnail_url
                os.remove(thumbnail_path)
                logger.info(f"Generated thumbnail: {thumbnail_key}")
        
        # Clean up local file
        if os.path.exists(local_path):
            os.remove(local_path)
        
        # Update job with results
        update_job_status(
            job_id,
            'completed',
            progress=100,
            message="Processing completed",
            results=json.dumps(results),
            completed_at=datetime.utcnow().isoformat()
        )
        
        # Send notification
        if notification_email:
            send_notification.delay(notification_email, job_id, 'completed', results)
        
        logger.info(f"Successfully processed job {job_id}")
        return results
        
    except Exception as e:
        logger.error(f"Error processing document {job_id}: {e}", exc_info=True)
        update_job_status(
            job_id,
            'failed',
            error=str(e),
            completed_at=datetime.utcnow().isoformat()
        )
        
        # Send failure notification
        if notification_email:
            send_notification.delay(notification_email, job_id, 'failed')
        
        raise


@app.task(bind=True, name='worker.tasks.extract_text_ocr')
def extract_text_ocr(self, job_id: str, s3_key: str) -> Optional[str]:
    """Extract text from document using AWS Textract."""
    logger.info(f"Extracting text for job {job_id}")
    
    try:
        text = ocr_processor.extract_text(S3_BUCKET, s3_key)
        logger.info(f"Extracted {len(text) if text else 0} characters from {s3_key}")
        return text
    except Exception as e:
        logger.error(f"OCR failed for {job_id}: {e}")
        return None


@app.task(bind=True, name='worker.tasks.generate_thumbnail')
def generate_thumbnail(self, job_id: str, local_path: str, original_s3_key: str) -> Optional[str]:
    """Generate thumbnail and upload to S3."""
    logger.info(f"Generating thumbnail for job {job_id}")
    
    try:
        thumbnail_path = thumbnail_processor.generate_thumbnail(local_path)
        
        if thumbnail_path:
            # Upload thumbnail to S3
            thumbnail_key = f"{S3_PROCESSED_PREFIX}{job_id}/thumbnail.jpg"
            s3_client.upload_file(
                thumbnail_path,
                S3_BUCKET,
                thumbnail_key,
                ExtraArgs={'ContentType': 'image/jpeg'}
            )
            
            # Clean up local thumbnail
            os.remove(thumbnail_path)
            
            # Generate presigned URL (valid for 7 days)
            url = s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': S3_BUCKET, 'Key': thumbnail_key},
                ExpiresIn=604800
            )
            
            logger.info(f"Generated thumbnail: {thumbnail_key}")
            return url
        
        return None
        
    except Exception as e:
        logger.error(f"Thumbnail generation failed for {job_id}: {e}")
        return None


@app.task(bind=True, name='worker.tasks.extract_metadata')
def extract_metadata(self, job_id: str, local_path: str, file_type: str) -> Dict[str, Any]:
    """Extract file metadata."""
    logger.info(f"Extracting metadata for job {job_id}")
    
    try:
        metadata = metadata_processor.extract_metadata(local_path, file_type)
        logger.info(f"Extracted metadata for {job_id}")
        return metadata
    except Exception as e:
        logger.error(f"Metadata extraction failed for {job_id}: {e}")
        return {}


@app.task(bind=True, name='worker.tasks.analyze_image')
def analyze_image(self, job_id: str, s3_key: str) -> Dict[str, Any]:
    """Analyze image using AWS Rekognition."""
    logger.info(f"Analyzing image for job {job_id}")
    
    try:
        analysis = image_analyzer.analyze_image(S3_BUCKET, s3_key)
        logger.info(f"Analyzed image for {job_id}")
        return analysis
    except Exception as e:
        logger.error(f"Image analysis failed for {job_id}: {e}")
        return {}


@app.task(bind=True, name='worker.tasks.send_notification')
def send_notification(self, email: str, job_id: str, status: str, results: Optional[Dict] = None):
    """Send notification via SNS."""
    logger.info(f"Sending notification for job {job_id} to {email}")
    send_sns_notification(email, job_id, status, results)
