# AWS Document Processing Service

A scalable web+API service for asynchronous document/image/video processing using AWS services.

## Architecture

- **FastAPI**: REST API for file uploads and status tracking
- **Celery**: Distributed task queue with AWS SQS broker
- **S3**: File storage for uploads and processed outputs
- **AWS Textract**: OCR for PDFs and images
- **AWS Rekognition**: Image analysis and moderation
- **Lambda**: S3 event triggers for automatic processing
- **SNS**: Email notifications
- **DynamoDB**: Celery result backend
- **ECS Fargate**: Container orchestration for workers
- **CloudWatch**: Logging and monitoring

## Project Structure

```
.
├── api/                    # FastAPI application
│   ├── main.py            # API endpoints
│   ├── models.py          # Pydantic models
│   └── config.py          # Configuration
├── worker/                 # Celery workers
│   ├── celery_app.py      # Celery configuration
│   ├── tasks.py           # Processing tasks
│   └── processors/        # Processing modules
├── lambda/                 # Lambda functions
│   └── s3_trigger.py      # S3 event handler
├── terraform/              # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── ecs.tf
│   ├── s3.tf
│   ├── lambda.tf
│   ├── dynamodb.tf
│   ├── sns.tf
│   └── iam.tf
├── docker/                 # Docker configurations
│   ├── api.Dockerfile
│   └── worker.Dockerfile
├── deploy.sh              # Deployment script
├── cleanup.sh             # Cleanup script
└── requirements.txt       # Python dependencies
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

### Upload File
```bash
POST /upload
Content-Type: multipart/form-data

curl -X POST http://API_URL/upload \
  -F "file=@document.pdf" \
  -F "notification_email=user@example.com"
```

### Check Status
```bash
GET /status/{job_id}

curl http://API_URL/status/abc-123-def
```

### Get Results
```bash
GET /results/{job_id}

curl http://API_URL/results/abc-123-def
```

## Processing Features

- **OCR**: Extract text from PDFs and images using AWS Textract
- **Thumbnails**: Generate thumbnails for images and videos
- **Metadata**: Extract file metadata (size, type, dimensions, duration)
- **Image Analysis**: Detect labels and content moderation via Rekognition
- **Notifications**: Email alerts when processing completes

## Cleanup

To destroy all AWS resources:
```bash
chmod +x cleanup.sh
./cleanup.sh
```

## Monitoring

- **CloudWatch Logs**: `/aws/ecs/doc-processor-api` and `/aws/ecs/doc-processor-worker`
- **CloudWatch Metrics**: ECS service metrics, Lambda invocations
- **DynamoDB**: Check `celery-results` table for task status

## Security

- IAM roles with least privilege
- VPC with private subnets for workers
- S3 bucket encryption
- API authentication (add your own auth middleware)

## Cost Optimization

- ECS Fargate Spot instances for workers
- S3 lifecycle policies for old files
- CloudWatch log retention policies
- Auto-scaling based on queue depth

## License

MIT
