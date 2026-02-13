param(
  [string]$Repository = "AKADRA-SAKURA/Enmusiquer",
  [string]$AwsRegion = "ap-northeast-1",
  [string]$RootDomain = "enmusiquer.com",
  [string]$TfStateBucket = "",
  [string]$DevApiDomain = "api-dev.enmusiquer.com",
  [string]$DevAlbName = "enm-dev-alb",
  [string]$DevEcsClusterName = "enm-dev-cluster",
  [string]$DevEcsServiceName = "enm-dev-api",
  [string]$DeployRoleArn = "",
  [string]$HealthRoleArn = "",
  [switch]$SetDiscordWebhookSecret,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Set-RepoVariable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Variable value is empty: $Name"
  }

  if ($DryRun) {
    Write-Host "[DRY-RUN] gh variable set $Name --repo $Repository"
    return
  }

  & gh variable set $Name --body $Value --repo $Repository
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to set variable: $Name"
  }
  Write-Host "[OK] variable set: $Name"
}

if (-not $DryRun) {
  Ensure-Command "gh"
}

if ([string]::IsNullOrWhiteSpace($TfStateBucket)) {
  throw "TfStateBucket is required. Example: -TfStateBucket enmusiquer-tfstate-785311025023-apne1"
}

if ([string]::IsNullOrWhiteSpace($DeployRoleArn)) {
  throw "DeployRoleArn is required. Example: -DeployRoleArn arn:aws:iam::785311025023:role/enm-github-actions-terraform-dev"
}

if ([string]::IsNullOrWhiteSpace($HealthRoleArn)) {
  throw "HealthRoleArn is required. Example: -HealthRoleArn arn:aws:iam::785311025023:role/enm-github-actions-dev-health"
}

Write-Host "==> Setting GitHub Actions Variables for $Repository"

Set-RepoVariable -Name "AWS_REGION" -Value $AwsRegion
Set-RepoVariable -Name "ROOT_DOMAIN" -Value $RootDomain
Set-RepoVariable -Name "TF_STATE_BUCKET" -Value $TfStateBucket

Set-RepoVariable -Name "DEV_API_DOMAIN" -Value $DevApiDomain
Set-RepoVariable -Name "DEV_ALB_NAME" -Value $DevAlbName
Set-RepoVariable -Name "DEV_ECS_CLUSTER_NAME" -Value $DevEcsClusterName
Set-RepoVariable -Name "DEV_ECS_SERVICE_NAME" -Value $DevEcsServiceName

Set-RepoVariable -Name "AWS_ROLE_TO_ASSUME_DEV_DEPLOY" -Value $DeployRoleArn
Set-RepoVariable -Name "AWS_ROLE_TO_ASSUME_DEV_HEALTH" -Value $HealthRoleArn

if ($SetDiscordWebhookSecret) {
  if ($DryRun) {
    Write-Host "[DRY-RUN] gh secret set DEV_DEPLOY_DISCORD_WEBHOOK --repo $Repository"
  }
  else {
    $webhook = Read-Host "Enter Discord webhook URL for DEV_DEPLOY_DISCORD_WEBHOOK"
    if ([string]::IsNullOrWhiteSpace($webhook)) {
      throw "Webhook input is empty."
    }
    $webhook | gh secret set DEV_DEPLOY_DISCORD_WEBHOOK --repo $Repository
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to set secret: DEV_DEPLOY_DISCORD_WEBHOOK"
    }
    Write-Host "[OK] secret set: DEV_DEPLOY_DISCORD_WEBHOOK"
  }
}

Write-Host "[OK] GitHub Actions configuration completed."
