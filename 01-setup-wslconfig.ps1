#Requires -Version 5.1
<#
.SYNOPSIS
    .wslconfig を更新し、mirrored networking + hostAddressLoopback を設定する。
.DESCRIPTION
    既存の .wslconfig をバックアップし、新しい設定で上書きする。
    設定反映のため wsl --shutdown を実行する。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$wslconfigPath = "$env:USERPROFILE\.wslconfig"
$backupPath = "$env:USERPROFILE\.wslconfig.bak"
$sourceConfig = Join-Path $PSScriptRoot 'config\wslconfig'

# バックアップ
if (Test-Path $wslconfigPath) {
    Copy-Item -Path $wslconfigPath -Destination $backupPath -Force
    Write-Host "[OK] Backed up existing .wslconfig to .wslconfig.bak" -ForegroundColor Green
} else {
    Write-Host "[INFO] No existing .wslconfig found, creating new one" -ForegroundColor Yellow
}

# 設定ファイルをコピー
Copy-Item -Path $sourceConfig -Destination $wslconfigPath -Force
Write-Host "[OK] Updated .wslconfig" -ForegroundColor Green

# 内容を表示
Write-Host "`n--- .wslconfig contents ---" -ForegroundColor Cyan
Get-Content $wslconfigPath
Write-Host "--- end ---`n" -ForegroundColor Cyan

# WSL シャットダウン
Write-Host "Shutting down WSL to apply changes..." -ForegroundColor Yellow
wsl --shutdown
Write-Host "[OK] WSL shutdown complete. Changes will take effect on next WSL start." -ForegroundColor Green
