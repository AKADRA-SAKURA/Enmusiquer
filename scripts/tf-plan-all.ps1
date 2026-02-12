param(
  [ValidateSet("shared-dev", "all")]
  [string]$Scope = "shared-dev",
  [switch]$ReconfigureInit,
  [switch]$SkipSecretCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Action
  if (-not $?) {
    throw "Step failed: $Name"
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$tfScript = Join-Path $repoRoot "scripts/tf.ps1"
$guardScript = Join-Path $repoRoot "scripts/check_terraform_secrets.ps1"

if (-not (Test-Path $tfScript)) {
  throw "Missing script: $tfScript"
}

if (-not $SkipSecretCheck) {
  if (-not (Test-Path $guardScript)) {
    throw "Missing script: $guardScript"
  }
  Invoke-Step -Name "secret guard" -Action {
    & $guardScript
  }
}

$targets = @("shared", "dev")
if ($Scope -eq "all") {
  $targets += "prod"
}

foreach ($env in $targets) {
  if ($ReconfigureInit) {
    Invoke-Step -Name "$env init (reconfigure)" -Action {
      & $tfScript -Environment $env -Command init -Reconfigure
    }
  }
  else {
    Invoke-Step -Name "$env init" -Action {
      & $tfScript -Environment $env -Command init
    }
  }

  Invoke-Step -Name "$env plan" -Action {
    & $tfScript -Environment $env -Command plan
  }
}

Write-Host "[OK] tf-plan-all completed." -ForegroundColor Green
