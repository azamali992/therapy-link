# TherapyLink v3 — Test Plan

**Version:** 1.0  
**Date:** 2026-10-03  
**Branch:** qa-plan  
**Scope:** Closed pilot (~100 users). Covers app (Flutter), API (FastAPI), and ML serving (llama.cpp + Guardian).

---

## 1. Scope

### 1.1 In scope

| Area | What is tested |
|---|---|
| Crisis path | Guardian keyword and ONNX routing, crisis sheet, PHQ-9 item 9, journal screening, output guard, offline behaviour, persistence across restart, ≤3-tap access from every screen |
| Privacy and security | SQLCipher DB encryption, backup exclusion, FLAG_SECURE, sign-out wipe, account deletion, clinician consent gating, access log, rate limits, TL_ENV prod guard |
| Eve chat | Streaming, prompt parity, memory, conversations, cloud-mode indicator, release build gates |
| Today / assessments | Mood check-in (offline queue), PHQ-9, GAD-7, scoring bands, trend chart |
| Journal | Create, edit, delete, Guardian screening on save, encrypted storage |
| Breathing and grounding exercises | Timer accuracy, keep-alive across scroll, reduced-motion fallback |
| Clinician linking | Invite code, pending/active state, per-section consent switches, access log entries |
| You / settings | App lock, quick exit, language toggle (EN/Roman Urdu), theme, export, sign-out, delete account |
| API routes | All routes listed in BACKEND.md; auth enforcement, IDOR, rate limits, error shapes |
| ML release gate | Model registry hash, prompt parity, safety eval thresholds, Guardian recall |

### 1.2 Out of scope for the pilot

- Voice input / TTS (not in MVP)
- On-device Eve LiteRT-LM (no fine-tuned .litertlm exists; chat gated off in release until P0-4)
- Urdu-script UI (Phase 2+)
- Admin panel (deferred)
- Verified clinician directory / booking marketplace (deferred)

---

## 2. Risk-Based Priority

Crisis path and privacy defects are the highest risks because they can directly harm a patient. Priorities are set as follows and applied throughout all sub-plans.

| Priority | Definition | Examples |
|---|---|---|
| S1 | Crisis path broken; a patient in danger cannot reach help or help is silently suppressed | Guardian not firing, PHQ-9 item 9 skipped, crisis sheet not reachable before sign-in, offline crisis path broken, output guard stripped a real helpline |
| S2 | Privacy or security breach that exposes patient data | DB readable without encryption, backup not excluded, TL_DEV_AUTH_BYPASS active in prod, clinician reading unconsented section |
| S3 | Feature broken in a way that degrades care quality but does not endanger the user | Assessment not submitted, mood trend missing, Eve chat returning error 500 |
| S4 | UX or accessibility defect that does not endanger the user | Contrast failure, reduced-motion animation still running, Roman Urdu layout issue |
| S5 | Minor cosmetic or documentation issue | Wrong colour shade, stale placeholder string |

Any S1 defect found during any phase blocks the pilot immediately.

---

## 3. Environments

| Environment | URL / location | Purpose |
|---|---|---|
| Local (developer) | localhost | Unit and widget tests; API tests against SQLite test DB |
| CI (GitHub Actions) | per-PR | `flutter test`, `pytest`, ML tests; Trivy; gitleaks |
| Staging | Cloud Run staging project | Integration tests, E2E automation, QA sign-off per phase |
| Pilot production | Cloud Run prod project | Pilot only; no automated tests run against it; manual smoke only |

### 3.1 API test database

Tests run against a real Postgres instance created per-session by `conftest.py` (pattern from `api/tests/conftest.py`). No test touches the pilot production database. The `TL_ENV=test` flag is required; `TL_DEV_AUTH_BYPASS` is allowed in test only.

### 3.2 Secrets in CI

- `TL_DATABASE_URL`, `TL_FIREBASE_SERVICE_ACCOUNT_JSON`, and `TL_INFERENCE_API_KEY` are GitHub Actions encrypted secrets.
- Never log secrets; the gitleaks CI job scans every push.

---

## 4. Device Matrix

A minimum of two physical Android devices must be used for all Phase 2 E2E and release-gate tests.

| Slot | Device spec | OS | RAM | Purpose |
|---|---|---|---|---|
| D1 (required) | Low-end Android — e.g. Samsung A05 or equivalent | Android 10 or 11 | 3 GB | Performance floor; cold-start budget; 3D breathing fallback to video; offline tests |
| D2 (required) | Mid-range Android — e.g. Samsung A34 or Pixel 6a | Android 13–15 | 6 GB | Typical user device; full feature set; primary automation runner |
| D3 (optional) | iPhone 12 or later | iOS 16+ | 4 GB | iOS-specific checks: Privacy Manifest, FLAG_SECURE equivalent (screenshot suppression), iCloud backup exclusion |
| D4 (optional) | Tablet (7–10 inch, Android) | Android 12+ | 4 GB | Clinician shell layout; landscape mode |

### 4.1 Emulator policy

Emulators are acceptable for unit and widget tests. E2E tests for crisis path, privacy, and performance must run on physical devices in D1 and D2 slots. The biometric app lock test always uses a physical device (emulator biometric simulation is not representative).

---

## 5. Test Data Rules

