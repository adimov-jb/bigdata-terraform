output "name_prefix" {
  description = "Prefixo dos recursos, ex.: bigdata-local"
  value       = local.name_prefix
}

output "bucket_names" {
  description = "Mapa chave => nome do bucket"
  value       = module.storage.bucket_names
}

output "bucket_arns" {
  description = "Mapa chave => ARN do bucket"
  value       = module.storage.bucket_arns
}

output "role_arns" {
  description = "Mapa role => ARN (ingestion, dbt, glue-crawler)"
  value       = module.iam.role_arns
}

output "airflow_admin_secret_name" {
  value = module.secrets.airflow_admin_secret_name
}
