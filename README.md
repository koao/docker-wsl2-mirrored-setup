# Docker Infrastructure for Windows (WSL2 + Docker CE)

[日本語](README.ja.md)

A toolkit for running Docker CE on a dedicated WSL2 distro without Docker Desktop.

## Why mirrored networking?

In WSL2's default NAT mode, the source IP seen by applications inside containers is always the WSL virtual gateway (`172.x.x.1`, etc.) — the real client IP is lost.

With **mirrored networking mode**, WSL2 shares the Windows host's network stack, so applications inside containers can see the client's actual IP address. This enables correct behavior for IP-based access logging, rate limiting, and authentication controls.

## Architecture

```
Windows (PowerShell)
  └─ docker.cmd wrapper (C:\Program Files\Docker-CLI\)
       └─ wsl -d Docker --exec docker ...  ← via Unix socket
            └─ Docker CE daemon (managed by systemd)
                 ├─ unix:///var/run/docker.sock (primary)
                 └─ tcp://127.0.0.1:2375 (for VS Code Dev Containers)
```

- Terminal `docker` commands go through `docker.cmd` → docker CLI inside WSL → Unix socket (no TCP)
- VS Code Dev Containers uses `docker.exe` (static binary) → TCP 2375
- The distro stays alive via a `sleep infinity` background session

## Directory structure

```
├── 01-setup-wslconfig.ps1   # Deploy .wslconfig (mirrored networking, vmIdleTimeout=-1)
├── 02-create-distro.ps1     # Create Docker distro based on Ubuntu 24.04
├── 02-init-distro.sh        # Initialize distro (create user, etc.)
├── 03-setup-docker.sh       # Install Docker CE + configure daemon
├── 04-install-windows-cli.ps1 # Install Windows-side CLI + Compose + Buildx
├── 05-install-portainer.sh  # Deploy Portainer CE (HTTPS :9443)
├── 06-verify.ps1 / .sh      # Verification scripts
├── backup-distro.ps1        # Export distro to tar
├── restore-distro.ps1       # Import distro from tar
├── config/
│   ├── docker.cmd           # Windows docker wrapper
│   ├── wslconfig            # .wslconfig template
│   ├── wsl.conf             # /etc/wsl.conf template for the distro
│   ├── daemon.json          # Docker daemon config template
│   ├── docker-override.conf # systemd drop-in (removes -H fd://)
│   └── portainer-compose.yaml
├── docs/
│   └── setup-new-pc.md      # Step-by-step setup guide
├── downloads/               # Downloaded binaries (gitignored)
└── backup/                  # Exported tar files
```

## Setup order

Run the numbered scripts in order (01 → 06).
To restore from a backup: 01 → restore-distro.ps1 → 04 → 06.

## Key design decisions

- **TCP 2375 is not for terminal use**: `docker.cmd` calls docker directly inside WSL via `wsl --exec`. TCP is only for external tools like VS Code Dev Containers, because mirrored networking mode makes long-lived TCP connections unstable.
- **Startup check in docker.cmd**: `wsl -l --running | findstr` cannot match due to UTF-16 output. Instead, `wsl -d Docker --exec docker info` is used for direct verification.
- **sleep infinity**: WSL shuts down a distro when there are no active sessions (even if systemd services are running). `docker.cmd` launches `start /b wsl -d Docker -- sh -c "exec sleep infinity"` on first run to keep the distro alive.
- **--exec vs --**: `wsl --exec` runs commands directly without a shell, providing correct TTY/signal forwarding for interactive commands like `docker exec -it`. `wsl --` runs through the default shell, which caused interactive sessions to break.

## Windows-side installation paths

| Path | Description |
|------|-------------|
| `C:\Program Files\Docker-CLI\docker.cmd` | Wrapper script (added to PATH) |
| `C:\Program Files\Docker-CLI\bin\docker.exe` | Docker static binary (for VS Code) |
| `%USERPROFILE%\.docker\cli-plugins\` | Compose / Buildx plugins |

## Development notes

- After modifying `config/docker.cmd`, copy it to `C:\Program Files\Docker-CLI\docker.cmd` (requires admin privileges)
- Some `.ps1` scripts use `#Requires -RunAsAdministrator`
- `.sh` scripts run inside WSL (`wsl -d Docker -- bash ...`)
- Documentation is consolidated in `docs/setup-new-pc.md`
