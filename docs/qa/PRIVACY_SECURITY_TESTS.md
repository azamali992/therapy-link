# TherapyLink v3 — Privacy and Security Tests

**Version:** 1.0  
**Date:** 2026-10-03  
**Severity of any failure:** P0 items → S2 (blocks pilot); P1 items → S2 (blocks public launch)  
**Source documents:** `docs/rebuild/SECURITY.md` §3 (P0/P1 backlog), §4 (architecture), §5 (secrets scan)

All test IDs use the prefix `PS-`.

---

## PS-001: SQLCipher DB encryption — adb pull cannot read DB without key

**P level:** P0 (SECURITY.md §3.1 — carry forward)  
**Preconditions:** Release build installed on D1 or D2 (Android). User signed in; at least one mood entry logged.  
**Steps:**
1. Enable Android Developer Options and USB debugging on D2.
2. Run: `adb backup -noapk <package_name>` (or `adb shell run-as <package> cat databases/therapylink_<uid>.db > /sdcard/test.db && adb pull /sdcard/test.db`)
3. Attempt to open the pulled file with SQLite browser (DB Browser for SQLite).

**Expected result:**
- The pulled file is either not readable (encrypted) or reports a "not a database" / "file is not a database" error from SQLite browser.
- The file is not readable as plain SQLite3.
- If `adb backup` is used, the DB file is absent from the backup archive (backup exclusion tested separately in PS-002).

**Automation target:** manual (D1, D2 required; adb access needed)

---

## PS-002: Backup exclusion — DB absent from Android backup

**P level:** P0 (SECURITY.md §3.1 — carry forward)  
**Preconditions:** Release build. `allowBackup=false` and `fullBackupContent` rules in `AndroidManifest.xml`. Google account logged in on device.  
**Steps:**
1. Log some mood entries and journal text.
2. Run: `adb backup -apk -shared <package_name>` and inspect the resulting `.ab` file with Android Backup Extractor.
3. Check whether `databases/therapylink_*.db` appears in the extracted archive.
4. Also check: Settings > Accounts > Google > Backup — confirm TherapyLink is excluded or backup is disabled.

**Expected result:**
- The DB file does not appear in the backup archive.
- No chat, mood, or journal data is extractable from the backup.

**Automation target:** unit (AndroidManifest `allowBackup=false` and extraction rules asserted in `privacy_platform_test.dart` — port from v2), manual (physical device adb check)

---

## PS-003: Backup exclusion — iOS backup does not include DB

**P level:** P0  
**Preconditions:** Release build on D3 (iPhone). iCloud Backup enabled.  
**Steps:**
1. Log some data.
2. Back up to iCloud via Settings > Apple ID > iCloud > iCloud Backup.
3. Restore to a different iPhone or use a tool to inspect the backup contents.
4. Confirm `Info.plist` has `UIFileSharingEnabled = false` and `LSSupportsOpeningDocumentsInPlace = false`.

**Expected result:**
- The app's DB file is NOT present in the iCloud backup.
- File sharing off (cannot open DB via Files app or Finder).

**Automation target:** unit (Info.plist assertions — port from `privacy_platform_test.dart`), manual (D3)

---

## PS-004: FLAG_SECURE — app content blacked out in recent apps

**P level:** P0 (SECURITY.md §3.1 — carry forward)  
**Preconditions:** Release build. User signed in. Eve chat visible with a message on screen.  
**Steps:**
1. Press the Android "recent apps" button (square or gesture swipe).
2. Observe the TherapyLink thumbnail.

**Expected result:**
- The thumbnail is black or shows a blurred/blank preview (not the chat content).
- Any health content (mood, journal text, chat messages) is NOT visible in the recent apps switcher.

**Automation target:** unit (FLAG_SECURE set in `privacy_platform_test.dart` — port from v2), manual (D1, D2)

---

## PS-005: Sign-out wipe — local DB deleted on sign-out

