variable "name_prefix" {
  description = "Prefixo das roles, ex.: bigdata-local"
  type        = string
}

variable "bucket_arns" {
  description = "Mapa chave => ARN do bucket. Precisa das chaves bronze, silver, gold e athena-results."
  type        = map(string)
}

variable "secret_arns" {
  description = "Segredos que a ingestão pode ler (chaves de API)"
  type        = list(string)
  default     = []
}
