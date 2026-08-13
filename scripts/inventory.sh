#!/usr/bin/env bash
# Helper: show current Docker state. Used to confirm demos start from a known
# baseline and to make sure this assignment does not disturb unrelated work.
set -uo pipefail

echo "=== RUNNING CONTAINERS ==="
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "=== ALL CONTAINERS (including stopped) ==="
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

echo
echo "=== IMAGES ==="
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'

echo
echo "=== NETWORKS ==="
docker network ls

echo
echo "=== VOLUMES ==="
docker volume ls

echo
echo "=== PORTS IN USE ON WSL HOST ==="
ss -tulnp 2>/dev/null | grep -E 'LISTEN' || echo "(ss unavailable)"
