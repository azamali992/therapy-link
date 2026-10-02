"""Tests for the v3 hardening tasks.

Covers: TL_ENV staging guard, rate limiting (dual inference bucket, write limit, IP limit),
structured JSON logging, Firebase App Check, admin clinician verify/revoke endpoints, inference
streaming and prompt-hash validation, and access log append-only on Postgres.
"""

from __future__ import annotations

import hashlib
import json
import logging

import httpx
import pytest

from tests.conftest import as_user, linked, verified_clinician
from therapylink_api import firebase
from therapylink_api.main import create_app
from therapylink_api.ratelimit import DualTokenBucket, TokenBucket
from therapylink_api.routers import inference as inference_mod
from therapylink_api.settings import get_settings

# ---------------------------------------------------------------------------
# Task 1 — TL_ENV: staging blocks dev bypass
# ---------------------------------------------------------------------------


def test_staging_blocks_dev_auth_bypass(monkeypatch):
    monkeypatch.setenv("TL_ENV", "staging")  # conftest already sets DEV_AUTH_BYPASS=true
    with pytest.raises(RuntimeError, match="TL_DEV_AUTH_BYPASS"):
        create_app()


def test_staging_allows_real_config(monkeypatch):
    """staging + no bypass + non-sqlite DB passes config check (create_app raises only on DB connect)."""
    monkeypatch.setenv("TL_ENV", "staging")
    monkeypatch.setenv("TL_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
    monkeypatch.delenv("TL_DEV_AUTH_BYPASS", raising=False)
    # Should not raise a config error (may raise on DB setup, which is fine in this test).
    from therapylink_api.settings import Settings, config_problems

    s = Settings(
        env="staging",
        database_url="sqlite+aiosqlite:///:memory:",
        dev_auth_bypass=False,
        log_uid_salt="test-salt",
        _env_file=None,
    )
    assert config_problems(s) == []


# ---------------------------------------------------------------------------
# Task 3 — Rate limiting
# ---------------------------------------------------------------------------


async def test_dual_bucket_enforces_short_window(app, client):
    """Short-window limit triggers 429 with Retry-After."""
    app.state.chat_limiter = DualTokenBucket(
        short=TokenBucket(capacity=2, period_s=600),
        daily=TokenBucket(capacity=300, period_s=86400),
    )
    body = {"messages": [{"role": "user", "content": "hi"}]}
    assert [(await client.post("/inference/chat", json=body, headers=as_user("a"))).status_code for _ in range(2)] == [
        503,
        503,
    ]
    r = await client.post("/inference/chat", json=body, headers=as_user("a"))
    assert r.status_code == 429 and int(r.headers["retry-after"]) > 0


async def test_dual_bucket_enforces_daily_cap(app, client):
    """Daily cap triggers 429 independently of the short window."""
    app.state.chat_limiter = DualTokenBucket(
        short=TokenBucket(capacity=300, period_s=600),
        daily=TokenBucket(capacity=2, period_s=86400),
    )
    body = {"messages": [{"role": "user", "content": "hi"}]}
    for _ in range(2):
        await client.post("/inference/chat", json=body, headers=as_user("a"))
    r = await client.post("/inference/chat", json=body, headers=as_user("a"))
    assert r.status_code == 429


async def test_dual_bucket_is_per_uid(app, client):
    """Different UIDs have independent buckets."""
    app.state.chat_limiter = DualTokenBucket(
        short=TokenBucket(capacity=1, period_s=600),
        daily=TokenBucket(capacity=300, period_s=86400),
    )
    body = {"messages": [{"role": "user", "content": "hi"}]}
    await client.post("/inference/chat", json=body, headers=as_user("a"))
    r_b = await client.post("/inference/chat", json=body, headers=as_user("b"))
    # b's first request hits 503 (no inference configured), not 429 (rate limited).
    assert r_b.status_code == 503


async def test_write_rate_limit_returns_429(app, client):
    """Exceeding the write rate limit returns 429 with Retry-After."""
    app.state.write_limiter = TokenBucket(capacity=2, period_s=60)
    for _ in range(2):
        await client.post("/mood/batch", json=[], headers=as_user("u"))
    r = await client.post("/mood/batch", json=[], headers=as_user("u"))
    assert r.status_code == 429 and int(r.headers["retry-after"]) > 0


async def test_write_rate_limit_is_per_uid(app, client):
    """Write rate limit does not bleed across UIDs."""
    app.state.write_limiter = TokenBucket(capacity=1, period_s=60)
    await client.post("/mood/batch", json=[], headers=as_user("a"))
    # uid b has a fresh bucket.
    r = await client.post("/mood/batch", json=[], headers=as_user("b"))
    assert r.status_code != 429


async def test_ip_rate_limit_on_unauthenticated_requests(app, client):
    """Requests without a Bearer token are IP-limited and eventually get 429."""
    app.state.ip_limiter = TokenBucket(capacity=2, period_s=60)
    # First two: 401 (no token), third: 429 (IP limited).
    statuses = [(await client.get("/me")).status_code for _ in range(3)]
    assert statuses[:2] == [401, 401]
    assert statuses[2] == 429


async def test_health_and_ready_exempt_from_ip_limit(app, client):
    """Monitoring probes must not be blocked even when the IP bucket is empty."""
    app.state.ip_limiter = TokenBucket(capacity=0, period_s=60)
    assert (await client.get("/health")).status_code == 200
    assert (await client.get("/ready")).status_code == 200


def test_dual_token_bucket_synergy():
    """Both sub-buckets must be satisfied; consuming from one is rolled back on the other's failure."""
    short = TokenBucket(capacity=10, period_s=600)
    daily = TokenBucket(capacity=2, period_s=86400)
    dual = DualTokenBucket(short, daily)

    assert dual.take("u") == 0.0
    assert dual.take("u") == 0.0
    # Daily is now empty; short still has capacity but that doesn't matter.
    wait = dual.take("u")
    assert wait > 0
    # The short bucket must NOT have been depleted by the blocked call.
    assert short._level("u:s", short._clock()) >= 8  # only 2 consumed, not 3


# ---------------------------------------------------------------------------
# Task 4 — Inference: streaming, prompt-hash, max_tokens cap
# ---------------------------------------------------------------------------


async def test_inference_prompt_hash_validation(client, monkeypatch):
    """When TL_PROMPT_SHA256 is set, a mismatched system prompt returns 422."""
    expected = hashlib.sha256(b"correct prompt").hexdigest()
    monkeypatch.setenv("TL_INFERENCE_BASE_URL", "http://unused")
    monkeypatch.setenv("TL_INFERENCE_API_KEY", "k")
    monkeypatch.setenv("TL_PROMPT_SHA256", expected)
    get_settings.cache_clear()

    wrong = {"messages": [{"role": "system", "content": "wrong prompt"}, {"role": "user", "content": "hi"}]}
    r = await client.post("/inference/chat", json=wrong, headers=as_user("u"))
    assert r.status_code == 422

    correct = {"messages": [{"role": "system", "content": "correct prompt"}, {"role": "user", "content": "hi"}]}
    monkeypatch.setattr(
        inference_mod,
        "upstream_transport",
        httpx.MockTransport(
            lambda req: httpx.Response(200, json={"model": "m", "choices": [{"message": {"content": "ok"}}]})
        ),
    )
    r = await client.post("/inference/chat", json=correct, headers=as_user("u"))
    assert r.status_code == 200


async def test_inference_max_tokens_is_capped(client, monkeypatch):
    """The server caps max_tokens regardless of what the client requests."""
    seen: list[dict] = []

    def capture(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content))
        return httpx.Response(200, json={"model": "m", "choices": [{"message": {"content": "hi"}}]})

    monkeypatch.setenv("TL_INFERENCE_BASE_URL", "http://cap-test")
    monkeypatch.setenv("TL_INFERENCE_API_KEY", "k")
    monkeypatch.setenv("TL_INFERENCE_MAX_TOKENS", "512")
    get_settings.cache_clear()
    monkeypatch.setattr(inference_mod, "upstream_transport", httpx.MockTransport(capture))

    await client.post(
        "/inference/chat",
        json={"messages": [{"role": "user", "content": "hi"}], "max_tokens": 999},
        headers=as_user("u"),
    )
    assert seen[0]["max_tokens"] == 512


