# Runbook — plataforma Big Data local

Guia de operação e de problemas dos quatro repositórios (`bigdata-terraform`, `bigdata-ingestion-python`, `bigdata-dbt-modeling` e `bigdata-airflow-dags`). Os comandos partem da pasta deste repositório, salvo quando indicado.

## Operação

| Situação | Comando |
|---|---|
| Subir tudo do zero, ou depois de reiniciar a máquina | `scripts/platform.sh up` |
| Mudou código na ingestão ou no dbt | `scripts/platform.sh build` |
| Ver se está tudo no ar e atualizado | `scripts/platform.sh status` |
| Dados locais inconsistentes (veja abaixo) | `scripts/platform.sh reset`, depois reprocessar |

O `up` faz o seguinte, nesta ordem:
1. Sobe LocalStack, Hive Metastore e Trino.
2. Aplica o Terraform, que também gera `platform/local.env`.
3. Constrói as imagens de ingestão e dbt, gravando nelas o commit de cada repositório.
4. Sobe o Airflow.

Ele pode ser repetido sem risco. O `reset` é o único comando destrutivo e pede confirmação.

No Git Bash, o script já define `MSYS_NO_PATHCONV=1`. Para rodar `docker compose` à mão com caminhos como `/workspace`, defina essa variável também.

### Onde olhar

- **Airflow:** http://localhost:8080 (`airflow`/`airflow`). O log de cada task fica na UI e em `airflow-dags/logs/`.
- **Qual código rodou:** a primeira linha do log das tasks de container mostra `bigdata-ingestion commit <sha>` ou `bigdata-dbt commit <sha>`. O sufixo `-dirty` indica uma imagem construída com alterações não commitadas, e `dev` indica uma imagem construída sem o script.
- **Dados:** Trino em http://localhost:8081, ou `docker compose exec trino trino`. A bronze fica em `hive.bronze`, e a silver e a gold em `iceberg.silver` e `iceberg.gold`.

### Reprocessar datas

Na pasta `airflow-dags`. A data lógica D processa o dia D-1:

```bash
# Um dia (processa 2026-09-24)
docker compose exec airflow-scheduler airflow dags trigger bigdata_daily --logical-date 2026-09-25T03:00:00+00:00

# Intervalo (processa 2026-09-01 a 2026-09-09)
docker compose exec airflow-scheduler airflow backfill create --dag-id bigdata_daily --from-date 2026-09-02 --to-date 2026-09-10T23:00:00
```

Para refazer só uma parte do run, abra o run na UI, escolha a task e use **Clear** com **Downstream**. Tudo é idempotente: reprocessar não duplica dados.

