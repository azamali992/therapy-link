# TherapyLink v2 -- Security, Privacy and Compliance Reference

**Written**: 2026-10-03  
**Reviewer**: Security & Privacy Lead  
**Scope**: `app/`, `api/`, model-serving topology, CI/CD; `legacy/` reviewed for secrets by path and type only. No secret values are printed in this document.  
**Branch**: rebuild/v2  
**Prior reviews incorporated**: `docs/ship-review/security-privacy-compliance.md`, `backend-devops.md`, `crisis-safety.md`, `STATUS.md`, `docs/legal/data-inventory.md`

---

## 1. Threat Model (STRIDE-style)

### 1.1 Assets

| Asset | Sensitivity | Where it lives |
|---|---|---|
| Chat transcripts (Eve conversations, memories, rolling summaries) | Critical -- mental health disclosures, crisis history | Phone only (release builds); debug/profile: also passed through API to model server |
| Mood and journal entries | High -- health data, daily timeline | Phone + API DB (journal is server-only) |
| PHQ-9/GAD-7 assessment answers and scores | High -- clinical instruments, suicidal ideation flag | API DB; phone displays results |
| Crisis events (Guardian flags, PHQ-9 item 9 positive) | Critical -- duty-of-care signals | Phone (Guardian flags); API DB (assessment flags) |
| Clinician-patient links and shared data | High -- care relationship and consent flags | API DB |
| Firebase auth tokens and user identities | High -- account takeover surface | Firebase Auth (Google, project therapylink69); API DB (uid + email) |
| Legacy Firestore data (chats, journals) from the FYP v1 app | Critical -- real mental-health disclosures from prior users | Firebase project therapylink69 (same project v2 uses for auth) |
| Model weights (Eve fine-tune, Guardian ONNX) | Medium -- IP; a tampered weights file silences crisis detection | Phone (downloaded); developer laptop (GGUF) |
| API service-account credentials | Critical -- admin access to patient identity store | Should exist only in GCP IAM and runtime env; legacy history contained one (revoked 2026-09-25, confirmation required) |
| Firebase client API keys | Low -- public identifiers by design; abuse risk if unrestricted | `app/lib/firebase_options.dart` (tracked) |

### 1.2 Threat Actors

| Actor | Capability | Motivation |
|---|---|---|
| Family member / abusive partner with physical phone access | Low-tech; unlocked phone | Reading or deleting patient disclosures; monitoring mental state |
| Abusive partner (remote) | Social engineering; coerced password; shared Google account | Same; also blocking help-seeking behaviour |
| Curious or malicious clinician | Authenticated API access | Reading patient data beyond consent grants; exporting data |
| Attacker on network | TLS intercept on misconfigured builds; traffic analysis | Intercepting API calls or model prompts |
| External attacker (unauthenticated) | Open internet; automated tooling | Enumerating endpoints; credential stuffing; burning GPU budget |
| Prompt-injection attacker | Crafted user messages sent to Eve | Manipulating model output; bypassing crisis detection; generating harmful content |
| Insider (developer / operator) | DB access; service-account credentials; CI pipeline | Reading patient journals and assessments; impersonating users via dev-bypass |
| Compromised CI/CD pipeline | Write access to build artefact | Injecting malicious code; leaking secrets from environment |
| Supply-chain attacker | Compromised pub/PyPI package | Backdoor in app or API image; targeting model downloads |

### 1.3 STRIDE Risk Register (top threats, ranked by likelihood x impact)

| Rank | STRIDE | Threat | Residual Risk |
|---|---|---|---|
| 1 | I | Crisis detection silenced by tampered Guardian ONNX or thresholds.json. Controls: Guardian per-file SHA-256 checks in code; no hash-pinned Eve download yet. | High: Guardian v1 not yet trained; Eve still stock Gemma |
| 2 | T/I | Phone shared with abusive partner reads mental health disclosures. Controls: SQLCipher DB; app lock opt-in; quick exit. | High: app lock is opt-in; coercion not addressed |
| 3 | E | Insider reads journal/assessments via DB or verify_clinician.py against prod. Controls: access log; TL_ENV=prod blocks dev-bypass. | High: no admin-role endpoint; script runs from any machine with the DB URL |
| 4 | I/D | Legacy plaintext Firestore data in therapylink69 accessible under test-mode rules. Controls: none verified. | High: see Section 5.3 |
| 5 | S | Developer laptop via Cloudflare Tunnel leaks chat content. Controls: cloud mode removed from release builds; inference key required. | Medium: dev/profile builds still route through the laptop; no DPA |
| 6 | D | Unauthenticated Firebase account floods /inference/chat and exhausts GPU. Controls: per-uid rate limit 30/10 min; input size caps. | Medium: App Check not yet enforced server-side |
| 7 | T | Prompt injection manipulates model output or extracts system prompt. Controls: output guard strips non-allowlist numbers; crisis bypass. | Medium: no input sanitisation layer |
| 8 | E | Malicious clinician reads patient data beyond active consent. Controls: active link + per-section consent flags + access log. | Low-Medium: no anomaly alert on unusual access patterns |
| 9 | S/T | Supply-chain attack on pub/PyPI dependency. Controls: Trivy CRITICAL scan in CI; no dependency lock file yet. | Medium: pyproject.toml uses unpinned version ranges |
| 10 | I | Legacy GCP service-account key in git history and public FYP repo. Controls: owner confirmed revocation; gitleaks CI prevents new leaks. | Low-current: revocation needs explicit confirmation in GCP IAM |

