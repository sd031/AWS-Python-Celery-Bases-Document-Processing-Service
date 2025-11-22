#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="doc-processor"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Document Processing Service Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"

# Load or create .env file
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    
    # Prompt for S3 bucket name
    read -p "Enter S3 bucket name (must be globally unique): " S3_BUCKET_NAME
    
    # Prompt for notification email (optional)
    read -p "Enter notification email (optional, press Enter to skip): " NOTIFICATION_EMAIL
    
    cat > .env << EOF
AWS_REGION=${AWS_REGION}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
S3_UPLOAD_PREFIX=uploads/
S3_PROCESSED_PREFIX=processed/
CELERY_BROKER_URL=sqs://
CELERY_RESULT_BACKEND=dynamodb://
DYNAMODB_TABLE_NAME=${PROJECT_NAME}-celery-results
JOBS_TABLE_NAME=${PROJECT_NAME}-jobs
SNS_TOPIC_ARN=
API_HOST=0.0.0.0
API_PORT=8000
API_WORKERS=4
MAX_FILE_SIZE=104857600
ALLOWED_EXTENSIONS=pdf,png,jpg,jpeg,gif,mp4,mov,avi
THUMBNAIL_SIZE=300,300
ENVIRONMENT=production
LOG_LEVEL=INFO
EOF
    
    echo -e "${GREEN}✓ Created .env file${NC}"
else
    echo -e "${GREEN}✓ Using existing .env file${NC}"
    source .env
fi

# Create terraform.tfvars
echo -e "\n${YELLOW}Creating Terraform variables...${NC}"
cat > terraform/terraform.tfvars << EOF
aws_region          = "${AWS_REGION}"
project_name        = "${PROJECT_NAME}"
environment         = "production"
s3_bucket_name      = "${S3_BUCKET_NAME}"
notification_email  = "${NOTIFICATION_EMAIL}"
api_cpu             = 512
api_memory          = 1024
worker_cpu          = 1024
worker_memory       = 2048
worker_desired_count = 2
api_desired_count   = 1
EOF

echo -e "${GREEN}✓ Created terraform.tfvars${NC}"

# Initialize Terraform
echo -e "\n${YELLOW}Initializing Terraform...${NC}"
cd terraform
terraform init

# Create ECR repositories first
echo -e "\n${YELLOW}Creating ECR repositories...${NC}"
terraform apply -target=aws_ecr_repository.api -target=aws_ecr_repository.worker -auto-approve

# Get ECR repository URLs
API_REPO=$(terraform output -raw ecr_api_repository)
WORKER_REPO=$(terraform output -raw ecr_worker_repository)

echo -e "${GREEN}✓ ECR repositories created${NC}"
echo -e "  API: ${API_REPO}"
echo -e "  Worker: ${WORKER_REPO}"

cd ..

# Login to ECR
echo -e "\n${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
echo -e "${GREEN}✓ Logged in to ECR${NC}"

# Build and push API image
echo -e "\n${YELLOW}Building API Docker image for linux/amd64...${NC}"
docker build --platform linux/amd64 -f docker/api.Dockerfile -t ${PROJECT_NAME}-api:latest .
docker tag ${PROJECT_NAME}-api:latest ${API_REPO}:latest
echo -e "${GREEN}✓ Built API image${NC}"

echo -e "\n${YELLOW}Pushing API image to ECR...${NC}"
docker push ${API_REPO}:latest
echo -e "${GREEN}✓ Pushed API image${NC}"

# Build and push Worker image
echo -e "\n${YELLOW}Building Worker Docker image for linux/amd64...${NC}"
docker build --platform linux/amd64 -f docker/worker.Dockerfile -t ${PROJECT_NAME}-worker:latest .
docker tag ${PROJECT_NAME}-worker:latest ${WORKER_REPO}:latest
echo -e "${GREEN}✓ Built Worker image${NC}"

echo -e "\n${YELLOW}Pushing Worker image to ECR...${NC}"
docker push ${WORKER_REPO}:latest
echo -e "${GREEN}✓ Pushed Worker image${NC}"

# Deploy infrastructure
echo -e "\n${YELLOW}Deploying infrastructure with Terraform...${NC}"
cd terraform
terraform apply -auto-approve

# Force ECS services to update with new images
echo -e "\n${YELLOW}Forcing ECS services to update with new images...${NC}"
aws ecs update-service \
  --cluster ${PROJECT_NAME}-cluster \
  --service ${PROJECT_NAME}-api-service \
  --force-new-deployment \
  --region ${AWS_REGION} > /dev/null 2>&1

aws ecs update-service \
  --cluster ${PROJECT_NAME}-cluster \
  --service ${PROJECT_NAME}-worker-service \
  --force-new-deployment \
  --region ${AWS_REGION} > /dev/null 2>&1

echo -e "${GREEN}✓ ECS services updating with new images${NC}"

# Get outputs
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

