variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}
variable "upload_bucket_name" {
  description = "Name of the S3 bucket to upload files"
  type        = string
}

variable "frontend_bucket_name" {
  description = "Name of the S3 bucket for frontend hosting"
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "notification_email" {
  description = "Email address to receive file upload notifications"
  type        = string
}