**P level:** P0 (SECURITY.md §3.1 — carry forward)  
**Preconditions:** User signed in with at least 3 mood entries and 1 journal entry. SQLCipher DB file exists.  
**Steps:**
1. Navigate to You > Account > Sign out.
2. Confirm sign-out (with "Remove chats?" if the option is shown — select Remove).
3. Check whether the DB file still exists using: `adb shell run-as <package> ls databases/`.
4. Re-open the app. Confirm sign-in screen appears with no pre-populated data.

**Expected result:**
- The DB file `therapylink_<uid>` is deleted from device storage.
- Re-opening the app shows the sign-in screen with no mood, journal, or chat history visible.
- A new sign-in creates a new empty DB.

**Automation target:** unit (sign-out triggers DB wipe — port from `platform_signout_test.dart`), manual (D2 adb check)

---

## PS-006: Account deletion — full cascade end-to-end

**P level:** P0 (SECURITY.md §3.1 — carry forward)  
**Preconditions:** Test account `test_deletion@therapylink.invalid` has been created. It has: 2 mood entries, 1 journal entry, 1 PHQ-9 result, a care link (pending), and at least one access log entry.  
**Steps:**
1. Sign in as the test account.
2. Navigate to You > Account > Delete account.
3. Confirm deletion.
4. Attempt to call `GET /me` with the now-deleted user's Firebase ID token (obtain before deletion, valid for ~1 hour).
5. Check the `erased_accounts` table in the test DB for a tombstone row.
6. Attempt to sign in with the same email/password.

**Expected result:**
- Step 4: API returns 401 or 403 (ErasedAccount tombstone prevents reuse of the ID token within the token window).
- Step 5: A row exists in `erased_accounts` with the uid.
- Step 6: Firebase returns "no user found" (Firebase account deleted).
- All rows in `mood_logs`, `journal_entries`, `assessments`, `care_links` for this uid are deleted.

**Automation target:** API test (port from `test_account.py`)

---

## PS-007: Account deletion web URL accessible and functional

**P level:** P0 (SECURITY.md §3.2 P0-2)  
**Preconditions:** The web deletion URL has been submitted to Google Play Data Safety. The URL must be a real deployed page (not a placeholder).  
**Steps:**
1. Open the URL from an incognito browser (not logged in).
2. Confirm the page loads (HTTP 200).
3. Submit a deletion request using a test email address.
4. Confirm the account is deleted (via API or admin check).

**Expected result:**
- Page returns HTTP 200 from an unauthenticated browser.
- Form submission triggers account deletion.
- Google Play accepts the URL in the Data Safety form.

**Automation target:** API test (`test_deletion_page.py` — port from v2)

---

## PS-008: Clinician sees only consented sections, from link date onward

**P level:** P0 (SECURITY.md §4.6)  
**Preconditions:** Two test accounts — `test_patient@therapylink.invalid` and `test_clinician@therapylink.invalid` (verified clinician). A care link exists with `status=active` and `shared_from=T_link_date`. The patient has: mood entries before T_link_date and after, journal entries before and after, one PHQ-9 before T_link_date. All sharing flags start OFF.  
**Steps:**
1. As clinician, call `GET /clinician/patients/{patient_uid}`. Confirm 403 for all sections (all flags off).
2. As patient, set `share_assessments=true` only.
3. As clinician, call `GET /clinician/patients/{patient_uid}` again. Confirm only assessments are visible, and only assessments on or after T_link_date.
4. As patient, set `share_mood_trend=true`.
5. As clinician, call `GET /clinician/patients/{patient_uid}`. Confirm mood trend is visible; mood entries before T_link_date are NOT in the trend.
6. Call `GET /clinician/patients/{patient_uid}` as a clinician who does NOT have a care link with this patient. Expect 403.

**Expected result:**
- Each section is gated independently by its sharing flag.
- No data from before T_link_date is returned by any section.
- An unlinked clinician gets 403.

