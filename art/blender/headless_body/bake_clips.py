"""Bake headless_body_build.py's clips into assets/models/headless_body.glb
without Blender.

The build script is the one source of the rig and the clips: this runs its
measures, its bones and its whole posing section (key poses, tracks, the
IK solve, `basis`) on plain-Python stand-ins for mathutils
(mathutils_lite.py), keys every frame as its `bake` does, converts each
bone's pose to the glTF node transform the Blender exporter writes (a
child's rest under its parent times its pose; the root's under the Z-up to
Y-up turn), and puts those clips into the glb in place of any of the same
name. The mesh, skin and every other clip are left as they are.

Use it where Blender isn't installed (the Windows PC); a full Blender
rebuild of headless_body_build.py makes the same clips.

    python art/blender/headless_body/bake_clips.py --clips=listen,feel [--drop=old_clip] [--glb=PATH] [--out=PATH]
    python art/blender/headless_body/bake_clips.py --check=idle,walk   (compares a bake to the glb's)
"""
import json
import math
import re
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import mathutils_lite as mu  # noqa: E402

V, Matrix, Quaternion = mu.Vector, mu.Matrix, mu.Quaternion
ROOT = HERE.parents[2]
BUILD = HERE / "headless_body_build.py"


def _between(src, start, end):
    a = src.index(start)
    b = src.index(end, a)
    return src[a:b]


def load():
    """The build script's measures, bones and posing, run here."""
    src = BUILD.read_text(encoding="utf-8")
    ns = {"math": math, "V": V, "Vector": V, "Matrix": Matrix, "Quaternion": Quaternion, "FPS": 30}
    exec(_between(src, "# ------------------------------------------------------------------ the measures",
                  "SPACING = 0.3"), ns)
    exec(_between(src, "def G(p):", "# ------------------------------------------------------------------ materials"), ns)
    exec(_between(src, "def smooth01(e0, e1, x):", "# ================================================================== the figure"), ns)
    exec(_between(src, "BONES = [", "arm_data = bpy"), ns)
    # The bones' rest (armature space), as Blender's edit bones make them:
    # Y along the bone, Z (its roll) toward X x Y.
    rest, length = {}, {}
    for name, parent, h, t in ns["BONES"]:
        head, tail = ns["G"](V(h)), ns["G"](V(t))
        y = (tail - head).normalized()
        z = V((1, 0, 0)).cross(y)
        if z.length < 1e-4: z = V((0, 0, 1))
        z = (z - y * z.dot(y)).normalized()
        x = y.cross(z)
        m = Matrix((x, y, z)).transposed().to_4x4()
        m.translation = head
        rest[name] = m
        length[name] = (tail - head).length
    ns["ORDER"] = [b[0] for b in ns["BONES"]]
    ns["PARENT"] = {b[0]: b[1] for b in ns["BONES"]}
    ns["REST"] = rest
    ns["LEN"] = length
    exec(_between(src, "# ================================================================== posing",
                  "# ================================================================== keying"), ns)
    return ns


# The Blender exporter's turn of the root bone from Z up to Y up.
C = Quaternion((1, 0, 0), -math.pi / 2).to_matrix().to_4x4()


