"""The temple kit's aqueduct (lane aqueduct): one tall tier of arches on
piers carrying a channel, in the kit's stone (temple_lib), on the kit's BAY.

    python tools/blender.py run art/blender/temple_kit/aqueduct_build.py [-- --only=aqueduct_pier]

Pieces (scripts/endless/aqueduct_site.gd lays them):
- `aqueduct_pier`: one pier, 4.0 m along the line by 5.0 across, its impost
  band at the arch's springing, its spandrel up to the cornice and the
  channel over it. It hangs from the deck down to PIER_DEEP, so it reaches
  the ground however low the land falls under the channel.
- `aqueduct_arch`, `aqueduct_arch_b` (another seed): the arch between two
  piers: a ring of wedge voussoirs, the spandrel courses, the cornice and
  the channel's two walls. Clear opening 14.5 m wide (BAY - PIER_W) and
  from the ground to the crown, 4.0 m under the deck.
- `aqueduct_arch_broken`: the same arch snapped part-way: its ring and
  courses stand out from the -x pier and end ragged around x -3.5.
- `aqueduct_pier_broken`: a pier's stump, standing to about 17 m, its top
  courses ragged; it runs STUMP_DEEP into the ground (the layout sinks it
  more or less for its height).
- `aqueduct_rubble`: a heap of fallen voussoirs and course blocks, sunk in.

Frame (Blender, z up): the line runs along x, the faces look along +-y.
Pier and arch origins are on the deck (the channel walls' top) at the
pier's / the opening's middle: piers at x = k*BAY, arches at (k+0.5)*BAY.
The stump and the rubble have their origin on the ground.
"""

import math
import sys

import bmesh
from mathutils import Matrix

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

BAY = T.BAY                 # 18.5, pier centre to centre
PIER_W = 4.0                # along the line
THICK = 5.0                 # across the line
OPEN = BAY - PIER_W         # 14.5 clear
R = OPEN / 2                # 7.25, the intrados
RING = 1.4                  # the voussoirs' depth
RE = R + RING               # 8.65, the extrados
VOUSSOIRS = 17
CORNICE_TOP = -1.8          # the channel's floor
CORNICE_H = 0.8
CORNICE_OUT = 0.25
SPAN_TOP = CORNICE_TOP - CORNICE_H   # -2.6: the spandrel's top, the ring's crown
SPRING = SPAN_TOP - RE               # -11.25: the springing
CROWN = SPRING + R                   # -4.0: the opening's top
IMPOST_H = 0.7
IMPOST_OUT = 0.25
WALL_T = 1.2                # the channel's side walls
COURSES = 7                 # spandrel courses, springing to SPAN_TOP
COURSE = (SPAN_TOP - SPRING) / COURSES
PIER_COURSE = 1.6
PIER_DEEP = 60.0            # the pier's foot under the deck
COURSED_TO = -42.0          # coursed stone above this, a plain footing under
STUMP_DEEP = 10.0


def wedge(p, theta, depth, chips):
    """One voussoir, its middle on the ring at angle theta (from +x, up),
    tapered so its joints run to the arch's centre."""
    rm = R + RING / 2
    tang = rm * math.pi / VOUSSOIRS - T.JOINT
    real = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    p.block((0, 0, 0), (RING - 0.02, depth, tang), chips=chips, far=False, chip_depth=(0.1, 0.35))
    p.near = real
    for v in tmp.verts:
        v.co.z *= (rm + v.co.x) / rm
    m = Matrix.Translation((rm * math.cos(theta), 0.0, SPRING + rm * math.sin(theta))) @ Matrix.Rotation(-theta, 4, "Y")
    T._append(real, tmp, m)
    tmp.free()


