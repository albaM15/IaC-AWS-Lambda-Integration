# grupo de seguridad del upload lambda
resource "aws_security_group" "upload_lambda" {
  name        = "upload-lambda-sg-${terraform.workspace}"
  description = "Security group for the upload lambda"
  vpc_id      = aws_vpc.main.id

  # salida a internet
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  tags = { Name = "image-processor-${terraform.workspace}-sg-upload" }
}

# grupo de seguridad del crop lambda
resource "aws_security_group" "crop_lambda" {
  name        = "crop-lambda-sg-${terraform.workspace}"
  description = "Security group for the crop lambda"
  vpc_id      = aws_vpc.main.id

  # salida a s3 y sqs
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "image-processor-${terraform.workspace}-sg-crop" }
}

# rol para el upload lambda
resource "aws_iam_role" "upload_lambda" {
  name = "upload-lambda-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# permiso basico
resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# permiso para la vpc
resource "aws_iam_role_policy_attachment" "upload_vpc" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# politica para s3
resource "aws_iam_policy" "upload_s3" {
  name = "upload-lambda-s3-policy-${terraform.workspace}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:PutObject"]
      Effect   = "Allow"
      Resource = "${aws_s3_bucket.images.arn}/uploads/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "upload_s3_attach" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = aws_iam_policy.upload_s3.arn
}

# rol para el crop lambda
resource "aws_iam_role" "crop_lambda" {
  name = "crop-lambda-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# politica para s3 y sqs del crop lambda
resource "aws_iam_policy" "crop_policy" {
  name = "crop-lambda-policy-${terraform.workspace}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      },
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.images.arn}/processed/*"
      },
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crop_policy_attach" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = aws_iam_policy.crop_policy.arn
}