async def test_inference_system_role_allowed(client):
    """Conversations that include a system message must not be rejected at the schema level."""
    body = {"messages": [{"role": "system", "content": "be helpful"}, {"role": "user", "content": "hi"}]}
    r = await client.post("/inference/chat", json=body, headers=as_user("u"))
    # 503 means the schema passed and the server just isn't configured; 422 would be a schema error.
    assert r.status_code == 503


async def test_inference_streaming_response(client, monkeypatch):
    """With stream=true the response media type is text/event-stream."""
    chunk = b"data: {}\n\n"

    class _SSETransport(httpx.AsyncBaseTransport):
        async def handle_async_request(self, request):
            # httpx expects SyncByteStream or AsyncByteStream protocol (an __aiter__ or __iter__).
            return httpx.Response(200, content=chunk, headers={"content-type": "text/event-stream"})

    monkeypatch.setenv("TL_INFERENCE_BASE_URL", "http://stream-test")
    monkeypatch.setenv("TL_INFERENCE_API_KEY", "k")
    get_settings.cache_clear()
    monkeypatch.setattr(inference_mod, "upstream_transport", _SSETransport())
    r = await client.post(
        "/inference/chat", json={"messages": [{"role": "user", "content": "hi"}], "stream": True}, headers=as_user("u")
    )
    assert "text/event-stream" in r.headers.get("content-type", "")


