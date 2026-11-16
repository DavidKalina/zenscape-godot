"""The temple kit's citadel: the pieces of a ruined fortress in the kit's stone
(temple_lib), laid by scripts/endless/citadel_site.gd. Bigger blocks than the
town's ashlar, in COURSE-high courses.

    python tools/blender.py run art/blender/temple_kit/citadel_build.py [-- --only=citadel_wall]

Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y). A curtain piece
runs along x, its origin on the ground at its middle, one BAY long; the wall
is WT thick and the same both sides (a parapet with merlons each side of the
walk, WALK over the ground), so a piece turned half round is its mirror.
Outside is Blender -y (Godot +z) where it matters (towers' doors, the gate).

- `citadel_wall`: a whole bay. The walk between the parapets is WT - 4.8 wide.
- `citadel_wall_gallery`: a bay with the covered gallery over the walk: an
  arched window to the court (+y), slits outward, a stone roof GALLERY over
  the walk.
- `citadel_wall_end`: a standing stretch's ragged end, full height at -x down
  to the ground at +x, its core open.
- `citadel_wall_low`: a bay standing to a third or half its height.
- `citadel_rubble`: a bank of fallen blocks along a bay, spilled both ways.
- `citadel_postern`: a bay with the lesser gate through it: a vaulted passage
  POSTERN_W wide, POSTERN_SPRING + POSTERN_W / 2 at the crown.
- `citadel_blocking`: the wall that blocks a postern's or a tower door's
  mouth (breaks_build.py makes its cracked and broken variants).
- `citadel_tower_base` (to the walk, a door on +y and on -y as the postern's mouth),
  `citadel_tower_storey` (STOREY high, the walk's doors on +-x),
  `citadel_tower_crown` (the top with its merlons, a corner down) and
  `citadel_tower_ruin` (a storey broken on the slant, low toward +x): a
  hollow square tower TOWER across, its walls TOWER_T thick, stacked.
- `citadel_tower_split`: a whole tower split top to bottom through its -y and
  +y walls, the cleft CLEFT_W wide at the ground and wider above.
- `citadel_bastion`, `citadel_bastion_tall`: a round corner bastion to the
  walk's level, BASTION_R in radius, its top a platform; a parapet (or the
  ragged shell of its upper storeys) round the outer arc.
- `citadel_gate`: the gatehouse, three bays long and GATE_D deep, the vaulted
  passage GATE_W wide through it along y.
- `citadel_keep`: the keep's lower storeys, KEEP across, a door in each side.
- `citadel_cistern`: a walled basin with two rows of piers, two ribs of its
  vault left across the nave, its -x end breached.
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

BAY = T.BAY
HALF = BAY / 2
COURSE = 2.2
WT = 21.0                   # the curtain wall, through
SKIN = 2.4                  # a face's blocks, deep
WALK = COURSE * 12          # 26.4: the walk over the ground
FOOT = -COURSE * 3          # the courses start this far under the origin
LIFT = 2.5                  # the site sets a piece's origin this far over its lowest ground
G0 = -LIFT - 0.2            # so fallen blocks lie this far under the origin
MERLON = COURSE * 2         # over the parapet's one course
GALLERY = COURSE * 7        # the gallery's roof over the walk
POSTERN_W = 14.5
POSTERN_SPRING = COURSE * 4
TOWER = BAY * 2             # 37, outside
TOWER_T = 5.0
STOREY = COURSE * 10        # 22
DOOR_W = 16.0               # the walk's doors through a tower
DOOR_SPRING = COURSE * 4
CLEFT_W = 15.0
BASTION_R = 21.0
GATE_W = 18.0
GATE_SPRING = COURSE * 6
GATE_D = 44.0
GATE_TOP = COURSE * 18
KEEP = BAY * 3
KEEP_T = 6.0
KEEP_DOOR_SPRING = COURSE * 5
KEEP_FOOT = -COURSE * 4      # the keep stands on a slope: its courses start deeper
CIST_FOOT = -COURSE * 3

ROT = {"-y": 0.0, "+x": math.pi / 2, "+y": math.pi, "-x": -math.pi / 2}
NRM = {"-y": (0, -1), "+x": (1, 0), "+y": (0, 1), "-x": (-1, 0)}
ALONG = {"-y": (1, 0), "+x": (0, 1), "+y": (-1, 0), "-x": (0, -1)}
SIDES = ("-x", "+x", "-y", "+y", "-z", "+z")


class Lay:
    """A piece under way: the temple Piece, a layout rng apart from the
    stone's own (so a mid LOD lays the same blocks) and whether it is the mid."""

    def __init__(self, name, seed, mid):
        self.p = T.Piece(name, seed=seed)
        self.r = random.Random(seed * 31 + 7)
        self.mid = mid
        self.name = name

    def block(self, center, size, yaw=0.0, tilt=(0.0, 0.0), hide=(), chips=None, edge=False, far=False, tone=None):
        r = self.r
        t = r.uniform(0.86, 1.08) if tone is None else tone
        n = (3 if edge else r.randint(0, 1)) if chips is None else chips
        seen = tuple(s for s in SIDES if s not in hide)
        if self.mid:
            self.p.block(center, size, yaw=yaw, tilt=tilt, bevel=0.0, chips=0, jitter=0.0, tone=t, far=False,
                         hide=tuple(hide), seen=seen if hide else None)
        else:
            self.p.block(center, size, yaw=yaw, tilt=tilt, chips=n, chip_depth=(0.2, 0.6) if edge else (0.1, 0.35),
                         tone=t, far=far, hide=tuple(hide), seen=seen if hide else None)

    def export(self):
        if self.mid:
            self.p.export(mid_of=self.name)
        else:
            self.p.export()


def rect(c, w, z0, z1):
    return lambda u, z: abs(u - c) < w / 2 and z0 <= z < z1


