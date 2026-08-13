#!/usr/bin/env bash
# Requirement 5: Build a customized nginx image that serves a custom web page,
# run it, and prove the custom page + custom server config are being served.
#
# Usage: bash scripts/req05-custom-nginx.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req05-custom-nginx.txt"
mkdir -p "$(dirname "$LOG")"

CTX="$REPO_ROOT/req05-custom-nginx"
IMAGE="auth3nticai/cse644-custom-nginx:v1"
CONTAINER="cse644-nginx"
PORT=8081   # 8080 is already taken by an unrelated Jenkins container

FAILED=0
check() {  # check <description> <condition-result>
  if [ "$2" -eq 0 ]; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; FAILED=1; fi
}

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Req 5: Customized Nginx Image"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Image: $IMAGE   Port: $PORT"
  echo "==================================================================="

  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

  echo
  echo "--- [1] The Dockerfile ---------------------------------------------"
  cat "$CTX/Dockerfile"

  echo
  echo "--- [2] The custom server config (default.conf) --------------------"
  cat "$CTX/default.conf"

  echo
  echo "--- [3] BUILD the image --------------------------------------------"
  docker build \
    --build-arg BUILD_DATE="$(date -u '+%Y-%m-%d %H:%M:%S UTC')" \
    --build-arg STUDENT="Tray Branch" \
    --build-arg IMAGE_TAG="$IMAGE" \
    --build-arg BASE_IMAGE="nginx:1.27-alpine" \
    -t "$IMAGE" \
    "$CTX"
  BUILD_RC=$?
  check "image built successfully" $BUILD_RC
  [ $BUILD_RC -ne 0 ] && { echo "Build failed; aborting."; exit 1; }

  echo
  echo "--- [3b] Image in local store --------------------------------------"
  docker images "$IMAGE" --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'

  echo
  echo "--- [4] RUN the container ------------------------------------------"
  docker run -d --name "$CONTAINER" -p "${PORT}:80" "$IMAGE"
  echo
  # Wait for the HEALTHCHECK to report healthy rather than sleeping blindly.
  echo -n "Waiting for container health"
  for _ in $(seq 1 30); do
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
  echo "--- [5] Response headers (proves custom default.conf is active) ----"
  curl -sS -D - -o /dev/null "http://localhost:${PORT}/"
  curl -sS -D - -o /dev/null "http://localhost:${PORT}/" 2>/dev/null \
    | grep -qi 'X-CSE644-Served-By'
  check "custom header X-CSE644-Served-By present" $?

  echo
  echo "--- [6] The custom page being served -------------------------------"
  curl -sS "http://localhost:${PORT}/"

  echo
  echo "--- [7] Content assertions ------------------------------------------"
  BODY="$(curl -sS "http://localhost:${PORT}/")"
  grep -q 'Customized Nginx Container' <<<"$BODY"; check "custom page title served" $?
  grep -q 'Tray Branch'                 <<<"$BODY"; check "student name baked in at build time" $?
  # NB: must be `! grep -q`, not `grep -qv`. `grep -v` inverts per-LINE matching,
  # so it exits 0 whenever *any* line lacks the pattern - almost always true, and
  # therefore a test that can never fail.
  ! grep -q '__[A-Z_]*__'               <<<"$BODY"; check "no unreplaced placeholders" $?
  grep -q 'Welcome to nginx'            <<<"$BODY" && \
    { echo "  [FAIL] stock nginx page still present"; FAILED=1; } || \
      echo "  [PASS] stock nginx welcome page replaced"

  echo
  echo "--- [8] /healthz endpoint (custom location block) -------------------"
  curl -sS -w 'HTTP %{http_code}\n' "http://localhost:${PORT}/healthz"
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/healthz")" = "200" ]
  check "/healthz returns 200" $?

  echo
  echo "--- [9] Custom 404 page ----------------------------------------------"
  curl -sS -o /dev/null -w 'GET /nope -> HTTP %{http_code}\n' "http://localhost:${PORT}/nope"

  echo
  echo "--- [10] Image labels (docker inspect) -------------------------------"
  docker inspect "$IMAGE" --format '{{range $k,$v := .Config.Labels}}{{$k}} = {{$v}}
{{end}}'

  echo
  echo "==================================================================="
  if [ $FAILED -eq 0 ]; then
    echo " RESULT: Req 5 VERIFIED - custom image builds and serves custom page"
  else
    echo " RESULT: Req 5 FAILED - see [FAIL] lines above"
  fi
  echo "==================================================================="
  echo
  echo "Container left running for your browser screenshot:"
  echo "    http://localhost:${PORT}/"
} 2>&1 | tee "$LOG"

echo
echo "Evidence written to: $LOG"
exit $FAILED
