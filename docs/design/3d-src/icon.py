"""Brand renders of Eve for the launcher icon, splash and store art.

Same bud as eve.py (imported, not copied), rendered for small sizes:
  - front view, orthographic, petals at rest (closed bud)
  - no aura card, no haze swirl, no ripple rings, no motes
  - tips just parting (a notched crown), so it reads as a bud and not a drop
  - rim lights kept and the violet rim raised, so both edges separate from the ground

Usage (headless):
  blender -b --factory-startup -P icon.py -- bud       -> BUILD/brand/bud.exr      2048x2048, transparent
  blender -b --factory-startup -P icon.py -- feature   -> BUILD/brand/feature.exr  1200x1200, aura + rings
brand.py turns these into the icon, splash and store PNGs.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa
import eve

OUT = os.path.join(BUILD, "brand")


def rest_pose(S, open_o=0.09, open_i=0.04):
    """Bud with the tips just parting. Fully closed it reads as a water drop at 48 px;
    the small notched crown is what makes it read as a flower bud."""
    for ob in S["petals"]:
        a = open_o if ob.name[5] == "O" else open_i
        ob.rotation_euler = (-a, 0, ob["phi"])


def front_camera(scale, target_z, tilt_deg=4.0, dist=6.0):
    """Orthographic, nearly straight on. A few degrees of tilt shows the parted tip."""
    t = math.radians(tilt_deg)
    cam = camera("Cam", (0, -dist * math.cos(t), target_z + dist * math.sin(t)),
                 (0, 0, target_z))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    return cam


def hide(*obs):
    for ob in obs:
        ob.hide_render = True
        for ch in ob.children_recursive:
            ch.hide_render = True


def do_bud(open_o="0.09", open_i="0.04", name="bud", rim="2.2"):
    S = eve.build()
    eve.render_dressing(S, motes=False)
    rest_pose(S, float(open_o), float(open_i))
    # the violet rim on the right is what keeps the shadow side off the ground at 48 px
    bpy.data.objects["RimViolet"].data.energy = 220 * float(rim)
    hide(S["aura"], S["ripple"])
    # the flame light also lifts the inside of the tip; keep it, but a touch brighter for small sizes
    bpy.data.objects["FlameLight"].data.energy = 55
    sc = setup_eevee(2048, 2048, samples=96)
    front_camera(1.5, 0.53)
    os.makedirs(OUT, exist_ok=True)
    sc.render.filepath = os.path.join(OUT, name + ".exr")
    bpy.ops.render.render(write_still=True)


def do_feature():
    S = eve.build()
    eve.render_dressing(S, motes=False)
    rest_pose(S, 0.05, 0.025)
    sc = setup_eevee(1200, 1200, samples=96)
    cam = eve.eve_camera()
    cam.data.lens = 42
    os.makedirs(OUT, exist_ok=True)
    sc.render.filepath = os.path.join(OUT, "feature.exr")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    a = args() or ["bud"]
    {"bud": do_bud, "feature": do_feature}[a[0]](*a[1:])
