"""The temple kit's ruined harbour (lane harbour): the colossus astride its
mouth, the colossus' fallen head and arm, the moles, the quay and the ship
sheds, in the kit's stone (temple_lib). scripts/endless/harbour_site.gd lays
them in the cove on the inland sea's west shore. The columns standing in the
water are the kit's own.

    python tools/blender.py run art/blender/temple_kit/harbour_build.py [-- --only=harbour_colossus]

Every piece's origin is at the sea's level (Blender z 0), so the site lays
them all at LandField.SEA_Y. Blender frame, z up; Godot (x, y, z) = Blender
(x, z, -y).

Pieces:
- `harbour_colossus`: the figure broken off at the chest, a foot on each of
  two pedestals FOOT_X either side of the origin along x, facing -y (out to
  sea). Built in courses of stone like a column's drums, weathered. The
  pedestals stand from the bed (z -36) to PED_TOP; between them the mouth is
  2 * (FOOT_X - PED_HALF) clear at the water, the crotch ~CROTCH up.
- `harbour_colossus_head`: the head lying on its right cheek, the neck's
  break toward +x; origin under its middle at the bed it rests on.
- `harbour_colossus_arm`: the right arm, broken at the shoulder (origin),
  lying along +x, the hand open, palm down.
- `harbour_mole`, `harbour_mole_broken`: MOLE_L of mole along x, MOLE_W wide,
  its deck MOLE_TOP over the water, the parapet on its -y (seaward) side, down
  to z -30. The broken one has its deck and parapet thrown down on one side.
- `harbour_quay`, `harbour_quay_steps`: a BAY of quay wall along x, its face
  on y 0 looking -y (the water), QUAY_TOP over it, 12 m deep behind; the
  second with a flight of steps down into the water.
- `harbour_shed`, `harbour_shed_broken`: one ship shed: a barrel-vaulted
  slip SHED_P wide (its left wall included; the clear SHED_CLEAR) and SHED_L
  long along +y, from the sea end (y 0, floor SHED_Z0 under the water) up to
  the land end (floor SHED_Z1). Open at both ends. Side by side they share
  walls; `harbour_shed_end` is the last one's right wall. The broken one's
  vault has fallen in over its middle.
Each has a mid LOD (<piece>_mid.glb).
"""

import math
import sys

from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

BAY = T.BAY

# ---- the colossus' numbers --------------------------------------------------------
FOOT_X = 50.0               # each foot's middle, either side of the origin along x
PED_TOP = 9.0               # the pedestals' top over the water
PED_HALF = 13.0             # half the pedestal across x
PED_Y = (-19.0, 13.0)       # the pedestal along y (the foot points -y)
PED_FOOT = -36.0
HIP_X = 11.0
HIP_Z = 72.0
CROTCH = 58.0

# ---- the moles, quay and sheds -------------------------------------------------------
MOLE_L = 19.0
MOLE_W = 14.0
MOLE_TOP = 3.5
MOLE_FOOT = -30.0
QUAY_TOP = 2.5
QUAY_D = 12.0
QUAY_FOOT = -14.0
SHED_P = 1.5 * BAY          # 27.75: one shed's pitch
SHED_WT = 3.0               # its wall
SHED_CLEAR = SHED_P - SHED_WT
SHED_L = 3.0 * BAY          # 55.5
SHED_Z0 = -4.5              # the floor at the sea end
SHED_Z1 = 3.5               # and at the land end
SHED_SPRING = 10.0          # the vault's springing over the floor
SHED_R = SHED_CLEAR / 2     # 12.375
SHED_SHELL = 1.6
SHED_FILL = 18.0            # the fill between the vaults, over the floor
SHED_XC = (-SHED_P / 2 + SHED_WT + SHED_P / 2) / 2   # the vault's axis (x), 1.5
SHED_SEGS = 6
SHED_FOOT = -12.0


def shed_floor(y):
    return SHED_Z0 + (SHED_Z1 - SHED_Z0) * y / SHED_L


SHED_SLOPE = math.atan((SHED_Z1 - SHED_Z0) / SHED_L)


class Lay:
    """Blocks for one piece at one LOD: the near's cut and chipped, the mid's
    plain boxes; `mid` also coarsens the lofted stone. Layout draws come from
    `r`, never the piece's rng, so both LODs lay the same stones."""

    def __init__(self, name, seed, mid):
        self.p = T.Piece(name, seed=seed)
        self.p.ground = 0.0
        self.r = T.random.Random(seed * 31 + 7)
        self.mid = mid

    def block(self, c, s, chips=1, hide=(), edge=False, **kw):
        if self.mid:
            self.p.block(c, s, bevel=0.0, chips=0, jitter=0.0, far=False, hide=hide,
                         **{k: v for k, v in kw.items() if k in ("yaw", "tilt", "tone")})
            return
        if edge:
            self.p.block(c, s, chips=4, chip_depth=(0.3, 0.9), far=False, hide=hide, **kw)
        else:
            self.p.block(c, s, chips=chips, far=False, hide=hide, **kw)

    def run(self, a0, a1, z0, z1, depth, at=0.0, along="x", maxlen=4.2, keep=None, chips=1,
            hide=("-z", "+z"), tilt=None, zf=None):
        """A course's blocks along x (or y) from a0 to a1, centred on `at`
        across; `keep(a, z)` drops a block. `zf(a)` lifts each block (a
        sloping course) and `tilt` leans it along y."""
        if a1 - a0 < 0.45:
            return
        n = max(1, math.ceil((a1 - a0) / maxlen))
        cuts = [a0] + [a0 + (a1 - a0) * (i + self.r.uniform(-0.18, 0.18)) / n for i in range(1, n)] + [a1]
        zc = (z0 + z1) / 2
        for a, b in zip(cuts, cuts[1:]):
            ac = (a + b) / 2
            if keep is not None and not keep(ac, zc):
                continue
            edge = keep is not None and not (keep(a - 1.5, zc) and keep(b + 1.5, zc) and keep(ac, z1 + 1.2))
            lift = zf(ac) if zf is not None else 0.0
            ln = b - a - T.JOINT
            if along == "x":
                c, s = (ac, at, zc + lift), (ln, depth, z1 - z0 - T.JOINT)
            else:
                c, s = (at, ac, zc + lift), (depth, ln / (math.cos(tilt) if tilt else 1.0), z1 - z0 - T.JOINT)
            kw = {"tilt": (tilt, 0.0)} if tilt else {}
            self.block(c, s, chips=self.r.randint(0, chips), hide=hide, edge=edge, **kw)

    def far_boxes(self, boxes):
        for lo, hi in boxes:
            self.p.far_box(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2),
                           (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))

    def solids(self, boxes):
        for lo, hi in boxes:
            self.p.solid(lo, hi)

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


