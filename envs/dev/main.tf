data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "storage" {
  source = "../../modules/storage"

  name_prefix = local.name_prefix
  # Nome de bucket é único em toda a AWS: o id da conta evita colisão.
  name_suffix   = "-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  buckets = {
    bronze           = {}
    silver           = {}
    gold             = {}
    "athena-results" = { expiration_days = 7 }
    "airflow-dags"   = {}
  }
}

module "secrets" {
  source = "../../modules/secrets"

  name_prefix             = "${var.project}/${var.environment}"
  recovery_window_in_days = 0
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  bucket_arns = module.storage.bucket_arns
}

module "glue" {
  source = "../../modules/glue"

  name_prefix      = local.name_prefix
  bucket_names     = module.storage.bucket_names
  crawler_role_arn = module.iam.role_arns["glue-crawler"]
}

module "athena" {
  source = "../../modules/athena"

  name_prefix         = local.name_prefix
  results_bucket_name = module.storage.bucket_names["athena-results"]
  force_destroy       = true
}

# Pendente até a conta AWS existir e a escolha EC2 x MWAA ser confirmada:
# network, ecr, ecs e o host do Airflow.
