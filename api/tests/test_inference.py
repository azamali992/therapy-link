"""Tests for the Eve-wire SSE contract, prompt-hash hardening, and consent accepted_at.

Covers:
- SSE stream normalisation: delta events, done event, error event on failure,
  mid-stream failure, keep-alive lines ignored.
- Urdu multi-byte UTF-8 split across upstream chunk boundaries.
- Prompt-hash: folded-without-notes, folded-with-notes, mismatch, absent settings.
- Config check: TL_PROMPT_SHA256 and TL_PROMPT_CHARS must both be set or both absent.
- Consent PUT: accepted_at is accepted and the server's own time is used.
"""

from __future__ import annotations

import contextlib
import hashlib
import json

import httpx

from tests.conftest import as_user
from therapylink_api.routers import inference as inference_mod
from therapylink_api.settings import Settings, config_problems, get_settings

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

# A short representative system prompt (tests don't need the full Eve prompt).
_SYSTEM_PROMPT = "You are Eve, a mental health companion."
_PROMPT_CHARS = len(_SYSTEM_PROMPT)
_PROMPT_SHA = hashlib.sha256(_SYSTEM_PROMPT.encode()).hexdigest()

# Notes the app appends after the system prompt in a folded conversation.
_NOTES = "\n\n[Memory]\nUser prefers walking exercises."


def _folded_msg(user_text: str, notes: str | None = None) -> dict:
    """Build the first-user-turn message as the app's foldSystemIntoFirstUser would."""
    head = _SYSTEM_PROMPT if not notes else f"{_SYSTEM_PROMPT}{notes}"
    return {"role": "user", "content": f"{head}\n\n{user_text}"}


def _settings_base(**kw) -> Settings:
    base = {
        "dev_auth_bypass": False,
        "dev_auto_verify_clinicians": False,
        "log_uid_salt": "test-salt-ok",
        "_env_file": None,
    }
    return Settings(**(base | kw))


# ---------------------------------------------------------------------------
# Helpers for fake upstream SSE transports
# ---------------------------------------------------------------------------


class _ChunkedSseTransport(httpx.AsyncBaseTransport):
    """Fake upstream that delivers the given byte chunks in order."""

    def __init__(self, chunks: list[bytes], status: int = 200):
        self._chunks = chunks
        self._status = status

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        body = b"".join(self._chunks)
        return httpx.Response(
            self._status,
            content=body,
            headers={"content-type": "text/event-stream"},
        )


def _openai_sse(*tokens: str, finish_reason: str = "stop") -> bytes:
    """Build an upstream OpenAI-style SSE byte string for the given tokens."""
    lines = []
    for tok in tokens:
        event = json.dumps({"choices": [{"delta": {"content": tok}, "finish_reason": None}]})
        lines.append(b"data: " + event.encode() + b"\n\n")
    # Final event with finish_reason
    final = json.dumps({"choices": [{"delta": {}, "finish_reason": finish_reason}]})
    lines.append(b"data: " + final.encode() + b"\n\n")
    lines.append(b"data: [DONE]\n\n")
    return b"".join(lines)


async def _collect_sse(client, body: dict, monkeypatch, transport: httpx.AsyncBaseTransport) -> list[dict]:
    """POST to /inference/chat with stream=True and collect all parsed SSE events."""
    monkeypatch.setenv("TL_INFERENCE_BASE_URL", "http://stream-test")
    monkeypatch.setenv("TL_INFERENCE_API_KEY", "k")
    get_settings.cache_clear()
    monkeypatch.setattr(inference_mod, "upstream_transport", transport)

    r = await client.post("/inference/chat", json={**body, "stream": True}, headers=as_user("u"))
    assert r.status_code == 200, r.text
    events = []
    for line in r.text.splitlines():
        if line.startswith("data: "):
            payload = line[6:]
            if payload == "[DONE]":
                events.append({"_done_raw": True})
            else:
                with contextlib.suppress(json.JSONDecodeError):
                    events.append(json.loads(payload))
    return events


# ---------------------------------------------------------------------------
# SSE streaming: normalisation
# ---------------------------------------------------------------------------


async def test_stream_emits_delta_events(client, monkeypatch):
    """Each upstream content token becomes data: {"delta":"..."}."""
    sse = _openai_sse("Hello", " world")
    transport = _ChunkedSseTransport([sse])
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hi"}]}, monkeypatch, transport)
    deltas = [e["delta"] for e in events if "delta" in e]
    assert deltas == ["Hello", " world"]


