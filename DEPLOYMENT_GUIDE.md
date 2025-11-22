# Deployment Guide

This guide walks you through deploying the Document Processing Service to AWS.

## Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** >= 1.0 installed
   ```bash
   brew install terraform  # macOS
   ```
4. **Docker** installed and running with buildx support
   ```bash
   docker --version
   docker buildx version  # Should be available by default in Docker Desktop
   ```
   **Note**: The deployment builds images for `linux/amd64` architecture (required for ECS Fargate). If you're on an ARM Mac (M1/M2/M3), Docker will automatically use emulation.

5. **jq** (for testing scripts)
   ```bash
   brew install jq  # macOS
   ```

## Step-by-Step Deployment

### 1. Clone and Navigate to Project

```bash
cd /Users/sandipdas/aws_project_8
```

### 2. Configure Environment

The deployment script will prompt you for required configuration:
- **S3 Bucket Name**: Must be globally unique (e.g., `my-company-doc-processor-2024`)
- **Notification Email**: (Optional) Email for SNS notifications

Alternatively, create a `.env` file manually:

```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Run Deployment

```bash
chmod +x deploy.sh
./deploy.sh
```

The deployment script will:
1. ✓ Verify prerequisites
2. ✓ Create ECR repositories
3. ✓ Build Docker images
4. ✓ Push images to ECR
5. ✓ Deploy infrastructure via Terraform
6. ✓ Output API endpoint and resource details

**Estimated time**: 10-15 minutes

### 4. Verify Deployment

After deployment completes, test the API:

```bash
# Test health endpoint
curl http://YOUR-ALB-DNS/health

# Or use the test script
chmod +x test_api.sh
./test_api.sh
```

## What Gets Deployed

### AWS Resources

| Resource | Purpose | Estimated Cost |
|----------|---------|----------------|
| VPC | Network isolation | Free |
| ECS Fargate | API & Worker containers | ~$30-50/month |
| Application Load Balancer | API routing | ~$16/month |
| S3 Bucket | File storage | ~$0.023/GB |
| DynamoDB | Job tracking & results | Pay per request |
| SQS | Task queue | First 1M requests free |
| Lambda | S3 event trigger | First 1M requests free |
| SNS | Notifications | First 1,000 emails free |
| CloudWatch | Logs & monitoring | ~$0.50/GB |
| ECR | Docker images | ~$0.10/GB |

**Total estimated cost**: $50-100/month for moderate usage

### Architecture

```
Internet → ALB → ECS (API) → S3
                           → DynamoDB
                           → SQS
                           
S3 → Lambda → SQS → ECS (Workers) → Textract
                                  → Rekognition
                                  → SNS
```

## Post-Deployment Configuration

### 1. SNS Email Subscription

If you provided an email, confirm the SNS subscription:
1. Check your email for "AWS Notification - Subscription Confirmation"
2. Click the confirmation link

### 2. Custom Domain (Optional)

To use a custom domain:

```bash
# Add to terraform/variables.tf
variable "domain_name" {
  default = "api.yourdomain.com"
}

# Add Route53 and ACM resources
# See: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
```

### 3. Enable HTTPS (Recommended)

```bash
# Request ACM certificate
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS

# Update ALB listener in terraform/ecs.tf to use HTTPS
```

### 4. Adjust Scaling

Edit `terraform/terraform.tfvars`:

```hcl
worker_desired_count = 5  # Increase workers
api_desired_count = 2     # Multiple API instances
```

Then redeploy:

```bash
cd terraform
terraform apply
```

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

### CloudWatch Metrics

View in AWS Console:
- ECS Service CPU/Memory utilization
- ALB request count and latency
- SQS queue depth
- Lambda invocations

### DynamoDB Tables

```bash
# List jobs
aws dynamodb scan --table-name doc-processor-jobs

# Get specific job
aws dynamodb get-item \
  --table-name doc-processor-jobs \
  --key '{"job_id": {"S": "YOUR-JOB-ID"}}'
```

## Troubleshooting

### Issue: API not responding

**Check ECS tasks:**
```bash
aws ecs list-tasks --cluster doc-processor-cluster
aws ecs describe-tasks --cluster doc-processor-cluster --tasks TASK-ARN
```

**Check logs:**
```bash
aws logs tail /aws/ecs/doc-processor-api --follow
```

### Issue: Workers not processing

**Check SQS queue:**
```bash
aws sqs get-queue-attributes \
  --queue-url YOUR-QUEUE-URL \
  --attribute-names All
```

**Check worker logs:**
```bash
aws logs tail /aws/ecs/doc-processor-worker --follow
```

### Issue: Deployment fails

**Common causes:**
1. S3 bucket name already exists (must be globally unique)
2. AWS credentials not configured
3. Insufficient IAM permissions
4. Docker not running
5. Docker image architecture mismatch

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Docker
docker ps

# Verify Docker buildx support (for multi-arch builds)
docker buildx version

# Clean up and retry
./cleanup.sh
./deploy.sh
```

### Issue: ECS tasks failing with "exec format error"

**Cause:** Docker images built for wrong architecture (ARM instead of x86_64)

**Solution:** The deployment script now automatically builds for `linux/amd64`. If you built images manually, rebuild:
```bash
docker build --platform linux/amd64 -f docker/api.Dockerfile -t doc-processor-api:latest .
docker build --platform linux/amd64 -f docker/worker.Dockerfile -t doc-processor-worker:latest .
```

## Updating the Application

### Update Code

```bash
# Make code changes
# Then rebuild and redeploy

./deploy.sh  # Rebuilds images and updates ECS
```

### Update Infrastructure

```bash
# Edit terraform/*.tf files
cd terraform
terraform plan
terraform apply
```

## Cost Optimization

### 1. Use Fargate Spot

Edit `terraform/ecs.tf`:

```hcl
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight           = 1
}
```

### 2. Reduce Worker Count

```bash
# In terraform.tfvars
worker_desired_count = 1
```

### 3. Enable S3 Lifecycle

Already configured to:
- Delete uploads after 30 days
- Move processed files to Glacier after 90 days

### 4. Set CloudWatch Log Retention

Already set to 7 days. Adjust in `terraform/ecs.tf`:

```hcl
retention_in_days = 3  # Reduce to 3 days
```

## Cleanup

To destroy all resources:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

**Warning**: This will permanently delete:
- All uploaded files in S3
- All job records in DynamoDB
- All Docker images in ECR
- All infrastructure resources

## Security Best Practices

1. **Enable VPC Flow Logs**
2. **Use AWS Secrets Manager** for sensitive data
3. **Enable S3 bucket versioning** (already enabled)
4. **Implement API authentication** (add your own middleware)
5. **Use HTTPS** with ACM certificates
6. **Enable CloudTrail** for audit logging
7. **Implement rate limiting** in API

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review Terraform state: `cd terraform && terraform show`
3. Check AWS Console for resource status

## Next Steps

1. ✓ Deploy the application
2. ✓ Test with sample files
3. ✓ Configure monitoring alerts
4. ✓ Set up custom domain
5. ✓ Implement authentication
6. ✓ Add more processing features
