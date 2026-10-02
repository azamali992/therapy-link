# TherapyLink feature inventory (for the new app's scope)

Product analyst, 2026-10-03. Written from the code, not the marketing docs. Nothing was run.

Sources:
- **Legacy** = `legacy/` (same as GitHub `origin/main`, the superset of all team branches; see below). Paths below are under `legacy/lib/` unless stated.
- **v2** = `app/` (Flutter) + `api/` (FastAPI), Sep 2026. App paths are under `app/lib/`.
- **APK** = `D:\therapylink-recovery\apk\` (TherapyLink-v16.apk, versionName 2.0.0, profile build). **It is a v2 build, not legacy** (`REPORT.md`). Its 77 non-generated Dart files all exist in the recovered `app/lib`.

Status words: **worked** (code path complete), **partial**, **stub** (UI or toggle with nothing behind it), **broken** (known not to work). Legacy statuses come from reading code; the legacy services it calls (Render-hosted models, Firebase) may be dead now.

## 0. Recovery caveats that affect this inventory

| Issue | Evidence | Effect |
|---|---|---|
| Recovered `api/` is behind the app and the APK | App calls `/me/access-log`, `/me/clinician/code`, `/clinician/requests/{id}/accept\|decline` (`core/api/api_client.dart:105,174,186-190`); no such routes in `api/therapylink_api/routers/*.py`, though `api/tests/test_access_log.py` exists | The server logic for access log, invite-code rotation and link accept/decline must be rewritten from tests + app client |
| Recovered `app/` has merge debris | `deleteMe` and `putConsent` defined twice (`core/api/api_client.dart:98/112`, `:108/115`) | Won't compile as is |
| `/you/memory` route missing in recovered router | `app/router.dart` imports `memory_screen.dart` but has no route; APK strings contain `/you/memory` | Memory screen unreachable in recovered code |
| Several v2 docs are older than the code | `app/README.md` / `app/PRODUCT.md` say DB unencrypted and no export/access-log screen; code and APK have SQLCipher, export and access log | Trust code + APK over those two docs |

Legacy branches (`D:\therapylink-recovery\github`): `main` (2026-03-09, 65 Dart files) is a superset. `master`, `zeeshan`, `sentiment-tracking` (Jul 2025) add nothing `main` lacks. `ahmad` and `mobile-ui` only have an older `Views/maps.dart` and `repos/chat_repo.dart`. **No feature lives only on a side branch.**

## 1. User roles

| Role | Legacy | v2 | New app |
|---|---|---|---|
| Patient / user | `UserRole.RegularUser` (`utils/user_role.dart`); routed to the main menu in `main.dart:71-90` | `Role.patient`, the default (`api/.../models.py:25-29`). 4 tabs: Eve, Today, Journal, You (`app/router.dart`) | Keep |
| Clinician | `UserRole.MentalHealthProfessional`. Separate sign-up with licence form (`Views/psychologist_signup.dart`), `status: 'pending'`, waits on `Views/verification_pending.dart`. Sees **any patient who booked an appointment**, plus a Gemini summary of that patient's chats, with no patient consent (`Views/view_user_insights.dart:69-214`) | `Role.clinician`. Any user can switch from You → "I'm a clinician" with a licence number (`features/clinician/become_clinician_screen.dart`, `POST /me/clinician`). Sees nothing until an admin sets `verified_at` (`routers/clinician.py:17-23`). Patient must link and switch on each section | Keep v2's model |
| Admin | A Flutter Web admin panel is shown in `legacy/screenshots/admin_panel.jpeg` and sequence diagrams, but **no admin code is in any branch** | `Role.admin` exists in the enum; the only admin tool is a CLI, `api/scripts/verify_clinician.py` (approve/revoke clinicians). No admin UI | Rethink: needs a minimal ops console (clinician verification, helpline register, incident log) |
| Guardian / family | None | None. Under-18s are turned away to helplines (`features/onboarding/consent_screen.dart:146-180`) | Decision needed (see section 5) |

## 2. Feature table

### Account and onboarding

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| Onboarding intro | Learn what the app is | `Views/onboardingpage.dart` (concentric transition slides). Worked | `features/onboarding/welcome_screen.dart`: 3 points, language pick, Get help button. Worked | | KEEP: one screen, language first |
| Consent + AI/emergency disclaimer | Know it's an AI, not emergency care, what data goes where | None | `consent_screen.dart` + router gate (`app/router.dart:62-66`), versioned, synced (`core/api/consent_sync.dart`, `PUT /me/consent`). Worked; wording and policy URLs are placeholders (`therapylink.example`) | Needs lawyer + clinician text | KEEP |
| Age gate (18+) | Keeps minors out until there's a safe path | None | Self-attested tickbox; under-18 screen shows 1098/Umang/1122 only. Worked | | KEEP (or RETHINK if minors are in scope) |
| Email/password sign-in | Account | `Views/login.dart`, `signup.dart`, `auth.dart`. Worked | `features/auth/sign_in_screen.dart`, reset password. Worked | Firebase Auth project `therapylink69` (reused) | KEEP |
| Google sign-in | One-tap account | Worked | Worked on web/iOS; Android needs the SHA-1 set up (`app/README.md`) | | KEEP |
| Phone OTP sign-in | Sign in without email (common in PK) | `Views/phone_auth_screen.dart` (`intl_phone_field`). Worked | None | Firebase SMS costs; phone number is identifying on shared phones | RETHINK: consider as an option, not default |
| Guest / anonymous use | Try without an account | None | None (a `therapylink_guest` DB name exists but no flow, `core/db/database.dart:193`) | Activation blocker per `docs/ship-review/marketing-ads.md` | RETHINK: strong candidate for the new app |
| Profile (name, age, DOB, gender, phone, country) | Personalisation | `Views/profile_info.dart`, `profilepage.dart`. Worked | Display name + locale only (`PATCH /me`) | Legacy collected far more PII than it used | DROP most fields; keep name + language (+ maybe gender for Urdu grammar) |

### Eve (AI companion)

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| Text chat with AI | Someone to talk to | `bloc/chat_bloc.dart`, `apis.dart:58` POSTs to `huggingfacerag.onrender.com/predict` (RAG model on Render free tier). No system prompt or history sent, single message in/out. Partial (service likely dead) | `features/eve/eve_screen.dart`, `eve_controller.dart`. On-device Gemma 4 E2B via LiteRT-LM (`core/ml/gemma_eve_engine.dart`), ~2 GB download; cloud mode (llama-server via `POST /inference/chat`) in debug/profile only. Streaming, starters, follow-up from last plan, typing state. Worked in debug; **paused in release** until a fine-tuned, hash-pinned model exists (`core/ml/eve_engine.dart:94-98`) | Stock Gemma failed safety probes (7/24). Fine-tune v14 only on a laptop. System prompt must match training (`eve_engine.dart:13-24`) | KEEP (core). RETHINK runtime: on-device vs hosted is the #1 scope decision |
| Chat history | Pick up where you left off | Firestore `users/{uid}/messages`. Worked | Encrypted local SQLite per account; conversation list, switch, delete one (`features/eve/conversations_screen.dart`, `eve_controller.dart:203-245`). Worked | v2 history never leaves phone in on-device mode | KEEP v2 approach |
| Voice chat | Talk instead of type | `Views/voicechat.dart`: records WAV, Google Cloud Speech-to-Text via a **service-account JSON bundled in the app** (`assets/google_speech.json`), `en-US` only, reply via `flutter_tts`, Rive avatar. Partial; insecure | None | Leaked key class of issue (B1). Roman Urdu STT is hard | RETHINK: high value for low-literacy users, but needs on-device or proxied STT with Urdu support. Not MVP |
| Memory across conversations | Not repeating your story | None | Model writes notes (person/situation/goal/helped/plan) after turns (`features/eve/memory.dart`, `eve_controller.dart:_maintain`); user can view, delete one, forget all, switch off (`features/you/memory_screen.dart`). **Notes are not sent to the model** (`eveUnderstandsNotes = false`, `eve_engine.dart:83`) because v14 got less safe with them. Partial | Crisis turns never become notes (`_isNoteworthy`) | KEEP the user controls; RETHINK whether memory feeds the model (depends on training) |
| Rolling summary + wrap-up | Long chats fit a small model; session ends with a recap and one small step | Gemini 2.0 Flash summary of chat history, used on mood page and by clinicians (`services/summary_service.dart:114`, `firebase_ai`). Worked (needs Gemini) | Rolling summary every few turns; "Wrap up" menu writes recap + next step, stored as a plan memory (`eve_controller.dart:wrapUp`). Worked | Legacy shared summaries with clinicians without consent | KEEP v2; summary sharing to clinician only by opt-in |
| Output guard | Model can't show a fake/foreign helpline number | None | Strips any phone number not in the helpline table, even while streaming, and adds a crisis card (`features/eve/output_guard.dart`). Worked, tested | | KEEP (non-negotiable) |
| Break nudge / grounding offer | Don't over-rely on the bot; calm down in the moment | None | After 40 messages a one-time "take a break / talk to someone" nudge; after 3 low turns an inline breathing offer, dismissible for the session (`eve_controller.dart:107-127`). Worked | | KEEP |
| Model download manager | Get the on-device model | n/a | Banner with progress/retry, SHA-256 pin for release (`gemma_eve_engine.dart`, `eve_model_manifest.dart`). Worked | 2 GB is a big ask on PK data plans | RETHINK with runtime decision |

### Crisis and safety

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| Crisis detection on chat | Risk is noticed and routed to real help | None. Only a cumulative sentiment score that pops "Immediate Support Needed → book an appointment" (`Views/home_page.dart:900-1000`) | Guardian runs **before** every turn: keyword floor (EN, Roman Urdu m/f, Urdu script, abuse, sexual violence, child) (`core/ml/guardian.dart`) + optional ONNX XLM-R classifier downloaded with hash check (`core/ml/onnx_guardian.dart`). Cross-turn check over 20 min. Crisis turns never reach the model. Worked (keywords); trained model v0 is English-only, v1 not trained | Release chat is gated on Guardian ready | KEEP (core). Bundle Guardian instead of download |
| Crisis sheet + in-chat card + help bar | One tap to call the right line | None | Kind-aware sheet (suicide / abuse / child / sexual violence) with Umang, Madadgaar 1098, Rescue 1122; card saved in transcript; pinned help bar; 60-min crisis mode that survives restart; copy-number fallback if dialer fails (`features/shared/crisis_sheet.dart`, `helplines.dart`, `features/eve/crisis_mode.dart`). Worked; **no number verified** | No women's/DV line. EN + Roman Urdu copy (`crisis_copy.dart`) | KEEP; make it the best-designed screen |
| Get help on every screen | Help before sign-in, on lock screen, everywhere | None | `Screen` widget shows Get help by default, incl. welcome/sign-in/consent/lock (`features/shared/widgets.dart:52`). Worked | | KEEP |
| PHQ-9 item 9 alert | Self-harm answer shows help even offline | Not handled (BDI item 9 just scored) | `itemNineFlagged` on device (`features/assessments/assessment_outbox.dart:16`). Worked | | KEEP |
| Journal screening | Crisis text in a journal is also caught | None | Guardian runs on save (`features/journal/journal_editor_screen.dart:59-82`). Worked | | KEEP |
| Clinician alert on crisis | Linked clinician learns of risk | None | Not built. Only caseload "attention" flags for item 9 / severe / worsening (`l10n` `clinicianAttention*`) | Clinical-governance decision (`docs/ship-review/crisis-safety.md` F6) | RETHINK: decide policy first |

### Mood, insights, assessments

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| Manual mood check-in | Log how you feel | "Mood tracker" tab in stress relief, Firestore `mood_logs` with notes (`Views/stress_relieving.dart`). Worked | 5-point labelled scale on Today, offline queue, upload of manual check-ins only (`features/today/today_screen.dart`, `today_providers.dart:32`, `POST /mood/batch`). Worked | | KEEP; consider tags (sleep, family, exams) |
| Mood from chat (sentiment tracking) | Mood tracked without effort | Each message sent to `multilingsentiment.onrender.com/predict` with local fallback, stored in `users/{uid}/sentiments` (`repos/sentiment_repo.dart`); drives popups and charts. Worked (service may be dead) | Guardian gives valence/emotion per turn, **kept on phone, never uploaded, not shown** (`eve_controller.dart:295-297`) | Uploading chat-derived mood was flagged as a privacy break (B13) | RETHINK: on-device only, show to the user, opt-in share |
| Mood charts | See your pattern | `Views/moodanalysis.dart`: pie (6 emotions) + line chart week/month/year, plus Gemini summary. Worked | 30-day trend chart (`features/shared/mood_chart.dart`). Worked | | KEEP |
| Insights | A pattern you might not notice | None beyond charts | One insight at a time, only above sample-size and effect-size floors: time of day, week over week; "A pattern, not a diagnosis" (`features/today/insights.dart`). Worked | Good, careful logic | KEEP |
| Stress popups from sentiment | Nudge to relax when stressed | `home_page.dart`: consecutive-negative counter → "Time to Relax" dialog; severe → "Immediate Support Needed" → book appointment. Worked | Replaced by grounding offer + crisis path | Legacy popup was non-dismissible and sent crisis users to booking, not helplines | DROP legacy version |
| Assessments | Structured self-check | BDI-II (21 items, copyrighted), GAD-7, PSS-10, Rosenberg self-esteem, resilience scale (`Views/test_page.dart`, `psychologicaltest.dart`). Scored locally, **results not saved**. Partial | PHQ-9 + GAD-7, server-scored with bands and flags, offline outbox, history on Today (`features/assessments/`, `api/.../scoring.py`, `routers/assessments.py`). BDI-II dropped (licence). Worked | Roman Urdu wording unvalidated (clinician flag `clinicianUnvalidatedTranslation`) | KEEP PHQ-9/GAD-7; PSS-10/Rosenberg are free and could return; DROP BDI-II |

### Self-help

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| Breathing exercises | Calm the body | List/detail pages (`Views/relaxtion/breathing_exercise_*`). Worked | Physiological sigh, box, 4-7-8 "calming"; animated player; can run inline in chat (`features/exercises/breathing*.dart`, `features/eve/exercise_cards.dart`). Worked | | KEEP |
| Grounding (5-4-3-2-1), muscle relaxation | Come back to the present | None | Inline cards in chat (`exercise_cards.dart:278-512`). Worked | | KEEP |
| Meditation / visualization | Guided practice | YouTube videos embedded (`Views/relaxtion/meditation_*`, `visualization_*`, `youtube_player_flutter`). Worked | None | YouTube needs data, shows ads/recommendations | RETHINK: short local audio in Urdu/Roman Urdu |
| Soothing sounds | Background calm, sleep | Rain, ocean, white noise, binaural, fireplace via `audioplayers` + `assets/audio` (`Views/stress_relieving.dart`). Worked | None | | RETHINK: cheap to add, good for sleep use case |
| Journal | Write it out | Firestore `users/{uid}/journalEntries`, emoji picker, edit, list (`Views/express your self/journal_*.dart`). Worked | Server-stored plaintext, mood per entry, 3 prompts, screened by Guardian, shareable to clinician (`features/journal/`, `routers/journal.py`). Worked; **no offline, not encrypted** | backend-devops review #21 | KEEP; RETHINK storage (local-first/encrypted, sync optional) |
| Artistic expression | Creative outlet | Prompts + detail pages (`Views/express your self/artistic_expression_*`). Content only, partial | None | | DROP (or fold into journal prompts) |

### Finding help and clinicians

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| Nearby clinics map | Find a real place to go | Google Maps + Places text search, details, favourites in Firestore (`Views/maps/map 2.dart`, `google_places_service.dart`). Worked (Maps key since revoked) | None | Places data for "psychologist" in PK is noisy and unvetted | RETHINK: curated, verified directory (city, fee, language, gender, online/in-person) beats raw Places |
| Professional directory + booking | Book a therapist | Registered professionals listed on the map (`professional_user_service.dart`), booking writes Firestore `appointments` (`map 2.dart:1348`). `appointments_details_page.dart` is empty. Partial | None | No payments, no calendar, no confirmation | RETHINK: decide if TherapyLink is a marketplace; likely out of MVP |
| Care link (patient ↔ clinician) | Let your own therapist see what you choose | None (access came from booking) | Patient enters clinician invite code → pending link → clinician accepts → patient toggles assessments / mood trend / journal per link; revoke any time (`features/care/care_screen.dart`, `routers/care.py`). Worked in APK; accept/decline routes missing from recovered API | Summaries flag exists but app never writes summaries (`care_screen.dart:103`) | KEEP (strong differentiator) |
| Clinician caseload + patient view | Review patients between sessions | `Views/professional_dashboard.dart` → `view_user_insights.dart`: appointment list + Gemini chat summary + sentiment. Worked, no consent | `features/clinician/caseload_screen.dart` (attention flags, invite code, rotate), `patient_screen.dart` (only sections the patient shares), `requests_screen.dart`. Also runs on web. Worked | | KEEP v2's consent model |
| Access log | See which clinician saw what, when | None | `features/you/access_log_screen.dart`, `GET /me/access-log`; server log is append-only. Worked in APK; route missing in recovered API | | KEEP |
| Clinician verification | Only real clinicians see data | Pending screen; approval done outside the app (admin panel not in repo) | CLI `api/scripts/verify_clinician.py`; "Verified clinician" badge for patients | Needs PMDC / council check SOP | KEEP, with an admin screen |

### Privacy, data, settings

| Feature | For the user | Legacy | v2 | Notes | New app |
|---|---|---|---|---|---|
| App lock | Others can't open it | None (biometric only in profile page) | Opt-in, uses phone biometrics/PIN (`local_auth`), relocks after a minute away (`core/security/app_lock.dart`, `features/shared/lock_screen.dart`). Worked | | KEEP |
| Screenshot / recents protection | Content hidden in app switcher | None | FLAG_SECURE via `therapylink/privacy` channel (`app/android/.../MainActivity.kt`, `app_lock.dart:58-67`). Worked | | KEEP |
| Quick exit | Hide the app instantly if someone walks in | None | On every page by default; neutral cover screen, closes app on Android, needs unlock to return if lock is on (`core/security/quick_exit.dart`, `features/shared/quick_exit_button.dart`). Worked | Key for women on shared phones | KEEP |
| Local encryption | Chats unreadable off the phone | None (all in Firestore) | SQLCipher, per-account key in secure storage, migrates plaintext (`core/db/encrypted_database_native.dart`, `core/security/database_key.dart`). Worked; not device-tested | | KEEP |
| Per-account wipe on sign-out | Shared phone safety | No | One DB per uid, wiped + deleted on sign-out (`core/auth/session.dart`). Worked | | KEEP |
| No cloud backup | Chats don't leak to Google backup | Default backup on | `allowBackup=false` + extraction rules (`app/android/app/src/main/res/xml/data_extraction_rules.xml`). Worked | | KEEP |
| Data export | Take your data | "Export My Data" JSON of user, chats, posts (`Views/privacy_security_page.dart`). Partial | `GET /me/export` saved as JSON in Downloads (`features/you/account_actions.dart:79-95`). Worked; **server data only, not on-phone chats** | | KEEP; include local data |
| Account deletion | Leave completely | "Delete My Account" sets `scheduledDeletion` with a countdown (`privacy_security_page.dart:175-191`). Partial (no backend purge) | `DELETE /me` cascades, erases Firebase user, blocks token reuse; web deletion page `GET /account/delete` (`api/.../routers/account_page.py`). Worked | Play requires web URL | KEEP |
| Delete chats / memory | Erase what Eve has | n/a | "Delete chats" and per-note delete (`you_screen.dart:73`, `memory_screen.dart`). Worked | | KEEP |
| Private account, location toggle, 2FA | Privacy settings | Toggles in `privacy_security_page.dart`; 2FA is phone OTP verify. Mostly stub | None | "Private account" implied a social feed that doesn't exist | DROP |
| Language | Use the app in your language | Dropdown English/Spanish/French/German, saved to prefs, **no translations** (`Views/settings.dart:161-178`). Stub | English + Roman Urdu (`l10n/app_en.arb`, `app_ur.arb`), Noto Nastaliq font loaded but **no Urdu-script UI**. Worked | Eve mirrors user language | KEEP EN + Roman Urdu; RETHINK Urdu script |
| Text size, theme, reduce motion | Comfort, accessibility | Font size + theme providers (`Views/font_size_provider.dart`, `theme_provider.dart`). Worked | Text size, light/dark/system, reduce motion (`features/you/settings_screen.dart`). Worked | | KEEP |
| Notifications / reminders | Gentle check-in reminders | "Enable Notifications" toggle only, no FCM or local notifications package. Stub | None | Must not leak content on lock screen | RETHINK: opt-in, neutral-text local reminders |
| Help & FAQ, feedback, about | Support | `Views/help_faq_page.dart`, `send_feedback_page.dart`, `about_page.dart`. Worked (static/email) | None | No "report an AI reply" either (store requirement) | KEEP FAQ + feedback + report-reply |
| Crash reporting / metrics | (Team) know what breaks | None | None (`docs/ship-review/STATUS.md` Phase 1 open) | Must scrub content | KEEP as engineering requirement |

## 3. Key v2 flows

**A. First run → consent → chat**
1. App opens on `/welcome` (router sends everyone there until consent, `app/router.dart:62-66`). Get help is top-right.
2. Pick English or Roman Urdu → Continue.
3. `/consent`: AI, emergency and data points; tick 18+ and agree; or "I'm under 18" → helplines only.
4. `/sign-in`: Google or email/password (create/sign in/reset). Consent version syncs to the server.
5. Router sends a patient to `/eve` (a clinician to `/clinic`).
6. On-device mode: banner offers the ~2 GB model download. Release build without a fine-tuned, pinned model + Guardian: composer is replaced by "exercises and help" (`eve_screen.dart:110-117`).
7. Starters or free text → Guardian check → model reply streams in (number-guarded) → saved locally.

**B. Crisis path**
1. User sends a message. Guardian classifies it before anything is saved.
2. If no hit, the last 20 min of messages are re-checked together.
3. On a hit: message flagged, model **not** called, crisis mode on for 60 min, crisis card (kind-specific lines) added, sheet opens (at most every 10 min).
4. In crisis mode every Eve reply is followed by the card; help bar stays pinned; wrap-up skips "next step".
5. Sheet: tap to call; if the dialer fails, big number + copy. Under-18/child/abuse kinds put Madadgaar first.
6. Same sheet from: PHQ-9 item 9 > 0 (offline too), journal save, Get help on any screen.

**C. Clinician linking**
1. Clinician: You → "I'm a clinician" → confirm → licence no. + specialty → role becomes clinician → `/clinic` shows "awaiting verification".
2. Admin runs `verify_clinician.py <email>` → caseload opens; clinician copies invite code (can rotate).
3. Patient: You → Your care team → enter code → link is **pending**, all sharing off.
4. Clinician: Requests → accept or decline.
5. Patient switches on assessments / mood trend / journal per link; can revoke any time.
6. Clinician patient view shows only switched-on sections; every view is written to the access log, which the patient can read under You.

## 4. Gaps neither version had

- **Verified help directory** for Pakistan: helplines with hours/cost/WhatsApp, plus vetted low-cost and free services by city (public hospital psychiatry OPDs, university counselling, NGOs). Neither has a women's/DV line.
- **Safety plan** (Stanley-Brown style): warning signs, coping steps, people to call, a trusted contact. Not built anywhere.
- **Trusted contact / "tell someone"** flow, with the user in control.
- **Urdu script UI** and **voice** for lower-literacy users; Roman Urdu only is a partial reach.
- **Low-end phone + data reality**: v2 needs a 2 GB download and an arm64 GPU path; no lite mode, no SMS/USSD/WhatsApp entry point.
- **Shared-phone discretion** beyond quick exit: disguised icon/name, neutral notification text, decoy screen.
- **Psychoeducation in context**: short content on stigma ("log kya kahenge"), family pressure, exam stress, postpartum, religion-sensitive coping.
- **Guided programmes** (e.g. a 2-week CBT-lite or sleep course) rather than single exercises.
- **Reminders/re-engagement** that don't nag (opt-in, neutral text).
- **Report an AI reply** and in-app feedback (store requirement for AI apps).
- **Minors / guardian pathway**: currently a hard stop; a large share of the likely audience is 16-18.
- **Offline-first journal** and export of on-device data.
- **Clinician tools beyond viewing**: notes, session prep, secure messaging, crisis escalation policy.
- **Payments / B2B entitlements** (university or employer licences) if that is the business model.
- **Content-free analytics and crash reporting**.
