#!/bin/bash
# =============================================================================
# WSL 側 総合検証
# Docker ディストロ内で実行する:
#   wsl -d Docker -- bash /mnt/c/Users/user/Documents/GitHub/docker/06-verify.sh
# =============================================================================

set -uo pipefail

passed=0
failed=0

test_step() {
    local name="$1"
    shift
    echo ""
    echo "--- $name ---"
    if "$@"; then
        echo "[PASS] $name"
        ((passed++))
    else
        echo "[FAIL] $name"
        ((failed++))
    fi
}

# Test 1: Docker デーモン起動確認
check_daemon() {
    local status
    status=$(systemctl is-active docker)
    echo "  docker.service: $status"
    [ "$status" = "active" ]
}

# Test 2: TCP 2375 リッスン確認
check_tcp() {
    if ss -tlnp | grep -q '127.0.0.1:2375'; then
        echo "  127.0.0.1:2375 is listening"
        return 0
    else
        echo "  127.0.0.1:2375 not found"
        ss -tlnp 2>/dev/null
        return 1
    fi
}

# Test 3: hello-world コンテナ実行
check_hello() {
    local output
    output=$(docker run --rm hello-world 2>&1)
    if echo "$output" | grep -q 'Hello from Docker'; then
        echo "  Hello from Docker!"
        return 0
    else
        echo "  $output"
        return 1
    fi
}

# Test 4: Portainer コンテナ稼働確認
check_portainer() {
    local status
    status=$(docker ps --filter "name=portainer" --format '{{.Names}} {{.Status}}')
    if echo "$status" | grep -q 'portainer'; then
        echo "  $status"
        return 0
    else
        echo "  Portainer container not found"
        return 1
    fi
}

# Test 5: docker compose バージョン
check_compose() {
    local version
    version=$(docker compose version 2>&1)
    echo "  $version"
    [ $? -eq 0 ]
}

test_step "Docker daemon status" check_daemon
test_step "TCP 2375 listening" check_tcp
test_step "hello-world container" check_hello
test_step "Portainer container" check_portainer
test_step "Docker Compose" check_compose

echo ""
echo "========================================"
echo "Results: $passed passed, $failed failed"
echo "========================================"

[ "$failed" -eq 0 ]
