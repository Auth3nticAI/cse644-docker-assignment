#!/usr/bin/env bash
# =============================================================================
# CSE644 Cloud Computing - Requirement 8
# Demonstrate Docker persistent storage with a named volume, and PROVE that
# data survives container removal and recreation.
#
# The demo is self-asserting: it writes a unique marker, destroys the
# container, and greps for that exact marker from a brand-new container. If the
# marker is missing the script exits non-zero, so a passing run is a real test
# rather than a transcript of commands.
#
# It also runs the NEGATIVE control: a file written outside the volume (into
# the container's writable layer) must NOT survive. Without that control,
# "the data is still there" proves nothing - it could just be the same disk.
# =============================================================================
set -uo pipefail

VOLUME="cse644-data"
C1="cse644-vol-writer"
C2="cse644-vol-reader"
IMAGE="alpine:3.20"

# Unique per-run marker: if this exact string comes back, it can only have come
# from the volume written earlier in THIS run.
MARKER="CSE644-PERSISTED-$(date -u '+%Y%m%dT%H%M%S')-$$"

FAILED=0
check() {
  if [ "$2" -eq 0 ]; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; FAILED=1; fi
}

echo "==================================================================="
echo " CSE644 Docker Assignment - Req 8: Persistent Volume"
echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo " Volume: $VOLUME   Marker: $MARKER"
echo "==================================================================="

# --- clean slate (only OUR resources) ---------------------------------------
docker rm -f "$C1" "$C2" >/dev/null 2>&1 || true
docker volume rm "$VOLUME" >/dev/null 2>&1 || true

echo
echo "--- [1] CREATE a named volume ---------------------------------------"
docker volume create "$VOLUME"
docker volume ls --filter "name=$VOLUME"

echo
echo "--- [2] INSPECT the volume (note the Mountpoint on the host) --------"
docker volume inspect "$VOLUME"

echo
echo "--- [3] RUN container #1 with the volume mounted at /data -----------"
docker run -d --name "$C1" -v "$VOLUME:/data" "$IMAGE" sleep 600
docker ps --filter "name=$C1" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Mounts}}'

echo
echo "--- [4] WRITE DATA to the mounted volume ----------------------------"
docker exec "$C1" sh -c "
  mkdir -p /data
  echo '$MARKER' > /data/persistent.txt
  echo 'written by container: '\$(hostname) >> /data/persistent.txt
  echo 'written at: '\$(date -u) >> /data/persistent.txt
  for i in 1 2 3; do echo \"record \$i\" >> /data/records.log; done
"
echo "Contents of /data inside container #1:"
docker exec "$C1" ls -la /data
echo
echo "Contents of /data/persistent.txt:"
docker exec "$C1" cat /data/persistent.txt

echo
echo "--- [5] NEGATIVE CONTROL: also write OUTSIDE the volume -------------"
echo "Writing /ephemeral.txt into the container's writable layer (NOT the volume)."
echo "This file must NOT survive container removal - that contrast is what"
echo "proves the volume is doing the work."
docker exec "$C1" sh -c "echo '$MARKER-EPHEMERAL' > /ephemeral.txt"
docker exec "$C1" cat /ephemeral.txt

echo
echo "--- [6] Confirm the data is readable before we destroy anything -----"
docker exec "$C1" cat /data/persistent.txt | grep -q "$MARKER"
check "marker is present in the volume before container removal" $?

echo
echo "--- [7] DESTROY the container completely ----------------------------"
echo "docker rm -f $C1"
docker rm -f "$C1"
echo
echo "Container list (the writer container should be GONE):"
docker ps -a --filter "name=$C1" --format 'table {{.Names}}\t{{.Status}}'
[ -z "$(docker ps -aq --filter "name=$C1")" ]
check "container #1 no longer exists" $?

echo
echo "The volume, however, still exists independently of any container:"
docker volume ls --filter "name=$VOLUME"
docker volume inspect "$VOLUME" --format 'Volume {{.Name}} still present, mountpoint {{.Mountpoint}}'
[ -n "$(docker volume ls -q --filter "name=$VOLUME")" ]
check "volume survived container removal" $?

echo
echo "--- [8] RECREATE: a BRAND-NEW container mounting the same volume ----"
echo "Different container name, fresh writable layer, same volume."
docker run -d --name "$C2" -v "$VOLUME:/data" "$IMAGE" sleep 600
docker ps --filter "name=$C2" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Mounts}}'

echo
echo "--- [9] THE PROOF: read the data back from the new container --------"
echo "Contents of /data in container #2:"
docker exec "$C2" ls -la /data
echo
echo "Contents of /data/persistent.txt:"
docker exec "$C2" cat /data/persistent.txt
echo
echo "Contents of /data/records.log:"
docker exec "$C2" cat /data/records.log

echo
RECOVERED="$(docker exec "$C2" cat /data/persistent.txt 2>/dev/null | head -1)"
echo "Expected marker : $MARKER"
echo "Recovered marker: $RECOVERED"
[ "$RECOVERED" = "$MARKER" ]
check "EXACT marker recovered from a different container -> data persisted" $?

docker exec "$C2" test -f /data/records.log
check "secondary file records.log also survived" $?

# The redirection must be INSIDE the container. Writing
#   docker exec "$C2" wc -l < /data/records.log
# would make the HOST shell open /data/records.log (which does not exist here)
# and feed it to docker exec's stdin, never reading the container's copy.
[ "$(docker exec "$C2" sh -c 'wc -l < /data/records.log' 2>/dev/null | tr -d ' ')" = "3" ]
check "records.log still has all 3 records (no truncation)" $?

echo
echo "--- [10] NEGATIVE CONTROL RESULT ------------------------------------"
echo "Does the non-volume file /ephemeral.txt exist in the new container?"
if docker exec "$C2" test -f /ephemeral.txt 2>/dev/null; then
  echo "  /ephemeral.txt FOUND - volume demo is invalid!"
  check "writable-layer file correctly did NOT survive" 1
else
  echo "  /ephemeral.txt is ABSENT, as expected."
  echo "  The writable layer died with container #1; only the volume persisted."
  check "writable-layer file correctly did NOT survive" 0
fi

echo
echo "--- [11] Which containers currently use this volume? ----------------"
docker ps -a --filter "volume=$VOLUME" --format 'table {{.Names}}\t{{.Status}}'

echo
echo "--- [12] CLEANUP (removes only this assignment's resources) ---------"
docker rm -f "$C2" >/dev/null 2>&1
echo "Removed container $C2. Volume $VOLUME is intentionally LEFT IN PLACE"
echo "as submission evidence. Remove it manually with:"
echo "    docker volume rm $VOLUME"

echo
echo "==================================================================="
if [ $FAILED -eq 0 ]; then
  echo " RESULT: Req 8 VERIFIED - data survived container removal/recreation"
else
  echo " RESULT: Req 8 FAILED - see [FAIL] lines above"
fi
echo "==================================================================="
exit $FAILED
