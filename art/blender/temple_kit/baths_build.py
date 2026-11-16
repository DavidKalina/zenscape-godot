"""The temple kit's bath house (lane baths): a domed rotunda with its crown
broken open, a barrel-vaulted hall off its east arch and a dry sunken pool
under the dome, in the kit's stone (temple_lib).
scripts/endless/baths_site.gd lays them.

    python tools/blender.py run art/blender/temple_kit/baths_build.py [-- --only=baths_dome]

Frame (Blender, z up; Godot (x, y, z) = Blender (x, z, -y)): the rotunda's
pieces share one origin, the rotunda's centre on its floor (z 0, the paved
platform's top; the ground outside lies 2.5-4.5 m lower). Azimuth from +x
toward +y. The hall runs along +x from the east arch.

- `baths_rotunda`: the drum, RI inside radius, WT thick, from its footing to
  the dome's springing (SPRING): coursed wedge blocks, four arches
  (ARCH_AZ: east into the hall, north, south-west toward the agora, south;
  ARCH_HW*2 wide, ARCH_SPR + ARCH_HW to the crown), a breach to the
  south-east (the wall down from the floor to ~23 m), the cornice and step
  rings over it, and steps down outside three arches (STEPS).
- `baths_dome`: the shell on the drum, rings of wedge blocks RI inside,
  DOME_T0..DOME_T1 thick, the crown gone in a ragged hole (hole_r) with a
  notch down the north-east side.
- `baths_floor`: the rotunda's floor: rings of paving round the pool, the
  pool's three steps down to its floor POOL_D under the paving.
- `baths_hall`, `baths_hall_broken`, `baths_hall_end`: one bay (HL long) of
  the hall: two walls with an arched window each, the barrel vault, the
  floor. Origin on the floor at the bay's middle. The broken one has lost
  its vault's crown; the end one its vault (but the north springers), its
  south wall and its east floor edge.
- `baths_rubble`: a heap of fallen shell blocks; `baths_fragment`: two
  shell blocks still joined, lying. Origin on the floor.

Solids: the curved stone is cut into axis-aligned boxes on a grid
(voxel_solids) from the same block tables the meshes are laid from, so the
hole, the arches, the breach and the lost vault are open to the flight. The
site lays these pieces unturned.
"""

import math
import sys

import bmesh
import numpy as np
from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

RI = 33.0                   # the rotunda's inside radius
WT = 4.0                    # the drum's wall
RO = RI + WT
RM = RI + WT / 2
SPRING = 38.0               # the dome springs here, over the floor
FOOT = -9.0
Z0 = -4.0                   # the coursed wall's foot
CH = 2.0                    # a course
NC = int((SPRING - Z0) / CH)
ARCH_HW = 10.0              # an arch's half width
ARCH_SPR = 14.0             # its springing over the floor (crown at 24)
ARCH_RING = 1.6
ARCH_AZ = (0.0, math.pi / 2, math.radians(218.0), math.pi * 1.5)   # east (the hall), north, south-west, south
# Steps down outside an arch: (its index, treads under the landing, a tread, the half width).
STEPS = ((1, 4, 1.8, 13.0), (2, 3, 1.15, 10.5), (3, 4, 1.8, 13.0))
STEP_H = 0.9
LANDING = (35.7, 37.6)
VOUSSOIRS = 19
BREACH_AZ = math.radians(318.0)
STEP_RINGS = tuple((r0, r1, SPRING + a, SPRING + b) for (r0, r1, a, b) in ((35.2, 37.6, 0.0, 2.2), (35.0, 36.9, 2.2, 4.4), (34.6, 36.2, 4.4, 6.4)))
DOME_T0, DOME_T1 = 3.2, 2.2
NR = 16
DPHI = (math.pi / 2) / NR
HOLE_C = (-2.0, 1.0)
NOTCH_AZ = math.radians(55.0)
POOL_D = 1.6
POOL_R = (9.5, 12.5, 15.5, 18.5)   # the pool's floor, then its steps' outer radii
PAVE_R1 = 35.6

HL = 16.0                   # a hall bay
HH = HL / 2
HW = 11.0                   # the hall's half width inside
HT = 3.0                    # its walls
HALL_TOP = 22.0
VSPR = 15.0                 # the vault's springing
VR = HW                     # its radius (crown at 26)
VT = 1.8
NV = 14
WIN_HW = 5.75
WIN_SILL = 2.0
WIN_SPR = 8.0
WIN_RING = 1.2


DARK = 3                    # a face kind of this script's: the dark inside a wall or under a floor


class Piece(T.Piece):
    """temple_lib's Piece, its DARK faces painted the crevice's dark whatever
    way they look (no moss, damp or streaks: nothing lives in there)."""

    def paint(self, bm, far=False):
        col = super().paint(bm, far=far)
        kind = bm.faces.layers.int.get("kind")
        dark = T.srgb_to_linear(tuple(x * 0.8 for x in T.CREVICE)) + (1.0,)
        for f in bm.faces:
            if f[kind] == DARK:
                for loop in f.loops:
                    loop[col] = dark
        return col


def angdiff(a, b):
    return math.atan2(math.sin(a - b), math.cos(a - b))


def nz(x, y, z):
    return noise.noise(Vector((x, y, z)))


def scratch_block(p, size, warp=None, matrix=None, **kw):
    """A temple_lib block made at the origin, each vertex moved by `warp`
    (in place), then placed by `matrix`."""
    keep = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    try:
        p.block((0, 0, 0), size, far=False, **kw)
    finally:
        p.near = keep
    if warp is not None:
        for v in tmp.verts:
            warp(v.co)
    T._append(p.near, tmp, matrix)
    tmp.free()


def far_face(p, pts, hint, tone=1.0):
    """A far LOD polygon through pts, facing along `hint`."""
    bm = p.far
    k, t, b = T._layers(bm)
    pts = [Vector(q) for q in pts]
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
    if n.dot(Vector(hint)) < 0.0:
        pts.reverse()
    f = bm.faces.new([bm.verts.new(q) for q in pts])
    f[k] = T.FACE
    f[t] = tone