API_ENDPOINT=$(terraform output -raw api_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
SQS_QUEUE=$(terraform output -raw sqs_queue_url)

echo -e "\n${GREEN}API Endpoint:${NC} ${API_ENDPOINT}"
echo -e "${GREEN}S3 Bucket:${NC} ${S3_BUCKET}"
echo -e "${GREEN}SQS Queue:${NC} ${SQS_QUEUE}"

# Update .env with outputs
cd ..
SNS_TOPIC_ARN=$(cd terraform && terraform output -raw sns_topic_arn)
sed -i.bak "s|SNS_TOPIC_ARN=.*|SNS_TOPIC_ARN=${SNS_TOPIC_ARN}|" .env
rm -f .env.bak

echo -e "\n${YELLOW}Testing API endpoint...${NC}"
sleep 10  # Wait for services to be ready

if curl -s -f "${API_ENDPOINT}/health" > /dev/null; then
    echo -e "${GREEN}✓ API is healthy!${NC}"
else
    echo -e "${YELLOW}⚠ API might still be starting up. Please wait a few minutes and try again.${NC}"
fi

# Deploy Frontend
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Frontend${NC}"
echo -e "${GREEN}========================================${NC}"

if [ -d "frontend" ]; then
    echo -e "${YELLOW}Building and deploying frontend...${NC}"
    
    # Get frontend infrastructure info
    FRONTEND_BUCKET=$(cd terraform && terraform output -raw frontend_bucket 2>/dev/null || echo "")
    CLOUDFRONT_ID=$(cd terraform && terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    FRONTEND_URL=$(cd terraform && terraform output -raw frontend_url 2>/dev/null || echo "")
    
    if [ -z "$FRONTEND_BUCKET" ]; then
        echo -e "${YELLOW}Frontend infrastructure not found in outputs. Skipping frontend deployment.${NC}"
        echo -e "${YELLOW}Frontend will be available after Terraform creates the resources.${NC}"
    else
        echo -e "${GREEN}✓ Frontend Bucket: ${FRONTEND_BUCKET}${NC}"
        echo -e "${GREEN}✓ CloudFront Distribution: ${CLOUDFRONT_ID}${NC}"
        
        cd frontend
        
        # Check if Node.js is installed
        if ! command -v node &> /dev/null; then
            echo -e "${YELLOW}⚠ Node.js not installed. Skipping frontend build.${NC}"
            echo -e "${YELLOW}  Install Node.js and run: cd frontend && npm install && npm run build${NC}"
        else
            # Install dependencies if needed
            if [ ! -d "node_modules" ]; then
                echo -e "${YELLOW}Installing frontend dependencies...${NC}"
                npm install
            fi
            
            # Create .env file with API endpoint
            echo -e "${YELLOW}Configuring frontend environment...${NC}"
            cat > .env << EOF
VITE_API_URL=${API_ENDPOINT}
EOF
            echo -e "${GREEN}✓ Created .env file${NC}"
            
            # Build frontend
            echo -e "${YELLOW}Building frontend...${NC}"
            npm run build
            
            if [ -d "dist" ]; then
                echo -e "${GREEN}✓ Frontend built successfully${NC}"
                
                # Upload to S3
                echo -e "${YELLOW}Uploading to S3...${NC}"
                aws s3 sync dist/ s3://${FRONTEND_BUCKET}/ \
                    --delete \
                    --region ${AWS_REGION} \
                    --cache-control "public, max-age=31536000" \
                    --exclude "index.html"
                
                # Upload index.html with no-cache
                aws s3 cp dist/index.html s3://${FRONTEND_BUCKET}/index.html \
                    --region ${AWS_REGION} \
                    --cache-control "no-cache, no-store, must-revalidate" \
                    --content-type "text/html"
                
                echo -e "${GREEN}✓ Files uploaded to S3${NC}"
                
                # Invalidate CloudFront cache
                echo -e "${YELLOW}Invalidating CloudFront cache...${NC}"
                INVALIDATION_ID=$(aws cloudfront create-invalidation \
                    --distribution-id ${CLOUDFRONT_ID} \
                    --paths "/*" \
                    --region ${AWS_REGION} \
                    --query 'Invalidation.Id' \
                    --output text 2>/dev/null || echo "")
                
                if [ -n "$INVALIDATION_ID" ]; then
                    echo -e "${GREEN}✓ CloudFront invalidation created: ${INVALIDATION_ID}${NC}"
                fi
            else
                echo -e "${RED}✗ Frontend build failed${NC}"
            fi
        fi
        
        cd ..
    fi
else
    echo -e "${YELLOW}Frontend directory not found. Skipping frontend deployment.${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backend API:${NC} ${API_ENDPOINT}"
if [ -n "$FRONTEND_URL" ]; then
    echo -e "${GREEN}Frontend URL:${NC} ${FRONTEND_URL}"
    echo -e "${YELLOW}Note: CloudFront may take 5-10 minutes to fully deploy${NC}"
fi
echo -e "${GREEN}S3 Bucket:${NC} ${S3_BUCKET}"
echo -e "${GREEN}Region:${NC} ${AWS_REGION}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}========================================${NC}"
if [ -n "$FRONTEND_URL" ]; then
    echo -e "1. Access the frontend:"
    echo -e "   ${FRONTEND_URL}"
    echo -e "\n2. Create an account and start uploading documents!"
else
    echo -e "1. Test the API:"
    echo -e "   curl ${API_ENDPOINT}/health"
    echo -e "\n2. Upload a document:"
    echo -e "   curl -X POST ${API_ENDPOINT}/upload -F \"file=@document.pdf\""
fi
echo -e "\n3. Check CloudWatch logs:"
echo -e "   aws logs tail /aws/ecs/${PROJECT_NAME}-api --follow"
echo -e "   aws logs tail /aws/ecs/${PROJECT_NAME}-worker --follow"
echo -e "\n4. Monitor in AWS Console:"
echo -e "   - ECS: https://console.aws.amazon.com/ecs/home?region=${AWS_REGION}"
echo -e "   - S3: https://console.aws.amazon.com/s3/buckets/${S3_BUCKET}"
if [ -n "$FRONTEND_BUCKET" ]; then
    echo -e "   - Frontend S3: https://console.aws.amazon.com/s3/buckets/${FRONTEND_BUCKET}"
    echo -e "   - CloudFront: https://console.aws.amazon.com/cloudfront/home?region=${AWS_REGION}"
fi
echo -e "   - CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}"

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
