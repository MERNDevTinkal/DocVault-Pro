terraform {
  required_version = ">= 1.5.0"

  #  Store Terraform state file in S3 
  # Why: Terraform needs to remember what it created
  # If multiple people work on same project, S3 keeps it synced

  # Meaning: S3 bucket name where state is stored
  # This bucket: holds terraform.tfstate file 

  # Line: dynamodb_table = "devops-accelerator-tf-locker"

  # Meaning: Uses DynamoDB for STATE LOCKING
  # Why: If 2 people run terraform at same time:
  #      - Person A locks the state (DynamoDB)
  #      - Person B waits
  #      - Person A finishes, releases lock
  #      - Person B can now proceed
  # Prevents: Conflicts & corruption of terraform state

  #   1. Use AWS S3 Server-Side Encryption Protect sensitive info from hackers
  # 2. Encrypt the file with AWS KMS master key
  # 3. Only decrypt when needed Only people with AWS account access , Only AWS can decrypt (with your AWS account key)
  # 4. File appears encrypted in S3


  backend "s3" {
    bucket = "devops-accelerator-plateform-tf-state-capstone"
    key    = "global/docVault/terraform.tfstate" #Yeh S3 bucket ke andar file ka path/location hai.
    region         = "us-east-1"
    dynamodb_table = "devops-accelerator-tf-locker"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------
# IAM roles for Lambda
# -----------------------------

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# -----------------------------
# Upload Bucket
# -----------------------------

resource "aws_s3_bucket" "upload_bucket" {
  bucket        = var.upload_bucket_name
  force_destroy = true
}

# -----------------------------
# Lambda: Process Uploaded File
# -----------------------------

# Reason 1: Size
#   Normal files: 500MB bhi ho sakte hain
#   Zip file: 50MB possible (10x smaller!)
# Reason 2: Upload speed
#   Zip = faster upload to AWS
#   50MB vs 500MB = Jaldi jaata hai
# Reason 3: AWS standard
#   Lambda expects zip format
# .arn = Amazon Resource Name (Unique ID)

# Checksum/Fingerprint nikalo zip file ka
# Jaise:
#   File content: "print('Hello')"
#   Hash: abc123xyz (unique)
#   Agar content change: "print('Hello World')"
#   Hash: def456uvw (completely different!)
# First time: lambda.zip upload hota hai
# Checksum: abc123
# Time 2: Aap code change karte ho
# New lambda.zip
# Checksum: def456 ← DIFFERENT!
# Terraform: "Checksum different! Code change hua!
#             Lambda function update karna padega!"
# Without it? Terraform nahi samjhega ki code change hua!



resource "aws_lambda_function" "process_uploaded_file" {
  function_name    = "process-uploaded-file"
  runtime          = "python3.11"
  handler          = "main.lambda_handler"
  filename         = "${path.module}/../../backend/process-uploaded-file/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../../backend/process-uploaded-file/lambda.zip")
  role             = aws_iam_role.lambda_exec_role.arn

  environment {
    variables = {
      UPLOAD_BUCKET = aws_s3_bucket.upload_bucket.bucket
      SNS_TOPIC_ARN = aws_sns_topic.docVault_upload_notify.arn
    }
  }
}

resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_uploaded_file.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_uploaded_file.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}

# Block	Purpose
# S3 Bucket Notification	S3 ko tell karo Lambda ko call karna
# Lambda Permission	Lambda ko tell karo S3 se calls accept karina
# Both Together	Event-driven automation complete!

# Property	Meaning
# statement_id	Permission ka unique name
# action	Kaunsa action allowed (invoke)
# function_name	Kaunsa Lambda function
# principal	Kaunsa service (S3)
# source_arn	Kaunse S3 bucket se (security)

# -----------------------------
# Frontend Hosting (S3 + CloudFront)
# -----------------------------

resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = var.frontend_bucket_name
  force_destroy = true

  tags = {
    Name = "Frontend Hosting Bucket"
  }
}

# AWS ka new security feature:
#   "Block Public Access" ON by default
# Matlab: S3 bucket public nahi hota automatically
# But website public hona chahiye!
#   Users ko access karna padega!
# Solution: "Block Public Access" OFF karo
# Result: Bucket public ho jaata hai



