param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("setup", "doctor", "secret-check", "plan-all", "apply-safe", "run", "api-health", "gh-dev-deploy")]
  [string]$Task,

  [ValidateSet("shared", "dev", "prod")]
  [string]$Environment,

  [ValidateSet("init", "validate", "plan", "apply")]
  [string]$RunCommand,

  [ValidateSet("shared-dev", "all")]
  [string]$Scope = "shared-dev",

  [string]$VarFile = "terraform.tfvars",
  [string]$ProdApproveToken,
  [string]$Region = "",
  [string]$Repository = "AKADRA-SAKURA/Enmusiquer",
  [string]$ImageTag = "manual",
  [string]$GhRef = "dev",
  [string]$ApiDomain = "",
  [string]$EcrBackendRepo = "",
  [string]$EcsClusterName = "",
  [string]$EcsServiceName = "",

  [switch]$Reconfigure,
  [switch]$ReconfigureInit,
  [switch]$InitIfNeeded,
  [switch]$AutoApprove,
  [switch]$SkipPlan,
  [switch]$SkipSecretCheck,
  [switch]$SkipAwsSts,
  [switch]$CheckGitHubActions,
  [switch]$RunSecretGuard,
  [switch]$WatchRun,
  [switch]$Force,
  [switch]$SkipHooks,
  [switch]$ShowEcsEvents
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
  apiHealth   = Join-Path $scriptDir "api-health.ps1"
  ghDevDeploy = Join-Path $scriptDir "gh-dev-deploy.ps1"
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
    if ($CheckGitHubActions) {
      $args.CheckGitHubActions = $true
      $args.Repository = $Repository
    }
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

  "api-health" {
    Ensure-ScriptExists $paths.apiHealth
    if (-not $Environment) {
      throw "-Environment is required for -Task api-health"
    }
    if ($Environment -eq "shared") {
      throw "-Task api-health supports only dev or prod."
    }

    $args = @{
      Environment = $Environment
    }
    if ($Region) { $args.Region = $Region }
    if ($ShowEcsEvents) { $args.ShowEcsEvents = $true }
    & $paths.apiHealth @args
  }

  "gh-dev-deploy" {
    Ensure-ScriptExists $paths.ghDevDeploy
    $args = @{
      Repository = $Repository
      Ref        = $GhRef
      ImageTag   = $ImageTag
    }
    if ($Region) { $args.AwsRegion = $Region }
    if ($ApiDomain) { $args.ApiDomain = $ApiDomain }
    if ($EcrBackendRepo) { $args.EcrBackendRepo = $EcrBackendRepo }
    if ($EcsClusterName) { $args.EcsClusterName = $EcsClusterName }
    if ($EcsServiceName) { $args.EcsServiceName = $EcsServiceName }
    if ($WatchRun) { $args.Watch = $true }
    & $paths.ghDevDeploy @args
  }
}

if (-not $?) {
  exit 1
}
