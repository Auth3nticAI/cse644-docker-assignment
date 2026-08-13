# =============================================================================
# CSE644 Cloud Computing - Requirement 6
# Simple Python (Flask) web server, containerized, listening on port 8888.
#
# Build:
#   docker build -t auth3nticai/cse644-python-web:v1 req06-python-web
# Run:
#   docker run -d --name cse644-python-web -p 8888:8888 \
#       auth3nticai/cse644-python-web:v1
# =============================================================================

FROM python:3.12-slim

ARG BUILD_DATE="unknown"
ARG STUDENT="Tray Branch"

LABEL org.opencontainers.image.title="cse644-python-web" \
      org.opencontainers.image.description="Flask web server on port 8888 for CSE644 Cloud Computing." \
      org.opencontainers.image.authors="Tray Branch" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="python:3.12-slim" \
      edu.cse644.requirement="6"

# PYTHONDONTWRITEBYTECODE: no .pyc files baked into layers.
# PYTHONUNBUFFERED:        logs reach `docker logs` immediately instead of
#                          sitting in a buffer, which matters for evidence.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8888 \
    STUDENT="${STUDENT}"

WORKDIR /app

# Dependencies are copied and installed BEFORE the source. Docker caches layers
# by instruction, so editing app.py reuses the cached pip layer instead of
# re-downloading Flask on every build.
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

COPY app.py ./

# Run as an unprivileged user. By default containers run as root, so a process
# escape would land the attacker as root on the host namespace.
RUN useradd --create-home --shell /usr/sbin/nologin appuser \
 && chown -R appuser:appuser /app
USER appuser

# Documents the mandated port. EXPOSE is metadata only - the actual publish
# happens with `-p 8888:8888` at run time.
EXPOSE 8888

# python:3.12-slim ships neither curl nor wget, so the health probe uses the
# stdlib rather than installing an extra package into the image.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; \
sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8888/healthz', timeout=2).status==200 else 1)"

# gunicorn rather than Flask's development server: the dev server is
# single-threaded and prints a 'do not use in production' warning.
# --access-logfile - sends access logs to stdout so `docker logs` shows traffic.
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8888", \
     "--workers", "2", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
