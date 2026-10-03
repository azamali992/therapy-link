#!/usr/bin/env bash
# One-shot setup of TherapyLink on a fresh Ubuntu 22.04/24.04 VM (arm64 Oracle Ampere A1, or x86_64).
#
#   git clone <repo> /srv/therapylink && cd /srv/therapylink
#   sudo TL_DOMAIN=eve-pilot.duckdns.org ACME_EMAIL=you@example.com \
#        EVE_ADAPTER_URL='https://objectstorage...' ops/free/setup.sh
#
# Safe to re-run: every step checks what is already done. Steps:
#   1. preflight (root, Ubuntu, arch, RAM, disk)
#   2. packages: Docker Engine + compose plugin (Docker's apt repo), jq, age, rclone, python3
#   3. 2 GB swap (build headroom), unattended security upgrades
#   4. ops/free/.env from .env.example, random secrets, values given on the command line
#   5. host firewall: open 80/443 for caddy (Oracle images REJECT everything but 22 in iptables)
#   6. model files into EVE_MODELS_DIR, verified against ml/registry.json, and the Guardian bundle
#      into GUARDIAN_DIR, verified against its release report (get-models.sh)
#   7. build the images (Eve's llama.cpp build takes 10-20 minutes on 2 OCPUs)
#   8. Postgres up, migrations (`api release`), everything up, wait for health
#   9. checks: nothing but 22/80/443 listening publicly, one real reply from Eve through the API's
#      network, the public https endpoint
#  10. cron: healthcheck every 5 minutes, encrypted backup nightly
#
# Values can come from the environment or from ops/free/.env (environment wins on first run):
#   TL_DOMAIN, ACME_EMAIL, EVE_ADAPTER_URL | EVE_ADAPTER_PATH, EVE_HF_TOKEN, COMPOSE_PROFILES,
#   GUARDIAN_RELEASE, GUARDIAN_BASE_URL | GUARDIAN_SRC_DIR, GUARDIAN_HF_TOKEN,
#   TL_DATABASE_URL, CLOUDFLARE_TUNNEL_TOKEN, BACKUP_AGE_RECIPIENT, HC_PING_URL, HC_BACKUP_PING_URL,
#   FIREBASE_SA_JSON (a path; copied to /srv/therapylink-secrets/ with the API user as owner)
set -euo pipefail

log() { printf '\n== %s\n' "$*"; }
fail() { echo "setup: $*" >&2; exit 1; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
envf="$here/.env"
dc() { docker compose --project-directory "$here" -f "$here/docker-compose.yml" "$@"; }

# ---------------------------------------------------------------------------------------------
log "1/10 preflight"
[ "$(id -u)" = 0 ] || fail "run with sudo"
. /etc/os-release
[ "${ID:-}" = ubuntu ] || fail "this script targets Ubuntu (found ${ID:-unknown})"
arch="$(uname -m)"
case "$arch" in aarch64|x86_64) ;; *) fail "unsupported architecture $arch" ;; esac
mem_gb="$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo)"
cores="$(nproc)"
disk_gb="$(df --output=avail -BG / | tail -1 | tr -dc '0-9')"
echo "Ubuntu $VERSION_ID $arch, $cores cores, ${mem_gb} GB RAM, ${disk_gb} GB free on /"
[ "$mem_gb" -ge 7 ] || fail "need at least 8 GB RAM for the 3.1 GB model plus API and Postgres (found ${mem_gb} GB)"
[ "$disk_gb" -ge 15 ] || fail "need at least 15 GB free disk (model 3.2 GB, images ~2 GB, build cache)"
[ -f "$repo/ml/registry.json" ] || fail "run this from a checkout of the repo (ml/registry.json not found)"

# ---------------------------------------------------------------------------------------------
log "2/10 packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg jq git python3 age rclone cron unattended-upgrades >/dev/null
if ! docker compose version >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
fi
systemctl enable --now docker >/dev/null
docker compose version

