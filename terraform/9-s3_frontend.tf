# 9-s3_frontend.tf

# 1. Tạo một S3 bucket để chứa các tệp frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "eventhub-frontend-site-${random_pet.suffix.id}"
}

# 2. Cấu hình bucket để hoạt động như một website tĩnh
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
  
  error_document {
    key = "index.html"
  }
}

# 3. Cho phép truy cập công khai vào bucket
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 4. Gán một policy để cho phép đọc các đối tượng trong bucket
#    SỬA LỖI: Thêm depends_on để đảm bảo tài nguyên này được tạo sau
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  # DÒNG QUAN TRỌNG NHẤT ĐỂ SỬA LỖI
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# 5. Tự động tải các tệp từ thư mục 'src' lên S3 bucket
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "../src/index.html"
  content_type = "text/html"
  etag         = filemd5("../src/index.html")
}

resource "aws_s3_object" "css" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "styles.css"
  source       = "../src/styles.css"
  content_type = "text/css"
  etag         = filemd5("../src/styles.css")
}

resource "aws_s3_object" "js" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "script.js"
  source       = "../src/script.js"
  content_type = "application/javascript"
  etag         = filemd5("../src/script.js")
}