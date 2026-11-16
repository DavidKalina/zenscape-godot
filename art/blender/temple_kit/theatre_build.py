"""The temple kit's theatre (lane theatre): a half bowl of stepped seating, its
rim terrace, the stage wall's bays and the side arches, in the kit's stone
(temple_lib). The rim's columns and lintels, the fallen drums and the rubble
are the kit's own pieces; scripts/endless/theatre_site.gd lays them all.

    python tools/blender.py run art/blender/temple_kit/theatre_build.py [-- --only=theatre_rim]

Pieces (Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y)):
- `theatre_seat_0`..`_4`: one SECTOR (15 degrees) of one ring of the bowl,
  origin at the bowl's centre on the orchestra's floor, the sector's middle
  along +x. Rings 0-2 are the lower tier (rows TREAD deep, LOW_RISE high, the
  first on a PODIUM), ring 3 the walk between the tiers, its back wall and
  the upper tier's first rows (UP_RISE high), ring 4 the rest of them. Each
  row is a course of seat blocks on a core of plain masonry that goes down
  to BASE under the floor, so a piece stands on any ground between; a stair
  of half steps runs up its +angle edge.
- `theatre_seat_broken_0`..`_4`: the same with seat blocks lost, the core
  bare where they were, a few lying on the row below.
- `theatre_rim`: a sector of the terrace round the top, RIM wide, flagged.
- `theatre_stage_mid`, `theatre_stage_door`, `theatre_stage_wall`,
  `theatre_stage_end`, `theatre_stage_fallen`: bays of the stage wall. The
  wall runs along x, WT thick, origin on the floor at the bay's middle; +y
  faces the seats. mid: MID_W wide, an arched doorway 2*MID_R wide and
  MID_SPRING+MID_R to its crown. door: DOOR_W wide, 2*DOOR_R by
  DOOR_SPRING+DOOR_R, a window over it. wall: WALL_W of solid wall under a
  window whose lintel is gone. end: END_W, its top stepping down toward +x.
  fallen: FALLEN_W of the wall down to a stump (tall at +x, where it meets a
  standing bay), its blocks lying both sides.
- `theatre_side_arch`: the arch across the passage between the stage wall
  and the seats' end: it runs along +y from the wall's face (y 0) for ARCH_L,
  WT thick about x 0, its opening 2*ARCH_R wide and ARCH_SPRING+ARCH_R high.
"""

import math
import sys

import bmesh
from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

# The bowl (scripts/endless/theatre_site.gd lays to the same numbers).
SECTOR = math.radians(15.0)
HALF_A = SECTOR / 2
R0 = 18.0                   # the orchestra's radius
TREAD = 2.8
LOW_RISE = 1.2
UP_RISE = 1.6
PODIUM = 1.5                # the first row's top over the floor
WALK = 3.6                  # the walk between the tiers
WALK_WALL = 2.4             # the wall behind it: the upper tier's first riser
RINGS = [(18.0, 26.4), (26.4, 34.8), (34.8, 43.2), (43.2, 55.2), (55.2, 63.6)]
RIM = (63.6, 75.0)
RIM_TOP = 21.5
BASE = -3.0                 # the core's foot under the floor
AISLE = 2.0                 # the stair's width

# The stage wall.
WT = 5.0
CH = 2.4                    # a course
FOOT = -2                   # courses under the floor
MID_W, MID_R, MID_SPRING = 22.0, 8.0, 14.4
DOOR_W, DOOR_R, DOOR_SPRING = 16.0, 6.25, 12.0
WALL_W = 10.0
END_W = 11.0
FALLEN_W = 26.0
ARCH_L, ARCH_R, ARCH_SPRING = 26.0, 9.0, 9.6
VOUSSOIR = 2.0
WIN_Z0, WIN_Z1 = 24.0, 31.2


