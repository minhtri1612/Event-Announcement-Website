# 7-api_gateway.tf

# Định nghĩa API Gateway V2 (HTTP)
resource "aws_apigatewayv2_api" "main" {
  name          = "EventHubAPI"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

# --- Integrations ---
resource "aws_apigatewayv2_integration" "subscription" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.subscription.invoke_arn
}

resource "aws_apigatewayv2_integration" "event_registration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.event_registration.invoke_arn
}

# --- Routes ---
# -- Subscription Routes --
resource "aws_apigatewayv2_route" "post_subscribe" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /subscribe"
  target    = "integrations/${aws_apigatewayv2_integration.subscription.id}"
}

resource "aws_apigatewayv2_route" "get_subscriptions" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /subscriptions"
  target    = "integrations/${aws_apigatewayv2_integration.subscription.id}"
}

resource "aws_apigatewayv2_route" "delete_subscribe" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "DELETE /subscribe/{email}"
  target    = "integrations/${aws_apigatewayv2_integration.subscription.id}"
}

# -- Event Registration Routes --
resource "aws_apigatewayv2_route" "post_submit_event" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /submit-event"
  target    = "integrations/${aws_apigatewayv2_integration.event_registration.id}"
}

resource "aws_apigatewayv2_route" "get_events" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /events"
  target    = "integrations/${aws_apigatewayv2_integration.event_registration.id}"
}

resource "aws_apigatewayv2_route" "get_event_by_id" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /events/{eventId}"
  target    = "integrations/${aws_apigatewayv2_integration.event_registration.id}"
}

# SỬA LỖI: Thêm tài nguyên deployment tường minh
resource "aws_apigatewayv2_deployment" "main" {
  api_id = aws_apigatewayv2_api.main.id

  # Dòng này sẽ buộc tạo một deployment mới mỗi khi có sự thay đổi trong các route
  triggers = {
    redeployment = sha1(jsonencode([
      aws_apigatewayv2_route.post_subscribe.id,
      aws_apigatewayv2_route.get_subscriptions.id,
      aws_apigatewayv2_route.delete_subscribe.id,
      aws_apigatewayv2_route.post_submit_event.id,
      aws_apigatewayv2_route.get_events.id,
      aws_apigatewayv2_route.get_event_by_id.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SỬA LỖI: Cập nhật stage để sử dụng deployment tường minh
resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.main.id
  name   = "dev"
  # auto_deploy = true # <-- Xóa dòng này
  deployment_id = aws_apigatewayv2_deployment.main.id # <-- Thêm dòng này
}


# Cấp quyền cho API Gateway gọi các Lambda function
resource "aws_lambda_permission" "api_gw_subscription" {
  statement_id  = "AllowExecutionFromAPIGatewayForSubscription"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscription.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_event_registration" {
  statement_id  = "AllowExecutionFromAPIGatewayForEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_registration.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}