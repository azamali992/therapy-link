# Follow-ups triage

Source: `.claude/followups.json` (65 items left by the six merged workstreams). Checked against `rebuild/v2` at `9fa4e4e1`.

Classes:
- **done**: already handled in the merged code, or needs no action.
- **code-now**: an engineer can do it in the repo today, with a test. The stream letter is in brackets.
- **needs-human**: needs a clinician, a lawyer, the owner, a helpline, a store console or keys.
- **ml-gpu**: needs a training run or a GPU.

Totals: 16 done, 28 code-now, 16 needs-human, 5 ml-gpu.

## All items

| # | From | Item (short) | Class | Evidence / note |
|---|---|---|---|---|
| 1 | ml-eval | Should 1099 (MoHR) join `ALLOWED_NUMBER`? | needs-human | `ml/therapylink_ml/eval/safety_rules.py:15` excludes 1099; `train/reply_rules.py:21,23` allows it; authored rows cite it (`crisis_support_02.jsonl:9,19`, `redline_violence_01.jsonl:10`). Owner/helpline decision. Stream D makes it a one-line switch |
| 2 | ml-eval | DPO sampling through HFBackend dtype | done | `ml/therapylink_ml/train/eve_dpo.py:207-210` refuses any backend but `openai:` (llama-server); the DPO notebook only trains on prebuilt pairs |
| 3 | ml-eval | tokenizer_reference now picks up `multiturn_draft.jsonl` | code-now [D] | `ml/therapylink_ml/export/tokenizer_reference.py:36` globs `probes/*.jsonl` |
| 4 | ml-eval | Document the new tl-eval flags, `rescore`, `calibrate` | code-now [D] | No hits for `--samples`, `rescore` or `calibrate` in `ml/README.md` or `ml/KAGGLE.md` |
| 5 | ml-eval | Review the multi-turn seeds and judge rubric; label 150 replies | needs-human | Clinician. `probes/multiturn_draft.jsonl` rows say "draft, pending clinician review" |
| 6 | ml-eval | Regenerate `rescored-summary.md` in the main checkout | done | `ml/runs/eval/rescored-summary.md` exists in the main checkout (gitignored) |
| 7 | ml-eval | `clinical_expectation` per probe not written | needs-human | Clinician. 0 rows have the field in `probes/*.jsonl` |
| 8 | ml-eval | `no_endorse` false positive on "great ways" (v14 s08) | done | No action. That reply ignores a crisis probe and already fails acknowledge and resource (`safety_rules.py:73-79`) |
| 9 | ml-eval | ruff format not run | done | No action. `ruff check` runs in CI (`.github/workflows/ci.yml` ml job) |
| 10 | api-hardening | Clinician accept/decline screen for pending links; patient pending copy; show name | code-now [A] | Name is shown (`app/lib/features/care/care_screen.dart:68`). No client for `GET /clinician/requests` or accept/decline in `app/lib/core/api/api_client.dart`; care screen lists only active links (`care_screen.dart:61`) |
| 11 | api-hardening | `POST /care/links` takes only `{code}` | done | `app/lib/core/api/api_client.dart:88` |
| 12 | api-hardening | DELETE /me with confirm and wipe; GET /me/export; PUT /me/consent | code-now [A] | Done: `api_client.dart:45,48`, confirm dialog `features/you/account_actions.dart:49`, local wipe `core/auth/session.dart:40-43`, consent sync `core/api/consent_sync.dart:17`. Missing: export download, deleting downloaded model files |
| 13 | api-hardening | Mood `client_id`, `{accepted, duplicates}`, 500-point cap, `tz` | code-now [A] | `MoodPointUpload.toJson` (`core/api/models.dart:66`) sends no `client_id`; `moodTrend` and `patientOverview` send no `tz` (`api_client.dart:63,100`) |
| 14 | api-hardening | Send `locale` with assessments; "unvalidated translation" notice; drop bdi2 | code-now [A] | `submitAssessment` sends no locale (`api_client.dart:53`); `bdi2` still in `core/api/models.dart:3`, `assessment_items.dart:10,14`, `assessment_outbox.dart:17`, `shared/widgets.dart:265`. Notice wording needs clinician review |
| 15 | api-hardening | 429/503 must not sign out; trim chat to 60 msgs/16k chars; access-log screen | code-now [A] | No 429/Retry-After handling or trimming in `api_client.dart:103`; no `/me/access-log` client. The API has the route (`api/therapylink_api/routers/me.py:96`) |
| 16 | api-hardening | CI: Postgres migrate round trip + tests, docker build; CD release step; TL_ENV=prod; llama-server key | code-now [C] | Done: Postgres job with upgrade + `alembic check` (`ci.yml:66-68`). Missing: downgrade round trip, docker build. CD, TL_ENV=prod and the llama-server key are deploy/owner work (see needs-human) |
| 17 | api-hardening | access_log kept after deletion: retention | needs-human | Lawyer |
| 18 | api-hardening | `email_verified` starts false; approvals need re-sign-in | needs-human | Owner: ask approved clinicians to sign in once before the next approval run |
| 19 | api-hardening | docker build not run | code-now [C] | No docker job in `ci.yml` |
| 20 | api-hardening | Postgres-only migration paths untested | code-now [C] | Upgrade runs in CI (`ci.yml:66`); downgrade and the append-only rules are not exercised |
| 21 | api-hardening | Base image not pinned to a digest | code-now [C] | `api/Dockerfile:1` `FROM python:3.12-slim` |
| 22 | app-crisis | Mirror Guardian patterns in guardian.py; per-file SHA-256; canaries; fine-tuned Eve spec | ml-gpu | Patterns mirrored: `ml/therapylink_ml/train/guardian.py:55-100`. The rest needs a trained Guardian and a fine-tuned LiteRT Eve |
| 23 | app-crisis | Move 'Eve said'/'You said' and safety/unavailable strings to ARB; drop unused crisis keys; GuardianFailed message; clinician `help:false`; cloud runtime in release | code-now [A] | Still hard-coded: `features/eve/eve_screen.dart:25-27`, `features/shared/crisis_copy.dart:51-54`. `crisisTitle`/`crisisBody` unused (`app_en.arb:67-68`; `crisisBody` still says "free"). `settings_screen.dart:116` maps GuardianFailed to errorGeneric. Cloud runtime part is done: dev-only (`settings_screen.dart:80`, `core/settings/settings.dart:137`) |
| 24 | app-crisis | Order messages by createdAt then rowid | code-now [B] | `app/lib/core/db/database.dart:136,141` order by createdAt only; workaround `_stamp()` at `eve_controller.dart:162` |
| 25 | app-crisis | Crisis copy, helpline verification, sticky crisis mode length | needs-human | Clinician + helpline verifier |
| 26 | app-crisis | Release Eve chat is paused until trained Guardian + fine-tuned Eve | ml-gpu | By design; `core/ml/eve_engine.dart:61-62`, `onnx_guardian.dart:16` |
| 27 | app-crisis | Same as 23 (strings outside ARB) | code-now [A] | See 23 |
| 28 | app-crisis | Canaries are English only | ml-gpu | Add Roman Urdu canaries once a Guardian scores on Roman Urdu |
| 29 | app-crisis | No widget test for the release pause | done | Gate functions unit-tested: `app/test/core_test.dart:64-73` |
| 30 | app-crisis | Crisis turns out of memory extraction (F16); two-tier response (F14) | code-now [B] | F16: flagged turns still feed summary/memory (`eve_controller.dart:304`, `_unsummarised` at 397). F14 needs a trained Guardian's probabilities and a clinical call on the soft tier, so it stays out of this round |
| 31 | infra-docs | conftest should use a Postgres `TL_DATABASE_URL` | code-now [C] | `api/tests/conftest.py:4,32` force sqlite |
| 32 | infra-docs | New tables need migrations | done | Enforced by `alembic check` in `ci.yml:68` |
| 33 | infra-docs | Dockerfile doesn't copy alembic | done | `api/Dockerfile:10-11` |
| 34 | infra-docs | Root README line 11 "both on-device" | code-now [E] | `README.md:11` unchanged |
| 35 | infra-docs | Revoke leaked keys, rewrite history, drop the gitleaks allowlist | needs-human | Owner. `.gitleaks.toml:10-16` |
| 36 | infra-docs | Refresh data-inventory, app/README and PRODUCT.md status | code-now [E] | `docs/legal/data-inventory.md:5,11,20-30,69`, `app/README.md:11-13`, `app/PRODUCT.md:15` still describe 9781df2d |
| 37 | infra-docs | Authored rows claim Umang is "free 24/7" | needs-human | Helpline verifier. 40 rows across `data/authored/*.jsonl`, and `ml/therapylink_ml/prompts.py:35`. Editing the served prompt changes the app parity and the run in training, so it waits for the answer |
| 38 | infra-docs | Fill red-lines, helplines, pilot protocol; retention periods | needs-human | Clinician, helpline verifier, lawyer |
| 39 | infra-docs | No downgrade round trip; enum types not dropped | code-now [C] | Initial downgrade drops tables only (`api/alembic/versions/4d9a35f16344_initial_schema.py`) |
| 40 | infra-docs | No docker build, Trivy scan, signed AAB | code-now [C] | Docker build and Trivy are code-now; the signed AAB needs the owner's keystore (see 54) |
| 41 | infra-docs | Same as 34 | code-now [E] | See 34 |
| 42 | app-platform | API field names for delete, consent, care links | done | `api/therapylink_api/schemas.py:40,140-141`, `routers/me.py:50,118` |
| 43 | app-platform | Hide eve_screen "Use cloud mode instead" in release | done | The button is gone; `modelUseCloud` (`app_en.arb:53`) is unused. Stream A deletes the key |
| 44 | app-platform | Use `dateLocaleOf` for DateFormat | code-now [A] | `eve_screen.dart:505`, `journal_screen.dart:28` |
| 45 | app-platform | Error text should use `scheme.error` | code-now [B] | `assessment_screen.dart:135`, `journal_editor_screen.dart:182` use `scheme.tertiary` |
| 46 | app-platform | brand_mark Semantics label via l10n | code-now [B] | `app/lib/features/shared/brand_mark.dart:18` |
| 47 | app-platform | Crisis sheet could add Madadgaar 1098 | done | `features/shared/helplines.dart:38`, used by `crisis_sheet.dart:66` |
| 48 | app-platform | Document dart-define build commands in app/README | code-now [E] | Not in `app/README.md` |
| 49 | app-platform | Real terms/privacy URLs and API host; legal review of consent strings and PrivacyInfo | needs-human | Owner + lawyer + clinician. `consent_screen.dart:11-12`, `app/env/prod.json` |
| 50 | app-platform | Same as 46 | code-now [B] | See 46 |
| 51 | app-platform | Signing files ignored | done | `app/android/.gitignore:12-13`, `app/test/platform_release_test.dart:72` |
| 52 | app-platform | No drift schema change needed | done | No action |
| 53 | app-platform | Legacy shared `therapylink.sqlite` not removed | needs-human | Owner: confirm no tester install holds data. If none does, add a one-time delete |
| 54 | app-platform | Release gradle checks never run | needs-human | Owner: one release build on a machine with the keystore |
| 55 | app-platform | Created `app/env/dev.json`, `prod.json` | done | Both files are tracked |
| 56 | ml-train | Dart patterns mirrored in guardian.py | done | `guardian.py:55-100`; `tests/test_train_guardian.py` passes against the merged `guardian.dart` |
| 57 | ml-train | reply_rules should delegate to safety_rules | code-now [D] | Only 3 checks delegate (`reply_rules.py:144-151`); allowlist duplicated (`reply_rules.py:21-23` vs `safety_rules.py:15`) |
| 58 | ml-train | `tl-kaggle corpus` skips dpo_pairs; `adapter` only uploads `run/adapter` | code-now [D] | `ml/therapylink_ml/kaggle_push.py:64,283-295` |
| 59 | ml-train | App could read `training_prompt.json` | ml-gpu | Needs a fine-tuned on-device Eve export that ships the file |
| 60 | ml-train | Approve 36 red-line rows; legal claim in rl-ch-mx-01; DPO prompts; held-out set; related-notes rows | needs-human | Clinician (+ lawyer for the forced-nikah claim) |
| 61 | ml-train | Old rows say "free 24/7" and assume a male user | needs-human | Helpline verifier + clinician/native reviewer |
| 62 | ml-train | DPO prompt set (~800) not authored | needs-human | Clinician |
| 63 | ml-train | Guardian held-out set (300+) not authored | needs-human | Clinician |
| 64 | ml-train | Guardian parity test skipped in the worktree | done | Runs and passes on the merged tree (`ml/tests/test_train_guardian.py`, 30 passed with `test_prompt_parity.py`) |
| 65 | ml-train | Unsloth/TRL paths never run | ml-gpu | Kaggle smoke run of DPO (SFT smoke landed in `e141b632`) |

