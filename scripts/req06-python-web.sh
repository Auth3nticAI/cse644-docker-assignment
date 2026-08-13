#!/usr/bin/env bash
# Requirement 6: Build and run a Python web server on port 8888, and prove
# the port is in use and the app responds.
#
# Usage: bash scripts/req06-python-web.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req06-python-web.txt"
mkdir -p "$(dirname "$LOG")"

CTX="$REPO_ROOT/req06-python-web"
IMAGE="auth3nticai/cse644-python-web:v1"
CONTAINER="cse644-python-web"
PORT=8888   # mandated by the assignment

FAILED=0
check() {
  if [ "$2" -eq 0 ]; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; FAILED=1; fi
}

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Req 6: Python Web Server on Port 8888"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Image: $IMAGE"
  echo "==================================================================="

  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

  echo
  echo "--- [1] Application source: app.py ----------------------------------"
  cat "$CTX/app.py"

  echo
  echo "--- [2] requirements.txt --------------------------------------------"
  cat "$CTX/requirements.txt"

  echo
  echo "--- [3] Dockerfile ---------------------------------------------------"
  cat "$CTX/Dockerfile"

  echo
  echo "--- [4] BUILD the image ----------------------------------------------"
  docker build \
    --build-arg BUILD_DATE="$(date -u '+%Y-%m-%d %H:%M:%S UTC')" \
    --build-arg STUDENT="Tray Branch" \
    -t "$IMAGE" "$CTX"
  check "image built successfully" $?
  [ $FAILED -ne 0 ] && { echo "Build failed; aborting."; exit 1; }

  echo
  docker images "$IMAGE" --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'

  echo
  echo "--- [5] RUN the container, publishing port 8888 ----------------------"
  docker run -d --name "$CONTAINER" -p "${PORT}:${PORT}" "$IMAGE"
  echo
  echo -n "Waiting for container health"
  STATE=""
  for _ in $(seq 1 40); do
    STATE="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null)"
    [ "$STATE" = "healthy" ] && break
    echo -n "."; sleep 1
  done
  echo " -> $STATE"
  check "container reports healthy" "$([ "$STATE" = healthy ] && echo 0 || echo 1)"

  echo
  docker ps --filter "name=$CONTAINER" \
    --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

  echo
  echo "--- [6] PORT 8888 IS IN USE ------------------------------------------"
  echo "(a) Docker's own port mapping:"
  docker port "$CONTAINER"
  echo
  echo "(b) Listening socket on the host, via ss:"
  ss -tulnp 2>/dev/null | grep -E "(^Netid|:${PORT}\b)" || echo "  (ss found nothing)"
  ss -tuln 2>/dev/null | grep -q ":${PORT}\b"
  check "port ${PORT} is bound and LISTENING on the host" $?
  echo
  echo "(c) Inside the container, gunicorn is bound to 0.0.0.0:${PORT}:"
  docker exec "$CONTAINER" python -c "
import socket
s = socket.socket()
r = s.connect_ex(('127.0.0.1', ${PORT}))
print('  connect to 127.0.0.1:${PORT} ->', 'OPEN' if r == 0 else f'CLOSED (errno {r})')
s.close()
"

  echo
  echo "--- [7] COMMAND-LINE RESPONSE: HTTP headers --------------------------"
  curl -sS -D - -o /dev/null "http://localhost:${PORT}/"
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/")" = "200" ]
  check "GET / returns HTTP 200" $?

  echo
  echo "--- [8] COMMAND-LINE RESPONSE: JSON API ------------------------------"
  curl -sS "http://localhost:${PORT}/api/info" | python3 -m json.tool
  curl -sS "http://localhost:${PORT}/api/info" | python3 -c "
import json,sys
d = json.load(sys.stdin)
assert d['listening_port'] == ${PORT}, 'wrong port reported'
assert d['requirement'] == 6
"
  check "/api/info reports listening_port=${PORT}" $?

  echo
  echo "--- [9] COMMAND-LINE RESPONSE: rendered HTML page --------------------"
  curl -sS "http://localhost:${PORT}/" | head -n 40
  echo "  ... (truncated)"
  curl -sS "http://localhost:${PORT}/" | grep -q 'Python Web Server in Docker'
  check "custom HTML page served" $?

  echo
  echo "--- [10] Health endpoint ---------------------------------------------"
  curl -sS -w 'HTTP %{http_code}\n' "http://localhost:${PORT}/healthz"

  echo
  echo "--- [11] Container is running as a NON-ROOT user ----------------------"
  docker exec "$CONTAINER" id
  [ "$(docker exec "$CONTAINER" id -un)" = "appuser" ]
  check "process runs as unprivileged 'appuser', not root" $?

  echo
  echo "--- [12] Application logs (gunicorn access log via docker logs) -------"
  docker logs --tail 15 "$CONTAINER"

  echo
  echo "==================================================================="
  if [ $FAILED -eq 0 ]; then
    echo " RESULT: Req 6 VERIFIED - Python web server containerized on :${PORT}"
  else
    echo " RESULT: Req 6 FAILED - see [FAIL] lines above"
  fi
  echo "==================================================================="
  echo
  echo "Container left running for your browser screenshot:"
  echo "    http://localhost:${PORT}/"
} > "$LOG" 2>&1

# Full evidence lives in the log; only the verdict goes to stdout. This keeps
# the transcript small without weakening the artifact the grader reads.
grep -E '^\s*\[(PASS|FAIL)\]|^ RESULT:' "$LOG"
echo "Evidence ($(wc -l < "$LOG") lines) -> $LOG"
exit $FAILED
