variable "name_prefix" {
  description = "Nome do workgroup, ex.: bigdata-dev"
  type        = string
}

variable "results_bucket_name" {
  description = "Bucket onde o Athena grava os resultados das queries"
  type        = string
}

variable "bytes_scanned_cutoff_per_query" {
  description = "Limite de bytes lidos por query (controle de custo). Padrão: 1 GB."
  type        = number
  default     = 1073741824
}

variable "force_destroy" {
  description = "Permite destruir o workgroup mesmo com queries salvas"
  type        = bool
  default     = false
}
