"""Breath: a front-facing jasmine (motia) bloom for box breathing.

clip `box` (16 s, seamless):
  0-4 s  inhale  -> petals unfold flat, flower and guide ring expand
  4-8 s  hold    -> held open (only the slow drift + timer bead move)
  8-12 s exhale  -> petals fold back toward the viewer into a bud, ring contracts
  12-16 s hold   -> held closed
A small white-pink bead travels once round the outer track per loop (90 deg per phase),
so the current phase can be read without text. Sine ease in/out on every phase.

  blender -b --factory-startup -P breath.py -- export   -> ../breath.glb
  blender -b --factory-startup -P breath.py -- video    -> EXR frames (16 s @ 30 fps)
"""
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa

TAU = math.tau
T = 16.0
N = 8
R_TRACK = 1.06


def ease(x):
    return 0.5 - 0.5 * math.cos(math.pi * min(max(x, 0.0), 1.0))


def progress(t):
    t = t % T
    if t < 4:
        return ease(t / 4)
    if t < 8:
        return 1.0
    if t < 12:
        return 1.0 - ease((t - 8) / 4)
    return 0.0


# ------------------------------------------------------------ geometry
def petal(L, W, r0, cup, tilt, curve, nu=11, nv=22):
    """Petal lying in the XZ plane pointing +X, facing -Y. Pinwheel tilt across
    the width and a slight sickle curve give the jasmine swirl."""
    v = np.linspace(0, 1, nv)[:, None]
    s = np.linspace(-1, 1, nu)[None, :]
    w = W * np.clip(np.sin(np.pi * v ** 0.72), 0, None) ** 0.75 + 0.004 * (1 - v)
    x = r0 + L * v + 0 * s
    z = s * w + curve * L * v ** 2
    y = -cup * (s ** 2) * w + tilt * s * w - 0.05 * L * np.sin(np.pi * v) * 0.3
    return np.stack([x, y, z], -1)


def tex_petal(name, inner):
    n = 256
    U, V = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
    e = np.abs(2 * U - 1)
    if not inner:
        # cooler and lighter than Eve's plum-pink bud: violet petals, white-pink edges
        c = mix(hex_lin("violet_deep") * 0.45, hex_lin("violet") * 0.8, smoothstep(0.0, 0.5, V))
        c = mix(c, hex_lin("violet_soft") * 0.9, smoothstep(0.5, 1.0, V) * 0.8)
    else:
        c = mix(hex_lin("violet_soft") * 0.6, hex_lin("glow") * 0.75, smoothstep(0.2, 1.0, V) * 0.8)
    edge = smoothstep(0.6, 1.0, e) ** 1.5
    c = c + hex_lin("glow") * (0.30 * edge)[..., None]
    rib = np.exp(-(e / 0.06) ** 2) * 0.12 * smoothstep(0.05, 0.8, V)
    c = c + hex_lin("blush") * rib[..., None]
    c = c + hex_lin("blush") * (0.15 * (1 - V) ** 3)[..., None]   # glow near the heart
    return save_texture(name, np.concatenate([c, np.ones_like(c[..., :1])], -1))


def tex_glow(name, col_a, col_b, peak=0.6, n=256):
    U, V = np.meshgrid(np.linspace(-1, 1, n), np.linspace(-1, 1, n))
    r = np.sqrt(U ** 2 + V ** 2)
    a = np.clip(1 - r, 0, 1) ** 2.2 * peak
    c = mix(hex_lin(col_a), hex_lin(col_b), smoothstep(0.0, 0.8, r))
    return save_texture(name, np.concatenate([c, a[..., None]], -1), alpha=True)


def tex_core(n=64):
    U, V = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
    c = mix(hex_lin("glow"), hex_lin("white"), smoothstep(0.3, 0.9, V) * 0.3)
    return save_texture("breath_core", np.concatenate([c, np.ones_like(c[..., :1])], -1))


def sphere(name, rad, coll, parent=None, nu=32, nv=16, flat=1.0):
    v = np.linspace(0, math.pi, nv)[:, None]
    u = np.linspace(0, TAU, nu)[None, :]
    x = rad * np.sin(v) * np.cos(u)
    z = rad * np.sin(v) * np.sin(u)
    y = -rad * np.cos(v) * flat + 0 * u            # poles on the Y axis (towards camera)
    return grid_mesh(name, np.stack([x, y, z], -1), coll, parent=parent)


