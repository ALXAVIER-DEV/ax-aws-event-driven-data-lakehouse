# Ax AWS Event-Driven Data Lakehouse

Projeto de arquitetura de dados na AWS com ingestao orientada a eventos, abordagem serverless e separacao por ambientes.

## Arquitetura Atual

Fluxo principal implementado na composicao Terraform raiz:

- SNS
- SQS
- Lambda de ingestao
- S3 para camada raw
- Athena Workgroup

Fluxo de dados:

`SNS -> SQS -> Lambda -> S3 raw -> Athena`

## Estrutura do Repositorio

- `main.tf`: compoe a stack principal
- `providers.tf`: providers AWS e aliases por ambiente
- `bootstrap/`: bucket de remote state
- `modules/`: modulos Terraform reutilizaveis
- `lambda_src/`: codigo Python da Lambda de ingestao
- `environmests/`: backends por ambiente

## Status do Projeto

Ja implementado:

- Bucket S3 do data lake com criptografia, versionamento e bloqueio publico
- Topico SNS e fila SQS integrados
- Dead-letter queue para mensagens com falha repetida
- Lambda consumindo da fila e gravando JSON particionado em S3
- Partial batch failure para reprocessamento seletivo no consumo SQS -> Lambda
- IAM role da Lambda
- Athena Workgroup
- Glue Python Shell para automatizar a carga da camada curated
- Alarmes basicos de Lambda, fila principal e DLQ
- Composicao da stack principal no root module

Ainda pendente:

- Estrategia final de deploy multi-account
- Dashboards e observabilidade mais completa

## Requisitos

- Terraform `>= 1.8.0`
- Credenciais AWS com permissao para assumir os roles de deploy
- Buckets de state configurados via `bootstrap/` ou previamente existentes

## Como Comecar

1. Copie `terraform.tfvars.example` para um arquivo local de variaveis.
2. Preencha os IDs reais das contas AWS.
3. Ajuste o backend do ambiente desejado em `environmests/<ambiente>/backend.hcl`.
4. Siga o passo a passo em [DEPLOY.md](DEPLOY.md).

## CI/CD

Workflows incluidos:

- `Terraform CI`: roda `terraform fmt -check`, `terraform init -backend=false` e `terraform validate`
- `Terraform Plan`: execucao manual por ambiente via GitHub Actions

Validacoes adicionais no CI:

- compilacao dos codigos Python da Lambda e do Glue
- testes unitarios locais em `tests/`

Para o workflow de `plan`, configure no GitHub:

- environments: `dev`, `hom`, `prod`
- secret por environment: `AWS_ROLE_ARN`
- repository vars: `AWS_REGION`, `PROJECT_NAME`, `CROSS_ACCOUNT_ROLE_NAME`
- repository vars: `DEV_ACCOUNT_ID`, `HOM_ACCOUNT_ID`, `PROD_ACCOUNT_ID`
- opcionais: `ALARM_TOPIC_ARN`, `CURATED_SCHEDULE_EXPRESSION`, `TAG_OWNER`, `TAG_COST_CENTER`

## SQLs de Referencia

Os SQLs para camada raw e curated estao em:

- `modules/athena/ddl/`
- `modules/athena/dml/`

Eles ainda usam placeholders e hoje servem como referencia para a proxima etapa da plataforma.

## Testes Locais

Checagens disponiveis no estado atual do repositorio:

```bash
terraform fmt -check -recursive
terraform validate
python -m compileall lambda_src glue_src tests
python -m unittest discover -s tests -v
```
