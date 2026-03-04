#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 側に Docker CLI + Compose + Buildx プラグインをインストールする。
.DESCRIPTION
    Docker 静的バイナリ、Docker Compose V2、Docker Buildx プラグインをダウンロードし、
    docker.cmd ラッパーとともに配置する。
    DOCKER_HOST 環境変数とユーザー PATH を設定する。
    管理者権限で実行すること。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dockerCliDir = 'C:\Program Files\Docker-CLI'
$dockerBinDir = Join-Path $dockerCliDir 'bin'
$downloadDir = Join-Path $PSScriptRoot 'downloads'
$dockerCmdSource = Join-Path $PSScriptRoot 'config\docker.cmd'

# Docker 静的バイナリのバージョンを取得してダウンロード
Write-Host "Fetching latest Docker CLI version..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'

# 最新の安定版バージョンを取得
$page = Invoke-WebRequest -Uri 'https://download.docker.com/win/static/stable/x86_64/' -UseBasicParsing
$versions = $page.Links | ForEach-Object { $_.href } | Where-Object { $_ -match '^docker-(\d+\.\d+\.\d+)\.zip$' } | Sort-Object -Descending
$latestZip = $versions | Select-Object -First 1

if (-not $latestZip) {
    Write-Host "[ERROR] Could not determine latest Docker version" -ForegroundColor Red
    exit 1
}

$dockerZipUrl = "https://download.docker.com/win/static/stable/x86_64/$latestZip"
$dockerZipPath = Join-Path $downloadDir $latestZip

Write-Host "Latest Docker CLI: $latestZip" -ForegroundColor Cyan

# ダウンロード
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

if (Test-Path $dockerZipPath) {
    Write-Host "[INFO] Archive already downloaded: $dockerZipPath" -ForegroundColor Yellow
} else {
    Write-Host "Downloading $latestZip..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $dockerZipUrl -OutFile $dockerZipPath -UseBasicParsing
    Write-Host "[OK] Download complete" -ForegroundColor Green
}

$ProgressPreference = 'Continue'

# ディレクトリ作成
if (-not (Test-Path $dockerBinDir)) {
    New-Item -ItemType Directory -Path $dockerBinDir -Force | Out-Null
}

# 展開（docker/ フォルダ内の docker.exe を bin/ へ）
Write-Host "Extracting docker.exe..." -ForegroundColor Cyan
$tempExtract = Join-Path $env:TEMP "docker-extract-$(Get-Random)"
Expand-Archive -Path $dockerZipPath -DestinationPath $tempExtract -Force
Copy-Item -Path (Join-Path $tempExtract 'docker\docker.exe') -Destination $dockerBinDir -Force
Remove-Item -Path $tempExtract -Recurse -Force
Write-Host "[OK] docker.exe installed to $dockerBinDir" -ForegroundColor Green

# --- Docker Compose V2 プラグイン ---
Write-Host "`nFetching latest Docker Compose version..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'

$composeRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/docker/compose/releases/latest' -UseBasicParsing
$composeVersion = $composeRelease.tag_name
$composeUrl = "https://github.com/docker/compose/releases/download/$composeVersion/docker-compose-windows-x86_64.exe"
$composeDownloadPath = Join-Path $downloadDir "docker-compose-$composeVersion.exe"

Write-Host "Latest Docker Compose: $composeVersion" -ForegroundColor Cyan

if (Test-Path $composeDownloadPath) {
    Write-Host "[INFO] Compose already downloaded: $composeDownloadPath" -ForegroundColor Yellow
} else {
    Write-Host "Downloading docker-compose $composeVersion..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $composeUrl -OutFile $composeDownloadPath -UseBasicParsing
    Write-Host "[OK] Download complete" -ForegroundColor Green
}

$ProgressPreference = 'Continue'

# CLI プラグインディレクトリに配置（ユーザー標準パス）
$cliPluginsDir = Join-Path $env:USERPROFILE '.docker\cli-plugins'
if (-not (Test-Path $cliPluginsDir)) {
    New-Item -ItemType Directory -Path $cliPluginsDir -Force | Out-Null
}
Copy-Item -Path $composeDownloadPath -Destination (Join-Path $cliPluginsDir 'docker-compose.exe') -Force
Write-Host "[OK] docker-compose plugin installed to $cliPluginsDir" -ForegroundColor Green

# --- Docker Buildx プラグイン ---
Write-Host "`nFetching latest Docker Buildx version..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'

$buildxRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/docker/buildx/releases/latest' -UseBasicParsing
$buildxVersion = $buildxRelease.tag_name
$buildxUrl = "https://github.com/docker/buildx/releases/download/$buildxVersion/buildx-$buildxVersion.windows-amd64.exe"
$buildxDownloadPath = Join-Path $downloadDir "docker-buildx-$buildxVersion.exe"

Write-Host "Latest Docker Buildx: $buildxVersion" -ForegroundColor Cyan

if (Test-Path $buildxDownloadPath) {
    Write-Host "[INFO] Buildx already downloaded: $buildxDownloadPath" -ForegroundColor Yellow
} else {
    Write-Host "Downloading docker-buildx $buildxVersion..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $buildxUrl -OutFile $buildxDownloadPath -UseBasicParsing
    Write-Host "[OK] Download complete" -ForegroundColor Green
}

$ProgressPreference = 'Continue'

Copy-Item -Path $buildxDownloadPath -Destination (Join-Path $cliPluginsDir 'docker-buildx.exe') -Force
Write-Host "[OK] docker-buildx plugin installed to $cliPluginsDir" -ForegroundColor Green

# docker.cmd ラッパー配置
Copy-Item -Path $dockerCmdSource -Destination $dockerCliDir -Force
Write-Host "[OK] docker.cmd wrapper installed to $dockerCliDir" -ForegroundColor Green

# ユーザー PATH に追加
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$dockerCliDir*") {
    [Environment]::SetEnvironmentVariable('PATH', "$dockerCliDir;$userPath", 'User')
    Write-Host "[OK] Added $dockerCliDir to user PATH" -ForegroundColor Green
} else {
    Write-Host "[INFO] $dockerCliDir already in user PATH" -ForegroundColor Yellow
}

# DOCKER_HOST 環境変数設定
[Environment]::SetEnvironmentVariable('DOCKER_HOST', 'tcp://127.0.0.1:2375', 'User')
Write-Host "[OK] Set DOCKER_HOST=tcp://127.0.0.1:2375 (user environment)" -ForegroundColor Green

Write-Host "`n[OK] Docker CLI installation complete." -ForegroundColor Green
Write-Host "[IMPORTANT] Restart your terminal to pick up PATH and DOCKER_HOST changes." -ForegroundColor Yellow
Write-Host "            Then run: docker version" -ForegroundColor Cyan