# ---- the seating ------------------------------------------------------------
def rows_of(ring):
    """[(ra, rb, top, thick)]: the ring's rows, inner to outer: radii, the
    seat's top over the floor and the seat block's height."""
    out = []
    if ring < 3:
        for j in range(ring * 3, ring * 3 + 3):
            out.append((R0 + TREAD * j, R0 + TREAD * (j + 1), PODIUM + LOW_RISE * j, PODIUM if j == 0 else LOW_RISE))
        return out
    walk_z = PODIUM + LOW_RISE * 8
    up0 = RINGS[3][0] + WALK
    if ring == 3:
        out.append((RINGS[3][0], up0, walk_z, 0.7))
    for j in (range(0, 3) if ring == 3 else range(3, 6)):
        out.append((up0 + TREAD * j, up0 + TREAD * (j + 1), walk_z + WALK_WALL + UP_RISE * j, WALK_WALL if j == 0 else UP_RISE))
    return out


def arc(p, ra, rb, z0, z1, a0, a1, n, each):
    """n blocks side by side round the arc a0..a1 between radii ra and rb,
    z0..z1; `each(i, centre, size, yaw)` lays one (or not)."""
    rm = (ra + rb) / 2
    da = (a1 - a0) / n
    for i in range(n):
        a = a0 + (i + 0.5) * da
        each(i, (rm * math.cos(a), rm * math.sin(a), (z0 + z1) / 2), (rb - ra, rm * da, z1 - z0), a)


def core(p, ra, rb, z0, z1, radial=1, course=2.0):
    """Plain masonry between radii and heights: courses of big blocks, each
    set back a little at random so the joints read."""
    r = p.rng
    if z1 - z0 < 0.2:
        return
    nz = max(1, round((z1 - z0) / course))
    hz = (z1 - z0) / nz
    for k in range(nz):
        for q in range(radial):
            qa = ra + (rb - ra) * q / radial
            qb = ra + (rb - ra) * (q + 1) / radial
            n = max(1, round((qa + qb) / 2 * SECTOR / 3.6))
            if k % 2 and n > 1:
                n -= 1

            def lay(i, c, s, yaw):
                p.block(c, (s[0] - r.uniform(0.0, 0.14), s[1] - r.uniform(0.02, 0.16), s[2] - 0.02), yaw=yaw, bevel=0.0,
                        chips=1 if r.random() < 0.25 else 0, chip_depth=(0.2, 0.6), jitter=0.02, far=False, hide=("-z",))
            arc(p, qa, qb, z0 + k * hz, z0 + (k + 1) * hz, -HALF_A, HALF_A, n, lay)


