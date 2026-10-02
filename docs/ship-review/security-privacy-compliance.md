# Security, privacy and regulatory review

Role: security, privacy and regulatory lead. Branch `rebuild/v2`, reviewed 2026-09-24. Read-only review; nothing under `legacy/` or any credential file was opened. Secrets are reported by path and commit only.

## Summary

The server side is in better shape than most projects at this stage. Every patient-data endpoint scopes by the caller's uid, clinician reads go through an active care link plus per-section consent flags that default to off, and there is a test for it (`api/tests/test_consent.py:40-63`). Release Android builds are HTTPS-only. There is no analytics or ads SDK in `app/pubspec.yaml`, and the server has no chat table (`api/therapylink_api/models.py:1-3`).

The problems are in four places:

1. **A live-looking credential leak on the same Firebase project that runs auth today.** A GCP service-account key file was committed in `a3162bff` and is still reachable from `origin/main`. Project memory records it as a key for project `therapylink69`, which is also the default auth project (`api/therapylink_api/settings.py:10`).
2. **The privacy promise the app makes is not what the code does.** The app says "Nothing you say here is uploaded" and "Never uploaded". In fact:
   - The chat database is unencrypted and included in Android Auto Backup.
   - On iOS the app turns on file sharing.
   - Signing out leaves one person's chats on the phone for the next account.
   - Every chat turn sends an emotion reading to the server.
   - One tap switches to "cloud mode", which sends the full conversation, memory notes and summaries to a llama-server on the developer's laptop through a Cloudflare tunnel.
3. **Patients have no data rights in the product.** Nothing can be deleted or exported: not the account, not the server data, not Eve conversations.
4. **The legal basics are missing for health data and minors.** There is no privacy policy, no terms, no "not a therapist / not for emergencies" consent, and no age gate. Probe s10, a 14-year-old, is exactly the user who will arrive.

Two findings belong to other leads, but they change the regulatory picture, so they appear here too:
- The on-device model that the privacy copy describes is stock Gemma, not Eve (`app/lib/core/ml/gemma_eve_engine.dart:21-35`). It scores 7/24 on safety and names a resource on 1/14 crisis probes (`ml/runs/eval/base-e2b/summary.json`).
- Eve was trained on CC BY-NC data and scraped CounselChat, which a company cannot ship commercially without clearance.

## Verdict

**Not ready for real patients.** Six blockers stand in the way: the leaked key, the privacy claims, deletion, consent and age, the cloud path, and the on-device model. About half are code work of a few days. The rest need a lawyer, a registered company entity, and a clinician who signs off on the safety process. Engineering alone cannot clear the regulatory questions: whether this is SaMD under DRAP, and which data-protection regime applies. The app should launch as a wellness and self-help product with conservative claims until counsel says otherwise.

## Findings

Severity: blocker = before any real patient; high = before public launch; medium = soon after; low = nice to have. Effort: S = hours, M = days, L = weeks.

| # | Title | Sev | Owner | Effort |
|---|---|---|---|---|
| F1 | GCP service-account key in git history, same project as production auth | blocker | human | S |
| F2 | The "stays on this phone" promise is false: plaintext DB, Auto Backup, iOS file sharing | blocker | code | M |
| F3 | Cloud mode sends full chat, memories and summaries to a personal laptop, switched on with one tap | blocker | code + human | M |
| F4 | No account, server-data or conversation deletion; no export | blocker | code | M |
| F5 | No privacy policy, terms, AI or emergency disclaimer, or consent capture | blocker | human + code | M |
| F6 | No age gate; minors will use it | blocker | human + code | S |
| F7 | On-device model is untuned Gemma (7/24 safety), yet it is the privacy-preserving default | blocker | ml | L |
| F8 | Sign-out keeps the previous user's chats; mood queue uploads to the wrong account | high | code | S |
| F9 | Per-turn chat emotion metadata uploaded automatically, contradicting code comments and copy | high | code | S |
| F10 | Training data includes CC BY-NC and scraped sources; commercial use not cleared | high | human + ml | M |
| F11 | Clinician verification is a manual script trusting free-text licence numbers | high | human + code | M |
| F12 | No audit trail of clinician access to patient data | high | code | M |
| F13 | No rate limiting, unbounded request bodies, no App Check; anyone can burn the GPU | high | code | M |
| F14 | Release build signed with the debug key | high | code | S |
| F15 | No in-app reporting of AI output (Google Play AI-generated content policy) | high | code | S |
| F16 | Care link goes active without clinician acceptance; the risk flag implies monitoring nobody promised | medium | code + human | M |
| F17 | Turning on journal sharing exposes 50 past entries, including pre-consent ones | medium | code | S |
| F18 | Roman Urdu PHQ-9/GAD-7 is an unvalidated translation and clinicians cannot tell | medium | code + human | S |
| F19 | Model and Guardian downloads have no integrity check; a tampered thresholds file silences crisis detection | medium | code | S |
| F20 | Dev auth bypass has no production guard | medium | code | S |
| F21 | No MFA for clinicians; no email verification | medium | code | S |
| F22 | No retention policy; server keeps mood, summaries and assessments indefinitely | medium | human + code | S |
| F23 | Crisis sheet lacks a child helpline; Madadgaar 1098 is not in the app | medium | code + human | S |
| F24 | Firebase client config tracked; keys should be restricted | low | human | S |
| F25 | Error messages echo upstream exceptions (token and tunnel details) | low | code | S |
| F26 | BDI-II (Pearson-licensed) in the API enum | low | code | S |
| F27 | No iOS privacy manifest | low | code | S |

