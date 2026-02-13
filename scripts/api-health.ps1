param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "prod")]
  [string]$Environment,

  [string]$Region = "",
  [switch]$ShowEcsEvents
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TfvarsBool {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $true)]
    [string]$VariableName
  )

  if (-not (Test-Path $FilePath)) {
    return $null
  }

  $lines = Get-Content -Path $FilePath -ErrorAction SilentlyContinue
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) {
      continue
    }

    if ($trimmed -match ("^{0}\s*=\s*(true|false)\s*$" -f [regex]::Escape($VariableName))) {
      return [System.Convert]::ToBoolean($Matches[1])
    }
  }

  return $null
}

function Get-TerraformOutputRaw {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $global:LASTEXITCODE = 0
  $value = ""
  $previousPreference = $ErrorActionPreference
  try {
    # Some environments emit NativeCommandError for terraform stderr when output is missing.
    $ErrorActionPreference = "Continue"
    $value = & terraform "-chdir=$Directory" output -raw $Name 2>$null
  }
  catch {
    return ""
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  if ($LASTEXITCODE -ne 0) {
    return ""
  }
  if ($null -eq $value) {
    return ""
  }

  return ($value | Out-String).Trim()
}

function Invoke-UrlCheck {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  try {
    $body = curl.exe -sS --max-time 15 $Url
    return @{
      Url     = $Url
      Success = ($body -match '"status"\s*:\s*"ok"')
      Body    = $body
    }
  }
  catch {
    return @{
      Url     = $Url
      Success = $false
      Body    = $_.Exception.Message
    }
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envDir = Join-Path $repoRoot "infra/terraform/envs/$Environment"
$tfvarsPath = Join-Path $envDir "terraform.tfvars"

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "terraform command not found in PATH."
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
  throw "aws command not found in PATH."
}

if (-not (Test-Path $envDir)) {
  throw "Environment directory not found: $envDir"
}

if ([string]::IsNullOrWhiteSpace($Region)) {
  if (-not [string]::IsNullOrWhiteSpace($env:AWS_REGION)) {
    $Region = $env:AWS_REGION
  }
  else {
    $Region = "ap-northeast-1"
  }
}

$runtimeEnabled = Get-TfvarsBool -FilePath $tfvarsPath -VariableName "runtime_enabled"
if ($runtimeEnabled -eq $false) {
  Write-Host "==> API Health ($Environment)" -ForegroundColor Cyan
  Write-Host "[INFO] runtime_enabled=false; skip ALB/API/ECS checks." -ForegroundColor Yellow
  exit 0
}

$albDns = Get-TerraformOutputRaw -Directory $envDir -Name "alb_dns_name"
$apiDomain = Get-TerraformOutputRaw -Directory $envDir -Name "api_domain_name"
$serviceName = Get-TerraformOutputRaw -Directory $envDir -Name "ecs_service_name"

$checks = @()
if (-not [string]::IsNullOrWhiteSpace($albDns)) {
  $checks += Invoke-UrlCheck -Url "http://$albDns/health"
}
else {
  Write-Host "[WARN] alb_dns_name output is empty. Skip ALB health check." -ForegroundColor Yellow
}

if (-not [string]::IsNullOrWhiteSpace($apiDomain)) {
  $checks += Invoke-UrlCheck -Url "http://$apiDomain/health"
}
else {
  Write-Host "[WARN] api_domain_name output is empty. Skip domain health check." -ForegroundColor Yellow
}

Write-Host "==> API Health ($Environment)" -ForegroundColor Cyan
foreach ($result in $checks) {
  if ($result.Success) {
    Write-Host "[OK] $($result.Url) => $($result.Body)" -ForegroundColor Green
  }
  else {
    Write-Host "[NG] $($result.Url) => $($result.Body)" -ForegroundColor Red
  }
}

$hasFailure = ($checks | Where-Object { -not $_.Success } | Measure-Object).Count -gt 0

if ($ShowEcsEvents -or $hasFailure) {
  $clusterName = "enm-$Environment-cluster"
  if ([string]::IsNullOrWhiteSpace($serviceName)) {
    $serviceName = "enm-$Environment-api"
    Write-Host "[WARN] ecs_service_name output is empty. Use fallback service name: $serviceName" -ForegroundColor Yellow
  }

  Write-Host "==> ECS Recent Events ($clusterName / $serviceName)" -ForegroundColor Cyan
  $global:LASTEXITCODE = 0
  & aws ecs describe-services `
    --cluster $clusterName `
    --services $serviceName `
    --region $Region `
    --query "services[0].events[0:10].[createdAt,message]" `
    --output table
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] failed to fetch ECS events for $clusterName / $serviceName" -ForegroundColor Yellow
  }
}

if ($hasFailure) {
  exit 1
}