def build_seat(ring, seed, broken=False):
    name = ("theatre_seat_broken_%d" if broken else "theatre_seat_%d") % ring
    p = T.Piece(name, seed=seed)
    p.ground = -100.0
    r = p.rng
    rows = rows_of(ring)
    ra_ring, rb_ring = RINGS[ring]
    zb = rows[0][2] - rows[0][3]
    core(p, ra_ring, rb_ring, BASE, zb, radial=2 if ring != 3 else 3)
    for j, (ra, rb, top, th) in enumerate(rows):
        rm = (ra + rb) / 2
        under = top - th
        if j > 0:
            core(p, ra, rb, zb, under)
        a_aisle = HALF_A - AISLE / rm
        walk = ring == 3 and j == 0
        n = max(1, round(rm * (a_aisle + HALF_A) / (3.0 if walk else 3.8)))
        lost_at = {}

        def lay(i, c, s, yaw):
            lost = False
            if broken:
                nz = noise.noise(Vector((yaw * rm * 0.11 + seed, j * 0.9 + 0.3 * ring, 1.3)))
                lost = nz > -0.12 or r.random() < 0.15
            if lost:
                lost_at[i] = True
                # A shard of the bed left, and sometimes the block itself on the row below.
                if r.random() < 0.5:
                    p.block((c[0] + r.uniform(-0.5, 0.5), c[1] + r.uniform(-0.6, 0.6), under + 0.12),
                            (s[0] * r.uniform(0.3, 0.6), s[1] * r.uniform(0.3, 0.6), 0.5), yaw=yaw + r.uniform(-0.5, 0.5),
                            tilt=(r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2)), chips=3, chip_depth=(0.15, 0.4), far=False)
                if j > 0 and not walk and r.random() < 0.45:
                    lo_top = rows[j - 1][2]
                    d = rm - TREAD + r.uniform(-0.3, 0.5)
                    a = yaw + r.uniform(-0.03, 0.03)
                    p.block((d * math.cos(a), d * math.sin(a), lo_top + th * 0.4), (s[0] * 0.9, s[1] * r.uniform(0.55, 0.95), th),
                            yaw=a + r.uniform(-0.6, 0.6), tilt=(r.uniform(-0.3, 0.3), r.uniform(0.15, 0.5)), chips=4,
                            chip_depth=(0.2, 0.6), far=False)
                return
            worn = broken and r.random() < 0.5
            p.block((c[0], c[1], c[2] - (r.uniform(0.0, 0.12) if worn else 0.0)),
                    (s[0] - T.JOINT, s[1] - T.JOINT * 2, s[2] - T.JOINT), yaw=yaw,
                    tilt=(r.uniform(-0.03, 0.03), r.uniform(-0.03, 0.03)) if worn else (0.0, 0.0),
                    chips=r.randint(2, 4) if worn else r.randint(0, 2), chip_depth=(0.15, 0.5), far=False, hide=("-z",))
        arc(p, ra, rb, under, top, -HALF_A, a_aisle, n, lay)
        # The stair: where a riser is high, a half step in the front of the tread.
        if walk or th < 1.0:
            arc(p, ra, rb, under, top, a_aisle, HALF_A, 1, lambda i, c, s, yaw: p.block(
                c, (s[0] - T.JOINT, s[1] - T.JOINT, s[2] - T.JOINT), yaw=yaw, chips=1, far=False, hide=("-z",)))
        else:
            mid = ra + TREAD * 0.5
            arc(p, ra, mid, under - 0.3, top - th / 2, a_aisle, HALF_A, 1, lambda i, c, s, yaw: p.block(
                c, (s[0] - T.JOINT, s[1] - T.JOINT, s[2]), yaw=yaw, chips=r.randint(0, 2), far=False, hide=("-z",)))
            arc(p, mid, rb, under, top, a_aisle, HALF_A, 1, lambda i, c, s, yaw: p.block(
                c, (s[0] - T.JOINT, s[1] - T.JOINT, s[2] - T.JOINT), yaw=yaw, chips=r.randint(0, 2), far=False, hide=("-z",)))
        w = rm * math.tan(HALF_A)
        ztop = top - (0.5 * th if broken else 0.0)
        p.far_box((rm, 0, (BASE + ztop) / 2), (rb - ra, 2 * w, ztop - BASE), tone=0.97)
        p.solid((ra, -w, BASE), (rb, w, ztop))
    p.export()


def build_rim(seed):
    p = T.Piece("theatre_rim", seed=seed)
    p.ground = -100.0
    r = p.rng
    ra, rb = RIM
    slab = 0.7
    core(p, ra, rb, BASE, RIM_TOP - slab, radial=2)
    bands = 3
    for q in range(bands):
        qa = ra + (rb - ra) * q / bands
        qb = ra + (rb - ra) * (q + 1) / bands
        n = max(1, round((qa + qb) / 2 * SECTOR / 3.4))

        def lay(i, c, s, yaw):
            nz = noise.noise(Vector((c[0] * 0.2 + 3.0, c[1] * 0.2, 4.4)))
            if nz > 0.38 and q != 1:
                return
            heave = nz > 0.2
            p.block((c[0], c[1], c[2] + (0.08 if heave else 0.0)), (s[0] - T.JOINT * 2, s[1] - T.JOINT * 2, s[2]), yaw=yaw,
                    tilt=(r.uniform(-0.05, 0.05), r.uniform(-0.05, 0.05)) if heave else (0.0, 0.0),
                    chips=r.randint(0, 2) + (2 if heave else 0), chip_depth=(0.1, 0.35), far=False, hide=("-z",))
        arc(p, qa, qb, RIM_TOP - slab, RIM_TOP, -HALF_A, HALF_A, n, lay)
    rm = (ra + rb) / 2
    w = rm * math.tan(HALF_A)
    p.far_box((rm, 0, (BASE + RIM_TOP) / 2), (rb - ra, 2 * w, RIM_TOP - BASE), tone=0.97)
    p.solid((ra, -w, BASE), (rb, w, RIM_TOP))
    p.export()


