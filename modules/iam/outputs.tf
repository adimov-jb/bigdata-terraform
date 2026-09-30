output "role_arns" {
  description = "Mapa role => ARN (ingestion, dbt, glue-crawler)"
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}
