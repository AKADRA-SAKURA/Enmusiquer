param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("shared", "dev", "prod")]
  [string]$Environment,
  [switch]$ReconfigureInit,
  [switch]$SkipSecretCheck,
  [switch]$SkipPlan,
  [switch]$AutoApprove,
  [string]$ProdApproveToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host "==> $Name" -ForegroundColor Cyan
  $global:LASTEXITCODE = 0
  & $Action
  $succeeded = $?
  $exitCode = $LASTEXITCODE

  if (-not $succeeded) {
    throw "Step failed: $Name"
  }
  if ($null -ne $exitCode -and $exitCode -ne 0) {
    throw "Step failed: $Name"
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$tfScript = Join-Path $repoRoot "scripts/tf.ps1"
$guardScript = Join-Path $repoRoot "scripts/check_terraform_secrets.ps1"

if (-not (Test-Path $tfScript)) {
  throw "Missing script: $tfScript"
}

if ($Environment -eq "prod") {
  if ($ProdApproveToken -ne "apply-prod") {
    throw "prod apply is blocked. Re-run with -ProdApproveToken apply-prod"
  }
}

if (-not $SkipSecretCheck) {
  if (-not (Test-Path $guardScript)) {
    throw "Missing script: $guardScript"
  }
  Invoke-Step -Name "secret guard" -Action {
    & $guardScript
  }
}

if ($ReconfigureInit) {
  Invoke-Step -Name "$Environment init (reconfigure)" -Action {
    & $tfScript -Environment $Environment -Command init -Reconfigure
  }
}
else {
  Invoke-Step -Name "$Environment init" -Action {
    & $tfScript -Environment $Environment -Command init
  }
}

if (-not $SkipPlan) {
  Invoke-Step -Name "$Environment plan" -Action {
    & $tfScript -Environment $Environment -Command plan
  }
}

if ($AutoApprove) {
  Invoke-Step -Name "$Environment apply (auto-approve)" -Action {
    & $tfScript -Environment $Environment -Command apply -AutoApprove
  }
}
else {
  Invoke-Step -Name "$Environment apply" -Action {
    & $tfScript -Environment $Environment -Command apply
  }
}

Write-Host "[OK] tf-apply-safe completed." -ForegroundColor Green