def run(p, x0, x1, z, h, depth, y=0.0, length=(2.2, 3.6), chips=1, end_chips=None):
    """A course from x0 to x1 (no far box); the block at x1 more broken
    when `end_chips`."""
    r = p.rng
    x = x0
    while x < x1 - 0.3:
        L = min(r.uniform(*length), x1 - x)
        if x1 - (x + L) < 0.9:
            L = x1 - x
        last = x + L >= x1 - 1e-6
        c = end_chips if (last and end_chips is not None) else r.randint(0, chips)
        p.block((x + L / 2, y + r.uniform(-0.04, 0.04), z + h / 2), (L - T.JOINT, depth, h - T.JOINT),
                chips=c, far=False)
        x += L


def ext_half(zt):
    """The extrados' half width at height zt (0 over the crown)."""
    d = zt - SPRING
    return math.sqrt(max(0.0, RE * RE - d * d))


def intra_z(x):
    return SPRING + math.sqrt(max(0.0, R * R - x * x))


def deck(p, x0, x1, broken=False):
    """The cornice and the channel walls over x0..x1."""
    hw = THICK / 2
    run(p, x0, x1, CORNICE_TOP - CORNICE_H, CORNICE_H, THICK + 2 * CORNICE_OUT, end_chips=3 if broken else None)
    for s in (-1, 1):
        x_end = x1
        if broken:
            x_end = x1 - p.rng.uniform(0.3, 1.8)
        run(p, x0, x_end, CORNICE_TOP, -CORNICE_TOP, WALL_T, y=s * (hw - WALL_T / 2), length=(1.8, 3.0),
            end_chips=3 if broken else None)


def arch_slices(x_lo=-R, x_hi=R):
    """[(xa, xb, bottom)]: the opening's soffit as boxes, finer near the
    springing, each box's bottom the soffit's lowest over it."""
    xs = [R * math.cos(math.radians(a)) for a in range(0, 91, 15)]
    out = []
    for k in range(len(xs) - 1):
        a, b = xs[k + 1], xs[k]
        out.append((a, b, intra_z(b)))
        out.append((-b, -a, intra_z(b)))
    return [(max(a, x_lo), min(b, x_hi), z) for a, b, z in out if min(b, x_hi) > max(a, x_lo) + 0.05]


def build_arch(name, seed):
    p = T.Piece(name, seed=seed)
    p.ground = -100.0
    hw = THICK / 2
    for i in range(VOUSSOIRS):
        th = math.pi * (i + 0.5) / VOUSSOIRS
        wedge(p, th, THICK - 0.04, chips=p.rng.randint(0, 2))
    for k in range(COURSES):
        zb = SPRING + k * COURSE
        zt = zb + COURSE
        w = ext_half(zt)
        if w <= 0.05:
            run(p, -R, R, zb, COURSE, THICK)
            continue
        run(p, -R, -w, zb, COURSE, THICK, length=(1.6, 3.2))
        run(p, w, R, zb, COURSE, THICK, length=(1.6, 3.2))
    deck(p, -R, R)
    # The far LOD and the solids: the soffit in steps, the deck band over it.
    for a, b, z in arch_slices():
        p.far_box(((a + b) / 2, 0, (z + SPAN_TOP) / 2), (b - a, THICK, SPAN_TOP - z))
        p.solid((a, -hw, z), (b, hw, 0.0))
    p.far_box((0, 0, (CORNICE_TOP - CORNICE_H) / 2), (2 * R, THICK + 2 * CORNICE_OUT, -(CORNICE_TOP - CORNICE_H)))
    p.export()


