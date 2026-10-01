# bigdata-terraform — infraestrutura e operação da plataforma

Base da plataforma de dados. Este repositório:

- provisiona a infraestrutura com Terraform: na AWS (S3 em camadas, IAM, Secrets Manager, Glue e Athena) e localmente (LocalStack, Hive Metastore e Trino em Docker);
- gera o **contrato da plataforma** (`platform/local.env`), que os outros repositórios leem em vez de repetir buckets e endereços, e guarda o arquivo local de chaves de API (`platform/secrets.env`);
- opera os quatro repositórios juntos com `scripts/platform.sh` e documenta a operação e os problemas conhecidos no [RUNBOOK.md](RUNBOOK.md).

## A plataforma

Este repositório é uma das quatro partes da plataforma de dados **bigdata**. Ela coleta dados públicos de APIs, organiza tudo num data lake em camadas (bronze → silver → gold) e entrega tabelas analíticas validadas. Tudo roda localmente em Docker, com LocalStack, Hive Metastore e Trino no lugar de S3, Glue e Athena, e está preparado para a AWS.

| Repositório | Papel |
|---|---|
| **bigdata-terraform** (este) | Infraestrutura (AWS e local), contrato da plataforma, operação (`scripts/platform.sh`) e runbook |
| [bigdata-ingestion-python](https://github.com/adimov-jb/bigdata-ingestion-python) | Ingestão das APIs para a camada bronze (Parquet no S3) |
| [bigdata-dbt-modeling](https://github.com/adimov-jb/bigdata-dbt-modeling) | Camadas silver e gold (Iceberg), relacionamento entre fontes e validação de qualidade |
| [bigdata-airflow-dags](https://github.com/adimov-jb/bigdata-airflow-dags) | Orquestração diária, alertas por e-mail e monitoramento de freshness |

| Domínio | Fontes | Principais tabelas na gold |
|---|---|---|
| Clima | [Open-Meteo](https://open-meteo.com/): tempo horário de 10 capitais brasileiras | `fct_weather_daily`, `dim_city` |
| Países | [Rest Countries v5](https://restcountries.com/) e [Banco Mundial](https://data.worldbank.org/): atributos dos países e indicadores socioeconômicos (PIB, inflação, expectativa de vida, pobreza, população) | `dim_country`, `fct_country_indicators_yearly`, `dq_indicator_coverage` |

Para subir e operar tudo junto, use o `scripts/platform.sh up` do repositório `bigdata-terraform`. Os problemas conhecidos estão no [RUNBOOK](https://github.com/adimov-jb/bigdata-terraform/blob/main/RUNBOOK.md).

## Ambientes

Há dois ambientes:

| Ambiente | Onde roda | O que provisiona |
|---|---|---|
| `envs/local` | Docker na sua máquina (LocalStack) | S3, IAM, Secrets Manager |
| `envs/dev` | Conta AWS real | Tudo de `local`, mais Glue Catalog e Athena |

## Equivalência local x AWS

| AWS | Local (docker-compose.yml) |
|---|---|
| S3, IAM, Secrets Manager | LocalStack (`localhost:4566`) |
| Glue Data Catalog | Hive Metastore (`hive-metastore:9083`), com banco Postgres (`hive-metastore-db`) |
| Athena | Trino (`localhost:8081`) |

O Athena é baseado em Trino e o Glue é compatível com Hive Metastore, então o SQL e os modelos dbt ficam praticamente iguais nos dois ambientes.

- Catálogo `hive` do Trino: camada bronze (tabelas externas em Parquet).
- Catálogo `iceberg` do Trino: camadas silver e gold.

## Pré-requisito

Somente o Docker Desktop. O Terraform roda em container, sem instalação local.

## Subir o ambiente local

O `scripts/platform.sh` opera os quatro repositórios de uma vez:

```bash
scripts/platform.sh up       # plataforma + terraform apply + imagens (com o commit) + Airflow
scripts/platform.sh build    # reconstrói as imagens de ingestão e dbt depois de mudar código
scripts/platform.sh status   # containers, contrato, imagens desatualizadas e erros de DAG
scripts/platform.sh reset    # apaga os dados locais e recria a plataforma vazia (pede confirmação)
```

O [RUNBOOK.md](RUNBOOK.md) explica a operação, o reprocessamento de datas e o que fazer em cada problema conhecido.

Para subir só a plataforma, à mão:

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
- Arquivo `platform/local.env`, com o contrato da plataforma (veja abaixo)

### Contrato da plataforma (`platform/local.env`)

O `apply` gera `platform/local.env` (código em `envs/local/platform.tf`) com o que os outros repositórios precisam saber da plataforma: buckets, endpoint e credenciais do LocalStack, e o endereço do Trino. Os composes da ingestão e do dbt carregam esse arquivo, e o Airflow repassa as variáveis dele aos containers das tasks. Nenhum desses repositórios repete esses valores.

- O arquivo não é versionado. Se ele não existir, rode o `apply` de novo.
- Os outros repositórios procuram a pasta em `../Terraform/platform`. Se o clone estiver em outro caminho, defina `BIGDATA_PLATFORM_DIR`.
- Para mudar um bucket ou endpoint, altere o Terraform e rode o `apply`. Depois, recrie os containers do Airflow (`docker compose up -d` em `airflow-dags`).

### Chaves de API (`platform/secrets.env`)

As chaves de API das fontes ficam em `platform/secrets.env`. Esse arquivo não é versionado: crie-o copiando `platform/secrets.env.example` e preencha as chaves. A ingestão e o Airflow o leem da mesma pasta do contrato. Hoje só existe `REST_COUNTRIES_API_KEY`.

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

A versão gratuita do LocalStack guarda os dados em memória, então **reiniciar o container apaga os buckets**. O metastore, ao contrário, fica no volume do Postgres e sobrevive.

O metastore usa Postgres, e não o Derby embutido, porque o Derby não suporta o commit atômico que as tabelas Iceberg fazem no Hive 4. Para voltar a um estado consistente:

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

## CI

O workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em todo PR e em todo push para a `main`, com `terraform fmt -check` e `terraform validate` em `envs/local` e `envs/dev`, sem backend e sem credenciais. Rode `docker compose run --rm --no-deps terraform fmt -recursive /workspace` antes de abrir o PR.

## Estrutura

```
docker-compose.yml     plataforma local
local/                 configs do Trino e do Hive Metastore (imagem com driver Postgres, com checksum)
scripts/platform.sh    operação do ambiente local (up, build, status, reset)
RUNBOOK.md             operação e problemas conhecidos
modules/
  platform/            base comum aos ambientes: buckets das camadas, roles e segredos
  storage/             buckets S3 (criptografia, bloqueio público, expiração)
  iam/                 roles ingestion, dbt e glue-crawler com privilégio mínimo
  secrets/             Secrets Manager (admin do Airflow)
  glue/                databases bronze/silver/gold e crawler da bronze (somente AWS)
  athena/              workgroup com limite de bytes por query (somente AWS)
envs/                  cada ambiente chama modules/platform e acrescenta o que é só dele
  local/               LocalStack: bucket do metastore; platform.tf gera platform/local.env
  dev/                 AWS: Glue e Athena
platform/              contrato da plataforma para os outros repositórios (local.env é gerado)
```
