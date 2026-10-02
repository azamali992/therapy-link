# TherapyLink v2 — Backend Architecture Proposal

Reviewer/author: backend & database architect
Date: 2026-10-03
Branch: rebuild/v2

---

## Part 1 — Current-State Inventory

### 1.1 API Routes

All routes are under the FastAPI application mounted in `api/therapylink_api/main.py`.
Auth legend: **Firebase JWT** = `Authorization: Bearer <token>` verified by Firebase Admin SDK;
**Dev bypass** = `X-Dev-Uid: <uid>` accepted only when `TL_DEV_AUTH_BYPASS=true` (never in prod);
**clinician** = verified clinician role required (`verified_at IS NOT NULL`).

#### /me — account & profile

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| GET | /me | Firebase JWT | Return caller's profile (MeOut) | recovered |
| PATCH | /me | Firebase JWT | Update display_name or locale | recovered |
| DELETE | /me | Firebase JWT | Erase all data + Firebase account, tombstone uid | recovered |
| GET | /me/export | Firebase JWT | GDPR-style dump of all server rows for this uid | recovered |
| GET | /me/access-log | Firebase JWT | Show which clinicians viewed patient's data and when | rewritten (was missing) |
| PUT | /me/consent | Firebase JWT | Record consent version and timestamp | recovered |
| POST | /me/clinician | Firebase JWT | Register or update clinician profile; generates invite code | recovered |
| POST | /me/clinician/code | Firebase JWT (clinician) | Rotate invite code | rewritten (was missing) |
| DELETE | /me/clinician | Firebase JWT | Revert role to patient (profile kept for re-verification) | recovered |

#### /care — patient-side care links

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| GET | /care/links | Firebase JWT | List the caller's care links | recovered |
| POST | /care/links | Firebase JWT | Initiate link by typing clinician's invite code | rewritten (was uid-based) |
| PATCH | /care/links/{id}/consent | Firebase JWT | Flip per-section share flags | recovered |
| DELETE | /care/links/{id} | Firebase JWT | Revoke a link and clear share flags | recovered |

#### /clinician — clinician-side care management

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| GET | /clinician/requests | Firebase JWT (clinician) | List pending patient requests, oldest first | rewritten (was missing) |
| POST | /clinician/requests/{id}/accept | Firebase JWT (clinician) | Accept request; sets status=active and shared_from=now | rewritten (was missing) |
| POST | /clinician/requests/{id}/decline | Firebase JWT (clinician) | Decline request; clears flags, sets status=revoked | rewritten (was missing) |
| GET | /clinician/patients | Firebase JWT (clinician) | Caseload with latest assessments and attention flags; logs read | recovered |
| GET | /clinician/patients/{uid} | Firebase JWT (clinician) | Full per-section overview gated by consent; logs read | recovered |

#### /assessments

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| POST | /assessments | Firebase JWT | Submit PHQ-9, GAD-7, or BDI-II answers; server scores and bands | recovered |
| GET | /assessments | Firebase JWT | List caller's assessments newest-first, with delta vs previous | recovered |

#### /mood

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| POST | /mood/batch | Firebase JWT | Upsert batch of mood points (idempotent via client_id) | recovered |
| GET | /mood/trend | Firebase JWT | Daily valence averages for a rolling window | recovered |

#### /journal and /summaries

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| GET | /journal | Firebase JWT | List journal entries newest-first | recovered |
| POST | /journal | Firebase JWT | Create journal entry | recovered |
| PUT | /journal/{id} | Firebase JWT | Replace journal entry body | recovered |
| DELETE | /journal/{id} | Firebase JWT | Delete journal entry | recovered |
| POST | /summaries | Firebase JWT | Upload a device-generated conversation summary | recovered |
| GET | /summaries | Firebase JWT | List shared summaries newest-first | recovered |

#### /inference

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| POST | /inference/chat | Firebase JWT | Proxy to llama-server (OpenAI-compatible); rate-limited by token bucket | recovered |

#### Platform

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | /health | none | Liveness: returns {"status":"ok"} |
| GET | /ready | none | Readiness: checks DB SELECT 1 and inference reachability |

#### Still missing (confirmed from APK analysis, not yet implemented)

- `/guardian` — Guardian/ONNX crisis classifier endpoint referenced in `onnx_guardian.dart`. Not implemented anywhere in the backend. On-device model is the primary path; whether the server needs a fallback endpoint is an open design decision (see Part 2).

