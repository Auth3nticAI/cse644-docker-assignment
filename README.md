# CSE644 Cloud Computing — Docker Assignment

**Student:** Tray Branch
**Course:** CSE644 Cloud Computing
**Docker Hub:** [`auth3nticai`](https://hub.docker.com/u/auth3nticai) · **GitHub:** [`Auth3nticAI`](https://github.com/Auth3nticAI)

Practical Docker work covering installation, Docker Hub publishing, custom images, a
containerized Python web server, an HAProxy → Nginx reverse-proxy stack, persistent
volumes, and Docker networking.

Every requirement is demonstrated by a **self-asserting script**. The scripts do not
merely print commands — they check their own results and exit non-zero on failure, so a
`RESULT: ... VERIFIED` line means the behavior was actually observed. Full terminal
output for each is committed under [`evidence/logs/`](evidence/logs/).

---

## Docker Hub images

| Image | Requirement | Link |
|---|---|---|
| `auth3nticai/cse644-custom-nginx` | 5 — customized Nginx | https://hub.docker.com/r/auth3nticai/cse644-custom-nginx |
| `auth3nticai/cse644-python-web` | 6 — Python web server on :8888 | https://hub.docker.com/r/auth3nticai/cse644-python-web |
| `auth3nticai/cse644-haproxy` | 7 — HAProxy reverse proxy | https://hub.docker.com/r/auth3nticai/cse644-haproxy |
| `auth3nticai/cse644-proxy-nginx` | 7 — Nginx backend behind HAProxy | https://hub.docker.com/r/auth3nticai/cse644-proxy-nginx |

All four are public and tagged `:v1` and `:latest`.

---

## Quick start

```bash
git clone https://github.com/Auth3nticAI/cse644-docker-assignment.git
cd cse644-docker-assignment

# Run any requirement's demonstration. Each writes full output to evidence/logs/
# and prints only a PASS/FAIL summary.
bash scripts/req01-verify-install.sh     # Docker installed and running
bash scripts/req04-pull-run-exec.sh      # pull, run, interactive exec
bash scripts/req05-custom-nginx.sh       # build + serve custom Nginx page
bash scripts/req06-python-web.sh         # build + run Flask on :8888
bash scripts/req07-haproxy-nginx.sh      # HAProxy proxying to Nginx
bash scripts/req08-volumes.sh            # persistent volume
bash scripts/req09-networking.sh         # bridge / isolated / host networking
```

Or pull the finished images without building anything:

```bash
docker run -d -p 8081:80   auth3nticai/cse644-custom-nginx:v1   # → http://localhost:8081
docker run -d -p 8888:8888 auth3nticai/cse644-python-web:v1     # → http://localhost:8888
```

### Ports used

| Port | Service | Note |
|---|---|---|
| 8081 | Customized Nginx | 8080 was occupied on the build machine |
| 8888 | Python/Flask server | mandated by the assignment |
| 8090 | HAProxy frontend | public entry point to the proxy stack |
| 8404 | HAProxy stats dashboard | read-only backend health view |

---

## Repository layout

```
.
├── README.md / SUBMISSION.md
├── req05-custom-nginx/          Dockerfile, default.conf, site/index.html
├── req06-python-web/            Dockerfile, app.py, requirements.txt
├── req07-haproxy-nginx/         docker-compose.yml, haproxy/, nginx/
├── req08-volumes/               volume-demo.sh
├── req09-networking/            network-demo.sh
├── scripts/                     one runner per requirement
└── evidence/logs/               captured terminal output for every requirement
```

Directories are named for the assignment requirement they satisfy.

---

## Requirements

### 1 — Install Docker
Docker Engine 29.4.0 (Docker Desktop 4.70.0) on Windows 11 with the WSL2 backend; all
commands run from Ubuntu 24.04. Verified with `docker version`, `docker info`, and a
`hello-world` container run.
→ [`evidence/logs/req01-docker-install.txt`](evidence/logs/req01-docker-install.txt)

### 2 & 3 — Docker Hub account and CLI credentials
Account `auth3nticai`. Authentication uses a **Personal Access Token** with Read & Write
scope, supplied to `docker login` interactively. The token is held by the OS credential
manager (`credsStore`), never written into this repository.
→ [`evidence/logs/req02-03-dockerhub-auth.txt`](evidence/logs/req02-03-dockerhub-auth.txt)

The evidence script prints registry hostnames and usernames only. It calls the credential
helper's `list` verb, which returns no secrets, and never calls `get`.

![docker login succeeded](evidence/screenshots/Login%20Succeeded.png)
*`docker login` authenticating to Docker Hub from the command line.*

### 4 — Pull, run, and exec
Pulls `ubuntu:24.04`, runs it, and opens an interactive shell inside it.

The container's command is `sleep 3600`. A container lives exactly as long as its PID 1;
a bare `docker run ubuntu` starts bash, bash finds no TTY, exits immediately, and there is
nothing left to exec into. The exec session is wrapped in `script(1)` so a real pseudo-TTY
is allocated — the log shows `/dev/pts/0`, proving the session was genuinely interactive.
→ [`evidence/logs/req04-pull-run-exec.txt`](evidence/logs/req04-pull-run-exec.txt)

![interactive exec session inside the container](evidence/screenshots/Interactive%20exec.png)
*`docker exec -it` — the prompt shows the container ID, not the host.*

### 5 — Customized Nginx image
[`req05-custom-nginx/`](req05-custom-nginx/) — `FROM nginx:1.27-alpine`, plus:

* a hand-written [`site/index.html`](req05-custom-nginx/site/index.html) replacing the stock welcome page,
* a replacement [`default.conf`](req05-custom-nginx/default.conf) adding `/healthz` and an `X-CSE644-Served-By` header,
* build metadata injected via `ARG` + `sed`,
* a `HEALTHCHECK`, and OCI labels.

The build **fails deliberately** if any `__PLACEHOLDER__` survives substitution, so the
image can never ship a page reading `__STUDENT__`.
→ [`evidence/logs/req05-custom-nginx.txt`](evidence/logs/req05-custom-nginx.txt)

![custom nginx page served on port 8081](evidence/screenshots/Custom%20Nginx%20page.png)
*The custom page served from the container at `http://localhost:8081/`.*

### 6 — Python web server on port 8888
[`req06-python-web/`](req06-python-web/) — Flask served by gunicorn on `0.0.0.0:8888`,
with `/` (HTML), `/api/info` (JSON), and `/healthz`.

Notable choices: dependencies are copied and installed *before* the source so editing
`app.py` reuses the cached pip layer; the container runs as an unprivileged `appuser`
rather than root; and the health probe uses the Python stdlib because `python:3.12-slim`
ships neither `curl` nor `wget`.

Port 8888 is proven in use three ways — `docker port`, `ss -tuln` on the host, and a
socket connect from inside the container.
→ [`evidence/logs/req06-python-web.txt`](evidence/logs/req06-python-web.txt)

![Flask web server responding on port 8888](evidence/screenshots/Python%20server%20on%208888.png)
*The Flask app at `http://localhost:8888/`, reporting live container facts.*

### 7 — HAProxy proxying to Nginx
[`req07-haproxy-nginx/`](req07-haproxy-nginx/) — HAProxy load-balancing across two Nginx
backends via [`docker-compose.yml`](req07-haproxy-nginx/docker-compose.yml).

**The backends publish no host ports.** They are reachable only through HAProxy, so a
successful response is itself proof the proxy hop happened. Demonstrated:

* round-robin balancing across `web1`/`web2`, visible via the `X-CSE644-Backend` header,
* active health checks (`http-check` against `/healthz`),
* **failover** — `/healthz` is broken on `web1`, HAProxy marks it `DOWN`, all traffic
  moves to `web2` with zero errors, then `web1` rejoins after recovery.

Two configuration details worth noting:

* `init-addr last,libc,none` on the server lines. HAProxy resolves backend hostnames at
  config-parse time; without this it aborts with *"Failed to initialize server(s) addr"*
  whenever DNS isn't available yet — during `docker build`, or when HAProxy starts before
  its backends.
* Recovery uses `compose up --force-recreate`, **not** `docker restart`. The failure was
  injected by editing a file inside the container's writable layer, and a restart reuses
  that same layer. Only recreating gives a fresh layer over the unmodified image.

→ [`evidence/logs/req07-haproxy-nginx.txt`](evidence/logs/req07-haproxy-nginx.txt)

![page served through the HAProxy proxy](evidence/screenshots/HAProxy-proxied%20page.png)
*`http://localhost:8090/` — served through HAProxy. The hostname shown is the
backend that answered; it alternates between `web1` and `web2` on reload.*

![HAProxy statistics dashboard](evidence/screenshots/HAProxy%20stats%20dashboard.png)
*The HAProxy stats dashboard at `http://localhost:8404/`, showing both backends
UP with per-server session counts from the active health checks.*

### 8 — Persistent volume
[`req08-volumes/volume-demo.sh`](req08-volumes/volume-demo.sh) — writes a unique
per-run marker into a named volume, **destroys the container**, starts a brand-new
container on the same volume, and asserts the exact marker comes back.

It also runs a **negative control**: a file written outside the volume (into the writable
layer) must *not* survive. Without that control, "the data is still there" proves nothing.
→ [`evidence/logs/req08-volumes.txt`](evidence/logs/req08-volumes.txt)

### 9 — Docker networking
[`req09-networking/network-demo.sh`](req09-networking/network-demo.sh) covers:

* **Default bridge** — reachable by IP, but no name resolution (no embedded DNS).
* **User-defined bridge** — name resolution via Docker's DNS at `127.0.0.11`; ping and
  HTTP between containers by container name.
* **Isolation** — a container on a second bridge cannot resolve, ping, or reach the first
  network even by raw IP. `docker network connect` then makes it work, and
  `docker network disconnect` restores isolation.
* **Host network** — see the note below.
* **`none` network** — loopback only, no outbound route.
* **Inspection** — `docker network ls`/`inspect`, subnets, and attached containers.

Isolation checks are written so that *successful* cross-network communication counts as a
FAILURE — otherwise a demo that silently lost its isolation would look like it passed.
→ [`evidence/logs/req09-networking.txt`](evidence/logs/req09-networking.txt)

> **Host networking under Docker Desktop.** Docker Desktop does not run containers inside
> the WSL2 Ubuntu distro; it runs them in its own Linux VM, and Ubuntu holds only a CLI
> that talks to that VM. So `--network host` shares the *Docker Desktop VM's* network
> namespace — `ss` in Ubuntu will not show the container's port, and `curl localhost:80`
> from Ubuntu has nothing to reach. That is correct behavior, not a broken demo.
>
> The demonstration therefore proves host networking from inside the right namespace:
> the container sees the host's full interface list including `docker0`, it binds port 80
> with no `-p` flag, and — the definitive test — a **second** `--network host` container
> reaches the first over `127.0.0.1`. A bridge-network container attempting the same
> request fails, because its loopback is its own.

### 10 — Upload images to Docker Hub
All four images pushed as `:v1` and `:latest`, verified against Docker Hub's public API,
then re-pulled to confirm they are usable.
→ [`evidence/logs/req10-dockerhub-push.txt`](evidence/logs/req10-dockerhub-push.txt)

### 11 & 12 — GitHub
This repository. Contains all source, Dockerfiles, the custom web page, scripts, and
evidence logs. No credentials of any kind.

---

## Environment notes

Built on Windows 11 with Docker Desktop (WSL2 backend), with all commands run from an
Ubuntu 24.04 WSL distro. Two consequences shaped the code:

* **Host networking** behaves as described above.
* **A space in the repository path** (`D:\CSE644 Cloud Computing\...`) broke an early
  version of the Compose runner. Storing a command in a string variable and expanding it
  unquoted word-splits the path; the fix is a shell *function*, which preserves argument
  boundaries. See the comment in
  [`scripts/req07-haproxy-nginx.sh`](scripts/req07-haproxy-nginx.sh).

A [`.gitattributes`](.gitattributes) enforces LF line endings. CRLF in `haproxy.cfg` or a
shell script breaks inside a Linux container (`bad interpreter: /bin/sh^M`).

The build machine hosts unrelated containers, so **every resource this assignment creates
is prefixed `cse644-`** and teardown targets only that prefix. No `docker system prune` is
used anywhere — it would destroy unrelated volumes and containers.

---

## Security

No password, access token, API key, or credential file appears anywhere in this
repository. The Docker Hub PAT was entered at an interactive `docker login` prompt (never
as `-p` on the command line, which would record it in shell history) and is stored by the
OS credential manager.

[`.gitignore`](.gitignore) blocks `.env`, `*.pem`, `*.key`, `.docker/`, and similar.
[`scripts/secret-scan.sh`](scripts/secret-scan.sh) scans the tree for credential-shaped
strings and was run before publishing.

---

## Cleanup

```bash
docker compose -f req07-haproxy-nginx/docker-compose.yml -p cse644-proxy down
docker rm -f $(docker ps -aq --filter "name=cse644-") 2>/dev/null
docker volume rm cse644-data
docker network rm cse644-net-a cse644-net-b 2>/dev/null
```

Do **not** run `docker system prune` — it would remove unrelated containers and volumes.
