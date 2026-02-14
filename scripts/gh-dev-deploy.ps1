param(
  [string]$Repository = "AKADRA-SAKURA/Enmusiquer",
  [string]$Ref = "dev",
  [string]$AwsRegion = "ap-northeast-1",
  [string]$ImageTag = "manual",
  [switch]$Watch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Require-GhAuth {
  $global:LASTEXITCODE = 0
  & gh auth status 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "gh is not authenticated. Run 'gh auth login' first."
  }
}

function Assert-ImageTag([string]$Tag) {
  if ([string]::IsNullOrWhiteSpace($Tag)) {
    throw "ImageTag is empty."
  }
  if ($Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$') {
    throw "Invalid ImageTag format: $Tag"
  }
}

function Assert-RequiredVariables([string]$Repo, [string[]]$Names) {
  foreach ($name in $Names) {
    $global:LASTEXITCODE = 0
    & gh variable get $name --repo $Repo 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
      throw "Missing required GitHub variable: $name (repo: $Repo)"
    }
  }
}

Write-Host "== Trigger dev-deploy-v2 ==" -ForegroundColor Cyan

Require-Command "gh"
Require-GhAuth
Assert-ImageTag -Tag $ImageTag

Assert-RequiredVariables -Repo $Repository -Names @(
  "AWS_ROLE_TO_ASSUME_DEV_DEPLOY",
  "TF_STATE_BUCKET",
  "ROOT_DOMAIN"
)

& gh workflow run dev-deploy-v2.yml `
  --repo $Repository `
  --ref $Ref `
  -f "aws_region=$AwsRegion" `
  -f "image_tag=$ImageTag"

if ($LASTEXITCODE -ne 0) {
  throw "Failed to dispatch dev-deploy-v2."
}

Write-Host "[OK] workflow dispatched: dev-deploy-v2.yml (ref=$Ref, image_tag=$ImageTag)" -ForegroundColor Green

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
    Write-Host "Latest run: #$($run.databaseId) $($run.status) $($run.url)"
  }
}

if ($Watch) {
  Write-Host "== Watching latest dev-deploy-v2 run ==" -ForegroundColor Cyan
  & gh run watch --repo $Repository
}
