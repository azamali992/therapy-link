from datetime import UTC, datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api.auth import Principal, current_principal
from therapylink_api.db import get_session
from therapylink_api.models import AccessLog, CareLink, ClinicianProfile, JournalEntry, LinkStatus, Role, SharedSummary, User
from therapylink_api.routers.assessments import list_for as assessments_for
from therapylink_api.routers.care import _link_out
from therapylink_api.routers.me import _me_out
from therapylink_api.routers.mood import trend_for, zone
from therapylink_api.schemas import CareLinkOut, CaseloadRow, MeOut, PatientOverview, RequestOut
from therapylink_api.scoring import attention

router = APIRouter(prefix="/clinician", tags=["clinician"])


async def _verified_clinician(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)) -> Principal:
    if p.role not in (Role.clinician, Role.admin):
        raise HTTPException(403, "clinician role required")
    profile = await session.get(ClinicianProfile, p.uid)
    if profile is None or profile.verified_at is None:
        raise HTTPException(403, "clinician not yet verified")
    return p


async def _active_link(session: AsyncSession, clinician_uid: str, patient_uid: str) -> CareLink:
    link = await session.scalar(
        select(CareLink).where(
            CareLink.clinician_uid == clinician_uid,
            CareLink.patient_uid == patient_uid,
            CareLink.status == LinkStatus.active,
        )
    )
    if link is None:
        raise HTTPException(404, "no active care link with this patient")
    return link


@router.get("/requests", response_model=list[RequestOut])
async def pending_requests(p: Principal = Depends(_verified_clinician), session: AsyncSession = Depends(get_session)):
    """Patients who have sent a care request that hasn't been accepted or declined yet."""
    links = (
        await session.scalars(
            select(CareLink)
            .where(CareLink.clinician_uid == p.uid, CareLink.status == LinkStatus.pending)
            .order_by(CareLink.created_at.asc())
        )
    ).all()
    result = []
    for lnk in links:
        patient = await session.get(User, lnk.patient_uid)
        if patient:
            result.append(RequestOut(link_id=lnk.id, patient=await _me_out(session, patient)))
    return result


@router.post("/requests/{link_id}/accept", response_model=CareLinkOut)
async def accept_request(link_id: str, p: Principal = Depends(_verified_clinician), session: AsyncSession = Depends(get_session)):
    """Accept a pending care request. Sets the link active and records shared_from = now."""
    link = await session.scalar(
        select(CareLink).where(
            CareLink.id == link_id,
            CareLink.clinician_uid == p.uid,
            CareLink.status == LinkStatus.pending,
        )
    )
    if link is None:
        raise HTTPException(404, "pending request not found")
    link.status = LinkStatus.active
    # Naive UTC with microseconds. JournalEntry and SharedSummary use _now_utc() as their
    # Python-side default, so their created_at values are also stored with microsecond
    # precision by SQLAlchemy's SQLite DATETIME bind_processor ('YYYY-MM-DD HH:MM:SS.ffffff').
    # Both sides of the WHERE created_at >= shared_from comparison therefore use the same
    # format, making SQLite string ordering correct even for same-second entries.
    link.shared_from = datetime.now(UTC).replace(tzinfo=None)
    await session.commit()
    await session.refresh(link)
    return await _link_out(session, link)


@router.post("/requests/{link_id}/decline", response_model=CareLinkOut)
async def decline_request(link_id: str, p: Principal = Depends(_verified_clinician), session: AsyncSession = Depends(get_session)):
    """Decline a pending care request. Clears share flags and sets status to revoked."""
    link = await session.scalar(
        select(CareLink).where(
            CareLink.id == link_id,
            CareLink.clinician_uid == p.uid,
            CareLink.status == LinkStatus.pending,
        )
    )
    if link is None:
        raise HTTPException(404, "pending request not found")
    link.status = LinkStatus.revoked
    link.share_assessments = False
    link.share_mood_trend = False
    link.share_summaries = False
    link.share_journal = False
    await session.commit()
    await session.refresh(link)
    return await _link_out(session, link)


@router.get("/patients", response_model=list[CaseloadRow])
async def caseload(p: Principal = Depends(_verified_clinician), session: AsyncSession = Depends(get_session)):
    """Active patients with their latest assessments and attention flags. Logs the read for each patient."""
    q = (
        select(User, CareLink)
        .join(CareLink, CareLink.patient_uid == User.uid)
        .where(CareLink.clinician_uid == p.uid, CareLink.status == LinkStatus.active)
        .order_by(User.uid)
    )
    rows = (await session.execute(q)).all()

    result: list[CaseloadRow] = []
    for user, link in rows:
        # Log this read for the patient.
        caseload_sections = ["assessments"] if link.share_assessments else []
        session.add(AccessLog(clinician_uid=p.uid, patient_uid=user.uid, action="caseload", sections=caseload_sections))

        patient_out = await _me_out(session, user)
        if link.share_assessments:
            assessments = await assessments_for(session, user.uid, None)
            # Latest one per instrument.
            seen: dict = {}
            latest = []
            for a in assessments:  # already sorted newest-first by list_for
                if a.instrument not in seen:
                    seen[a.instrument] = True
                    latest.append(a)
            # Compute attention from the most recent result (first entry after reversal).
            if latest:
                top = latest[0]
                att = attention(top.instrument, top.band, top.delta, top.flags)
            else:
                att = []
        else:
            latest = []
            att = []

        result.append(CaseloadRow(patient=patient_out, latest=latest, attention=att, shares_assessments=link.share_assessments))

    await session.commit()

    # Sort: patients with attention flags first, then by uid.
    result.sort(key=lambda r: (not bool(r.attention), r.patient.uid))
    return result


@router.get("/patients/{patient_uid}", response_model=PatientOverview)
async def overview(
    patient_uid: str,
    days: int = 30,
    tz: ZoneInfo = Depends(zone),
    p: Principal = Depends(_verified_clinician),
    session: AsyncSession = Depends(get_session),
):
    """Every section is present only if the patient turned that consent flag on.
    Journal and summaries are limited to content created after the clinician was accepted."""
    link = await _active_link(session, p.uid, patient_uid)
    patient = await session.get(User, patient_uid)
    out = PatientOverview(patient=await _me_out(session, patient), consent=await _link_out(session, link))

    sections: list[str] = []
    if link.share_assessments:
        out.assessments = await assessments_for(session, patient_uid, None)
        sections.append("assessments")
    if link.share_mood_trend:
        out.mood_trend = await trend_for(session, patient_uid, min(days, 365), tz)
        sections.append("mood_trend")
    if link.share_summaries:
        q = (
            select(SharedSummary)
            .where(SharedSummary.patient_uid == patient_uid)
            .order_by(SharedSummary.created_at.desc())
            .limit(20)
        )
        if link.shared_from:
            q = q.where(SharedSummary.created_at >= link.shared_from)
        out.summaries = list((await session.scalars(q)).all())
        sections.append("summaries")
    if link.share_journal:
        q = (
            select(JournalEntry)
            .where(JournalEntry.patient_uid == patient_uid)
            .order_by(JournalEntry.created_at.desc())
            .limit(50)
        )
        if link.shared_from:
            q = q.where(JournalEntry.created_at >= link.shared_from)
        out.journal = list((await session.scalars(q)).all())
        sections.append("journal")

    # Log the access after we know which sections were actually served.
    session.add(AccessLog(clinician_uid=p.uid, patient_uid=patient_uid, action="overview", sections=sections))
    await session.commit()
    return out
