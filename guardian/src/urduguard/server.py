"""HTTP server: POST /v1/moderations (OpenAI-compatible shape) and POST /v1/guard (native), GET /healthz.

    URDUGUARD_MODEL_DIR=<dir> uvicorn urduguard.server:app

Privacy by construction: no request body, text, flag or result is written anywhere. There is no access
log of bodies (uvicorn's default access log carries method, path and status only). Metrics are counts.
There is no option that stores text or stores self_harm or needs_caution flags, so none can be left on.
"""

from __future__ import annotations

import os
import time
from collections import Counter

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from . import api, taxonomy

MAX_ITEMS = 32
MAX_CHARS = 2000

app = FastAPI(title="urduguard", version="0.1.0a0", docs_url=None, redoc_url=None)
_counts: Counter = Counter()  # requests, items, errors, flagged per protective label. Never self_harm or needs_caution.
_started = time.time()


class ModerationRequest(BaseModel):
    input: str | list[str]
    model: str | None = None


class GuardRequest(BaseModel):
    input: str | list[str]
    mode: str = Field(default="strict", pattern="^(strict|loose)$")
    form: str | None = Field(default=None, pattern="^(en|roman_ur|ur|mixed)$")


def _items(inp: str | list[str]) -> list[str]:
    items = [inp] if isinstance(inp, str) else list(inp)
    if not items or len(items) > MAX_ITEMS:
        raise HTTPException(422, f"input must hold 1 to {MAX_ITEMS} items")
    for i, t in enumerate(items):
        if not isinstance(t, str) or not t.strip():
            raise HTTPException(422, f"item {i} is empty")
        if len(t) > MAX_CHARS:
            raise HTTPException(413, f"item {i} is over {MAX_CHARS} characters")
    return items


def _run(items: list[str], mode: str, form: str | None):
    try:
        results = api.check_batch(items, mode=mode, form=form)
    except RuntimeError as e:
        raise HTTPException(503, str(e))
    _counts["requests"] += 1
    _counts["items"] += len(items)
    for r in results:
        for l in taxonomy.PROTECTIVE:
            if r.labels[l]:
                _counts[f"flagged:{l}"] += 1
    return results


@app.post("/v1/moderations")
def moderations(req: ModerationRequest):
    results = _run(_items(req.input), "strict", None)
    m = results[0]
    return {"id": f"modr-{int(time.time() * 1000)}", "model": f"urduguard/{m.model_name}", "results": [r.to_openai() for r in results]}


@app.post("/v1/guard")
def guard(req: GuardRequest):
    results = _run(_items(req.input), req.mode, req.form)
    return {"results": [r.to_dict() for r in results]}


@app.get("/healthz")
def healthz():
    try:
        m = api._model(None)
    except RuntimeError as e:
        raise HTTPException(503, str(e))
    return {"ok": True, "model_name": m.name, "model_hash": m.model_hash, "placeholder": m.placeholder,
            "taxonomy_version": taxonomy.TAXONOMY_VERSION, "uptime_s": int(time.time() - _started)}


@app.get("/metrics")
def metrics_():
    if os.environ.get("URDUGUARD_METRICS", "0") != "1":
        raise HTTPException(404)
    return dict(_counts)
