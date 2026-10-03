# Security

TherapyLink holds mental-health data: crisis disclosures, assessment answers, journal entries. Please treat any weakness in it as urgent, and report it privately.

## Reporting a vulnerability

Use GitHub's private reporting: the **Security** tab of this repository, then **Report a vulnerability**. Don't open a public issue, and don't put details in a PR or commit message.

Tell us what you found, how to reproduce it, and what you think an attacker could reach. Don't access, keep or change another person's data to prove a point. A test account of your own is enough.

You'll get an acknowledgement within 3 working days and a first assessment within 7.

Safety failures count as security bugs and go through the same channel, at the top of the queue:

- the crisis card or helplines not showing for a crisis message
- the output guard letting through a phone number that isn't on the helpline list
- Eve answering a turn that should have been routed to crisis support

If you are in distress yourself, this channel is too slow. In Pakistan call Rescue 1122, or the helplines listed in the app.

## In scope

`app/`, `api/`, `ml/` (the served prompt, the safety rules and the eval gates), `ops/`, and the CI config in `.github/`. Bugs in Firebase, Google Cloud, Neon or llama.cpp themselves go to those vendors.

## What data goes where

This is the design v3 is built to. The full threat model, and which parts are enforced in code versus still open, are in [docs/rebuild/SECURITY.md](docs/rebuild/SECURITY.md). In short:

| Data | Where it lives |
| --- | --- |
| Eve chats, memories, conversation summaries, Guardian crisis flags | Phone only, in a SQLCipher database whose key is in the Android Keystore / iOS Keychain. Excluded from device backups. Never sent to the API in release builds. |
| PHQ-9 / GAD-7 answers and scores | API database (scored on the server). |
| Mood check-ins | Phone, and the API when the patient syncs them. Text-free points only. |
| Journal entries | API database for now. Moving to local-first is on the roadmap. |
| Clinician links and sharing choices | API database. All four sharing switches start off, a link starts `pending`, and every clinician read writes an append-only access-log row the patient can see. |
| Identity | Firebase Auth. The API stores the uid and email. |

The model server has no public URL. It listens on localhost or a private network, needs an API key, and doesn't log prompts. The phone reaches it only through the API, which checks the Firebase token and rate-limits per user. Crisis turns never reach the model.

Server logs carry route templates, status, latency and request IDs. They never carry request bodies, conversation or journal text, tokens, or raw uids.

Deleting an account (`DELETE /me`) erases the server data and the Firebase user, and the app wipes the local database on sign-out.

## Secrets

No secret belongs in this repo. The only credentials committed are the Firebase client identifiers in `app/lib/firebase_options.dart`, which ship in every app build anyway and are locked down in the GCP console and by App Check.

gitleaks scans the full history on every push and PR (`.gitleaks.toml`), and CI also fails on any `.env`, `key.properties`, keystore or service-account file ever added to history. If a secret does get committed, revoke it first, then clean up the history. Hiding the finding with an allowlist doesn't make the key safe.
