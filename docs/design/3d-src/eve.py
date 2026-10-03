"""Eve: an abstract luminous presence for TherapyLink v3.

Form: a twisted jasmine/lotus bud (five outer + five inner petals, imbricate
like a motia bud) around a hidden diya-flame core, floating over two thin violet /
white-pink ripple rings, with a violet aura and a slow three-arm haze swirl behind it.

All motion is object transforms (petal hinges, ring rotation, scale), so it
survives glTF export in every runtime (no shader animation, no morph targets).

Usage (headless):
  blender -b --factory-startup -P eve.py -- export            -> ../eve.glb
  blender -b --factory-startup -P eve.py -- video             -> EXR frames, idle loop 720x720
  blender -b --factory-startup -P eve.py -- stills            -> EXR stills for review sheet
  blender -b --factory-startup -P eve.py -- hero              -> EXR 1080x1920 hero
"""
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa

TAU = math.tau
CLIPS = {"idle": 8.0, "listening": 4.0, "thinking": 8.0}
N_PET = 5

# Bud geometry
OUT = dict(r0=0.02, Rm=0.29, H=1.06, width=1.22, twist=0.45, rscale=1.00, z0=0.0)
INN = dict(r0=0.015, Rm=0.29, H=1.00, width=1.08, twist=0.32, rscale=0.90, z0=0.025)


# ============================================================== geometry
def bud_profile(v, r0, Rm, H):
    """Lotus/jasmine bud silhouette: round bottom, widest at ~35% height,
    long tapering point (also reads as a diya flame)."""
    s = np.clip(np.sin(np.pi * np.power(v, 0.66)), 0, None)
    r = r0 * (1 - v) + Rm * s ** 0.85 + 0.004
    z = H * v
    return r, z


def petal_grid(r0, Rm, H, width, twist, rscale, z0=0.0, nu=15, nv=32):
    v = np.linspace(0, 1, nv)[:, None]
    s = np.linspace(-1, 1, nu)[None, :]
    r, z = bud_profile(v, r0, Rm, H)
    r = r * rscale
    sector = math.pi / N_PET
    hw = sector * width * (0.80 + 0.20 * np.sin(np.pi * np.clip(v, 0, 1) ** 0.8) ** 0.55)
    hw = hw * np.sqrt(np.clip(1 - v ** 3.5, 0, 1)) + 0.002
    phi = math.pi / 2 + s * hw + twist * v ** 1.4
    # imbricate overlap: + edge rides outside its neighbour's - edge (no z-fighting)
    rr = r + 0.022 * s * np.sqrt(r / Rm) + 0.010 * (1 - s ** 2) * np.sin(np.pi * v)
    x = rr * np.cos(phi)
    y = rr * np.sin(phi) - r0 * rscale       # origin at the hinge
    zz = np.broadcast_to(z + z0, x.shape)
    return np.stack([x, y, zz], -1)


def core_grid(nu=40, nv=28):
    v = np.linspace(0, 1, nv)[:, None]
    th = np.linspace(0, TAU, nu)[None, :]
    r = 0.15 * np.clip(np.sin(np.pi * v ** 0.62), 0, None) ** 0.85 + 0.003
    z = 0.14 + 0.60 * v
    lean = 0.035 * np.sin(np.pi * v) * v      # tip leans: makes rotation readable
    x = r * np.cos(th) + lean
    y = r * np.sin(th)
    return np.stack([x, y, np.broadcast_to(z, x.shape)], -1)


