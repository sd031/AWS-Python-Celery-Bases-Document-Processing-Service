# AWS Document Processing Service

A scalable, full-stack web application for asynchronous document/image/video processing using AWS services. Features a React frontend, FastAPI backend, Celery workers, and AWS AI/ML services.

## Features

✅ **Modern Web UI** - React frontend with authentication and real-time job tracking  
✅ **User Authentication** - Secure signup/login with token-based auth  
✅ **Document Processing** - OCR, thumbnail generation, metadata extraction  
✅ **AI-Powered Analysis** - AWS Textract for OCR, Rekognition for image analysis  
✅ **Scalable Architecture** - ECS Fargate with auto-scaling workers  
✅ **Asynchronous Processing** - Celery task queue with SQS broker  
✅ **Secure Storage** - S3 with pre-signed URLs and encryption  
✅ **User Isolation** - Each user only sees their own documents  

## Quick Start

```bash
# 1. Clone and configure
git clone <repo-url>
cd aws_project_8
cp .env.example .env
# Edit .env with your AWS credentials

# 2. Deploy everything
./deploy.sh

# 3. Access the web UI
# Frontend URL will be output after deployment
```

## Architecture

- **React Frontend**: Modern web UI with authentication (ECS Fargate + Nginx)
- **FastAPI**: REST API for file uploads, authentication, and job management
- **Celery**: Distributed task queue with AWS SQS broker
- **S3**: File storage for uploads and processed outputs
- **AWS Textract**: OCR for PDFs and images
- **AWS Rekognition**: Image analysis and moderation
- **Lambda**: S3 event triggers for automatic processing
- **SNS**: Email notifications
- **DynamoDB**: User authentication and job tracking
- **ECS Fargate**: Container orchestration for frontend, API, and workers
- **CloudWatch**: Logging and monitoring

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture diagrams and documentation.

## Project Structure

```
.
├── api/                    # FastAPI application
│   ├── main.py            # API endpoints & authentication
│   ├── models.py          # Pydantic models
│   └── config.py          # Configuration
├── frontend/               # React web application
│   ├── src/
│   │   ├── components/    # React components
│   │   │   ├── Auth/      # Login/Signup
│   │   │   ├── Dashboard/ # Job management
│   │   │   └── Upload/    # File upload
│   │   ├── services/      # API client
│   │   └── App.jsx        # Main app
│   ├── package.json
│   └── vite.config.js
├── worker/                 # Celery workers
│   ├── celery_app.py      # Celery configuration
│   ├── tasks.py           # Processing tasks
│   └── processors/        # Processing modules
│       ├── metadata_processor.py
│       ├── thumbnail_processor.py
│       ├── ocr_processor.py
│       └── image_processor.py
├── lambda/                 # Lambda functions
│   └── s3_trigger.py      # S3 event handler
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Main configuration
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   ├── vpc.tf             # VPC & networking
│   ├── ecs.tf             # ECS cluster & services
│   ├── frontend.tf        # Frontend ECS service
│   ├── s3.tf              # S3 buckets
│   ├── lambda.tf          # Lambda functions
│   ├── dynamodb.tf        # DynamoDB tables
│   ├── sns.tf             # SNS topics
│   ├── sqs.tf             # SQS queues
│   └── iam.tf             # IAM roles & policies
├── docker/                 # Docker configurations
│   ├── api.Dockerfile     # API container
│   ├── worker.Dockerfile  # Worker container
│   ├── frontend.Dockerfile # Frontend container
│   └── nginx.conf         # Nginx config for frontend
├── deploy.sh              # Deployment script
├── cleanup.sh             # Cleanup script
├── Makefile               # Build & deployment tasks
├── requirements.txt       # Python dependencies
├── .env.example           # Environment variables template
└── README.md              # Documentation
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Docker
- Python 3.11+

## Deployment

1. Copy `.env.example` to `.env` and configure your AWS settings:
   ```bash
   cp .env.example .env
   # Edit .env with your AWS account details
   ```

2. Run the deployment script:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. The script will:
   - Build Docker images
   - Push to ECR
   - Deploy infrastructure via Terraform
   - Output API endpoint URL

## API Endpoints

### Authentication

#### Sign Up
```bash
POST /auth/signup
Content-Type: application/json

curl -X POST http://API_URL/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securepassword",
    "name": "John Doe"
  }'
```

#### Login
```bash
POST /auth/login
Content-Type: application/json

curl -X POST http://API_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securepassword"
  }'
```

### Document Processing (Requires Authentication)

#### Upload File
```bash
POST /upload
Content-Type: multipart/form-data
Authorization: Bearer {token}

curl -X POST http://API_URL/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@document.pdf" \
  -F "notification_email=user@example.com"
```

#### List Jobs
```bash
GET /jobs
Authorization: Bearer {token}

curl http://API_URL/jobs \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### Check Status
```bash
GET /status/{job_id}
Authorization: Bearer {token}

curl http://API_URL/status/abc-123-def \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### Get Results
```bash
GET /results/{job_id}
Authorization: Bearer {token}