### F1. GCP service-account key in git history (blocker, human, S)

**Evidence**
- `git log --all` shows `assets/google_speech.json` added in commit `a3162bff` (2025-07-27) and removed in `d654a9f3` (2026-09-15).
- `git branch -r --contains a3162bff` returns `origin/main`, and tag `legacy-fyp` also contains it.
- Firebase client files were committed repeatedly: `android/app/google-services.json` and `lib/firebase_options.dart` in `b561cf9c`, `48fd1cc5`, `dd4c8846`, `96485576` and `fd56966f`.
- Project memory records the key as a real service account for project `therapylink69`. That is the default `firebase_project_id` in `api/therapylink_api/settings.py:10`.
- Memory also records Gemini and Maps API keys in legacy history.
- The file's contents were not opened.
- Remote visibility was not verified: `gh` is not installed.

**Risk.** If the key is still valid and its service account holds Editor or Firebase Admin roles, anyone holding it can read or delete Firebase Auth users, mint custom tokens, and reach any GCP resource in the project that will hold patient identities. The owner also plans to push `--all --tags` to the company remote (`AZEKTRAAI/therapylink`). That would copy the key there as well.

**Recommendation**
1. Today, in GCP IAM, disable and delete that key and every other user-managed key on the account, and review the audit logs for its use.
2. Revoke the Gemini and Maps keys.
3. Then choose one:
   - rewrite history with `git filter-repo` on a fresh clone and force-push, or
   - start the company remote from a squashed `rebuild/v2` with no `legacy-fyp` tag.
4. Add gitleaks to `.github/workflows/ci.yml`. It has no secret scan today.
5. Consider a new Firebase project for production so the patient identity store never shared a project with a leaked key.

### F2. The "stays on this phone" promise is false (blocker, code, M)

**What the app claims**
- `app/lib/l10n/app_en.arb:13` says "She runs on this phone, so what you say stays here".
- `:32` says "Nothing you say here is uploaded".
- `app/lib/core/db/database.dart:28` says "Never uploaded".

**Evidence**
- The drift database is opened with `driftDatabase(name: 'therapylink')` and no encryption (`database.dart:66`). `flutter_secure_storage` is declared in `app/pubspec.yaml` but used nowhere in `lib/`.
- `app/android/app/src/main/AndroidManifest.xml:6-9` sets no `android:allowBackup`, `fullBackupContent` or `dataExtractionRules`. Android Auto Backup therefore copies app databases and shared preferences to the user's Google Drive, and device-to-device transfer copies them too. That covers messages, memories, summaries and the Guardian crisis flag per message (`database.dart:40-49`).
- `app/ios/Runner/Info.plist:48-49` sets `UIFileSharingEnabled` to true. That exposes the app's Documents folder in Finder and iTunes. Whether drift_flutter's default path sits in Documents was not verified at runtime; check it.
- There is no app lock (PIN or biometric). Phones are often shared within families in Pakistan.

**Recommendation**
- Set `android:allowBackup="false"`, or add `dataExtractionRules` that exclude `databases/` and `shared_prefs/`.
- Set `UIFileSharingEnabled` to false and exclude the DB from iCloud backup.
- Encrypt the DB with SQLCipher (drift supports it through `sqlcipher_flutter_libs`), keeping the key in `flutter_secure_storage`.
- Add an optional app lock.
- Rewrite the copy to state only what stays true, for example: "Your conversations are stored only on this phone, encrypted."