## Needs a person, by owner

### Clinician / psychologist
- Review the 10 multi-turn seeds, the judge rubric in `judge.py` VERDICT_CRITERIA, and label ~150 replies as `run,id,sample,criterion,human` (5).
- Write `clinical_expectation` for each probe (7).
- Review all crisis wording in `crisis_copy.dart` and decide how long sticky crisis mode lasts and how it behaves (25).
- Fill `docs/clinical/red-lines.md` and `pilot-protocol.md` (38).
- Review consent, under-18 and emergency ARB strings, and the wording of the "unvalidated translation" notice (14, 49).
- Approve the 36 `pending_clinician` red-line rows and author related-notes rows (60).
- Check gendered Roman Urdu in older authored rows (61).
- Author the ~800 DPO prompts (62) and the 300+ Guardian held-out probes (63).
- Decide the F14 soft tier and whether a structured crisis history should exist (30).

### Helpline verifier
- Confirm numbers, hours, scope and cost for Umang, 1122, 1098, 15 and 1099, and fill `verifiedOn` and `docs/clinical/helplines.md` (25, 38).
- Confirm or strike "free" and "24/7" for Umang in the authored rows and `prompts.py:35` (37, 61). An engineer edits the data after.

### Lawyer / counsel
- Access-log retention after deletion, and retention periods in `data-inventory.md` (17, 38).
- Terms, privacy policy, `PrivacyInfo.xcprivacy` and consent copy (49).
- The claim "qanoon bhi is ke khilaf hai" in `rl-ch-mx-01` (60).

### Owner
- Decide whether 1099 joins the allowlist (1).
- Revoke the leaked GCP, Gemini and Maps keys, rewrite or squash history, then delete the `.gitleaks.toml` allowlist (35).
- Deploy config: set `TL_ENV=prod`, start llama-server with `--api-key` and set `TL_INFERENCE_API_KEY` (including the local `api/.env`), and run the image's `release` command before shifting traffic once a CD target exists (16).
- Ask approved clinicians to sign in once so `email_verified` fills (18).
- Real terms/privacy URLs and the production API host in `app/env/prod.json` (49).
- Confirm no tester install holds data in the legacy `therapylink.sqlite` (53).
- One release `flutter build appbundle` with the keystore, and a signed AAB (40, 54).