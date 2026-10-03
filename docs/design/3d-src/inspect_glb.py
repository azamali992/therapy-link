"""Quick structural check of a .glb: size, nodes, meshes, triangles, materials,
extensions, animation clip names and durations. Plain Python, no deps.
  python inspect_glb.py ../eve.glb ../breath.glb
"""
import json
import os
import struct
import sys

COMP = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}


def load(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and ver == 2, "not a glTF 2 binary"
    off, js, binc = 12, None, None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen
    return js, binc


def acc_minmax(js, binc, idx):
    a = js["accessors"][idx]
    if "max" in a:
        return a["min"], a["max"]
    bv = js["bufferViews"][a["bufferView"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    vals = struct.unpack_from("<%df" % a["count"], binc, start)
    return [min(vals)], [max(vals)]


def main(path):
    js, binc = load(path)
    size = os.path.getsize(path)
    print(f"== {os.path.basename(path)}  {size/1024:.1f} KB")
    print("  extensionsUsed:", js.get("extensionsUsed", []))
    print("  nodes:", len(js.get("nodes", [])), " meshes:", len(js.get("meshes", [])),
          " materials:", [m["name"] for m in js.get("materials", [])],
          " images:", len(js.get("images", [])))
    tris = 0
    for n in js["nodes"]:
        if "mesh" in n:
            for p in js["meshes"][n["mesh"]]["primitives"]:
                if "indices" in p:
                    tris += js["accessors"][p["indices"]]["count"] // 3
    verts = sum(js["accessors"][p["attributes"]["POSITION"]]["count"]
                for m in js["meshes"] for p in m["primitives"])
    print(f"  unique vertices: {verts}   rendered triangles (incl. instances): {tris}")
    for a in js.get("animations", []):
        tmin, tmax = 1e9, -1e9
        for s in a["samplers"]:
            mn, mx = acc_minmax(js, binc, s["input"])
            tmin, tmax = min(tmin, mn[0]), max(tmax, mx[0])
        paths = sorted({c["target"]["path"] for c in a["channels"]})
        print(f"  clip '{a['name']}': {tmax - tmin:.3f}s (t {tmin:.2f}..{tmax:.2f}), "
              f"{len(a['channels'])} channels {paths}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