**Automation target:** API test (port from `test_consent.py` and `test_access_log.py`)

---

## PS-009: Access log entry written for every clinician read

**P level:** P0 (SECURITY.md §4.6)  
**Preconditions:** Active care link. Assessment sharing flag ON.  
**Steps:**
1. As clinician, call `GET /clinician/patients/{patient_uid}` three times.
2. As patient, call `GET /me/access-log`.

**Expected result:**
- Three access log entries appear, each showing the action and timestamp.
- The entries are append-only: re-calling the patient endpoint as clinician adds new entries, does not overwrite old ones.
- The patient can see these entries via `GET /me/access-log`.

**Automation target:** API test (port from `test_access_log.py`)

---

## PS-010: Access log is append-only — UPDATE and DELETE rejected by DB

**P level:** P0  
**Preconditions:** At least one access log row exists.  
**Steps:**
1. Directly on the test DB, attempt: `UPDATE access_log SET action='modified' WHERE id=<any id>`.
2. Attempt: `DELETE FROM access_log WHERE id=<any id>`.

**Expected result:**
- Both operations fail with a permission error (Postgres row-level security or trigger prevents modification and deletion of access_log rows).

**Automation target:** API test (DB-level assertion in `test_access_log.py`)

---

## PS-011: Rate limit — inference endpoint blocked after 30 requests in 10 minutes

**P level:** P0 (SECURITY.md §3.1)  
**Preconditions:** Test account with a valid Firebase token. Staging inference endpoint up.  
**Steps:**
1. Send 30 POST requests to `/inference/chat` within 10 minutes using the same token.
2. Send the 31st request.

**Expected result:**
- Requests 1–30 return 200 (or streaming 200).
- Request 31 returns 429 with a `Retry-After` header.
- After the 10-minute window resets, a new request succeeds.

**Automation target:** API test (port from `test_limits.py`)

---

## PS-012: Rate limit — daily limit of 300 requests enforced

**P level:** P0  
**Preconditions:** As above.  
**Steps:**
1. Mock or advance the token bucket to 300 consumed for the day.
2. Send one more request.

**Expected result:**
- 429 returned with a message indicating daily limit exhausted.

**Automation target:** API test (`test_limits.py`)

---

## PS-013: TL_ENV=prod rejects TL_DEV_AUTH_BYPASS

**P level:** P0 (SECURITY.md §3.1)  
**Preconditions:** API started with `TL_ENV=prod` and `TL_DEV_AUTH_BYPASS=true` in the environment.  
**Steps:**
1. Attempt to start the API.

**Expected result:**
- The API fails to start (raises a configuration error).
- The error message does not reveal secret values.
- Alternatively: if the API starts, a call with `X-Dev-Uid: anything` returns 401 (the header is ignored in prod).

**Note:** The SECURITY.md requirement is startup failure, not silent ignore. Test both: startup guard and, if that guard is missing, that the bypass header has no effect.

**Automation target:** API test (port from `test_config.py`)

---

## PS-014: TL_ENV=prod + non-sqlite DB required — no bypass in prod

**P level:** P0 (SECURITY.md §4.3)  
**Preconditions:** API started with `TL_ENV=prod` and `TL_DATABASE_URL=sqlite://...`.  
**Steps:**
1. Attempt to start the API.

**Expected result:**
- API fails to start (SQLite is not allowed in prod; too easy to copy off a server).

**Automation target:** API test (`test_config.py`)

---

## PS-015: Unauthenticated request to any protected route returns 401

**P level:** P0 (SECURITY.md §4.4)  
**Steps:**
1. Call each of the following with no Authorization header:
   - `GET /me`
   - `POST /inference/chat`
   - `GET /clinician/patients`
   - `GET /me/access-log`
   - `POST /assessments`

**Expected result:**
- All return 401 with a generic error message (no upstream exception details).

**Automation target:** API test (port from `test_auth_ops.py` and `test_errors.py`)

---

