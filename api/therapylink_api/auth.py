from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass

from fastapi import Depends, HTTPException, Request, status
from fastapi.concurrency import run_in_threadpool
from firebase_admin import auth as firebase_auth
from sqlalchemy import insert
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api import firebase, requestid
from therapylink_api.db import get_session
from therapylink_api.models import ErasedAccount, Role, User
from therapylink_api.settings import get_settings

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Principal:
    uid: str
    email: str | None
    role: Role
    # Signed in through TL_DEV_AUTH_BYPASS: there is no Firebase account behind this uid.
    dev: bool = False


@dataclass(frozen=True)
class Identity:
    """Who a verified token (or the dev bypass) says the caller is, before any database lookup."""

    uid: str
    email: str | None
    name: str | None
    email_verified: bool
    dev: bool = False


def erased_key(uid: str) -> str:
    return hashlib.sha256(uid.encode()).hexdigest()


def _verify(token: str) -> dict:
    # The Admin SDK caches Google's signing certs between calls; a plain google-auth transport
    # fetched them on every request.
    return firebase_auth.verify_id_token(token, app=firebase.app())


async def _ensure_user(session: AsyncSession, uid: str, email: str | None, name: str | None, email_verified: bool) -> None:
    """Insert the user if missing. Two first requests racing each other both succeed."""
    values = {"uid": uid, "email": email, "display_name": name, "email_verified": email_verified}
    dialect = session.bind.dialect.name
    if dialect in ("postgresql", "sqlite"):
        ins = pg_insert if dialect == "postgresql" else sqlite_insert
        await session.execute(ins(User).values(**values).on_conflict_do_nothing(index_elements=["uid"]))
        await session.commit()
        return
    try:
        await session.execute(insert(User).values(**values))
        await session.commit()
    except IntegrityError:
        await session.rollback()


async def _get_or_create_user(session: AsyncSession, uid: str, email: str | None, name: str | None, email_verified: bool) -> User:
    user = await session.get(User, uid)
    if user is None:
        await _ensure_user(session, uid, email, name, email_verified)
        user = await session.get(User, uid)
    elif user.email_verified != email_verified:
        user.email_verified = email_verified  # the token is the source of truth; it can change either way
        await session.commit()
    return user


async def signed_in(request: Request) -> Identity:
    """The caller's verified identity. Touches no database, so it works for an erased account too."""
    settings = get_settings()
    if settings.dev_auth_bypass and (dev_uid := request.headers.get("x-dev-uid")):
        return Identity(dev_uid, f"{dev_uid}@dev.local", dev_uid, True, dev=True)

    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")
    try:
        claims = await run_in_threadpool(_verify, header[7:])
    except firebase_auth.CertificateFetchError as e:
        # Our problem, not the token's: don't make the app sign the user out.
        log.warning("could not fetch signing certs [request %s]: %s", requestid.current(), e)
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "sign-in check unavailable, try again") from None
    except (ValueError, firebase_auth.InvalidIdTokenError) as e:
        # The parse error can describe the token; it stays in the server log.
        log.warning("token rejected [request %s]: %s", requestid.current(), e)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid token") from None
    return Identity(claims["uid"], claims.get("email"), claims.get("name"), bool(claims.get("email_verified")))


async def current_principal(ident: Identity = Depends(signed_in), session: AsyncSession = Depends(get_session)) -> Principal:
    # A deleted account's token outlives it by up to an hour. Checking the tombstone is one indexed
    # read; asking Firebase (check_revoked) would be a network call on every request.
    if not ident.dev and await session.get(ErasedAccount, erased_key(ident.uid)) is not None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "account deleted")
    user = await _get_or_create_user(session, ident.uid, ident.email, ident.name, ident.email_verified)
    return Principal(user.uid, user.email, user.role, dev=ident.dev)


def require_role(*roles: Role):
    async def dep(principal: Principal = Depends(current_principal)) -> Principal:
        if principal.role not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "insufficient role")
        return principal

    return dep