def arch(c, w, z0, spring):
    R = w / 2
    return lambda u, z: abs(u - c) < R and z >= z0 and (z < spring or (u - c) ** 2 + (z - spring) ** 2 < R * R)


def courses(z0, z1, course=COURSE):
    out = []
    z = z0
    while z < z1 - 0.01:
        h = min(course, z1 - z)
        if z1 - (z + h) < 0.8:
            h = z1 - z
        out.append((z, z + h))
        z += h
    return out


def step_top(fn, course=COURSE, z0=FOOT):
    """`fn` (a height along the wall) stepped to the courses."""
    return lambda u: z0 + math.floor((fn(u) - z0) / course + 0.5) * course


def wall(L, a, b, z0, z1, out, thick=SKIN, holes=(), top=None, length=(3.8, 6.2), through=False, body=None,
         solid=True, far=True, ragged=False, course=COURSE):
    """A wall's face in courses of blocks from plan point a to b (along x or
    along y), z0 to z1, facing `out`, its blocks `thick` deep behind the
    face. `holes`: fn(along, z) true where there is none (`along`: the
    world coordinate along the wall); `top`: fn(along) the wall's height
    there. A block's faces against other blocks are left out, and its back
    unless `through` (a wall one block thick, seen both sides). `solid` /
    `far`: the wall's boxes (`body` deep, default `thick`) for the flight
    and the far LOD."""
    r = L.r
    ud = ALONG[out]
    n = NRM[out]
    pa = a[0] * ud[0] + a[1] * ud[1]
    pb = b[0] * ud[0] + b[1] * ud[1]
    u_min = min(pa, pb)
    Lw = abs(pb - pa)
    f = a[0] * n[0] + a[1] * n[1]
    s = ud[0] + ud[1]

    def axis(u):
        return (u_min + u) * s

    def stone(u, zl, zh):
        if u < -1e-6 or u > Lw + 1e-6 or zl < z0 - 1e-6:
            return False
        t = z1 if top is None else min(z1, top(axis(u)))
        if zh > t + 1e-6:
            return False
        c = axis(u)
        for h in holes:
            if h(c, zl + 0.05) or h(c, zh - 0.05):
                return False
        return True

    def plan(u, back):
        return (ud[0] * (u_min + u) + n[0] * (f - back), ud[1] * (u_min + u) + n[1] * (f - back))

    rows = courses(z0, z1, course)
    for (zl, zh) in rows:
        # The course's stretches of stone.
        runs = []
        start = None
        k = 0
        du = 0.1
        steps = int(round(Lw / du))
        for k in range(steps + 1):
            u = min(Lw, k * du)
            ok = stone(min(max(u, 0.01), Lw - 0.01), zl, zh)
            if ok and start is None:
                start = u
            if (not ok or k == steps) and start is not None:
                end = u if not ok else Lw
                if end - start > 0.5:
                    runs.append((start, end))
                start = None
        for (ua, ub) in runs:
            x = ua
            while x < ub - 0.3:
                Lb = min(r.uniform(*length), ub - x)
                if ub - (x + Lb) < 1.6:
                    Lb = ub - x
                u0, u1 = x, x + Lb
                x += Lb
                um = (u0 + u1) / 2
                hide = [] if through else ["+y"]
                if stone(u0 - 0.3, zl, zh):
                    hide.append("-x")
                if stone(u1 + 0.3, zl, zh):
                    hide.append("+x")
                over = all(stone(uu, zh, zh + 0.5) for uu in (u0 + 0.2, um, u1 - 0.2))
                if over:
                    hide.append("+z")
                if zl <= z0 + 1e-6 or all(stone(uu, zl - 0.5, zl) for uu in (u0 + 0.2, um, u1 - 0.2)):
                    hide.append("-z")
                px, py = plan(um, thick / 2)
                L.block((px, py, (zl + zh) / 2), (Lb - T.JOINT, thick, zh - zl - T.JOINT), yaw=ROT[out], hide=hide,
                        edge=ragged and not over)
    if not (solid or far):
        return
    # The wall's boxes: columns of the same stretches of height run together.
    bt = thick if body is None else body
    ncol = max(1, int(round(Lw / 2.3)))
    du = Lw / ncol
    cols = []
    for i in range(ncol):
        um = (i + 0.5) * du
        got = []
        for (zl, zh) in rows:
            if stone(um, zl, zh):
                if got and abs(got[-1][1] - zl) < 1e-6:
                    got[-1] = (got[-1][0], zh)
                else:
                    got.append((zl, zh))
        cols.append(got)
    i = 0
    while i < ncol:
        j = i
        while j + 1 < ncol and cols[j + 1] == cols[i]:
            j += 1
        for (zl, zh) in cols[i]:
            p0 = plan(i * du, 0.0)
            p1 = plan((j + 1) * du, bt)
            lo = (min(p0[0], p1[0]), min(p0[1], p1[1]), zl)
            hi = (max(p0[0], p1[0]), max(p0[1], p1[1]), zh)
            if solid:
                L.p.solid(lo, hi)
            if far:
                L.p.far_box(tuple((lo[k] + hi[k]) / 2 for k in range(3)), tuple(hi[k] - lo[k] for k in range(3)))
        i = j + 1


