"""The Kaggle notebooks are where a flag typo costs a GPU session, so check them without running them."""

import json
import re
from pathlib import Path

import typer.main

from therapylink_ml.train import eos_check, eve_dpo, eve_sft

NOTEBOOKS = Path(__file__).resolve().parents[1] / "notebooks"


def _cells(name: str) -> dict[str, str]:
    nb = json.loads((NOTEBOOKS / name).read_text(encoding="utf-8"))
    return {c.get("id", str(i)): "".join(c["source"]) for i, c in enumerate(nb["cells"])}


def _options(app, sub: str | None = None) -> set[str]:
    cmd = typer.main.get_command(app)
    if sub:
        cmd = cmd.commands[sub]
    return {opt for p in cmd.params for opt in (*p.opts, *p.secondary_opts)}


def _flags(text: str, module: str) -> list[set[str]]:
    """The --flags of every command line in `text` that runs `module`."""
    text = text.replace("\\\n", " ")  # join shell line continuations
    return [set(re.findall(r"(--[a-z][\w-]*)", line)) for line in text.splitlines() if f"-m {module}" in line]


def test_every_notebook_parses():
    for path in NOTEBOOKS.glob("*.ipynb"):
        nb = json.loads(path.read_text(encoding="utf-8"))
        assert nb["cells"] and all("source" in c for c in nb["cells"]), path.name


def test_v17_clean_is_commercial_clean_with_the_v16_flags():
    clean = _flags(_cells("eve_sft_kaggle.ipynb")["v17-clean"], "therapylink_ml.train.eve_sft")
    assert len(clean) == 1
    assert {"--exclude-nc", "--min-quality", "--mentalchat-max-words", "--val-size", "--epochs", "--notes-frac", "--no-gguf"} <= clean[0]
    text = _cells("eve_sft_kaggle.ipynb")["v17-clean"]
    # More data, not more epochs (v16-clean's val loss rose in epoch 2).
    assert "--epochs 2" in text and "tl_authored=" in text and "eve-sft-e2b-v17-clean" in text
    assert not re.search(r"esconv|counselchat|empathetic", text.split("-m therapylink_ml")[1])
    # The red-line rows passed only by the AI clinical review train only with the explicit opt-in.
    assert "TL_ACCEPT_AI_CLINICAL_REVIEW=1 python" in text


def test_full_control_is_off_keeps_the_nc_sources_and_never_decides_the_version():
    # Off since v17 (it cost 4.6 h in v16 and can't ship). It trains the non-commercial sources back
    # in, so it may inform a decision but never ships: only the clean run's gate fails the version.
    cells = _cells("eve_sft_kaggle.ipynb")
    text = cells["full-control"]
    assert "RUN_FULL_CONTROL = False" in text
    (flags,) = _flags(text, "therapylink_ml.train.eve_sft")
    assert "--exclude-nc" not in flags and "esconv=0.5" in text and "counselchat=1.5" in text
    final = [t for t in cells.values() if "raise RuntimeError" in t and "GATES" in t]
    assert len(final) == 1 and "GATES.get(RUN" in final[0] and "FULL" not in final[0]
    # A clean-run failure must not stop the control from training.
    assert not re.search(r"^\s*raise\b", cells["gate"], re.M)


def test_smoke_run_uses_real_trainer_flags_and_checks_every_save():
    smoke = next(t for t in _cells("eve_sft_kaggle.ipynb").values() if "RUN_SMOKE = True" in t)
    used = set(re.findall(r"'(--[a-z][\w-]*)'", smoke))
    assert used and used <= _options(eve_sft.app)
    assert all(f"'{d}'" in smoke for d in ("adapter-epoch1", "adapter-epoch2", "adapter"))


def test_both_epoch_adapters_are_gated():
    gate = _cells("eve_sft_kaggle.ipynb")["gate"]
    assert "adapter-epoch" in gate and "therapylink_ml.train.eos_check" in gate
    assert "gate(RUN)" in gate


def test_validation_split_is_copied_for_the_val_flag():
    assert any("conversations.val.jsonl" in text for text in _cells("eve_sft_kaggle.ipynb").values())


def test_every_flag_in_the_notebooks_exists_on_the_cli():
    sft, dpo = _options(eve_sft.app), _options(eve_dpo.app, "train")
    for name in ("eve_sft_kaggle.ipynb", "eve_sft_continue_kaggle.ipynb", "eve_dpo_kaggle.ipynb"):
        for text in _cells(name).values():
            for flags in _flags(text, "therapylink_ml.train.eve_sft"):
                assert flags <= sft, (name, flags - sft)
            for flags in _flags(text, "therapylink_ml.train.eve_dpo train"):
                assert flags <= dpo, (name, flags - dpo)


def test_dpo_notebook_uses_the_fixed_trainer_and_finds_a_flattened_adapter():
    cells = _cells("eve_dpo_kaggle.ipynb")
    setup = next(t for t in cells.values() if "glob" in t and "adapter" in t)
    # Kaggle flattens a dataset's single top-level folder: glob for the files, not adapter/.
    assert "**/adapter_config.json" in setup and "adapter_model.safetensors" in setup
    assert "**/adapter/adapter_config.json" not in setup
    # The run goes through run_dpo.py, which turns the datasets cache off, then runs eve_dpo.
    (line,) = [ln for ln in cells["train"].splitlines() if "run_dpo.py train" in ln]
    flags = set(re.findall(r"(--[a-z][\w-]*)", line))
    assert {"--rpo-alpha", "--epochs", "--max-length", "--eval-frac"} <= flags <= _options(eve_dpo.app, "train")
    wrapper = next(t for t in cells.values() if "RUN_DPO = " in t)
    assert "datasets.disable_caching()" in wrapper and "run_module('therapylink_ml.train.eve_dpo'" in wrapper
    assert "os.environ['CUDA_VISIBLE_DEVICES'] = '0'" in wrapper
    assert not any("build-pairs" in t and "hf:" in t for t in cells.values())
    assert "eos_check" in cells["gate"] and "check=True" in cells["gate"]


def test_eos_check_takes_the_adapter_as_its_only_argument():
    assert _options(eos_check.app) >= {"--prompt", "--out"}


def test_dpo_smoke_runs_before_the_real_run_with_real_flags():
    cells = list(_cells("eve_dpo_kaggle.ipynb").values())
    smoke = next(i for i, t in enumerate(cells) if "DPO smoke OK" in t)
    real = next(i for i, t in enumerate(cells) if "--pairs data/processed/dpo_pairs.jsonl" in t)
    assert smoke < real
    used = set(re.findall(r"'(--[a-z][\w-]*)'", cells[smoke]))
    assert used and used <= _options(eve_dpo.app, "train")
    # 0 would fire the margin check on the first logged step and abort the smoke run.
    assert "'--margin-check-steps', '0'" not in cells[smoke]


def test_dpo_refuses_a_pre_v16_adapter_and_stale_code():
    setup = next(t for t in _cells("eve_dpo_kaggle.ipynb").values() if "shutil.copytree(adapters[0]" in t)
    assert "training_prompt.json" in setup and "stale code" in setup and "n_pairs >= 100" in setup


def test_dpo_trl_patch_compiles():
    # trl 0.24 + transformers 5.x: the optional-package check returns a truthy tuple. The notebook
    # patches trl's installed file; a newline escaped wrongly once broke this block, so compile it.
    setup = next(t for t in _cells("eve_dpo_kaggle.ipynb").values() if "_tl_bool_is_package_available" in t)
    block = setup[setup.index("import importlib.util, os"):setup.index("print('patched', _iu)")]
    compile(block, "dpo-setup", "exec")
