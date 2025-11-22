# Complete Deployment Guide - Full Stack Document Processor

## 🎯 Overview

This is a **complete, production-ready document processing system** with:
- ✅ **Backend API** - FastAPI with authentication
- ✅ **Workers** - Celery workers for async processing
- ✅ **Frontend** - React SPA with modern UI
- ✅ **Infrastructure** - All AWS resources via Terraform
- ✅ **Single Command Deployment** - Everything deploys with `./deploy.sh`

## 📦 What You Get

### Frontend Application
- **Authentication**: Signup/Login with DynamoDB
- **File Upload**: Drag-and-drop interface
- **Real-time Progress**: Auto-updating status
- **Results Viewer**: OCR text, metadata, thumbnails, labels
- **Hosted on**: S3 + CloudFront CDN

### Backend Services
- **FastAPI**: REST API with auth endpoints
- **Celery Workers**: Async document processing
- **AWS Textract**: OCR text extraction
- **AWS Rekognition**: Image analysis and moderation
- **DynamoDB**: User data, jobs, results
- **S3**: Document storage
- **SQS**: Task queue
- **Lambda**: S3 event triggers

## 🚀 Quick Start (Single Command)

### Prerequisites

Install these tools:

```bash
# macOS
brew install awscli terraform jq node

# Verify installations
aws --version
terraform --version
docker --version
node --version
npm --version
```

### Deploy Everything

```bash
# 1. Set AWS profile
export AWS_PROFILE=personal_new
export AWS_REGION=us-east-1

# 2. Clone and navigate
cd /Users/sandipdas/aws_project_8

# 3. Deploy (this does EVERYTHING)
chmod +x deploy.sh
./deploy.sh
```

**That's it!** The script will:
1. ✅ Build Docker images for API and Worker
2. ✅ Push images to ECR
3. ✅ Deploy all AWS infrastructure (Terraform)
4. ✅ Build React frontend
5. ✅ Upload frontend to S3
6. ✅ Configure CloudFront CDN
7. ✅ Output all URLs and endpoints

**Time**: 15-20 minutes

## 📊 Deployment Output

After deployment, you'll see:

```
========================================
Deployment Summary
========================================
Backend API: http://doc-processor-alb-XXXXX.us-east-1.elb.amazonaws.com
Frontend URL: https://XXXXX.cloudfront.net
S3 Bucket: aws-celery-demo
Region: us-east-1

========================================
Next Steps:
========================================
1. Access the frontend:
   https://XXXXX.cloudfront.net

2. Create an account and start uploading documents!

3. Check CloudWatch logs:
   aws logs tail /aws/ecs/doc-processor-api --follow
   aws logs tail /aws/ecs/doc-processor-worker --follow
```

## 🎨 Using the Application

### 1. Access Frontend

Visit the CloudFront URL from deployment output:
```
https://YOUR-DISTRIBUTION.cloudfront.net
```

### 2. Create Account

- Click "create a new account"
- Enter name, email, password
- Click "Sign up"

### 3. Upload Document

- Drag and drop a file (or click browse)
- Supported formats:
  - **PDF** documents
  - **Images**: PNG, JPG, GIF, WebP, TIFF, BMP
  - **Videos**: MP4, MOV, AVI
- Click "Upload and Process"

### 4. Watch Progress

- Job appears in "Recent Jobs" list
- Progress bar shows 0-100%
- Status updates every 3 seconds
- Stages:
  - 🟡 Pending
  - 🔵 Processing (20% → 40% → 70% → 100%)
  - 🟢 Completed
  - 🔴 Failed (if error)

### 5. View Results

Click on completed job to see:
- **Document Info**: Type, size, dates
- **Metadata**: Pages, author, creator, etc.
- **OCR Text**: Full extracted text
- **Thumbnail**: Preview image
- **Labels**: AI-detected objects (for images)

## 🏗️ Infrastructure Created

### Compute
- **ECS Fargate Cluster** - Runs API and Worker containers
- **Application Load Balancer** - Routes traffic to API
- **Lambda Function** - Triggers on S3 uploads

### Storage
- **S3 Bucket (Documents)** - Uploaded files and processed results
- **S3 Bucket (Frontend)** - Static website files
- **DynamoDB (Jobs)** - Job tracking and status
- **DynamoDB (Users)** - User authentication
- **DynamoDB (Results)** - Celery task results

### Networking
- **VPC** - Isolated network (10.0.0.0/16)
- **Public Subnets** - For ALB
- **Private Subnets** - For ECS tasks
- **NAT Gateway** - Outbound internet for private subnets
- **Security Groups** - Firewall rules

### Content Delivery
- **CloudFront Distribution** - CDN for frontend
- **S3 Website Hosting** - Static site origin

### Messaging & Queue
- **SQS Queue** - Celery task queue
- **SQS DLQ** - Dead letter queue
- **SNS Topic** - Email notifications

### Monitoring
- **CloudWatch Logs** - API, Worker, Lambda logs
- **CloudWatch Metrics** - Performance metrics

### Container Registry
- **ECR Repositories** - Docker images for API and Worker

## 💰 Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| ECS Fargate (2 tasks) | $30-50 |
| Application Load Balancer | $16 |
| NAT Gateway | $32 |
| CloudFront | $1-5 |
| S3 (100GB) | $2.30 |
| DynamoDB (on-demand) | $1-10 |
| Other services | $5-10 |
| **Total** | **~$87-125/month** |

