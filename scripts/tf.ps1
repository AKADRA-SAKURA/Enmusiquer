param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("shared", "dev", "prod")]
  [string]$Environment,

  [Parameter(Mandatory = $true)]
  [ValidateSet("init", "validate", "plan", "apply")]
  [string]$Command,

  [string]$VarFile = "terraform.tfvars",
  [switch]$Reconfigure,
  [switch]$AutoApprove,
  [switch]$InitIfNeeded
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Exit-IfFailed {
  param([int]$ExitCode)
  if ($ExitCode -ne 0) {
    exit $ExitCode
  }
}

function Ensure-LocalFileFromExample {
  param(
    [string]$Directory,
    [string]$FileName
  )

  $filePath = Join-Path $Directory $FileName
  if (Test-Path $filePath) {
    return
  }

  $examplePath = "$filePath.example"
  if (-not (Test-Path $examplePath)) {
    throw "Missing required file and example: $filePath"
  }

  Copy-Item $examplePath $filePath -Force
  Write-Host "[INFO] Created $FileName from example. Please edit as needed: $filePath"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envDir = Join-Path $repoRoot "infra/terraform/envs/$Environment"

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "terraform command not found in PATH. Install Terraform or add it to PATH first."
}

if (-not (Test-Path $envDir)) {
  throw "Environment directory not found: $envDir"
}

if ($Command -eq "init") {
  Ensure-LocalFileFromExample -Directory $envDir -FileName "backend.hcl"
}

if ($Command -in @("plan", "apply")) {
  Ensure-LocalFileFromExample -Directory $envDir -FileName $VarFile
}

if ($InitIfNeeded -and $Command -in @("validate", "plan", "apply")) {
  $terraformDir = Join-Path $envDir ".terraform"
  if (-not (Test-Path $terraformDir)) {
    Write-Host "[INFO] .terraform not found. Running init first."
    & terraform "-chdir=$envDir" init -backend-config=backend.hcl -input=false
    Exit-IfFailed $LASTEXITCODE
  }
}

$args = @("-chdir=$envDir", $Command)

switch ($Command) {
  "init" {
    if ($Reconfigure) {
      $args += "-reconfigure"
    }
    $args += "-backend-config=backend.hcl"
    $args += "-input=false"
  }
  "plan" {
    $args += "-var-file=$VarFile"
    $args += "-input=false"
  }
  "apply" {
    $args += "-var-file=$VarFile"
    $args += "-input=false"
    if ($AutoApprove) {
      $args += "-auto-approve"
    }
  }
}

& terraform @args
Exit-IfFailed $LASTEXITCODE
