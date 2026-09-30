output "bucket_names" {
  value = module.storage.bucket_names
}

output "role_arns" {
  value = module.iam.role_arns
}

output "airflow_admin_secret_name" {
  value = module.secrets.airflow_admin_secret_name
}

output "platform_env_file" {
  description = "Arquivo com o contrato da plataforma, lido pela ingestão, pelo dbt e pelo Airflow"
  # Relativo à raiz do repositório (o Terraform roda em container, com outro caminho absoluto).
  value = "platform/local.env"
}
