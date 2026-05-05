# vpc principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "image-processor-${terraform.workspace}-vpc"
  }
}

# las zonas disponibles
data "aws_availability_zones" "available" {
  state = "available"
}

# subred publica 1
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "image-processor-${terraform.workspace}-pub-a" }
}

# subred publica 2
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "image-processor-${terraform.workspace}-pub-b" }
}

# subred privada 1
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "image-processor-${terraform.workspace}-priv-a" }
}

# subred privada 2
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "image-processor-${terraform.workspace}-priv-b" }
}

# gateway de internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "image-processor-${terraform.workspace}-igw" }
}

# ips elasticas para el nat
resource "aws_eip" "nat_a" {
  domain = "vpc"
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
}

# nat gateway 1
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags = { Name = "image-processor-${terraform.workspace}-nat-a" }
  depends_on = [aws_internet_gateway.igw]
}

# nat gateway 2
resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  tags = { Name = "image-processor-${terraform.workspace}-nat-b" }
  depends_on = [aws_internet_gateway.igw]
}

# tabla de rutas publica
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "image-processor-${terraform.workspace}-rt-public" }
}

# asociar subredes publicas
resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# tabla de rutas privada 1
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }
  tags = { Name = "image-processor-${terraform.workspace}-rt-priv-a" }
}

# asociar privada 1
resource "aws_route_table_association" "priv_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

# tabla de rutas privada 2
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }
  tags = { Name = "image-processor-${terraform.workspace}-rt-priv-b" }
}

# asociar privada 2
resource "aws_route_table_association" "priv_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# endpoint para s3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_a.id, aws_route_table.private_b.id]
  tags = { Name = "image-processor-${terraform.workspace}-vpce-s3" }
}

# security group del endpoint de sqs
resource "aws_security_group" "vpce_sqs" {
  name        = "sg-vpce-sqs-${terraform.workspace}"
  description = "Security group for SQS VPC Endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.upload_lambda.id, aws_security_group.crop_lambda.id]
  }
  tags = { Name = "image-processor-${terraform.workspace}-sg-vpce-sqs" }
}

# endpoint para sqs
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpce_sqs.id]
  private_dns_enabled = true
  tags = { Name = "image-processor-${terraform.workspace}-vpce-sqs" }
}
