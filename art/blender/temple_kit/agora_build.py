"""The temple kit's agora (lane agora): the pieces a ruined square needs that
the kit lacks, in the kit's stone (temple_lib) and on its BAY. The square's
columns, lintels, fallen drums and broken wall are the kit's own pieces;
scripts/endless/agora_site.gd lays them all.

    python tools/blender.py run art/blender/temple_kit/agora_build.py [-- --only=agora_gate]

Pieces (Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y)):
- `agora_stoa_wall`: one bay of the stoa's back wall, the wall kit's ashlar
  (wall_build.py's courses) carried on to WALL_TOP. The wall runs along x,
  origin on the foot line at the bay's middle; course k spans
  -9.25+t_k..9.25+t_k (t_k the wall kit's tooth), so bays laid every BAY
  meet course for course, and a `wall_broken` after one (turn 0) too.
- `agora_stoa_roof`: one bay of the stoa's roof: half a cross beam at each
  bay end, coffer slabs on them, a stone roof falling from the back wall to
  the front lintel. Origin on the ground at the bay's middle on the front
  column line; the back wall's axis at y = DEPTH (Godot z = -DEPTH).
- `agora_stoa_roof_broken`: the same bay fallen in through its middle: a
  ragged hole across the whole width, one half beam snapped short.
- `agora_roof_rubble`: what fell: roof slabs, coffers and a beam piece on
  the floor, in the roof bay's frame (origin as the roof's, on the ground).
- `agora_gate`: the west gateway: two piers, a flat arch of wedge stones
  over a GATE_W x GATE_H clear opening and the kit's entablature height
  over it, its +y top end fallen to the +x side. Travel along x; origin on
  the ground at the opening's middle; nothing at x < -GATE_T/2.
- `agora_paving`, `agora_paving_broken`: one BAY x BAY tile of flagstones,
  origin on the ground at its middle, tops PAVE_TOP over it; the broken one
  lost in drifts (most toward +x +y), slabs heaved and split.
- `agora_altar`, `agora_plinth` (a statue base, the statue gone but its
  feet), `agora_drum` (one drum lying on its side): origin on the ground.
"""

import math
import sys
from pathlib import Path

import bmesh
from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

HERE = Path(__file__).resolve().parent


def borrow(fname, stop):
    """Another build script's helpers without running its builds: its source
    up to `stop` (its build calls), run in a namespace of its own."""
    src = (HERE / fname).read_text()
    src = src[:src.index(stop)]
    ns = {"__name__": "agora_borrowed_" + fname.replace(".py", "")}
    exec(compile(src, str(HERE / fname), "exec"), ns)
    return ns


W = borrow("wall_build.py", "\nbuild_door()\nbuild_broken()")

BAY = T.BAY
HALF = BAY / 2
DEPTH = 24.0                # the front column line to the back wall's axis
WT = T.WALL_T + 0.3         # the wall kit's stones stand ~0.15 proud each face
WALL_IN = DEPTH - WT / 2    # the back wall's inner face
WALL_TOP = 43.0
LINTEL_TOP = T.COLUMN_H + T.ENTABLATURE_H   # 38.0
BEAM_W = 1.1                # half a cross beam (two bays' halves make one)
BEAM_LO = T.COLUMN_H + T.ARCHITRAVE_H       # 33.7
BEAM_HI = BEAM_LO + T.FRIEZE_H              # 36.3
COFFER_T = 0.7
ROOF_T = 0.75
ROOF_Y0, ROOF_Z0 = -3.4, LINTEL_TOP         # the front eave's underside
ROOF_Y1 = DEPTH + WT / 2 + 0.3              # the back eave
SLOPE = (WALL_TOP - 0.5 - ROOF_Z0) / (WALL_IN - ROOF_Y0)

GATE_W = 20.0               # the clear opening, across
GATE_H = 26.0               # to the flat arch's soffit
GATE_T = 6.0                # along the way through
PIER = 7.0                  # each pier's width, across
GATE_TOP = LINTEL_TOP

PAVE_TOP = 0.2
PAVE_T = 0.75


def scratch(p, fn):
    keep = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    try:
        fn()
    finally:
        p.near = keep
    return tmp