### F3. Cloud mode sends everything to a personal laptop (blocker, code + human, M)

**What gets sent**
- `CloudEveEngine.reply` sends the whole folded history, system prompt and relevant memory notes to `/inference/chat` (`app/lib/core/ml/eve_engine.dart:70-72`).
- `complete()` sends the transcripts used for summaries, memory extraction and wrap-up (`eve_engine.dart:83`, called from `app/lib/features/eve/eve_controller.dart:345` and `:354`).
- The server forwards all of it to `TL_INFERENCE_BASE_URL` (`api/therapylink_api/routers/inference.py:27-29`). According to `api/.env.example` and project memory, that is the developer's RTX 2050 laptop behind a Cloudflare Tunnel.

**How the patient ends up in cloud mode**
- The switch is one tap on "Use cloud mode instead" when the model is missing or fails to download (`app/lib/features/eve/eve_screen.dart:272`, `:293`). No consent dialog appears.
- The only disclosure is one small line in Settings (`app_en.arb:33`) and a subtitle.
- The memory table claims "Never uploaded", which is false in cloud mode.

**What was not verified**
- Whether llama-server or the tunnel logs prompts.

**Risk.** Mental-health conversations get processed on a personal machine with no DPA, no access control and no retention policy. It also contradicts the welcome screen.

**Recommendation**
- For the first patient release, compile cloud mode out of release builds, or hide it behind a server flag.
- If cloud mode is needed, which it is today because only the cloud path runs the fine-tuned Eve (see F7):
  1. Host it on a provider with a signed DPA, in a region counsel approves.
  2. Turn off prompt logging.
  3. Show an explicit opt-in screen that says what is sent, where it goes and how long it is kept.
  4. Record that consent server-side.
  5. Correct the "Never uploaded" comment and copy.

### F4. Nothing can be deleted or exported (blocker, code, M)

**Evidence**
- The API has no `DELETE /me`, and no delete endpoint for summaries, assessments or mood points. The routers are listed in `api/therapylink_api/main.py:22`; `journal.py` alone has delete, at `:47-51`.
- There is no export endpoint.
- The app has no account deletion. `auth_repository.dart:47-52` only signs out.
- The local DB has no way to delete conversations or messages. `database.dart:83-155` only offers `deleteMemory` and `clearMemories`.
- The schema already cascades on user delete (`models.py:78`, `:93` and others), so server-side deletion is cheap to add.

**Why it blocks**
- Google Play's User Data policy requires in-app account deletion plus a web deletion link for apps that create accounts.
- App Store guideline 5.1.1(v) requires in-app account deletion.
- The draft Pakistani PDP Bill and GDPR grant erasure rights.

**Recommendation**
- Add `DELETE /me`: delete rows (the cascade does the rest), delete the Firebase user through the Admin SDK, and log the deletion.
- Add `GET /me/export` returning JSON.
- In the app, add "Delete a conversation", "Delete all Eve data on this phone" and "Delete my account".
- Publish a web form for account deletion.

### F5. No privacy policy, terms, disclaimers or consent capture (blocker, human + code, M)

**Evidence**
- A search of `app/lib/l10n/app_en.arb` and `lib/` finds no privacy policy, terms, "not a substitute for professional care", "not for emergencies", or "you are talking to an AI" consent. The only disclaimers are "not a diagnosis" at `app_en.arb:103` and `:201`.
- Onboarding (`app/lib/features/onboarding/welcome_screen.dart`) collects language and nothing else.
- The server stores no consent timestamp or version. There is no consent column in `models.py`.

**Recommendation**
- A lawyer drafts a privacy policy and terms (see "What needs a human").
- In code:
  - Add a blocking first-run consent screen covering what Eve is (an AI, not a clinician), what it cannot do, the emergency numbers, what is stored where, and cloud mode.
  - Store `consent_version` and `accepted_at` per user, on the server and locally.
  - Re-prompt when the version changes.
  - Link both documents from You and Settings.

### F6. No age gate (blocker, human + code, S)

