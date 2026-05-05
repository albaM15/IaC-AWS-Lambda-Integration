# cola de mensajes muertos (si falla algo va aqui)
resource "aws_sqs_queue" "dlq" {
  name                      = "image-processor-${terraform.workspace}-image-dlq"
  message_retention_seconds = 1209600
  tags                      = { Name = "image-processor-${terraform.workspace}-image-dlq" }
}

# cola principal
resource "aws_sqs_queue" "main" {
  name                       = "image-processor-${terraform.workspace}-image-queue"
  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20
  
  # maximo 3 intentos
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = "image-processor-${terraform.workspace}-image-queue" }
}

# politica para que s3 le mande eventos a la cola
resource "aws_sqs_queue_policy" "main_policy" {
  queue_url = aws_sqs_queue.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_s3_bucket.images.arn
        }
      }
    }]
  })
}
