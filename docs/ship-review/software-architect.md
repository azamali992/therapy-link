# Ship review: principal engineer and QA lead

Scope: code quality, architecture, tests and release engineering across `app/` (Flutter), `api/` (FastAPI) and `ml/`. Branch `rebuild/v2` at `0185e0dc`. I only read files. I did not edit, build or train anything, and I did not call the model server.

What I ran: `api` pytest (16 passed) and `ml` pytest (36 passed), both from their existing venvs. I did not run `flutter test` or `flutter analyze`, because an eval was using this machine. The README says they are green, but I have not checked that.

## Summary

The codebase is small and easy to read. The comments explain why each decision was made, and prompt parity between app and training is pinned by a test (`ml/tests/test_prompt_parity.py`). That is better discipline than most portfolio projects have. The API's consent model is simple and has tests.

The product is still not safe to hand to patients, for four reasons:

1. **The on-device runtime, which is the default, runs stock Gemma, not Eve.** `app/lib/core/ml/gemma_eve_engine.dart:23-36` downloads `litert-community/gemma-4-E2B-it` and never loads the fine-tune. On the eval, the base model scores 7/24 safety and names a resource on 1 of 14 crisis probes (`ml/runs/eval/base-e2b/summary.json`), against 18/24 and 12/14 for v14.
2. **A release build falls back to the keyword guardian unless someone remembers a `--dart-define`.** `TL_GUARDIAN_URL` defaults to `''` (`app/lib/core/ml/onnx_guardian.dart:15`), and then `guardianProvider` returns `HeuristicGuardian` (`onnx_guardian.dart:210-215`). By the repo's own measurement that guardian catches 12% of crisis probes (`onnx_guardian.dart:176-181`).
3. **The chat controller has real concurrency bugs.** "New conversation" can be tapped while a reply is streaming. That resets `generating` and allows two inferences at once on the single phone model. A double tap can also send twice. The controller itself has no tests.
4. **Release engineering does not exist yet.** The release build is signed with the debug key. There are no flavors, and the API URL defaults to `http://localhost:8000`. There is no crash reporting. Sign-out leaves the last user's conversations, memories and unsent mood points on the device. Chat history cannot be deleted, and there is no account deletion.

Most of these are ordinary engineering fixes. About two weeks of focused work would close the code blockers. The model and clinical gates are separate and are covered in the "What needs a human" section.

## Verdict

**Not ready for real patients.** Six blockers are listed below. Four can be fixed in the repo: ship the fine-tuned model on device, make Guardian mandatory in release, fix the controller races, and wipe local data on sign-out. The other two are a release signing key and an explicit data-deletion path. After those, a closed beta with supervision is reasonable. A public launch also needs the "high" items: crash reporting, a production inference host, rate limits, an encrypted local DB with Android backup turned off, and tests on the controller and crisis path.

## Findings

Severity: blocker = before any real patient; high = before public launch; medium = soon after; low = nice to have.

### Blockers

**B1. The default on-device Eve is stock Gemma, not the fine-tuned model.** Owner: ml + code. Effort: M.
- Evidence: `app/lib/core/ml/gemma_eve_engine.dart:21-36` points `eveModelSpecs` at `litert-community/gemma-4-E2B-it-litert-lm`, and the comment says "The fine-tuned Eve replaces these once the LiteRT-LM export from ml/ is published". `Settings.eveRuntime` defaults to `EveRuntime.onDevice` (`app/lib/core/settings/settings.dart:16`). Eval `base-e2b`: all safety checks 7/24, resource_on_crisis 1/14, language_match 2/8. Eval `sft-v14`: 18/24, 12/14, 8/8. The app still sends the v14 prompt (`eve_engine.dart:9-20`) to a model that was never trained on it.
- Recommendation: export v14 (or the model that replaces it) through `ml/EXPORT.md` step 3 and publish the `.litertlm`. Point `eveModelSpecs` at it, pinned by commit hash, with a SHA-256 check after download. Then re-run the 48 probes against the **LiteRT build on a phone**. The GGUF eval does not prove the int8 LiteRT bundle behaves the same. Until then, either block the on-device runtime in release or default to cloud.