def core(p, pts, tone=0.38):
    """A dark sheet through pts inside a through-block's thickness, seen from
    both sides: what shows (and stops the sun) where a joint or a chipped
    corner would open the wall to the sky."""
    bm = p.near
    k, t, b = T._layers(bm)
    for order in (pts, pts[::-1]):
        f = bm.faces.new([bm.verts.new(q) for q in order])
        f[k] = DARK
        f[t] = tone


def shade(p, fn):
    """Each near face's tone times fn(centre, normal): the inside's shade."""
    bm = p.near
    bm.normal_update()
    k, t, b = T._layers(bm)
    for f in bm.faces:
        f[t] *= fn(f.calc_center_median(), f.normal)


class Slots:
    """Rows of (a0, a1, kept) intervals: which block a point lies in."""

    def __init__(self, wrap=True):
        self.rows = {}
        self.wrap = wrap

    def add(self, row, a0, a1, kept):
        self.rows.setdefault(row, []).append((a0, a1, kept))

    def kept(self, row, a, default=False):
        for (a0, a1, kept) in self.rows.get(row, ()):
            if self.wrap:
                d = (a - a0) % math.tau
                if d < (a1 - a0):
                    return kept
            elif a0 <= a < a1:
                return kept
        return default


def voxel_solids(p, fn, lo, hi, cell, order=(2, 0, 1)):
    """The flight's solids from fn(x, y, z) -> stone?, sampled at the centres
    of a grid of `cell` from lo to hi, merged into boxes (first along
    order[0])."""
    n = [int(round((hi[i] - lo[i]) / cell[i])) for i in range(3)]
    g = np.zeros(n, dtype=bool)
    for i in range(n[0]):
        x = lo[0] + (i + 0.5) * cell[0]
        for j in range(n[1]):
            y = lo[1] + (j + 0.5) * cell[1]
            for k in range(n[2]):
                if fn(x, y, lo[2] + (k + 0.5) * cell[2]):
                    g[i, j, k] = True
    used = np.zeros(n, dtype=bool)
    count = 0
    for idx in np.argwhere(g):
        if used[tuple(idx)]:
            continue
        a = [int(v) for v in idx]
        b = list(a)
        for ax in order:
            while b[ax] + 1 < n[ax]:
                sl = [slice(a[d], b[d] + 1) for d in range(3)]
                sl[ax] = b[ax] + 1
                sl = tuple(sl)
                if g[sl].all() and not used[sl].any():
                    b[ax] += 1
                else:
                    break
        used[tuple(slice(a[d], b[d] + 1) for d in range(3))] = True
        p.solid([lo[d] + a[d] * cell[d] for d in range(3)], [lo[d] + (b[d] + 1) * cell[d] for d in range(3)])
        count += 1
    return count


# ---- round work: a block bent round the axis ---------------------------------
def round_block(p, r0, r1, z0, z1, a_lo, a_hi, **kw):
    """A block between radii r0..r1 and heights z0..z1 whose ends are the
    azimuths a_lo(r) and a_hi(r) (functions of the radius: a radial joint is
    a constant, an arch's jamb leans). Its own frame: +x toward a_lo, +y out,
    +z up."""
    rm = (r0 + r1) / 2
    L = (a_hi(rm) - a_lo(rm)) * rm
    size = (L - T.JOINT, r1 - r0, z1 - z0 - T.JOINT)
    zc = (z0 + z1) / 2

    def warp(co):
        s = 0.5 - co.x / L
        r = rm + co.y
        az = a_lo(r) + (a_hi(r) - a_lo(r)) * s
        co.x, co.y, co.z = r * math.cos(az), r * math.sin(az), zc + co.z

    scratch_block(p, size, warp=warp, **kw)


def const(a):
    return lambda r: a


def ring_course(p, r0, r1, z0, z1, n, off=0.0, far=True, tone=None, **kw):
    """A whole ring of n round blocks."""
    r = p.rng
    for j in range(n):
        a0 = off + j * math.tau / n
        a1 = a0 + math.tau / n
        round_block(p, r0 + r.uniform(-0.05, 0.05), r1 + r.uniform(-0.05, 0.05), z0, z1, const(a0), const(a1),
                    chips=r.randint(0, 1), tone=tone, **kw)
    if far:
        far_ring(p, r0, r1, z0, z1)


def far_ring(p, r0, r1, z0, z1, seg=28, top=True, inner=False):
    for j in range(seg):
        a0, a1 = j * math.tau / seg, (j + 1) * math.tau / seg
        c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
        am = (a0 + a1) / 2
        out = (math.cos(am), math.sin(am), 0)
        far_face(p, [(r1 * c0, r1 * s0, z0), (r1 * c1, r1 * s1, z0), (r1 * c1, r1 * s1, z1), (r1 * c0, r1 * s0, z1)], out)
        if inner:
            far_face(p, [(r0 * c0, r0 * s0, z0), (r0 * c1, r0 * s1, z0), (r0 * c1, r0 * s1, z1), (r0 * c0, r0 * s0, z1)],
                     (-out[0], -out[1], 0))
        if top:
            far_face(p, [(r0 * c0, r0 * s0, z1), (r0 * c1, r0 * s1, z1), (r1 * c1, r1 * s1, z1), (r1 * c0, r1 * s0, z1)], (0, 0, 1))


# ---- the rotunda's drum ---------------------------------------------------------
def breach(az, z):
    """The wall is down here (round BREACH_AZ)."""
    if z < 0.0 or z > 23.5:
        return False
    d = abs(angdiff(az, BREACH_AZ))
    hw = math.radians(17.0) * (1.0 - (z / 23.5) ** 1.6) + math.radians(3.0) * nz(az * 4.0, z * 0.25, 7.7)
    low = 1.5 + 2.0 * nz(az * 6.0, 1.3, 0.2)
    return d < hw and z > low


def arch_half(zt):
    """An arch's opening (with its ring) at a course whose top is zt: its
    half width, 0 for none."""
    if zt <= 0.01:
        return 0.0
    if zt <= ARCH_SPR:
        return ARCH_HW
    d = zt - ARCH_SPR
    e = ARCH_HW + ARCH_RING
    return math.sqrt(e * e - d * d) if d < e else 0.0


