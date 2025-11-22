output "api_endpoint" {
  description = "API endpoint URL"
  value       = "http://${aws_lb.api.dns_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.documents.id
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.celery.url
}

output "dynamodb_jobs_table" {
  description = "DynamoDB jobs table name"
  value       = aws_dynamodb_table.jobs.name
}

output "dynamodb_results_table" {
  description = "DynamoDB results table name"
  value       = aws_dynamodb_table.celery_results.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = aws_sns_topic.notifications.arn
}

output "ecr_api_repository" {
  description = "ECR repository URL for API"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_worker_repository" {
  description = "ECR repository URL for worker"
  value       = aws_ecr_repository.worker.repository_url
}

output "cloudwatch_log_group_api" {
  description = "CloudWatch log group for API"
  value       = aws_cloudwatch_log_group.api.name
}

output "cloudwatch_log_group_worker" {
  description = "CloudWatch log group for worker"
  value       = aws_cloudwatch_log_group.worker.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "frontend_bucket" {
  description = "Frontend S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_url" {
  description = "Frontend CloudFront URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    api_endpoint           = "http://${aws_lb.api.dns_name}"
    frontend_url          = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    s3_bucket             = aws_s3_bucket.documents.id
    frontend_bucket       = aws_s3_bucket.frontend.id
    region                = var.aws_region
    account_id            = local.account_id
  }
}