**B2. A release build ships without the trained Guardian unless a dart-define is passed.** Owner: code. Effort: S.
- Evidence: `app/lib/core/ml/onnx_guardian.dart:15` has `String.fromEnvironment('TL_GUARDIAN_URL', defaultValue: '')`. With that empty, `available` is false (`:61`), `download()` returns immediately (`:64`), and `guardianProvider` returns the keyword `HeuristicGuardian` (`:213`). The code's own note puts the model at 53% and keywords at 12% (`:176-181`). Even when the model is installed, a truncated download counts as installed, because `_installed()` only checks that the files exist (`:45-52`). A failed `OnnxGuardian.load()` then falls back to keywords silently (`:196-199`), while Settings still says "Trained model installed" (`app/lib/l10n/app_en.arb:56`).
- Recommendation: bundle the int8 ONNX model and vocab as app assets. The download path cannot be trusted for safety. If it stays a download, make the release build fail when `TL_GUARDIAN_URL` is empty, write to a temp file, check a SHA-256, and rename only on success. Report `GuardianFailed` when `load()` throws. Block Eve until Guardian is ready, or tell the user it is not.

**B3. Controller races: "New conversation" mid-reply, and double send.** Owner: code. Effort: M.
- Evidence:
  - `EveController.newConversation` (`app/lib/features/eve/eve_controller.dart:130-138`) never checks `state.generating`. It sets `state = const EveState()`, and the menu item is always enabled (`app/lib/features/eve/eve_screen.dart:128`).
  - The in-flight `send` keeps streaming into `state.partial` (`eve_controller.dart:315-320`). The composer re-enables because `enabled: !state.generating` (`eve_screen.dart:157`), so a second `send` can start `engine.reply` while the first is still running.
  - `_schedule(() => _maintain(previous, closing: true))` starts at once because `_upkeep` has already resolved. That is a third concurrent call on the single `GemmaEveEngine`, which `_load()` shares (`gemma_eve_engine.dart:117-120`).
  - When the first `send` finishes it runs `state = EveState(...)` (`eve_controller.dart:189`), which clears `generating` in the middle of the second reply.
  - Separately, `send` checks `state.generating` at `:142` but only sets it at `:151`, after two awaited DB writes. Two quick taps on a starter chip (`eve_screen.dart:428`), or Enter pressed twice, both get past the guard.
  - The same gap exists in `wrapUp` (`:197` vs `:203`).
- Recommendation: set a synchronous `_busy` flag (or `generating: true`) before the first `await`. Route every engine call through one serial queue: reply, summary, memory and wrap-up. Today only upkeep is queued. Disable "New conversation" while generating, or have it cancel the in-flight reply with a cancellation token. Put `send` in `try/finally` so `generating` can never stay stuck (`:140-191` has no `finally`).

**B4. Sign-out leaves the previous user's data on the device, and their mood points get uploaded under the next user.** Owner: code. Effort: S.
- Evidence: `AuthRepository.signOut` (`app/lib/core/auth/auth_repository.dart:47-52`) only signs out of Firebase. It does not touch the drift DB (conversations, messages, memories, `MoodQueue`), SharedPreferences (`conversationId`, `memoryEnabled`) or the downloaded models. `MoodQueue` has no uid column (`app/lib/core/db/database.dart:55-62`). `_syncMood` uploads every pending row with whichever token is current (`eve_controller.dart:376-388`, `api_client.dart:13-16`). So on a shared family phone, which is common in the target market, the next person to sign in sees Eve's memory notes about the previous user, and the previous user's mood points go into the new user's clinician-visible trend.
- Recommendation: on sign-out, delete the DB file (or drop all rows) and clear conversation and memory prefs. Or key the DB file by uid. Add a uid column to `MoodQueue` and only upload rows that match the signed-in user.

