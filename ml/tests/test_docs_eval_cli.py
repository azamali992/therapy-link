"""ml/README.md documents tl-eval's flags; these tests keep the docs and the CLI from drifting apart."""

import re
from pathlib import Path

import pytest
import typer
from typer.testing import CliRunner

from therapylink_ml.eval import run

ML_ROOT = Path(__file__).resolve().parents[1]
README = (ML_ROOT / "README.md").read_text(encoding="utf-8")
KAGGLE = (ML_ROOT / "KAGGLE.md").read_text(encoding="utf-8")
COMMANDS = typer.main.get_command(run.app).commands

# FOLLOWUPS item 4: the flags that were missing from the docs.
REQUIRED = {
    "generate": ["--samples", "--greedy", "--include-drafts", "--model-id", "--adapter-id", "--dtype", "--system"],
    "rescore": ["--out"],
    "calibrate": ["--min-kappa", "--max-false-pass"],
}


def _section(command: str) -> str:
    m = re.search(rf"^### `tl-eval {command}`\n(.*?)(?=^##)", README, re.M | re.S)
    assert m, f"README has no section for tl-eval {command}"
    return m.group(1)


def _documented(command: str) -> list[str]:
    """The first cell of every flag-table row in the command's section."""
    return re.findall(r"^\| `([^`]+)` \|", _section(command), re.M)


def _params(command: str) -> set[str]:
    names = set()
    for p in COMMANDS[command].params:
        names.update(p.opts if p.param_type_name == "option" else [p.name.upper()])
    return names


@pytest.mark.parametrize("command", sorted(REQUIRED))
def test_every_required_flag_is_documented(command):
    documented = _documented(command)
    assert set(REQUIRED[command]) <= set(documented), set(REQUIRED[command]) - set(documented)


@pytest.mark.parametrize("command", sorted(REQUIRED))
def test_every_documented_flag_exists(command):
    assert set(_documented(command)) <= _params(command)
    result = CliRunner().invoke(run.app, [command, "--help"], terminal_width=200, env={"COLUMNS": "200"})
    assert result.exit_code == 0, result.output
    for flag in _documented(command):
        if flag.startswith("--"):
            assert flag in result.output, f"{flag} missing from tl-eval {command} --help"


def test_calibrate_csv_header_is_the_one_load_labels_reads():
    assert "run,id,sample,criterion,human" in _section("calibrate")


def test_the_ship_plan_gate_invocation_is_documented():
    gate = re.compile(r"tl-eval generate .*--samples 5 --greedy --system served", re.S)
    assert gate.search(README.split("### `tl-eval generate`")[0])
    assert "--samples 5 --greedy --system served" in KAGGLE
