# Bảng DynamoDB để lưu thông tin đăng ký (subscriptions)
resource "aws_dynamodb_table" "subscriptions" {
  name         = "event-subscriptions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }
}

# Bảng DynamoDB để lưu thông tin sự kiện (events)
resource "aws_dynamodb_table" "events" {
  name         = "events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    projection_type = "ALL"
  }
}