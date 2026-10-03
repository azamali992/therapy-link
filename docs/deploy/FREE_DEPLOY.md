# Free deploy: TherapyLink on one Oracle Always Free VM

The whole backend (TLS, the FastAPI API, Postgres and Eve on llama.cpp) runs on one Oracle Cloud Always Free Ampere A1 VM for $0 a month. Files are in `ops/free/`. This doc covers why that host, how fast Eve is on it, how many people it can take, and the steps from sign-up to the first chat from the app.

Researched and written 2026-10-03. Free tiers change without notice (Oracle halved its A1 allowance in mid-2026), so recheck the prices and limits below before you sign up.

## Where things landed

- **Primary: Oracle Always Free, one A1 VM, 2 OCPU / 12 GB, home region Mumbai or Hyderabad.** Docker Compose runs Caddy (Let's Encrypt TLS), the API, llama-server on CPU and Postgres. Eve runs unmodified: the same Q4_K_M base and v16c-e2 LoRA, checked against `ml/registry.json` on every start. Nothing to pay. Sign-up asks for a card for verification. Oracle says Always Free resources are never charged.
- **Expect replies of 15 to 30 s** on 2 OCPUs. They stream, so the first words show up after a few seconds when the prompt cache hits. That's fine for a ~100-user pilot. It won't hold more than 2 or 3 people chatting at the same moment (see Capacity).
- **Fallback, if Oracle won't give you an A1 VM** ("out of host capacity", or the account is refused): the same `ops/free` stack on a paid ARM box, Hetzner CAX21 (4 vCPU / 8 GB, about €10.49 a month after Hetzner's June 2026 increase, Germany/Finland only). `setup.sh` works on any Ubuntu arm64 or x86_64 VM. Upgrading the Oracle account to Pay-As-You-Go also gets past capacity errors and stays $0 inside the Always Free limits, but then a mistake can cost money, so set a budget alert.
- **No free host runs Eve on a GPU.** Every GPU option is either paid (Cloud Run L4, Modal past its $30 of credits, HF Inference Endpoints) or can't load a GGUF LoRA on Gemma 4 E2B (Workers AI, Groq, Together, Fireworks serverless, ZeroGPU). Details in the next table.

## Model hosting options

Checked on the web on 2026-10-03. "UNVERIFIED" means only a secondary source or a search snippet said it.

