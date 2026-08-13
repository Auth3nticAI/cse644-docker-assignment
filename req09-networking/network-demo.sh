#!/usr/bin/env bash
# =============================================================================
# CSE644 Cloud Computing - Requirement 9
# Demonstrate Docker networking: bridge, host, and isolated networks.
#
# Covers every item the assignment asks for:
#   * bridge-network use
#   * communication between containers on the same bridge
#   * isolation between separate networks UNLESS explicitly connected
#   * host-network demonstration
#   * network inspection output
#
# Self-asserting: the isolation tests treat SUCCESSFUL cross-network
# communication as a FAILURE, because a demo that silently loses its isolation
# would otherwise look like it passed.
# =============================================================================
set -uo pipefail

NET_A="cse644-net-a"
NET_B="cse644-net-b"
WEB_A="cse644-web-a"
CLIENT_A="cse644-client-a"
CLIENT_B="cse644-client-b"
DEF1="cse644-defbridge-1"
DEF2="cse644-defbridge-2"
HOST_NGINX="cse644-host-nginx"
HOST_CLIENT="cse644-host-client"
BRIDGE_CLIENT="cse644-bridge-client"
NONE_C="cse644-none-demo"

ALPINE="alpine:3.20"
NGINX="nginx:1.27-alpine"
HOST_PORT=80

FAILED=0
check() {
  if [ "$2" -eq 0 ]; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; FAILED=1; fi
}

cleanup() {
  docker rm -f "$WEB_A" "$CLIENT_A" "$CLIENT_B" "$DEF1" "$DEF2" \
                "$HOST_NGINX" "$HOST_CLIENT" "$BRIDGE_CLIENT" \
                "$NONE_C" >/dev/null 2>&1 || true
  docker network rm "$NET_A" "$NET_B" >/dev/null 2>&1 || true
}

echo "==================================================================="
echo " CSE644 Docker Assignment - Req 9: Docker Networking"
echo " Captured: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "==================================================================="

cleanup

# =============================================================================
echo
echo "#####################################################################"
echo "# PART 1 - THE DEFAULT BRIDGE NETWORK                               #"
echo "#####################################################################"

echo
echo "--- [1.1] Docker's built-in networks --------------------------------"
docker network ls

echo
echo "--- [1.2] Two containers on the DEFAULT bridge ----------------------"
docker run -d --name "$DEF1" "$ALPINE" sleep 600 >/dev/null
docker run -d --name "$DEF2" "$ALPINE" sleep 600 >/dev/null
# Read the IP out of the .Networks map rather than the legacy top-level
# .NetworkSettings.IPAddress field, which comes back empty on this engine.
DEF1_IP="$(docker inspect -f '{{.NetworkSettings.Networks.bridge.IPAddress}}' "$DEF1")"
DEF2_IP="$(docker inspect -f '{{.NetworkSettings.Networks.bridge.IPAddress}}' "$DEF2")"
echo "$DEF1 -> $DEF1_IP"
echo "$DEF2 -> $DEF2_IP"

echo
echo "--- [1.3] Default bridge: reachable by IP ---------------------------"
docker exec "$DEF2" ping -c 2 -W 2 "$DEF1_IP"
docker exec "$DEF2" ping -c 2 -W 2 "$DEF1_IP" >/dev/null 2>&1
check "default bridge: containers reach each other by IP address" $?

echo
echo "--- [1.4] Default bridge: NOT resolvable by NAME --------------------"
echo "The default bridge has no embedded DNS server, so container names do"
echo "not resolve. This is the key limitation that user-defined bridges fix."
docker exec "$DEF2" nslookup "$DEF1" 2>&1 | head -8 || true
if docker exec "$DEF2" ping -c 1 -W 2 "$DEF1" >/dev/null 2>&1; then
  check "default bridge correctly lacks name resolution" 1
else
  echo "  (name lookup failed, as expected on the default bridge)"
  check "default bridge correctly lacks name resolution" 0
fi

docker rm -f "$DEF1" "$DEF2" >/dev/null 2>&1

# =============================================================================
echo
echo "#####################################################################"
echo "# PART 2 - USER-DEFINED BRIDGE NETWORK + CONTAINER COMMUNICATION    #"
echo "#####################################################################"

echo
echo "--- [2.1] CREATE a user-defined bridge network ----------------------"
docker network create --driver bridge --subnet 172.30.0.0/16 "$NET_A"
docker network ls --filter "name=$NET_A"