---

## 2. Regulatory and Policy Checklist

**Legend**: BLOCKER = hard launch blocker; REQUIRED = required before public launch; LAWYER = needs counsel; ACTION = technical work item.

### 2.1 Pakistan -- PECA 2016 (as amended 2022 and 2025)

| Requirement | Status | Owner |
|---|---|---|
| PECA s.32: traffic-data retention -- does TherapyLink qualify as a "service provider"? | OPEN -- LAWYER | Counsel must determine. Preliminary position: a mental-health app is not an ISP; counsel should confirm. |
| Lawful-access requests for journal and summary data | OPEN -- LAWYER | Establish a point of contact and internal policy before the first pilot patient. |
| The legacy key leak -- unauthorised-access risk and reporting obligation | OPEN -- LAWYER | Counsel should assess whether disclosure is required and whether anyone else used the key. |

### 2.2 Pakistan -- Personal Data Protection Bill (Draft 2023)

Status as of knowledge cutoff (August 2025): not enacted. Counsel must verify current status. Design to the draft regardless, as it reflects the government's declared intent and aligns with GDPR-grade practices.

| Requirement | Status | Owner |
|---|---|---|
| Health data = sensitive personal data requiring explicit consent | BLOCKER | Consent screen and versioning exist; privacy policy URL is a placeholder (`consent_screen.dart:11-12`) |
| Data subject right to erasure | Partly done | `DELETE /me` cascade exists; no web deletion URL yet |
| Data subject right to portability | Partly done | `GET /me/export` exists in API; no in-app button yet |
| 72-hour breach notification | OPEN -- LAWYER | No incident-response plan exists |
| Cross-border transfer and data localisation | OPEN -- LAWYER | Proposed regions (Singapore, Mumbai) and Firebase Auth (Google US) must be assessed by counsel |
| Data Processing Agreements with vendors | OPEN -- LAWYER | Needed with Google/Firebase, Neon, and any model-hosting vendor before a real patient uses the service |
| Retention periods | OPEN -- LAWYER | No retention period set for any table; no purge job exists |

### 2.3 Google Play Requirements

| Requirement | Status | Owner |
|---|---|---|
| Health apps policy: submit via an organisation developer account (not individual) | BLOCKER | Company entity (SECP + FBR) required |
| Data safety form: health info, emotion, journal, identifiers declared | PARTIALLY DONE | `docs/legal/data-inventory.md` is a draft; final form requires the privacy policy |
| Account deletion in-app and via a web URL | BLOCKER | In-app deletion exists; no web deletion URL |
| Sensitive content rating questionnaire filed (18+) | BLOCKER | Not filed |
| AI-generated content: in-app reporting for Eve replies | REQUIRED | Not implemented |
| Play Families policy vs self-attested 18+ tick box | REQUIRED -- LAWYER | Decide with counsel; a self-attested tick box will not keep minors out |

### 2.4 App Store (Apple)

| Requirement | Status | Owner |
|---|---|---|
| Guideline 5.1.1(ix): apps in regulated healthcare fields must be submitted by a legal entity, not an individual developer | BLOCKER | Company entity required |
| Guideline 5.1.1(v): in-app account deletion | Done | |
| Guideline 1.4.1: no unsubstantiated medical claims ("therapy", "diagnosis", "clinically proven") | REQUIRED -- LAWYER | Marketing and consent copy must avoid these terms without clinical evidence and regulatory clearance |
| iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) | BLOCKER | Does not exist; required for App Store submission |
| Privacy nutrition label | OPEN -- LAWYER | Must match `data-inventory.md` |

### 2.5 GDPR-Grade Practices (for users abroad)

Do not market outside Pakistan until legal clearance. The following baseline reduces exposure for diaspora users:

- Explicit consent before health data leaves the phone (done in release builds for chat; journal is always server-side -- disclose clearly)
- Right to erasure (API endpoint done; web deletion URL pending)
- Right to portability (API endpoint done; in-app button pending)
- DPAs with Google, Neon, and any model host -- not yet executed
- 72-hour breach notification -- no plan exists
- No data used for advertising -- confirmed by code (no ad or analytics SDK)

GDPR applies directly if any user is in the EU/EEA and the company has an EU establishment or targets EU users. Counsel must advise.

### 2.6 Medical Device Regulation

Requires a lawyer and a licensed clinician. PHQ-9/GAD-7 scoring with severity bands, triage of patients by risk for clinicians, and an AI providing mental-health support could be read as medical use under:

- Pakistan DRAP (Medical Devices Rules 2017): software intended for diagnosis, monitoring or treatment
- US FDA: general-wellness vs. SaMD guidance; Illinois / Nevada / Utah AI therapy restrictions (2025)
- EU AI Act (chatbot transparency duties) + MDR Rule 11

Position the app as general wellness and self-help, with no diagnosis or treatment claims, until counsel advises otherwise. Do not distribute outside Pakistan without clearance.