---

### 1.2 Database Schema

Engine: SQLAlchemy 2.0 async ORM. Dev: aiosqlite (SQLite). Prod: asyncpg (Postgres).

#### Table: users

| Column | Type | Notes |
|--------|------|-------|
| uid | String(128) PK | Firebase UID |
| email | String(320) nullable | Copied from token on sign-in |
| email_verified | Boolean | Copied from token; required for auto-verify in dev |
| display_name | String(120) nullable | |
| role | Enum(patient,clinician,admin) | Default: patient |
| locale | String(8) | Default: en; only en and ur accepted by API |
| consent_version | String(32) nullable | e.g. "2026-09" |
| consent_accepted_at | DateTime(tz) nullable | UTC; not updated on re-accept of same version |
| created_at | DateTime(tz) | server_default=NOW() |

#### Table: clinician_profiles

| Column | Type | Notes |
|--------|------|-------|
| uid | String(128) PK FK→users(uid) CASCADE | |
| license_no | String(64) nullable | PMDC number; changing it clears verified_at |
| specialty | String(120) nullable | |
| bio | Text nullable | Max 2000 chars enforced by Pydantic |
| verified_at | DateTime(tz) nullable | NULL = not yet approved |
| invite_code | String(12) unique index nullable | 6-char alphanumeric from ALPHABET; generated on first /me/clinician call |
| created_at | DateTime(tz) | server_default=NOW() |

#### Table: care_links

| Column | Type | Notes |
|--------|------|-------|
| id | String(32) PK | uuid4().hex |
| patient_uid | String(128) FK→users CASCADE index | |
| clinician_uid | String(128) FK→users CASCADE index | |
| status | Enum(pending,active,revoked) | Default: pending |
| share_assessments | Boolean | Default: false |
| share_mood_trend | Boolean | Default: false |
| share_summaries | Boolean | Default: false |
| share_journal | Boolean | Default: false |
| shared_from | DateTime(tz) nullable | Set when clinician accepts; data before this is hidden |
| created_at | DateTime(tz) | server_default=NOW() |
| updated_at | DateTime(tz) | server_default + onupdate=NOW() |
| UNIQUE | (patient_uid, clinician_uid) | name: uq_care_pair |

#### Table: assessments

| Column | Type | Notes |
|--------|------|-------|
| id | String(32) PK | uuid4().hex |
| patient_uid | String(128) FK→users CASCADE index | |
| instrument | Enum(phq9,gad7,bdi2) | |
| answers | JSON | list[int] |
| score | Integer | |
| band | String(32) | e.g. "moderate", "severe" |
| flags | JSON | list[str]; includes "suicidal_ideation_item" if PHQ-9 item 9 > 0 |
| locale | String(8) nullable | en or ur; null for pre-locale records |
| taken_at | DateTime(tz) index | server_default=NOW() |

#### Table: mood_points

| Column | Type | Notes |
|--------|------|-------|
| id | String(32) PK | uuid4().hex |
| patient_uid | String(128) FK→users CASCADE index | |
| valence | Integer | -2 to +2 |
| emotion | String(32) nullable | Classifier label |
| source | String(16) | chat, journal, or manual |
| client_id | String(64) nullable | App-side dedup key |
| recorded_at | DateTime(tz) index | |
| UNIQUE | (patient_uid, client_id) | name: uq_mood_client_id; prevents double-counting retried batches |

#### Table: journal_entries

| Column | Type | Notes |
|--------|------|-------|
| id | String(32) PK | uuid4().hex |
| patient_uid | String(128) FK→users CASCADE index | |
| title | String(200) nullable | |
| body | Text | Max 20000 chars enforced by Pydantic |
| mood | Integer nullable | Snapshot valence at time of writing |
| created_at | DateTime(tz) index | server_default=NOW() |
| updated_at | DateTime(tz) | server_default + onupdate=NOW() |

#### Table: shared_summaries

| Column | Type | Notes |
|--------|------|-------|
| id | String(32) PK | uuid4().hex |
| patient_uid | String(128) FK→users CASCADE index | |
| kind | String(16) | weekly or session |
| content | Text | Max 8000 chars enforced by Pydantic |
| period_start | DateTime(tz) nullable | |
| period_end | DateTime(tz) nullable | |
| created_at | DateTime(tz) index | server_default=NOW() |

