from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Empty values (TL_X= in .env.example) mean unset, not an empty string.
    model_config = SettingsConfigDict(env_file=".env", env_prefix="TL_", extra="ignore", env_ignore_empty=True)

    # prod and staging turn the dev switches below into a startup error rather than trusting
    # the env file. staging uses a real Firebase project and a real database; prod is for patients.
    env: Literal["dev", "staging", "prod"] = "dev"
    database_url: str = "sqlite+aiosqlite:///./dev.db"
    # Behind a transaction-mode pooler (Neon's -pooler host, PgBouncer). None: guess from the URL.
    database_pooled: bool | None = None
    firebase_project_id: str = "therapylink69"
    firebase_service_account_json: str | None = None
    inference_base_url: str | None = None
    inference_api_key: str | None = None
    inference_model: str = "eve-e4b"
    # Maximum tokens the server will forward to the LLM, regardless of what the client requests.
    inference_max_tokens: int = 1024
    cors_origins: list[str] = ["http://localhost:8080", "http://localhost:3000"]
    dev_auth_bypass: bool = False
    # Local demos only: approve clinician sign-ups immediately instead of waiting for
    # scripts/verify_clinician.py. Never enable where real patients exist.
    dev_auto_verify_clinicians: bool = False
    # /inference/chat per uid: short window — a burst of this many, refilled over the period.
    inference_rate_capacity: int = 30
    inference_rate_period_s: float = 600
    # /inference/chat per uid: hard daily cap regardless of the short window.
    inference_daily_cap: int = 300
    # Mutating routes (POST/PUT/PATCH/DELETE) per uid: capacity per minute.
    write_rate_capacity: int = 60
    # Redis URL for shared rate-limit state across workers. Empty → in-memory (per-worker) buckets.
    redis_url: str | None = None
    # When true, every mutating and inference request must carry a valid Firebase App Check token
    # in X-Firebase-AppCheck. Disabled by default so tests and curl work without an app.
    app_check_required: bool = False
    # SHA-256 hex digest of the first TL_PROMPT_CHARS characters of the expected system/folded
    # prompt. When set together with TL_PROMPT_CHARS, /inference/chat checks that the first
    # message (role=user for folded conversations, or role=system) starts with the registered
    # prompt. Both must be set or neither; startup fails if only one is present.
    prompt_sha256: str | None = None
    # Number of leading characters from the first message to hash against TL_PROMPT_SHA256.
    # Must be set alongside TL_PROMPT_SHA256.
    prompt_chars: int | None = None
    # Allowlist of additional registered prompts, comma-separated as "sha256hex:chars" pairs.
    # Use this to register the Eve system prompt AND the summary/memory instruction prompts so
    # all /inference/chat calls pass the hash check.  Example:
    #   TL_PROMPT_SHA256S=<eve-hash>:732,<summary-hash>:200,<memory-hash>:180
    # If set, each entry must be a 64-character hex SHA-256 and a positive integer chars count.
    # Compatible with TL_PROMPT_SHA256 / TL_PROMPT_CHARS: both contribute to the same allowlist.
    prompt_sha256s: str | None = None
    # Secret salt mixed into uid hashes in structured logs (never the raw uid).
    # Change this in every non-dev environment; a known salt defeats the hash.
    log_uid_salt: str = "dev-salt-change-me"
    # Max concurrent upstream inference requests (per process).  Requests beyond this wait in the
    # queue up to TL_INFERENCE_MAX_QUEUE total; beyond that, /inference/chat returns 503 immediately
    # and the rate-limit token is NOT spent.  Set TL_INFERENCE_MAX_INFLIGHT=2 for a 2-slot CPU server.
    inference_max_inflight: int = 2
    # Max total inflight + queued inference requests before returning 503 eve_busy.
    inference_max_queue: int = 4
    # Directory holding the trained Guardian's four bundle files, served publicly at
    # GET /guardian/<file> for the app to download (routers/guardian.py). Unset: that route is 404.
    guardian_dir: str | None = None


def config_problems(s: Settings) -> list[str]:
    """Settings that must never reach real patients. Empty means safe to start."""
    problems = []
    # staging and prod both use real Firebase projects; the dev bypass is never safe there.
    real_env = s.env in ("prod", "staging")
    real_db = not s.database_url.startswith("sqlite")
    real = real_env or real_db
    if real and s.dev_auth_bypass:
        problems.append("TL_DEV_AUTH_BYPASS lets anyone act as any uid; it is only allowed with sqlite in dev")
    if real and s.dev_auto_verify_clinicians:
        problems.append(
            "TL_DEV_AUTO_VERIFY_CLINICIANS approves unchecked clinicians; it is only allowed with sqlite in dev"
        )
    if s.inference_base_url and not s.inference_api_key:
        problems.append(
            "TL_INFERENCE_BASE_URL is set without TL_INFERENCE_API_KEY; the model server must require a key"
        )
    sha256_set = bool(s.prompt_sha256)
    chars_set = s.prompt_chars is not None
    if sha256_set != chars_set:
        problems.append(
            "TL_PROMPT_SHA256 and TL_PROMPT_CHARS must be set together or not at all; "
            "set both to enable the prompt integrity check"
        )
    if s.prompt_sha256s:
        for entry in s.prompt_sha256s.split(","):
            entry = entry.strip()
            if not entry:
                continue
            parts = entry.split(":")
            if len(parts) != 2:
                problems.append(f"TL_PROMPT_SHA256S entry {entry!r} must be 'sha256hex:chars'")
                continue
            sha, chars_str = parts[0].strip(), parts[1].strip()
            if len(sha) != 64 or not all(c in "0123456789abcdefABCDEF" for c in sha):
                problems.append(f"TL_PROMPT_SHA256S entry {entry!r}: first part must be a 64-char hex SHA-256")
            if not chars_str.isdigit() or int(chars_str) <= 0:
                problems.append(f"TL_PROMPT_SHA256S entry {entry!r}: second part must be a positive integer")
    # Guard against a common mistake of deploying with the placeholder salt.
    if s.env == "prod" and s.log_uid_salt == "dev-salt-change-me":
        problems.append("TL_LOG_UID_SALT is still the default; set a secret value before deploying to prod")
    return problems


def check_config(s: Settings) -> None:
    if problems := config_problems(s):
        raise RuntimeError("refusing to start: " + "; ".join(problems))


@lru_cache
def get_settings() -> Settings:
    return Settings()