# ============================================================== textures
def tex_petal(name, inner=False, n=256):
    """u = across the petal, v = base -> tip. Deep plum at the base rising to hot
    pink at the tip (a lotus bud's own colouring), luminous edges where light from
    the hidden flame leaks round, and a faint midrib."""
    U, V = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
    e = np.abs(2 * U - 1)
    plum, violet, pink, blush = (hex_lin(k) for k in ("plum", "violet_deep", "pink", "blush"))
    body = mix(plum * 0.7, (plum * 0.62 + pink * 0.18 + violet * 0.2) * 1.25, smoothstep(0.08, 0.6, V))
    c = mix(body, pink * 0.85, smoothstep(0.38, 1.0, V) ** 1.4)
    edge = smoothstep(0.55, 1.0, e) ** 1.6
    c = c + mix(pink, blush, 0.15) * (0.55 * edge * smoothstep(0.05, 0.5, V))[..., None]
    rib = np.exp(-(e / 0.05) ** 2) * 0.10 * smoothstep(0.1, 0.7, V)
    c = c + pink * rib[..., None]
    veins = (np.cos(e * np.pi * 4) * 0.5 + 0.5) ** 14 * 0.035 * (1 - edge)
    c = c + pink * veins[..., None]
    tip = smoothstep(0.82, 1.0, V)
    c = mix(c, mix(pink, blush, 0.5), tip * 0.5)
    if inner:
        c = mix(c, mix(pink, blush, 0.45), 0.55) + pink * (0.25 * (1 - V) ** 2)[..., None]
    rgba = np.concatenate([c, np.ones_like(c[..., :1])], -1)
    return save_texture(name, rgba)


def tex_ripple(name="eve_ripple", color="glow", n=512):
    """Alpha along the ring: bright at the front, fading round the back, so the
    ripple reads as a glint on water rather than a neon hoop."""
    U, V = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, 4))
    front = (0.5 + 0.5 * np.cos(TAU * (U - 0.75))) ** 1.8
    a = 0.06 + 0.94 * front
    c = np.broadcast_to(hex_lin(color), U.shape + (3,))
    return save_texture(name, np.concatenate([c, a[..., None]], -1), alpha=True)


def tex_core(n=128):
    U, V = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
    c = mix(hex_lin("violet_soft"), hex_lin("pink"), smoothstep(0.0, 0.45, V))
    c = mix(c, hex_lin("blush"), smoothstep(0.4, 0.8, V))
    c = mix(c, hex_lin("white"), smoothstep(0.8, 1.0, V))
    return save_texture("eve_core", np.concatenate([c, np.ones_like(c[..., :1])], -1))


def tex_halo(n=256):
    U, V = np.meshgrid(np.linspace(-1, 1, n), np.linspace(-1, 1, n))
    r = np.sqrt(U ** 2 + V ** 2)
    a = np.clip(1 - r, 0, 1) ** 2.6 * 0.5
    c = mix(mix(hex_lin("violet_soft"), hex_lin("violet"), smoothstep(0.0, 0.35, r)),
            hex_lin("violet_deep"), smoothstep(0.35, 1.0, r))
    return save_texture("eve_halo", np.concatenate([c, a[..., None]], -1), alpha=True)


def tex_swirl(n=512):
    U, V = np.meshgrid(np.linspace(-1, 1, n), np.linspace(-1, 1, n))
    r = np.sqrt(U ** 2 + V ** 2) + 1e-6
    th = np.arctan2(V, U)
    arms = (0.5 + 0.5 * np.cos(3 * th - 4.2 * np.log(r + 0.08))) ** 2.5
    env = smoothstep(0.08, 0.38, r) * (1 - smoothstep(0.55, 0.98, r))
    a = arms * env * 0.22
    c = mix(hex_lin("violet_soft"), hex_lin("pink"), smoothstep(0.25, 0.85, r) * 0.6)
    return save_texture("eve_swirl", np.concatenate([c, a[..., None]], -1), alpha=True)