**B5. The release build is signed with the debug key and has no release configuration.** Owner: code + human (key custody). Effort: S.
- Evidence: `app/android/app/build.gradle.kts:32-38` has `signingConfig = signingConfigs.getByName("debug")` next to the Flutter TODO. There is no `key.properties` loading, no `minifyEnabled` or R8 keep rules for ONNX Runtime and LiteRT, and no flavors. Google Sign-In also needs the release SHA-1 (`app/README.md:36`).
- Recommendation: create an upload key, stored outside the repo with a backup, and enrol in Play App Signing. Load `key.properties` in Gradle and fail the release build if it is missing. Add R8 with keep rules and test the minified build on a device. Register the release and Play-signing SHA-1s in Firebase.

**B6. No way to delete chat history or the account.** Owner: code. Effort: M.
- Evidence: `database.dart` has `clearMemories` and `deleteMemory` (`:103-105`) but no conversation or message deletion. The only `onDelete: cascade` is on the Messages FK (`:44`), and drift does not enforce FKs unless `PRAGMA foreign_keys = ON` is set in `beforeOpen`, which it is not. The API has no `DELETE /me` and no export endpoint (`api/therapylink_api/routers/me.py`). Play policy requires in-app account deletion for apps that create accounts, and patients will expect to be able to erase a mental-health chat.
- Recommendation: add "Delete this conversation" and "Delete everything on this device". Add `DELETE /me`, which cascades through `users` (all FKs already have `ondelete="CASCADE"`, `api/therapylink_api/models.py`) and deletes the Firebase user. Enable `foreign_keys` in drift's `beforeOpen`.

### High

**H1. Guardian only reads the start of long text, and the cross-turn check puts the newest message last.** Owner: code. Effort: S.
- Evidence: `SentencePieceTokenizer.encode` stops at `maxLen - 1` tokens and keeps the head (`app/lib/core/ml/tokenizer/sentencepiece.dart:101-110`, `max_len` 128 from `ml/therapylink_ml/export/tokenizer_json.py:38`). `_crisisAcrossTurns` builds `earlier…, current` and keeps the last 600 characters (`eve_controller.dart:278-279`). 600 characters of Roman Urdu is well over 128 tokens, so the model cuts off exactly the current message the check exists for. A single long message with the risk statement at the end only gets keyword coverage.
- Recommendation: truncate from the head so the tail is kept, and put the current message first in the joined text. For long messages, run overlapping 128-token windows and take the maximum. Add a test: 3 long neutral sentences followed by "mar jaun to behtar hai" must flag (see missing tests T2).

**H2. No timeout or cancel on inference, and the app and API timeouts do not match.** Owner: code. Effort: S.
- Evidence: `send` awaits `_upkeep` (`eve_controller.dart:175`). A summary (300 tokens) and a memory pass (250 tokens) can take tens of seconds on a phone GPU, with no timeout and no stop button. If LiteRT hangs, the chat stays in "typing" forever. In cloud mode Dio's `receiveTimeout` is 30 s (`app/lib/core/api/api_client.dart:9`) but the API waits 60 s upstream (`api/therapylink_api/routers/inference.py:27`), so slow replies turn into `eveFailureReply` while the server is still generating.
- Recommendation: add a per-turn deadline and a Stop button that cancels the stream. Put upkeep on a timeout and skip it when the user is waiting. Set the client timeout above the server's, and have the server return 504 at its own deadline.

**H3. The chat database is unencrypted, and Android Auto Backup is on.** Owner: code. Effort: M.
- Evidence: `driftDatabase(name: 'therapylink')` (`database.dart:70`) is plain SQLite. `AndroidManifest.xml` has no `android:allowBackup="false"` and no `dataExtractionRules`, so Android's default backup uploads the app's data to the user's Google Drive. `flutter_secure_storage` is declared in `pubspec.yaml` but never used (grep over `lib/` finds nothing).
- Recommendation: use SQLCipher (`sqlcipher_flutter_libs` with drift) and keep the key in `flutter_secure_storage`. Set `allowBackup="false"`, or add extraction rules that exclude the DB.

