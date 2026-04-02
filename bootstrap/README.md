# Bootstrap do Remote State

Este modulo cria o bucket S3 usado como backend remoto do Terraform.

## O que ele cria

- Bucket S3 para state
- Versionamento
- Criptografia server-side
- Bloqueio de acesso publico

## Como usar

1. Crie um arquivo local de variaveis a partir de `bootstrap.tfvars.example`.
2. Preencha o `management_account_id` real.
3. Execute o bootstrap a partir da pasta `bootstrap/`.

Exemplo:

```bash
terraform init
terraform plan -var-file=bootstrap.tfvars
terraform apply -var-file=bootstrap.tfvars
```

## Saida esperada

O nome do bucket segue este padrao:

`<project_name>-tfstate-<management_account_id>`

Depois de criar o bucket, atualize os arquivos em:

- `environmests/dev/backend.hcl`
- `environmests/hom/backend.hcl`
- `environmests/prod/backend.hcl`

## Observacoes

- O bootstrap deve ser executado na conta de management ou admin.
- Se quiser endurecer ainda mais o backend, o proximo passo natural e adicionar DynamoDB para state locking.
