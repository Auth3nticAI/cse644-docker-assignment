# CSE644 Requirement 7 - Nginx backend image sitting behind HAProxy.

FROM nginx:1.27-alpine

ARG BUILD_DATE="unknown"

LABEL org.opencontainers.image.title="cse644-proxy-nginx" \
      org.opencontainers.image.description="Nginx backend served through an HAProxy reverse proxy (CSE644)." \
      org.opencontainers.image.authors="Tray Branch" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      edu.cse644.requirement="7"

COPY default.conf /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/

RUN nginx -t

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
