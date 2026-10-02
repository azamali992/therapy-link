"""Model registry: the exact files Eve is served from, pinned by sha256.

`ml/registry.json` lists the base GGUF and every LoRA adapter with its hash, size, training run,
prompt and eval numbers. `serve` names the pair to run. Serving scripts (ops/serving/) refuse a
file whose hash does not match, and refuse a `rejected` adapter outright.

    tl-registry verify                # every file in --models-dir, plus the structure and prompt hashes
    tl-registry verify --serving-only # just the base + adapter that `serve` names
    tl-registry show                  # what would be served
"""

from __future__ import annotations

import hashlib
import importlib
import json
import os
from pathlib import Path

import typer

REGISTRY_PATH = Path(__file__).resolve().parents[1] / "registry.json"
STATUSES = ("candidate", "approved", "rejected", "superseded")
SHA256_LEN = 64

app = typer.Typer(add_completion=False, help="Check the model registry against the files on disk.")


def load(path: Path = REGISTRY_PATH) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path, chunk: int = 8 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(chunk):
            h.update(block)
    return h.hexdigest()


def prompt_text(source: str) -> str:
    """Resolve 'module:ATTRIBUTE' to the prompt string it names."""
    module, _, attr = source.partition(":")
    return getattr(importlib.import_module(module), attr)


def entries(reg: dict) -> list[dict]:
    return [*reg.get("base_models", []), *reg.get("adapters", [])]


def by_id(reg: dict) -> dict[str, dict]:
    return {e["id"]: e for e in entries(reg)}


def serving(reg: dict, adapter_id: str | None = None) -> tuple[dict, dict]:
    """The (base, adapter) pair to serve. Raises ValueError for anything that must not be served."""
    ids = by_id(reg)
    adapter_id = adapter_id or reg["serve"]["adapter"]
    if adapter_id not in ids:
        raise ValueError(f"adapter '{adapter_id}' is not in the registry")
    adapter = ids[adapter_id]
    base = ids.get(adapter.get("base_model", ""))
    if base is None:
        raise ValueError(f"adapter '{adapter_id}' names unknown base model '{adapter.get('base_model')}'")
    for e in (base, adapter):
        if e["status"] == "rejected":
            raise ValueError(f"'{e['id']}' is rejected: {e.get('status_reason', 'no reason given')}")
    return base, adapter


def is_approved(entry: dict) -> bool:
    return entry.get("status") == "approved" and bool(entry.get("approved_by"))


def check_structure(reg: dict) -> list[str]:
    """Everything that can be checked without the model files."""
    problems: list[str] = []
    seen: set[str] = set()
    prompts = reg.get("prompts", {})
    for pid, p in prompts.items():
        if p.get("source"):
            try:
                actual = sha256_text(prompt_text(p["source"]))
            except (ImportError, AttributeError) as exc:
                problems.append(f"prompt {pid}: cannot load {p['source']} ({exc})")
                continue
            if actual != p.get("sha256"):
                problems.append(f"prompt {pid}: registry sha256 {p.get('sha256')} but {p['source']} hashes to {actual}")
    base_ids = {b["id"] for b in reg.get("base_models", [])}
    for e in entries(reg):
        eid = e.get("id", "?")
        if eid in seen:
            problems.append(f"{eid}: duplicate id")
        seen.add(eid)
        for key in ("file", "sha256", "size_bytes", "status"):
            if e.get(key) in (None, ""):
                problems.append(f"{eid}: missing {key}")
        if len(str(e.get("sha256", ""))) != SHA256_LEN:
            problems.append(f"{eid}: sha256 is not 64 hex characters")
        if "approved_by" not in e:
            problems.append(f"{eid}: no approved_by field (use null until a clinician signs)")
        status = e.get("status")
        if status not in STATUSES:
            problems.append(f"{eid}: status '{status}' is not one of {STATUSES}")
        if status == "approved" and not e.get("approved_by"):
            problems.append(f"{eid}: status approved but approved_by is empty")
        if e.get("approved_by") and status != "approved":
            problems.append(f"{eid}: approved_by set but status is '{status}'")
        if status in ("rejected", "superseded") and not e.get("status_reason"):
            problems.append(f"{eid}: {status} without a status_reason")
    for a in reg.get("adapters", []):
        aid = a.get("id", "?")
        if a.get("base_model") not in base_ids:
            problems.append(f"{aid}: base_model '{a.get('base_model')}' is not a registered base model")
        pid = a.get("prompt_id")
        if pid not in prompts:
            problems.append(f"{aid}: prompt_id '{pid}' is not in prompts")
        elif a.get("prompt_sha256") != prompts[pid].get("sha256"):
            problems.append(f"{aid}: prompt_sha256 does not match prompts.{pid}.sha256")
    serve = reg.get("serve", {})
    try:
        base, adapter = serving(reg)
    except (KeyError, ValueError) as exc:
        problems.append(f"serve: {exc}")
    else:
        if serve.get("base") != base["id"]:
            problems.append(f"serve: base '{serve.get('base')}' but adapter '{adapter['id']}' is on '{base['id']}'")
        if serve.get("prompt_id") != adapter.get("prompt_id"):
            problems.append(
                f"serve: prompt_id '{serve.get('prompt_id')}' but the adapter was trained on '{adapter.get('prompt_id')}'"
            )
        if not prompts.get(adapter.get("prompt_id"), {}).get("source"):
            problems.append(f"serve: prompt '{adapter.get('prompt_id')}' has no source text to pin")
    return problems


