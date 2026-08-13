#!/usr/bin/env bash
# Requirement 1: Prove Docker is installed and the daemon is running.
# Usage: bash scripts/req01-verify-install.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req01-docker-install.txt"
mkdir -p "$(dirname "$LOG")"

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Requirement 1: Docker Installation"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Host shell: $(. /etc/os-release && echo "$PRETTY_NAME") (WSL2)"
  echo "==================================================================="

  echo
  echo "--- [1] docker --version -------------------------------------------"
  docker --version

  echo
  echo "--- [2] docker version (client + server) ---------------------------"
  docker version

  echo
  echo "--- [3] docker info : daemon is alive and reporting -----------------"
  docker info --format 'Server Version : {{.ServerVersion}}
Operating System: {{.OperatingSystem}}
OSType/Arch     : {{.OSType}}/{{.Architecture}}
Storage Driver  : {{.Driver}}
Cgroup Version  : {{.CgroupVersion}}
CPUs / Memory   : {{.NCPU}} CPUs / {{.MemTotal}} bytes
Containers      : {{.Containers}} (running {{.ContainersRunning}})
Images          : {{.Images}}'

  echo
  echo "--- [4] hello-world : end-to-end proof the engine can run a container"
  docker run --rm hello-world

  echo
  echo "=== Requirement 1 verified: Docker installed and daemon running ==="
} 2>&1 | tee "$LOG"

echo
echo "Evidence written to: $LOG"
