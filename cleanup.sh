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

echo -e "${RED}========================================${NC}"
echo -e "${RED}Document Processing Service Cleanup${NC}"
echo -e "${RED}========================================${NC}"

echo -e "\n${YELLOW}This will destroy all AWS resources created by this project.${NC}"
echo -e "${YELLOW}This action cannot be undone!${NC}\n"

read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

# Load environment variables
if [ -f .env ]; then
    source .env
    echo -e "${GREEN}✓ Loaded .env file${NC}"
fi

# Empty S3 bucket before deletion
if [ ! -z "$S3_BUCKET_NAME" ]; then
    echo -e "\n${YELLOW}Emptying S3 bucket...${NC}"
    
    if aws s3 ls "s3://${S3_BUCKET_NAME}" 2>/dev/null; then
        echo -e "Deleting all objects in ${S3_BUCKET_NAME}..."
        aws s3 rm "s3://${S3_BUCKET_NAME}" --recursive
        
        # Delete all versions if versioning is enabled
        aws s3api list-object-versions \
            --bucket "${S3_BUCKET_NAME}" \
            --output json \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            2>/dev/null | \
        jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
        xargs -I {} aws s3api delete-object --bucket "${S3_BUCKET_NAME}" {} 2>/dev/null || true
        
        # Delete delete markers
        aws s3api list-object-versions \
            --bucket "${S3_BUCKET_NAME}" \
            --output json \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            2>/dev/null | \
        jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
        xargs -I {} aws s3api delete-object --bucket "${S3_BUCKET_NAME}" {} 2>/dev/null || true
        
        echo -e "${GREEN}✓ S3 bucket emptied${NC}"
    else
        echo -e "${YELLOW}S3 bucket not found or already deleted${NC}"
    fi
fi

# Delete ECR images
echo -e "\n${YELLOW}Deleting ECR images...${NC}"

API_REPO="${PROJECT_NAME}-api"
WORKER_REPO="${PROJECT_NAME}-worker"

for REPO in $API_REPO $WORKER_REPO; do
    if aws ecr describe-repositories --repository-names $REPO --region $AWS_REGION 2>/dev/null; then
        echo -e "Deleting images in ${REPO}..."
        IMAGE_IDS=$(aws ecr list-images --repository-name $REPO --region $AWS_REGION --query 'imageIds[*]' --output json)
        
        if [ "$IMAGE_IDS" != "[]" ]; then
            aws ecr batch-delete-image \
                --repository-name $REPO \
                --region $AWS_REGION \
                --image-ids "$IMAGE_IDS" 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✓ Deleted images in ${REPO}${NC}"
    fi
done

# Stop ECS tasks
echo -e "\n${YELLOW}Stopping ECS tasks...${NC}"

CLUSTER_NAME="${PROJECT_NAME}-cluster"

if aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION 2>/dev/null | grep -q "ACTIVE"; then
    # Stop API service tasks
    API_SERVICE="${PROJECT_NAME}-api-service"
    TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $API_SERVICE --region $AWS_REGION --query 'taskArns[]' --output text 2>/dev/null || true)
    
    for TASK_ARN in $TASK_ARNS; do
        aws ecs stop-task --cluster $CLUSTER_NAME --task $TASK_ARN --region $AWS_REGION 2>/dev/null || true
    done
    
    # Stop Worker service tasks
    WORKER_SERVICE="${PROJECT_NAME}-worker-service"
    TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $WORKER_SERVICE --region $AWS_REGION --query 'taskArns[]' --output text 2>/dev/null || true)
    
    for TASK_ARN in $TASK_ARNS; do
        aws ecs stop-task --cluster $CLUSTER_NAME --task $TASK_ARN --region $AWS_REGION 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Stopped ECS tasks${NC}"
fi

# Purge SQS queue
echo -e "\n${YELLOW}Purging SQS queue...${NC}"

QUEUE_NAME="${PROJECT_NAME}-queue"
QUEUE_URL=$(aws sqs get-queue-url --queue-name $QUEUE_NAME --region $AWS_REGION --query 'QueueUrl' --output text 2>/dev/null || true)

if [ ! -z "$QUEUE_URL" ]; then
    aws sqs purge-queue --queue-url $QUEUE_URL --region $AWS_REGION 2>/dev/null || true
    echo -e "${GREEN}✓ Purged SQS queue${NC}"
fi

# Destroy Terraform infrastructure
echo -e "\n${YELLOW}Destroying Terraform infrastructure...${NC}"

cd terraform

if [ -f terraform.tfstate ]; then
    terraform destroy -auto-approve
    echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
else
    echo -e "${YELLOW}No Terraform state found${NC}"
fi

cd ..

# Clean up local files
echo -e "\n${YELLOW}Cleaning up local files...${NC}"

rm -f terraform/terraform.tfvars
rm -f terraform/lambda_function.zip
rm -f terraform/.terraform.lock.hcl
rm -rf terraform/.terraform

echo -e "${GREEN}✓ Local files cleaned${NC}"

# Remove Docker images
echo -e "\n${YELLOW}Removing local Docker images...${NC}"

docker rmi ${PROJECT_NAME}-api:latest 2>/dev/null || true
docker rmi ${PROJECT_NAME}-worker:latest 2>/dev/null || true

echo -e "${GREEN}✓ Docker images removed${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Note: The following items were preserved:${NC}"
echo -e "- .env file (contains your configuration)"
echo -e "- Source code and documentation"
echo -e "\n${YELLOW}To completely remove the project:${NC}"
echo -e "rm -rf /Users/sandipdas/aws_project_8"

echo -e "\n${GREEN}All AWS resources have been destroyed.${NC}"
