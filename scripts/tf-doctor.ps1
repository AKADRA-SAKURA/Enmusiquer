param(
  [switch]$SkipAwsSts,
  [switch]$RunSecretGuard,
  [switch]$CheckGitHubActions,
  [string]$Repository = "AKADRA-SAKURA/Enmusiquer"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Error([string]$message) {
  $script:errors.Add($message) | Out-Null
  Write-Host "[ERROR] $message" -ForegroundColor Red
}

function Add-Warn([string]$message) {
  $script:warnings.Add($message) | Out-Null
  Write-Host "[WARN] $message" -ForegroundColor Yellow
}

function Add-Ok([string]$message) {
  Write-Host "[OK] $message" -ForegroundColor Green
}

function Command-Exists([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Get-GhApiList {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Jq
  )

  $global:LASTEXITCODE = 0
  $raw = & gh api --paginate $Path --jq $Jq 2>$null
  if ($LASTEXITCODE -ne 0 -or $null -eq $raw) {
    return @()
  }

  $lines = ($raw | Out-String).Trim() -split "(`r`n|`n|`r)"
  return @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
}

function Get-GhVariableValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $global:LASTEXITCODE = 0
  $value = & gh variable get $Name --repo $Repo 2>$null
  if ($LASTEXITCODE -ne 0 -or $null -eq $value) {
    return ""
  }

  return ($value | Out-String).Trim()
}

function New-CaseInsensitiveSet {
  param([string[]]$Items)
  $set = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($item in $Items) {
    if (-not [string]::IsNullOrWhiteSpace($item)) {
      $null = $set.Add($item)
    }
  }
  return $set
}

function Test-EnvFiles([string]$repoRoot, [string]$env) {
  $envDir = Join-Path $repoRoot "infra/terraform/envs/$env"
  if (-not (Test-Path $envDir)) {
    Add-Error "env directory not found: $envDir"
    return
  }

  $backendPath = Join-Path $envDir "backend.hcl"
  $backendExamplePath = Join-Path $envDir "backend.hcl.example"
  $tfvarsPath = Join-Path $envDir "terraform.tfvars"
  $tfvarsExamplePath = Join-Path $envDir "terraform.tfvars.example"

  if (Test-Path $backendPath) {
    Add-Ok "$env backend.hcl exists"
    $backendContent = Get-Content $backendPath -Raw
    if ($backendContent -match 'REPLACE_ME_TFSTATE_BUCKET') {
      Add-Warn "$env backend.hcl still has placeholder bucket. Update local value before init."
    }
  }
  elseif (Test-Path $backendExamplePath) {
    Add-Warn "$env backend.hcl is missing. Copy from backend.hcl.example."
  }
  else {
    Add-Error "$env backend.hcl and backend.hcl.example are both missing."
  }

  if (Test-Path $tfvarsPath) {
    Add-Ok "$env terraform.tfvars exists"
  }
  elseif (Test-Path $tfvarsExamplePath) {
    Add-Warn "$env terraform.tfvars is missing. Copy from terraform.tfvars.example."
  }
  else {
    Add-Error "$env terraform.tfvars and terraform.tfvars.example are both missing."
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Write-Host "== Terraform Doctor ==" -ForegroundColor Cyan

if (Command-Exists "terraform") {
  $tfVersion = (& terraform version | Select-Object -First 1)
  Add-Ok "terraform detected: $tfVersion"
}
else {
  Add-Error "terraform command not found in PATH."
}

if (Command-Exists "aws") {
  $awsVersion = (& aws --version 2>&1 | Select-Object -First 1)
  Add-Ok "aws cli detected: $awsVersion"
}
else {
  Add-Error "aws command not found in PATH."
}

if (-not $SkipAwsSts -and (Command-Exists "aws")) {
  try {
    $identityRaw = & aws sts get-caller-identity --output json 2>$null
    if (-not $identityRaw) {
      Add-Error "aws sts get-caller-identity returned empty result."
    }
    else {
      $identity = $identityRaw | ConvertFrom-Json
      if ($identity.Account) {
        Add-Ok "AWS authentication OK. Account: $($identity.Account)"
      }
      else {
        Add-Error "AWS authentication response does not include account."
      }
    }
  }
  catch {
    Add-Error "AWS authentication failed. Run aws configure or aws sso login."
  }
}

$hooksPath = (& git config --get core.hooksPath 2>$null)
if ($hooksPath -eq ".githooks") {
  Add-Ok "git hooks path is .githooks"
}
else {
  Add-Warn "git hooks path is '$hooksPath'. Run scripts/install_git_hooks.ps1 once."
}

Test-EnvFiles -repoRoot $repoRoot -env "shared"
Test-EnvFiles -repoRoot $repoRoot -env "dev"
Test-EnvFiles -repoRoot $repoRoot -env "prod"

if ($CheckGitHubActions) {
  Write-Host "== GitHub Actions config check ==" -ForegroundColor Cyan
  if (-not (Command-Exists "gh")) {
    Add-Error "gh command not found in PATH. Install GitHub CLI to run -CheckGitHubActions."
  }
  else {
    $global:LASTEXITCODE = 0
    & gh auth status 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
      Add-Error "gh auth status failed. Run 'gh auth login' first."
    }
    else {
      Add-Ok "gh authentication OK"

      $variableNames = Get-GhApiList -Path "repos/$Repository/actions/variables" -Jq ".variables[].name"
      $secretNames = Get-GhApiList -Path "repos/$Repository/actions/secrets" -Jq ".secrets[].name"

      $varSet = New-CaseInsensitiveSet -Items $variableNames
      $secretSet = New-CaseInsensitiveSet -Items $secretNames

      $requiredVars = @(
        "AWS_ROLE_TO_ASSUME_DEV_DEPLOY",
        "TF_STATE_BUCKET",
        "ROOT_DOMAIN"
      )

      $recommendedVars = @(
        "AWS_REGION",
        "AWS_ROLE_TO_ASSUME_DEV_HEALTH",
        "DEV_API_DOMAIN",
        "DEV_ALB_NAME",
        "DEV_ECR_BACKEND_REPO",
        "DEV_ECS_CLUSTER_NAME",
        "DEV_ECS_SERVICE_NAME"
      )

      foreach ($name in $requiredVars) {
        if ($varSet.Contains($name)) {
          Add-Ok "GitHub variable exists: $name"
        }
        else {
          Add-Error "Missing required GitHub variable: $name"
        }
      }

      foreach ($name in $recommendedVars) {
        if ($varSet.Contains($name)) {
          Add-Ok "GitHub variable exists: $name"
        }
        else {
          Add-Warn "Missing recommended GitHub variable: $name"
        }
      }

      if ($secretSet.Contains("DEV_DEPLOY_DISCORD_WEBHOOK")) {
        Add-Ok "GitHub secret exists: DEV_DEPLOY_DISCORD_WEBHOOK"
      }
      else {
        Add-Warn "Missing optional GitHub secret: DEV_DEPLOY_DISCORD_WEBHOOK"
      }

      $deployRoleArn = Get-GhVariableValue -Repo $Repository -Name "AWS_ROLE_TO_ASSUME_DEV_DEPLOY"
      if (-not [string]::IsNullOrWhiteSpace($deployRoleArn)) {
        if ($deployRoleArn -match "^arn:aws:iam::[0-9]{12}:role/.+") {
          Add-Ok "AWS_ROLE_TO_ASSUME_DEV_DEPLOY format looks valid"
        }
        else {
          Add-Error "AWS_ROLE_TO_ASSUME_DEV_DEPLOY format looks invalid: $deployRoleArn"
        }
      }

      $healthRoleArn = Get-GhVariableValue -Repo $Repository -Name "AWS_ROLE_TO_ASSUME_DEV_HEALTH"
      if (-not [string]::IsNullOrWhiteSpace($healthRoleArn)) {
        if ($healthRoleArn -match "^arn:aws:iam::[0-9]{12}:role/.+") {
          Add-Ok "AWS_ROLE_TO_ASSUME_DEV_HEALTH format looks valid"
        }
        else {
          Add-Error "AWS_ROLE_TO_ASSUME_DEV_HEALTH format looks invalid: $healthRoleArn"
        }
      }
    }
  }
}

if ($RunSecretGuard) {
  $guardScript = Join-Path $repoRoot "scripts/check_terraform_secrets.ps1"
  if (Test-Path $guardScript) {
    try {
      & $guardScript
      Add-Ok "secret guard check passed"
    }
    catch {
      Add-Error "secret guard check failed: $($_.Exception.Message)"
    }
  }
  else {
    Add-Warn "secret guard script not found: $guardScript"
  }
}

Write-Host ""
Write-Host "== Summary ==" -ForegroundColor Cyan
Write-Host "Errors: $($errors.Count)"
Write-Host "Warnings: $($warnings.Count)"

if ($errors.Count -gt 0) {
  exit 1
}

exit 0