### 2.7 Hard Launch Blockers Summary

1. Company legal entity and accounts (SECP + FBR + company Firebase/GCP + company Play + company App Store)
2. Privacy policy and terms drafted by a lawyer, published at real URLs
3. Web account-deletion URL (Play Data safety requirement)
4. iOS Privacy Manifest
5. Gate-passing fine-tuned Eve LiteRT-LM on device
6. Guardian v1 with Roman Urdu and multi-category support, published and bundled
7. Clinician sign-off on crisis copy, red lines, and the served model
8. Helplines verified (numbers, hours; women's/DV line confirmed)
9. Content rating questionnaire filed on Play (18+ or restricted)
10. Legacy Firestore data in therapylink69 assessed and either deleted or secured

---

## 3. v2 Review -- What Changed, What to Carry, What to Fix

### 3.1 Already Done -- Carry Forward As-Is

These were blockers or high-severity findings in the prior review and are now correctly implemented.

| Item | Evidence |
|---|---|
| SQLCipher DB encryption, per-account key in platform keystore | `app/lib/core/db/encrypted_database_native.dart`; `core/security/database_key.dart`; `privacy_db_encryption_test.dart` |
| Android backup disabled + full extraction-rules exclusions | `android/app/src/main/AndroidManifest.xml:10-12`; `data_extraction_rules.xml` |
| iOS file sharing off | `ios/Runner/Info.plist:48-49` |
| Per-user DB file; wipe on sign-out and account deletion | `core/auth/session.dart:85-96`; `platform_signout_test.dart` |
| Cloud mode removed from release builds | `core/settings/settings.dart:103,137`; `core_test.dart:64-80` |
| Chat-derived mood NOT uploaded; only manual check-ins | `features/today/today_providers.dart:32`; `eve_controller.dart:230-232` |
| `DELETE /me` with Firebase user removal and `ErasedAccount` tombstone | `api/therapylink_api/routers/me.py:50-67`; `test_account.py` |
| `GET /me/export` | `api/therapylink_api/routers/me.py:74-93` |
| Versioned consent screen with server sync | `features/onboarding/consent_screen.dart`; `api/tests/test_consent.py` |
| Rate limit on inference endpoint (30 req / 10 min per uid, 300/day) | `api/therapylink_api/settings.py:28-29`; `api/therapylink_api/ratelimit.py` |
| Input size caps on API text fields | `api/therapylink_api/schemas.py` |
| `TL_ENV=prod` and `TL_DEV_AUTH_BYPASS` mutual exclusion | `api/therapylink_api/settings.py:35-42`; `test_config.py` |
| Error messages no longer echo upstream exceptions | `api/therapylink_api/auth.py:97-99` (generic messages returned) |
| Firebase Admin SDK cert caching (not per-request fetch) | `api/therapylink_api/auth.py:49-51` |
| Clinician access log (append-only, Postgres rules prevent modification) | `api/therapylink_api/models.py:150-162`; `clinician.py:105,146-147` |
| Care link requires clinician acceptance (pending state) | `api/therapylink_api/routers/care.py`; `data-inventory.md:38` |
| App lock (opt-in, local_auth) and quick exit | `core/security/privacy_settings.dart:11`; `privacy_app_lock_test.dart`; `privacy_quick_exit_test.dart` |
| PHQ-9 item 9 checked locally before submission | `features/assessments/assessment_outbox.dart:16-17`; `crisis_assessment_test.dart:67` |
| Persistent crisis card, 60-minute crisis mode | `features/eve/crisis_mode.dart`; `crisis_controller_test.dart:143-199` |
| Category-aware helplines table with Madadgaar 1098 routing | `features/shared/helplines.dart:31-47`; `crisis_card_test.dart:87` |
| Guardian per-file SHA-256 verification and canary self-test | `core/ml/onnx_guardian.dart:22-29,108-118,164-168` |
| Gitleaks whole-history scan in CI (checksum-pinned binary) | `.github/workflows/ci.yml:158-175` |
| Trivy image scan (CRITICAL fixable only) in CI | `.github/workflows/ci.yml:121-131` |
| Postgres + alembic migration roundtrip tests in CI | `.github/workflows/ci.yml:39-78` |
| Docker image with non-root user and digest-pinned base image | `api/Dockerfile` |
| Release build fails without `key.properties` and a real HTTPS API URL | `android/app/build.gradle.kts:93-108` |
| BDI-II (Pearson-copyrighted) removed from schema | `api/therapylink_api/models.py:43-46` |

### 3.2 Partially Done -- Fix Before Launch

| Item | Gap | Priority |
|---|---|---|
| Account deletion web URL | No static page or form published; Play Data safety requires a URL | P0 |
| Privacy policy and terms | Placeholder URLs in `consent_screen.dart:11-12`; no document text | P0 (blocker) |
| iOS Privacy Manifest | No `PrivacyInfo.xcprivacy` | P0 (App Store blocker) |
| Fine-tuned Eve on device | Stock Gemma still in `gemma_eve_engine.dart:41-54`; chat correctly disabled in release builds | P0 (blocker) |
| Guardian v1 trained, published, bundled | Only v0/smoke runs exist; no Roman Urdu or abuse categories; `TL_GUARDIAN_URL` still empty by default | P0 (blocker) |
| Firebase client API keys unrestricted | Three `AIzaSy...` keys for project `therapylink69` with no package/SHA-1 restriction in GCP | P1 |
| Firebase App Check not verified server-side | Client sends App Check token but the API does not verify it | P1 |
| No in-app report button for AI replies | Google Play AI-generated content policy requires in-app reporting | P1 |
| Clinician admin endpoint | `verify_clinician.py` still requires a machine with the prod DB URL | P1 |
| Eve model download not hash-pinned | Mutable `resolve/main` ref; no hash check (unlike Guardian) | P1 |
| Helpline numbers unverified | `verifiedOn` is null for all entries; no women's/DV line | P0 (clinical blocker) |
| `--exclude-nc` not the default in training | `eve_sft.py:314` defaults to `False`; a plain run includes non-commercial data | P1 |
| Access log outlives account deletion | By design on Postgres rules; retention period undefined | P1 (lawyer) |
| Retention policies and purge jobs | No TTL for any server table | P1 (lawyer + code) |
| Journal server-only plaintext | Any DB operator can read journal text | P2 |
| Clinician MFA / email verification not enforced | `auth.py` does not require `email_verified` for clinicians; no MFA | P1 |
| Clinician care link accept screen in app | App has no accept/decline UI yet | P1 |
| Crash reporting with PII scrubbing | No Sentry or Crashlytics in `pubspec.yaml` | P1 |
| In-app export button | `GET /me/export` exists but no UI | P2 |
| Access log UI for patients | `GET /me/access-log` exists but no screen | P2 |
| Google Fonts runtime fetch | Manrope and Noto Nastaliq Urdu fetched from `fonts.gstatic.com` at runtime; device IP goes to Google | P2 |

test from section 4 start

---

## 4. Recommended Security Architecture

### 4.1 On-Device Storage

Chat, memories, and summaries are stored in a SQLCipher-encrypted drift database, one file per Firebase UID (named `therapylink_{uid}`), key in the platform keystore (Android Keystore or iOS Secure Enclave via `flutter_secure_storage`). Never exported to Google Drive, iCloud, or device-transfer.

Core rule: anything the user says to Eve stays on the device in release builds. The journal is currently server-side; the roadmap should move it to local-first with selective upload only for shared entries.

Verify on real devices: adb backup excludes the DB, Google One excludes the DB, iCloud excludes the DB, Finder shows nothing via file sharing.

### 4.2 Key Management

| Key or Secret | Where stored | Must never appear in |
|---|---|---|
| SQLCipher DB key | Platform keystore only (Android Keystore, iOS Secure Enclave) | SharedPreferences, source code, backups |
| Firebase ID token | Firebase SDK session store | Server logs, API logs |
| API service-account JSON | TL_FIREBASE_SERVICE_ACCOUNT_JSON via GCP Secret Manager on Cloud Run | The repo, CI variables visible to PR runners, developer laptops |
| Inference API key | TL_INFERENCE_API_KEY on the server host | Absent when TL_INFERENCE_BASE_URL is set (enforced by settings.py:40-42) |
| DB connection string | TL_DATABASE_URL on the server host | The repo, CI logs |
| Android upload keystore | Created once by the owner, outside the repo, enrolled in Play App Signing | Source control |
| Guardian and Eve SHA-256 hashes | Hard-coded in the app and in ml/registry.json | Fetched at runtime from a mutable URL without verification |

Use Workload Identity Federation for GCP access from CI/CD. Never store a JSON service-account key in GitHub Actions secrets or on a developer laptop.

### 4.3 Authentication and Session

Firebase Authentication for all users. Email/password for patients; clinicians must have a verified email (`email_verified` enforced in the API on clinician-only routes) and eventually Google sign-in or Firebase MFA.

Session lifetime: Firebase ID tokens expire after one hour; the app refreshes them. The `ErasedAccount` tombstone prevents reuse within that window.

Do not mint custom Firebase tokens anywhere in the codebase; this is a lateral-movement risk.

The dev auth bypass (`TL_DEV_AUTH_BYPASS`) must never be on when `TL_ENV=prod` or with a non-sqlite database. This is enforced at startup; add an integration test.

### 4.4 API Authorisation Model

Every route must scope its queries to `principal.uid` or a verified care link. The established pattern (no IDOR found in prior review):

    Patient token
      -> signed_in(): verifies Firebase ID token, checks ErasedAccount tombstone
      -> current_principal(): looks up role in DB
      -> route handler: scopes every query to principal.uid
         - journal: _owned (uid == caller)
         - care links: _owned_link (patient_uid == caller OR clinician_uid == caller)
         - clinician reads: _active_link + per-section consent flag + verified_clinician

Rules for all new routes:
1. Never accept a uid from the request body as the current user. Always use `principal.uid` from the authenticated context.
2. Add a test for every new clinician route: unauthenticated returns 401, unlinked clinician returns 403, linked non-consenting clinician returns 403 for the flagged section.
3. Run the consent test suite on every PR that touches clinician routes.

### 4.5 Data Minimisation

| Data item | Must never leave phone (release builds) | Current status |
|---|---|---|
| Raw chat messages | YES | Enforced |
| Guardian crisis flags per message | YES | Enforced |
| Eve memories | YES | Enforced |
| Rolling conversation summary | YES | Enforced |
| Mood derived from chat | YES | Enforced |
| PHQ-9/GAD-7 answers | No -- sent to API by design | By design |
| Manual mood check-ins | No -- user voluntarily uploads | By design |
| Journal entries | No -- server-side only currently | Roadmap: local-first; disclose in privacy policy until then |

### 4.6 Clinician Access and Audit

All four sharing flags (`share_assessments`, `share_mood_trend`, `share_summaries`, `share_journal`) default to off.

A care link begins as `pending`; the clinician must accept before seeing any data.

Every clinician read writes an append-only row to `access_log`. On Postgres, database rules prevent UPDATE and DELETE on this table.

The patient can view their access log via `GET /me/access-log`. An in-app screen is a P2 item.

Clinician accounts must have a verified email before profile approval. MFA is a P1 item.

The `verify_clinician.py` script must be replaced with an admin-role API endpoint. DB credentials must not be on developer laptops.

### 4.7 Model-Serving Security (No Public Tunnel)

Current state (debug and profile builds): Eve runs on the developer laptop via llama-server behind a Cloudflare quick tunnel. Not acceptable for real patients.

Target architecture for production:
- Release build: Eve runs on-device via LiteRT-LM (chat disabled until gate-passing model shipped).
- Debug and profile builds: Phone -> API (Cloud Run, TLS, Firebase auth, rate limit, App Check) -> llama-server in the same Cloud Run project or VPC, no public URL, API key required.

Requirements for the production model server:
1. No public URL. Reachable only by the API container via Cloud Run service-to-service auth or private networking.
2. API key required at all times (enforced by settings.py:40-42). Set `--api-key` on llama-server.
3. No prompt logging. Configure llama-server with logging disabled or metrics-only.
4. Context limit and slots: run with `-c 4096*N -np N`. Max output tokens 1024 enforced in API schemas.
5. Rate limits: 30 req per 10 min per uid, 300 per day. IP-level limit at Cloudflare or Cloud Armor for unauthenticated traffic.
6. Firebase App Check enforced server-side. Limits inference calls to genuine app installations.

### 4.8 Prompt-Injection and Output Guard

Strip HTML and XML control characters from user input before forwarding to the model.

The output guard (`features/eve/output_guard.dart`) strips any phone number not on the allowlist from model replies, including during streaming. Extend with: a foreign country code pattern, a method-seeking instruction pattern, and a `no_foreign_number` rule in eval.

Crisis turns bypass the model entirely and return a deterministic helpline card. Do not add a network step to this path.

Do not rely on system prompt secrecy. The system prompt ships in the app and should be treated as public.

### 4.9 Logging Without PII

Log: route template (never the raw path, which contains patient uids), HTTP status, latency, request ID, model ID, prompt version, token counts, hashed uid (HMAC-SHA256 with a secret salt).

Never log: request or response bodies, plain uids in URL paths, Firebase ID tokens, any part of a conversation or journal entry, the inference URL or tunnel host.

Structured JSON logs only. Replace the default uvicorn access log with custom middleware that emits the template-based format.

### 4.10 Backups

Phone: the DB is excluded from all backups by construction. Verify on real devices via adb backup, Google One, iCloud, and Finder.

Server DB: nightly `pg_dump`, encrypted with `age` or GCP CMEK, uploaded to Cloudflare R2 or GCS. Run a restore drill monthly before the first pilot patient. Provider PITR on Neon Launch (7-day) supplements.

Do not back up journal or chat content to any personal cloud storage.

### 4.11 Secrets Management

Only non-sensitive public identifiers belong in version control. `firebase_options.dart` is acceptable; restrict the three API keys in the GCP console.

In CI: use GitHub Actions encrypted secrets, not variables visible to PR workflows from forks. Use Workload Identity Federation for GCP access from CD, never a JSON key file.

Gitleaks runs on the full history on every push and PR. Once history is rewritten and the allowlist block deleted, any new leak fails CI immediately.

Rotation policy: rotate the inference API key and DB password quarterly. Use Application Default Credentials on Cloud Run (no JSON key file).

### 4.12 Dependency and CI Scanning

| Gate | Tool | Blocks merge? |
|---|---|---|
| Python API CVEs | Trivy on Docker image (CRITICAL fixable only) | Yes |
| Python dependency lock drift | uv lock --check (add to CI) | Yes |
| Secret scanning, full history | gitleaks with .gitleaks.toml | Yes |
| Static analysis, Python | mypy strict mode (add) | Yes |
| Static analysis, Dart | flutter analyze | Yes |
| Postgres migration roundtrip | alembic upgrade, downgrade, upgrade | Yes |
| Outdated Python and Dart dependencies | Dependabot weekly | Advisory only |

Add `uv.lock` to `api/` and a `uv lock --check` gate to CI. Add mypy or pyright to the API CI job in strict mode for new files.

---

## 5. Secrets Scan -- Current Working Tree

Scan method: grep for known secret patterns over the working tree (excluding `.git/`). `legacy/` was included; only paths and key types are reported. No values are printed in this document.

### 5.1 v2 Working Tree (app/, api/, ml/, .github/)

| File | Type | Notes |
|---|---|---|
| `app/lib/firebase_options.dart` | Firebase client API keys (three `AIzaSy...` values, one per platform) | Public identifiers by design. Allowlisted in `.gitleaks.toml` for the `gcp-api-key` and `generic-api-key` rules, scoped to this file only. Risk: keys are unrestricted in GCP. Action: restrict by Android package name + SHA-1 and iOS bundle ID in the GCP console; enable App Check. |
| `api/.env.example` | Template only -- all sensitive fields are blank or placeholder | No secrets present. Safe to track. |

No other secret patterns were found in the v2 working tree. The CI gitleaks job confirms this on every push.

### 5.2 Legacy/ Directory -- Credential Inventory

The following files contain credentials in the current working tree. The owner must verify each item against GCP IAM before the legacy/ directory is removed or the company remote receives the full history.

| File | Credential type | Revoked? | Action required |
|---|---|---|---|
| `legacy/assets/google_speech.json` | GCP Service Account JSON (fields: private_key_id, private_key, client_email, token_uri). Used by voicechat.dart via SpeechToText.viaServiceAccount. Listed in legacy/pubspec.yaml as an app asset. Committed in `a3162bff`. | [ ] Owner: confirm this specific key is deleted or disabled in GCP IAM > Service Accounts. Check audit logs for any use after 2026-09-25. | Highest priority: a live service-account key grants GCP and Firebase Admin access |
| `legacy/android/app/google-services.json` | Firebase client config (Firebase API key, app ID) for project therapylink69 | n/a -- client identifier | Restrict the API key in GCP console by Android package + SHA-1 |
| `legacy/lib/firebase_options.dart` | Firebase client config (same project therapylink69) | n/a -- client identifier | Same as above |
| `legacy/lib/utils/const.dart` | Gemini API key (const apikey) and Google Maps API key (const gmapapi). Present on all branches. | [ ] Owner: confirm both revoked in GCP API credentials console | |
| `legacy/android/app/src/main/AndroidManifest.xml` | Google Maps API key in manifest meta-data. Present on main and origin/ahmad branches. | [ ] Owner: confirm revoked | |
| `legacy/android/gradle.properties` | Additional API key. Present on origin/ahmad branch. | [ ] Owner: confirm revoked | |
| `legacy/lib/Views/maps/map 2.dart` (history before commit 57762483) | Google Places API key in git history, not working tree. | [ ] Owner: confirm revoked | |

**Important note on the public GitHub repository `azamali992/fyp_therapylink`**: this repository still contains all of the above credentials in its history, including on side branches (ahmad, mobile-ui). The mobile-ui and ahmad branches call Gemini REST from the Flutter client using the key in const.dart, meaning the keys were used for client-side API calls and are not just configuration. Any attacker who clones that repo can retrieve the values. Revocation is the primary control but is not sufficient alone.

Recommended action: delete or archive the public FYP repo (`azamali992/fyp_therapylink`), or at minimum push a history rewrite that removes the five commit SHAs listed in `.gitleaks.toml`. The company remote (`AZEKTRAAI/therapylink`) should receive only a clean history starting from rebuild/v2 with no legacy-fyp tag. This is cleaner than a full git filter-repo on the combined history. Once done, delete the `[[allowlists]]` block from `.gitleaks.toml`.

### 5.3 Legacy Firestore Data -- Residual Risk in Project therapylink69

The v1 FYP app stored patient chats, journals, and potentially crisis events in Firestore under project therapylink69. The v2 app uses this same Firebase project for Authentication. This is a critical residual risk that must be resolved before the first pilot patient.

**What is known**:
- The legacy app wrote chat and journal data to Firestore (evidenced by `legacy/lib/bloc/chat_bloc.dart` and the `dataconnect-generated/` directory).
- The Firestore security rules in the repo (`legacy/firestore.rules`) are deny-all in source, but `legacy/firebase.json` does not wire them to the deployed project. The deployed rules were likely in test mode (allow read, write: if true), which is the Firebase default during development.
- If test-mode rules were ever deployed and never tightened, any authenticated Firebase user for the project can read any other user's Firestore documents.

**Required actions (owner)**:
1. Open the Firebase console for project therapylink69, go to Firestore Database > Rules. If the deployed rules are not deny-all, fix them immediately. This is a P0 action.
2. Enumerate the Firestore collections and document counts. Identify whether any real patient data (non-test) was stored.
3. If real patient data exists: consult counsel. Options include notifying affected users, deleting the data, or migrating to a separate project.
4. Strongly recommended: create a new Firebase project for v2 production, entirely separate from therapylink69. This ensures: legacy data and new patient data are in separate projects with no cross-access; a future legacy leak cannot affect v2 auth; the new project has clean IAM from day one.
5. If a new project is used: update `TL_FIREBASE_PROJECT_ID` in `api/.env.example` and update `app/lib/firebase_options.dart` with the new project config.

---

## 6. Prioritised Security Backlog

### P0 -- Before any real patient (including the closed pilot)

| ID | Item | Acceptance Criteria (QA-testable) |
|---|---|---|
| P0-1 | Publish privacy policy and terms; update `consent_screen.dart:11-12` with real URLs | Fresh install shows consent screen; tapping "Privacy policy" opens a non-placeholder URL returning HTTP 200; consent version on server matches the displayed text version |
| P0-2 | Web account-deletion URL | URL submitted to Google Play returns HTTP 200 from a non-logged-in browser; a deletion request from the form results in the account being deleted (testable with a test account) |
| P0-3 | iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) | File exists under `app/ios/Runner/`; App Store Connect validation passes without "missing privacy manifest" warnings |
| P0-4 | Gate-passing fine-tuned Eve LiteRT-LM exported and hash-pinned | `gemma_eve_engine.dart` contains a non-stock spec with a SHA-256 hash; `evePatientBuildAvailable` returns true; model passes safety gate (>=18/24 all-checks, >=12/14 resource-on-crisis) through `GemmaEveEngine` on a mid-range Android phone; chat enabled in a release build only after this |
| P0-5 | Guardian v1 trained, published, bundled or auto-downloaded | Guardian v1 with >=95% routing recall per language and per category (suicidal, self-harm, abuse) on a clinician-written held-out set of >=300 probes; published with SHA-256 hashes; chat disabled in release until `GuardianReady`; no manual Settings download required |
| P0-6 | Helplines verified and women's/DV line added | `verifiedOn` is non-null for every entry in `helplines.dart`; a women's/DV helpline row exists; `consent_screen.dart` reads 1098 from the table (not hard-coded); a licensed clinician has signed off on the wording |
| P0-7 | Licensed clinician sign-off | `docs/clinical/red-lines.md` is signed; `docs/clinical/pilot-protocol.md` is signed; no `pending_clinician` rows remain in authored red-line data; `ml/registry.json` has a non-empty `approved_by` for the served model |
| P0-8 | Company legal entity and accounts | SECP company registered; FBR NTN obtained; company-owned Firebase/GCP project in use for the pilot; company Play developer account; company App Store account |
| P0-9 | Legacy Firestore rules verified and data assessed | Firebase console shows deny-all Firestore rules deployed on project therapylink69; owner has documented whether real patient data exists; counsel briefed if it does |
| P0-10 | GCP service-account key revocation confirmed | Owner has verified in GCP IAM that the key from `legacy/assets/google_speech.json` is deleted or disabled; audit logs reviewed for any use after 2026-09-25 |

