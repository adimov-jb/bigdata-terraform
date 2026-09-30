output "bucket_names" {
  value = module.platform.bucket_names
}

output "role_arns" {
  value = module.platform.role_arns
}

output "airflow_admin_secret_name" {
  value = module.platform.airflow_admin_secret_name
}

output "platform_env_file" {
  description = "Arquivo com o contrato da plataforma, lido pela ingestão, pelo dbt e pelo Airflow"
  # Relativo à raiz do repositório (o Terraform roda em container, com outro caminho absoluto).
  value = "platform/local.env"
}