def build():
    reset_scene()
    col = collection("Breath")
    root = empty("Breath", coll=col)
    flower = empty("Flower", parent=root, coll=col)
    guide = empty("Guide", parent=root, coll=col)
    arm = empty("TimerArm", parent=root, coll=col)

    m_out = material("BreathPetalOuter", base="plum", emis_img=tex_petal("breath_petal_outer", False),
                     strength=1.0, rough=0.45)
    m_in = material("BreathPetalInner", base="plum", emis_img=tex_petal("breath_petal_inner", True),
                    strength=1.15, rough=0.45)
    m_core = material("BreathCore", base="glow", emis_img=tex_core(), strength=1.3, rough=0.4)
    halo = tex_glow("breath_halo", "violet_soft", "violet_deep", 0.36)
    m_halo = material("BreathAura", base="violet", base_img=halo, alpha_img=halo, emis_img=halo,
                      strength=1.0, rough=1, blend=True, spec=0)
    m_ring = material("BreathGuide", base="white", emis_color="glow", strength=1.2, rough=0.4)
    m_track = material("BreathTrack", base="violet", emis_color="violet_soft", strength=0.55, rough=0.5)
    m_bead = material("BreathBead", base="glow", emis_color="glow", strength=2.6, rough=0.4)

    po = grid_mesh("BreathPetalOuterMesh", petal(0.80, 0.20, 0.10, 0.35, 0.22, 0.10), col)
    assign(po, m_out)
    pi_ = grid_mesh("BreathPetalInnerMesh", petal(0.50, 0.14, 0.07, 0.40, 0.25, 0.12), col)
    assign(pi_, m_in)
    petals = []
    for ring, src, off, dy in (("O", po, 0.0, 0.0), ("I", pi_, 0.5, -0.03)):
        for i in range(N):
            ob = instance(f"Petal{ring}{i}", src.data, col, parent=flower)
            ob.rotation_mode = "ZYX"
            ob["phi"] = TAU * (i + off) / N
            ob["dy"] = dy
            ob.location = (0, dy, 0)
            petals.append(ob)
    bpy.data.objects.remove(po)
    bpy.data.objects.remove(pi_)

    core = sphere("Core", 0.085, col, parent=flower, flat=0.25)   # flat disc, not an orb
    core.location = (0, -0.05, 0)
    assign(core, m_core)
    aura = plane_xz("Aura", 3.0, col, parent=root)
    aura.location = (0, 0.25, 0)
    assign(aura, m_halo)
    ring = torus("GuideRing", R_TRACK, 0.0055, col, parent=guide, nu=160)
    ring.rotation_euler = (math.pi / 2, 0, 0)
    assign(ring, m_ring)
    track = torus("TrackRing", R_TRACK, 0.0035, col, parent=root, nu=192)
    track.rotation_euler = (math.pi / 2, 0, 0)
    assign(track, m_track)
    for k in range(4):                                  # four phase ticks on the track
        tk = sphere(f"Tick{k}", 0.014, col, parent=root, nu=12, nv=8)
        a = math.pi / 2 - k * math.pi / 2
        tk.location = (R_TRACK * math.cos(a), 0, R_TRACK * math.sin(a))
        assign(tk, m_track)
    bead = sphere("Bead", 0.03, col, parent=arm, nu=16, nv=10)
    bead.location = (0, -0.01, R_TRACK)
    assign(bead, m_bead)
    for ob in col.objects:
        if ob.rotation_mode != "ZYX":
            ob.rotation_mode = "XYZ"
    return dict(col=col, root=root, flower=flower, guide=guide, arm=arm, petals=petals,
                core=core, aura=aura)


def pose(t, S):
    p = progress(t)
    P = {}
    for ob in S["petals"]:
        inner = ob.name[5] == "I"
        fold = (1.30 if inner else 1.10) * (1 - p)
        sc = (0.85 + 0.15 * p) if inner else (0.78 + 0.22 * p)
        P[ob.name] = {"rot": (0, ob["phi"], -fold), "scale": (sc,) * 3}
    P["Flower"] = {"rot": (0, -TAU / N * (t / T), 0), "scale": (0.76 + 0.24 * p,) * 3}
    P["Guide"] = {"scale": (0.58 + 0.42 * p,) * 3}
    P["TimerArm"] = {"rot": (0, TAU * (t / T), 0)}        # clockwise from the viewer, starts at 12 o'clock
    P["Core"] = {"scale": (0.85 + 0.35 * p,) * 3}
    P["Aura"] = {"scale": (0.75 + 0.30 * p,) * 3}
    return P


def animate(S):
    objs = [S["flower"], S["guide"], S["arm"], S["core"], S["aura"]] + S["petals"]
    bake_clip("box", int(T * FPS), lambda t: pose(t, S), objs)
    return objs


def dressing():
    rc = collection("RenderOnly")
    k = light("Key", "AREA", (-1.5, -3.0, 2.0), "blush", 50, size=3, coll=rc)
    aim(k, (0, 0, 0))
    r = light("RimViolet", "AREA", (2.2, 1.0, 1.6), "violet_soft", 120, size=1.5, coll=rc)
    aim(r, (0, 0, 0))
    return rc


def do_export():
    S = build()
    animate(S)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in S["col"].objects:
        ob.select_set(True)
    out = os.path.join(ROOT, "breath.glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_force_sampling=True, export_frame_step=1,
        export_optimize_animation_size=False, export_morph=False, export_skins=False,
        export_lights=False, export_cameras=False, export_yup=True, export_apply=False,
        export_image_format="AUTO", export_draco_mesh_compression_enable=False,
        export_extras=False, export_tangents=False,
    )
    print("EXPORTED", out, os.path.getsize(out))


def do_video(stills=False):
    S = build()
    objs = animate(S)
    dressing()
    solo_clip(objs, "box")
    sc = setup_eevee(720, 720, samples=48)
    camera("Cam", (0, -4.3, 0.0), (0, 0, 0), lens=50)
    if stills:
        out = os.path.join(BUILD, "breath_stills")
        os.makedirs(out, exist_ok=True)
        for sec in (0, 2, 6, 10):
            sc.frame_set(int(sec * FPS))
            sc.render.filepath = os.path.join(out, f"box_{sec:02d}.exr")
            bpy.ops.render.render(write_still=True)
        return
    sc.frame_start, sc.frame_end = 0, int(T * FPS) - 1
    out = os.path.join(BUILD, "breath_box")
    os.makedirs(out, exist_ok=True)
    sc.render.filepath = os.path.join(out, "f_")
    bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    mode = (args() or ["export"])[0]
    {"export": do_export, "video": do_video, "stills": lambda: do_video(True)}[mode]()
