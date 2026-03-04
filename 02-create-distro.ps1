#Requires -Version 5.1
<#
.SYNOPSIS
    Docker 専用 WSL ディストロを新規作成する。
.DESCRIPTION
    Ubuntu 24.04 クラウドイメージをダウンロードし、"Docker" ディストロとしてインポートする。
    デフォルトユーザーの作成と wsl.conf の配置を行う。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$distroName = 'Docker'
$installDir = 'C:\WSL\Docker'
$imageUrl = 'https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
$downloadDir = Join-Path $PSScriptRoot 'downloads'
$imagePath = Join-Path $downloadDir 'ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'

# 既存ディストロの確認
$existing = wsl -l -q 2>$null | ForEach-Object { $_.Trim("`0") } | Where-Object { $_ -eq $distroName }
if ($existing) {
    Write-Host "[ERROR] Distro '$distroName' already exists. Unregister it first with: wsl --unregister $distroName" -ForegroundColor Red
    exit 1
}

# ダウンロードディレクトリ作成
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

# イメージダウンロード
if (Test-Path $imagePath) {
    Write-Host "[INFO] Image already downloaded: $imagePath" -ForegroundColor Yellow
} else {
    Write-Host "Downloading Ubuntu 24.04 rootfs..." -ForegroundColor Cyan
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "[OK] Download complete" -ForegroundColor Green
}

# インストール先ディレクトリ作成
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# ディストロインポート
Write-Host "Importing distro '$distroName'..." -ForegroundColor Cyan
wsl --import $distroName $installDir $imagePath
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to import distro" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Distro '$distroName' imported" -ForegroundColor Green

# セットアップスクリプトのパス（Windows から見た WSL マウントパス）
$setupPath = ($PSScriptRoot -replace '\\','/') -replace '^C:','/mnt/c'

# ユーザー作成と wsl.conf 配置（root として、外部スクリプト経由で実行）
Write-Host "Creating default user and configuring wsl.conf..." -ForegroundColor Cyan
wsl -d $distroName -u root -- bash "$setupPath/02-init-distro.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to configure distro" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] User configured with password and passwordless sudo" -ForegroundColor Green

# ディストロ再起動（systemd + デフォルトユーザー反映）
Write-Host "Restarting distro to apply systemd and default user..." -ForegroundColor Yellow
wsl --terminate $distroName
Start-Sleep -Seconds 2

# 確認
$whoami = wsl -d $distroName -- whoami
if ($whoami.Trim() -eq 'user') {
    Write-Host "[OK] Default user verified: $($whoami.Trim())" -ForegroundColor Green
} else {
    Write-Host "[WARN] Default user is '$($whoami.Trim())', expected 'user'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[OK] Docker distro '$distroName' is ready. Next: run 03-setup-docker.sh inside the distro." -ForegroundColor Green
Write-Host "     wsl -d $distroName -- sudo bash $setupPath/03-setup-docker.sh" -ForegroundColor Cyan
