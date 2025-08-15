# SNS Topic for Event Notifications
resource "aws_sns_topic" "event_notifications" {
  name = "event-notifications"
  
  tags = {
    Name        = "EventHub Notifications"
    Environment = "dev"
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "event_notifications" {
  arn = aws_sns_topic.event_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.event_notifications.arn
      }
    ]
  })
}

# Output SNS Topic ARN
output "sns_topic_arn" {
  description = "ARN of the SNS topic for event notifications"
  value       = aws_sns_topic.event_notifications.arn
}