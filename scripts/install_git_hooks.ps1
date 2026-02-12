Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

git config core.hooksPath .githooks
Write-Host "[OK] core.hooksPath is set to .githooks"
Write-Host "Run this once per local clone."
