# Ship status

Independent audit of `rebuild/v2` at `ffb50877`, 2026-09-25, against the blockers and Phase 1 list in `SHIP_PLAN.md`. I read the current code, not the commit messages. Paths are relative to the repo root; app paths are under `app/lib/` unless they say otherwise.

Tests run at this commit: Flutter 380 passed (`flutter test`, all files), API 103 passed, ML 258 passed. Nothing was run on a phone, and no release build was made.

Statuses:
- **closed**: the code does what the blocker asks and has a test.
- **partly closed**: the code side is done or half done, and something real is still missing.
- **open**: not done.
- **human-only**: only a person can close it.

## Short version

- Blockers: 10 closed, 6 partly closed, 1 open, 3 human-only.
- Phase 1: 1 closed, 3 open, 2 human-only.
- A release build today opens no chat at all. Eve is paused because no fine-tuned model exists and the trained Guardian is not published. That is the safe result, but it also means the product the pilot needs does not exist yet.
- The biggest remaining gaps are a gate-passing fine-tuned Eve exported to `.litertlm`, Guardian v1 trained and pinned, and clinician sign-off. None of these three is code work.

## Blockers

| # | Item | Status | Evidence | What is left |
|---|---|---|---|---|
| B1 | Revoke leaked GCP, Gemini and Maps keys; clean history on the company remote | partly closed | Owner confirmed on 2026-09-25 that all three keys are revoked, so the leaked values no longer work. `.gitleaks.toml:10-20` still allowlists the five v1 commits that contain them | Optional: push a history without those commits to the company remote, then delete the allowlist. Restrict the Firebase client keys by package and SHA-1 and enable App Check |
| B2 | Hide stock on-device Gemma and cloud mode from patients | closed | `core/ml/eve_engine.dart:94-98` `evePatientBuildAvailable`: release refuses cloud and any spec that is stock or not fine-tuned. `features/eve/eve_screen.dart:112-116` replaces the composer with "unavailable" when it fails. All specs in `core/ml/gemma_eve_engine.dart:41-54` are stock litert-community. Cloud can't be picked or loaded in release (`core/settings/settings.dart:103,137`). Tests: `test/core_test.dart:64-80` | The guard is a hand-set `isFineTuned` bool. The Eve download has no hash check (`gemma_eve_engine.dart:103-116` installs from a URL with no digest), unlike Guardian. Pinning is the Phase 1 model item |
| B3 | Widen the keyword floor; train, bundle and hash-check Guardian v1; gate chat on it | partly closed | Floor widened: gendered `marna chaht[aie]`, "end my life", Urdu script (`core/ml/guardian.dart:72-83`), plus abuse, sexual-violence and child routes (`:94-134`); tests in `test/crisis_keywords_test.dart`. Per-file SHA-256 from `TL_GUARDIAN_SHA256`, and install fails with no hashes (`core/ml/onnx_guardian.dart:22-29,108-118`). Canaries run on load (`:164-168`). Release chat is gated on `GuardianReady` (`onnx_guardian.dart:216`, `eve_screen.dart:114`; test `crisis_guardian_test.dart:157-161`). Multi-label training code exists (`ml/therapylink_ml/train/guardian.py:43`) | No Guardian v1 has been trained. Only `ml/runs/guardian-v0` and `guardian-smoke` exist. It is downloaded from `TL_GUARDIAN_URL` (empty by default), not bundled. The 300+ held-out probe set is not written. Canaries are English only |
| B4 | Eve fails red lines: output guard, crisis card on crisis turns, red-line data and DPO | partly closed | App side is done. Crisis-routed turns never reach the model (`features/eve/eve_controller.dart:299-308`). Any number not in the helplines table is removed, streaming included (`features/eve/output_guard.dart:36-74`, `eve_controller.dart:327,498`), and a card is added when that happens (`:333-335`). Tests: `crisis_output_guard_test.dart`, `crisis_controller_test.dart:225-256`. ML side: DPO now uses the SFT-policy reference with rpo_alpha (`ml/therapylink_ml/train/eve_dpo.py:297,317,332`). The scorer has an allowlist, method comparison and worst-of-N (`ml/therapylink_ml/eval/safety_rules.py:21,222`, `eval/run.py:111-118`) | No model fixes the behaviour. All 36 red-line rows are `pending_clinician` (`ml/therapylink_ml/data/authored/redline_*.jsonl`), so the loader drops them from real training. v16 SFT is training on Kaggle (third launch, 2026-09-25 02:17 PKT, past the smoke test; the first two found stale dataset code). DPO has not run; its 820-prompt draft set is in `ml/therapylink_ml/data/dpo_prompts/`. v15 with 5 samples scores 55/120 all-checks and 45/70 resource-on-crisis (`ml/runs/eval/sft-v15-s5/summary.json`) |
| B5 | Stop sending memory notes to a model not trained on them | closed | `core/ml/eve_engine.dart:83` `eveUnderstandsNotes = false`; `eve_controller.dart:482-484` sends history only; test `test/eve_history_test.dart:50` | None. It stays off until a model trained on notes beats v14 |
| B6 | Persistent in-chat crisis card, pinned help bar, ~60 min crisis mode | closed | Card saved into the transcript and rendered from the helplines table (`eve_controller.dart:304,340-342`, `eve_screen.dart:406-408`). Help bar while active (`eve_screen.dart:191-192`). 60-minute mode that survives a restart (`features/eve/crisis_mode.dart:10,43-49`). Every reply in the window gets a card (`eve_controller.dart:333`). Tests: `crisis_controller_test.dart:143-199`, `crisis_eve_screen_test.dart:81` | The sheet itself is still `isDismissible: true` (`features/shared/crisis_sheet.dart:36`), which is acceptable now that the card and bar persist. A clinician still has to approve the wording and the 60 minutes (see B20) |
| B7 | Route for abuse and child abuse: Madadgaar 1098 and a women's line in a category-aware sheet | partly closed | Kind-aware table and ordering (`features/shared/helplines.dart:31-47`); the sheet uses `helplinesFor(kind)` (`crisis_sheet.dart:66`); test "the sheet fits the danger: a child gets Madadgaar first" (`crisis_card_test.dart:87`) | No women's or DV line in the table. None of the three numbers is verified (`verifiedOn` is null for all). `features/onboarding/consent_screen.dart:15-16` still hard-codes 1098 with a TODO instead of reading the table |
| B8 | PHQ-9 item 9 checked on the device | closed | `features/assessments/assessment_outbox.dart:16-17` `answers[8] > 0`; used at `assessment_screen.dart:53`; test "a positive item 9 shows help on the phone even when the server cannot be reached" (`crisis_assessment_test.dart:67`) | None |
| B9 | Help from every screen, including before sign-in | closed | `Screen` shows Get help by default (`features/shared/widgets.dart:52`); welcome, sign-in, consent, lock and quick-exit screens have it; only clinician-console pages turn it off. Tests: `platform_help_test.dart:25-37`, `crisis_card_test.dart:72`, `privacy_app_lock_test.dart:120`, `privacy_quick_exit_test.dart:44` | None |
| B10 | Controller races: double send, New conversation mid-reply | closed | A synchronous `_busy` flag is set before any await (`eve_controller.dart:157,247-248`). `newConversation`, `openConversation`, `deleteConversation` and `wrapUp` refuse while busy (`:203,216,232,348`). Engine calls are serialised (`:508-512`). Tests: `crisis_controller_test.dart:25,37,56` | None |
| B11 | Local data per user; cleared on sign-out | closed | One DB file per uid, rows wiped then file deleted, personal prefs and consent cleared (`core/auth/session.dart:85-96`, `core/settings/settings.dart:170-183`). Tests: `platform_signout_test.dart:147-243` | None in code |
| B12 | Chat DB out of backups, iOS file sharing off, "stays on this phone" true | closed | `android/app/src/main/AndroidManifest.xml:10-12` backup off plus extraction rules; `ios/Runner/Info.plist:50-53` file sharing off. SQLCipher, with a per-account key and migration of plaintext files (`core/db/encrypted_database_native.dart`). Tests: `platform_manifest_test.dart`, `privacy_db_encryption_test.dart`, `privacy_platform_test.dart:15` | Not yet checked on a real device (adb backup, iTunes file sharing, reading the file off a rooted phone) |
| B13 | Stop uploading chat-derived mood | closed | Only manual check-ins are queued (`features/today/today_providers.dart:32`); the chat turn keeps valence on the phone (`eve_controller.dart:295-297`). Test "mood read from chat stays on the phone" (`crisis_controller_test.dart:216`) | None |
| B14 | Account and data deletion: `DELETE /me`, in-app, web form | partly closed | API: `api/therapylink_api/routers/me.py:50-67`, export at `:74`, tests `api/tests/test_account.py` (cascade, Firebase user, erased token can't recreate). App: `features/you/account_actions.dart:95-102`, `core/auth/session.dart:49-61`, tests `platform_delete_test.dart:146-188` | No web deletion page or URL anywhere in the repo. Play requires one for a health app |
| B15 | First-run consent, AI and emergency disclaimer, 18+ gate, privacy policy, terms | partly closed | Consent screen, versioned consent, router holds everything until accepted, under-18 path shows helplines, consent synced to the API (`features/onboarding/consent_screen.dart`, `core/settings/settings.dart:16,51`, `api/.../me.py:118`). Tests: `platform_consent_test.dart:47-153`, `api/tests/test_consent.py` | Terms and policy URLs are placeholders (`consent_screen.dart:11-12` `therapylink.example`). No policy or terms text exists. The 18+ gate is a self-attested tick box. Consent wording is unreviewed by a lawyer or clinician |
| B16 | API image can migrate Postgres | closed | `api/Dockerfile:12-15` ships alembic; `api/docker-entrypoint.sh` `release` runs `alembic upgrade head`; digest-pinned base (`Dockerfile:3`). Tests: `api/tests/test_deploy.py` (release migrates an empty DB), `test_migrations.py` (Postgres downgrade). CI builds and Trivy-scans the image (`.github/workflows/ci.yml:121-131`) | None in code. There is still no deploy target |
| B17 | Release signed with the debug key; localhost API default | partly closed | Release signs from `key.properties` and the build fails without it (`android/app/build.gradle.kts:53-56,100-103`). The build also fails on http, local or placeholder API URLs (`:81-106`), mirrored in `core/api/api_config.dart`. Tests: `platform_release_test.dart:9-71` | No upload keystore exists. `app/env/prod.json` still points at `api.therapylink.example`, so a release build fails by design until a real host exists. No release build has ever been run (CI builds `--debug` only, `ci.yml:156`) |
| B18 | Training-data licence: ~47% non-commercial or unverified | open | `--exclude-nc` exists (`ml/therapylink_ml/train/eve_sft.py:195,314`) | It defaults to `False` (`eve_sft.py:314`), so a plain run still trains on non-commercial data. No clean model has been trained. There is no legal opinion on MentalChat16K or the Gemma terms |
| B19 | Legal entity, tax registration, company-owned Firebase/GCP | human-only | Nothing in code | Owner: SECP company, NTN, bank account, company Firebase/GCP and Play account |
| B20 | Licensed clinical sign-off on crisis copy, red lines, served model | human-only | `docs/clinical/red-lines.md`, `pilot-protocol.md` and `helplines.md` are drafts; `helplines.md` says "No number on this page has been verified" | A Pakistan-licensed psychologist signs the red lines, the crisis copy and the rows, and rates the served model |

## Phase 1 items

| Item | Status | Evidence | What is left |
|---|---|---|---|
| Export the gate-passing candidate to `.litertlm`, evaluate on a mid-range Android phone through `GemmaEveEngine`, pin by hash and model+prompt manifest | open | No fine-tuned spec in `gemma_eve_engine.dart:41-54`; no digest check on the Eve download; v16 is still training | Train v16-clean, pass the hard gates, export, run on a phone, and add hash pinning to `EveModelManager` |
| Guardian v1: ≥95% recall per language and category on a clinician-written held-out set of ≥300 | open | Multi-label code is ready (`ml/therapylink_ml/train/guardian.py:43`); only v0 and a smoke run exist | Clinician writes the held-out set; train; publish with hashes; set `TL_GUARDIAN_URL` and `TL_GUARDIAN_SHA256` |
| Clinician protocol: 2,450 served-path samples, blind raters, zero red-line violations | human-only | Judge and multi-turn code exist (`ml/therapylink_ml/eval/judge.py`, `probes/multiturn_draft.jsonl`, marked draft) | Needs a served model first, then raters |
| App lock, quick exit, conversation list with delete, SQLCipher | closed | App lock is opt-in (`core/security/privacy_settings.dart:11`), with tests in `privacy_app_lock_test.dart`. Quick exit is on by default on every page (`privacy_quick_exit_test.dart:26-176`). Conversation list, switch and delete in `conversations_screen_test.dart:115-216`. SQLCipher in `privacy_db_encryption_test.dart` | Lock uses the phone's own lock (`local_auth`), not an app PIN. That is fine, but it is not the "PIN" in the plan. Check on devices |
| Crashlytics or Sentry with PII scrubbing; content-free metrics | open | No crash-reporting or metrics package in `app/pubspec.yaml`; no `FlutterError.onError` hook in `lib/` | Everything |
| Pilot operations: partner, consent form, on-call clinician, incident log, weekly review, stop rule | human-only | `docs/clinical/pilot-protocol.md` is a draft | Everything, by people |

## What agents can still do in code

1. **Web account deletion page.** Build a small static page plus a signed-in flow (or an emailed request form) at a stable URL for Play's Data safety form. Closes the code half of B14.
2. **Crash reporting and metrics.** Add Sentry or Crashlytics with a `beforeSend` scrubber that drops message text, journal text and user ids, plus a test that proves chat content never reaches an event. Add content-free counters (turns, crisis-card shown, sheet opened) with no text.
3. **Pin the Eve model.** Give `EveModelManager` the same per-file SHA-256 check and verified marker that Guardian has, and a model+prompt manifest. Make `evePatientBuildAvailable` require the hash instead of a hand-set bool.
4. **Bundle Guardian as an asset** as an option alongside the download, so the safety check doesn't depend on a network fetch on first run.
5. **Make `--exclude-nc` the default** in `eve_sft.py` (or refuse to run without an explicit choice), so a clean run can't be forgotten. Do the same in the Kaggle notebook flags.
6. **Evaluate v16 when it finishes:** convert both epoch adapters, run the 48 probes with 5 samples (with and without notes) and pick one, then build DPO pairs from `ml/therapylink_ml/data/dpo_prompts/` and run DPO.
7. **Add a women's/DV line slot to the helplines table**, hidden until a verified number is filled in. Make `consent_screen.dart:15-16` read 1098 from the table.
8. **Remove "free, 24/7"** from `ml/therapylink_ml/prompts.py:35` and the 20 authored rows that still say it, once the helpline answer is in. The app strings are already clean.
9. **Roman Urdu Guardian canaries**, once a Guardian scores on Roman Urdu.
10. **CI release build check.** Add a job that runs the gradle release guards with a throwaway keystore and a fake https host, so the release path is exercised before the owner's first real build.
11. The remaining code-now items in `FOLLOWUPS.md` that this audit did not re-check one by one.

## What only people can do

**Owner and company**
- Revoke the GCP service-account, Gemini and Maps keys today. Push a clean history to the company remote. Delete the `.gitleaks.toml` allowlist (B1).
- Decide commercial or not. If commercial, only `--exclude-nc` models are candidates (B18).
- Register the SECP company, get the FBR NTN and sales-tax registration, and open a bank account (B19).
- Set up company-owned Firebase/GCP projects and a Play developer account. Create the upload keystore and enrol in Play App Signing (B17).
- Pick a real API host and put it in `app/env/prod.json`. Set `TL_ENV=prod` and the llama-server key on the deploy.
- Run the first signed `flutter build appbundle` with the keystore.
- Spend the Kaggle hours: v16-clean SFT, then DPO, then Guardian v1.
- Decide whether 1099 joins the number allowlist.
- Confirm no tester install holds data in the legacy `therapylink.sqlite`.
- Trademark search on "TherapyLink" and "Eve".

**Lawyer**
- Privacy policy and terms under PECA and the PDP Bill draft. Real URLs for `consent_screen.dart:11-12`.
- Review of the consent copy, the 18+ approach and `PrivacyInfo.xcprivacy`.
- Training-data licences: MentalChat16K's synthetic half, the other non-commercial sources, and the Gemma terms (B18).
- DRAP SaMD status, data residency and retention periods, including access-log retention after deletion.
- BDI-II: remove or license.
- The legal claim in authored row `rl-ch-mx-01`.

**Clinician (Pakistan-licensed psychologist)**
- Sign `docs/clinical/red-lines.md` and the pilot protocol (B20).
- Approve or rewrite the 36 `pending_clinician` red-line rows and the 820 draft DPO prompts (`ml/therapylink_ml/data/dpo_prompts/`).
- Write the 300+ Guardian held-out probes and `clinical_expectation` per eval probe.
- Approve the crisis copy in English and Roman Urdu, and the 60-minute crisis mode.
- Label about 150 replies to calibrate the judge. Rate the final candidate under the protocol with zero red-line violations.
- Own the helpline list. Decide whether chat crises alert a linked clinician, and the F14 soft tier.
- Serve as the named on-call clinician for the pilot.

**Helplines**
- Verify Umang, 1122, Madadgaar 1098, 15 and 1099: numbers, hours, cost, scope, SMS/WhatsApp. Fill `verifiedOn` in `helplines.dart` and the register in `docs/clinical/helplines.md`.
- Find and verify a women's/DV line (B7).
- Get Umang's permission or an MoU before naming them. Re-verify every quarter.

**Pilot operations**
- Partner institution (a university counselling centre or an NGO), written consent form, incident log, weekly safety review, and a stop rule.
- At least three native Roman Urdu speakers to review the app copy, the gender handling and the PHQ-9/GAD-7 wording.

**Device testing**
- Run the fine-tuned `.litertlm` on a mid-range Android phone through `GemmaEveEngine`: speed, memory, and the hard gates on the device.
- Confirm on real phones that backups exclude the database (adb backup, Google One, iCloud), that iOS file sharing shows nothing, and that the SQLCipher file is unreadable when pulled off the phone.
- Test app lock with biometrics and the device PIN, quick exit, and the app-switcher snapshot cover on Android and iOS.
- Test sign-out and account deletion on a shared phone with two accounts.
- Check that the crisis sheet dials correctly on a phone with a SIM, and that the copy fallback works on a tablet.