# ---------------------------------------------------------------------------------------------
log "3/10 swap and automatic security updates"
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
sysctl -q -w vm.swappiness=10
echo 'vm.swappiness=10' > /etc/sysctl.d/90-therapylink.conf
dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------------------------
log "4/10 configuration (ops/free/.env)"
if [ ! -f "$envf" ]; then
  cp "$here/.env.example" "$envf"
  echo "created $envf"
fi
chmod 600 "$envf"
setenv() {  # key value: replace KEY=... in .env (value may contain / & etc.)
  python3 - "$envf" "$1" "$2" <<'PY'
import re, sys
path, key, value = sys.argv[1:]
text = open(path, encoding="utf-8").read()
line = f"{key}={value}"
text, n = re.subn(rf"^{re.escape(key)}=.*$", lambda m: line, text, flags=re.M)
if not n:
    text += ("" if text.endswith("\n") else "\n") + line + "\n"
open(path, "w", encoding="utf-8").write(text)
PY
}
getenv() { sed -n "s/^$1=//p" "$envf" | tail -1; }
for k in TL_DOMAIN ACME_EMAIL EVE_ADAPTER_URL EVE_ADAPTER_PATH EVE_HF_TOKEN COMPOSE_PROFILES TL_DATABASE_URL \
         CLOUDFLARE_TUNNEL_TOKEN BACKUP_AGE_RECIPIENT HC_PING_URL HC_BACKUP_PING_URL TL_ENV EVE_THREADS EVE_SLOTS          GUARDIAN_RELEASE GUARDIAN_BASE_URL GUARDIAN_SRC_DIR GUARDIAN_HF_TOKEN; do
  if [ -n "${!k:-}" ]; then setenv "$k" "${!k}"; fi
done
rand() { python3 -c "import secrets; print(secrets.token_urlsafe($1))"; }
[ -n "$(getenv TL_LLM_API_KEY)" ] || setenv TL_LLM_API_KEY "$(rand 32)"
[ -n "$(getenv POSTGRES_PASSWORD)" ] || setenv POSTGRES_PASSWORD "$(rand 24)"
[ -n "$(getenv TL_LOG_UID_SALT)" ] || setenv TL_LOG_UID_SALT "$(rand 32)"
# Threads = physical cores (an Ampere OCPU is one core, no SMT).
[ -n "$(getenv EVE_THREADS)" ] || setenv EVE_THREADS "$cores"
set -a
# shellcheck source=/dev/null
. "$envf"
set +a
profiles=",${COMPOSE_PROFILES:-},"
if [[ "$profiles" == *",caddy,"* ]]; then
  [ -n "${TL_DOMAIN:-}" ] || fail "TL_DOMAIN is empty: give a DNS name pointing at this VM (see FREE_DEPLOY.md)"
  [ -n "${ACME_EMAIL:-}" ] || fail "ACME_EMAIL is empty (Let's Encrypt expiry notices go there)"
fi
if [[ "$profiles" == *",tunnel,"* ]]; then
  [ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ] || fail "profile tunnel needs CLOUDFLARE_TUNNEL_TOKEN"
fi
if [[ "$profiles" != *",localdb,"* ]] && [ -z "${TL_DATABASE_URL:-}" ]; then
  fail "without the localdb profile, TL_DATABASE_URL must point at Neon (or another Postgres)"
fi

# Firebase service account: copy it where the API's non-root user can read it, and nobody else.
if [ -n "${FIREBASE_SA_JSON:-}" ]; then
  [ -f "$FIREBASE_SA_JSON" ] || fail "FIREBASE_SA_JSON=$FIREBASE_SA_JSON not found"
  install -d -m 0700 /srv/therapylink-secrets
  install -m 0400 "$FIREBASE_SA_JSON" /srv/therapylink-secrets/firebase.json
  setenv FIREBASE_SA_JSON_HOST_PATH /srv/therapylink-secrets/firebase.json
  set -a
  # shellcheck source=/dev/null
  . "$envf"
  set +a
fi

