@echo off
wsl -d Docker --exec docker info >nul 2>&1 && goto :ready
echo Starting Docker distro... 1>&2
start "" /b wsl -d Docker -- sh -c "exec sleep infinity"
wsl -d Docker --exec sh -c "while ! docker info >/dev/null 2>&1; do sleep 0.5; done"
:ready
wsl -d Docker --cd "%cd%" --exec docker %*
