# SNS Topic để gửi thông báo về sự kiện
resource "aws_sns_topic" "event_notifications" {
  name = "event-notifications"
}