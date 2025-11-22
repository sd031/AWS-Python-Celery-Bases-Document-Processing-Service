variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "doc-processor"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for document storage"
  type        = string
}

variable "notification_email" {
  description = "Email address for SNS notifications"
  type        = string
  default     = ""
}

variable "api_cpu" {
  description = "CPU units for API task"
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "Memory for API task (MB)"
  type        = number
  default     = 1024
}

variable "worker_cpu" {
  description = "CPU units for worker task"
  type        = number
  default     = 1024
}

variable "worker_memory" {
  description = "Memory for worker task (MB)"
  type        = number
  default     = 2048
}

variable "worker_desired_count" {
  description = "Desired number of worker tasks"
  type        = number
  default     = 2
}

variable "api_desired_count" {
  description = "Desired number of API tasks"
  type        = number
  default     = 1
}

variable "max_file_size" {
  description = "Maximum file size in bytes"
  type        = number
  default     = 104857600 # 100MB
}

variable "allowed_extensions" {
  description = "Allowed file extensions"
  type        = string
  default     = "pdf,png,jpg,jpeg,gif,mp4,mov,avi"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "doc-processor"
    ManagedBy   = "terraform"
  }
}
