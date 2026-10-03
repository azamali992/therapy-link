"""Cloud inference proxy for the Eve model.

Forwards to an OpenAI-compatible llama-server.  Supports both streaming (SSE pass-through)
and non-streaming responses.  Never logs message bodies or the system prompt.

Rate limits are enforced per uid before the upstream call.
"""

from __future__ import annotations

import hashlib
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

_EVE_DOWN_DETAIL = "Eve is resting right now — please try again in a moment"


async def chat_rate_limit(request: Request, p: Principal = Depends(current_principal)) -> Principal:
    """Every call spends a token, answered or not: the limit is on what a uid can ask of the GPU."""
    # App Check on inference routes.
    await _verify_app_check(request)
    # Per-uid inference rate limit (short window + daily cap).
    wait = await atake(request.app.state.chat_limiter, p.uid)
    if wait:
        raise HTTPException(429, "too many messages, try again shortly", headers={"Retry-After": str(math.ceil(wait))})
    return p


def _validate_prompt_hash(body: ChatIn, expected_sha256: str | None) -> None:
    """If TL_PROMPT_SHA256 is set, the first message must be role=system and its content must hash
    to that value.  This prevents the server from serving arbitrary prompts; the app ships its own.
    """
    if not expected_sha256:
        return
    system_msgs = [m for m in body.messages if m.role == "system"]
    if not system_msgs:
        raise HTTPException(422, "system prompt required when TL_PROMPT_SHA256 is configured")
    actual = hashlib.sha256(system_msgs[0].content.encode()).hexdigest()
    if actual != expected_sha256.lower():
        raise HTTPException(422, "system prompt does not match the configured hash")


@router.post("/chat", response_model=ChatOut)
async def chat(body: ChatIn, request: Request, _: Principal = Depends(chat_rate_limit)):
    """Cloud path: forwards to an OpenAI-compatible llama-server. On-device inference never hits this."""
    s = get_settings()
    if not s.inference_base_url:
        raise HTTPException(503, _EVE_DOWN_DETAIL)

    _validate_prompt_hash(body, s.prompt_sha256)

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
    """Pass the llama-server SSE stream straight through to the client."""

    async def _generate():
        try:
            async with (
                httpx.AsyncClient(base_url=base_url, timeout=120, transport=upstream_transport) as client,
                client.stream("POST", "/v1/chat/completions", json=payload, headers=headers) as r,
            ):
                if r.status_code != 200:
                    log.warning("inference stream returned HTTP %s [request %s]", r.status_code, rid)
                    yield b'data: {"error":"Eve is resting"}\n\n'
                    return
                async for chunk in r.aiter_bytes():
                    yield chunk
        except httpx.ConnectError:
            log.warning("inference upstream unreachable (stream) [request %s]", rid)
            yield b'data: {"error":"Eve is resting"}\n\n'
        except httpx.ReadTimeout:
            log.warning("inference upstream timed out (stream) [request %s]", rid)
            yield b'data: {"error":"Eve is resting"}\n\n'
        except httpx.HTTPError:
            log.warning("inference upstream error (stream) [request %s]", rid)
            yield b'data: {"error":"Eve is resting"}\n\n'

    return StreamingResponse(_generate(), media_type="text/event-stream")
