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


_TOKEN_ISSUER = "https://securetoken.google.com/"
_cert_request = None


def _google_request():
    """A google-auth transport whose HTTP session is reused, so Google's signing certs stay cached."""
    global _cert_request
    if _cert_request is None:
        import requests
        from google.auth.transport import requests as google_requests

        _cert_request = google_requests.Request(session=requests.Session())
    return _cert_request


def verify_id_token_public(token: str) -> dict:
    """Verify a Firebase ID token against Google's public signing certs, without Cloud credentials.

    The Admin SDK can't start its auth client without Application Default Credentials (a local run,
    or the free VM before a service account is added). This makes the same checks it does:
    signature, expiry, audience (the Firebase project) and issuer. Returns the claims with "uid".
    """
    from google.oauth2 import id_token

    project = get_settings().firebase_project_id
    claims = id_token.verify_firebase_token(token, _google_request(), audience=project)
    if claims.get("iss") != _TOKEN_ISSUER + project:
        raise ValueError("token issuer is not this Firebase project")
    if not claims.get("sub"):
        raise ValueError("token has no subject")
    claims["uid"] = claims["sub"]
    return claims


def delete_user(uid: str) -> None:
    """Remove the sign-in account. Already gone counts as done, so a retried deletion succeeds."""
    with contextlib.suppress(auth.UserNotFoundError):
        auth.delete_user(uid, app=app())
