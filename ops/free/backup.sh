#!/usr/bin/env bash
# Nightly encrypted Postgres backup (setup.sh installs the cron entry).
#
#   sudo ops/free/backup.sh
#
# 1. pg_dump (custom format) of the database: the local postgres container, or TL_DATABASE_URL
#    (Neon) through a throwaway postgres client container.
# 2. Encrypted with age to BACKUP_AGE_RECIPIENT before it touches disk. The private key is never
#    on the VM, so a stolen VM or bucket gives no plaintext. Refuses to run without a recipient.
# 3. Kept in BACKUP_DIR (last BACKUP_KEEP_LOCAL files) and, if BACKUP_REMOTE_PATH is set, copied
#    with rclone to free object storage (OCI Object Storage 20 GB / Cloudflare R2 10 GB) and
#    pruned there after BACKUP_KEEP_REMOTE_DAYS.
# 4. Pings HC_BACKUP_PING_URL (healthchecks.io), so a backup that stops running gets noticed.
#
# Restore (on any machine with the age private key):
#   age -d -i tl-backup.key tl-YYYYmmddTHHMMZ.dump.age > tl.dump
#   docker compose exec -T postgres pg_restore -U therapylink -d therapylink --clean --if-exists < tl.dump
set -euo pipefail

fail() {
  echo "backup: $*" >&2
  [ -n "${HC_BACKUP_PING_URL:-}" ] && curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "$*" "$HC_BACKUP_PING_URL/fail" || true
  exit 1
}
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$here/.env" ] || fail "ops/free/.env not found"
set -a; . "$here/.env"; set +a
dc() { docker compose --project-directory "$here" -f "$here/docker-compose.yml" "$@"; }

[[ "${BACKUP_AGE_RECIPIENT:-}" == age1* ]] || fail "BACKUP_AGE_RECIPIENT (an age1... public key) is not set; refusing to write an unencrypted dump"
command -v age >/dev/null || fail "age is not installed (apt-get install age)"

dir="${BACKUP_DIR:-/var/backups/therapylink}"
mkdir -p "$dir"
chmod 0700 "$dir"
out="$dir/tl-$(date -u +%Y%m%dT%H%MZ).dump.age"
[ -n "${HC_BACKUP_PING_URL:-}" ] && curl -fsS -m 10 -o /dev/null "$HC_BACKUP_PING_URL/start" || true

umask 077
if [ -z "${TL_DATABASE_URL:-}" ]; then
  dc exec -T postgres pg_dump -U therapylink -d therapylink -Fc --no-owner \
    | age -r "$BACKUP_AGE_RECIPIENT" -o "$out.part" || fail "pg_dump of the local database failed"
else
  # postgresql+asyncpg://...?ssl=require  ->  postgresql://...?sslmode=require
  url="${TL_DATABASE_URL/postgresql+asyncpg:/postgresql:}"
  url="${url/ssl=require/sslmode=require}"
  img="$(dc config --images 2>/dev/null | grep '^postgres:' | head -1)"
  docker run --rm -e PGURL="$url" "${img:-postgres:17-alpine}" sh -c 'pg_dump "$PGURL" -Fc --no-owner' \
    | age -r "$BACKUP_AGE_RECIPIENT" -o "$out.part" || fail "pg_dump of TL_DATABASE_URL failed"
fi
[ -s "$out.part" ] || fail "empty dump"
mv "$out.part" "$out"
echo "wrote $out ($(du -h "$out" | cut -f1))"

# Keep the newest N locally.
ls -1t "$dir"/tl-*.dump.age 2>/dev/null | tail -n +"$(( ${BACKUP_KEEP_LOCAL:-7} + 1 ))" | xargs -r rm -f

if [ -n "${BACKUP_REMOTE_PATH:-}" ]; then
  command -v rclone >/dev/null || fail "rclone is not installed"
  rclone copy --no-traverse "$out" "tlbackup:${BACKUP_REMOTE_PATH%/}/" || fail "upload failed"
  rclone delete --min-age "${BACKUP_KEEP_REMOTE_DAYS:-30}d" "tlbackup:${BACKUP_REMOTE_PATH%/}/" || echo "backup: remote prune failed" >&2
  echo "uploaded to tlbackup:${BACKUP_REMOTE_PATH%/}/"
fi

[ -n "${HC_BACKUP_PING_URL:-}" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_BACKUP_PING_URL" || true