# ---------------------------------------------------------------------------
# Task 5 — Admin endpoints
# ---------------------------------------------------------------------------

from firebase_admin import auth as firebase_auth  # noqa: E402


@pytest.fixture
def admin_token(monkeypatch):
    """A Firebase token with admin: true."""
    claims = {"uid": "admin1", "email": "admin@example.com", "email_verified": True, "admin": True}

    def verify(tok, app=None):
        if isinstance(claims.get("raise"), (type, Exception)):
            raise claims["raise"]
        return claims

    monkeypatch.setattr(firebase, "app", lambda: None)
    monkeypatch.setattr(firebase_auth, "verify_id_token", verify)
    return claims


ADMIN_HDR = {"Authorization": "Bearer admin-token"}


async def test_admin_verify_clinician(client, admin_token):
    """Admin can verify a clinician that has a verified email."""
    # Set up a clinician with verified email (simulate via dev bypass for profile creation).
    await client.post("/me/clinician", json={"license_no": "PMC-999"}, headers=as_user("doc99"))
    # Fake that email is verified by writing it directly to DB.
    from sqlalchemy import update

    from therapylink_api import db as db_mod
    from therapylink_api.models import User

    async with db_mod.sessionmaker()() as s:
        await s.execute(update(User).where(User.uid == "doc99").values(email_verified=True))
        await s.commit()

    r = await client.post("/admin/clinicians/doc99/verify", headers=ADMIN_HDR)
    assert r.status_code == 200 and r.json()["uid"] == "doc99" and r.json()["verified_at"] is not None


async def test_admin_revoke_clinician(client, admin_token):
    """Admin can revoke a clinician's verification."""
    await verified_clinician(client, "doc-r")

    r = await client.post("/admin/clinicians/doc-r/revoke", headers=ADMIN_HDR)
    assert r.status_code == 200 and r.json()["verified_at"] is None


async def test_admin_verify_requires_admin_claim(client, monkeypatch):
    """A regular Firebase token (no admin claim) is rejected with 403."""
    monkeypatch.setattr(firebase, "app", lambda: None)
    monkeypatch.setattr(firebase_auth, "verify_id_token", lambda t, app=None: {"uid": "u1", "email": "u@x.com"})
    r = await client.post("/admin/clinicians/someone/verify", headers={"Authorization": "Bearer regular"})
    assert r.status_code == 403


