import json
import os
import boto3
import uuid

s3 = boto3.client("s3") # create connection with s3 bucket
BUCKET_NAME = os.environ["BUCKET_NAME"] # read from env variable bucket name

# AWS Lambda Calls
def lambda_handler(event, context):
    # Handle CORS preflight request
    if event.get("httpMethod") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "*",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            },
            "body": json.dumps("CORS preflight success")
        }
    # request allowed from any origin, any header and POST/GET/Option method allowed
    try:
        body = json.loads(event["body"]) # parse data which you have submitted
        filename = body.get("filename")
        content_type = body.get("contentType")
        full_name = body.get("fullName")
        email = body.get("email")
        notes = body.get("notes")

        # Log or process these fields as needed
        print(f"Received upload from: {full_name} ({email}), Notes: {notes}") # generate Log

        if not filename or not content_type:
            return {
                "statusCode": 400,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Headers": "*",
                    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
                },
                "body": json.dumps({"message": "Missing filename or contentType"})
            }
        # if filename or content type missed return 400 Bad Request
        key = f"{uuid.uuid4()}_{filename}" # generate S3 Object Key

        presigned_url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": BUCKET_NAME,
                "Key": key,
                "ContentType": content_type
            },
            ExpiresIn=300
        )
# creates temporary S3 Upload URL
# Anuone with this URL can upload one file
# valid for 5 minutes
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "*",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            },
            "body": json.dumps({"uploadUrl": presigned_url, "key": key})
        }
# if all good provide response OK
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "*",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            },
            "body": json.dumps({"message": "Error generating URL", "error": str(e)})
        }

        #if is there anu error then return status code 500 