#### Table: access_log

| Column | Type | Notes |
|--------|------|-------|
| id | String(32) PK | uuid4().hex |
| clinician_uid | String(128) index | Not FK; tombstone must survive account deletion |
| patient_uid | String(128) index | Not FK; same reason |
| action | String(16) | overview or caseload |
| sections | JSON | list[str]; which sections were actually served |
| at | DateTime(tz) index | Python-side default (microseconds) + server_default=NOW() |

Postgres append-only enforcement: add a RULE or row-level trigger blocking UPDATE and DELETE on this table before going to production. On SQLite, the application must not issue those statements.

#### Table: erased_accounts

| Column | Type | Notes |
|--------|------|-------|
| uid_sha256 | String(64) PK | SHA-256 of uid; never stores the uid itself |
| erased_at | DateTime(tz) | server_default=NOW() |

Every auth path checks this table before upsert-or-returning the user row. A still-valid Firebase token for a deleted account gets 401 "account deleted".

---

### 1.3 Migrations (Alembic)

Chain is linear. All use `render_as_batch=True` for SQLite column-add compatibility.

| # | Revision ID | Description |
|---|-------------|-------------|
| 1 | 4d9a35f16344 | Initial schema: users, clinician_profiles, care_links, assessments, mood_points, journal_entries, shared_summaries |
| 2 | 7b1c2d3e4f50 | clinician_profiles.invite_code (String 12, unique, index) |
| 3 | a1c3e5f70912 | users.consent_version, users.consent_accepted_at |
| 4 | a7c9e1f36578 | BDI-II removal (dropped from instrument enum; rows preserved) |
| 5 | b2d4f6a81023 | access_log table |
| 6 | b8d0f2a47689 | erased_accounts table |
| 7 | c3e5a7b92134 | care_links.shared_from |
| 8 | d4f6b8c03245 | mood_points.client_id, unique constraint uq_mood_client_id |
| 9 | e5a7c9d14356 | assessments.locale |
| 10 | f6b8d0e25467 | users.email_verified |

`alembic upgrade head` runs clean on SQLite (confirmed). `alembic downgrade -1` from head also tested. Postgres path tested by the test suite when `TL_TEST_DATABASE_URL` points at a Postgres instance.

---

### 1.4 Legacy Firestore (v1 app)

