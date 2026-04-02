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

Depois ajuste os arquivos em `environmests/dev/backend.hcl`, `environmests/hom/backend.hcl` e `environmests/prod/backend.hcl` com o bucket real.

Referencia:

- `bootstrap/README.md`
- `bootstrap/bootstrap.tfvars.example`

## 2. Variaveis do Projeto

Crie um arquivo local a partir de `terraform.tfvars.example` e preencha:

- `dev_account_id`
- `hom_account_id`
- `prod_account_id`
- `cross_account_role_name`, se o nome do role for diferente
- `alarm_topic_arn`, se quiser notificar alarmes via SNS

Se preferir trabalhar com arquivos separados por ambiente, use:

- `dev.tfvars.example`
- `hom.tfvars.example`
- `prod.tfvars.example`

## 3. Inicializacao

Para inicializar um ambiente:

```bash
terraform init -backend-config=environmests/dev/backend.hcl
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
- Alarmes CloudWatch basicos

## Observacoes

- O projeto ja possui aliases de provider para `dev`, `hom` e `prod`, mas a composicao atual ainda nao instancia modulos separados por conta.
- A camada curated ainda nao e aplicada automaticamente.
- Antes de aplicar em producao, ainda vale adicionar testes de deploy, dashboards e tratamento mais completo de observabilidade.