def ring(L, a, c, spring, R, out, depth, t=2.2, front=True, back=True, proud=0.25, solid=False):
    """A ring of wedge stones round an arch's head in a wall facing `out`:
    `a` a plan point on the wall's face, `c` the arch's middle along the
    wall, the stones standing `proud` of the face and `depth` deep."""
    ud = ALONG[out]
    n = NRM[out]
    f = a[0] * n[0] + a[1] * n[1]
    s = ud[0] + ud[1]
    rm = R + t / 2
    count = max(7, int(round(math.pi * rm / 2.6)) | 1)
    for i in range(count):
        phi = math.pi * (i + 0.5) / count
        du = rm * math.cos(phi)
        z = spring + rm * math.sin(phi)
        w = math.pi * rm / count
        back_off = depth / 2 - proud
        px = ud[0] * (c * s + du) + n[0] * (f - back_off)
        py = ud[1] * (c * s + du) + n[1] * (f - back_off)
        hide = ["+z", "+x", "-x"]
        if not front:
            hide.append("-y")
        if not back:
            hide.append("+y")
        L.block((px, py, z), (w - T.JOINT, depth, t), yaw=ROT[out], tilt=(0.0, math.pi / 2 - phi), hide=hide)
        if solid:
            e = (abs(math.cos(phi)) * t + abs(math.sin(phi)) * w) / 2
            ez = (abs(math.sin(phi)) * t + abs(math.cos(phi)) * w) / 2
            ax, ay = abs(ud[0]) * e + abs(n[0]) * depth / 2, abs(ud[1]) * e + abs(n[1]) * depth / 2
            L.p.solid((px - ax, py - ay, z - ez), (px + ax, py + ay, z + ez))
            L.p.far_box((px, py, z), (2 * ax, 2 * ay, 2 * ez))


def vault(L, c, w, spring, y0, y1, t=2.2, x_axis=True):
    """A barrel vault's stones over a passage along y from y0 to y1, `w`
    wide about x = c, and the passage's two side walls up to `spring`."""
    n = max(1, int(round((y1 - y0) / 5.6)))
    d = (y1 - y0) / n
    for i in range(n):
        ring(L, (0.0, y0 + i * d), c, spring, w / 2, "-y", d - T.JOINT, t=t, front=i == 0, back=i == n - 1,
             proud=0.25 if i == 0 else 0.0)
    wall(L, (c - w / 2, y0), (c - w / 2, y1), FOOT, spring, "+x", thick=1.8, solid=False, far=False)
    wall(L, (c + w / 2, y0), (c + w / 2, y1), FOOT, spring, "-x", thick=1.8, solid=False, far=False)


def floor(L, x0, x1, y0, y1, z, t=0.9, size=(3.6, 5.6), keep=None, under=False, far=True):
    """Slabs with their tops at z; `keep(x, y)` false leaves one out. Only
    their tops are made (and their undersides with `under`)."""
    r = L.r
    y = y0
    while y < y1 - 0.3:
        w = min(r.uniform(3.4, 4.6), y1 - y)
        if y1 - (y + w) < 1.6:
            w = y1 - y
        x = x0
        while x < x1 - 0.3:
            Lb = min(r.uniform(*size), x1 - x)
            if x1 - (x + Lb) < 1.6:
                Lb = x1 - x
            if keep is None or keep(x + Lb / 2, y + w / 2):
                hide = ["-x", "+x", "-y", "+y"] + ([] if under else ["-z"])
                L.block((x + Lb / 2, y + w / 2, z - t / 2 + r.uniform(-0.05, 0.03)), (Lb - T.JOINT, w - T.JOINT, t),
                        hide=hide, chips=0)
            x += Lb
        y += w
    if far and keep is None:
        L.p.far_box(((x0 + x1) / 2, (y0 + y1) / 2, z - t / 2), (x1 - x0, y1 - y0, t))


def core(L, x0, x1, y0, y1, top, deep=5.5, cell=(2.6, 4.2), skip=None):
    """The wall's core open to the sky: rough blocks whose tops follow
    `top(x)`, each `deep` (so a step in the top shows stone, not a gap)."""
    r = L.r
    nx = max(1, int(round((x1 - x0) / cell[0])))
    ny = max(1, int(round((y1 - y0) / cell[1])))
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx):
        xc = x0 + (i + 0.5) * dx
        if skip is not None and skip(xc):
            continue
        for j in range(ny):
            yc = y0 + (j + 0.5) * dy
            z = top(xc) - r.uniform(0.2, 1.6)
            L.block((xc, yc, z - deep / 2), (dx - T.JOINT, dy - T.JOINT, deep), hide=["-z"], edge=True,
                    tilt=(r.uniform(-0.04, 0.04), r.uniform(-0.04, 0.04)))


def tumble(L, n, spot, size=(1.4, 3.6), solid_over=2.6):
    """Fallen blocks: `spot()` gives each one's (x, y, ground z); half sunk,
    askew. The big ones get a far box and (over `solid_over` m) a solid."""
    r = L.r
    for _ in range(n):
        x, y, g = spot()
        sx = r.uniform(*size)
        sy = sx * r.uniform(0.5, 0.9)
        sz = sx * r.uniform(0.4, 0.7)
        tilt = (r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5))
        z = g + sz * r.uniform(0.05, 0.4)
        big = sx > solid_over
        L.block((x, y, z), (sx, sy, sz), yaw=r.uniform(0, math.pi), tilt=tilt, chips=r.randint(2, 4), far=big and not L.mid)


def merlons(L, a, b, z, out, count, gone=(), thick=SKIN, width=3.6):
    """`count` merlons evenly along the parapet from a to b, on top of z."""
    for i in range(count):
        if i in gone:
            continue
        t = (i + 0.5) / count
        cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        ud = ALONG[out]
        p0 = (cx - abs(ud[0]) * width / 2, cy - abs(ud[1]) * width / 2)
        p1 = (cx + abs(ud[0]) * width / 2, cy + abs(ud[1]) * width / 2)
        wall(L, p0, p1, z, z + MERLON, out, thick=thick, through=True, length=(width, width))


# ---- the curtain wall -----------------------------------------------------------
YO = WT / 2                  # the faces


