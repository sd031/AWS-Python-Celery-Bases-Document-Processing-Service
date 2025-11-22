import logging
import uuid
import json
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import boto3
from botocore.exceptions import ClientError
import aiofiles

from api.config import settings
from api.models import (
    UploadResponse, StatusResponse, ResultsResponse, 
    HealthResponse, JobStatus, ProcessingResult
)

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Document Processing API",
    description="Asynchronous document/image/video processing service",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AWS clients
s3_client = boto3.client('s3', region_name=settings.aws_region)
dynamodb = boto3.resource('dynamodb', region_name=settings.aws_region)
sqs_client = boto3.client('sqs', region_name=settings.aws_region)

# DynamoDB table for job tracking
try:
    jobs_table = dynamodb.Table('doc-processor-jobs')
except Exception as e:
    logger.warning(f"Could not connect to DynamoDB jobs table: {e}")
    jobs_table = None


def is_allowed_file(filename: str) -> bool:
    """Check if file extension is allowed."""
    allowed = settings.allowed_extensions.split(',')
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed


def create_job_record(job_id: str, s3_key: str, file_info: dict, email: Optional[str] = None):
    """Create a job record in DynamoDB."""
    if not jobs_table:
        logger.warning("Jobs table not available, skipping record creation")
        return
    
    try:
        jobs_table.put_item(
            Item={
                'job_id': job_id,
                'status': JobStatus.PENDING.value,
                's3_key': s3_key,
                'file_name': file_info['filename'],
                'file_size': file_info['size'],
                'file_type': file_info['content_type'],
                'notification_email': email or '',
                'created_at': datetime.utcnow().isoformat(),
                'updated_at': datetime.utcnow().isoformat(),
            }
        )
        logger.info(f"Created job record for {job_id}")
    except Exception as e:
        logger.error(f"Failed to create job record: {e}")


def get_job_record(job_id: str) -> Optional[dict]:
    """Retrieve job record from DynamoDB."""
    if not jobs_table:
        return None
    
    try:
        response = jobs_table.get_item(Key={'job_id': job_id})
        return response.get('Item')
    except Exception as e:
        logger.error(f"Failed to get job record: {e}")
        return None


def update_job_status(job_id: str, status: JobStatus, **kwargs):
    """Update job status in DynamoDB."""
    if not jobs_table:
        return
    
    try:
        update_expr = "SET #status = :status, updated_at = :updated_at"
        expr_values = {
            ':status': status.value,
            ':updated_at': datetime.utcnow().isoformat()
        }
        expr_names = {'#status': 'status'}
        
        for key, value in kwargs.items():
            update_expr += f", {key} = :{key}"
            expr_values[f':{key}'] = value
        
        jobs_table.update_item(
            Key={'job_id': job_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames=expr_names
        )
        logger.info(f"Updated job {job_id} status to {status.value}")
    except Exception as e:
        logger.error(f"Failed to update job status: {e}")


@app.get("/", response_model=HealthResponse)
async def root():
    """Health check endpoint."""
    return HealthResponse(status="healthy")


@app.get("/health", response_model=HealthResponse)
async def health():
    """Detailed health check."""
    return HealthResponse(status="healthy")


@app.post("/upload", response_model=UploadResponse)
async def upload_file(
    file: UploadFile = File(...),
    notification_email: Optional[str] = Form(None)
):
    """
    Upload a file for processing.
    
    - **file**: The file to upload (PDF, image, or video)
    - **notification_email**: Optional email for completion notification
    """
    # Validate file
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")
    
    if not is_allowed_file(file.filename):
        raise HTTPException(
            status_code=400,
            detail=f"File type not allowed. Allowed types: {settings.allowed_extensions}"
        )
    
    # Read file content
    content = await file.read()
    file_size = len(content)
    
    if file_size > settings.max_file_size:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Max size: {settings.max_file_size} bytes"
        )
    
    # Generate job ID and S3 key
    job_id = str(uuid.uuid4())
    file_extension = file.filename.rsplit('.', 1)[1].lower()
    s3_key = f"{settings.s3_upload_prefix}{job_id}/{file.filename}"
    
    try:
        # Upload to S3
        s3_client.put_object(
            Bucket=settings.s3_bucket_name,
            Key=s3_key,
            Body=content,
            ContentType=file.content_type or 'application/octet-stream',
            Metadata={
                'job_id': job_id,
                'original_filename': file.filename,
                'notification_email': notification_email or ''
            }
        )
        logger.info(f"Uploaded file to S3: {s3_key}")
        
        # Create job record
        file_info = {
            'filename': file.filename,
            'size': file_size,
            'content_type': file.content_type or 'application/octet-stream'
        }
        create_job_record(job_id, s3_key, file_info, notification_email)
        
        return UploadResponse(
            job_id=job_id,
            message="File uploaded successfully. Processing will begin shortly.",
            s3_key=s3_key,
            file_size=file_size,
            file_type=file.content_type or 'application/octet-stream'
        )
        
    except ClientError as e:
        logger.error(f"S3 upload failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload file")
    except Exception as e:
        logger.error(f"Upload error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/status/{job_id}", response_model=StatusResponse)
async def get_status(job_id: str):
    """
    Get the processing status of a job.
    
    - **job_id**: The unique job identifier returned from upload
    """
    job = get_job_record(job_id)
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return StatusResponse(
        job_id=job_id,
        status=JobStatus(job.get('status', 'pending')),
        created_at=job.get('created_at'),
        updated_at=job.get('updated_at'),
        progress=job.get('progress'),
        message=job.get('message')
    )


@app.get("/results/{job_id}", response_model=ResultsResponse)
async def get_results(job_id: str):
    """
    Get the processing results for a completed job.
    
    - **job_id**: The unique job identifier returned from upload
    """
    job = get_job_record(job_id)
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    status = JobStatus(job.get('status', 'pending'))
    
    # Parse results if available
    results = None
    if status == JobStatus.COMPLETED and job.get('results'):
        results_data = job.get('results')
        if isinstance(results_data, str):
            results_data = json.loads(results_data)
        results = ProcessingResult(**results_data)
    
    return ResultsResponse(
        job_id=job_id,
        status=status,
        original_file=job.get('file_name', ''),
        file_type=job.get('file_type', ''),
        file_size=job.get('file_size', 0),
        results=results,
        error=job.get('error'),
        created_at=job.get('created_at'),
        completed_at=job.get('completed_at')
    )


@app.delete("/jobs/{job_id}")
async def delete_job(job_id: str):
    """
    Delete a job and its associated files.
    
    - **job_id**: The unique job identifier
    """
    job = get_job_record(job_id)
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    try:
        # Delete S3 objects
        s3_key = job.get('s3_key')
        if s3_key:
            # Delete original file
            s3_client.delete_object(Bucket=settings.s3_bucket_name, Key=s3_key)
            
            # Delete processed files (thumbnails, etc.)
            prefix = f"{settings.s3_processed_prefix}{job_id}/"
            response = s3_client.list_objects_v2(
                Bucket=settings.s3_bucket_name,
                Prefix=prefix
            )
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    s3_client.delete_object(
                        Bucket=settings.s3_bucket_name,
                        Key=obj['Key']
                    )
        
        # Delete DynamoDB record
        if jobs_table:
            jobs_table.delete_item(Key={'job_id': job_id})
        
        return {"message": "Job deleted successfully", "job_id": job_id}
        
    except Exception as e:
        logger.error(f"Failed to delete job: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete job")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        workers=settings.api_workers,
        log_level=settings.log_level.lower()
    )
