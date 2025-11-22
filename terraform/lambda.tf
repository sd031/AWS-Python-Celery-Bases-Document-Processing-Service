# Lambda function for S3 trigger
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "s3_trigger" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-s3-trigger"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "s3_trigger.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 256
  
  environment {
    variables = {
      SQS_QUEUE_URL    = aws_sqs_queue.celery.url
      S3_UPLOAD_PREFIX = "uploads/"
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-s3-trigger"
    }
  )
}

# Lambda permission for S3
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.documents.arn
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.s3_trigger.function_name}"
  retention_in_days = 7
  
  tags = local.common_tags
}
