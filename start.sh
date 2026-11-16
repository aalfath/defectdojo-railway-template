#!/bin/bash
# Railway wrapper for the official DefectDojo image.
set -euo pipefail
cd /app

PORT="${PORT:-8080}"
APP_UID=1001
APP_GID=1337

# Uploads (scan files, evidence, threat models) live on the Railway volume at /app/media.
mkdir -p "${DD_MEDIA_ROOT:-/app/media}/threat"
chown -R "${APP_UID}:${APP_GID}" "${DD_MEDIA_ROOT:-/app/media}"

# Public URL, allowed hosts and HTTPS settings, derived from Railway's domain unless set.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export DD_SITE_URL="${DD_SITE_URL:-https://${RAILWAY_PUBLIC_DOMAIN}}"
  export DD_SECURE_PROXY_SSL_HEADER="${DD_SECURE_PROXY_SSL_HEADER:-True}"
  export DD_SESSION_COOKIE_SECURE="${DD_SESSION_COOKIE_SECURE:-True}"
  export DD_CSRF_COOKIE_SECURE="${DD_CSRF_COOKIE_SECURE:-True}"
fi
if [ -n "${DD_SITE_URL:-}" ]; then
  SITE_HOST="$(printf '%s' "${DD_SITE_URL}" | sed -E 's#^[a-zA-Z]+://##; s#[:/].*$##')"
  SITE_ORIGIN="$(printf '%s' "${DD_SITE_URL}" | sed -E 's#^([a-zA-Z]+://[^/]+).*$#\1#')"
  export DD_CSRF_TRUSTED_ORIGINS="${DD_CSRF_TRUSTED_ORIGINS:-${SITE_ORIGIN}}"
fi
if [ -z "${DD_ALLOWED_HOSTS:-}" ]; then
  HOSTS="localhost,127.0.0.1,healthcheck.railway.app"
  [ -n "${SITE_HOST:-}" ] && HOSTS="${SITE_HOST},${HOSTS}"
  [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] && [ "${RAILWAY_PUBLIC_DOMAIN}" != "${SITE_HOST:-}" ] && HOSTS="${RAILWAY_PUBLIC_DOMAIN},${HOSTS}"
  export DD_ALLOWED_HOSTS="${HOSTS}"
fi

# Railway's Postgres URL works as is; a bare Redis URL gets separate databases for the broker and the cache.
if [ -n "${REDIS_URL:-}" ]; then
  export DD_CELERY_BROKER_URL="${DD_CELERY_BROKER_URL:-${REDIS_URL%/}/0}"
  export DD_CACHE_URL="${DD_CACHE_URL:-${REDIS_URL%/}/1}"
fi

for v in DD_DATABASE_URL DD_CELERY_BROKER_URL DD_SECRET_KEY DD_CREDENTIAL_AES_256_KEY DD_ADMIN_PASSWORD; do
  if [ -z "${!v:-}" ]; then echo "ERROR: ${v} is not set" >&2; exit 1; fi
done

as_app() { setpriv --reuid="${APP_UID}" --regid="${APP_GID}" --init-groups -- "$@"; }

echo "==> Waiting for the database"
for i in $(seq 1 60); do
  if as_app python3 manage.py shell --no-imports -c "from django.db import connection; connection.ensure_connection()" >/dev/null 2>&1; then break; fi
  [ "$i" = 60 ] && { echo "ERROR: database not reachable" >&2; exit 1; }
  sleep 2
done

echo "==> Initializing DefectDojo (migrations, fixtures, admin user)"
as_app python3 manage.py complete_initialization

echo "==> Starting Celery worker, Celery beat and uWSGI on port ${PORT}"
umask 0002
as_app celery --app=dojo worker --loglevel="${DD_CELERY_LOG_LEVEL:-INFO}" \
  --pool="${DD_CELERY_WORKER_POOL_TYPE:-solo}" --concurrency="${DD_CELERY_WORKER_CONCURRENCY:-1}" &
WORKER=$!
as_app celery --app=dojo beat --loglevel="${DD_CELERY_LOG_LEVEL:-INFO}" \
  --pidfile=/var/run/defectdojo/celery-beat.pid --schedule=/var/run/defectdojo/celerybeat-schedule &
BEAT=$!
as_app uwsgi \
  --master --die-on-term \
  --http "0.0.0.0:${PORT}" --http-timeout 1800 \
  --enable-threads \
  --processes "${DD_UWSGI_NUM_OF_PROCESSES}" --threads "${DD_UWSGI_NUM_OF_THREADS}" \
  --wsgi dojo.wsgi:application \
  --buffer-size "${DD_UWSGI_BUFFER_SIZE:-8192}" \
  --static-map /static=/app/static --offload-threads 2 \
  --disable-logging --log-4xx --log-5xx &
WEB=$!

shutdown() { kill -TERM "${WEB}" "${WORKER}" "${BEAT}" 2>/dev/null || true; wait || true; }
trap 'shutdown; exit 0' TERM INT

# If any process exits, stop the others so Railway restarts the whole service.
set +e
wait -n "${WEB}" "${WORKER}" "${BEAT}"
CODE=$?
echo "A DefectDojo process exited (code ${CODE}); stopping the service" >&2
shutdown
[ "${CODE}" = 0 ] && CODE=1
exit "${CODE}"
