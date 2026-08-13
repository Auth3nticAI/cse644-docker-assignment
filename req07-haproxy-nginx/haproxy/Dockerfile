# CSE644 Requirement 7 - HAProxy image with the proxy config baked in.
# Building a real image (rather than bind-mounting the config) is what makes
# this pushable to Docker Hub for Requirement 10.

FROM haproxy:3.0-alpine

ARG BUILD_DATE="unknown"

LABEL org.opencontainers.image.title="cse644-haproxy" \
      org.opencontainers.image.description="HAProxy configured as a load-balancing reverse proxy in front of two Nginx backends (CSE644)." \
      org.opencontainers.image.authors="Tray Branch" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="haproxy:3.0-alpine" \
      edu.cse644.requirement="7"

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Validate the config at BUILD time. A syntax error becomes a failed build
# instead of a container that crash-loops at 3am.
# -c = check and exit. Run as root here; the process drops to the haproxy
# user at runtime via the `user`/`group` directives in the config.
USER root
RUN haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

EXPOSE 80 8404

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD sh -c 'wget -qO- http://127.0.0.1:8404/ >/dev/null 2>&1 || exit 1'
