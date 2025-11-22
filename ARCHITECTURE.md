# System Architecture

## Overview

This document describes the architecture of the AWS Document Processing Service, a scalable, serverless-first system for asynchronous document, image, and video processing.

## High-Level Architecture

```
┌─────────────┐
│   Client    │
│ Application │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud (VPC)                          │
│                                                             │
│  ┌──────────────┐         ┌──────────────────────────┐    │
│  │     ALB      │────────▶│    ECS Fargate (API)     │    │
│  │  (Public)    │         │   FastAPI Application    │    │
│  └──────────────┘         └───────────┬──────────────┘    │
│                                        │                    │
│                                        ▼                    │
│                            ┌────────────────────┐          │
│                            │    Amazon S3       │          │
│                            │  Document Storage  │          │
│                            └─────────┬──────────┘          │
│                                      │                      │
│                                      │ S3 Event             │
│                                      ▼                      │
│                            ┌────────────────────┐          │
│                            │  Lambda Function   │          │
│                            │   S3 Trigger       │          │
│                            └─────────┬──────────┘          │
│                                      │                      │
│                                      ▼                      │
│                            ┌────────────────────┐          │
│                            │    Amazon SQS      │          │
│                            │   Celery Broker    │          │
│                            └─────────┬──────────┘          │
│                                      │                      │
│                                      ▼                      │
│                      ┌──────────────────────────┐          │
│                      │  ECS Fargate (Workers)   │          │
│                      │   Celery Workers         │          │
│                      └────────┬─────────────────┘          │
│                               │                             │
│                               ├──────────────┐             │
│                               ▼              ▼             │
│                      ┌─────────────┐  ┌──────────────┐    │
│                      │  Textract   │  │ Rekognition  │    │
│                      │    (OCR)    │  │   (Vision)   │    │
│                      └─────────────┘  └──────────────┘    │
│                                                             │
│  ┌──────────────┐         ┌──────────────────────────┐    │
│  │  DynamoDB    │         │      Amazon SNS          │    │
│  │ Job Tracking │         │    Notifications         │    │
│  └──────────────┘         └──────────────────────────┘    │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │           CloudWatch Logs & Metrics              │     │
│  └──────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. API Layer (FastAPI on ECS Fargate)

**Purpose**: REST API for file uploads and job management

**Endpoints**:
- `POST /upload` - Upload files for processing
- `GET /status/{job_id}` - Check processing status
- `GET /results/{job_id}` - Retrieve processing results
- `GET /health` - Health check
- `DELETE /jobs/{job_id}` - Delete job and files

**Technology**:
- FastAPI (Python)
- Uvicorn ASGI server
- ECS Fargate (serverless containers)
- Application Load Balancer

**Scaling**:
- Auto-scales based on CPU/Memory
- Stateless design for horizontal scaling

### 2. Storage Layer (Amazon S3)

**Purpose**: Durable storage for uploaded and processed files

**Structure**:
```
s3://bucket-name/
├── uploads/
│   └── {job_id}/
│       └── {filename}
└── processed/
    └── {job_id}/
        ├── thumbnail.jpg
        └── results.json