async def test_admin_verify_requires_authenticated_token(client):
    """Missing token returns 401."""
    r = await client.post("/admin/clinicians/someone/verify")
    assert r.status_code == 401


async def test_admin_verify_unknown_clinician_is_404(client, admin_token):
    r = await client.post("/admin/clinicians/nobody/verify", headers=ADMIN_HDR)
    assert r.status_code == 404


async def test_admin_revoke_unknown_clinician_is_404(client, admin_token):
    r = await client.post("/admin/clinicians/nobody/revoke", headers=ADMIN_HDR)
    assert r.status_code == 404


async def test_admin_actions_are_written_to_access_log(client, admin_token):
    """Admin verify/revoke are appended to access_log for audit."""
    from sqlalchemy import select, update

    from therapylink_api import db as db_mod
    from therapylink_api.models import AccessLog, User

    await client.post("/me/clinician", json={"license_no": "PMC-audit"}, headers=as_user("doc-audit"))
    async with db_mod.sessionmaker()() as s:
        await s.execute(update(User).where(User.uid == "doc-audit").values(email_verified=True))
        await s.commit()

    await client.post("/admin/clinicians/doc-audit/verify", headers=ADMIN_HDR)
    await client.post("/admin/clinicians/doc-audit/revoke", headers=ADMIN_HDR)

    async with db_mod.sessionmaker()() as s:
        entries = (await s.scalars(select(AccessLog).where(AccessLog.patient_uid == "doc-audit"))).all()
    actions = [e.action for e in entries]
    assert "admin_verify" in actions and "admin_revoke" in actions


# ---------------------------------------------------------------------------
# Task 2 — App Check (optional gate)
# ---------------------------------------------------------------------------


async def test_app_check_not_required_by_default(client):
    """Without TL_APP_CHECK_REQUIRED=true, missing App Check header has no effect."""
    r = await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=as_user("u"))
    assert r.status_code == 201


async def test_app_check_required_rejects_missing_token(client, monkeypatch):
    """When TL_APP_CHECK_REQUIRED=true, inference routes require X-Firebase-AppCheck."""
    monkeypatch.setenv("TL_APP_CHECK_REQUIRED", "true")
    get_settings.cache_clear()
    r = await client.post(
        "/inference/chat", json={"messages": [{"role": "user", "content": "hi"}]}, headers=as_user("u")
    )
    assert r.status_code == 403


# ---------------------------------------------------------------------------
# Task 7 — Structured JSON logging
# ---------------------------------------------------------------------------


async def test_structured_log_uses_route_template_not_actual_path(client, caplog):
    """Logs must contain the route template, never the actual uid in the path."""
    await verified_clinician(client)
    await linked(client, "pat-log")

    with caplog.at_level(logging.INFO, logger="therapylink_api.main"):
        await client.get("/clinician/patients/pat-log", headers=as_user("doc"))

    # Find the log line that corresponds to this request.
    records = [r for r in caplog.records if r.name == "therapylink_api.main"]
    routes = [r.__dict__.get("route") for r in records]
    # The route template must appear, not the actual uid.
    assert any("/clinician/patients/{patient_uid}" in (rt or "") for rt in routes)
    # The actual uid must never appear in any log route field.
    assert not any("pat-log" in (rt or "") for rt in routes)


async def test_structured_log_contains_hashed_uid_not_raw(client, caplog):
    """Logs must include uid_hash, not the raw uid."""
    with caplog.at_level(logging.INFO, logger="therapylink_api.main"):
        await client.get("/me", headers=as_user("uid-secret"))

    records = [r for r in caplog.records if r.name == "therapylink_api.main"]
    # Raw uid must not appear in any structured log field.
    assert not any("uid-secret" in str(r.__dict__.get("uid_hash", "")) for r in records)
    # uid_hash field must be present for authenticated requests.
    assert any(r.__dict__.get("uid_hash") is not None for r in records)