| Option | Runs Eve as is? | ~110-token reply | Cold start | Catches | Health data / ToS | Near Pakistan | $ / month, pilot |
|---|---|---|---|---|---|---|---|
| **Oracle Always Free A1** (2 OCPU, 12 GB) [1][2] | Yes, llama.cpp on CPU | 15–30 s (estimate, see Measured) | None, always on | Was 4 OCPU / 24 GB until mid-2026 [3]; "out of host capacity" errors; idle VMs reclaimed (7 days with CPU p95, network and memory all under 20%) | Normal Oracle cloud terms; you control the VM | Mumbai, Hyderabad, Dubai, Abu Dhabi, Jeddah, Riyadh [4] | **$0** |
| Oracle PAYG, 4 OCPU / 24 GB | Yes | ~2x faster generation | None | Extra 2 OCPU + 12 GB billed; price page blocked our fetch, check it | Same | Same | Paid part only, UNVERIFIED |
| Hugging Face Space, CPU Basic (2 vCPU, 16 GB) [5][6] | Yes (Docker Space) | 20–40 s (x86, 2 vCPU) | Minutes after the 48 h sleep (re-download and hash 3.1 GB) | Docker/Gradio Spaces now need PRO to create; a private Space needs an `hf_` token the API can't send, so it would have to be public | US hosting, no health-data clause [7] | US/EU | $9 (PRO) |
| HF ZeroGPU [8] | No: Gradio + PyTorch only, no llama-server | – | – | Free accounts get 5 GPU-minutes a day | – | – | – |
| HF Inference Providers / Endpoints [6][9] | Providers: no custom LoRA found. Endpoints: yes | GPU: 2–4 s | Endpoint scale-to-zero cold start | Endpoints from $0.03/h CPU, $0.50/h T4 | – | Some regions | ≥ $360 for a 24/7 T4 |
| Modal [10][11] | Yes, a llama.cpp container | 2–4 s on T4/L4 | 20–60 s (UNVERIFIED) | $30 of compute a month on Starter; T4 $0.59/h, L4 $0.80/h; region pinning costs 1.15–1.75x; the public URL's proxy auth needs headers our API doesn't send | Fine | ap-south (Mumbai) | $0 while GPU time stays under ~37 L4-hours or ~50 T4-hours, then paid |
| Lightning AI | Probably, in a Studio | – | – | 15 credits a month (secondary source only), built for interactive work | – | – | UNVERIFIED |
| Google Cloud | Trial: no GPUs allowed [12]. Cloud Run L4: yes (`Dockerfile.gpu`) | 2–4 s | 30–90 s | Always Free e2-micro is 1 GB and US-only; Cloud Run GPUs have no free tier, L4 about $0.67/h [13] | Fine with a DPA | asia-southeast1 (Mumbai is invite-only) | $10–40 (BACKEND.md), more with min 1 |
| Azure free / for Students [14] | Credits only | – | – | $200 for 30 days / $100 for students; GPU access on free accounts UNVERIFIED | – | Central India | $0 for a month, then paid |
| AWS Free Tier [15] | No (t4g.small is 2 GB RAM) | – | – | $100–200 credits over 6 months; t4g.small trial runs to 2026-12-31 | – | Mumbai | Credits, then paid |
| Colab / Kaggle [16] | Not allowed | – | – | Colab bans "web service offerings not related to interactive compute" on all runtimes and remote control on the free tier. Kaggle's terms only render with JavaScript, so we couldn't quote them, but sessions end after hours and there is no stable inbound URL | Not for patient data | – | – |
| Cloudflare Workers AI [17][18] | No | – | – | LoRA only on unquantized gemma-2b/7b-it-lora, mistral-7b, llama-2-7b (maybe gemma-3-12b); PEFT safetensors, rank ≤ 32; no Gemma 4, no GGUF | Doesn't train on your data | Global | – |
| Groq / Together / Fireworks / OpenRouter [19]–[22] | No | – | – | Groq LoRA is Enterprise, Llama 3.1 8B only; Together dropped serverless LoRA; Fireworks LoRA is dedicated-only; OpenRouter has no upload | – | – | Dedicated GPUs, paid |
| Gemini API (Gemma) [23][24] | No: hosts Gemma 4 31B / 26B-A4B, no E2B, no custom weights | – | – | Unpaid tier uses prompts to improve Google products, with human review, and says not to send sensitive data | **Never for health data** on the free tier | – | – |
| Hetzner CAX21 (paid fallback) [25] | Yes, same stack | ~10–20 s (4 vCPU) | None | Restock-gated; Germany/Finland | Normal | ~150 ms from Pakistan | ~€10.49 |

## API and database options

