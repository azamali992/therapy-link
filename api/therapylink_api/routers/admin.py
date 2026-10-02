"""Admin-only clinician management.

All routes require a Firebase ID token that carries the custom claim ``admin: true``.
No database credential is needed — the Firebase Admin SDK handles auth.

Usage:
    POST /admin/clinicians/{uid}/verify   — approve a clinician profile
    POST /admin/clinicians/{uid}/revoke   — remove approval
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from firebase_admin import auth as firebase_auth
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api import firebase, requestid
from therapylink_api.db import get_session
from therapylink_api.models import AccessLog, ClinicianProfile, User

log = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])


async def _admin_identity(request: Request) -> str:
    """Verify the bearer token and confirm the ``admin: true`` custom claim.

    Returns the admin's uid on success.  Never uses the dev bypass so that admin routes
    are always real-Firebase-gated, even in development.
    """
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(401, "missing bearer token")
    token = header[7:]

    def _verify(tok: str) -> dict:
        return firebase_auth.verify_id_token(tok, app=firebase.app())

    try:
        claims = await run_in_threadpool(_verify, token)
    except (ValueError, firebase_auth.InvalidIdTokenError, firebase_auth.CertificateFetchError) as e:
        log.warning("admin token rejected [request %s]: %s", requestid.current(), e)
        raise HTTPException(401, "invalid token") from None

    if not claims.get("admin"):
        log.warning("admin route accessed without admin claim [request %s] uid=%s", requestid.current(), claims.get("uid"))
        raise HTTPException(403, "admin claim required")

    return claims["uid"]


def _audit(session: AsyncSession, admin_uid: str, target_uid: str, action: str) -> None:
    """Write an admin action to the access log so the audit trail is append-only."""
    session.add(
        AccessLog(
            clinician_uid=admin_uid,
            patient_uid=target_uid,
            action=action,
            sections=[],
        )
    )


@router.post("/clinicians/{uid}/verify", status_code=200)
async def verify_clinician(
    uid: str,
    admin_uid: str = Depends(_admin_identity),
    session: AsyncSession = Depends(get_session),
):
    """Approve a clinician profile so they can accept patient care requests."""
    profile = await session.get(ClinicianProfile, uid)
    if profile is None:
        raise HTTPException(404, "clinician profile not found")
    user = await session.get(User, uid)
    if user is None or not user.email_verified:
        raise HTTPException(422, "clinician has not verified their email; ask them to verify then retry")
    profile.verified_at = datetime.now(UTC)
    _audit(session, admin_uid, uid, "admin_verify")
    await session.commit()
    log.info(
        "clinician verified [request %s] admin=%s target=%s",
        requestid.current(),
        admin_uid,
        uid,
    )
    return {"uid": uid, "verified_at": profile.verified_at}


@router.post("/clinicians/{uid}/revoke", status_code=200)
async def revoke_clinician(
    uid: str,
    admin_uid: str = Depends(_admin_identity),
    session: AsyncSession = Depends(get_session),
):
    """Remove approval from a clinician profile.  Existing care links are not deleted."""
    profile = await session.get(ClinicianProfile, uid)
    if profile is None:
        raise HTTPException(404, "clinician profile not found")
    profile.verified_at = None
    _audit(session, admin_uid, uid, "admin_revoke")
    await session.commit()
    log.info(
        "clinician revoked [request %s] admin=%s target=%s",
        requestid.current(),
        admin_uid,
        uid,
    )
    return {"uid": uid, "verified_at": None}