# ============================================================== build
def build():
    reset_scene()
    col = collection("Eve")
    root = empty("Eve", coll=col)
    bloom = empty("Bloom", parent=root, coll=col)
    outer = empty("OuterPetals", parent=bloom, coll=col)
    inner = empty("InnerPetals", parent=bloom, coll=col)
    aura = empty("Aura", parent=root, coll=col, loc=(0, 0.30, 0.50))
    ripple = empty("Ripple", parent=root, coll=col, loc=(0, 0, -0.07))

    m_out = material("PetalOuter", base="plum", emis_img=tex_petal("eve_petal_outer"),
                     strength=1.25, rough=0.45)
    m_in = material("PetalInner", base="plum", emis_img=tex_petal("eve_petal_inner", inner=True),
                    strength=1.9, rough=0.45)
    m_core = material("Core", base="pink", emis_img=tex_core(), strength=4.0, rough=0.4)
    halo_img, swirl_img = tex_halo(), tex_swirl()
    m_halo = material("Aura", base="violet", base_img=halo_img, alpha_img=halo_img,
                      emis_img=halo_img, strength=1.0, rough=1.0, blend=True, spec=0.0)
    m_swirl = material("Swirl", base="violet_soft", base_img=swirl_img, alpha_img=swirl_img,
                       emis_img=swirl_img, strength=1.2, rough=1.0, blend=True, spec=0.0)
    rip = tex_ripple("eve_ripple", "glow")
    rip2 = tex_ripple("eve_ripple_violet", "violet_soft")
    m_ring = material("Ripple", base="glow", base_img=rip, alpha_img=rip, emis_img=rip,
                      strength=1.3, rough=0.4, blend=True)
    m_ring2 = material("RippleFaint", base="violet_soft", base_img=rip2, alpha_img=rip2,
                       emis_img=rip2, strength=1.1, rough=0.4, blend=True)

    # petals: one mesh per ring, instanced five times (keeps the glb small)
    po = grid_mesh("PetalOuterMesh", petal_grid(**OUT), col)
    assign(po, m_out)
    pi_ = grid_mesh("PetalInnerMesh", petal_grid(**INN), col)
    assign(pi_, m_in)
    petals = []
    for ring, src, prm, off, par in (("O", po, OUT, 0.0, outer), ("I", pi_, INN, 0.5, inner)):
        for i in range(N_PET):
            phi = TAU * (i + off) / N_PET
            ob = instance(f"Petal{ring}{i}", src.data, col, parent=par)
            ob.location = (-prm["r0"] * prm["rscale"] * math.sin(phi),
                           prm["r0"] * prm["rscale"] * math.cos(phi), 0)
            ob.rotation_mode = "XYZ"
            ob.rotation_euler = (0, 0, phi)
            ob["phi"] = phi
            petals.append(ob)
    bpy.data.objects.remove(po)
    bpy.data.objects.remove(pi_)

    core = grid_mesh("Core", core_grid(), col, parent=bloom)
    assign(core, m_core)
    halo = plane_xz("Halo", 2.1, col, parent=aura)
    assign(halo, m_halo)
    swirl = plane_xz("Swirl", 1.9, col, parent=aura)
    swirl.location = (0, -0.02, 0)
    assign(swirl, m_swirl)
    ra = torus("RingA", 0.40, 0.0045, col, parent=ripple)
    assign(ra, m_ring)
    rb = torus("RingB", 0.58, 0.003, col, parent=ripple, nu=160)
    rb.location = (0, 0, -0.012)
    assign(rb, m_ring2)
    for ob in col.objects:
        ob.rotation_mode = "XYZ"
    return dict(col=col, root=root, bloom=bloom, outer=outer, inner=inner, aura=aura,
                ripple=ripple, petals=petals, core=core, swirl=swirl, ra=ra, rb=rb)


# ============================================================== motion
def wave(t, T, d=0.0):
    """0 -> 1 -> 0 over one period (exhaled at t=0, inhaled at T/2)."""
    return 0.5 - 0.5 * math.cos(TAU * t / T - d)