def check_file(entry: dict, models_dir: Path, skip_missing: bool = False) -> str | None:
    """None when the file on disk is exactly the registered one."""
    path = Path(models_dir) / entry["file"]
    if not path.is_file():
        return None if skip_missing else f"{entry['id']}: {path} not found"
    size = path.stat().st_size
    if size != entry["size_bytes"]:
        return f"{entry['id']}: size {size} != registered {entry['size_bytes']}"
    actual = sha256_file(path)
    if actual != entry["sha256"]:
        return f"{entry['id']}: sha256 {actual} != registered {entry['sha256']}"
    return None


def default_models_dir(reg: dict) -> Path:
    return Path(os.environ.get("TL_MODELS_DIR") or reg.get("models_dir_hint") or ".")


@app.callback()
def main() -> None:
    """Model registry checks."""


@app.command()
def verify(
    registry: Path = typer.Option(REGISTRY_PATH, help="registry.json to check"),
    models_dir: Path | None = typer.Option(
        None, help="Where the GGUF files are (default: $TL_MODELS_DIR, then models_dir_hint)"
    ),
    serving_only: bool = typer.Option(False, help="Hash only the base + adapter that `serve` names"),
    skip_missing: bool = typer.Option(
        False, help="Don't fail on files that are absent (CI without weights); mismatches still fail"
    ),
) -> None:
    """Recompute every sha256 and fail on any mismatch, missing file or broken entry."""
    reg = load(registry)
    problems = check_structure(reg)
    folder = models_dir or default_models_dir(reg)
    if serving_only:
        try:
            targets = list(serving(reg))
        except (KeyError, ValueError):
            targets = []  # already reported by check_structure
    else:
        targets = entries(reg)
    for e in targets:
        problem = check_file(e, folder, skip_missing=skip_missing)
        typer.echo(f"{'FAIL' if problem else 'ok  '} {e['id']:<24} {e['sha256'][:12]}  {e['file']}")
        if problem:
            problems.append(problem)
    for p in problems:
        typer.echo(f"problem: {p}", err=True)
    if problems:
        raise typer.Exit(1)
    typer.echo(f"registry ok: {len(targets)} file(s) in {folder} match")


@app.command()
def show(registry: Path = typer.Option(REGISTRY_PATH, help="registry.json to read")) -> None:
    """Print the base + adapter that would be served, as JSON."""
    reg = load(registry)
    base, adapter = serving(reg)
    out = {
        "base": {k: base[k] for k in ("id", "file", "sha256", "size_bytes", "status")},
        "adapter": {k: adapter[k] for k in ("id", "file", "sha256", "size_bytes", "status", "approved_by")},
        "prompt_id": adapter["prompt_id"],
        "prompt_sha256": adapter["prompt_sha256"],
        "approved": is_approved(base) and is_approved(adapter),
    }
    typer.echo(json.dumps(out, indent=2))


if __name__ == "__main__":
    app()
