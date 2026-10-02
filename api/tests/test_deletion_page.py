import base64
import hashlib
import re

from therapylink_api.routers.account_page import UNSET_CONTACT
from therapylink_api.templates.account_delete import STYLE, STYLE_HASH


async def _page(client, monkeypatch, email: str | None = None):
    if email is None:
        monkeypatch.delenv("TL_SUPPORT_EMAIL", raising=False)
    else:
        monkeypatch.setenv("TL_SUPPORT_EMAIL", email)
    return await client.get("/account/delete")


async def test_served_without_auth(client, monkeypatch):
    r = await _page(client, monkeypatch)
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/html")


async def test_explains_in_app_route_in_both_languages(client, monkeypatch):
    html = (await _page(client, monkeypatch)).text
    en = html[html.index('<section lang="en"') : html.index('<section lang="ur-Latn"')]
    ur = html[html.index('<section lang="ur-Latn"') : html.index("</main>")]
    # How to delete, and the phone-only data, each name the path in the labels the reader's app shows.
    assert en.count("You &gt; Delete account") == 2
    assert ur.count("Aap &gt; Account delete karein") == 2
    assert "You &gt; Delete account" in ur  # for an Urdu reader whose app is set to English
    assert 'lang="en"' in html and 'lang="ur-Latn"' in html
    assert "Delete your TherapyLink account" in html
    assert "Apna TherapyLink account delete karein" in html
    for held in ("mood points", "check-ins", "Journal entries", "clinicians", "Firebase"):
        assert held in html
    assert "only on your phone" in html
    assert "sirf aap ke phone par" in html


async def test_names_everything_kept_after_deletion(client, monkeypatch):
    # DELETE /me keeps the clinician access log and a permanent erased_accounts row; say so in both languages.
    html = (await _page(client, monkeypatch)).text
    en = html[html.index("<h2>What we keep</h2>") : html.index("<h2>What is not on our server</h2>")]
    ur = html[html.index("<h2>Hum kya rakhte hain</h2>") : html.index("<h2>Hamare server par kya nahi hota</h2>")]
    assert "clinician was shown your data" in en
    assert "one-way hash of your sign-in ID" in en and "kept permanently" in en
    assert "clinician ko aap ka data dikhaya gaya" in ur
    assert "sign-in ID ka one-way hash" in ur and "hamesha rakha jata hai" in ur


async def test_footer_names_the_crisis_line(client, monkeypatch):
    html = (await _page(client, monkeypatch)).text
    footer = html[html.index("<footer>") :]
    assert "Rescue <strong>1122</strong>" in footer


async def test_security_headers(client, monkeypatch):
    r = await _page(client, monkeypatch)
    csp = r.headers["content-security-policy"]
    assert "default-src 'none'" in csp
    assert f"style-src '{STYLE_HASH}'" in csp
    assert "script-src" not in csp  # default-src 'none' already forbids scripts
    assert r.headers["cache-control"] == "no-store"
    assert r.headers["x-content-type-options"] == "nosniff"


async def test_style_hash_matches_the_inline_block(client, monkeypatch):
    # A browser hashes the text between the style tags; an edit that breaks the match unstyles the page.
    html = (await _page(client, monkeypatch)).text
    served = re.search(r"<style>(.*?)</style>", html, re.S).group(1)
    assert served == STYLE
    assert STYLE_HASH == "sha256-" + base64.b64encode(hashlib.sha256(served.encode()).digest()).decode()


async def test_nothing_external_or_scripted(client, monkeypatch):
    html = (await _page(client, monkeypatch, "help@example.org")).text
    assert "http://" not in html and "https://" not in html and "//" not in html
    assert "<script" not in html and "src=" not in html and "<link" not in html
    assert set(re.findall(r'href="([^"]*)"', html)) == {"mailto:help@example.org"}


async def test_contact_placeholder_is_marked_when_unset(client, monkeypatch):
    html = (await _page(client, monkeypatch)).text
    assert html.count(UNSET_CONTACT) == 2
    assert "mailto:" not in html


async def test_contact_uses_setting_and_is_escaped(client, monkeypatch):
    html = (await _page(client, monkeypatch, "help@example.org")).text
    assert html.count('<a href="mailto:help@example.org">help@example.org</a>') == 2
    assert "not configured" not in html
    html = (await _page(client, monkeypatch, 'x"><b>@example.org')).text
    assert "<b>" not in html
    assert "x&quot;&gt;&lt;b&gt;@example.org" in html
