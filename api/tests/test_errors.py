import logging

import httpx
import pytest

from tests.conftest import as_user
from therapylink_api import auth
from therapylink_api.routers import inference
from therapylink_api.settings import get_settings

SECRET = "gpu-box.internal:8080"


async def test_every_response_carries_a_request_id(client):
    a = (await client.get("/health")).headers["x-request-id"]
    b = (await client.get("/health")).headers["x-request-id"]
    assert a and b and a != b


async def test_bad_token_gets_a_generic_401_and_a_logged_reason(client, monkeypatch, caplog):
    def reject(token: str) -> dict:
        raise ValueError(f"Token used too early; issuer {SECRET}")

    monkeypatch.setattr(auth, "_verify", reject)
    with caplog.at_level(logging.WARNING, logger="therapylink_api.auth"):
        r = await client.get("/me", headers={"Authorization": "Bearer not-a-real-token"})
    assert r.status_code == 401 and r.json() == {"detail": "invalid token"}
    rid = r.headers["x-request-id"]
    assert any(SECRET in m and rid in m for m in caplog.messages)


def _cloud_inference(monkeypatch, handler) -> None:
    monkeypatch.setenv("TL_INFERENCE_BASE_URL", f"http://{SECRET}")
    monkeypatch.setenv("TL_INFERENCE_API_KEY", "k")
    get_settings.cache_clear()
    monkeypatch.setattr(inference, "upstream_transport", httpx.MockTransport(handler))


@pytest.mark.parametrize(
    ("error", "status"),
    [
        (httpx.ConnectError(f"All connection attempts failed: http://{SECRET}/v1/chat/completions"), 502),
        (httpx.ReadTimeout(f"timed out reading from {SECRET}"), 504),
    ],
)
async def test_upstream_failures_hide_the_upstream(client, monkeypatch, caplog, error, status):
    def fail(request: httpx.Request) -> httpx.Response:
        raise error

    _cloud_inference(monkeypatch, fail)
    body = {"messages": [{"role": "user", "content": "hi"}]}
    with caplog.at_level(logging.WARNING, logger="therapylink_api.routers.inference"):
        r = await client.post("/inference/chat", json=body, headers=as_user("u"))
    assert r.status_code == status
    assert SECRET not in r.text and "http" not in r.json()["detail"]
    assert any(SECRET in m and r.headers["x-request-id"] in m for m in caplog.messages)


async def test_unreadable_upstream_reply_is_a_generic_502(client, monkeypatch):
    _cloud_inference(monkeypatch, lambda request: httpx.Response(200, text=f"<html>{SECRET}</html>"))
    r = await client.post(
        "/inference/chat", json={"messages": [{"role": "user", "content": "hi"}]}, headers=as_user("u")
    )
    assert r.status_code == 502 and SECRET not in r.text


async def test_a_good_upstream_reply_passes_through_with_the_key(client, monkeypatch):
    seen: list[httpx.Request] = []

    def ok(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json={"model": "eve", "choices": [{"message": {"content": " hello "}}]})

    _cloud_inference(monkeypatch, ok)
    r = await client.post(
        "/inference/chat", json={"messages": [{"role": "user", "content": "hi"}]}, headers=as_user("u")
    )
    assert r.status_code == 200 and r.json() == {"reply": "hello", "model": "eve"}
    assert seen[0].headers["authorization"] == "Bearer k"