1. No real patient data is ever used in any test. All test accounts use synthetic identities with the naming pattern `test_{purpose}@therapylink.invalid`.
2. Synthetic journal entries, chat transcripts, and mood data are generated from a seed; they contain no real health disclosures.
3. Test PHQ-9 and GAD-7 answers use published example responses from the instrument's manual (public domain scoring examples), not answers from real people.
4. Crisis probe messages for Guardian tests come from `ml/tests/` and `app/test/crisis_keywords_test.dart`. No probe is based on a real user's message.
5. At the end of each test run, all test accounts are deleted via `DELETE /me` or the test-teardown fixture. The test database is destroyed.
6. Helpline numbers used in tests are the candidates listed in `docs/clinical/helplines.md`. Tests check format and routing logic, not whether the numbers are answered.
7. The staging environment never receives data from real pilot users until the pilot begins, and even then it operates on a separate Firebase project.

---

## 6. Entry and Exit Criteria

### Phase 0 — Foundation (~1 week)

**Entry:** New v3 repo created; Flutter 3.47.4 project bootstrapped; v2 API committed.

**Exit (all required):**
- `flutter analyze` passes with zero errors.
- `flutter test` passes on the app shell (router, tokens, theme, DB init, app lock, quick exit).
- API: all 108 v2 test cases pass (`pytest api/tests/ -x`).
- ML: 256 tests pass with one known skip (`pytest ml/tests/`); prompt parity test passes once `eveSystemPrompt` is updated to V2.
- Gitleaks CI job passes with zero new findings.
- App boots on D2 with no crash; SQLCipher DB is created and readable.

### Phase 1 — Core Experience (~2 weeks)

**Entry:** Phase 0 exit criteria met.

**Exit (all required):**
- All crisis tests ported from v2 and passing (see CRISIS_ACCEPTANCE.md).
- Guardian keyword tests pass in English and Roman Urdu.
- PHQ-9 item 9 fires crisis sheet offline.
- Journal Guardian screening fires on save.
- Offline mood check-in and journal create work with no network.
- Clinician link invite-code flow creates a pending link and the clinician sees it in the requests list.
- 0 open S1 defects; ≤2 open S2 defects (each with a documented workaround and owner).

### Phase 2 — Hardening (~1 week)

**Entry:** Phase 1 exit criteria met.

**Exit (all required):**
- All P0 code items in SECURITY.md closed (App Check, rate limits, key restriction, deletion page).
- E2E suite passes on D1 and D2.
- No open P0 or P1 defects.
- `adb backup` on D1 and D2 confirms DB file is excluded.
- FLAG_SECURE confirmed (screenshot blackout in recent apps) on D2.
- Roman Urdu LTR layout verified: no Urdu-script leak, no RTL layout.
- Reduced-motion: all animations collapse to zero duration when `MediaQuery.disableAnimations` is true.
- Cold-start on D1 (3 GB Android 10) is under 3 seconds to interactive (Today screen).
- 0 open S1 or S2 defects.

### Phase 3 — Pilot

**Entry:** Phase 2 exit criteria met; all human blockers in PLAN.md §"Human blockers" resolved (clinician sign-off, helplines verified, legal entity, privacy policy, web deletion URL, iOS Privacy Manifest).

**Exit (ongoing monitoring):**
- Pilot release checklist in RELEASE_CHECKLIST.md signed off.
- Guardian v1 recall ≥ 95% per language and category on clinician-labelled held-out set.
- Model registry `approved_by` field is non-empty for the served model.
- Zero S1 incidents in the first 72 hours; any S1 pauses the pilot.

---

## 7. Defect Management

| Severity | SLA (time to fix or workaround) | Pilot gate |
|---|---|---|
| S1 | Fix within 4 hours; pilot paused until fixed | Blocks pilot |
| S2 | Fix within 24 hours | Blocks pilot if unresolved |
| S3 | Fix within 1 week (current sprint) | Does not block pilot; must be tracked |
| S4 | Fix before public launch | Does not block pilot |
| S5 | Fix at discretion | Does not block pilot |

Defect fields: ID, severity, title, steps to reproduce, affected device/OS, phase found, owner, status.

S1 defects are always labelled `crisis-path` or `privacy-breach` and pinged immediately to the owner and clinical lead.

---

## 8. Test Types and Tooling

| Type | Tool | Where it runs | Coverage target |
|---|---|---|---|
| Unit (Dart) | `flutter test` | CI, local | Crisis logic, Guardian, output guard, scoring, DB encryption, consent, settings |
| Widget (Dart) | `flutter test` with `flutter_test` | CI, local | Crisis sheet, mood picker, chat bubbles, crisis card, help button presence |
| Integration (Dart) | `integration_test` package | Physical devices D1, D2 | End-to-end flows: crisis ≤3 taps, offline mood, journal screening |
| API (Python) | `pytest` + `httpx` TestClient | CI, staging | All routes, auth enforcement, rate limits, consent gating |
| ML (Python) | `pytest` | CI, local | Prompt parity, safety eval thresholds, Guardian recall, model registry hash |
| Manual | Test script in this plan | D1, D2, D3 | Biometric app lock, backup exclusion via adb, FLAG_SECURE, voice call button |

---

## 9. Running Tests

```
# App unit + widget tests
cd app && flutter test

# API tests (requires TEST_DATABASE_URL or Docker postgres)
cd api && pytest tests/ -v

# ML tests
cd ml && pytest tests/ -v

# Integration tests on device (connect D2 via USB)
cd app && flutter test integration_test/ --device-id <device-id>
```