## PS-016: IDOR — clinician cannot read another clinician's patient

**P level:** P0 (SECURITY.md §4.4)  
**Preconditions:** Two patients (P1, P2), two clinicians (C1, C2). C1 is linked to P1 (active, all sections on). C2 is NOT linked to P1.  
**Steps:**
1. As C2, call `GET /clinician/patients/{P1_uid}`.
2. As C2, call `GET /clinician/patients` (caseload list).

**Expected result:**
- Step 1: 403 returned.
- Step 2: P1 does not appear in C2's caseload list.

**Automation target:** API test (`test_consent.py`)

---

## PS-017: Patient cannot read another patient's data

**P level:** P0 (SECURITY.md §4.4)  
**Preconditions:** Two test patients P1 and P2.  
**Steps:**
1. As P1, call `GET /journal` — confirm only P1's entries.
2. As P1, call `GET /journal/{P2_journal_id}` — confirm 403 or 404.
3. As P1, call `GET /me` — confirm P2's uid is not in the response.

**Expected result:**
- All P1 API calls return only P1's data. No P2 data accessible.

**Automation target:** API test

---

## PS-018: Firebase App Check — request without App Check token returns 403

**P level:** P1 (SECURITY.md §3.2 P1-1)  
**Preconditions:** API configured with `TL_APP_CHECK_ENABLED=true`. Valid Firebase ID token available but no App Check token.  
**Steps:**
1. Call `POST /inference/chat` with a valid `Authorization: Bearer <firebase_token>` but no `X-Firebase-AppCheck` header.

**Expected result:**
- API returns 403.

**Automation target:** API test (`test_auth_ops.py`)

---

## PS-019: Clinician email verification enforced

**P level:** P1 (SECURITY.md §3.2 P1-6)  
**Preconditions:** A clinician account exists with `email_verified=false` in Firebase.  
**Steps:**
1. Call `GET /clinician/patients` with the unverified clinician's token.

**Expected result:**
- API returns 403 with a message indicating email verification is required.

**Automation target:** API test (`test_auth_ops.py`)

---

## PS-020: Eve model download hash verification

**P level:** P1 (SECURITY.md §3.2 P1-4)  
**Preconditions:** `EveModelManager` configured with the correct SHA-256 hash in `gemma_eve_engine.dart`.  
**Steps (simulated in unit test):**
1. Simulate a download where the downloaded file's SHA-256 does NOT match the pinned hash.
2. Attempt to mark the model as ready.

**Expected result:**
- The model is NOT marked ready.
- An error is surfaced to the user ("Model verification failed; trying again").
- The corrupted file is deleted.

**Automation target:** unit (port from `eve_model_pinning_test.dart`)

---

## PS-021: Guardian per-file SHA-256 verified on load

**P level:** P0 (SECURITY.md §3.1)  
**Preconditions:** ONNX Guardian file loaded.  
**Steps (unit test):**
1. Tamper the Guardian file (change one byte) and attempt to load it.

**Expected result:**
- `OnnxGuardian` refuses to load the tampered file.
- The canary self-test fails.
- Crisis routing falls back to keyword-only mode; chat is disabled until a valid model is available.

**Automation target:** unit (port from `crisis_guardian_test.dart`)

---

## PS-022: Prod build — cloud mode not available

**P level:** P0 (SECURITY.md §3.1)  
**Preconditions:** Release build of the app (not debug or profile).  
**Steps:**
1. Navigate to Settings / Eve preferences.
2. Search for any toggle or option enabling cloud mode.

**Expected result:**
- Cloud mode is entirely absent from the release build UI.
- `core_test.dart` asserts `EveSettings.cloudModeAvailable == false` in kReleaseMode.

**Automation target:** unit (port from `core_test.dart`), manual (D2 release build)

---

## PS-023: Structured logging — no PII in API logs

