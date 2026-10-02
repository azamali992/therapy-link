from html import escape

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from pydantic_settings import BaseSettings, SettingsConfigDict

from therapylink_api.settings import Settings
from therapylink_api.templates.account_delete import PAGE, STYLE_HASH

router = APIRouter(tags=["account"])

# Nothing else may load or run: the page is one document with one hashed style block.
CSP = f"default-src 'none'; style-src '{STYLE_HASH}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
HEADERS = {
    "Content-Security-Policy": CSP,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
}

UNSET_CONTACT = '<strong class="unset">[support email not configured: set TL_SUPPORT_EMAIL]</strong>'


class _Support(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="TL_", extra="ignore", env_ignore_empty=True)
    support_email: str | None = None


def contact_html() -> str:
    # Read per request, from the same env file as Settings (the tests switch that off), so a
    # changed address shows without touching the app's cached settings.
    email = _Support(_env_file=Settings.model_config.get("env_file")).support_email
    if not email:
        return UNSET_CONTACT
    safe = escape(email.strip(), quote=True)
    return f'<a href="mailto:{safe}">{safe}</a>'


@router.get("/account/delete", response_class=HTMLResponse)
async def account_delete_page():
    """Public page for Google Play's account deletion requirement: what deleting removes, what the
    server never holds, and how to ask without the app. No auth, no scripts, nothing external."""
    return HTMLResponse(PAGE.substitute(contact=contact_html()), headers=HEADERS)