```

**Features**:
- Server-side encryption (AES-256)
- Versioning enabled
- Lifecycle policies:
  - Uploads deleted after 30 days
  - Processed files → Glacier after 90 days
  - Permanent deletion after 365 days

### 3. Event Processing (Lambda)

**Purpose**: Trigger processing when files are uploaded

**Flow**:
1. S3 emits ObjectCreated event
2. Lambda receives event
3. Lambda enqueues Celery task to SQS
4. Returns immediately (async processing)

**Configuration**:
- Runtime: Python 3.11
- Memory: 256 MB
- Timeout: 60 seconds
- Trigger: S3 ObjectCreated events on `uploads/` prefix

### 4. Task Queue (Amazon SQS)

**Purpose**: Reliable message broker for Celery

**Configuration**:
- Visibility timeout: 3600s (1 hour)
- Message retention: 14 days
- Long polling: 20 seconds
- Dead Letter Queue for failed messages

**Features**:
- At-least-once delivery
- FIFO not required (idempotent workers)
- Automatic retry with exponential backoff

### 5. Worker Layer (Celery on ECS Fargate)

**Purpose**: Asynchronous document processing

**Tasks**:
- `process_document` - Main orchestration task
- `extract_text_ocr` - OCR via AWS Textract
- `generate_thumbnail` - Image/video thumbnails
- `extract_metadata` - File metadata extraction
- `analyze_image` - AWS Rekognition analysis
- `send_notification` - SNS email notifications

**Processing Pipeline**:
```
1. Download file from S3
2. Extract metadata (parallel)
3. Generate thumbnail (if applicable)
4. Run OCR (for documents/images)
5. Analyze image (for images)
6. Upload results to S3
7. Update DynamoDB status
8. Send SNS notification
9. Clean up temp files
```

**Scaling**:
- Auto-scales based on SQS queue depth
- Min: 2 workers
- Max: 10 workers
- Concurrency: 2 tasks per worker

### 6. AI/ML Services

#### AWS Textract
- Extract text from PDFs and images
- Table and form detection
- Multi-page document support

#### AWS Rekognition
- Object and scene detection
- Content moderation
- Text detection in images
- Face detection (optional)

### 7. Data Layer (DynamoDB)

#### Jobs Table
**Purpose**: Track job status and metadata

**Schema**:
```json
{
  "job_id": "uuid",
  "status": "pending|processing|completed|failed",
  "s3_key": "uploads/job_id/file.pdf",
  "file_name": "document.pdf",
  "file_size": 1024000,
  "file_type": "application/pdf",
  "notification_email": "user@example.com",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:05:00Z",
  "completed_at": "2024-01-01T00:05:00Z",
  "results": "{...}",
  "error": "error message if failed"
}
```

**Indexes**:
- Primary: `job_id`
- GSI: `status` + `created_at` (for querying by status)

#### Celery Results Table
**Purpose**: Store Celery task results

**Configuration**:
- TTL enabled (auto-delete old results)
- Pay-per-request billing

### 8. Notification Layer (Amazon SNS)

**Purpose**: Email notifications on job completion

**Flow**:
1. Worker completes processing
2. Publishes message to SNS topic
3. SNS delivers email to subscriber
4. User receives notification with results

**Message Format**:
```
Subject: Document Processing Completed: {job_id}
Body:
  Job ID: abc-123-def
  Status: completed
  Results:
    - OCR Text: 1234 characters
    - Thumbnail: https://...
    - Labels: [document, text, business]
```

### 9. Monitoring (CloudWatch)

**Logs**:
- `/aws/ecs/doc-processor-api` - API logs
- `/aws/ecs/doc-processor-worker` - Worker logs
- `/aws/lambda/doc-processor-s3-trigger` - Lambda logs

**Metrics**:
- ECS CPU/Memory utilization
- ALB request count and latency
- SQS queue depth and age
- Lambda invocations and errors
- DynamoDB read/write capacity

**Alarms** (recommended):
- API error rate > 5%
- Worker CPU > 80%
- SQS queue depth > 100
- Lambda errors > 10/min

## Network Architecture

### VPC Configuration

```
VPC: 10.0.0.0/16

Public Subnets (2 AZs):
├── 10.0.1.0/24 (us-east-1a)
└── 10.0.2.0/24 (us-east-1b)
    └── ALB, NAT Gateways

Private Subnets (2 AZs):
├── 10.0.10.0/24 (us-east-1a)
└── 10.0.11.0/24 (us-east-1b)
    └── ECS Tasks (API + Workers)
```

**Security Groups**:
- ALB SG: Allow 80/443 from internet
- ECS SG: Allow 8000 from ALB SG only
- Egress: Allow all (for AWS service access)

**VPC Endpoints**:
- S3 Gateway Endpoint (cost optimization)
- Optional: Interface endpoints for other services

## Data Flow

### Upload Flow

```
1. Client → ALB → API
2. API validates file
3. API uploads to S3 (uploads/{job_id}/file)
4. API creates DynamoDB record
5. API returns job_id to client
6. S3 → Lambda (event trigger)
7. Lambda → SQS (enqueue task)
8. Worker polls SQS
9. Worker processes file
10. Worker updates DynamoDB
11. Worker sends SNS notification
```

### Processing Flow

```
Worker receives task from SQS
├─→ Download file from S3
├─→ Extract metadata
│   └─→ File size, type, dimensions
├─→ Generate thumbnail
│   ├─→ Images: PIL resize
│   ├─→ Videos: ffmpeg frame extract
│   └─→ PDFs: pdf2image + resize
├─→ Run OCR (if applicable)
│   └─→ AWS Textract DetectDocumentText
├─→ Analyze image (if applicable)
│   ├─→ AWS Rekognition DetectLabels
│   ├─→ AWS Rekognition DetectModerationLabels
│   └─→ AWS Rekognition DetectText
├─→ Upload results to S3
├─→ Update DynamoDB (status=completed)
└─→ Send SNS notification
```

## Scalability

### Horizontal Scaling

| Component | Min | Max | Trigger |
|-----------|-----|-----|---------|
| API Tasks | 1 | 10 | CPU > 70% |
| Worker Tasks | 2 | 10 | SQS depth > 10 |
| Lambda | 0 | 1000 | Concurrent invocations |

### Vertical Scaling

| Component | CPU | Memory |
|-----------|-----|--------|
| API | 512 | 1024 MB |
| Worker | 1024 | 2048 MB |
| Lambda | N/A | 256 MB |

### Performance Characteristics

- **API Latency**: < 100ms (upload endpoint)
- **Processing Time**: 
  - Small image: 10-30 seconds
  - PDF document: 30-60 seconds
  - Video: 1-5 minutes
- **Throughput**: 100+ concurrent jobs
- **Max File Size**: 100 MB (configurable)

## Fault Tolerance

### High Availability

- Multi-AZ deployment (2 AZs)
- ALB health checks
- ECS task auto-recovery
- SQS message retry (3 attempts)
- Dead Letter Queue for failed messages

### Error Handling

1. **API Errors**: Return HTTP error codes
2. **Worker Errors**: 
   - Retry with exponential backoff
   - Move to DLQ after 3 failures
   - Update job status to "failed"
3. **AWS Service Errors**: 
   - Boto3 automatic retry
   - Circuit breaker pattern

### Data Durability

- S3: 99.999999999% (11 9's)
- DynamoDB: 99.999999999% (11 9's)
- SQS: Message persistence
- ECS: Stateless (no data loss on restart)

## Security

### Authentication & Authorization

- **API**: No auth by default (add your own)
- **AWS Services**: IAM roles (least privilege)
- **Inter-service**: VPC security groups

### Encryption

- **At Rest**:
  - S3: AES-256
  - DynamoDB: AWS managed keys
  - EBS: Encrypted
- **In Transit**:
  - ALB → ECS: HTTP (add HTTPS)
  - All AWS APIs: TLS 1.2+

### IAM Roles

```
ECS Task Execution Role:
└─→ Pull ECR images
└─→ Write CloudWatch logs