# ---- the stage wall ---------------------------------------------------------
def rect(a, b, z0, z1):
    return {"x": (a, b), "cut": lambda lo, hi: (a, b) if lo >= z0 - 0.01 and hi <= z1 + 0.01 else None}


def arch(xc, rad, spring, depth=VOUSSOIR):
    def cut(lo, hi):
        if hi <= spring + 0.01:
            return (xc - rad, xc + rad)
        zm = (lo + hi) / 2 - spring
        if zm >= rad + depth:
            return None
        half = math.sqrt((rad + depth) ** 2 - zm * zm)
        return (xc - half, xc + half)
    return {"x": (xc - rad - depth, xc + rad + depth), "cut": cut}


def steps(*pairs):
    """A top line: (x from, top) pairs in rising x; the top at x."""
    def top(x):
        t = pairs[0][1]
        for (x0, v) in pairs:
            if x >= x0:
                t = v
        return t
    return top


def wall(p, x0, x1, top, openings=(), thick=WT):
    """The wall's courses from x0 to x1 up to top(x), left open where an
    opening cuts a course."""
    r = p.rng
    k = FOOT
    while k * CH < 48.0:
        z = k * CH
        spans = [(x0, x1)]
        for op in openings:
            c = op["cut"](z, z + CH)
            if c is None:
                continue
            nxt = []
            for (a, b) in spans:
                if c[1] <= a or c[0] >= b:
                    nxt.append((a, b))
                    continue
                if c[0] - a > 0.5:
                    nxt.append((a, c[0]))
                if b - c[1] > 0.5:
                    nxt.append((c[1], b))
            spans = nxt
        for (a, b) in spans:
            x = a
            first = True
            while x < b - 0.3:
                L = min(r.uniform(3.0, 5.0), b - x)
                if first and k % 2:
                    L = min(L * 0.55, b - x)
                if b - (x + L) < 1.3:
                    L = b - x
                first = False
                xc = x + L / 2
                t_here = min(top(x + 0.05), top(xc), top(x + L - 0.05))
                if z + CH <= top(xc) + 0.01:
                    edge = z + 2 * CH > t_here + 0.01
                    over = any(op["x"][0] < x + L and op["x"][1] > x for op in openings)
                    hide = [] if edge else ["+z"]
                    if not over and z > 0.0:
                        hide.append("-z")
                    p.block((xc, r.uniform(-0.05, 0.05), z + CH / 2), (L - T.JOINT, thick - r.uniform(0.0, 0.25), CH - T.JOINT),
                            chips=r.randint(2, 4) if edge else r.randint(0, 2), chip_depth=(0.25, 0.8) if edge else (0.1, 0.4),
                            far=False, hide=tuple(hide))
                x += L
        k += 1


def voussoirs(p, xc, rad, spring, depth=VOUSSOIR, thick=WT, lost=()):
    r = p.rng
    rm = rad + depth / 2
    n = int(round(math.pi * rm / 2.3)) | 1
    for i in range(n):
        if i in lost:
            continue
        a = (i + 0.5) * math.pi / n
        key = i == n // 2
        d = depth + (0.5 if key else 0.0)
        rr = rm + (0.25 - 0.12 if key else 0.0)
        p.block((xc + rr * math.cos(a), 0, spring + rr * math.sin(a)), (d - T.JOINT, thick + 0.3, math.pi * rm / n - T.JOINT),
                tilt=(0.0, -a), chips=r.randint(0, 2), chip_depth=(0.12, 0.4), far=False)


