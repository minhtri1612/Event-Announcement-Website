# outputs.tf

output "api_gateway_invoke_url" {
  description = "URL to invoke the API Gateway"
  value       = aws_apigatewayv2_stage.dev.invoke_url
}

output "website_url" {
  description = "URL of the static website hosted on S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "event_data_s3_bucket_name" {
  description = "Name of the S3 bucket for event data"
  value       = aws_s3_bucket.event_data.id
}