def pose(clip, t, S):
    T = CLIPS[clip]
    ph = TAU * t / T
    P = {}

    def pet(open_o, amp_o, open_i, amp_i, lag=0.35):
        for ob in S["petals"]:
            ring = ob.name[5]
            i = int(ob.name[6:])
            if ring == "O":
                a = open_o + amp_o * wave(t, T, 0.20 + lag * i / N_PET)
            else:
                a = open_i + amp_i * wave(t, T, 0.75 + lag * i / N_PET)
            P[ob.name] = {"rot": (-a, 0, ob["phi"])}

    if clip == "idle":
        b = wave(t, T)
        P["Eve"] = {"loc": (0, 0, 0.035 * (b - 0.5)), "scale": (1 + 0.02 * b,) * 3}
        P["Bloom"] = {"rot": (0.022 * math.sin(ph), 0.018 * math.sin(ph + 1.3), 0)}
        P["OuterPetals"] = {"rot": (0, 0, 0.045 * math.sin(ph))}
        P["InnerPetals"] = {"rot": (0, 0, -0.055 * math.sin(ph))}
        pet(0.025, 0.095, 0.012, 0.06)
        P["Core"] = {"scale": (1 + 0.07 * wave(t, T, 0.2),) * 3, "rot": (0, 0, 0)}
        P["Aura"] = {"scale": (1 + 0.08 * wave(t, T, 0.3),) * 3}
        P["Swirl"] = {"rot": (0, 0.14 * math.sin(ph), 0)}
        P["RingA"] = {"scale": (1 + 0.05 * wave(t, T, 0.5), 1 + 0.05 * wave(t, T, 0.5), 1)}
        P["RingB"] = {"scale": (1 + 0.07 * wave(t, T, 0.9), 1 + 0.07 * wave(t, T, 0.9), 1)}
    elif clip == "listening":
        b = wave(t, T)
        P["Eve"] = {"loc": (0, 0, 0.02 + 0.012 * (b - 0.5)), "scale": (1.03 + 0.015 * b,) * 3}
        P["Bloom"] = {"rot": (0.10 + 0.018 * math.sin(ph), 0, 0)}
        P["OuterPetals"] = {"rot": (0, 0, 0.02 * math.sin(ph))}
        P["InnerPetals"] = {"rot": (0, 0, -0.02 * math.sin(ph))}
        pet(0.17, 0.05, 0.09, 0.03, lag=0.2)
        P["Core"] = {"scale": (1.14 + 0.05 * b,) * 3, "rot": (0, 0, 0)}
        P["Aura"] = {"scale": (1.17 + 0.05 * wave(t, T, 0.2),) * 3}
        P["Swirl"] = {"rot": (0, 0.05 * math.sin(ph), 0)}
        P["RingA"] = {"scale": (1.07 + 0.04 * b, 1.07 + 0.04 * b, 1)}
        P["RingB"] = {"scale": (1.10 + 0.05 * wave(t, T, 0.4), 1.10 + 0.05 * wave(t, T, 0.4), 1)}
    elif clip == "thinking":
        b = wave(t, T)
        u = t / T
        P["Eve"] = {"loc": (0, 0, 0.02 * (b - 0.5)), "scale": (1.0,) * 3}
        P["Bloom"] = {"rot": (0.03 * math.sin(ph), 0.03 * math.cos(ph), 0)}
        P["OuterPetals"] = {"rot": (0, 0, TAU / N_PET * u)}
        P["InnerPetals"] = {"rot": (0, 0, -TAU / N_PET * u)}
        pet(0.01, 0.035, 0.005, 0.02)
        P["Core"] = {"scale": (0.96 + 0.04 * b,) * 3, "rot": (0, 0, TAU * u)}
        P["Aura"] = {"scale": (0.98 + 0.05 * b,) * 3}
        P["Swirl"] = {"rot": (0, -TAU / 3 * u, 0)}
        P["RingA"] = {"scale": (1 + 0.03 * b, 1 + 0.03 * b, 1)}
        P["RingB"] = {"scale": (1 + 0.04 * wave(t, T, 0.6), 1 + 0.04 * wave(t, T, 0.6), 1)}
    return P


def animate(S):
    objs = [S[k] for k in ("root", "bloom", "outer", "inner", "core", "aura", "swirl", "ra", "rb")]
    objs += S["petals"]
    for clip, T in CLIPS.items():
        bake_clip(clip, int(round(T * FPS)), lambda t, c=clip: pose(c, t, S), objs)
    return objs


