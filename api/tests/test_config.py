from pathlib import Path

import pytest

from therapylink_api.main import create_app
from therapylink_api.settings import Settings, config_problems

PG = "postgresql+asyncpg://u:p@db.example/tl"


def _settings(**kw) -> Settings:
    base = {"dev_auth_bypass": False, "dev_auto_verify_clinicians": False, "_env_file": None}
    return Settings(**(base | kw))


@pytest.mark.parametrize(
    "kw",
    [
        {"dev_auth_bypass": True, "database_url": PG},
        {"dev_auth_bypass": True, "env": "prod"},
        {"dev_auto_verify_clinicians": True, "database_url": PG},
        {"dev_auto_verify_clinicians": True, "env": "prod"},
        {"inference_base_url": "https://gpu.example"},
        {"inference_base_url": "https://gpu.example", "inference_api_key": ""},
        # A local model server is only exempt in dev on sqlite, never in prod or on a real database.
        {"inference_base_url": "http://localhost:8080", "env": "prod"},
        {"inference_base_url": "http://127.0.0.1:8080", "database_url": PG},
        # A hostname that merely contains "localhost" is not loopback.
        {"inference_base_url": "http://localhost.evil.example:8080"},
    ],
)
def test_unsafe_settings_are_refused(kw):
    assert config_problems(_settings(**kw))


@pytest.mark.parametrize(
    "kw",
    [
        {"dev_auth_bypass": True, "dev_auto_verify_clinicians": True},  # local sqlite dev
        {"env": "prod", "database_url": PG},
        {"env": "prod", "database_url": PG, "inference_base_url": "https://gpu.example", "inference_api_key": "k"},
    ],
)
def test_safe_settings_start(kw):
    assert config_problems(_settings(**kw)) == []


def test_the_example_env_file_loads_and_is_safe(monkeypatch):
    # Blank lines like TL_DATABASE_POOLED= must read as unset, not fail bool parsing.
    for var in ("TL_DEV_AUTH_BYPASS", "TL_DATABASE_URL"):
        monkeypatch.delenv(var, raising=False)
    s = Settings(_env_file=Path(__file__).resolve().parents[1] / ".env.example")
    assert s.database_pooled is None and s.inference_base_url is None and s.firebase_service_account_json is None
    assert config_problems(s) == []


def test_app_refuses_to_start_with_the_bypass_in_prod(monkeypatch):
    monkeypatch.setenv("TL_ENV", "prod")  # conftest already turns the bypass on
    with pytest.raises(RuntimeError, match="TL_DEV_AUTH_BYPASS"):
        create_app()


def test_app_refuses_cloud_inference_without_a_key(monkeypatch):
    monkeypatch.setenv("TL_INFERENCE_BASE_URL", "https://gpu.example")
    monkeypatch.delenv("TL_INFERENCE_API_KEY", raising=False)
    with pytest.raises(RuntimeError, match="TL_INFERENCE_API_KEY"):
        create_app()
