#!/usr/bin/env bash
# Remove ONLY the resources this assignment created.
#
# Every container, network, and volume made by these scripts is prefixed
# "cse644-", so teardown can be surgical. This machine hosts unrelated work
# (Jenkins, n8n, Postgres volumes), so `docker system prune` is deliberately
# NOT used anywhere - it would delete other people's data.
#
# Images are kept by default: they are the graded deliverable and are also
# published on Docker Hub. Pass --images to remove the local copies too.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOVE_IMAGES=0
[ "${1:-}" = "--images" ] && REMOVE_IMAGES=1

echo "=== BEFORE ==="
docker ps -a --filter "name=cse644-" --format 'table {{.Names}}\t{{.Status}}'

echo
echo "--- Stopping the HAProxy compose stack ---"
docker compose -f "$REPO_ROOT/req07-haproxy-nginx/docker-compose.yml" \
  -p cse644-proxy down --remove-orphans 2>&1 | sed 's/^/  /' || true

echo
echo "--- Removing remaining cse644-* containers ---"
CONTAINERS="$(docker ps -aq --filter 'name=cse644-')"
if [ -n "$CONTAINERS" ]; then
  docker rm -f $CONTAINERS | sed 's/^/  removed /'
else
  echo "  (none left)"
fi

echo
echo "--- Removing cse644-* networks ---"
NETS="$(docker network ls -q --filter 'name=cse644-')"
if [ -n "$NETS" ]; then
  docker network rm $NETS 2>/dev/null | sed 's/^/  removed /'
else
  echo "  (none)"
fi

echo
echo "--- Volumes ---"
if docker volume ls -q --filter 'name=cse644-' | grep -q .; then
  docker volume ls --filter 'name=cse644-' --format '  {{.Name}} (KEPT as Req 8 evidence)'
  echo "  Remove manually with: docker volume rm cse644-data"
else
  echo "  (none)"
fi

if [ $REMOVE_IMAGES -eq 1 ]; then
  echo
  echo "--- Removing local cse644-* images ---"
  IMGS="$(docker images -q 'auth3nticai/cse644-*' | sort -u)"
  [ -n "$IMGS" ] && docker rmi -f $IMGS 2>&1 | sed 's/^/  /' || echo "  (none)"
else
  echo
  echo "--- Images KEPT (graded deliverable; also on Docker Hub) ---"
  docker images --filter 'reference=auth3nticai/cse644-*' \
    --format '  {{.Repository}}:{{.Tag}}  {{.Size}}'
fi

echo
echo "=== AFTER ==="
echo "cse644-* containers remaining:"
docker ps -a --filter "name=cse644-" --format '  {{.Names}}\t{{.Status}}' || true
echo
echo "Everything still running on this machine (should be YOUR unrelated work):"
docker ps --format '  {{.Names}}\t{{.Image}}\t{{.Ports}}'

echo
echo "Teardown complete. No unrelated containers, networks, or volumes were touched."
