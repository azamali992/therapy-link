# Eve serving

llama.cpp's `llama-server` running Gemma 4 E2B-it Q4_K_M plus the Eve LoRA, behind the FastAPI API. The scripts here start it from `ml/registry.json` and nothing else, so what runs is exactly the file pair the registry pins by sha256 (today v16-clean epoch 2 on the Q4_K_M base, prompt `eve-v2`).

| File | What it does |
|---|---|
| `run-llama-server.ps1` | Windows/local. Reads the registry, checks both hashes, starts llama-server on 127.0.0.1 |
| `run-llama-server.sh` | Same contract for Linux and the container (needs `jq`, `sha256sum`) |
| `fetch-models.sh` | Container entrypoint. Pulls the two GGUFs from `TL_MODEL_SOURCE`, then execs the run script |
| `Dockerfile.gpu` | Official llama.cpp CUDA server image + the scripts + the registry. No weights in the image |
| `smoke.py` | Starts the server through the run script, checks the lock-down, sends the six MODEL.md prompts, stops it |

## Run it locally

```powershell
$b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
$env:TL_LLM_API_KEY = [Convert]::ToBase64String($b)
$env:TL_LLM_ALLOW_UNAPPROVED = "1"   # v16c-e2 is still `candidate`, see below
powershell -ExecutionPolicy Bypass -File ops\serving\run-llama-server.ps1
```

