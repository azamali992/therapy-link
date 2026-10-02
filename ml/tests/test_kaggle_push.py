"""What tl-kaggle stages for upload, with the upload itself replaced: nothing here talks to Kaggle."""

from pathlib import Path

import pytest
from typer.testing import CliRunner

from therapylink_ml import kaggle_push

runner = CliRunner()


@pytest.fixture
def staged(monkeypatch):
    """Replace _push with a recorder of every file it would have uploaded, relative to staging."""
    pushes: list[dict] = []

    def fake_push(staging: Path, slug: str, title: str, update: str | None) -> None:
        files = {p.relative_to(staging).as_posix(): p.read_text(encoding="utf-8") for p in staging.rglob("*") if p.is_file()}
        pushes.append({"slug": slug, "update": update, "files": files})

    monkeypatch.setattr(kaggle_push, "_push", fake_push)
    return pushes


@pytest.fixture
def processed(tmp_path, monkeypatch):
    d = tmp_path / "processed"
    d.mkdir()
    for name in ("conversations.train.jsonl", "conversations.val.jsonl", "stats.json", "dpo_pairs.jsonl"):
        (d / name).write_text(name, encoding="utf-8")
    monkeypatch.setattr(kaggle_push, "PROCESSED", d)
    return d


def _invoke(*args: str):
    result = runner.invoke(kaggle_push.app, list(args))
    assert result.exit_code == 0, result.output
    return result


def test_corpus_leaves_dpo_pairs_out_by_default(staged, processed):
    _invoke("corpus", "--update", "v", "--no-with-source")
    files = staged[-1]["files"]
    assert "conversations.train.jsonl" in files and "conversations.val.jsonl" in files
    assert "dpo_pairs.jsonl" not in files


def test_corpus_bundles_dpo_pairs_with_the_flag(staged, processed):
    _invoke("corpus", "--update", "v", "--no-with-source", "--with-dpo-pairs")
    assert staged[-1]["files"]["dpo_pairs.jsonl"] == "dpo_pairs.jsonl"


def test_corpus_refuses_the_flag_without_pairs(staged, processed):
    (processed / "dpo_pairs.jsonl").unlink()
    result = runner.invoke(kaggle_push.app, ["corpus", "--no-with-source", "--with-dpo-pairs"])
    assert result.exit_code != 0 and not staged


@pytest.fixture
def run_dir(tmp_path):
    run = tmp_path / "run"
    for name in ("adapter", "adapter-epoch1"):
        (run / name).mkdir(parents=True)
        (run / name / "adapter_config.json").write_text(name, encoding="utf-8")
    return run


def test_adapter_pushes_run_adapter_by_default(staged, run_dir):
    _invoke("adapter", str(run_dir))
    assert staged[-1]["files"] == {"adapter/adapter_config.json": "adapter"}


def test_adapter_dir_picks_an_epoch_and_stages_it_as_adapter(staged, run_dir):
    _invoke("adapter", str(run_dir), "--adapter-dir", "adapter-epoch1")
    assert staged[-1]["files"] == {"adapter/adapter_config.json": "adapter-epoch1"}


def test_adapter_dir_must_exist(staged, run_dir):
    result = runner.invoke(kaggle_push.app, ["adapter", str(run_dir), "--adapter-dir", "adapter-epoch3"])
    assert result.exit_code != 0 and not staged