**Evidence**
- There is no age or date-of-birth question anywhere in `lib/`.
- Probe s10 (`ml/therapylink_ml/eval/probes/safety.jsonl:10`) is a 14-year-old disclosing abuse, so the team expects minors.
- v14 answered s10 with "call 1122" and a trusted adult (`ml/runs/eval/sft-v14/scored.jsonl`, id s10). That is acceptable, but no child-protection line was named.
- The on-device base model named no resource at all for s10 (`ml/runs/eval/base-e2b/scored.jsonl`, id s10).

**Rules in play.** Google Play Families and Apple rules apply if the app targets children. The draft PDP Bill requires guardian consent under 18. GDPR sets the age of digital consent at 13 to 16, and COPPA applies under 13 in the US.

**Recommendation**
- Launch 18+ (or 16+ if counsel agrees), with a self-declared age screen and an 18+ content rating on both stores.
- Handle minors who arrive anyway: route child-abuse disclosures to a child line (see F23).
- A lawyer decides whether to support minors with guardian consent later.

### F7. The private default runs an untuned model (blocker, ml, L)

**Evidence**
- `app/lib/core/ml/gemma_eve_engine.dart:21-35` downloads stock `litert-community/gemma-4-E2B-it` ("The fine-tuned Eve replaces these once the LiteRT-LM export from ml/ is published").
- `ml/runs/eval/base-e2b/summary.json` measures that model at:
  - all safety checks: 7/24
  - resource on crisis: 1/14
  - language match: 2/8
- v14 reaches 18/24, 12/14 and 8/8 (`ml/runs/eval/sft-v14/summary.json`), but only through the cloud path.

**Why it matters here.** Patients currently choose between a private model that is measurably unsafe and a safer model that leaks their conversations (F3). No compliant configuration exists today. The crisis sheet and Guardian keyword union still fire on device, but the model reply is what the patient reads.

**Recommendation.** Export the chosen adapter to LiteRT-LM, pin it by revision and hash (see F19), and require the same eval gate on the on-device artifact. The ML lead owns this; it is listed here because it decides whether F3 can be fixed at all.

### F8. Sign-out keeps the previous user's data; mood uploads cross accounts (high, code, S)

**Evidence**
- `signOut()` (`app/lib/core/auth/auth_repository.dart:47-52`) does not touch the drift DB.
- No table has a user column (`database.dart:8-63`). After sign-out, the next account on that phone sees the previous person's conversations and memories.
- `MoodQueue` rows are not user-tagged. `_syncMood` (`eve_controller.dart:376-388`) and `recordManualMood` (`app/lib/features/today/today_providers.dart:30-45`) upload every pending row under whichever account is signed in, so person A's moods can land in person B's clinician-visible trend.

**Recommendation.** Wipe the local DB and memories on sign-out, after a confirm dialog that offers export first. Alternatively, open one database file per uid. Tag queued mood rows with the uid and drop any whose uid does not match the signed-in user.

### F9. Per-turn chat emotions uploaded automatically (high, code, S)

**Evidence**
- Every chat message queues its Guardian valence and emotion with a timestamp, and they upload immediately (`eve_controller.dart:158-159`).
- The server stores them per point (`models.py:102-112`), and a consenting clinician sees the daily trend.
- The comment at `today_providers.dart:26` says "the raw readings never leave the phone", which is false.
- `youDataBody` (`app_en.arb:218`) mentions the mood trend but implies the chat itself is untouched.

**Why it matters.** Timestamped emotion labels per message amount to health data and a usage timeline.

**Recommendation**
- Make chat-derived mood sync opt-in, off by default.
- Or upload daily aggregates only.
- Fix the comment and the copy.

### F10. Training data licences not cleared for commercial use (high, human + ml, M)

**Evidence**
- `ml/therapylink_ml/data/loaders/esconv.py:76-77` and `empathetic.py:52-53` are CC BY-NC 4.0 with `commercial_ok=False`.
- `counselchat.py:40-41` reads "Scraped … verify terms before redistribution" and is marked non-commercial.
- `--exclude-nc` exists (`ml/therapylink_ml/train/eve_sft.py:164`) but no notebook uses it: `exclude_nc` does not appear in `ml/notebooks/*.ipynb`.
- `ml/KAGGLE.md:24` already notes that the corpus holds non-commercial data.

**Risk.** Shipping v14 or later through a company is commercial use.

**Recommendation**
- Get a written legal opinion on whether a model's weights are a derivative work under these licences.
- Otherwise, retrain with `--exclude-nc` and re-run the full eval before launch.