# ---------------------------------------------------------------------------------------------
log "5/10 host firewall"
if [[ "$profiles" == *",caddy,"* ]]; then
  if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ufw allow 443/udp >/dev/null
    echo "ufw: allowed 80/tcp 443/tcp 443/udp"
  else
    # Oracle's Ubuntu images ship iptables rules that end INPUT with a REJECT. Insert ACCEPTs for
    # 80/443 above it (idempotent) and persist them.
    for rule in "-p tcp --dport 80" "-p tcp --dport 443" "-p udp --dport 443"; do
      # shellcheck disable=SC2086
      iptables -C INPUT $rule -m conntrack --ctstate NEW -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 5 $rule -m conntrack --ctstate NEW -j ACCEPT
    done
    if command -v netfilter-persistent >/dev/null; then
      netfilter-persistent save >/dev/null 2>&1 || true
    else
      apt-get install -y -qq iptables-persistent >/dev/null && netfilter-persistent save >/dev/null 2>&1 || true
    fi
    echo "iptables: 80/tcp 443/tcp 443/udp accepted"
  fi
  echo "Also open TCP 80 and 443 (and UDP 443) in the VCN security list / cloud firewall. Nothing else."
else
  echo "tunnel profile: no inbound ports needed besides SSH"
fi

# ---------------------------------------------------------------------------------------------
log "6/10 model files"
"$here/get-models.sh"

# ---------------------------------------------------------------------------------------------
log "7/10 build images (llama.cpp from source: 10-20 minutes on 2 cores)"
dc build --pull api eve

# ---------------------------------------------------------------------------------------------
log "8/10 start"
if [ -n "${FIREBASE_SA_JSON_HOST_PATH:-}" ]; then
  api_uid="$(dc run --rm --no-deps -T --entrypoint id api -u)"
  chown "$api_uid" "$FIREBASE_SA_JSON_HOST_PATH"
fi
if [[ "$profiles" == *",localdb,"* ]]; then
  dc up -d --wait postgres
fi
echo "migrating the database (alembic upgrade head)"
dc run --rm -T api release
dc up -d --remove-orphans
echo "waiting for Eve to hash, load and answer /health (up to 15 minutes)"
for _ in $(seq 1 90); do
  s="$(docker inspect -f '{{.State.Health.Status}}' "$(dc ps -q eve)" 2>/dev/null || echo starting)"
  [ "$s" = healthy ] && break
  [ "$s" = unhealthy ] && { dc logs --tail 40 eve; fail "Eve is unhealthy"; }
  sleep 10
done
[ "$s" = healthy ] || { dc logs --tail 40 eve; fail "Eve did not become healthy"; }
dc ps

# ---------------------------------------------------------------------------------------------
log "9/10 checks"
# llama-server, Postgres and the API must not be reachable from outside the VM.
listeners="$(ss -Hltnu | awk '{print $5}')"
if grep -E ':(8080|5432|7860)$' <<<"$listeners" | grep -vE '^(127\.|\[::1\])' >/dev/null; then
  echo "$listeners"
  fail "llama-server, Postgres or the API is listening on a public address"
fi
others="$(grep -vE '^(127\.|\[::1\]|::1)' <<<"$listeners" | grep -vE ':(22|80|443)$' | grep -v '%lo' || true)"
[ -z "$others" ] || { echo "warning: other public listeners (close them or block them in the VCN):"; echo "$others"; }
echo "model, database and API ports: not public"

# One real reply through the same network path the API uses, without printing the reply.
dc exec -T api python - <<'PY'
import json, os, time, urllib.error, urllib.request
body = json.dumps({"model": "eve", "max_tokens": 64, "temperature": 0,
                   "messages": [{"role": "user", "content": "Hi Eve, quick test. Say hello in one sentence."}]}).encode()
req = urllib.request.Request("http://eve:8080/v1/chat/completions", data=body, headers={
    "Content-Type": "application/json", "Authorization": "Bearer " + os.environ["TL_INFERENCE_API_KEY"]})