# ============================================================== render-only dressing
def render_dressing(S, motes=True, petals_drift=0):
    """Extras that only exist in the pre-rendered loops / posters: a soft white-pink fresnel
    rim and brighter petal interiors (shader-only, can't be exported), lights,
    and slow motes."""
    rimcol = hex_lin("glow")
    for name, rim in (("PetalOuter", 1.0), ("PetalInner", 0.5)):
        m = bpy.data.materials[name]
        nt = m.node_tree
        bsdf = nt.nodes["BSDF"]
        tex = nt.nodes["EmisTex"]
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.12
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        # rim = fresnel^3 on front faces only
        p = nt.nodes.new("ShaderNodeMath"); p.operation = "POWER"; p.inputs[1].default_value = 2.2
        nt.links.new(lw.outputs["Facing"], p.inputs[0])
        inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
        nt.links.new(geo.outputs["Backfacing"], inv.inputs[1])
        rimm = nt.nodes.new("ShaderNodeMath"); rimm.operation = "MULTIPLY"
        nt.links.new(p.outputs[0], rimm.inputs[0]); nt.links.new(inv.outputs[0], rimm.inputs[1])
        rimm2 = nt.nodes.new("ShaderNodeMath"); rimm2.operation = "MULTIPLY"; rimm2.inputs[1].default_value = 0.55 * rim
        nt.links.new(rimm.outputs[0], rimm2.inputs[0])
        mixc = nt.nodes.new("ShaderNodeMix"); mixc.data_type = "RGBA"; mixc.blend_type = "MIX"
        nt.links.new(rimm2.outputs[0], mixc.inputs["Factor"])
        nt.links.new(tex.outputs["Color"], mixc.inputs["A"])
        mixc.inputs["B"].default_value = (*(rimcol * 1.4), 1)
        # interiors (backfaces) glow brighter, lit by the flame
        bf = nt.nodes.new("ShaderNodeMath"); bf.operation = "MULTIPLY_ADD"
        nt.links.new(geo.outputs["Backfacing"], bf.inputs[0])
        bf.inputs[1].default_value = 1.2
        bf.inputs[2].default_value = 1.0
        mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        nt.links.new(mixc.outputs["Result"], mul.inputs["A"])
        comb = nt.nodes.new("ShaderNodeCombineColor")
        for k in ("Red", "Green", "Blue"):
            nt.links.new(bf.outputs[0], comb.inputs[k])
        nt.links.new(comb.outputs[0], mul.inputs["B"])
        nt.links.new(mul.outputs["Result"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Coat Weight"].default_value = 0.35
        bsdf.inputs["Coat Roughness"].default_value = 0.25
    rc = collection("RenderOnly")
    light("FlameLight", "POINT", (0, 0, 0.42), "pink", 40, size=0.12, coll=rc).parent = S["bloom"]
    k = light("Key", "AREA", (-1.6, -2.2, 2.4), "blush", 45, size=2.5, coll=rc)
    aim(k, (0, 0, 0.4))
    r = light("RimViolet", "AREA", (1.5, 1.8, 1.4), "violet_soft", 220, size=1.0, coll=rc)
    aim(r, (0, 0, 0.5))
    r2 = light("RimPink", "AREA", (-1.6, 1.6, 0.6), "pink", 90, size=1.2, coll=rc)
    aim(r2, (0, 0, 0.4))
    if motes:
        add_motes(rc, S["root"])
    return rc


def add_motes(coll, parent, n=11, seed=7, T=8.0):
    rng = np.random.default_rng(seed)
    me = bpy.data.meshes.new("Mote")
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    cols = ["glow", "glow", "violet_soft", "blush"]   # warm fireflies, a few violet
    mats = {c: material("Mote_" + c, base=c, emis_color=c, strength=4.0) for c in cols}
    motes = []
    for i in range(n):
        ob = bpy.data.objects.new(f"Mote{i}", me.copy())
        assign(ob, mats[cols[i % 4]])
        coll.objects.link(ob)
        ob.parent = parent
        ang = rng.uniform(0, TAU)
        rad = rng.uniform(0.55, 0.95)
        x0, y0 = rad * math.cos(ang), rad * math.sin(ang) * 0.6
        z0 = rng.uniform(-0.15, 0.35)
        size = rng.uniform(0.006, 0.013)
        off = rng.uniform(0, 1)
        sway = rng.uniform(0.02, 0.06)
        for f in range(int(T * FPS) + 1):
            s = (f / (T * FPS) + off) % 1.0
            ob.location = (x0 + sway * math.sin(TAU * s), y0, z0 + 0.55 * s)
            ob.scale = (size * math.sin(math.pi * s) ** 1.5 + 1e-5,) * 3
            ob.keyframe_insert("location", frame=f)
            ob.keyframe_insert("scale", frame=f)
        motes.append(ob)
    return motes


def eve_camera(res=(720, 720), lens=50, dist=3.7, height=0.95, target_z=0.45):
    return camera("Cam", (0, -dist, height), (0, 0, target_z), lens=lens)


# ============================================================== modes
def do_export():
    S = build()
    animate(S)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in S["col"].objects:
        ob.select_set(True)
    out = os.path.join(ROOT, "eve.glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_force_sampling=True, export_frame_step=1,
        export_optimize_animation_size=False, export_anim_single_armature=False,
        export_morph=False, export_skins=False, export_lights=False, export_cameras=False,
        export_yup=True, export_apply=False, export_image_format="AUTO",
        export_draco_mesh_compression_enable=False, export_extras=False,
        export_texcoords=True, export_normals=True, export_tangents=False,
    )
    print("EXPORTED", out, os.path.getsize(out))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BUILD, "eve.blend"))