def build_arch_broken(seed):
    p = T.Piece("aqueduct_arch_broken", seed=seed)
    p.ground = -100.0
    r = p.rng
    hw = THICK / 2
    keep = 0
    for i in range(VOUSSOIRS):
        th = math.pi * (i + 0.5) / VOUSSOIRS
        if th < math.radians(124):
            continue
        wedge(p, th, THICK - 0.04 - (0.6 if th < math.radians(132) else 0.0), chips=3 if th < math.radians(132) else 1)
        keep += 1
    # The courses end ragged: each its own break, never inside the ring's
    # stub, the lower ones reaching furthest.
    ends = []
    for k in range(COURSES):
        zb = SPRING + k * COURSE
        zt = zb + COURSE
        w = ext_half(zt)
        reach = -3.2 - 0.25 * k + r.uniform(-0.9, 0.6)
        x1 = min(-w, reach) if w > 0.05 else reach
        if x1 > -R + 0.8:
            run(p, -R, x1, zb, COURSE, THICK, length=(1.6, 3.0), end_chips=3)
        ends.append(x1)
    deck(p, -R, -4.6 + r.uniform(-0.4, 0.4), broken=True)
    x_end = max(max(ends), -3.2)
    for a, b, z in arch_slices(-R, x_end):
        p.far_box(((a + b) / 2, 0, (z + SPAN_TOP) / 2), (b - a, THICK, SPAN_TOP - z))
        p.solid((a, -hw, z), (b, hw, 0.0))
    p.far_box(((-R - 4.6) / 2, 0, (CORNICE_TOP - CORNICE_H) / 2), (R - 4.6, THICK, -(CORNICE_TOP - CORNICE_H)))
    p.export()


def pier_courses(p, z0, z1, top_ragged=False):
    """Coursed pier from z0 to z1, two blocks a course, the split turning
    each course so the joints bond."""
    n = max(1, round((z1 - z0) / PIER_COURSE))
    h = (z1 - z0) / n
    hx, hy = PIER_W / 2, THICK / 2
    r = p.rng
    for k in range(n):
        zb = z0 + k * h
        zc = zb + h / 2
        top = top_ragged and k >= n - 3
        cut = r.uniform(-0.4, 0.4)
        if k % 2 == 0:
            blocks = [(((-hx + cut) / 2, 0.0, zc), (hx + cut - T.JOINT, THICK - T.JOINT, h - T.JOINT)),
                      (((hx + cut) / 2, 0.0, zc), (hx - cut - T.JOINT, THICK - T.JOINT, h - T.JOINT))]
        else:
            blocks = [((0.0, (-hy + cut) / 2, zc), (PIER_W - T.JOINT, hy + cut - T.JOINT, h - T.JOINT)),
                      ((0.0, (hy + cut) / 2, zc), (PIER_W - T.JOINT, hy - cut - T.JOINT, h - T.JOINT))]
        if top:
            # The last courses: one block gone, then both, the stub's top stepped.
            lost = n - 1 - k
            if lost == 0:
                blocks = blocks[:1]
            elif lost == 1 and r.random() < 0.5:
                blocks = blocks[1:]
        for c, s in blocks:
            c =(c[0] + r.uniform(-0.03, 0.03), c[1], c[2])
            p.block(c, s, chips=(3 if top else r.randint(0, 2)), far=False)


def build_pier(seed):
    p = T.Piece("aqueduct_pier", seed=seed)
    p.ground = -100.0
    hx, hy = PIER_W / 2, THICK / 2
    # The footing, always under the ground: one plain block.
    p.block((0, 0, (-PIER_DEEP + COURSED_TO) / 2), (PIER_W, THICK, COURSED_TO + PIER_DEEP), bevel=0.0, chips=0,
            far=False, jitter=0.0)
    pier_courses(p, COURSED_TO, SPRING - IMPOST_H)
    # The impost band: the arches spring from its top.
    p.block((0, 0, SPRING - IMPOST_H / 2), (PIER_W + 2 * IMPOST_OUT, THICK + 2 * IMPOST_OUT, IMPOST_H), chips=2, far=False)
    # Over the impost, the pier's part of the spandrel on the arches' courses.
    for k in range(COURSES):
        zb = SPRING + k * COURSE
        p.block((p.rng.uniform(-0.03, 0.03), 0, zb + COURSE / 2), (PIER_W - T.JOINT, THICK - T.JOINT, COURSE - T.JOINT),
                chips=p.rng.randint(0, 1), far=False)
    deck(p, -hx, hx)
    p.far_box((0, 0, (-PIER_DEEP + SPAN_TOP) / 2), (PIER_W, THICK, SPAN_TOP + PIER_DEEP))
    p.far_box((0, 0, SPRING - IMPOST_H / 2), (PIER_W + 2 * IMPOST_OUT, THICK + 2 * IMPOST_OUT, IMPOST_H))
    p.far_box((0, 0, (CORNICE_TOP - CORNICE_H) / 2), (PIER_W, THICK + 2 * CORNICE_OUT, -(CORNICE_TOP - CORNICE_H)))
    p.solid((-hx, -hy, -PIER_DEEP), (hx, hy, 0.0))
    p.solid((-hx - IMPOST_OUT, -hy - IMPOST_OUT, SPRING - IMPOST_H), (hx + IMPOST_OUT, hy + IMPOST_OUT, SPRING))
    p.export()


