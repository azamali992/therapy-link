from sqlalchemy import func, select

from tests.conftest import as_user, linked, verified_clinician
from therapylink_api import db
from therapylink_api.models import AccessLog


async def test_overview_and_caseload_reads_are_logged_for_the_patient(client):
    await verified_clinician(client)
    await client.patch("/me", json={"display_name": "Dr Ayesha"}, headers=as_user("doc"))
    await linked(client, "pat", assessments=True, journal=True)
    await linked(client, "quiet")

    assert (await client.get("/clinician/patients", headers=as_user("doc"))).status_code == 200
    assert (await client.get("/clinician/patients/pat", headers=as_user("doc"))).status_code == 200

    log = (await client.get("/me/access-log", headers=as_user("pat"))).json()
    assert [(e["action"], e["sections"]) for e in log] == [
        ("overview", ["assessments", "journal"]),
        ("caseload", ["assessments"]),
    ]
    assert {e["clinician_uid"] for e in log} == {"doc"} and log[0]["clinician_name"] == "Dr Ayesha"

    quiet = (await client.get("/me/access-log", headers=as_user("quiet"))).json()
    assert [(e["action"], e["sections"]) for e in quiet] == [("caseload", [])]
    assert (await client.get("/me/access-log", headers=as_user("stranger"))).json() == []


async def test_refused_reads_are_not_logged_as_access(client):
    await verified_clinician(client)
    assert (await client.get("/clinician/patients/nobody", headers=as_user("doc"))).status_code == 404
    async with db.sessionmaker()() as s:
        assert await s.scalar(select(func.count()).select_from(AccessLog)) == 0


async def test_the_log_outlives_account_deletion_and_is_in_the_export(client):
    await verified_clinician(client)
    await linked(client, "pat", mood_trend=True)
    await client.get("/clinician/patients/pat", headers=as_user("doc"))

    export = (await client.get("/me/export", headers=as_user("pat"))).json()
    assert [(e["clinician_uid"], e["sections"]) for e in export["access_log"]] == [("doc", ["mood_trend"])]

    assert (await client.delete("/me", headers=as_user("doc"))).status_code == 204
    log = (await client.get("/me/access-log", headers=as_user("pat"))).json()
    assert [e["clinician_uid"] for e in log] == ["doc"] and log[0]["clinician_name"] is None