def curtain(L, top=None, holes=(), z1=WALK, ragged=False, x0=-HALF, x1=HALF):
    """Both faces of a bay from the foot to z1."""
    wall(L, (x0, -YO), (x1, -YO), FOOT, z1, "-y", holes=holes, top=top, body=WT, ragged=ragged)
    wall(L, (x0, YO), (x1, YO), FOOT, z1, "+y", holes=holes, top=top, solid=False, far=False, ragged=ragged)


def caps(L, ends=(-1, 1), z1=WALK):
    """The bay's ends closed (the next piece may stand lower)."""
    for sd in ends:
        wall(L, (sd * HALF, -YO + SKIN), (sd * HALF, YO - SKIN), FOOT, z1, "-x" if sd < 0 else "+x", solid=False, far=False)


def parapets(L, sides=(-1, 1), gone=((), ()), top=None, x0=-HALF, x1=HALF):
    for k, sd in enumerate(sides):
        out = "-y" if sd < 0 else "+y"
        wall(L, (x0, sd * YO), (x1, sd * YO), WALK, WALK + COURSE, out, through=True, top=top, ragged=top is not None)
        if top is None:
            merlons(L, (x0, sd * YO), (x1, sd * YO), WALK + COURSE, out, 3, gone=gone[k])


def build_wall(L):
    L.p.ground = 0.0
    curtain(L)
    caps(L)
    parapets(L, gone=((1,), ()))
    floor(L, -HALF, HALF, -YO + SKIN, YO - SKIN, WALK)


def build_gallery(L):
    L.p.ground = 0.0
    curtain(L)
    caps(L)
    floor(L, -HALF, HALF, -YO + SKIN, YO - SKIN, WALK)
    top = WALK + GALLERY
    # Outward: a wall with two slits. To the court: one wide arched window over a sill.
    wall(L, (-HALF, -YO), (HALF, -YO), WALK, top, "-y", through=True,
         holes=[rect(-4.6, 2.0, WALK + COURSE * 2, WALK + COURSE * 5), rect(4.6, 2.0, WALK + COURSE * 2, WALK + COURSE * 5)])
    win = arch(0.0, 13.0, WALK + COURSE, WALK + COURSE * 3)
    wall(L, (-HALF, YO), (HALF, YO), WALK, top, "+y", through=True, holes=[win])
    ring(L, (0.0, YO), 0.0, WALK + COURSE * 3, 6.5, "+y", SKIN + 0.5, t=1.8)
    # The roof: slabs seen from over and under.
    floor(L, -HALF, HALF, -YO, YO, top + 1.2, t=1.2, under=True, size=(4.4, 6.5))
    L.p.solid((-HALF, -YO, top), (HALF, YO, top + 1.2))


def end_top(x):
    t = (x + HALF) / BAY
    h = (WALK + COURSE) * (1.0 - t) ** 0.75 + 2.6 * noise.noise(Vector((x * 0.21, 3.3, 0.7)))
    return max(FOOT + COURSE * 0.6, h) if t < 0.93 else FOOT


def build_end(L):
    L.p.ground = 0.0
    top = step_top(end_top)
    curtain(L, top=top, ragged=True)
    caps(L, ends=(-1,))
    parapets(L, top=top)
    core(L, -HALF, HALF, -YO + SKIN, YO - SKIN, lambda x: min(top(x), WALK), skip=lambda x: top(x) <= 0.0)
    r = L.r
    tumble(L, 26, lambda: (r.uniform(1.0, 13.0), r.gauss(0.0, 9.0), G0))


def low_top(x):
    return 12.0 + 5.5 * noise.noise(Vector((x * 0.13, 7.7, 1.9))) + 2.5 * noise.noise(Vector((x * 0.45, 1.2, 4.0)))


def build_low(L):
    L.p.ground = 0.0
    top = step_top(low_top)
    curtain(L, top=top, ragged=True)
    core(L, -HALF, HALF, -YO + SKIN, YO - SKIN, top)
    # Its two ends closed (a gap may come next).
    for sd, x in (("-x", -HALF), ("+x", HALF)):
        wall(L, (x, -YO + SKIN), (x, YO - SKIN), FOOT, top(x * 0.98), sd, solid=False, far=False, ragged=True)
    r = L.r
    tumble(L, 14, lambda: (r.uniform(-HALF, HALF), r.choice((-1, 1)) * r.uniform(YO + 1.0, YO + 9.0), G0))


def build_rubble(L):
    """A bank where the wall is down: big blocks heaped along the bay,
    highest on the wall's line, spilled out both ways."""
    L.p.ground = 0.0
    r = L.r

    def mound(x, y):
        return 5.0 * math.exp(-(y / 9.0) ** 2) * (0.75 + 0.25 * noise.noise(Vector((x * 0.2, y * 0.2, 9.1))))

    def spot():
        x = r.uniform(-HALF, HALF)
        y = r.gauss(0.0, 9.5)
        return (x, y, mound(x, y) * r.uniform(0.35, 0.95) - 0.4)

    tumble(L, 64, spot, size=(1.6, 4.6), solid_over=9.0)
    # The foot of the wall still there under the heap, in places.
    wall(L, (-HALF, -YO), (HALF, -YO), FOOT, COURSE * 2, "-y", ragged=True, solid=False, far=False,
         top=step_top(lambda x: 1.2 + 2.6 * noise.noise(Vector((x * 0.3, 0.4, 2.2)))))
    wall(L, (-HALF, YO), (HALF, YO), FOOT, COURSE * 2, "+y", ragged=True, solid=False, far=False,
         top=step_top(lambda x: 1.0 + 2.6 * noise.noise(Vector((x * 0.3, 5.4, 6.2)))))
    for (hy, h) in ((5.5, 4.4), (13.0, 2.6), (20.0, 1.1)):
        L.p.solid((-HALF, -hy, -1.0), (HALF, hy, h))
    if not L.mid:
        L.p.far_box((0, 0, 1.6), (BAY, 12.0, 4.6))
        L.p.far_box((0, 0, 0.6), (BAY, 30.0, 1.6))


