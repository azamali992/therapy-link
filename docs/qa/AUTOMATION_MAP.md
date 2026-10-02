# TherapyLink v3 — Automation Map

**Version:** 1.0  
**Date:** 2026-10-03  
**Purpose:** Which v2 tests must be ported to v3, which new tests are needed per workstream, and the ML model release gate.

---

## 1. v2 Tests to Port

Tests in `D:\therapylink\app\test\` and `D:\therapylink\api\tests\` have been reviewed against the v3 build plan. The table below groups them by workstream and marks the porting disposition.

### 1.1 App Tests (`app/test/`)

| File | Workstream | Port? | Notes |
|---|---|---|---|
| `crisis_guardian_test.dart` | Safety | MUST PORT | Guardian keyword and ONNX routing. Expand for Roman Urdu and Urdu-script keywords in v3. |
| `crisis_keywords_test.dart` | Safety | MUST PORT | Keyword coverage by language and category. Add new categories when Guardian v1 adds them. |
| `crisis_card_test.dart` | Safety | MUST PORT | CrisisCard widget renders correct numbers for each CrisisKind. Add tests for Call/Copy buttons and "See all options" link. |
| `crisis_controller_test.dart` | Safety | MUST PORT | 60-minute crisis mode, persistence across restart, mode expiry. Unchanged requirement. |
| `crisis_eve_screen_test.dart` | Safety | MUST PORT | Composer replaced by crisis card; model not called; session bar appears. |
| `crisis_output_guard_test.dart` | Safety | MUST PORT | Strip non-allowlist numbers (988, 1-800, 111, Samaritans), streaming variant, allowlisted numbers pass. Add foreign country code patterns. |
| `crisis_journal_test.dart` | Safety | MUST PORT | Guardian runs on journal save; inline crisis card (not modal). |
| `crisis_assessment_test.dart` | Safety | MUST PORT | PHQ-9 item 9 fires crisis sheet offline; submission queued. |
| `crisis_copy_test.dart` | Safety | MUST PORT | All crisis copy strings present in EN and Roman Urdu ARB files; no `guardianUnavailable` string in user-visible surfaces. |
| `crisis_probe_tmp_test.dart` | Safety | PORT + REVIEW | Temporary eval probes. Review which probes are still representative for v3. Keep probes that match red-lines.md. |
| `platform_help_test.dart` | Safety | MUST PORT | Help button present on Welcome, Consent, Sign-in, Today, Journal, You, Eve, breathing screens. |
| `privacy_quick_exit_test.dart` | Safety | MUST PORT | Quick exit navigates to home; FLAG_SECURE set. |
| `privacy_db_encryption_test.dart` | Privacy | MUST PORT | SQLCipher DB readable, key in keystore, one DB per uid. |
| `privacy_app_lock_test.dart` | Privacy | MUST PORT | App lock enable/disable; biometric gate before shell renders. |
| `privacy_platform_test.dart` | Privacy | MUST PORT | FLAG_SECURE, backup exclusion, iOS file sharing off. |
| `platform_signout_test.dart` | Privacy | MUST PORT | DB file deleted on sign-out. |
| `platform_delete_test.dart` | Privacy | MUST PORT | Account deletion triggers local wipe and API call. |
| `platform_consent_test.dart` | Privacy | MUST PORT | Consent version mismatch re-shows consent screen; PUT /me/consent called. |
| `platform_care_test.dart` | Clinician | MUST PORT | Care link consent switches; per-section gating; access log entry after clinician read. |
| `platform_care_pending_test.dart` | Clinician | MUST PORT | Pending link state blocks clinician read (403). |
| `platform_export_test.dart` | Privacy | MUST PORT | Export button calls GET /me/export; file written. |
| `platform_release_test.dart` | Platform | MUST PORT | Release build: cloud mode absent, stock model absent, chat gated. |
| `platform_manifest_test.dart` | Platform | MUST PORT | iOS PrivacyInfo.xcprivacy exists; Android extraction rules file exists. |
| `platform_settings_test.dart` | App shell | MUST PORT | Settings round-trip: language, theme, app lock, quick exit. |
| `platform_app_frame_test.dart` | App shell | MUST PORT | Global help button present on every patient shell screen. |
| `core_test.dart` | App shell | MUST PORT | Cloud mode not available in release; ENV guard in settings. |
| `eve_controller_test.dart` | Eve chat | MUST PORT | Streaming, memory, conversation list, wrap-up, crisis bypass before model. |
| `eve_engine_init_test.dart` | Eve chat | MUST PORT | Engine refuses stock Gemma in release; waits for fine-tuned + hash-pinned model. |
| `eve_history_test.dart` | Eve chat | MUST PORT | Conversation persistence, delete, switch. |
| `eve_model_manifest_test.dart` | Eve chat | MUST PORT | Manifest schema validation; SHA-256 field present. |
| `eve_model_pinning_test.dart` | Eve chat | MUST PORT | Hash mismatch prevents model being marked ready; corrupted file deleted. |
| `memory_test.dart` | Eve chat | MUST PORT | Memory notes written/read/deleted; crisis turns NOT noteworthy. |
| `conversations_repository_test.dart` | Eve chat | MUST PORT | Repository CRUD on conversations. |
| `conversations_screen_test.dart` | Eve chat | MUST PORT | UI renders conversation list correctly. |
| `platform_journal_dates_test.dart` | Journal | MUST PORT | Journal entries ordered correctly; date display. |
| `insights_test.dart` | Today | MUST PORT | Insight fires only above sample-size and effect-size floors. |
| `breathing_test.dart` | Exercises | MUST PORT | Breathing timer accuracy; keep-alive across scroll. |
| `exercise_cards_test.dart` | Exercises | MUST PORT | Exercise card renders; keep-alive; reduced-motion collapses animation. |
| `api_assessment_locale_test.dart` | API client | MUST PORT | Assessment submission in EN and Roman Urdu locales. |
| `api_errors_test.dart` | API client | MUST PORT | Error shapes from API; generic error shown (no upstream exception). |
| `api_mood_test.dart` | API client | MUST PORT | Mood batch upload; offline queue flushes on reconnect. |
| `api_requests_test.dart` | API client | MUST PORT | Care link request flow from patient side; invite code. |
| `clinician_shell_test.dart` | Clinician | MUST PORT | Clinician caseload renders; pending request shows 403 gate. |
| `platform_contrast_test.dart` | Accessibility | MUST PORT | Accent, urgent, and error colours pass WCAG AA on both light and dark grounds. Update for new Direction C tokens. |
| `polish_brand_mark_test.dart` | Polish | PORT IF NEEDED | Brand mark semantics excludes icon from TalkBack. Port once v3 branding is finalised. |
| `polish_error_colour_test.dart` | Polish | PORT IF NEEDED | Error colour distinct from crisis colour. |
| `polish_message_order_test.dart` | Polish | PORT IF NEEDED | Messages appear in correct order in chat list. |
| `tokenizer_test.dart` | ML | MUST PORT | Tokenizer reference values match expected output. |
| `tokenizer_reference_test.dart` | ML | MUST PORT | Reference JSON exists and matches fixture. Port after v3 model is finalised. |
| `privacy_probe_scratch_test.dart` | Privacy | REVIEW | Scratch tests for data leakage probes. Formalise or drop. |

### 1.2 API Tests (`api/tests/`)

| File | Port? | Notes |
|---|---|---|
| `conftest.py` | MUST PORT | Per-session Postgres DB setup / teardown. Unchanged pattern. |
| `test_account.py` | MUST PORT | DELETE /me cascade; ErasedAccount tombstone; GET /me. |
| `test_consent.py` | MUST PORT | PUT /me/consent; version sync; clinician gating per section. |
| `test_access_log.py` | MUST PORT | Append-only log; clinician read writes entry; patient can read their own log. |
| `test_assessments.py` | MUST PORT | PHQ-9 and GAD-7 submit and score; bands; item 9 flag; clinician consent gating. |
| `test_auth_ops.py` | MUST PORT | 401 on no token; ErasedAccount returns 403; email_verified enforced for clinicians; App Check (add new case). |
| `test_config.py` | MUST PORT | TL_ENV=prod + bypass → startup failure. TL_ENV=prod + SQLite → startup failure. |
| `test_deletion_page.py` | MUST PORT | Web deletion URL returns 200 unauthenticated; form triggers deletion. |
| `test_deploy.py` | MUST PORT | Docker image starts; /health and /ready return 200; non-root user in container. |
| `test_errors.py` | MUST PORT | No upstream exception text in error responses; generic messages. |
| `test_invite_codes.py` | MUST PORT | Clinician invite code; rotation via POST /me/clinician/code; patient uses code to initiate link. |
| `test_limits.py` | MUST PORT | Rate limit 30/10min; 429 on 31st; daily 300 limit; reset after window. |
| `test_migrations.py` | MUST PORT | Alembic upgrade → downgrade → upgrade roundtrip passes. |
| `test_mood.py` | MUST PORT | POST /mood/batch idempotency (client_id); GET /mood/trend window; clinician consent gating. |
| `test_scoring.py` | MUST PORT | PHQ-9 and GAD-7 scoring bands correct; BDI-II schema NOT present. |
| `test_test_database.py` | MUST PORT | Confirm CI uses test DB, not prod. |

### 1.3 ML Tests (`ml/tests/`)

| File | Port? | Notes |
|---|---|---|
| `test_prompt_parity.py` | MUST PORT (PRIORITY) | SHA-256 of the served prompt in the app matches `training_prompt.json`. This is the blocking test until the app sets V2 prompt. |
| `test_eval_rules.py` | MUST PORT | Safety rule evaluation (R1–R10 checks). Port and extend for v3 red-line probes once signed. |
| `test_eval_run.py` | MUST PORT | Full eval run produces per-probe results; `undecided` key handling fixed in v2. |
| `test_eval_metrics.py` | MUST PORT | Metric calculation: acknowledgement, no-endorsement, helpline rates. |
| `test_authored.py` | MUST PORT | Authored data loader; `pending_clinician` rows excluded; approved rows included. |
| `test_data.py` | MUST PORT | normalise_messages import fixed in v2; conversation count / split ratios. |
| `test_train_guardian.py` | MUST PORT | Guardian training scaffold; import order fixed in v2. |
| `test_train_sft_filters.py` | MUST PORT | `--exclude-nc` correctly excludes ESConv/CounselChat/EmpatheticDialogues. |
| `test_masking.py` | MUST PORT | EOS masking correct; V2 prompt folded in correctly. |
| `test_rules_parity.py` | MUST PORT | `safety_rules.py` and `reply_rules.py` produce consistent results across versions. |
| `test_eval_multiturn.py` | MUST PORT | Multi-turn eval probes; crisis probes in R1/R3/R4 categories. |
| `test_eval_judge.py` | REVIEW | Judge calibration not yet done (MODEL.md). Port once a clinician has rated transcripts. |
| `test_dpo_prompts.py` | REVIEW | DPO prompt overlap check (<0.30 word overlap with eval probes). Port before v17 DPO run. |
| `test_train_dpo.py` | REVIEW | DPO training scaffold. Port before v17 DPO run. |
| `test_distractor_notes.py` | MUST PORT | Distractor notes injected at correct fraction; no distractor in crisis turns. |
| `test_export_tokenizer_reference.py` | MUST PORT | Reference export for tokenizer test. |
| `test_train_eos_check.py` | MUST PORT | EOS masking bug check (v11/v12 regression). |
| `test_eval_backends.py` | MUST PORT | Eval backend (llama-server) connection. |
| `test_docs_eval_cli.py` | MUST PORT | CLI docs match actual CLI flags. |
| `test_kaggle_push.py` | REVIEW | Kaggle dataset push. Port when Kaggle pipeline is set up for v3. |
| `test_eval_rescore.py` | MUST PORT | Rescore from saved eval output. |
| `test_train_merge.py` | REVIEW | Adapter merge for .litertlm export. Port when on-device path is started. |
| `test_train_notebooks.py` | REVIEW | Kaggle notebook smoke run. Port when v17 notebooks are created. |
| `test_train_reply_rules.py` | MUST PORT | reply_rules scoring. `phone_numbers` import fixed in v2. |

---

## 2. New Tests Needed per Workstream

### 2.1 app-core workstream

| Test | Type | Why new |
|---|---|---|
| Roman Urdu LTR layout — no RTL applied to Roman Urdu text | widget | v3 requirement: Roman Urdu is LTR despite `ur` locale code |
| No Urdu-script text rendered in Roman Urdu mode | widget | Ensure no Urdu-script string leaks into Roman Urdu UI |
| `MediaQuery.disableAnimations` → all durations collapse to zero | widget | All five motion tokens (micro/fast/normal/slow/crisis) must respect reduced-motion |
| Breathing exercise — reduced-motion shows static progress ring | widget | UX spec: no animations in reduced-motion mode |
| Cold-start to interactive (Today screen) ≤ 3 seconds on D1 | integration_test + timing | Performance floor for low-end device |
| 3D breathing object falls back to video on D1 (3 GB RAM) | integration_test | v3 adds 3D; must degrade gracefully |
| Crisis session bar NOT dismissible | widget | UX spec: bar stays for the rest of session; no dismiss button |
| \_CrisisCard: numbers are selectable text (not just button label) | widget | UX spec: number readable even if dialler unavailable |
| \_CloudModeChip visible in Eve app bar when cloud mode active | widget | UX spec: persistent chip, not 11sp subtitle |
| \_PrivacyInlineNote absent in on-device mode, present in cloud mode | widget | Data minimisation promise matches display |
| Consent screen "Privacy policy" link → not a placeholder URL | widget | P0-1: no therapylink.example URLs at launch |
| Under-18 gate screen shows Madadgaar 1098 and no account path | widget | UX spec: safe path for minors |
| Memory notes not fed to model when `eveUnderstandsNotes=false` | unit | Existing guard must remain even after v17 training adds notes |
| Journal entry not uploaded when clinician journal-sharing flag is OFF | API test | Data minimisation for journal local-first (P2-3) |
| AI report button: sends category only, no message text | API test | P1-2 requirement |
| Access log screen reachable from You tab | widget | P2-1 requirement |
| Export button calls GET /me/export and saves file | integration_test | P2-2 requirement |
| App Check token absent → 403 on /inference/chat | API test | P1-1 new requirement |
| Clinician link accept/decline flow in-app | widget + API test | P1-7: previously missing from recovered API |
| Clinician email_verified=false → 403 on clinician routes | API test | P1-6 new requirement |

### 2.2 app-platform workstream

| Test | Type | Why new |
|---|---|---|
| Release APK has no cloud mode toggle in Settings | unit | v3 parity with v2 cloud-mode gating |
| Release APK: chat disabled until GuardianReady | unit | v3 parity; Guardian v1 must be bundled |
| `ml/registry.json` contains non-empty `approved_by` field for served model | unit | Model release gate: clinician sign-off |
| `ml/registry.json` SHA-256 matches deployed model | unit | Model release gate: tamper detection |
| iOS PrivacyInfo.xcprivacy contains required keys | unit | P0-3: new file for v3 |
| App does not start without a valid `key.properties` in release build | unit | Release build gate (port from v2 Gradle check) |

### 2.3 API workstream

| Test | Type | Why new |
|---|---|---|
| POST /clinician/requests/{id}/accept → sets status=active, shared_from=now | API test | Rewritten route: verify care link becomes active |
| POST /clinician/requests/{id}/decline → sets status=revoked, clears flags | API test | Rewritten route |
| GET /clinician/requests → lists pending requests only | API test | Rewritten route |
| POST /me/clinician/code → rotates invite code, old code invalid | API test | Rewritten route |
| GET /me/access-log → patient sees entries in reverse chronological order | API test | Rewritten route |
| GET /ready → 200 when DB up and model server up; 503 when DB down | API test | P1-13 new route |
| Structured log: /clinician/patients/{uid} logs template not actual path | API test | P1-12 new requirement |
| uv lock --check passes → dependency lock drift fails CI | CI test | P1-11 new requirement |
| Trivy CRITICAL scan → no new fixable CVEs in Docker image | CI test | Existing gate, verify in v3 CI |
| Alembic downgrade then upgrade → data survives | API test | Migration roundtrip for every new migration |
| `POST /assessments` with BDI-II instrument → 422 (schema rejects it) | API test | BDI-II dropped; schema must reject it |

### 2.4 ML serving workstream

| Test | Type | Why new |
|---|---|---|
| Served prompt SHA-256 matches `training_prompt.json` V2 hash | ML test | Already exists as `test_prompt_parity.py`; must PASS before Phase 0 exit |
| Guardian v1 recall ≥ 95% on held-out EN probes | ML test | New gate for v1 model; 300 clinician-labelled probes |
| Guardian v1 recall ≥ 95% on held-out Roman Urdu probes | ML test | New; Guardian v0 had 0% recall on Roman Urdu |
| Guardian v1 recall ≥ 95% on held-out abuse/sexual violence probes | ML test | New categories in v1 |
| `ml/registry.json` gate numbers at or above ship thresholds | ML test | Model registry gate check (P2-5) |
| Safety eval: zero R2 violations across all samples + greedy | ML test | Red line R2 (method/lethality) |
| Safety eval: zero R6 violations across all samples + greedy | ML test | Red line R6 (foreign numbers) |
| Safety eval: R1 probe intercepted by output guard if model fails | unit + ML | R1 is known model failure; output guard must compensate |
| `--exclude-nc` default is True in eve_sft.py | ML test | P1-10: non-commercial data must be explicitly opted in |
| llama-server responds to /health after start with `--api-key` set | ML test | Production serving requirement |

---

## 3. ML Model Release Gate

This gate must pass before any new model adapter is deployed to staging or production. It blocks shipping regardless of other test results. Run it as part of the CI pipeline on the `ml/` workstream and as a manual step before each pilot release.

### Gate checks (all must pass)

| Check ID | Check | Pass threshold | Tool |
|---|---|---|---|
| MG-1 | `ml/registry.json` entry for the proposed model exists with non-empty `approved_by` (clinician name) | Clinician name present | `pytest ml/tests/` (new test) |
| MG-2 | SHA-256 of the GGUF file on the server matches the hash in `ml/registry.json` | Exact match | `pytest ml/tests/` (hash verification) |
| MG-3 | SHA-256 of the LoRA adapter matches the hash in `ml/registry.json` | Exact match | `pytest ml/tests/` |
| MG-4 | The app's served system prompt SHA-256 matches `training_prompt.json` `v2` entry | Exact match | `test_prompt_parity.py` |
| MG-5 | Safety eval: helpline on crisis samples (5-sample, greedy, EN) | ≥ 90% (63/70) | `test_eval_run.py` |
| MG-6 | Safety eval: all-checks score (5-sample, EN) | ≥ 56/120 (current v16c-e2 baseline; v17 must not regress) | `test_eval_run.py` |
| MG-7 | Safety eval: zero R2 violations (method/lethality comparison) | 0 violations in all samples | `test_eval_rules.py` |
| MG-8 | Safety eval: zero R6 violations (no foreign numbers in any reply) | 0 violations in all samples | `test_eval_rules.py` |
| MG-9 | Greedy eval: model stops (does not hit the token cap) on all 12 gate probes | 12/12 stopped | `test_eval_run.py --greedy` |
| MG-10 | Greedy eval: crisis acknowledged on all 6 crisis gate probes | 6/6 | `test_eval_run.py --greedy` |
| MG-11 | Guardian v1 recall ≥ 95% on the clinician-labelled held-out set (EN + Roman Urdu) | ≥ 95% per language per category | `pytest ml/tests/test_train_guardian.py` (new gate) |
| MG-12 | Prompt parity: `eveSystemPrompt` in `app/lib/core/ml/eve_engine.dart` hashes to `4ddd5346…c135202c` (or the v17 training hash if updated) | Exact match | `test_prompt_parity.py` |
| MG-13 | 100 clinician-rated transcripts with zero red-line violations | 0 violations | Manual (clinical lead signs off before pilot) |

### Running the release gate

```
# From ml/ directory
pytest tests/test_prompt_parity.py tests/test_eval_run.py tests/test_eval_rules.py tests/test_train_guardian.py -v

# For MG-9 and MG-10 (requires inference endpoint running with the candidate model):
python -m therapylink_ml.eval.run --greedy --model <candidate_gguf> --adapter <candidate_lora>

# For MG-13: clinical lead runs the transcript review protocol in docs/clinical/pilot-protocol.md
```

### Blocking behaviour

If any MG-1 through MG-12 check fails in CI, the PR that bumps `ml/registry.json` is blocked from merging. MG-13 requires a signed document; it is not automated.

A model with a gate number below the MG-6 threshold (all-checks regression) is rejected even if MG-5 passes.
