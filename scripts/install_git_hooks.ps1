Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

git config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
  throw "failed to set git hooksPath to .githooks"
}

Write-Host "[OK] core.hooksPath is set to .githooks"
Write-Host "Run this once per local clone."
