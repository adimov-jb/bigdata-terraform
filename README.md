# Terraform — infraestrutura do projeto Big Data

Infraestrutura como código do pipeline: ingestão Python → S3 (Parquet/Iceberg) → dbt → Glue Catalog → Athena, orquestrado pelo Airflow.

Há dois ambientes:

| Ambiente | Onde roda | O que provisiona |
|---|---|---|
| `envs/local` | Docker na sua máquina (LocalStack) | S3, IAM, Secrets Manager |
| `envs/dev` | Conta AWS real | Tudo de `local`, mais Glue Catalog e Athena |

## Equivalência local x AWS

| AWS | Local (docker-compose.yml) |
|---|---|
| S3, IAM, Secrets Manager | LocalStack (`localhost:4566`) |
| Glue Data Catalog | Hive Metastore (`hive-metastore:9083`) |
| Athena | Trino (`localhost:8081`) |

O Athena é baseado em Trino e o Glue é compatível com Hive Metastore, então o SQL e os modelos dbt ficam praticamente iguais nos dois ambientes.

- Catálogo `hive` do Trino: camada bronze (tabelas externas em Parquet).
- Catálogo `iceberg` do Trino: camadas silver e gold.

## Pré-requisito

Somente o Docker Desktop. O Terraform roda em container, sem instalação local.

## Subir o ambiente local

```bash
# 1. Sobe LocalStack, Hive Metastore e Trino
docker compose up -d

# 2. Provisiona os recursos no LocalStack
docker compose run --rm terraform init
docker compose run --rm terraform apply
```

No Git Bash, exporte `MSYS_NO_PATHCONV=1` antes dos comandos acima; no PowerShell isso não é necessário.

Recursos criados:

- Buckets: `bigdata-local-{bronze,silver,gold,athena-results,airflow-dags,metastore}`
- Roles: `bigdata-local-{ingestion,dbt,glue-crawler}`
- Segredo: `bigdata/local/airflow/admin`

### Consultar

```bash
docker compose exec trino trino                   # CLI SQL
# ou a UI em http://localhost:8081

docker run --rm --network bigdata \
  -e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test -e AWS_DEFAULT_REGION=us-east-1 \
  amazon/aws-cli --endpoint-url http://localstack:4566 s3 ls
```

### Rede compartilhada

O compose cria a rede Docker `bigdata`. Os repositórios de ingestão, dbt e Airflow entram nela como rede externa e acessam `localstack:4566` e `trino:8080`.

### Limitação: LocalStack sem persistência

A versão gratuita do LocalStack guarda os dados em memória, então **reiniciar o container apaga os buckets**. O metastore, ao contrário, fica em volume e sobrevive. Para voltar a um estado consistente:

```bash
docker compose down -v
docker compose up -d
docker compose run --rm terraform apply -auto-approve
```

Depois é preciso reprocessar os dados pelo Airflow, porque as DAGs serão idempotentes.

## Ambiente AWS (`envs/dev`)

Ainda não foi aplicado; por enquanto só é validado:

```bash
docker run --rm -v "$PWD:/workspace" -w /workspace/envs/dev hashicorp/terraform:1.13 init -backend=false
docker run --rm -v "$PWD:/workspace" -w /workspace/envs/dev hashicorp/terraform:1.13 validate
```

Pendente para quando a conta existir:

- Bootstrap do bucket de state.
- Módulos `network`, `ecr`, `ecs` e o host do Airflow (EC2 ou MWAA).

## Estrutura

```
docker-compose.yml     plataforma local
local/                 configs do Trino e do Hive Metastore
modules/
  storage/             buckets S3 (criptografia, bloqueio público, expiração)
  iam/                 roles ingestion, dbt e glue-crawler com privilégio mínimo
  secrets/             Secrets Manager (admin do Airflow)
  glue/                databases bronze/silver/gold e crawler da bronze (somente AWS)
  athena/              workgroup com limite de bytes por query (somente AWS)
envs/
  local/               LocalStack
  dev/                 AWS
```