def roof_under(y):
    """The roof's underside at y."""
    return ROOF_Z0 + (y - ROOF_Y0) * SLOPE


# ---- the stoa's back wall ---------------------------------------------------
def build_stoa_wall(seed):
    p = T.Piece("agora_stoa_wall", seed=seed)
    p.ground = 0.0
    r = p.rng
    courses = W["COURSES"]
    if courses[-1][0] < 30.0:
        pass
    # The courses on from the kit's 30.5 to WALL_TOP.
    top = courses[-1][0] + courses[-1][1]
    for h in (2.1, 2.1, 2.1, 2.1, 2.1, 2.0):
        courses.append((top, h))
        top += h
    assert abs(top - WALL_TOP) < 1e-6, top
    W["footing"](p, -HALF, HALF)
    W["plinth"](p, -HALF, HALF)
    below = ()
    for k in range(1, len(courses)):
        t = W["tooth"](k)
        rec = {r.randrange(6)} if r.random() < 0.3 else None
        sp = W["lay_course"](p, k, -HALF + t, HALF + t, below=below, recess_at=rec)
        below = W["joints"](sp)
    p.far_box((0, 0, WALL_TOP / 2), (BAY, WT, WALL_TOP))
    p.solid((-HALF, -WT / 2, -W["FOOTING"]), (HALF, WT / 2, WALL_TOP))
    p.export()
    del courses[-6:]


# ---- the stoa's roof ----------------------------------------------------------
def roof_rows():
    """[(y0, y1)] of the roof's slab rows, front eave to back eave."""
    n = 9
    step = (ROOF_Y1 - ROOF_Y0) / n
    return [(ROOF_Y0 + i * step, ROOF_Y0 + (i + 1) * step) for i in range(n)]


def slab_along(p, x0, x1, y0, y1, keep, broken_edge, chips=1):
    """A roof row's slabs from x0 to x1 between y0 and y1 (along the slope);
    `keep(x, y)` decides each slab; a kept one next to a lost one breaks."""
    r = p.rng
    a = math.atan(SLOPE)
    ym = (y0 + y1) / 2
    run = (y1 - y0) / math.cos(a)
    zc = roof_under(ym) + ROOF_T / 2 / math.cos(a)
    x = x0
    out = []
    while x < x1 - 0.3:
        L = min(r.uniform(2.6, 4.6), x1 - x)
        if x1 - (x + L) < 1.2:
            L = x1 - x
        xc = x + L / 2
        if keep(xc, ym):
            edge = broken_edge(xc, ym)
            p.block((xc, ym, zc), (L - T.JOINT, run - T.JOINT, ROOF_T),
                    tilt=(a + (r.uniform(-0.03, 0.03) if edge else 0.0), r.uniform(-0.004, 0.004)),
                    chips=3 if edge else r.randint(0, chips), chip_depth=(0.15, 0.5) if edge else (0.08, 0.3),
                    far=False, hide=("-z",) if not edge else ())
            out.append((x, x + L))
        x += L
    return out


