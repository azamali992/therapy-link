"""Package the corpus (and optionally a trained adapter) as a PRIVATE Kaggle Dataset.

Private is not optional. The corpus contains ESConv and EmpatheticDialogues (CC BY-NC) and
CounselChat (scraped, terms unverified). Training on them for a non-commercial portfolio project
is defensible; re-publishing them is not.

    tl-kaggle corpus                      # first upload (creates the dataset)
    tl-kaggle corpus --update "rebuilt"   # new version of an existing dataset
    tl-kaggle corpus --update "pairs" --with-dpo-pairs   # also bundle data/processed/dpo_pairs.jsonl
    tl-kaggle adapter runs/eve-sft        # push a trained adapter back for the DPO notebook
    tl-kaggle adapter runs/eve-sft --adapter-dir adapter-epoch1   # push a chosen epoch instead
    tl-kaggle run / wait / status         # launch a notebook, block until it ends, fetch its log
    tl-kaggle cancel --slug <kernel>      # stop a running session (the kaggle CLI can't)
    tl-kaggle quota                       # weekly GPU hours used
"""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import typer
from rich.console import Console

ML_ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ML_ROOT / "data" / "processed"

app = typer.Typer(add_completion=False, no_args_is_help=True)
console = Console()


def _username() -> str:
    cfg = Path.home() / ".kaggle" / "kaggle.json"
    if not cfg.exists():
        raise typer.BadParameter("~/.kaggle/kaggle.json not found. Kaggle → Settings → API → Create New Token.")
    return json.loads(cfg.read_text())["username"]


