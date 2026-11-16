"""The temple kit's road of tombs: the monuments that line the road from the
town to the citadel, in the kit's stone, laid by scripts/endless/tombs_site.gd
(with the street's paving, kerbs and arch, the agora's altar, plinth and gate
and the kit's columns).

    python tools/blender.py run art/blender/temple_kit/tombs_build.py [-- --only=tombs_tower]

Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y). A monument's
origin is on the ground at its middle; its front is Blender -y (Godot +z).

- `tombs_house`: a house tomb: a stepped base, four walls, a door (dark
  inside), a cornice and a gabled stone roof. HOUSE_W by HOUSE_D.
- `tombs_house_broken`: the same with its roof and half its walls down.
- `tombs_tower`: a tower tomb: a square shaft in three tiers on a stepped
  base, a stepped cap. TOWER_W across (breaks_build.py makes its cracked
  variant and its stump).
- `tombs_exedra`: a half-round bench with a high back on a low platform,
  open toward the front.
- `tombs_pillar`: a square pillar on a stepped base, its cap chipped.
- `tombs_sarcophagus`: a stone chest on a stepped base, its gabled lid askew.
- `tombs_step`: one giant step of the way over the pass: a row of blocks
  STEP_W wide (x) and STEP_T deep (y), their tops at the origin's height,
  STEP_DEEP down into the slope.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

HERE = Path(__file__).resolve().parent
# The citadel's helpers (Lay, wall, ring, floor, tumble, drum ...), without its builds.
_src = (HERE / "citadel_build.py").read_text()
_src = _src[:_src.index("\n# ---- builds")]
C = {"__name__": "tombs_borrowed_citadel"}
exec(compile(_src, str(HERE / "citadel_build.py"), "exec"), C)
Lay, wall, ring, floor, tumble, drum, rect, arch, step_top, courses = (C[k] for k in (
    "Lay", "wall", "ring", "floor", "tumble", "drum", "rect", "arch", "step_top", "courses"))

CR = 1.6                    # the monuments' course
HOUSE_W, HOUSE_D = 11.0, 13.0
HOUSE_H = CR * 6            # the walls, over the base
BASE_H = 1.6
TOWER_W = 9.0
TOWER_H = CR * 17
STEP_W = 17.0
STEP_T = 3.0
STEP_DEEP = 16.0


def base(L, w, d, steps=2, h=0.8, out=0.9, ground=-1.6):
    """A stepped base: `steps` courses, each `out` wider all round than the
    one over it, the top one w by d; its top at steps * h."""
    for k in range(steps):
        e = out * (steps - k)
        z0 = ground if k == 0 else k * h
        z1 = (k + 1) * h
        hw, hd = w / 2 + e, d / 2 + e
        for sd, a, b in (("-y", (-hw, -hd), (hw, -hd)), ("+y", (-hw, hd), (hw, hd)),
                         ("-x", (-hw, -hd + 1.4), (-hw, hd - 1.4)), ("+x", (hw, -hd + 1.4), (hw, hd - 1.4))):
            wall(L, a, b, z0, z1, sd, thick=1.4, course=z1 - z0, length=(2.4, 4.2), solid=False, far=False)
        floor(L, -hw, hw, -hd, hd, z1, t=0.5, size=(2.4, 4.0), far=False,
              keep=lambda x, y, e=e: abs(x) > w / 2 + e - out - 0.2 or abs(y) > d / 2 + e - out - 0.2)
        L.p.far_box((0, 0, (z0 + z1) / 2), (2 * hw, 2 * hd, z1 - z0))
    L.p.solid((-w / 2 - out * steps, -d / 2 - out * steps, ground), (w / 2 + out * steps, d / 2 + out * steps, steps * h))
    return steps * h


def box_walls(L, w, d, z0, z1, holes=None, tops=None, thick=1.2, ragged=False, length=(2.2, 3.8), solid=True):
    holes = holes or {}
    tops = tops or {}
    hw, hd = w / 2, d / 2
    for sd, a, b in (("-y", (-hw, -hd), (hw, -hd)), ("+y", (-hw, hd), (hw, hd)),
                     ("-x", (-hw, -hd + thick), (-hw, hd - thick)), ("+x", (hw, -hd + thick), (hw, hd - thick))):
        wall(L, a, b, z0, z1, sd, thick=thick, course=CR, length=length, holes=holes.get(sd, ()), top=tops.get(sd),
             ragged=ragged, through=ragged, solid=solid, far=True)


def build_house(L, broken):
    L.p.ground = 0.0
    r = L.r
    z0 = base(L, HOUSE_W + 1.0, HOUSE_D + 1.0)
    z1 = z0 + HOUSE_H
    door = rect(0.0, 3.6, z0, z0 + CR * 4)
    tops = {}
    if broken:
        def rag(seed, lo, hi, tilt):
            return step_top(lambda u: z0 + lo + (hi - lo) * (0.5 + 0.5 * tilt * u / 6.5)
                            + 1.6 * noise.noise(Vector((u * 0.4, seed, 2.0))), course=CR, z0=z0)
        tops = {"-y": rag(1.0, 3.0, 8.0, -1.0), "+y": rag(2.0, 5.0, 9.6, -1.0), "-x": rag(3.0, 6.5, 9.6, 1.0),
                "+x": rag(4.0, 1.0, 4.0, 1.0)}
    box_walls(L, HOUSE_W, HOUSE_D, z0, z1, holes={"-y": [door]}, tops=tops, ragged=broken, solid=broken)
    # The dark inside the door.
    L.block((0.0, -HOUSE_D / 2 + 1.5, z0 + CR * 2), (3.8, 0.4, CR * 4), tone=0.3, chips=0, hide=["+y", "-z", "+z", "-x", "+x"])
    if broken:
        tumble(L, 22, lambda: (r.uniform(-4.0, 9.0), r.uniform(-HOUSE_D / 2 - 5.0, HOUSE_D / 2), z0 * (0.0 if r.random() < 0.6 else 1.0) - 0.2),
               size=(1.0, 2.8), solid_over=9.0)
        L.p.solid((2.0, -HOUSE_D / 2 - 4.0, -0.5), (9.0, HOUSE_D / 2, 1.8))
        return
    L.p.solid((-HOUSE_W / 2, -HOUSE_D / 2, z0), (HOUSE_W / 2, HOUSE_D / 2, z1 + 4.6))
    # The cornice: a course standing out all round.
    cw, cd = HOUSE_W + 1.2, HOUSE_D + 1.2
    for sd, a, b in (("-y", (-cw / 2, -cd / 2), (cw / 2, -cd / 2)), ("+y", (-cw / 2, cd / 2), (cw / 2, cd / 2)),
                     ("-x", (-cw / 2, -cd / 2 + 1.0), (-cw / 2, cd / 2 - 1.0)), ("+x", (cw / 2, -cd / 2 + 1.0), (cw / 2, cd / 2 - 1.0))):
        wall(L, a, b, z1, z1 + 0.9, sd, thick=1.0, course=0.9, length=(2.6, 4.4), solid=False, far=False, through=True)
    # The gables front and back (courses stepping in), the roof's two slopes.
    rise = 3.6
    zc = z1 + 0.9
    for k in range(3):
        half = cw / 2 * (1.0 - (k + 0.5) / 3.2)
        for sd, y in (("-y", -cd / 2 + 0.3), ("+y", cd / 2 - 0.3)):
            wall(L, (-half, y), (half, y), zc + k * rise / 3, zc + (k + 1) * rise / 3, sd, thick=1.0, course=rise / 3,
                 length=(2.4, 4.0), solid=False, far=False, through=True)
    a = math.atan2(rise, cw / 2)
    run = cw / 2 / math.cos(a) + 0.5
    y = -cd / 2 - 0.2
    while y < cd / 2:
        w = min(r.uniform(2.6, 3.6), cd / 2 + 0.2 - y)
        for s in (-1, 1):
            if r.random() < 0.08:
                continue
            L.block((s * cw / 4, y + w / 2, zc + rise / 2 + 0.2), (run, w - T.JOINT, 0.7), tilt=(0.0, s * a), chips=1,
                    hide=["-z"])
        y += w
    L.p.far_box((-cw / 4, 0, zc + rise / 2 + 0.2), (run, cd, 0.7), tilt=(0.0, -a))
    L.p.far_box((cw / 4, 0, zc + rise / 2 + 0.2), (run, cd, 0.7), tilt=(0.0, a))


def build_tower(L):
    L.p.ground = 0.0
    r = L.r
    z0 = base(L, TOWER_W + 1.0, TOWER_W + 1.0, steps=3)
    door = rect(0.0, 2.8, z0, z0 + CR * 3)
    niche = rect(0.0, 3.0, z0 + CR * 8, z0 + CR * 11)
    z = z0
    w = TOWER_W
    for tier in range(3):
        n = (6, 6, 5)[tier]
        box_walls(L, w, w, z, z + CR * n, holes={"-y": [door] if tier == 0 else ([niche] if tier == 1 else [])},
                  length=(2.4, 4.6), solid=False)
        z += CR * n
        # A band standing out between the tiers.
        bw = w + 1.0
        for sd, a, b in (("-y", (-bw / 2, -bw / 2), (bw / 2, -bw / 2)), ("+y", (-bw / 2, bw / 2), (bw / 2, bw / 2)),
                         ("-x", (-bw / 2, -bw / 2 + 0.9), (-bw / 2, bw / 2 - 0.9)), ("+x", (bw / 2, -bw / 2 + 0.9), (bw / 2, bw / 2 - 0.9))):
            wall(L, a, b, z - 0.01, z + 0.8, sd, thick=0.9, course=0.81, length=(2.6, 4.6), solid=False, far=False, through=True)
        floor(L, -bw / 2, bw / 2, -bw / 2, bw / 2, z + 0.8, t=0.8, far=False, size=(2.4, 4.0), under=True,
              keep=lambda x, y, w=w: abs(x) > w / 2 - 0.9 or abs(y) > w / 2 - 0.9)
        z += 0.8
        w -= 0.7
    for (yy, zz) in ((-TOWER_W / 2 + 1.3, z0 + CR * 1.5), (-(TOWER_W - 0.7) / 2 + 1.3, z0 + CR * 9.5 + 0.8)):
        L.block((0.0, yy, zz), (3.0, 0.4, CR * 3), tone=0.3, chips=0, hide=["+y", "-z", "+z", "-x", "+x"])
    # The cap: steps in to a block, its top broken.
    for k, (cw, h) in enumerate(((w + 0.2, 1.3), (w - 1.8, 1.3), (w - 3.8, 1.5))):
        L.block((0, 0, z + h / 2), (cw, cw, h - T.JOINT), hide=["-z"], edge=k == 2, far=True)
        z += h
    L.p.solid((-TOWER_W / 2, -TOWER_W / 2, z0), (TOWER_W / 2, TOWER_W / 2, z))


def build_exedra(L):
    L.p.ground = 0.0
    R = 7.5
    # The platform: a half round of slabs behind the front's straight kerb.
    drum(L, R + 1.2, -1.4, 0.7, 0.0, math.pi, thick=1.2, length=3.2)
    floor(L, -R - 1.2, R + 1.2, 0.0, R + 1.2, 0.7, t=0.5, far=False, size=(2.4, 3.8),
          keep=lambda x, y: x * x + y * y < (R + 0.4) ** 2)
    wall(L, (-R - 1.2, 0.0), (R + 1.2, 0.0), -1.4, 0.7, "-y", thick=1.2, course=2.1, length=(2.6, 4.2), solid=False, far=False)
    # The seat and the high back: a half ring open to the front (-y).
    for (rad, z0, z1, th) in ((R - 1.6, 0.7, 2.0, 1.6), (R, 0.7, 5.1, 1.3)):
        for k, (zl, zh) in enumerate(courses(z0, z1, 1.5)):
            n = 9
            for i in range(n):
                am = (i + 0.5) * math.pi / n
                chord = 2.0 * rad * math.sin(math.pi / n / 2)
                L.block(((rad - th / 2) * math.cos(am), (rad - th / 2) * math.sin(am), (zl + zh) / 2),
                        (chord - T.JOINT, th, zh - zl - T.JOINT), yaw=am + math.pi / 2, hide=["-z"],
                        edge=zh >= z1 - 0.01 and i in (2, 3))
    # The two ends: blocks with a worn arm rest.
    for s in (-1, 1):
        L.block((s * (R - 0.8), 0.9, 2.2), (1.9, 1.6, 3.0), hide=["-z"], edge=s > 0)
    n = 7
    for i in range(n):
        am = (i + 0.5) * math.pi / n
        cx, cy = (R - 0.9) * math.cos(am), (R - 0.9) * math.sin(am)
        L.p.solid((cx - 1.8, cy - 1.8, -1.0), (cx + 1.8, cy + 1.8, 5.1))
        L.p.far_box((cx, cy, 2.0), (3.4, 2.4, 6.2), yaw=am + math.pi / 2)
    L.p.solid((-R - 1.2, 0.0, -1.4), (R + 1.2, R + 1.2, 0.7))
    L.p.far_box((0, R / 2, -0.35), (2 * R + 2.4, R + 1.2, 2.1))


def build_pillar(L):
    L.p.ground = 0.0
    z = base(L, 4.2, 4.2, steps=2)
    w = 3.2
    for k in range(8):
        L.block((0, 0, z + CR / 2), (w, w, CR - T.JOINT), hide=["-z", "+z"] if k < 7 else ["-z"], far=False)
        z += CR
    L.block((0, 0, z + 0.5), (w + 1.0, w + 1.0, 1.0 - T.JOINT), edge=True, hide=["-z"])
    L.block((0.3, -0.2, z + 1.0 + 0.7), (1.6, 1.6, 1.4), edge=True, hide=["-z"], tilt=(0.06, -0.04))
    L.p.far_box((0, 0, (1.6 + z) / 2), (w, w, z - 1.6))
    L.p.solid((-w / 2, -w / 2, 0.0), (w / 2, w / 2, z + 2.4))


def build_sarcophagus(L):
    L.p.ground = 0.0
    r = L.r
    z = base(L, 8.6, 5.0, steps=2)
    # The chest: two long stones a side, the ends one each.
    w, d, h = 7.4, 3.8, 3.2
    box_walls(L, w, d, z, z + h, thick=1.0, length=(3.2, 4.4), solid=False)
    # The lid: a gabled stone, slid askew, a corner broken.
    a = math.atan2(1.1, d / 2 + 0.3)
    run = (d / 2 + 0.3) / math.cos(a)
    m_yaw = 0.09
    for s in (-1, 1):
        for (x0, x1) in ((-w / 2 - 0.4, 0.2), (0.2, w / 2 + 0.4)):
            cx, cy = (x0 + x1) / 2 + 0.5, s * (d / 4 + 0.15) + 0.35
            L.block((cx * math.cos(m_yaw) - cy * math.sin(m_yaw), cx * math.sin(m_yaw) + cy * math.cos(m_yaw), z + h + 0.75),
                    (x1 - x0 - T.JOINT, run, 0.9), yaw=m_yaw, tilt=(-s * a, 0.0), hide=["-z"], edge=s > 0 and x0 > 0, far=True)
    L.p.solid((-w / 2, -d / 2, z), (w / 2, d / 2, z + h + 1.6))


def build_step(L, broken):
    """A row of big blocks: the tops level, a little uneven; the broken row
    has lost a block and another has slid."""
    L.p.ground = -100.0
    r = L.r
    x = -STEP_W / 2
    k = 0
    while x < STEP_W / 2 - 0.3:
        Lb = min(r.uniform(3.4, 5.2), STEP_W / 2 - x)
        if STEP_W / 2 - (x + Lb) < 2.0:
            Lb = STEP_W / 2 - x
        dz = r.uniform(-0.12, 0.06)
        lost = broken and k == 1
        slid = broken and k == 2
        if not lost:
            L.block((x + Lb / 2, 0.6 if slid else 0.0, -STEP_DEEP / 2 + dz - (0.9 if slid else 0.0)),
                    (Lb - T.JOINT * 2, STEP_T, STEP_DEEP), hide=["-z"], edge=broken,
                    tilt=(0.1, 0.03) if slid else (r.uniform(-0.01, 0.01), r.uniform(-0.01, 0.01)), far=True)
        x += Lb
        k += 1
    L.p.solid((-STEP_W / 2, -STEP_T / 2, -STEP_DEEP), (STEP_W / 2, STEP_T / 2, 0.0))


JOBS = {
    "tombs_house": (lambda L: build_house(L, False), 201),
    "tombs_house_broken": (lambda L: build_house(L, True), 202),
    "tombs_tower": (build_tower, 203),
    "tombs_exedra": (build_exedra, 204),
    "tombs_pillar": (build_pillar, 205),
    "tombs_sarcophagus": (build_sarcophagus, 206),
    "tombs_step": (lambda L: build_step(L, False), 207),
    "tombs_step_broken": (lambda L: build_step(L, True), 208),
}
NO_MID = {"tombs_step", "tombs_step_broken", "tombs_pillar", "tombs_sarcophagus"}

if __name__ in ("__main__", "temple_breaks_source"):
    for name, (job, seed) in JOBS.items():
        if only is None or only == name:
            for mid in (False, True):
                if mid and (name in NO_MID or __name__ != "__main__"):
                    continue
                L = Lay(name, seed, mid)
                job(L)
                L.export()