curl http://API_URL/results/abc-123-def \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### Delete Job
```bash
DELETE /jobs/{job_id}
Authorization: Bearer {token}

curl -X DELETE http://API_URL/jobs/abc-123-def \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Web Interface

Access the web UI at the Frontend ALB URL (output after deployment):
- **Login/Signup**: User authentication
- **Dashboard**: View all your processing jobs
- **Upload**: Drag-and-drop file upload
- **Job Details**: View processing results, thumbnails, OCR text, and metadata
- **Real-time Status**: Auto-refreshing job status

## Processing Features

- **User Isolation**: Each user only sees their own documents
- **OCR**: Extract text from PDFs and images using AWS Textract
- **Thumbnails**: Generate thumbnails for images and videos with pre-signed URLs
- **Metadata**: Extract file metadata (size, type, dimensions, duration)
- **Image Analysis**: Detect labels and content moderation via Rekognition
- **Notifications**: Email alerts when processing completes

## How Celery Document Processing Works

The system uses Celery for asynchronous document processing with the following workflow:

### 1. **File Upload & Trigger**
```
User uploads file → API stores in S3 → S3 event triggers Lambda → Lambda enqueues Celery task to SQS
```

### 2. **Task Queue (SQS)**
- Lambda sends task message to Amazon SQS queue
- SQS acts as the Celery broker for reliable message delivery
- Workers poll SQS for new tasks

### 3. **Worker Processing Pipeline**
```python
# Main task: process_document(job_id, s3_key)
1. Download file from S3
2. Extract metadata (file size, type, dimensions)
3. Generate thumbnail (images/videos/PDFs)
4. Run OCR via AWS Textract (if applicable)
5. Analyze image via AWS Rekognition (if applicable)
6. Upload results to S3 (processed/{job_id}/)
7. Update DynamoDB job status to 'completed'
8. Send SNS email notification
9. Clean up temporary files
```

### 4. **Task Execution**
- **Celery Workers**: Run as ECS Fargate containers
- **Concurrency**: 2 tasks per worker (configurable)
- **Auto-scaling**: Workers scale based on SQS queue depth
- **Retry Logic**: Failed tasks retry 3 times with exponential backoff
- **Dead Letter Queue**: Failed tasks move to DLQ after max retries

### 5. **Result Storage**
- **Job Status**: Stored in DynamoDB `doc-processor-jobs` table
- **Task Results**: Stored in DynamoDB `doc-processor-celery-results` table
- **Processed Files**: Stored in S3 `processed/{job_id}/` prefix
- **Thumbnails**: Accessible via pre-signed URLs (1-hour expiry)

### 6. **Status Tracking**
```
pending → processing → completed/failed
```
- Users can check status via `/status/{job_id}` endpoint
- Frontend auto-refreshes status every 5 seconds
- Email notification sent on completion

### Example Task Flow
```
1. User uploads "document.pdf"
2. API: Creates job record with status='pending'
3. S3: Triggers Lambda on ObjectCreated event
4. Lambda: Enqueues task {"job_id": "abc-123", "s3_key": "uploads/abc-123/document.pdf"}
5. Worker: Picks up task from SQS
6. Worker: Updates status to 'processing'
7. Worker: Extracts text using Textract
8. Worker: Generates thumbnail using pdf2image
9. Worker: Uploads thumbnail.jpg to S3
10. Worker: Updates job with results and status='completed'
11. Worker: Sends SNS notification
12. User: Receives email and views results in dashboard
```

## Cleanup

To destroy all AWS resources:
```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Monitoring

- **CloudWatch Logs**: 
  - `/aws/ecs/doc-processor-frontend` - Frontend logs
  - `/aws/ecs/doc-processor-api` - API logs
  - `/aws/ecs/doc-processor-worker` - Worker logs
  - `/aws/lambda/doc-processor-s3-trigger` - Lambda logs
- **CloudWatch Metrics**: ECS service metrics, Lambda invocations, ALB metrics
- **DynamoDB**: 
  - `doc-processor-jobs` - Job tracking and status
  - `doc-processor-users` - User accounts
  - `doc-processor-celery-results` - Celery task results

### Useful Commands

```bash
# View API logs
make logs-api

# View worker logs
make logs-worker

# View frontend logs
make logs-frontend

# Check ECS service status
aws ecs describe-services \
  --cluster doc-processor-cluster \
  --services doc-processor-api-service doc-processor-worker-service doc-processor-frontend-service
```

## Security

- **User Authentication**: Token-based authentication with DynamoDB user store
- **User Isolation**: Users can only access their own jobs and documents
- **IAM Roles**: Least privilege access for all services
- **VPC**: Private subnets for ECS tasks
- **S3 Encryption**: Server-side encryption (AES-256)
- **Pre-signed URLs**: Temporary, secure access to S3 objects
- **Security Groups**: Restricted network access between services

## Cost Optimization

- ECS Fargate Spot instances for workers
- S3 lifecycle policies for old files
- CloudWatch log retention policies
- Auto-scaling based on queue depth

## Improvement Challenges

🚀 **Challenge yourself to implement these enhancements:**

1. **Add HTTPS Support** - Configure ACM certificates and enable HTTPS on both ALBs for secure communication
2. **Implement WebSocket Updates** - Replace polling with WebSocket connections for real-time job status updates
3. **Add Batch Processing** - Allow users to upload and process multiple files simultaneously in a single request
4. **Create Admin Dashboard** - Build an admin panel to monitor all users, jobs, and system metrics across the platform
5. **Multi-Region Deployment** - Extend the architecture to support multi-region deployment with cross-region replication for disaster recovery

## License

MIT