def mass(p, x0, x1, z0, z1, thick=WT):
    """A far box and a solid."""
    if x1 - x0 < 0.05 or z1 - z0 < 0.05:
        return
    p.far_box(((x0 + x1) / 2, 0, (z0 + z1) / 2), (x1 - x0, thick, z1 - z0), tone=0.97)
    p.solid((x0, -thick / 2, z0), (x1, thick / 2, z1))


def arch_mass(p, x0, x1, xc, rad, spring, top, thick=WT):
    """The mass of a bay x0..x1 with an arched opening, up to `top`."""
    crown = spring + rad
    h = rad * 0.7071
    mass(p, x0, xc - rad, FOOT * CH, crown, thick)
    mass(p, xc + rad, x1, FOOT * CH, crown, thick)
    mass(p, xc - rad, xc - h, spring + h, crown, thick)
    mass(p, xc + h, xc + rad, spring + h, crown, thick)
    mass(p, x0, x1, crown, top, thick)


def window_mass(p, x0, x1, half, z_from, top):
    """A bay's mass from z_from up round a window `half` wide each side whose lintel stands."""
    mass(p, x0, x1, z_from, WIN_Z0)
    mass(p, x0, -half, WIN_Z0, WIN_Z1)
    mass(p, half, x1, WIN_Z0, WIN_Z1)
    mass(p, x0, x1, WIN_Z1, top)


def build_stage_mid(seed):
    p = T.Piece("theatre_stage_mid", seed=seed)
    p.ground = 0.0
    h = MID_W / 2
    top = steps((-h, 36.0), (-7.5, 38.4), (5.0, 36.0), (8.5, 33.6))
    wall(p, -h, h, top, [arch(0.0, MID_R, MID_SPRING, 2.2)])
    voussoirs(p, 0.0, MID_R, MID_SPRING, 2.2)
    arch_mass(p, -h, h, 0.0, MID_R, MID_SPRING, 33.6)
    p.export()


def build_stage_door(seed):
    p = T.Piece("theatre_stage_door", seed=seed)
    p.ground = 0.0
    h = DOOR_W / 2
    top = steps((-h, 36.0), (2.5, 33.6))
    wall(p, -h, h, top, [arch(0.0, DOOR_R, DOOR_SPRING), rect(-3.5, 3.5, WIN_Z0, WIN_Z1), rect(-4.7, 4.7, WIN_Z1, WIN_Z1 + CH)])
    voussoirs(p, 0.0, DOOR_R, DOOR_SPRING)
    p.block((0, 0, WIN_Z1 + CH / 2), (9.4 - T.JOINT, WT + 0.2, CH - T.JOINT), chips=2, far=False)
    crown = DOOR_SPRING + DOOR_R
    arch_mass(p, -h, h, 0.0, DOOR_R, DOOR_SPRING, crown)
    window_mass(p, -h, h, 3.5, crown, 33.6)
    p.export()


def build_stage_wall(seed):
    p = T.Piece("theatre_stage_wall", seed=seed)
    p.ground = 0.0
    h = WALL_W / 2
    # The window's lintel and the wall over it are gone: a notch down to the sill's jambs.
    top = steps((-h, 36.0), (-2.5, 28.8), (2.5, 31.2), (3.8, 33.6))
    wall(p, -h, h, top, [rect(-2.5, 2.5, WIN_Z0, 40.0)])
    mass(p, -h, h, FOOT * CH, WIN_Z0)
    mass(p, -h, -2.5, WIN_Z0, 36.0)
    mass(p, 2.5, h, WIN_Z0, 31.2)
    p.export()


def build_stage_end(seed):
    p = T.Piece("theatre_stage_end", seed=seed)
    p.ground = 0.0
    h = END_W / 2
    marks = ((-h, 33.6), (-2.0, 28.8), (1.0, 24.0), (3.2, 19.2))
    wall(p, -h, h, steps(*marks))
    ends = [m[0] for m in marks[1:]] + [h]
    for (x0, t), x1 in zip(marks, ends):
        mass(p, x0, x1, FOOT * CH, t)
    p.export()