def build_roof(name, seed, broken=False):
    p = T.Piece(name, seed=seed)
    p.ground = -100.0
    r = p.rng
    # The hole: lost where y is inside a ragged band across the bay.
    def gone(x, y):
        if not broken:
            return False
        lo = 5.0 + 2.0 * noise.noise(Vector((x * 0.15, 0.3, 1.7)))
        hi = 19.5 + 2.0 * noise.noise(Vector((x * 0.13, 5.1, 0.4)))
        return lo < y < hi

    def near_gone(x, y):
        return broken and (gone(x, y - 3.2) or gone(x, y + 3.2))

    def keep(x, y):
        return not gone(x, y)

    # The half beams: the +x one whole, the -x one snapped at y ~10.5 (broken).
    beam_len = WALL_IN - 2.6
    for s in (-1, 1):
        xc = s * (HALF - BEAM_W / 2)
        y_end = WALL_IN
        y_start = 2.6
        segs = [(2.6, 6.2), (6.2, 12.8), (12.8, 19.4), (19.4, WALL_IN)]
        for (ya, yb) in segs:
            if broken and s < 0 and ya > 6.0 and yb < 19.5:
                continue
            ragged = broken and s < 0 and (abs(yb - 6.2) < 0.01 or abs(ya - 19.4) < 0.01)
            if broken and s < 0 and abs(yb - 6.2) < 0.01:
                yb = 6.2 + r.uniform(0.8, 1.6)
            p.block((xc, (ya + yb) / 2, (BEAM_LO + BEAM_HI) / 2), (BEAM_W - T.JOINT / 2, yb - ya - T.JOINT, BEAM_HI - BEAM_LO),
                    chips=3 if ragged else r.randint(0, 1), chip_depth=(0.2, 0.6) if ragged else (0.08, 0.3),
                    far=True, hide=("+z",) if not ragged else ())
            p.solid((xc - BEAM_W / 2, ya, BEAM_LO), (xc + BEAM_W / 2, yb, BEAM_HI))
    # The coffers: slabs across the bay on the beams, in strips along y.
    y = 2.6
    coffer_strips = []
    while y < WALL_IN - 0.3:
        w = min(r.uniform(2.4, 3.4), WALL_IN - y)
        if WALL_IN - (y + w) < 1.2:
            w = WALL_IN - y
        coffer_strips.append((y, y + w))
        y += w
    for (ya, yb) in coffer_strips:
        ym = (ya + yb) / 2
        x = -HALF
        while x < HALF - 0.3:
            L = min(r.uniform(5.0, 9.5), HALF - x)
            if HALF - (x + L) < 2.0:
                L = HALF - x
            xc = x + L / 2
            if keep(xc, ym):
                edge = near_gone(xc, ym)
                p.block((xc, ym, BEAM_HI + COFFER_T / 2), (L - T.JOINT, yb - ya - T.JOINT, COFFER_T),
                        chips=3 if edge else 1, chip_depth=(0.15, 0.45), far=False, hide=("+z",) if not edge else ())
            x += L
    # The fill between the coffers and the roof (only seen at the stoa's
    # ends and through the hole): plain stone stepped up under each row.
    rows = roof_rows()
    for (ya, yb) in rows:
        ys, ye = max(ya, 2.6), min(yb, WALL_IN)
        if ye - ys < 0.3:
            continue
        ym = (ys + ye) / 2
        if not keep(0.0, ym) or near_gone(0.0, ym):
            continue
        zt = roof_under(ys)
        z0 = BEAM_HI + COFFER_T
        if zt - z0 > 0.2:
            p.block((0, ym, (z0 + zt) / 2), (BAY - 0.1, ye - ys, zt - z0), bevel=0.0, chips=0, jitter=0.0,
                    far=False, hide=("-z", "+z"))
    # The roof's slabs, row by row.
    for (ya, yb) in rows:
        slab_along(p, -HALF, HALF, ya, yb, keep, near_gone)
    # A slab at the hole's front edge hanging, its back end dropped.
    if broken:
        a = math.atan(SLOPE)
        p.block((2.5, 6.6, roof_under(6.6) - 1.4), (3.4, 3.0, ROOF_T), tilt=(a + 0.55, 0.08), chips=3,
                chip_depth=(0.2, 0.5), far=True)
        p.solid((0.8, 5.2, roof_under(6.6) - 2.6), (4.2, 8.0, roof_under(6.6) + 0.2))
    # Far LOD and solids.
    a = math.atan(SLOPE)
    if not broken:
        p.far_box((0, (2.6 + WALL_IN) / 2, BEAM_HI + COFFER_T / 2), (BAY, WALL_IN - 2.6, COFFER_T))
        ym = (ROOF_Y0 + ROOF_Y1) / 2
        p.far_box((0, ym, roof_under(ym) + ROOF_T / 2), (BAY, (ROOF_Y1 - ROOF_Y0) / math.cos(a), ROOF_T), tilt=(a, 0))
        p.solid((-HALF, -3.2, BEAM_HI), (HALF, WALL_IN, WALL_TOP))
    else:
        for (y0, y1) in ((2.6, 4.5), (20.5, WALL_IN)):
            p.far_box((0, (y0 + y1) / 2, BEAM_HI + COFFER_T / 2), (BAY, y1 - y0, COFFER_T))
        for (y0, y1) in ((ROOF_Y0, 4.5), (20.0, ROOF_Y1)):
            ym = (y0 + y1) / 2
            p.far_box((0, ym, roof_under(ym) + ROOF_T / 2), (BAY, (y1 - y0) / math.cos(a), ROOF_T), tilt=(a, 0))
        p.solid((-HALF, -3.2, BEAM_HI), (HALF, 4.5, roof_under(4.5) + ROOF_T))
        p.solid((-HALF, 20.0, BEAM_HI), (HALF, WALL_IN, WALL_TOP))
    p.export()