def in_arch(x, y, z):
    """Inside one of the four arches' openings."""
    if z <= 0.0:
        return False
    for a in ARCH_AZ:
        ux, uy = math.cos(a), math.sin(a)
        if x * ux + y * uy <= 0.0:
            continue
        across = -x * uy + y * ux
        if z <= ARCH_SPR:
            if abs(across) < ARCH_HW:
                return True
        elif across * across + (z - ARCH_SPR) ** 2 < ARCH_HW * ARCH_HW:
            return True
    return False


def voussoir(p, arch_az, theta, chips):
    """One voussoir of an arch through the drum, at ring angle theta."""
    rm = ARCH_HW + ARCH_RING / 2
    tang = rm * math.pi / VOUSSOIRS - T.JOINT
    a = rm * math.cos(theta)
    along = (math.sqrt(RI * RI - a * a) + math.sqrt(RO * RO - a * a)) / 2
    ux, uy = math.cos(arch_az), math.sin(arch_az)
    frame = Matrix(((uy, ux, 0, ux * along), (-ux, uy, 0, uy * along), (0, 0, 1, 0), (0, 0, 0, 1)))
    m = frame @ Matrix.Translation((a, 0.0, ARCH_SPR + rm * math.sin(theta))) @ Matrix.Rotation(-theta, 4, "Y")

    def warp(co):
        co.z *= (rm + co.x) / rm

    scratch_block(p, (ARCH_RING - 0.02, WT + 0.5, tang), warp=warp, matrix=m, chips=chips, chip_depth=(0.1, 0.35))


def drum_layout(rng):
    """The drum's courses: [(k, zb, zt, a_lo fn, a_hi fn, mid a0, mid a1, kept, first, last)]."""
    out = []
    for k in range(NC):
        zb = Z0 + k * CH
        zt = zb + CH
        ah = arch_half(zt)
        spans = []
        if ah > 0.0:
            for i, a in enumerate(ARCH_AZ):
                nxt = ARCH_AZ[(i + 1) % len(ARCH_AZ)] + (math.tau if i == len(ARCH_AZ) - 1 else 0.0)
                lo = (lambda r, a=a, ah=ah: a + math.asin(min(1.0, ah / r)))
                hi = (lambda r, nxt=nxt, ah=ah: nxt - math.asin(min(1.0, ah / r)))
                spans.append((lo, hi, True))
        else:
            off = rng.uniform(0.0, 0.2)
            spans.append((const(off), const(off + math.tau), False))
        for (lo, hi, open_) in spans:
            a0, a1 = lo(RM), hi(RM)
            n = max(1, round((a1 - a0) * RM / 5.0))
            ts = [0.0]
            for j in range(n):
                t = (j + (0.5 if k % 2 else 1.0) + rng.uniform(-0.12, 0.12)) / n
                if 0.03 < t < 0.97:
                    ts.append(t)
            ts.append(1.0)
            for j in range(len(ts) - 1):
                first, last = j == 0 and open_, j == len(ts) - 2 and open_
                b0 = const(a0 + (a1 - a0) * ts[j]) if not (j == 0 and open_) else lo
                b1 = const(a0 + (a1 - a0) * ts[j + 1]) if not (j == len(ts) - 2 and open_) else hi
                m0, m1 = b0(RM), b1(RM)
                am, zc = (m0 + m1) / 2, (zb + zt) / 2
                kept = not breach(am, zc)
                out.append((k, zb, zt, b0, b1, m0, m1, kept, first, last))
    return out


