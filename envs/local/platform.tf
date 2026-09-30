# Contrato da plataforma local para os outros repositórios (ingestão, dbt e Airflow).
# O apply grava platform/local.env; os composes e o Airflow leem esse arquivo em vez
# de repetir nomes de buckets, endpoint e credenciais.

locals {
  platform_env = {
    # Credenciais fictícias do LocalStack (as mesmas de providers.tf).
    AWS_ACCESS_KEY_ID     = "test"
    AWS_SECRET_ACCESS_KEY = "test"
    AWS_DEFAULT_REGION    = var.aws_region
    AWS_ENDPOINT_URL      = var.localstack_endpoint

    BRONZE_BUCKET = module.storage.bucket_names["bronze"]
    SILVER_BUCKET = module.storage.bucket_names["silver"]
    GOLD_BUCKET   = module.storage.bucket_names["gold"]

    # Serviço trino do docker-compose.yml, visto de dentro da rede bigdata.
    TRINO_HOST = "trino"
    TRINO_PORT = "8080"
  }
}

resource "local_file" "platform_env" {
  filename        = "${path.root}/../../platform/local.env"
  file_permission = "0644"
  content = join("\n", concat(
    ["# Gerado pelo Terraform (envs/local/platform.tf). Não edite: rode terraform apply."],
    [for key in sort(keys(local.platform_env)) : "${key}=${local.platform_env[key]}"],
    [""],
  ))
}
