"""Approve (or revoke) a clinician account — local dev / emergency fallback only.

PREFER THE ADMIN API IN PRODUCTION:
    POST /admin/clinicians/{uid}/verify  — requires Firebase token with admin:true custom claim
    POST /admin/clinicians/{uid}/revoke

This script requires direct database access (TL_DATABASE_URL). Never put a production database
URL on a developer laptop. It exists only for:
  - local dev with SQLite (TL_DEV_AUTH_BYPASS=true)
  - emergency break-glass when the admin API is unavailable

Usage:
    python scripts/verify_clinician.py                    # list clinician profiles
    python scripts/verify_clinician.py doctor@example.com # approve by email or uid
    python scripts/verify_clinician.py doctor@example.com --revoke

Run from api/ so the .env file is found.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import or_, select  # noqa: E402

from therapylink_api import db  # noqa: E402
from therapylink_api.models import ClinicianProfile, User  # noqa: E402


async def _list() -> None:
    async with db.sessionmaker()() as s:
        rows = (await s.execute(select(User, ClinicianProfile).join(ClinicianProfile, ClinicianProfile.uid == User.uid))).all()
    if not rows:
        print("no clinician profiles yet — sign up via You → I'm a clinician")
    for user, profile in rows:
        state = f"verified {profile.verified_at:%Y-%m-%d}" if profile.verified_at else "PENDING"
        email = f"{user.email or '-'}{'' if user.email_verified else ' (unverified)'}"
        print(f"{state:20} {user.role:10} {email:45} licence={profile.license_no} uid={user.uid}")


async def _set(who: str, revoke: bool) -> int:
    async with db.sessionmaker()() as s:
        user = await s.scalar(select(User).where(or_(User.uid == who, User.email == who)))
        profile = user and await s.get(ClinicianProfile, user.uid)
        if profile is None:
            print(f"no clinician profile for {who!r}", file=sys.stderr)
            return 1
        if not revoke and not user.email_verified:
            # Otherwise anyone could sign up with a clinician's address and inherit the approval.
            print(f"{user.email or user.uid} has not verified their email; ask them to, then sign in again", file=sys.stderr)
            return 1
        profile.verified_at = None if revoke else datetime.now(UTC)
        await s.commit()
    print(f"{'revoked' if revoke else 'verified'} {user.email or user.uid} (licence {profile.license_no})")
    return 0


async def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("who", nargs="?", help="email or uid; omit to list profiles")
    ap.add_argument("--revoke", action="store_true")
    args = ap.parse_args()
    try:
        if args.who is None:
            await _list()
            return 0
        return await _set(args.who, args.revoke)
    finally:
        await db.dispose()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