def build_roof_rubble(seed):
    """Under the hole: slabs, coffers and a beam's middle on the floor,
    heaped toward the middle of the hole, a few leaning on others."""
    p = T.Piece("agora_roof_rubble", seed=seed)
    p.ground = 0.0
    r = p.rng
    stones = []
    for _ in range(9):
        stones.append((r.uniform(2.6, 4.4), r.uniform(2.6, 3.2), ROOF_T, "slab"))
    for _ in range(5):
        stones.append((r.uniform(4.0, 8.0), r.uniform(2.4, 3.2), COFFER_T, "slab"))
    stones.append((BEAM_W, 6.4, BEAM_HI - BEAM_LO, "beam"))
    for _ in range(18):
        stones.append((r.uniform(0.5, 1.4), r.uniform(0.5, 1.2), r.uniform(0.3, 0.8), "chunk"))
    for i, (sx, sy, sz, kind) in enumerate(stones):
        if kind == "beam":
            # The beam's snapped middle, one end on the floor, the other up on slabs.
            p.block((-6.4, 12.0, 1.6), (sx, sy, sz), yaw=0.25, tilt=(0.32, 0.12), chips=4,
                    chip_depth=(0.2, 0.6), far=True)
            p.solid((-8.4, 8.6, -0.5), (-4.4, 15.4, 3.6))
            continue
        x = max(-8.0, min(8.0, r.gauss(0.0, 3.8)))
        y = max(5.0, min(20.0, r.gauss(12.5, 3.4)))
        yaw = r.uniform(-0.5, 0.5) + (math.pi / 2 if r.random() < 0.3 else 0.0)
        big = kind == "slab"
        tilt = (r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)) if big else (r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6))
        z = sz * 0.3 + (r.uniform(0.2, 0.9) if big and r.random() < 0.4 else 0.0)
        if big and r.random() < 0.18:
            tilt = (r.choice((-1, 1)) * r.uniform(0.7, 1.0), 0.0)   # on its edge, leaning
            z = max(sx, sy) * 0.35
        p.block((x, y, z), (sx, sy, sz), yaw=yaw, tilt=tilt, chips=r.randint(2, 4), far=big,
                chip_depth=(0.15, 0.5))
        if big:
            e = max(sx, sy) / 2 * 0.85
            p.solid((x - e, y - e, -0.5), (x + e, y + e, z + max(sx, sy) * abs(math.sin(max(abs(tilt[0]), abs(tilt[1])))) / 2 + sz / 2))
    p.export()


# ---- the gate -----------------------------------------------------------------
def wedge_block(p, yc, w, z0, z1, zc, chips, sink=0.0):
    """A voussoir of the flat arch: centred across at yc, w wide at mid
    height, z0..z1, its side joints running toward (0, zc)."""
    zm = (z0 + z1) / 2
    bm = scratch(p, lambda: p.block((0, 0, zm), (GATE_T - 0.1, w - T.JOINT, z1 - z0 - T.JOINT), chips=chips,
                                     far=False, chip_depth=(0.12, 0.4)))
    for v in bm.verts:
        f = (v.co.z - zc) / (zm - zc)
        v.co.y = (yc + v.co.y) * f
        v.co.z -= sink
    T._append(p.near, bm)
    bm.free()