**H4. No crash reporting or observability in the app or API.** Owner: code. Effort: S.
- Evidence: errors go only to `debugPrint` (`eve_controller.dart:227, 283, 322, 329, 386`; `onnx_guardian.dart:197`), which is stripped in release. The API has no logging config, no Sentry and no request ids. `/health` does not check the DB (`api/therapylink_api/main.py:31-33`).
- Recommendation: add Firebase Crashlytics or Sentry, with a PII scrubber so message text is never attached. Count Guardian failures and inference failures without logging any text. Make `/health` check the DB.

**H5. The inference proxy has no rate limit or input cap, and the upstream is a laptop.** Owner: code + human. Effort: M.
- Evidence: `ChatIn.messages` has no maximum count and `ChatMessage.content` has no maximum length (`api/therapylink_api/schemas.py:145-153`). Any Firebase user can sign up and call `/inference/chat` (`routers/inference.py:11`). There is no Firebase App Check. `api/.env.example` describes the upstream as "the 2050 box behind a Cloudflare Tunnel". `inference_model` defaults to `"eve-e4b"` (`settings.py:11`), but the trained model is E2B.
- Recommendation: cap messages at about 40 and content at about 4 k characters. Add a per-uid rate limit and App Check. Budget for a real GPU host before cloud mode is offered to patients, or remove the cloud option from release builds.

**H6. There is no production migration path for the API.** Owner: code. Effort: S.
- Evidence: `create_all` only runs for SQLite (`api/therapylink_api/main.py:13-14`). The Dockerfile copies only `therapylink_api/` and `pyproject.toml` (`api/Dockerfile:5-7`), leaving out `alembic/` and `alembic.ini`, so a container cannot run `alembic upgrade head`. The migrations were generated against SQLite (`render_as_batch`, `(CURRENT_TIMESTAMP)` defaults in `api/alembic/versions/4d9a35f16344_initial_schema.py`). I have not verified that they run on Postgres. Dependencies are lower bounds only, with no lock file (`api/pyproject.toml:5-18`).
- Recommendation: copy the alembic files into the image and run `alembic upgrade head` as a release step. Add a CI job that runs the migrations against a Postgres service container and checks `alembic check` for drift. Pin dependencies with `uv lock` or `pip-compile`.

**H7. Release configuration depends on dart-defines that nothing enforces.** Owner: code. Effort: S.
- Evidence: `TL_API_URL` defaults to `http://localhost:8000` (`api_client.dart:6`). `TL_GUARDIAN_URL` defaults to `''`. There are no flavors. Release cleartext is blocked (only the debug manifest allows it, `app/android/app/src/debug/AndroidManifest.xml`), so a release build without the define fails every API call and shows generic errors.
- Recommendation: add `dev` and `prod` flavors, or a `--dart-define-from-file=env/prod.json` that is checked in, plus an `assert`/startup check that refuses `localhost` or `http://` in release mode.

**H8. The crisis sheet lists two numbers, and a failed call is silent.** Owner: code + human. Effort: S.
- Evidence: `app/lib/features/shared/crisis_sheet.dart:7-8, 46-57` has Umang and 1122 only. The brief says Madadgaar 1098 is included, but it is not in the sheet or in the ARB files (grep `1098` finds nothing). `launchUrl` results are ignored (`:48, :54`), so on a tablet without telephony the tap does nothing, and the 1122 number only appears inside the button label.
- Recommendation: check the result of `launchUrl`. On failure, show the number as selectable text with a copy button. A human needs to confirm the list and each line's hours (see What needs a human).

### Medium

**M1. Mood points can upload twice.** Owner: code. Effort: S.
- Evidence: `_syncMood()` runs without an await (`eve_controller.dart:159`). If a sync is still in flight, for example on a slow network with the 30 s timeout, the next `send` reads the same `pendingMood()` rows and uploads them again. `POST /mood/batch` has no idempotency key (`api/therapylink_api/routers/mood.py:14-18`). Duplicates skew the trend a clinician sees.
- Recommendation: use a single-flight guard in `_syncMood`, and send the client row id as an idempotency key with a unique constraint on the server.

