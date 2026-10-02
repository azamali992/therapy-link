from functools import lru_cache
from typing import Literal
from urllib.parse import urlparse

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
    # SHA-256 hex digest of the allowed system prompt. When set, /inference/chat rejects any
    # conversation whose first message (role=system) does not hash to this value.
    prompt_sha256: str | None = None
    # Secret salt mixed into uid hashes in structured logs (never the raw uid).
    # Change this in every non-dev environment; a known salt defeats the hash.
    log_uid_salt: str = "dev-salt-change-me"


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
        problems.append("TL_DEV_AUTO_VERIFY_CLINICIANS approves unchecked clinicians; it is only allowed with sqlite in dev")
    if s.inference_base_url and not s.inference_api_key:
        problems.append("TL_INFERENCE_BASE_URL is set without TL_INFERENCE_API_KEY; the model server must require a key")
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