The legacy Flutter app at `D:\therapylink\legacy\` used Firebase Firestore directly from the client. The security rules (`legacy/firestore.rules`) deny all reads and writes globally (set to `if false`), meaning the legacy backend was already locked down at the time of the v2 rebuild.

Collections observed in `legacy/lib/` code:

| Collection | Purpose |
|------------|---------|
| users | User profiles |
| professionals | Clinician/therapist profiles |
| chats | Conversation sessions |
| messages | Individual chat messages (subcollection under chats) |
| journalEntries | Journal text (subcollection under users) |
| mood_logs | Mood readings |
| summaries | Conversation summaries |
| appointments | Scheduled sessions |
| sentiments | Sentiment/emotion records |
| artWorks | Artistic expression entries |
| posts | Community feed posts |
| favorites | Saved posts/resources |
| feedback | User feedback submissions |
| logs | General event logs |

None of these collections are migrated to v2. The v2 schema covers the mental-health core (assessments, mood, journal, summaries, care links). Community feed, appointments, and artistic expression are not implemented in v2.

---

### 1.5 Device vs Server Data

| Data | Location | Notes |
|------|----------|-------|
| Eve conversation history | Device (drift local DB) | Never sent to server; no chat table exists |
| Memory notes (extracted by Eve) | Device | Never sent to server |
| Rolling conversation summary | Device | Only the weekly/session digest is sent to /summaries if the patient opts in |
| PHQ-9/GAD-7 answers and scores | Server | Submitted via /assessments; scored server-side |
| Mood valence + emotion label | Server | No free text; classifier output only |
| Journal entries | Server | Full text stored in Postgres; not encrypted at rest at the DB layer |
| Shared conversation summaries | Server | Only what the patient explicitly uploads |
| Care link state and consent flags | Server | |
| Clinician profile | Server | |
| Consent version and timestamp | Server | |
| Access log | Server | Append-only; visible to patient via /me/access-log |
| Firebase auth token | Device | |
| Guardian (ONNX crisis model) | Device | Downloaded on-demand or bundled; never runs server-side |
| Crisis helpline sheet | Device (compiled in) | No network needed |

---

## Part 2 — New Backend Proposal

### 2.1 Framework Recommendation: Keep FastAPI

Keep FastAPI. The case against switching:

- The v2 codebase is already written, tested (108 passing), and the route/service/repository separation is clean.
- The async SQLAlchemy + Pydantic v2 stack is a known quantity for this team.
- Django REST Framework adds ORM and admin but the admin is not needed yet and the ORM would be a rewrite.
- Node/NestJS or Go would be a full rewrite with no safety return in the current timeline.

What to change within the FastAPI stack for production readiness:

1. Replace `firebase_admin.id_token` verification with `firebase_admin.auth.verify_id_token` (caches public keys, avoids a Google fetch on every request).
2. Add `slowapi` + Upstash Redis for distributed rate limiting (see Section 2.5).
3. Replace the Dockerfile's `--workers 1` with `WEB_CONCURRENCY` from env; pin the base image to a digest.
4. Copy `alembic/` and `alembic.ini` into the image; run migrations as a pre-traffic release step, not inside the app.
5. Add a `TL_ENV` setting (`dev` | `staging` | `prod`). Refuse to start with `dev_auth_bypass=true` or `dev_auto_verify_clinicians=true` when `env=prod`.

---

### 2.2 Authentication

Keep Firebase Auth as the identity provider. It handles Google/email sign-in, token refresh, and session revocation. The server never stores passwords.

Changes needed before production:

- Use `firebase_admin.auth.verify_id_token` instead of `google.oauth2.id_token.verify_firebase_token`. The Admin SDK caches Google's public key bundle; the current code fetches it on every call.
- Add Firebase App Check: verify the App Check token in a FastAPI dependency. Enable Play Integrity attestation on Android. This ensures only the real APK can call the API, blocking credential-stuffing tools.
- The `X-Dev-Uid` bypass must be gated on `TL_ENV != prod`. Add a startup assertion and a test that proves it.
- For the closed pilot: clinician verification remains a manual script (`scripts/verify_clinician.py`). Before public launch, replace it with an admin-role endpoint so no one needs production DB credentials on a laptop.

---

### 2.3 Postgres Schema for Production

The SQLAlchemy models are already production-quality. The Alembic chain runs to head. Additions needed before going live:

**Append-only enforcement on access_log:**
```sql
CREATE RULE no_update_access_log AS ON UPDATE TO access_log DO INSTEAD NOTHING;
CREATE RULE no_delete_access_log AS ON DELETE TO access_log DO INSTEAD NOTHING;
```
Add this as migration revision 11 after the current chain.

**Row-level security for clinician reads:**
Consider enabling RLS on `assessments`, `mood_points`, `journal_entries`, and `shared_summaries` so that even a compromised application credential cannot read data across patients. The current approach (application-layer consent checks) is correct but defence-in-depth at the DB layer costs little.

**Full-text index for future clinician search:**
```sql
CREATE INDEX idx_users_display_name_trgm ON users USING GIN (display_name gin_trgm_ops);
```
Not urgent; add when a clinician directory is built.

**Neon-specific connection pool settings:**
When using the Neon pooled endpoint (PgBouncer), asyncpg prepared statements cause "prepared statement already exists" errors. Set:
```
connect_args={"statement_cache_size": 0, "prepared_statement_cache_size": 0}
pool_size=5, max_overflow=5
```
Cap Cloud Run max instances to keep total connections under the Neon Launch plan limit (50).

---

### 2.4 API Surface for New Features

Features confirmed from the product brief that have no backend route yet:

| Feature | Route(s) to add | Notes |
|---------|-----------------|-------|
| Guardian fallback | POST /guardian/classify | Optional: only if on-device model is unavailable. Body: {text: str (max 512 chars)}. Response: {crisis: bool, confidence: float}. Rate-limit heavily; never log text. |
| Clinician directory search | GET /clinician/search?q= | Returns verified clinicians by name/specialty. Required for making invite codes discoverable in-app. |
| Admin: verify clinician | POST /admin/clinicians/{uid}/verify | Replaces the laptop script; requires role=admin. |
| Admin: revoke clinician | POST /admin/clinicians/{uid}/revoke | Clears verified_at. |
| Timezone-aware mood trend | GET /mood/trend?tz=Asia/Karachi | Already accepts tz param; default currently Asia/Karachi. No schema change needed. |
| Appointment booking | POST /appointments, GET /appointments | Not in v2 scope. Add only after the care link workflow is validated in pilot. |

For the Guardian fallback endpoint specifically: the crisis path must never depend on the network. If you add this endpoint, the app must call it only as a supplement to the on-device union (ONNX + keyword), never as a replacement. The endpoint should time out after 2 seconds and the app must treat a timeout as "no crisis signal from server" and fall through to the on-device result.

---

### 2.5 Rate Limiting and Abuse Prevention

Current state: token bucket in-memory rate limiter on `/inference/chat`. In-memory does not survive restarts and does not work across multiple Cloud Run instances.

Production plan:

- Replace in-memory bucket with `slowapi` backed by Upstash Redis (pay-as-you-go, ~$0–10/month at pilot scale).
- Limits:
  - `/inference/chat`: 30 requests per 10 minutes, 300 per day per uid. Return 429 with `Retry-After`. The app must say "cloud Eve is busy; on-device mode still works". Crisis path is unaffected.
  - Write routes: 60 per minute per uid.
  - Unauthenticated traffic: per-IP limit at the edge (Cloud Armor or Cloudflare).
- Require `TL_INFERENCE_API_KEY` whenever `inference_base_url` is set. The llama-server must be started with `--api-key`. Rotate monthly.
- Cap `content` at 4,000 chars, `messages` at 60, and total chars in the conversation at 16,000. These limits are already in `schemas.py`; verify they are enforced in the proxy handler.

---

### 2.6 Model-Serving Architecture (Eve)

The fine-tuned Eve model (v14 LoRA, Gemma 4 E2B base) must be the default on-device model before any patient uses the app. Stock Gemma 4 E2B passes 7/24 safety checks; v14 passes 18/24. Do not ship stock Gemma to patients.

**On-device path (primary, always available):**
- Export v14 (or the latest gated version) to `.litertlm` using `litetune convert` + `verify`.
- Host in a repo you own with an immutable URL keyed by version + SHA-256 hash.
- The app downloads it once, verifies SHA-256, refuses to run an unverified artifact.
- Record `model_id` and `prompt_id` on every assistant message in the local drift DB so bad replies can be traced without the server seeing text.

**Server path (fallback for low-RAM devices):**
- Container image: `ghcr.io/therapylink/eve-server:v14-p1-<sha>` — llama-server binary + base GGUF + LoRA baked in.
- Start with: `llama-server -m base.gguf --lora lora.gguf -c $((4096 * NP)) -np $NP --metrics --api-key $TL_INFERENCE_API_KEY`
- `NP=4` for up to ~1,000 MAU; `NP=8` for ~10,000 MAU. Each slot gets full context.
- Deploy on Cloud Run GPU (L4). At pilot scale (~100 MAU, ~400 cloud conversations/month) this costs roughly $10–40/month including idle tail.
- Pre-warm the container when the user opens the Eve screen in cloud mode. Cold start is 30–90 seconds; show "Eve is waking up…" in the UI.
- Rollback is a Cloud Run revision traffic shift back to the previous tagged image.

**Model and prompt versioning:**
- `ml/registry.json` (tracked, not gitignored): one entry per release with base GGUF sha256, LoRA sha256, `.litertlm` URL + sha256, prompt id + sha256, eval run name, gate numbers (≥18/24 all-safety), `approved_by` (clinician reviewer).
- CI fails if the current registry entry is below the gate or if the prompt sha does not match `eveSystemPrompt` in the app.
- The app bundles every prompt it supports, keyed by `prompt_id`. A Firebase Remote Config manifest names the active `model_id` per runtime + a kill switch (`cloud_enabled`, `min_model`). The app refuses any `model_id` whose prompt it does not have.

---

### 2.7 Environments

| Environment | Database | Auth | Eve | Purpose |
|-------------|----------|------|-----|---------|
| dev (local) | SQLite in-memory | X-Dev-Uid bypass | llama-server on localhost | Coding and unit tests |
| staging | Neon free tier (separate project) | Firebase (test project) | Cloud Run GPU min=0 | Integration tests, PR checks, demos |
| prod | Neon Launch (Singapore or Mumbai) | Firebase (prod project) | Cloud Run GPU | Real patients |

Env vars that differ per environment: `TL_ENV`, `TL_DATABASE_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_CREDENTIALS` (path to service account JSON or Workload Identity), `TL_INFERENCE_BASE_URL`, `TL_INFERENCE_API_KEY`, `REDIS_URL` (rate limiter).

The service account JSON must never be committed. Use Workload Identity Federation for Cloud Run → Firebase Admin. For local dev, the file path goes in `.env` (gitignored).

---

### 2.8 Deployment

**Container: Cloud Run (recommended for pilot)**

- API: 1 vCPU, 512 MB, min-instances=1 during pilot hours (09:00–24:00 PKT), min=0 off-hours, max=5.
- Eve server: Cloud Run GPU (L4), min=0 off-hours, min=1 during peak (18:00–02:00 PKT), max=2, `-np 4`.
- API and GPU container in the same region (Singapore ap-southeast-1 or Mumbai asia-south1; verify GPU availability before choosing).
- Neon Launch database in the same region as the API.

**Dockerfile changes needed:**
```
# current issues:
# - alembic/ not copied
# - base image unpinned
# - single worker hardcoded
# - no --proxy-headers (client IPs wrong behind Cloud Run)
# - no HEALTHCHECK

