.PHONY: help deploy cleanup test logs-api logs-worker logs-frontend build-api build-worker build-frontend update-images

# Variables
PROJECT_NAME := doc-processor
AWS_REGION := us-east-1

help:
	@echo "Document Processing Service - Make Commands"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy          - Deploy entire application"
	@echo "  make update-images   - Update Docker images and redeploy services"
	@echo "  make cleanup         - Destroy all AWS resources"
	@echo ""
	@echo "Development:"
	@echo "  make build-api       - Build API Docker image"
	@echo "  make build-worker    - Build Worker Docker image"
	@echo "  make test            - Run API tests"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs-api        - Tail API logs"
	@echo "  make logs-worker     - Tail Worker logs"
	@echo "  make logs-lambda     - Tail Lambda logs"
	@echo ""
	@echo "Utilities:"
	@echo "  make status          - Show deployment status"
	@echo "  make outputs         - Show Terraform outputs"

deploy:
	@echo "Deploying application..."
	@chmod +x deploy.sh
	@./deploy.sh

cleanup:
	@echo "Cleaning up resources..."
	@chmod +x cleanup.sh
	@./cleanup.sh

build-api:
	@echo "Building API Docker image for linux/amd64..."
	@docker build --platform linux/amd64 -f docker/api.Dockerfile -t $(PROJECT_NAME)-api:latest .

build-worker:
	@echo "Building Worker Docker image for linux/amd64..."
	@docker build --platform linux/amd64 -f docker/worker.Dockerfile -t $(PROJECT_NAME)-worker:latest .

build-frontend:
	@echo "Building Frontend Docker image for linux/amd64..."
	@docker build --platform linux/amd64 -f docker/frontend.Dockerfile -t $(PROJECT_NAME)-frontend:latest .

update-images:
	@echo "Updating Docker images and redeploying ECS services..."
	@echo "Getting ECR repository URLs..."
	@$(eval API_REPO := $(shell cd terraform && terraform output -raw ecr_api_repository 2>/dev/null))
	@$(eval WORKER_REPO := $(shell cd terraform && terraform output -raw ecr_worker_repository 2>/dev/null))
	@$(eval FRONTEND_REPO := $(shell cd terraform && terraform output -raw ecr_frontend_repository 2>/dev/null))
	@echo "Logging into ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(shell aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com
	@echo "Building and pushing API image..."
	@docker build --platform linux/amd64 -f docker/api.Dockerfile -t $(PROJECT_NAME)-api:latest .
	@docker tag $(PROJECT_NAME)-api:latest $(API_REPO):latest
	@docker push $(API_REPO):latest
	@echo "Building and pushing Worker image..."
	@docker build --platform linux/amd64 -f docker/worker.Dockerfile -t $(PROJECT_NAME)-worker:latest .
	@docker tag $(PROJECT_NAME)-worker:latest $(WORKER_REPO):latest
	@docker push $(WORKER_REPO):latest
	@echo "Building and pushing Frontend image..."
	@docker build --platform linux/amd64 -f docker/frontend.Dockerfile -t $(PROJECT_NAME)-frontend:latest .
	@docker tag $(PROJECT_NAME)-frontend:latest $(FRONTEND_REPO):latest
	@docker push $(FRONTEND_REPO):latest
	@echo "Forcing ECS services to update..."
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-api-service --force-new-deployment --region $(AWS_REGION) > /dev/null
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-worker-service --force-new-deployment --region $(AWS_REGION) > /dev/null
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-frontend-service --force-new-deployment --region $(AWS_REGION) > /dev/null
	@echo "✓ Images updated and services redeploying with new images"

test:
	@echo "Running API tests..."
	@chmod +x test_api.sh
	@./test_api.sh

logs-api:
	@echo "Tailing API logs..."
	@aws logs tail /aws/ecs/$(PROJECT_NAME)-api --follow --region $(AWS_REGION)

logs-worker:
	@echo "Tailing Worker logs..."
	@aws logs tail /aws/ecs/$(PROJECT_NAME)-worker --follow --region $(AWS_REGION)

logs-lambda:
	@echo "Tailing Lambda logs..."
	@aws logs tail /aws/lambda/$(PROJECT_NAME)-s3-trigger --follow --region $(AWS_REGION)

logs-frontend:
	@echo "Tailing Frontend logs..."
	@aws logs tail /aws/ecs/$(PROJECT_NAME)-frontend --follow --region $(AWS_REGION)

status:
	@echo "Checking deployment status..."
	@cd terraform && terraform show 2>/dev/null || echo "No deployment found"

outputs:
	@echo "Terraform outputs:"
	@cd terraform && terraform output 2>/dev/null || echo "No outputs available"

init:
	@echo "Initializing Terraform..."
	@cd terraform && terraform init

plan:
	@echo "Planning Terraform changes..."
	@cd terraform && terraform plan

apply:
	@echo "Applying Terraform changes..."
	@cd terraform && terraform apply

fmt:
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive

validate:
	@echo "Validating Terraform configuration..."
	@cd terraform && terraform validate

clean-local:
	@echo "Cleaning local files..."
	@rm -rf terraform/.terraform
	@rm -f terraform/.terraform.lock.hcl
	@rm -f terraform/terraform.tfstate*
	@rm -f terraform/terraform.tfvars
	@rm -f terraform/lambda_function.zip
	@docker rmi $(PROJECT_NAME)-api:latest 2>/dev/null || true
	@docker rmi $(PROJECT_NAME)-worker:latest 2>/dev/null || true
	@echo "Local cleanup complete"