t0 = time.time()
j = json.load(urllib.request.urlopen(req, timeout=600))
t = j.get("timings", {})
print(f"Eve answered: {j['usage']['completion_tokens']} tokens in {time.time() - t0:.1f} s, "
      f"generation {t.get('predicted_per_second', 0):.1f} tok/s, prompt {t.get('prompt_per_second', 0):.1f} tok/s")
try:
    urllib.request.urlopen(urllib.request.Request("http://eve:8080/v1/chat/completions", data=body,
                                                  headers={"Content-Type": "application/json"}), timeout=60)
    raise SystemExit("llama-server answered without the API key")
except urllib.error.HTTPError as e:
    assert e.code == 401, e.code
    print("llama-server refuses requests without the key (401)")
PY

if [[ "$profiles" == *",caddy,"* ]]; then
  echo "waiting for the certificate and https://$TL_DOMAIN/ready"
  ok=""
  for _ in $(seq 1 30); do
    if curl -fsS -m 10 "https://$TL_DOMAIN/ready"; then ok=1; echo; break; fi
    sleep 10
  done
  [ -n "$ok" ] || { dc logs --tail 30 caddy; fail "https://$TL_DOMAIN/ready did not answer. Check DNS, the VCN security list and ports 80/443"; }
  # The Guardian bundle, as a phone fetches it: the ETag the API sends is the file's sha256.
  if g="$(curl -fsSI -m 10 "https://$TL_DOMAIN/guardian/config.json")"; then
    want="$(jq -r '.files["config.json"].sha256' "$repo/ml/releases/${GUARDIAN_RELEASE:-guardian-v1b}/report.json")"
    if grep -qi "etag: \"$want\"" <<<"$g"; then
      echo "https://$TL_DOMAIN/guardian/ serves ${GUARDIAN_RELEASE:-guardian-v1b}"
    else
      echo "warning: /guardian/config.json is not the ${GUARDIAN_RELEASE:-guardian-v1b} file"
    fi
  else
    echo "warning: https://$TL_DOMAIN/guardian/config.json did not answer; release apps keep Eve's chat paused without it"
  fi
fi

# ---------------------------------------------------------------------------------------------
log "10/10 cron"
cat > /etc/cron.d/therapylink <<CRON
# Installed by ops/free/setup.sh
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/5 * * * * root $here/healthcheck.sh >> /var/log/therapylink-health.log 2>&1
# 21:30 UTC = 02:30 PKT, after the evening peak
30 21 * * * root $here/backup.sh >> /var/log/therapylink-backup.log 2>&1
CRON
chmod 0644 /etc/cron.d/therapylink
cat > /etc/logrotate.d/therapylink <<'ROT'
/var/log/therapylink-*.log {
  weekly
  rotate 8
  compress
  missingok
  notifempty
}
ROT
[[ "${BACKUP_AGE_RECIPIENT:-}" == age1* ]] || echo "NOTE: BACKUP_AGE_RECIPIENT is empty, so the nightly backup will fail (and say so) until you set it."

log "done"
url="https://${TL_DOMAIN:-<your tunnel hostname>}"
cat <<EOF
API:  $url   (health: $url/health, readiness: $url/ready)
Build the app against it (the Guardian flags come from ml/releases/${GUARDIAN_RELEASE:-guardian-v1b}/report.json):
  flutter build apk --release --dart-define=TL_API_URL=$url \\
    --dart-define=TL_GUARDIAN_URL=$url/guardian/ \\
    --dart-define=$(jq -r .dart_define "$repo/ml/releases/${GUARDIAN_RELEASE:-guardian-v1b}/report.json")
Measure Eve's speed on this VM (prints no reply text):
  sudo docker compose --project-directory $here -f $here/docker-compose.yml run --rm --no-deps \\
    -v $repo:/repo:ro -e TL_LLM_API_KEY --entrypoint python api /repo/ops/free/bench.py --url http://eve:8080
  (export TL_LLM_API_KEY from $envf first)
EOF
