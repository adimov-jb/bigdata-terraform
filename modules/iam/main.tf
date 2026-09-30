terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  # role => serviço AWS que pode assumi-la
  roles = {
    ingestion    = "ecs-tasks.amazonaws.com"
    dbt          = "ecs-tasks.amazonaws.com"
    glue-crawler = "glue.amazonaws.com"
  }
}

data "aws_iam_policy_document" "assume" {
  for_each = local.roles

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [each.value]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.roles

  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json
}

# Ingestão: só escreve na bronze.
data "aws_iam_policy_document" "ingestion" {
  statement {
    sid       = "ListBronze"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.bucket_arns["bronze"]]
  }

  statement {
    sid       = "WriteBronze"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.bucket_arns["bronze"]}/*"]
  }

  dynamic "statement" {
    for_each = length(var.secret_arns) > 0 ? [1] : []

    content {
      sid       = "ReadSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.secret_arns
    }
  }
}

# dbt: lê a bronze, escreve silver/gold e consulta via Athena + Glue.
data "aws_iam_policy_document" "dbt" {
  statement {
    sid     = "ListBuckets"
    actions = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [
      for k in ["bronze", "silver", "gold", "athena-results"] : var.bucket_arns[k]
    ]
  }

  statement {
    sid       = "ReadBronze"
    actions   = ["s3:GetObject"]
    resources = ["${var.bucket_arns["bronze"]}/*"]
  }

  statement {
    sid     = "WriteCurated"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      for k in ["silver", "gold", "athena-results"] : "${var.bucket_arns[k]}/*"
    ]
  }

  statement {
    sid = "Athena"
    actions = [
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetWorkGroup",
      "athena:GetDataCatalog",
      "athena:ListDatabases",
      "athena:ListTableMetadata",
      "athena:GetTableMetadata",
    ]
    resources = ["*"]
  }

  statement {
    sid = "GlueCatalog"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:GetTableVersions",
      "glue:DeleteTableVersion",
    ]
    resources = ["*"]
  }
}

# Crawler: lê a bronze; o restante vem da policy gerenciada AWSGlueServiceRole.
data "aws_iam_policy_document" "glue_crawler" {
  statement {
    sid       = "ListBronze"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.bucket_arns["bronze"]]
  }

  statement {
    sid       = "ReadBronze"
    actions   = ["s3:GetObject"]
    resources = ["${var.bucket_arns["bronze"]}/*"]
  }
}

resource "aws_iam_role_policy" "ingestion" {
  name   = "ingestion"
  role   = aws_iam_role.this["ingestion"].id
  policy = data.aws_iam_policy_document.ingestion.json
}

resource "aws_iam_role_policy" "dbt" {
  name   = "dbt"
  role   = aws_iam_role.this["dbt"].id
  policy = data.aws_iam_policy_document.dbt.json
}

resource "aws_iam_role_policy" "glue_crawler" {
  name   = "glue-crawler"
  role   = aws_iam_role.this["glue-crawler"].id
  policy = data.aws_iam_policy_document.glue_crawler.json
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.this["glue-crawler"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
