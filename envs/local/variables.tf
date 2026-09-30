variable "project" {
  type    = string
  default = "bigdata"
}

variable "environment" {
  type    = string
  default = "local"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "localstack_endpoint" {
  description = "Endpoint do LocalStack visto de dentro da rede do docker compose"
  type        = string
  default     = "http://localstack:4566"
}
