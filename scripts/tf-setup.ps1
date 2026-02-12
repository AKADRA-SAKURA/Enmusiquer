param(
  [switch]$Force,
  [switch]$RunDoctor,
  [switch]$SkipHooks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Copy-IfNeeded {
  param(
    [string]$Source,
    [string]$Destination,
    [bool]$ForceCopy
  )

  if (-not (Test-Path $Source)) {
    Write-Host "[WARN] source not found: $Source" -ForegroundColor Yellow
    return
  }

  if ((-not (Test-Path $Destination)) -or $ForceCopy) {
    Copy-Item $Source $Destination -Force
    Write-Host "[OK] copied: $Destination" -ForegroundColor Green
  }
  else {
    Write-Host "[SKIP] already exists: $Destination"
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Write-Host "== Terraform setup ==" -ForegroundColor Cyan

if (-not $SkipHooks) {
  & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts/install_git_hooks.ps1")
  if ($LASTEXITCODE -ne 0) {
    throw "install_git_hooks.ps1 failed."
  }
}
else {
  Write-Host "[SKIP] install_git_hooks.ps1"
}

$envs = @("shared", "dev", "prod")
foreach ($env in $envs) {
  $envDir = Join-Path $repoRoot "infra/terraform/envs/$env"
  if (-not (Test-Path $envDir)) {
    Write-Host "[WARN] env directory not found: $envDir" -ForegroundColor Yellow
    continue
  }

  Copy-IfNeeded -Source (Join-Path $envDir "backend.hcl.example") -Destination (Join-Path $envDir "backend.hcl") -ForceCopy $Force
  Copy-IfNeeded -Source (Join-Path $envDir "terraform.tfvars.example") -Destination (Join-Path $envDir "terraform.tfvars") -ForceCopy $Force
}

if ($RunDoctor) {
  & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts/tf-doctor.ps1") -RunSecretGuard
  if ($LASTEXITCODE -ne 0) {
    throw "tf-doctor.ps1 failed."
  }
}

Write-Host "[OK] Terraform setup finished." -ForegroundColor Green