def build_postern(L):
    L.p.ground = 0.0
    hole = arch(0.0, POSTERN_W, -9.0, POSTERN_SPRING)
    curtain(L, holes=[hole])
    caps(L)
    parapets(L)
    floor(L, -HALF, HALF, -YO + SKIN, YO - SKIN, WALK)
    vault(L, 0.0, POSTERN_W, POSTERN_SPRING, -YO, YO)


def blocking_top(u):
    d = abs(u)
    R = POSTERN_W / 2
    return POSTERN_SPRING + math.sqrt(max(0.0, R * R - d * d)) - 0.15


def build_blocking(L):
    """The wall in a doorway's mouth: smaller stones, laid in a hurry. Its
    face on y = 0, the mouth's shape (the postern's)."""
    L.p.ground = 0.0
    R = POSTERN_W / 2
    for (zl, zh) in courses(FOOT, POSTERN_SPRING + R, 1.6):
        half = R - 0.1 if zh <= POSTERN_SPRING else math.sqrt(max(0.0, R * R - (zh - POSTERN_SPRING) ** 2)) - 0.1
        if half < 1.2:
            continue
        wall(L, (-half, 0.0), (half, 0.0), zl, zh, "-y", thick=2.0, through=True, length=(2.0, 3.4), course=1.6)


# ---- the square towers ----------------------------------------------------------
TH = TOWER / 2               # 18.5
TI = TH - TOWER_T            # 13.5: the inner faces


def tower_walls(L, z0, z1, holes=None, tops=None, ragged=False, half=TH, thick=TOWER_T, length=(4.6, 7.0)):
    """A square tower's four walls, both faces. `holes`, `tops`: per side
    ("-y", "+y", "-x", "+x") lists of holes / a top fn, in the wall's own
    world coordinate (x for the +-y walls, y for the +-x walls)."""
    holes = holes or {}
    tops = tops or {}
    inner = half - thick
    sk = thick / 2
    for sd, sign in (("-y", -1), ("+y", 1)):
        h, t = holes.get(sd, ()), tops.get(sd)
        wall(L, (-half, sign * half), (half, sign * half), z0, z1, sd, thick=sk, holes=h, top=t, body=thick,
             ragged=ragged, length=length)
        back = "+y" if sign < 0 else "-y"
        wall(L, (-inner, sign * inner), (inner, sign * inner), z0, z1, back, thick=sk, holes=h, top=t, solid=False,
             far=False, ragged=ragged, length=length)
    for sd, sign in (("-x", -1), ("+x", 1)):
        h, t = holes.get(sd, ()), tops.get(sd)
        wall(L, (sign * half, -half + sk), (sign * half, half - sk), z0, z1, sd, thick=sk, holes=h, top=t, body=thick,
             ragged=ragged, length=length)
        back = "+x" if sign < 0 else "-x"
        wall(L, (sign * inner, -inner), (sign * inner, inner), z0, z1, back, thick=sk, holes=h, top=t, solid=False,
             far=False, ragged=ragged, length=length)


def door_rings(L, side, c, spring, w, half=TH, thick=TOWER_T):
    sign = -1 if side[0] == "-" else 1
    a = (0.0, sign * half) if side[1] == "y" else (sign * half, 0.0)
    ring(L, a, c, spring, w / 2, side, thick + 0.5, t=2.0)


def build_tower_base(L):
    L.p.ground = 0.0
    door = arch(0.0, POSTERN_W, -9.0, POSTERN_SPRING)
    tower_walls(L, FOOT, WALK, holes={"+y": [door], "-y": [door]})
    for sd in ("+y", "-y"):
        door_rings(L, sd, 0.0, POSTERN_SPRING, POSTERN_W)


def storey_holes():
    door = arch(0.0, DOOR_W, -1.0, DOOR_SPRING)
    slit = [rect(-6.0, 2.2, COURSE * 3, COURSE * 6), rect(6.0, 2.2, COURSE * 3, COURSE * 6)]
    return {"-x": [door], "+x": [door], "-y": slit, "+y": slit}


def build_tower_storey(L):
    L.p.ground = -100.0
    tower_walls(L, 0.0, STOREY, holes=storey_holes())
    for sd in ("-x", "+x"):
        door_rings(L, sd, 0.0, DOOR_SPRING, DOOR_W)


def build_tower_crown(L):
    L.p.ground = -100.0
    H = COURSE * 4
    # The +x -y corner is down.
    def cut(a, b):
        return step_top(lambda u: H if (u * a) < 4.0 else H - (u * a - 4.0) * 0.55 * b
                        + 1.5 * noise.noise(Vector((u * 0.3, 2.0, 8.0))), z0=0.0)
    tops = {"-y": cut(1, 1), "+x": cut(-1, 1)}
    tower_walls(L, 0.0, H, tops=tops, ragged=True)
    for sd, a, b, gone in (("+y", (-TH, TH), (TH, TH), (2,)), ("-x", (-TH, -TI), (-TH, TI), ()),
                           ("-y", (-TH, -TH), (2.0, -TH), (0,)), ("+x", (TH, 0.0), (TH, TI), ())):
        merlons(L, a, b, H, sd, 5 if sd == "+y" else (4 if sd == "-x" else 2), gone=gone, thick=TOWER_T / 2, width=4.2)


def ruin_tops():
    def slope(x):
        return STOREY * (0.55 - 0.45 * x / TH) + 3.0 * noise.noise(Vector((x * 0.2, 4.1, 3.3)))
    return {"-y": step_top(lambda x: slope(x) + 2.0, z0=0.0), "+y": step_top(lambda x: slope(x) - 2.0, z0=0.0),
            "-x": step_top(lambda y: STOREY * 0.95 + 2.0 * noise.noise(Vector((y * 0.3, 1.0, 6.0))), z0=0.0),
            "+x": step_top(lambda y: STOREY * 0.12 + 2.0 * noise.noise(Vector((y * 0.3, 3.0, 2.0))), z0=0.0)}