### F11. Clinician verification is manual and unauditable (high, human + code, M)

**Evidence**
- `api/scripts/verify_clinician.py:36-46` sets `verified_at` from the command line, based on a free-text `license_no` (`api/therapylink_api/schemas.py:30`).
- Nothing checks the number against the PMDC or Pakistan Psychological Council registers.
- Nothing records who verified whom, or on what evidence.
- `TL_DEV_AUTO_VERIFY_CLINICIANS` (`settings.py:20`) can switch verification off entirely.

**Recommendation**
- The business defines a written verification SOP: register lookup, ID match and a video call, with records kept.
- In code, add `verified_by`, `verification_evidence` and `verified_at` history, and refuse to start with auto-verify on a non-sqlite database.

### F12. No audit trail of clinician access (high, code, M)

**Evidence.** `api/therapylink_api/routers/clinician.py:69-85` returns assessments, mood, summaries and journal without recording the access. There is no logging module in `api/`.

**Recommendation**
- Add an append-only `access_log` table (clinician_uid, patient_uid, sections, timestamp).
- Show patients "who viewed my data and when" under Care.

### F13. No rate limiting or size limits, and no App Check (high, code, M)

**Evidence**
- `/inference/chat` accepts any Firebase-authenticated user (`inference.py:12`). Accounts are self-service email/password (`auth_repository.dart:21-22`), and there is no Firebase App Check (no `app_check` in `pubspec.yaml`).
- `ChatMessage.content` and `messages` are unbounded (`schemas.py:145-151`). So are `JournalIn.body` (`:65`), `SummaryIn.content` (`:80`), `BecomeClinician.bio` (`:32`) and the `/mood/batch` list (`routers/mood.py:28-32`).
- There is no rate limiter anywhere in `api/`.

**Recommendation**
- Add per-uid rate limits (slowapi, or at the Cloudflare edge).
- Set `max_length` on every text field, cap list sizes, and cap total request size.
- Enable Firebase App Check and verify it server-side.

### F14. Release build signed with the debug key (high, code, S)

**Evidence.** `app/android/app/build.gradle.kts:31-35`.

**Recommendation.** Create an upload keystore stored outside the repo, use Play App Signing, and read the key from `key.properties`, which `.gitignore` must exclude. Add `key.properties` and `*.jks` to `.gitignore`; neither is listed now.

### F15. No way to report an AI reply (high, code, S)

**Evidence.** Eve replies in `app/lib/features/eve/eve_screen.dart` carry no report or flag action. Google Play's AI-Generated Content policy requires in-app reporting for generative AI apps.

**Recommendation**
- Add long-press "Report this reply".
- Send the reply text only with explicit consent on that dialog, otherwise just the category.
- Review the reports.

### F16. Care link needs no clinician acceptance; the risk flag implies monitoring (medium, code + human, M)

**Evidence**
- `POST /care/links` creates the link as `active` immediately (`api/therapylink_api/routers/care.py:46-53`), from a code or a raw clinician uid (`:35-37`). The clinician never accepts.
- The caseload sorts patients with `risk_item` first (`clinician.py:62-64`), but no notification fires.
- A patient who answers PHQ-9 item 9 positively may reasonably believe their clinician has been alerted.

**Recommendation**
- Make links `pending` until the clinician accepts.
- Drop uid-based linking (`care.py:35`).
- Tell the patient in plain words at link time that their clinician does not watch the app in real time and will not be alerted.
- The clinical governance lead decides whether risk flags create a duty to respond.

### F17. Journal sharing exposes past entries (medium, code, S)

**Evidence.** When `share_journal` is on, the clinician receives the latest 50 entries regardless of date (`clinician.py:82-84`). The same applies to summaries (`:79-81`) and to the full assessment history (`:75-76`).

**Recommendation.** Offer "share from today" as the default, or per-entry sharing. Store `shared_from` on the link.

### F18. Roman Urdu instruments unvalidated, and clinicians cannot tell (medium, code + human, S)

**Evidence**
- `app/lib/features/assessments/assessment_items.dart:3-4` says the translation "is an app translation, not a validated clinical instrument — say so wherever scores are shown to a clinician".
- `Assessment` stores no language (`models.py:89-99`).
- `app/lib/features/clinician/patient_screen.dart` has no such notice.

**Recommendation**
- Store `locale` on each assessment and show "unvalidated translation" beside Roman Urdu scores.
- A human sources the validated Urdu PHQ-9 and GAD-7 wording, or commissions a validation study.

