from tests.conftest import as_user, linked, verify_clinician
from therapylink_api.invite import ALPHABET, LENGTH
from therapylink_api.models import Instrument
from therapylink_api.scoring import attention


async def _clinician(client, uid: str = "doc", verify: bool = True) -> str:
    await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=as_user(uid))
    if verify:
        await verify_clinician(uid)
    return (await client.get("/me", headers=as_user(uid))).json()["invite_code"]


async def test_patient_links_with_a_typed_code(client):
    code = await _clinician(client)
    assert len(code) == LENGTH and set(code) <= set(ALPHABET)
    typed = f"{code[:3].lower()}-{code[3:]}"
    r = await client.post("/care/links", json={"code": typed}, headers=as_user("pat"))
    assert r.status_code == 201 and r.json()["clinician_uid"] == "doc"
    assert (await client.get("/me", headers=as_user("pat"))).json()["invite_code"] is None


async def test_unverified_clinicians_code_is_refused(client):
    code = await _clinician(client, verify=False)
    assert code  # issued at sign-up, so it can go on a card before approval lands
    r = await client.post("/care/links", json={"code": code}, headers=as_user("pat"))
    assert r.status_code == 404


async def test_rotating_retires_the_old_code_but_keeps_patients(client):
    old = await _clinician(client)
    await linked(client, "p1")
    new = (await client.post("/me/clinician/code", headers=as_user("doc"))).json()["invite_code"]
    assert new and new != old
    assert (await client.post("/care/links", json={"code": old}, headers=as_user("p2"))).status_code == 404
    await linked(client, "p2")  # with the new code
    rows = (await client.get("/clinician/patients", headers=as_user("doc"))).json()
    assert {r["patient"]["uid"] for r in rows} == {"p1", "p2"}


async def test_self_links_and_empty_codes_are_refused(client):
    code = await _clinician(client)
    assert (await client.post("/care/links", json={"code": code}, headers=as_user("doc"))).status_code == 422
    assert (await client.post("/care/links", json={}, headers=as_user("pat"))).status_code == 422
    assert (await client.post("/care/links", json={"code": ""}, headers=as_user("pat"))).status_code == 422
    assert (await client.post("/me/clinician/code", headers=as_user("pat"))).status_code == 403


def test_attention_rules():
    assert attention(Instrument.phq9, "mild", None, ["suicidal_ideation_item"]) == ["risk_item"]
    assert attention(Instrument.gad7, "moderate", 4, []) == ["worsened"]
    assert attention(Instrument.phq9, "moderate", 4, []) == []  # below PHQ-9's 5-point threshold
    assert attention(Instrument.phq9, "severe", -3, []) == ["severe"]


async def test_caseload_puts_risk_first_and_hides_unshared_scores(client):
    await _clinician(client)
    for uid in ("calm", "risk", "hidden"):
        await linked(client, uid, **({} if uid == "hidden" else {"assessments": True}))
    await client.post("/assessments", json={"instrument": "gad7", "answers": [2] * 7}, headers=as_user("calm"))
    await client.post("/assessments", json={"instrument": "gad7", "answers": [1] * 7}, headers=as_user("calm"))
    await client.post("/assessments", json={"instrument": "phq9", "answers": [1] * 9}, headers=as_user("risk"))
    await client.post("/assessments", json={"instrument": "phq9", "answers": [3] * 9}, headers=as_user("hidden"))

    rows = (await client.get("/clinician/patients", headers=as_user("doc"))).json()
    assert [r["patient"]["uid"] for r in rows] == ["risk", "calm", "hidden"]
    risk, calm, hidden = rows
    assert risk["attention"] == ["risk_item"] and risk["latest"][0]["instrument"] == "phq9"
    assert calm["attention"] == [] and calm["latest"][0]["score"] == 7 and calm["latest"][0]["delta"] == -7
    assert hidden["shares_assessments"] is False and hidden["latest"] == [] and hidden["attention"] == []
