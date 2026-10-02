import json

import pytest
import typer

from therapylink_ml.export.merge import float_base, merge


def test_unsloth_4bit_bases_map_to_their_float_repo():
    # What v14 and v15 recorded in adapter_config.json.
    assert float_base("unsloth/gemma-4-e2b-it-unsloth-bnb-4bit") == "unsloth/gemma-4-E2B-it"
    assert float_base("unsloth/gemma-4-E4B-it-unsloth-bnb-4bit") == "unsloth/gemma-4-E4B-it"


def test_float_bases_pass_through():
    assert float_base("unsloth/gemma-4-E2B-it") == "unsloth/gemma-4-E2B-it"
    assert float_base("google/gemma-4-e2b-it") == "google/gemma-4-e2b-it"


def test_unknown_quantised_bases_fail_with_a_way_out():
    with pytest.raises(ValueError, match="--base"):
        float_base("someone/qwen3.5-4b-bnb-4bit")


def test_merge_refuses_a_quantised_override_before_loading_anything(tmp_path):
    (tmp_path / "adapter_config.json").write_text(json.dumps({"base_model_name_or_path": "x/y-bnb-4bit"}), encoding="utf-8")
    with pytest.raises(typer.BadParameter, match="quantised"):
        merge(adapter=tmp_path, out=tmp_path / "out", base="", dtype="float32")
