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

function Assert-NoSecretPatternInTerraform([string]$pattern, [string]$label) {
  $trackedFiles = git ls-files "infra/terraform"
  $targets = $trackedFiles | Where-Object { $_ -notlike "*.example" }
  $hit = @()
  foreach ($path in $targets) {
    $match = Select-String -Path $path -Pattern $pattern
    if ($match) {
      $hit += $match
    }
  }
  if ($hit) {
    Write-Host "[ERROR] Found secret-like value: $label" -ForegroundColor Red
    $hit | ForEach-Object { Write-Host " - $($_.Path):$($_.LineNumber)" -ForegroundColor Red }
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

Assert-NoSecretPatternInTerraform 'discord_webhook_url\s*=\s*"https?://discord(app)?\.com/api/webhooks/' 'Discord webhook URL'
Assert-NoSecretPatternInTerraform 'AKIA[0-9A-Z]{16}' 'AWS access key id'
Assert-NoSecretPatternInTerraform 'aws_secret_access_key\s*=\s*"' 'AWS secret access key'

Write-Host "[OK] Terraform secret guard passed." -ForegroundColor Green
