param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("setup", "doctor", "secret-check", "plan-all", "apply-safe", "run")]
  [string]$Task,

  [ValidateSet("shared", "dev", "prod")]
  [string]$Environment,

  [ValidateSet("init", "validate", "plan", "apply")]
  [string]$RunCommand,

  [ValidateSet("shared-dev", "all")]
  [string]$Scope = "shared-dev",

  [string]$VarFile = "terraform.tfvars",
  [string]$ProdApproveToken,

  [switch]$Reconfigure,
  [switch]$ReconfigureInit,
  [switch]$InitIfNeeded,
  [switch]$AutoApprove,
  [switch]$SkipPlan,
  [switch]$SkipSecretCheck,
  [switch]$SkipAwsSts,
  [switch]$RunSecretGuard,
  [switch]$Force,
  [switch]$SkipHooks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-ScriptExists([string]$Path) {
  if (-not (Test-Path $Path)) {
    throw "Missing script: $Path"
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$scriptDir = Join-Path $repoRoot "scripts"

$paths = @{
  setup       = Join-Path $scriptDir "tf-setup.ps1"
  doctor      = Join-Path $scriptDir "tf-doctor.ps1"
  secretCheck = Join-Path $scriptDir "check_terraform_secrets.ps1"
  planAll     = Join-Path $scriptDir "tf-plan-all.ps1"
  applySafe   = Join-Path $scriptDir "tf-apply-safe.ps1"
  run         = Join-Path $scriptDir "tf.ps1"
}

switch ($Task) {
  "setup" {
    Ensure-ScriptExists $paths.setup
    $args = @{}
    if ($Force) { $args.Force = $true }
    if ($RunSecretGuard) { $args.RunDoctor = $true }
    if ($SkipHooks) { $args.SkipHooks = $true }
    & $paths.setup @args
  }

  "doctor" {
    Ensure-ScriptExists $paths.doctor
    $args = @{}
    if ($SkipAwsSts) { $args.SkipAwsSts = $true }
    if ($RunSecretGuard) { $args.RunSecretGuard = $true }
    & $paths.doctor @args
  }

  "secret-check" {
    Ensure-ScriptExists $paths.secretCheck
    & $paths.secretCheck
  }

  "plan-all" {
    Ensure-ScriptExists $paths.planAll
    $args = @{ Scope = $Scope }
    if ($ReconfigureInit) { $args.ReconfigureInit = $true }
    if ($SkipSecretCheck) { $args.SkipSecretCheck = $true }
    & $paths.planAll @args
  }

  "apply-safe" {
    Ensure-ScriptExists $paths.applySafe
    if (-not $Environment) {
      throw "-Environment is required for -Task apply-safe"
    }

    $args = @{ Environment = $Environment }
    if ($ReconfigureInit) { $args.ReconfigureInit = $true }
    if ($SkipSecretCheck) { $args.SkipSecretCheck = $true }
    if ($SkipPlan) { $args.SkipPlan = $true }
    if ($AutoApprove) { $args.AutoApprove = $true }
    if ($ProdApproveToken) { $args.ProdApproveToken = $ProdApproveToken }
    & $paths.applySafe @args
  }

  "run" {
    Ensure-ScriptExists $paths.run
    if (-not $Environment) {
      throw "-Environment is required for -Task run"
    }
    if (-not $RunCommand) {
      throw "-RunCommand is required for -Task run"
    }

    $args = @{
      Environment = $Environment
      Command     = $RunCommand
      VarFile     = $VarFile
    }
    if ($Reconfigure) { $args.Reconfigure = $true }
    if ($AutoApprove) { $args.AutoApprove = $true }
    if ($InitIfNeeded) { $args.InitIfNeeded = $true }
    & $paths.run @args
  }
}

if (-not $?) {
  exit 1
}