### F19. Model downloads have no integrity check (medium, code, S)

**Evidence**
- Eve downloads from `.../resolve/main/...`, a mutable branch (`gemma_eve_engine.dart:18`).
- Guardian downloads four files, including `thresholds.json`, from `TL_GUARDIAN_URL` with plain `dio.download` and no hash check (`app/lib/core/ml/onnx_guardian.dart:15-16`, `:63-80`).
- A swapped thresholds file could raise the crisis threshold until detection stops firing.

**Recommendation.** Pin a commit revision, ship expected SHA-256 values in the app, and verify before marking the model ready.

### F20. Dev auth bypass has no production guard (medium, code, S)

**Evidence.** With `TL_DEV_AUTH_BYPASS=true`, any `X-Dev-Uid` header becomes that user (`api/therapylink_api/auth.py:39-42`, `settings.py:17`). Nothing stops it running against Postgres.

**Recommendation.** Fail startup when the bypass is on and the database is not sqlite, or when an `ENV=prod` variable is set.

### F21. No MFA for clinicians, no email verification (medium, code, S)

**Evidence.** Password sign-in only (`auth_repository.dart:18-22`). `auth.py` does not check `email_verified`.

**Recommendation**
- Require Google sign-in or Firebase MFA for clinician accounts.
- Require a verified email before a clinician profile can be approved.

### F22. No retention policy (medium, human + code, S)

**Evidence.** No TTL or cleanup job exists for `mood_points`, `shared_summaries` or `assessments`, and revoking a link keeps everything on the server (`care.py:66-73`).

**Recommendation.** A human decides retention periods. Code then adds a scheduled purge and documents it in the privacy policy.

### F23. No child helpline in the crisis sheet (medium, code + human, S)

**Evidence**
- `app/lib/features/shared/crisis_sheet.dart:7-8` holds only Umang and 1122.
- Madadgaar 1098, cited in the product brief, appears nowhere in `app/lib`.
- v14's s10 reply named only 1122.

**Recommendation.** A human confirms current numbers and hours with each service: Madadgaar, Punjab Child Protection 1121, Umang. Add them to the crisis sheet, with a written agreement where possible.

### F24. Firebase client config tracked (low, human, S)

**Evidence.** `app/lib/firebase_options.dart` is tracked. Firebase client keys are identifiers, not secrets. Values were not opened.

**Recommendation**
- Restrict the API keys by Android package, SHA-1 and iOS bundle in the GCP console.
- Enable App Check (see F13).

### F25. Error details leak (low, code, S)

**Evidence**
- `auth.py:48` returns `f"invalid token: {e}"`.
- `inference.py:32` returns the httpx exception, which for status errors includes the upstream URL, meaning the tunnel host.

**Recommendation.** Log the details server-side and return generic messages.

### F26. BDI-II in the API (low, code, S)

**Evidence.** `Instrument.bdi2` is defined in `models.py:40` and scored in `api/therapylink_api/scoring.py:20`. BDI-II is Pearson-copyrighted. The app has no items for it (`assessment_items.dart:10`).

**Recommendation.** Remove it until it is licensed.

### F27. No iOS privacy manifest (low, code, S)

**Evidence.** There is no `PrivacyInfo.xcprivacy` under `app/ios`.

**Recommendation.** Add one declaring the required-reason APIs and the data collected (health, identifiers), consistent with the App Store privacy label.

## What is already right

- Authorisation is enforced on every route:
  - `_owned` in `journal.py:12-16`
  - `_owned_link` in `care.py:14-18`
  - `_active_link` plus consent flags in `clinician.py:26-36` and `:75-84`
  - `verified_clinician` in `clinician.py:17-23`

  No IDOR was found. Clinicians cannot read patients without an active link, and each section needs its flag. Revoking a link clears every flag (`care.py:70`).
- Release builds are HTTPS-only. Cleartext is allowed only in the debug manifest (`app/android/app/src/debug/...`).
- Chat text is never stored server-side, and there are no third-party analytics or ad SDKs.
- The Guardian crisis check and crisis sheet run on device whichever model runtime is active (`eve_controller.dart:154-165`).
- The API Docker image runs as a non-root user (`api/Dockerfile:10-11`).

## Recommendations (order of work)

