"""A short id per request, returned as X-Request-ID and put in server-side log lines, so a user's
"it said error" can be matched to the real cause without sending that cause to the client."""

from __future__ import annotations

import uuid
from contextvars import ContextVar

from fastapi import Request

HEADER = "X-Request-ID"
_current: ContextVar[str] = ContextVar("request_id", default="-")


def current() -> str:
    return _current.get()


async def middleware(request: Request, call_next):
    rid = uuid.uuid4().hex[:16]
    token = _current.set(rid)
    try:
        response = await call_next(request)
    finally:
        _current.reset(token)
    response.headers[HEADER] = rid
    return response
