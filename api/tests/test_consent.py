from datetime import UTC, datetime, timedelta

from sqlalchemy import update

from tests.conftest import as_user, linked, verified_clinician, verify_clinician
from therapylink_api import db
from therapylink_api.models import JournalEntry, SharedSummary


async def test_unverified_clinician_cannot_see_caseload(client):
    r = await client.post("/me/clinician", json={"license_no": "PMC-123"}, headers=as_user("doc"))
    assert r.status_code == 201 and r.json()["role"] == "clinician" and r.json()["clinician_verified"] is False
    r = await client.get("/clinician/patients", headers=as_user("doc"))
    assert r.status_code == 403
    assert (await client.get("/clinician/requests", headers=as_user("doc"))).status_code == 403


async def test_leaving_clinician_mode_keeps_approval(client):
    await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=as_user("doc"))
    await verify_clinician("doc")
    r = await client.delete("/me/clinician", headers=as_user("doc"))
    assert r.status_code == 200 and r.json()["role"] == "patient"
    assert (await client.get("/clinician/patients", headers=as_user("doc"))).status_code == 403
    r = await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=as_user("doc"))
    assert r.json()["role"] == "clinician" and r.json()["clinician_verified"] is True


async def test_changing_licence_needs_fresh_verification(client):
    await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=as_user("doc"))
    await verify_clinician("doc")
    r = await client.post("/me/clinician", json={"license_no": "PMC-2"}, headers=as_user("doc"))
    assert r.json()["clinician_verified"] is False


async def test_overview_only_exposes_consented_sections(client):
    await verified_clinician(client)
    await client.get("/me", headers=as_user("pat"))
    await client.post("/assessments", json={"instrument": "phq9", "answers": [1] * 9}, headers=as_user("pat"))
    link_id = await linked(client, "pat")
    await client.post("/journal", json={"body": "rough day"}, headers=as_user("pat"))

    r = await client.get("/clinician/patients/pat", headers=as_user("doc"))
    assert r.status_code == 200
    body = r.json()
    assert body["assessments"] is None and body["journal"] is None and body["mood_trend"] is None

    await client.patch(f"/care/links/{link_id}/consent", json={"share_assessments": True}, headers=as_user("pat"))
    body = (await client.get("/clinician/patients/pat", headers=as_user("doc"))).json()
    assert body["assessments"][0]["score"] == 9 and body["journal"] is None

    await client.delete(f"/care/links/{link_id}", headers=as_user("pat"))
    r = await client.get("/clinician/patients/pat", headers=as_user("doc"))
    assert r.status_code == 404


async def test_links_stay_pending_until_the_clinician_accepts(client):
    code = await verified_clinician(client)
    r = await client.post("/care/links", json={"code": code}, headers=as_user("pat"))
    assert r.status_code == 201 and r.json()["status"] == "pending"
    link_id = r.json()["id"]
    await client.patch(f"/care/links/{link_id}/consent", json={"share_assessments": True}, headers=as_user("pat"))

    # Consent flags on a pending link open nothing.
    assert (await client.get("/clinician/patients/pat", headers=as_user("doc"))).status_code == 404
    assert (await client.get("/clinician/patients", headers=as_user("doc"))).json() == []
    reqs = (await client.get("/clinician/requests", headers=as_user("doc"))).json()
    assert [(q["link_id"], q["patient"]["uid"]) for q in reqs] == [(link_id, "pat")]

    # Only the clinician it was sent to can answer it.
    await verified_clinician(client, "other-doc")
    assert (await client.post(f"/clinician/requests/{link_id}/accept", headers=as_user("other-doc"))).status_code == 404
    assert (await client.post(f"/clinician/requests/{link_id}/accept", headers=as_user("pat"))).status_code == 403

    r = await client.post(f"/clinician/requests/{link_id}/accept", headers=as_user("doc"))
    assert r.status_code == 200 and r.json()["status"] == "active"
    assert (await client.get("/clinician/requests", headers=as_user("doc"))).json() == []
    assert (await client.get("/clinician/patients/pat", headers=as_user("doc"))).status_code == 200
    # Accepting twice is not a thing.
    assert (await client.post(f"/clinician/requests/{link_id}/accept", headers=as_user("doc"))).status_code == 404


async def test_declined_requests_open_nothing_and_can_be_asked_again(client):
    code = await verified_clinician(client)
    link_id = await linked(client, "pat", accept=False, journal=True)
    r = await client.post(f"/clinician/requests/{link_id}/decline", headers=as_user("doc"))
    assert r.status_code == 200 and r.json()["status"] == "revoked" and r.json()["share_journal"] is False
    assert (await client.get("/clinician/patients/pat", headers=as_user("doc"))).status_code == 404

    r = await client.post("/care/links", json={"code": code}, headers=as_user("pat"))
    assert r.status_code == 201 and r.json()["id"] == link_id and r.json()["status"] == "pending"


async def test_raw_clinician_uids_no_longer_link(client):
    await verified_clinician(client)
    assert (await client.post("/care/links", json={"clinician_uid": "doc"}, headers=as_user("pat"))).status_code == 422
    # A uid pasted into the code box isn't a code either.
    assert (await client.post("/care/links", json={"code": "doc"}, headers=as_user("pat"))).status_code == 404


async def _backdate(model, text: str, days: int) -> None:
    async with db.sessionmaker()() as s:
        col = model.body if model is JournalEntry else model.content
        await s.execute(update(model).where(col == text).values(created_at=datetime.now(UTC) - timedelta(days=days)))
        await s.commit()


async def test_sharing_starts_at_the_link_and_never_reaches_back(client):
    await verified_clinician(client)
    await client.post("/journal", json={"body": "written in private"}, headers=as_user("pat"))
    await client.post("/summaries", json={"kind": "weekly", "content": "old week"}, headers=as_user("pat"))
    await _backdate(JournalEntry, "written in private", 3)
    await _backdate(SharedSummary, "old week", 3)

    link_id = await linked(client, "pat", journal=True, summaries=True)
    await client.post("/journal", json={"body": "after linking"}, headers=as_user("pat"))
    await client.post("/summaries", json={"kind": "weekly", "content": "new week"}, headers=as_user("pat"))

    body = (await client.get("/clinician/patients/pat", headers=as_user("doc"))).json()
    assert [j["body"] for j in body["journal"]] == ["after linking"]
    assert [s["content"] for s in body["summaries"]] == ["new week"]
    assert body["consent"]["shared_from"] is not None
    # The patient still sees everything they wrote.
    assert len((await client.get("/journal", headers=as_user("pat"))).json()) == 2

    links = (await client.get("/care/links", headers=as_user("pat"))).json()
    assert [link["id"] for link in links] == [link_id]


async def test_patient_cannot_read_another_patients_journal(client):
    r = await client.post("/journal", json={"body": "private"}, headers=as_user("a"))
    entry_id = r.json()["id"]
    r = await client.put(f"/journal/{entry_id}", json={"body": "hacked"}, headers=as_user("b"))
    assert r.status_code == 404


async def test_assessment_delta_against_previous(client):
    await client.post("/assessments", json={"instrument": "gad7", "answers": [2] * 7}, headers=as_user("p"))
    r = await client.post("/assessments", json={"instrument": "gad7", "answers": [1] * 7}, headers=as_user("p"))
    assert r.json()["score"] == 7 and r.json()["delta"] == -7
