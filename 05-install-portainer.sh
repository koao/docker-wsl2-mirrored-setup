#!/bin/bash
# =============================================================================
# Portainer デプロイ
# Docker ディストロ内で実行する:
#   wsl -d Docker -- bash /mnt/c/Users/user/Documents/GitHub/docker/05-install-portainer.sh
# =============================================================================

set -euo pipefail

COMPOSE_FILE="/mnt/c/Users/user/Documents/GitHub/docker/config/portainer-compose.yaml"

echo "=== Portainer デプロイ ==="

# Docker 動作確認
if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker is not running. Start the Docker daemon first." >&2
    exit 1
fi

# 既存の Portainer を停止（存在する場合）
if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "Removing existing Portainer container..."
    docker rm -f portainer
fi

# Compose でデプロイ
echo "Deploying Portainer with docker compose..."
docker compose -f "$COMPOSE_FILE" up -d

# 起動確認
echo ""
echo "Waiting for Portainer to start..."
sleep 5

if docker ps --filter "name=portainer" --format '{{.Names}} {{.Status}}' | grep -q 'portainer'; then
    echo "[OK] Portainer is running"
    docker ps --filter "name=portainer" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
else
    echo "[FAIL] Portainer failed to start"
    docker logs portainer 2>&1 | tail -20
    exit 1
fi

echo ""
echo "[OK] Portainer deployed successfully."
echo "     Access: https://localhost:9443"
echo "     (Accept the self-signed certificate warning)"
echo "     Create an admin account on first access."
