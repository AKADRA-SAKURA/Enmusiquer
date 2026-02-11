# Terraform Layout

This directory manages AWS infrastructure in one account with three Terraform environments:

- `envs/shared`: shared foundation resources
- `envs/dev`: dev runtime resources
- `envs/prod`: prod runtime resources

## Prerequisites

- Terraform `>= 1.6.0`
- AWS credentials configured (`aws configure` or SSO)
- Existing S3 bucket and DynamoDB table for remote state/lock

## 1) Configure backend files

Replace placeholders in:

- `envs/shared/backend.hcl`
- `envs/dev/backend.hcl`
- `envs/prod/backend.hcl`

Required fields:

- `bucket`
- `dynamodb_table`

## 2) Create tfvars from examples

For each environment:

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Set `root_domain` and any environment-specific values

## 3) Apply order

Apply in this order:

1. `shared`
2. `dev`
3. `prod`

Example (`shared`):

```powershell
cd infra/terraform/envs/shared
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Use the same sequence in `envs/dev` and `envs/prod`.