FROM python:3.12-slim@sha256:<pin>
COPY alembic/ alembic/
COPY alembic.ini .
ENV WEB_CONCURRENCY=2
CMD ["uvicorn", "therapylink_api.main:app", "--host", "0.0.0.0", "--port", "8080",
     "--workers", "${WEB_CONCURRENCY}", "--proxy-headers",
     "--forwarded-allow-ips", "*"]
HEALTHCHECK CMD curl -f http://localhost:8080/health || exit 1
```

**Release step (before traffic shift):**
```bash
# Run as a Cloud Run Job, not inside the app container
alembic upgrade head
```

---

### 2.9 CI/CD

**api job (on every PR and push to main):**
1. `ruff check` + `ruff format --check`
2. `pytest -q` with SQLite (current, passing 108 tests)
3. `pytest -q` with a `postgres:16` service container via `TL_TEST_DATABASE_URL` (add this job)
4. `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` against the Postgres service container
5. `docker build` + Trivy image scan (block on CRITICAL)
6. `gitleaks detect` on the full history

**app job:**
- Existing: `flutter analyze` + `flutter test`
- Add: crisis-offline widget test (Eve engine throws + no network → crisis reply and sheet still appear)
- Add: release-config check (fail if `TL_API_URL` is not https or `TL_GUARDIAN_URL` is empty in prod flavor)

**ml job:**
- Existing eval tests
- Add: registry gate check (eval numbers ≥ ship gate; prompt sha matches app)

**CD on tag `api-v*`:**
1. `docker build` → push to Artifact Registry
2. Run migration job (`alembic upgrade head`) against prod DB
3. Deploy new Cloud Run revision with 0% traffic
4. Smoke-test `/ready` on the new revision
5. Shift 100% traffic
6. Authenticate with Workload Identity Federation; zero JSON keys in CI secrets

**CD on tag `app-v*`:**
1. Build signed AAB for arm64
2. Upload to Play internal testing
3. Promote to production manually after QA

Branch protection on `main`: required checks, no force push.

---

### 2.10 Observability

**Structured logging (replace current print/uvicorn default):**
- Every request: `{"request_id": "...", "route": "/me", "method": "GET", "status": 200, "latency_ms": 12, "uid_hash": "sha256(uid + salt)[0:16]"}`
- Inference calls additionally: `{"model_id": "...", "prompt_id": "...", "prompt_tokens": 1200, "completion_tokens": 80, "duration_ms": 900}`
- Never log request or response bodies. Never log raw uid (hash it with a secret salt).
- Route template, not raw path: log `/clinician/patients/{uid}` not `/clinician/patients/firebase-abc123`.

**Error tracking:** Sentry free tier on the API (`send_default_pii=False`, scrub request data in `before_send`). Firebase Crashlytics on the Flutter app.

**Metrics:**
- llama-server `--metrics` endpoint scraped by Cloud Monitoring or Grafana Cloud free tier.
- Watch: tokens/s, queue depth per slot, empty-reply rate, p95 latency.

**Uptime:** 1-minute checks on `/ready` from 3 regions. Alert owner's phone if the API is down for 2 consecutive checks. Note: the crisis path has no server dependency; an API outage cannot break it.

**Alerts:**
- API 5xx rate > 2% over 5 minutes
- Inference p95 > 20 seconds
- Empty-reply rate > 1%
- DB connections > 80% of pool limit
- Any 429 spike (possible abuse)

---

### 2.11 Backups

| Scale | Strategy |
|-------|----------|
| Pilot (~100 MAU) | Nightly `pg_dump` encrypted with `age` to Cloudflare R2 (10 GB free tier). Scheduled GitHub Action. Restore drill monthly. RPO 24 h. |
| Growth (~1k MAU) | Same, plus Neon Launch 7-day PITR. RPO minutes from PITR, 24 h from dumps. |
| Scale (~10k MAU) | Same, plus cross-region copy of dumps to a second R2 bucket. Neon Scale or Cloud SQL with HA. |

The restore drill must be documented and run before the first real patient is on the system. A backup that has never been restored is not a backup.

---

### 2.12 Phased Plan

**Phase 0 — Blockers (before any real patient, ~1 week)**

1. Fix: copy `alembic/` into the Docker image; run migrations as a release job.
2. Fix: add `TL_ENV` guard; refuse to start with dev bypass enabled in prod.
3. Fix: export v14 `.litertlm`, host it in a repo you own, verify SHA-256 on-device.
4. Fix: bundle Guardian ONNX as an install-time asset pack or auto-download before first conversation.
5. Fix: revoke the legacy GCP/Gemini/Maps keys; push a clean-history repo to the company remote.
6. Fix: release build must use an `https://` API URL (not localhost); add Flutter flavor with `--dart-define-from-file`.