def build_gate(seed):
    p = T.Piece("agora_gate", seed=seed)
    p.ground = 0.0
    r = p.rng
    hx = GATE_T / 2
    y_in, y_out = GATE_W / 2, GATE_W / 2 + PIER
    # Footings under the ground.
    for s in (-1, 1):
        p.block((0, s * (y_in + y_out) / 2, -1.6), (GATE_T + 0.6, PIER + 0.6, 3.2), bevel=0.0, chips=0, jitter=0.0,
                far=False)
    # The piers: a base course standing out, then courses of two blocks,
    # split along x or across in turn, to the impost.
    course_h = 2.5
    for s in (-1, 1):
        yc = s * (y_in + y_out) / 2
        p.block((0, yc, 0.6), (GATE_T + 0.4, PIER + 0.4, 1.2), chips=2, chip_depth=(0.15, 0.4), far=False)
        z = 1.2
        k = 0
        while z < GATE_H - 1.0 - 0.01:
            h = min(course_h, GATE_H - 1.0 - z)
            cut = r.uniform(-0.6, 0.6)
            if k % 2 == 0:
                parts = [((-hx + cut) / 2, yc, hx + cut), ((hx + cut) / 2, yc, hx - cut)]
                for (xc, yc2, L) in parts:
                    p.block((xc + r.uniform(-0.03, 0.03), yc2, z + h / 2), (L - T.JOINT, PIER - T.JOINT, h - T.JOINT),
                            chips=r.randint(0, 2), far=False)
            else:
                ya, yb = yc - PIER / 2, yc + PIER / 2
                ym = yc + cut
                for (a, b) in ((ya, ym), (ym, yb)):
                    p.block((r.uniform(-0.03, 0.03), (a + b) / 2, z + h / 2), (GATE_T - T.JOINT, b - a - T.JOINT, h - T.JOINT),
                            chips=r.randint(0, 2), far=False)
            z += h
            k += 1
        # The impost band, standing out all round.
        p.block((0, yc, GATE_H - 0.5), (GATE_T + 0.5, PIER + 0.5, 1.0), chips=2, chip_depth=(0.15, 0.4), far=False)
        p.far_box((0, yc, (GATE_H - 3.2) / 2), (GATE_T, PIER, GATE_H + 3.2))
        p.solid((-hx - 0.3, yc - PIER / 2 - 0.3, -3.2), (hx + 0.3, yc + PIER / 2 + 0.3, GATE_H))
    # The flat arch: wedge stones over the opening and the piers' inner
    # halves, joints running to a point under it, the keystone settled.
    arch_top = GATE_H + 4.5
    zc = GATE_H - 16.0
    n = 9
    span = GATE_W + 4.0
    for i in range(n):
        yc = -span / 2 + (i + 0.5) * span / n
        wedge_block(p, yc, span / n, GATE_H, arch_top, zc, chips=r.randint(0, 2),
                    sink=0.28 if i == n // 2 else 0.0)
    # The piers' outer halves up beside the arch.
    for s in (-1, 1):
        a, b = s * (y_in + 2.0), s * y_out
        a, b = min(a, b), max(a, b)
        z = GATE_H
        for h in (2.3, 2.2):
            p.block((0, (a + b) / 2, z + h / 2), (GATE_T - T.JOINT, b - a - T.JOINT, h - T.JOINT), chips=1, far=False)
            z += h
    p.far_box((0, 0, (GATE_H + arch_top) / 2), (GATE_T, GATE_W + 2 * PIER, arch_top - GATE_H))
    # The entablature: architrave, frieze, cornice. The +y end is down from
    # BREAK_Y on (the cornice) and its frieze's last block too.
    full = GATE_W / 2 + PIER + 0.3
    z = arch_top
    BREAK_Y = 8.0 + r.uniform(-0.6, 0.6)
    for (h, depth, out, kind) in ((T.ARCHITRAVE_H, GATE_T, 0.0, "arch"), (T.FRIEZE_H, GATE_T - 0.2, 0.0, "frieze"),
                                  (T.CORNICE_H, GATE_T + 1.2, 0.6, "cornice")):
        y = -full - out
        y_end = full + out
        if kind == "cornice":
            y_end = BREAK_Y
        elif kind == "frieze":
            y_end = full - 4.2
        while y < y_end - 0.3:
            L = min(r.uniform(3.4, 6.2), y_end - y)
            if y_end - (y + L) < 1.5:
                L = y_end - y
            last = y + L >= y_end - 1e-6
            broke = last and kind != "arch"
            if kind == "frieze" and not broke:
                # Panels set back between plain blocks.
                p.block((0, y + L / 2, z + h / 2), (depth - (0.35 if r.random() < 0.5 else 0.0), L - T.JOINT, h - T.JOINT),
                        chips=r.randint(0, 2), far=False)
            else:
                p.block((r.uniform(-0.04, 0.04), y + L / 2, z + h / 2), (depth, L - T.JOINT, h - T.JOINT),
                        chips=4 if broke else r.randint(0, 2), chip_depth=(0.25, 0.7) if broke else (0.1, 0.35),
                        far=False)
            y += L
        if kind == "frieze":
            # A stub of the lost block, its top bitten.
            p.block((0, full - 3.4, z + h * 0.3), (depth, 1.4, h * 0.6), chips=3, chip_depth=(0.2, 0.5), far=False)
        p.far_box((0, ((-full - out) + y_end) / 2, z + h / 2), (depth, y_end + full + out, h))
        z += h
    top = z
    p.solid((-hx - 0.6, -full - 0.6, GATE_H), (hx + 0.6, full, arch_top + T.ARCHITRAVE_H + T.FRIEZE_H))
    p.solid((-hx - 0.6, -full - 0.6, arch_top + T.ARCHITRAVE_H + T.FRIEZE_H), (hx + 0.6, BREAK_Y, top))
    # What fell: cornice and frieze blocks on the ground on the +x side, by the +y pier.
    falls = [(6.0, 13.5, (1.7, 5.0, 2.8), 0.4), (9.5, 17.0, (2.6, 4.6, 2.2), -0.9), (5.2, 19.5, (1.6, 3.6, 2.6), 1.2),
             (11.8, 12.6, (0.9, 1.3, 0.8), 0.3), (8.2, 21.4, (0.8, 1.0, 0.7), 2.0), (4.6, 16.4, (1.0, 0.8, 0.6), 0.7)]
    for (fx, fy, (sx, sy, sz), yaw) in falls:
        tilt = (r.uniform(-0.25, 0.25), r.uniform(-0.25, 0.25))
        zc_ = sz / 2 - sz * r.uniform(0.15, 0.3)
        p.block((fx, fy, zc_), (sx, sy, sz), yaw=yaw, tilt=tilt, chips=r.randint(2, 4), chip_depth=(0.15, 0.5),
                far=sx > 1.2)
        if sx > 1.2:
            e = max(sx, sy) / 2
            p.solid((fx - e, fy - e, -0.5), (fx + e, fy + e, zc_ + sz / 2 + 0.2))
    p.export()


# ---- paving -------------------------------------------------------------------
def paving_slabs(rng, broken):
    """[(x0, x1, y0, y1, lost, heave)]: the tile's flagstones in rows along x."""
    out = []
    y = -HALF
    while y < HALF - 0.3:
        w = min(rng.uniform(1.7, 2.7), HALF - y)
        if HALF - (y + w) < 1.0:
            w = HALF - y
        x = -HALF + rng.uniform(0.0, 0.0)
        while x < HALF - 0.3:
            L = min(rng.uniform(2.0, 4.2), HALF - x)
            if HALF - (x + L) < 1.0:
                L = HALF - x
            xc, yc = x + L / 2, y + w / 2
            n = noise.noise(Vector((xc * 0.16 + (7.3 if broken else 1.1), yc * 0.16, 2.2)))
            if broken:
                bias = (xc + yc) / (2 * HALF) * 0.5      # more lost toward +x +y
                lost = n + bias > 0.0
                heave = (not lost) and n + bias > -0.35
            else:
                lost = n > 0.42 or rng.random() < 0.03
                heave = (not lost) and (n > 0.25 or rng.random() < 0.05)
            out.append((x, x + L, y, y + w, lost, heave))
            x += L
        y += w
    return out


def build_paving(name, seed, broken, mid=False):
    p = T.Piece(name, seed=seed)
    p.ground = -0.3
    slabs = paving_slabs(T.random.Random(seed * 7 + 1), broken)
    shape = T.random.Random(seed * 13 + 5)
    for (x0, x1, y0, y1, lost, heave) in slabs:
        L, w = x1 - x0, y1 - y0
        xc, yc = (x0 + x1) / 2, (y0 + y1) / 2
        dz = shape.uniform(-0.05, 0.04)
        tilt = (shape.uniform(-0.012, 0.012), shape.uniform(-0.012, 0.012))
        if heave:
            ax = shape.choice((0, 1))
            t = shape.uniform(0.05, 0.14 if not broken else 0.26)
            tilt = (t * shape.choice((-1, 1)), 0.0) if ax == 0 else (0.0, t * shape.choice((-1, 1)))
            dz += t * (w if ax == 0 else L) * 0.3
        split = (heave or broken) and shape.random() < (0.35 if broken else 0.15) and L > 2.4
        if lost:
            # A lost slab: sometimes a sunk shard of it left in the hole.
            if shape.random() < (0.3 if broken else 0.2):
                s = (L * shape.uniform(0.3, 0.5), w * shape.uniform(0.3, 0.6), PAVE_T * 0.5)
                c = (xc + shape.uniform(-0.3, 0.3) * L, yc + shape.uniform(-0.2, 0.2) * w, PAVE_TOP - 0.3)
                tl = (shape.uniform(-0.25, 0.25), shape.uniform(-0.25, 0.25))
                if mid:
                    p.block(c, s, tilt=tl, bevel=0.0, chips=0, jitter=0.0, far=False, hide=("-z",))
                else:
                    p.block(c, s, tilt=tl, chips=2, chip_depth=(0.08, 0.2), far=False, hide=("-z",))
            continue
        parts = [(x0, x1)]
        if split:
            m = x0 + L * shape.uniform(0.35, 0.65)
            parts = [(x0, m - 0.08), (m + 0.08, x1)]
        for (a, b) in parts:
            pl = b - a
            c = ((a + b) / 2, yc, PAVE_TOP - PAVE_T / 2 + dz)
            s = (pl - T.JOINT * 2, w - T.JOINT * 2, PAVE_T)
            tl = tilt if len(parts) == 1 else (tilt[0] + shape.uniform(-0.04, 0.04), tilt[1] + shape.uniform(-0.04, 0.04))
            ch = shape.randint(0, 2) + (2 if heave or split else 0)
            if mid:
                p.block(c, s, tilt=tl, bevel=0.0, chips=0, jitter=0.0, far=False, hide=("-z",))
            else:
                p.block(c, s, tilt=tl, chips=ch, chip_depth=(0.08, 0.3), far=False, hide=("-z",))
            if broken:
                p.far_box(c, s, tilt=tl)
    if mid:
        p.export(mid_of=name)
        return
    if not broken:
        p.far_box((0, 0, PAVE_TOP - PAVE_T / 2), (BAY, BAY, PAVE_T))
    p.export()


# ---- things standing in the square ------------------------------------------------
def build_altar(seed):
    p = T.Piece("agora_altar", seed=seed)
    p.ground = 0.0
    r = p.rng
    p.course(-5.3, 5.3, -0.4, 1.2, 7.0, length=(2.6, 4.0), chips=2)
    p.course(-4.7, 4.7, 0.8, 0.8, 5.9, length=(2.4, 3.8), chips=2)
    for k, z in enumerate((1.6, 2.9)):
        for s in (-1, 1):
            p.course(-4.2, 4.2, z, 1.3, 2.45, y=s * 1.225, length=(2.0, 3.6), chips=2)
    p.course(-4.5, 4.5, 4.2, 0.55, 5.5, length=(3.0, 4.6), chips=2)
    # The bolsters: one at each end, the +x one knocked off and lying by it.
    p.block((-3.75, 0, 5.2), (1.4, 5.5, 0.95), chips=2)
    p.block((3.9, 0.3, 5.0), (1.2, 4.8, 0.6), chips=4, chip_depth=(0.2, 0.5))
    p.block((7.2, 1.0, 0.35), (1.4, 5.3, 0.95), yaw=0.5, tilt=(0.0, 0.35), chips=3, chip_depth=(0.15, 0.4))
    p.solid((-5.3, -3.5, -0.4), (5.3, 3.5, 4.75))
    p.solid((-4.5, -2.75, 4.75), (-3.0, 2.75, 5.7))
    p.solid((5.8, -2.0, -0.2), (8.6, 4.0, 1.0))
    p.export()


def build_plinth(seed):
    p = T.Piece("agora_plinth", seed=seed)
    p.ground = 0.0
    r = p.rng
    p.course(-3.3, 3.3, -0.6, 1.3, 6.6, length=(2.8, 3.6), chips=2)
    p.course(-2.75, 2.75, 0.7, 0.6, 5.5, length=(2.6, 3.2), chips=2)
    for z in (1.3, 3.8):
        for s in (-1, 1):
            p.course(-2.3, 2.3, z, 2.5, 2.3, y=s * 1.15, length=(2.2, 3.2), chips=1)
    p.course(-2.8, 2.8, 6.3, 0.75, 5.6, length=(2.6, 3.2), chips=3)
    # The statue's feet and the stump of its legs, broken off at the shin.
    p.block((-0.5, 0.2, 7.5), (2.0, 1.3, 0.9), chips=2)
    p.block((-0.7, 0.4, 8.6), (0.8, 0.8, 1.6), tilt=(0.05, -0.08), chips=3, chip_depth=(0.12, 0.3))
    p.block((0.3, 0.1, 8.3), (0.75, 0.75, 1.0), chips=3, chip_depth=(0.12, 0.3))
    # The rest of it on the ground: a torso's block on its side.
    p.block((4.6, -2.1, 0.55), (2.6, 1.5, 1.5), yaw=0.7, tilt=(0.25, 0.1), chips=4, chip_depth=(0.2, 0.5))
    p.solid((-3.3, -3.3, -0.6), (3.3, 3.3, 7.05))
    p.solid((-1.5, -0.5, 7.05), (0.8, 0.9, 9.4))
    p.solid((3.2, -3.4, -0.2), (6.0, -0.8, 1.4))
    p.export()


def build_drum(seed):
    """One drum lying on its side along x, half a metre sunk, with spalls."""
    p = T.Piece("agora_drum", seed=seed)
    p.ground = 0.0
    r = p.rng
    r0, r1 = T.COLUMN_D / 2 - 0.1, T.COLUMN_D / 2 - 0.15
    bm = scratch(p, lambda: p.drum((0, 0, 0), T.DRUM_H - T.JOINT, r0, r1, chips=3, samples=2))
    rad = (r0 + r1) / 2
    m = Matrix.Translation((-T.DRUM_H / 2, 0, rad - 0.35)) @ Matrix.Rotation(0.06, 4, "X") @ Matrix.Rotation(math.pi / 2, 4, "Y")
    T._append(p.near, bm, m)
    bm.free()
    p.far_cylinder((0, 0, 0), T.DRUM_H, r0, r1, segments=10, matrix=m)
    for _ in range(4):
        s = r.uniform(0.3, 0.7)
        a = r.uniform(0, math.tau)
        d = r.uniform(2.4, 3.6)
        p.block((math.cos(a) * d, math.sin(a) * d, s * 0.2), (s * 1.3, s, s * 0.6), yaw=r.uniform(0, 3),
                tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), chips=2, far=False, chip_depth=(0.05, 0.15))
    p.solid((-T.DRUM_H / 2, -rad, -0.4), (T.DRUM_H / 2, rad, 2 * rad - 0.35))
    p.export()


JOBS = {
    "agora_stoa_wall": lambda: build_stoa_wall(41),
    "agora_stoa_roof": lambda: build_roof("agora_stoa_roof", 42),
    "agora_stoa_roof_broken": lambda: build_roof("agora_stoa_roof_broken", 43, broken=True),
    "agora_roof_rubble": lambda: build_roof_rubble(44),
    "agora_gate": lambda: build_gate(45),
    "agora_paving": lambda: (build_paving("agora_paving", 46, False), build_paving("agora_paving", 46, False, mid=True)),
    "agora_paving_broken": lambda: (build_paving("agora_paving_broken", 47, True),
                                    build_paving("agora_paving_broken", 47, True, mid=True)),
    "agora_altar": lambda: build_altar(48),
    "agora_plinth": lambda: build_plinth(49),
    "agora_drum": lambda: build_drum(50),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