# ---- lofted stone: the figure's limbs ----------------------------------------------
class Path:
    """A smooth line through keys [(point, rx, ry)], by arc length."""

    def __init__(self, keys):
        self.keys = [(Vector(k[0]), k[1], k[2]) for k in keys]
        self.table = []
        acc = 0.0
        prev = None
        n = 60 * (len(keys) - 1)
        for i in range(n + 1):
            u = (len(keys) - 1) * i / n
            p = self.pos(u)
            if prev is not None:
                acc += (p - prev).length
            self.table.append((acc, u))
            prev = p
        self.length = acc

    def pos(self, u):
        k = self.keys
        n = len(k)
        i = min(int(u), n - 2)
        f = u - i
        p0, p1, p2, p3 = k[max(i - 1, 0)][0], k[i][0], k[i + 1][0], k[min(i + 2, n - 1)][0]
        f2, f3 = f * f, f * f * f
        return 0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2
                      + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f3)

    def u_at(self, s):
        s = max(0.0, min(self.length, s))
        lo, hi = 0, len(self.table) - 1
        while hi - lo > 1:
            m = (lo + hi) // 2
            if self.table[m][0] < s:
                lo = m
            else:
                hi = m
        (s0, u0), (s1, u1) = self.table[lo], self.table[hi]
        return u0 if s1 <= s0 else u0 + (u1 - u0) * (s - s0) / (s1 - s0)

    def at(self, s):
        u = self.u_at(s)
        c = self.pos(u)
        du = 0.01
        t = (self.pos(min(u + du, len(self.keys) - 1)) - self.pos(max(u - du, 0.0))).normalized()
        i = min(int(u), len(self.keys) - 2)
        f = u - i
        f = f * f * (3 - 2 * f)
        rx = self.keys[i][1] + (self.keys[i + 1][1] - self.keys[i][1]) * f
        ry = self.keys[i][2] + (self.keys[i + 1][2] - self.keys[i][2]) * f
        return c, t, rx, ry


def loft(bm, path, side, segs, rng, course=None, sub=1, step=2.5, bump=None, rough=0.3, end="open",
         start="open", jag=(0.0, 0.0), matrix=None, inner=False, seed=0.0, seams=4, bites=0.25, groove=0.32):
    """A tube of stone round `path`: elliptic sections (rx along `side` made
    square to the path, ry across both), `bump(s, a, p)` metres out at arc
    length s, angle a (0 along side, pi/2 along path x side), point p. With
    `course` (m) it is laid in courses like a column's drums: a groove ring
    between them painted dark, each its own shade and shift, a few vertical
    joints and the odd bitten edge. `jag` (start, end) metres of ragged
    break at each end; `start` / `end`: open, flat (a cap) or broken (a
    ragged cap, pale). Returns the last ring's vertices."""
    kind, tone, broke = T._layers(bm)
    deep = T._deep(bm)
    side = Vector(side)
    L = path.length
    rows = []           # (s, groove, course index)
    if course:
        K = max(1, round(L / course))
        cl = L / K
        e = min(0.2, cl * 0.1)
        for k in range(K):
            a = k * cl
            rows.append((a, True, k))
            for j in range(sub + 1):
                rows.append((a + e + (cl - 2 * e) * j / sub, False, k))
        rows.append((L, True, K - 1))
        info = []
        for k in range(K):
            off = rng.uniform(0, math.tau)
            info.append({"tone": rng.uniform(0.86, 1.07), "shift": (rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08)),
                         "seams": [off + math.tau * i / seams + rng.uniform(-0.3, 0.3) for i in range(seams)],
                         "bites": [(rng.uniform(0, math.tau), rng.uniform(0.15, 0.4), rng.uniform(0.3, 0.9))
                                   for _ in range(1 if rng.random() < bites else 0)]})
    else:
        n = max(2, math.ceil(L / step))
        for i in range(n + 1):
            rows.append((L * i / n, False, i))
        info = [{"tone": rng.uniform(0.9, 1.04), "shift": (0, 0), "seams": [], "bites": []} for _ in range(n + 1)]
    j0, j1 = jag
    trim0 = lambda a: j0 * (0.5 + 0.5 * noise.noise(Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, seed + 4.1)))) if j0 else 0.0
    trim1 = lambda a: j1 * (0.55 + 0.45 * noise.noise(Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, seed + 7.3)))) if j1 else 0.0
    # Rows wholly inside a ragged end are dropped; a ragged ring closes each end.
    rows = [r for r in rows if r[0] >= j0 and r[0] <= L - j1]
    if j0:
        rows.insert(0, (None, False, rows[0][2] if rows else 0))
    if j1:
        rows.append((-1.0, False, rows[-1][2] if rows else 0))
    seam_tol = math.tau / segs * 0.5

    def ring(sv, groove, k):
        out = []
        centre = None
        for i in range(segs):
            a = math.tau * i / segs
            s = sv
            ragged = False
            if sv is None:
                s, ragged = trim0(a), True
            elif sv == -1.0:
                s, ragged = L - trim1(a), True
            else:
                s = max(s, trim0(a))
                s = min(s, L - trim1(a))
            c, t, rx, ry = path.at(s)
            x = (side - t * side.dot(t)).normalized()
            y = t.cross(x)
            if centre is None:
                centre = c
            inf = info[min(k, len(info) - 1)]
            dx, dy = inf["shift"]
            e = x * (rx * math.cos(a)) + y * (ry * math.sin(a))
            d = e.normalized()
            p = c + e + x * dx + y * dy
            dr = 0.0
            if bump is not None:
                dr += bump(s, a, p)
            if rough:
                q = p + Vector((seed, seed * 0.7, 0.0))
                dr += rough * noise.noise(q * 0.09) + rough * 0.35 * noise.noise(q * 0.37)
            br = 1.0 if ragged else 0.0
            dp = 0.0
            if course:
                if groove:
                    dr -= groove
                    dp = 1.0
                for sa in inf["seams"]:
                    if abs(math.atan2(math.sin(a - sa), math.cos(a - sa))) < seam_tol:
                        dr -= 0.14
                        dp = max(dp, 0.6)
                for (ba, hw, bd) in inf["bites"]:
                    da = abs(math.atan2(math.sin(a - ba), math.cos(a - ba)))
                    w = max(0.0, 1.0 - da / hw)
                    if w > 0:
                        dr -= bd * w ** 0.7
                        br = max(br, w)
            if inner:
                dr = -dr
            pt = p + d * dr
            if matrix is not None:
                pt = matrix @ pt
            v = bm.verts.new(pt)
            v[broke] = br
            v[deep] = dp
            out.append(v)
        if matrix is not None:
            centre = matrix @ centre
        return out, centre

    def face(vs, k, centre_a, centre_b, kd):
        f = bm.faces.new(vs)
        f[kind] = kd
        f[tone] = info[min(k, len(info) - 1)]["tone"]
        f.normal_update()
        mid = sum((v.co for v in vs), Vector()) / len(vs)
        axis = (centre_a + centre_b) / 2
        out = (f.normal.dot(mid - axis) > 0)
        if out == inner:
            f.normal_flip()
        return f

    prev = None
    last = None
    first = None
    for (sv, groove, k) in rows:
        cur, c = ring(sv, groove, k)
        if prev is not None:
            pv, pc, pg = prev
            kd = T.JOINTFACE if (groove or pg) else T.FACE
            for i in range(segs):
                j = (i + 1) % segs
                face((pv[i], pv[j], cur[j], cur[i]), k, pc, c, kd)
        else:
            first = (cur, c)
        prev = (cur, c, groove)
        last = (cur, c)

    def cap(rv, c, s_in, kind_cap, at_end):
        # The axis' far point: past the cap (outward) for orientation.
        cs, ct, rx, ry = path.at(max(0.0, min(L, s_in)))
        if kind_cap == "flat":
            cv = bm.verts.new(matrix @ cs if matrix is not None else cs)
            for i in range(segs):
                j = (i + 1) % segs
                f = bm.faces.new((rv[i], rv[j], cv))
                f[kind] = T.JOINTFACE
                f[tone] = 0.9
                f.normal_update()
                want = ct if at_end else -ct
                if matrix is not None:
                    want = matrix.to_3x3() @ want
                if f.normal.dot(want) < 0:
                    f.normal_flip()
            return
        # Broken: a ragged heap of a surface, a ring in, then the middle.
        mid = []
        for i in range(segs):
            a = math.tau * i / segs
            p0 = rv[i].co
            pc = matrix @ cs if matrix is not None else cs
            dz = (rng.uniform(-0.6, 0.9)) * (1 if at_end else -1)
            q = pc + (p0 - pc) * rng.uniform(0.45, 0.65)
            w = ct if matrix is None else matrix.to_3x3() @ ct
            q = q + w * dz * 1.5
            v = bm.verts.new(q)
            v[broke] = 1.0
            mid.append(v)
        w = ct if matrix is None else matrix.to_3x3() @ ct
        pc = matrix @ cs if matrix is not None else cs
        cv = bm.verts.new(pc + w * (rng.uniform(-0.5, 0.5)))
        cv[broke] = 1.0
        want = w if at_end else -w
        for i in range(segs):
            j = (i + 1) % segs
            for vs in ((rv[i], rv[j], mid[j], mid[i]), (mid[i], mid[j], cv)):
                f = bm.faces.new(vs)
                f[kind] = T.BROKEN
                f[tone] = 0.95
                f.normal_update()
                if f.normal.dot(want) < 0:
                    f.normal_flip()
    if end != "open" and last is not None:
        cap(last[0], last[1], L - j1 * 0.8, end, True)
    if start != "open" and first is not None:
        cap(first[0], first[1], j0 * 0.8, start, False)
    return last[0] if last else []


