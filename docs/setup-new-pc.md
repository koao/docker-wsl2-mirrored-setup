# 別環境向けセットアップガイド

Windows 11 PC で WSL2 + Docker CE + Portainer 環境を構築する手順書。

## 前提条件

- Windows 11 (22H2 以降推奨)
- WSL2 が利用可能であること
- 管理者権限があること

---

## パターン A: バックアップからリストア（推奨・最速）

エクスポート済み `Docker-distro-*.tar` を持っている場合。

### 1. WSL2 を有効化

```powershell
# 管理者権限の PowerShell で実行
wsl --install --no-distribution
# PC を再起動
```

### 2. .wslconfig を配置

```powershell
# リポジトリをクローンまたはコピー済みとする
cd C:\Users\<username>\Documents\GitHub\docker
.\01-setup-wslconfig.ps1
```

### 3. ディストロをインポート

```powershell
# tar ファイルを指定してリストア
.\restore-distro.ps1 -TarFile "パス\Docker-distro-YYYYMMDD-HHmmss.tar"
```

インポート後、ディストロ内の設定（wsl.conf、daemon.json、systemd override）はすべて含まれているため、WSL 起動するだけで Docker デーモンが自動起動する。

### 4. Windows 側 CLI インストール

```powershell
# 管理者権限で実行
.\04-install-windows-cli.ps1
```

### 5. ターミナルを再起動して動作確認

```powershell
# 新しいターミナルを開く
.\06-verify.ps1
```

**所要時間: WSL 有効化済みなら 5-10 分**

---

## パターン B: ゼロから構築

バックアップなし、クリーンな Windows 11 から構築する場合。

### 1. WSL2 を有効化

```powershell
# 管理者権限の PowerShell で実行
wsl --install --no-distribution
# PC を再起動
```

### 2. .wslconfig を配置

```powershell
cd C:\Users\<username>\Documents\GitHub\docker
.\01-setup-wslconfig.ps1
```

### 3. Docker 専用ディストロを作成

```powershell
.\02-create-distro.ps1
```

- ユーザーパスワードの入力を求められる
- Ubuntu 24.04 rootfs のダウンロードが行われる

### 4. Docker CE をインストール

```powershell
wsl -d Docker -- sudo bash /mnt/c/Users/<username>/Documents/GitHub/docker/03-setup-docker.sh
```

### 5. Windows 側 CLI インストール

```powershell
# 管理者権限で実行
.\04-install-windows-cli.ps1
```

### 6. Portainer をデプロイ

```powershell
wsl -d Docker -- bash /mnt/c/Users/<username>/Documents/GitHub/docker/05-install-portainer.sh
```

### 7. ターミナルを再起動して動作確認

```powershell
# 新しいターミナルを開く
.\06-verify.ps1
```

**所要時間: 15-30 分（ネットワーク速度依存）**

---

## 起動/停止

### 起動（手動）

```powershell
# systemd が Docker デーモンを自動起動する
wsl -d Docker -- echo "Docker started"
```

- `docker.cmd` ラッパーにより、`docker` コマンド初回実行時にも自動起動する
- ラッパーは WSL 内の docker CLI を直接呼ぶ（Unix ソケット経由、TCP 不要）

### 停止

```powershell
wsl --terminate Docker
```

### 常時稼働

`.wslconfig` に `vmIdleTimeout=-1` を設定済み（`01-setup-wslconfig.ps1` で自動配置）。
また `docker.cmd` ラッパーが初回起動時にバックグラウンドセッション（`sleep infinity`）を
維持するため、WSL がディストロをアイドル停止することはない。

---

## VS Code からコンテナにアタッチ

VS Code の **Dev Containers** 拡張機能で、WSL 内のコンテナに接続できる。

### 設定

VS Code の `settings.json` に以下を追加:

```json
{
  "dev.containers.dockerPath": "C:\\Program Files\\Docker-CLI\\bin\\docker.exe"
}
```

> **注意:** `docker.cmd`（ラッパー）ではなく `docker.exe`（実体）を指定すること。
> `.cmd` ファイルは Dev Containers 拡張と相性が悪い。
> `docker.exe` は `DOCKER_HOST=tcp://127.0.0.1:2375` 経由でデーモンに接続する。

### 使い方

1. コンテナが起動していることを確認: `docker ps`
2. VS Code で `F1` → **Dev Containers: Attach to Running Container** を選択
3. 対象のコンテナを選択

### コマンドラインからアタッチ

```powershell
# シェルに入る
docker exec -it <コンテナ名> bash

# ログを見る
docker logs -f <コンテナ名>
```

---

## バックアップ

構築完了後、環境をエクスポートしておくと別 PC への移行が容易になる。

```powershell
.\backup-distro.ps1
```

- `backup/` ディレクトリにタイムスタンプ付きの tar ファイルが作成される
- Docker CE、設定ファイル、コンテナイメージ、Portainer データすべてが含まれる
- ファイルサイズ目安: 2-4GB（Docker イメージの量による）

---

## トラブルシューティング

### Docker デーモンが起動しない

```bash
# WSL 内で実行
sudo systemctl status docker
sudo journalctl -u docker --no-pager -n 50
```

### Windows 側から接続できない

ターミナルでの `docker` コマンドは `docker.cmd` ラッパーが WSL 内の docker を直接呼ぶため、
TCP 接続は不要。VS Code の Dev Containers 等が `docker.exe` を使う場合のみ TCP が必要。

```powershell
# DOCKER_HOST が設定されているか確認（docker.exe 用）
echo $env:DOCKER_HOST
# → tcp://127.0.0.1:2375 であること

# WSL 内で TCP 2375 がリッスンしているか確認
wsl -d Docker -- ss -tlnp | findstr 2375
```

### docker compose / buildx が使えない

CLI プラグインは `%USERPROFILE%\.docker\cli-plugins\` に配置される。
`04-install-windows-cli.ps1` を管理者権限で再実行すれば Compose と Buildx が
再インストールされる。

```powershell
# 確認
docker compose version
docker buildx version
```

### Portainer にアクセスできない

```powershell
# コンテナが動いているか確認
docker ps --filter "name=portainer"

# 再デプロイ
wsl -d Docker -- bash /mnt/c/Users/<username>/Documents/GitHub/docker/05-install-portainer.sh
```

### mirrored mode が効いていない

```powershell
# .wslconfig を確認
cat $env:USERPROFILE\.wslconfig

# [experimental] セクションに hostAddressLoopback=true があること
# 変更後は wsl --shutdown が必要
```

---

## セキュリティ注意

- TCP 2375 は**非暗号化**。`127.0.0.1` バインドにより localhost のみアクセス可
- **絶対に `0.0.0.0` にバインドしない**こと
- Docker グループ所属 = WSL 内 root 相当のアクセス権
- Portainer は HTTP 9000 / HTTPS 9443（自己署名証明書）で使用可能