**M2. Drift stores DateTime at second precision, but the summary and memory cut-offs compare with `isAfter`.** Owner: code. Effort: S.
- Evidence: there is no `build.yaml` in `app/`. By drift's default, `DateTimeColumn`s are stored as unix seconds. `_unsummarised` keeps messages with `createdAt.isAfter(summarizedThrough)` (`eve_controller.dart:288-291`), and `summarizedThrough` is `older.last.createdAt` (`:348`). A message in the same second as the last summarised one, such as a fast cloud reply or the crisis reply written right after the user turn, is then in neither the summary nor the history. `watchMessages` orders only by `createdAt` (`database.dart:109-110`), so rows in the same second have no defined order. I reasoned this from drift's documented default and have not reproduced it on a device.
- Recommendation: set `store_date_time_values_as_text: true` in `build.yaml` (this needs a schema v3 migration), or add a monotonic `seq` column and order and cut by it.

**M3. The crisis sheet can be lost, and wrap-up clears state.** Owner: code. Effort: S.
- Evidence: the listener calls `crisisShown()` **before** `showCrisisSheet` (`eve_screen.dart:78-82`). If the context is not usable at that moment, the flag is already cleared and the sheet never shows. `wrapUp`'s `finally` sets `state = const EveState()` (`eve_controller.dart:229-231`), which drops a pending `crisisPending` and `suggestBreak`.
- Recommendation: clear the flag after the sheet has been presented. In `wrapUp`, only reset `generating` and `partial`.

**M4. Race on first request creating the user.** Owner: code. Effort: S.
- Evidence: `_get_or_create_user` does get-then-insert (`api/therapylink_api/auth.py:29-35`). On first sign-in the app fires `/me` and possibly `/mood/batch` together, and the second insert raises IntegrityError, which becomes a 500.
- Recommendation: use `INSERT … ON CONFLICT DO NOTHING`, then select.

**M5. The dev auth bypass has no production guard.** Owner: code. Effort: S.
- Evidence: `TL_DEV_AUTH_BYPASS=true` lets any caller become any uid through `X-Dev-Uid` (`auth.py:40-43`). The only protection is a README sentence.
- Recommendation: refuse to start when the bypass is on and `database_url` is not SQLite. Also strip the exception text from `invalid token: {e}` (`auth.py:50`).

**M6. Cloud mode sends the conversation, and the privacy copy does not always say so.** Owner: code. Effort: S.
- Evidence: switching to cloud takes one tap from the model banner (`eve_screen.dart:272, 293`) with no confirmation. `CloudEveEngine.complete` also sends the summary and memory passes, so the whole conversation leaves the device (`eve_engine.dart:83`). `youDataBody` says "Conversations with Eve stay on this device" whatever the mode (`app_en.arb:218`).
- Recommendation: add a confirmation dialog that states what leaves the device, and make `youDataBody` depend on the mode.

**M7. Guardian resource handling.** Owner: code. Effort: S.
- Evidence: `OrtValue`s created per message are never disposed (`onnx_guardian.dart:115-119`). Every rebuild of `guardianProvider` creates a new `OnnxGuardian.load()`, and the session is never closed (`:210-215`). I have not verified the native memory growth on a device.
- Recommendation: dispose inputs and outputs after `run`, and hold one session in a provider with `onDispose`.

**M8. There is no audit trail of clinician access.** Owner: code. Effort: M.
- Evidence: `GET /clinician/patients/{uid}` returns journal, summaries and assessments without recording who read what (`api/therapylink_api/routers/clinician.py:69-85`).
- Recommendation: add an `access_log` table written on every overview read, and show it to the patient on the Care screen.

**M9. The eval scorer is untested, and eval evidence is not versioned.** Owner: ml. Effort: S.
- Evidence: `ml/therapylink_ml/eval/safety_rules.py` produces the 18/24 gate but has no test (grep over `ml/tests/` finds none). `ml/runs/` is gitignored (`.gitignore`), so the evidence behind a model going live cannot be reproduced from the repo. ML training requirements are unpinned (`ml/requirements-train.txt`: `unsloth`, `trl>=0.15`, `bitsandbytes`).
- Recommendation: add golden tests for `safety_rules` (known pass and fail replies per rule). Commit each shipped model's `summary.json`, and a hash of `scored.jsonl`, to `ml/releases/<model>.json`. Pin the Kaggle environment.

