[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [Alias("Workspace")]
  [string[]] $WorkerDir,

  [string] $MachineName = "",
  [switch] $EnableStartup,
  [switch] $StartNow
)

$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
  throw "This setup script supports Windows only."
}

function Get-DirectoryPath {
  param([Parameter(Mandatory = $true)][string] $Path)

  $item = Get-Item -LiteralPath $Path -ErrorAction Stop
  if (-not ($item -is [System.IO.DirectoryInfo])) {
    throw "Worker directory is not a directory: $Path"
  }
  $fullPath = $item.FullName
  if ($fullPath.Length -gt 3) {
    $fullPath = $fullPath.TrimEnd("\")
  }
  return $fullPath
}

function Write-ManagedWorkspaceBlock {
  param(
    [Parameter(Mandatory = $true)][string] $Path,
    [Parameter(Mandatory = $true)][string] $Name,
    [Parameter(Mandatory = $true)][string[]] $Directories,
    [Parameter(Mandatory = $true)][string] $UpdatedAt
  )

  $begin = "<!-- BEGIN CURSOR WORKER WORKSPACE ROOTS -->"
  $end = "<!-- END CURSOR WORKER WORKSPACE ROOTS -->"
  $blockLines = @(
    $begin
    "## Cursor Worker registered roots"
    ""
    "- worker: ``$Name``"
    "- updated: $UpdatedAt"
    ""
    "| Path |"
    "| --- |"
  )
  foreach ($directory in $Directories) {
    $blockLines += "| ``$directory`` |"
  }
  $blockLines += $end
  $block = $blockLines -join [Environment]::NewLine

  if (Test-Path -LiteralPath $Path) {
    $existing = Get-Content -LiteralPath $Path -Raw
    $beginIndex = $existing.IndexOf($begin, [StringComparison]::Ordinal)
    $endIndex = if ($beginIndex -ge 0) {
      $existing.IndexOf($end, $beginIndex + $begin.Length, [StringComparison]::Ordinal)
    } else {
      -1
    }
    if ($beginIndex -ge 0 -and $endIndex -ge 0) {
      $afterEnd = $endIndex + $end.Length
      $updated = $existing.Substring(0, $beginIndex) + $block + $existing.Substring($afterEnd)
    } elseif ($existing.Trim().Length -eq 0) {
      $updated = $block + [Environment]::NewLine
    } else {
      $updated = $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
    }
  } else {
    $updated = @(
      "# Cursor Workspace Roots"
      ""
      "This file is maintained by the Cursor Worker onboarding skill."
      ""
      $block
      ""
    ) -join [Environment]::NewLine
  }

  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
}

function Get-CurrentUserId {
  return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

function Get-WindowsPowerShellPath {
  $candidate = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  if (Test-Path -LiteralPath $candidate) {
    return $candidate
  }
  return (Get-Command powershell.exe -ErrorAction Stop).Source
}

function Register-WorkerStartupTask {
  param(
    [Parameter(Mandatory = $true)][string] $RunnerPath,
    [Parameter(Mandatory = $true)][string] $ConfigRoot
  )

  $taskName = "Cursor Agent Worker"
  $userId = Get-CurrentUserId
  $powershellPath = Get-WindowsPowerShellPath
  $arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RunnerPath`""

  if (-not (Get-Command New-ScheduledTaskAction -ErrorAction SilentlyContinue)) {
    $schtasks = Get-Command schtasks.exe -ErrorAction SilentlyContinue
    if (-not $schtasks) {
      throw "Neither the ScheduledTasks PowerShell module nor schtasks.exe is available."
    }

    $taskRun = "`"$powershellPath`" $arguments"
    & $schtasks.Source /Create /TN $taskName /TR $taskRun /SC ONLOGON /RU $userId /RL LIMITED /F | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "schtasks.exe could not register the logon task (exit code $LASTEXITCODE)."
    }
    return $taskName
  }

  $action = New-ScheduledTaskAction `
    -Execute $powershellPath `
    -Argument $arguments `
    -WorkingDirectory $ConfigRoot
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
  $principal = New-ScheduledTaskPrincipal `
    -UserId $userId `
    -LogonType Interactive `
    -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RestartCount 20 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Starts the user-approved Cursor My Machines worker." | Out-Null

  return $taskName
}

function Start-WorkerNow {
  param(
    [Parameter(Mandatory = $true)][string] $RunnerPath,
    [Parameter(Mandatory = $true)][string] $ConfigRoot
  )

  $powershellPath = Get-WindowsPowerShellPath
  $arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RunnerPath`""
  return Start-Process `
    -FilePath $powershellPath `
    -ArgumentList $arguments `
    -WorkingDirectory $ConfigRoot `
    -WindowStyle Hidden `
    -PassThru
}

$agent = Get-Command agent -ErrorAction SilentlyContinue
if (-not $agent) {
  throw "Cursor Agent CLI was not found. Install it with: irm 'https://cursor.com/install?win32=true' | iex"
}

$directories = @(
  $WorkerDir |
    ForEach-Object { Get-DirectoryPath -Path $_ } |
    Select-Object -Unique
)
if ($directories.Count -eq 0) {
  throw "At least one existing worker directory is required."
}

$name = $MachineName.Trim()
if ($name.Length -eq 0) {
  $name = $env:COMPUTERNAME
}
if ($name.Length -gt 80 -or $name -match "[\r\n]") {
  throw "MachineName must be 1 to 80 characters and must not contain newlines."
}

$cursorRoot = Join-Path $env:USERPROFILE ".cursor"
$configRoot = Join-Path $cursorRoot "agent-worker"
$memoryRoot = Join-Path $cursorRoot "memory-graphs"
$configPath = Join-Path $configRoot "worker-config.json"
$runnerSource = Join-Path $PSScriptRoot "worker-runner.ps1"
$runnerPath = Join-Path $configRoot "worker-runner.ps1"
$memoryPath = Join-Path $memoryRoot "WORKSPACE-ROOTS.md"
$updatedAt = (Get-Date).ToString("o")

New-Item -ItemType Directory -Path $configRoot -Force | Out-Null
New-Item -ItemType Directory -Path $memoryRoot -Force | Out-Null
Copy-Item -LiteralPath $runnerSource -Destination $runnerPath -Force

$config = [ordered]@{
  version = 1
  machineName = $name
  workerDirectories = $directories
  startupTaskName = "Cursor Agent Worker"
  generatedAt = $updatedAt
}
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
Write-ManagedWorkspaceBlock `
  -Path $memoryPath `
  -Name $name `
  -Directories $directories `
  -UpdatedAt $updatedAt

Write-Host "Saved worker configuration: $configPath"
Write-Host "Saved workspace roots: $memoryPath"

if ($EnableStartup) {
  $taskName = Register-WorkerStartupTask -RunnerPath $runnerPath -ConfigRoot $configRoot
  Write-Host "Registered logon startup task: $taskName"
} else {
  Write-Host "Startup task unchanged. Pass -EnableStartup after explicit user confirmation to register it."
}

if ($StartNow) {
  $process = Start-WorkerNow -RunnerPath $runnerPath -ConfigRoot $configRoot
  Write-Host "Started hidden worker process (PID $($process.Id))."
  Write-Host "Startup diagnostics and worker output: $(Join-Path $configRoot 'worker.log')"
} else {
  Write-Host "Worker not started. Pass -StartNow after explicit user confirmation to start it."
}

Write-Host ""
Write-Host "Next: open https://cursor.com/agents and choose '$name' in the environment picker."
