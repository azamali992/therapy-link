# api/

FastAPI gateway. Verifies Firebase ID tokens, owns the consent model, scores assessments server-side, and proxies the optional cloud inference path.

**What it deliberately does not store:** chat messages. Conversations stay on the device. The server sees assessments, text-free mood points, journal entries, and summaries the patient chose to share.

## Run locally

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -e ".[dev]"
copy .env.example .env          # sqlite + dev auth bypass for local work
.venv\Scripts\uvicorn therapylink_api.main:app --reload
```

With `TL_DEV_AUTH_BYPASS=true`, send `X-Dev-Uid: anything` instead of a Firebase token.
The API refuses to start with the bypass (or `TL_DEV_AUTO_VERIFY_CLINICIANS`) when
`TL_ENV` is `staging` or `prod`, or when the database is not SQLite.

## Tests

```powershell
.venv\Scripts\python -m pytest
```

Set `TL_TEST_DATABASE_URL=postgresql+asyncpg://...` to also run the Postgres-only tests
(access-log append-only rules, migration round-trip). Point it at a **scratch** database —
the suite truncates every table after each test.

`tests/test_consent.py` is the authorization contract: clinicians see nothing until verified
and until they accept the patient's link request, and then only the sections each patient
switched on, with journal entries and summaries from the link's `shared_from` onwards.
`tests/test_migrations.py` builds the schema from alembic and fails if it drifts from the models.
`tests/test_hardening.py` covers v3 security additions: rate limiting, App Check, admin endpoints,
inference hardening, and structured logging.

## Endpoints

| Area | Routes |
|---|---|
| me | `GET/PATCH/DELETE /me` (delete: 204), `GET /me/export`, `PUT /me/consent`, `GET /me/access-log`, `POST/DELETE /me/clinician`, `POST /me/clinician/code` |
| assessments | `POST /assessments` (server-scored PHQ-9 / GAD-7), `GET /assessments` |
| mood | `POST /mood/batch` (≤500 points; `client_id` makes resends idempotent), `GET /mood/trend` |
| journal | `GET/POST /journal`, `PUT/DELETE /journal/{id}` |
| summaries | `POST/GET /summaries` |
| care | `GET/POST /care/links`, `PATCH /care/links/{id}/consent`, `DELETE /care/links/{id}` |
| clinician | `GET /clinician/requests`, `POST /clinician/requests/{id}/accept\|decline`, `GET /clinician/patients`, `GET /clinician/patients/{uid}` |
| inference | `POST /inference/chat` → llama-server; streaming with `stream: true`; 503 if not configured; 429 past per-uid limits |
| admin | `POST /admin/clinicians/{uid}/verify`, `POST /admin/clinicians/{uid}/revoke` — requires Firebase token with `admin: true` custom claim |
| ops | `GET /health` (liveness), `GET /ready` (runs `SELECT 1`) |

Every response carries `X-Request-ID`. Logs are structured JSON; bodies are never logged; uids
are hashed in logs with `TL_LOG_UID_SALT`.

## Clinician verification

Use the admin API instead of the laptop script:

```sh
# Approve
curl -X POST https://api.example.com/admin/clinicians/<uid>/verify \
     -H "Authorization: Bearer <admin-firebase-token>"

# Revoke
curl -X POST https://api.example.com/admin/clinicians/<uid>/revoke \
     -H "Authorization: Bearer <admin-firebase-token>"
```

The Firebase token must carry the custom claim `admin: true` (set via Firebase Admin SDK or
the Firebase console → Authentication → Users → Edit → Custom claims).

The legacy script `scripts/verify_clinician.py` still works for local dev with SQLite but
requires direct database access — not safe for production.

## Environment variables

All variables are prefixed `TL_`. See `.env.example` for defaults.

| Variable | Required | Notes |
|---|---|---|
| `TL_ENV` | — | `dev` (default) / `staging` / `prod`. Staging and prod block the dev bypass. |
| `TL_DATABASE_URL` | prod | SQLite (dev) or `postgresql+asyncpg://…` |
| `TL_DATABASE_POOLED` | — | `true` behind Neon `-pooler` / PgBouncer. Auto-detected from URL if unset. |
| `TL_FIREBASE_PROJECT_ID` | — | Firebase project ID. Default: `therapylink69`. |
| `TL_FIREBASE_SERVICE_ACCOUNT_JSON` | prod (account deletion) | Path to service-account JSON. Not needed for token verification. |
| `TL_INFERENCE_BASE_URL` | — | OpenAI-compatible llama-server base URL (e.g. `https://eve.example.com`). |
| `TL_INFERENCE_API_KEY` | if URL set | Bearer key for the model server. Required when URL is set. |
| `TL_INFERENCE_MODEL` | — | Model name forwarded to llama-server. Default: `eve-e4b`. |
| `TL_INFERENCE_MAX_TOKENS` | — | Hard cap on tokens forwarded per request. Default: `1024`. |
| `TL_INFERENCE_RATE_CAPACITY` | — | Short-window per-uid burst for `/inference/chat`. Default: `30`. |
| `TL_INFERENCE_RATE_PERIOD_S` | — | Short-window period in seconds. Default: `600` (10 min). |
| `TL_INFERENCE_DAILY_CAP` | — | Hard daily per-uid cap for `/inference/chat`. Default: `300`. |
| `TL_WRITE_RATE_CAPACITY` | — | Mutating requests (POST/PUT/PATCH/DELETE) per uid per minute. Default: `60`. |
| `TL_REDIS_URL` | — | Redis URL for shared rate-limit state across workers. In-memory (per-worker) if unset. |
| `TL_APP_CHECK_REQUIRED` | — | `true` to require a valid Firebase App Check token on mutating and inference routes. |
| `TL_PROMPT_SHA256` | — | SHA-256 hex of the expected system prompt. Set to reject requests with the wrong prompt. |
| `TL_CORS_ORIGINS` | — | JSON array of allowed CORS origins. |
| `TL_LOG_UID_SALT` | prod | Secret salt for uid hashing in logs. **Must be changed from the default in prod/staging.** |
| `TL_DEV_AUTH_BYPASS` | dev only | Accept `X-Dev-Uid` header instead of a Firebase token. Blocked in staging/prod. |
| `TL_DEV_AUTO_VERIFY_CLINICIANS` | dev only | Approve clinicians instantly. Blocked in staging/prod. |

## Deploy

The image is host-agnostic. Free tier: Hugging Face Spaces (Docker, port 7860). Recommended for
pilot: Cloud Run. Database: Neon Postgres — set `TL_DATABASE_URL=postgresql+asyncpg://…`,
`TL_ENV=prod`, and `TL_LOG_UID_SALT` to a secret value.

The image has two entry-point commands:

```sh
docker build -t tl-api api/
docker run --env-file api/.env tl-api release   # alembic upgrade head, then exits (run before traffic shift)
docker run --env-file api/.env -p 7860:7860 tl-api   # default: serve
```

Run `release` as a Cloud Run Job (or CD step) **before** shifting traffic, never from app startup —
multiple instances racing to migrate would corrupt the schema.

Rate limits are per-worker in-memory unless `TL_REDIS_URL` is set, in which case state is shared
across workers via Redis sliding windows.
