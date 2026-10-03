# therapylink

The TherapyLink Flutter app: Eve (chat), journal, check-ins and the crisis help that sits on top of all of it.

## Build flags

| Flag | What it is |
|---|---|
| `TL_API_URL` | The API, e.g. `https://therapylink-pilot.duckdns.org` |
| `TL_GUARDIAN_URL` | Where the Guardian bundle is downloaded from: the API's `/guardian/` route, e.g. `https://therapylink-pilot.duckdns.org/guardian/` |
| `TL_GUARDIAN_SHA256` | The four files' sha256, pinned. Copy the `dart_define` value from `ml/releases/<release>/report.json` |
| `TL_GUARDIAN_BYTES` | Optional. The bundle's total size, shown before a download if the server doesn't say. Defaults to v1b's 287,093,575 |

A release build for the pilot:

```powershell
$guardianHashes = (Get-Content ..\ml\releases\guardian-v1b\report.json | ConvertFrom-Json).dart_define
flutter build apk --release `
  --dart-define=TL_API_URL=https://<domain> `
  --dart-define=TL_GUARDIAN_URL=https://<domain>/guardian/ `
  --dart-define=$guardianHashes
```

Serving the files is in `docs/deploy/FREE_DEPLOY.md` (step 4b).

## Guardian, the on-device safety check

Every message is checked on the phone before Eve sees it: a keyword floor (`lib/core/ml/guardian.dart`) that is always on, and the trained Guardian (`lib/core/ml/onnx_guardian.dart`, XLM-R int8 ONNX) once it is installed. Either one firing routes the person to help. Which help depends on the kind: suicide, self-harm, abuse, child, sexual violence, harm to others or a medical emergency, each with its own copy (`lib/features/shared/crisis_copy.dart`) and lines (`helplines.dart`). A message with several kinds goes to the most urgent one the model is sure of; the order and the reasons are on `crisisPriority`.

How it behaves:

- The download starts by itself on Wi-Fi. On mobile data it waits, and Settings → Safety check lets the person download anyway. It checks free space first and resumes after a dropped connection. The keyword floor guards every message meanwhile.
- Every file is checked against `TL_GUARDIAN_SHA256` before it is moved into place, and the loaded model has to pass its canaries (English, Roman Urdu and Urdu script) before it is used. A build without the hashes never installs anything.
- Tokenizing runs in its own isolate and inference goes through the ONNX plugin's async API. Each message gives the model 3 seconds; past that the keyword verdict stands, so a send is never held up and never skips the floor.
- In a release build Eve's chat stays paused until the model is installed and working. Debug and profile builds chat on the keyword floor alone.

Swapping in a new release (v1c) is a config change: same four file names, a new `TL_GUARDIAN_SHA256` (and `TL_GUARDIAN_BYTES`), new files on the server.

### Trying a bundle locally (debug and profile builds only)

`TL_GUARDIAN_URL` can be a local directory. The app copies the four files from it and checks them against `TL_GUARDIAN_SHA256`, or, if that isn't set, against the `verified.json` next to them (the ML bundle has one). Release builds ignore a local path.

On Windows desktop, point it at the bundle:

```powershell
flutter run -d windows --dart-define=TL_GUARDIAN_URL=D:\therapylink-v3\ml\runs\guardian-v1b-kaggle\runs\xlmr-base\bundle
```

On an Android device, push the files to the app's external files directory, which it can read without asking for a permission:

```powershell
adb push <bundle>\. /sdcard/Android/data/com.therapylink.therapylink/files/guardian/
flutter run --dart-define=TL_GUARDIAN_URL=/sdcard/Android/data/com.therapylink.therapylink/files/guardian
```

## Tests

```powershell
flutter analyze
flutter test
```
