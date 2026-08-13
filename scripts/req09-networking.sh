#!/usr/bin/env bash
# Wrapper: runs the Requirement 9 networking demo, captures full output as
# evidence, prints only the verdict.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req09-networking.txt"
mkdir -p "$(dirname "$LOG")"

bash "$REPO_ROOT/req09-networking/network-demo.sh" > "$LOG" 2>&1
RC=$?

grep -E '^\s*\[(PASS|FAIL)\]|^ RESULT:' "$LOG"
echo "Evidence ($(wc -l < "$LOG") lines) -> $LOG"
exit $RC
