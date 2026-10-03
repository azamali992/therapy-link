#!/usr/bin/env bash
# Rebuild every TherapyLink v3 3D asset from scratch (Git Bash on Windows).
# Needs: Blender 4.5 LTS at D:\dev\blender, ffmpeg at D:\dev\tools\ffmpeg-*,
# OpenEXR + Pillow in D:\dev\tools\pylibs (pip install --target).
# Usage: bash build.sh [eve|breath|hero|sheet|all]
#        bash build.sh brand <repo>   (launcher icon, splash, store art; not part of "all")
set -euo pipefail
cd "$(dirname "$0")"
export TMP='D:\dev\tmp' TEMP='D:\dev\tmp' PYTHONPATH='D:\dev\tools\pylibs'
B=/d/dev/blender/blender.exe
PY=/d/dev/blender/4.5/python/bin/python.exe
T=/d/dev/tmp/tl3d
what=${1:-all}
run() { "$B" -b --factory-startup -P "$@" 2>&1 | grep -iE "error|traceback|EXPORTED" || true; }

if [[ $what == eve || $what == all ]]; then
  run eve.py -- export
  rm -rf "$T/eve_idle"; run eve.py -- video
  "$PY" post.py video eve_idle eve-idle eve.png 0,60,120,180 0
  run eve.py -- stills
fi
if [[ $what == breath || $what == all ]]; then
  run breath.py -- export
  rm -rf "$T/breath_box"; run breath.py -- video
  "$PY" post.py video breath_box breath-box breath.png 0,60,180,300,420 180
fi
if [[ $what == hero || $what == all ]]; then
  run eve.py -- hero
  "$PY" post.py hero "$T/eve_hero.exr" ../eve-hero.png
fi
if [[ $what == sheet || $what == all ]]; then
  S=$T/eve_stills
  for n in listening_2 thinking_3; do "$PY" post.py still "$S/$n.exr" "$S/$n.png"; done
  "$PY" post.py sheet ../review.png \
    "eve idle 0s (exhaled)" "$T/sheet/eve-idle_000.png" \
    "eve idle 4s (inhaled)" "$T/sheet/eve-idle_120.png" \
    "eve listening 2s" "$S/listening_2.png" \
    "eve thinking 3s" "$S/thinking_3.png" \
    "breath box 2s (inhaling)" "$T/sheet/breath-box_060.png" \
    "breath box 6s (hold, full)" "$T/sheet/breath-box_180.png"
fi
if [[ $what == brand ]]; then
  repo=${2:?usage: build.sh brand D:\therapylink-v3-wt\brand-assets}
  run icon.py -- bud
  run icon.py -- feature
  "$PY" brand.py all "$repo"
  exit 0
fi
python inspect_glb.py $(ls ../*.glb)
ls -la ..