def build_pier_broken(seed):
    p = T.Piece("aqueduct_pier_broken", seed=seed)
    p.ground = 0.0
    hx, hy = PIER_W / 2, THICK / 2
    top = 17.6
    pier_courses(p, -STUMP_DEEP, top, top_ragged=True)
    p.far_box((0, 0, (top - STUMP_DEEP) / 2), (PIER_W, THICK, top + STUMP_DEEP))
    p.solid((-hx, -hy, -STUMP_DEEP), (hx, hy, top))
    p.export()


def build_rubble(seed):
    """Fallen stone: voussoirs and course blocks of the arch, lying askew and
    sunk into the ground, a heap under where the span was."""
    p = T.Piece("aqueduct_rubble", seed=seed)
    p.ground = 0.0
    r = p.rng
    rm = R + RING / 2
    tang = rm * math.pi / VOUSSOIRS
    stones = []
    for _ in range(16):
        stones.append((RING, THICK * r.uniform(0.45, 1.0), tang))           # voussoirs, some broken short
    for _ in range(14):
        stones.append((r.uniform(1.8, 3.2), THICK * r.uniform(0.5, 1.0), COURSE))   # spandrel blocks
    for _ in range(6):
        stones.append((r.uniform(1.8, 2.8), WALL_T, -CORNICE_TOP))            # channel wall blocks
    for _ in range(16):
        stones.append((r.uniform(0.5, 1.2), r.uniform(0.5, 1.2), r.uniform(0.4, 0.9)))  # chunks
    for i, (sx, sy, sz) in enumerate(stones):
        big = i < 36
        # Heaped toward the middle, spread along the line more than across.
        x = r.gauss(0.0, 4.2)
        y = r.gauss(0.0, 3.0 if big else 4.2)
        x = max(-9.0, min(9.0, x))
        y = max(-7.5, min(7.5, y))
        yaw = r.uniform(0, math.tau)
        tilt = (r.uniform(-0.45, 0.45), r.uniform(-0.45, 0.45))
        # Lying on a side: its least size is the height; sunk a third.
        lo = min(sx, sy, sz)
        if lo == sx:
            sx, sz = sz, sx
        elif lo == sy:
            sy, sz = sz, sy
        z = sz * r.uniform(0.1, 0.35)
        if big and abs(x) < 3.0 and abs(y) < 2.0:
            z += r.uniform(0.3, 1.0)   # one on another in the middle
        p.block((x, y, z), (sx, sy, sz), yaw=yaw, tilt=tilt, chips=r.randint(2, 4), far=big,
                chip_depth=(0.15, 0.5))
        if big:
            ext = max(sx, sy) / 2
            p.solid((x - ext * 0.8, y - ext * 0.8, -1.0), (x + ext * 0.8, y + ext * 0.8, z + sz / 2))
    p.export()


JOBS = {
    "aqueduct_pier": lambda: build_pier(21),
    "aqueduct_arch": lambda: build_arch("aqueduct_arch", 22),
    "aqueduct_arch_b": lambda: build_arch("aqueduct_arch_b", 37),
    "aqueduct_arch_broken": lambda: build_arch_broken(23),
    "aqueduct_pier_broken": lambda: build_pier_broken(24),
    "aqueduct_rubble": lambda: build_rubble(25),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
