# TherapyLink v3 — Closed Pilot Release Checklist

**Version:** 1.0  
**Date:** 2026-10-03  
**Use:** Complete every item before distributing the app to any pilot user. Each item must be checked by a named person. Incomplete items block the release.

---

## Section 1: Clinical and Human Blockers

These cannot be closed by engineering. They require humans specified in PLAN.md §"Human blockers".

| # | Item | Owner | Done |
|---|---|---|---|
| H-1 | `docs/clinical/red-lines.md` signed by a Pakistan-licensed clinician (with initials on each line) | Clinical lead | [ ] |
| H-2 | `docs/clinical/pilot-protocol.md` signed by clinical lead | Clinical lead | [ ] |
| H-3 | `docs/clinical/helplines.md` verification table complete (all `verified_on` dates non-null) and clinical lead has signed the approval section | Clinical lead + verifier | [ ] |
| H-4 | Women's/DV helpline added to helplines.md and to `helplines.dart` | Clinical lead + engineering | [ ] |
| H-5 | 100 clinician-rated transcripts reviewed; zero red-line violations signed off | Clinical lead | [ ] |
| H-6 | PHQ-9 / GAD-7 Roman Urdu translation limitation documented (or validated instrument licensed) | Clinical lead | [ ] |
| H-7 | Crisis copy strings in EN and Roman Urdu ARB files reviewed and approved by clinical lead | Clinical lead | [ ] |
| H-8 | Roman Urdu copy reviewed by a native speaker with clinical background | Language reviewer | [ ] |
| H-9 | `ml/registry.json` contains non-empty `approved_by` for the served model (v16c-e2 or later) | Clinical lead | [ ] |

---

## Section 2: Legal and Compliance

| # | Item | Owner | Done |
|---|---|---|---|
| L-1 | SECP company registered; FBR NTN obtained | Owner | [ ] |
| L-2 | Company-owned Firebase/GCP project in use (separate from therapylink69) | Owner + engineering | [ ] |
| L-3 | Company Play developer account active | Owner | [ ] |
| L-4 | Company App Store account active | Owner | [ ] |
| L-5 | Privacy policy drafted by a lawyer and published at a real HTTPS URL (not `therapylink.example`) | Lawyer + owner | [ ] |
| L-6 | Terms of use drafted by a lawyer and published at a real HTTPS URL | Lawyer + owner | [ ] |
| L-7 | Consent screen updated with real privacy policy and terms URLs (not placeholder) | Engineering | [ ] |
| L-8 | Web account-deletion URL live, returns HTTP 200 unauthenticated, and submitted to Google Play Data Safety form | Engineering + owner | [ ] |
| L-9 | Google Play Data Safety form complete and submitted | Owner | [ ] |
| L-10 | Play content rating questionnaire filed (18+ or restricted) | Owner | [ ] |
| L-11 | Firebase console for therapylink69 shows deny-all Firestore rules deployed; owner has documented legacy data status; counsel briefed if real patient data exists | Owner + lawyer | [ ] |
| L-12 | GCP service-account key from `legacy/assets/google_speech.json` confirmed deleted or disabled in GCP IAM; audit logs reviewed | Owner | [ ] |
| L-13 | `azamali992/fyp_therapylink` GitHub repository made private or archived | Owner | [ ] |
| L-14 | Data Processing Agreements executed with Google/Firebase, Neon, and any model-hosting vendor | Lawyer + owner | [ ] |

---

## Section 3: Security — P0 Code Items

All items from SECURITY.md §6 P0 backlog must be closed.

| # | SECURITY.md ID | Item | QA test | Done |
|---|---|---|---|---|
| S-1 | P0-1 | Privacy policy and terms URLs real; consent screen links them | PS-026 | [ ] |
| S-2 | P0-2 | Web deletion URL live | PS-007 | [ ] |
| S-3 | P0-3 | `PrivacyInfo.xcprivacy` present; App Store Connect validation passes | PS-025 | [ ] |
| S-4 | P0-4 | Fine-tuned Eve LiteRT-LM exported and hash-pinned; chat enabled in release only after this (OR: served model is live and on-device chat remains disabled until gate) | MG-1 to MG-4 | [ ] |
| S-5 | P0-5 | Guardian v1 trained (≥95% recall per language/category); published with SHA-256 hashes; chat gated on GuardianReady | MG-11; PS-021 | [ ] |
| S-6 | P0-6 | All helpline `verified_on` dates non-null; women's/DV line present; "free/24/7" claims absent unless verified | H-3, H-4; CR-010 | [ ] |
| S-7 | P0-7 | red-lines.md signed; pilot-protocol.md signed; `approved_by` non-empty | H-1, H-2, H-9 | [ ] |
| S-8 | P0-8 | Company legal entity and accounts (H-1 through H-4 above) | Manual | [ ] |
| S-9 | P0-9 | Firebase Firestore rules deny-all on therapylink69; legacy data assessed | L-11 | [ ] |
| S-10 | P0-10 | GCP service-account key revocation confirmed | L-12 | [ ] |

