from tests.conftest import as_user, linked, verified_clinician, verify_clinician
from therapylink_api import db
from therapylink_api.models import ClinicianProfile


async def test_assessment_records_the_locale_it_was_answered_in(client):
    await client.patch("/me", json={"locale": "ur"}, headers=as_user("pat"))
    r = await client.post("/assessments", json={"instrument": "phq9", "answers": [0] * 9}, headers=as_user("pat"))
    assert r.status_code == 201 and r.json()["locale"] == "ur"  # falls back to the app language
    r = await client.post(
        "/assessments", json={"instrument": "gad7", "answers": [0] * 7, "locale": "en"}, headers=as_user("pat")
    )
    assert r.json()["locale"] == "en"
    assert [a["locale"] for a in (await client.get("/assessments", headers=as_user("pat"))).json()] == ["en", "ur"]
    bad = {"instrument": "gad7", "answers": [0] * 7, "locale": "fr"}
    assert (await client.post("/assessments", json=bad, headers=as_user("pat"))).status_code == 422


async def test_clinician_sees_the_locale_in_overview_and_caseload(client):
    await verified_clinician(client)
    await linked(client, "pat", assessments=True)
    await client.post(
        "/assessments", json={"instrument": "phq9", "answers": [1] * 9, "locale": "ur"}, headers=as_user("pat")
    )
    overview = (await client.get("/clinician/patients/pat", headers=as_user("doc"))).json()
    assert overview["assessments"][0]["locale"] == "ur"
    [row] = (await client.get("/clinician/patients", headers=as_user("doc"))).json()
    assert row["latest"][0]["locale"] == "ur"


async def test_patient_link_shows_the_clinicians_name_and_approval(client):
    await verified_clinician(client)
    await client.patch("/me", json={"display_name": "Dr Ayesha"}, headers=as_user("doc"))
    link_id = await linked(client, "pat", accept=False)

    [link] = (await client.get("/care/links", headers=as_user("pat"))).json()
    assert (link["id"], link["clinician_name"], link["clinician_verified"]) == (link_id, "Dr Ayesha", True)

    # Approval withdrawn: the patient can see it on the link.
    async with db.sessionmaker()() as s:
        (await s.get(ClinicianProfile, "doc")).verified_at = None
        await s.commit()
    [link] = (await client.get("/care/links", headers=as_user("pat"))).json()
    assert link["clinician_verified"] is False

    await verify_clinician("doc")
    r = await client.patch(f"/care/links/{link_id}/consent", json={"share_journal": True}, headers=as_user("pat"))
    assert r.json()["clinician_name"] == "Dr Ayesha" and r.json()["share_journal"] is True
