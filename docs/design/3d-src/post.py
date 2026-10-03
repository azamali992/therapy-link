"""Post-processing for the pre-rendered loops: EXR (linear, premultiplied, transparent)
-> bloom -> soft tone curve -> composite on #1D1E2C -> H.264 MP4 + VP9-alpha WebM
+ PNG posters + review contact sheet.

Runs with Blender's bundled Python plus OpenEXR/Pillow installed to D:\\dev\\tools\\pylibs:
  set PYTHONPATH=D:\\dev\\tools\\pylibs
  D:\\dev\\blender\\4.5\\python\\bin\\python.exe post.py video eve_idle eve-idle eve.png
"""
import os
import subprocess
import sys

import numpy as np
import OpenEXR
from PIL import Image, ImageDraw, ImageFont

ROOT = r"D:\therapylink-recovery\design\3d"
BUILD = r"D:\dev\tmp\tl3d"
FFMPEG = r"D:\dev\tools\ffmpeg-master-latest-win64-gpl\bin\ffmpeg.exe"
FPS = 30
NIGHT = np.array([0x1D, 0x1E, 0x2C]) / 255.0
PLUM = np.array([0x34, 0x06, 0x3F]) / 255.0


# ------------------------------------------------------------------ io
def read_exr(path):
    with OpenEXR.File(path) as f:
        ch = f.channels()
        if "RGBA" in ch:
            img = np.asarray(ch["RGBA"].pixels, dtype=np.float32)
        else:
            img = np.stack([np.asarray(ch[k].pixels, dtype=np.float32) for k in "RGBA"], -1)
    return np.nan_to_num(img)


# ------------------------------------------------------------------ image ops
def box_blur(a, r):
    if r < 1:
        return a
    for axis in (0, 1):
        n = a.shape[axis]
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r + 1, r)
        p = np.pad(a, pad, mode="edge")
        c = np.cumsum(p, axis=axis, dtype=np.float64)
        hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
        lo = np.take(c, np.arange(0, n), axis=axis)
        a = ((hi - lo) / (2 * r + 1)).astype(np.float32)
    return a


def gauss(a, r):
    rr = max(1, int(r / 1.7))
    return box_blur(box_blur(box_blur(a, rr), rr), rr)


def resize(a, w, h):
    out = np.empty((h, w, a.shape[2]), np.float32)
    for c in range(a.shape[2]):
        out[..., c] = np.asarray(Image.fromarray(a[..., c]).resize((w, h), Image.BILINEAR))
    return out


def bloom(rgb, strength=1.0, thresh=0.55):
    h, w, _ = rgb.shape
    lum = rgb.max(-1, keepdims=True)
    bright = rgb * np.clip((lum - thresh) / (lum + 1e-6), 0, None)
    out = np.zeros_like(rgb)
    scale = w / 720.0
    for div, rad, wt in ((2, 3, 0.30), (4, 6, 0.28), (8, 10, 0.26), (16, 14, 0.30)):
        sw, sh = max(8, w // div), max(8, h // div)
        small = resize(bright, sw, sh)
        small = gauss(small, rad * scale)
        out += wt * resize(small, w, h)
    return out * strength


def tone(x):
    """Linear toe + soft exponential shoulder, with highlights drifting toward
    white the way real light does (stops hot pink clipping to flat magenta)."""
    m = x.max(-1, keepdims=True)
    k = np.clip((m - 0.8) / 5.0, 0, 0.55)
    x = x * (1 - k) + m * k
    knee = 0.62
    return np.where(x < knee, x, knee + (1 - knee) * (1 - np.exp(-(x - knee) / (1 - knee))))


def to_srgb(a):
    a = np.clip(a, 0, 1)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - 0.055)


_DITHER = {}


def dither(shape):
    if shape not in _DITHER:
        rng = np.random.default_rng(3)
        _DITHER[shape] = ((rng.random(shape) + rng.random(shape)) - 1.0).astype(np.float32) / 255.0
    return _DITHER[shape]


def grade(exr, bg=None, bloom_k=1.0):
    """Returns (opaque_rgb uint8, straight_rgba uint8)."""
    rgb, a = exr[..., :3], exr[..., 3:4]
    b = bloom(rgb, bloom_k)
    disp = to_srgb(tone(rgb + b))                       # light over black, display space
    alpha = np.clip(a + b.max(-1, keepdims=True) * 1.4, 0, 1)
    if bg is None:
        bg = np.broadcast_to(NIGHT, rgb.shape)
    opaque = disp + bg * (1 - alpha)
    straight = np.where(alpha > 1e-4, disp / np.maximum(alpha, 1e-4), 0)
    d = dither(rgb.shape[:2] + (1,))
    q = lambda v: np.clip(np.round((v + d) * 255), 0, 255).astype(np.uint8)
    return q(opaque), np.concatenate([q(np.clip(straight, 0, 1)), q(alpha)], -1)


