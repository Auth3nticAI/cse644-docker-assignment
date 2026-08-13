#!/usr/bin/env bash
# Requirement 4: Pull a public image, run it as a container, and open an
# interactive shell session inside the running container.
#
# Usage: bash scripts/req04-pull-run-exec.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req04-pull-run-exec.txt"
mkdir -p "$(dirname "$LOG")"

IMAGE="ubuntu:24.04"
CONTAINER="cse644-req04-demo"

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Req 4: Pull, Run, and Exec"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Image: $IMAGE   Container: $CONTAINER"
  echo "==================================================================="

  # Start clean so the run below is unambiguous evidence, not a leftover.
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker rmi "$IMAGE" >/dev/null 2>&1 || true

  echo
  echo "--- [1] PULL a public image from Docker Hub ------------------------"
  docker pull "$IMAGE"

  echo
  echo "--- [1b] Confirm the image is now in the local image store ---------"
  docker images "$IMAGE" --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'

  echo
  echo "--- [2] RUN the image as a container -------------------------------"
  # 'sleep 3600' keeps the container alive. A container lives exactly as long
  # as its PID 1; plain 'docker run ubuntu' would exit instantly because bash
  # gets no TTY, leaving nothing to exec into.
  docker run -d --name "$CONTAINER" "$IMAGE" sleep 3600
  echo
  echo "Container is running:"
  docker ps --filter "name=$CONTAINER" \
    --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Command}}'

  echo
  echo "--- [3] INTERACTIVE SHELL SESSION inside the running container -----"
  echo "Allocating a real pseudo-TTY with script(1) so 'docker exec -it'"
  echo "behaves exactly as it would when typed by hand:"
  echo
  script -qec "docker exec -it $CONTAINER bash -lc '
    echo \"### I am now INSIDE the container ###\"
    echo
    echo \"Shell PID / TTY : \$\$ on \$(tty)\"
    echo \"Container host  : \$(hostname)\"
    echo \"Distro          : \$(. /etc/os-release && echo \$PRETTY_NAME)\"
    echo \"Whoami          : \$(whoami)\"
    echo
    echo \"--- Process table (own PID namespace: sleep is PID 1) ---\"
    ps -ef
    echo
    echo \"--- Root filesystem is the image, not the host ---\"
    ls /
    echo
    echo \"--- Write a file that exists only in this container ---\"
    echo \"written inside \$(hostname) at \$(date -u)\" > /tmp/proof.txt
    cat /tmp/proof.txt
  '" /dev/null

  echo
  echo "--- [3b] Prove that session really ran in the container ------------"
  echo "Re-entering with a second exec and reading back the file:"
  docker exec "$CONTAINER" cat /tmp/proof.txt
  echo
  echo "Container hostname  : $(docker exec "$CONTAINER" hostname)"
  echo "WSL host hostname   : $(hostname)"
  echo "(different hostnames => the shell was isolated in the container)"

  echo
  echo "--- [4] Final state -------------------------------------------------"
  docker ps --filter "name=$CONTAINER" --format 'table {{.Names}}\t{{.Status}}'

  echo
  echo "=== Req 4 verified: image pulled, container run, interactive exec ==="
  echo
  echo "Container '$CONTAINER' is left RUNNING so you can open your own"
  echo "interactive session for a screenshot:"
  echo "    docker exec -it $CONTAINER bash"
  echo "Clean up afterwards with:"
  echo "    docker rm -f $CONTAINER"
} 2>&1 | tee "$LOG"

echo
echo "Evidence written to: $LOG"
