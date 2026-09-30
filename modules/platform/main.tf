# Base comum a todos os ambientes: buckets das camadas, roles e segredos.
# Cada ambiente (envs/*) chama este módulo e acrescenta só o que é dele
# (local: bucket do metastore e platform/local.env; dev: Glue e Athena).

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Buckets que todo ambiente tem; extra_buckets acrescenta os específicos.
  buckets = merge(
    {
      bronze           = {}
      silver           = {}
      gold             = {}
      "athena-results" = { expiration_days = 7 }
      "airflow-dags"   = {}
    },
    var.extra_buckets,
  )
}

module "storage" {
  source = "../storage"

  name_prefix   = local.name_prefix
  name_suffix   = var.bucket_name_suffix
  force_destroy = var.force_destroy
  buckets       = local.buckets
}

module "secrets" {
  source = "../secrets"

  name_prefix             = "${var.project}/${var.environment}"
  recovery_window_in_days = var.secret_recovery_window_in_days
}

module "iam" {
  source = "../iam"

  name_prefix = local.name_prefix
  bucket_arns = module.storage.bucket_arns
}