echo
echo "--- [2.2] Run a web server and a client on that network -------------"
docker run -d --name "$WEB_A" --network "$NET_A" "$NGINX" >/dev/null
docker run -d --name "$CLIENT_A" --network "$NET_A" "$ALPINE" sleep 600 >/dev/null
sleep 2
WEB_A_IP="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET_A\").IPAddress}}" "$WEB_A")"
CLIENT_A_IP="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET_A\").IPAddress}}" "$CLIENT_A")"
echo "$WEB_A    -> $WEB_A_IP"
echo "$CLIENT_A -> $CLIENT_A_IP"

echo
echo "--- [2.3] COMMUNICATION between containers on the same bridge -------"
echo "(a) DNS: resolve the container name via Docker's embedded DNS at 127.0.0.11"
docker exec "$CLIENT_A" nslookup "$WEB_A" 2>&1 | head -8
docker exec "$CLIENT_A" nslookup "$WEB_A" >/dev/null 2>&1
check "same bridge: container name resolves via embedded DNS" $?

echo
echo "(b) ICMP: ping by NAME"
docker exec "$CLIENT_A" ping -c 3 -W 2 "$WEB_A"
docker exec "$CLIENT_A" ping -c 2 -W 2 "$WEB_A" >/dev/null 2>&1
check "same bridge: ping by container name succeeds" $?

echo
echo "(c) HTTP: fetch the web server by NAME"
docker exec "$CLIENT_A" wget -q -T 5 -O - "http://$WEB_A/" | head -5
docker exec "$CLIENT_A" wget -q -T 5 -O - "http://$WEB_A/" >/dev/null 2>&1
check "same bridge: HTTP request to nginx by name succeeds" $?

# =============================================================================
echo
echo "#####################################################################"
echo "# PART 3 - ISOLATED NETWORK (separate bridge = no connectivity)     #"
echo "#####################################################################"

echo
echo "--- [3.1] CREATE a second, separate bridge network ------------------"
docker network create --driver bridge --subnet 172.31.0.0/16 "$NET_B"
docker run -d --name "$CLIENT_B" --network "$NET_B" "$ALPINE" sleep 600 >/dev/null
sleep 1
CLIENT_B_IP="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET_B\").IPAddress}}" "$CLIENT_B")"
echo "$CLIENT_B -> $CLIENT_B_IP  (on $NET_B)"
echo "$WEB_A    -> $WEB_A_IP  (on $NET_A)"
echo
echo "Different subnets, different bridges: 172.31.x.x vs 172.30.x.x"

echo
echo "--- [3.2] ISOLATION: name resolution must FAIL across networks ------"
docker exec "$CLIENT_B" nslookup "$WEB_A" 2>&1 | head -8 || true
if docker exec "$CLIENT_B" nslookup "$WEB_A" >/dev/null 2>&1; then
  echo "  Name resolved across networks - isolation is BROKEN"
  check "isolated network: cannot resolve container on other network" 1
else
  echo "  (lookup failed, as expected - $CLIENT_B cannot see $NET_A's DNS)"
  check "isolated network: cannot resolve container on other network" 0
fi

echo
echo "--- [3.3] ISOLATION: ping by IP must FAIL ---------------------------"
echo "Even with the raw IP, the bridges are separate L2 segments."
timeout 12 docker exec "$CLIENT_B" ping -c 2 -W 2 "$WEB_A_IP" 2>&1 || true
if timeout 12 docker exec "$CLIENT_B" ping -c 2 -W 2 "$WEB_A_IP" >/dev/null 2>&1; then
  echo "  Ping SUCCEEDED across isolated networks - isolation is BROKEN"
  check "isolated network: cannot reach other network by IP" 1
else
  echo "  (ping failed, as expected)"
  check "isolated network: cannot reach other network by IP" 0
fi

echo
echo "--- [3.4] ISOLATION: HTTP must FAIL ---------------------------------"
timeout 12 docker exec "$CLIENT_B" wget -q -T 4 -O - "http://$WEB_A_IP/" 2>&1 | head -3 || true
if timeout 12 docker exec "$CLIENT_B" wget -q -T 4 -O - "http://$WEB_A_IP/" >/dev/null 2>&1; then
  check "isolated network: HTTP to other network blocked" 1
else
  echo "  (HTTP request failed, as expected)"
  check "isolated network: HTTP to other network blocked" 0
fi

echo
echo "--- [3.5] EXPLICIT CONNECTION removes the isolation -----------------"
echo "The assignment says isolation holds 'unless explicitly connected'."
echo "Attaching $CLIENT_B to $NET_A as well:"
docker network connect "$NET_A" "$CLIENT_B"
sleep 2
echo
echo "$CLIENT_B is now attached to BOTH networks:"
docker inspect -f '{{range $net, $conf := .NetworkSettings.Networks}}  {{$net}} -> {{$conf.IPAddress}}
{{end}}' "$CLIENT_B"

