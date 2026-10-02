#!/bin/sh
# serve (default): run the API. release: migrate the database, then exit. Run release as its own
# step before shifting traffic (a Cloud Run job, or a CD step); never from app startup, where
# several instances would race to migrate.
set -e

case "${1:-serve}" in
  release)
    exec alembic upgrade head
    ;;
  serve)
    # --proxy-headers: behind Cloud Run or a tunnel, take the client address from X-Forwarded-For.
    # Each worker keeps its own in-memory rate-limit buckets, so the chat limit is per worker.
    exec uvicorn therapylink_api.main:app \
      --host 0.0.0.0 --port "${PORT:-7860}" \
      --proxy-headers --forwarded-allow-ips "${FORWARDED_ALLOW_IPS:-*}" \
      --workers "${WEB_CONCURRENCY:-1}"
    ;;
  *)
    exec "$@"
    ;;
esac
