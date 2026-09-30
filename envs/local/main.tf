module "platform" {
  source = "../../modules/platform"

  project                        = var.project
  environment                    = var.environment
  force_destroy                  = true
  secret_recovery_window_in_days = 0

  extra_buckets = {
    # Só existe no ambiente local: warehouse padrão do Hive Metastore, que faz o papel do Glue Catalog.
    metastore = {}
  }
}

# Glue e Athena não existem no LocalStack gratuito: localmente o Hive Metastore
# e o Trino (docker-compose.yml) cumprem esse papel. Os módulos entram em envs/dev.

# Os recursos saíram da raiz do ambiente para o módulo platform: sem estes blocos,
# o Terraform destruiria e recriaria tudo em vez de só mudar o endereço no state.
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
