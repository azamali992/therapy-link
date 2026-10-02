import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.concurrency import run_in_threadpool
from firebase_admin.exceptions import FirebaseError
from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api import firebase, requestid
from therapylink_api.auth import Identity, Principal, current_principal, erased_key, signed_in
from therapylink_api.db import Base, get_session
from therapylink_api.invite import new_code, unique_code
from therapylink_api.models import (
    AccessLog,
    Assessment,
    CareLink,
    ClinicianProfile,
    ErasedAccount,
    JournalEntry,
    MoodPoint,
    Role,
    SharedSummary,
    User,
)
from therapylink_api.schemas import BecomeClinician, ConsentIn, MeOut, MePatch
from therapylink_api.settings import get_settings

log = logging.getLogger(__name__)
router = APIRouter(prefix="/me", tags=["me"])


async def _me_out(session: AsyncSession, user: User) -> MeOut:
    profile = await session.get(ClinicianProfile, user.uid)
    return MeOut.model_validate(user).model_copy(
        update={
            "clinician_verified": bool(profile and profile.verified_at),
            "invite_code": profile.invite_code if profile else None,
        }
    )


@router.get("", response_model=MeOut)
async def get_me(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    user = await session.get(User, p.uid)
    return await _me_out(session, user)


@router.delete("", status_code=204)
async def delete_me(p: Identity = Depends(signed_in), session: AsyncSession = Depends(get_session)):
    """Erase the account. Deleting the users row cascades to everything the server holds for this
    uid, and the uid is tombstoned in the same commit so its still-valid tokens can't recreate the
    row. The sign-in account goes second, so a failure there leaves nothing behind but a login; this
    route skips the tombstone check, so the app can retry it."""
    await session.execute(delete(User).where(User.uid == p.uid))
    if not p.dev:
        await session.merge(ErasedAccount(uid_sha256=erased_key(p.uid)))
    await session.commit()
    log.info("account data deleted")
    if not p.dev:
        try:
            await run_in_threadpool(firebase.delete_user, p.uid)
        except FirebaseError:
            log.exception("firebase user deletion failed [request %s]", requestid.current())
            raise HTTPException(502, "your data is deleted but the sign-in account is not yet; try again") from None
    return Response(status_code=204)


def _row(obj: Base) -> dict:
    return {c.key: getattr(obj, c.key) for c in obj.__table__.columns}


@router.get("/export")
async def export_me(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Everything the server holds for this uid, column for column, so new columns can't be missed."""

    async def rows(model, *where) -> list[dict]:
        return [_row(r) for r in (await session.scalars(select(model).where(*where))).all()]

    user = await session.get(User, p.uid)
    profile = await session.get(ClinicianProfile, p.uid)
    return {
        "exported_at": datetime.now(UTC),
        "user": _row(user),
        "clinician_profile": _row(profile) if profile else None,
        "assessments": await rows(Assessment, Assessment.patient_uid == p.uid),
        "mood_points": await rows(MoodPoint, MoodPoint.patient_uid == p.uid),
        "journal_entries": await rows(JournalEntry, JournalEntry.patient_uid == p.uid),
        "shared_summaries": await rows(SharedSummary, SharedSummary.patient_uid == p.uid),
        "care_links": await rows(CareLink, or_(CareLink.patient_uid == p.uid, CareLink.clinician_uid == p.uid)),
        "access_log": await rows(AccessLog, AccessLog.patient_uid == p.uid),
    }


@router.get("/access-log")
async def access_log(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Which clinicians were shown my data, what sections they saw, and when. Newest first."""
    entries = (
        await session.scalars(select(AccessLog).where(AccessLog.patient_uid == p.uid).order_by(AccessLog.at.desc()))
    ).all()
    result = []
    for e in entries:
        clinician = await session.get(User, e.clinician_uid)
        result.append(
            {
                "clinician_uid": e.clinician_uid,
                "clinician_name": clinician.display_name if clinician else None,
                "action": e.action,
                "sections": e.sections,
                "at": e.at,
            }
        )
    return result


@router.patch("", response_model=MeOut)
async def patch_me(body: MePatch, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    user = await session.get(User, p.uid)
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(user, k, v)
    await session.commit()
    return await _me_out(session, user)


@router.put("/consent", response_model=MeOut)
async def accept_consent(body: ConsentIn, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Record that the user accepted this version of the consent screen. Accepting a new version
    moves the timestamp; accepting the same one again keeps the original."""
    user = await session.get(User, p.uid)
    if user.consent_version != body.consent_version or user.consent_accepted_at is None:
        user.consent_version, user.consent_accepted_at = body.consent_version, datetime.now(UTC)
        await session.commit()
    return await _me_out(session, user)


@router.post("/clinician", response_model=MeOut, status_code=201)
async def become_clinician(body: BecomeClinician, p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Registers as a clinician. Clinician endpoints stay closed until verified_at is set, by
    scripts/verify_clinician.py or, in local demos, TL_DEV_AUTO_VERIFY_CLINICIANS."""
    user = await session.get(User, p.uid)
    profile = await session.get(ClinicianProfile, p.uid) or ClinicianProfile(uid=p.uid)
    if profile.license_no is not None and profile.license_no != body.license_no:
        profile.verified_at = None  # the approval was for a different licence
    profile.license_no, profile.specialty, profile.bio = body.license_no, body.specialty, body.bio
    if profile.invite_code is None:
        profile.invite_code = await unique_code(session)
    if profile.verified_at is None and get_settings().dev_auto_verify_clinicians and user.email_verified:
        profile.verified_at = datetime.now(UTC)
    if user.role == Role.patient:
        user.role = Role.clinician
    session.add(profile)
    await session.commit()
    return await _me_out(session, user)


@router.post("/clinician/code", response_model=MeOut)
async def rotate_invite_code(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Generate a new invite code and retire the old one. Existing patients are not affected."""
    if p.role not in (Role.clinician, Role.admin):
        raise HTTPException(403, "clinician role required")
    profile = await session.get(ClinicianProfile, p.uid)
    if profile is None:
        raise HTTPException(403, "clinician profile not found")
    profile.invite_code = await unique_code(session)
    await session.commit()
    user = await session.get(User, p.uid)
    return await _me_out(session, user)


@router.delete("/clinician", response_model=MeOut)
async def leave_clinician(p: Principal = Depends(current_principal), session: AsyncSession = Depends(get_session)):
    """Back to the patient experience. The profile and its approval are kept, so returning with the
    same licence doesn't wait for verification again."""
    user = await session.get(User, p.uid)
    if user.role == Role.clinician:
        user.role = Role.patient
        await session.commit()
    return await _me_out(session, user)
