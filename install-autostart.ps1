<#
  Bot Crossing -- start now + survive reboots/power failures.

  Default (no admin needed):  runs at your logon.
      powershell -ExecutionPolicy Bypass -File .\install-autostart.ps1

  Boot-time, no logon required (run PowerShell as Administrator):
      powershell -ExecutionPolicy Bypass -File .\install-autostart.ps1 -AtStartup

  Remove:
      Unregister-ScheduledTask -TaskName BotCrossing -Confirm:$false
#>
param(
  [int]$Port = 5274,
  [switch]$AtStartup,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$name = 'BotCrossing'
$vbs  = Join-Path $root 'run-hidden.vbs'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "node is not on PATH. Install Node 20+ or add it to PATH, then re-run."
}
if (-not (Test-Path $vbs)) { throw "Missing $vbs" }

$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`"" -WorkingDirectory $root

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
  -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
  -MultipleInstances IgnoreNew
$settings.DisallowStartIfOnBatteries = $false
$settings.StopIfGoingOnBatteries     = $false

if ($AtStartup) {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "-AtStartup needs an elevated PowerShell (Run as Administrator)."
  }
  $trigger   = New-ScheduledTaskTrigger -AtStartup
  $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
  $how = 'at boot, as SYSTEM (no logon needed)'
} else {
  $trigger   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  $how = "at logon of $env:USERNAME"
}
$trigger.Delay = 'PT15S'

Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings `
  -Description 'Keeps the Bot Crossing server running on http://127.0.0.1:5274' -Force | Out-Null

Write-Host "Registered scheduled task '$name' -- starts $how, auto-restarts on failure." -ForegroundColor Green

Get-ScheduledTask -TaskName $name | Stop-ScheduledTask -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName $name

$url = "http://127.0.0.1:$Port/"
Write-Host "Waiting for $url ..." -NoNewline
$ok = $false
foreach ($i in 1..120) {
  Start-Sleep -Seconds 2
  try {
    Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 | Out-Null
    $ok = $true; break
  } catch { Write-Host '.' -NoNewline }
}
Write-Host ''

if ($ok) {
  Write-Host "Bot Crossing is up: $url" -ForegroundColor Green
  if (-not $NoBrowser) { Start-Process $url }
} else {
  Write-Warning "Not answering yet. First run builds dist/ and can take a few minutes."
  Write-Warning "Tail the log:  Get-Content .\bot-crossing.log -Tail 40 -Wait"
}