def build_stage_fallen(seed):
    p = T.Piece("theatre_stage_fallen", seed=seed)
    p.ground = 0.0
    r = p.rng
    h = FALLEN_W / 2
    marks = ((-h, 9.6), (-11.0, 4.8), (-9.0, 2.4), (-3.0, 0.0), (1.0, 2.4), (4.0, 4.8), (7.0, 9.6), (9.0, 14.4), (11.0, 19.2))
    wall(p, -h, h, steps(*marks))
    ends = [m[0] for m in marks[1:]] + [h]
    for (x0, t), x1 in zip(marks, ends):
        mass(p, x0, x1, FOOT * CH, t)
    # What fell: most behind the wall (-y), some in front; a heap by the stump.
    for i in range(26):
        back = i < 17
        x = r.uniform(-10.5, 8.5)
        d = abs(r.gauss(0.0, 5.0)) + 3.6
        d = min(d, 17.0 if back else 11.0)
        y = -d if back else d
        big = i % 3 != 2
        s = (r.uniform(2.6, 4.6), r.uniform(2.2, 4.4), 2.3) if big else (r.uniform(0.8, 1.8), r.uniform(0.8, 1.6), r.uniform(0.6, 1.2))
        tilt = (r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3))
        zc = s[2] / 2 - s[2] * r.uniform(0.15, 0.4) + (1.2 if big and d < 6.0 and r.random() < 0.4 else 0.0)
        p.block((x, y, zc), s, yaw=r.uniform(0, math.pi), tilt=tilt, chips=r.randint(2, 4), chip_depth=(0.2, 0.7), far=big)
        if big:
            e = max(s[0], s[1]) / 2 * 0.8
            p.solid((x - e, y - e, -0.5), (x + e, y + e, zc + s[2] / 2 + 0.3))
    p.export()


def build_side_arch(seed):
    """Built along x from 0 to ARCH_L, then turned to run along +y."""
    p = T.Piece("theatre_side_arch", seed=seed)
    p.ground = 0.0
    keep_near, keep_far, keep_boxes = p.near, p.far, p.boxes
    p.near, p.far, p.boxes = bmesh.new(), bmesh.new(), []
    T._layers(p.near)
    T._layers(p.far)
    xc = ARCH_L / 2
    top = steps((0.0, 24.0), (6.0, 26.4), (16.5, 24.0), (21.0, 21.6))
    wall(p, 0.0, ARCH_L, top, [arch(xc, ARCH_R, ARCH_SPRING)])
    voussoirs(p, xc, ARCH_R, ARCH_SPRING)
    arch_mass(p, 0.0, ARCH_L, xc, ARCH_R, ARCH_SPRING, 21.6)
    m = Matrix.Rotation(math.pi / 2, 4, "Z")
    T._append(keep_near, p.near, m)
    T._append(keep_far, p.far, m)
    for (lo, hi) in p.boxes:
        # (x, y) -> (-y, x)
        keep_boxes.append(((-hi[1], lo[0], lo[2]), (-lo[1], hi[0], hi[2])))
    p.near.free()
    p.far.free()
    p.near, p.far, p.boxes = keep_near, keep_far, keep_boxes
    p.export()


JOBS = {}
for _i in range(5):
    JOBS["theatre_seat_%d" % _i] = (lambda i=_i: build_seat(i, 61 + i))
    JOBS["theatre_seat_broken_%d" % _i] = (lambda i=_i: build_seat(i, 71 + i, broken=True))
JOBS.update({
    "theatre_rim": lambda: build_rim(81),
    "theatre_stage_mid": lambda: build_stage_mid(82),
    "theatre_stage_door": lambda: build_stage_door(83),
    "theatre_stage_wall": lambda: build_stage_wall(84),
    "theatre_stage_end": lambda: build_stage_end(85),
    "theatre_stage_fallen": lambda: build_stage_fallen(86),
    "theatre_side_arch": lambda: build_side_arch(87),
})

for name, job in JOBS.items():
    if only is None or only == name:
        job()