def bridge(bm, a, b, want):
    """Quads between two rings of the same count, facing `want`."""
    kind, tone, broke = T._layers(bm)
    n = len(a)
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((a[i], a[j], b[j], b[i]))
        f[kind] = T.JOINTFACE
        f[tone] = 0.9
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()


def gauss(x, w):
    return math.exp(-(x / w) ** 2)


def ang(a, b):
    return abs(math.atan2(math.sin(a - b), math.cos(a - b)))


# ---- the colossus ------------------------------------------------------------------
def leg_path(sx):
    """sx: -1 the left (x < 0), 1 the right. From inside the foot up past the hip."""
    ax, az = sx * (FOOT_X - 0.8), PED_TOP + 6.0
    hx = sx * HIP_X
    keys = []
    for t, rx, ry, fwd in ((0.0, 3.4, 3.4, 0.0), (0.1, 3.7, 4.0, 0.2), (0.28, 4.9, 5.6, 0.9), (0.42, 4.3, 4.6, 0.3),
                           (0.5, 4.5, 4.9, -0.5), (0.58, 5.4, 5.8, -0.2), (0.78, 7.0, 7.4, 0.0), (1.0, 8.6, 8.8, 0.0),
                           (1.1, 8.4, 8.4, 0.0)):
        x = ax + (hx - ax) * t
        z = az + (HIP_Z - az) * t
        y = 2.0 - 2.0 * t - 3.0 * math.sin(math.pi * min(t, 1.0)) + fwd
        keys.append(((x, y, z), rx, ry))
    return Path(keys)


def foot_path(sx):
    fx = sx * FOOT_X
    keys = [((fx, 9.5, PED_TOP + 2.8), 3.2, 2.8), ((fx, 6.0, PED_TOP + 4.4), 4.5, 4.4),
            ((fx + sx * 0.3, -1.0, PED_TOP + 3.3), 5.2, 3.3), ((fx + sx * 0.4, -8.5, PED_TOP + 2.0), 5.6, 2.1),
            ((fx + sx * 0.4, -11.5, PED_TOP + 1.5), 5.3, 1.6)]
    return Path(keys)


TOES = [(-3.7, 1.35, 1.25, 6.0), (-1.4, 1.0, 0.95, 5.2), (0.6, 0.95, 0.9, 4.6), (2.4, 0.85, 0.8, 4.0), (3.9, 0.8, 0.75, 3.2)]


def torso_path():
    # From under the kilt (its flat cap closes the kilt's underside) up past
    # the shoulders, broken off over them.
    keys = [((0, 0.6, 48.5), 4.0, 3.0), ((0, 0.5, 51.5), 12.5, 8.0), ((0, 0.4, 56.0), 18.4, 11.6), ((0, 0.4, 63.0), 19.6, 12.0), ((0, 0.6, 70.0), 19.4, 11.8), ((0, 0.3, 78.0), 17.0, 10.6),
            ((0, 0, 84.0), 15.6, 10.0), ((0, -0.2, 92.0), 17.2, 10.6), ((0, -0.4, 100.0), 19.6, 11.2), ((0, -0.3, 107.0), 22.4, 11.4),
            ((0, 0.0, 112.0), 23.6, 10.8), ((0, 0.4, 116.5), 19.0, 9.6)]
    return Path(keys)


def torso_bump(s, a, p):
    z = p.z
    # a: 0 along +x, pi/2 along +y (the back), -pi/2 the front.
    back = math.sin(a)
    out = 0.0
    out -= 0.9 * gauss(ang(a, math.pi / 2), 0.08) * (1.0 if z > 74 else 0.0)                            # the spine
    for px in (-1, 1):
        aa = math.atan2(-0.9, 0.45 * px)
        out += 2.2 * gauss(ang(a, aa), 0.38) * gauss(z - 101.0, 4.5)                                   # the chest
        out -= 0.8 * gauss(ang(a, aa), 0.5) * gauss(z - 95.5, 0.9)                                     # its lower edge
        ab = math.atan2(0.9, 0.5 * px)
        out += 1.3 * gauss(ang(a, ab), 0.4) * gauss(z - 104.0, 5.0)                                    # the shoulder blades
        for k in range(3):                                                                             # the belly's blocks
            out += 0.45 * gauss(ang(a, -math.pi / 2 + px * 0.16), 0.11) * gauss(z - (86.0 + 3.2 * k), 1.0)
    out -= 0.8 * gauss(ang(a, -math.pi / 2), 0.06) * gauss(z - 82.5, 1.0)                               # the navel
    out -= 0.6 * gauss(ang(a, -math.pi / 2), 0.05) * gauss(z - 97.0, 5.0)                               # the breastbone
    for px in (-1, 1):                                                                                 # the collarbones
        out += 0.9 * gauss(ang(a, math.atan2(-0.55, 0.85 * px)), 0.3) * gauss(z - 110.5, 1.2)
    return out


