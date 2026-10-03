#!/usr/bin/env bash
# Every 5 minutes from cron (setup.sh installs it). Checks the stack from inside the VM and pings
# healthchecks.io (HC_PING_URL), which emails you when a ping is missed or reports failure. An
# outside uptime monitor on https://$TL_DOMAIN/ready covers "the VM or the network is down".
#
# Checks: API /ready (database answers), Eve /health (model loaded), the TLS endpoint, disk and
# memory. An unhealthy Eve or API container is restarted once per run. Logs carry no request data.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$here/.env" ] && { set -a; . "$here/.env"; set +a; }
dc() { docker compose --project-directory "$here" -f "$here/docker-compose.yml" "$@"; }

problems=()

state() { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$(dc ps -q "$1" 2>/dev/null)" 2>/dev/null || echo missing; }

for svc in api eve; do
  s="$(state "$svc")"
  if [ "$s" = "unhealthy" ] || [ "$s" = "exited" ] || [ "$s" = "missing" ]; then
    problems+=("$svc:$s")
    if [ "$s" = "unhealthy" ]; then dc restart "$svc" >/dev/null 2>&1; else dc up -d "$svc" >/dev/null 2>&1; fi
  fi
done

if ! dc exec -T api python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:7860/ready', timeout=10).status == 200 else 1)" >/dev/null 2>&1; then
  problems+=("api-ready")
fi
if ! dc exec -T eve curl -fsS -m 10 http://127.0.0.1:8080/health >/dev/null 2>&1; then
  # Eve answers 503 while loading; that's only a problem if it lasts (the container health covers it).
  problems+=("eve-health")
fi
if [[ ",${COMPOSE_PROFILES:-}," == *",caddy,"* ]] && [ -n "${TL_DOMAIN:-}" ]; then
  curl -fsS -m 15 -o /dev/null "https://$TL_DOMAIN/health" || problems+=("tls-endpoint")
fi

disk="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
[ "${disk:-0}" -lt 85 ] || problems+=("disk-${disk}%")
mem_avail_mb="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"
[ "${mem_avail_mb:-0}" -gt 400 ] || problems+=("mem-avail-${mem_avail_mb}MB")

stamp="$(date -u +%FT%TZ)"
if [ ${#problems[@]} -eq 0 ]; then
  echo "$stamp ok disk=${disk}% mem_avail=${mem_avail_mb}MB"
  [ -n "${HC_PING_URL:-}" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_PING_URL"
  exit 0
fi
echo "$stamp FAIL ${problems[*]}"
[ -n "${HC_PING_URL:-}" ] && curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "${problems[*]}" "$HC_PING_URL/fail"
exit 1
