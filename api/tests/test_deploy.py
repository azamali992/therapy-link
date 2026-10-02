"""Checks on the image recipe that don't need a Docker daemon. CI should still run `docker build`."""

import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

API = Path(__file__).resolve().parents[1]


def test_image_ships_migrations_and_a_release_entry():
    dockerfile = (API / "Dockerfile").read_text()
    for line in ("COPY alembic.ini ./", "COPY alembic ./alembic", "COPY docker-entrypoint.sh", 'ENTRYPOINT ["tl-api"]'):
        assert line in dockerfile
    entry = (API / "docker-entrypoint.sh").read_text()
    assert "alembic upgrade head" in entry
    assert "--proxy-headers" in entry and "${WEB_CONCURRENCY:-1}" in entry


def test_dockerfile_has_healthcheck():
    dockerfile = (API / "Dockerfile").read_text()
    assert "HEALTHCHECK" in dockerfile, "Dockerfile must include a HEALTHCHECK instruction"
    assert "/health" in dockerfile, "HEALTHCHECK must probe the /health liveness endpoint"


def test_base_image_is_pinned_to_a_digest():
    # A tag alone moves under us: the same commit could build a different image next week.
    froms = [line for line in (API / "Dockerfile").read_text().splitlines() if line.startswith("FROM ")]
    assert froms and all("@sha256:" in line for line in froms), froms


def test_dependabot_keeps_the_base_image_digest_current():
    # A pinned digest never moves by itself; without this it silently misses base-image security fixes.
    config = yaml.safe_load((API.parent / ".github" / "dependabot.yml").read_text())
    assert any(u["package-ecosystem"] == "docker" and u["directory"] == "/api" for u in config["updates"]), config


def test_ci_builds_releases_serves_and_scans_the_image():
    ci = yaml.safe_load((API.parent / ".github" / "workflows" / "ci.yml").read_text())
    job = ci["jobs"]["api-image"]
    assert "postgres" in job["services"]
    runs = "\n".join(step.get("run", "") for step in job["steps"])
    assert "docker build" in runs
    assert re.search(r"docker run .*\brelease\b", runs), "the release entry must migrate the service database"
    assert re.search(r"docker run .*\bserve\b", runs) and "curl -sf http://localhost:7860/health" in runs
    assert re.search(r"trivy image .*--exit-code 1 .*--severity CRITICAL", runs)


def test_ci_round_trips_migrations_on_postgres():
    steps = yaml.safe_load((API.parent / ".github" / "workflows" / "ci.yml").read_text())["jobs"]["api-postgres"][
        "steps"
    ]
    runs = [step["run"] for step in steps if "run" in step]
    order = [
        "alembic upgrade head",
        "alembic downgrade base",
        "alembic upgrade head",
        "alembic check",
        "python -m pytest -q",
    ]
    assert [r for r in runs if r in order] == order


def test_build_context_leaves_out_secrets_and_local_state():
    ignored = (API / ".dockerignore").read_text().split()
    assert {".env", ".venv", "*.db"} <= set(ignored)


@pytest.mark.skipif(shutil.which("sh") is None, reason="needs a POSIX sh")
def test_release_entry_migrates_an_empty_database(tmp_path):
    db = tmp_path / "release.db"
    env = os.environ | {
        "TL_DATABASE_URL": f"sqlite+aiosqlite:///{db.as_posix()}",
        # The console scripts (alembic, uvicorn) sit next to this interpreter.
        "PATH": str(Path(sys.executable).parent) + os.pathsep + os.environ["PATH"],
        "PYTHONPATH": str(API),
    }
    subprocess.run(
        ["sh", "docker-entrypoint.sh", "release"], cwd=API, env=env, check=True, capture_output=True, timeout=120
    )
    with sqlite3.connect(db) as conn:
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert {"alembic_version", "users", "care_links"} <= tables
