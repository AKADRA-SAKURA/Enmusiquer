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
- ECR lifecycle policy (keep last 50 images by default)
- Route53 hosted zone (`create_hosted_zone=true` by default)

## Prerequisites

- Terraform `>= 1.6.0`
- AWS credentials configured (`aws configure` or SSO)
- Existing S3 bucket and DynamoDB table for remote state/lock

## CI

- GitHub Actions: `.github/workflows/terraform-validate.yml`
- Runs `fmt -check` and `validate` for `envs/shared`, `envs/dev`, `envs/prod`
- `init` uses `-backend=false` in CI

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

ECS image selection:

- `use_shared_ecr_image = true`: uses `shared` output `repository_urls["backend"]` + `api_image_tag`
- `use_shared_ecr_image = false`: uses `api_container_image` directly

ECS container runtime settings:

- `api_environment_variables`: additional plain environment variables
- `api_secret_arns`: additional secret refs (`name => secret ARN`)
- When `runtime_enabled=true`, `DB_HOST` and `DB_MASTER_SECRET_ARN` are auto-injected

Always-on resources in `envs/dev` and `envs/prod`:

- App S3 bucket
- Cognito user pool + app client

Optional resources in `envs/dev` and `envs/prod`:

- CloudFront (`edge_enabled`)
- WAF for ALB (`edge_enabled && runtime_enabled`)
- CloudWatch alarms (`monitoring_enabled && runtime_enabled`)
- Route53 alias records (`create_dns_records`)

Current WAF module scope is `REGIONAL` and associates to ALB.

For CloudFront custom domain, also set:

- `cloudfront_aliases`
- `cloudfront_acm_certificate_arn` (must be in `us-east-1`)

For DNS records, set:

- `create_dns_records = true`
- `api_record_name` (for example `api-dev` / `api`)
- `cdn_record_name` (for example `cdn-dev` / `cdn`)

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
