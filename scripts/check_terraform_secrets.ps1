Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail($message) {
  Write-Error $message
  exit 1
}

function Assert-TrackedFileNotPresent([string]$pattern, [string]$label) {
  $tracked = git ls-files | Select-String -Pattern $pattern
  if ($tracked) {
    Write-Host "[ERROR] Forbidden tracked files found: $label" -ForegroundColor Red
    $tracked | ForEach-Object { Write-Host " - $($_.Line)" -ForegroundColor Red }
    exit 1
  }
}

function Assert-FileContains([string]$path, [string]$pattern, [string]$message) {
  if (-not (Test-Path $path)) {
    Fail "Missing file: $path"
  }

  $hit = Select-String -Path $path -Pattern $pattern
  if (-not $hit) {
    Fail $message
  }
}

function Assert-NoSecretPatternInTrackedFiles([string]$pattern, [string]$label) {
  $global:LASTEXITCODE = 0
  $hit = & git grep -n -I -E $pattern -- . ":(exclude)*.example" 2>$null
  if ($LASTEXITCODE -eq 0 -and $hit) {
    Write-Host "[ERROR] Found secret-like value: $label" -ForegroundColor Red
    $hit | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
  }
}

Assert-TrackedFileNotPresent '^infra/terraform/.*/terraform\.tfvars$' 'terraform.tfvars'
Assert-TrackedFileNotPresent '^infra/terraform/.*\.auto\.tfvars$' '*.auto.tfvars'
Assert-TrackedFileNotPresent '^infra/terraform/.*\.tfvars\.json$' '*.tfvars.json'
Assert-TrackedFileNotPresent '^infra/terraform/.*\.tfstate(\..*)?$' '*.tfstate*'
Assert-TrackedFileNotPresent '^infra/terraform/envs/.*/backend\.hcl$' 'backend.hcl (must stay local only)'

Assert-FileContains "infra/terraform/envs/shared/backend.hcl.example" 'REPLACE_ME_TFSTATE_BUCKET' "backend.hcl.example must keep placeholder bucket value in repository (shared)."
Assert-FileContains "infra/terraform/envs/dev/backend.hcl.example" 'REPLACE_ME_TFSTATE_BUCKET' "backend.hcl.example must keep placeholder bucket value in repository (dev)."
Assert-FileContains "infra/terraform/envs/prod/backend.hcl.example" 'REPLACE_ME_TFSTATE_BUCKET' "backend.hcl.example must keep placeholder bucket value in repository (prod)."

Assert-NoSecretPatternInTrackedFiles 'https?://discord(app)?\.com/api/webhooks/[A-Za-z0-9_/-]+' 'Discord webhook URL'
Assert-NoSecretPatternInTrackedFiles 'AKIA[0-9A-Z]{16}' 'AWS access key id'
Assert-NoSecretPatternInTrackedFiles 'aws_secret_access_key\s*=\s*"' 'AWS secret access key'

Write-Host "[OK] Terraform secret guard passed." -ForegroundColor Green
