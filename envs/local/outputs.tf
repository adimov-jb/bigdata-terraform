output "bucket_names" {
  value = module.storage.bucket_names
}

output "role_arns" {
  value = module.iam.role_arns
}

output "airflow_admin_secret_name" {
  value = module.secrets.airflow_admin_secret_name
}
