from __future__ import annotations

from datasets import DatasetDict, load_dataset

PARQUET_REF = "refs/convert/parquet"


def load_hf(hf_id: str, name: str | None = None, split: str | None = None):
    """load_dataset that survives datasets>=3 dropping loading scripts.

    Older hub datasets still ship a `<name>.py`; the hub keeps an auto-converted parquet copy
    under refs/convert/parquet, so retry there when the script path is refused.
    """
    try:
        return load_dataset(hf_id, name, split=split)
    except RuntimeError as e:
        if "scripts are no longer supported" not in str(e):
            raise
    ds = load_dataset(hf_id, name, split=split, revision=PARQUET_REF)
    if isinstance(ds, DatasetDict):
        # The parquet branch names splits "<config>.<split>" or keeps them plain, depending on age.
        ds = DatasetDict({k.split(".")[-1]: v for k, v in ds.items()})
    return ds