def build_tower_ruin(L):
    L.p.ground = -100.0
    tower_walls(L, 0.0, STOREY, tops=ruin_tops(), ragged=True)


SPLIT_TOP = COURSE * 28


def cleft(u, z):
    mid = 1.6 * math.sin(z * 0.11) + 1.2 * noise.noise(Vector((z * 0.21, 4.4, 0.3)))
    half = CLEFT_W / 2 + 0.3 + max(0.0, z) * 0.1 + 0.9 * noise.noise(Vector((z * 0.33, 8.8, 1.5)))
    return abs(u - mid) < half


def build_tower_split(L):
    L.p.ground = 0.0
    door = arch(0.0, DOOR_W, WALK - 1.0, WALK + DOOR_SPRING)

    def lean(sign, base):
        return step_top(lambda x: base + 15.0 * abs(x) / TH * (1.0 if x * sign > 0 else 0.55)
                        + 3.0 * noise.noise(Vector((x * 0.2, base, 3.3))))
    tops = {"-y": lean(1, 40.0), "+y": lean(-1, 36.0),
            "-x": step_top(lambda y: 47.0 + 3.0 * noise.noise(Vector((y * 0.3, 1.0, 6.0)))),
            "+x": step_top(lambda y: 56.0 + 3.0 * noise.noise(Vector((y * 0.3, 3.0, 2.0))))}
    tower_walls(L, FOOT, SPLIT_TOP, holes={"-y": [cleft], "+y": [cleft], "-x": [door], "+x": [door]}, tops=tops,
                ragged=True)
    for sd in ("-x", "+x"):
        door_rings(L, sd, 0.0, WALK + DOOR_SPRING, DOOR_W)
    r = L.r
    tumble(L, 30, lambda: (r.gauss(0.0, 3.0) + r.choice((-1, 1)) * 11.0, r.choice((-1, 1)) * r.uniform(TH + 1.0, TH + 16.0), G0),
           size=(1.6, 4.2), solid_over=9.0)


# ---- the round bastions ---------------------------------------------------------
def drum(L, R, z0, z1, a0, a1, top=None, thick=SKIN, inward=False, through=False, length=4.8, ragged=False):
    """A round wall's face of radius R in courses, from angle a0 to a1
    (radians, from +x toward +y); `top(angle)` its height there."""
    r = L.r
    full = abs((a1 - a0) - math.tau) < 1e-6
    n = max(3, int(round(R * (a1 - a0) / length)))
    da = (a1 - a0) / n

    def stone(a, zl, zh):
        if not full and (a < a0 - 1e-6 or a > a1 + 1e-6):
            return False
        if zl < z0 - 1e-6:
            return False
        t = z1 if top is None else min(z1, top(a))
        return zh <= t + 1e-6

    for k, (zl, zh) in enumerate(courses(z0, z1)):
        off = da / 2 if k % 2 else 0.0
        for i in range(n if full or not k % 2 else n - 1):
            am = a0 + off + (i + 0.5) * da
            if not stone(am, zl, zh):
                continue
            hide = [] if through else ["+y"]
            if stone(am - da, zl, zh) and stone(am - da / 2 - 0.01, zl, zh):
                hide.append("-x" if not inward else "+x")
            if stone(am + da, zl, zh) and stone(am + da / 2 + 0.01, zl, zh):
                hide.append("+x" if not inward else "-x")
            over = stone(am - da * 0.4, zh, zh + 0.5) and stone(am + da * 0.4, zh, zh + 0.5)
            if over:
                hide.append("+z")
            if zl <= z0 + 1e-6 or (stone(am - da * 0.4, zl - 0.5, zl) and stone(am + da * 0.4, zl - 0.5, zl)):
                hide.append("-z")
            rc = R - thick / 2 if not inward else R + thick / 2
            chord = 2.0 * (R if not inward else R + thick) * math.sin(da / 2)
            yaw = am + math.pi / 2 if not inward else am - math.pi / 2
            L.block((rc * math.cos(am), rc * math.sin(am), (zl + zh) / 2), (chord - T.JOINT, thick, zh - zl - T.JOINT),
                    yaw=yaw, hide=hide, edge=ragged and not over)


def arc_boxes(L, R0, R1, z0, a0, a1, top, step=math.radians(11.0), far=True):
    """Solids and far boxes for a round wall between radii R0 and R1."""
    n = max(1, int(round((a1 - a0) / step)))
    da = (a1 - a0) / n
    rm = (R0 + R1) / 2
    e = max((R1 - R0) / 2, rm * math.sin(da / 2)) * 1.02
    for i in range(n):
        am = a0 + (i + 0.5) * da
        t = top(am)
        if t <= z0 + 0.5:
            continue
        cx, cy = rm * math.cos(am), rm * math.sin(am)
        L.p.solid((cx - e, cy - e, z0), (cx + e, cy + e, t))
        if far:
            L.p.far_box((cx, cy, (z0 + t) / 2), (2 * e, 2 * e, t - z0), yaw=am)


# The outer arc: centred on -y (outside), this wide.
ARC0, ARC1 = math.radians(-152.0), math.radians(-28.0)


def bastion_shell_top(a):
    t = (a - ARC0) / (ARC1 - ARC0)
    h = WALK + COURSE * 17 * (0.25 + 0.75 * max(0.0, math.sin(math.pi * min(1.0, t * 1.25))) ** 0.8)
    return h + 5.0 * noise.noise(Vector((a * 2.2, 6.0, 0.4)))