1. **Today, human:** revoke the leaked GCP key and the Gemini and Maps keys, and audit IAM (F1). Do not push `--all --tags` to the company remote until history is cleaned.
2. **Code sprint, about one week:**
   - Correct the backup and file-sharing flags and add SQLCipher (F2).
   - Wipe local data on sign-out and tag mood rows by uid (F8).
   - Make chat mood sync opt-in (F9).
   - Build account, data and conversation deletion plus export (F4).
   - Add consent and age screens with stored consent versions (F5, F6).
   - Remove cloud mode from release builds (F3).
   - Set up release signing (F14) and a report button (F15).
   - Add the rate limits, size limits and App Check (F13).
   - Add an audit log (F12).
   - Add hash-pinned downloads (F19).
   - Add the production guard on the dev bypass (F20).
   - Add gitleaks to CI.
3. **ML:** ship the fine-tuned Eve on device (F7), and retrain without NC data if counsel says so (F10).
4. **Human track, in parallel:** the items below.

## What needs a human

These need a lawyer, a registered entity or a licensed professional. Agents cannot close them.

1. **Pakistan data protection.** No comprehensive data-protection law is in force as far as I know: the Personal Data Protection Bill (latest draft 2023) had not been enacted at my knowledge cutoff. Counsel must confirm its current status. Design to the draft anyway:
   - health data is "sensitive personal data" needing explicit consent;
   - rules on cross-border transfer and localisation of "critical personal data";
   - 72-hour breach notification;
   - data-subject rights.

   Counsel should say whether hosting on Neon, Firebase and US or EU regions is acceptable for Pakistani health data.
2. **PECA 2016, as amended in 2025.** It is mainly a cybercrime statute. Counsel should confirm:
   - whether TherapyLink counts as a "service provider" with traffic-data retention duties (s.32);
   - how to respond to lawful-access requests for journal and summary data;
   - what the unauthorised-access offences imply for the F1 incident, and whether to report it.
3. **Is it a medical device?**
   - **DRAP.** The Medical Devices Rules 2017 under the DRAP Act 2012 cover software intended for diagnosis, monitoring or treatment. PHQ-9 and GAD-7 scoring with severity bands (`api/therapylink_api/scoring.py:18-36`), triage of patients by risk for clinicians (`clinician.py:39-66`) and an AI giving mental-health support could all be read as intended medical use. Positioning as general wellness and self-help, with no diagnosis or treatment claims, lowers the risk. Counsel must classify and advise on registration.
   - **Abroad.**
     - US: FDA device-software policy and general-wellness guidance. Several states restrict AI therapy: Illinois (2025), Nevada, and Utah's mental-health chatbot law.
     - EU: MDR Rule 11 would likely put diagnosis and monitoring software at class IIa or above. The AI Act adds transparency duties for chatbots, and more if it is a medical device.
     - UK: MHRA SaMD rules, and DTAC/DCB0129 for NHS use.

   Do not market outside Pakistan until this is done.
4. **App stores.**
   - Google Play health apps policy and the Health apps declaration.
   - A Data safety form that lists health info, emotion data and journal text.
   - Account deletion with a web link.
   - AI-generated content reporting.
   - A likely requirement to publish health apps from an organisation developer account.
   - Apple 1.4.1 (medical claims and the reminder to see a doctor), 5.1.1(v) account deletion, 5.1.1(ix) (apps in regulated healthcare fields must be submitted by a legal entity, not an individual developer), and 5.1.3 (no health data for advertising).

   The company, not the individual, must be the publisher on both stores.
5. **Advertising.** Health data must never feed ad targeting or custom audiences. Google Ads and Meta both restrict personalised health targeting. Marketing must not claim "therapy", "diagnosis" or "clinically proven" without evidence and regulatory clearance.
6. **Minors policy.** Decide the minimum age and whether guardian consent will ever be offered. Set up a child-safeguarding escalation route with a child protection body.
7. **Crisis-line partnerships.** Confirm Umang, Madadgaar and 1122 numbers and hours in writing, and inform them that the app refers users to them.
8. **Clinician verification SOP and clinical governance.** Covers the register checks, who owns risk-flag response expectations, and a named clinical safety officer who signs off on Eve's safety evals before each model release.
9. **Training-data licensing opinion** for ESConv, EmpatheticDialogues and CounselChat (F10), and for Gemma's licence terms on the shipped weights.
10. **Privacy policy, terms and a DPIA,** plus DPAs with Firebase/Google, Neon and any inference host. Write an incident-response plan, starting with F1.
