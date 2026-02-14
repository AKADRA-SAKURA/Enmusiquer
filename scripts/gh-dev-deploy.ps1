param(
  [string]$Repository = "AKADRA-SAKURA/Enmusiquer",
  [string]$Ref = "dev",
  [string]$AwsRegion = "ap-northeast-1",
  [string]$ImageTag = "manual",
  [string]$ApiDomain = "",
  [string]$EcrBackendRepo = "",
  [string]$EcsClusterName = "",
  [string]$EcsServiceName = "",
  [switch]$Watch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "必要なコマンドが見つかりません: $Name"
  }
}

function Require-GhAuth {
  $global:LASTEXITCODE = 0
  & gh auth status 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "gh の認証が未完了です。先に 'gh auth login' を実行してください。"
  }
}

function Assert-ImageTag([string]$Tag) {
  if ([string]::IsNullOrWhiteSpace($Tag)) {
    throw "ImageTag が未設定です。"
  }
  if ($Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$') {
    throw "ImageTag の形式が不正です: $Tag"
  }
}

function Assert-RequiredVariables([string]$Repo, [string[]]$Names) {
  foreach ($name in $Names) {
    $global:LASTEXITCODE = 0
    & gh variable get $name --repo $Repo 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
      throw "必須の GitHub Variable が不足しています: $name (repo: $Repo)"
    }
  }
}

Write-Host "== dev-deploy-v2 起動 ==" -ForegroundColor Cyan

Require-Command "gh"
Require-GhAuth
Assert-ImageTag -Tag $ImageTag

Assert-RequiredVariables -Repo $Repository -Names @(
  "AWS_ROLE_TO_ASSUME_DEV_DEPLOY",
  "TF_STATE_BUCKET",
  "ROOT_DOMAIN"
)

$runArgs = @(
  "workflow", "run", "dev-deploy-v2.yml",
  "--repo", $Repository,
  "--ref", $Ref,
  "-f", "aws_region=$AwsRegion",
  "-f", "image_tag=$ImageTag"
)

if (-not [string]::IsNullOrWhiteSpace($ApiDomain)) {
  $runArgs += @("-f", "api_domain=$ApiDomain")
}
if (-not [string]::IsNullOrWhiteSpace($EcrBackendRepo)) {
  $runArgs += @("-f", "ecr_backend_repo=$EcrBackendRepo")
}
if (-not [string]::IsNullOrWhiteSpace($EcsClusterName)) {
  $runArgs += @("-f", "ecs_cluster_name=$EcsClusterName")
}
if (-not [string]::IsNullOrWhiteSpace($EcsServiceName)) {
  $runArgs += @("-f", "ecs_service_name=$EcsServiceName")
}

& gh @runArgs

if ($LASTEXITCODE -ne 0) {
  throw "dev-deploy-v2 の起動に失敗しました。"
}

Write-Host "[OK] workflow を起動しました: dev-deploy-v2.yml (ref=$Ref, image_tag=$ImageTag)" -ForegroundColor Green

$global:LASTEXITCODE = 0
$runJson = & gh run list `
  --repo $Repository `
  --workflow dev-deploy-v2.yml `
  --branch $Ref `
  --event workflow_dispatch `
  --limit 1 `
  --json databaseId,status,conclusion,url,displayTitle

if ($LASTEXITCODE -eq 0 -and $runJson) {
  $runs = $runJson | ConvertFrom-Json
  if ($runs.Count -gt 0) {
    $run = $runs[0]
    Write-Host "最新Run: #$($run.databaseId) $($run.status) $($run.url)"
  }
}

if ($Watch) {
  Write-Host "== 最新 dev-deploy-v2 Run を監視 ==" -ForegroundColor Cyan
  & gh run watch --repo $Repository
}