# ------------------------------------------------------------------ outputs
def frames(dirname):
    d = os.path.join(BUILD, dirname)
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".exr")]


def encode(dirname, base, poster, crf264=23, crfvp9=31, keep=(), poster_frame=0):
    fs = frames(dirname)
    h, w = read_exr(fs[0]).shape[:2]
    mp4 = os.path.join(ROOT, base + ".mp4")
    webm = os.path.join(ROOT, base + ".webm")
    common = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-s", f"{w}x{h}",
              "-r", str(FPS)]
    p1 = subprocess.Popen(common + ["-pix_fmt", "rgb24", "-i", "-",
                                    "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p",
                                    "-c:v", "libx264", "-preset", "veryslow", "-crf", str(crf264),
                                    "-tune", "film", "-g", "60", "-colorspace", "bt709",
                                    "-color_primaries", "bt709", "-color_trc", "bt709",
                                    "-movflags", "+faststart", "-an", mp4], stdin=subprocess.PIPE)
    p2 = subprocess.Popen(common + ["-pix_fmt", "rgba", "-i", "-",
                                    "-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-b:v", "0",
                                    "-crf", str(crfvp9), "-deadline", "good", "-cpu-used", "1",
                                    "-row-mt", "1", "-auto-alt-ref", "0", "-g", "120",
                                    "-an", webm], stdin=subprocess.PIPE)
    os.makedirs(os.path.join(BUILD, "sheet"), exist_ok=True)
    for i, f in enumerate(fs):
        op, st = grade(read_exr(f))
        p1.stdin.write(op.tobytes())
        p2.stdin.write(st.tobytes())
        if i == poster_frame and poster:
            Image.fromarray(op).save(os.path.join(ROOT, poster), optimize=True)
        if i in keep:
            Image.fromarray(op).save(os.path.join(BUILD, "sheet", f"{base}_{i:03d}.png"))
    for p in (p1, p2):
        p.stdin.close()
        p.wait()
    for p in (mp4, webm):
        print(f"{os.path.basename(p)}: {os.path.getsize(p)/1024:.0f} KB, {len(fs)} frames")


def still(exr_path, out_png, bg=None):
    op, _ = grade(read_exr(exr_path), bg)
    Image.fromarray(op).save(out_png, optimize=True)
    print("wrote", out_png)


def hero_bg(w, h):
    """Deep plum-to-night space: a soft plum bloom behind Eve fading to night."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    ny = y / h
    vert = np.clip(ny, 0, 1)[..., None]
    top = PLUM * 0.75 + NIGHT * 0.25
    base = NIGHT * (vert ** 0.7) + top * (1 - vert ** 0.7)
    cx, cy = w * 0.5, h * 0.40
    r = np.sqrt(((x - cx) / (w * 0.85)) ** 2 + ((y - cy) / (h * 0.42)) ** 2)[..., None]
    glow = np.clip(1 - r, 0, 1) ** 2.0
    violet = np.array([0x6E, 0x29, 0xFF]) / 255.0
    base = base + violet * 0.10 * glow + PLUM * 0.35 * glow
    return np.clip(base, 0, 1).astype(np.float32)


def hero(exr_path, out_png):
    exr = read_exr(exr_path)
    h, w = exr.shape[:2]
    op, _ = grade(exr, hero_bg(w, h), bloom_k=1.0)
    Image.fromarray(op).save(out_png, optimize=True)
    print("wrote", out_png, os.path.getsize(out_png) // 1024, "KB")


def sheet(items, out_png, tile=360):
    cols, rows = 3, 2
    W, H = cols * tile, rows * (tile + 28)
    img = Image.new("RGB", (W, H), tuple(int(c * 255) for c in NIGHT))
    dr = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
    for k, (label, path) in enumerate(items):
        r, c = divmod(k, cols)
        im = Image.open(path).convert("RGB").resize((tile, tile), Image.LANCZOS)
        img.paste(im, (c * tile, r * (tile + 28)))
        dr.text((c * tile + 10, r * (tile + 28) + tile + 4), label, fill=(220, 210, 235), font=font)
    img.save(out_png, optimize=True)
    print("wrote", out_png)


if __name__ == "__main__":
    cmd, *rest = sys.argv[1:]
    if cmd == "video":
        dirname, base, poster = rest[:3]
        keep = tuple(int(k) for k in rest[3].split(",")) if len(rest) > 3 else ()
        pf = int(rest[4]) if len(rest) > 4 else 0
        encode(dirname, base, poster if poster != "-" else None, keep=keep, poster_frame=pf)
    elif cmd == "still":
        still(rest[0], rest[1])
    elif cmd == "hero":
        hero(rest[0], rest[1])
    elif cmd == "sheet":
        it = iter(rest[1:])
        sheet(list(zip(it, it)), rest[0])
