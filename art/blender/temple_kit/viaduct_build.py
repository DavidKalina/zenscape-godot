"""The viaduct on the north-west plain (scripts/endless/viaduct_site.gd): two
tiers of arches on one bay, in the kit's stone (temple_lib), as the aqueduct
(aqueduct_build.py) but bigger.

    python tools/blender.py run art/blender/temple_kit/viaduct_build.py [-- --only=viaduct_pier]

Pieces (each with a mid LOD, <piece>_mid.glb: the same stones, plain):
- `viaduct_pier`: a lower pier, W1 along the line by T1 across, its impost
  at the lower arches' springing, its part of the spandrel and the lower
  cornice over it. Origin on the lower deck (the cornice's top, the upper
  tier's floor); it hangs PIER_DEEP down, so it reaches the ground however
  low the land falls.
- `viaduct_arch`, `viaduct_arch_b`: a lower span: ring, spandrel courses,
  cornice. Clear OPEN1 (45.2 m) wide, its crown 3.8 m under the lower deck.
- `viaduct_arch_broken`: a lower span snapped: the ring and courses stand
  out from the -x pier and end ragged.
- `viaduct_top_pier`: an upper pier, W2 by T2, standing on the lower deck
  (TIER2 under its origin) to the channel's walls. Origin on the top deck.
- `viaduct_top_arch`, `viaduct_top_arch_b`, `viaduct_top_arch_broken`: the
  upper spans, two over each lower span (every BAY2), clear OPEN2 (23.6 m)
  wide from the lower deck to 4 m under the top. Origin on the top deck.
- `viaduct_pier_stump`: a lower pier's stump on the ground, STUMP_TOP tall,
  ragged, STUMP_DEEP into the ground. Origin on the ground.
- `viaduct_top_stump`: an upper pier broken off TOP_STUMP over the lower
  deck. Origin on the lower deck.

Frame (Blender, z up): the line runs along x, the faces look along +-y.
Lower piers at x = k*BAY, spans at (k+0.5)*BAY; upper piers every BAY2.
"""

import math
import sys

import bmesh
from mathutils import Matrix

import temple_lib as T

# The far and mid LODs painted to the near's mean light (no flash at a swap).
T.MATCH_LOD_LIGHT = True

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

# Wide enough to weave arch by arch at cruise (the plane turns back in about
# 30 to 53 m of line at full to 80% stick): one lower span every BAY, two upper
# spans over each.
BAY = 57.2
# The lower tier.
W1 = 12.0
T1 = 8.0
OPEN1 = BAY - W1            # 45.2
R1 = OPEN1 / 2
RING1 = 2.6
CORN1_H = 1.2
CORN1_OUT = 0.35
SPAN1_TOP = -CORN1_H        # the spandrel's top, the ring's crown
SPRING1 = SPAN1_TOP - (R1 + RING1)   # -26.4
IMPOST_H = 1.0
IMPOST_OUT = 0.35
COURSES1 = 12
PIER_DEEP = 82.0
COURSED_TO = -54.0
PIER_COURSE = 1.8
# The upper tier, its origin on the top deck; the lower deck TIER2 under it.
BAY2 = BAY / 2
TIER2 = 24.0
W2 = 5.0
T2 = 6.0
OPEN2 = BAY2 - W2           # 23.6
R2 = OPEN2 / 2
RING2 = 1.4
CORNICE_TOP = -1.8          # the channel's floor
CORNICE_H = 0.8
CORNICE_OUT = 0.25
SPAN2_TOP = CORNICE_TOP - CORNICE_H     # -2.6
SPRING2 = SPAN2_TOP - (R2 + RING2)      # -15.7
WALL_T = 1.1
COURSES2 = 7
STUMP_TOP = 19.0
STUMP_DEEP = 10.0
TOP_STUMP = 8.5
VOUSSOIRS = 19
VOUSSOIRS1 = 33


