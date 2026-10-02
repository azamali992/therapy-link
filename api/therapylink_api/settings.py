from functools import lru_cache
from typing import Literal
from urllib.parse import urlparse

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Empty values (TL_X= in .env.example) mean unset, not an empty string.
    model_config = SettingsConfigDict(env_file=".env", env_prefix="TL_", extra="ignore", env_ignore_empty=True)

    # prod turns the dev switches below into a startup error rather than trusting the env file.
    env: Literal["dev", "prod"] = "dev"
    database_url: str = "sqlite+aiosqlite:///./dev.db"
    # Behind a transaction-mode pooler (Neon's -pooler host, PgBouncer). None: guess from the URL.
    database_pooled: bool | None = None
    firebase_project_id: str = "therapylink69"
    firebase_service_account_json: str | None = None
    inference_base_url: str | None = None
    inference_api_key: str | None = None
    inference_model: str = "eve-e4b"
    cors_origins: list[str] = ["http://localhost:8080", "http://localhost:3000"]
    dev_auth_bypass: bool = False
    # Local demos only: approve clinician sign-ups immediately instead of waiting for
    # scripts/verify_clinician.py. Never enable where real patients exist.
    dev_auto_verify_clinicians: bool = False
    # /inference/chat per uid: a burst of this many, refilled evenly over the period.
    inference_rate_capacity: int = 30
    inference_rate_period_s: float = 600


def config_problems(s: Settings) -> list[str]:
    """Settings that must never reach real patients. Empty means safe to start."""
    problems = []
    real = s.env == "prod" or not s.database_url.startswith("sqlite")
    if real and s.dev_auth_bypass:
        problems.append("TL_DEV_AUTH_BYPASS lets anyone act as any uid; it is only allowed with sqlite outside prod")
    if real and s.dev_auto_verify_clinicians:
        problems.append("TL_DEV_AUTO_VERIFY_CLINICIANS approves unchecked clinicians; it is only allowed with sqlite outside prod")
    if s.inference_base_url and not s.inference_api_key:
        problems.append("TL_INFERENCE_BASE_URL is set without TL_INFERENCE_API_KEY; the model server must require a key")
    return problems


def check_config(s: Settings) -> None:
    if problems := config_problems(s):
        raise RuntimeError("refusing to start: " + "; ".join(problems))


@lru_cache
def get_settings() -> Settings:
    return Settings()
