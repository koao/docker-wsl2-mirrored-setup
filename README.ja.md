# Docker Infrastructure for Windows (WSL2 + Docker CE)

[English](README.md)

Docker Desktop を使わずに、WSL2 上の専用ディストロ「Docker」で Docker CE を動かす環境構築ツール。

## なぜ mirrored networking なのか

WSL2 のデフォルト（NAT モード）では、コンテナ内のアプリケーションから見た接続元 IP はすべて WSL の仮想ゲートウェイ（`172.x.x.1` 等）になり、実際のクライアント IP を取得できない。

**mirrored networking モード**を使うと、WSL2 が Windows ホストのネットワークスタックを共有するため、コンテナ内のアプリケーションがクライアントの実際の IP アドレスをそのまま取得できる。これにより、IP ベースのアクセスログ・レート制限・認証制御が正しく機能する。

## アーキテクチャ

```
Windows (PowerShell)
  └─ docker.cmd ラッパー (C:\Program Files\Docker-CLI\)
       └─ wsl -d Docker --exec docker ...  ← Unix ソケット経由
            └─ Docker CE デーモン (systemd管理)
                 ├─ unix:///var/run/docker.sock (メイン)
                 └─ tcp://127.0.0.1:2375 (VS Code Dev Containers 用)
```

- ターミナルからの `docker` コマンドは `docker.cmd` → WSL 内の docker CLI → Unix ソケットで通信（TCP 不使用）
- VS Code Dev Containers は `docker.exe`（静的バイナリ）→ TCP 2375 で通信
- ディストロは `sleep infinity` バックグラウンドセッションで常時稼働

## ディレクトリ構成

```
├── 01-setup-wslconfig.ps1   # .wslconfig 配置（mirrored networking, vmIdleTimeout=-1）
├── 02-create-distro.ps1     # Ubuntu 24.04 ベースの Docker ディストロ作成
├── 02-init-distro.sh        # ディストロ内初期化（ユーザー作成等）
├── 03-setup-docker.sh       # Docker CE インストール + デーモン設定
├── 04-install-windows-cli.ps1 # Windows 側 CLI + Compose + Buildx インストール
├── 05-install-portainer.sh  # Portainer CE デプロイ（HTTP :9000 / HTTPS :9443）
├── 06-verify.ps1 / .sh      # 動作確認スクリプト
├── backup-distro.ps1        # ディストロを tar にエクスポート
├── restore-distro.ps1       # tar からディストロをインポート
├── config/
│   ├── docker.cmd           # Windows 用 docker ラッパー（本体）
│   ├── wslconfig            # .wslconfig テンプレート
│   ├── wsl.conf             # ディストロ内 /etc/wsl.conf テンプレート
│   ├── daemon.json          # Docker デーモン設定テンプレート
│   ├── docker-override.conf # systemd ドロップイン（-H fd:// 除去）
│   └── portainer-compose.yaml
├── docs/
│   └── setup-new-pc.md      # セットアップ手順書
├── downloads/               # ダウンロード済みバイナリ（gitignore 推奨）
└── backup/                  # エクスポートした tar ファイル
```

## セットアップ順序

番号付きスクリプトを順番に実行する（01 → 06）。
バックアップからリストアする場合は 01 → restore-distro.ps1 → 04 → 06。

## 重要な設計判断

- **TCP 2375 はターミナル用ではない**: `docker.cmd` は `wsl --exec` で WSL 内の docker を直接呼ぶ。TCP は VS Code Dev Containers 等の外部ツール用。mirrored networking モードで TCP 長時間接続が不安定なため。
- **docker.cmd の起動チェック**: `wsl -l --running | findstr` は UTF-16 出力のためマッチ不可。代わりに `wsl -d Docker --exec docker info` で直接確認している。
- **sleep infinity**: WSL はアクティブセッションがないとディストロを停止する（systemd サービスが動いていても）。`docker.cmd` が初回起動時に `start /b wsl -d Docker -- sh -c "exec sleep infinity"` でセッションを維持。
- **--exec vs --**: `wsl --exec` はシェルを介さず直接実行。TTY/シグナル転送が正しく動作し、`docker exec -it` 等の対話的コマンドが安定する。`wsl --` はデフォルトシェル経由で実行されるため、対話的セッションが切れる問題があった。
- **ボリュームマウントのパス自動変換**: `-v` / `--volume` で渡す Windows パス（`C:\Users\...`）を WSL 形式（`/mnt/c/Users/...`）に自動変換する。WSL の `--cd` はパスを自動変換するが、docker の `-v` 引数は変換されないため、`docker.cmd` 内で引数をパースして変換している。名前付きボリューム（`myvolume:/app`）は2文字目が `:` でないため変換せずそのまま通過する。`--mount` 形式は未対応。

## Windows 側のインストール先

| パス | 内容 |
|------|------|
| `C:\Program Files\Docker-CLI\docker.cmd` | ラッパー（PATH に追加済み） |
| `C:\Program Files\Docker-CLI\bin\docker.exe` | Docker 静的バイナリ（VS Code 用） |
| `%USERPROFILE%\.docker\cli-plugins\` | Compose / Buildx プラグイン |

## 編集時の注意

- `config/docker.cmd` を変更したら `C:\Program Files\Docker-CLI\docker.cmd` にもコピーが必要（管理者権限）
- `.ps1` スクリプトの一部は `#Requires -RunAsAdministrator`（管理者権限が必要）
- `.sh` スクリプトは WSL 内で実行する（`wsl -d Docker -- bash ...`）
- ドキュメントは `docs/setup-new-pc.md` に集約
