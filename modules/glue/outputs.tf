output "database_names" {
  description = "Mapa camada => nome do database no Glue"
  value       = { for k, d in aws_glue_catalog_database.this : k => d.name }
}

output "bronze_crawler_name" {
  value = aws_glue_crawler.bronze.name
}
