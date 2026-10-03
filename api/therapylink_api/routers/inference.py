"""Cloud inference proxy for the Eve model.

Forwards to an OpenAI-compatible llama-server.  Supports both streaming (SSE) and
non-streaming responses.  Never logs message bodies or the system prompt.

## Eve-wire SSE contract (stream=true)

The upstream llama-server speaks the OpenAI SSE format
(``data: {"choices":[{"delta":{"content":"..."}}]}`` … ``data: [DONE]``).
This proxy normalises that into the TherapyLink wire format so clients need not
depend on the upstream shape:

  ``data: {"delta":"<text>"}``
      One text piece from Eve's reply.

  ``data: {"done":true,"finish_reason":"<reason>"}``
      Normal end of stream. ``finish_reason`` is ``"stop"`` or the value the
      upstream reported.

  ``data: [DONE]``
      Alternative normal-end marker accepted by the client but never emitted
      here; reserved for future use.

  ``: wait``
      SSE keep-alive comment emitted every ~10 s while waiting for the first
      upstream token (or after a gap of >10 s mid-stream).  Clients must treat
      this as a no-op: it prevents idle-timeout disconnections on slow CPU
      inference (5–8 tok/s, first-token latency 10–25 s).

  ``data: {"error":"eve_resting"}``
      Upstream connect failure, timeout, non-200 status, or stream that ended
      without a terminal event. The client must NOT retry automatically; show
      the calm "Eve is resting" message instead.

  ``data: {"error":"eve_busy"}``
      All inference slots are in use. The client must NOT retry automatically
      within the Retry-After window; show the calm "Eve is with someone else"
      message instead.  The rate-limit token is NOT spent on a busy rejection.

Handling guarantees:
- Upstream byte chunks split across line boundaries are assembled before
  parsing (byte-level line buffer).
- SSE keep-alive lines (empty or starting with ``:`` ) are silently dropped.
- Message content is never logged, even on error.

Rate limits are enforced per uid before the upstream call.
"""

from __future__ import annotations

import asyncio
import contextlib
import hashlib
import json as _json
import logging
import math

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse

from therapylink_api import requestid
from therapylink_api.auth import Principal, _verify_app_check, current_principal
from therapylink_api.ratelimit import atake
from therapylink_api.schemas import ChatIn, ChatOut
from therapylink_api.settings import Settings, get_settings

log = logging.getLogger(__name__)
router = APIRouter(prefix="/inference", tags=["inference"])
# Tests swap in an httpx.MockTransport; None is the real network.
upstream_transport: httpx.AsyncBaseTransport | None = None

_EVE_DOWN_DETAIL = "Eve is resting right now. Please try again in a moment."

# How often to emit an SSE keep-alive comment while waiting for the first upstream
# token (and during mid-stream gaps longer than this interval).  Must be shorter
# than the client's idle timeout (currently 45 s) so the connection stays alive
# during slow CPU inference where the first token can take 10–25 s.
_KEEPALIVE_INTERVAL_S = 10

# Retry-After suggested to clients on a busy rejection, in seconds.
_BUSY_RETRY_AFTER_S = 30


# ---------------------------------------------------------------------------
# In-process inference concurrency limiter
# ---------------------------------------------------------------------------


class _InferenceBusy(Exception):
    """Raised by _InferenceTracker.acquire() when the queue is full."""


class _InferenceTracker:
    """Limits concurrent upstream inference requests.

    Prevents retry storms: when all slots are busy the caller receives
    ``{"error":"eve_busy"}`` immediately, without spending a rate-limit token.

    Attributes
    ----------
    max_inflight:
        Maximum number of requests simultaneously forwarded upstream.
    max_queue:
        Maximum total (inflight + waiting for a slot).  When this is reached,
        new requests are rejected with 503 rather than queued.
    """

    def __init__(self, max_inflight: int, max_queue: int) -> None:
        self._sem = asyncio.Semaphore(max_inflight)
        self._max_queue = max_queue
        self._count = 0  # inflight + waiting

    @property
    def is_full(self) -> bool:
        return self._count >= self._max_queue

    @contextlib.asynccontextmanager
    async def acquire(self):
        """Acquire a slot. Raises _InferenceBusy if the queue is full."""
        if self._count >= self._max_queue:
            raise _InferenceBusy()
        self._count += 1
        try:
            async with self._sem:
                yield
        finally:
            self._count -= 1


