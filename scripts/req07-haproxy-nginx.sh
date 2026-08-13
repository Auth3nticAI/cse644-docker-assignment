#!/usr/bin/env bash
# Requirement 7: HAProxy proxying to Nginx. Proves the proxy hop is real,
# that round-robin balancing works, and that health-check failover works.
#
# Usage: bash scripts/req07-haproxy-nginx.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req07-haproxy-nginx.txt"
mkdir -p "$(dirname "$LOG")"

PROJ="$REPO_ROOT/req07-haproxy-nginx"

# A FUNCTION, not a string variable. The repo path contains a space
# ("CSE644 Cloud Computing"); an unquoted `$COMPOSE` string would word-split
# that path into two arguments, and a quoted one would be treated as a single
# binary name. A function preserves argument boundaries correctly.
compose() { docker compose -f "$PROJ/docker-compose.yml" -p cse644-proxy "$@"; }

PROXY_PORT=8090
STATS_PORT=8404

FAILED=0
check() {
  if [ "$2" -eq 0 ]; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; FAILED=1; fi
}

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Req 7: HAProxy Proxying to Nginx"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "==================================================================="

  compose down --remove-orphans >/dev/null 2>&1 || true

  echo
  echo "--- [1] HAProxy configuration ---------------------------------------"
  cat "$PROJ/haproxy/haproxy.cfg"

  echo
  echo "--- [2] Nginx backend configuration ---------------------------------"
  cat "$PROJ/nginx/default.conf"

  echo
  echo "--- [3] Compose topology ---------------------------------------------"
  cat "$PROJ/docker-compose.yml"

  echo
  echo "--- [4] BUILD AND START the stack ------------------------------------"
  compose up -d --build
  check "stack started" $?

  echo
  echo -n "Waiting for HAProxy to become healthy"
  STATE=""
  for _ in $(seq 1 45); do
    STATE="$(docker inspect -f '{{.State.Health.Status}}' cse644-haproxy 2>/dev/null)"
    [ "$STATE" = "healthy" ] && break
    echo -n "."; sleep 1
  done
  echo " -> $STATE"

  echo
  echo "--- [5] BOTH SERVICES RUNNING -----------------------------------------"
  compose ps
  echo
  docker ps --filter "name=cse644-web1" --filter "name=cse644-web2" \
            --filter "name=cse644-haproxy" \
            --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
  RUNNING="$(docker ps --filter 'name=cse644-web1' --filter 'name=cse644-web2' \
             --filter 'name=cse644-haproxy' -q | wc -l)"
  [ "$RUNNING" -eq 3 ]
  check "all 3 containers (haproxy + web1 + web2) are running" $?

  echo
  echo "--- [6] Nginx backends are NOT reachable directly from the host -------"
  echo "Published ports for web1/web2 (expected: empty):"
  docker port cse644-web1 2>&1 || true
  docker port cse644-web2 2>&1 || true
  echo
  echo "Only HAProxy publishes to the host:"
  docker port cse644-haproxy
  [ -z "$(docker port cse644-web1 2>/dev/null)" ] && [ -z "$(docker port cse644-web2 2>/dev/null)" ]
  check "backends publish no host ports (traffic MUST traverse the proxy)" $?

  echo
  echo "--- [7] FORWARDED REQUEST through HAProxy ------------------------------"
  echo "curl -D - http://localhost:${PROXY_PORT}/"
  curl -sS -D - -o /dev/null "http://localhost:${PROXY_PORT}/"
  echo
  HDRS="$(curl -sS -D - -o /dev/null "http://localhost:${PROXY_PORT}/" 2>/dev/null)"
  grep -qi 'X-CSE644-Proxy: *haproxy' <<<"$HDRS"
  check "response carries X-CSE644-Proxy: haproxy (added BY the proxy)" $?
  grep -qi 'X-CSE644-Backend:' <<<"$HDRS"
  check "response carries X-CSE644-Backend (added BY nginx, passed through)" $?

  echo
  echo "--- [8] PROXIED RESPONSE BODY ------------------------------------------"
  curl -sS "http://localhost:${PROXY_PORT}/" | grep -A2 'class="host"'
  curl -sS "http://localhost:${PROXY_PORT}/" | grep -q 'Nginx Backend'
  check "proxied response returns the Nginx backend page" $?

  echo
  echo "--- [9] ROUND-ROBIN LOAD BALANCING across both backends ----------------"
  echo "Issuing 10 requests and recording which backend answered each:"
  : > /tmp/cse644_backends.txt
  for i in $(seq 1 10); do
    B="$(curl -sS -D - -o /dev/null "http://localhost:${PROXY_PORT}/" 2>/dev/null \
         | grep -i '^X-CSE644-Backend:' | tr -d '\r' | awk '{print $2}')"
    printf '  request %2d -> backend %s\n' "$i" "$B"
    echo "$B" >> /tmp/cse644_backends.txt
  done
  echo
  echo "Distribution:"
  sort /tmp/cse644_backends.txt | uniq -c | sed 's/^/  /'
  DISTINCT="$(sort -u /tmp/cse644_backends.txt | grep -c .)"
  [ "$DISTINCT" -eq 2 ]
  check "requests were balanced across 2 distinct backends" $?

  echo
  echo "--- [10] HAProxy stats dashboard (backend health) ----------------------"
  curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null \
    | awk -F, 'NR==1 || $1=="be_nginx" {printf "  %-10s %-8s status=%s\n", $1, $2, $18}'
  curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null | grep -q 'be_nginx,web1,.*,UP,'
  check "HAProxy reports web1 UP via active health check" $?

  echo
  echo "--- [11] HEALTH-CHECK FAILOVER -----------------------------------------"
  echo "Breaking web1's /healthz so HAProxy should evict it from the pool..."
  # Point /healthz at a 503 and reload nginx inside web1.
  docker exec cse644-web1 sh -c \
    "sed -i 's|return 200 \"ok\\\\n\";|return 503 \"down\\\\n\";|' /etc/nginx/conf.d/default.conf && nginx -s reload" \
    >/dev/null 2>&1
  echo "Waiting for HAProxy to mark web1 DOWN (check inter 2s, fall 2)..."
  for _ in $(seq 1 20); do
    curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null | grep -q 'be_nginx,web1,.*,DOWN,' && break
    sleep 1
  done
  curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null \
    | awk -F, '$1=="be_nginx" {printf "  %-10s %-8s status=%s\n", $1, $2, $18}'
  curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null | grep -q 'be_nginx,web1,.*,DOWN,'
  check "HAProxy detected the unhealthy backend and marked web1 DOWN" $?

  echo
  echo "With web1 evicted, 6 requests should ALL land on web2:"
  : > /tmp/cse644_failover.txt
  for i in $(seq 1 6); do
    B="$(curl -sS -D - -o /dev/null "http://localhost:${PROXY_PORT}/" 2>/dev/null \
         | grep -i '^X-CSE644-Backend:' | tr -d '\r' | awk '{print $2}')"
    printf '  request %d -> backend %s\n' "$i" "$B"
    echo "$B" >> /tmp/cse644_failover.txt
  done
  [ "$(sort -u /tmp/cse644_failover.txt | grep -c .)" -eq 1 ]
  check "all traffic failed over to the surviving backend, zero errors" $?

  echo
  echo "Restoring web1 by RECREATING it from its image..."
  echo "  NOTE: 'docker restart' would NOT restore it. The sed above modified"
  echo "  the container's writable layer, and restart reuses that same layer."
  echo "  Only recreating the container gives it a fresh writable layer over"
  echo "  the untouched image - the image itself was never modified."
  compose up -d --force-recreate --no-deps web1 >/dev/null 2>&1
  for _ in $(seq 1 25); do
    curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null | grep -q 'be_nginx,web1,.*,UP,' && break
    sleep 1
  done
  curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null \
    | awk -F, '$1=="be_nginx" {printf "  %-10s %-8s status=%s\n", $1, $2, $18}'
  curl -sS "http://localhost:${STATS_PORT}/;csv" 2>/dev/null | grep -q 'be_nginx,web1,.*,UP,'
  check "web1 rejoined the pool after recovery" $?

  echo
  echo "--- [12] HAProxy request log (shows the forwarding decisions) ----------"
  docker logs --tail 12 cse644-haproxy 2>&1

  echo
  echo "==================================================================="
  if [ $FAILED -eq 0 ]; then
    echo " RESULT: Req 7 VERIFIED - HAProxy proxies and balances to Nginx"
  else
    echo " RESULT: Req 7 FAILED - see [FAIL] lines above"
  fi
  echo "==================================================================="
  echo
  echo "Stack left running for your browser screenshots:"
  echo "    http://localhost:${PROXY_PORT}/   (reload: hostname alternates)"
  echo "    http://localhost:${STATS_PORT}/   (HAProxy stats dashboard)"
  echo "Tear down with:"
  echo "    docker compose -f req07-haproxy-nginx/docker-compose.yml -p cse644-proxy down"
} > "$LOG" 2>&1

grep -E '^\s*\[(PASS|FAIL)\]|^ RESULT:' "$LOG"
echo "Evidence ($(wc -l < "$LOG") lines) -> $LOG"
exit $FAILED
