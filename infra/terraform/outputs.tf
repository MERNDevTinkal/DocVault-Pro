output "lambda_function_name" {
  value = aws_lambda_function.process_uploaded_file.function_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.upload_bucket.bucket
}

output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting frontend"
  value       = aws_s3_bucket.frontend_bucket.bucket
}

output "cloudfront_url" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}

output "presigned_url_api_endpoint" {
  description = "API endpoint to generate presigned S3 upload URLs"
  value       = aws_apigatewayv2_api.presign_api.api_endpoint
}