# Disable Block Public Access so bucket policy works
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Static website hosting
resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Public bucket policy (depends on disabling Block Public Access first)
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

#   depends_on = Terraform ko order tell karna
# Matlab: "Yeh resource create karne se pehle,
#          WOAH resource create kar pehle!"

  depends_on = [aws_s3_bucket_public_access_block.frontend_bucket_public_access]

# If GUI se bucket create kar aur set kare:
#   ✓ Block Public Access = OFF
#   ✗ NO bucket policy added
# Result: Still CANNOT access! ❌
# Why?
#   Block PA OFF = Door unlocked
#   But NO policy = Permission denied inside
# BOTH needed:
#   1. Block PA = OFF ✓
#   2. Bucket Policy = ALLOW ✓

# Without policy → Access denied!

}

# CORS (optional, for presigned uploads / APIs)
resource "aws_s3_bucket_cors_configuration" "frontend_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = ["https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"]
    expose_headers  = []
    max_age_seconds = 3000
  }

# max_age_seconds = 3000
# Matlab: Browser 3000 seconds (50 minutes) tak
#         CORS rules cache rakhe!
# Why?
#   ├─ Browser ek baar CORS check kar le
#   ├─ Phir 3000 sec tak cache mein rakh le
#   ├─ Baar baar AWS ko request na bheje
#   └─ Faster! 🚀
# Example:
#   User 1st time: Browser checks S3 CORS → Ask AWS
#   User 2nd time (within 50 min): Browser uses cache
#   User 3rd time (after 50 min): Check AWS again

}

# CORS for Upload Bucket - Browser se presigned URL par PUT request ke liye zaroori hai
resource "aws_s3_bucket_cors_configuration" "upload_cors" {
  bucket = aws_s3_bucket.upload_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  # enabled = false → CDN off (bucketse direct)
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend_bucket_website.website_endpoint
    origin_id   = "S3-Frontend-Origin"

    custom_origin_config {
      http_port              = 80 #CloudFront S3 se HTTP port 80 par connect kare
      https_port             = 443 #User side: HTTPS (secure, encrypted)
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Frontend-Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https" #CloudFront automatically convert to: http://example.com → https://example.com
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "FrontendCDN"
  }

  depends_on = [aws_s3_bucket_policy.frontend_bucket_policy]
}

# -----------------------------
# Lambda: Presigned URL API
# -----------------------------

resource "aws_iam_role" "presign_lambda_role" {
  name = "DocVault-Presign-Lambda-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole" #STS = Security Token Service
    }]
  })
}

resource "aws_iam_policy" "presign_lambda_policy" {
  name = "DocVault-Presign-Lambda-Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
          # When Lambda uploads logs to CloudWatch, Log Group is like folder for that Lambda. Inside it, Log Stream is like file for each execution. And inside log stream, actual messages are called Log Events.
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
          # Lambda can upload and download objects from the S3 bucket
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.upload_bucket_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "presign_lambda_attach" {
  role       = aws_iam_role.presign_lambda_role.name
  policy_arn = aws_iam_policy.presign_lambda_policy.arn
}

resource "aws_lambda_function" "presign_lambda" {
  function_name    = "DocVault-Presign-Handler"
  role             = aws_iam_role.presign_lambda_role.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  filename         = "${path.module}/../../backend/generate-presigned-url/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../../backend/generate-presigned-url/lambda.zip")

  environment {
    variables = {
      BUCKET_NAME = var.upload_bucket_name
    }
  }
}

# API Gateway HTTP API

