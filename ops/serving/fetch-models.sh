#!/usr/bin/env bash
# Container entrypoint: get the two GGUF files the registry serves, then hand over to
# run-llama-server.sh (which checks their sha256 against the registry before starting).
#
# Weights are never baked into the image. TL_MODEL_SOURCE says where they live:
#   gs://bucket/prefix   download with the GCS JSON API, authenticated as the service's own
#                        service account via the metadata server (needs storage.objects.get)
#   /mnt/models          a directory, e.g. a Cloud Run Cloud Storage volume mount; used in place
#   https://host/prefix  plain HTTPS download of <prefix>/<file> (private network only)
set -euo pipefail

fail() { echo "fetch-models: $*" >&2; exit 1; }

src="${TL_MODEL_SOURCE:-}"
[ -n "$src" ] || fail "TL_MODEL_SOURCE is not set (gs://bucket/prefix, a mounted directory, or https://...)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
registry="${TL_LLM_REGISTRY:-$here/../../ml/registry.json}"
dest="${TL_MODELS_DIR:-/models}"

adapter_id="${TL_LLM_ADAPTER:-$(jq -r '.serve.adapter' "$registry")}"
adapter_file="$(jq -r --arg id "$adapter_id" '.adapters[] | select(.id == $id) | .file' "$registry")"
base_id="$(jq -r --arg id "$adapter_id" '.adapters[] | select(.id == $id) | .base_model' "$registry")"
base_file="$(jq -r --arg id "$base_id" '.base_models[] | select(.id == $id) | .file' "$registry")"
[ -n "$adapter_file" ] && [ -n "$base_file" ] || fail "adapter '$adapter_id' or its base model is not in $registry"

case "$src" in
  gs://*)
    rest="${src#gs://}"
    bucket="${rest%%/*}"
    prefix="${rest#"$bucket"}"
    prefix="${prefix#/}"
    token="$(curl -fsS -H 'Metadata-Flavor: Google' \
      'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' | jq -r '.access_token')"
    [ -n "$token" ] && [ "$token" != "null" ] || fail "no access token from the metadata server"
    mkdir -p "$dest"
    for f in "$base_file" "$adapter_file"; do
      object="${prefix:+$prefix/}$f"
      encoded="$(jq -rn --arg o "$object" '$o | @uri')"
      echo "fetching gs://$bucket/$object" >&2
      curl -fsS --retry 3 -H "Authorization: Bearer $token" -o "$dest/$f.part" \
        "https://storage.googleapis.com/storage/v1/b/$bucket/o/$encoded?alt=media"
      mv "$dest/$f.part" "$dest/$f"
    done
    ;;
  https://*)
    mkdir -p "$dest"
    for f in "$base_file" "$adapter_file"; do
      echo "fetching ${src%/}/$f" >&2
      curl -fsS --retry 3 -o "$dest/$f.part" "${src%/}/$f"
      mv "$dest/$f.part" "$dest/$f"
    done
    ;;
  /*)
    [ -d "$src" ] || fail "$src is not a directory"
    export TL_MODELS_DIR="$src"
    ;;
  *)
    fail "TL_MODEL_SOURCE must be gs://..., https://... or an absolute directory, got '$src'"
    ;;
esac

exec "$here/run-llama-server.sh"
