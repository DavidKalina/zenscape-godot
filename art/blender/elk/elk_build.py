"""The elk: the wilderness skin of the ground escort kind
(docs/design/endless-flight/spec-wild-kit-elk.md, the body lane).

    python3 tools/blender.py run art/blender/elk/elk_build.py [-- --stills=DIR] [--strips=DIR] [--clips=a,b] [--no-export]

Writes assets/models/elk/elk.glb: one skinned body (ElkBody), the bull's mane
(Mane) and antlers (Antlers) as their own meshes on the same skeleton, so
the body script shows them for `bull` and hides them for `cow`, and the
contract's sockets as empties riding their bones (Godot imports them as
BoneAttachment3Ds), and the clips (elk_clips.py) as its animations, with
their table (length, loop, ground, beats) in elk_clips.json beside it.
--stills renders a turntable of both variants and a head close-up there
(Workbench, vertex colours); --strips a strip of each clip's key poses (or
those --clips names), side-on and three-quarter, the time over each.

Units: the plane's span (scripts/world_scale.gd `span`) is 1. The body
script scales the glb by WorldScale.span, so every size here is the spec's
multiple of the span: nose to tail about 0.9 (one body length, BL),
shoulder 0.55, eye 0.62, the bull's antlers 0.45 over the head.
Blender +z up, +y his front, +x his right; the origin is on the ground
midway between his fore and hind hooves. Left is "l" (-x).

The coat is vertex colour on one material (no textures): a caramel body,
a chocolate neck, head and legs, a cream rump patch, dark hooves, pale
antlers with bone-white tips. Crevice darkness (belly, inner legs, under
the neck) is painted into the same colours.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

V = Vector
HERE = Path(__file__).resolve().parent
GLB = HERE.parents[2] / "assets" / "models" / "elk" / "elk.glb"   # art/blender is Godot-ignored
TABLE = GLB.with_name("elk_clips.json")
sys.path.insert(0, str(HERE))
import elk_clips as ec  # noqa: E402
X = V((1, 0, 0))

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
STILLS = next((Path(a.split("=", 1)[1]) for a in ARGS if a.startswith("--stills=")), None)
STRIPS = next((Path(a.split("=", 1)[1]) for a in ARGS if a.startswith("--strips=")), None)
ONLY = next((set(a.split("=", 1)[1].split(",")) for a in ARGS if a.startswith("--clips=")), None)
EXPORT = "--no-export" not in ARGS
SIDES = {"l": -1.0, "r": 1.0}


def srgb(hx):
    hx = hx.lstrip("#")
    c = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return V(tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c))


PAL = {
    "coat": srgb("bf8a52"),      # the body's caramel
    "back": srgb("c99862"),      # sun-bleached along the back
    "belly": srgb("6b4730"),
    "neck": srgb("5c3b26"),      # chocolate
    "mane": srgb("4a2f1e"),
    "head": srgb("6e4a31"),
    "muzzle": srgb("2e221a"),
    "leg": srgb("4d3323"),
    "hoof": srgb("26201c"),
    "rump": srgb("e8d6aa"),      # the cream patch
    "rim": srgb("7a5434"),       # the patch's darker rim
    "eye": srgb("120d0a"),
    "ear_in": srgb("8a6a50"),
    "antler_base": srgb("5e4a36"),
    "antler": srgb("c8b08a"),
    "antler_tip": srgb("f3ecdc"),
}


def mix(a, b, t):
    t = min(max(t, 0.0), 1.0)
    return a.lerp(b, t)


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ joints
# Side views (y forward, z up); legs add x = side * LEG_X. The legs' chains:
# fore  shoulder -> elbow -> knee (carpus) -> fetlock -> toe
# hind  hip -> stifle -> hock -> fetlock -> toe
FORE_X, HIND_X = 0.062, 0.070
FORE = {"scap": V((0.165, 0.50)), "shoulder": V((0.255, 0.385)), "elbow": V((0.198, 0.285)),
        "knee": V((0.206, 0.152)), "fetlock": V((0.211, 0.052)), "toe": V((0.226, 0.0))}
HIND = {"hip": V((-0.19, 0.435)), "stifle": V((-0.125, 0.29)), "hock": V((-0.245, 0.158)),
        "fetlock": V((-0.226, 0.052)), "toe": V((-0.211, 0.0))}


def yz(p, x=0.0):
    return V((x, p.x, p.y))


JOINT = {
    "root": V((0, 0, 0)),
    "body": V((0, 0.0, 0.42)),
    "hips": V((0, -0.08, 0.45)),
    "chest": V((0, 0.06, 0.45)),
    "neck1": V((0, 0.20, 0.455)),
    "neck2": V((0, 0.30, 0.535)),
    "head": V((0, 0.385, 0.605)),
    "nose": V((0, 0.553, 0.535)),
    "tail": V((0, -0.338, 0.468)),
}
for _s, _sg in SIDES.items():
    for _k, _p in FORE.items():
        JOINT[f"f_{_k}_{_s}"] = yz(_p, _sg * FORE_X)
    for _k, _p in HIND.items():
        JOINT[f"h_{_k}_{_s}"] = yz(_p, _sg * HIND_X)
    JOINT[f"ear_{_s}"] = V((_sg * 0.03, 0.392, 0.664))

# The contract's sizes, checked by the build (span units).
SIZE = {"length": 0.9, "shoulder": 0.55, "eye": 0.62, "antler_rise": 0.45}


# ------------------------------------------------------------------ the mesh builder
class Part:
    """Vertices, faces, per-vertex bone weights and colours for one mesh."""

    def __init__(self, name):
        self.name = name
        self.v, self.f, self.w, self.c = [], [], [], []

    def vert(self, p, w, c):
        self.v.append(V(p))
        self.w.append(dict(w))
        self.c.append(V(c))
        return len(self.v) - 1


def sgnpow(x, e):
    return math.copysign(abs(x) ** e, x)


def frames(rings):
    """Tangents for a path of rings (finite differences unless given)."""
    n = len(rings)
    out = []
    for i, r in enumerate(rings):
        if "t" in r:
            out.append(V(r["t"]).normalized())
            continue
        a = rings[max(i - 1, 0)]["c"]
        b = rings[min(i + 1, n - 1)]["c"]
        out.append((V(b) - V(a)).normalized())
    return out


def loft(part, rings, around, colour, cap0=0.0, cap1=0.0, phase=0.0):
    """A tube through `rings`: each {c, a, bu, bd, n, w, [side], [t], [dz]}.
    a is the half width along the ring's side axis, bu / bd the half height
    above / below (its up is side x tangent), n a superellipse exponent
    (2 an ellipse, more boxy). capN closes an end with a rounded dome that
    far past the end ring. colour(p, info) -> linear rgb."""
    tans = frames(rings)
    idx = []
    for i, (r, t) in enumerate(zip(rings, tans)):
        side = V(r.get("side", X))
        up = side.cross(t).normalized()
        side = t.cross(up).normalized()
        e = 2.0 / r.get("n", 2.0)
        row = []
        for k in range(around):
            th = phase + 2 * math.pi * k / around
            cs, sn = math.cos(th), math.sin(th)
            b = r["bu"] if sn >= 0 else r["bd"]
            p = V(r["c"]) + side * (r["a"] * sgnpow(cs, e)) + up * (b * sgnpow(sn, e))
            info = {"ring": i, "of": len(rings), "cs": cs, "sn": sn, "up": up, "side": side}
            row.append(part.vert(p, r["w"], colour(p, info)))
        r["_frame"] = (side, up, t)
        idx.append(row)
    for i in range(len(idx) - 1):
        for k in range(around):
            k1 = (k + 1) % around
            part.f.append((idx[i][k], idx[i][k1], idx[i + 1][k1], idx[i + 1][k]))

    def cap(row, r, t, d):
        side, up, _ = r["_frame"]
        mid = []
        c = V(r["c"]) + t * (d * 0.62)
        for k in range(around):
            p0 = part.v[row[k]]
            p = c + (p0 - V(r["c"])) * 0.72
            mid.append(part.vert(p, r["w"], part.c[row[k]]))
        tip = part.vert(V(r["c"]) + t * d, r["w"], part.c[row[0]].lerp(part.c[row[around // 2]], 0.5))
        for k in range(around):
            k1 = (k + 1) % around
            part.f.append((row[k], row[k1], mid[k1], mid[k]))
            part.f.append((mid[k], mid[k1], tip))

    if cap0 > 0:
        cap(idx[0], rings[0], -tans[0], cap0)
    if cap1 > 0:
        cap(idx[-1], rings[-1], tans[-1], cap1)
    return idx


def W(**kw):
    return kw


def blend(a, b, t):
    """Weights a -> b by t (0 all a)."""
    t = min(max(t, 0.0), 1.0)
    out = {}
    for k, v in a.items():
        out[k] = out.get(k, 0.0) + v * (1 - t)
    for k, v in b.items():
        out[k] = out.get(k, 0.0) + v * t
    return {k: v for k, v in out.items() if v > 1e-4}


# ------------------------------------------------------------------ the coat
def coat_colour(p, info):
    """The body: caramel, a bleached back, a dark belly and brisket, the
    chocolate neck coming down over the shoulders, the cream rump patch."""
    y, z = p.y, p.z
    c = mix(PAL["coat"], PAL["back"], smooth(0.47, 0.55, z) * 0.45)
    # the belly darkens toward the underside
    c = mix(c, PAL["belly"], smooth(0.36, 0.28, z) * 0.85)
    # the chocolate of the neck reaches back over the shoulders and brisket
    yb = 0.10 + (z - 0.30) * 0.32
    c = mix(c, PAL["neck"], smooth(yb - 0.035, yb + 0.03, y))
    # the rump patch: cream from the tail down over the buttocks, a dark rim
    dx = abs(p.x)
    rp = smooth(-0.282, -0.312, y - dx * 0.65) * smooth(0.385, 0.425, z)
    rim = smooth(-0.25, -0.285, y - dx * 0.65) * (1 - rp) * smooth(0.36, 0.42, z)
    c = mix(c, PAL["rim"], rim * 0.7)
    c = mix(c, PAL["rump"], rp)
    return c


def neck_colour(p, info):
    c = mix(PAL["neck"], PAL["mane"], 0.3 * max(-info["sn"], 0.0))
    return mix(c, PAL["head"], smooth(0.56, 0.64, p.z) * 0.6)


def head_colour(p, info):
    t = info["ring"] / max(info["of"] - 1, 1)
    c = mix(PAL["head"], PAL["muzzle"], smooth(0.62, 0.9, t))
    # a paler brow over the eyes
    c = mix(c, PAL["back"], 0.25 * smooth(0.2, 0.5, info["sn"]) * smooth(0.15, 0.3, t) * smooth(0.6, 0.4, t))
    return c


def leg_colour_fore(p, info):
    c = mix(PAL["neck"], PAL["leg"], smooth(0.36, 0.28, p.z))
    c = mix(c, PAL["leg"] * 0.85, smooth(0.2, 0.1, p.z))
    return mix(c, PAL["hoof"], smooth(0.032, 0.018, p.z))


def leg_colour_hind(p, info):
    c = coat_colour(p, info)
    # the inside of the thigh and the lower leg darken
    inner = max(-info["cs"] * math.copysign(1.0, p.x), 0.0)
    c = mix(c, PAL["belly"], inner * 0.6 * smooth(0.40, 0.30, p.z))
    c = mix(c, PAL["leg"], smooth(0.27, 0.19, p.z))
    return mix(c, PAL["hoof"], smooth(0.032, 0.018, p.z))


# ------------------------------------------------------------------ the parts
body = Part("ElkBody")

# Torso, rump to chest: (y, top, bottom, half width, widest at (0 bottom, 1 top), n)
TORSO = [
    (-0.322, 0.500, 0.380, 0.078, 0.55, 2.2),
    (-0.300, 0.522, 0.340, 0.100, 0.55, 2.3),
    (-0.255, 0.535, 0.318, 0.112, 0.55, 2.4),
    (-0.200, 0.537, 0.305, 0.116, 0.55, 2.4),
    (-0.140, 0.531, 0.300, 0.113, 0.52, 2.4),
    (-0.075, 0.526, 0.287, 0.114, 0.50, 2.4),
    (-0.010, 0.523, 0.276, 0.118, 0.50, 2.4),
    (0.055, 0.537, 0.271, 0.120, 0.50, 2.4),
    (0.115, 0.549, 0.274, 0.116, 0.52, 2.4),
    (0.160, 0.556, 0.283, 0.109, 0.55, 2.3),
    (0.215, 0.548, 0.297, 0.098, 0.55, 2.3),
    (0.255, 0.522, 0.318, 0.086, 0.52, 2.2),
    (0.285, 0.488, 0.345, 0.068, 0.48, 2.1),
]


def torso_w(y):
    if y < -0.02:
        return blend(W(hips=1.0), W(body=1.0), smooth(-0.17, -0.02, y))
    return blend(W(body=1.0), W(chest=1.0), smooth(0.0, 0.13, y))


rings = []
for y, top, bot, hw, wz, n in TORSO:
    zc = bot + wz * (top - bot)
    rings.append({"c": V((0, y, zc)), "a": hw, "bu": top - zc, "bd": zc - bot, "n": n,
                  "w": torso_w(y), "t": (0, 1, 0)})
loft(body, rings, 18, coat_colour, cap0=0.028, cap1=0.03, phase=math.pi / 2)

# Neck: from inside the chest up and forward to the head's joint.
NECK = [  # (y, z, half width, half height up(back), half height down(throat), weights)
    (0.130, 0.415, 0.074, 0.092, 0.100, W(chest=0.9, neck1=0.1)),
    (0.180, 0.438, 0.078, 0.100, 0.104, W(chest=0.7, neck1=0.3)),
    (0.235, 0.470, 0.074, 0.100, 0.098, W(chest=0.3, neck1=0.7)),
    (0.295, 0.520, 0.062, 0.084, 0.082, W(neck1=0.6, neck2=0.4)),
    (0.340, 0.565, 0.052, 0.068, 0.068, W(neck2=1.0)),
    (0.378, 0.608, 0.046, 0.060, 0.058, W(neck2=0.5, head=0.5)),
    (0.398, 0.640, 0.040, 0.048, 0.050, W(head=1.0)),
]
neck_rings = [{"c": V((0, y, z)), "a": a, "bu": bu, "bd": bd, "n": 2.2, "w": w} for y, z, a, bu, bd, w in NECK]
loft(body, neck_rings, 14, neck_colour, phase=math.pi / 2)

# Head: poll to nose along the face.
POLL = V((0, 0.378, 0.648))
NOSE = JOINT["nose"]
HEAD_AX = (NOSE - POLL).normalized()
HEAD_LEN = (NOSE - POLL).length
HEAD = [  # (t along poll->nose, half width, up, down, n)
    (0.00, 0.038, 0.032, 0.036, 2.0),
    (0.10, 0.050, 0.040, 0.054, 2.1),
    (0.27, 0.053, 0.036, 0.060, 2.3),
    (0.45, 0.043, 0.031, 0.054, 2.3),
    (0.66, 0.035, 0.028, 0.047, 2.4),
    (0.84, 0.034, 0.030, 0.045, 2.4),
    (0.96, 0.034, 0.028, 0.040, 2.3),
]
_hup = X.cross(HEAD_AX).normalized()
EYE = {}
for _s, _sg in SIDES.items():
    EYE[_s] = POLL + HEAD_AX * (HEAD[2][0] * HEAD_LEN) + X * (_sg * HEAD[2][1] * 0.93) + _hup * (HEAD[2][2] * 0.25)


def head_eyed(p, info):
    c = head_colour(p, info)
    d = min((p - e).length for e in EYE.values())
    return mix(c, PAL["ear_in"], smooth(0.03, 0.016, d) * 0.8)


head_rings = [{"c": POLL + HEAD_AX * (t * HEAD_LEN), "a": a, "bu": bu, "bd": bd, "n": n,
               "w": W(head=1.0), "t": HEAD_AX} for t, a, bu, bd, n in HEAD]
loft(body, head_rings, 14, head_eyed, cap0=0.025, cap1=0.024, phase=math.pi / 2)

# Eyes: dark beads on the face's sides.
for s, sg in SIDES.items():
    c = EYE[s]
    eye_rings = [{"c": c + X * (sg * dx), "a": r, "bu": r * 0.8, "bd": r * 0.8, "w": W(head=1.0),
                  "t": X * sg, "side": V((0, 1, 0))} for dx, r in ((-0.004, 0.0125), (0.003, 0.0125))]
    loft(body, eye_rings, 8, lambda p, i: PAL["eye"], cap0=0.004, cap1=0.007)

# Ears: leaves from the poll, out, up and back.
for s, sg in SIDES.items():
    base = JOINT[f"ear_{s}"]
    d = V((sg * 0.75, -0.35, 0.55)).normalized()
    side = V((0, 1, 0.2)).cross(d).normalized()
    ear = []
    for t, a, b in ((0.0, 0.013, 0.011), (0.25, 0.024, 0.009), (0.6, 0.021, 0.007), (0.9, 0.010, 0.004)):
        ear.append({"c": base + d * (0.088 * t), "a": a, "bu": b, "bd": b, "w": W(**{f"ear_{s}": 1.0}),
                    "t": d, "side": side})
    loft(body, ear, 8, lambda p, i: mix(PAL["head"], PAL["ear_in"], max(i["sn"], 0.0) * 0.7),
         cap0=0.006, cap1=0.012)

# Tail: a short cream stub.
tail_rings = []
for t, r in ((0.0, 0.020), (0.5, 0.019), (1.0, 0.012)):
    tail_rings.append({"c": JOINT["tail"] + V((0, -0.012, -0.045)) * t, "a": r, "bu": r, "bd": r * 1.1,
                       "w": W(tail=1.0)})
loft(body, tail_rings, 8, lambda p, i: mix(PAL["rump"], PAL["rim"], 0.35 * max(-i["sn"], 0.0)), cap0=0.01, cap1=0.012)


# Legs: (joint or point, half width, front, back, weights). Up for a leg's
# ring is its front (side x a downward tangent).
def leg_rings(chain, x, spec):
    out = []
    for at, a, fr, bk, w in spec:
        if isinstance(at, str):
            p = chain[at]
        else:
            p = chain[at[0]].lerp(chain[at[1]], at[2])
        out.append({"c": yz(p, x), "a": a, "bu": fr, "bd": bk, "n": 2.0, "w": w})
    return out


for s, sg in SIDES.items():
    fx = sg * FORE_X
    S = lambda b: f"{b}_{s}"  # noqa: E731
    top = dict(FORE)
    top["top"] = V((0.21, 0.44))
    spec = [
        ("top", 0.028, 0.050, 0.050, blend(W(chest=1.0), W(**{S("scap"): 1.0}), 0.5)),
        (("top", "shoulder", 0.55), 0.044, 0.064, 0.066, W(**{S("scap"): 0.6, S("upper"): 0.4})),
        ("shoulder", 0.047, 0.068, 0.070, W(**{S("upper"): 1.0})),
        (("shoulder", "elbow", 0.5), 0.045, 0.060, 0.062, W(**{S("upper"): 1.0})),
        ("elbow", 0.040, 0.048, 0.050, W(**{S("upper"): 0.5, S("fore"): 0.5})),
        (("elbow", "knee", 0.25), 0.032, 0.037, 0.036, W(**{S("fore"): 1.0})),
        (("elbow", "knee", 0.6), 0.025, 0.027, 0.025, W(**{S("fore"): 1.0})),
        (("elbow", "knee", 0.9), 0.021, 0.022, 0.021, W(**{S("fore"): 0.8, S("cannon"): 0.2})),
        ("knee", 0.021, 0.023, 0.022, W(**{S("fore"): 0.5, S("cannon"): 0.5})),
        (("knee", "fetlock", 0.2), 0.016, 0.017, 0.016, W(**{S("cannon"): 1.0})),
        (("knee", "fetlock", 0.75), 0.014, 0.015, 0.015, W(**{S("cannon"): 1.0})),
        ("fetlock", 0.017, 0.017, 0.021, W(**{S("cannon"): 0.5, S("hoof"): 0.5})),
        (("fetlock", "toe", 0.45), 0.016, 0.017, 0.016, W(**{S("hoof"): 1.0})),
        (("fetlock", "toe", 0.75), 0.020, 0.024, 0.019, W(**{S("hoof"): 1.0})),
        ("toe", 0.022, 0.027, 0.020, W(**{S("hoof"): 1.0})),
    ]
    rr = leg_rings(top, fx, spec)
    rr[-1]["t"] = (0, 0, -1)
    rr[-2]["t"] = (0, 0.15, -1)
    loft(body, rr, 10, leg_colour_fore, cap0=0.03, cap1=0.006, phase=math.pi / 2)

    hx = sg * HIND_X
    top = dict(HIND)
    top["top"] = V((-0.20, 0.485))
    spec = [
        ("top", 0.046, 0.075, 0.080, blend(W(hips=1.0), W(**{S("thigh"): 1.0}), 0.5)),
        ("hip", 0.058, 0.088, 0.094, W(**{S("thigh"): 1.0})),
        (("hip", "stifle", 0.5), 0.058, 0.078, 0.084, W(**{S("thigh"): 1.0})),
        ("stifle", 0.047, 0.052, 0.064, W(**{S("thigh"): 0.5, S("shin"): 0.5})),
        (("stifle", "hock", 0.3), 0.036, 0.034, 0.046, W(**{S("shin"): 1.0})),
        (("stifle", "hock", 0.65), 0.024, 0.023, 0.028, W(**{S("shin"): 1.0})),
        ("hock", 0.020, 0.022, 0.027, W(**{S("shin"): 0.5, S("hcannon"): 0.5})),
        (("hock", "fetlock", 0.2), 0.016, 0.017, 0.017, W(**{S("hcannon"): 1.0})),
        (("hock", "fetlock", 0.75), 0.014, 0.015, 0.015, W(**{S("hcannon"): 1.0})),
        ("fetlock", 0.017, 0.017, 0.021, W(**{S("hcannon"): 0.5, S("hhoof"): 0.5})),
        (("fetlock", "toe", 0.45), 0.016, 0.017, 0.016, W(**{S("hhoof"): 1.0})),
        (("fetlock", "toe", 0.75), 0.020, 0.024, 0.019, W(**{S("hhoof"): 1.0})),
        ("toe", 0.022, 0.027, 0.020, W(**{S("hhoof"): 1.0})),
    ]
    rr = leg_rings(top, hx, spec)
    rr[-1]["t"] = (0, 0, -1)
    rr[-2]["t"] = (0, 0.15, -1)
    loft(body, rr, 10, leg_colour_hind, cap0=0.035, cap1=0.006, phase=math.pi / 2)


# The bull's mane: a shaggy dark fall under the neck, its lower edge jagged.
mane = Part("Mane")
MANE = [  # (y, z, half width, up, down): inside the neck but for the fall under it
    (0.180, 0.438, 0.070, 0.085, 0.120, W(chest=0.7, neck1=0.3)),
    (0.235, 0.470, 0.068, 0.085, 0.128, W(chest=0.3, neck1=0.7)),
    (0.295, 0.520, 0.057, 0.072, 0.114, W(neck1=0.6, neck2=0.4)),
    (0.340, 0.565, 0.047, 0.058, 0.096, W(neck2=1.0)),
    (0.378, 0.608, 0.040, 0.050, 0.070, W(neck2=0.5, head=0.5)),
]
mane_rings = [{"c": V((0, y, z)), "a": a, "bu": bu, "bd": bd, "n": 2.2, "w": w} for y, z, a, bu, bd, w in MANE]
idx = loft(mane, mane_rings, 14, lambda p, i: mix(PAL["mane"], PAL["neck"], max(i["sn"], 0.0) * 0.5),
           cap0=0.02, cap1=0.02, phase=math.pi / 2)
# shag: pull alternate points of the throat's underside down into locks
for ri, row in enumerate(idx[1:-1], 1):
    for k, vi in enumerate(row):
        th = math.pi / 2 + 2 * math.pi * k / 14
        if math.sin(th) < -0.6:
            lock = 0.024 if (k + ri) % 2 == 0 else 0.008
            mane.v[vi] = mane.v[vi] + V((0, -0.006, -lock))


# The bull's antlers: two beams sweeping up, out and back, then forward at
# the crown, each with five tines rising off its front (brow, bez, trez,
# royal, and the crown's fork). Rigid on the head bone.
antlers = Part("Antlers")


def antler_colour(t_beam, tip):
    def f(p, info):
        tt = info["ring"] / max(info["of"] - 1, 1)
        c = mix(PAL["antler_base"], PAL["antler"], smooth(0.0, 0.25, t_beam + tt * 0.1))
        return mix(c, PAL["antler_tip"], smooth(0.55, 1.0, tt) * tip)
    return f


def bez(pts, t):
    """A Catmull-Rom path through pts at t in 0..1."""
    n = len(pts) - 1
    f = min(t * n, n - 1e-6)
    i = int(f)
    u = f - i
    p0 = pts[max(i - 1, 0)]
    p1, p2 = pts[i], pts[i + 1]
    p3 = pts[min(i + 2, n)]
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                  + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)


ANTLER_TOP = 0.0
for s, sg in SIDES.items():
    beam = [V((sg * x, y, z)) for x, y, z in (
        (0.034, 0.402, 0.668), (0.075, 0.385, 0.745), (0.135, 0.335, 0.830),
        (0.190, 0.255, 0.905), (0.225, 0.180, 0.980), (0.236, 0.138, 1.058), (0.214, 0.150, 1.130))]
    n = 11
    rr = []
    for i in range(n):
        t = i / (n - 1)
        r = 0.027 * (1 - t) + 0.010 * t
        if i == 0:
            r = 0.033          # the burr
        rr.append({"c": bez(beam, t), "a": r, "bu": r, "bd": r, "w": W(head=1.0)})
    loft(antlers, rr, 7, antler_colour(0.0, 1.0), cap1=0.012)
    ANTLER_TOP = max(ANTLER_TOP, max(r["c"].z for r in rr) + 0.012)
    # tines: (t on the beam, direction (out, forward, up), length, upward curl)
    for tb, d, ln, curl in ((0.05, (0.15, 1.0, 0.12), 0.150, 0.75),
                            (0.13, (0.12, 1.0, 0.30), 0.125, 0.60),
                            (0.37, (0.10, 0.90, 0.55), 0.100, 0.45),
                            (0.56, (0.06, 0.80, 0.75), 0.160, 0.30),
                            (0.78, (0.00, 0.60, 0.90), 0.100, 0.20)):
        p0 = bez(beam, tb)
        dv = V((sg * d[0], d[1], d[2])).normalized()
        rbase = (0.027 * (1 - tb) + 0.010 * tb) * 0.72
        tr = []
        for j in range(4):
            u = j / 3
            dd = (dv + V((0, 0, curl)) * u).normalized()
            p = p0 + dd * (ln * u)
            r = rbase * (1 - u) + 0.004 * u
            tr.append({"c": p, "a": r, "bu": r, "bd": r, "w": W(head=1.0)})
        loft(antlers, tr, 6, antler_colour(tb, 1.0), cap1=0.008)
        ANTLER_TOP = max(ANTLER_TOP, tr[-1]["c"].z + 0.008)


# ------------------------------------------------------------------ objects
scene = bpy.context.scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

coat = bpy.data.materials.new("ElkCoat")
coat.use_nodes = True
_nt = coat.node_tree
_bsdf = _nt.nodes.get("Principled BSDF")
_ca = _nt.nodes.new("ShaderNodeVertexColor")
_ca.layer_name = "Col"
_nt.links.new(_ca.outputs["Color"], _bsdf.inputs["Base Color"])
_bsdf.inputs["Roughness"].default_value = 0.85


def make(part):
    me = bpy.data.meshes.new(part.name)
    me.from_pydata([tuple(p) for p in part.v], [], part.f)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(part.c):
        ca.data[i].color = (c.x, c.y, c.z, 1.0)
    me.color_attributes.active_color = ca
    me.materials.append(coat)
    ob = bpy.data.objects.new(part.name, me)
    scene.collection.objects.link(ob)
    groups = {}
    for i, w in enumerate(part.w):
        tot = sum(w.values())
        for bone, x in w.items():
            if bone not in groups:
                groups[bone] = ob.vertex_groups.new(name=bone)
            groups[bone].add([i], x / tot, "REPLACE")
    return ob


meshes = [make(body), make(mane), make(antlers)]

# ------------------------------------------------------------------ the rig
BONES = {"root": (V((0, 0, 0)), V((0, 0.1, 0)), None),
         "body": (JOINT["body"], JOINT["body"] + V((0, 0.1, 0)), "root"),
         "hips": (JOINT["hips"], V((0, -0.26, 0.46)), "body"),
         "chest": (JOINT["chest"], V((0, 0.2, 0.47)), "body"),
         "neck1": (JOINT["neck1"], JOINT["neck2"], "chest"),
         "neck2": (JOINT["neck2"], JOINT["head"], "neck1"),
         "head": (JOINT["head"], JOINT["nose"], "neck2"),
         "tail": (JOINT["tail"], JOINT["tail"] + V((0, -0.025, -0.05)), "hips")}
for s, sg in SIDES.items():
    J = lambda k: JOINT[f"{k}_{s}"]  # noqa: E731
    BONES[f"ear_{s}"] = (JOINT[f"ear_{s}"], JOINT[f"ear_{s}"] + V((sg * 0.75, -0.35, 0.55)).normalized() * 0.07, "head")
    BONES[f"scap_{s}"] = (J("f_scap"), J("f_shoulder"), "chest")
    BONES[f"upper_{s}"] = (J("f_shoulder"), J("f_elbow"), f"scap_{s}")
    BONES[f"fore_{s}"] = (J("f_elbow"), J("f_knee"), f"upper_{s}")
    BONES[f"cannon_{s}"] = (J("f_knee"), J("f_fetlock"), f"fore_{s}")
    BONES[f"hoof_{s}"] = (J("f_fetlock"), J("f_toe"), f"cannon_{s}")
    BONES[f"thigh_{s}"] = (J("h_hip"), J("h_stifle"), "hips")
    BONES[f"shin_{s}"] = (J("h_stifle"), J("h_hock"), f"thigh_{s}")
    BONES[f"hcannon_{s}"] = (J("h_hock"), J("h_fetlock"), f"shin_{s}")
    BONES[f"hhoof_{s}"] = (J("h_fetlock"), J("h_toe"), f"hcannon_{s}")

arm_data = bpy.data.armatures.new("ElkRig")
rig = bpy.data.objects.new("ElkRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (hd, tl, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = hd, tl
    b.roll = 0.0
    b.use_deform = name != "root"
    eb[name] = b
for name, (hd, tl, parent) in BONES.items():
    if parent:
        eb[name].parent = eb[parent]
        eb[name].use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
for ob in meshes:
    for vg in ob.vertex_groups:
        assert vg.name in BONES, (ob.name, vg.name)
    ob.parent = rig
    ob.modifiers.new("Rig", "ARMATURE").object = rig


def socket(name, bone, at):
    e = bpy.data.objects.new(f"socket_{name}", None)
    e.empty_display_size = 0.03
    e.location = V(at)
    scene.collection.objects.link(e)
    e.parent = rig
    e.parent_type = "BONE"
    e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(V(at))
    return e


EYE_MID = (EYE["l"] + EYE["r"]) * 0.5
sockets = [
    socket("head", "head", EYE_MID),
    socket("chest", "chest", V((0, 0.24, 0.36))),
    socket("rump", "hips", V((0, -0.30, 0.44))),
]
for s in SIDES:
    sockets.append(socket(f"foot_f{s}", f"hoof_{s}", JOINT[f"f_toe_{s}"]))
    sockets.append(socket(f"foot_h{s}", f"hhoof_{s}", JOINT[f"h_toe_{s}"]))

# ------------------------------------------------------------------ measure
allv = [ob.matrix_world @ v.co for ob in meshes[:1] for v in ob.data.vertices]
length = max(p.y for p in allv) - min(p.y for p in allv)
withers = max(p.z for p in allv if abs(p.y - 0.165) < 0.04 and abs(p.x) < 0.02)
crown = max(p.z for p in allv if p.y > 0.33 and abs(p.x) < 0.05 and p.z < 0.75)
print(f"ELK_SIZE length {length:.3f} (spec {SIZE['length']})  shoulder {withers:.3f} ({SIZE['shoulder']})  "
      f"eye {EYE_MID.z:.3f} ({SIZE['eye']})  antler rise over the head {ANTLER_TOP - crown:.3f} ({SIZE['antler_rise']})")
tris = {}
for ob in meshes:
    tris[ob.name] = sum(len(p.vertices) - 2 for p in ob.data.polygons)
print("ELK_TRIS", tris, "cow", tris["ElkBody"], "bull", sum(tris.values()))
print("ELK_BONES", len(BONES), "sockets", [e.name for e in sockets])

# ------------------------------------------------------------------ clips
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
KRIG = ec.Rig(rig, JOINT)
CLIPS = ec.clips()
ACTIONS = {c.name: ec.bake(KRIG, c) for c in CLIPS}
ec.reset(rig)
scene.render.fps = ec.FPS
scene.render.fps_base = 1.0
SOCKET_BONES = {e.name[len("socket_"):]: e.parent_bone for e in sockets}


def _pose_report(clip, t):
    """Where the muzzle and the hooves are at t (span): the graze's reach, a lifted foot."""
    KRIG.apply(clip, t)
    bpy.context.view_layer.update()
    pb = rig.pose.bones
    nose = rig.matrix_world @ pb["head"].tail
    feet = {s: round((rig.matrix_world @ pb[b].tail).z, 3)
            for s, b in (("fl", "hoof_l"), ("fr", "hoof_r"), ("hl", "hhoof_l"), ("hr", "hhoof_r"))}
    return f"t={t:.2f} muzzle z={nose.z:.3f} y={nose.y:.3f} toes z={feet}"


