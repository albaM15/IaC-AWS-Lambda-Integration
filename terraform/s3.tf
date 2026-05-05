# el bucket para las imagenes
resource "aws_s3_bucket" "images" {
  bucket = "image-processor-${terraform.workspace}-images-${var.suffix}"
  tags = { Name = "image-processor-${terraform.workspace}-images" }
}

# encriptar bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# habilitar versionamiento
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

# hacerlo privado
resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# reglas de expiracion
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.images.id

  # borrar lo subido en 30 dias
  rule {
    id     = "uploads-expiration"
    status = "Enabled"
    filter { prefix = "uploads/" }
    expiration { days = 30 }
  }

  # borrar lo procesado en 90 dias
  rule {
    id     = "processed-expiration"
    status = "Enabled"
    filter { prefix = "processed/" }
    expiration { days = 90 }
  }
}

# notificar a sqs cuando suben algo
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_sqs_queue_policy.main_policy]
}
