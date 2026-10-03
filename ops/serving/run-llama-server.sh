#!/usr/bin/env bash
# Start Eve's llama-server from ml/registry.json, on 127.0.0.1 only, behind an API key.
# Same contract as run-llama-server.ps1; needs bash, jq and sha256sum (or shasum).
#
#   TL_LLM_API_KEY=<at least 24 random characters> ops/serving/run-llama-server.sh
#
#   1. reads ml/registry.json and picks the base + adapter that `serve` names
#   2. refuses a rejected adapter; refuses an unapproved one unless TL_LLM_ALLOW_UNAPPROVED=1
#      (never allowed with TL_ENV=prod)
#   3. checks size and sha256 of both GGUF files against the registry
#   4. execs llama-server: 127.0.0.1, API key from the environment (not argv), --lora, --metrics,
#      no web UI, no /slots (it shows prompt text), CORS limited to localhost
#
# Environment (all optional except the key):
#   TL_LLM_API_KEY           required, >= 24 characters
#   TL_MODELS_DIR            default /models
#   TL_LLAMA_SERVER          default llama-server on PATH, else /app/llama-server
#   TL_LLM_REGISTRY          default <repo>/ml/registry.json
#   TL_LLM_ADAPTER           adapter id, default registry serve.adapter
#   TL_LLM_PORT              default $PORT, else 8080
#   TL_LLM_PARALLEL          slots (-np), default 2 (4 on an L4)
#   TL_LLM_CTX_PER_SLOT      context per slot, default 8192 (-c is this times -np)
#   TL_LLM_NGL               GPU layers, default 99
#   TL_LLM_ALLOW_UNAPPROVED  1 to serve a `candidate` before clinician sign-off (dev/staging only)
#   TL_LLM_CONTAINER         1 only inside the serving container (Dockerfile.gpu sets it): binds
#                            0.0.0.0 because the platform's ingress must reach the port. Anywhere
#                            else the server stays on 127.0.0.1.
set -euo pipefail

fail() { echo "run-llama-server: $*" >&2; exit 1; }

key="${TL_LLM_API_KEY:-}"
[ -n "$key" ] || fail "TL_LLM_API_KEY is not set. Refusing to start llama-server without an API key."
[ "${#key}" -ge 24 ] || fail "TL_LLM_API_KEY is shorter than 24 characters."
command -v jq >/dev/null || fail "jq is required to read the registry"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
registry="${TL_LLM_REGISTRY:-$here/../../ml/registry.json}"
models_dir="${TL_MODELS_DIR:-/models}"
port="${TL_LLM_PORT:-${PORT:-8080}}"
parallel="${TL_LLM_PARALLEL:-2}"
ctx_per_slot="${TL_LLM_CTX_PER_SLOT:-8192}"
ngl="${TL_LLM_NGL:-99}"
server="${TL_LLAMA_SERVER:-$(command -v llama-server || echo /app/llama-server)}"

[ -f "$registry" ] || fail "registry not found: $registry"
[ -x "$server" ] || fail "llama-server not found or not executable: $server"

host=127.0.0.1
if [ "${TL_LLM_CONTAINER:-}" = "1" ]; then
  host=0.0.0.0
fi

adapter_id="${TL_LLM_ADAPTER:-$(jq -r '.serve.adapter' "$registry")}"
adapter="$(jq -c --arg id "$adapter_id" '.adapters[] | select(.id == $id)' "$registry")"
[ -n "$adapter" ] || fail "adapter '$adapter_id' is not in $registry"
base_id="$(jq -r '.base_model' <<<"$adapter")"
base="$(jq -c --arg id "$base_id" '.base_models[] | select(.id == $id)' "$registry")"
[ -n "$base" ] || fail "adapter '$adapter_id' names unknown base model '$base_id'"
serve_prompt="$(jq -r '.serve.prompt_id' "$registry")"
[ "$(jq -r '.prompt_id' <<<"$adapter")" = "$serve_prompt" ] || fail "adapter '$adapter_id' was not trained on the served prompt '$serve_prompt'"

for e in "$base" "$adapter"; do
  if [ "$(jq -r '.status' <<<"$e")" = "rejected" ]; then
    fail "'$(jq -r '.id' <<<"$e")' is rejected: $(jq -r '.status_reason' <<<"$e")"
  fi
done
approved="$(jq -n --argjson b "$base" --argjson a "$adapter" \
  '[$b, $a] | all(.status == "approved" and (.approved_by // "") != "")')"
if [ "$approved" != "true" ]; then
  [ "${TL_ENV:-}" != "prod" ] || fail "'$adapter_id' has no clinician approval. TL_ENV=prod never serves an unapproved model."
  [ "${TL_LLM_ALLOW_UNAPPROVED:-}" = "1" ] || fail "'$adapter_id' has no clinician approval. Set TL_LLM_ALLOW_UNAPPROVED=1 to serve it outside prod."
  echo "warning: serving '$adapter_id' ($(jq -r '.status' <<<"$adapter")) without clinician approval" >&2
fi

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

verify() {
  local e="$1" id file path size want got
  id="$(jq -r '.id' <<<"$e")"
  file="$(jq -r '.file' <<<"$e")"
  path="$models_dir/$file"
  [ -f "$path" ] || fail "$id: $path not found"
  size="$(wc -c <"$path" | tr -d ' ')"
  [ "$size" = "$(jq -r '.size_bytes' <<<"$e")" ] || fail "$id: size $size != registered $(jq -r '.size_bytes' <<<"$e")"
  want="$(jq -r '.sha256' <<<"$e")"
  got="$(sha256 "$path")"
  [ "$got" = "$want" ] || fail "$id: sha256 $got != registered $want"
  echo "verified $id ${got:0:12}" >&2
}
verify "$base"
verify "$adapter"

base_path="$models_dir/$(jq -r '.file' <<<"$base")"
adapter_path="$models_dir/$(jq -r '.file' <<<"$adapter")"

# llama-server reads --api-key from LLAMA_API_KEY; keep it out of argv.
export LLAMA_API_KEY="$key"
unset TL_LLM_API_KEY

echo "serving $adapter_id on $base_id, prompt $serve_prompt, http://$host:$port, -np $parallel, $ctx_per_slot tokens per slot" >&2
exec "$server" \
  -m "$base_path" \
  --lora "$adapter_path" \
  --host "$host" \
  --port "$port" \
  -c "$((ctx_per_slot * parallel))" \
  -np "$parallel" \
  -ngl "$ngl" \
  -n 1024 \
  --alias eve \
  --reasoning off \
  --metrics \
  --no-webui \
  --no-slots \
  --cors-origins localhost \
  --no-cors-credentials