**Phase 1 — Closed pilot (~100 patients, ~2 weeks after Phase 0)**

7. Deploy API to Cloud Run (Singapore/Mumbai). Set min-instances=1 during pilot hours.
8. Deploy Eve server on Cloud Run GPU L4 (`-np 4`). Pre-warm on Eve screen open.
9. Neon Launch database. Run the migration job before the first traffic shift.
10. Set up Sentry (API) + Firebase Crashlytics (app).
11. Add distributed rate limiting (slowapi + Upstash Redis).
12. Nightly `pg_dump` to Cloudflare R2. Run the first restore drill.
13. Replace the verify-clinician laptop script with an admin-role API endpoint.
14. Update the privacy copy in the app: "cloud mode sends summaries and journal entries to the server".
15. Estimated cost: $25–75/month.

**Phase 2 — Public launch (~1k MAU, ~4 weeks after pilot)**

16. Add Firebase App Check + Play Integrity.
17. Add CI Postgres job and migration round-trip test.
18. Add Docker build + Trivy to CI. Add gitleaks.
19. Add the model registry gate check to CI.
20. Clinician directory search endpoint.
21. Add admin/clinician verify and revoke endpoints.
22. Estimated cost: $200–400/month.

**Phase 3 — Scale (~10k MAU)**

