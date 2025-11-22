# Frontend ECS Fargate Deployment

## Overview

The frontend is now deployed as an **ECS Fargate service** instead of S3 + CloudFront. This solves the mixed content issue since both frontend and backend are served over HTTP.

## Architecture

```
User → Frontend ALB (HTTP) → ECS Fargate (Nginx + React) → Backend ALB (HTTP) → API
```

### Components

1. **Docker Container**: Nginx serving built React app
2. **ECS Fargate**: Runs the frontend container
3. **Application Load Balancer**: Routes traffic to frontend
4. **ECR**: Stores frontend Docker image

## Benefits

✅ **No Mixed Content**: Both frontend and backend use HTTP  
✅ **Consistent Deployment**: All services deployed via ECS  
✅ **Auto-scaling**: Can scale frontend containers  
✅ **Health Checks**: Nginx health endpoint  
✅ **Centralized Logs**: CloudWatch logs for frontend  

## Deployment

### Automatic (via deploy.sh)

```bash
./deploy.sh
```

This will:
1. Build frontend Docker image
2. Push to ECR
3. Deploy ECS service with ALB
4. Output frontend URL

### Manual Update

```bash
# Update all services (API, Worker, Frontend)
AWS_PROFILE=personal_new make update-images

# Or build and push frontend only
AWS_PROFILE=personal_new AWS_REGION=us-east-1 make build-frontend
```

## Frontend Container

### Dockerfile

- **Build stage**: Node.js builds React app
- **Production stage**: Nginx serves static files
- **Health check**: `/health` endpoint
- **Port**: 80

### Nginx Configuration

- **SPA routing**: All routes serve `index.html`
- **Gzip compression**: Enabled
- **Cache headers**: Static assets cached for 1 year
- **Security headers**: X-Frame-Options, X-Content-Type-Options

## Infrastructure

### Resources Created

- **ECR Repository**: `doc-processor-frontend`
- **ECS Task Definition**: 256 CPU, 512 MB memory
- **ECS Service**: 1 task (can scale)
- **Application Load Balancer**: Public-facing
- **Target Group**: Health checks on `/health`
- **Security Groups**: ALB and ECS task
- **CloudWatch Log Group**: `/aws/ecs/doc-processor-frontend`

### Environment Variables

The container receives `VITE_API_URL` automatically set to the backend ALB URL during build.

## Accessing the Frontend

After deployment:

```bash
# Get frontend URL
cd terraform
terraform output frontend_url

# Example output:
# http://doc-processor-frontend-alb-XXXXX.us-east-1.elb.amazonaws.com
```

Visit the URL in your browser to access the application.

## Monitoring

### Logs

```bash
# View frontend logs
make logs-frontend

# Or directly
aws logs tail /aws/ecs/doc-processor-frontend --follow
```

### Health Check

```bash
# Check frontend health
FRONTEND_URL=$(cd terraform && terraform output -raw frontend_url)
curl $FRONTEND_URL/health
```

### ECS Service Status

```bash
aws ecs describe-services \
  --cluster doc-processor-cluster \
  --services doc-processor-frontend-service \
  --region us-east-1
```

## Troubleshooting

### Frontend Not Loading

**Check ECS task status:**
```bash
aws ecs list-tasks \
  --cluster doc-processor-cluster \
  --service-name doc-processor-frontend-service
```

**Check logs:**
```bash
make logs-frontend
```

### 502 Bad Gateway

This means the ECS task is not healthy:

1. Check task is running
2. Check health check endpoint
3. Review logs for errors

### Frontend Shows Old Version

Force new deployment:

```bash
aws ecs update-service \
  --cluster doc-processor-cluster \
  --service doc-processor-frontend-service \
  --force-new-deployment \
  --region us-east-1
```

## Scaling

### Manual Scaling

Update desired count in `terraform/frontend.tf`:

```hcl
resource "aws_ecs_service" "frontend" {
  desired_count = 2  # Change from 1 to 2
  # ...
}
```

Then apply:

```bash
cd terraform
terraform apply
```

### Auto Scaling (Optional)

Add auto-scaling configuration:

```hcl
resource "aws_appautoscaling_target" "frontend" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "frontend-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

## Cost

**Frontend ECS Service:**
- **Fargate**: ~$10-15/month (1 task, 256 CPU, 512 MB)
- **ALB**: ~$16/month
- **Data Transfer**: ~$0.09/GB

**Total**: ~$26-31/month for frontend

**Comparison to S3 + CloudFront:**
- S3 + CloudFront: ~$1-5/month
- ECS: ~$26-31/month

**Trade-off**: Higher cost but solves mixed content issue and provides consistent deployment model.

## Future Improvements

### Add HTTPS

To enable HTTPS on both frontend and backend:

1. Get a domain name
2. Request SSL certificates in ACM
3. Add HTTPS listeners to both ALBs
4. Update security groups for port 443

See `MIXED_CONTENT_FIX.md` for detailed steps.

### Use CloudFront with ECS

For better performance:

1. Keep ECS Fargate for frontend
2. Add CloudFront in front of frontend ALB
3. Use CloudFront's free SSL certificate
4. Both frontend and backend still HTTP internally

### Optimize Container

- Use multi-stage build (already done)
- Minimize image size
- Use Alpine Linux (already done)
- Enable Nginx caching

## Summary

The frontend is now:
- ✅ Deployed as ECS Fargate service
- ✅ Served via Application Load Balancer
- ✅ No mixed content errors (HTTP to HTTP)
- ✅ Consistent with backend deployment
- ✅ Easy to update and scale
- ✅ Centralized logging and monitoring

Access your frontend at the ALB URL and enjoy a fully functional document processing application!
