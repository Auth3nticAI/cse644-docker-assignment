# =============================================================================
# CSE644 Cloud Computing - Requirement 5
# Customize an existing web server image (nginx) to serve a custom web page.
#
# Build:
#   docker build -t auth3nticai/cse644-custom-nginx:v1 req05-custom-nginx
# Run:
#   docker run -d --name cse644-nginx -p 8081:80 auth3nticai/cse644-custom-nginx:v1
# =============================================================================

# Pinned to a specific minor version rather than :latest so the build is
# reproducible. -alpine keeps the final image ~50MB instead of ~190MB.
FROM nginx:1.27-alpine

# Build-time metadata. Passed with --build-arg; defaults keep a bare
# `docker build` working.
ARG BUILD_DATE="unknown"
ARG STUDENT="Tray Branch"
ARG IMAGE_TAG="auth3nticai/cse644-custom-nginx:v1"
ARG BASE_IMAGE="nginx:1.27-alpine"

# OCI standard labels - these show up in `docker inspect` and on Docker Hub.
LABEL org.opencontainers.image.title="cse644-custom-nginx" \
      org.opencontainers.image.description="Nginx image customized for CSE644 Cloud Computing, serving a hand-written page and a custom server config." \
      org.opencontainers.image.authors="Tray Branch" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="${BASE_IMAGE}" \
      edu.cse644.requirement="5"

# 1. Custom server config: adds /healthz and the X-CSE644-Served-By header.
COPY default.conf /etc/nginx/conf.d/default.conf

# 2. Custom web page, replacing nginx's stock index.html.
COPY site/ /usr/share/nginx/html/

# 3. Bake build metadata into the page. Done in a single RUN so it becomes one
#    layer, and placed AFTER the COPYs so edits to the HTML don't invalidate
#    the config layer above it.
RUN set -eux; \
    sed -i \
      -e "s|__BUILD_DATE__|${BUILD_DATE}|g" \
      -e "s|__STUDENT__|${STUDENT}|g" \
      -e "s|__IMAGE_TAG__|${IMAGE_TAG}|g" \
      -e "s|__BASE_IMAGE__|${BASE_IMAGE}|g" \
      /usr/share/nginx/html/index.html; \
    # Fail the build loudly if a placeholder was missed, rather than shipping
    # an image that serves "__STUDENT__" to the grader.
    ! grep -q '__[A-Z_]*__' /usr/share/nginx/html/index.html; \
    nginx -t

EXPOSE 80

# BusyBox wget ships in alpine, so no extra package install is needed.
HEALTHCHECK --interval=10s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1

# Inherited from the base image, restated for clarity:
CMD ["nginx", "-g", "daemon off;"]
