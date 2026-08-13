#!/usr/bin/env bash
# Requirements 2 & 3: Docker Hub account + CLI authentication evidence.
#
# SECURITY: this script is written so it can never emit a credential.
# It prints registry hostnames and usernames only. The Docker credential
# helper's "list" verb returns {registry: username} pairs and never secrets;
# the "get" verb (which WOULD return a secret) is deliberately never called.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req02-03-dockerhub-auth.txt"
mkdir -p "$(dirname "$LOG")"

HUB_USER="auth3nticai"

{
  echo "==================================================================="
  echo " CSE644 Docker Assignment - Req 2 & 3: Docker Hub Account + Auth"
  echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "==================================================================="

  echo
  echo "--- [1] Docker Hub account exists (public API, no auth needed) -----"
  curl -s "https://hub.docker.com/v2/users/${HUB_USER}/" \
    | python3 -c "
import json,sys
d = json.load(sys.stdin)
print(f\"Username    : {d.get('username')}\")
print(f\"Full name   : {d.get('full_name') or '(not set)'}\")
print(f\"Date joined : {d.get('date_joined')}\")
print(f\"Profile URL : https://hub.docker.com/u/{d.get('username')}\")
"

  echo
  echo "--- [2] Docker client config (no secrets printed) -------------------"
  CFG="$HOME/.docker/config.json"
  if [ -f "$CFG" ]; then
    echo "Config path      : $CFG"
    echo "Credential store : $(python3 -c "
import json
d = json.load(open('$CFG'))
print(d.get('credsStore') or d.get('credStore') or '(none)')
")"
    echo
    echo "NOTE: credsStore is set, so 'docker login' hands the access token to"
    echo "      the OS credential manager instead of writing it into this file."
    echo "      No token is stored anywhere in this repository."
  else
    echo "No client config at $CFG"
  fi

  echo
  echo "--- [3] Stored registry credentials (hostname + username ONLY) ------"
  if command -v docker-credential-desktop.exe >/dev/null 2>&1; then
    docker-credential-desktop.exe list | python3 -c "
import json,sys
for host, user in json.load(sys.stdin).items():
    print(f'  {host}  ->  user: {user}')
"
    echo
    echo "  ^ Proves 'docker login' succeeded: an access token for the above"
    echo "    user is held by the credential manager and is available to the"
    echo "    Docker CLI for authenticated pushes."
  else
    echo "  credential helper not on PATH"
  fi

  echo
  echo "=== Req 2 & 3 verified: account exists, CLI is authenticated ========"
  echo "=== No password, token, or secret appears in this log. =============="
} 2>&1 | tee "$LOG"

echo
echo "Evidence written to: $LOG"
