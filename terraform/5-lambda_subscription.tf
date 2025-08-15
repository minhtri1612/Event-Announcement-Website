# 5-lambda_subscription.tf

# Đóng gói mã nguồn Lambda từ đúng thư mục
data "archive_file" "lambda_subscription" {
  type        = "zip"
  source_dir  = "../subscription" # <-- SỬA ĐƯỜNG DẪN TẠI ĐÂY
  output_path = "subscription.zip"
}

# Tải tệp zip lên S3
resource "aws_s3_object" "lambda_subscription" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "subscription.zip"
  source = data.archive_file.lambda_subscription.output_path
  etag   = filemd5(data.archive_file.lambda_subscription.output_path)
}

# Định nghĩa Lambda function
resource "aws_lambda_function" "subscription" {
  function_name    = "subscription-handler"
  role             = aws_iam_role.subscription_lambda_exec.arn
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_object.lambda_subscription.key
  runtime          = "nodejs18.x"
  handler          = "function.handler"
  source_code_hash = data.archive_file.lambda_subscription.output_base64sha256
  timeout          = 30 # <-- THÊM DÒNG NÀY

  environment {
    variables = {
      SUBSCRIPTIONS_TABLE = aws_dynamodb_table.subscriptions.name
      SNS_TOPIC_ARN       = aws_sns_topic.event_notifications.arn
    }
  }
}