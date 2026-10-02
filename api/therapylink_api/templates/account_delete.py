"""The public account deletion page Google Play links to. Plain HTML, one inline style block, no
scripts and nothing loaded from anywhere else, so it works on any browser and under a CSP of
default-src 'none'. $contact is the only substitution and arrives already escaped."""

import base64
import hashlib
from string import Template

STYLE = """
body { margin: 0; background: #fbfaf7; color: #1f2328; font: 1rem/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main, footer { max-width: 40rem; margin: 0 auto; padding: 1.5rem 1rem; }
h1 { font-size: 1.6rem; line-height: 1.25; margin: 0 0 1rem; }
h2 { font-size: 1.2rem; margin: 2rem 0 0.5rem; }
h3 { font-size: 1rem; margin: 1.25rem 0 0.25rem; }
section + section { border-top: 1px solid #d0cdc4; margin-top: 2rem; }
a { color: #0b5cad; }
a:focus-visible { outline: 3px solid #0b5cad; outline-offset: 2px; }
.path { font-weight: 600; }
.unset { background: #fff3cd; border: 1px solid #b58a00; padding: 0.1rem 0.35rem; }
footer { border-top: 2px solid #1f2328; font-size: 0.95rem; }
@media (prefers-color-scheme: dark) {
  body { background: #16181c; color: #e6e6e6; }
  a { color: #7db7ff; }
  a:focus-visible { outline-color: #7db7ff; }
  section + section { border-top-color: #3a3d44; }
  .unset { background: #3d3200; border-color: #d9a900; }
  footer { border-top-color: #e6e6e6; }
}
"""

# Hash of the exact text inside <style>, for the style-src directive.
STYLE_HASH = "sha256-" + base64.b64encode(hashlib.sha256(STYLE.encode()).digest()).decode()

PAGE = Template(
    """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Delete your TherapyLink account</title>
<style>"""
    + STYLE
    + """</style>
</head>
<body>
<main>
<section lang="en" aria-labelledby="en-title">
<h1 id="en-title">Delete your TherapyLink account</h1>
<p>You can delete your account and your data at any time. Deleting cannot be undone.</p>

<h2>Delete it in the app</h2>
<p>Open TherapyLink and go to <span class="path">You &gt; Delete account</span>, then confirm.
Everything below is removed at once, and Eve's conversations are cleared from that phone too.</p>

<h2>What is deleted from our server</h2>
<ul>
<li>Your mood points (the mood trend)</li>
<li>Your check-ins (questionnaire answers and scores)</li>
<li>Journal entries you shared with the server, and summaries you shared with a clinician</li>
<li>Your links to clinicians</li>
<li>Your sign-in account (Firebase)</li>
</ul>

<h2>What we keep</h2>
<ul>
<li>A log of each time a clinician was shown your data: which clinician, when, and which sections. It
holds none of the data itself. It is kept after deletion so there is always a record of who looked.</li>
<li>A note that the account was deleted: a one-way hash of your sign-in ID and the time of deletion,
nothing else. A sign-in stays valid for up to an hour after deletion, and this note stops it from
creating your account again. It is kept permanently.</li>
</ul>

<h2>What is not on our server</h2>
<p>Your conversations with Eve, and what Eve remembers about you, are kept only on your phone. We never
receive them. They are deleted when you uninstall the app, or when you use
<span class="path">You &gt; Delete account</span> on that phone.</p>

<h2>If you cannot open the app</h2>
<p>Email $contact from the address you signed in with and ask us to delete your account. We will
confirm the request with you, delete the data listed above, and reply when it is done.</p>
</section>

<section lang="ur-Latn" aria-labelledby="ur-title">
<h1 id="ur-title">Apna TherapyLink account delete karein</h1>
<p>Aap kisi bhi waqt apna account aur data delete kar sakte hain. Delete hone ke baad yeh wapas nahi
aa sakta.</p>

<h2>App mein delete karein</h2>
<p>TherapyLink kholein, <span class="path">Aap &gt; Account delete karein</span> par jayein aur confirm karein
(app English mein ho to <span class="path">You &gt; Delete account</span>).
Neeche likha sab kuch foran mit jata hai, aur us phone se Eve ki baatein bhi saaf ho jati hain.</p>

<h2>Hamare server se kya delete hota hai</h2>
<ul>
<li>Aap ke mood points (mood trend)</li>
<li>Aap ke check-ins (sawalnamon ke jawab aur scores)</li>
<li>Journal entries jo aap ne server ke saath share keen, aur summaries jo aap ne clinician ko bheji</li>
<li>Clinicians ke saath aap ke links</li>
<li>Aap ka sign-in account (Firebase)</li>
</ul>

<h2>Hum kya rakhte hain</h2>
<ul>
<li>Ek log ke kab kis clinician ko aap ka data dikhaya gaya: kaun sa clinician, kab, aur kaun se hisse.
Is mein data khud nahi hota. Yeh delete ke baad bhi rehta hai taake hamesha record rahe ke kis ne dekha.</li>
<li>Ek note ke account delete ho chuka hai: aap ki sign-in ID ka one-way hash aur delete hone ka waqt,
aur kuch nahi. Delete ke baad ek ghante tak sign-in chalta rehta hai, aur yeh note us se aap ka account
dobara banne nahi deta. Yeh hamesha rakha jata hai.</li>
</ul>

<h2>Hamare server par kya nahi hota</h2>
<p>Eve ke saath aap ki baatein, aur Eve ko aap ke baare mein jo yaad hai, sirf aap ke phone par rehta hai.
Yeh hamare paas kabhi nahi aata. App uninstall karne se, ya us phone par
<span class="path">Aap &gt; Account delete karein</span> karne se yeh delete ho jata hai.</p>

<h2>Agar aap app nahi khol sakte</h2>
<p>Jis email se aap ne sign in kiya tha, us se $contact par email karein aur account delete karne ka
kahein. Hum aap se request confirm karenge, upar likha data delete karenge, aur kaam hone par jawab
denge.</p>
</section>
</main>

<footer>
<p lang="en">If you might hurt yourself or someone else, or you are in danger, call Rescue <strong>1122</strong> now.</p>
<p lang="ur-Latn">Agar aap khud ko ya kisi aur ko nuqsan pohncha sakte hain, ya khatre mein hain, to abhi Rescue <strong>1122</strong> par call karein.</p>
</footer>
</body>
</html>
"""
)