def _kaggle(*args: str) -> None:
    exe = ML_ROOT / ".venv" / "Scripts" / "kaggle.exe"
    cmd = [str(exe) if exe.exists() else "kaggle", *args]
    console.print(f"[dim]$ {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def _push(staging: Path, slug: str, title: str, update: str | None) -> None:
    owner = _username()
    (staging / "dataset-metadata.json").write_text(
        json.dumps({"title": title, "id": f"{owner}/{slug}", "licenses": [{"name": "other"}]}, indent=2),
        encoding="utf-8",
    )
    size = sum(f.stat().st_size for f in staging.rglob("*") if f.is_file()) >> 20
    console.print(f"uploading {size} MB to [bold]{owner}/{slug}[/] (private)")
    if update:
        _kaggle("datasets", "version", "-p", str(staging), "-m", update, "--dir-mode", "zip")
    else:
        _kaggle("datasets", "create", "-p", str(staging), "--dir-mode", "zip")
    console.print(f"\n[green]done[/] → https://www.kaggle.com/datasets/{owner}/{slug}")
    console.print("Attach it to the notebook with [bold]+ Add Input[/] → Datasets → Your Datasets.")


@app.command()
def corpus(
    slug: str = "therapylink-corpus",
    title: str = "TherapyLink corpus",
    update: str = typer.Option("", help="Version message; omit to create the dataset for the first time"),
    bilingual: bool = typer.Option(False, help="Include conversations.bilingual.train.jsonl instead of the English-only file"),
    with_source: bool = typer.Option(True, help="Bundle the therapylink_ml package so the notebook needs no GitHub clone"),
    with_dpo_pairs: bool = typer.Option(
        False, "--with-dpo-pairs", help="Also bundle data/processed/dpo_pairs.jsonl for the DPO notebook"
    ),
) -> None:
    """Upload the training splits, data card and stats."""
    train = PROCESSED / ("conversations.bilingual.train.jsonl" if bilingual else "conversations.train.jsonl")
    if not train.exists():
        raise typer.BadParameter(f"{train} not found — run `tl-data build` first")
    pairs = PROCESSED / "dpo_pairs.jsonl"
    if with_dpo_pairs and not pairs.exists():
        raise typer.BadParameter(f"{pairs} not found — run `eve_dpo build-pairs` first")

    with tempfile.TemporaryDirectory() as tmp:
        staging = Path(tmp)
        files = [train, PROCESSED / "conversations.val.jsonl", PROCESSED / "DATA_CARD.md", PROCESSED / "stats.json"]
        for f in files + ([pairs] if with_dpo_pairs else []):
            if f.exists():
                shutil.copy(f, staging / f.name.replace(".bilingual", ""))
        if with_source:
            code = staging / "code"
            shutil.copytree(
                ML_ROOT / "therapylink_ml",
                code / "therapylink_ml",
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
            )
            shutil.copy(ML_ROOT / "pyproject.toml", code / "pyproject.toml")
        _push(staging, slug, title, update or None)


@app.command()
def run(
    notebook: Path = typer.Argument(Path("notebooks/eve_sft_kaggle.ipynb")),
    slug: str = typer.Option("therapylink-eve-sft", help="Kernel slug on Kaggle"),
    title: str = typer.Option("", help="Defaults to the slug — Kaggle derives the real slug from the title, so they must agree"),
    datasets: list[str] = typer.Option(["therapylink-corpus"], "--dataset", help="Dataset slugs to attach"),
    kernels: list[str] = typer.Option([], "--kernel", help="Kernel slugs whose output to attach (e.g. the SFT run, for DPO)"),
    gpu: bool = True,
    internet: bool = True,
) -> None:
    """Push a notebook to Kaggle and start it. Consumes the account's weekly GPU quota."""
    owner = _username()
    # Kaggle slugifies the title and ignores the id's slug, so a mismatched title silently produces
    # a different kernel than the one you then poll.
    title = title or slug
    with tempfile.TemporaryDirectory() as tmp:
        staging = Path(tmp)
        shutil.copy(notebook, staging / notebook.name)
        (staging / "kernel-metadata.json").write_text(
            json.dumps(
                {
                    "id": f"{owner}/{slug}",
                    "title": title,
                    "code_file": notebook.name,
                    "language": "python",
                    "kernel_type": "notebook",
                    "is_private": True,
                    "enable_gpu": gpu,
                    "enable_internet": internet,
                    "dataset_sources": [f"{owner}/{d}" for d in datasets],
                    "competition_sources": [],
                    "kernel_sources": [f"{owner}/{k}" for k in kernels],
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        _kaggle("kernels", "push", "-p", str(staging))
    console.print(f"\n[green]running[/] → https://www.kaggle.com/code/{owner}/{slug}")
    console.print(f"poll with:  python -m therapylink_ml.kaggle_push status --slug {slug}")


PENDING = ("QUEUED", "RUNNING", "CANCEL_REQUESTED")


def _api():
    import os

    os.environ.setdefault("KAGGLE_CONFIG_DIR", str(Path.home() / ".kaggle"))
    from kaggle.api.kaggle_api_extended import KaggleApi

    api = KaggleApi()
    api.authenticate()
    return api


def _kernel_status(api, owner: str, slug: str) -> str:
    raw = api.kernels_status(f"{owner}/{slug}")
    status = raw.get("status") if isinstance(raw, dict) else getattr(raw, "status", raw)
    return str(status).rsplit(".", 1)[-1].upper()


@app.command()
def status(slug: str = "therapylink-eve-sft") -> None:
    """Print a kernel's current status."""
    console.print(_kernel_status(_api(), _username(), slug))


def _session_id(api, owner: str, slug: str) -> tuple[int, int]:
    """(session id, version) of the kernel's current version.

    No public call returns a session id, and cancelling needs one. The output-download redirect
    embeds it — https://www.kaggleusercontent.com/kf/<session id>/… — and works while running.
    """
    import re

    from kagglesdk.kernels.types.kernels_api_service import ApiDownloadKernelOutputRequest, ApiGetKernelRequest

    with api.build_kaggle_client() as k:
        client = k.kernels.kernels_api_client
        meta = ApiGetKernelRequest()
        meta.user_name = owner
        meta.kernel_slug = slug
        version = client.get_kernel(meta).metadata.current_version_number
        req = ApiDownloadKernelOutputRequest()
        req.owner_slug = owner
        req.kernel_slug = slug
        req.version_number = version
        req.file_path = "__results__.html"
        http = client._client
        http._init_session()
        prepared = http._prepare_request("kernels.KernelsApiService", "DownloadKernelOutput", req)
        resp = http._session.send(prepared, allow_redirects=False)
    match = re.search(r"/kf/(\d+)/", resp.headers.get("Location", ""))
    if not match:
        raise RuntimeError(f"no session id for {owner}/{slug} v{version} (HTTP {resp.status_code})")
    return int(match.group(1)), version


@app.command()
def cancel(slug: str = "therapylink-eve-sft") -> None:
    """Stop a running kernel and stop spending GPU quota on it. The kaggle CLI can't; the SDK can."""
    import time

    from kagglesdk.kernels.types.kernels_api_service import ApiCancelKernelSessionRequest

    api, owner = _api(), _username()
    state = _kernel_status(api, owner, slug)
    if state not in PENDING:
        console.print(f"nothing to cancel: {state}")
        return
    session, version = _session_id(api, owner, slug)
    req = ApiCancelKernelSessionRequest()
    req.kernel_session_id = session
    with api.build_kaggle_client() as k:
        error = k.kernels.kernels_api_client.cancel_kernel_session(req).error_message
    if error:
        raise RuntimeError(error)
    for _ in range(30):
        state = _kernel_status(api, owner, slug)
        if state not in PENDING:
            break
        time.sleep(5)
    console.print(f"v{version} (session {session}): [bold]{state}[/]")


@app.command()
def quota() -> None:
    """Weekly GPU time used. Every run spends it, cancelled ones included."""
    from kagglesdk.kernels.types.kernels_api_service import ApiGetAcceleratorQuotaStatisticsRequest

    with _api().build_kaggle_client() as k:
        q = k.kernels.kernels_api_client.get_accelerator_quota_statistics(ApiGetAcceleratorQuotaStatisticsRequest())
    g = q.gpu_quota
    console.print(f"GPU {g.time_used} used of {g.total_time_allowed}; resets {q.quota_refresh_time:%Y-%m-%d}")


@app.command()
def wait(
    slug: str = "therapylink-eve-sft",
    out: Path = typer.Option(Path("runs/kaggle"), "--out"),
    poll: int = typer.Option(45, help="Seconds between status checks"),
    # A full T4 run is ~9 h and Kaggle allows 12; a shorter default gives up on a healthy run.
    timeout_min: int = 720,
    tail: int = typer.Option(30, help="Log lines to print when it finishes"),
) -> None:
    """Block until a kernel reaches a terminal state, then download and print its log.

    QUEUED counts as pending — a poll loop that only waits on RUNNING exits instantly and reads
    the *previous* run's log, which looks exactly like the new run failing the same way.
    """
    import json
    import os
    import re
    import sys
    import time

    # Kaggle logs carry box-drawing characters and emoji. On Windows the SDK writes the log file
    # with the locale codec (cp1252), which raises on them — after the run has finished, so the log
    # is lost. Only UTF-8 mode changes open()'s default, and it must be set at interpreter start,
    # so re-run this command under -X utf8 rather than patch the SDK.
    if sys.platform == "win32" and not sys.flags.utf8_mode:
        env = {**os.environ, "PYTHONUTF8": "1"}
        raise SystemExit(subprocess.call([sys.executable, "-X", "utf8", "-m", "therapylink_ml.kaggle_push", *sys.argv[1:]], env=env))
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")

    api, owner = _api(), _username()
    deadline = time.time() + timeout_min * 60
    state = _kernel_status(api, owner, slug)
    while state in PENDING and time.time() < deadline:
        console.print(f"[dim]{state}…")
        time.sleep(poll)
        state = _kernel_status(api, owner, slug)
    console.print(f"[bold]{state}[/]")

    out.mkdir(parents=True, exist_ok=True)
    api.kernels_output(f"{owner}/{slug}", path=str(out), force=True, quiet=True)
    log = out / f"{slug}.log"
    # A cancelled session returns an empty log file rather than none at all.
    if not log.exists() or not log.read_text(encoding="utf-8").strip():
        console.print("[yellow]no log returned")
        return
    entries = json.loads(log.read_text(encoding="utf-8"))
    text = re.sub(r"\x1b\[[0-9;]*m", "", "".join(e.get("data", "") for e in entries))
    (out / "kernel.txt").write_text(text, encoding="utf-8")
    lines = [ln for ln in text.splitlines() if ln.strip() and "Map:" not in ln and "it/s]" not in ln]
    for ln in lines[-tail:]:
        console.print(ln[:150], highlight=False)


@app.command()
def adapter(
    run: Path = typer.Argument(..., help="A run directory containing adapter/"),
    slug: str = "therapylink-eve-sft",
    title: str = "TherapyLink Eve SFT adapter",
    update: str = typer.Option("", help="Version message; omit to create the dataset"),
    adapter_dir: str = typer.Option(
        "adapter", "--adapter-dir", help="Which adapter in the run to push, e.g. adapter-epoch1; uploaded as adapter/"
    ),
) -> None:
    """Upload a trained LoRA adapter so the DPO notebook can pick it up."""
    src = run / adapter_dir
    if not src.exists():
        raise typer.BadParameter(f"{src} not found")
    with tempfile.TemporaryDirectory() as tmp:
        staging = Path(tmp)
        shutil.copytree(src, staging / "adapter")
        _push(staging, slug, title, update or None)


@app.command()
def pairs(
    slug: str = "therapylink-dpo-pairs",
    title: str = "TherapyLink DPO pairs",
    update: str = typer.Option("", help="Version message; omit to create the dataset"),
) -> None:
    """Upload data/processed/dpo_pairs.jsonl on its own, so a DPO run doesn't wait on a corpus upload."""
    src = PROCESSED / "dpo_pairs.jsonl"
    if not src.exists():
        raise typer.BadParameter(f"{src} not found — run `eve_dpo build-pairs` first")
    with tempfile.TemporaryDirectory() as tmp:
        staging = Path(tmp)
        shutil.copy(src, staging / src.name)
        _push(staging, slug, title, update or None)


if __name__ == "__main__":
    app()