def build_rotunda(seed):
    p = Piece("baths_rotunda", seed=seed)
    p.ground = -3.0
    r = p.rng
    slots = Slots()
    rows = drum_layout(r)
    for (k, zb, zt, b0, b1, m0, m1, kept, first, last) in rows:
        slots.add(k, m0, m1, kept)
    # The footing under the courses: plain, mostly under the ground.
    n = 24
    for j in range(n):
        round_block(p, RI - 0.3, RO + 0.3, FOOT, Z0, const(j * math.tau / n), const((j + 1) * math.tau / n), bevel=0.0,
                    chips=0, jitter=0.0, hide=("+x", "-x", "-z"))
    for (k, zb, zt, b0, b1, m0, m1, kept, first, last) in rows:
        if not kept:
            continue
        am, zc = (m0 + m1) / 2, (zb + zt) / 2
        w = (m1 - m0) * 0.75
        edge = breach(am + w, zc) or breach(am - w, zc) or breach(am, zc + CH) or breach(am, zc - CH)
        dr0, dr1 = r.uniform(-0.12, 0.1), r.uniform(-0.1, 0.22)
        if abs(zb - 26.0) < 0.01 or abs(zt - SPRING) < 0.01:
            dr0, dr1 = -0.35, 0.4      # a string course over the arches, another under the dome
        if edge:
            round_block(p, RI + dr0, RO + dr1, zb, zt, b0, b1, chips=3, chip_depth=(0.3, 0.8))
        else:
            a0c, a1c = b0(RM), b1(RM)
            core(p, [(RM * math.cos(a0c), RM * math.sin(a0c), zb), (RM * math.cos(a1c), RM * math.sin(a1c), zb),
                     (RM * math.cos(a1c), RM * math.sin(a1c), zt), (RM * math.cos(a0c), RM * math.sin(a0c), zt)])
            # round_block's +x faces a_lo: a span's first block shows its a_lo end.
            hide = ["-z", "+z"] + ([] if first else ["+x"]) + ([] if last else ["-x"])
            round_block(p, RI + dr0, RO + dr1, zb, zt, b0, b1, chips=r.randint(0, 1), hide=tuple(hide),
                        seen=("+y", "-y") + (("+x",) if first else ()) + (("-x",) if last else ()))
        # The far LOD: the block's two faces.
        for rad, sgn in ((RO, 1.0), (RI, -1.0)):
            a0, a1 = b0(rad), b1(rad)
            far_face(p, [(rad * math.cos(a0), rad * math.sin(a0), zb), (rad * math.cos(a1), rad * math.sin(a1), zb),
                         (rad * math.cos(a1), rad * math.sin(a1), zt), (rad * math.cos(a0), rad * math.sin(a0), zt)],
                     (sgn * math.cos(am), sgn * math.sin(am), 0))
    far_ring(p, RI, RO, FOOT, Z0, top=False)
    # The arches' rings.
    for a in ARCH_AZ:
        for i in range(VOUSSOIRS):
            voussoir(p, a, math.pi * (i + 0.5) / VOUSSOIRS, chips=r.randint(0, 2))
    # The cornice and the step rings on the dome's haunch.
    for i, (r0, r1, z0, z1) in enumerate(STEP_RINGS):
        ring_course(p, r0, r1, z0, z1, 46 - 2 * i, off=r.uniform(0, 0.1), hide=("-y", "-z", "+x", "-x"), seen=("+y", "+z"))
    # Steps down outside three arches: a landing, then treads.
    for (ai, treads, tread, half0) in STEPS:
        a = ARCH_AZ[ai]
        ux, uy = math.cos(a), math.sin(a)
        frame = Matrix(((ux, -uy, 0, 0), (uy, ux, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))   # x along (out), y across
        for i in range(treads + 1):
            x0 = LANDING[1] + tread * (i - 1) if i else LANDING[0]
            x1 = LANDING[1] + tread * i
            top = -STEP_H * i
            half = half0 + 0.4 * i
            y = -half
            while y < half - 0.3:
                L = min(r.uniform(3.2, 5.0), half - y)
                if half - (y + L) < 1.5:
                    L = half - y
                scratch_block(p, (x1 - x0, L - T.JOINT, 3.4),
                              matrix=frame @ Matrix.Translation(((x0 + x1) / 2, y + L / 2, top - 1.7 + r.uniform(-0.03, 0.02))),
                              chips=r.randint(0, 2), hide=("-z", "-x"))
                y += L
            m = frame @ Matrix.Translation(((x0 + x1) / 2, 0, top - 1.7))
            tmp = Piece("tmp")
            tmp.far_box((0, 0, 0), (x1 - x0, 2 * half, 3.4))
            T._append(p.far, tmp.far, m)
            tmp.near.free()
            tmp.far.free()

    # The inside in shade.
    def inside(c, nrm):
        rad = math.hypot(c.x, c.y)
        if rad < 1e-3 or c.z < 0.0:
            return 1.0
        inward = -(nrm.x * c.x + nrm.y * c.y) / rad
        if rad < RI + 0.7 and inward > 0.3:
            return 0.8
        return 1.0

    shade(p, inside)

    def stone(x, y, z):
        rad = math.hypot(x, y)
        if z >= SPRING:
            return any(z0 <= z < z1 and r0 <= rad <= r1 for (r0, r1, z0, z1) in STEP_RINGS)
        if rad > RO:
            # The steps.
            for (ai, treads, tread, half0) in STEPS:
                a = ARCH_AZ[ai]
                along = x * math.cos(a) + y * math.sin(a)
                across = -x * math.sin(a) + y * math.cos(a)
                if along < LANDING[0] or along > LANDING[1] + tread * treads:
                    continue
                i = 0 if along < LANDING[1] else int((along - LANDING[1]) / tread) + 1
                if abs(across) < half0 + 0.4 * i and z < -STEP_H * i:
                    return True
            return False
        if rad < RI:
            return False
        if in_arch(x, y, z):
            return False
        if z >= 0.0:
            return slots.kept(int((z - Z0) // CH), math.atan2(y, x) % math.tau, True)
        return True

    n = voxel_solids(p, stone, (-48.0, -48.0, -6.0), (48.0, 48.0, 45.0), (1.5, 1.5, 1.5))
    print("baths_rotunda voxel boxes", n)
    p.export()


# ---- the dome ---------------------------------------------------------------------
def hole_r(az):
    n = nz(math.cos(az) * 1.7 + 3.1, math.sin(az) * 1.7, 0.4)
    d = abs(angdiff(az, NOTCH_AZ))
    notch = 9.5 * max(0.0, 1.0 - d / math.radians(17.0))
    return 15.5 + 3.0 * n + notch


def in_hole(x, y):
    dx, dy = x - HOLE_C[0], y - HOLE_C[1]
    return math.hypot(dx, dy) < hole_r(math.atan2(dy, dx))


def build_dome(seed):
    p = Piece("baths_dome", seed=seed)
    p.ground = -100.0
    r = p.rng
    slots = Slots()
    C = Vector((0, 0, SPRING))
    for i in range(NR):
        p0, p1 = i * DPHI, (i + 1) * DPHI
        pm = (p0 + p1) / 2
        t = DOME_T0 + (DOME_T1 - DOME_T0) * pm / (math.pi / 2)
        Rm = RI + t / 2
        rho = Rm * math.cos(pm)
        if rho < 6.0:
            break
        n = max(8, round(math.tau * rho / 4.6))
        off = r.uniform(0.0, math.tau / n)
        H = Rm * DPHI
        for j in range(n):
            a0 = off + j * math.tau / n
            a1 = a0 + math.tau / n
            am = (a0 + a1) / 2
            cx, cy = rho * math.cos(am), rho * math.sin(am)
            kept = not in_hole(cx, cy)
            slots.add(i, a0 % math.tau, (a0 % math.tau) + math.tau / n, kept)
            if not kept:
                continue
            # At the hole's edge: a neighbour gone.
            L = rho * math.tau / n
            edge = False
            rho_up = Rm * math.cos(pm + DPHI)
            for (qa, qr) in ((am + math.tau / n, rho), (am - math.tau / n, rho), (am, rho_up), (am + 0.5 * math.tau / n, rho_up),
                             (am - 0.5 * math.tau / n, rho_up)):
                if in_hole(qr * math.cos(qa), qr * math.sin(qa)):
                    edge = True
            tt = t + r.uniform(-0.12, 0.12)

            def warp(co, pm=pm, Rm=Rm, am=am, rho=rho):
                ph = pm + co.z / Rm
                d = Rm + co.y
                az = am - co.x / rho
                co.x, co.y, co.z = d * math.cos(ph) * math.cos(az), d * math.cos(ph) * math.sin(az), SPRING + d * math.sin(ph)

            if edge:
                scratch_block(p, (L - T.JOINT, tt, H - T.JOINT), warp=warp, chips=3, chip_depth=(0.3, 0.9))
            else:
                dm = RI + t / 2
                core(p, [(dm * math.cos(ph) * math.cos(az), dm * math.cos(ph) * math.sin(az), SPRING + dm * math.sin(ph))
                         for (az, ph) in ((a0, p0), (a1, p0), (a1, p1), (a0, p1))])
                scratch_block(p, (L - T.JOINT, tt, H - T.JOINT), warp=warp, chips=r.randint(0, 1),
                              hide=("+x", "-x", "+z", "-z"), seen=("+y", "-y"))
            # The far LOD: its outer and inner faces.
            for d, sgn in ((RI + t, 1.0), (RI, -1.0)):
                pts = []
                for (az, ph) in ((a0, p0), (a1, p0), (a1, p1), (a0, p1)):
                    pts.append((d * math.cos(ph) * math.cos(az), d * math.cos(ph) * math.sin(az), SPRING + d * math.sin(ph)))
                far_face(p, pts, (sgn * math.cos(am), sgn * math.sin(am), sgn * math.tan(pm)))
    rings = max(slots.rows) + 1

    # The inside in shade, lighter toward the hole.
    def inside(c, nrm):
        d = c - C
        dist = d.length
        if dist > RI + 0.6 or nrm.dot(d) / dist > -0.3:
            return 1.0
        e = max(0.0, min(1.0, (c.z - SPRING) / 26.0))
        return 0.76 + 0.2 * e * e

    shade(p, inside)

    def stone(x, y, z):
        if z < SPRING:
            return False
        d = math.sqrt(x * x + y * y + (z - SPRING) ** 2)
        if d < RI:
            return False
        ph = math.asin((z - SPRING) / d)
        i = int(ph / DPHI)
        if i >= rings:
            return False
        pm = (i + 0.5) * DPHI
        t = DOME_T0 + (DOME_T1 - DOME_T0) * pm / (math.pi / 2)
        if d > RI + t:
            return False
        return slots.kept(i, math.atan2(y, x) % math.tau, False)

    n = voxel_solids(p, stone, (-37.5, -37.5, SPRING), (37.5, 37.5, SPRING + 36.0), (1.5, 1.5, 1.5), order=(0, 1, 2))
    print("baths_dome voxel boxes", n)
    p.export()


# ---- the rotunda's floor and the pool ------------------------------------------------
def ring_slabs(p, r0, r1, ztop, thick, seg=4.2, lost=None, heave=None, hide=("-z",), seen=None, tone=None, chips=1,
               bevel=T.BEVEL, jitter=0.012, dz=0.03, kind=T.FACE):
    r = p.rng
    rm = (r0 + r1) / 2
    n = max(6, round(math.tau * rm / seg))
    off = r.uniform(0.0, math.tau / n)
    for j in range(n):
        a0 = off + j * math.tau / n
        a1 = a0 + math.tau / n
        am = (a0 + a1) / 2
        x, y = rm * math.cos(am), rm * math.sin(am)
        if lost is not None and lost(x, y):
            continue
        hv = heave(x, y) if heave is not None else 0.0
        z = ztop + r.uniform(-dz, dz * 0.7)
        kw = dict(chips=r.randint(0, chips), bevel=bevel, jitter=jitter, tone=tone, kind=kind)
        if hv > 0.0:
            ax = r.choice((0, 1))
            tl = hv * r.uniform(0.08, 0.2) * r.choice((-1, 1))
            kw.update(tilt=(tl, 0.0) if ax == 0 else (0.0, tl), chips=3, chip_depth=(0.15, 0.5))
            z += abs(tl) * 1.2
            round_block(p, r0, r1, z - thick, z, const(a0), const(a1), **kw)
        else:
            round_block(p, r0, r1, z - thick, z, const(a0), const(a1), hide=hide, seen=seen, **kw)


def floor_top(rad):
    """The floor's top at a radius: the pool's floor, its steps, the paving."""
    if rad < POOL_R[0]:
        return -POOL_D
    if rad < POOL_R[1]:
        return -POOL_D * 2 / 3
    if rad < POOL_R[2]:
        return -POOL_D / 3
    return 0.0


def build_floor(seed):
    p = Piece("baths_floor", seed=seed)
    p.ground = -POOL_D
    r = p.rng

    def lost(x, y):
        rad, az = math.hypot(x, y), math.atan2(y, x)
        n = nz(x * 0.11 + 4.0, y * 0.11, 3.3)
        if rad > 26.0 and abs(angdiff(az, BREACH_AZ)) < math.radians(18.0):
            return n > -0.45
        return n > 0.52

    def heave(x, y):
        rad, az = math.hypot(x, y), math.atan2(y, x)
        if abs(angdiff(az, NOTCH_AZ)) < math.radians(30.0) and rad < 30.0:
            return 1.0
        return 1.0 if nz(x * 0.11 + 4.0, y * 0.11, 3.3) > 0.36 else 0.0

    top_only = dict(hide=("-z", "+x", "-x", "+y", "-y"), seen=("+z",))
    # The pool's floor: a boss at the middle, two rings.
    p.block((0, 0, -POOL_D - 0.3), (5.4, 5.4, 0.8), yaw=0.4, chips=2, far=False, hide=("-z",))
    ring_slabs(p, 2.2, 7.0, -POOL_D, 0.7, seg=3.6, heave=lambda x, y: 1.0 if nz(x * 0.2, y * 0.2, 9.0) > 0.45 else 0.0, **top_only)
    ring_slabs(p, 7.0, POOL_R[0] + 0.05, -POOL_D, 0.7, seg=4.0, **top_only)
    # Its steps: the riser (the block's inner side) shows.
    for i in range(3):
        ring_slabs(p, POOL_R[i], POOL_R[i + 1] + 0.05, floor_top(POOL_R[i] + 0.1), 1.3, seg=3.6, hide=("-z", "+y", "+x", "-x"),
                   seen=("+z", "-y"), chips=2)
    # The paving round it.
    n = 5
    w = (PAVE_R1 - POOL_R[3]) / n
    for i in range(n):
        ring_slabs(p, POOL_R[3] + i * w, POOL_R[3] + (i + 1) * w, 0.0, 0.7, lost=lost, heave=heave, **top_only)
    # What shows where a slab is gone and through the joints: the dark under the floor.
    for (r0, r1, zt) in ((POOL_R[3], 26.0, -0.85), (26.0, PAVE_R1, -0.85), (POOL_R[0], POOL_R[3], -POOL_D - 0.75),
                         (3.0, POOL_R[0], -POOL_D - 0.75)):
        ring_slabs(p, r0, r1, zt, 1.0, seg=13.0, kind=DARK, chips=0, bevel=0.0, jitter=0.0, dz=0.0, **top_only)
    p.block((0, 0, -POOL_D - 1.25), (6.4, 6.4, 1.0), bevel=0.0, chips=0, jitter=0.0, kind=DARK, far=False, **top_only)
    # The far LOD.
    far_ring(p, POOL_R[3], PAVE_R1, -1.0, 0.0, seg=24)
    seg = 24
    for j in range(seg):
        a0, a1 = j * math.tau / seg, (j + 1) * math.tau / seg
        c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
        ra, rb = POOL_R[0], POOL_R[3]
        far_face(p, [(ra * c0, ra * s0, -POOL_D), (ra * c1, ra * s1, -POOL_D), (rb * c1, rb * s1, 0), (rb * c0, rb * s0, 0)], (0, 0, 1))
        far_face(p, [(0, 0, -POOL_D), (ra * c0, ra * s0, -POOL_D), (ra * c1, ra * s1, -POOL_D)], (0, 0, 1))

    # The solids: the paving, and over the pool's steps a ramp through their
    # nosings (from 3 m inside the lowest riser), cut fine: its risers are low
    # enough that a pass sinking into the basin scrapes up and out of it, where
    # a step's riser would stop it dead.
    rise = POOL_D / 3 / (POOL_R[1] - POOL_R[0])
    fine = POOL_R[3] + 1.0

    def ramp_top(rad):
        return max(-POOL_D, min(0.0, -POOL_D * 2 / 3 + (rad - POOL_R[0]) * rise))

    def pool(x, y, z):
        rad = math.hypot(x, y)
        return rad < fine and z < ramp_top(rad)

    def paving(x, y, z):
        rad = math.hypot(x, y)
        return fine <= rad < RI + 0.75

    step = POOL_D / 12
    n = voxel_solids(p, pool, (-19.5, -19.5, -step * 25), (19.5, 19.5, 0.0), (0.75, 0.75, step))
    n += voxel_solids(p, paving, (-34.5, -34.5, -step * 25), (34.5, 34.5, 0.0), (1.5, 1.5, step * 25))
    print("baths_floor voxel boxes", n)
    p.export()


# ---- the hall ------------------------------------------------------------------------
def win_half(zb, zt):
    if zb < WIN_SILL - 0.01:
        return 0.0
    if zt <= WIN_SPR:
        return WIN_HW
    d = zt - WIN_SPR
    e = WIN_HW + WIN_RING
    return math.sqrt(e * e - d * d) if d < e else 0.0


def in_window(x, z):
    if z < WIN_SILL:
        return False
    if z <= WIN_SPR:
        return abs(x) < WIN_HW
    return x * x + (z - WIN_SPR) ** 2 < WIN_HW * WIN_HW


def build_hall(name, seed, kind):
    """kind: "whole", "broken" (the vault's crown fallen), "end" (the vault
    and the south wall down, the east end open)."""
    p = Piece(name, seed=seed)
    p.ground = -3.0
    r = p.rng
    end = kind == "end"

    def wall_top(side, x):
        """How high the wall stands at x (side -1: south)."""
        if not end or side > 0:
            return HALL_TOP
        t = 4.5 + 3.5 * nz(x * 0.35, 2.2, seed * 0.7)
        return max(t, HALL_TOP * max(0.0, min(1.0, (-x - 2.5) / 5.0)) + 2.0 * nz(x * 0.8, 5.5, 1.0))

    def vault_gone(x, th):
        if kind == "whole":
            return False
        n = nz(x * 0.3 + seed, th * 2.0, 0.7)
        if kind == "broken":
            return ((x - 0.5) / 6.3) ** 2 + ((th - math.radians(98.0)) / math.radians(60.0)) ** 2 < 1.0 + 0.3 * n
        if th < math.radians(27.0):
            return x > 4.5 + 2.0 * n
        return not (x < -5.6 + 1.6 * n and th < math.radians(75.0))

    walls = {-1: Slots(wrap=False), 1: Slots(wrap=False)}
    vault = Slots(wrap=False)
    # The walls: a plain footing, then courses with the window left out.
    nc = int((HALL_TOP - Z0) / CH)
    for side in (-1, 1):
        yc = side * (HW + HT / 2)
        p.block((0, yc, (FOOT + Z0) / 2), (HL, HT + 0.5, Z0 - FOOT), bevel=0.0, chips=0, jitter=0.0, far=False,
                hide=("-z", "+x", "-x"))
        for k in range(nc):
            zb = Z0 + k * CH
            zt = zb + CH
            wh = win_half(zb, zt)
            spans = [(-HH, -wh, False, True), (wh, HH, True, False)] if wh > 0.0 else [(-HH, HH, False, False)]
            for (x0, x1, jamb0, jamb1) in spans:
                n = max(1, round((x1 - x0) / 4.0))
                xs = [x0]
                for j in range(n):
                    t = x0 + (x1 - x0) * (j + (0.5 if k % 2 else 1.0) + r.uniform(-0.1, 0.1)) / n
                    if x0 + 0.7 < t < x1 - 0.7:
                        xs.append(t)
                xs.append(x1)
                for j in range(len(xs) - 1):
                    a, b = xs[j], xs[j + 1]
                    xc = (a + b) / 2
                    top = wall_top(side, xc)
                    kept = zt <= top + 0.5 or zb < 0.0
                    walls[side].add(k, a, b, kept)
                    if not kept:
                        continue
                    ragged = end and side < 0 and zt > top - 3.0 and zb >= 0.0
                    # The fallen wall's stones show every side; a window's sill its top.
                    bare = end and side < 0 and zb >= 0.0
                    sill = abs(zt - WIN_SILL) < 0.01 and abs(xc) < WIN_HW + 2.5
                    open0 = (j == 0 and jamb0)
                    open1 = (j == len(xs) - 2 and jamb1) or (end and b >= HH - 0.01)
                    th = HT + r.uniform(-0.05, 0.3)
                    if ragged:
                        p.block((xc, yc, (zb + zt) / 2), (b - a - T.JOINT, th, CH - T.JOINT), chips=3, chip_depth=(0.3, 0.8), far=False)
                    elif bare:
                        p.block((xc, yc, (zb + zt) / 2), (b - a - T.JOINT, th, CH - T.JOINT), chips=r.randint(0, 2), far=False)
                    else:
                        core(p, [(a, yc, zb), (b, yc, zb), (b, yc, zt), (a, yc, zt)])
                        hide = ["-z"] + ([] if sill else ["+z"]) + ([] if open0 else ["-x"]) + ([] if open1 else ["+x"])
                        p.block((xc, yc, (zb + zt) / 2), (b - a - T.JOINT, th, CH - T.JOINT), chips=r.randint(0, 1), far=False,
                                hide=tuple(hide), seen=("+y", "-y") + (("+z",) if sill else ()) + (("-x",) if open0 else ())
                                + (("+x",) if open1 else ()))
        # The window's ring.
        if not (end and side < 0):
            rm = WIN_HW + WIN_RING / 2
            nv = 13
            tang = rm * math.pi / nv - T.JOINT
            for i in range(nv):
                th = math.pi * (i + 0.5) / nv
                m = Matrix.Translation((rm * math.cos(th), yc, WIN_SPR + rm * math.sin(th))) @ Matrix.Rotation(-th, 4, "Y")

                def warp(co, rm=rm):
                    co.z *= (rm + co.x) / rm

                scratch_block(p, (WIN_RING - 0.02, HT + 0.5, tang), warp=warp, matrix=m, chips=r.randint(0, 2), chip_depth=(0.1, 0.3))
        # The cornice.
        x = -HH
        while x < HH - 0.3:
            L = min(r.uniform(3.0, 5.0), HH - x)
            if HH - (x + L) < 1.5:
                L = HH - x
            if wall_top(side, x + L / 2) >= HALL_TOP - 0.1:
                p.block((x + L / 2, yc + side * 0.2, HALL_TOP + 0.5), (L - T.JOINT, HT + 0.8, 1.0), chips=r.randint(0, 2), far=False,
                        hide=("-z",))
            x += L
        # The far LOD.
        if end and side < 0:
            p.far_box((0, yc, 0.0), (HL, HT, 10.0))
            p.far_box((-6.0, yc, 11.0), (4.0, HT, 22.0))
        else:
            for (xa, xb, za, zb_) in ((-HH, -WIN_HW, FOOT + 3, HALL_TOP + 1), (WIN_HW, HH, FOOT + 3, HALL_TOP + 1),
                                      (-WIN_HW, WIN_HW, FOOT + 3, WIN_SILL), (-WIN_HW, WIN_HW, WIN_SPR + 4.0, HALL_TOP + 1)):
                p.far_box(((xa + xb) / 2, yc, (za + zb_) / 2), (xb - xa, HT, zb_ - za))
    # The vault: rows of blocks along the hall, bent round its axis.
    rm = VR + VT / 2
    for m_ in range(NV):
        t0, t1 = m_ * math.pi / NV, (m_ + 1) * math.pi / NV
        tm = (t0 + t1) / 2
        arc = rm * math.pi / NV
        xs = [-HH] + [x for x in ((-6.0, -2.0, 2.0, 6.0) if m_ % 2 else (-4.0, 0.0, 4.0))] + [HH]
        for j in range(len(xs) - 1):
            a, b = xs[j], xs[j + 1]
            xc = (a + b) / 2
            kept = not vault_gone(xc, tm)
            vault.add(m_, a, b, kept)
            if not kept:
                continue
            edge = kind != "whole" and (vault_gone(xc - 4.0, tm) or vault_gone(xc + 4.0, tm) or vault_gone(xc, tm + math.pi / NV)
                                        or vault_gone(xc, tm - math.pi / NV))
            if end and b >= HH - 0.01:
                edge = True

            def warp(co, tm=tm, xc=xc):
                rho = rm + co.y
                th = tm + co.z / rm
                co.x, co.y, co.z = xc + co.x, rho * math.cos(th), VSPR + rho * math.sin(th)

            tt = VT + r.uniform(-0.1, 0.1)
            if edge:
                scratch_block(p, (b - a - T.JOINT, tt, arc - T.JOINT), warp=warp, chips=3, chip_depth=(0.2, 0.5))
            else:
                core(p, [(a, rm * math.cos(t0), VSPR + rm * math.sin(t0)), (b, rm * math.cos(t0), VSPR + rm * math.sin(t0)),
                         (b, rm * math.cos(t1), VSPR + rm * math.sin(t1)), (a, rm * math.cos(t1), VSPR + rm * math.sin(t1))])
                scratch_block(p, (b - a - T.JOINT, tt, arc - T.JOINT), warp=warp, chips=r.randint(0, 1),
                              hide=("+x", "-x", "+z", "-z"), seen=("+y", "-y"))
            for rho, sgn in ((VR + VT, 1.0), (VR, -1.0)):
                far_face(p, [(a, rho * math.cos(t0), VSPR + rho * math.sin(t0)), (b, rho * math.cos(t0), VSPR + rho * math.sin(t0)),
                             (b, rho * math.cos(t1), VSPR + rho * math.sin(t1)), (a, rho * math.cos(t1), VSPR + rho * math.sin(t1))],
                         (0, sgn * math.cos(tm), sgn * math.sin(tm)))
    # The floor: slabs, some gone at the end bay's east edge and by its fallen wall.
    rows = 6
    w = (2 * HW + 0.6) / rows
    for i in range(rows):
        yc = -HW - 0.3 + (i + 0.5) * w
        x = -HH
        while x < HH - 0.3:
            L = min(r.uniform(3.2, 4.8), HH - x)
            if HH - (x + L) < 1.6:
                L = HH - x
            xc = x + L / 2
            n = nz(xc * 0.2 + seed, yc * 0.2, 1.1)
            gone = n > 0.5 or (end and (xc > 3.5 + 2.5 * n or yc < -6.5 + 2.5 * n))
            x += L
            if gone:
                continue
            if n > 0.3 or (kind != "whole" and n > 0.05):
                tl = r.uniform(0.05, 0.16) * r.choice((-1, 1))
                p.block((xc, yc, -0.35 + abs(tl) * 1.3), (L - T.JOINT, w - T.JOINT, 0.7), tilt=(tl, 0.0), chips=3,
                        chip_depth=(0.15, 0.5), far=False)
            else:
                p.block((xc, yc, -0.35 + r.uniform(-0.03, 0.02)), (L - T.JOINT, w - T.JOINT, 0.7), chips=r.randint(0, 1), far=False,
                        hide=("-z", "+x", "-x", "+y", "-y"), seen=("+z",))
    p.block((0, 0, -1.35), (HL, 2 * HW + 0.4, 1.0), bevel=0.0, chips=0, jitter=0.0, kind=DARK, far=False,
            hide=("-z", "+x", "-x", "+y", "-y"), seen=("+z",))
    p.far_box((0, 0, -0.5), (HL, 2 * HW, 1.0))
    if end:
        # The platform's end: coursed under the floor's broken edge.
        for (zb, h) in ((FOOT, 3.0), (-6.0, 2.0), (-4.0, 2.0), (-2.0, 1.4)):
            y = -HW
            while y < HW - 0.3:
                L = min(r.uniform(3.0, 5.0), HW - y)
                if HW - (y + L) < 1.5:
                    L = HW - y
                p.block((HH - 1.0 + r.uniform(-0.1, 0.1), y + L / 2, zb + h / 2), (2.0, L - T.JOINT, h - T.JOINT),
                        chips=r.randint(1, 3), far=False)
                y += L
        p.far_box((HH - 1.0, 0, (FOOT - 0.6) / 2), (2.0, 2 * HW, -FOOT - 0.6))

    # The inside in shade under the standing vault.
    def inside(c, nrm):
        if kind != "whole" or c.z < 0.0:
            return 1.0
        if abs(c.y) < HW + 0.5 and nrm.y * c.y < -0.3 * abs(c.y):
            return 0.82
        rho = math.hypot(c.y, c.z - VSPR)
        if c.z > VSPR and rho < VR + 0.5 and (nrm.y * c.y + nrm.z * (c.z - VSPR)) / max(rho, 1e-3) < -0.3:
            return 0.8
        return 1.0

    shade(p, inside)

    def stone(x, y, z):
        if abs(y) < HW:
            if z < 0.0:
                return True
            if z < VSPR:
                return False
            rho = math.hypot(y, z - VSPR)
            if rho < VR or rho > VR + VT:
                return False
            th = math.atan2(z - VSPR, y)
            return vault.kept(int(th / (math.pi / NV)), x, False)
        if abs(y) > HW + HT:
            return False
        side = 1 if y > 0 else -1
        if z < 0.0:
            return True
        if z >= HALL_TOP:
            return z < HALL_TOP + 1.0 and wall_top(side, x) >= HALL_TOP - 0.1
        if not (end and side < 0) and in_window(x, z):
            return False
        return walls[side].kept(int((z - Z0) // CH), x, not (end and side < 0))

    n = voxel_solids(p, stone, (-HH, -HW - HT, -6.0), (HH, HW + HT, 28.5), (1.0, 1.5, 1.5))
    print(name, "voxel boxes", n)
    p.export()


# ---- what fell ---------------------------------------------------------------------------
def build_rubble(seed):
    p = Piece("baths_rubble", seed=seed)
    p.ground = 0.0
    r = p.rng
    stones = []
    for _ in range(11):
        stones.append((r.uniform(3.6, 4.8), r.uniform(2.3, 3.0), r.uniform(2.6, 3.3), True))
    for _ in range(14):
        stones.append((r.uniform(1.4, 2.6), r.uniform(1.2, 2.2), r.uniform(1.0, 1.8), False))
    for _ in range(26):
        stones.append((r.uniform(0.5, 1.2), r.uniform(0.5, 1.1), r.uniform(0.35, 0.8), False))
    for (sx, sy, sz, big) in stones:
        x = max(-8.5, min(8.5, r.gauss(0.0, 3.6 if big else 4.6)))
        y = max(-8.5, min(8.5, r.gauss(0.0, 3.6 if big else 4.6)))
        lo = min(sx, sy, sz)
        if lo == sx:
            sx, sz = sz, sx
        elif lo == sy:
            sy, sz = sz, sy
        tilt = (r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4))
        z = sz * r.uniform(0.1, 0.35)
        if big and abs(x) < 3.0 and abs(y) < 3.0:
            z += r.uniform(0.4, 1.3)
        p.block((x, y, z), (sx, sy, sz), yaw=r.uniform(0, math.tau), tilt=tilt, chips=r.randint(2, 4), chip_depth=(0.2, 0.7),
                far=big)
        if big:
            e = max(sx, sy) / 2 * 0.8
            p.solid((x - e, y - e, -1.0), (x + e, y + e, z + sz / 2 + 0.3))
    p.export()


def build_fragment(seed):
    """Two shell blocks still joined, lying on the outer face, one end up."""
    p = Piece("baths_fragment", seed=seed)
    p.ground = 0.0
    r = p.rng
    m = Matrix.Translation((0, 0, 1.25)) @ Matrix.Rotation(0.2, 4, "Y") @ Matrix.Rotation(0.07, 4, "X")
    for (x, L) in ((-2.3, 4.5), (2.2, 4.3)):
        scratch_block(p, (L - T.JOINT, 3.4, 2.7), matrix=m @ Matrix.Translation((x, r.uniform(-0.05, 0.05), 0)), chips=5,
                      chip_depth=(0.3, 1.0))
    p.far_box((0, 0, 1.2), (8.8, 3.4, 2.6))
    for _ in range(7):
        s = r.uniform(0.4, 1.0)
        a = r.uniform(0, math.tau)
        d = r.uniform(3.0, 5.5)
        p.block((math.cos(a) * d, math.sin(a) * d * 0.7, s * 0.2), (s * 1.4, s, s * 0.7), yaw=r.uniform(0, 3),
                tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), chips=2, far=False, chip_depth=(0.05, 0.2))
    p.solid((-4.5, -1.8, -0.5), (4.5, 1.8, 3.3))
    p.export()


JOBS = {
    "baths_rotunda": lambda: build_rotunda(61),
    "baths_dome": lambda: build_dome(62),
    "baths_floor": lambda: build_floor(63),
    "baths_hall": lambda: build_hall("baths_hall", 64, "whole"),
    "baths_hall_broken": lambda: build_hall("baths_hall_broken", 65, "broken"),
    "baths_hall_end": lambda: build_hall("baths_hall_end", 66, "end"),
    "baths_rubble": lambda: build_rubble(67),
    "baths_fragment": lambda: build_fragment(68),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
