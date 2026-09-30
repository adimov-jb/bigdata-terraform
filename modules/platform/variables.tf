variable "project" {
  description = "Nome do projeto, primeira parte dos nomes, ex.: bigdata"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente, ex.: local ou dev"
  type        = string
}

variable "bucket_name_suffix" {
  description = "Sufixo dos buckets para garantir nome único global na AWS, ex.: -123456789012"
  type        = string
  default     = ""
}

variable "extra_buckets" {
  description = "Buckets além dos comuns (bronze, silver, gold, athena-results, airflow-dags)"
  type = map(object({
    expiration_days = optional(number)
  }))
  default = {}
}

variable "force_destroy" {
  description = "Permite destruir buckets com objetos dentro (use apenas fora de produção)"
  type        = bool
  default     = false
}

variable "secret_recovery_window_in_days" {
  description = "Dias de retenção após apagar um segredo (0 apaga na hora)"
  type        = number
  default     = 7
}