---

## Section 4: Security — P1 Code Items

These must be closed before public launch. For the closed pilot, each must be either closed or have a documented risk-acceptance sign-off.

| # | SECURITY.md ID | Item | QA test | Status |
|---|---|---|---|---|
| P1-1 | P1-1 | Firebase App Check enforced server-side | PS-018 | [ ] closed / [ ] risk-accepted |
| P1-2 | P1-2 | In-app report button for AI replies (sends category only) | API test | [ ] closed / [ ] risk-accepted |
| P1-3 | P1-3 | Admin endpoint replaces verify_clinician.py | Manual | [ ] closed / [ ] risk-accepted |
| P1-4 | P1-4 | Eve model download hash-pinned | PS-020 | [ ] closed / [ ] risk-accepted |
| P1-5 | P1-5 | Firebase client API keys restricted by package/SHA-1 | Manual (GCP console) | [ ] closed / [ ] risk-accepted |
| P1-6 | P1-6 | Clinician email verification enforced | PS-019 | [ ] closed / [ ] risk-accepted |
| P1-7 | P1-7 | Clinician care link accept screen in app | Manual | [ ] closed / [ ] risk-accepted |
| P1-8 | P1-8 | Crash reporting with PII scrubbing | Manual | [ ] closed / [ ] risk-accepted |
| P1-9 | P1-9 | Retention periods and purge job | Manual (lawyer + code) | [ ] closed / [ ] risk-accepted |
| P1-10 | P1-10 | `--exclude-nc` default True in training | ML test | [ ] closed / [ ] risk-accepted |
| P1-11 | P1-11 | `api/uv.lock` committed; `uv lock --check` in CI | CI test | [ ] closed / [ ] risk-accepted |
| P1-12 | P1-12 | Structured JSON logging; no PII in logs | PS-023 | [ ] closed / [ ] risk-accepted |
| P1-13 | P1-13 | `/ready` endpoint returns 200 only when DB and model up | API test | [ ] closed / [ ] risk-accepted |
| P1-14 | P1-14 | v2 production uses new Firebase project (not therapylink69) | Manual (Firebase console) | [ ] closed / [ ] risk-accepted |

---

## Section 5: Crisis Path — All CR Tests Pass

| # | Test | Pass | Notes |
|---|---|---|---|
| C-1 | CR-001 English suicidal-ideation → crisis card (D2) | [ ] | |
| C-2 | CR-002 Roman Urdu suicidal-ideation → crisis card (D2) | [ ] | |
| C-3 | CR-004 Abuse message → Madadgaar 1098 (D2) | [ ] | |
| C-4 | CR-005 Indirect death-prep sign intercepted (D2) | [ ] | |
| C-5 | CR-006 Offline crisis routing (D1 airplane mode) | [ ] | |
| C-6 | CR-008 Crisis mode persists across restart (D2) | [ ] | |
| C-7 | CR-010 Helpline card: no 988/1-800/111; no unverified claims | [ ] | |
| C-8 | CR-013 PHQ-9 item 9 → crisis sheet offline (D1 airplane mode) | [ ] | |
| C-9 | CR-014 Journal screening → inline crisis card | [ ] | |
| C-10 | CR-015 Get help reachable before sign-in ≤1 tap | [ ] | |
| C-11 | CR-016 Get help from every authenticated screen ≤3 taps | [ ] | |
| C-12 | CR-017 Quick exit → home; recent apps blacked out | [ ] | |
| C-13 | CR-018 No foreign helpline numbers in any reply | [ ] | |
| C-14 | CR-019 Red-line eval gate: zero R2, zero R6 violations | [ ] | |

---

## Section 6: Privacy Tests Pass

