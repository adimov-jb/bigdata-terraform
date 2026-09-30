#!/usr/bin/env bash
# Operação do ambiente local inteiro (Terraform, ingestão, dbt e Airflow).
#
#   scripts/platform.sh up       sobe a plataforma, aplica o Terraform, constrói as imagens e sobe o Airflow
#   scripts/platform.sh build    reconstrói as imagens de ingestão e dbt, gravando o commit de cada uma
#   scripts/platform.sh status   containers, contrato da plataforma, imagens desatualizadas e erros de DAG
#   scripts/platform.sh reset    apaga LocalStack e metastore e recria tudo vazio (pede confirmação)
#
# Os outros repositórios são procurados ao lado deste. Para outros caminhos, defina
# BIGDATA_INGESTION_DIR, BIGDATA_DBT_DIR e BIGDATA_AIRFLOW_DIR. Guia de problemas: RUNBOOK.md.
set -euo pipefail

# Git Bash: não converter caminhos como /workspace em caminhos do Windows.
export MSYS_NO_PATHCONV=1

# Caminho absoluto. No Git Bash, pwd -W devolve o formato do Windows (C:/...), que o git e o
# docker entendem mesmo com a conversão de caminhos desligada; fora dele, vale o pwd comum.
abs_path() { (cd "$1" && (pwd -W 2>/dev/null || pwd)); }

ROOT="$(abs_path "$(dirname "$0")/..")"
PARENT="$(dirname "$ROOT")"
INGESTION_DIR="${BIGDATA_INGESTION_DIR:-$PARENT/ingestion-python}"
DBT_DIR="${BIGDATA_DBT_DIR:-$PARENT/dbt-modeling}"
AIRFLOW_DIR="${BIGDATA_AIRFLOW_DIR:-$PARENT/airflow-dags}"

# Os composes dos outros repositórios leem o contrato daqui, mesmo que este repositório
# não esteja em ../Terraform.
BIGDATA_PLATFORM_DIR="$ROOT/platform"
export BIGDATA_PLATFORM_DIR

SCHEDULER=bigdata-airflow-airflow-scheduler-1

step() { printf '\n==> %s\n' "$*"; }

# Commit do código de um repositório; "-dirty" indica alterações não commitadas.
git_sha() { git -C "$1" describe --always --dirty --abbrev=7; }

require_repo() {
  if [ ! -d "$1/.git" ]; then
    echo "Repositório não encontrado em $1. Veja as variáveis BIGDATA_*_DIR no topo do script." >&2
    exit 1
  fi
}

platform_up() {
  step "Plataforma (LocalStack, Hive Metastore, Trino)"
  (cd "$ROOT" && docker compose up -d --wait)

  step "Terraform: recursos no LocalStack e platform/local.env"
  (cd "$ROOT" && docker compose run --rm terraform init -input=false >/dev/null \
    && docker compose run --rm terraform apply -auto-approve -input=false)
}

build_images() {
  require_repo "$INGESTION_DIR"
  require_repo "$DBT_DIR"
  local sha

  sha="$(git_sha "$INGESTION_DIR")"
  step "Imagem bigdata-ingestion:local (commit $sha)"
  (cd "$INGESTION_DIR" && GIT_SHA="$sha" docker compose build ingestion)

  sha="$(git_sha "$DBT_DIR")"
  step "Imagem bigdata-dbt:local (commit $sha)"
  (cd "$DBT_DIR" && GIT_SHA="$sha" docker compose build dbt)
}

airflow_up() {
  require_repo "$AIRFLOW_DIR"
  step "Airflow"
  (cd "$AIRFLOW_DIR" && docker compose up -d --build)
}

cmd_up() {
  platform_up
  build_images
  airflow_up
  step "Pronto"
  echo "Airflow: http://localhost:8080 (airflow/airflow) | Trino: http://localhost:8081"
  echo "DAGs novas nascem pausadas: airflow dags unpause bigdata_daily / bronze_freshness"
  echo "Confira com: scripts/platform.sh status"
}

image_status() {
  local image="$1" repo="$2" built current
  built="$(docker image inspect "$image" \
    --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' 2>/dev/null || true)"
  current="$(git_sha "$repo")"
  if [ -z "$built" ]; then
    printf '  %-26s NÃO EXISTE: rode scripts/platform.sh build\n' "$image"
  elif [ "$built" = "$current" ]; then
    printf '  %-26s ok (commit %s)\n' "$image" "$built"
  else
    printf '  %-26s DESATUALIZADA: imagem %s, código %s. Rode scripts/platform.sh build\n' \
      "$image" "$built" "$current"
  fi
}

cmd_status() {
  step "Containers"
  docker ps --filter "name=bigdata" --format '  {{.Names}}\t{{.Status}}' | sort

  step "Contrato da plataforma"
  if [ -f "$ROOT/platform/local.env" ]; then
    echo "  platform/local.env ok"
  else
    echo "  platform/local.env NÃO EXISTE: rode scripts/platform.sh up (ou terraform apply)"
  fi

  step "Imagens executadas pelo Airflow"
  image_status bigdata-ingestion:local "$INGESTION_DIR"
  image_status bigdata-dbt:local "$DBT_DIR"

  step "DAGs"
  if docker ps --format '{{.Names}}' | grep -qx "$SCHEDULER"; then
    local errors
    errors="$(docker exec "$SCHEDULER" airflow dags list-import-errors 2>/dev/null || true)"
    if echo "$errors" | grep -q "No data found"; then
      echo "  sem erros de import"
    else
      echo "$errors" | sed 's/^/  /'
    fi
    docker exec "$SCHEDULER" airflow dags list --columns dag_id,is_paused 2>/dev/null \
      | grep -E "bigdata_daily|bronze_freshness" | sed 's/^/  /'
  else
    echo "  Airflow fora do ar: rode scripts/platform.sh up"
  fi
}

cmd_reset() {
  echo "O reset APAGA todos os dados locais: buckets do LocalStack (bronze, silver, gold)"
  echo "e o banco do Hive Metastore. Depois é preciso reprocessar as datas pelo Airflow."
  if [ "${1:-}" != "--yes" ]; then
    read -r -p "Digite 'reset' para continuar: " answer
    if [ "$answer" != "reset" ]; then
      echo "Cancelado."
      exit 1
    fi
  fi
  step "Removendo a plataforma e os volumes"
  (cd "$ROOT" && docker compose down -v)
  platform_up
  step "Pronto. Reprocesse as datas, por exemplo:"
  echo "  docker compose exec airflow-scheduler airflow backfill create --dag-id bigdata_daily \\"
  echo "    --from-date <AAAA-MM-DD> --to-date <AAAA-MM-DD>T23:00:00   (na pasta airflow-dags)"
}

case "${1:-}" in
  up) cmd_up ;;
  build) build_images ;;
  status) cmd_status ;;
  reset) shift; cmd_reset "$@" ;;
  *)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
