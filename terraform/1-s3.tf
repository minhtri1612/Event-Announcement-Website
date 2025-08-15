# Bucket để lưu trữ mã nguồn của các Lambda function
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "eventhub-lambda-code-bucket-${random_pet.suffix.id}"
}

# Bucket để lưu trữ dữ liệu của ứng dụng (ví dụ: event.json)
resource "aws_s3_bucket" "event_data" {
  bucket = "eventhub-data-bucket-${random_pet.suffix.id}"
}

resource "aws_s3_bucket_public_access_block" "event_data_block" {
  bucket = aws_s3_bucket.event_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tạo hậu tố ngẫu nhiên để tên bucket là duy nhất
resource "random_pet" "suffix" {
  length = 2
}