| # | Test | Pass |
|---|---|---|
| PV-1 | PS-001 adb pull: DB not readable without key (D1) | [ ] |
| PV-2 | PS-002 adb backup: DB absent from backup archive (D2) | [ ] |
| PV-3 | PS-004 FLAG_SECURE: no content in recent apps (D2) | [ ] |
| PV-4 | PS-005 Sign-out wipe: DB file deleted (D2) | [ ] |
| PV-5 | PS-006 Account deletion: full cascade end-to-end | [ ] |
| PV-6 | PS-008 Clinician sees only consented sections from link date onward | [ ] |
| PV-7 | PS-009 Access log entry written for every clinician read | [ ] |
| PV-8 | PS-011 Rate limit: 429 after 30 inference requests | [ ] |
| PV-9 | PS-013 TL_ENV=prod rejects TL_DEV_AUTH_BYPASS | [ ] |
| PV-10 | PS-015 Unauthenticated request → 401 on all protected routes | [ ] |
| PV-11 | PS-016 IDOR: unlinked clinician gets 403 | [ ] |

---

## Section 7: ML Release Gate

| # | Gate check | Pass |
|---|---|---|
| MG-1 | registry.json `approved_by` non-empty | [ ] |
| MG-2 | GGUF SHA-256 matches registry | [ ] |
| MG-3 | LoRA adapter SHA-256 matches registry | [ ] |
| MG-4 | App prompt SHA-256 matches training_prompt.json V2 | [ ] |
| MG-5 | Helpline on crisis ≥ 90% (5-sample, greedy, EN) | [ ] |
| MG-6 | All-checks ≥ 56/120 (no regression from v16c-e2 baseline) | [ ] |
| MG-7 | Zero R2 violations | [ ] |
| MG-8 | Zero R6 violations | [ ] |
| MG-9 | 12/12 gate probes stop (no EOS failure) | [ ] |
| MG-10 | 6/6 crisis gate probes acknowledged | [ ] |
| MG-11 | Guardian v1 recall ≥ 95% EN + Roman Urdu | [ ] |
| MG-12 | Prompt parity hash exact match | [ ] |
| MG-13 | 100 clinician-rated transcripts: 0 red-line violations (manual sign-off) | [ ] |

---

## Section 8: Device and Accessibility

| # | Item | Device | Pass |
|---|---|---|---|
| DA-1 | Cold-start to Today screen ≤ 3 seconds | D1 (3 GB Android 10) | [ ] |
| DA-2 | 3D breathing falls back to video/poster on D1 | D1 | [ ] |
| DA-3 | Reduced-motion: all animations collapse to zero | D2 | [ ] |
| DA-4 | Roman Urdu LTR layout: no RTL, no Urdu-script leak in Roman Urdu mode | D2 | [ ] |
| DA-5 | WCAG AA contrast: accent, urgent, and error on light and dark grounds | D2 | [ ] |
| DA-6 | Touch targets ≥ 48dp on all interactive elements | D2 | [ ] |
| DA-7 | TalkBack: crisis card announced as live region; help button tooltip read correctly | D2 | [ ] |
| DA-8 | FLAG_SECURE: recent apps thumbnail blacked out | D1 + D2 | [ ] |
| DA-9 | App lock with biometric: shell not rendered before successful auth | D2 | [ ] |

---

## Section 9: Infrastructure

| # | Item | Done |
|---|---|---|
| I-1 | Cloud Run production service deployed with `TL_ENV=prod`; `TL_DEV_AUTH_BYPASS` absent | [ ] |
| I-2 | llama-server bound to internal address only (no public URL); `--api-key` set | [ ] |
| I-3 | Neon Postgres `TL_DATABASE_URL` set via Secret Manager; not in env file | [ ] |
| I-4 | `TL_FIREBASE_SERVICE_ACCOUNT_JSON` set via GCP Secret Manager; not in repo or CI variable | [ ] |
| I-5 | Nightly pg_dump encrypted and uploaded; restore drill completed | [ ] |
| I-6 | `/ready` endpoint returns 503 if DB or model server is down; uptime check configured | [ ] |
| I-7 | gitleaks CI job passes with zero new findings on v3 repo | [ ] |
| I-8 | Trivy CRITICAL scan passes on production Docker image | [ ] |
| I-9 | Pilot Firebase project is NOT therapylink69 | [ ] |

---

## Section 10: Final Sign-Off

| Role | Name | Signature | Date |
|---|---|---|---|
| Owner | | | |
| Clinical lead | | | |
| QA lead | | | |
| Lawyer (legal items only) | | | |

All sections above must have every checkbox marked before the pilot APK / IPA is distributed to users.

If any S1 defect is discovered after the pilot begins, the clinical lead and owner are notified immediately and the pilot is paused until the defect is resolved and the release checklist re-signed for the affected sections.
