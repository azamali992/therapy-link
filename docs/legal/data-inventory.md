# Data inventory

> **DRAFT, pending legal review.** An engineering description of what the code stores and sends, for the lawyer writing the privacy policy and for the Google Play Data safety form. It states facts about the code, not legal conclusions. Retention is **TBD** everywhere: no retention period has been decided and no purge job exists. Nothing here has been checked by counsel.

Written from the code at commit 9fa4e4e1 (`api/therapylink_api/models.py`, `app/lib/core/db/database.dart`, the API routers and the app's API client). Each fact cites the file and line it comes from; paths starting `lib/` or `android/` are under `app/`. Re-check this page against the code before it is used.

## Where data lives

| Place | What it is | Who runs it |
| --- | --- | --- |
| **Phone** | One drift/SQLite database per signed-in account, named `therapylink_<uid>`, in the app-support folder (`lib/core/db/database.dart:191-194`); the app's shared preferences; downloaded model files | The patient's device. The database is not encrypted. Android Auto Backup is off and every domain is excluded from cloud backup and device-to-device transfer (`android/app/src/main/AndroidManifest.xml:10-12`, `android/app/src/main/res/xml/data_extraction_rules.xml:7-22`). iOS file sharing is off (`ios/Runner/Info.plist:48-49`) |
| **API database** | Postgres in production (sqlite in development). Region and provider not yet chosen (Neon in Singapore or Mumbai proposed) | TherapyLink |
| **Firebase Authentication** | Sign-in accounts, project `therapylink69` | Google |
| **Model server** (cloud mode, debug and profile builds only) | An OpenAI-compatible llama-server behind the API. Today this is a developer's laptop behind a Cloudflare Tunnel. Release builds cannot switch to cloud mode (`lib/core/settings/settings.dart:11,136-137`) | TherapyLink (today, an individual) |

## On the phone

Signing out uploads any queued check-ins, then empties every table, clears the person's preferences, signs out and deletes the database file (`lib/core/auth/session.dart:32-35,67-78`). Deleting the account does the same after the server confirms (`lib/core/auth/session.dart:40-43`). The next account on the phone starts with an empty database of its own.

| Data item | Content | Leaves the phone? | Who can read it | Retention |
| --- | --- | --- | --- | --- |
| Conversations | Title, created/updated times, a rolling summary of older turns written by the model, markers for what has been summarised and read for memories (`lib/core/db/database.dart:14`) | In cloud mode the summary is sent to the model server as part of each request. Otherwise no | Anyone with the unlocked phone while the account is signed in | TBD. Deleted on sign-out, on account deletion, or all at once with "Delete chats" (`lib/features/you/you_screen.dart:71`, `lib/core/db/database.dart:121-126`). No way to delete a single conversation in the app |
| Messages | Every user and Eve message in full, with the time, and for user turns the crisis classifier's valence (−2..2), emotion label and crisis flag (`lib/core/db/database.dart:47`) | In cloud mode the text of the recent turns is sent with each request. Valence and emotion are never uploaded (`lib/features/eve/eve_controller.dart:230-232`) | As above | TBD. Deleted as for conversations |
| Memories ("What Eve remembers") | Short notes the model writes about the person: people, situations, goals, what helped, plans. Can include abuse or risk notes (`lib/core/db/database.dart:36`) | In cloud mode, notes relevant to the message are sent with the request, and the memory-extraction step sends the transcript | As above | TBD. Deletable one by one or all at once in the app (`lib/features/you/memory_screen.dart:99,108`), and deleted as for conversations |
| Mood queue | Valence, emotion, source, time, uploaded flag (`lib/core/db/database.dart:63`) | Only check-ins the person logs by hand are queued and uploaded as mood points (`lib/features/today/today_providers.dart:32`). Mood read from chat is not queued or uploaded, and there is no opt-in to upload it | As above | TBD. Deleted on sign-out and account deletion |
| Settings (shared preferences) | Language, text size, reduce motion, theme, model runtime, onboarding done; and per person: last conversation ID, memory on/off, accepted consent version and time (`lib/core/settings/settings.dart:88-89`) | The accepted consent version is sent to the API (below). The rest, no | Anyone with the phone | The per-person values are cleared on sign-out (`lib/core/settings/settings.dart:170-183`); device preferences stay until the app is uninstalled |
| Downloaded models | Eve (~2 GB) and, if installed, Guardian (~278 MB, in `guardian/` under app support, `lib/core/ml/onnx_guardian.dart:76`). No personal data | No | — | Until the app is uninstalled. Not removed on sign-out or account deletion |
| Firebase sign-in session | Tokens the Firebase SDK keeps to stay signed in | Sent to Google and the API to authenticate | The Firebase SDK | Until sign-out |

## On the API database

Every table below except `access_log` and `erased_accounts` hangs off the user row by a foreign key with `ON DELETE CASCADE` (`api/therapylink_api/models.py:70,90-91,109,129,142,171`). `DELETE /me` deletes that row, so the cascade removes the rest, records the erasure, then deletes the Firebase sign-in (`api/therapylink_api/routers/me.py:50-67`). The app calls it from "Delete account" after a confirmation (`lib/features/you/account_actions.dart:46-55`). `GET /me/export` returns every column of every row the server holds for the account, including its access-log rows (`api/therapylink_api/routers/me.py:74-93`); the app has no button for it yet.

| Table | Data item | Content | How it gets there | Who can read it | Retention |
| --- | --- | --- | --- | --- | --- |
| `users` | Account | Firebase UID, email, whether the email is verified, display name, role (patient / clinician / admin), language, accepted consent version and time, created time (`api/therapylink_api/models.py:52-62`) | Created on first API call from the sign-in token. The consent version comes from the phone on sign-in, on launch and after each new acceptance (`lib/core/api/consent_sync.dart:13-18`, `api/therapylink_api/routers/me.py:118-126`) | The user; a clinician sees the patient's name and email once the patient requests a link, before accepting it (`api/therapylink_api/routers/clinician.py:58-70`), and in their caseload after; database operators | TBD. Deleted with the account |
| `clinician_profiles` | Clinician details | Licence number (free text), specialty, bio, verified time, invite code | The clinician's sign-up form | The clinician; database operators; whoever runs the verification script | TBD. Deleted with the account |
| `care_links` | Patient–clinician link | The two UIDs, status (pending, active, revoked), the four sharing flags (assessments, mood trend, summaries, journal), the time sharing starts from, times (`api/therapylink_api/models.py:89-102`) | The patient enters a clinician's invite code, which creates a **pending** link with every flag off; the clinician must accept it before seeing anything (`api/therapylink_api/routers/care.py:38-59`, `api/therapylink_api/routers/clinician.py:74-90`). The patient sets the flags. The app has no accept or decline screen yet | Both parties; database operators | TBD. Revoking clears the flags but keeps the row and all shared data (`api/therapylink_api/routers/care.py:72-79`). Deleted if either account is deleted |
| `assessments` | PHQ-9 and GAD-7 results | Every answer, total score, severity band, flags (including a positive answer to PHQ-9 item 9, the self-harm question), time. A language column exists (`api/therapylink_api/models.py:117`) but the app does not fill it yet | Sent every time a check-in is completed; the server scores it | The patient; a linked clinician if `share_assessments` is on (the whole history, not only after the link); database operators | TBD. Deleted with the account |
| `mood_points` | Mood readings | Valence (−2..2), emotion label, source, time, an optional client ID for de-duplication (`api/therapylink_api/models.py:130-135`). No text | The patient's own mood check-ins. The app does not upload mood read from chat (`lib/features/eve/eve_controller.dart:230-232`) | The patient (as a trend); a linked clinician sees a daily trend if `share_mood_trend` is on; database operators see each point | TBD. Deleted with the account |
| `journal_entries` | Journal | Title, full body text, mood, times. Stored as plain text | Every journal entry is written to the server; the journal has no local copy (`lib/core/api/api_client.dart:68-76`) | The patient; a linked clinician sees the latest 50 entries written since the link was requested, if `share_journal` is on (`api/therapylink_api/routers/clinician.py:141-145`); database operators | TBD. The patient can delete an entry. Deleted with the account |
| `shared_summaries` | Shared summaries | Summary text generated on the phone, kind (weekly or session), period | The API route exists, but the app never calls it yet | The patient; a linked clinician sees the latest 20 written since the link was requested, if `share_summaries` is on (`api/therapylink_api/routers/clinician.py:136-140`); database operators | TBD. Deleted with the account |
| `access_log` | Who saw what | Clinician UID, patient UID, whether it was the caseload or the patient overview, which sections were shown, time (`api/therapylink_api/models.py:150-162`) | Written every time a clinician is shown a patient's data (`api/therapylink_api/routers/clinician.py:105,146-147`) | The patient, through `GET /me/access-log` (`api/therapylink_api/routers/me.py:96-106`); the app has no screen for it yet; database operators | TBD. Append-only: no foreign keys, so it **outlives account deletion**, and on Postgres rules ignore UPDATE and DELETE (`api/alembic/versions/b2d4f6a81023_access_log.py:33-36`) |
| `erased_accounts` | Deleted accounts | A SHA-256 of the deleted Firebase UID and the time (`api/therapylink_api/models.py:179-187`) | Written by `DELETE /me`, so the deleted account's still-valid tokens can't recreate it | Database operators | Kept indefinitely by design; TBD for counsel |

The server accepts PHQ-9 and GAD-7 only; BDI-II, which is Pearson-copyrighted, is out of the schema (`api/therapylink_api/models.py:43-46`).

## Passing through, not stored by TherapyLink

| Data item | Path | Stored? |
| --- | --- | --- |
| Cloud-mode requests (debug and profile builds only) | Phone → API `/inference/chat` → model server. Carries the system prompt, recent conversation, relevant memory notes and summary; also the summarising, memory-extraction and wrap-up transcripts | The API does not store them. Whether llama-server or the tunnel logs prompts has not been checked. Server access logs record paths, which for clinicians include the patient UID |
| Sign-in | Phone → Firebase Authentication | Google stores the account (email, password hash or Google identity). Covered by Google's terms, not ours. `DELETE /me` deletes it |
| Model downloads | Phone ← Hugging Face (`litert-community` for Eve; the `TL_GUARDIAN_URL` host for Guardian) | The host sees the phone's IP address at download |
| Fonts | Phone ← Google Fonts (`fonts.gstatic.com`), fetched at runtime by the `google_fonts` package the first time Manrope or Noto Nastaliq Urdu is drawn (`app/lib/app/theme/theme.dart`). No font files are bundled and runtime fetching is not switched off | Google sees the device's IP address and the app's user agent at each fetch. The font is cached on the phone afterwards. Bundling the fonts and setting `GoogleFonts.config.allowRuntimeFetching = false` would remove this flow |
| Web runtime (web build only) | Browser ← jsDelivr (`cdn.jsdelivr.net`), which serves the LiteRT-LM runtime loaded by `app/web/index.html` | jsDelivr and its CDN providers see the browser's IP address and the page it was loaded from. The Android and iOS builds do not make this call |

There are no analytics, advertising or crash-reporting SDKs in the app. The font and web-runtime fetches above are the only third-party calls that are not a feature the user chose.

## For the Play Data safety form

A starting list only. The lawyer decides the final answers.

| Play category | What we collect | Collected (leaves the device)? | Shared with third parties? |
| --- | --- | --- | --- |
| Personal info: name, email | Account | Yes | Google (Firebase Authentication), as our processor |
| Health and fitness: health info | Assessments, the patient's own mood check-ins, journal, summaries | Yes | No, beyond hosting providers |
| Messages / other user-generated content | Eve conversations and memory notes | No in release builds. Cloud mode, which sends them for processing, exists only in debug and profile builds | Model host, if it is a third party |
| App activity / app interactions | Mood check-in timestamps form a usage timeline | Yes | No |
| App info and performance | None yet | — | — |
| Device or other IDs | Firebase UID | Yes | Google (Firebase) |

Security questions the form asks: data is encrypted in transit in release builds (HTTPS only, enforced at build time by `android/app/build.gradle.kts:82-107`); the person can delete their account and its server data in the app; the phone's database is not encrypted at rest.

## Open questions for counsel

1. Retention period for each server table, and what happens to shared data when a link is revoked.
2. How long `access_log` rows may be kept after the patient or clinician deletes their account, since they survive deletion by design; and whether `erased_accounts` may be kept indefinitely.
3. Whether the processing region (Singapore or Mumbai) is acceptable for Pakistani health data.
4. If uploading chat-derived mood is ever added, whether it needs separate opt-in consent. Today it is not uploaded.
5. What the privacy policy must say about cloud mode, if it ever returns to patient builds.
6. Which vendors need a data processing agreement: Google (Firebase, GCP), the database host, the model host.
7. Whether the runtime Google Fonts fetch must be disclosed, or the fonts bundled so that no IP address goes to Google outside sign-in.
8. Whether the in-app export must exist before launch, since `GET /me/export` has no screen yet.
