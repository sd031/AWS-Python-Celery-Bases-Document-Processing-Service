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

# Empty S3 buckets before deletion
echo -e "\n${YELLOW}Emptying S3 buckets...${NC}"

# List of buckets to empty (from .env and hardcoded bucket name)
BUCKETS=("${S3_BUCKET_NAME}" "aws-celery-demo")

for BUCKET in "${BUCKETS[@]}"; do
    if [ -z "$BUCKET" ]; then
        continue
    fi
    
    if aws s3 ls "s3://${BUCKET}" 2>/dev/null; then
        echo -e "Emptying bucket: ${BUCKET}..."
        
        # Delete all current objects first
        echo "  Deleting current objects..."
        aws s3 rm "s3://${BUCKET}" --recursive 2>/dev/null || true
        
        # Delete all object versions and delete markers
        echo "  Deleting all versions and delete markers..."
        
        # Get all versions and delete markers in one go
        VERSIONS=$(aws s3api list-object-versions \
            --bucket "${BUCKET}" \
            --output json \
            --max-items 1000 2>/dev/null || echo '{}')
        
        # Process versions
        echo "$VERSIONS" | jq -r '.Versions[]? | .Key + " " + .VersionId' | while read -r key version_id; do
            if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
                aws s3api delete-object --bucket "${BUCKET}" --key "$key" --version-id "$version_id" 2>/dev/null || true
            fi
        done
        
        # Process delete markers
        echo "$VERSIONS" | jq -r '.DeleteMarkers[]? | .Key + " " + .VersionId' | while read -r key version_id; do
            if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
                aws s3api delete-object --bucket "${BUCKET}" --key "$key" --version-id "$version_id" 2>/dev/null || true
            fi
        done
        
        # Check if there are more items (pagination)
        NEXT_TOKEN=$(echo "$VERSIONS" | jq -r '.NextToken // empty')
        while [ ! -z "$NEXT_TOKEN" ]; do
            echo "  Processing next batch..."
            VERSIONS=$(aws s3api list-object-versions \
                --bucket "${BUCKET}" \
                --output json \
                --max-items 1000 \
                --starting-token "$NEXT_TOKEN" 2>/dev/null || echo '{}')
            
            # Process versions
            echo "$VERSIONS" | jq -r '.Versions[]? | .Key + " " + .VersionId' | while read -r key version_id; do
                if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
                    aws s3api delete-object --bucket "${BUCKET}" --key "$key" --version-id "$version_id" 2>/dev/null || true
                fi
            done
            
            # Process delete markers
            echo "$VERSIONS" | jq -r '.DeleteMarkers[]? | .Key + " " + .VersionId' | while read -r key version_id; do
                if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
                    aws s3api delete-object --bucket "${BUCKET}" --key "$key" --version-id "$version_id" 2>/dev/null || true
                fi
            done
            
            NEXT_TOKEN=$(echo "$VERSIONS" | jq -r '.NextToken // empty')
        done
        
        echo -e "${GREEN}✓ Bucket ${BUCKET} emptied${NC}"
    else
        echo -e "${YELLOW}Bucket ${BUCKET} not found or already deleted${NC}"
    fi
done

# Delete ECR images
echo -e "\n${YELLOW}Deleting ECR images...${NC}"

API_REPO="${PROJECT_NAME}-api"
WORKER_REPO="${PROJECT_NAME}-worker"
FRONTEND_REPO="${PROJECT_NAME}-frontend"

for REPO in $API_REPO $WORKER_REPO $FRONTEND_REPO; do
    if aws ecr describe-repositories --repository-names $REPO --region $AWS_REGION 2>/dev/null; then
        echo -e "Deleting images in ${REPO}..."
        IMAGE_IDS=$(aws ecr list-images --repository-name $REPO --region $AWS_REGION --query 'imageIds[*]' --output json)
        
        if [ "$IMAGE_IDS" != "[]" ] && [ "$IMAGE_IDS" != "null" ]; then
            aws ecr batch-delete-image \
                --repository-name $REPO \
                --region $AWS_REGION \
                --image-ids "$IMAGE_IDS" 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✓ Deleted images in ${REPO}${NC}"
    else
        echo -e "${YELLOW}Repository ${REPO} not found or already deleted${NC}"
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
    
    # Stop Frontend service tasks
    FRONTEND_SERVICE="${PROJECT_NAME}-frontend-service"
    TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $FRONTEND_SERVICE --region $AWS_REGION --query 'taskArns[]' --output text 2>/dev/null || true)
    
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
docker rmi ${PROJECT_NAME}-frontend:latest 2>/dev/null || true

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