resource "aws_apigatewayv2_api" "presign_api" {
  name          = "DocVault-Presign-API"
  protocol_type = "HTTP" #protocol_type = API kaunse protocol use karega?

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["OPTIONS", "POST"] #Browser directly POST nahi karta, pehle OPTIONS request bhejta hai (preflight) → Check CORS rules → Phir POST chake if allowed or not then POST request bhejta hai
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_integration" "presign_api_integration" {
  api_id                 = aws_apigatewayv2_api.presign_api.id
  integration_type       = "AWS_PROXY" #AWS_PROXY = API Gateway Lambda ko directly call karega, bina extra configuration ke. Lambda function ke input/output ko automatically handle karega.
  integration_uri        = aws_lambda_function.presign_lambda.invoke_arn #Lambda function ka unique ARN (Amazon Resource Name) jo usko identify karta hai. API Gateway ko pata hona chahiye ki kaunsa Lambda function call karna hai jab API hit hota hai.
  integration_method     = "POST" #API Gateway Lambda ko POST request se call karega Lambda invoke always POST se hota hai
  payload_format_version = "2.0" #Lambda function ke input/output format ko define karta hai. Version 2.0 latest hai, aur recommended bhi. and used for HTTP APIs.
}
# Route define karta hai means Kaunsa URL kis Lambda ko call karega
resource "aws_apigatewayv2_route" "presign_route" {
  api_id    = aws_apigatewayv2_api.presign_api.id
  route_key = "POST /generate-presigned-url" #When user calls: POST /generate-presigned-url then API Gateway is triggered and it will call the Lambda function through the integration we set up above.
  target    = "integrations/${aws_apigatewayv2_integration.presign_api_integration.id}" #Target tells API Gateway ki jab yeh route hit ho, toh kaunsa integration use karna hai. Integration ke andar humne Lambda function set kiya hai, toh yeh route hit hone par woh Lambda function call hoga. simple Ye route kis integration ko call karega
}
#CloudWatch me log folder create kar rahe ho
resource "aws_cloudwatch_log_group" "apigw_logs" {
  name              = "/aws/apigateway/presign-api" #CloudWatch me log folder create kar rahe ho
  retention_in_days = 7 #Logs kitne din tak store rahenge auto delete after 7 days
}

resource "aws_apigatewayv2_stage" "presign_stage" {  #Stage = Running version of your API API Gateway ka stage (running environment) create kar rahe ho
  api_id      = aws_apigatewayv2_api.presign_api.id #Ye stage kis API Gateway ke liye hai
  name        = "$default"  #Ye default stage hai it means jab bhi API Gateway ka URL hit hoga, toh yeh stage use hoga. $default stage automatically available hota hai, aur isko use karna sabse simple hota hai. benifits URL short hota hai
  auto_deploy = true #When change happens → auto update deploy kar de

  default_route_settings {  #Default settings for all routes in this stage 
    data_trace_enabled = true
    throttling_burst_limit = 50
    throttling_rate_limit  = 100
  }

  access_log_settings { #Access logs enable kar rahe ho
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn #Logs kaha store karne hai (CloudWatch log group)
    format = jsonencode({
      requestId   = "$context.requestId",
      requestTime = "$context.requestTime",
      httpMethod  = "$context.httpMethod",
      path        = "$context.path",
      status      = "$context.status"
    })
  }
}

resource "aws_lambda_permission" "allow_apigw_invoke_presign" { #Without this → API Gateway Lambda call nahi kar sakta Lambda ko permission de rahe ho
  statement_id  = "AllowInvokeFromAPIGatewayPresign"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presign_lambda.function_name
  principal     = "apigateway.amazonaws.com" #Kaun invoke karega API Gateway
  source_arn    = "${aws_apigatewayv2_api.presign_api.execution_arn}/*/*" #Kaunse API Gateway ke routes se invoke ho sakta hai
}

# -----------------------------
# SNS Topic for Notifications When file uploaded → Lambda message send karega → Topic ko
# -----------------------------

resource "aws_sns_topic" "docVault_upload_notify" {
  name = "docVault-upload-notification-topic"
}

resource "aws_sns_topic_subscription" "docVault_email_sub" {
  topic_arn = aws_sns_topic.docVault_upload_notify.arn
  protocol  = "email"
  endpoint  = var.notification_email #Kis email par send kare
}

resource "aws_iam_policy" "docVault_lambda_sns_policy" {
  name = "docVault-lambda-sns-publish-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sns:Publish", # allow sns publish action
        Resource = aws_sns_topic.docVault_upload_notify.arn # sirf is topic par publish karne ki permission
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name # jo Lambda execution role humne pehle banaya tha, usko attach kar rahe ho
  policy_arn = aws_iam_policy.docVault_lambda_sns_policy.arn
}