# ---------------------------------------------------------------------------
# Busy response helpers
# ---------------------------------------------------------------------------


def _busy_response(body: ChatIn) -> StreamingResponse | JSONResponse:
    """Return the appropriate busy response for streaming or non-streaming."""
    headers = {"Retry-After": str(_BUSY_RETRY_AFTER_S)}
    if body.stream:
        # HTTP 200 so the client can read the SSE event (a 503 would be swallowed
        # before the body is decoded).
        async def _gen():
            yield b'data: {"error":"eve_busy"}\n\n'

        return StreamingResponse(_gen(), media_type="text/event-stream", headers=headers)
    return JSONResponse({"error": "eve_busy"}, status_code=503, headers=headers)


# ---------------------------------------------------------------------------
# Auth-only dependency (no rate limit — busy check runs before rate limit)
# ---------------------------------------------------------------------------


async def _auth_only(request: Request, p: Principal = Depends(current_principal)) -> Principal:
    """App Check verification only.  Rate limiting is handled inside the route
    handler, after the busy check, so a busy rejection never spends a token."""
    await _verify_app_check(request)
    return p


# ---------------------------------------------------------------------------
# Prompt hash allowlist
# ---------------------------------------------------------------------------


def _build_prompt_allowlist(s: Settings) -> list[tuple[str, int]]:
    """Collect all registered (sha256, chars) pairs from settings.

    Combines TL_PROMPT_SHA256S (multi-hash) and the legacy TL_PROMPT_SHA256 /
    TL_PROMPT_CHARS pair, so operators can register the Eve system prompt and
    all instruction prompts (summary, memory) without breaking backwards compat.
    """
    entries: list[tuple[str, int]] = []
    if s.prompt_sha256s:
        for raw in s.prompt_sha256s.split(","):
            raw = raw.strip()
            if not raw:
                continue
            parts = raw.split(":")
            if len(parts) == 2:
                with contextlib.suppress(ValueError):
                    entries.append((parts[0].strip().lower(), int(parts[1].strip())))
    if s.prompt_sha256 and s.prompt_chars:
        entries.append((s.prompt_sha256.lower(), s.prompt_chars))
    return entries


def _validate_prompt_hash(body: ChatIn, allowlist: list[tuple[str, int]]) -> None:
    """Check that the first user/system message starts with a registered prompt.

    If ``allowlist`` is empty, no check is performed (backwards-compatible with
    deployments that have not set TL_PROMPT_SHA256 / TL_PROMPT_SHA256S).

    The first ``chars`` characters of the message must hash to the registered
    SHA-256.  A message shorter than ``chars`` cannot match; it is skipped for
    that entry.  If no entry matches, 422 is returned.

    The app folds the system prompt into the first user turn, so both
    ``role=user`` (folded) and ``role=system`` (explicit) are accepted.
    """
    if not allowlist:
        return
    first = next((m for m in body.messages if m.role in ("system", "user")), None)
    if first is None:
        raise HTTPException(422, "prompt check failed: no user or system message")
    for expected_sha256, prompt_chars in allowlist:
        if len(first.content) >= prompt_chars:
            actual = hashlib.sha256(first.content[:prompt_chars].encode()).hexdigest()
            if actual == expected_sha256:
                return  # a registered prompt matched
    raise HTTPException(422, "system prompt does not match any registered hash")


# ---------------------------------------------------------------------------
# Route
# ---------------------------------------------------------------------------


