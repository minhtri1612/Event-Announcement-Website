# DynamoDB table for subscriptions
resource "aws_dynamodb_table" "subscriptions" {
  name           = "event-subscriptions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "email"

  attribute {
    name = "email"
    type = "S"
  }

  tags = {
    Name        = "EventHub Subscriptions"
    Environment = "dev"
  }
}

# IAM Role for Subscription Lambda
resource "aws_iam_role" "subscription_lambda_exec" {
  name = "subscription-lambda"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Basic Lambda execution role
resource "aws_iam_role_policy_attachment" "subscription_lambda_policy" {
  role       = aws_iam_role.subscription_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB and SNS access policy
resource "aws_iam_policy" "subscription_lambda_policy" {
  name = "SubscriptionLambdaPolicy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.subscriptions.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic"
        ]
        Resource = aws_sns_topic.event_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "subscription_lambda_custom_policy" {
  role       = aws_iam_role.subscription_lambda_exec.name
  policy_arn = aws_iam_policy.subscription_lambda_policy.arn
}

# Subscription Lambda Function
resource "aws_lambda_function" "subscription" {
  function_name    = "subscription-handler"
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key          = aws_s3_object.lambda_subscription.key
  runtime         = "nodejs18.x"
  handler         = "function.handler"
  source_code_hash = data.archive_file.lambda_subscription.output_base64sha256
  role            = aws_iam_role.subscription_lambda_exec.arn

  environment {
    variables = {
      SUBSCRIPTIONS_TABLE = aws_dynamodb_table.subscriptions.name
      SNS_TOPIC_ARN       = aws_sns_topic.event_notifications.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "subscription" {
  name              = "/aws/lambda/${aws_lambda_function.subscription.function_name}"
  retention_in_days = 14
}

# Archive subscription lambda code
data "archive_file" "lambda_subscription" {
  type        = "zip"
  source_dir  = "../${path.module}/subscription"
  output_path = "../${path.module}/subscription.zip"
}

resource "aws_s3_object" "lambda_subscription" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "subscription.zip"
  source = data.archive_file.lambda_subscription.output_path
  etag   = filemd5(data.archive_file.lambda_subscription.output_path)
}