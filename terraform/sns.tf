# SNS Topic for notifications
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-notifications"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-notifications-topic"
    }
  )
}

# SNS Email Subscription (optional)
resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "notifications" {
  arn = aws_sns_topic.notifications.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}
