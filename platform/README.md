# platform/

`local.env` é gerado pelo `terraform apply` de `envs/local` (veja `envs/local/platform.tf`) e não é versionado.

Ele concentra o que os outros repositórios precisam saber da plataforma local: buckets, endpoint e credenciais do LocalStack, e o endereço do Trino. A ingestão e o dbt o carregam no `docker-compose.yml`. O Airflow monta esta pasta e repassa as variáveis aos containers das tasks.

Por padrão, os outros repositórios procuram esta pasta em `../Terraform/platform`. Se o repositório estiver clonado em outro caminho, defina `BIGDATA_PLATFORM_DIR` com o caminho da pasta.

`secrets.env` guarda as chaves de API das fontes (por exemplo, `REST_COUNTRIES_API_KEY`). Ele também não é versionado: crie-o a partir de `secrets.env.example`. O Airflow repassa cada chave só para a task da fonte que a usa.
