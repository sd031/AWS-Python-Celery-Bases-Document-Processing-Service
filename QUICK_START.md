# Quick Start Guide

Get the Document Processing Service running in under 15 minutes.

## Prerequisites (5 minutes)

```bash
# 1. Install AWS CLI
brew install awscli  # macOS
# or download from: https://aws.amazon.com/cli/

# 2. Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output (json)

# 3. Install Terraform
brew install terraform  # macOS

# 4. Verify Docker is running
docker ps
```

## Deploy (10 minutes)

```bash
# 1. Navigate to project
cd /Users/sandipdas/aws_project_8

# 2. Run deployment script
chmod +x deploy.sh
./deploy.sh

# You'll be prompted for:
# - S3 bucket name (must be globally unique)
# - Notification email (optional)

# Wait for deployment to complete...
```

## Test (2 minutes)

```bash
# 1. Get API endpoint from deployment output
# It will look like: http://doc-processor-alb-123456789.us-east-1.elb.amazonaws.com

# 2. Test health endpoint
curl http://YOUR-ALB-DNS/health

# 3. Upload a test file
curl -X POST http://YOUR-ALB-DNS/upload \
  -F "file=@/path/to/document.pdf" \
  -F "notification_email=your@email.com"

# Response will include job_id:
# {"job_id":"abc-123-def","message":"File uploaded successfully..."}

# 4. Check status
curl http://YOUR-ALB-DNS/status/abc-123-def

# 5. Get results (wait ~30 seconds for processing)
curl http://YOUR-ALB-DNS/results/abc-123-def
```

## Using the Test Script

```bash
chmod +x test_api.sh
./test_api.sh
```

## Common Commands

```bash
# View API logs
make logs-api

# View worker logs
make logs-worker

# Check deployment status
make status

# Redeploy after code changes
make deploy

# Clean up everything
make cleanup
```

## API Examples

### Upload Image
```bash
curl -X POST http://YOUR-ALB-DNS/upload \
  -F "file=@photo.jpg" \
  -F "notification_email=user@example.com"
```

### Upload PDF
```bash
curl -X POST http://YOUR-ALB-DNS/upload \
  -F "file=@document.pdf"
```

### Upload Video
```bash
curl -X POST http://YOUR-ALB-DNS/upload \
  -F "file=@video.mp4"
```

### Check Status
```bash
curl http://YOUR-ALB-DNS/status/{job_id}
```

### Get Results
```bash
curl http://YOUR-ALB-DNS/results/{job_id} | jq .
```

### Delete Job
```bash
curl -X DELETE http://YOUR-ALB-DNS/jobs/{job_id}
```

## Expected Processing Times

| File Type | Size | Time |
|-----------|------|------|
| Image (JPG) | 1 MB | 10-20s |
| PDF (10 pages) | 5 MB | 30-60s |
| Video (1 min) | 50 MB | 1-3 min |

## Monitoring

### CloudWatch Logs
```bash
# API logs
aws logs tail /aws/ecs/doc-processor-api --follow

# Worker logs
aws logs tail /aws/ecs/doc-processor-worker --follow

# Lambda logs
aws logs tail /aws/lambda/doc-processor-s3-trigger --follow
```

### Check S3 Bucket
```bash
aws s3 ls s3://YOUR-BUCKET-NAME/uploads/
aws s3 ls s3://YOUR-BUCKET-NAME/processed/
```

### Check DynamoDB
```bash
# List all jobs
aws dynamodb scan --table-name doc-processor-jobs

# Get specific job
aws dynamodb get-item \
  --table-name doc-processor-jobs \
  --key '{"job_id": {"S": "YOUR-JOB-ID"}}'
```

### Check SQS Queue
```bash
aws sqs get-queue-attributes \
  --queue-url YOUR-QUEUE-URL \
  --attribute-names ApproximateNumberOfMessages
```

## Troubleshooting

### Issue: Deployment fails with "bucket already exists"
**Solution**: S3 bucket names must be globally unique. Choose a different name.

### Issue: API returns 503
**Solution**: Wait 2-3 minutes for ECS tasks to start. Check logs:
```bash
make logs-api
```

### Issue: Files uploaded but not processing
**Solution**: Check worker logs and SQS queue:
```bash
make logs-worker
aws sqs get-queue-attributes --queue-url YOUR-QUEUE-URL --attribute-names All
```

### Issue: "Access Denied" errors
**Solution**: Verify AWS credentials have necessary permissions:
```bash
aws sts get-caller-identity
```

## Clean Up

```bash
# Destroy all resources
chmod +x cleanup.sh
./cleanup.sh

# Confirm with: yes
```

**Warning**: This permanently deletes all data and resources.

## Cost Estimate

For light usage (100 documents/month):
- **~$10-20/month**

For moderate usage (10,000 documents/month):
- **~$100-150/month**

## Next Steps

1. ✅ Deploy and test
2. 📖 Read [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for details
3. 🏗️ Review [ARCHITECTURE.md](ARCHITECTURE.md) for system design
4. 🔒 Add authentication to API
5. 🌐 Configure custom domain
6. 📊 Set up CloudWatch alarms
7. 🚀 Scale based on usage

## Support

- **Documentation**: See README.md, DEPLOYMENT_GUIDE.md, ARCHITECTURE.md
- **Logs**: Check CloudWatch logs for errors
- **AWS Console**: Monitor resources in AWS Console

## Useful Links

- [AWS ECS Console](https://console.aws.amazon.com/ecs/)
- [AWS S3 Console](https://console.aws.amazon.com/s3/)
- [AWS CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)
- [AWS Lambda Console](https://console.aws.amazon.com/lambda/)
- [Terraform Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**Happy Processing! 🚀**
