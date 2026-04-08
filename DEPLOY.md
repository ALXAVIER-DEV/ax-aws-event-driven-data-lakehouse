# Deploy

## 1. Bootstrap do State

Use o modulo em `bootstrap/` para criar o bucket de state na conta de management.

Exemplo:

```hcl
project_name          = "ax-onboarding"
management_account_id = "123456789012"
tags = {
  Project   = "ax-onboarding"
  ManagedBy = "Terraform"
}
```

Depois ajuste os arquivos em `environments/dev/backend.hcl`, `environments/hom/backend.hcl` e `environments/prod/backend.hcl` com o bucket real.

Referencia:

- `bootstrap/README.md`
- `bootstrap/bootstrap.tfvars.example`

## 2. Variaveis do Projeto

Crie um arquivo local a partir de `terraform.tfvars.example` e preencha:

- `dev_account_id`
- `hom_account_id`
- `prod_account_id`
- `alarm_topic_arn`, se quiser notificar alarmes via SNS

Se preferir trabalhar com arquivos separados por ambiente, use:

- `dev.tfvars.example`
- `hom.tfvars.example`
- `prod.tfvars.example`

## 3. Inicializacao

Para inicializar um ambiente:

```bash
terraform init -backend-config=environments/dev/backend.hcl
```

Troque `dev` por `hom` ou `prod` conforme necessario.

## 4. Planejamento

```bash
terraform plan -var-file=terraform.tfvars
```

Se quiser trocar o ambiente sem manter varios arquivos de variaveis:

```bash
terraform plan -var-file=terraform.tfvars -var="environment=dev"
```

Se estiver usando arquivos por ambiente:

```bash
terraform plan -var-file=dev.tfvars
```

## 5. Aplicacao

```bash
terraform apply -var-file=terraform.tfvars
```

## 6. O que sera criado

A stack raiz atual cria:

- SNS topic
- SQS queue
- SQS dead-letter queue
- S3 bucket do data lake
- IAM role da Lambda
- Lambda de ingestao
- Athena workgroup
- Glue job para carga automatizada da camada curated
- Alarmes CloudWatch basicos

## Observacoes

- O deploy multi-account agora e garantido por credencial separada por `environment` e por uma checagem que valida se a conta AWS ativa corresponde ao `environment` escolhido.
- A camada curated agora pode ser carregada automaticamente pelo Glue job agendado.
- O projeto agora inclui dashboard operacional, alarmes adicionais de Lambda/SQS e regra de falha do Glue para reforcar observabilidade.
- O script do Glue tambem suporta execucao local para testes unitarios sem depender do runtime `awsglue`.

## 7. Teste de Ponta a Ponta

Mensagem de teste sugerida para publicar no SNS:

```json
{
  "id": "msg-001",
  "mensagem": "Onbording aprendizagem serveless aws",
  "autor": "Alex"
}
```

Exemplo com AWS CLI:

```bash
aws sns publish \
  --topic-arn SEU_TOPIC_ARN \
  --message "{\"id\":\"msg-001\",\"mensagem\":\"Onbording aprendizagem serveless aws\",\"autor\":\"Alex\"}"
```

Verificacoes apos o publish:

1. Confirmar que a mensagem entrou na fila SQS principal.
2. Confirmar que a Lambda foi executada.
3. Conferir logs da Lambda no CloudWatch.
4. Validar se um arquivo foi gravado em `raw/messages/date=YYYYMMDD/`.
5. Confirmar que a DLQ permaneceu vazia.

Formato esperado no S3:

```json
{
  "event_id": "uuid-gerado",
  "ingestion_ts": "2026-04-02T00:00:00+00:00",
  "payload": {
    "id": "msg-001",
    "mensagem": "Onbording aprendizagem serveless aws",
    "autor": "Alex"
  }
}
```

## 8. Validacao no Athena

Crie o database:

```sql
CREATE DATABASE IF NOT EXISTS onboarding;
```

Crie a tabela raw:

```sql
CREATE TABLE IF NOT EXISTS onboarding.raw_messages_json (
  event_id string,
  ingestion_ts string,
  payload struct<
    id:string,
    mensagem:string,
    autor:string
  >
)
PARTITIONED BY (date string)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://SEU_BUCKET/raw/messages/';
```

Carregue as particoes:

```sql
MSCK REPAIR TABLE onboarding.raw_messages_json;
```

Consulte os dados:

```sql
SELECT
  event_id,
  ingestion_ts,
  payload.id,
  payload.mensagem,
  payload.autor,
  date
FROM onboarding.raw_messages_json
ORDER BY ingestion_ts DESC
LIMIT 20;
```

## 9. Camada Curated Automatizada

O projeto agora cria um Glue Python Shell agendado para automatizar a carga da camada curated.

Comportamento atual:

- cria o database e as tabelas do Athena, se ainda nao existirem
- executa `MSCK REPAIR TABLE` na camada raw
- recria a particao correspondente na camada curated
- grava os dados em parquet no prefixo `curated/messages/`

Outputs uteis:

```bash
terraform output -raw glue_curated_job_name
terraform output -raw glue_curated_trigger_name
```

Para executar manualmente um teste do job:

```bash
aws glue start-job-run --job-name NOME_DO_JOB --region sa-east-1
```

## 10. GitHub Actions

O repositorio inclui dois workflows:

- `.github/workflows/terraform-ci.yml`
- `.github/workflows/terraform-plan.yml`
- `.github/workflows/environment-smoke.yml`

Configuracao recomendada no GitHub:

1. Criar environments chamados `dev`, `hom` e `prod`.
2. Em cada environment, definir o secret `AWS_ROLE_ARN`.
3. Definir repository variables:

- `AWS_REGION`
- `PROJECT_NAME`
- `DEV_ACCOUNT_ID`
- `HOM_ACCOUNT_ID`
- `PROD_ACCOUNT_ID`

Variaveis opcionais:

- `ALARM_TOPIC_ARN`
- `CURATED_SCHEDULE_EXPRESSION`
- `TAG_OWNER`
- `TAG_COST_CENTER`

## 11. Validacoes Locais

Antes de abrir PR ou aplicar mudancas, rode:

```bash
terraform fmt -check -recursive
terraform validate
python -m compileall lambda_src glue_src tests
python -m unittest discover -s tests -v
python scripts/smoke_test.py --environment dev --mode static
```
