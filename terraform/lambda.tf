# zipear el upload lambda
data "archive_file" "upload_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/upload-lambda"
  output_path = "${path.module}/upload-lambda.zip"
}

# crear funcion upload lambda
resource "aws_lambda_function" "upload_lambda" {
  filename         = data.archive_file.upload_lambda_zip.output_path
  function_name    = "image-processor-${terraform.workspace}-upload"
  role             = aws_iam_role.upload_lambda.arn 
  handler          = "index.handler" 
  runtime          = "nodejs20.x"    
  memory_size      = 256             
  timeout          = 30              
  source_code_hash = data.archive_file.upload_lambda_zip.output_base64sha256

  # asociar a las subredes privadas
  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.upload_lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.bucket
      UPLOAD_PREFIX = "uploads/"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_basic,
    aws_iam_role_policy_attachment.upload_vpc
  ]
}

# zipear el crop lambda
data "archive_file" "crop_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/crop-lambda"
  output_path = "${path.module}/crop-lambda.zip"
}

# crear funcion crop lambda
resource "aws_lambda_function" "crop_lambda" {
  filename         = data.archive_file.crop_lambda_zip.output_path
  function_name    = "image-processor-${terraform.workspace}-crop"
  role             = aws_iam_role.crop_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 512 
  timeout          = 60
  source_code_hash = data.archive_file.crop_lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.crop_lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.images.bucket
      PROCESSED_PREFIX = "processed/"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.crop_basic,
    aws_iam_role_policy_attachment.crop_vpc
  ]
}

# conectar sqs al lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn        = aws_sqs_queue.main.arn
  function_name           = aws_lambda_function.crop_lambda.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"] 
}
