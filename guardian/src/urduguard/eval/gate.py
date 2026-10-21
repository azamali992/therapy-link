"""The release gate in its first form: fail if any form's catch rate drops more than 5 points against the
last tagged release, or if the eval-set exclusion check fails.

    python -m urduguard.eval.gate --report runs/eval/x/report.json --baseline tests/fixtures/gate_baseline.json
    python -m urduguard.eval.gate --report ... --baseline ... --write-baseline   # after a tag, record the new numbers
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MAX_DROP_POINTS = 5.0


def compare(report: dict, baseline: dict) -> list[str]:
    failures = []
    for form, base in baseline.get("per_form", {}).items():
        old = base["catch_rate"]["value"]
        new = (report["per_form"].get(form) or {}).get("catch_rate", {}).get("value")
        if old is None:
            continue
        if new is None:
            failures.append(f"{form}: no catch rate in the new report (baseline {100 * old:.1f}%)")
        elif 100 * (old - new) > MAX_DROP_POINTS:
            failures.append(f"{form}: catch rate fell {100 * (old - new):.1f} points ({100 * old:.1f}% -> {100 * new:.1f}%)")
    for form, v in report.get("verdicts", {}).items():
        for rule in ("R1", "R2", "R3"):
            if v[rule]["status"] == "not_cleared":
                failures.append(f"{form}: {rule} not cleared ({v[rule]})")
    return failures


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--ignore-verdicts", action="store_true", help="only check the drop against the baseline")
    a = ap.parse_args(argv)
    report = json.loads(Path(a.report).read_text(encoding="utf-8"))
    if a.write_baseline:
        Path(a.baseline).write_text(json.dumps({"backend": report["backend"], "date": report["date"], "per_form": report["per_form"]}, indent=1), encoding="utf-8")
        print(f"baseline written to {a.baseline}")
        return 0
    baseline = json.loads(Path(a.baseline).read_text(encoding="utf-8"))
    failures = compare(report, baseline)
    if a.ignore_verdicts:
        failures = [f for f in failures if "not cleared" not in f]
    for f in failures:
        print("GATE FAIL:", f)
    if not failures:
        print("gate passed:", ", ".join(f"{k} {100 * v['catch_rate']['value']:.1f}%" for k, v in report["per_form"].items() if v["catch_rate"]["value"] is not None))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