Defaults: `D:\dev\models`, `D:\dev\llama\llama-server.exe`, port 8080, `-np 2`, 8192 tokens per slot (`-c 16384`), `-ngl 99`. The header of each script lists the env vars that override them. The API points `TL_INFERENCE_BASE_URL` at `http://127.0.0.1:8080` and sends the same secret as `TL_INFERENCE_API_KEY` (BACKEND.md's name for it on the API side; the server side reads `TL_LLM_API_KEY`).

The scripts refuse to start when:

- `TL_LLM_API_KEY` is missing or shorter than 24 characters,
- the adapter is `rejected` in the registry (DPO v16 is),
- the base or adapter has no clinician approval (`approved_by` null). `TL_LLM_ALLOW_UNAPPROVED=1` lets a `candidate` run on dev/staging. With `TL_ENV=prod` nothing unapproved runs, flag or not,
- the adapter's training prompt isn't the prompt the registry serves,
- either file is missing or its size or sha256 differs from the registry.

Flags they always pass, and why:

- `--host 127.0.0.1`. Only the API talks to it. The container is the one exception (below).
- API key through `LLAMA_API_KEY` in the environment, not `--api-key` on the command line, so it isn't readable from the process list. No key or a wrong key gets 401.
- `--cors-origins localhost --no-cors-credentials`. The default is `*`. The API calls it server to server, so no browser origin needs access.
- `--no-webui`, `--no-slots`. `/slots` shows the prompt text in each slot, which here is patient text.
- `--metrics` for Prometheus (tokens/s, queue depth per slot).
- `--reasoning off`, `--alias eve`, `-n 1024` as a hard cap (the app asks for 450).

Hashing the 3.1 GB base takes about 15 s on this laptop, every start. That's on purpose.

## Smoke test

```powershell
D:\therapylink\ml\.venv\Scripts\python.exe ops\serving\smoke.py
```

It writes `D:\therapylink-recovery\model-smoke\v3-serving-smoke.json` and the server log next to it, and exits non-zero unless every reply ended on its own with no foreign number, the lock-down checks passed, and the server was stopped with the port closed.

Run on 2026-10-03, RTX 2050 4 GB, build b10955, `-np 2`, 8192 per slot:

| | |
|---|---|
| Start to healthy | 31.3 s (15 s of it is the base hash) |
| Lock-down | no key 401, wrong key 401, `/slots` 501, web UI 404, no CORS header for a foreign origin, nothing on the LAN address |
| Replies ending on their own | 12/12, no leaked template tokens, no reasoning text |
| Foreign numbers | 0 |
| Crisis draws passing every safety check | 7/8 (same as MODEL.md; the miss is the English "letters just in case" sample 2 again, no number and no safety question) |
| Crisis draws with an allowlisted number / asking about safety | 7/8 / 7/8 |
| Latency | mean 4.1 s, max 6.9 s, 108 tokens per reply on average |
| Generation | 31 tok/s mean single stream (19 to 41, the laptop GPU throttles), 60 tok/s across two requests at once |

With `-np 1` the same run gave 36 tok/s single stream and identical replies. Two slots cost a little per stream and buy concurrency, so 2 stays the local default.

## Cloud GPU (Cloud Run, L4)

Build from the repo root:

```bash
docker build -f ops/serving/Dockerfile.gpu -t REGION-docker.pkg.dev/PROJECT/eve/eve-server:v16c-e2-$(git rev-parse --short HEAD) .
```

Put the two GGUFs in a private bucket under one prefix (`gs://BUCKET/eve/gemma-4-E2B-it-Q4_K_M.gguf`, `gs://BUCKET/eve/eve-sft-v16c-e2-lora-f16.gguf`), give the service account `roles/storage.objectViewer` on that bucket, and deploy:

```bash
gcloud run deploy eve-server \
  --image REGION-docker.pkg.dev/PROJECT/eve/eve-server:TAG \
  --region asia-southeast1 \
  --gpu 1 --gpu-type nvidia-l4 --cpu 4 --memory 16Gi \
  --no-allow-unauthenticated --ingress internal \
  --concurrency 4 --min-instances 0 --max-instances 2 \
  --set-env-vars TL_MODEL_SOURCE=gs://BUCKET/eve,TL_ENV=staging,TL_LLM_ALLOW_UNAPPROVED=1 \
  --set-secrets TL_LLM_API_KEY=tl-llm-api-key:latest
```

Inside the container the server has to listen on `0.0.0.0:$PORT`, because Cloud Run's ingress connects from outside the container. `Dockerfile.gpu` sets `TL_LLM_CONTAINER=1` for that and nothing else does. What keeps it private there is `--ingress internal`, `--no-allow-unauthenticated` (the API calls it with an identity token) and the API key, all three.

`TL_MODEL_SOURCE` can also be a mounted directory (a Cloud Run Cloud Storage volume at, say, `/mnt/models`), which skips the copy into memory but reads the 3.1 GB through gcsfuse for the hash check on every cold start. The `gs://` path downloads into `/models`, which is in-memory on Cloud Run, so 3.2 GB of the 16 GiB goes to the files.

Prod is the same command with `TL_ENV=prod` and without `TL_LLM_ALLOW_UNAPPROVED`. It won't start until a clinician's name is in `approved_by` for both entries.

### Costs and limits (from docs/rebuild/BACKEND.md)

- Pilot plan: Cloud Run GPU L4, `-np 4`, min 0 off-hours, min 1 during the evening peak (18:00 to 02:00 PKT), max 2. API and GPU service in the same region, Singapore or Mumbai. Check L4 availability in the region before picking it.
- BACKEND.md puts the Eve server at $10 to 40 a month for ~100 MAU (~400 cloud conversations a month) and all pilot infra at $25 to 75. That only holds at min 0. A min-1 instance is billed for every hour it's up, GPU included, so 8 hours a day of min 1 costs far more than $40 on its own. Price it against the current Cloud Run GPU rates before turning min 1 on, or pre-warm instead.
- Cold start is 30 to 90 s (BACKEND.md), plus the model download and the hash check. The app should pre-warm when the Eve screen opens and show "Eve is waking up…".
- `NP=4` for up to ~1,000 MAU, `NP=8` for ~10,000, each slot with its full context. At ~10k MAU, compare vLLM with LoRA hot-swap against llama.cpp at `-np 8`.
- API limits that keep a slot's context enough: 4,000 chars per message, 60 messages, 16,000 chars per conversation. 8192 tokens per slot covers that plus the ~400-token prompt and the 450-token reply.
- Rate limits live in the API (30 requests per 10 minutes, 300 a day per uid). Watch tokens/s, queue depth per slot, empty-reply rate and p95 latency from `/metrics`. Alert on inference p95 over 20 s.
- Rollback: shift Cloud Run traffic back to the previous revision. A new adapter means a new registry entry, a new image tag and a new revision.
- Rotate the API key monthly.

## Not done yet

- `Dockerfile.gpu` hasn't been built or run here (no Docker daemon on this box, and the CUDA image is several GB). `run-llama-server.sh` and `fetch-models.sh` were run under Git Bash with stand-in files and a stand-in server; the `gs://` download path hasn't run against a real bucket.
- The base image is pinned by tag (`server-cuda-b10955`). Pin it by digest after the first pull.
- Nothing is clinician-approved, so every start today needs `TL_LLM_ALLOW_UNAPPROVED=1`.