**M10. CI does not guard what matters.** Owner: code. Effort: M.
- Evidence: `.github/workflows/ci.yml` runs only on pushes to `main` and on PRs. `rebuild/v2` is where all the work is, and I have not verified whether any PR has triggered CI. There is no Android build job, so the release config is never compiled in CI. There is no alembic or Postgres job. The Dart/HF tokenizer parity test always skips in CI because the fixtures are gitignored (`app/test/tokenizer_reference_test.dart:8-12, 27`). There is no coverage report.
- Recommendation: see the release checklist below.

### Low

**L1. `Instrument.values.byName` crashes on a bad deep link.** Evidence: `app/lib/app/router.dart:84`. Recommendation: validate the parameter and redirect.

**L2. google_fonts downloads fonts at runtime.** Evidence: `app/lib/app/theme/theme.dart:19-20`, no bundled fonts under `assets/`. First launch offline shows fallback fonts, and the Nastaliq font is large. Recommendation: bundle the fonts and set `GoogleFonts.config.allowRuntimeFetching = false`.

**L3. The 2 GB model download has no Wi-Fi check and no resume.** Evidence: `gemma_eve_engine.dart:85-98`. Recommendation: warn on metered connections and let the download resume.

**L4. Mood trend buckets days in UTC.** Evidence: `api/therapylink_api/routers/mood.py:8-12` groups by `recorded_at.date()` in UTC, so Pakistan's 00:00–05:00 counts as the previous day. Recommendation: accept a `tz` parameter and bucket in local time.

**L5. The invite endpoint links to a clinician who has left clinician mode.** Evidence: `care.py:27-29` checks only `verified_at`, not `role`. Recommendation: also require `user.role == clinician`.

**L6. Dead code and config.** Evidence: `kConversationId` (`eve_controller.dart:15`) is unused, and so is `flutter_secure_storage` (`pubspec.yaml`). `firebase-admin` is listed in `api/pyproject.toml` but never imported by the API package. Recommendation: remove them or use them.

## Missing tests that matter most

In priority order, with exact scenarios. None exists today. `app/test/eve_controller_test.dart` only exercises `HeuristicGuardian`, not `EveController`.

**T1. `EveController` with fake engine, guardian and in-memory drift** (`AppDatabase(NativeDatabase.memory())`).
- a) A crisis verdict writes the user row with `flagged=true`, writes exactly one assistant row whose content is `crisisReply`, sets `crisisPending=true`, and makes **zero** `engine.reply` calls.
- b) Calling `send` twice without awaiting produces one user row and one `engine.reply` call.
- c) `newConversation()` during a reply that is still streaming (the fake stream is held open by a Completer) causes no concurrent engine call, and the old reply lands in the old conversation.
- d) If the engine throws before the first token, an `eveFailureReply` row is saved, `generating=false`, and the row is excluded by `buildHistory`.
- e) If `guardian.classify` throws, `generating` returns to false. This test fails today.
- f) With `_upkeep` blocked, `send` still shows the user row and times out rather than hanging. This needs H2.
- g) `wrapUp` with fewer than 2 user turns returns false and writes nothing. With a stub summary and step, it writes one assistant row and one `plan` memory, and only when `memoryEnabled` is on.
- h) With memory disabled, `allMemories` is never read into notes, and `_maintain` writes no memories.
- i) A severe turn (valence ≤ −2) sends `notes: null` even when related memories exist.

**T2. Crisis detection across turns and long text.**
- a) Two neutral earlier messages, then "I have the pills ready", flags.
- b) A 600-character Roman Urdu vent ending in "ab jeena nahi chahta" flags through the model path, not only through keywords. Use the real tokenizer fixture; this needs H1.
- c) A message already flagged earlier does not re-trigger on "thanks".
- d) Messages older than 20 minutes are ignored.

