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
## 一括 plan 実行（shared -> dev -> prod）

複数環境の `init/plan` を順番に実行する場合は、以下を使います。

```powershell
# shared -> dev
powershell -ExecutionPolicy Bypass -File scripts/tf-plan-all.ps1

# shared -> dev -> prod
powershell -ExecutionPolicy Bypass -File scripts/tf-plan-all.ps1 -Scope all

# backend再設定付き
powershell -ExecutionPolicy Bypass -File scripts/tf-plan-all.ps1 -Scope all -ReconfigureInit
```

オプション:
- `-SkipSecretCheck`: 先頭の機密チェックをスキップ（通常は未指定推奨）
## 事前診断（doctor）

Terraform実行前に、CLI/認証/必要ファイルを確認できます。

```powershell
# 基本チェック
powershell -ExecutionPolicy Bypass -File scripts/tf-doctor.ps1

# AWS STS確認をスキップ（CLI導入直後など）
powershell -ExecutionPolicy Bypass -File scripts/tf-doctor.ps1 -SkipAwsSts

# secret guard も合わせて実行
powershell -ExecutionPolicy Bypass -File scripts/tf-doctor.ps1 -RunSecretGuard
```
## 初期セットアップ（まとめて実行）

```powershell
# hooks設定 + backend/tfvars の雛形作成
powershell -ExecutionPolicy Bypass -File scripts/tf-setup.ps1

# 既存ファイルも上書きして作り直す
powershell -ExecutionPolicy Bypass -File scripts/tf-setup.ps1 -Force

# セットアップ後に診断まで実行
powershell -ExecutionPolicy Bypass -File scripts/tf-setup.ps1 -RunDoctor
```
補足:
- `-SkipHooks`: `git config core.hooksPath` が権限都合で実行できない環境向け
## 安全 apply 実行

`apply` の前に `secret guard` と `plan` を必ず通すためのラッパーです。

```powershell
# dev apply（plan確認込み）
powershell -ExecutionPolicy Bypass -File scripts/tf-apply-safe.ps1 -Environment dev

# prod apply（明示トークン必須）
powershell -ExecutionPolicy Bypass -File scripts/tf-apply-safe.ps1 -Environment prod -ProdApproveToken apply-prod

# auto-approve で実行
powershell -ExecutionPolicy Bypass -File scripts/tf-apply-safe.ps1 -Environment dev -AutoApprove
```

オプション:
- `-SkipPlan`: 事前 `plan` を省略
- `-SkipSecretCheck`: 事前 `secret guard` を省略（通常は未指定推奨）
- `-ReconfigureInit`: `init -reconfigure` を実行
## 統合CLI（tf-cli.ps1）

複数スクリプトをまとめて呼び出す入口です。

```powershell
# secret check
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task secret-check

# doctor + secret guard
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task doctor -RunSecretGuard

# plan-all (shared -> dev -> prod)
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task plan-all -Scope all -ReconfigureInit

# safe apply (dev)
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task apply-safe -Environment dev

# raw run (tf.ps1 相当)
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task run -Environment dev -RunCommand plan
```
## ECSへ実バックエンドイメージを反映する手順

1. GitHub Actions `backend-image` で `enm/backend:<tag>` を ECR へ push
2. `infra/terraform/envs/dev/terraform.tfvars`（必要なら `prod` も）で以下を確認
   - `use_shared_ecr_image = true`
   - `api_image_tag = "<pushしたtag>"`
   - `runtime_enabled = true`
3. Terraform反映

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task plan-all -Scope shared-dev
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task apply-safe -Environment dev
```

prodへ反映する場合:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task plan-all -Scope all
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task apply-safe -Environment prod -ProdApproveToken apply-prod
```

## APIヘルスチェック（ALB + 独自ドメイン + ECSイベント）

```powershell
# dev の API ヘルスを確認（異常時は自動で ECS イベントも表示）
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task api-health -Environment dev

# prod で ECS イベントを常に表示したい場合
powershell -ExecutionPolicy Bypass -File scripts/tf-cli.ps1 -Task api-health -Environment prod -ShowEcsEvents
```

補足:
- `terraform.tfvars` の `runtime_enabled=false` の環境では、`api-health` は実行系未作成としてチェックをスキップします。

## GitHub Actions で dev デプロイ

