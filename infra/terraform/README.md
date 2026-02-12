# Terraform 構成

このディレクトリでは、1つのAWSアカウント内で以下3つのTerraform環境を管理します。

- `envs/shared`: 共通基盤リソース
- `envs/dev`: 開発環境の実行系リソース
- `envs/prod`: 本番環境の実行系リソース

## `envs/shared` で作成するもの

- VPC（デフォルト: `10.20.0.0/16`）
- Public / Private サブネット（2AZ）
- Internet Gateway + ルートテーブル
- ECRリポジトリ（デフォルト: `enm/backend`, `enm/frontend`）
- ECRライフサイクルポリシー（デフォルトで最新50件保持）
- Route53 Hosted Zone（デフォルト: `create_hosted_zone=true`）

## 前提条件

- Terraform `>= 1.6.0`
- AWS認証情報が設定済み（`aws configure` または SSO）
- リモートステート/ロック用の S3 バケットが作成済み

## CI

- GitHub Actions: `.github/workflows/terraform-validate.yml`
- `envs/shared`, `envs/dev`, `envs/prod` に対して `fmt -check` と `validate` を実行
- CIの `init` は `-backend=false` で実行

## 1) backendファイルの設定

以下のプレースホルダを実環境値に置き換えてください。

- `envs/shared/backend.hcl`
- `envs/dev/backend.hcl`
- `envs/prod/backend.hcl`

必須項目:

- `bucket`
- `key`
- `region`
- `use_lockfile`

`dynamodb_table` は非推奨のため、本構成では使用しません。

## 2) tfvars の作成

各環境で以下を実施します。

1. `terraform.tfvars.example` を `terraform.tfvars` としてコピー
2. `root_domain` など環境固有の値を設定
3. 既存のHosted Zoneを使う場合は以下を設定
   - `create_hosted_zone = false`
   - `existing_hosted_zone_id = "ZXXXXXXXXXXXX"`
4. `envs/dev` と `envs/prod` では以下も設定
   - `shared_state_bucket`
   - `shared_state_key`（デフォルト: `enm/shared/terraform.tfstate`）
   - `shared_state_region`

`envs/dev` と `envs/prod` は `terraform_remote_state` で `envs/shared` の出力を参照します。  
必ず `shared` を先に適用してください。

## 実行系リソース（`dev` / `prod`）

- ALB
- ECS（Fargate）
- RDS PostgreSQL

上記は `runtime_enabled` で作成を制御します。  
開発中の課金を抑えるため、通常は `runtime_enabled = false`。  
実際に公開運用を開始する時点で `true` に切り替えます。

### ECSイメージ指定

- `use_shared_ecr_image = true` の場合:
  - `shared` の出力 `repository_urls["backend"]` と `api_image_tag` を組み合わせて使用
- `use_shared_ecr_image = false` の場合:
  - `api_container_image` をそのまま使用

### ECSコンテナ実行設定

- `api_environment_variables`: 追加の平文環境変数
- `api_secret_arns`: 追加のシークレット参照（`name => secret ARN`）
- `runtime_enabled=true` 時は `DB_HOST` と `DB_MASTER_SECRET_ARN` を自動注入

## 常時作成リソース（`dev` / `prod`）

- App用S3バケット
- Cognito User Pool + App Client

## 任意作成リソース（`dev` / `prod`）

- CloudFront（`edge_enabled`）
- ALB向けWAF（`edge_enabled && runtime_enabled`）
- CloudWatchアラーム（`monitoring_enabled && runtime_enabled`）
- Discord通知ブリッジ（`discord_alert_enabled`）
- Route53 Aliasレコード（`create_dns_records`）

現在のWAFは `REGIONAL` スコープで ALB に関連付ける設計です。

### CloudFrontを独自ドメインで使う場合

- `cloudfront_aliases`
- `cloudfront_acm_certificate_arn`（`us-east-1` の証明書が必要）

### DNSレコードを作成する場合

- `create_dns_records = true`
- `api_record_name`（例: `api-dev` / `api`）
- `cdn_record_name`（例: `cdn-dev` / `cdn`）

### CloudWatchアラームをDiscordへ通知する場合

- `discord_alert_enabled = true`
- `discord_webhook_url = "<Discord Incoming Webhook URL>"`
- `monitoring_enabled = true`（アラーム作成が必要）

通知先の優先順位:

- `monitoring_alarm_actions` が空でない場合: その値を使用
- `monitoring_alarm_actions` が空で `discord_alert_enabled=true` の場合: 自動生成SNSトピック（Discord連携）を使用

## 3) 適用順序

適用順は以下です。

1. `shared`
2. `dev`
3. `prod`

例（`shared`）:

```powershell
cd infra/terraform/envs/shared
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

`dev` / `prod` も同じ手順で実行してください。

## Secret guard (local)

See `infra/terraform/SECURITY.md` for details.

Quick setup:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install_git_hooks.ps1
```

Manual run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_terraform_secrets.ps1
```
## Terraform実行ラッパー（PowerShell）

PowerShellで `-chdir` や引数解釈に詰まりやすいため、ラッパーを追加しました。

```powershell
# 例: dev validate
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment dev -Command validate

# 例: shared init（reconfigure）
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment shared -Command init -Reconfigure

# 例: dev plan
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment dev -Command plan

# 例: prod apply
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment prod -Command apply
```

オプション:
- `-InitIfNeeded`: `validate/plan/apply` 実行時に `.terraform` が無ければ先に `init`
- `-AutoApprove`: `apply` 時に `-auto-approve` を付与
- `-VarFile`: `terraform.tfvars` 以外を使う場合に指定