def do_video():
    S = build()
    objs = animate(S)
    render_dressing(S)
    solo_clip(objs, "idle")
    sc = setup_eevee(720, 720, samples=48)
    eve_camera()
    T = int(CLIPS["idle"] * FPS)
    sc.frame_start, sc.frame_end = 0, T - 1
    out = os.path.join(BUILD, "eve_idle")
    os.makedirs(out, exist_ok=True)
    sc.render.filepath = os.path.join(out, "f_")
    bpy.ops.render.render(animation=True)


def do_stills():
    S = build()
    objs = animate(S)
    render_dressing(S)
    sc = setup_eevee(720, 720, samples=48)
    eve_camera()
    out = os.path.join(BUILD, "eve_stills")
    os.makedirs(out, exist_ok=True)
    for clip, sec in (("idle", 0.0), ("idle", 4.0), ("listening", 2.0), ("thinking", 3.0)):
        solo_clip(objs, clip)
        sc.frame_set(int(sec * FPS))
        sc.render.filepath = os.path.join(out, f"{clip}_{sec:.0f}.exr")
        bpy.ops.render.render(write_still=True)


def do_hero():
    S = build()
    objs = animate(S)
    rc = render_dressing(S, motes=False)
    add_drift(rc)
    solo_clip(objs, "idle")
    sc = setup_eevee(1080, 1920, samples=96)
    cam = camera("Cam", (0, -5.3, 0.8), (0, 0, 0.05), lens=42)
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = 5.3
    cam.data.dof.aperture_fstop = 0.7
    sc.frame_set(int(4.0 * FPS))
    sc.render.filepath = os.path.join(BUILD, "eve_hero.exr")
    bpy.ops.render.render(write_still=True)


def add_drift(coll, n=34, seed=11):
    """Faint jasmine petals and motes drifting at various depths (hero only)."""
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, 8)[:, None]
    s = np.linspace(-1, 1, 5)[None, :]
    w = 0.5 * np.sin(np.pi * v ** 0.8) ** 0.7
    x = s * w
    y = 0.25 * (s ** 2) * w + 0.1 * v ** 2
    z = v + 0 * s
    pm = grid_mesh("DriftPetal", np.stack([x, y, z], -1), coll).data
    import bmesh
    me = bpy.data.meshes.new("DriftMote")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    bm.to_mesh(me)
    bm.free()
    m_pet = material("DriftPetal", base="glow", emis_color="glow", strength=0.45)
    m_pet2 = material("DriftPetalPink", base="blush", emis_color="pink", strength=0.4)
    m_mote = material("DriftMote", base="glow", emis_color="glow", strength=3.0)
    m_violet = material("DriftViolet", base="violet_soft", emis_color="violet_soft", strength=3.0)
    bpy.data.objects.remove(bpy.data.objects["DriftPetal"])
    pm.materials.append(m_pet)
    me.materials.append(m_mote)
    for i in range(n):
        is_pet = i % 3 != 0
        ob = bpy.data.objects.new(f"Drift{i}", pm if is_pet else me)
        coll.objects.link(ob)
        while True:   # keep the drift clear of Eve herself
            y = rng.uniform(-3.0, 4.0)
            x = rng.uniform(-1.7, 1.7) * (1 + y * 0.3)
            z = rng.uniform(-2.6, 2.8)
            if not (abs(x) < 0.75 and -0.35 < z < 1.35 and y < 1.2):
                break
        ob.location = (x, y, z)
        ob.rotation_euler = tuple(rng.uniform(0, TAU, 3))
        if is_pet:
            ob.scale = (rng.uniform(0.028, 0.055),) * 3
        else:
            ob.scale = (rng.uniform(0.005, 0.011),) * 3
        mat = (m_pet if i % 2 else m_pet2) if is_pet else (m_violet if i % 4 == 0 else m_mote)
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = mat


if __name__ == "__main__":
    mode = (args() or ["export"])[0]
    {"export": do_export, "video": do_video, "stills": do_stills, "hero": do_hero}[mode]()
