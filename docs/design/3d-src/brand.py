"""Launcher icon, splash and store art from the Eve bud render (icon.py).

Works in "dp space": every layer is built on a canvas measured in dp and rendered
at a high working resolution, then downsampled per density. The colour icon,
adaptive foreground, splash and marks all use the same bud and the same glow recipe,
so they match.

Runs with Blender's bundled Python plus OpenEXR/Pillow/numpy from D:\\dev\\tools\\pylibs:
  set PYTHONPATH=D:\\dev\\tools\\pylibs
  D:\\dev\\blender\\4.5\\python\\bin\\python.exe brand.py preview   -> BUILD/brand/*.png for review
  D:\\dev\\blender\\4.5\\python\\bin\\python.exe brand.py all <repo> -> writes into the repo
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import post  # noqa: E402  (read_exr, gauss, tone, to_srgb)

BUILD = r"D:\dev\tmp\tl3d\brand"
FONT = r"D:\dev\tools\fonts\Unbounded[wght].ttf"


def srgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def lin(h):
    c = srgb(h)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).astype(np.float32)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


NIGHT, PLUM = srgb("#1D1E2C"), srgb("#34063F")

# ------------------------------------------------------------------ geometry (dp)
ADAPTIVE = 108      # adaptive icon layer canvas
VIEW = 72           # what the launcher shows of it (the master icon is this crop)
BUD_H = 50          # bud height in the colour icon (69% of the 72 dp viewport)
BUD_DY = 0.6        # optical centring: the round base is heavy, nudge the bud down a little
MONO_H = 40         # themed-icon glyph is drawn a little smaller, as Android's own glyphs are
SPLASH = 288        # Android 12 splash icon canvas, visible circle 192 dp
SPLASH_BUD_H = 112
DENS = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# ------------------------------------------------------------------ glow recipe
# "Simplified" glow: one tight rim bloom that sharpens the silhouette, and one soft
# violet aura that lifts the ground behind the bud. No rings, no swirl, no motes.
GLOW = dict(rim=0.55, rim_r=(0.018, 0.05), aura=0.18, aura_sx=0.48, aura_sy=0.50)


# ------------------------------------------------------------------ io
_BUD = {}


def bud_src():
    """Premultiplied linear RGB + alpha of the 2048 render, cropped to the bud bbox."""
    if "src" not in _BUD:
        e = post.read_exr(os.path.join(BUILD, os.environ.get("BUD", "bud") + ".exr"))
        a = e[..., 3]
        ys, xs = np.where(a > 0.02)
        pad = 8
        y0, y1, x0, x1 = ys.min() - pad, ys.max() + pad + 1, xs.min() - pad, xs.max() + pad + 1
        _BUD["src"] = e[y0:y1, x0:x1].copy()
        _BUD["h"] = (ys.max() - ys.min() + 1)       # bud height in source px (without pad)
    return _BUD["src"], _BUD["h"]


def fresize(a, w, h):
    """Float resize (Lanczos) for HxWxC arrays."""
    out = np.empty((h, w, a.shape[2]), np.float32)
    for c in range(a.shape[2]):
        out[..., c] = np.asarray(Image.fromarray(np.ascontiguousarray(a[..., c])).resize((w, h), Image.LANCZOS))
    return out


def place(canvas_px, bud_h_px, cx, cy):
    """Bud (premultiplied linear RGBA) scaled to bud_h_px, bbox centred at (cx, cy) px."""
    src, sh = bud_src()
    s = bud_h_px / sh
    h, w = max(1, round(src.shape[0] * s)), max(1, round(src.shape[1] * s))
    b = np.clip(fresize(src, w, h), 0, None)
    b[..., 3] = np.clip(b[..., 3], 0, 1)
    out = np.zeros((canvas_px, canvas_px, 4), np.float32)
    x0, y0 = round(cx - w / 2), round(cy - h / 2)
    xs0, ys0 = max(0, -x0), max(0, -y0)
    xd0, yd0 = max(0, x0), max(0, y0)
    ww = min(w - xs0, canvas_px - xd0)
    hh = min(h - ys0, canvas_px - yd0)
    out[yd0:yd0 + hh, xd0:xd0 + ww] = b[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def blur(a, r):
    """Gaussian-ish blur, computed at reduced resolution for big radii."""
    h, w = a.shape[:2]
    k = max(1, int(r / 6))
    if k > 1:
        small = fresize(a, max(4, w // k), max(4, h // k))
        small = post.gauss(small, r / k)
        return fresize(small, w, h)
    return post.gauss(a, r)


def light_layer(canvas_dp, bud_h_dp, ppd, dy_dp=0.0, glow=GLOW, fade=None):
    """Returns (premultiplied display RGB, alpha, bud coverage) at canvas_dp * ppd px.
    fade: radius in dp beyond which every bit of glow is gone (splash circle)."""
    W = round(canvas_dp * ppd)
    bh = bud_h_dp * ppd
    cx, cy = W / 2, W / 2 + dy_dp * ppd
    b = place(W, bh, cx, cy)
    L, A = b[..., :3], b[..., 3]
    # rim bloom from the brightest parts (the lit petal edges)
    m = L.max(-1, keepdims=True)
    bright = L * np.clip((m - 0.5) / (m + 1e-6), 0, None)
    G = np.zeros_like(L)
    for r, wt in zip(glow["rim_r"], (0.6, 0.4)):
        G += wt * blur(bright, r * bh)
    G *= glow["rim"]
    # soft aura, centred a little below the bud's middle (where the hidden flame sits)
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    ax, ay = cx, cy + 0.06 * bh
    d2 = ((xx - ax) / (glow["aura_sx"] * bh)) ** 2 + ((yy - ay) / (glow["aura_sy"] * bh)) ** 2
    aura_col = lin("#6E29FF") * 0.55 + lin("#F23598") * 0.25 + lin("#A36FFF") * 0.20
    G += glow["aura"] * np.exp(-d2)[..., None] * aura_col
    if fade is not None:
        r = np.sqrt((xx - W / 2) ** 2 + (yy - W / 2) ** 2) / ppd
        G *= (1 - smoothstep(fade * 0.72, fade, r))[..., None]
    disp = post.to_srgb(post.tone(L + G))
    alpha = np.clip(A + G.max(-1) * 1.4, 0, 1)
    disp = np.minimum(disp, alpha[..., None])        # keep it a valid premultiplied colour
    return disp.astype(np.float32), alpha.astype(np.float32), A


def ground(Wpx, top=NIGHT, bottom=PLUM, y0=0.0, y1=1.0):
    """CSS-style 180deg gradient (sRGB interpolation), night at the top to plum at the bottom.
    y0/y1: where the ramp starts/ends as a fraction of the canvas (clamped outside)."""
    t = np.clip((np.linspace(0, 1, Wpx, dtype=np.float32) - y0) / (y1 - y0), 0, 1)[:, None, None]
    return np.broadcast_to(top * (1 - t) + bottom * t, (Wpx, Wpx, 3)).astype(np.float32)


def over(disp, alpha, bg):
    return disp + bg * (1 - alpha[..., None])


def q8(a):
    d = post.dither(a.shape[:2] + (1,))
    return np.clip(np.round((a + d) * 255), 0, 255).astype(np.uint8)


def to_rgba(disp, alpha):
    straight = np.where(alpha[..., None] > 1e-4, disp / np.maximum(alpha[..., None], 1e-4), 0)
    # No dither on transparent layers: the glow ramps are steep enough not to band, and noise
    # in a mostly-empty image triples the PNG size. Empty pixels are exactly (0, 0, 0, 0).
    q = lambda v: np.round(np.clip(v, 0, 1) * 255).astype(np.uint8)
    out = np.concatenate([q(straight), q(alpha[..., None])], -1)
    out[out[..., 3] == 0] = 0
    return out


def q8mask(m):
    """Alpha of a hard shape: no dither, so empty stays exactly empty."""
    return np.round(np.clip(m, 0, 1) * 255).astype(np.uint8)[..., None]


def down(rgb_or_premult, alpha, size):
    """Downsample premultiplied (rgb, alpha) to size x size."""
    if alpha is None:
        return fresize(rgb_or_premult, size, size), None
    st = np.concatenate([rgb_or_premult, alpha[..., None]], -1)
    r = np.clip(fresize(st, size, size), 0, None)
    return np.minimum(r[..., :3], np.clip(r[..., 3:], 0, 1)), np.clip(r[..., 3], 0, 1)


def save(arr, path, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr, mode).save(path, optimize=True)


# ------------------------------------------------------------------ products
PPD = 20   # working px per dp (108 dp canvas -> 2160 px)


def adaptive_layers():
    """Foreground (premult disp, alpha) and the matching background, on the 108 dp canvas."""
    if "adaptive" not in _BUD:
        disp, alpha, cov = light_layer(ADAPTIVE, BUD_H, PPD, BUD_DY)
        W = disp.shape[0]
        # the ramp spans the visible 72 dp (18..90), clamped outside, exactly like the vector bg
        bg = ground(W, y0=18 / 108, y1=90 / 108)
        _BUD["adaptive"] = (disp, alpha, cov, bg)
    return _BUD["adaptive"]


def master():
    """Opaque square icon = the 72 dp viewport of the adaptive icon, at working res."""
    disp, alpha, _, bg = adaptive_layers()
    full = over(disp, alpha, bg)
    o = 18 * PPD
    return full[o:o + VIEW * PPD, o:o + VIEW * PPD]


def master_png(size):
    m, _ = down(master(), None, size)
    return q8(m)


def mask_shape(size, shape, inset=0.0):
    """Anti-aliased mask: 'circle', 'squircle' (superellipse n=5), 'rounded' (r=18%)."""
    ss = 4
    n = size * ss
    yy, xx = (np.mgrid[0:n, 0:n].astype(np.float32) + 0.5) / n * 2 - 1
    s = 1 - inset * 2
    xx, yy = xx / s, yy / s
    if shape == "circle":
        m = (xx ** 2 + yy ** 2) <= 1
    elif shape == "squircle":
        m = (np.abs(xx) ** 5 + np.abs(yy) ** 5) <= 1
    else:
        r = 0.18 * 2
        qx, qy = np.maximum(np.abs(xx) - (1 - r), 0), np.maximum(np.abs(yy) - (1 - r), 0)
        m = ((qx ** 2 + qy ** 2) <= r ** 2) & (np.abs(xx) <= 1) & (np.abs(yy) <= 1)
    m = m.astype(np.float32).reshape(size, ss, size, ss).mean((1, 3))
    return m


def legacy_png(size, shape):
    rgb = master_png(size).astype(np.float32) / 255
    m = mask_shape(size, "circle" if shape == "round" else "rounded", inset=1 / 48)
    out = np.concatenate([q8(rgb), q8mask(m)], -1)
    out[out[..., 3] == 0] = 0
    return out


def foreground_png(size):
    disp, alpha, _, _ = adaptive_layers()
    d, a = down(disp, alpha, size)
    return to_rgba(d, a)


def monochrome_png(size):
    """Flat bud silhouette for Android 13 themed icons (tinted by the system)."""
    if "mono" not in _BUD:
        W = ADAPTIVE * PPD
        cov = place(W, MONO_H * PPD, W / 2, W / 2 + BUD_DY * PPD * MONO_H / BUD_H)[..., 3]
        sil = smoothstep(0.3, 0.7, cov)
        _BUD["mono"] = sil.astype(np.float32)
    sil = _BUD["mono"]
    a = fresize(sil[..., None], size, size)[..., 0]
    a = np.clip(a, 0, 1)
    out = np.concatenate([np.full(a.shape + (3,), 255, np.uint8), q8mask(a)], -1)
    out[out[..., 3] == 0] = 0
    return out


def splash_layer():
    if "splash" not in _BUD:
        g = dict(GLOW, aura=0.34, aura_sx=0.52, aura_sy=0.55)
        _BUD["splash"] = light_layer(SPLASH, SPLASH_BUD_H, 6, 2.0, glow=g, fade=94)
    return _BUD["splash"]


def splash_png(size):
    disp, alpha, _ = splash_layer()
    d, a = down(disp, alpha, size)
    return to_rgba(d, a)


def mark_png(size):
    """In-app mark: the bud with its rim bloom only, on transparent, tightly framed."""
    if "mark" not in _BUD:
        g = dict(GLOW, aura=0.18, aura_sx=0.40, aura_sy=0.44)
        _BUD["mark"] = light_layer(100, 74, 20, 0.8, glow=g, fade=50)
    disp, alpha, _ = _BUD["mark"]
    d, a = down(disp, alpha, size)
    return to_rgba(d, a)


def feature_graphic(path):
    """Play Store feature graphic 1024x500: Eve left, 'TherapyLink' in Unbounded Light right."""
    W, H, S = 1024, 500, 2
    w, h = W * S, H * S
    # ground: night -> plum, 180deg, plus a soft plum bloom behind Eve
    t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    bg = np.broadcast_to(NIGHT * (1 - t) + PLUM * t, (h, w, 3)).copy()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ex, ey = 0.27 * w, 0.50 * h
    r = np.sqrt(((xx - ex) / (0.42 * w)) ** 2 + ((yy - ey) / (0.75 * h)) ** 2)
    bg += (np.clip(1 - r, 0, 1) ** 2)[..., None] * (PLUM * 0.45 + srgb("#6E29FF") * 0.08)
    # Eve (full render with aura and ripple rings)
    e = post.read_exr(os.path.join(BUILD, "feature.exr"))
    rgb, a = e[..., :3], e[..., 3]
    m = rgb.max(-1, keepdims=True)
    bright = rgb * np.clip((m - 0.55) / (m + 1e-6), 0, None)
    G = 0.6 * blur(bright, 10) + 0.4 * blur(bright, 34)
    disp = post.to_srgb(post.tone(rgb + G))
    alpha = np.clip(a + G.max(-1) * 1.4, 0, 1)
    side = round(1.10 * h)
    d, al = down(np.minimum(disp, alpha[..., None]), alpha, side)
    x0, y0 = round(ex - side / 2), round(ey - side / 2 + 0.02 * h)
    canvas = bg
    ys0, xs0 = max(0, -y0), max(0, -x0)
    sub = canvas[max(0, y0):y0 + side, max(0, x0):x0 + side]
    dd = d[ys0:ys0 + sub.shape[0], xs0:xs0 + sub.shape[1]]
    aa = al[ys0:ys0 + sub.shape[0], xs0:xs0 + sub.shape[1]]
    canvas[max(0, y0):y0 + side, max(0, x0):x0 + side] = dd + sub * (1 - aa[..., None])
    img = Image.fromarray(q8(np.clip(canvas, 0, 1)))
    # wordmark
    dr = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 54 * S)
    f.set_variation_by_axes([300])
    text = "TherapyLink"
    bx = dr.textbbox((0, 0), text, font=f)
    tw, th = bx[2] - bx[0], bx[3] - bx[1]
    tx = round(0.50 * w)
    ty = round(h / 2 - th / 2 - bx[1])
    dr.text((tx, ty), text, font=f, fill=(245, 238, 255))
    img = img.resize((W, H), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    assert tx + tw < 0.92 * w, "wordmark runs into the right edge"
    return tw / S, tx / S


# ------------------------------------------------------------------ review sheet
def legibility_sheet(path):
    """Master downscaled to launcher sizes, shown 1:1 and enlarged (nearest) side by side,
    on a dark and a light wallpaper, through the common launcher masks."""
    tile_bg = [(20, 20, 26), (226, 222, 232)]
    sizes = [192, 144, 96, 72, 48]
    W, H = 1360, 760
    img = Image.new("RGB", (W, H), (14, 14, 18))
    dr = ImageDraw.Draw(img)
    try:
        lab = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 15)
    except Exception:
        lab = ImageFont.load_default()
    y = 16
    for wall in tile_bg:
        dr.rectangle([0, y - 8, W, y + 330], fill=wall)
        x = 20
        for s, shape in zip(sizes, ["squircle", "circle", "rounded", "squircle", "circle"]):
            rgb = master_png(s).astype(np.float32) / 255
            m = mask_shape(s, shape)
            ic = Image.fromarray(np.concatenate([q8(rgb), q8(m[..., None])], -1), "RGBA")
            img.paste(ic, (x, y), ic)
            dr.text((x, y + s + 4), f"{s}px {shape}", fill=(128, 128, 140), font=lab)
            x += s + 26
        # enlarged pixels of the 48 px icon so the review can see what the launcher gets
        rgb48 = Image.fromarray(master_png(48)).resize((288, 288), Image.NEAREST)
        img.paste(rgb48, (W - 300, y))
        dr.text((W - 300, y + 292), "48px, 6x nearest", fill=(128, 128, 140), font=lab)
        y += 360
    img.save(path, optimize=True)


def contact_sheet(path):
    """Everything the build produces, at real pixel size where it fits."""
    W, H = 1600, 1215
    img = Image.new("RGB", (W, H), (18, 18, 24))
    dr = ImageDraw.Draw(img)
    try:
        lab = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 15)
        hd = ImageFont.truetype(FONT, 20)
        hd.set_variation_by_axes([300])
    except Exception:
        lab = hd = ImageFont.load_default()
    grey = (150, 146, 165)

    def head(x, y, s):
        dr.text((x, y), s, fill=(235, 228, 245), font=hd)

    def put(arr, x, y, label, mode=None):
        im = Image.fromarray(arr, mode)
        if im.mode == "RGBA":
            img.paste(im, (x, y), im)
        else:
            img.paste(im, (x, y))
        if label:
            dr.text((x, y + im.size[1] + 4), label, fill=grey, font=lab)
        return im.size

    # 1. master
    head(24, 18, "Master 1024 (shown at 384)")
    put(master_png(384), 24, 52, "icon-master-1024.png / iOS 1024 / Play 512")
    # 2. legacy launcher sizes, 1:1
    head(440, 18, "Android legacy, 1:1 (mdpi to xxxhdpi)")
    x = 440
    for d, k in DENS.items():
        s = round(48 * k)
        put(legacy_png(s, "square"), x, 52, f"{s}")
        put(legacy_png(s, "round"), x, 52 + 200, f"{s} round")
        x += s + 18
    # 3. adaptive layers
    head(24, 480, "Adaptive 108 dp: background, foreground, masks, themed")
    _, _, _, bg = adaptive_layers()
    s = 216
    bgp = q8(fresize(bg, s, s))
    put(bgp, 24, 514, "background (vector)")
    fg = foreground_png(s)
    chk = np.zeros((s, s, 3), np.uint8) + 60
    chk[(np.add.outer(np.arange(s) // 12, np.arange(s) // 12) % 2) == 0] = 90
    put(chk, 260, 514, None)
    put(fg, 260, 514, "foreground (transparent)", "RGBA")
    x = 496
    for shape in ("circle", "squircle", "rounded"):
        t = 144
        rgb = master_png(t).astype(np.float32) / 255
        m = mask_shape(t, shape)
        put(np.concatenate([q8(rgb), q8(m[..., None])], -1), x, 514, shape, "RGBA")
        x += t + 22
    # themed: system tints the monochrome layer, e.g. dark tint on a light pastel disc
    t = 144
    mono = monochrome_png(round(t * 108 / 72)).astype(np.float32) / 255
    o = round((mono.shape[0] - t) / 2)
    mono = mono[o:o + t, o:o + t]
    for tint, disc, nm in (((52, 6, 63), (236, 220, 246), "themed light"),
                           ((226, 204, 255), (46, 36, 62), "themed dark")):
        m = mask_shape(t, "circle")
        rgb = np.array(disc, np.float32) / 255 * (1 - mono[..., 3:]) + np.array(tint, np.float32) / 255 * mono[..., 3:]
        put(np.concatenate([q8(rgb), q8(m[..., None])], -1), x, 514, nm, "RGBA")
        x += t + 22
    # 4. splash, as a phone shows it
    head(24, 790, "Splash on #1D1E2C (Android 12+, pre-12, iOS)")
    sp = splash_png(288).astype(np.float32) / 255
    bgc = np.broadcast_to(NIGHT, (288, 288, 3))
    comp = sp[..., :3] * sp[..., 3:] + bgc * (1 - sp[..., 3:])
    phone = np.broadcast_to(NIGHT, (360, 200, 3)).copy()
    put(q8(phone), 24, 824, None)
    sm = Image.fromarray(q8(comp)).resize((150, 150), Image.LANCZOS)
    img.paste(sm, (24 + 25, 824 + 105))
    dr.ellipse([24 + 25 + 25, 824 + 105 + 25, 24 + 25 + 125, 824 + 105 + 125], outline=(70, 70, 90))
    dr.text((24, 824 + 364), "phone, 192 dp circle outlined", fill=grey, font=lab)
    put(q8(comp), 250, 824, "splash_eve 288 dp @ mdpi")
    # 5. marks + iOS sizes
    head(640, 790, "In-app mark (transparent) and iOS sizes, 1:1")
    put(chk[:128, :128], 640, 824, None)
    put(mark_png(128), 640, 824, "eve-mark-128", "RGBA")
    x = 790
    for s in (180, 120, 87, 80, 58, 40):
        put(master_png(s), x, 824, f"{s}")
        x += s + 16
    img.save(path, optimize=True)


# ------------------------------------------------------------------ write everything
def write_all(repo):
    app = os.path.join(repo, "app")
    res = os.path.join(app, "android", "app", "src", "main", "res")
    for d, k in DENS.items():
        mm = os.path.join(res, f"mipmap-{d}")
        save(legacy_png(round(48 * k), "square"), os.path.join(mm, "ic_launcher.png"), "RGBA")
        save(legacy_png(round(48 * k), "round"), os.path.join(mm, "ic_launcher_round.png"), "RGBA")
        save(foreground_png(round(108 * k)), os.path.join(mm, "ic_launcher_foreground.png"), "RGBA")
        save(monochrome_png(round(108 * k)), os.path.join(mm, "ic_launcher_monochrome.png"), "RGBA")
        save(splash_png(round(SPLASH * k)), os.path.join(res, f"drawable-{d}", "splash_eve.png"), "RGBA")
    # iOS
    ios = os.path.join(app, "ios", "Runner", "Assets.xcassets")
    ai = os.path.join(ios, "AppIcon.appiconset")
    with open(os.path.join(ai, "Contents.json")) as f:
        cj = json.load(f)
    for im in cj["images"]:
        pt = float(im["size"].split("x")[0])
        px = round(pt * int(im["scale"][0]))
        save(master_png(px), os.path.join(ai, im["filename"]), "RGB")
    li = os.path.join(ios, "LaunchImage.imageset")
    for sfx, k in (("", 1), ("@2x", 2), ("@3x", 3)):
        save(splash_png(SPLASH * k), os.path.join(li, f"LaunchImage{sfx}.png"), "RGBA")
    # in-app marks and store art
    brand = os.path.join(app, "assets", "brand")
    save(mark_png(512), os.path.join(brand, "eve-mark-512.png"), "RGBA")
    save(mark_png(128), os.path.join(brand, "eve-mark-128.png"), "RGBA")
    save(master_png(512), os.path.join(brand, "store", "play-icon-512.png"), "RGB")
    feature_graphic(os.path.join(brand, "store", "play-feature-1024x500.png"))
    # docs
    docs = os.path.join(repo, "docs", "design", "brand")
    save(master_png(1024), os.path.join(docs, "icon-master-1024.png"), "RGB")
    legibility_sheet(os.path.join(docs, "icon-legibility.png"))
    contact_sheet(os.path.join(docs, "icon-contact-sheet.png"))


def preview():
    os.makedirs(BUILD, exist_ok=True)
    save(master_png(1024), os.path.join(BUILD, "p_master.png"), "RGB")
    for s in (48, 72, 96):
        Image.fromarray(master_png(s)).resize((s * 4, s * 4), Image.NEAREST).save(os.path.join(BUILD, f"p_{s}x4.png"))
    legibility_sheet(os.path.join(BUILD, "p_legibility.png"))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if cmd == "preview":
        preview()
    elif cmd == "all":
        write_all(sys.argv[2])
    elif cmd == "sheet":
        contact_sheet(os.path.join(BUILD, "p_contact.png"))
    elif cmd == "feature":
        print(feature_graphic(os.path.join(BUILD, "p_feature.png")))