class Lay:
    """Blocks for one piece at one LOD: the near's cut and chipped, the mid's
    plain. Layout draws come from `r`, so both LODs lay the same stones."""

    def __init__(self, name, seed, mid):
        self.p = T.Piece(name, seed=seed)
        self.p.ground = -100.0
        self.r = T.random.Random(seed * 31 + 7)
        self.mid = mid

    def block(self, c, s, chips=1, **kw):
        if self.mid:
            self.p.block(c, s, bevel=0.0, chips=0, jitter=0.0, far=False,
                         **{k: v for k, v in kw.items() if k in ("yaw", "tilt", "tone", "hide")})
            return
        self.p.block(c, s, chips=chips, far=False, **kw)

    def run(self, x0, x1, z, h, depth, y=0.0, length=(2.2, 3.6), chips=1, end_chips=None, hide=()):
        """A course from x0 to x1; the block at x1 more broken when `end_chips`."""
        x = x0
        while x < x1 - 0.3:
            L = min(self.r.uniform(*length), x1 - x)
            if x1 - (x + L) < 0.9:
                L = x1 - x
            last = x + L >= x1 - 1e-6
            c = end_chips if (last and end_chips is not None) else self.r.randint(0, chips)
            self.block((x + L / 2, y + self.r.uniform(-0.04, 0.04), z + h / 2), (L - T.JOINT, depth, h - T.JOINT),
                       chips=c, hide=hide)
            x += L

    def wedge(self, R, ring, spring, theta, depth, chips, n=VOUSSOIRS):
        """One voussoir, its middle on the ring at angle theta (from +x, up),
        tapered so its joints run to the arch's centre; `n` to the half circle."""
        rm = R + ring / 2
        tang = rm * math.pi / n - T.JOINT
        p = self.p
        real = p.near
        tmp = bmesh.new()
        T._layers(tmp)
        p.near = tmp
        self.block((0, 0, 0), (ring - 0.02, depth, tang), chips=chips, chip_depth=(0.1, 0.35))
        p.near = real
        for v in tmp.verts:
            v.co.z *= (rm + v.co.x) / rm
        m = Matrix.Translation((rm * math.cos(theta), 0.0, spring + rm * math.sin(theta))) @ Matrix.Rotation(-theta, 4, "Y")
        T._append(real, tmp, m)
        tmp.free()

    def export(self, name):
        if self.mid:
            self.p.export(mid_of=name)
        else:
            self.p.export()


def both(name, seed, fn):
    for mid in (False, True):
        lay = Lay(name, seed, mid)
        fn(lay)
        lay.export(name)


def ext_half(R, ring, spring, zt):
    d = zt - spring
    re = R + ring
    return math.sqrt(max(0.0, re * re - d * d))


def soffit(R, spring, x_lo=None, x_hi=None, step=15.0):
    """[(xa, xb, bottom)]: the opening's soffit as boxes, a box every `step` degrees of the ring."""
    x_lo = -R if x_lo is None else x_lo
    x_hi = R if x_hi is None else x_hi
    n = int(round(90.0 / step))
    xs = [R * math.cos(math.radians(90.0 * i / n)) for i in range(n + 1)]
    out = []
    for k in range(len(xs) - 1):
        a, b = xs[k + 1], xs[k]
        # The bottom at the mean of the step's two edges: within a few dm of the drawn soffit either way.
        z = spring + 0.5 * (math.sqrt(max(0.0, R * R - a * a)) + math.sqrt(max(0.0, R * R - b * b)))
        out.append((a, b, z))
        out.append((-b, -a, z))
    return [(max(a, x_lo), min(b, x_hi), z) for a, b, z in out if min(b, x_hi) > max(a, x_lo) + 0.05]


# ---- the lower tier -------------------------------------------------------------
def lower_cornice(L, x0, x1, broken=False):
    L.run(x0, x1, -CORN1_H, CORN1_H, T1 + 2 * CORN1_OUT, length=(2.4, 3.8), end_chips=3 if broken else None,
          hide=("-z",))