### P1 -- Before public launch

| ID | Item | Acceptance Criteria (QA-testable) |
|---|---|---|
| P1-1 | Firebase App Check verified server-side | API returns 403 when called with a valid Firebase ID token but missing or invalid App Check token; `test_auth_ops.py` covers this case |
| P1-2 | In-app report button for AI replies | Long-press on any Eve message shows "Report this reply"; sends category (not text) to a server endpoint; no chat content sent without explicit secondary confirmation |
| P1-3 | Clinician admin endpoint replaces `verify_clinician.py` | An admin-role API endpoint exists with admin-role gating; `verify_clinician.py` removed or marked dev-only; no DB credential needed on a developer laptop to approve a clinician |
| P1-4 | Eve model download hash-pinned | `EveModelManager` verifies SHA-256 after download (matching Guardian's pattern); download to a `.part` file renamed only after verification; a test asserts that hash mismatch prevents the model being marked ready |
| P1-5 | Firebase client API keys restricted | GCP console shows each `AIzaSy...` key restricted to its Android package name + SHA-1 (and iOS bundle ID); App Check enabled on the Firebase project |
| P1-6 | Clinician email verification enforced | API returns 403 on clinician-role routes when `email_verified` is false; clinician sign-up prompts email verification before profile approval |
| P1-7 | Clinician care link accept screen in app | Clinician sees pending link requests in the app; a pending link returns 403 on `GET /clinician/patients/{uid}`; test asserts this |
| P1-8 | Crash reporting with PII scrubbing | Sentry or Crashlytics initialised with `send_default_pii=False` and a `beforeSend` scrubber; a test asserts that a simulated crash event contains no chat text, journal text, or plain uid |
| P1-9 | Retention periods and purge job | Counsel has decided retention periods; a scheduled job deletes rows older than the period; job is idempotent and tested |
| P1-10 | `--exclude-nc` as default in training | `eve_sft.py:314` default changed to `True`; Kaggle notebook flags updated; CI ML job fails if a run is started without the flag being explicitly set; legal opinion obtained for MentalChat16K and Gemma terms |
| P1-11 | Dependency lock file | `api/` has `uv.lock` committed; CI job runs `uv lock --check` and fails on drift |
| P1-12 | Structured JSON logging; no PII in logs | API emits JSON logs with request ID, route template (not actual path), status, latency, hashed uid; a test asserts that a request to `/clinician/patients/{uid}` logs the template and not the actual uid; no bodies logged |
| P1-13 | Production readiness endpoint `/ready` | `GET /ready` returns 200 only when `SELECT 1` succeeds and (if `TL_INFERENCE_BASE_URL` is set) the model server responds; uptime checks point at `/ready` |
| P1-14 | Separate Firebase project for v2 production | v2 app uses a new Firebase project separate from therapylink69; `api/.env.example` and `firebase_options.dart` updated; old project used only for legacy auth migration if needed |

### P2 -- Before or shortly after public launch

| ID | Item | Acceptance Criteria (QA-testable) |
|---|---|---|
| P2-1 | In-app access log screen for patients | Screen reachable from Settings; shows clinician name (masked), sections viewed, date; test asserts correct entries appear after a clinician reads patient data |
| P2-2 | In-app data export button | "Download my data" button calls `GET /me/export` and saves a JSON file containing every server-held item in `data-inventory.md` |
| P2-3 | Local-first journal | Journal entries written to the local drift DB first; only entries explicitly shared with a clinician uploaded; test asserts journal text is not uploaded without the sharing flag being set |
| P2-4 | Bundle Google Fonts | `GoogleFonts.config.allowRuntimeFetching = false` in `main.dart`; Manrope and Noto Nastaliq Urdu bundled in `assets/`; test asserts no HTTP call to `fonts.gstatic.com` during a simulated session |
| P2-5 | Model registry and canary deploy | `ml/registry.json` committed and tracks the active model entry with gate numbers; CI ML job fails if gate numbers fall below the ship threshold; Cloud Run traffic split used for canary deploys |
| P2-6 | DPIA completed | A signed Data Protection Impact Assessment covers all data flows in `data-inventory.md`, the risk register in Section 1, and the cross-border transfer question |

---

## Summary

### Top 10 Risks

1. **Crisis detection not deployed**: Guardian v1 is not trained; the shipped model is stock Gemma (7/24 safety). Chat is correctly disabled in release builds, but the product does not yet exist for patients. This is the single most important thing to fix.

2. **No legal entity or published policy**: the company is an individual, the privacy policy URL is a placeholder, and the Play listing requires an organisation account. No pilot or launch is possible without this.

3. **Legacy Firestore data in project therapylink69**: real prior users' mental-health disclosures may be readable by anyone with a Firebase account for the project if test-mode rules were deployed and never tightened.

4. **Abusive partner / family access to the phone**: app lock is opt-in; shared devices are the norm in the target population. Nudge app lock on during onboarding and add a coercion consideration to the threat model.

5. **Insider DB access exposes journals and assessments in plaintext**: the `verify_clinician.py` script requires a machine with the prod DB URL. Replace with an admin-role endpoint.

6. **Legacy GCP service-account key in git history and public FYP repo** (`azamali992/fyp_therapylink`): owner confirmed revocation but this needs explicit confirmation in GCP IAM. The public repo should be archived or the history rewritten.

7. **Firebase client API keys unrestricted**: three `AIzaSy...` keys for project therapylink69 with no package/SHA-1 restriction in GCP. Restrict them and enable App Check.

8. **No App Check enforcement server-side**: any Firebase account can call the inference endpoint without being a genuine app installation. Enforce App Check server-side before public launch.

9. **Supply-chain risk in model downloads**: Eve's download is from a mutable `resolve/main` ref with no hash check. A compromised download silently replaces the crisis classifier.

10. **Prompt injection through Eve chat**: no input sanitisation layer; output guards cover the most dangerous outputs (non-allowlist numbers, streaming) but the broader prompt injection surface remains open.

### Hard Launch Blockers

- P0-4: Gate-passing fine-tuned Eve LiteRT-LM on device
- P0-5: Guardian v1 with Roman Urdu and abuse categories, published and bundled
- P0-7: Licensed clinician sign-off on crisis copy, red lines, and served model
- P0-6: Helplines verified; women's/DV line added
- P0-1: Privacy policy and terms at real URLs
- P0-8: Company legal entity and accounts
- P0-2: Web account-deletion URL
- P0-3: iOS Privacy Manifest
- P0-9: Legacy Firestore rules verified and data assessed
- P0-10: GCP service-account key revocation confirmed by owner in GCP IAM

### P0 Backlog (one line per item for QA tracking)

- P0-1: Lawyer publishes privacy policy and terms; app consent screen links real URLs
- P0-2: Web deletion page live and submitted to Play Data safety form
- P0-3: `PrivacyInfo.xcprivacy` present; App Store Connect validation passes
- P0-4: Fine-tuned Eve LiteRT-LM exported, hash-pinned, on-device safety gate passed, chat enabled in release build
- P0-5: Guardian v1 trained (>=95% recall per language/category), published with hashes, chat gated on `GuardianReady`
- P0-6: All helpline `verifiedOn` dates populated; women's/DV line added; clinician approved wording
- P0-7: `red-lines.md` signed; `pilot-protocol.md` signed; `ml/registry.json` has `approved_by` for the served model
- P0-8: SECP company + FBR NTN + company Firebase/GCP/Play/App Store accounts active
- P0-9: Firebase console shows deny-all Firestore rules on therapylink69; owner documents legacy data status; counsel briefed
- P0-10: Owner confirms in GCP IAM that the service-account key is deleted or disabled; audit logs reviewed

---

*This document was written from the code at branch rebuild/v2, incorporating all prior ship-review findings. It does not modify any code. All recommendations must be applied by the engineering and product team. Items marked LAWYER require counsel and cannot be closed by engineering alone.*