echo "Now the same requests that just failed should succeed:"
docker exec "$CLIENT_B" ping -c 2 -W 2 "$WEB_A"
docker exec "$CLIENT_B" ping -c 2 -W 2 "$WEB_A" >/dev/null 2>&1
check "after explicit connect: ping by name now SUCCEEDS" $?

docker exec "$CLIENT_B" wget -q -T 5 -O - "http://$WEB_A/" | head -3
docker exec "$CLIENT_B" wget -q -T 5 -O - "http://$WEB_A/" >/dev/null 2>&1
check "after explicit connect: HTTP now SUCCEEDS" $?

echo
echo "Disconnecting again to restore isolation:"
docker network disconnect "$NET_A" "$CLIENT_B"
sleep 1
if timeout 12 docker exec "$CLIENT_B" ping -c 1 -W 2 "$WEB_A" >/dev/null 2>&1; then
  check "after disconnect: isolation is restored" 1
else
  echo "  (ping fails again - isolation restored)"
  check "after disconnect: isolation is restored" 0
fi

# =============================================================================
echo
echo "#####################################################################"
echo "# PART 4 - HOST NETWORK                                             #"
echo "#####################################################################"

echo
echo "--- [4.1] Host ports in use BEFORE starting the host-network container"
ss -tuln | grep -E "LISTEN.*:${HOST_PORT}\b" || echo "  (nothing listening on :${HOST_PORT} yet)"

echo
echo "--- [4.2] RUN nginx with --network host -----------------------------"
echo "Note: NO -p flag. With host networking the container shares the host's"
echo "network namespace directly, so port publishing is neither needed nor"
echo "possible."
docker run -d --name "$HOST_NGINX" --network host "$NGINX" >/dev/null
sleep 3
docker ps --filter "name=$HOST_NGINX" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "--- [4.3] The container has NO separate IP or port mapping ----------"
echo "NetworkMode : $(docker inspect -f '{{.HostConfig.NetworkMode}}' "$HOST_NGINX")"
echo "IPAddress   : '$(docker inspect -f '{{.NetworkSettings.IPAddress}}' "$HOST_NGINX")' (empty by design)"
echo "Port map    : '$(docker port "$HOST_NGINX" 2>&1)' (empty by design)"
[ "$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$HOST_NGINX")" = "host" ]
check "container is running in host network mode" $?
[ -z "$(docker inspect -f '{{.NetworkSettings.IPAddress}}' "$HOST_NGINX")" ]
check "host-network container has no private IP of its own" $?

echo
echo "--- [4.4] WHICH host? An important Docker Desktop detail -------------"
cat <<'NOTE'
  Docker Desktop does NOT run containers inside the WSL2 Ubuntu distro. It
  runs them in its own hidden Linux VM; the Ubuntu distro only holds a docker
  CLI that talks to that VM's daemon.

  So "--network host" shares the DOCKER DESKTOP VM's network namespace, not
  Ubuntu's. Running `ss` here in Ubuntu therefore will NOT show the container's
  port, and `curl localhost:80` from Ubuntu has nothing to connect to. That is
  expected behaviour, not a broken demo.

  The tests below prove host networking from inside the correct namespace, by
  demonstrating the property that DEFINES it: a host-network container shares
  the host's interfaces and loopback with every other host-network process.
NOTE

echo
echo "--- [4.5] Host-network container sees ALL of the host's interfaces ----"
echo "Interfaces inside the HOST-network container:"
docker exec "$HOST_NGINX" ip -o addr show 2>/dev/null | awk '{printf "   %-20s %s %s\n", $2, $3, $4}'
HOST_IF="$(docker exec "$HOST_NGINX" ip -o link show 2>/dev/null | wc -l)"

echo
echo "For contrast, a BRIDGE-network container in its own namespace:"
docker run -d --name "$BRIDGE_CLIENT" --network "$NET_A" "$ALPINE" sleep 300 >/dev/null
sleep 1
docker exec "$BRIDGE_CLIENT" ip -o addr show 2>/dev/null | awk '{printf "   %-20s %s %s\n", $2, $3, $4}'
BR_IF="$(docker exec "$BRIDGE_CLIENT" ip -o link show 2>/dev/null | wc -l)"

echo
echo "Interface count -> host-network container: $HOST_IF, bridge container: $BR_IF"
[ "$HOST_IF" -gt "$BR_IF" ]
check "host-network container sees more interfaces than an isolated one" $?

docker exec "$HOST_NGINX" ip -o addr show 2>/dev/null | grep -q 'docker0'
check "host-network container can see the host's docker0 bridge" $?

