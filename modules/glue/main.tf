terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_glue_catalog_database" "this" {
  for_each = toset(["bronze", "silver", "gold"])

  # Glue/Athena não aceitam hífen em nome de database.
  name         = replace("${var.name_prefix}_${each.key}", "-", "_")
  location_uri = "s3://${var.bucket_names[each.key]}/"
}

resource "aws_glue_crawler" "bronze" {
  name          = "${var.name_prefix}-bronze"
  role          = var.crawler_role_arn
  database_name = aws_glue_catalog_database.this["bronze"].name

  s3_target {
    path = "s3://${var.bucket_names["bronze"]}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}
