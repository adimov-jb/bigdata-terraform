data "aws_caller_identity" "current" {}

module "platform" {
  source = "../../modules/platform"

  project     = var.project
  environment = var.environment
  # Nome de bucket é único em toda a AWS: o id da conta evita colisão.
  bucket_name_suffix             = "-${data.aws_caller_identity.current.account_id}"
  force_destroy                  = true
  secret_recovery_window_in_days = 0
}

module "glue" {
  source = "../../modules/glue"

  name_prefix      = module.platform.name_prefix
  bucket_names     = module.platform.bucket_names
  crawler_role_arn = module.platform.role_arns["glue-crawler"]
}

module "athena" {
  source = "../../modules/athena"

  name_prefix         = module.platform.name_prefix
  results_bucket_name = module.platform.bucket_names["athena-results"]
  force_destroy       = true
}

# Pendente até a conta AWS existir e a escolha EC2 x MWAA ser confirmada:
# network, ecr, ecs e o host do Airflow.

moved {
  from = module.storage
  to   = module.platform.module.storage
}

moved {
  from = module.secrets
  to   = module.platform.module.secrets
}

moved {
  from = module.iam
  to   = module.platform.module.iam
}
