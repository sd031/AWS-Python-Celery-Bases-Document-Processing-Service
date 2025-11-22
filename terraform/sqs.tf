# SQS Queue for Celery tasks
resource "aws_sqs_queue" "celery" {
  name                       = "${var.project_name}-queue"
  visibility_timeout_seconds = 3600
  message_retention_seconds  = 1209600  # 14 days
  receive_wait_time_seconds  = 20       # Long polling
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-celery-queue"
    }
  )
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "celery_dlq" {
  name                       = "${var.project_name}-queue-dlq"
  message_retention_seconds  = 1209600  # 14 days
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-celery-dlq"
    }
  )
}

# Redrive policy for main queue
resource "aws_sqs_queue_redrive_policy" "celery" {
  queue_url = aws_sqs_queue.celery.id
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.celery_dlq.arn
    maxReceiveCount     = 3
  })
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "celery" {
  queue_url = aws_sqs_queue.celery.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.celery.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.s3_trigger.arn
          }
        }
      }
    ]
  })
}
