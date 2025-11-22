# DynamoDB table for job tracking
resource "aws_dynamodb_table" "jobs" {
  name           = "${var.project_name}-jobs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "job_id"
  
  attribute {
    name = "job_id"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }
  
  attribute {
    name = "created_at"
    type = "S"
  }
  
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-jobs-table"
    }
  )
}

# DynamoDB table for Celery results
resource "aws_dynamodb_table" "celery_results" {
  name           = "${var.project_name}-celery-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-celery-results-table"
    }
  )
}
