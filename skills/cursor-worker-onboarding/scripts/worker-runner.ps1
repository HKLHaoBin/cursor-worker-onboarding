$ErrorActionPreference = "Stop"

$configRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $configRoot "worker-config.json"
$logPath = Join-Path $configRoot "worker.log"

New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

if (Test-Path -LiteralPath $logPath) {
  $logSize = (Get-Item -LiteralPath $logPath).Length
  if ($logSize -gt 5MB) {
    Move-Item -LiteralPath $logPath -Destination "$logPath.1" -Force
  }
}

function Write-WorkerLog {
  param([Parameter(Mandatory = $true)][string] $Message)

  $line = "[{0}] {1}" -f (Get-Date).ToString("o"), $Message
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Invoke-AgentCommand {
  param([Parameter(Mandatory = $true)][string[]] $Arguments)

  Write-WorkerLog ("agent " + ($Arguments -join " "))
  $output = @(& $agent @Arguments 2>&1)
  foreach ($line in $output) {
    Add-Content -LiteralPath $logPath -Value ([string]$line) -Encoding UTF8
  }
  return $LASTEXITCODE
}

try {
  if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing worker configuration: $configPath"
  }

  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $directories = @($config.workerDirectories)
  if ($directories.Count -eq 0) {
    throw "Worker configuration contains no workerDirectories."
  }

  foreach ($directory in $directories) {
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
      throw "Configured worker directory does not exist: $directory"
    }
  }

  $agentCommand = Get-Command agent -ErrorAction SilentlyContinue
  if (-not $agentCommand) {
    throw "Cursor Agent CLI was not found on PATH."
  }
  $agent = $agentCommand

  $commonArguments = @("worker", "--name", [string]$config.machineName)
  foreach ($directory in $directories) {
    $commonArguments += @("--worker-dir", [string]$directory)
  }

  Write-WorkerLog "Starting Cursor My Machines worker."
  $debugCode = Invoke-AgentCommand -Arguments ($commonArguments + @("debug"))
  if ($debugCode -ne 0) {
    Write-WorkerLog "Worker debug exited with code $debugCode. Starting worker so the failure remains observable."
  }

  $startCode = Invoke-AgentCommand -Arguments ($commonArguments + @("start"))
  Write-WorkerLog "Worker process exited with code $startCode."
  exit $startCode
} catch {
  Write-WorkerLog ("Startup failure: " + $_.Exception.Message)
  exit 1
}
