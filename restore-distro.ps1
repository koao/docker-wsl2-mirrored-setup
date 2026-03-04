#Requires -Version 5.1
<#
.SYNOPSIS
    バックアップからDocker ディストロをインポートする。
.DESCRIPTION
    エクスポート済みの tar ファイルから Docker ディストロをインポートする。
    インポート後、ディストロ起動するだけで Docker デーモンが自動起動する。
.PARAMETER TarFile
    インポートする tar ファイルのパス。省略時は backup/ 内の最新ファイルを使用。
#>

param(
    [string]$TarFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$distroName = 'Docker'
$installDir = 'C:\WSL\Docker'

# tar ファイルの決定
if (-not $TarFile) {
    $backupDir = Join-Path $PSScriptRoot 'backup'
    if (Test-Path $backupDir) {
        $latest = Get-ChildItem -Path $backupDir -Filter 'Docker-distro-*.tar' |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1
        if ($latest) {
            $TarFile = $latest.FullName
            Write-Host "[INFO] Using latest backup: $TarFile" -ForegroundColor Yellow
        }
    }
    if (-not $TarFile) {
        Write-Host "[ERROR] No tar file specified and no backup found in backup/ directory" -ForegroundColor Red
        Write-Host "Usage: .\restore-distro.ps1 -TarFile <path-to-tar>" -ForegroundColor Cyan
        exit 1
    }
}

if (-not (Test-Path $TarFile)) {
    Write-Host "[ERROR] File not found: $TarFile" -ForegroundColor Red
    exit 1
}

# 既存ディストロの確認
$existing = wsl -l -q 2>$null | ForEach-Object { $_.Trim("`0") } | Where-Object { $_ -eq $distroName }
if ($existing) {
    Write-Host "[ERROR] Distro '$distroName' already exists. Unregister it first with:" -ForegroundColor Red
    Write-Host "        wsl --unregister $distroName" -ForegroundColor Yellow
    exit 1
}

# インストール先ディレクトリ作成
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# インポート
$size = (Get-Item $TarFile).Length / 1GB
Write-Host "Importing distro '$distroName' from: $TarFile ($([math]::Round($size, 2)) GB)" -ForegroundColor Cyan
Write-Host "This may take several minutes..." -ForegroundColor Yellow

wsl --import $distroName $installDir $TarFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Import failed" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Distro '$distroName' imported successfully" -ForegroundColor Green

# ディストロ起動確認
Write-Host "Starting distro and verifying Docker..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

$whoami = wsl -d $distroName -- whoami
Write-Host "  Default user: $($whoami.Trim())"

# Docker デーモンの起動を待つ
Write-Host "Waiting for Docker daemon..." -ForegroundColor Yellow
wsl -d $distroName -- bash -c 'for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done'

$dockerStatus = wsl -d $distroName -- systemctl is-active docker 2>&1
if ($dockerStatus.Trim() -eq 'active') {
    Write-Host "[OK] Docker daemon is running" -ForegroundColor Green
} else {
    Write-Host "[WARN] Docker daemon status: $dockerStatus" -ForegroundColor Yellow
    Write-Host "       Try: wsl -d $distroName -- sudo systemctl start docker" -ForegroundColor Cyan
}

Write-Host "`n[OK] Restore complete. Next steps:" -ForegroundColor Green
Write-Host "  1. Run 04-install-windows-cli.ps1 (as admin) to install Docker CLI on Windows" -ForegroundColor Cyan
Write-Host "  2. Restart terminal, then run: docker version" -ForegroundColor Cyan
