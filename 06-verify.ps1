#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 側から Docker 環境の総合検証を行う。
.DESCRIPTION
    Docker CLI の接続、Portainer のアクセス、mirrored mode の実IP確認をテストする。
    ターミナル再起動後（PATH/DOCKER_HOST 反映後）に実行すること。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$passed = 0
$failed = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Test)
    Write-Host "`n--- $Name ---" -ForegroundColor Cyan
    try {
        & $Test
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    } catch {
        Write-Host "[FAIL] $Name : $_" -ForegroundColor Red
        $script:failed++
    }
}

# SSL 証明書検証を無効化（Portainer 自己署名証明書用）
Add-Type @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCerts {
    public static void Trust() {
        ServicePointManager.ServerCertificateValidationCallback =
            new RemoteCertificateValidationCallback(
                delegate { return true; }
            );
    }
    public static void Reset() {
        ServicePointManager.ServerCertificateValidationCallback = null;
    }
}
"@

# Test 1: DOCKER_HOST 環境変数
Test-Step "DOCKER_HOST environment variable" {
    $dockerHost = $env:DOCKER_HOST
    if ($dockerHost -ne 'tcp://127.0.0.1:2375') {
        throw "DOCKER_HOST='$dockerHost', expected 'tcp://127.0.0.1:2375'"
    }
    Write-Host "  DOCKER_HOST=$dockerHost"
}

# Test 2: Docker version (接続確認)
Test-Step "docker version (client + server)" {
    $version = docker version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker version failed: $version" }
    $clientVer = $version | Select-String 'Version:' | Select-Object -First 1
    $serverVer = $version | Select-String 'Server:'
    Write-Host "  $clientVer"
    Write-Host "  $serverVer"
}

# Test 3: docker info
Test-Step "docker info" {
    $info = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker info failed" }
    $serverVersion = $info | Select-String 'Server Version'
    Write-Host "  $serverVersion"
}

# Test 4: hello-world コンテナ
Test-Step "docker run hello-world" {
    $result = docker run --rm hello-world 2>&1
    if ($LASTEXITCODE -ne 0) { throw "hello-world failed: $result" }
    $hello = $result | Select-String 'Hello from Docker'
    if (-not $hello) { throw "Unexpected output from hello-world" }
    Write-Host "  $hello"
}

# Test 5: Portainer コンテナ稼働
Test-Step "Portainer container running" {
    $containers = docker ps --filter "name=portainer" --format "{{.Names}} {{.Status}}" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker ps failed: $containers" }
    if ($containers -notmatch 'portainer') { throw "Portainer container not found" }
    Write-Host "  $containers"
}

# Test 6: Portainer HTTP アクセス
Test-Step "Portainer HTTP access (port 9000)" {
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:9000' -UseBasicParsing -TimeoutSec 15
        Write-Host "  Status: $($response.StatusCode)"
    } catch {
        if ($_.Exception.Response) {
            Write-Host "  Portainer is responding (may redirect to setup)"
        } else {
            throw $_
        }
    }
}

# Test 7: mirrored mode 実IP テスト（WSL 経由でアクセスしてログ確認）
Test-Step "Mirrored mode real IP test (nginx)" {
    Write-Host "  Starting nginx test container..."
    docker rm -f nginx-ip-test 2>$null | Out-Null
    docker run -d --name nginx-ip-test -p 8080:80 nginx:alpine | Out-Null
    Start-Sleep -Seconds 3

    # WSL 側から curl でアクセス（mirrored mode では実IP が見える）
    wsl -d Docker -- curl -s http://localhost:8080 -o /dev/null
    Start-Sleep -Seconds 1

    # アクセスログを確認
    $logs = docker logs nginx-ip-test 2>&1
    Write-Host "  Nginx access log:"
    $accessLines = $logs | Select-String 'GET / '
    foreach ($line in $accessLines) {
        Write-Host "    $line"
        if ($line -match '^172\.' -or $line -match '^10\.') {
            Write-Host "  [WARN] NAT IP detected. Mirrored mode may not be active." -ForegroundColor Yellow
        }
    }

    # クリーンアップ
    docker rm -f nginx-ip-test | Out-Null
    Write-Host "  Test container cleaned up"
}

# 結果サマリー
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
Write-Host "========================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