for _trk in rig.animation_data.nla_tracks:
    _trk.mute = True
for c in CLIPS:
    for t in c.shots:
        print("ELK_POSE", c.name, _pose_report(c, t))
for _trk in rig.animation_data.nla_tracks:
    _trk.mute = False
ec.reset(rig)


def _slide_report(clip, hz=240):
    """A moving clip's foot slide: each planted toe, posed by the rig, in
    the ground's frame (the root moving at the clip's own speed, or by its
    ground curve for a one-shot). It should hold still: the worst drift
    along and the worst lift over any one stance (span), and how long the
    foot is down."""
    speed = clip.ground * ec.BL / clip.length
    n = round(clip.length * hz)
    if clip.loop:
        travel, steps = (lambda t: speed * t), 2 * n      # two cycles, so a stance across the seam is whole
    else:
        travel, steps = (lambda t: clip.ground * ec.BL * clip.ground_curve(t / clip.length)), n + 1
        speed = (travel(clip.length) - travel(clip.length - 1e-3)) / 1e-3    # the pace it ends at
    worst = {}
    for leg, (fh, s) in ec.LEGS.items():
        bone, toe = (f"hoof_{s}", JOINT[f"f_toe_{s}"]) if fh == "f" else (f"hhoof_{s}", JOINT[f"h_toe_{s}"])
        runs, cur = [], []
        for i in range(steps):
            t = i / hz
            if clip.values(t)[f"fz.{leg}"] <= 1e-6:
                p = KRIG.moves(clip, t)[bone] @ toe
                cur.append((p.y + travel(t), p.z, t))
            elif cur:
                runs.append(cur)
                cur = []
        if cur:
            runs.append(cur)
        runs = [r for r in runs if len(r) > 1]

        def bad(r):
            return max(q[0] for q in r) - min(q[0] for q in r), max(abs(q[1]) for q in r)
        r0 = max(runs, key=lambda r: sum(bad(r))) if runs else [(0.0, 0.0, 0.0)]
        drift = max(bad(r)[0] for r in runs) if runs else 0.0
        lift = max(bad(r)[1] for r in runs) if runs else 0.0
        ends = f"{r0[0][1]:.3f}/{r0[len(r0) // 2][1]:.3f}/{r0[-1][1]:.3f}"
        worst[leg] = (drift, lift, len(r0) / hz, f"{ends} from t={r0[0][2]:.3f}")
    print("ELK_SLIDE", clip.name, f"speed={speed:.3f} span/s",
          " ".join(f"{k}: drift={a:.4f} lift={b:.4f} down={c:.3f}s worst z(td/mid/lo)={e}"
                   for k, (a, b, c, e) in worst.items()))


