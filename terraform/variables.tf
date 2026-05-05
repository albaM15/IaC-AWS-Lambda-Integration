# entorno actual
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# para que no choque el nombre del bucket
variable "suffix" {
  description = "Unique suffix"
  type        = string
  default     = "alba"
}


variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

# cidr de la red
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}
