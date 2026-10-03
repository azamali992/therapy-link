"""The registry pins what Eve is served from. A wrong hash or a served rejected adapter must fail."""

import copy
import hashlib
import json

import pytest
from typer.testing import CliRunner

from therapylink_ml import prompts, registry

runner = CliRunner()


def _fake(tmp_path):
    """A registry pointing at two small files in tmp_path, built from the real one."""
    reg = copy.deepcopy(registry.load())
    base, adapter = registry.serving(reg)
    reg["base_models"] = [base]
    reg["adapters"] = [adapter]
    for e, content in ((base, b"base weights"), (adapter, b"adapter weights")):
        (tmp_path / e["file"]).write_bytes(content)
        e["sha256"] = hashlib.sha256(content).hexdigest()
        e["size_bytes"] = len(content)
    path = tmp_path / "registry.json"
    path.write_text(json.dumps(reg), encoding="utf-8")
    return reg, path


def test_the_real_registry_is_consistent():
    assert registry.check_structure(registry.load()) == []


def test_v16c_e2_is_served_with_the_v2_prompt_and_dpo_is_rejected():
    reg = registry.load()
    base, adapter = registry.serving(reg)
    assert adapter["id"] == "eve-sft-v16c-e2" and adapter["status"] == "candidate"
    assert base["file"] == "gemma-4-E2B-it-Q4_K_M.gguf"
    assert adapter["prompt_sha256"] == hashlib.sha256(prompts.SERVED_SYSTEM_PROMPT.encode()).hexdigest()
    assert adapter["prompt_sha256"].startswith("4ddd5346") and adapter["prompt_sha256"].endswith("c135202c")
    dpo = registry.by_id(reg)["eve-dpo-v16"]
    assert dpo["status"] == "rejected" and dpo["status_reason"]
    with pytest.raises(ValueError, match="rejected"):
        registry.serving(reg, "eve-dpo-v16")


def test_nothing_is_approved_until_a_clinician_signs():
    reg = registry.load()
    assert all(e["approved_by"] is None for e in registry.entries(reg))
    assert not any(registry.is_approved(e) for e in registry.entries(reg))


def test_every_registered_file_has_a_full_hash_and_size():
    for e in registry.entries(registry.load()):
        assert len(e["sha256"]) == 64 and int(e["sha256"], 16) >= 0, e["id"]
        assert e["size_bytes"] > 0, e["id"]


def test_structure_catches_a_drifted_prompt_and_a_bad_approval():
    reg = copy.deepcopy(registry.load())
    reg["prompts"]["eve-v2"]["sha256"] = "0" * 64
    reg["adapters"][0]["status"] = "approved"
    problems = "\n".join(registry.check_structure(reg))
    assert "prompt eve-v2" in problems
    assert "approved but approved_by is empty" in problems


def test_serving_a_rejected_adapter_is_a_structure_problem():
    reg = copy.deepcopy(registry.load())
    reg["serve"]["adapter"] = "eve-dpo-v16"
    assert any("rejected" in p for p in registry.check_structure(reg))


def test_verify_passes_on_matching_files(tmp_path):
    _, path = _fake(tmp_path)
    r = runner.invoke(registry.app, ["verify", "--registry", str(path), "--models-dir", str(tmp_path)])
    assert r.exit_code == 0, r.output
    assert "registry ok: 2 file(s)" in r.output


def test_verify_fails_on_a_changed_file(tmp_path):
    reg, path = _fake(tmp_path)
    adapter = reg["adapters"][0]
    (tmp_path / adapter["file"]).write_bytes(b"adapter weightz")  # same size, different bytes
    r = runner.invoke(registry.app, ["verify", "--registry", str(path), "--models-dir", str(tmp_path)])
    assert r.exit_code == 1
    assert "sha256" in r.output and adapter["id"] in r.output


def test_verify_fails_on_a_missing_file_unless_told_to_skip(tmp_path):
    reg, path = _fake(tmp_path)
    (tmp_path / reg["base_models"][0]["file"]).unlink()
    args = ["verify", "--registry", str(path), "--models-dir", str(tmp_path)]
    assert runner.invoke(registry.app, args).exit_code == 1
    assert runner.invoke(registry.app, [*args, "--skip-missing"]).exit_code == 0


def test_show_reports_the_served_pair_as_unapproved(tmp_path):
    _, path = _fake(tmp_path)
    r = runner.invoke(registry.app, ["show", "--registry", str(path)])
    assert r.exit_code == 0, r.output
    out = json.loads(r.output)
    assert out["adapter"]["id"] == "eve-sft-v16c-e2" and out["approved"] is False
