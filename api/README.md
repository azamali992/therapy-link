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

With `TL_DEV_AUTH_BYPASS=true`, send `X-Dev-Uid: anything` instead of a Firebase token. The API refuses to start with it (or `TL_DEV_AUTO_VERIFY_CLINICIANS`) on when `TL_ENV=prod` or the database isn't sqlite. It also refuses `TL_INFERENCE_BASE_URL` without `TL_INFERENCE_API_KEY`, so a local `.env` pointing at llama-server needs the key too.

## Tests

```powershell
.venv\Scripts\python -m pytest
```

`tests/test_consent.py` is the authorization contract: clinicians see nothing until verified and until they accept the patient's link request, and then only the sections each patient switched on, with journal entries and summaries from the link's `shared_from` onwards. `tests/test_migrations.py` builds the schema from alembic and fails if it drifts from the models.

## Endpoints

| Area | Routes |
|---|---|
| me | `GET/PATCH/DELETE /me` (delete: 204, erases server data and the Firebase user; the uid's still-valid tokens then get 401), `GET /me/export`, `PUT /me/consent` `{consent_version}`, `GET /me/access-log`, `POST/DELETE /me/clinician`, `POST /me/clinician/code` |
| assessments | `POST /assessments` (server-scored PHQ-9 / GAD-7, records `locale`), `GET /assessments` |
| mood | `POST /mood/batch` (≤500 points; optional `client_id` makes resends idempotent), `GET /mood/trend?days=&tz=Asia/Karachi` |
| journal | `GET/POST /journal`, `PUT/DELETE /journal/{id}` |
| summaries | `POST/GET /summaries` |
| care | `GET/POST /care/links` (invite code only; starts `pending`), `PATCH /care/links/{id}/consent`, `DELETE /care/links/{id}` |
| clinician | `GET /clinician/requests`, `POST /clinician/requests/{id}/accept\|decline`, `GET /clinician/patients`, `GET /clinician/patients/{uid}?tz=` (every read is written to the access log) |
| inference | `POST /inference/chat` → llama-server, 503 if not configured, 429 past the per-uid limit |
| ops | `GET /health` (liveness), `GET /ready` (runs `SELECT 1`) |

Every response carries `X-Request-ID`; server-side log lines for failures include it, and error bodies stay generic.

## Deploy

The image is host-agnostic. Free options without a card: Hugging Face Spaces (Docker, port 7860). With billing enabled: Cloud Run. Database: Neon Postgres free tier — set `TL_DATABASE_URL=postgresql+asyncpg://…` and `TL_ENV=prod`. Verifying sign-ins needs only `TL_FIREBASE_PROJECT_ID`, but account deletion also removes the Firebase user, which needs Google credentials: on Spaces, store the service-account JSON as a secret file and point `TL_FIREBASE_SERVICE_ACCOUNT_JSON` at it; Cloud Run's own service account works if it has the Firebase Authentication Admin role.

The image has two commands. Run `release` once per deploy, before traffic moves (a Cloud Run job or a CD step), to apply migrations; the default `serve` starts uvicorn with `--proxy-headers` and `WEB_CONCURRENCY` workers.

```sh
docker build -t tl-api api/
docker run --env-file api/.env tl-api release   # alembic upgrade head, then exits
docker run --env-file api/.env -p 7860:7860 tl-api
```

Behind Neon's `-pooler` host, asyncpg's statement caches are switched off automatically (`TL_DATABASE_POOLED` overrides the guess). The chat rate limit lives in process memory, so it applies per worker and resets on restart; swap `app.state.chat_limiter` for a shared store before running more than one instance.