def lower_span(L, keep_from=None):
    """The ring and courses; `keep_from` None for whole, else the broken
    stub's reach (x) from the -x pier."""
    r = L.r
    hw = T1 / 2
    course = (SPAN1_TOP - SPRING1) / COURSES1
    for i in range(VOUSSOIRS1):
        th = math.pi * (i + 0.5) / VOUSSOIRS1
        if keep_from is not None and th < math.radians(116):
            continue
        ragged = keep_from is not None and th < math.radians(125)
        L.wedge(R1, RING1, SPRING1, th, T1 - 0.04 - (0.8 if ragged else 0.0), chips=3 if ragged else r.randint(0, 2),
                n=VOUSSOIRS1)
    ends = []
    for k in range(COURSES1):
        zb = SPRING1 + k * course
        w = ext_half(R1, RING1, SPRING1, zb + course)
        if keep_from is None:
            if w <= 0.05:
                L.run(-R1, R1, zb, course, T1, length=(1.8, 3.4), hide=("-z", "+z"))
            else:
                L.run(-R1, -w, zb, course, T1, length=(1.8, 3.4), hide=("-z", "+z"))
                L.run(w, R1, zb, course, T1, length=(1.8, 3.4), hide=("-z", "+z"))
            continue
        reach = keep_from - 0.45 * k + r.uniform(-1.4, 1.0)
        x1 = min(-w, reach) if w > 0.05 else reach
        if x1 > -R1 + 0.8:
            L.run(-R1, x1, zb, course, T1, length=(1.6, 3.0), end_chips=3)
        ends.append(x1)
    if keep_from is None:
        lower_cornice(L, -R1, R1)
        for a, b, z in soffit(R1, SPRING1, step=5.0):
            L.p.far_box(((a + b) / 2, 0, (z + SPAN1_TOP) / 2), (b - a, T1, SPAN1_TOP - z))
            L.p.solid((a, -hw, z), (b, hw, 0.0))
        L.p.far_box((0, 0, -CORN1_H / 2), (2 * R1, T1 + 2 * CORN1_OUT, CORN1_H))
        return
    # The cornice breaks off about where the top courses do, not out over the void.
    top = keep_from - 0.45 * (COURSES1 - 1) + r.uniform(-0.6, 0.8)
    lower_cornice(L, -R1, top, broken=True)
    x_end = max(max(ends), keep_from)
    for a, b, z in soffit(R1, SPRING1, -R1, x_end, step=5.0):
        L.p.far_box(((a + b) / 2, 0, (z + SPAN1_TOP) / 2), (b - a, T1, SPAN1_TOP - z))
        L.p.solid((a, -hw, z), (b, hw, 0.0))
    L.p.far_box(((-R1 + top) / 2, 0, -CORN1_H / 2), (top + R1, T1, CORN1_H))


def pier_courses(L, z0, z1, wx, wy, top_ragged=False):
    """Coursed pier from z0 to z1, two blocks a course, the split turning
    each course so the joints bond."""
    n = max(1, round((z1 - z0) / PIER_COURSE))
    h = (z1 - z0) / n
    hx, hy = wx / 2, wy / 2
    r = L.r
    for k in range(n):
        zb = z0 + k * h
        zc = zb + h / 2
        top = top_ragged and k >= n - 3
        cut = r.uniform(-0.5, 0.5)
        if k % 2 == 0:
            blocks = [(((-hx + cut) / 2, 0.0, zc), (hx + cut - T.JOINT, wy - T.JOINT, h - T.JOINT)),
                      (((hx + cut) / 2, 0.0, zc), (hx - cut - T.JOINT, wy - T.JOINT, h - T.JOINT))]
        else:
            blocks = [((0.0, (-hy + cut) / 2, zc), (wx - T.JOINT, hy + cut - T.JOINT, h - T.JOINT)),
                      ((0.0, (hy + cut) / 2, zc), (wx - T.JOINT, hy - cut - T.JOINT, h - T.JOINT))]
        if top:
            lost = n - 1 - k
            if lost == 0:
                blocks = blocks[:1]
            elif lost == 1 and r.random() < 0.5:
                blocks = blocks[1:]
        for c, s in blocks:
            c = (c[0] + r.uniform(-0.03, 0.03), c[1], c[2])
            L.block(c, s, chips=(3 if top else r.randint(0, 2)), hide=() if top else ("-z", "+z"))