23. Profile DB queries; add read replica for clinician dashboards if needed.
24. Evaluate vLLM with LoRA hot-swap vs llama.cpp throughput at `-np 8`. Switch if throughput wins.
25. Add cross-region backup copy.
26. Estimated cost: $1,300–2,000/month.

---

### 2.13 What Needs a Human

- **Revoke the legacy GCP, Gemini, and Maps keys.** Only the account owner can do this. Do it before the repo goes to the company remote.
- **Budget and billing.** Cloud Run GPU, Neon Launch, and a Play developer account all need a company card. Phase 0 and 1 infra is $25–75/month; Phase 2 is $200–400/month.
- **Legal.** Whether patient health data may be processed in Singapore or Mumbai; what Pakistan's data protection rules require; data processing agreements with Google, Neon, and Sentry; the privacy notice and deletion policy text.
- **Clinician sign-off on each model release.** The registry `approved_by` field requires a licensed clinician to review the eval report before `tl-eval generate` marks a model as approved.
- **Helpline list review.** Madadgaar 1098 is not in the app. A licensed clinician picks and re-verifies the numbers quarterly.
- **Real-device testing.** Whether E2B `.litertlm` runs acceptably on the low-end Android devices your patients actually own sets the cloud-share percentage and therefore determines whether Phase 1 is $25/month or $75/month.
- **Crisis-line partnership.** Tell Umang (or the chosen lines) about expected referral volume before public launch.