def kilt_path(r_in=0.0):
    keys = [((0, 0, 86.0), 16.6 - r_in, 11.0 - r_in), ((0, 0, 78.0), 18.8 - r_in, 12.2 - r_in), ((0, 0, 68.0), 20.6 - r_in, 13.2 - r_in),
            ((0, 0, 60.0), 21.6 - r_in, 13.8 - r_in), ((0, 0, 56.5), 21.9 - r_in, 14.0 - r_in)]
    return Path(keys)


def kilt_bump(s, a, p):
    pleat = abs(math.sin(14 * a))
    return 0.75 * pleat * min(1.0, s / 8.0)


def neck_path():
    return Path([((0, 0.6, 110.0), 8.6, 8.8), ((0, 0.2, 117.0), 8.2, 8.4), ((0, -0.4, 122.0), 7.6, 8.0)])


def arm_stump_path(sx):
    """The arm left standing (sx: its side): from inside the shoulder down
    and out to its break above the elbow."""
    return Path([((sx * 18.0, 0.4, 110.0), 7.6, 7.6), ((sx * 23.5, 0.6, 107.0), 7.4, 7.2),
                 ((sx * 26.5, 0.8, 99.0), 6.4, 6.2), ((sx * 28.0, 0.4, 88.0), 5.6, 5.6)])


def arm_socket_path(sx):
    """The fallen arm's side: the shoulder's round broken off short."""
    return Path([((sx * 18.0, 0.4, 110.0), 7.6, 7.6), ((sx * 23.0, 0.5, 108.5), 7.4, 7.2), ((sx * 25.5, 0.6, 106.5), 6.8, 6.6)])


def leg_bump_for(path):
    L = path.length

    def bump(s, a, p):
        f = -math.pi / 2
        out = 0.0
        out += 1.5 * gauss(ang(a, f), 0.45) * gauss(s - 0.455 * L, 2.2)              # the knee
        out -= 0.5 * gauss(ang(a, f), 0.9) * gauss(s - 0.40 * L, 1.5)               # under it
        out += 1.4 * gauss(ang(a, -f), 0.7) * gauss(s - 0.30 * L, 5.0)               # the calf
        out += 1.1 * gauss(ang(a, f + 0.35), 0.45) * gauss(s - 0.66 * L, 6.0)        # the thigh's front
        out += 0.8 * gauss(ang(a, -f), 0.6) * gauss(s - 0.75 * L, 6.0)               # its back
        out -= 0.6 * gauss(ang(a, -f), 0.25) * gauss(s - 0.455 * L, 1.6)             # behind the knee
        return out
    return bump


def belt_path():
    return Path([((0, 0, 86.5), 16.0, 10.6), ((0, 0, 84.0), 16.9, 11.2), ((0, 0, 81.5), 16.5, 10.9)])