| Option | Fit | Catches |
|---|---|---|
| **Same Oracle VM** (chosen) | API + Postgres next to Eve, no extra processor of patient data, private Docker network | 2 cores shared with Eve (the API gets 4x Eve's CPU weight in compose); backups are on us (`backup.sh`) |
| Neon free [26] | Good managed Postgres; set `TL_DATABASE_URL` and drop the `localdb` profile | 1 GB per project, 100 CU-hours a month, suspends after 5 min idle (first query wakes it in about a second), Singapore yes, Mumbai no |
| Supabase free [27] | Works | 500 MB, pauses after a week without activity, no backups |
| Render free [28] | API only | Spins down after 15 min (30+ s wake-up); free Postgres expires after 30 days |
| Fly.io [29] | No | No free tier for new organisations; 2-hour/7-day trial |
| Railway [30] | No | $5 one-time trial, then $1 a month of usage |
| Koyeb [31] | No | No free compute any more; free Postgres limited to 5 hours a month |
| Cloud Run free tier [12] | API yes (2M requests, 180k vCPU-s a month) | Needs a database elsewhere (Neon), and it can't reach a llama-server on Oracle privately |
| Cloudflare Tunnel [32][33] | TLS without opening ports (`tunnel` profile) | Cloudflare decrypts every request, so chat text passes through it; 125 s proxy read timeout (Enterprise can change it) |
| Backup storage | OCI Object Storage 20 GB on an Always-Free-only account (10+10+10 GB on PAYG/trial) [1]; Cloudflare R2 10 GB [34]; Backblaze B2 10 GB [35] | `backup.sh` encrypts with age before upload either way |
| Uptime | UptimeRobot 50 monitors at 5 min [36]; Better Stack 10 monitors [37]; healthchecks.io 20 checks [38] | UptimeRobot banned commercial use on free in Dec 2024; reports say that was reversed (UNVERIFIED), so Better Stack is the safe default |

Caddy on the VM is the default ingress over Cloudflare Tunnel. It keeps TLS ending on our own box, so no third party sees message bodies, and it has no 125 s cap on a slow reply.

## Measured CPU speed

Run 2026-10-03 on this laptop (i5-12450H, x86, llama.cpp b10955 Windows build), CPU only: `CUDA_VISIBLE_DEVICES=-1 --device none --no-op-offload -ngl 0`, threads pinned with `-C`. `ops/free/bench.py`: the four non-crisis smoke prompts with the real V2 prompt folded in (411–433 prompt tokens), greedy, max 450, then a second turn, then two requests at once. Raw JSON in `D:\dev\tmp\free-bench\`.

| Run | Generation tok/s (mean, range) | Prompt tok/s | Reply tokens | Wall per reply (mean / max) | 2 at once |
|---|---|---|---|---|---|
| 4 threads, LoRA, `-np 1`, no SWA cache | 7.3 (3.8–10.7) | 27 | 76 | 30 s / 41 s | 2.1 tok/s total (queued) |
| 4 P-cores, LoRA, `-np 2`, `--swa-full` | 5.5 (4.1–6.0) | 23 | 70 | 17 s / 26 s | 3.4 tok/s total, slowest 46 s |
| 4 P-cores, base only (no LoRA), `-np 2`, `--swa-full` | 3.8 (3.2–5.0) | 19 | 67 | 24 s / 31 s | 2.6 tok/s total |
| 2 P-cores, LoRA, `-np 1`, `--swa-full` | 4.0 (1.3–6.5) | 15 | 76 | 42 s / 62 s | – |

Read these as a pessimistic floor. The laptop was 65–93% busy with another job (Eve v17 work) the whole time, and the base-only run came out slower than the LoRA run in the same session, so the noise is bigger than the LoRA's cost. Two conclusions hold anyway:

1. **Merging the LoRA isn't worth doing for CPU now.** Its overhead is below what this box can measure (llama.cpp applies it as an extra low-rank matmul; the adapter is 97 MB against a 3.1 GB base). A merged GGUF would also be a new artifact that needs its own registry entry, sha256, gate and clinician sign-off. `llama-export-lora` isn't in the local b10955 Windows build, so no merged file was made.
2. **`--swa-full` matters more than threads.** Gemma 4 uses a sliding-window cache, and without the full-size cache llama-server couldn't reuse the cached Eve prompt across conversations (`cache_n` was 1). With it, 389 of 411 prompt tokens came from cache, and the wall time of a fresh conversation's first reply dropped (sleep prompt: 24 s to 9 s). On CPU, prompt reading runs at 15–35 tok/s, so a cold 411-token prompt costs 12–27 s before the first word. The compose file sets `LLAMA_ARG_SWA_FULL=1` and a 1.5 GB host-RAM prompt cache (`--cache-ram`) so returning conversations don't re-read their history.

**ARM vs this laptop.** An A1 OCPU is one Neoverse N1 core (3.0 GHz, NEON + dotprod, no SMT, no i8mm). Per core it is slower than a Golden Cove P-core, but token generation on CPU is mostly limited by memory bandwidth, and the A1 has plenty per core. The one public A1 number found: Qwen2.5-3B Q4_K_M at 10.6 tok/s generation on 4 A1 cores with upstream llama.cpp (13.4 with Ampere's own build) [39]. Gemma 4 E2B does about 2B parameters of compute per token, a bit less than Qwen 3B, so expect roughly 10–14 tok/s on 4 OCPUs and **5–8 tok/s on the free 2 OCPUs**, with prompt reading at maybe 30–60 tok/s. Current llama.cpp repacks Q4_K for N1 (8x4 layout), so Q4_K_M doesn't need converting to Q4_0 to get the fast ARM kernels [39]. Check the eve logs for repack lines. These are estimates. Run the benchmark on the VM (step 9) and replace this paragraph with the real numbers.

## Architecture

```
phone ──https──> Caddy :443 (Let's Encrypt) ──> api:7860 ──> eve:8080  llama-server, CPU, API key, no published port
                 [edge network]                  │   └────> postgres:5432  no published port
                                                 └── Firebase token checks (egress via edge)
                 [backend network: internal, no internet in or out]
cron: healthcheck.sh every 5 min -> healthchecks.io;  backup.sh 02:30 PKT -> age -> OCI Object Storage
```

How this meets `docs/rebuild/SECURITY.md`:

- **No public model endpoint.** llama-server and Postgres sit only on an `internal: true` Docker network. No port is published, and the VM's firewall and VCN only open 80/443 (to Caddy) and 22. Inside the container llama-server binds 0.0.0.0 because the API calls it from another container (`TL_LLM_CONTAINER=1`, same as the Cloud Run image), and it still needs the API key. `setup.sh` fails if 8080, 5432 or 7860 listen on a public address and checks that a request without the key gets 401.
- **API key between API and model.** One random 43-character key, `TL_LLM_API_KEY` for llama-server (moved into `LLAMA_API_KEY` by the run script, not on the command line) and `TL_INFERENCE_API_KEY` for the API. Generated by `setup.sh` into `ops/free/.env`, mode 600.
- **TLS.** Caddy with Let's Encrypt and HSTS. The app refuses non-https URLs in release builds anyway.
- **No message bodies in logs.** Caddy has no access log (paths carry uids). llama-server runs with `--no-slots` (slots show prompt text) and no web UI. Postgres runs with `log_min_error_statement=panic`, so a failing query doesn't print journal text. The API logs token counts only. Docker logs rotate at 5 x 10 MB.
- **Model integrity.** `get-models.sh` and `run-llama-server.sh` both check size and sha256 against `ml/registry.json`. The base comes from Hugging Face (`unsloth/gemma-4-E2B-it-GGUF`, whose LFS sha256 equals the registry's, checked 2026-10-03). The adapter comes from your own private copy.
- **Backups encrypted before they leave the VM**, with age. The private key is never on the VM.

Not solved here: SECURITY.md's open lawyer item on cross-border transfer still applies (Oracle India region, Firebase Auth in the US), and nobody has signed a DPA with Oracle.

## Capacity

Usage from BACKEND.md: ~100 MAU, ~400 cloud conversations a month. Assume 8 Eve replies per conversation plus one summary/memory call: about 110 calls a day. Most land in the 18:00–02:00 PKT evening window, so the busiest hour sees maybe 15–20.

One reply on 2 OCPUs: ~100 tokens at 5–8 tok/s is 13–20 s, plus 1–5 s to read the new part of the prompt when the cache hits. Call it **20 s of the whole machine per reply**. Two slots run side by side but share the same two cores, so the box finishes about one reply every 20 s however it is split: ~180 replies an hour at most.

- Busiest hour: ~20 replies needs ~400 s of 3,600 s, about 11% busy. Average wait in the queue is a second or two. **The pilot fits.**
- Someone actively chatting sends a message every 60–90 s, so each one keeps the box 20–35% busy. **2 people chatting at the same moment is fine, 3 gets slow, 4 or more and the queue grows without limit.** At BACKEND.md's usage that's rare: about 13 conversations of ~12 minutes spread over the 8-hour evening averages 0.3 at a time, and four overlapping happens a few times a year. If real usage is 5x that (every user chatting daily), four overlapping happens around 8% of the time in the peak.
- A cache miss is the slow case. A long conversation (3,000 tokens of history) whose cache got evicted re-reads all of it: 50–100 s before the first word. The 1.5 GB `--cache-ram` makes that rare at pilot scale.

What the app shows today: typing dots until the first token, then the reply streams in. If anything fails it shows "I'm having trouble replying right now. I'm still here, try again in a moment." (`eveFailureReply`). Rate limits (30 per 10 min, 300 a day per user) return 429.

**The timeouts don't fit a CPU server yet.** These need app and API changes (not made here, this branch only touches ops and docs):

1. The app's Dio client has `receiveTimeout: 30 s`. In Dio 5 that's the longest gap allowed between received bytes, including the wait for the first token. A reply that waits behind another one, or misses the cache, can go past 30 s before its first token. Dio then throws, `cloudChatStream` catches the `DioException` and **sends the same request again without streaming**. Eve now has two copies to answer, and the second one also has to finish within 30 s, so it fails too. Under load this doubles the work. Fixes: in the API, send an SSE comment line (`: wait`) every 10 s until the first token (the app already skips lines that don't start with `data: `). In the app, give `/inference/chat` a 90 s receive timeout, and only fall back to non-streaming on a 404/405, never on a timeout.
2. `ServerEveEngine.complete` (summaries, memory notes) is non-streaming with up to 300 tokens: 40–60 s on 2 OCPUs. That's over the app's 30 s and right at the API's own 60 s upstream timeout, so those calls will fail often on this box. Stream them, or cap them at ~120 tokens and raise both timeouts.
3. Nothing in the API caps how many requests wait on Eve; llama-server queues without limit. Add a small semaphore (e.g. 4 in flight) and return 503 with `Retry-After` past it, and have the app say "Eve is busy right now, give it a minute" instead of the generic error. After 10 s of typing dots, show "Eve is slower than usual right now" so nobody thinks it froze.
4. `TL_PROMPT_SHA256`/`TL_PROMPT_CHARS` (the prompt integrity check) would reject those `complete` calls, because they don't start with the Eve prompt. The compose file leaves the check off. Turning it on needs the API to exempt them, or a separate route.

**When to move to a paid GPU.** Watch llama-server's metrics (command under Day-2). Move when any of these holds for a week of evenings: `llamacpp:requests_deferred` above 0 most evenings, p95 time to first token over 15 s, more than ~3 conversations overlapping at peak, or more than ~40 daily active users. The next step is the existing Cloud Run L4 setup in `ops/serving/` (2–4 s replies, $10–40 a month at min 0 per BACKEND.md). The API, Postgres and Caddy can stay on the Oracle VM: point `TL_INFERENCE_BASE_URL` at the GPU service. That needs the private-access piece SECURITY.md asks for (Cloud Run identity token or a VPN), which the API doesn't do yet.

## Step by step: sign-up to first chat

You need: an Oracle Cloud account, a DNS name (a free DuckDNS subdomain is enough), and optionally free healthchecks.io and Better Stack accounts. Nothing else to buy.

### 1. Oracle Cloud account

Sign up at oracle.com/cloud/free. Pick the **home region** carefully, because it can't be changed and Always Free only works there: **India West (Mumbai)** or **India South (Hyderabad)** for latency to Pakistan. If A1 capacity is short in one, the other is just as close. Dubai or Jeddah are the next best. A card and a phone number are needed for verification. Don't upgrade to Pay-As-You-Go unless you hit capacity errors; if you do, set a budget with an alert at $1 straight away.

### 2. The VM

Compute → Instances → Create:

- Image: **Canonical Ubuntu 24.04** (the aarch64 build is picked automatically for A1).
- Shape: **VM.Standard.A1.Flex, 2 OCPU, 12 GB**. That uses the whole free allowance, so don't create another A1.
- Boot volume: 100 GB (200 GB total block storage is free).
- Networking: create a VCN with a public subnet and assign a public IPv4. Paste your SSH public key.

"Out of host capacity" means no free A1 hosts in that availability domain. Try another AD in the same region, retry later (early morning UTC tends to work), or upgrade to PAYG (still $0 for the same shape).

Then the VCN: Networking → your VCN → public subnet → Default Security List → Add Ingress Rules: TCP 80 and TCP 443 from `0.0.0.0/0`, and UDP 443 from `0.0.0.0/0`. Leave 22 as it is, or narrow it to your own IP. Open nothing else.

### 3. A DNS name

Free: sign in at duckdns.org, create e.g. `therapylink-pilot`, and set its IP to the VM's public IP. `TL_DOMAIN=therapylink-pilot.duckdns.org`.
Or with your own domain: an `A` record `api.yourdomain` → VM IP. Check with `nslookup` before the next step, because Caddy needs it to get the certificate.

### 4. Put the adapter somewhere the VM can fetch it

The base GGUF downloads from Hugging Face. The LoRA (`eve-sft-v16c-e2-lora-f16.gguf`, 97 MB) is ours, so don't make it public. Either:

- Oracle Object Storage: create a private bucket `eve-models`, upload `D:\dev\models\eve-sft-v16c-e2-lora-f16.gguf`, then ⋯ → Create Pre-Authenticated Request → Object, read-only, expiring tomorrow. Copy the URL (it is a credential, treat it like a password). Or:
- `scp D:\dev\models\eve-sft-v16c-e2-lora-f16.gguf ubuntu@VM_IP:/tmp/` and use `EVE_ADAPTER_PATH=/tmp/eve-sft-v16c-e2-lora-f16.gguf`.

### 4b. Put the Guardian bundle somewhere the VM can fetch it

Guardian is the crisis classifier that runs on the phone before every message (v1b: XLM-R int8, 287 MB in four files). The API serves it to the app at `https://TL_DOMAIN/guardian/<file>`, public, with the file's sha256 as its ETag, and the app checks every file against hashes baked into the build. A release build won't open Eve's chat until it has the model, so this step isn't optional for a pilot.

The four files are in `ml/runs/guardian-v1b-kaggle/runs/xlmr-base/bundle/` (gitignored): `guardian.int8.onnx`, `spm_vocab.json`, `config.json`, `thresholds.json`. Their sizes and sha256 are in `ml/releases/guardian-v1b/report.json`, which is what `get-models.sh` checks against. Either:

- Upload them to the same Object Storage bucket under `guardian-v1b/`, make a pre-authenticated request for that prefix (read, objects with prefix), and set `GUARDIAN_BASE_URL` to the URL ending in `/o/guardian-v1b/`. Or a private Hugging Face repo: `GUARDIAN_BASE_URL=https://huggingface.co/<org>/<repo>/resolve/main/` with `GUARDIAN_HF_TOKEN`. Or:
- `scp` the four files to `/tmp/guardian-v1b/` and set `GUARDIAN_SRC_DIR=/tmp/guardian-v1b`.

Setup puts them in `/srv/guardian` (`GUARDIAN_DIR`) and compose mounts that read-only into the API as `TL_GUARDIAN_DIR`. If neither source is set, setup warns and carries on, and `/guardian/*` answers 404.

### 5. Backup key (on your laptop)

```powershell
winget install FiloSottile.age
age-keygen -o D:\secure\tl-backup.key      # prints "Public key: age1..."
```

Keep `tl-backup.key` in your password manager and nowhere near the VM. The `age1...` public key goes into `.env` as `BACKUP_AGE_RECIPIENT`.

For off-VM copies, in Oracle: Identity → your user → Customer Secret Keys → Generate (gives an access key and secret), and Object Storage → create a private bucket `tl-backups`. Find your namespace under Tenancy details.

### 6. Run setup

```bash
ssh ubuntu@VM_IP
sudo mkdir -p /srv/therapylink && sudo chown ubuntu /srv/therapylink
git clone <repo-url> /srv/therapylink        # a read-only deploy key on the repo is the clean way
cd /srv/therapylink && git checkout <branch-or-tag>

sudo TL_DOMAIN=therapylink-pilot.duckdns.org \
     ACME_EMAIL=you@example.com \
     EVE_ADAPTER_URL='https://objectstorage.ap-mumbai-1.oraclecloud.com/p/.../eve-sft-v16c-e2-lora-f16.gguf' \
     GUARDIAN_BASE_URL='https://objectstorage.ap-mumbai-1.oraclecloud.com/p/.../o/guardian-v1b/' \
     BACKUP_AGE_RECIPIENT=age1... \
     ops/free/setup.sh
```

It takes 25–40 minutes, most of it the llama.cpp build and the 3.1 GB download. It is safe to re-run. At the end it prints the URL, one test reply's speed, whether `/guardian/config.json` serves the expected file, and the `flutter build` line with the Guardian flags filled in.

Then fill in what setup can't know, in `ops/free/.env`:

```bash
sudo nano /srv/therapylink/ops/free/.env
#   BACKUP_REMOTE_PATH=tl-backups/therapylink
#   RCLONE_CONFIG_TLBACKUP_ENDPOINT=https://<namespace>.compat.objectstorage.ap-mumbai-1.oraclecloud.com
#   RCLONE_CONFIG_TLBACKUP_REGION=ap-mumbai-1
#   RCLONE_CONFIG_TLBACKUP_ACCESS_KEY_ID=...   RCLONE_CONFIG_TLBACKUP_SECRET_ACCESS_KEY=...
#   HC_PING_URL=https://hc-ping.com/<uuid>     HC_BACKUP_PING_URL=https://hc-ping.com/<uuid>
sudo /srv/therapylink/ops/free/backup.sh        # first backup now; check it reached the bucket
```

Account deletion (`DELETE /me`) needs the Firebase service-account JSON. Copy it to the VM and re-run setup with `FIREBASE_SA_JSON=/path/to/sa.json`. Setup copies it to `/srv/therapylink-secrets/` readable only by the API's user. Delete the original afterwards.

### 7. Monitoring

- healthchecks.io: two checks. "therapylink-health", period 5 min, grace 10 min; "therapylink-backup", period 1 day, grace 2 h. Their ping URLs go in `.env` (above). The health check emails you when the API, Eve, the database, TLS, disk or memory goes wrong, and it restarts an unhealthy container once.
- Better Stack (or UptimeRobot): an HTTP monitor on `https://TL_DOMAIN/ready` every 3–5 min, from outside, for "the whole VM is gone". It never calls Eve, so it costs no model time.

### 8. The app

```powershell
cd app
$guardianHashes = (Get-Content ..\ml\releases\guardian-v1b\report.json | ConvertFrom-Json).dart_define
flutter build apk --release `
  --dart-define=TL_API_URL=https://therapylink-pilot.duckdns.org `
  --dart-define=TL_GUARDIAN_URL=https://therapylink-pilot.duckdns.org/guardian/ `
  --dart-define=$guardianHashes
```

`dart_define` in the report is the whole `TL_GUARDIAN_SHA256=guardian.int8.onnx:<hex>,spm_vocab.json:<hex>,...` value. Without it every download fails verification and the release app keeps chat paused, which is the point: a model nobody can vouch for doesn't get to decide who sees a helpline.

Check the route first: `curl -I https://therapylink-pilot.duckdns.org/guardian/guardian.int8.onnx` should give `200`, `content-length: 278239825` and an `etag` equal to the sha256 in the report.

Install it, sign in, open Eve. On Wi-Fi the app starts the Guardian download by itself; on mobile data it waits, and Settings → Safety check offers "Download on mobile data". Until the model is in, Eve shows "Safety check not ready" where the composer would be. Then send a message. On the VM, `sudo docker compose -f /srv/therapylink/ops/free/docker-compose.yml logs --tail 20 api` should show an `inference ok ... completion_tokens=...` line (token counts only, never text).

### 9. Measure Eve on the VM

```bash
cd /srv/therapylink
export TL_LLM_API_KEY="$(sudo sed -n 's/^TL_LLM_API_KEY=//p' ops/free/.env)"
sudo -E docker compose -f ops/free/docker-compose.yml run --rm --no-deps \
  -v "$PWD:/repo:ro" -e TL_LLM_API_KEY --entrypoint python api /repo/ops/free/bench.py --url http://eve:8080 --parallel 2
```

It prints prompt and generation tok/s per reply, and never the reply text. Put the numbers in the "Measured" section above.

## Day-2

```bash
cd /srv/therapylink && dc() { sudo docker compose -f ops/free/docker-compose.yml "$@"; }
dc ps                                   # health of every service
dc logs --tail 50 eve                   # load, hash check, slot activity (no prompt text)
tail /var/log/therapylink-health.log /var/log/therapylink-backup.log

# llama-server metrics (queue depth: llamacpp:requests_deferred; speed: llamacpp:predicted_tokens_seconds)
dc exec -T api python -c "import os,urllib.request as u;print(u.urlopen(u.Request('http://eve:8080/metrics',headers={'Authorization':'Bearer '+os.environ['TL_INFERENCE_API_KEY']})).read().decode())" | grep -E 'deferred|processing|tokens_seconds'

# New code
git pull && dc build api && dc run --rm api release && dc up -d api

# New adapter: add it to ml/registry.json (sha256, size, status) and set serve.adapter, commit, then on the VM
git pull && sudo EVE_ADAPTER_URL='...' ops/free/get-models.sh && dc build eve && dc up -d eve

# New Guardian release (v1c, say): put its four files where GUARDIAN_BASE_URL points, then on the VM
git pull && sudo GUARDIAN_RELEASE=guardian-v1c ops/free/get-models.sh && dc restart api
#   and rebuild the app with TL_GUARDIAN_SHA256 from ml/releases/guardian-v1c/report.json. File names don't change.
#   Responses carry Cache-Control max-age=3600, so a cache in front may serve the old files for up to an hour,
#   and old app builds stop installing once the old files are gone (their hashes are pinned).

# Restore drill (monthly, on a scratch DB or a second machine with the private key)
age -d -i tl-backup.key tl-<stamp>.dump.age > tl.dump
dc exec -T postgres pg_restore -U therapylink -d therapylink --clean --if-exists < tl.dump
```

Rotate `TL_LLM_API_KEY` monthly: put a new value in `.env`, then `dc up -d api eve` (both read it, so they change together). Rotate `POSTGRES_PASSWORD` quarterly with `ALTER USER` and `.env`.

Oracle's idle reclaim: the VM is "idle" only if CPU, network and memory are all under 20% for 7 days. Eve's weights are loaded into RAM (`LLAMA_ARG_LOAD_MODE=none`), about 3.3 GB of 12 (27%), so memory alone keeps it above the line even in a quiet week. Don't turn that off to save RAM.

## Not done or not checked

- Nothing was deployed and no image was built. Docker Desktop's disk on this machine lives on C:, so builds weren't run here. Checked: `docker compose config` renders for both the default (caddy + localdb) and the tunnel + Neon variants; shellcheck finds no warnings in the four scripts; `get-models.sh` passed against the real files in `D:\dev\models` and threw away a wrong file; `bench.py` ran the measurements above.
- llama.cpp b10955 has no prebuilt image on ghcr.io. The nearest tags are b10951 and b10964, so `Dockerfile.eve-cpu` builds the tagged source and checks the commit (2f539596c, same as the local build). The same gap means **`ops/serving/Dockerfile.gpu` (`server-cuda-b10955`) won't pull either**. Pick b10964 there and re-run the smoke test, or build from source the same way.
- The ARM speed is an estimate until step 9 runs on the VM.
- The Guardian route and the app's download were tested with small stand-in files (API tests, a simulated `get-models.sh` run, Dart tests with fake files and network). Nobody has fetched the real 287 MB bundle through Caddy to a phone yet, so resume over a flaky mobile connection, and how long the first download takes, are unmeasured.
- v16c-e2 has no clinician sign-off. The stack runs with `TL_ENV=staging` and `TL_LLM_ALLOW_UNAPPROVED=1`. With `TL_ENV=prod`, Eve refuses to start until `approved_by` is filled in the registry. That's on purpose, and it is the clinician's call, not ops'.
- The timeout and busy-handling fixes under Capacity are app/API work for someone else.
- Oracle could cut Always Free again, as it did in 2026 (2 OCPU / 12 GB is the current allowance, and third-party reports say instances over the new limit get stopped or deleted [3]).

## Sources (fetched 2026-10-03)

1. Oracle, Always Free resources (© 2026): https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
2. Oracle, Free Tier overview (© 2026): https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm
3. Linuxiac, 2026-06-14: https://linuxiac.com/oracle-quietly-cuts-free-tier-ampere-a1-resources-in-half/ ; Terminalbytes, June 2026: https://terminalbytes.com/oracle-cloud-free-tier-changes-2026/
4. Oracle regions (© 2026): https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm
5. HF Spaces overview / GPU upgrades (undated): https://huggingface.co/docs/hub/spaces-overview , https://huggingface.co/docs/hub/spaces-gpus
6. HF pricing: https://huggingface.co/pricing
7. HF content policy (2025-04-10): https://huggingface.co/content-policy
8. HF ZeroGPU (undated): https://huggingface.co/docs/hub/spaces-zerogpu
9. HF Inference Providers pricing (undated): https://huggingface.co/docs/inference-providers/pricing
10. Modal pricing (© 2026): https://modal.com/pricing
11. Modal regions (undated): https://modal.com/docs/guide/region-selection
12. Google Cloud free features (2026-09-30): https://docs.cloud.google.com/free/docs/free-cloud-features
13. Cloud Run GPUs (2026-09-30): https://docs.cloud.google.com/run/docs/configuring/services/gpu (L4 price from a search snippet of https://cloud.google.com/run/pricing, recheck)
14. Azure free account (2026-03-25): https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/avoid-charges-free-account ; students: https://azure.microsoft.com/en-us/free/students
15. AWS Free Tier: https://aws.amazon.com/free/ ; t4g.small trial to 2026-12-31: https://dev.classmethod.jp/en/articles/ec2-t4g-small-free-tier-2026/
16. Colab FAQ (undated): https://research.google.com/colaboratory/faq.html ; Kaggle terms: https://www.kaggle.com/terms
17. Workers AI pricing (2026-10-01): https://developers.cloudflare.com/workers-ai/platform/pricing/
18. Workers AI LoRA (2026-04-21): https://developers.cloudflare.com/workers-ai/features/fine-tunes/loras/ ; deprecations (2026-05-08): https://developers.cloudflare.com/changelog/post/2026-05-08-planned-model-deprecations/
19. Groq LoRA: https://console.groq.com/docs/lora
20. Together LoRA: https://docs.together.ai/docs/lora-inference
21. Fireworks LoRA: https://docs.fireworks.ai/fine-tuning/deploying-loras
22. OpenRouter private models: https://openrouter.ai/docs/guides/routing/private-models
23. Gemma on the Gemini API: https://ai.google.dev/gemma/docs/core/gemma_on_gemini_api
24. Gemini API terms (2026-04-28): https://ai.google.dev/gemini-api/terms
25. Hetzner CAX21 after the June 2026 increase (secondary): https://bex.co/blog/2026/08/21/hetzner-arm-cax-cost-per-vcpu-recheck , https://www.bitdoze.com/hetzner-cloud-cost-optimized-plans/
26. Neon pricing: https://neon.com/pricing ; regions: https://neon.com/docs/introduction/regions
27. Supabase pricing: https://supabase.com/pricing
28. Render free: https://render.com/docs/free
29. Fly.io pricing: https://docs.fly.io/about/pricing
30. Railway pricing: https://railway.com/pricing
31. Koyeb pricing: https://www.koyeb.com/pricing
32. Cloudflare Tunnel (2026-08-04): https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/
33. Cloudflare connection limits, 125 s proxy read timeout (2026-07-23): https://developers.cloudflare.com/fundamentals/reference/connection-limits/
34. R2 pricing (2026-10-01): https://developers.cloudflare.com/r2/pricing/
35. Backblaze B2 pricing: https://www.backblaze.com/cloud-storage/pricing
36. UptimeRobot pricing (2026-08-10): https://uptimerobot.com/pricing/
37. Better Stack pricing: https://betterstack.com/pricing
38. healthchecks.io pricing: https://healthchecks.io/pricing/
39. A1 llama.cpp benchmark (2025-11-12): https://tiffena.me/blog/ai-infrastructure/benchmark-cpu-only-llm-inference-oracle-ampere-a1-llama.cpp-ollama-docker/ ; repack kernels: https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cpu/repack.cpp
