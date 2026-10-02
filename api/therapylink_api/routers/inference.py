import logging
import math

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request

from therapylink_api import requestid
from therapylink_api.auth import Principal, current_principal
from therapylink_api.schemas import ChatIn, ChatOut
from therapylink_api.settings import get_settings

log = logging.getLogger(__name__)
router = APIRouter(prefix="/inference", tags=["inference"])
# Tests swap in an httpx.MockTransport; None is the real network.
upstream_transport: httpx.AsyncBaseTransport | None = None


async def chat_rate_limit(request: Request, p: Principal = Depends(current_principal)) -> Principal:
    """Every call spends a token, answered or not: the limit is on what a uid can ask of the GPU."""
    wait = request.app.state.chat_limiter.take(p.uid)
    if wait:
        raise HTTPException(429, "too many messages, try again shortly", headers={"Retry-After": str(math.ceil(wait))})
    return p


@router.post("/chat", response_model=ChatOut)
async def chat(body: ChatIn, _: Principal = Depends(chat_rate_limit)):
    """Cloud path: forwards to an OpenAI-compatible llama-server. On-device inference never hits this."""
    s = get_settings()
    if not s.inference_base_url:
        raise HTTPException(503, "cloud inference is not configured; use on-device inference")
    headers = {"Authorization": f"Bearer {s.inference_api_key}"} if s.inference_api_key else {}
    payload = {
        "model": s.inference_model,
        "messages": [m.model_dump() for m in body.messages],
        "max_tokens": body.max_tokens,
        "temperature": body.temperature,
    }
    rid = requestid.current()
    async with httpx.AsyncClient(base_url=s.inference_base_url, timeout=60, transport=upstream_transport) as client:
        try:
            r = await client.post("/v1/chat/completions", json=payload, headers=headers)
            r.raise_for_status()
        except httpx.ConnectError as e:
            log.warning("inference upstream unreachable [request %s]: %s", rid, e)
            raise HTTPException(502, "inference upstream unreachable") from None
        except httpx.ReadTimeout as e:
            log.warning("inference upstream timed out [request %s]: %s", rid, e)
            raise HTTPException(504, "inference upstream timed out") from None
        except httpx.HTTPStatusError as e:
            log.warning("inference upstream returned HTTP %s [request %s]: %s", e.response.status_code, rid, e)
            raise HTTPException(502, "inference upstream error") from None
        except httpx.HTTPError as e:
            log.warning("inference upstream error [request %s]: %s", rid, e)
            raise HTTPException(502, "inference upstream error") from None

    try:
        data = r.json()
        return ChatOut(reply=data["choices"][0]["message"]["content"].strip(), model=data.get("model", s.inference_model))
    except (KeyError, ValueError, TypeError) as e:
        log.warning("inference upstream bad reply [request %s]: %s", rid, r.text[:200])
        raise HTTPException(502, "inference upstream returned an unreadable reply") from None
