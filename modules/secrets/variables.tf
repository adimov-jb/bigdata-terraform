variable "name_prefix" {
  description = "Prefixo do caminho dos segredos, ex.: bigdata/local"
  type        = string
}

variable "recovery_window_in_days" {
  description = "Dias de retenção após apagar o segredo (0 apaga na hora)"
  type        = number
  default     = 7
}
