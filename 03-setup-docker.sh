#!/bin/bash
# =============================================================================
# Docker CE インストール + デーモン設定
# Docker ディストロ内で sudo 付きで実行する:
#   wsl -d Docker -- sudo bash /mnt/c/Users/user/Documents/GitHub/docker/03-setup-docker.sh
# =============================================================================

set -euo pipefail

# root 確認
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (use sudo)" >&2
    exit 1
fi

echo "=== Step 3a: Docker CE インストール ==="

# 競合パッケージ削除
echo "Removing conflicting packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

# 前提パッケージ
echo "Installing prerequisites..."
apt-get update
apt-get install -y ca-certificates curl

# Docker 公式 GPG キー追加
echo "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Docker apt リポジトリ追加
echo "Adding Docker apt repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker CE インストール
echo "Installing Docker CE..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ユーザーを docker グループに追加
echo "Adding user to docker group..."
usermod -aG docker user

echo "[OK] Docker CE installed"

echo ""
echo "=== Step 3b: デーモン設定 ==="

# systemd ドロップインオーバーライド（-H fd:// を除去）
echo "Creating systemd override..."
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF

# daemon.json 配置
echo "Writing daemon.json..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
    "hosts": ["unix:///var/run/docker.sock", "tcp://127.0.0.1:2375"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF

echo "[OK] Daemon configured"

echo ""
echo "=== Step 3c: Docker 起動 ==="

systemctl daemon-reload
systemctl disable docker.socket
systemctl stop docker.socket 2>/dev/null || true
systemctl enable docker containerd
systemctl start docker

echo ""
echo "--- Verification ---"

# Docker デーモン起動確認
if systemctl is-active --quiet docker; then
    echo "[OK] Docker daemon is active"
else
    echo "[FAIL] Docker daemon is not active"
    systemctl status docker
    exit 1
fi

# TCP 2375 リッスン確認
if ss -tlnp | grep -q '127.0.0.1:2375'; then
    echo "[OK] TCP 2375 is listening on 127.0.0.1"
else
    echo "[WARN] TCP 2375 not detected. Checking..."
    ss -tlnp | grep 2375 || echo "Port 2375 not found"
fi

# hello-world テスト（docker グループ反映のため sudo 付き）
echo "Running hello-world test..."
docker run --rm hello-world | head -5

echo ""
echo "[OK] Docker CE setup complete."
echo "     Next: run 05-install-portainer.sh inside the distro."
echo "     wsl -d Docker -- bash /mnt/c/Users/user/Documents/GitHub/docker/05-install-portainer.sh"