**T3. Guardian loading.** A truncated `guardian.int8.onnx` produces `GuardianFailed`, not `GuardianReady`. `UnionGuardian` falls back to keywords and reports it.

**T4. Drift migration tests.** Use `drift_dev schema dump` and `SchemaVerifier`: v1 → v2 keeps messages and adds the memories table. Add the same for every future version (v3 is needed for M2 and B4).

**T5. Sign-out isolation.** User A chats and builds memories, signs out, user B signs in. B sees no conversations or memories, and A's pending mood rows are not uploaded with B's token.

**T6. Crisis sheet widget test.** With `crisisPending` flipped, the sheet shows Umang and 1122 with visible numbers. When `launchUrl` returns false, the number stays on screen as copyable text.

**T7. API.**
- a) `/inference/chat` with an upstream mock: an empty reply gives 502, a timeout gives 504, and 200 messages or a 100 k-character body gives 422.
- b) `/mood/batch` sent twice with the same idempotency key stores the points once.
- c) Two concurrent first requests for a new uid both return 200.
- d) `DELETE /me` removes every row across all tables.
- e) With the bypass flag on and a Postgres URL, the app refuses to start.
- f) Real Firebase token path: expired token, wrong audience, and a missing `sub` all give 401 and never 500 (mock `_verify`).
- g) Journal update, delete and ownership. Only reading another patient's journal is tested today.

**T8. ML.**
- a) Golden cases for every rule in `safety_rules.py`.
- b) The tokenizer parity test runs in CI from a small committed fixture: 50 probes, not the full 8 MB vocab. Or fetch the fixture from a pinned HF revision.
- c) A test that `eveModelSpecs` points at the model version recorded in `ml/releases/`.

## Release-engineering checklist for this repo

Android app:
- [ ] Upload keystore created and backed up offline. `key.properties` read in `app/android/app/build.gradle.kts`. The build fails without it. Play App Signing enrolled.
- [ ] Release and Play-signing SHA-1/SHA-256 added to Firebase project `therapylink69` for Google Sign-In.
- [ ] `applicationId` `com.therapylink.therapylink` confirmed as final. It cannot change after the first Play upload.
- [ ] `version:` in `app/pubspec.yaml` (currently `2.0.0+1`) bumped by CI from a tag, with build number = CI run number.
- [ ] Flavors `dev` and `prod`, or `--dart-define-from-file=env/prod.json`, with `TL_API_URL=https://…` and the Guardian source. A startup assert rejects `localhost` and `http` in release.
- [ ] Guardian ONNX and vocab bundled as assets, or downloaded with SHA-256 checks. The fine-tuned `.litertlm` pinned by HF revision with its SHA-256.
- [ ] R8 enabled, with keep rules for `ai.onnxruntime`, LiteRT-LM and flutter_gemma, and the minified build tested on a real arm64 device. `--obfuscate --split-debug-info` with symbols uploaded to the crash reporter.
- [ ] `android:allowBackup="false"` (or data extraction rules) set. SQLCipher enabled.
- [ ] Play Console declarations: `FOREGROUND_SERVICE_DATA_SYNC` use (manifest line 4), Data Safety form (mood and assessments go to the server; chat stays on device unless cloud mode), and health-app declaration.
- [ ] Ship an AAB (`flutter build appbundle --release`); Play splits by ABI. Confirm `minSdk` meets flutter_gemma's GPU requirement. I did not verify the current value (`flutter.minSdkVersion`).
- [ ] Device matrix: at least one 4 GB RAM Android device and one mid-range device, covering first run with no model, model download, airplane mode, and a crisis message in English and in Roman Urdu.

API:
- [ ] Image includes `alembic/`, and `alembic upgrade head` runs before rollout. Migrations tested on Postgres in CI.
- [ ] Dependencies locked. Image rebuilt from the lock file.
- [ ] Startup guard against `TL_DEV_AUTH_BYPASS` and `TL_DEV_AUTO_VERIFY_CLINICIANS` outside SQLite.
- [ ] Secrets only in the host's secret store. `api/.env` exists locally and is gitignored; its contents were not read.
- [ ] Rate limits and request size caps. App Check on `/inference/chat`.
- [ ] Sentry or structured logs with no PII, `/health` that checks the DB, uptime alerting.
- [ ] Nightly Postgres backups with a tested restore.
- [ ] Uvicorn behind a TLS-terminating proxy with `--proxy-headers`, more than one worker, and a host outside the dev laptop.

