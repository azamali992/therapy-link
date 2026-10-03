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

  ``data: {"error":"eve_resting"}``
      Upstream connect failure, timeout, non-200 status, or stream that ended
      without a terminal event. The client must NOT retry automatically; show
      the calm "Eve is resting" message instead.

Handling guarantees:
- Upstream byte chunks split across line boundaries are assembled before
  parsing (byte-level line buffer).
- SSE keep-alive lines (empty or starting with ``:``) are silently dropped.
- Message content is never logged, even on error.

Rate limits are enforced per uid before the upstream call.
"""

from __future__ import annotations

import hashlib
import json as _json
import logging
import math

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse

from therapylink_api import requestid
from therapylink_api.auth import Principal, _verify_app_check, current_principal
from therapylink_api.ratelimit import atake
from therapylink_api.schemas import ChatIn, ChatOut
from therapylink_api.settings import get_settings

log = logging.getLogger(__name__)
router = APIRouter(prefix="/inference", tags=["inference"])
# Tests swap in an httpx.MockTransport; None is the real network.
upstream_transport: httpx.AsyncBaseTransport | None = None

_EVE_DOWN_DETAIL = "Eve is resting right now. Please try again in a moment."


async def chat_rate_limit(request: Request, p: Principal = Depends(current_principal)) -> Principal:
    """Every call spends a token, answered or not: the limit is on what a uid can ask of the GPU."""
    # App Check on inference routes.
    await _verify_app_check(request)
    # Per-uid inference rate limit (short window + daily cap).
    wait = await atake(request.app.state.chat_limiter, p.uid)
    if wait:
        raise HTTPException(429, "too many messages, try again shortly", headers={"Retry-After": str(math.ceil(wait))})
    return p


def _validate_prompt_hash(body: ChatIn, expected_sha256: str | None, prompt_chars: int | None) -> None:
    """Check the prompt integrity when TL_PROMPT_SHA256 and TL_PROMPT_CHARS are both set.

    The app folds the system prompt into the first user turn
    (``foldSystemIntoFirstUser`` in eve_engine.dart / ``prompts.py``), so there
    is normally no ``role=system`` message in a real conversation.  This check
    accepts both the folded form (first ``role=user`` message) and an explicit
    ``role=system`` message by looking at whichever comes first.

    The first ``prompt_chars`` characters of that message must hash to
    ``expected_sha256`` (SHA-256 hex).  If the message is shorter than
    ``prompt_chars`` the check fails: the registered prompt is not present.
    """
    if not expected_sha256 or not prompt_chars:
        return
    first = next((m for m in body.messages if m.role in ("system", "user")), None)
    if first is None or len(first.content) < prompt_chars:
        raise HTTPException(422, "prompt check failed: first message shorter than expected prompt")
    actual = hashlib.sha256(first.content[:prompt_chars].encode()).hexdigest()
    if actual != expected_sha256.lower():
        raise HTTPException(422, "system prompt does not match the configured hash")


@router.post("/chat", response_model=ChatOut)
async def chat(body: ChatIn, request: Request, _: Principal = Depends(chat_rate_limit)):
    """Cloud path: forwards to an OpenAI-compatible llama-server. On-device inference never hits this."""
    s = get_settings()
    if not s.inference_base_url:
        raise HTTPException(503, _EVE_DOWN_DETAIL)

    _validate_prompt_hash(body, s.prompt_sha256, s.prompt_chars)

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
        return await _stream_response(s.inference_base_url, payload, headers, rid)

    return await _non_stream_response(s, payload, headers, rid)


async def _non_stream_response(s, payload: dict, headers: dict, rid: str) -> ChatOut:
    async with httpx.AsyncClient(base_url=s.inference_base_url, timeout=60, transport=upstream_transport) as client:
        try:
            r = await client.post("/v1/chat/completions", json=payload, headers=headers)
            r.raise_for_status()
        except httpx.ConnectError as e:
            # Log the upstream error for ops debugging; never forward it to the client.
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
        # Log token counts but never the message content.
        usage = data.get("usage", {})
        log.info(
            "inference ok [request %s] prompt_tokens=%s completion_tokens=%s model=%s",
            rid,
            usage.get("prompt_tokens"),
            usage.get("completion_tokens"),
            data.get("model", s.inference_model),
        )
        return ChatOut(
            reply=data["choices"][0]["message"]["content"].strip(), model=data.get("model", s.inference_model)
        )
    except (KeyError, ValueError, TypeError):
        log.warning("inference upstream bad reply [request %s]", rid)
        raise HTTPException(502, _EVE_DOWN_DETAIL) from None


async def _stream_response(base_url: str, payload: dict, headers: dict, rid: str) -> StreamingResponse:
    """Normalise the upstream OpenAI SSE stream into the TherapyLink wire format.

    See module docstring for the full contract.
    """

    async def _generate():
        done = False
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
                async for chunk in r.aiter_bytes():
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
                                # Never log the content.
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
            # Upstream stream ended without a terminal event (mid-stream failure).
            log.warning("inference upstream stream ended without terminal event [request %s]", rid)
            yield b'data: {"error":"eve_resting"}\n\n'

    return StreamingResponse(_generate(), media_type="text/event-stream")