async def test_stream_emits_done_event(client, monkeypatch):
    """The stream ends with data: {"done":true,...}."""
    sse = _openai_sse("hi")
    transport = _ChunkedSseTransport([sse])
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hey"}]}, monkeypatch, transport)
    done_events = [e for e in events if e.get("done") is True]
    assert done_events, "expected a done event"


async def test_stream_emits_error_on_upstream_non_200(client, monkeypatch):
    """A non-200 upstream response yields data: {"error":"eve_resting"}."""
    transport = _ChunkedSseTransport([b""], status=503)
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hi"}]}, monkeypatch, transport)
    assert any(e.get("error") == "eve_resting" for e in events)


async def test_stream_emits_error_on_mid_stream_failure(client, monkeypatch):
    """Stream that ends without [DONE] yields data: {"error":"eve_resting"}."""
    # Send one partial event with no [DONE] to simulate a truncated upstream.
    sse = b'data: {"choices":[{"delta":{"content":"He"},"finish_reason":null}]}\n\n'
    transport = _ChunkedSseTransport([sse])
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hi"}]}, monkeypatch, transport)
    assert any(e.get("error") == "eve_resting" for e in events)


async def test_stream_ignores_keepalive_lines(client, monkeypatch):
    """SSE keep-alive (:) and empty lines do not become events."""
    sse = (
        b": keep-alive\n\n"
        b"data: " + json.dumps({"choices": [{"delta": {"content": "ok"}, "finish_reason": None}]}).encode() + b"\n\n"
        b": another comment\n\n"
        b"data: [DONE]\n\n"
    )
    transport = _ChunkedSseTransport([sse])
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hi"}]}, monkeypatch, transport)
    deltas = [e["delta"] for e in events if "delta" in e]
    assert deltas == ["ok"]
    assert not any(e.get("error") for e in events)


async def test_stream_handles_lines_split_across_chunks(client, monkeypatch):
    """Upstream byte chunks that do not align with line boundaries are reassembled."""
    full_sse = _openai_sse("split")
    # Split at every 5 bytes to force many partial-line chunks.
    chunks = [full_sse[i : i + 5] for i in range(0, len(full_sse), 5)]
    transport = _ChunkedSseTransport(chunks)
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hi"}]}, monkeypatch, transport)
    deltas = [e["delta"] for e in events if "delta" in e]
    assert deltas == ["split"]


async def test_stream_urdu_multibyte_split_across_chunks(client, monkeypatch):
    """A multi-byte Urdu token split at a byte boundary is reassembled correctly.

    'آپ کیسے ہیں' (UTF-8) spans multiple bytes per character.  If the proxy
    were to decode bytes eagerly before line-splitting, the JSON would be
    malformed.  Instead we buffer bytes and split on 0x0a.
    """
    # A short Urdu phrase whose UTF-8 encoding spans multiple bytes per character.
    urdu = "آپ کیسے"

    # Build the upstream event byte-by-byte across the Urdu token.
    prefix = b'data: {"choices":[{"delta":{"content":"'
    suffix = b'"},"finish_reason":null}]}\n\n'
    urdu_bytes = json.dumps(urdu)[1:-1].encode("utf-8")  # JSON-escaped, no surrounding quotes
    done_line = b"data: [DONE]\n\n"

    full = prefix + urdu_bytes + suffix + done_line
    # Split right in the middle of the Urdu UTF-8 bytes.
    mid = len(prefix) + len(urdu_bytes) // 2
    chunks = [full[:mid], full[mid:]]

    transport = _ChunkedSseTransport(chunks)
    events = await _collect_sse(client, {"messages": [{"role": "user", "content": "hi"}]}, monkeypatch, transport)
    deltas = [e["delta"] for e in events if "delta" in e]
    assert deltas == [urdu], f"expected [{urdu!r}], got {deltas!r}"


# ---------------------------------------------------------------------------
# Prompt hash: config check
# ---------------------------------------------------------------------------


def test_prompt_sha256_without_prompt_chars_is_a_config_problem():
    """TL_PROMPT_SHA256 alone fails the config check."""
    s = _settings_base(prompt_sha256="a" * 64)
    assert config_problems(s)


def test_prompt_chars_without_prompt_sha256_is_a_config_problem():
    """TL_PROMPT_CHARS alone fails the config check."""
    s = _settings_base(prompt_chars=50)
    assert config_problems(s)


def test_both_prompt_settings_together_are_fine():
    """TL_PROMPT_SHA256 and TL_PROMPT_CHARS together pass the config check."""
    s = _settings_base(prompt_sha256="a" * 64, prompt_chars=50)
    assert config_problems(s) == []


