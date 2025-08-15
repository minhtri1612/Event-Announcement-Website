# --- IAM cho Subscription Lambda ---

resource "aws_iam_role" "subscription_lambda_exec" {
  name               = "subscription-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "subscription_lambda_policy" {
  name   = "SubscriptionLambdaPolicy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Scan"],
        Resource = aws_dynamodb_table.subscriptions.arn
      },
      {
        Effect   = "Allow",
        Action   = ["sns:Subscribe", "sns:Unsubscribe", "sns:ListSubscriptionsByTopic"],
        Resource = aws_sns_topic.event_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "subscription_lambda_basic_execution" {
  role       = aws_iam_role.subscription_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "subscription_lambda_custom_policy" {
  role       = aws_iam_role.subscription_lambda_exec.name
  policy_arn = aws_iam_policy.subscription_lambda_policy.arn
}

# --- IAM cho Event Registration Lambda ---

resource "aws_iam_role" "event_registration_lambda_exec" {
  name               = "event-registration-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "event_registration_lambda_policy" {
  name   = "EventRegistrationLambdaPolicy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"],
        Resource = [aws_dynamodb_table.events.arn, "${aws_dynamodb_table.events.arn}/index/*", aws_dynamodb_table.subscriptions.arn]
      },
      {
        Effect   = "Allow",
        Action   = ["sns:Publish"],
        Resource = aws_sns_topic.event_notifications.arn
      },
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.event_data.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_registration_lambda_basic_execution" {
  role       = aws_iam_role.event_registration_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# TÊN ĐỊNH DANH CỦA TÀI NGUYÊN NÀY ĐÃ ĐƯỢC SỬA LẠI CHO ĐÚNG
resource "aws_iam_role_policy_attachment" "event_registration_lambda_custom_policy" {
  role       = aws_iam_role.event_registration_lambda_exec.name
  policy_arn = aws_iam_policy.event_registration_lambda_policy.arn
}