def colossus_figure(lay, bm, segs, course, rough, far=False):
    r = lay.r
    sd = 0.0
    kw = dict(course=None if far else course, step=8.0 if far else 3.0, rough=0.0 if far else rough, groove=0.2)
    for sx in (-1, 1):
        sd += 3.1
        lp = leg_path(sx)
        loft(bm, lp, (1, 0, 0), segs, r, sub=2, seed=sd, seams=2, bump=None if far else leg_bump_for(lp), **kw)
        loft(bm, foot_path(sx), (1, 0, 0), segs, r, sub=1, seed=sd + 1, start="flat", end="open", **kw)
        if not far:
            for (ox, rx, rz, ln) in TOES:
                tx = sx * FOOT_X + sx * ox + sx * 0.4
                y0 = -10.0
                p = Path([((tx, y0, PED_TOP + rz), rx, rz), ((tx, y0 - ln * 0.6, PED_TOP + rz * 0.95), rx * 1.02, rz),
                          ((tx, y0 - ln, PED_TOP + rz * 0.75), rx * 0.8, rz * 0.7)])
                loft(bm, p, (1, 0, 0), max(10, segs // 4), r, step=1.0, rough=0.06, end="flat", seed=sd + ox)
    tp = torso_path()
    loft(bm, tp, (1, 0, 0), segs + (segs // 2), r, sub=2, bump=None if far else torso_bump, start="flat",
         end="broken", jag=(0.0, 0.0 if far else 2.5), seed=11.0, seams=2, **kw)
    loft(bm, neck_path(), (1, 0, 0), segs // 2 + 4, r, sub=1, end="broken", jag=(0.0, 0.0 if far else 3.5), seed=12.0, seams=2, **kw)
    # The arm left standing on the figure's left (+x), broken above the elbow;
    # the right one (fallen, in the shallows) broken off at the shoulder.
    loft(bm, arm_stump_path(1), (0, 1, 0), segs // 2 + 6, r, sub=1, end="broken", jag=(0.0, 0.0 if far else 3.0), seed=14.0,
         seams=2, **kw)
    loft(bm, arm_socket_path(-1), (0, 1, 0), segs // 2 + 6, r, sub=1, end="broken", jag=(0.0, 0.0 if far else 2.0), seed=15.0,
         seams=2, **kw)
    outer = loft(bm, kilt_path(), (1, 0, 0), segs * 2 if not far else segs, r, sub=2, bump=None if far else kilt_bump,
                 seed=13.0, end="open" if not far else "flat", jag=(0.0, 0.0 if far else 2.2), **kw)
    if not far:
        inner = loft(bm, kilt_path(1.3), (1, 0, 0), segs * 2, r, sub=1, step=3.0, course=None, rough=0.1, inner=True,
                     end="open", jag=(0.0, 2.2), seed=13.0)
        bridge(bm, outer, inner, Vector((0, 0, -1)))
        loft(bm, belt_path(), (1, 0, 0), segs + segs // 2, r, course=None, step=1.2, rough=0.15, seed=17.0)


def pedestal(lay, sx):
    fx = sx * FOOT_X
    x0, x1 = fx - PED_HALF, fx + PED_HALF
    y0, y1 = PED_Y
    yc, yd = (y0 + y1) / 2, y1 - y0
    # Below the low water, few big stones.
    for (a, b) in ((PED_FOOT, -20.0), (-20.0, -8.0)):
        lay.run(x0, x1, a, b, yd, at=yc, maxlen=9.0, chips=0)
    zs = [-8.0 + (PED_TOP - 1.4 + 8.0) * i / 10 for i in range(11)]
    for i, (a, b) in enumerate(zip(zs, zs[1:])):
        jut = 0.8 if i == len(zs) - 2 else 0.0
        lay.run(x0 - jut, x1 + jut, a, b, yd + 2 * jut, at=yc, maxlen=4.6, chips=2, hide=("-z", "+z"))
    # The top: slabs round the foot, some lifted, the cornice under them.
    lay.run(x0 - 0.8, x1 + 0.8, PED_TOP - 1.4, PED_TOP, yd + 1.6, at=yc, maxlen=5.5, chips=3, hide=("-z",))


def build_colossus(lay):
    segs = 22 if lay.mid else 56
    colossus_figure(lay, lay.p.near, segs, None if lay.mid else 4.2, 0.35)
    if not lay.mid:
        colossus_figure(lay, lay.p.far, 12, None, 0.0, far=True)
    for sx in (-1, 1):
        pedestal(lay, sx)
        fx = sx * FOOT_X
        if not lay.mid:
            lay.p.far_box((fx, sum(PED_Y) / 2, (PED_FOOT + PED_TOP) / 2), (2 * PED_HALF + 1.6, PED_Y[1] - PED_Y[0] + 1.6, PED_TOP - PED_FOOT))
    # The solids: pedestals, feet, the legs in slabs, the kilt and the torso.
    boxes = []
    for sx in (-1, 1):
        fx = sx * FOOT_X
        boxes.append(((fx - PED_HALF - 0.8, PED_Y[0] - 0.8, PED_FOOT), (fx + PED_HALF + 0.8, PED_Y[1] + 0.8, PED_TOP)))
        boxes.append(((fx - 6.2, -16.5, PED_TOP), (fx + 6.2, 10.0, PED_TOP + 8.8)))
        lp = leg_path(sx)
        n = 11
        for i in range(n):
            s0, s1 = lp.length * i / n, lp.length * (i + 1) / n
            c0, _, rx0, ry0 = lp.at(s0)
            c1, _, rx1, ry1 = lp.at(s1)
            rr = max(rx0, ry0, rx1, ry1) * 0.92
            boxes.append(((min(c0.x, c1.x) - rr, min(c0.y, c1.y) - rr, min(c0.z, c1.z)),
                          (max(c0.x, c1.x) + rr, max(c0.y, c1.y) + rr, max(c0.z, c1.z))))
    for (z0, z1, rx, ry) in ((48.5, 52.0, 12.5, 8.0), (52.0, 55.0, 17.5, 11.5), (55.0, 60.0, 21.0, 13.5), (60.0, 68.0, 21.0, 13.4), (68.0, 78.0, 20.0, 12.8), (78.0, 87.0, 17.5, 11.5),
                             (87.0, 96.0, 17.0, 10.8), (96.0, 104.0, 20.0, 11.6), (104.0, 112.0, 23.0, 11.2), (112.0, 117.0, 21.0, 10.0),
                             (117.0, 122.0, 8.0, 8.0)):
        boxes.append(((-rx, -ry, z0), (rx, ry, z1)))
    boxes.append(((19.0, -7.0, 86.0), (34.0, 7.5, 112.0)))
    boxes.append(((-31.0, -7.0, 100.0), (-19.0, 7.5, 116.0)))
    lay.solids(boxes)


# ---- the head --------------------------------------------------------------------
HEAD_H = 24.0


def head_path():
    keys = [((0, 0, -6.0), 6.0, 6.4), ((0, 0.5, 0.0), 6.6, 7.4), ((0, 0.2, 2.5), 7.0, 8.6), ((0, 0, 7.0), 7.6, 9.4),
            ((0, 0, 11.0), 8.0, 9.8), ((0, 0.2, 15.0), 8.2, 10.0), ((0, 0.4, 18.5), 7.9, 9.6), ((0, 0.6, 21.5), 6.6, 8.2),
            ((0, 0.6, 23.4), 4.0, 5.2), ((0, 0.6, 24.2), 1.0, 1.4)]
    return Path(keys)


def head_bump(s, a, p):
    z = p.z
    front = -math.pi / 2
    da = math.atan2(math.sin(a - front), math.cos(a - front))     # signed, + toward +x
    ad = abs(da)
    out = 0.0
    # The nose: from the bridge (z 14) out to its tip (z 8), its wings.
    if 6.4 < z < 14.5:
        prof = 2.9 * (1.0 - (z - 8.0) / 6.5) if z > 8.0 else 2.9 * (z - 6.4) / 1.6
        out += max(0.0, prof) * gauss(da, 0.11 + 0.02 * (14.5 - z) / 8)
        out += 0.6 * gauss(z - 7.6, 0.9) * gauss(ad - 0.2, 0.08)
    # The eyes' sockets, the lids' swell, the brow over them.
    for sgn in (-1, 1):
        out -= 1.6 * gauss(da - sgn * 0.42, 0.16) * gauss(z - 12.3, 1.5)
        out += 0.45 * gauss(da - sgn * 0.42, 0.11) * gauss(z - 12.0, 0.6)
    out += 0.9 * gauss(ad - 0.35, 0.35) * gauss(z - 14.6, 0.9)
    # Cheeks, mouth, lips, chin.
    out += 0.6 * gauss(ad - 0.62, 0.22) * gauss(z - 8.4, 2.0)
    out += 0.65 * gauss(da, 0.26) * gauss(z - 5.6, 0.55)
    out += 0.55 * gauss(da, 0.24) * gauss(z - 4.3, 0.5)
    out -= 0.7 * gauss(da, 0.30) * gauss(z - 4.95, 0.22)
    out += 1.0 * gauss(da, 0.32) * gauss(z - 1.9, 1.1)
    # Ears.
    for ea in (0.0, math.pi):
        out += 1.8 * gauss(ang(a, ea), 0.12) * gauss(z - 11.5, 2.4)
    # Hair: thick curls over the crown and back, a fringe of them on the brow.
    hair = 0.0
    if z > 16.0 or (z > 8.0 and ad > 1.25):
        hair = 1.0
    if z > 15.6 and ad < 1.25:
        hair = min(1.0, (z - 15.6) / 0.8)
    if hair > 0:
        q = Vector((math.cos(a) * 6.0, math.sin(a) * 6.0, z * 0.8))
        curl = abs(noise.noise(q * 0.55))
        out += hair * (1.1 + 1.3 * (1.0 - curl))
    # The neck narrows under the jaw at the back.
    if z < 2.0:
        out -= 1.2 * gauss(ad - math.pi, 1.0) * gauss(z - 0.5, 1.5)
    return out


def head_lie():
    # Laid on its right cheek: the head's +z (up) to +x... the neck toward -x
    # would bury the face; here the head's axis runs along +x (crown to +x),
    # its face turned up and to -y a little.
    # Rolled onto the back of the skull, so the face looks up (and a little
    # to -y): from the air and from the water it reads as a face.
    return (Matrix.Translation((0.0, 0.0, 6.5)) @ Matrix.Rotation(math.radians(-64.0), 4, "X")
            @ Matrix.Rotation(math.radians(90.0), 4, "Y") @ Matrix.Translation((0.0, 0.0, -9.0)))


def build_head(lay):
    m = head_lie()
    segs = 32 if lay.mid else 96
    loft(lay.p.near, head_path(), (1, 0, 0), segs, lay.r, course=None, sub=3, step=0.8,
         bump=head_bump, rough=0.25, start="broken", end="flat", jag=(3.0, 0.0), matrix=m, seed=21.0, bites=0.1)
    if not lay.mid:
        loft(lay.p.far, head_path(), (1, 0, 0), 14, lay.r, step=3.0, bump=head_bump, rough=0.0, start="flat",
             end="flat", matrix=m, seed=21.0)
    lay.solids([((-15.5, -12.0, -4.0), (15.5, 12.0, 18.5))])


# ---- the arm --------------------------------------------------------------------
def arm_path():
    keys = [((0, 0, 0), 7.2, 6.6), ((7, 0, 0.2), 6.0, 5.6), ((15, 0.3, 0.3), 5.6, 5.2), ((24, 0.8, 0.2), 4.4, 4.2),
            ((27, 1.0, 0.0), 4.5, 4.1), ((33, -1.8, -0.2), 4.7, 4.0), ((42, -6.0, -0.4), 3.7, 3.0),
            ((49, -9.2, -0.6), 2.3, 3.0), ((52, -10.6, -0.7), 1.9, 4.0), ((57, -12.8, -0.9), 1.8, 4.6)]
    return Path(keys)


def arm_bump(s, a, p):
    # a: 0 up (+z), pi/2 across. The biceps' swell, the elbow's point, the
    # forearm's muscle near the elbow.
    out = 1.3 * gauss(ang(a, 0.0), 0.7) * gauss(s - 13.0, 5.0)
    out += 1.2 * gauss(ang(a, math.pi), 0.4) * gauss(s - 27.0, 2.0)
    out += 1.0 * gauss(ang(a, 0.6), 0.6) * gauss(s - 34.0, 4.0)
    out -= 0.5 * gauss(s - 24.0, 1.5)
    return out


FINGERS = [(-2.9, 0.95, 7.0), (-0.95, 1.05, 8.0), (1.0, 1.0, 7.6), (2.9, 0.85, 6.0)]


def build_arm(lay):
    m = Matrix.Translation((0.0, 0.0, 1.5))
    segs = 20 if lay.mid else 56
    loft(lay.p.near, arm_path(), (0, 0, 1), segs, lay.r, course=None, sub=2, step=1.5,
         rough=0.3, start="broken", end="flat", jag=(4.0, 0.0), matrix=m, seed=31.0, seams=2, bump=arm_bump)
    if not lay.mid:
        loft(lay.p.far, arm_path(), (0, 0, 1), 10, lay.r, step=8.0, rough=0.0, start="flat", end="flat", matrix=m)
    # The hand's fingers, from the knuckles on, slightly curled; the thumb.
    hand = arm_path()
    c, t, rx, ry = hand.at(hand.length)
    side = Vector((0, 0, 1)).cross(t).normalized()
    for (o, rr, ln) in FINGERS:
        b = c + side * o
        keys = [(b - t * 1.0, rr * 1.1, rr), (b + t * ln * 0.5, rr, rr * 0.95), (b + t * ln + Vector((0, 0, -0.9)), rr * 0.8, rr * 0.75)]
        loft(lay.p.near, Path(keys), (0, 0, 1), 10 if lay.mid else 16, lay.r, step=1.2, rough=0.08, end="flat", matrix=m,
             seed=33.0 + o)
    tb = hand.at(hand.length - 5.0)[0] - side * 4.0
    keys = [(tb, 1.6, 1.3), (tb - side * 2.5 + t * 2.5, 1.35, 1.15), (tb - side * 3.6 + t * 5.5 + Vector((0, 0, -0.6)), 1.0, 0.9)]
    loft(lay.p.near, Path(keys), (0, 0, 1), 10 if lay.mid else 16, lay.r, step=1.2, rough=0.08, end="flat", matrix=m, seed=39.0)
    lay.solids([((-4.0, -7.0, -6.0), (27.0, 7.0, 8.0)), ((25.0, -12.0, -5.0), (48.0, 4.0, 6.0)),
                ((46.0, -20.0, -3.5), (66.0, -4.0, 3.0))])


# ---- the moles -------------------------------------------------------------------
def build_mole(lay, broken):
    h = MOLE_L / 2
    w = MOLE_W / 2
    gone = (lambda x, z: not (z > 0.8 and x + 2.5 * noise.noise(Vector((x * 0.2, z * 0.3, 2.2))) > -2.0)) if broken else None
    for (a, b) in ((MOLE_FOOT, -18.0), (-18.0, -9.0)):
        lay.run(-h, h, a, b, MOLE_W, maxlen=9.5, chips=0)
    zs = [-9.0, -7.3, -5.7, -4.2, -2.8, -1.4, 0.0, 1.2, 2.4]
    for (a, b) in zip(zs, zs[1:]):
        lay.run(-h, h, a, b, MOLE_W, maxlen=4.4, keep=gone, chips=2)
    # The deck: two rows of slabs, a kerb on the harbour side.
    for (y0, y1) in ((-w, -0.2), (-0.2, w - 1.0)):
        lay.run(-h, h, 2.4, MOLE_TOP, y1 - y0, at=(y0 + y1) / 2, maxlen=3.4, keep=gone, chips=2, hide=("-z",))
    lay.run(-h, h, 2.4, MOLE_TOP + 0.5, 1.0, at=w - 0.5, maxlen=2.8, keep=gone, chips=2, hide=("-z",))
    # The parapet on the seaward side, broken here and there.
    par = lambda x, z: noise.noise(Vector((x * 0.13, 7.7, 1.0))) > -0.25 and (gone is None or gone(x, 2.0))
    lay.run(-h, h, MOLE_TOP, MOLE_TOP + 1.3, 2.0, at=-w + 1.0, maxlen=3.6, keep=par, chips=2)
    par2 = lambda x, z: par(x, z) and noise.noise(Vector((x * 0.21, 3.3, 5.0))) > -0.1
    lay.run(-h, h, MOLE_TOP + 1.3, MOLE_TOP + 2.5, 2.0, at=-w + 1.0, maxlen=3.6, keep=par2, chips=3)
    r = lay.r
    if broken:
        # What fell: deck slabs and parapet stones tumbled off the seaward side.
        for i in range(9):
            x = r.uniform(-h + 2, 2.0)
            y = -w - r.uniform(1.0, 6.0)
            lay.block((x, y, r.uniform(-1.5, 0.3)), (r.uniform(2.2, 4.0), r.uniform(1.6, 3.0), r.uniform(1.0, 1.8)),
                      yaw=r.uniform(0, 3), tilt=(r.uniform(-0.5, 0.5), r.uniform(-0.4, 0.4)), chips=3)
    if not lay.mid:
        lay.far_boxes([((-h, -w, MOLE_FOOT), (h, w, MOLE_TOP if not broken else 0.8)), ((-h, -w, MOLE_TOP), (h, -w + 2.0, MOLE_TOP + 2.0))])
    if broken:
        lay.solids([((-h, -w, MOLE_FOOT), (h, w, 0.8)), ((-h, -w, 0.8), (-2.0, w, MOLE_TOP)),
                    ((-h, -w, MOLE_TOP), (-2.0, -w + 2.0, MOLE_TOP + 2.5))])
    else:
        lay.solids([((-h, -w, MOLE_FOOT), (h, w, MOLE_TOP)), ((-h, -w, MOLE_TOP), (h, -w + 2.0, MOLE_TOP + 2.5))])


# ---- the quay ------------------------------------------------------------------
def build_quay(lay, steps):
    h = BAY / 2
    yd = QUAY_D
    notch = (lambda x, z: not (abs(x) < 4.2 and z > -1.4)) if steps else None
    lay.run(-h, h, QUAY_FOOT, -5.0, yd, at=yd / 2, maxlen=9.0, chips=0)
    zs = [-5.0, -3.6, -2.3, -1.1, 0.1, 1.3, QUAY_TOP - 0.6]
    for (a, b) in zip(zs, zs[1:]):
        lay.run(-h, h, a, b, 3.0, at=1.5, maxlen=4.0, keep=notch, chips=2)
        lay.run(-h, h, a, b, yd - 3.0, at=3.0 + (yd - 3.0) / 2, maxlen=9.0, keep=notch, chips=0, hide=("-z", "+z"))
    # The coping: long stones along the face, then the paving behind.
    lay.run(-h, h, QUAY_TOP - 0.6, QUAY_TOP, 2.2, at=1.1, maxlen=3.2, keep=notch, chips=3, hide=("-z",))
    for (y0, y1) in ((2.2, 6.5), (6.5, yd)):
        lay.run(-h, h, QUAY_TOP - 0.6, QUAY_TOP - 0.05, y1 - y0, at=(y0 + y1) / 2, maxlen=3.6, keep=notch, chips=1, hide=("-z",))
    r = lay.r
    if steps:
        n = 8
        back = 7.5
        for i in range(n):
            zt = -1.4 + (i + 1) * (QUAY_TOP - 0.45 + 1.4) / n
            y0 = i * back / n
            lay.block((0.0, (y0 + back) / 2, (zt - 1.4) / 2), (8.36, back - y0 - 0.04, zt + 1.4), chips=1, hide=("-z",))
        lay.block((0.0, (back + yd) / 2, (QUAY_TOP - 1.4) / 2), (8.36, yd - back - 0.04, QUAY_TOP + 1.4), chips=1, hide=("-z",))
        lay.run(-4.2, 4.2, -5.0, -1.4, yd, at=yd / 2, maxlen=4.2, chips=0)
    else:
        # A bollard.
        lay.block((r.uniform(-5, 5), 2.6, QUAY_TOP + 0.7), (1.4, 1.4, 1.5), chips=3)
    if not lay.mid:
        lay.far_boxes([((-h, 0.0, QUAY_FOOT), (h, yd, QUAY_TOP))])
    lay.solids([((-h, 0.0, QUAY_FOOT), (h, yd, QUAY_TOP))])


# ---- the ship sheds ----------------------------------------------------------------
def build_shed(lay, broken):
    hp = SHED_P / 2
    xw0, xw1 = -hp, -hp + SHED_WT
    xc = SHED_XC
    R = SHED_R
    seg = SHED_L / SHED_SEGS
    tan_s = math.tan(SHED_SLOPE)
    fallen = (lambda y: 17.0 < y < 39.5) if broken else (lambda y: False)
    # The wall, in horizontal courses stepping up the slope, under a sloping impost.
    wall_side(lay, xw0, xw1, broken)
    # The floor: a sloping slip, plain under the water, paved above it.
    for i in range(SHED_SEGS):
        y0, y1 = i * seg, (i + 1) * seg
        yc = (y0 + y1) / 2
        zt = shed_floor(yc)
        if zt < -0.6:
            lay.block((xc, yc, (zt + SHED_FOOT) / 2), (SHED_CLEAR + 0.02, seg / math.cos(SHED_SLOPE), zt - SHED_FOOT),
                      chips=0, tilt=(SHED_SLOPE, 0.0), hide=("-z",))
        else:
            lay.block((xc, yc, (zt - 0.6 + SHED_FOOT) / 2), (SHED_CLEAR + 0.02, seg / math.cos(SHED_SLOPE), zt - 0.6 - SHED_FOOT),
                      chips=0, tilt=(SHED_SLOPE, 0.0), hide=("-z", "+z"))
            for k in range(4):
                xa = -hp + SHED_WT + SHED_CLEAR * k / 4
                for yy in (y0 + seg * 0.25, y0 + seg * 0.75):
                    lay.block((xa + SHED_CLEAR / 8, yy, shed_floor(yy) - 0.3 + lay.r.uniform(-0.05, 0.05)),
                              (SHED_CLEAR / 4 - 0.06, seg / 2 - 0.06, 0.6), tilt=(SHED_SLOPE + lay.r.uniform(-0.02, 0.02), 0.0),
                              chips=lay.r.randint(0, 2), hide=("-z",))
    # The vault: a shell of voussoir courses, the end rings proud.
    vault(lay, xc, R, fallen)
    # The fill between the vaults, both sides, up to SHED_FILL over the floor.
    band = [0.0, 1.6, 3.2, 4.8, 6.4, 8.0]
    ext = lambda hh: math.sqrt(max(0.0, (R + SHED_SHELL) ** 2 - hh * hh))
    keep_fill = lambda y, z: not fallen(y) and noise.noise(Vector((y * 0.12, z * 0.3, 4.0))) > -0.45 + 0.08 * z
    for (a, b) in zip(band, band[1:]):
        e = ext(b)
        for (x0, x1) in ((-hp, xc - e), (xc + e, hp)):
            if x1 - x0 < 0.4:
                continue
            lay.run(0.0, SHED_L, SHED_SPRING + a, SHED_SPRING + b, x1 - x0, at=(x0 + x1) / 2, along="y", maxlen=4.7,
                    keep=keep_fill if b > 3.3 else (lambda y, z: not fallen(y) or z < SHED_SPRING + 2.0),
                    chips=2, tilt=SHED_SLOPE, zf=shed_floor, hide=("-z",))
    r = lay.r
    if broken:
        for i in range(16):
            y = r.uniform(19.0, 38.0)
            x = xc + r.uniform(-9.0, 9.0)
            sz = r.uniform(1.2, 2.2)
            lay.block((x, y, shed_floor(y) + sz * 0.3), (r.uniform(2.0, 3.6), r.uniform(1.6, 3.0), sz), yaw=r.uniform(0, 3),
                      tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), chips=3)
    if not lay.mid:
        boxes = []
        for i in range(SHED_SEGS):
            y0, y1 = i * seg, (i + 1) * seg
            z0 = shed_floor(y0)
            boxes.append(((xw0, y0, SHED_FOOT), (xw1, y1, z0 + SHED_SPRING)))
            boxes.append(((xw1, y0, SHED_FOOT), (hp, y1, z0)))
            if not fallen((y0 + y1) / 2):
                boxes.append(((-hp, y0, z0 + SHED_SPRING), (xc - R * 0.55, y1, z0 + SHED_SPRING + 8.0)))
                boxes.append(((xc + R * 0.55, y0, z0 + SHED_SPRING), (hp, y1, z0 + SHED_SPRING + 8.0)))
                boxes.append(((-hp, y0, z0 + SHED_SPRING + 8.0), (hp, y1, z0 + SHED_SPRING + R + SHED_SHELL)))
        lay.far_boxes(boxes)
    lay.solids(shed_solids(broken, fallen))


def shed_solids(broken, fallen):
    hp = SHED_P / 2
    xw0, xw1 = -hp, -hp + SHED_WT
    xc, R = SHED_XC, SHED_R
    seg = SHED_L / SHED_SEGS
    out = []
    for i in range(SHED_SEGS):
        y0, y1 = i * seg, (i + 1) * seg
        zlo, zhi = shed_floor(y0), shed_floor(y1)
        out.append(((xw0, y0, SHED_FOOT), (xw1, y1, zhi + SHED_SPRING + 0.2)))
        out.append(((xw1, y0, SHED_FOOT), (hp, y1, zhi)))
        if fallen((y0 + y1) / 2):
            continue
        zs = zlo + SHED_SPRING
        for (a, b) in ((0.0, 4.0), (4.0, 7.0), (7.0, 9.4), (9.4, 11.0)):
            hw = math.sqrt(max(0.0, R * R - b * b))
            out.append(((-hp, y0, zs + a), (xc - hw, y1, zs + b)))
            out.append(((xc + hw, y0, zs + a), (hp, y1, zs + b)))
        out.append(((-hp, y0, zs + 11.0), (hp, y1, zhi + SHED_SPRING + R + SHED_SHELL)))
    return out


def wall_side(lay, x0, x1, broken, top=None):
    """A shed's wall from x0 to x1: courses stepping up with the slope, under
    a sloping impost at the vault's springing (or to `top` over the floor)."""
    seg = SHED_L / SHED_SEGS
    yc = (x0 + x1) / 2
    wt = x1 - x0
    for i in range(SHED_SEGS):
        y0, y1 = i * seg, (i + 1) * seg
        lid = shed_floor(y1) + (top if top is not None else SHED_SPRING - 1.4)
        lay.block((yc, (y0 + y1) / 2, (SHED_FOOT - 6.0) / 2), (wt, seg - T.JOINT, -6.0 - SHED_FOOT), chips=0,
                  hide=("-z", "+z"))
        z = -6.0
        while z < lid - 0.3:
            zt = min(z + 1.8, lid)
            lay.run(y0, y1, z, zt, wt, at=yc, along="y", maxlen=4.8, chips=2)
            z = zt
    if top is None:
        lay.run(0.0, SHED_L, SHED_SPRING - 1.4, SHED_SPRING + 0.2, wt + 0.8, at=yc, along="y", maxlen=4.7, chips=2,
                tilt=SHED_SLOPE, zf=shed_floor, hide=("-z",))


def vault(lay, xc, R, fallen):
    """The barrel vault over the slip: a shell SHED_SHELL thick in voussoir
    courses (joints painted dark), springing at shed_floor + SHED_SPRING,
    and a ring of proud voussoirs at each open end."""
    bm = lay.p.near
    kind, tone, broke = T._layers(bm)
    deep = T._deep(bm)
    r = lay.r
    nv = 13
    nring = 12
    mid = lay.mid
    ths = []
    for k in range(nv):
        a0, a1 = math.pi * k / nv, math.pi * (k + 1) / nv
        if mid:
            ths += [(a0, False)]
        else:
            e = 0.05
            ths += [(a0, True), (a0 + e, False), (a1 - e, False)]
    ths.append((math.pi, True if not mid else False))
    ys = []
    seg = SHED_L / nring
    for k in range(nring):
        b0, b1 = k * seg, (k + 1) * seg
        if mid:
            ys += [(b0, False)]
        else:
            ys += [(b0, True), (b0 + 0.12, False), (b1 - 0.12, False)]
    ys.append((SHED_L, not mid))
    tones = {}

    def pt(th, y, rad):
        zs = shed_floor(y) + SHED_SPRING
        return Vector((xc - rad * math.cos(th), y, zs + rad * math.sin(th)))

    for surface, rad0, sgn in (("in", R, 1.0), ("out", R + SHED_SHELL, -1.0)):
        grid = []
        for (y, gy) in ys:
            row = []
            for (th, gt) in ths:
                g = gy or gt
                rad = rad0 + (sgn * 0.12 if g and not mid else 0.0)
                rad += 0.05 * noise.noise(Vector((th * 3.0, y * 0.3, rad0)))
                v = bm.verts.new(pt(th, y, rad))
                v[deep] = 1.0 if g and not mid else 0.0
                row.append(v)
            grid.append(row)
        for i in range(len(ys) - 1):
            ym = (ys[i][0] + ys[i + 1][0]) / 2
            if fallen(ym):
                continue
            for j in range(len(ths) - 1):
                key = (int(ym // seg), int(((ths[j][0] + ths[j + 1][0]) / 2) // (math.pi / nv)))
                if key not in tones:
                    tones[key] = r.uniform(0.86, 1.06)
                f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
                gj = ys[i][1] or ys[i + 1][1] or ths[j][1] or ths[j + 1][1]
                f[kind] = T.JOINTFACE if gj and not mid else T.FACE
                f[tone] = tones[key]
                f.normal_update()
                th = (ths[j][0] + ths[j + 1][0]) / 2
                axis = Vector((xc, ym, shed_floor(ym) + SHED_SPRING))
                outward = f.normal.dot(pt(th, ym, rad0) - axis) > 0
                if outward != (surface == "out"):
                    f.normal_flip()
    # The proud rings at the open ends (and where the vault broke off).
    ends = [0.0, SHED_L]
    if fallen(SHED_L / 2):
        ends += [17.0 - 0.6, 39.5 + 0.6]
    for y in ends:
        dy = 1.2 if y < SHED_L / 2 else -1.2
        if 10.0 < y < 45.0:
            dy = -dy
        rm = R + SHED_SHELL / 2
        broken_ring = 10.0 < y < 45.0
        for k in range(nv):
            if broken_ring and r.random() < 0.35:
                continue
            th = math.pi * (k + 0.5) / nv
            c = pt(th, y + dy / 2, rm)
            wdt = 2.0 * (R + SHED_SHELL + 0.3) * math.tan(math.pi / nv / 2) - 0.05
            lay.block(tuple(c), (wdt, abs(dy), SHED_SHELL + 0.5), tilt=(0.0, th - math.pi / 2), chips=1)


def build_shed_end(lay):
    hp = SHED_P / 2
    wall_side(lay, hp, hp + SHED_WT, False, top=SHED_FILL)
    seg = SHED_L / SHED_SEGS
    if not lay.mid:
        lay.far_boxes([((hp, i * seg, SHED_FOOT), (hp + SHED_WT, (i + 1) * seg, shed_floor((i + 1) * seg) + SHED_FILL)) for i in range(SHED_SEGS)])
    lay.solids([((hp, i * seg, SHED_FOOT), (hp + SHED_WT, (i + 1) * seg, shed_floor((i + 1) * seg) + SHED_FILL)) for i in range(SHED_SEGS)])


JOBS = {
    "harbour_colossus": lambda: both("harbour_colossus", 81, build_colossus),
    "harbour_colossus_head": lambda: both("harbour_colossus_head", 82, build_head),
    "harbour_colossus_arm": lambda: both("harbour_colossus_arm", 83, build_arm),
    "harbour_mole": lambda: both("harbour_mole", 84, lambda lay: build_mole(lay, False)),
    "harbour_mole_broken": lambda: both("harbour_mole_broken", 85, lambda lay: build_mole(lay, True)),
    "harbour_quay": lambda: both("harbour_quay", 86, lambda lay: build_quay(lay, False)),
    "harbour_quay_steps": lambda: both("harbour_quay_steps", 87, lambda lay: build_quay(lay, True)),
    "harbour_shed": lambda: both("harbour_shed", 88, lambda lay: build_shed(lay, False)),
    "harbour_shed_broken": lambda: both("harbour_shed_broken", 89, lambda lay: build_shed(lay, True)),
    "harbour_shed_end": lambda: both("harbour_shed_end", 90, build_shed_end),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