**Free Tier Eligible**: SQS, Lambda, SNS (first year)

## 🔧 Post-Deployment

### Update Backend Code

```bash
# After changing API or Worker code
AWS_PROFILE=personal_new make update-images
```

### Update Frontend

```bash
# After changing frontend code
cd frontend
npm run build
cd ..
AWS_PROFILE=personal_new ./deploy.sh
# (Frontend section will rebuild and redeploy)
```

### View Logs

```bash
# API logs
make logs-api

# Worker logs
make logs-worker

# Lambda logs
make logs-lambda
```

### Test API Directly

```bash
# Run test script
./test_api.sh

# Or manual test
API_URL=$(cd terraform && terraform output -raw api_endpoint)
curl $API_URL/health
```

## 📁 Project Structure

```
aws_project_8/
├── api/                    # FastAPI application
│   ├── main.py            # API endpoints + auth
│   ├── config.py          # Configuration
│   └── models.py          # Pydantic models
├── worker/                # Celery workers
│   ├── tasks.py           # Processing tasks
│   ├── celery_app.py      # Celery config
│   └── processors/        # Document processors
├── frontend/              # React application
│   ├── src/
│   │   ├── components/    # React components
│   │   ├── services/      # API client
│   │   └── context/       # Auth context
│   ├── package.json       # Dependencies
│   └── vite.config.js     # Build config
├── terraform/             # Infrastructure as Code
│   ├── main.tf           # Main config
│   ├── ecs.tf            # ECS services
│   ├── frontend.tf       # S3 + CloudFront
│   ├── users.tf          # Users DynamoDB
│   └── outputs.tf        # Output values
├── docker/               # Dockerfiles
│   ├── api.Dockerfile
│   └── worker.Dockerfile
├── deploy.sh             # Main deployment script
├── cleanup.sh            # Cleanup script
└── Makefile             # Make commands
```

## 🛠️ Troubleshooting

### Frontend Not Loading

**Issue**: CloudFront shows error or old content

**Solution**:
```bash
# Get distribution ID
DIST_ID=$(cd terraform && terraform output -raw cloudfront_distribution_id)

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"
```

### API Not Responding

**Issue**: API endpoint returns errors

**Solution**:
```bash
# Check ECS tasks are running
aws ecs list-tasks --cluster doc-processor-cluster

# Check logs
make logs-api
```

### Jobs Stuck in Processing

**Issue**: Jobs don't complete

**Solution**:
```bash
# Check worker logs
make logs-worker

# Check SQS queue
aws sqs get-queue-attributes \
  --queue-url $(cd terraform && terraform output -raw sqs_queue_url) \
  --attribute-names All
```

### Authentication Fails

**Issue**: Cannot signup or login

**Solution**:
```bash
# Verify users table exists
aws dynamodb describe-table --table-name doc-processor-users

# Check API logs for errors
make logs-api
```

## 🔐 Security Notes

### Production Recommendations

1. **HTTPS**: Add custom domain with SSL certificate
2. **Password Hashing**: Upgrade from SHA-256 to bcrypt/Argon2
3. **Token Management**: Implement JWT with expiration
4. **CORS**: Restrict to specific frontend domain
5. **API Keys**: Add rate limiting and API keys
6. **Secrets**: Use AWS Secrets Manager for sensitive data
7. **IAM**: Follow principle of least privilege

### Current Security Features

- ✅ Token-based authentication
- ✅ Password hashing (SHA-256)
- ✅ Private subnets for workers
- ✅ Security groups for network isolation
- ✅ CloudFront for DDoS protection
- ✅ S3 bucket policies

## 📚 Additional Documentation

- **[README.md](README.md)** - Project overview
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Detailed deployment
- **[FRONTEND_SETUP.md](FRONTEND_SETUP.md)** - Frontend development
- **[USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)** - API usage examples
- **[FINAL_SUMMARY.md](FINAL_SUMMARY.md)** - Complete project summary

## 🎉 Success Checklist

After deployment, verify:

- [ ] Frontend loads at CloudFront URL
- [ ] Can create new account
- [ ] Can login successfully
- [ ] Can upload document
- [ ] Progress updates in real-time
- [ ] Job completes successfully
- [ ] Can view results (OCR text, metadata, etc.)
- [ ] API health check responds
- [ ] CloudWatch logs show activity

## 🚨 Cleanup

To destroy all resources:

```bash
./cleanup.sh
```

This will:
1. Empty S3 buckets
2. Delete ECR images
3. Destroy all Terraform resources
4. Remove local state files

**Warning**: This is irreversible!

## 🆘 Support

If you encounter issues:

1. Check logs: `make logs-api` or `make logs-worker`
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Check Terraform state: `cd terraform && terraform show`
4. Review deployment output for errors

## 🎯 Next Steps

Now that your system is deployed:

1. **Customize Frontend**: Update colors, branding in `frontend/src`
2. **Add Features**: Extend API with new endpoints
3. **Scale**: Adjust ECS task counts in `terraform/ecs.tf`
4. **Monitor**: Set up CloudWatch alarms
5. **Optimize**: Review and optimize costs

---

**Congratulations! Your full-stack document processing system is live!** 🚀

Access your frontend at the CloudFront URL and start processing documents!