echo
echo "--- [4.6] The host's port table is visible from inside the container --"
echo "Listening sockets as seen from INSIDE the host-network container:"
docker exec "$HOST_NGINX" sh -c 'netstat -tuln 2>/dev/null || ss -tuln' | head -15
echo
echo "Note port 8080 above: that belongs to an UNRELATED container published"
echo "on the host. Seeing another process's port proves this container is"
echo "looking at the host's shared network namespace, not its own."
docker exec "$HOST_NGINX" sh -c 'netstat -tuln 2>/dev/null || ss -tuln' | grep -qE ":${HOST_PORT}\b"
check "nginx bound host port ${HOST_PORT} without any -p flag" $?

echo
echo "--- [4.7] DEFINITIVE PROOF: two host-network containers share loopback"
echo "Starting a SECOND --network host container and curling 127.0.0.1:${HOST_PORT}"
echo "from inside it. Under bridge networking each container has its own"
echo "private loopback, so this could never work."
docker run -d --name "$HOST_CLIENT" --network host "$ALPINE" sleep 300 >/dev/null
sleep 1
docker exec "$HOST_CLIENT" wget -q -T 5 -O - "http://127.0.0.1:${HOST_PORT}/" | head -5
docker exec "$HOST_CLIENT" wget -q -T 5 -O - "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1
check "container B reached container A over 127.0.0.1 (shared loopback)" $?

echo
echo "--- [4.8] CONTRAST: a bridge container CANNOT do that -----------------"
echo "Same request from the bridge-network container, which has its own loopback:"
timeout 12 docker exec "$BRIDGE_CLIENT" wget -q -T 4 -O - "http://127.0.0.1:${HOST_PORT}/" 2>&1 | head -3 || true
if timeout 12 docker exec "$BRIDGE_CLIENT" wget -q -T 4 -O - "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then
  check "bridge container correctly CANNOT reach host loopback" 1
else
  echo "  (connection refused - its 127.0.0.1 is a different, private loopback)"
  check "bridge container correctly CANNOT reach host loopback" 0
fi

docker rm -f "$HOST_NGINX" "$HOST_CLIENT" "$BRIDGE_CLIENT" >/dev/null 2>&1

# =============================================================================
echo
echo "#####################################################################"
echo "# PART 5 - 'none' NETWORK (complete network isolation)              #"
echo "#####################################################################"

echo
echo "--- [5.1] Container with --network none -----------------------------"
docker run -d --name "$NONE_C" --network none "$ALPINE" sleep 300 >/dev/null
echo "Interfaces inside a --network none container:"
docker exec "$NONE_C" ip -o addr show
NONE_IFACES="$(docker exec "$NONE_C" ip -o link show | wc -l)"
echo "Interface count: $NONE_IFACES (loopback only)"
[ "$NONE_IFACES" -eq 1 ]
check "'none' network container has only loopback" $?

if timeout 10 docker exec "$NONE_C" ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
  check "'none' network container has no outbound connectivity" 1
else
  echo "  (no route to the outside, as expected)"
  check "'none' network container has no outbound connectivity" 0
fi

docker rm -f "$NONE_C" >/dev/null 2>&1

# =============================================================================
echo
echo "#####################################################################"
echo "# PART 6 - NETWORK INSPECTION OUTPUT                                #"
echo "#####################################################################"

echo
echo "--- [6.1] All networks ------------------------------------------------"
docker network ls

echo
echo "--- [6.2] docker network inspect $NET_A -------------------------------"
docker network inspect "$NET_A"

echo
echo "--- [6.3] docker network inspect $NET_B -------------------------------"
docker network inspect "$NET_B"

echo
echo "--- [6.4] Subnets and gateways side by side ---------------------------"
for n in bridge host none "$NET_A" "$NET_B"; do
  printf '%-20s driver=%-8s subnet=%s\n' "$n" \
    "$(docker network inspect "$n" -f '{{.Driver}}' 2>/dev/null)" \
    "$(docker network inspect "$n" -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null)"
done

echo
echo "--- [6.5] Containers attached to each user-defined network ------------"
for n in "$NET_A" "$NET_B"; do
  echo "$n:"
  docker network inspect "$n" \
    -f '{{range .Containers}}  {{.Name}} -> {{.IPv4Address}}
{{end}}'
done

# =============================================================================
echo
echo "--- [7] CLEANUP (removes only this assignment's resources) ------------"
cleanup
echo "Removed cse644-* demo containers and networks."
echo "Unrelated containers, networks, and volumes on this machine were NOT touched."

echo
echo "==================================================================="
if [ $FAILED -eq 0 ]; then
  echo " RESULT: Req 9 VERIFIED - bridge, isolated, and host networking"
else
  echo " RESULT: Req 9 FAILED - see [FAIL] lines above"
fi
echo "==================================================================="
exit $FAILED
