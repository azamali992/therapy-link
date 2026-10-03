# TherapyLink

A mental-health companion app for English and Roman Urdu speakers in Pakistan. Patients chat with Eve (a fine-tuned Gemma 4 E2B served from our own llama-server), log mood, keep an encrypted journal, take PHQ-9 and GAD-7, and can link a clinician who only sees what they switch on. Crisis routing runs on the phone before any message reaches the model, and never depends on the server.

This is v3: a new app with a new design, a fresh git history, and the tested API and ML code carried over from v2. The plan is in [docs/rebuild/PLAN.md](docs/rebuild/PLAN.md). It is not cleared for real patients yet (see "Human blockers" in the plan).

## Repo layout

| Path | What's in it |
| --- | --- |
| `app/` | Flutter 3.47.4 app (Riverpod, go_router, drift + SQLCipher, Firebase Auth). Chats and memories stay on the device. |
| `api/` | FastAPI gateway: Firebase token checks, consent, server-scored assessments, clinician access log, inference proxy to llama-server. Postgres in prod, SQLite locally. See [api/README.md](api/README.md). |
| `ml/` | Data pipeline, Guardian and Eve training, the eval harness and the served prompt. See [ml/README.md](ml/README.md). |
| `ops/serving/` | Running Eve's llama-server from `ml/registry.json` (being added on the `ml-serving` branch). |
| `docs/rebuild/` | v3 discovery docs: features, model, UX, backend, security, plan. |
| `docs/clinical/`, `docs/legal/` | Helplines, red lines, pilot protocol, data inventory. |
| `scripts/` | Windows setup scripts (Android SDK, llama.cpp) and a resumable downloader. |
| `.github/` | CI and Dependabot. |

## Local setup (Windows, everything on D:)

Nothing goes on C:. Toolchains live under `D:\dev`, and the caches that default to your user profile get moved there too. Set these once, then open a new terminal:

```powershell
[Environment]::SetEnvironmentVariable("PUB_CACHE",        "D:\dev\pub-cache", "User")
[Environment]::SetEnvironmentVariable("GRADLE_USER_HOME", "D:\dev\gradle",    "User")
[Environment]::SetEnvironmentVariable("PIP_CACHE_DIR",    "D:\dev\pip-cache", "User")
[Environment]::SetEnvironmentVariable("HF_HOME",          "D:\dev\hf",        "User")
[Environment]::SetEnvironmentVariable("TMP",              "D:\dev\tmp",       "User")
[Environment]::SetEnvironmentVariable("TEMP",             "D:\dev\tmp",       "User")
```

Then the toolchains:

1. **Flutter 3.47.4** unpacked to `D:\dev\flutter`, with `D:\dev\flutter\bin` on your user PATH. CI pins the same version, so check `flutter --version` before chasing an analyzer difference.
2. **JDK 17 and the Android SDK** (no Android Studio needed). The script puts them in `D:\dev\jdk-17` and `D:\dev\android-sdk`, sets `JAVA_HOME` and `ANDROID_HOME`, and accepts the licences:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\setup-android-sdk.ps1 -Root D:\dev
   ```

3. **Python 3.12.** Each Python project gets its own `.venv` inside its folder, so the venvs are on D: with the repo.
4. **llama.cpp and a base GGUF**, only if you run Eve locally (needs a CUDA GPU, or add `-Cpu`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\setup-llama-server.ps1 -Root D:\dev
   ```

5. **gitleaks 8.30+** in `D:\dev\tools\gitleaks`, on PATH, if you want the pre-commit hook (below).

## Run it

### API

```powershell
cd api
python -m venv .venv
.venv\Scripts\python -m pip install -e ".[dev]"
copy .env.example .env          # SQLite and the dev auth bypass, for local work only
.venv\Scripts\alembic upgrade head
.venv\Scripts\uvicorn therapylink_api.main:app --reload
```

It listens on `http://localhost:8000`. With `TL_DEV_AUTH_BYPASS=true` in `.env`, send `X-Dev-Uid: anything` instead of a Firebase token. The API refuses to start with the bypass on when `TL_ENV=prod` or the database isn't SQLite.

### Model server (Eve)

The served model, its adapter and their checksums come from `ml/registry.json`. [ops/serving/](ops/serving/) starts llama-server on 127.0.0.1 only and refuses to start without an API key:

```powershell
$env:TL_LLM_API_KEY = "<24+ random characters>"
powershell -ExecutionPolicy Bypass -File ops\serving\run-llama-server.ps1
```

Point the API at it by adding the same key to `api\.env`. The API won't start with a URL and no key.

```text
TL_INFERENCE_BASE_URL=http://127.0.0.1:8080
TL_INFERENCE_API_KEY=<same key>
```

There is no public tunnel any more. A phone reaches Eve only through the API.

### App

```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run --dart-define=TL_API_URL=http://10.0.2.2:8000     # Android emulator
```

On a USB phone, run `adb reverse tcp:8000 tcp:8000` and use `TL_API_URL=http://localhost:8000`. Release signing reads `app/android/key.properties` and the upload keystore, and neither ever goes into git (CI and the pre-commit hook both fail on them).

## Tests

The same commands CI runs:

```powershell
# app
cd app
flutter analyze
flutter test

# api
cd api
.venv\Scripts\ruff check .
.venv\Scripts\ruff format --check .
.venv\Scripts\python -m pytest

# ml (CPU torch is enough for the tests)
cd ml
python -m venv .venv
.venv\Scripts\python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
.venv\Scripts\python -m pip install transformers peft scikit-learn pandas datasets huggingface_hub pydantic typer rich requests pytest ruff
.venv\Scripts\python -m pip install -e . --no-deps
.venv\Scripts\ruff check .
.venv\Scripts\python -m pytest
```

`ml/tests/test_prompt_parity.py` checks that the app sends exactly the prompt Eve was trained on, so it reads files under `app/lib`. A change to Eve's prompt touches both folders.

Secret scan, the same way CI does it:

```powershell
gitleaks git --config .gitleaks.toml --redact .     # every commit
gitleaks dir --config .gitleaks.toml --redact .     # working tree, untracked files too
```

## CI

`.github/workflows/ci.yml` runs on every PR and on pushes to `main`. A job runs only when its folder changes; the gitleaks history scan runs every time. `ci-ok` is the one job branch protection needs to require. No repository secrets are used.

Optional local hooks (ruff, gitleaks, dart format, a block on `.env`, keystore and service-account files):

```powershell
pip install pre-commit
pre-commit install
```

## More

- [CONTRIBUTING.md](CONTRIBUTING.md): branches, commits, tests.
- [SECURITY.md](SECURITY.md): reporting a vulnerability, and what data goes where.
