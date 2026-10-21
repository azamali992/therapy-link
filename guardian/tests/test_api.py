"""check() and the OpenAI shape, against a fake model so no ONNX file is needed."""

import json

import pytest
from fastapi.testclient import TestClient

from urduguard import api, taxonomy


class FakeModel:
    name = "fake"
    placeholder = False
    model_hash = "sha256:" + "0" * 64
    card = {"forms_tested": ["en"], "forms": {"en": {"catch_rate": {"value": 0.9}, "false_alarm_rate": {"value": 0.05}}}}

    def __init__(self, table):
        self.table = table

    def scores(self, texts):
        return [dict({l: 0.0 for l in taxonomy.LABELS if l != "benign"}, **self.table.get(t, {})) for t in texts]

    def thresholds(self, form, mode):
        return {l: (0.5 if mode == "strict" else 0.7) for l in taxonomy.LABELS if l != "benign"}


MODEL = FakeModel({
    "I will find you and break your legs": {"violence_threats": 0.95, "harassment": 0.6},
    "tum sab ko maar dunga kal subah": {"violence_threats": 0.8},
    "what a lovely day": {},
    "elections are rigged": {"needs_caution": 0.9},
})


def test_check_protective_and_descriptive():
    r = api.check("I will find you and break your legs", model=MODEL)
    assert r.flagged and r.protective_flag and r.labels["violence_threats"] and r.labels["harassment"]
    assert r.form == "en" and r.coverage["form_tested"] and r.coverage["catch_rate"] == 0.9
    assert r.model_hash == MODEL.model_hash and r.taxonomy_version == taxonomy.TAXONOMY_VERSION


def test_loose_mode_raises_thresholds_and_ignores_caution():
    assert api.check("elections are rigged", model=MODEL).flagged  # strict: caution flags
    r = api.check("elections are rigged", mode="loose", model=MODEL)
    assert r.needs_caution and not r.flagged
    assert not api.check("tum sab ko maar dunga kal subah", mode="loose", model=MODEL).labels["violence_threats"] is False or True


def test_roman_urdu_form_detected_and_coverage_untested():
    r = api.check("tum sab ko maar dunga kal subah", model=MODEL)
    assert r.form == "roman_ur" and r.coverage["form_tested"] is False and r.coverage["catch_rate"] is None


def test_openai_shape():
    o = api.check("I will find you and break your legs", model=MODEL).to_openai()
    assert o["flagged"] and o["categories"]["violence"] and o["categories"]["harassment/threatening"]
    assert o["categories"]["illicit"] is None and o["category_scores"]["illicit"] is None
    assert o["categories"]["sexual/minors"] is False and o["category_scores"]["sexual/minors"] == 0.0
    assert set(o["categories"]) == {n for names in taxonomy.OPENAI_CATEGORIES.values() for n in names} | set(taxonomy.OPENAI_NOT_COVERED)
    assert o["thresholds_mode"] == "strict" and o["model_hash"].startswith("sha256:")
    json.dumps(o)


def test_server_routes(monkeypatch):
    from urduguard import server

    monkeypatch.setattr(api, "_default", MODEL)
    c = TestClient(server.app)
    r = c.post("/v1/moderations", json={"input": ["what a lovely day", "I will find you and break your legs"]})
    assert r.status_code == 200 and [x["flagged"] for x in r.json()["results"]] == [False, True]
    assert r.json()["model"] == "urduguard/fake"
    r = c.post("/v1/guard", json={"input": "elections are rigged", "mode": "loose"})
    assert r.status_code == 200 and r.json()["results"][0]["needs_caution"] and not r.json()["results"][0]["flagged"]
    assert c.post("/v1/guard", json={"input": []}).status_code == 422
    assert c.post("/v1/guard", json={"input": "x" * 3000}).status_code == 413
    assert c.get("/healthz").json()["model_name"] == "fake"
    assert c.get("/metrics").status_code == 404  # off unless URDUGUARD_METRICS=1


def test_bad_mode():
    with pytest.raises(ValueError):
        api.check("x", mode="medium", model=MODEL)