def bake(ns, c):
    """{bone: [(t, r, s) per frame]} of glTF node transforms for clip `c`."""
    fps = 30
    frames = max(1, round(c.length * fps))
    out = {n: [] for n in ns["ORDER"]}
    last = {}
    worst = 0.0
    for f in range(frames + 1):
        t = c.length * f / frames
        v = c.values(t)
        pose = ns["pose_of"](v)
        P, reach = ns["solve"](pose)
        worst = max(worst, reach)
        B = ns["basis"](P)
        for name in ns["ORDER"]:
            loc, rot, _ = B[name].decompose()
            if name in last and last[name].dot(rot) < 0: rot.negate()
            last[name] = rot
            basis = Matrix.Translation(loc) @ rot.to_matrix().to_4x4()
            scale = V((1, 1, 1))
            if name == "root":
                sq = pose.squash
                w = 1.0 / math.sqrt(max(sq, 0.2))
                scale = V((w, w, sq))
                basis = basis @ Matrix([[w, 0, 0, 0], [0, w, 0, 0], [0, 0, sq, 0], [0, 0, 0, 1]])
            parent = ns["PARENT"][name]
            rest = ns["REST"]
            if parent is None: node = C @ rest[name] @ basis
            else: node = rest[parent].inverted() @ rest[name] @ basis
            nt, nr, _ = node.decompose()
            out[name].append((f / fps, nt, nr, scale))
    # Each node's rotation kept on one side of the sphere, as the keys are.
    for name, keys in out.items():
        for i in range(1, len(keys)):
            if keys[i][2].dot(keys[i - 1][2]) < 0: keys[i][2].negate()
    print(f"BAKED {c.name} frames={frames} seconds={c.length:.3f} worst_leg_reach={worst:.3f}")
    return out


# ------------------------------------------------------------------ the glb
def read_glb(path):
    d = Path(path).read_bytes()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    b0 = 20 + jl
    bl = struct.unpack("<I", d[b0:b0 + 4])[0]
    return j, bytearray(d[b0 + 8:b0 + 8 + bl])


def write_glb(path, j, bin_):
    while len(bin_) % 4: bin_.append(0)
    j["buffers"] = [{"byteLength": len(bin_)}]
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    while len(js) % 4: js += b" "
    total = 12 + 8 + len(js) + 8 + len(bin_)
    out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_)
    Path(path).write_bytes(out)