for c in CLIPS:
    if c.ground > 0 and (c.loop or c.ground_curve):
        _slide_report(c)

if EXPORT:
    table = {"fps": ec.FPS, "units": "span", "bl": ec.BL,
             "clips": {c.name: c.table() for c in CLIPS},
             "sockets": SOCKET_BONES}
    TABLE.write_text(json.dumps(table, indent=1) + "\n")
    print("ELK_TABLE", TABLE)

# ------------------------------------------------------------------ export
if EXPORT:
    GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes + sockets + [rig]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = rig
    kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
              export_apply=False, export_animations=True, export_animation_mode="ACTIONS",
              export_force_sampling=True, export_frame_step=1, export_def_bones=False,
              export_materials="EXPORT", export_normals=True, export_extras=True, export_texcoords=False)
    try:
        bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kw, export_colors=True)
    print("ELK_EXPORTED", GLB)

# ------------------------------------------------------------------ stills
if STILLS or STRIPS:
    import numpy as np
    OUTDIR = STILLS or STRIPS
    OUTDIR.mkdir(parents=True, exist_ok=True)
    for _trk in rig.animation_data.nla_tracks:
        _trk.mute = True
    ec.reset(rig)
    scene.render.engine = "BLENDER_WORKBENCH"
    shd = scene.display.shading
    shd.light = "STUDIO"
    shd.color_type = "VERTEX"
    shd.show_cavity = True
    shd.cavity_type = "WORLD"
    shd.show_shadows = True
    shd.shadow_intensity = 0.35
    scene.display.shadow_focus = 0.9
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.color = srgb("a9c6dc")
    scene.view_settings.view_transform = "Standard"
    # a ground and the plane's span for scale: a bar 1 long beside him
    gme = bpy.data.meshes.new("ground")
    gbm = bmesh.new()
    bmesh.ops.create_grid(gbm, x_segments=2, y_segments=2, size=3.0)
    gbm.to_mesh(gme)
    gbm.free()
    gca = gme.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for d in gca.data:
        d.color = (*srgb("8fa25a"), 1.0)
    ground = bpy.data.objects.new("ground", gme)
    scene.collection.objects.link(ground)
    bar_me = bpy.data.meshes.new("span")
    bbm = bmesh.new()
    bmesh.ops.create_cube(bbm, size=1.0)
    bmesh.ops.scale(bbm, vec=(0.012, 1.0, 0.012), verts=bbm.verts)
    bbm.to_mesh(bar_me)
    bbm.free()
    bca = bar_me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for d in bca.data:
        d.color = (0.9, 0.2, 0.15, 1.0)
    bar = bpy.data.objects.new("span_bar", bar_me)
    bar.location = (0.32, 0.0, 0.006)
    scene.collection.objects.link(bar)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def shoot(eye, at, lens=50, res=(640, 560)):
        cam.location = V(eye)
        cam.rotation_euler = (V(at) - V(eye)).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.render.resolution_x, scene.render.resolution_y = res
        cam_data.lens = lens
        path = OUTDIR / "_cell.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(path), check_existing=False)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        bpy.data.images.remove(img)
        return a

    def save(a, name, where=None):
        where = where or OUTDIR
        out = bpy.data.images.new(name, a.shape[1], a.shape[0])
        out.pixels = a.ravel()
        out.filepath_raw = str(where / f"{name}.png")
        out.file_format = "PNG"
        out.save()
        print("ELK_STILL", where / f"{name}.png")

    if STILLS:
        mane_ob, antler_ob = meshes[1], meshes[2]
        at = V((0, 0.05, 0.48))
        views = [(-90, 0.55), (-40, 0.75), (0, 0.6), (40, 0.75), (140, 0.75), (180, 0.6)]

        def ring_of(dist, height):
            out = []
            for ang, h in views:
                a = math.radians(ang)
                eye = V((math.sin(a) * dist, math.cos(a) * dist, height * h + 0.15))
                out.append(shoot(eye, at, lens=50))
            return out

        for variant in ("bull", "cow"):
            mane_ob.hide_render = variant == "cow"
            antler_ob.hide_render = variant == "cow"
            cells = ring_of(2.6, 0.9)
            row1 = np.concatenate(cells[:3], axis=1)
            row2 = np.concatenate(cells[3:], axis=1)
            save(np.concatenate([row2, row1], axis=0), f"turntable_{variant}")
        mane_ob.hide_render = False
        antler_ob.hide_render = False
        # the head, three-quarter and side; the whole bull flat side-on (the size check)
        c1 = shoot((-0.55, 0.95, 0.78), (0, 0.42, 0.68), lens=50, res=(640, 640))
        c2 = shoot((-1.3, 0.45, 0.70), (0, 0.42, 0.75), lens=50, res=(640, 640))
        save(np.concatenate([c1, c2], axis=1), "head")
        side = shoot((-3.2, 0.1, 0.55), (0, 0.1, 0.55), lens=60, res=(900, 640))
        save(side, "side_scale")
        # A rig check (not a clip): the head down to graze, a fore leg folded
        # up, a hind leg reaching back, the body pitched; side and three-quarter.
        TEST = {"neck1": -50, "neck2": -30, "head": -20, "upper_l": -35, "fore_l": 95, "cannon_l": -70,
                "thigh_r": 28, "shin_r": -25, "hcannon_r": 20, "ear_l": -30, "tail": 40}
        for pb in rig.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (math.radians(TEST.get(pb.name, 0)), 0, 0)
        bpy.context.view_layer.update()
        c1 = shoot((-3.0, 0.1, 0.55), (0, 0.1, 0.45), lens=60, res=(800, 600))
        c2 = shoot((-1.9, 1.9, 0.9), (0, 0.05, 0.42), lens=55, res=(800, 600))
        save(np.concatenate([c1, c2], axis=1), "rig_check")
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)

    if STRIPS:
        # A strip a clip: its key poses side-on (from his left) over the
        # same three-quarter front, the time in the corner of each cell.
        meshes[1].hide_render = meshes[2].hide_render = False
        font = bpy.data.curves.new("label", "FONT")
        font.size = 0.055
        label = bpy.data.objects.new("label", font)
        scene.collection.objects.link(label)
        label.parent = cam
        label.location = (-0.40, -0.33, -1.0)
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
        views = [((-1.75, 0.05, 0.5), (0, 0.05, 0.5), 42), ((-1.3, 1.3, 0.8), (0, 0.04, 0.45), 42)]
        STRIP_UP = {"leap": 0.18}
        for c in CLIPS:
            if ONLY and c.name not in ONLY:
                continue
            rows = []
            up = STRIP_UP.get(c.name, 0.0)    # a clip that rises (the leap's hang) framed higher and wider
            for eye, at_, lens in views:
                eye = V(eye) * (1.0 + up) + V((0, 0, up))
                at_ = V(at_) + V((0, 0, up))
                row = []
                for t in c.shots:
                    KRIG.apply(c, t)
                    font.body = f"{c.name}  {t:.2f}"
                    bpy.context.view_layer.update()
                    row.append(shoot(eye, at_, lens=lens, res=(360, 300)))
                rows.append(np.concatenate(row, axis=1))
            save(np.concatenate(rows[::-1], axis=0), f"strip_{c.name}", STRIPS)
        # the held poses close: graze.lift, alert.up held, stop_look.hold
        cells = []
        by = {c.name: c for c in CLIPS}
        for name, t, eye in (("graze", 2.2, (-1.05, 0.95, 0.55)), ("alert", 0.6, (-1.0, 1.1, 0.7)),
                             ("stop_look", 0.8, (-1.15, 0.85, 0.75))):
            KRIG.apply(by[name], t)
            font.body = f"{name}  {t:.2f}"
            bpy.context.view_layer.update()
            cells.append(shoot(eye, (0, 0.12, 0.45), lens=40, res=(560, 560)))
        save(np.concatenate(cells, axis=1), "holds", STRIPS)
        ec.reset(rig)
        bpy.data.objects.remove(label, do_unlink=True)
    (OUTDIR / "_cell.png").unlink(missing_ok=True)