API Task Role:
├─→ S3: Read/Write
├─→ DynamoDB: Read/Write (jobs table)
└─→ SQS: SendMessage

Worker Task Role:
├─→ S3: Read/Write
├─→ DynamoDB: Read/Write (both tables)
├─→ SQS: ReceiveMessage, DeleteMessage
├─→ Textract: DetectDocumentText, AnalyzeDocument
├─→ Rekognition: DetectLabels, DetectModerationLabels
└─→ SNS: Publish

Lambda Execution Role:
├─→ S3: GetObject
├─→ SQS: SendMessage
└─→ CloudWatch: Logs
```

## Cost Optimization

### Strategies

1. **Fargate Spot**: 70% savings for workers
2. **S3 Lifecycle**: Auto-archive old files
3. **DynamoDB On-Demand**: Pay per request
4. **VPC Endpoints**: Reduce NAT costs
5. **CloudWatch Retention**: 7 days (configurable)
6. **ECR Lifecycle**: Keep last 10 images

### Estimated Monthly Cost

**Assumptions**: 10,000 documents/month, avg 5MB each

| Service | Cost |
|---------|------|
| ECS Fargate (API) | $15 |
| ECS Fargate (Workers) | $30 |
| ALB | $16 |
| S3 Storage (50GB) | $1.15 |
| S3 Requests | $0.50 |
| DynamoDB | $2.50 |
| SQS | Free tier |
| Lambda | Free tier |
| Textract (10K pages) | $15 |
| Rekognition (10K images) | $10 |
| SNS | $2 |
| CloudWatch | $5 |
| Data Transfer | $5 |
| **Total** | **~$102/month** |

## Disaster Recovery

### Backup Strategy

- **S3**: Versioning enabled
- **DynamoDB**: Point-in-time recovery
- **Infrastructure**: Terraform state in S3

### Recovery Procedures

1. **Complete Failure**: Redeploy via Terraform
2. **Data Loss**: Restore from S3 versions
3. **Region Failure**: Deploy to new region

**RTO**: 30 minutes  
**RPO**: 0 (no data loss with versioning)

## Future Enhancements

### Planned Features

1. **API Authentication**: JWT/OAuth2
2. **Rate Limiting**: Per-user quotas
3. **Webhooks**: Alternative to SNS
4. **Batch Processing**: Process multiple files
5. **Custom Models**: Bring your own ML models
6. **Real-time Updates**: WebSocket support
7. **Multi-region**: Global deployment

### Performance Improvements

1. **Caching**: Redis for API responses
2. **CDN**: CloudFront for processed files
3. **Async Upload**: Direct S3 upload with presigned URLs
4. **Parallel Processing**: Split large files

## Maintenance

### Regular Tasks

- **Weekly**: Review CloudWatch metrics
- **Monthly**: Check cost reports
- **Quarterly**: Update dependencies
- **Annually**: Review architecture

### Updates

```bash
# Update application code
git pull
./deploy.sh

# Update infrastructure
cd terraform
terraform plan
terraform apply

# Update dependencies
pip install --upgrade -r requirements.txt
```

## Conclusion

This architecture provides a scalable, fault-tolerant, and cost-effective solution for document processing. The serverless-first approach minimizes operational overhead while maintaining high availability and performance.
