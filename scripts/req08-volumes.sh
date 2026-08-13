#!/usr/bin/env bash
# Wrapper: runs the Requirement 8 volume demo and captures its full output as
# evidence, printing only the verdict.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_ROOT/evidence/logs/req08-volumes.txt"
mkdir -p "$(dirname "$LOG")"

bash "$REPO_ROOT/req08-volumes/volume-demo.sh" > "$LOG" 2>&1
RC=$?

grep -E '^\s*\[(PASS|FAIL)\]|^ RESULT:' "$LOG"
echo "Evidence ($(wc -l < "$LOG") lines) -> $LOG"
exit $RC
