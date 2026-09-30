output "bucket_names" {
  description = "Mapa chave => nome do bucket"
  value       = { for k, b in aws_s3_bucket.this : k => b.bucket }
}

output "bucket_arns" {
  description = "Mapa chave => ARN do bucket"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}
