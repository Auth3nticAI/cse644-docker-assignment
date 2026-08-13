#!/usr/bin/env bash
# Requirement 10: Upload the created/modified images to Docker Hub.
#
# SECURITY: this script never handles a credential. It relies on the login
# already performed with `docker login`, whose access token is held by the OS
# credential manager. Nothing secret is printed or written.
#
# Usage: bash scripts/req10-push-to-hub.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req10-dockerhub-push.txt"
mkdir -p "$(dirname "$LOG")"

HUB_USER="auth3nticai"

# repo-name:requirement-covered
IMAGES=(
  "cse644-custom-nginx:5   Customized Nginx image serving a custom web page"
  "cse644-python-web:6     Python/Flask web server on port 8888"
  "cse644-haproxy:7        HAProxy reverse proxy for the Nginx backends"
  "cse644-proxy-nginx:7    Nginx backend used by the HAProxy project"
)

FAILED=0
check() {
  if [ "$2" -eq 0 ]; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; FAILED=1; fi
}

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Req 10: Upload Images to Docker Hub"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Docker Hub user: $HUB_USER"
  echo "==================================================================="

  echo
  echo "--- [1] Images built locally by this assignment ----------------------"
  docker images --filter "reference=${HUB_USER}/cse644-*" \
    --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'

  echo
  echo "--- [2] Tag each image with :latest in addition to :v1 ---------------"
  for entry in "${IMAGES[@]}"; do
    NAME="${entry%%:*}"
    docker tag "${HUB_USER}/${NAME}:v1" "${HUB_USER}/${NAME}:latest"
    echo "  tagged ${HUB_USER}/${NAME}:latest"
  done

  echo
  echo "--- [3] PUSH each image to Docker Hub --------------------------------"
  for entry in "${IMAGES[@]}"; do
    NAME="${entry%%:*}"
    REST="${entry#*:}"
    REQ="${REST%% *}"
    DESC="$(echo "${REST#* }" | sed 's/^ *//')"

    echo
    echo "======================================================="
    echo " Pushing ${HUB_USER}/${NAME}  (Requirement ${REQ})"
    echo " ${DESC}"
    echo "======================================================="

    docker push "${HUB_USER}/${NAME}:v1"
    check "pushed ${HUB_USER}/${NAME}:v1" $?

    docker push "${HUB_USER}/${NAME}:latest"
    check "pushed ${HUB_USER}/${NAME}:latest" $?
  done

  echo
  echo "--- [4] Local record of the pushed digests ---------------------------"
  for entry in "${IMAGES[@]}"; do
    NAME="${entry%%:*}"
    echo "${HUB_USER}/${NAME}:"
    docker inspect "${HUB_USER}/${NAME}:v1" \
      --format '  RepoDigest: {{range .RepoDigests}}{{.}}{{end}}' 2>/dev/null
  done

  echo
  echo "--- [5] VERIFY from Docker Hub's public API (proves upload landed) ---"
  for entry in "${IMAGES[@]}"; do
    NAME="${entry%%:*}"
    echo
    echo "Repository: ${HUB_USER}/${NAME}"
    curl -s "https://hub.docker.com/v2/repositories/${HUB_USER}/${NAME}/" \
      | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print('  (no JSON response)'); raise SystemExit
if d.get('message'):
    print('  NOT FOUND:', d['message']); raise SystemExit
print(f\"  visibility  : {'PUBLIC' if not d.get('is_private') else 'PRIVATE'}\")
print(f\"  last pushed : {d.get('last_updated')}\")
print(f\"  pull count  : {d.get('pull_count')}\")
print(f\"  URL         : https://hub.docker.com/r/${HUB_USER}/${NAME}\")
"
    echo "  Tags on Hub:"
    curl -s "https://hub.docker.com/v2/repositories/${HUB_USER}/${NAME}/tags?page_size=25" \
      | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print('    (none)'); raise SystemExit
for t in d.get('results', []):
    size_mb = round((t.get('full_size') or 0) / 1048576, 1)
    print(f\"    - {t['name']:<8} {size_mb} MB   pushed {t.get('tag_last_pushed')}\")
"
    curl -s "https://hub.docker.com/v2/repositories/${HUB_USER}/${NAME}/" | grep -q '"name"'
    check "${NAME} is visible on Docker Hub" $?
  done

  echo
  echo "--- [6] End-to-end pull test (proves the images are usable) ----------"
  echo "Removing the local copy and pulling it back down from Docker Hub:"
  docker rmi "${HUB_USER}/cse644-python-web:latest" >/dev/null 2>&1 || true
  docker pull "${HUB_USER}/cse644-python-web:latest"
  check "image pulls back down from Docker Hub successfully" $?

  echo
  echo "--- [7] Docker Hub links for the submission --------------------------"
  echo "  Profile: https://hub.docker.com/u/${HUB_USER}"
  for entry in "${IMAGES[@]}"; do
    NAME="${entry%%:*}"
    echo "  https://hub.docker.com/r/${HUB_USER}/${NAME}"
  done

  echo
  echo "==================================================================="
  if [ $FAILED -eq 0 ]; then
    echo " RESULT: Req 10 VERIFIED - all images uploaded to Docker Hub"
  else
    echo " RESULT: Req 10 FAILED - see [FAIL] lines above"
  fi
  echo "==================================================================="
} > "$LOG" 2>&1

grep -E '^\s*\[(PASS|FAIL)\]|^ RESULT:' "$LOG"
echo "Evidence ($(wc -l < "$LOG") lines) -> $LOG"
exit $FAILED
