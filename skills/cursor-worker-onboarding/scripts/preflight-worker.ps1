[CmdletBinding()]
param(
  [switch] $SkipRemoteDebug
)

$ErrorActionPreference = "Continue"
$failures = 0
$cursorRoot = Join-Path $env:USERPROFILE ".cursor"
$configRoot = Join-Path $cursorRoot "agent-worker"
$configPath = Join-Path $configRoot "worker-config.json"
$logPath = Join-Path $configRoot "worker.log"

function Check-Result {
  param(
    [Parameter(Mandatory = $true)][string] $Label,
    [Parameter(Mandatory = $true)][bool] $Ok,
    [Parameter(Mandatory = $true)][string] $Detail
  )

  if ($Ok) {
    Write-Host "[PASS] $Label - $Detail" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $Label - $Detail" -ForegroundColor Red
    $script:failures++
  }
}

Write-Host "Cursor My Machines worker preflight"
Write-Host "Config root: $configRoot"
Write-Host ""

$agent = Get-Command agent -ErrorAction SilentlyContinue
Check-Result `
  -Label "Cursor Agent CLI" `
  -Ok ($null -ne $agent) `
  -Detail ($(if ($agent) { ((& $agent.Source --version 2>&1) -join " ").Trim() } else { "not found" }))

$config = $null
if (Test-Path -LiteralPath $configPath) {
  try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    Check-Result -Label "Worker config" -Ok $true -Detail $configPath
  } catch {
    Check-Result -Label "Worker config" -Ok $false -Detail $_.Exception.Message
  }
} else {
  Check-Result -Label "Worker config" -Ok $false -Detail "missing: $configPath"
}

$directories = @()
if ($config) {
  $directories = @($config.workerDirectories)
  Check-Result `
    -Label "Registered directories" `
    -Ok ($directories.Count -gt 0) `
    -Detail ($directories -join "; ")

  foreach ($directory in $directories) {
    Check-Result `
      -Label "Directory $directory" `
      -Ok (Test-Path -LiteralPath $directory -PathType Container) `
      -Detail $(if (Test-Path -LiteralPath $directory -PathType Container) { "exists" } else { "missing" })
  }
}

$task = $null
$taskDetail = "not registered"
if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
  $task = Get-ScheduledTask -TaskName "Cursor Agent Worker" -ErrorAction SilentlyContinue
  if ($task) {
    $taskDetail = "state=$($task.State)"
  }
} elseif (Get-Command schtasks.exe -ErrorAction SilentlyContinue) {
  $taskOutput = @(& (Get-Command schtasks.exe).Source /Query /TN "Cursor Agent Worker" /FO LIST /NH 2>$null)
  if ($LASTEXITCODE -eq 0) {
    $task = $taskOutput
    $taskDetail = "registered through schtasks.exe"
  }
} else {
  $taskDetail = "no ScheduledTasks module or schtasks.exe"
}
Check-Result `
  -Label "Logon startup task" `
  -Ok ($null -ne $task) `
  -Detail $taskDetail

if ($agent -and $config -and $directories.Count -gt 0 -and -not $SkipRemoteDebug) {
  $commonArguments = @("worker", "--name", [string]$config.machineName)
  foreach ($directory in $directories) {
    $commonArguments += @("--worker-dir", [string]$directory)
  }

  Write-Host ""
  Write-Host "Running agent worker debug..."
  $debugOutput = @(& $agent.Source @($commonArguments + @("debug")) 2>&1)
  foreach ($line in $debugOutput) {
    Write-Host ([string]$line)
  }
  Check-Result `
    -Label "Remote worker debug" `
    -Ok ($LASTEXITCODE -eq 0) `
    -Detail "exit code $LASTEXITCODE"
} elseif ($SkipRemoteDebug) {
  Write-Host "[SKIP] Remote worker debug was disabled."
}

if (Test-Path -LiteralPath $logPath) {
  Write-Host ""
  Write-Host "Recent worker log:"
  Get-Content -LiteralPath $logPath -Tail 40
} else {
  Write-Host ""
  Write-Host "No worker log yet: $logPath"
}

if ($failures -gt 0) {
  exit 1
}
exit 0