def build_bastion(L, tall):
    L.p.ground = 0.0
    R = BASTION_R
    drum(L, R, FOOT, WALK, 0.0, math.tau)
    # The platform: slabs inside the circle.
    floor(L, -R, R, -R, R, WALK, keep=lambda x, y: x * x + y * y < (R - 1.0) ** 2, far=False)
    # The drum's solids: small squares (the site turns the bastion any way, and a
    # box's bounds in the chunk's frame grow with its size), a ring of them at the rim.
    cell = R / 4
    for i in range(-4, 4):
        for j in range(-4, 4):
            cx, cy = (i + 0.5) * cell, (j + 0.5) * cell
            if math.hypot(cx, cy) < R - cell * 0.8:
                L.p.solid((cx - cell / 2, cy - cell / 2, FOOT), (cx + cell / 2, cy + cell / 2, WALK))
    arc_boxes(L, R - 4.2, R - 0.2, FOOT, 0.0, math.tau, lambda a: WALK, far=False)
    if not L.mid:
        L.p.far_cylinder((0, 0, FOOT), WALK - FOOT, R, R, segments=14)
    if tall:
        top = lambda a: FOOT + math.floor((bastion_shell_top(a) - FOOT) / COURSE + 0.5) * COURSE
        z1 = WALK + COURSE * 18
        drum(L, R, WALK, z1, ARC0, ARC1, top=top, ragged=True)
        drum(L, R - TOWER_T, WALK, z1, ARC0, ARC1, top=top, inward=True, ragged=True)
        # The shell's two ends, where it is cut: the gap between its faces filled.
        for a in (ARC0, ARC1):
            rm = R - TOWER_T / 2
            for (zl, zh) in courses(WALK, min(z1, top(a + (0.02 if a == ARC0 else -0.02)))):
                L.block((rm * math.cos(a), rm * math.sin(a), (zl + zh) / 2), (TOWER_T - 0.1, 2.0, zh - zl - T.JOINT),
                        yaw=a, edge=True)
        arc_boxes(L, R - TOWER_T, R, WALK, ARC0, ARC1, top)
    else:
        drum(L, R, WALK, WALK + COURSE, ARC0, ARC1, through=True)
        n = 6
        for i in range(n):
            if i == 4:
                continue
            am = ARC0 + (i + 0.5) * (ARC1 - ARC0) / n
            rc = R - SKIN / 2
            for (zl, zh) in courses(WALK + COURSE, WALK + COURSE + MERLON):
                L.block((rc * math.cos(am), rc * math.sin(am), (zl + zh) / 2), (3.8, SKIN, zh - zl - T.JOINT),
                        yaw=am + math.pi / 2)
        arc_boxes(L, R - SKIN, R, WALK, ARC0, ARC1, lambda a: WALK + COURSE + MERLON)


# ---- the gatehouse ----------------------------------------------------------------
GX = BAY * 1.5              # 27.75
GY = GATE_D / 2


def build_gate(L):
    L.p.ground = 0.0
    hole = arch(0.0, GATE_W, -9.0, GATE_SPRING)

    def corner(sign_u):
        # The top down toward the -y +x corner.
        return step_top(lambda u: GATE_TOP if u * sign_u < 9.0 else GATE_TOP - (u * sign_u - 9.0) * 0.6
                        + 1.6 * noise.noise(Vector((u * 0.3, 2.0, 5.0))))
    wall(L, (-GX, -GY), (GX, -GY), FOOT, GATE_TOP, "-y", holes=[hole], body=GATE_D, top=corner(1), ragged=True)
    wall(L, (-GX, GY), (GX, GY), FOOT, GATE_TOP, "+y", holes=[hole], solid=False, far=False)
    wall(L, (-GX, -GY + SKIN), (-GX, GY - SKIN), FOOT, GATE_TOP, "-x", solid=False, far=False)
    wall(L, (GX, -GY + SKIN), (GX, GY - SKIN), FOOT, GATE_TOP, "+x", solid=False, far=False, top=corner(-1), ragged=True)
    vault(L, 0.0, GATE_W, GATE_SPRING, -GY, GY)
    # A band standing out over the arch, front and back.
    for sd, y in (("-y", -GY - 0.35), ("+y", GY + 0.35)):
        wall(L, (-GX, y), (9.0 if sd == "-y" else GX, y), COURSE * 12, COURSE * 13, sd, thick=1.0, solid=False, far=False)
    L.p.solid((9.0, -6.0, GATE_TOP - 14.0), (GX, GY, GATE_TOP))
    floor(L, -GX + SKIN, GX - SKIN, -GY + SKIN, GY - SKIN, GATE_TOP, keep=lambda x, y: not (x > 9.0 and y < -6.0))
    core(L, 9.0, GX - SKIN, -GY + SKIN, -6.0, lambda x: GATE_TOP - (x - 9.0) * 0.6 - 1.0)
    merlons(L, (-GX, GY), (GX, GY), GATE_TOP, "+y", 8, gone=(5,))
    merlons(L, (-GX, -GY), (9.0, -GY), GATE_TOP, "-y", 5, gone=(1,))
    merlons(L, (-GX, -GY + SKIN), (-GX, GY - SKIN), GATE_TOP, "-x", 6, gone=(3,))
    merlons(L, (GX, -4.0), (GX, GY - SKIN), GATE_TOP, "+x", 3)
    r = L.r
    tumble(L, 16, lambda: (r.uniform(12.0, GX + 8.0), -GY - r.uniform(1.0, 12.0), G0), size=(1.6, 4.0), solid_over=9.0)


# ---- the keep -----------------------------------------------------------------------
KH = KEEP / 2


