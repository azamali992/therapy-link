"""Streaming downloader with resume, retries and size verification, stdlib only.

curl.exe on this machine fails TLS handshakes to some hosts (GitHub, Adoptium) while Python's
OpenSSL stack does not, so the setup scripts shell out to this instead.

    python scripts/download.py <url> <dest>
"""

from __future__ import annotations

import os
import sys
import time
import urllib.error
import urllib.request

CHUNK = 1 << 20
UA = {"User-Agent": "therapylink-setup/1.0"}


def _expected_size(url: str) -> int | None:
    """HEAD the URL (following redirects) to learn the full size, so a truncated stream is detectable."""
    try:
        req = urllib.request.Request(url, headers=UA, method="HEAD")
        with urllib.request.urlopen(req, timeout=60) as resp:
            return int(resp.headers["Content-Length"]) if resp.headers.get("Content-Length") else None
    except Exception:
        return None


def download(url: str, dest: str, retries: int = 8) -> None:
    part = dest + ".part"
    expected = _expected_size(url)
    if expected:
        print(f"expected {expected >> 20} MB")

    for attempt in range(1, retries + 1):
        have = os.path.getsize(part) if os.path.exists(part) else 0
        if expected and have == expected:
            break
        headers = dict(UA) | ({"Range": f"bytes={have}-"} if have else {})
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as resp:
                if have and resp.status != 206:  # server ignored the range; start over
                    have = 0
                done = have
                last = time.time()
                with open(part, "ab" if have else "wb") as f:
                    while chunk := resp.read(CHUNK):
                        f.write(chunk)
                        done += len(chunk)
                        if time.time() - last > 10:
                            pct = f" {done / expected * 100:5.1f}%" if expected else ""
                            print(f"  {done >> 20} MB{pct}", flush=True)
                            last = time.time()
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as e:
            print(f"attempt {attempt}/{retries}: {e}", flush=True)

        size = os.path.getsize(part) if os.path.exists(part) else 0
        if expected is None or size >= expected:
            break
        if size == have:  # no progress at all this attempt
            time.sleep(min(30, 5 * attempt))
        print(f"attempt {attempt}/{retries}: have {size >> 20} of {expected >> 20} MB, resuming", flush=True)
    else:
        raise SystemExit(f"download incomplete after {retries} attempts: {url}")

    size = os.path.getsize(part)
    if expected and size != expected:
        raise SystemExit(f"size mismatch: got {size}, expected {expected} — left at {part}")
    os.replace(part, dest)
    print(f"saved {dest} ({size >> 20} MB)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    os.makedirs(os.path.dirname(os.path.abspath(sys.argv[2])), exist_ok=True)
    download(sys.argv[1], sys.argv[2])