@router.post("/chat", response_model=ChatOut)
async def chat(body: ChatIn, request: Request, p: Principal = Depends(_auth_only)):
    """Cloud path: forwards to an OpenAI-compatible llama-server.  On-device inference never hits this."""
    s = get_settings()

    # --- Busy check BEFORE spending the rate-limit token ---
    # asyncio is single-threaded so there is no race between is_full and the
    # rate-limit await: if the tracker is full right now we return immediately
    # without consuming any of the uid's rate-limit budget.
    tracker: _InferenceTracker | None = getattr(request.app.state, "inference_tracker", None)
    if tracker is not None and tracker.is_full:
        return _busy_response(body)

    # Spend the per-uid rate-limit token (always, even when no upstream is configured,
    # to match the original behaviour that tests rely on).
    wait = await atake(request.app.state.chat_limiter, p.uid)
    if wait:
        raise HTTPException(429, "too many messages, try again shortly", headers={"Retry-After": str(math.ceil(wait))})

    # No upstream configured → 503 after spending the token (legitimate request,
    # just no model server running).
    if not s.inference_base_url:
        raise HTTPException(503, _EVE_DOWN_DETAIL)

    _validate_prompt_hash(body, _build_prompt_allowlist(s))

    headers = {"Authorization": f"Bearer {s.inference_api_key}"} if s.inference_api_key else {}
    # Cap max_tokens to the server's configured limit regardless of what the client requests.
    capped_max_tokens = min(body.max_tokens, s.inference_max_tokens)
    payload = {
        "model": s.inference_model,
        "messages": [m.model_dump() for m in body.messages],
        "max_tokens": capped_max_tokens,
        "temperature": body.temperature,
        "stream": body.stream,
    }
    rid = requestid.current()

    if body.stream:
        return await _stream_response(s.inference_base_url, tracker, payload, headers, rid)

    return await _non_stream_response(s, tracker, payload, headers, rid)


# ---------------------------------------------------------------------------
# Non-streaming path
# ---------------------------------------------------------------------------


async def _non_stream_response(s, tracker, payload: dict, headers: dict, rid: str) -> ChatOut | JSONResponse:
    acquired = tracker.acquire() if tracker is not None else contextlib.nullcontext()
    try:
        async with acquired:
            async with httpx.AsyncClient(
                base_url=s.inference_base_url, timeout=120, transport=upstream_transport
            ) as client:
                try:
                    r = await client.post("/v1/chat/completions", json=payload, headers=headers)
                    r.raise_for_status()
                except httpx.ConnectError as e:
                    log.warning("inference upstream unreachable [request %s]: %s", rid, e)
                    raise HTTPException(502, _EVE_DOWN_DETAIL) from None
                except httpx.ReadTimeout as e:
                    log.warning("inference upstream timed out [request %s]: %s", rid, e)
                    raise HTTPException(504, _EVE_DOWN_DETAIL) from None
                except httpx.HTTPStatusError as e:
                    log.warning("inference upstream returned HTTP %s [request %s]: %s", e.response.status_code, rid, e)
                    raise HTTPException(502, _EVE_DOWN_DETAIL) from None
                except httpx.HTTPError as e:
                    log.warning("inference upstream error [request %s]: %s", rid, e)
                    raise HTTPException(502, _EVE_DOWN_DETAIL) from None

            try:
                data = r.json()
                usage = data.get("usage", {})
                log.info(
                    "inference ok [request %s] prompt_tokens=%s completion_tokens=%s model=%s",
                    rid,
                    usage.get("prompt_tokens"),
                    usage.get("completion_tokens"),
                    data.get("model", s.inference_model),
                )
                return ChatOut(
                    reply=data["choices"][0]["message"]["content"].strip(),
                    model=data.get("model", s.inference_model),
                )
            except (KeyError, ValueError, TypeError):
                log.warning("inference upstream bad reply [request %s]", rid)
                raise HTTPException(502, _EVE_DOWN_DETAIL) from None
    except _InferenceBusy:
        log.info("inference busy [request %s]", rid)
        return JSONResponse(
            {"error": "eve_busy"},
            status_code=503,
            headers={"Retry-After": str(_BUSY_RETRY_AFTER_S)},
        )


# ---------------------------------------------------------------------------
# Streaming path
# ---------------------------------------------------------------------------


