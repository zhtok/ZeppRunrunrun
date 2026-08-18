[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = $PSScriptRoot
$targetDir = $scriptDir
$configFile = Join-Path $scriptDir "config.json"
$taskName = "步数修改"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting admin rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Task Scheduler Import Tool" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Checking script path" -ForegroundColor Green
Write-Host "  Current dir: $scriptDir" -ForegroundColor White

$runBatPath = Join-Path $targetDir "run.bat"
if (-not (Test-Path $runBatPath)) {
    Write-Host "  [ERROR] run.bat not found" -ForegroundColor Red
    Read-Host "Press any key to exit..."
    exit 1
}
Write-Host "  [OK] run.bat found" -ForegroundColor Green

Write-Host ""
Write-Host "[2/5] Run mode" -ForegroundColor Green

$defaultMode = "interactive"
if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($config.RUN_MODE) { $defaultMode = $config.RUN_MODE }
    } catch {}
}

Write-Host "  Choose run mode:" -ForegroundColor White
Write-Host "    1. Interactive mode (only runs when you are logged in)" -ForegroundColor Gray
Write-Host "    2. Server mode (runs whether you are logged in or not)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Tip: Use server mode on a server/remote machine" -ForegroundColor DarkGray
$modeInput = Read-Host "  Enter 1 or 2 (default: 1)"

if ([string]::IsNullOrWhiteSpace($modeInput)) {
    $modeInput = "1"
}

$useServerMode = ($modeInput -eq "2")

if ($useServerMode) {
    Write-Host "  [OK] Mode: Server" -ForegroundColor Yellow
    $password = Read-Host "  Enter password for $env:USERDOMAIN\$env:USERNAME" -AsSecureString
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
} else {
    Write-Host "  [OK] Mode: Interactive" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3/5] Set start time" -ForegroundColor Green

$defaultStart = "07:00"
$defaultEnd = "22:30"
$defaultInterval = "3"

if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($config.RUN_START_TIME) { $defaultStart = $config.RUN_START_TIME }
        if ($config.RUN_END_TIME) { $defaultEnd = $config.RUN_END_TIME }
        if ($config.RUN_INTERVAL) { $defaultInterval = $config.RUN_INTERVAL }
    } catch {}
}

Write-Host "  Format: HH:mm (e.g. 07:00)" -ForegroundColor Gray
Write-Host "  Or set RUN_START_TIME in config.json" -ForegroundColor DarkGray
$startInput = Read-Host "  Enter start time (default $defaultStart)"

if ([string]::IsNullOrWhiteSpace($startInput)) {
    $startInput = $defaultStart
}

try {
    $startTime = [DateTime]::ParseExact($startInput, "HH:mm", $null)
} catch {
    Write-Host "  [ERROR] Invalid time format" -ForegroundColor Red
    Read-Host "Press any key to exit..."
    exit 1
}

Write-Host "  [OK] Start: $($startTime.ToString('HH:mm'))" -ForegroundColor Yellow

Write-Host ""
Write-Host "[4/5] Set end time and interval" -ForegroundColor Green
Write-Host "  Format: HH:mm (e.g. 22:30)" -ForegroundColor Gray
Write-Host "  Or set RUN_END_TIME in config.json" -ForegroundColor DarkGray
$endInput = Read-Host "  Enter end time (default $defaultEnd)"

if ([string]::IsNullOrWhiteSpace($endInput)) {
    $endInput = $defaultEnd
}

try {
    $endTime = [DateTime]::ParseExact($endInput, "HH:mm", $null)
} catch {
    Write-Host "  [ERROR] Invalid time format" -ForegroundColor Red
    Read-Host "Press any key to exit..."
    exit 1
}

Write-Host "  [OK] End: $($endTime.ToString('HH:mm'))" -ForegroundColor Yellow

Write-Host ""
Write-Host "  Format: number of hours (e.g. 3)" -ForegroundColor Gray
Write-Host "  Or set RUN_INTERVAL in config.json" -ForegroundColor DarkGray
$intervalInput = Read-Host "  Enter interval hours (default $defaultInterval)"

if ([string]::IsNullOrWhiteSpace($intervalInput)) {
    $intervalInput = $defaultInterval
}

try {
    $intervalHours = [int]$intervalInput
    if ($intervalHours -le 0) { throw }
} catch {
    Write-Host "  [ERROR] Interval must be positive" -ForegroundColor Red
    Read-Host "Press any key to exit..."
    exit 1
}

Write-Host "  [OK] Interval: every $intervalHours hours" -ForegroundColor Yellow

Write-Host ""
Write-Host "[5/5] Generate schedule" -ForegroundColor Green

$times = @()
$currentTime = $startTime
while ($currentTime -le $endTime) {
    $times += $currentTime.ToString("HH:mm")
    $currentTime = $currentTime.AddHours($intervalHours)
}

if ($times.Count -gt 0 -and $times[-1] -ne $endTime.ToString("HH:mm")) {
    $times[-1] = $endTime.ToString("HH:mm")
}

Write-Host "  Times:" -ForegroundColor White
foreach ($t in $times) { Write-Host "    - $t" -ForegroundColor Cyan }

Write-Host ""
Write-Host "Creating scheduled task..." -ForegroundColor Green

schtasks /delete /tn "$taskName" /f 2>$null

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</Date>
    <Author>Administrator</Author>
    <Description>Step Counter Modifier</Description>
    <URI>步数修改</URI>
  </RegistrationInfo>
  <Triggers>
"@

$today = Get-Date -Format "yyyy-MM-dd"
foreach ($t in $times) {
    $taskXml += @"
    <CalendarTrigger>
      <StartBoundary>$today`T$t`:00+08:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>
    </CalendarTrigger>
"@
}

if ($useServerMode) {
    $logonType = "Password"
} else {
    $logonType = "InteractiveToken"
}

$taskXml += @"
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERDOMAIN\$env:USERNAME</UserId>
      <LogonType>$logonType</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec><Command>$runBatPath</Command></Exec>
  </Actions>
</Task>
"@

$tempXmlFile = [System.IO.Path]::GetTempFileName() + ".xml"
$utf16 = New-Object System.Text.UnicodeEncoding $false, $true
[System.IO.File]::WriteAllText($tempXmlFile, $taskXml, $utf16)

Write-Host "  Creating task..." -ForegroundColor White

if ($useServerMode) {
    schtasks /create /tn "$taskName" /xml "$tempXmlFile" /ru "$env:USERDOMAIN\$env:USERNAME" /rp $plainPassword /f
    $plainPassword = $null
} else {
    schtasks /create /tn "$taskName" /xml "$tempXmlFile" /f
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Task created" -ForegroundColor Green
    Remove-Item $tempXmlFile -ErrorAction SilentlyContinue
} else {
    Write-Host "  [ERROR] Failed" -ForegroundColor Red
    Remove-Item $tempXmlFile -ErrorAction SilentlyContinue
    Read-Host "Press any key to exit..."
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Task: $taskName" -ForegroundColor White
if ($useServerMode) {
    Write-Host "Mode: Server (runs whether logged on or not)" -ForegroundColor Yellow
} else {
    Write-Host "Mode: Interactive (runs only when logged on)" -ForegroundColor Yellow
}
Write-Host "Times: $($times -join ', ')" -ForegroundColor Yellow
Write-Host "Script: $runBatPath" -ForegroundColor White
Write-Host ""
Read-Host "Press any key to exit..."
