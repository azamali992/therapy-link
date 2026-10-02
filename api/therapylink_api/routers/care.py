from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api.auth import Principal, current_principal
from therapylink_api.db import get_session
from therapylink_api.invite import normalise_code
from therapylink_api.models import CareLink, ClinicianProfile, LinkStatus, User
from therapylink_api.schemas import CareLinkIn, CareLinkOut, Consent

router = APIRouter(prefix="/care", tags=["care"])


async def _link_out(session: AsyncSession, link: CareLink) -> CareLinkOut:
    """Enrich a CareLink with the clinician's display name and verification status."""
    user = await session.get(User, link.clinician_uid)
    profile = await session.get(ClinicianProfile, link.clinician_uid)
    return CareLinkOut.model_validate(link).model_copy(
        update={
            "clinician_name": user.display_name if user else None,
            "clinician_verified": bool(profile and profile.verified_at),
        }
    )


async def _owned_link(session: AsyncSession, uid: str, link_id: str) -> CareLink:
    link = await session.get(CareLink, link_id)
    if link is None or link.patient_uid != uid:
        raise HTTPException(404, "link not found")
    return link


@router.get("/links", response_model=list[CareLinkOut])
async def my_links(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    links = (await session.scalars(select(CareLink).where(CareLink.patient_uid == p.uid))).all()
    return [await _link_out(session, lnk) for lnk in links]


@router.post("/links", response_model=CareLinkOut, status_code=201)
async def invite(body: CareLinkIn, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Patient initiates the relationship by typing the clinician's invite code.
    The link starts pending until the clinician accepts. Sharing flags start off."""
    code = normalise_code(body.code)
    profile = await session.scalar(select(ClinicianProfile).where(ClinicianProfile.invite_code == code))
    if profile is None or profile.verified_at is None:
        raise HTTPException(404, "no verified clinician found with that code")
    if profile.uid == p.uid:
        raise HTTPException(422, "cannot link to yourself")

    existing = await session.scalar(
        select(CareLink).where(CareLink.patient_uid == p.uid, CareLink.clinician_uid == profile.uid)
    )
    if existing:
        # Allow re-sending after a decline or revocation; already-active is idempotent.
        if existing.status == LinkStatus.active:
            return await _link_out(session, existing)
        existing.status = LinkStatus.pending
        # Clear share flags: clinician re-accepts on fresh terms.
        existing.share_assessments = False
        existing.share_mood_trend = False
        existing.share_summaries = False
        existing.share_journal = False
        existing.shared_from = None
        await session.commit()
        await session.refresh(existing)
        return await _link_out(session, existing)

    link = CareLink(patient_uid=p.uid, clinician_uid=profile.uid, status=LinkStatus.pending)
    session.add(link)
    await session.commit()
    await session.refresh(link)
    return await _link_out(session, link)


@router.patch("/links/{link_id}/consent", response_model=CareLinkOut)
async def set_consent(link_id: str, body: Consent, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    link = await _owned_link(session, p.uid, link_id)
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(link, k, v)
    await session.commit()
    await session.refresh(link)
    return await _link_out(session, link)


@router.delete("/links/{link_id}", response_model=CareLinkOut)
async def revoke(link_id: str, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    link = await _owned_link(session, p.uid, link_id)
    link.status = LinkStatus.revoked
    link.share_assessments = link.share_mood_trend = link.share_summaries = link.share_journal = False
    await session.commit()
    await session.refresh(link)
    return await _link_out(session, link)
