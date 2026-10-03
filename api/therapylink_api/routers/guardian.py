"""The trained Guardian's files, for the app to download: GET /guardian/<file>.

The Guardian is the on-device crisis classifier (app/lib/core/ml/onnx_guardian.dart). Its bundle is a
model and a tokenizer, the same for everyone and holding nothing about anyone, so it is served
without sign-in. The app pins each file's SHA-256 at build time and refuses anything else, so this
route only has to hand over bytes; it does not vouch for them.

Only the four bundle files can be fetched, from the directory in TL_GUARDIAN_DIR (ops/free mounts
it read-only and get-models.sh fills it, sha256-checked). The ETag is the file's SHA-256, a strong
validator, so a phone resuming a download with If-Range never gets the tail of a different file
spliced onto the start of the old one. Range requests are honoured, so a dropped download resumes.
"""

import asyncio
import hashlib
import os
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, Response

from therapylink_api.settings import get_settings

router = APIRouter(tags=["guardian"])

# The names every Guardian bundle uses (guardianFileNames in onnx_guardian.dart). Nothing else in the
# directory is reachable, whatever the request path says.
FILES = {
    "guardian.int8.onnx": "application/octet-stream",
    "spm_vocab.json": "application/json",
    "config.json": "application/json",
    "thresholds.json": "application/json",
}

# Public and cacheable, but not forever: a new release (v1c) keeps the same file names, so a cache
# must look again within the hour. The ETag makes that look cheap.
CACHE_CONTROL = "public, max-age=3600"

# SHA-256 per file, keyed on what would change if the file were swapped.
_digests: dict[tuple[str, int, int], str] = {}


def _sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


async def _etag(path: Path) -> str:
    st = path.stat()
    key = (str(path), st.st_mtime_ns, st.st_size)
    digest = _digests.get(key)
    if digest is None:
        # 280 MB takes a second or so to hash; off the event loop, once per file version.
        digest = await asyncio.to_thread(_sha256, str(path))
        _digests[key] = digest
    return f'"{digest}"'


def _matches(header: str | None, etag: str) -> bool:
    if not header:
        return False
    return header.strip() == "*" or etag in [t.strip().removeprefix("W/") for t in header.split(",")]


@router.api_route("/guardian/{name}", methods=["GET", "HEAD"], include_in_schema=False)
async def guardian_file(name: str, request: Request):
    directory = get_settings().guardian_dir
    if name not in FILES or not directory:
        raise HTTPException(status_code=404, detail="not found")
    path = Path(directory) / name
    if not path.is_file():
        raise HTTPException(status_code=404, detail="not found")
    etag = await _etag(path)
    headers = {"ETag": etag, "Cache-Control": CACHE_CONTROL, "X-Content-Type-Options": "nosniff"}
    if _matches(request.headers.get("if-none-match"), etag):
        return Response(status_code=304, headers=headers)
    # FileResponse answers Range and If-Range itself, checking If-Range against this ETag.
    return FileResponse(os.fspath(path), media_type=FILES[name], headers=headers)
