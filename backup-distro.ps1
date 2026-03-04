#Requires -Version 5.1
<#
.SYNOPSIS
    Docker ディストロをエクスポートする。
.DESCRIPTION
    Docker ディストロを停止し、tar ファイルとしてエクスポートする。
    エクスポートには Docker CE、設定ファイル、コンテナイメージ、
    Portainer データすべてが含まれる。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$distroName = 'Docker'
$backupDir = Join-Path $PSScriptRoot 'backup'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupFile = Join-Path $backupDir "Docker-distro-$timestamp.tar"

# バックアップディレクトリ作成
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# ディストロ存在確認
$existing = wsl -l -q 2>$null | ForEach-Object { $_.Trim("`0") } | Where-Object { $_ -eq $distroName }
if (-not $existing) {
    Write-Host "[ERROR] Distro '$distroName' not found" -ForegroundColor Red
    exit 1
}

# ディストロ停止
Write-Host "Stopping distro '$distroName'..." -ForegroundColor Yellow
wsl --terminate $distroName
Start-Sleep -Seconds 2

# エクスポート
Write-Host "Exporting distro '$distroName' to:" -ForegroundColor Cyan
Write-Host "  $backupFile" -ForegroundColor Cyan
Write-Host "This may take several minutes depending on distro size..." -ForegroundColor Yellow

wsl --export $distroName $backupFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Export failed" -ForegroundColor Red
    exit 1
}

$size = (Get-Item $backupFile).Length / 1GB
Write-Host "`n[OK] Export complete: $([math]::Round($size, 2)) GB" -ForegroundColor Green
Write-Host "     File: $backupFile" -ForegroundColor Cyan

# ディストロを再起動
Write-Host "`nRestarting distro..." -ForegroundColor Yellow
wsl -d $distroName -- echo "Docker distro restarted"
Write-Host "[OK] Distro '$distroName' is running again" -ForegroundColor Green
