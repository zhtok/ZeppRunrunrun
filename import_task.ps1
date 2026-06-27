[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = $PSScriptRoot
$targetDir = $scriptDir
$xmlFile = Join-Path $scriptDir "cron.xml"
$taskName = "\步数修改"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在请求管理员权限..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "任务计划程序自动导入工具" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/2] 检测脚本路径" -ForegroundColor Green
Write-Host "  当前脚本目录: $scriptDir" -ForegroundColor White

Write-Host ""
Write-Host "[2/2] 更新任务XML并导入" -ForegroundColor Green
$runBatPath = (Join-Path $targetDir "run.bat") -replace "\\", "\"
Write-Host "  更新任务运行路径为: $runBatPath" -ForegroundColor White

if (-not (Test-Path $runBatPath)) {
    Write-Host "  ✗ 未找到 run.bat 文件" -ForegroundColor Red
    Read-Host "按任意键退出..."
    exit 1
}

[xml]$xmlContent = Get-Content $xmlFile
$xmlContent.Task.Actions.Exec.Command = $runBatPath
$tempXmlFile = [System.IO.Path]::GetTempFileName() + ".xml"
$xmlContent.Save($tempXmlFile)
Write-Host "  ✓ XML文件更新成功" -ForegroundColor Green

schtasks /create /tn "$taskName" /xml "$tempXmlFile" /f
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ 任务导入成功" -ForegroundColor Green
    Remove-Item $tempXmlFile -ErrorAction SilentlyContinue
} else {
    Write-Host "  ✗ 任务导入失败" -ForegroundColor Red
    Remove-Item $tempXmlFile -ErrorAction SilentlyContinue
    Read-Host "按任意键退出..."
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "所有操作完成！" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "任务名称: $taskName" -ForegroundColor White
Write-Host "脚本目录: $targetDir" -ForegroundColor White
Write-Host ""
Read-Host "按任意键退出..."
