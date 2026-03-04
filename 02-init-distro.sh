#!/bin/bash
# ディストロ初期化（02-create-distro.ps1 から呼び出される）
set -euo pipefail

# ユーザー作成（パスワード: docker）
HASH=$(openssl passwd -6 docker)
useradd -m -s /bin/bash -G sudo -p "$HASH" user

# wsl.conf 配置
cat > /etc/wsl.conf << 'EOF'
[boot]
systemd=true

[user]
default=user
EOF

# パスワードなし sudo
cat > /etc/sudoers.d/user << 'EOF'
user ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/user

echo "[OK] User 'user' created (password: docker) and wsl.conf configured"