**P level:** P1 (SECURITY.md §3.2 P1-12)  
**Preconditions:** Staging API running with structured JSON logging middleware.  
**Steps:**
1. Make authenticated calls to `/clinician/patients/{uid}`, `/journal`, `/assessments`.
2. Capture the log output from the API container.
3. Search the log output for: the patient's uid, the raw URL path (with uid embedded), any journal text, any chat text.

**Expected result:**
- Log lines contain: request ID, route template (e.g. `/clinician/patients/{uid}`, not `/clinician/patients/abc123`), HTTP status, latency, hashed uid (HMAC-SHA256), model ID, prompt version (where applicable).
- Log lines do NOT contain: plain uid, raw path, request body, response body, Firebase ID token.

**Automation target:** API test (log capture assertion)

---

## PS-024: Sign-out does not leave orphaned DB files

**P level:** P0  
**Preconditions:** User signed in. DB file exists.  
**Steps:**
1. Sign out (without "Keep chats" option if present, or the option that removes data).
2. Sign in as a DIFFERENT test user.
3. Check for DB files from the first user.

**Expected result:**
- Only one DB file exists: `therapylink_<new_uid>`.
- The previous user's DB file `therapylink_<old_uid>` has been deleted.

**Automation target:** unit (sign-out wipe in `platform_signout_test.dart`)

---

## PS-025: Privacy Manifest — iOS PrivacyInfo.xcprivacy exists and is valid

**P level:** P0 (SECURITY.md §3.2 P0-3)  
**Preconditions:** v3 app repository with iOS support.  
**Steps:**
1. Check that `app/ios/Runner/PrivacyInfo.xcprivacy` exists.
2. Submit to App Store Connect (or use `xcodebuild -validateArchive`) and confirm no "missing privacy manifest" warning.

**Expected result:**
- File exists with all required keys for the app's API usage (file system, UserDefaults, etc.).
- App Store Connect validation passes.

**Automation target:** unit (file existence check in `platform_manifest_test.dart`), manual (D3 App Store Connect)

---

## PS-026: Consent version — server and app agree

**P level:** P0 (SECURITY.md §3.1)  
**Preconditions:** Test account.  
**Steps:**
1. Fresh install. Complete onboarding. Observe consent version stored.
2. Server increments consent version.
3. Re-open the app.

**Expected result:**
- Step 1: `PUT /me/consent` is called with the current version.
- Step 3: App detects the version mismatch and shows the consent screen again before entering the shell.

**Automation target:** API test (`test_consent.py`), unit (consent sync logic)

---

## PS-027: Chat content never uploaded in release mode (data minimisation)

**P level:** P0 (SECURITY.md §4.5)  
**Preconditions:** Release build. Network traffic intercepted (mitmproxy or Charles on the LAN gateway).  
**Steps:**
1. Have a chat conversation with Eve in on-device mode (when available) or confirm cloud mode is absent in release (CR-022).
2. Inspect all outbound HTTPS requests.

**Expected result:**
- No request body contains raw chat message text.
- No request body contains memory note text.
- No request body contains Guardian crisis flag or valence per message.
- Only `POST /mood/batch` uploads manual check-in values (no text).
- `POST /journal` uploads journal body only when the user explicitly saves (by design — disclose in privacy policy).

**Automation target:** manual (mitmproxy on LAN), unit (`privacy_probe_scratch_test.dart` patterns)

---

## Running Privacy and Security Tests

```
# API tests (cover PS-006 through PS-027 API-layer items)
cd api && pytest tests/ -v -k "test_account or test_consent or test_limits or test_auth or test_access_log or test_config or test_deletion_page"

# App unit tests (cover PS-001 through PS-005, PS-020 through PS-022)
cd app && flutter test test/privacy_* test/platform_* test/eve_model_pinning_test.dart test/crisis_guardian_test.dart test/core_test.dart

# Manual tests: PS-001, PS-002, PS-003, PS-004, PS-027
# Require physical devices D1, D2 (Android), D3 (iOS), adb, mitmproxy
```
