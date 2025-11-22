# S3 Bucket for document storage
resource "aws_s3_bucket" "documents" {
  bucket = var.s3_bucket_name
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-documents"
    }
  )
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  rule {
    id     = "delete-old-uploads"
    status = "Enabled"
    
    filter {
      prefix = "uploads/"
    }
    
    expiration {
      days = 30
    }
  }
  
  rule {
    id     = "transition-processed"
    status = "Enabled"
    
    filter {
      prefix = "processed/"
    }
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = 365
    }
  }
}

# S3 Bucket Notification to Lambda
resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }
  
  depends_on = [aws_lambda_permission.allow_s3]
}

# S3 Bucket CORS Configuration
resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
