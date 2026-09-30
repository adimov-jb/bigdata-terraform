variable "name_prefix" {
  description = "Prefixo dos recursos, ex.: bigdata-dev"
  type        = string
}

variable "bucket_names" {
  description = "Mapa chave => nome do bucket. Precisa das chaves bronze, silver e gold."
  type        = map(string)
}

variable "crawler_role_arn" {
  description = "Role assumida pelo crawler da bronze"
  type        = string
}
