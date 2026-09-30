output "airflow_admin_secret_arn" {
  value = aws_secretsmanager_secret.airflow_admin.arn
}

output "airflow_admin_secret_name" {
  value = aws_secretsmanager_secret.airflow_admin.name
}
