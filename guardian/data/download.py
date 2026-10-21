"""Download every source in sources.json into raw/<source>/ and record content hashes.

    python -I guardian/data/download.py            # all sources
    python -I guardian/data/download.py aegis2     # one source

Each file's sha256 and size go to hashes/<source>.json (committed). raw/ is gitignored and is
untrusted data: nothing in this package ever imports from it or runs code found there.
"""

from __future__ import annotations

import hashlib
import json
import sys
import urllib.request
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
HASHES = HERE / "hashes"
SOURCES = json.loads((HERE / "sources.json").read_text(encoding="utf-8"))


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "urduguard-data/0.1"})
    with urllib.request.urlopen(req, timeout=120) as r, dest.open("wb") as f:
        for chunk in iter(lambda: r.read(1 << 20), b""):
            f.write(chunk)


def download(source: str) -> dict:
    spec = SOURCES[source]
    out = RAW / source
    record = {"hf": spec["hf"], "licence": spec["licence"], "downloaded": date.today().isoformat(), "files": {}}
    for name in spec["files"]:
        dest = out / name
        if not dest.exists():
            print(f"{source}: fetching {name}")
            fetch(f"https://huggingface.co/datasets/{spec['hf']}/resolve/main/{name}", dest)
        record["files"][name] = {"sha256": sha256_of(dest), "bytes": dest.stat().st_size}
        print(f"{source}: {name} {record['files'][name]['bytes']} bytes {record['files'][name]['sha256'][:12]}")
    HASHES.mkdir(exist_ok=True)
    previous = HASHES / f"{source}.json"
    if previous.exists():
        old = json.loads(previous.read_text(encoding="utf-8"))["files"]
        changed = [n for n in old if n in record["files"] and old[n]["sha256"] != record["files"][n]["sha256"]]
        if changed:
            raise SystemExit(f"{source}: content changed upstream for {changed}; delete hashes/{source}.json if that is expected")
    previous.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return record


if __name__ == "__main__":
    for s in sys.argv[1:] or SOURCES:
        download(s)
