#!/usr/bin/env bash
# Put the two GGUF files that ml/registry.json serves into EVE_MODELS_DIR, and the Guardian
# bundle (four files) into GUARDIAN_DIR, verified.
#
#   sudo ops/free/get-models.sh            # reads ops/free/.env; setup.sh calls this
#
# Base:    EVE_BASE_URL (default: the public unsloth GGUF on Hugging Face) or EVE_BASE_PATH.
# Adapter: EVE_ADAPTER_URL (a time-limited link: OCI pre-authenticated request, or a private HF
#          repo with EVE_HF_TOKEN) or EVE_ADAPTER_PATH (a file you copied to the VM with scp).
# Guardian: GUARDIAN_BASE_URL (a URL the four files sit under; GUARDIAN_HF_TOKEN for a private HF
#          repo) or GUARDIAN_SRC_DIR (a directory you copied them to). Sizes and sha256 come from
#          ml/releases/$GUARDIAN_RELEASE/report.json (default guardian-v1b).
#
# Every file must match the registry's size and sha256 before it is moved into place; a file that
# is already there and matches is left alone. Downloads resume after a dropped connection.
# run-llama-server.sh checks both hashes again on every start, so a swapped file never serves.
set -euo pipefail

fail() { echo "get-models: $*" >&2; exit 1; }
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
registry="$repo/ml/registry.json"
[ -f "$here/.env" ] && { set -a; . "$here/.env"; set +a; }
command -v jq >/dev/null || fail "jq is required"
command -v curl >/dev/null || fail "curl is required"

dest="${EVE_MODELS_DIR:-/srv/eve/models}"
adapter_id="${TL_LLM_ADAPTER:-$(jq -r '.serve.adapter' "$registry")}"
adapter="$(jq -c --arg id "$adapter_id" '.adapters[] | select(.id == $id)' "$registry")"
[ -n "$adapter" ] || fail "adapter '$adapter_id' is not in $registry"
base="$(jq -c --arg id "$(jq -r '.base_model' <<<"$adapter")" '.base_models[] | select(.id == $id)' "$registry")"
[ -n "$base" ] || fail "the base model of '$adapter_id' is not in $registry"

mkdir -p "$dest"
chmod 0755 "$dest"

matches() {  # entry-json path
  local e="$1" p="$2"
  [ -f "$p" ] || return 1
  [ "$(wc -c <"$p" | tr -d ' ')" = "$(jq -r '.size_bytes' <<<"$e")" ] || return 1
  [ "$(sha256sum "$p" | cut -d' ' -f1)" = "$(jq -r '.sha256' <<<"$e")" ]
}

get() {  # entry-json url local-path [bearer-token]
  local e="$1" url="$2" local_path="$3" token="${4:-}"
  local id file out
  id="$(jq -r '.id' <<<"$e")"
  file="$(jq -r '.file' <<<"$e")"
  out="$dest/$file"
  if matches "$e" "$out"; then
    echo "ok       $id already in place ($(jq -r '.sha256' <<<"$e" | cut -c1-12))"
    return
  fi
  if [ -n "$local_path" ]; then
    [ -f "$local_path" ] || fail "$id: $local_path not found"
    echo "copying  $id from $local_path"
    cp "$local_path" "$out.part"
  elif [ -n "$url" ]; then
    echo "fetching $id ($(( $(jq -r '.size_bytes' <<<"$e") / 1048576 )) MiB)"
    local auth=()
    [ -n "$token" ] && auth=(-H "Authorization: Bearer $token")
    # -C - resumes a partial .part file; the URL itself is never printed (a pre-authenticated
    # request URL is a credential).
    curl -fL --retry 5 --retry-delay 5 --retry-all-errors -C - "${auth[@]}" -o "$out.part" "$url" \
      || fail "$id: download failed"
  else
    fail "$id: no source. Set $([ "$e" = "$base" ] && echo EVE_BASE_URL or EVE_BASE_PATH || echo EVE_ADAPTER_URL or EVE_ADAPTER_PATH) in ops/free/.env"
  fi
  if ! matches "$e" "$out.part"; then
    rm -f "$out.part"
    fail "$id: size or sha256 differs from ${truth:-$registry}; file discarded"
  fi
  chmod 0444 "$out.part"
  mv -f "$out.part" "$out"
  echo "verified $id $(jq -r '.sha256' <<<"$e" | cut -c1-12) -> $out"
}

get "$base" "${EVE_BASE_URL:-}" "${EVE_BASE_PATH:-}"
get "$adapter" "${EVE_ADAPTER_URL:-}" "${EVE_ADAPTER_PATH:-}" "${EVE_HF_TOKEN:-}"
df -h "$dest" | tail -1

# --- Guardian ----------------------------------------------------------------------------------
# The on-device crisis classifier's four files, which the API serves at /guardian/<file> for the
# app to download. Sizes and sha256 come from the release report the app's TL_GUARDIAN_SHA256 build
# flag is made from, so the server and the app pin the same bytes.
guardian_release="${GUARDIAN_RELEASE:-guardian-v1b}"
report="$repo/ml/releases/$guardian_release/report.json"
truth="$report"
[ -f "$report" ] || fail "Guardian release '$guardian_release' has no $report"
dest="${GUARDIAN_DIR:-/srv/guardian}"
mkdir -p "$dest"
chmod 0755 "$dest"
guardian_missing=""
for f in guardian.int8.onnx spm_vocab.json config.json thresholds.json; do
  entry="$(jq -c --arg f "$f" '{id: ("guardian " + $f), file: $f, size_bytes: .files[$f].bytes, sha256: .files[$f].sha256}' "$report")"
  [ "$(jq -r '.sha256' <<<"$entry")" != null ] || fail "$report has no sha256 for $f"
  if matches "$entry" "$dest/$f"; then
    echo "ok       guardian $f already in place ($(jq -r '.sha256' <<<"$entry" | cut -c1-12))"
  elif [ -n "${GUARDIAN_SRC_DIR:-}" ]; then
    get "$entry" "" "$GUARDIAN_SRC_DIR/$f"
  elif [ -n "${GUARDIAN_BASE_URL:-}" ]; then
    get "$entry" "${GUARDIAN_BASE_URL%/}/$f" "" "${GUARDIAN_HF_TOKEN:-}"
  else
    guardian_missing="$guardian_missing $f"
  fi
done
if [ -n "$guardian_missing" ]; then
  # Not fatal: the API and Eve still run. But release apps keep Eve's chat paused until the phone
  # has the trained Guardian, and this server is where they get it.
  echo "WARNING: Guardian files not installed:$guardian_missing" >&2
  echo "         Set GUARDIAN_BASE_URL or GUARDIAN_SRC_DIR in ops/free/.env and run get-models.sh again." >&2
fi
df -h "$dest" | tail -1