## Problemas conhecidos

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| A DAG não aparece, e a UI mostra erro de import citando `platform/local.env` | O contrato da plataforma não foi gerado, ou este repositório não está em `../Terraform` | `scripts/platform.sh up`. Se o clone estiver em outro caminho, defina `BIGDATA_PLATFORM_DIR` antes de subir o Airflow |
| `ingestion run` falha com `BRONZE_BUCKET não definido` | Mesmo caso: falta `platform/local.env` | `scripts/platform.sh up` |
| Tasks falham com `NoSuchBucket`, ou consultas Iceberg falham com arquivo de metadados inexistente | O LocalStack reiniciou. Ele guarda os buckets em memória, mas o metastore (Postgres) sobreviveu e aponta para arquivos que sumiram | `scripts/platform.sh reset` e reprocessar as datas |
| Uma mudança de código não surtiu efeito, ou o comportamento é antigo | O Airflow executa a imagem `:local`, que não foi reconstruída | `scripts/platform.sh status` mostra `DESATUALIZADA`. Rode `scripts/platform.sh build`. A primeira linha do log da task confirma o commit |
| `register_<fonte>` falha com `ALREADY_EXISTS: One or more partitions already exist` | Duas sincronizações de partições da mesma tabela ao mesmo tempo, por exemplo um `register-local` manual durante um run | A nova tentativa automática normalmente resolve. Evite rodar `register-local` à mão com a DAG em execução |
| A task de container falha e o log só mostra `Task failed with exception`, sem saída do programa | O container morreu antes de começar: imagem inexistente, permissão na imagem ou `docker-proxy` fora do ar | Rode a imagem à mão para ver o erro (`docker compose run --rm dbt debug` em `dbt-modeling`, `docker compose run --rm ingestion list` em `ingestion-python`) e confira `scripts/platform.sh status` |
| `dbt_build_<domínio>` falha no teste `assert_gold_days_complete` | O dia não chegou à gold, ou alguma cidade não tem as 24 horas: API incompleta ou ingestão parcial | Veja no log do teste qual dia ou cidade falhou, confira o `ingest_<fonte>` da mesma data e reprocesse o dia |
| `dbt_build_<domínio>` falha em `relationships` de `city` | A silver tem uma cidade que não está em `open_meteo_locations` | Confira se a cidade está em `ingestion-python/src/ingestion/sources/open_meteo/config.py` e se `ingest_open_meteo_locations` rodou |
| `bronze_freshness` falha | Faz 2 dias ou mais que não chega dado novo na bronze: `bigdata_daily` pausada ou falhando | Veja os últimos runs de `bigdata_daily`, corrija e reprocesse os dias que faltam |
| Fora do local, o e-mail de alerta não chega | A conexão `smtp_default` não existe ou está sem `from_email` | O log da task mostra o erro de envio. Veja "Alertas e monitoramento" no README do `airflow-dags` |
| `ingest_rest_countries` falha com `REST_COUNTRIES_API_KEY não definida` ou `HTTP 401` | A chave não foi preenchida, ou foi recusada (plano gratuito expirado ou chave trocada) | Preencha ou atualize `platform/secrets.env` (modelo em `platform/secrets.env.example`). O Airflow lê o arquivo ao carregar a DAG, então não precisa reiniciar |
| `dbt_build_countries` falha em `assert_world_bank_countries_matched` | Um país do Banco Mundial ficou sem par na Rest Countries: código novo ou alterado numa das APIs | Veja o código no log do teste. Se for exceção legítima, documente-a no seed `country_code_crosswalk` (repositório dbt), com o motivo |
| `dbt_build_countries` falha em `assert_indicator_coverage` | Algum indicador ficou abaixo da cobertura mínima nos anos já publicados: API parcial ou revisão grande do Banco Mundial | Consulte `iceberg.gold.dq_indicator_coverage` (status `abaixo_do_minimo`). Se for queda real e duradoura, ajuste o mínimo no seed `world_bank_indicators`; se for falha pontual, reprocesse o dia |
| Aviso em `assert_population_sources_consistent` | A população da Rest Countries e a do Banco Mundial divergem mais de 25% | Só avisa. Hoje aparecem Chipre, Ucrânia, Micronésia e duas ilhas do Caribe, por diferença de metodologia. Um país novo na lista pode indicar par errado no relacionamento |
| `docker compose run ... terraform` falha com um caminho como `C:/Program Files/Git/workspace` | O Git Bash converteu o caminho | `export MSYS_NO_PATHCONV=1` |
| O build do Hive Metastore falha com `digest mismatch` | O JAR baixado não bate com o checksum fixado em `local/hive/Dockerfile` | Não ignore. Confira a versão no Maven Central (arquivo `.sha1`) e atualize a versão e o checksum juntos |

## Atualizar dependências

- **GitHub Actions, imagens base e providers do Terraform:** o Dependabot abre PRs mensais, agrupados, em cada repositório. A CI valida cada PR.
- **Python (ingestão e dbt):** as versões exatas ficam em `requirements*.lock`. Para atualizar, rode `scripts/lock.sh` no repositório, revise o diff e rode os testes (`docker compose run --rm --build tests`). Na ingestão, os limites ficam no `pyproject.toml`. No dbt, as versões de `dbt-core` e dos adapters ficam em `requirements.in`.
- **Airflow:** a versão fica em `AIRFLOW_VERSION`, no `Dockerfile`. Os providers seguem as constraints oficiais dessa versão, então atualizar o Airflow atualiza os dois juntos.
