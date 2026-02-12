# Terraform Layout

This directory manages AWS infrastructure in one account with three Terraform environments:

- `envs/shared`: shared foundation resources
- `envs/dev`: dev runtime resources
- `envs/prod`: prod runtime resources

`envs/shared` currently creates:

- VPC (`10.20.0.0/16` default)
- Public/Private subnets (2 AZ)
- Internet Gateway + route tables
- ECR repositories (`enm/backend`, `enm/frontend` default)
- Route53 hosted zone (`create_hosted_zone=true` by default)

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
3. If you already have a hosted zone, set:
   - `create_hosted_zone = false`
   - `existing_hosted_zone_id = "ZXXXXXXXXXXXX"`
4. In `envs/dev` and `envs/prod`, set:
   - `shared_state_bucket`
   - `shared_state_key` (default: `enm/shared/terraform.tfstate`)
   - `shared_state_region`

`envs/dev` and `envs/prod` read `envs/shared` outputs via `terraform_remote_state`.
Apply `shared` first.

Runtime resources in `envs/dev` and `envs/prod`:

- ALB
- ECS (Fargate)
- RDS PostgreSQL

These are controlled by `runtime_enabled`.
Set `runtime_enabled = false` during development to avoid runtime charges.
Switch to `true` only when starting actual release operation.

Always-on resources in `envs/dev` and `envs/prod`:

- App S3 bucket
- Cognito user pool + app client

`cloudfront`, `waf`, and `monitoring` modules are still placeholders.

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
