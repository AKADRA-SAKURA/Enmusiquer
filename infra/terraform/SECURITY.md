# Terraform機密情報の扱い

Terraform運用でGitHubへ公開してはいけない情報を、このプロジェクトで統一するためのルールです。

## Gitに含めないもの

- `terraform.tfvars`
- `*.auto.tfvars`
- `*.tfvars.json`
- `*.tfstate*`
- 実値入りの `backend.hcl`
- Discord Webhook URL
- AWSアクセスキー/シークレット

## いまの実装方針

- `terraform.tfvars` は `.gitignore` 済み
- `infra/terraform/envs/*/backend.hcl` は `.gitignore` 済み
- リポジトリには `backend.hcl.example` を配置
- CI (`terraform-secret-guard.yml`) で漏れを検知して失敗させる

## ローカルセットアップ

1. `backend.hcl.example` を `backend.hcl` としてコピー
2. `backend.hcl` の `bucket` などを自分の値に編集
3. `terraform.tfvars.example` を `terraform.tfvars` としてコピー
4. `terraform.tfvars` に機密値を記入（Git管理しない）

PowerShell例:

```powershell
Copy-Item infra/terraform/envs/shared/backend.hcl.example infra/terraform/envs/shared/backend.hcl -Force
Copy-Item infra/terraform/envs/dev/backend.hcl.example infra/terraform/envs/dev/backend.hcl -Force
Copy-Item infra/terraform/envs/prod/backend.hcl.example infra/terraform/envs/prod/backend.hcl -Force
```
## 既に追跡済みの場合（1回だけ実行）

既に `backend.hcl` がGit追跡対象の場合は、次を1回実行してインデックスから外してください。

```powershell
git rm --cached infra/terraform/envs/shared/backend.hcl
git rm --cached infra/terraform/envs/dev/backend.hcl
git rm --cached infra/terraform/envs/prod/backend.hcl
```

その後、`backend.hcl` は `.gitignore` によりローカル専用になります。

## Local pre-commit guard (recommended)

Before your first commit in this clone:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install_git_hooks.ps1
```

Manual check (can be run any time):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_terraform_secrets.ps1
```

This blocks commits when:
- `terraform.tfvars` / `*.tfstate*` are tracked
- `infra/terraform/envs/*/backend.hcl` is tracked by Git
- `infra/terraform/envs/*/backend.hcl.example` loses placeholder bucket value
- Discord webhook URL or AWS key patterns are detected in `infra/terraform`

## Terraform実行の推奨方法

PowerShellでは引数解釈差異が起きやすいため、以下のラッパー経由を推奨します。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment shared -Command init -Reconfigure
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment shared -Command plan
powershell -ExecutionPolicy Bypass -File scripts/tf.ps1 -Environment dev -Command validate
```