def build_keep(L):
    L.p.ground = 0.0
    door = arch(0.0, DOOR_W, -9.0, KEEP_DOOR_SPRING)

    def top(seed, lo, hi):
        return step_top(lambda u: lo + (hi - lo) * (0.5 + 0.5 * noise.noise(Vector((u * 0.07, seed, 1.1))))
                        + 2.0 * noise.noise(Vector((u * 0.35, seed, 7.0))))
    z1 = COURSE * 17
    tops = {"-y": top(1.3, 22.0, 37.0), "+y": top(5.1, 15.0, 30.0), "-x": top(9.7, 24.0, 37.0), "+x": top(3.9, 15.0, 26.0)}
    tower_walls(L, KEEP_FOOT, z1, holes={s: [door] for s in ("-y", "+y", "-x", "+x")}, tops=tops, ragged=True, half=KH,
                thick=KEEP_T)
    for sd in ("-y", "+y", "-x", "+x"):
        door_rings(L, sd, 0.0, KEEP_DOOR_SPRING, DOOR_W, half=KH, thick=KEEP_T)


# ---- the cistern ----------------------------------------------------------------------
CX, CY = BAY * 2, BAY       # half sizes: 37 by 18.5
CIST_H = COURSE * 6
PIER_Y = 9.7
PIER = 3.4
PIERS_X = (-24.6, -12.3, 0.0, 12.3, 24.6)
RIBS = (1, 3)               # piers (of PIERS_X) whose rib across the nave stands


def build_cistern(L):
    L.p.ground = 0.0

    def rag(seed, lo):
        return step_top(lambda u: lo + (CIST_H - lo) * (0.6 + 0.6 * noise.noise(Vector((u * 0.09, seed, 2.0)))))
    breach = lambda y: CIST_FOOT if abs(y - 1.0) < 11.5 else CIST_H - 2.0 * abs(noise.noise(Vector((y * 0.3, 1.0, 1.0))))
    notch = lambda y: COURSE * 2 if abs(y + 0.5) < 8.6 else CIST_H - 2.0 * abs(noise.noise(Vector((y * 0.3, 6.0, 1.0))))
    tops = {"-y": rag(1.0, 8.0), "+y": rag(4.0, 6.0), "-x": step_top(breach), "+x": step_top(notch)}
    sk = 1.5
    for sd, sign in (("-y", -1), ("+y", 1)):
        wall(L, (-CX, sign * CY), (CX, sign * CY), CIST_FOOT, CIST_H, sd, thick=sk, top=tops[sd], body=3.0, ragged=True)
        wall(L, (-CX + 3.0, sign * (CY - 3.0)), (CX - 3.0, sign * (CY - 3.0)), CIST_FOOT, CIST_H, "+y" if sign < 0 else "-y",
             thick=sk, top=tops[sd], solid=False, far=False, ragged=True)
    for sd, sign in (("-x", -1), ("+x", 1)):
        wall(L, (sign * CX, -CY + 3.0), (sign * CX, CY - 3.0), CIST_FOOT, CIST_H, sd, thick=sk, top=tops[sd], body=3.0,
             ragged=tops[sd] is not None)
        wall(L, (sign * (CX - 3.0), -CY + 3.0), (sign * (CX - 3.0), CY - 3.0), CIST_FOOT, CIST_H, "+x" if sign < 0 else "-x",
             thick=sk, top=tops[sd], solid=False, far=False, ragged=tops[sd] is not None)
    r = L.r
    spring = COURSE * 5
    for i, x in enumerate(PIERS_X):
        whole = i in RIBS
        for sy in (-1, 1):
            n = 5 if whole else r.randint(1, 3)
            n += 2
            for k in range(n + 1):
                zl = CIST_FOOT + k * COURSE
                hide = ["-z"] + (["+z"] if k < n else [])
                L.block((x, sy * PIER_Y, zl + COURSE / 2), (PIER, PIER, COURSE - T.JOINT), hide=hide, edge=k == n and not whole)
            L.p.solid((x - PIER / 2, sy * PIER_Y - PIER / 2, CIST_FOOT), (x + PIER / 2, sy * PIER_Y + PIER / 2, CIST_FOOT + (n + 1) * COURSE))
            L.p.far_box((x, sy * PIER_Y, CIST_FOOT + (n + 1) * COURSE / 2), (PIER, PIER, (n + 1) * COURSE))
        if whole:
            ring(L, (x - PIER / 2, 0.0), 0.0, spring, PIER_Y - PIER / 2, "-x", PIER, t=2.0, proud=0.0, solid=True)


# ---- builds ---------------------------------------------------------------------------
JOBS = {
    "citadel_wall": (build_wall, 101),
    "citadel_wall_gallery": (build_gallery, 102),
    "citadel_wall_end": (build_end, 103),
    "citadel_wall_low": (build_low, 104),
    "citadel_rubble": (build_rubble, 105),
    "citadel_postern": (build_postern, 106),
    "citadel_blocking": (build_blocking, 107),
    "citadel_tower_base": (build_tower_base, 108),
    "citadel_tower_storey": (build_tower_storey, 109),
    "citadel_tower_crown": (build_tower_crown, 110),
    "citadel_tower_ruin": (build_tower_ruin, 111),
    "citadel_tower_split": (build_tower_split, 112),
    "citadel_bastion": (lambda L: build_bastion(L, False), 113),
    "citadel_bastion_tall": (lambda L: build_bastion(L, True), 114),
    "citadel_gate": (build_gate, 115),
    "citadel_keep": (build_keep, 116),
    "citadel_cistern": (build_cistern, 117),
}
# Pieces small enough to draw near until the far LOD.
NO_MID = {"citadel_blocking"}

if __name__ in ("__main__", "temple_breaks_source"):
    for name, (job, seed) in JOBS.items():
        if only is None or only == name:
            for mid in (False, True):
                if mid and (name in NO_MID or __name__ != "__main__"):
                    continue
                L = Lay(name, seed, mid)
                job(L)
                L.export()