- Workflow: `.github/workflows/dev-deploy.yml`
- 実行方法: Actions から `dev-deploy` を `workflow_dispatch` で実行
- 主要入力:
  - `aws_role_to_assume`: Terraform apply 用の OIDC ロール ARN
  - `tf_state_bucket`: Terraform state の S3 バケット名
  - `root_domain`: ルートドメイン（例: `enmusiquer.com`）
  - `image_tag`: デプロイする backend イメージタグ

処理内容:
1. `infra/terraform/envs/dev` で `init -> plan -> apply`
2. ECS service stable 待機
3. `ALB / APIドメイン` の `/health` をリトライ付きで確認
4. 失敗時に ECS events を表示

## backend-image ���� dev-deploy �������N������

`backend-image` workflow �� `trigger_dev_deploy` ��ǉ����܂����B

- `trigger_dev_deploy = true` �̂Ƃ��Aimage push ��� `dev-deploy` ������ dispatch
- `image_tag` �� `backend-image` �Ŏw�肵���l�����̂܂� `dev-deploy` �Ɉ����n��

�K�v�� Repository Variables:
- `AWS_ROLE_TO_ASSUME_DEV_DEPLOY`
- `TF_STATE_BUCKET`
- `ROOT_DOMAIN`

�C�ӂ� Repository Variables:
- `DEV_API_DOMAIN`�idefault: `api-dev.enmusiquer.com`�j
- `DEV_ECS_CLUSTER_NAME`�idefault: `enm-dev-cluster`�j
- `DEV_ECS_SERVICE_NAME`�idefault: `enm-dev-api`�j

## dev-deploy ���s�K�[�h

- `dev-deploy` �� `run_apply=true` �̏ꍇ�A`dev` �u�����`���s�̂݋����܂��B
- `backend-image` ����� `trigger_dev_deploy=true` �����A�g���A`dev` �u�����`���̂ݎ��s����܂��B

## dev-deploy �� apply ���F�g�[�N��

`dev-deploy` �ł� `run_apply=true` �̏ꍇ�A`apply_approve_token=apply-dev` ���K�{�ł��B

- �蓮���s��: `apply_approve_token` �� `apply-dev` �����
- `backend-image` ����̎����A�g��: ������ `apply-dev` ��ݒ肵�� dispatch

## dev-deploy Discord �ʒm�i�C�Ӂj

`dev-deploy` workflow �́A�ȉ� Secret ���ݒ肳��Ă���ꍇ�Ɍ��ʂ� Discord �֒ʒm���܂��B

- `DEV_DEPLOY_DISCORD_WEBHOOK`

�ʒm���e:
- ������: `dev-deploy success`�irepository / branch / image_tag / run URL�j
- ���s��: `dev-deploy failed`�irepository / branch / image_tag / run URL�j

## Webhook �̈���

- Discord Webhook URL �̓��|�W�g���֒��ڋL�ڂ��Ȃ��ł��������B
- GitHub �ł� Secret `DEV_DEPLOY_DISCORD_WEBHOOK` �ɂ̂ݐݒ肵�Ă��������B
- pre-commit / CI �� secret guard �́A���|�W�g���S�̂� Discord Webhook ����������m���Ď��s�����܂��B

## GitHub Variables/Secret �̈ꊇ�ݒ�

�ȉ��X�N���v�g�ŁAActions �� Variables ���ꊇ�o�^�ł��܂��B

- `scripts/setup_github_actions_config.ps1`

���s��:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_github_actions_config.ps1 `
  -Repository "AKADRA-SAKURA/Enmusiquer" `
  -TfStateBucket "enmusiquer-tfstate-785311025023-apne1" `
  -DeployRoleArn "arn:aws:iam::785311025023:role/enm-github-actions-terraform-dev" `
  -HealthRoleArn "arn:aws:iam::785311025023:role/enm-github-actions-dev-health" `
  -SetDiscordWebhookSecret
```

- `-SetDiscordWebhookSecret` ��t����ƁA`DEV_DEPLOY_DISCORD_WEBHOOK` ��Θb���͂� Secret �ɕۑ����܂��B
- ���O�� `gh auth login` ���K�v�ł��B
- ���f���e�m�F�����������ꍇ�� `-DryRun` ��t���Ă��������B
