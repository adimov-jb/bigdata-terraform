locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "storage" {
  source = "../../modules/storage"

  name_prefix   = local.name_prefix
  force_destroy = true

  buckets = {
    bronze           = {}
    silver           = {}
    gold             = {}
    "athena-results" = { expiration_days = 7 }
    "airflow-dags"   = {}
    # Só existe no ambiente local: warehouse padrão do Hive Metastore, que faz o papel do Glue Catalog.
    metastore = {}
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

# Glue e Athena não existem no LocalStack gratuito: localmente o Hive Metastore
# e o Trino (docker-compose.yml) cumprem esse papel. Os módulos entram em envs/dev.
