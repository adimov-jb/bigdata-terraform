output "bucket_names" {
  value = module.storage.bucket_names
}

output "role_arns" {
  value = module.iam.role_arns
}

output "glue_database_names" {
  value = module.glue.database_names
}

output "athena_workgroup_name" {
  value = module.athena.workgroup_name
}

output "airflow_admin_secret_name" {
  value = module.secrets.airflow_admin_secret_name
}