CI (`.github/workflows/ci.yml`):
- [ ] Trigger on pushes to all branches, or at least `rebuild/**`.
- [ ] Add `flutter build appbundle --release` (unsigned or with a CI key) so release config breakage is caught.
- [ ] Add a Postgres service job running alembic upgrade and `alembic check`.
- [ ] Add a coverage report with a floor on `lib/features/eve/` and `lib/core/ml/`.
- [ ] Make the tokenizer parity test run, not skip.
- [ ] Add a model release gate: a job that reads `ml/releases/<model>.json` and fails if the shipped model's safety numbers are below the agreed threshold.

Before every model release:
- [ ] Run the 48 probes on the exact artifact the app downloads (LiteRT int8, on device), not only on the GGUF.
- [ ] Check prompt parity. `ml/tests/test_prompt_parity.py` exists; keep `SERVED_SYSTEM_PROMPT` in step.
- [ ] Clinician review of a random sample of transcripts, plus all crisis-probe outputs.

## Recommendations

In order:

1. Fix the controller with one engine queue, a synchronous busy flag, `try/finally` and cancellation (B3, H2), and write T1 at the same time. This is the highest-leverage code change.
2. Ship the real Eve on device and make Guardian non-optional in release (B1, B2, H1). Re-run the probes on the LiteRT build.
3. Handle local data properly: wipe on sign-out, per-user mood queue, deletion, encryption, backup off (B4, B6, H3).
4. Release plumbing: signing, flavors, R8, crash reporting, CI build job (B5, H4, H7, M10).
5. API hardening: migrations in the image, locked deps, rate limits, idempotent mood upload, user-create race, bypass guard, access log (H5, H6, M1, M4, M5, M8).
6. Store each model's eval evidence in the repo and test the scorer (M9).

## What needs a human

- **Clinical safety sign-off.** A licensed psychologist or psychiatrist must review the crisis flow, the crisis reply text (`crisisBody` in `app/lib/l10n/app_en.arb:68` and the Urdu ARB), the grounding and break nudges, and a transcript sample from the model that actually ships. They must also decide the minimum eval bar: 18/24 safety leaves 6 probes failing, and 2 of 14 crisis probes name no resource even on v14.
- **Helpline verification.** Someone must call and confirm that Umang 0311-7786264, Rescue 1122 and Madadgaar 1098 are current, what hours each runs, and that each is willing to be listed. Decide whether 1098 belongs in the sheet (it is missing today). Do this again every quarter.
- **Legal and regulatory.** A privacy policy and terms, written by counsel, that cover Pakistan's data protection regime and Play's health-app policy. A decision on whether the product is a wellness app or a medical device. Consent language for clinician sharing. Licensing for BDI-II, which is Pearson-copyrighted; it is in the API enum (`api/therapylink_api/models.py`, `app/lib/core/api/models.dart:3`), even though the app shows no items for it (`app/lib/features/assessments/assessment_items.dart:10`).
- **Clinician verification process.** Today it is a manual script (`api/scripts/verify_clinician.py`). Someone has to check licences against the PMDC register, or the equivalent for psychologists, and own that process.
- **Key custody.** Holding the Android upload key, Firebase project ownership, the HF repo that hosts the models, and production database credentials.
- **Revoking legacy secrets.** `.gitignore` notes that the legacy app's working copy "holds a Gemini API key, Maps keys and a GCP service-account key", and the legacy code is still in git history under tag `legacy-fyp`. Those keys must be rotated or revoked in their consoles. I did not open anything under `legacy/`.
- **Production inference hosting budget.** Cloud mode currently depends on a personal laptop behind a tunnel. Someone has to decide whether to pay for hosting or drop cloud mode for launch.
