# DynamoDB table for events
resource "aws_dynamodb_table" "events" {
  name           = "events"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  global_secondary_index {
    name     = "CategoryIndex"
    hash_key = "category"
    
    projection_type = "ALL"
  }

  attribute {
    name = "category"
    type = "S"
  }

  tags = {
    Name        = "EventHub Events"
    Environment = "dev"
  }
}

# IAM Role for Event Registration Lambda
resource "aws_iam_role" "event_registration_lambda_exec" {
  name = "event-registration-lambda"
  
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
resource "aws_iam_role_policy_attachment" "event_registration_lambda_policy" {
  role       = aws_iam_role.event_registration_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB, SNS and S3 access policy
resource "aws_iam_policy" "event_registration_lambda_policy" {
  name = "EventRegistrationLambdaPolicy"
  
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
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.events.arn,
          "${aws_dynamodb_table.events.arn}/index/*",
          aws_dynamodb_table.subscriptions.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.event_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.lambda_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_registration_lambda_custom_policy" {
  role       = aws_iam_role.event_registration_lambda_exec.name
  policy_arn = aws_iam_policy.event_registration_lambda_policy.arn
}

# Event Registration Lambda Function
resource "aws_lambda_function" "event_registration" {
  function_name    = "event-registration"
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key          = aws_s3_object.lambda_event_registration.key
  runtime         = "nodejs18.x"
  handler         = "function.handler"
  source_code_hash = data.archive_file.lambda_event_registration.output_base64sha256
  role            = aws_iam_role.event_registration_lambda_exec.arn

  environment {
    variables = {
      EVENTS_TABLE        = aws_dynamodb_table.events.name
      SUBSCRIPTIONS_TABLE = aws_dynamodb_table.subscriptions.name
      SNS_TOPIC_ARN       = aws_sns_topic.event_notifications.arn
      S3_BUCKET           = aws_s3_bucket.lambda_bucket.id
    }
  }
}

resource "aws_cloudwatch_log_group" "event_registration" {
  name              = "/aws/lambda/${aws_lambda_function.event_registration.function_name}"
  retention_in_days = 14
}

# Archive event registration lambda code
data "archive_file" "lambda_event_registration" {
  type        = "zip"
  source_dir  = "../${path.module}/event-registration"
  output_path = "../${path.module}/event-registration.zip"
}

resource "aws_s3_object" "lambda_event_registration" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "event-registration.zip"
  source = data.archive_file.lambda_event_registration.output_path
  etag   = filemd5(data.archive_file.lambda_event_registration.output_path)
}