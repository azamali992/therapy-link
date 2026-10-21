import math

from urduguard.eval import metrics


def _rows():
    rows = []
    for i in range(40):
        prot = i < 20
        for form in ("en", "roman_ur"):
            rows.append({"id": f"{i}-{form}", "text": "", "form": form, "labels": ["violence_threats"] if prot else ["benign"],
                         "provenance": {"source_id": str(i)}})
    return rows


def test_wilson_bounds():
    lo, hi = metrics.wilson(19, 20)
    assert 0.75 < lo < 0.95 and hi <= 1.0
    assert all(math.isnan(x) for x in metrics.wilson(0, 0))


def test_rates_and_gaps_perfect_parity():
    rows = _rows()
    flagged = {r["id"]: r["labels"] != ["benign"] for r in rows}
    per = metrics.rates(rows, flagged)
    assert per["en"]["catch_rate"]["value"] == 1.0 and per["roman_ur"]["false_alarm_rate"]["value"] == 0.0
    gap = metrics.gaps(rows, flagged, resamples=200)
    assert gap["roman_ur"]["catch_gap"]["value"] == 0.0 and gap["roman_ur"]["catch_gap"]["ci95"] == [0.0, 0.0]
    v = metrics.verdicts(per, gap)["roman_ur"]
    assert v["R1"]["status"] == v["R2"]["status"] == v["R3"]["status"] == "cleared" and v["R4"]["status"] == "not_applicable"


def test_urdu_regression_is_not_cleared():
    rows = _rows()
    # English catches everything, Roman Urdu misses 8 of 20: a 40 point gap
    flagged = {r["id"]: (r["labels"] != ["benign"]) and not (r["form"] == "roman_ur" and int(r["id"].split("-")[0]) < 8) for r in rows}
    per = metrics.rates(rows, flagged)
    gap = metrics.gaps(rows, flagged, resamples=300)
    v = metrics.verdicts(per, gap)["roman_ur"]
    assert v["R1"]["status"] == "not_cleared" and gap["roman_ur"]["catch_gap"]["value"] == 40.0
    assert v["R2"]["status"] == "not_cleared"  # 60% point, lower bound well under 70
    assert v["R3"]["status"] == "cleared"


def test_r4_uses_previous_release():
    rows = _rows()
    flagged = {r["id"]: r["labels"] != ["benign"] for r in rows}
    per = metrics.rates(rows, flagged)
    previous = {"en": {"catch_rate": {"value": 1.0}}, "roman_ur": {"catch_rate": {"value": 1.0}}}
    v = metrics.verdicts(per, metrics.gaps(rows, flagged, resamples=50), previous)["roman_ur"]
    assert v["R4"]["status"] == "cleared" and v["R4"]["measured"] == 0.0
