"""Shared helpers for the TherapyLink v3 Blender assets (Blender 4.5 LTS, bpy).

Everything here is deterministic so the .glb / video outputs can be rebuilt
from scratch. Colours live in PAL; change them here and re-run build.sh.
"""
import math
import os

import bpy
import numpy as np

ROOT = r"D:\therapylink-recovery\design\3d"
SRC = os.path.join(ROOT, "src")
TEX = os.path.join(SRC, "tex")            # generated textures (embedded into the .glb)
BUILD = r"D:\dev\tmp\tl3d"                # EXR frames and other scratch output
FPS = 30

# Legacy TherapyLink palette (sRGB hex)
PAL = {
    "night": "#1D1E2C",
    "plum": "#34063F",
    "pink": "#F23598",
    "violet": "#8A4FFF",
    "violet_deep": "#6E29FF",
    "violet_soft": "#A36FFF",
    "lime": "#89F336",
    "green": "#38A711",
    "white": "#FFFFFF",
    "blush": "#FFC9E6",   # pink mixed toward white, used only for hot centres / tips
    "glow": "#FFD3EA",    # soft white-pink glow (rings, rim light, firefly motes)
}
# Colour jobs (design system "Jugnu"): violet/pink = Eve. Lime #89F336 means
# "a protection is on / saved on this phone" ONLY, so none of these assets use it.


# ---------------------------------------------------------------- colour
def _s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_srgb(h):
    h = PAL.get(h, h).lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def hex_lin(h):
    return np.array([_s2l(c) for c in hex_srgb(h)])


def lin_to_srgb(a):
    a = np.clip(a, 0.0, 1.0)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - 0.055)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t


# ---------------------------------------------------------------- scene
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.unit_settings.system = "METRIC"
    os.makedirs(TEX, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)
    return sc