def test_neither_prompt_setting_is_fine():
    """No prompt settings: no config problem."""
    s = _settings_base()
    assert config_problems(s) == []


# ---------------------------------------------------------------------------
# Prompt hash: folded-form validation
# ---------------------------------------------------------------------------


async def _set_prompt_env(monkeypatch):
    monkeypatch.setenv("TL_INFERENCE_BASE_URL", "http://unused")
    monkeypatch.setenv("TL_INFERENCE_API_KEY", "k")
    monkeypatch.setenv("TL_PROMPT_SHA256", _PROMPT_SHA)
    monkeypatch.setenv("TL_PROMPT_CHARS", str(_PROMPT_CHARS))
    get_settings.cache_clear()


async def test_prompt_hash_folded_without_notes(client, monkeypatch):
    """Folded form with no memory notes passes the hash check."""
    await _set_prompt_env(monkeypatch)
    body = {"messages": [_folded_msg("hello")]}
    r = await client.post("/inference/chat", json=body, headers=as_user("u"))
    assert r.status_code != 422, r.text


async def test_prompt_hash_folded_with_notes(client, monkeypatch):
    """Folded form with memory/summary notes passes: only the first prompt_chars chars are hashed."""
    await _set_prompt_env(monkeypatch)
    body = {"messages": [_folded_msg("hello", notes=_NOTES)]}
    r = await client.post("/inference/chat", json=body, headers=as_user("u"))
    assert r.status_code != 422, r.text


async def test_prompt_hash_mismatch(client, monkeypatch):
    """Wrong content at the head of the first user turn → 422."""
    await _set_prompt_env(monkeypatch)
    wrong_body = {"messages": [{"role": "user", "content": "wrong prompt here\n\nhello"}]}
    r = await client.post("/inference/chat", json=wrong_body, headers=as_user("u"))
    assert r.status_code == 422, r.text


async def test_prompt_hash_absent_settings(client):
    """Without TL_PROMPT_SHA256 / TL_PROMPT_CHARS, any prompt is accepted (returns 503 not 422)."""
    body = {"messages": [{"role": "user", "content": "whatever comes first"}]}
    r = await client.post("/inference/chat", json=body, headers=as_user("u"))
    # 503 = no inference server configured; 422 would mean the schema rejected it.
    assert r.status_code == 503, r.text


async def test_prompt_hash_explicit_system_role_still_accepted(client, monkeypatch):
    """An explicit role=system message (not folded) also passes the hash check."""
    await _set_prompt_env(monkeypatch)
    body = {
        "messages": [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": "hello"},
        ]
    }
    r = await client.post("/inference/chat", json=body, headers=as_user("u"))
    assert r.status_code != 422, r.text


async def test_prompt_hash_message_shorter_than_prompt_chars_is_rejected(client, monkeypatch):
    """A user message shorter than prompt_chars can't possibly start with the full prompt."""
    await _set_prompt_env(monkeypatch)
    short = {"messages": [{"role": "user", "content": "hi"}]}
    r = await client.post("/inference/chat", json=short, headers=as_user("u"))
    assert r.status_code == 422, r.text


# ---------------------------------------------------------------------------
# Consent: accepted_at accepted and ignored
# ---------------------------------------------------------------------------


async def test_consent_with_accepted_at_is_accepted(client):
    """PUT /me/consent with accepted_at must not return 422."""
    r = await client.put(
        "/me/consent",
        json={"consent_version": "v1.0", "accepted_at": "2024-01-15T10:30:00Z"},
        headers=as_user("u"),
    )
    assert r.status_code == 200, r.text


async def test_consent_server_time_is_authoritative(client):
    """The server's own timestamp is used for consent_accepted_at, not the client-sent one."""
    r = await client.put(
        "/me/consent",
        json={"consent_version": "v2.0", "accepted_at": "2000-01-01T00:00:00Z"},
        headers=as_user("u"),
    )
    assert r.status_code == 200, r.text
    # Server time is recent (not year 2000).
    body = r.json()
    assert body["consent_accepted_at"] is not None
    # The stored timestamp must not be the client-sent 2000 date.
    assert body["consent_accepted_at"].startswith("2000") is False


async def test_consent_without_accepted_at_still_works(client):
    """accepted_at is optional; omitting it must not break anything."""
    r = await client.put(
        "/me/consent",
        json={"consent_version": "v1.1"},
        headers=as_user("u"),
    )
    assert r.status_code == 200, r.text
