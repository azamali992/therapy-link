"""The Firebase Admin SDK, initialised on first use so tests and local dev never need credentials."""

from __future__ import annotations

import contextlib

import firebase_admin
from firebase_admin import auth, credentials

from therapylink_api.settings import get_settings


def app() -> firebase_admin.App:
    try:
        return firebase_admin.get_app()
    except ValueError:
        s = get_settings()
        # No service account means Application Default Credentials, loaded lazily. Verifying tokens
        # needs only the project id; deleting users needs real credentials.
        cred = credentials.Certificate(s.firebase_service_account_json) if s.firebase_service_account_json else None
        return firebase_admin.initialize_app(cred, {"projectId": s.firebase_project_id})


def delete_user(uid: str) -> None:
    """Remove the sign-in account. Already gone counts as done, so a retried deletion succeeds."""
    with contextlib.suppress(auth.UserNotFoundError):
        auth.delete_user(uid, app=app())
