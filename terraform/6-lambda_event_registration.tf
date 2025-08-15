# 6-lambda_event_registration.tf

# Đóng gói mã nguồn Lambda từ đúng thư mục
data "archive_file" "lambda_event_registration" {
  type        = "zip"
  source_dir  = "../event-registration" # <-- SỬA ĐƯỜNG DẪN TẠI ĐÂY
  output_path = "event-registration.zip"
}

# Tải tệp zip lên S3
resource "aws_s3_object" "lambda_event_registration" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "event-registration.zip"
  source = data.archive_file.lambda_event_registration.output_path
  etag   = filemd5(data.archive_file.lambda_event_registration.output_path)
}

# Định nghĩa Lambda function
resource "aws_lambda_function" "event_registration" {
  function_name    = "event-registration"
  role             = aws_iam_role.event_registration_lambda_exec.arn
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_object.lambda_event_registration.key
  runtime          = "nodejs18.x"
  handler          = "function.handler"
  source_code_hash = data.archive_file.lambda_event_registration.output_base64sha256
  timeout          = 30 # <-- THÊM DÒNG NÀY
  
  environment {
    variables = {
      EVENTS_TABLE        = aws_dynamodb_table.events.name
      SUBSCRIPTIONS_TABLE = aws_dynamodb_table.subscriptions.name
      SNS_TOPIC_ARN       = aws_sns_topic.event_notifications.arn
      S3_BUCKET           = aws_s3_bucket.event_data.id
    }
  }
}