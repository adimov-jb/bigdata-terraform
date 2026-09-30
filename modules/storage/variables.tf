variable "name_prefix" {
  description = "Prefixo dos buckets, ex.: bigdata-local"
  type        = string
}

variable "name_suffix" {
  description = "Sufixo opcional para garantir nome único global na AWS, ex.: -123456789012"
  type        = string
  default     = ""
}

variable "buckets" {
  description = "Buckets a criar. A chave vira parte do nome; expiration_days apaga objetos antigos."
  type = map(object({
    expiration_days = optional(number)
  }))
}

variable "force_destroy" {
  description = "Permite destruir buckets com objetos dentro (use apenas fora de produção)"
  type        = bool
  default     = false
}