def collection(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def empty(name, parent=None, coll=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    o.empty_display_size = 0.1
    (coll or bpy.context.scene.collection).objects.link(o)
    o.parent = parent
    o.location = loc
    return o


def save_texture(name, rgba_lin, alpha=False):
    """rgba_lin: HxWx4 array, colour in *linear*, row 0 = bottom (v=0).
    Stored as an sRGB PNG in src/tex so the build is reproducible."""
    h, w, _ = rgba_lin.shape
    arr = rgba_lin.copy()
    arr[..., :3] = lin_to_srgb(arr[..., :3])
    arr[..., 3] = np.clip(arr[..., 3], 0, 1)
    if not alpha:
        arr[..., 3] = 1.0
    img = bpy.data.images.new(name, w, h, alpha=alpha)
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    path = os.path.join(TEX, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.filepath = path
    img.reload()
    if alpha:
        img.alpha_mode = "STRAIGHT"
    return img


# ---------------------------------------------------------------- meshes
def grid_mesh(name, P, coll, parent=None, close_u=False, uv=None, smooth=True):
    """P: (nv, nu, 3) grid of points. Rows along v, columns along u.
    close_u wraps the last column onto the first (surfaces of revolution use a
    duplicated seam column instead so the UVs stay clean)."""
    nv, nu, _ = P.shape
    verts = P.reshape(-1, 3)
    faces = []
    ucount = nu if close_u else nu - 1
    for j in range(nv - 1):
        for i in range(ucount):
            i2 = (i + 1) % nu
            faces.append((j * nu + i, j * nu + i2, (j + 1) * nu + i2, (j + 1) * nu + i))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces)
    if uv is None:
        U, V = np.meshgrid(np.linspace(0, 1, nu), np.linspace(0, 1, nv))
        uv = np.stack([U, V], -1)
    uvl = me.uv_layers.new(name="UVMap")
    flat_uv = uv.reshape(-1, 2)
    loop_uv = np.array([flat_uv[l.vertex_index] for l in me.loops])
    uvl.data.foreach_set("uv", loop_uv.ravel())
    if smooth:
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    ob.parent = parent
    return ob


def instance(name, mesh, coll, parent=None):
    ob = bpy.data.objects.new(name, mesh)
    coll.objects.link(ob)
    ob.parent = parent
    return ob


def torus_points(R, r, nu=128, nv=8):
    # seam columns/rows duplicated so UVs run cleanly 0..1 around the ring
    u = np.linspace(0, 2 * math.pi, nu + 1)[None, :]
    v = np.linspace(0, 2 * math.pi, nv + 1)[:, None]
    x = (R + r * np.cos(v)) * np.cos(u)
    y = (R + r * np.cos(v)) * np.sin(u)
    z = r * np.sin(v) + 0 * u
    return np.stack([x, y, z], -1)


def torus(name, R, r, coll, parent=None, nu=128, nv=8):
    """Thin ring in the XY plane; UV u = angle / 2pi (front, facing -Y, is u=0.75)."""
    return grid_mesh(name, torus_points(R, r, nu, nv), coll, parent=parent)


def plane_xz(name, size, coll, parent=None):
    """Square in the XZ plane facing -Y (towards the default camera)."""
    h = size / 2
    me = bpy.data.meshes.new(name)
    me.from_pydata([(-h, 0, -h), (h, 0, -h), (h, 0, h), (-h, 0, h)], [], [(0, 1, 2, 3)])
    uvl = me.uv_layers.new(name="UVMap")
    uvl.data.foreach_set("uv", [0, 0, 1, 0, 1, 1, 0, 1])
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    ob.parent = parent
    return ob


# ---------------------------------------------------------------- materials
def material(name, base="#34063F", emis_img=None, emis_color=None, strength=1.0,
             rough=0.55, alpha_img=None, base_img=None, blend=False, double=True,
             spec=0.3):
    """A glTF-exportable Principled material: base colour (+ optional texture),
    emissive texture or colour with strength (KHR_materials_emissive_strength),
    optional alpha from the base texture's alpha channel."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.name = "BSDF"
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = spec
    bsdf.inputs["Base Color"].default_value = (*hex_lin(base), 1)
    if base_img is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = base_img
        t.name = "BaseTex"
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_img is base_img:
            nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
    if emis_img is not None:
        if base_img is not None and emis_img is base_img:
            t = nt.nodes["BaseTex"]
        else:
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = emis_img
            t.name = "EmisTex"
        nt.links.new(t.outputs["Color"], bsdf.inputs["Emission Color"])
    elif emis_color is not None:
        bsdf.inputs["Emission Color"].default_value = (*hex_lin(emis_color), 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    m.use_backface_culling = not double
    if blend:
        m.surface_render_method = "BLENDED"
        try:
            m.blend_method = "BLEND"
        except Exception:
            pass
        m.use_transparency_overlap = False
    return m


def assign(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


# ---------------------------------------------------------------- animation
def bake_clip(clip, frames, pose_fn, objects):
    """Key every frame 0..frames (inclusive; last == first so loops are seamless)
    from pose_fn(t_seconds) -> {obj_name: {"loc":..., "rot":..., "scale":...}},
    then push each object's action into an NLA track named `clip`.
    The glTF exporter (NLA_TRACKS mode) turns each track name into one animation."""
    actions = {}
    for ob in objects:
        ad = ob.animation_data or ob.animation_data_create()
        act = bpy.data.actions.new(f"{clip}__{ob.name}")
        ad.action = act
        actions[ob.name] = act
    for f in range(frames + 1):
        t = f / FPS
        pose = pose_fn(t)
        for ob in objects:
            p = pose.get(ob.name, {})
            if "loc" in p:
                ob.location = p["loc"]
                ob.keyframe_insert("location", frame=f)
            if "rot" in p:
                ob.rotation_euler = p["rot"]
                ob.keyframe_insert("rotation_euler", frame=f)
            if "scale" in p:
                ob.scale = p["scale"]
                ob.keyframe_insert("scale", frame=f)
    for ob in objects:
        ad = ob.animation_data
        act = actions[ob.name]
        for fc in _fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        slot = getattr(ad, "action_slot", None)
        tr = ad.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, 0, act)
        if slot is not None and hasattr(st, "action_slot"):
            try:
                st.action_slot = slot
            except Exception:
                pass
        st.extrapolation = "HOLD"
        ad.action = None


def _fcurves(act):
    if hasattr(act, "fcurves") and len(act.fcurves):
        return act.fcurves
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def solo_clip(objects, clip):
    """Mute every NLA track except `clip` (used for rendering)."""
    for ob in objects:
        ad = ob.animation_data
        if not ad:
            continue
        for tr in ad.nla_tracks:
            tr.mute = tr.name != clip


# ---------------------------------------------------------------- render
def setup_eevee(res_x, res_y, samples=32):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    ee = sc.eevee
    ee.taa_render_samples = samples
    for attr, val in (("use_raytracing", False), ("use_shadows", True),
                      ("use_volumetric_shadows", False)):
        if hasattr(ee, attr):
            setattr(ee, attr, val)
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    im = sc.render.image_settings
    im.file_format = "OPEN_EXR"
    im.color_mode = "RGBA"
    im.color_depth = "16"
    im.exr_codec = "ZIP"
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*(hex_lin("night") * 0.6 + hex_lin("plum") * 0.4), 1)
    bg.inputs["Strength"].default_value = 0.6
    sc.world = w
    return sc


def camera(name, loc, target, lens=50, coll=None):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_start = 0.05
    cam.clip_end = 100
    ob = bpy.data.objects.new(name, cam)
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    tgt = empty(name + "_target", coll=coll, loc=target)
    c = ob.constraints.new("TRACK_TO")
    c.target = tgt
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    bpy.context.scene.camera = ob
    return ob


def light(name, kind, loc, color, energy, size=0.5, rot=None, coll=None, shadow=False):
    ld = bpy.data.lights.new(name, kind)
    ld.color = tuple(hex_lin(color))
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    else:
        ld.shadow_soft_size = size
    if hasattr(ld, "use_shadow"):
        ld.use_shadow = shadow
    ob = bpy.data.objects.new(name, ld)
    (coll or bpy.context.scene.collection).objects.link(ob)
    ob.location = loc
    if rot:
        ob.rotation_euler = rot
    return ob


def aim(ob, target):
    from mathutils import Vector
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def args():
    import sys
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