def build_pier(L):
    hx, hy = W1 / 2, T1 / 2
    L.p.block((0, 0, (-PIER_DEEP + COURSED_TO) / 2), (W1, T1, COURSED_TO + PIER_DEEP), bevel=0.0, chips=0,
              far=False, jitter=0.0)
    pier_courses(L, COURSED_TO, SPRING1 - IMPOST_H, W1, T1)
    L.block((0, 0, SPRING1 - IMPOST_H / 2), (W1 + 2 * IMPOST_OUT, T1 + 2 * IMPOST_OUT, IMPOST_H), chips=2)
    course = (SPAN1_TOP - SPRING1) / COURSES1
    for k in range(COURSES1):
        zb = SPRING1 + k * course
        L.block((L.r.uniform(-0.03, 0.03), 0, zb + course / 2), (W1 - T.JOINT, T1 - T.JOINT, course - T.JOINT),
                chips=L.r.randint(0, 1), hide=("-z", "+z"))
    lower_cornice(L, -hx, hx)
    L.p.far_box((0, 0, (-PIER_DEEP + SPAN1_TOP) / 2), (W1, T1, SPAN1_TOP + PIER_DEEP))
    L.p.far_box((0, 0, SPRING1 - IMPOST_H / 2), (W1 + 2 * IMPOST_OUT, T1 + 2 * IMPOST_OUT, IMPOST_H))
    L.p.far_box((0, 0, -CORN1_H / 2), (W1, T1 + 2 * CORN1_OUT, CORN1_H))
    L.p.solid((-hx, -hy, -PIER_DEEP), (hx, hy, 0.0))
    L.p.solid((-hx - IMPOST_OUT, -hy - IMPOST_OUT, SPRING1 - IMPOST_H), (hx + IMPOST_OUT, hy + IMPOST_OUT, SPRING1))


def build_pier_stump(L):
    L.p.ground = 0.0
    hx, hy = W1 / 2, T1 / 2
    pier_courses(L, -STUMP_DEEP, STUMP_TOP, W1, T1, top_ragged=True)
    L.p.far_box((0, 0, (STUMP_TOP - STUMP_DEEP) / 2), (W1, T1, STUMP_TOP + STUMP_DEEP))
    L.p.solid((-hx, -hy, -STUMP_DEEP), (hx, hy, STUMP_TOP))


# ---- the upper tier -------------------------------------------------------------
def channel(L, x0, x1, broken=False):
    """The cornice and the channel walls over x0..x1."""
    hw = T2 / 2
    L.run(x0, x1, CORNICE_TOP - CORNICE_H, CORNICE_H, T2 + 2 * CORNICE_OUT, end_chips=3 if broken else None)
    for s in (-1, 1):
        x_end = x1 - (L.r.uniform(0.3, 1.8) if broken else 0.0)
        L.run(x0, x_end, CORNICE_TOP, -CORNICE_TOP, WALL_T, y=s * (hw - WALL_T / 2), length=(1.8, 3.0),
              end_chips=3 if broken else None)


def upper_span(L, keep_from=None):
    r = L.r
    hw = T2 / 2
    course = (SPAN2_TOP - SPRING2) / COURSES2
    for i in range(VOUSSOIRS):
        th = math.pi * (i + 0.5) / VOUSSOIRS
        if keep_from is not None and th < math.radians(126):
            continue
        ragged = keep_from is not None and th < math.radians(136)
        L.wedge(R2, RING2, SPRING2, th, T2 - 0.04 - (0.6 if ragged else 0.0), chips=3 if ragged else r.randint(0, 2))
    ends = []
    for k in range(COURSES2):
        zb = SPRING2 + k * course
        w = ext_half(R2, RING2, SPRING2, zb + course)
        if keep_from is None:
            if w <= 0.05:
                L.run(-R2, R2, zb, course, T2, length=(1.6, 3.2), hide=("-z", "+z"))
            else:
                L.run(-R2, -w, zb, course, T2, length=(1.6, 3.2), hide=("-z", "+z"))
                L.run(w, R2, zb, course, T2, length=(1.6, 3.2), hide=("-z", "+z"))
            continue
        reach = keep_from - 0.25 * k + r.uniform(-0.9, 0.6)
        x1 = min(-w, reach) if w > 0.05 else reach
        if x1 > -R2 + 0.8:
            L.run(-R2, x1, zb, course, T2, length=(1.6, 3.0), end_chips=3)
        ends.append(x1)
    if keep_from is None:
        channel(L, -R2, R2)
        for a, b, z in soffit(R2, SPRING2, step=7.5):
            L.p.far_box(((a + b) / 2, 0, (z + SPAN2_TOP) / 2), (b - a, T2, SPAN2_TOP - z))
            L.p.solid((a, -hw, z), (b, hw, 0.0))
        L.p.far_box((0, 0, (CORNICE_TOP - CORNICE_H) / 2), (2 * R2, T2 + 2 * CORNICE_OUT, -(CORNICE_TOP - CORNICE_H)))
        return
    top = keep_from - 1.3 + r.uniform(-0.4, 0.4)
    channel(L, -R2, top, broken=True)
    x_end = max(max(ends), keep_from)
    for a, b, z in soffit(R2, SPRING2, -R2, x_end, step=7.5):
        L.p.far_box(((a + b) / 2, 0, (z + SPAN2_TOP) / 2), (b - a, T2, SPAN2_TOP - z))
        L.p.solid((a, -hw, z), (b, hw, 0.0))
    L.p.far_box(((-R2 + top) / 2, 0, (CORNICE_TOP - CORNICE_H) / 2), (top + R2, T2, -(CORNICE_TOP - CORNICE_H)))