def accessor(j, bin_, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    vals = struct.unpack_from("<%df" % (n * a["count"]), bin_, off)
    return [vals[k * n:(k + 1) * n] for k in range(a["count"])]


def add_floats(j, bin_, rows, kind):
    while len(bin_) % 4: bin_.append(0)
    flat = [float(x) for r in rows for x in (r if isinstance(r, (list, tuple)) else [r])]
    off = len(bin_)
    bin_ += struct.pack("<%df" % len(flat), *flat)
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": 4 * len(flat)})
    acc = {"bufferView": len(j["bufferViews"]) - 1, "componentType": 5126, "count": len(rows), "type": kind}
    if kind == "SCALAR":
        acc["min"] = [min(flat)]
        acc["max"] = [max(flat)]
    j["accessors"].append(acc)
    return len(j["accessors"]) - 1


def compact(j, bin_):
    """Drop accessors and buffer views nothing uses any more; repack the buffer."""
    used = set()
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            used |= set(p["attributes"].values())
            if "indices" in p: used.add(p["indices"])
            for t in p.get("targets", []): used |= set(t.values())
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s: used.add(s["inverseBindMatrices"])
    for a in j.get("animations", []):
        for s in a["samplers"]: used |= {s["input"], s["output"]}
    amap = {}
    accs = []
    for i, a in enumerate(j["accessors"]):
        if i in used:
            amap[i] = len(accs)
            accs.append(a)
    views_used = {a["bufferView"] for a in accs if "bufferView" in a}
    views_used |= {im["bufferView"] for im in j.get("images", []) if "bufferView" in im}
    vmap = {}
    views = []
    nb = bytearray()
    for i, bv in enumerate(j["bufferViews"]):
        if i not in views_used: continue
        while len(nb) % 4: nb.append(0)
        off = bv.get("byteOffset", 0)
        chunk = bin_[off:off + bv["byteLength"]]
        nbv = dict(bv)
        nbv["byteOffset"] = len(nb)
        nb += chunk
        vmap[i] = len(views)
        views.append(nbv)
    for a in accs:
        if "bufferView" in a: a["bufferView"] = vmap[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im: im["bufferView"] = vmap[im["bufferView"]]
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            p["attributes"] = {k: amap[v] for k, v in p["attributes"].items()}
            if "indices" in p: p["indices"] = amap[p["indices"]]
            if "targets" in p: p["targets"] = [{k: amap[v] for k, v in t.items()} for t in p["targets"]]
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s: s["inverseBindMatrices"] = amap[s["inverseBindMatrices"]]
    for a in j.get("animations", []):
        for s in a["samplers"]:
            s["input"] = amap[s["input"]]
            s["output"] = amap[s["output"]]
    j["accessors"] = accs
    j["bufferViews"] = views
    return nb


def put(j, bin_, name, keys):
    node_of = {n["name"]: i for i, n in enumerate(j["nodes"])}
    j["animations"] = [a for a in j["animations"] if a["name"] != name]
    any_keys = next(iter(keys.values()))
    times = add_floats(j, bin_, [k[0] for k in any_keys], "SCALAR")
    anim = {"name": name, "channels": [], "samplers": []}
    for bone, ks in keys.items():
        for path, idx, kind in (("translation", 1, "VEC3"), ("rotation", 2, "VEC4"), ("scale", 3, "VEC3")):
            if path == "rotation": rows = [(k[2].x, k[2].y, k[2].z, k[2].w) for k in ks]
            else: rows = [tuple(k[idx]) for k in ks]
            out = add_floats(j, bin_, rows, kind)
            anim["samplers"].append({"input": times, "interpolation": "LINEAR", "output": out})
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": node_of[bone], "path": path}})
    j["animations"].append(anim)
    j["animations"].sort(key=lambda a: a["name"])


def check(j, bin_, name, keys):
    """The largest differences between a bake and the glb's clip of that name."""
    node_of = {n["name"]: i for i, n in enumerate(j["nodes"])}
    anim = next(a for a in j["animations"] if a["name"] == name)
    worst = {"translation": 0.0, "rotation": 0.0, "scale": 0.0}
    for ch in anim["channels"]:
        s = anim["samplers"][ch["sampler"]]
        times = [r[0] for r in accessor(j, bin_, s["input"])]
        vals = accessor(j, bin_, s["output"])
        bone = j["nodes"][ch["target"]["node"]]["name"]
        path = ch["target"]["path"]
        ks = keys[bone]
        for f, k in enumerate(ks):
            # The glb's value at this key's time (STEP or LINEAR keys).
            t = k[0]
            i = max(0, min(len(times) - 1, sum(1 for x in times if x <= t + 1e-6) - 1))
            g = vals[i]
            if path == "rotation":
                mine = (k[2].x, k[2].y, k[2].z, k[2].w)
                d = 1.0 - abs(sum(a * b for a, b in zip(mine, g)))
            else:
                mine = tuple(k[1] if path == "translation" else k[3])
                d = max(abs(a - b) for a, b in zip(mine, g))
            worst[path] = max(worst[path], d)
    print(f"CHECK {name}: translation {worst['translation']:.5f} m, rotation 1-|dot| {worst['rotation']:.2e}, scale {worst['scale']:.5f}")


def main():
    args = sys.argv[1:]
    glb = ROOT / "assets/models/headless_body.glb"
    out = None
    clips, checks, drops = [], [], []
    for a in args:
        if a.startswith("--glb="): glb = Path(a.split("=", 1)[1])
        elif a.startswith("--out="): out = Path(a.split("=", 1)[1])
        elif a.startswith("--clips="): clips = a.split("=", 1)[1].split(",")
        elif a.startswith("--check="): checks = a.split("=", 1)[1].split(",")
        elif a.startswith("--drop="): drops = a.split("=", 1)[1].split(",")
    ns = load()
    by_name = {c.name: c for c in ns["CLIPS"]}
    j, bin_ = read_glb(glb)
    for name in checks:
        check(j, bin_, name, bake(ns, by_name[name]))
    if not clips and not drops: return
    j["animations"] = [a for a in j["animations"] if a["name"] not in drops]
    for name in clips:
        put(j, bin_, name, bake(ns, by_name[name]))
    bin_ = compact(j, bin_)
    write_glb(out or glb, j, bin_)
    print("WROTE", out or glb, [a["name"] for a in j["animations"]])


if __name__ == "__main__":
    main()