async def _keepalive_iter(aiter, interval: float):
    """Wrap an async byte iterator, yielding ``None`` as a keep-alive tick every
    *interval* seconds when no data has arrived.  The underlying iterator is not
    cancelled on a tick; asyncio.wait() leaves it running so the connection stays open."""
    task: asyncio.Task = asyncio.ensure_future(aiter.__anext__())
    try:
        while True:
            done, _ = await asyncio.wait({task}, timeout=interval)
            if done:
                try:
                    yield task.result()
                except StopAsyncIteration:
                    return
                task = asyncio.ensure_future(aiter.__anext__())
            else:
                yield None  # keep-alive tick
    finally:
        task.cancel()
        # Drain the cancellation so the task is fully cleaned up.
        with contextlib.suppress(asyncio.CancelledError, StopAsyncIteration, Exception):
            await task


async def _stream_response(
    base_url: str,
    tracker: _InferenceTracker | None,
    payload: dict,
    headers: dict,
    rid: str,
) -> StreamingResponse:
    """Normalise the upstream OpenAI SSE stream into the TherapyLink wire format.

    Emits ``: wait`` keep-alive comments every ~10 s while waiting for the first
    upstream token (or during mid-stream gaps), so the client's 45-second idle
    timeout never fires during normal slow CPU inference.

    See module docstring for the full SSE contract.
    """

    async def _generate():
        done = False
        acquired = tracker.acquire() if tracker is not None else contextlib.nullcontext()
        try:
            async with acquired:
                try:
                    async with (
                        httpx.AsyncClient(base_url=base_url, timeout=120, transport=upstream_transport) as client,
                        client.stream("POST", "/v1/chat/completions", json=payload, headers=headers) as r,
                    ):
                        if r.status_code != 200:
                            log.warning("inference stream returned HTTP %s [request %s]", r.status_code, rid)
                            yield b'data: {"error":"eve_resting"}\n\n'
                            return

                        buf = b""
                        async for chunk in _keepalive_iter(r.aiter_bytes(), _KEEPALIVE_INTERVAL_S):
                            if chunk is None:
                                # No data in the last KEEPALIVE_INTERVAL_S seconds — emit a comment
                                # so the client's idle timeout does not fire.
                                yield b": wait\n\n"
                                continue
                            buf += chunk
                            # Process complete lines from the buffer.  Splitting on b"\n" is safe for
                            # UTF-8: the byte 0x0a never appears inside a multi-byte sequence.
                            while b"\n" in buf:
                                line, buf = buf.split(b"\n", 1)
                                line = line.rstrip(b"\r")
                                if not line or line.startswith(b":"):
                                    continue  # SSE keep-alive / comment
                                if not line.startswith(b"data: "):
                                    continue  # other SSE fields (event:, id:, retry:) — ignore
                                data = line[6:]
                                if data == b"[DONE]":
                                    yield b'data: {"done":true,"finish_reason":"stop"}\n\n'
                                    done = True
                                    return
                                try:
                                    obj = _json.loads(data)
                                    choices = obj.get("choices") or []
                                    if not choices:
                                        continue
                                    delta_obj = choices[0].get("delta") or {}
                                    content = delta_obj.get("content")
                                    finish = choices[0].get("finish_reason")
                                    if content:
                                        yield ("data: " + _json.dumps({"delta": content}) + "\n\n").encode()
                                    elif finish:
                                        yield (
                                            "data: " + _json.dumps({"done": True, "finish_reason": finish}) + "\n\n"
                                        ).encode()
                                        done = True
                                        return
                                except (_json.JSONDecodeError, IndexError, KeyError, TypeError):
                                    pass  # skip malformed upstream events

                except httpx.ConnectError:
                    log.warning("inference upstream unreachable (stream) [request %s]", rid)
                    yield b'data: {"error":"eve_resting"}\n\n'
                    return
                except httpx.ReadTimeout:
                    log.warning("inference upstream timed out (stream) [request %s]", rid)
                    yield b'data: {"error":"eve_resting"}\n\n'
                    return
                except httpx.HTTPError:
                    log.warning("inference upstream error (stream) [request %s]", rid)
                    yield b'data: {"error":"eve_resting"}\n\n'
                    return

                if not done:
                    log.warning("inference upstream stream ended without terminal event [request %s]", rid)
                    yield b'data: {"error":"eve_resting"}\n\n'
        except _InferenceBusy:
            log.info("inference busy (stream) [request %s]", rid)
            yield b'data: {"error":"eve_busy"}\n\n'

    return StreamingResponse(_generate(), media_type="text/event-stream")