def build_top_pier(L):
    hx, hy = W2 / 2, T2 / 2
    # A plinth course on the lower deck, then the shaft to the impost.
    L.block((0, 0, -TIER2 + 0.4), (W2 + 0.6, T2 + 0.6, 0.8 - T.JOINT), chips=2, hide=("-z",))
    pier_courses(L, -TIER2 + 0.8, SPRING2 - IMPOST_H, W2, T2)
    L.block((0, 0, SPRING2 - IMPOST_H / 2), (W2 + 2 * IMPOST_OUT, T2 + 2 * IMPOST_OUT, IMPOST_H), chips=2)
    course = (SPAN2_TOP - SPRING2) / COURSES2
    for k in range(COURSES2):
        zb = SPRING2 + k * course
        L.block((L.r.uniform(-0.03, 0.03), 0, zb + course / 2), (W2 - T.JOINT, T2 - T.JOINT, course - T.JOINT),
                chips=L.r.randint(0, 1), hide=("-z", "+z"))
    channel(L, -hx, hx)
    L.p.far_box((0, 0, (-TIER2 + SPAN2_TOP) / 2), (W2, T2, SPAN2_TOP + TIER2))
    L.p.far_box((0, 0, SPRING2 - IMPOST_H / 2), (W2 + 2 * IMPOST_OUT, T2 + 2 * IMPOST_OUT, IMPOST_H))
    L.p.far_box((0, 0, (CORNICE_TOP - CORNICE_H) / 2), (W2, T2 + 2 * CORNICE_OUT, -(CORNICE_TOP - CORNICE_H)))
    L.p.solid((-hx, -hy, -TIER2), (hx, hy, 0.0))
    L.p.solid((-hx - IMPOST_OUT, -hy - IMPOST_OUT, SPRING2 - IMPOST_H), (hx + IMPOST_OUT, hy + IMPOST_OUT, SPRING2))


def build_top_stump(L):
    hx, hy = W2 / 2, T2 / 2
    L.block((0, 0, 0.4), (W2 + 0.6, T2 + 0.6, 0.8 - T.JOINT), chips=2, hide=("-z",))
    pier_courses(L, 0.8, TOP_STUMP, W2, T2, top_ragged=True)
    L.p.far_box((0, 0, TOP_STUMP / 2), (W2, T2, TOP_STUMP))
    L.p.solid((-hx, -hy, 0.0), (hx, hy, TOP_STUMP))


JOBS = {
    "viaduct_pier": (41, build_pier),
    "viaduct_arch": (42, lambda L: lower_span(L)),
    "viaduct_arch_b": (57, lambda L: lower_span(L)),
    "viaduct_arch_broken": (43, lambda L: lower_span(L, keep_from=-6.0)),
    "viaduct_pier_stump": (44, build_pier_stump),
    "viaduct_top_pier": (45, build_top_pier),
    "viaduct_top_arch": (46, lambda L: upper_span(L)),
    "viaduct_top_arch_b": (58, lambda L: upper_span(L)),
    # The stub reaches only to -7.2 so a line at the top deck's height has room either side of the gap.
    "viaduct_top_arch_broken": (47, lambda L: upper_span(L, keep_from=-7.2)),
    "viaduct_top_stump": (48, build_top_stump),
}

for name, (seed, fn) in JOBS.items():
    if only is None or only == name:
        both(name, seed, fn)
