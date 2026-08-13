# CSE644 Cloud Computing — Docker Assignment · Submission

## Required submission items

| Item | Value |
|---|---|
| **Name** | Tray Branch |
| **Docker Hub username** | `auth3nticai` |
| **GitHub username** | `Auth3nticAI` |
| **Docker Hub profile** | https://hub.docker.com/u/auth3nticai |
| **Customized Nginx image** | https://hub.docker.com/r/auth3nticai/cse644-custom-nginx |
| **Python web server image** | https://hub.docker.com/r/auth3nticai/cse644-python-web |
| **HAProxy + Nginx proxy project** | Images: https://hub.docker.com/r/auth3nticai/cse644-haproxy · https://hub.docker.com/r/auth3nticai/cse644-proxy-nginx<br>Source: https://github.com/Auth3nticAI/cse644-docker-assignment/tree/main/req07-haproxy-nginx |
| **GitHub repository** | https://github.com/Auth3nticAI/cse644-docker-assignment |

---

## Required evidence checklist

| # | Evidence | Where |
|---|---|---|
| 1 | Docker installation | [`req01-docker-install.txt`](evidence/logs/req01-docker-install.txt) |
| 2 | Docker Hub account + CLI authentication | [`req02-03-dockerhub-auth.txt`](evidence/logs/req02-03-dockerhub-auth.txt) |
| 3 | Docker image pull | [`req04-pull-run-exec.txt`](evidence/logs/req04-pull-run-exec.txt) §1 |
| 4 | Container run | [`req04-pull-run-exec.txt`](evidence/logs/req04-pull-run-exec.txt) §2 |
| 5 | Interactive exec session | [`req04-pull-run-exec.txt`](evidence/logs/req04-pull-run-exec.txt) §3 — TTY `/dev/pts/0` |
| 6 | Customized Nginx image | [`req05-custom-nginx.txt`](evidence/logs/req05-custom-nginx.txt) |
| 7 | Python web server image (port 8888) | [`req06-python-web.txt`](evidence/logs/req06-python-web.txt) |
| 8 | HAProxy proxying traffic to Nginx | [`req07-haproxy-nginx.txt`](evidence/logs/req07-haproxy-nginx.txt) |
| 9 | Persistent volume behavior | [`req08-volumes.txt`](evidence/logs/req08-volumes.txt) |
| 10 | Bridge network connectivity | [`req09-networking.txt`](evidence/logs/req09-networking.txt) Part 2 |
| 11 | Host network demonstration | [`req09-networking.txt`](evidence/logs/req09-networking.txt) Part 4 |
| 12 | Isolated network behavior | [`req09-networking.txt`](evidence/logs/req09-networking.txt) Part 3 |
| 13 | Docker Hub image upload | [`req10-dockerhub-push.txt`](evidence/logs/req10-dockerhub-push.txt) |
| 14 | GitHub repository upload | https://github.com/Auth3nticAI/cse644-docker-assignment |

Every log ends with a `RESULT: ... VERIFIED` line produced by an assertion, not by a
human transcribing commands. Each script exits non-zero if any check fails.

---

## Requirement-to-artifact map

| Req | Artifact |
|---|---|
| 1 Install Docker | Engine 29.4.0 / Docker Desktop 4.70.0, WSL2 Ubuntu 24.04 |
| 2 Docker Hub account | `auth3nticai` |
| 3 CLI credentials | PAT (Read & Write) via `docker login`, stored in OS credential manager |
| 4 Pull / run / exec | [`scripts/req04-pull-run-exec.sh`](scripts/req04-pull-run-exec.sh) |
| 5 Customized web server image | [`req05-custom-nginx/`](req05-custom-nginx/) |
| 6 Python web server on 8888 | [`req06-python-web/`](req06-python-web/) |
| 7 HAProxy → Nginx | [`req07-haproxy-nginx/`](req07-haproxy-nginx/) |
| 8 Persistent volume | [`req08-volumes/volume-demo.sh`](req08-volumes/volume-demo.sh) |
| 9 Networking | [`req09-networking/network-demo.sh`](req09-networking/network-demo.sh) |
| 10 Upload to Docker Hub | 4 images, `:v1` + `:latest`, all public |
| 11 GitHub account | `Auth3nticAI` |
| 12 Upload to GitHub | This repository |
| 13 Submit links | This file |

---

## Security statement

No password, Docker Hub access token, API key, private key, or environment file
containing secrets appears in this repository or in any committed log.

The Docker Hub Personal Access Token was entered at an interactive `docker login`
prompt — never passed as `-p` on the command line, which would have recorded it in shell
history. It is held by the OS credential manager, so it was never written to
`~/.docker/config.json` in the first place.

The authentication evidence log deliberately prints registry hostnames and usernames
only: it calls the credential helper's `list` verb, which returns no secrets, and never
calls `get`. [`scripts/secret-scan.sh`](scripts/secret-scan.sh) scans the tree for
token-, key-, and password-shaped strings and reported **CLEAN** before publishing.
