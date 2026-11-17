"""The temple kit's great dome (lane dome): a ruined rotunda, a round drum
under a coffered dome with the eye open at its top, a porch on the south and
a breach on the north where the drum and the dome have fallen in. Its pieces
are wedges, one sixteenth of the round each, which scripts/endless/dome_site.gd
turns about the rotunda's middle; the porch is the kit's columns and lintels
under a roof of its own.

    python tools/blender.py run art/blender/temple_kit/dome_build.py [-- --only=dome_shell]

A wedge's frame (Blender, z up): the origin is the rotunda's middle on its
floor, the wedge looks out along -y (Godot +z) and spans t in +-DT/2 about
it (x = r sin t, y = -r cos t). The floor's top is z 0.

Pieces:
- `dome_drum`: the drum's wedge, RI to RO, its footing from FOOT0 to the
  outer cornice's top OTOP; inside, a niche between two pilasters under a
  cornice, an attic with a blind window, the main cornice at S; outside,
  ashlar with a string course and a cornice.
- `dome_drum_door`: the same with the door, DOOR_W by DOOR_H, framed.
- `dome_shell`: the dome's wedge from S to the eye: two columns of five rows
  of stepped coffers inside, step rings and a skin of courses outside, the
  eye's kerb at the top.
- `dome_drum_b<k>`, `dome_shell_b<k>` (k -2..2, written m2 m1 0 p1 p2): the
  wedges of the breach, wedge k at BREACH_K + k; what fell is cut from them
  by `drum_gone` / `shell_gone` in the rotunda's own angle.
- `dome_floor`: the floor's wedge, rings of paving.
- `dome_footing`: the drum's footing, FOOT_H of courses under FOOT0; stacked
  down to the ground.
- `dome_porch_roof`: the porch's roof on its entablature: ceiling beams, the
  pediment, the roof back to the drum. Its origin is the rotunda's middle (the
  porch looks out along -y).
- `dome_slab`: a fallen piece of the dome, two coffers on their shell, lying.
- `dome_heap`: a heap of the drum's blocks, about 26 by 20 m, 7 high.
Each but the breach's has a mid LOD (<piece>_mid.glb). Every vertex's colour
carries in its alpha how much sky it sees (`sky`): the stone shader dims its
sky fill by it, so the inside reads as an inside.
"""

import math
import sys

import bmesh
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

N = 16
DT = math.tau / N
RI = 47.0                  # the inside's radius
WT = 6.0
RO = RI + WT               # the drum's outer face
S = 38.0                   # the dome springs (inside)
OTOP = S + 8.0             # the drum's outer top
RS = RI + 3.5              # the dome's outer skin (about (0, 0, S))
EYE = 16.0                 # the eye's radius
PHI_EYE = math.acos(EYE / RI)
FOOT0 = -4.0
FOOT_H = 12.0
DOOR_W = 16.0
DOOR_H = 25.6
SKIN = 1.5
# The breach: centred on wedge BREACH_K (north); the door on DOOR_K (south).
BREACH_K = 0
DOOR_K = 8
# Porch (dome_site.gd's numbers): the entablature's top, the roof's reach.
PORCH_TOP = T.COLUMN_H + T.ENTABLATURE_H      # 38
PORCH_HALF = 1.5 * T.BAY + 3.2                # 30.95
PORCH_FRONT = RO + 2.0 * T.BAY + 3.2 + 0.6    # 93.8
PORCH_BACK = 44.0
PITCH = math.radians(16.0)

# Course grids (z0, z1).
INNER = ([(FOOT0, -2.0), (-2.0, 0.0), (0.0, 1.2)] + [(1.2 + 2.2 * i, 3.4 + 2.2 * i) for i in range(9)]
         + [(21.0, 23.0)] + [(23.0 + 2.6 * i, 25.6 + 2.6 * i) for i in range(5)] + [(36.0, 38.0)])
OUTER = INNER[:-1] + [(36.0, 38.6), (38.6, 41.3), (41.3, 44.0), (44.0, OTOP)]


def wedge_rot(k):
    """Wedge k's turn into the rotunda's frame (Blender; the same angle as Godot's yaw)."""
    return Matrix.Rotation(math.pi + k * DT, 4, "Z")


def angle_of(p):
    """A rotunda-frame point's angle from the breach's middle, degrees, signed."""
    return math.degrees(math.atan2(p.x, p.y))


# ---- what fell ---------------------------------------------------------------------
def drum_top(a):
    """How high the drum stands at angle a (deg from the breach's middle)."""
    x = abs(a)
    n = noise.noise(Vector((a * 0.09, 1.3, 0.7)))
    if x < 27.0:
        return 3.0 + 3.5 * n + 1.5 * noise.noise(Vector((a * 0.3, 4.4, 0.0)))
    return min(OTOP + 1.0, 3.0 + (x - 27.0) * 2.5 + 6.0 * n)


def drum_gone(p):
    return p.z > drum_top(angle_of(p))


def shell_cut(a):
    """The dome is gone below this elevation (deg) at angle a."""
    x = abs(a)
    n = 5.0 * noise.noise(Vector((a * 0.07, 7.1, 2.0))) + 2.0 * noise.noise(Vector((a * 0.25, 1.0, 9.0)))
    if x < 20.0:
        return 57.0 + n
    return max(-5.0, 57.0 + n - (x - 20.0) * 2.1)


def shell_gone(p):
    q = p - Vector((0.0, 0.0, S))
    phi = math.degrees(math.atan2(q.z, math.hypot(q.x, q.y)))
    return phi < shell_cut(angle_of(p))


# ---- the sky each vertex sees -------------------------------------------------------
def _proxy(breach):
    """The inside's faces (rotunda frame) for the sky's rays: floor, drum, dome,
    and the porch's ceiling; with `breach`, what fell and the door are open."""
    verts, polys = [], []

    def quad(a, b, c, d):
        i = len(verts)
        verts.extend([a, b, c, d])
        polys.append((i, i + 1, i + 2, i + 3))
    M = 96
    for i in range(M):
        t0, t1 = math.tau * i / M, math.tau * (i + 1) / M
        tm = (t0 + t1) / 2
        c0, s0, c1, s1 = math.cos(t0), math.sin(t0), math.cos(t1), math.sin(t1)
        quad(Vector((0, 0, 0)), Vector((0, 0, 0)), Vector((RI * s1, RI * c1, 0)), Vector((RI * s0, RI * c0, 0)))
        zs = [0.0, 4.0, 8.0, 13.0, 18.0, 23.0, 28.0, 33.0, S]
        for za, zb in zip(zs, zs[1:]):
            mid = Vector((RI * math.sin(tm), RI * math.cos(tm), (za + zb) / 2))
            if breach and drum_gone(mid):
                continue
            if breach and abs(angle_of(mid)) > 180.0 - math.degrees(math.asin(DOOR_W / 2 / RI)) and mid.z < DOOR_H:
                continue
            quad(Vector((RI * s0, RI * c0, za)), Vector((RI * s1, RI * c1, za)), Vector((RI * s1, RI * c1, zb)), Vector((RI * s0, RI * c0, zb)))
        P = 18
        for j in range(P):
            p0, p1 = PHI_EYE * j / P, PHI_EYE * (j + 1) / P
            pm = (p0 + p1) / 2
            mid = Vector((RI * math.cos(pm) * math.sin(tm), RI * math.cos(pm) * math.cos(tm), S + RI * math.sin(pm)))
            if breach and shell_gone(mid):
                continue
            pts = [Vector((RI * math.cos(p) * s, RI * math.cos(p) * c, S + RI * math.sin(p))) for (p, s, c) in
                   ((p0, s0, c0), (p0, s1, c1), (p1, s1, c1), (p1, s0, c0))]
            quad(*pts)
    # The porch's ceiling, south (-y in Blender's rotunda frame is north; the porch looks out to -y in its own, south).
    zc = PORCH_TOP - T.ENTABLATURE_H
    quad(Vector((-PORCH_HALF, -PORCH_BACK, zc)), Vector((PORCH_HALF, -PORCH_BACK, zc)), Vector((PORCH_HALF, -PORCH_FRONT, zc)),
         Vector((-PORCH_HALF, -PORCH_FRONT, zc)))
    return BVHTree.FromPolygons(verts, polys, all_triangles=False)


_PROXY = {}


def proxy(breach):
    if breach not in _PROXY:
        _PROXY[breach] = _proxy(breach)
    return _PROXY[breach]


def _dirs(n=48):
    out = []
    for i in range(n):
        u = (i + 0.5) / n
        a = i * 2.399963
        r = math.sqrt(u)
        out.append((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1.0 - u))))
    return out


DIRS = _dirs()
SKY_LOW = 0.30          # what a vertex that sees no sky keeps of the fill
SKY_GAIN = 2.6


class DomePiece(T.Piece):
    """A Piece whose colours' alpha is the sky its vertices see: `rot` the
    piece's frame in the rotunda's, `breach` which proxy (False: the whole
    round, for a wedge drawn all round; the breach's own wedges see what fell)."""

    def __init__(self, name, seed=1, rot=None, breach=False, lift=0.0):
        super().__init__(name, seed=seed)
        self.rot = rot if rot is not None else Matrix.Identity(4)
        self.breach = breach
        self.lift = lift

    def paint(self, bm, far=False):
        col = super().paint(bm, far=far)
        tree = proxy(self.breach)
        rot3 = self.rot.to_3x3()
        sky = {}
        for v in bm.verts:
            n = v.normal
            if n.length < 0.5:
                sky[v] = 1.0
                continue
            p = self.rot @ (v.co + Vector((0.0, 0.0, self.lift)))
            nw = (rot3 @ n).normalized()
            tx = nw.orthogonal().normalized()
            ty = nw.cross(tx)
            o = p + nw * 0.35
            seen = 0
            for (a, b, c) in DIRS:
                d = tx * a + ty * b + nw * c
                if tree.ray_cast(o, d, 600.0)[0] is None:
                    seen += 1
            sky[v] = seen / len(DIRS)
        for f in bm.faces:
            for loop in f.loops:
                r, g, b, _ = loop[col]
                loop[col] = (r, g, b, min(1.0, SKY_LOW + SKY_GAIN * sky[loop.vert]))
        return col


# ---- laying stones ------------------------------------------------------------------
class Lay:
    """Blocks for one piece at one LOD (as sanctuary_build.py's): the near's cut
    and chipped, the mid's plain."""

    def __init__(self, name, seed, mid, rot=None, breach=False, lift=0.0):
        self.p = DomePiece(name, seed=seed, rot=rot, breach=breach, lift=lift)
        self.p.ground = FOOT0 - 50.0
        self.r = T.random.Random(seed * 31 + 7)
        self.mid = mid
        self.rot = rot if rot is not None else Matrix.Identity(4)

    def block(self, c, s, chips=1, hide=(), edge=False, yaw=0.0, tilt=(0.0, 0.0), tone=None):
        if self.mid:
            self.p.block(c, s, bevel=0.0, chips=0, jitter=0.0, far=False, hide=hide, yaw=yaw, tilt=tilt, tone=tone)
            return
        self.p.block(c, s, chips=4 if edge else chips, chip_depth=(0.3, 0.9) if edge else (0.12, 0.45), far=False,
                     hide=hide, yaw=yaw, tilt=tilt, tone=tone)

    def world(self, p):
        return self.rot @ Vector(p)

    def arc(self, r0, r1, t0, t1, z0, z1, maxlen=4.2, chips=1, hide=("-z", "+z"), gone=None, jag=0.18):
        """A course of blocks on the round from angle t0 to t1, r0 to r1 out,
        z0 to z1; `gone(world point)` drops a block (the ones beside a dropped
        one are broken)."""
        if t1 - t0 < 1e-4:
            return
        rm = (r0 + r1) / 2
        n = max(1, math.ceil(rm * (t1 - t0) / maxlen))
        cuts = [t0] + [t0 + (t1 - t0) * (i + self.r.uniform(-jag, jag)) / n for i in range(1, n)] + [t1]
        zc = (z0 + z1) / 2
        for a, b in zip(cuts, cuts[1:]):
            tc = (a + b) / 2
            c = (rm * math.sin(tc), -rm * math.cos(tc), zc)
            chord = 2.0 * rm * math.sin((b - a) / 2)
            if gone is not None and gone(self.world(c)):
                continue
            edge = False
            if gone is not None:
                for dt, dz in ((-(b - a), 0.0), (b - a, 0.0), (0.0, z1 - z0 + 0.5)):
                    q = (rm * math.sin(tc + dt), -rm * math.cos(tc + dt), zc + dz)
                    if gone(self.world(q)):
                        edge = True
            self.block(c, (chord - T.JOINT, r1 - r0, z1 - z0 - T.JOINT), chips=self.r.randint(0, chips),
                       hide=() if edge else hide, edge=edge, yaw=tc)

    def far_arc(self, r0, r1, t0, t1, z0, z1, n=2):
        rm = (r0 + r1) / 2
        for i in range(n):
            a = t0 + (t1 - t0) * i / n
            b = t0 + (t1 - t0) * (i + 1) / n
            tc = (a + b) / 2
            self.p.far_box((rm * math.sin(tc), -rm * math.cos(tc), (z0 + z1) / 2),
                           (2.0 * r1 * math.sin((b - a) / 2) + 0.2, r1 - r0, z1 - z0), yaw=tc)

    def export(self, name):
        if self.mid:
            self.p.export(mid_of=name)
        else:
            self.p.export()


def both(name, seed, fn, rot=None, breach=False, mid=True):
    for m in ((False, True) if mid else (False,)):
        lay = Lay(name, seed, m, rot=rot, breach=breach)
        fn(lay)
        lay.export(name)


def edge_t(r, x):
    """The angle at radius r of the line |x| from the wedge's axis."""
    return math.asin(min(1.0, x / r))


# ---- the drum ----------------------------------------------------------------------
H0 = DT / 2
PIL = 1.0          # half a pilaster's arc (m) at the inside


def drum(lay, door=False, gone=None):
    """The drum's stones: outer skin, inner skin with its order, the core where it shows."""
    tp = PIL / RI
    for (z0, z1) in OUTER:
        proud = 0.0
        if (z0, z1) == (21.0, 23.0):
            proud = 0.5
        if z0 >= 44.0:
            proud = 1.0
        if z0 < 0.0:
            proud = 0.3
        r0, r1 = RO - SKIN, RO + proud
        if door and z0 >= 0.0 and z1 <= DOOR_H + 0.01:
            td = edge_t(RO, DOOR_W / 2 + 1.6)
            lay.arc(r0, r1, -H0, -td, z0, z1, gone=gone)
            lay.arc(r0, r1, td, H0, z0, z1, gone=gone)
            # The door's frame, outside: a jamb each side, proud.
            tf = edge_t(RO, DOOR_W / 2)
            for s in (-1, 1):
                lay.arc(RO - 0.4, RO + 0.6, *sorted((s * tf, s * td)), z0, z1, maxlen=3.0, gone=gone, hide=("-z", "+z"))
        else:
            lay.arc(r0, r1, -H0, H0, z0, z1, gone=gone, maxlen=4.6)
        if door and abs(z0 - DOOR_H) < 0.01:
            tf = edge_t(RO, DOOR_W / 2 + 1.6)
            lay.arc(RO - 0.4, RO + 0.7, -tf, tf, DOOR_H, DOOR_H + 1.6, maxlen=3.5, gone=gone, hide=("-z",))
    # The core: only where something fell (else nobody sees it), or the door's passage.
    for (z0, z1) in OUTER:
        if gone is None and not door:
            break
        rc0, rc1 = RI + SKIN, RO - SKIN
        if door and z0 >= 0.0 and z1 <= DOOR_H + 0.01:
            for s in (-1, 1):
                t_in = edge_t(RI + SKIN, DOOR_W / 2)
                lay.arc(rc0, rc1, *sorted((s * t_in, s * H0)), z0, z1, maxlen=6.0, chips=0, gone=gone)
            continue
        if gone is None:
            continue
        lay.arc(rc0, rc1, -H0, H0, z0, z1, maxlen=6.0, chips=0, gone=gone, hide=("-z", "+z", "-y", "+y"))
    # The inner skin and its order.
    for (z0, z1) in INNER:
        if z1 <= 0.01:
            continue
        if door and z0 >= 0.0 and z1 <= DOOR_H + 0.01:
            t_in = edge_t(RI, DOOR_W / 2)
            for s in (-1, 1):
                lay.arc(RI, RI + SKIN, *sorted((s * t_in, s * H0)), z0, z1, gone=gone)
            # The frame inside.
            for s in (-1, 1):
                ta, tb = edge_t(RI, DOOR_W / 2), edge_t(RI, DOOR_W / 2 + 1.4)
                lay.arc(RI - 0.5, RI, *sorted((s * ta, s * tb)), z0, z1, maxlen=3.0, gone=gone)
            continue

        if (z0, z1) == (21.0, 23.0) or (z0, z1) == (36.0, 38.0):
            # A cornice, proud of the face.
            jut = 1.2 if z0 < 30 else 1.6
            lay.arc(RI - jut, RI + SKIN, -H0, H0, z0, z1, maxlen=3.6, chips=2, gone=gone, hide=("-z",))
            continue
        if z1 <= 1.21:
            lay.arc(RI - 0.4, RI + SKIN, -H0, H0, z0, z1, maxlen=4.6, gone=gone)
            continue
        lower = z0 < 21.0
        # Pilasters at the wedge's edges (halves), proud by 0.6.
        if not door:
            lay.arc(RI - 0.6, RI + SKIN, -H0, -H0 + tp, z0, z1, maxlen=3.0, chips=1, gone=gone)
            lay.arc(RI - 0.6, RI + SKIN, H0 - tp, H0, z0, z1, maxlen=3.0, chips=1, gone=gone)
        ta, tb = (-H0 + tp, H0 - tp) if not door else (-H0, H0)
        zc = (z0 + z1) / 2
        # The niche (lower) or the blind window (attic): set back 1.4 m.
        if door:
            hw = 0.0
        elif lower:
            hw = 4.5 if zc < 14.5 else math.sqrt(max(0.0, 4.5 ** 2 - (zc - 14.5) ** 2))
        else:
            hw = 2.6 if 25.6 <= zc <= 33.4 else 0.0
        if hw > 0.6:
            tn = hw / RI
            lay.arc(RI, RI + SKIN, ta, -tn, z0, z1, gone=gone)
            lay.arc(RI + 1.4, RI + SKIN + 1.4, -tn, tn, z0, z1, gone=gone, maxlen=3.0)
            lay.arc(RI, RI + SKIN, tn, tb, z0, z1, gone=gone)
        else:
            lay.arc(RI, RI + SKIN, ta, tb, z0, z1, gone=gone)
    if door:
        # The lintel inside over the door: one long stone and a relieving course.
        t_in = edge_t(RI, DOOR_W / 2 + 1.4)
        lay.arc(RI - 0.5, RI, -t_in, t_in, DOOR_H, DOOR_H + 1.8, maxlen=6.0, gone=gone, hide=("-z",))


def drum_boxes(door=False, gone=None, k=0):
    """The drum's solids in the wedge's frame: slices across, each to the
    height that stands; the door left open."""
    out = []
    xs = [-10.7, -5.4, 0.0, 5.4, 10.7]
    for xa, xb in zip(xs, xs[1:]):
        # The inside face at the slice's innermost drawn point (not -RI + 0.9
        # across, which stood 0.9 m proud of the wall at the wedge's middle).
        yi = -math.sqrt(RI * RI - max(xa * xa, xb * xb))
        top = OTOP
        if gone is not None:
            rot = wedge_rot(BREACH_K + k)
            top = min(drum_top(angle_of(rot @ Vector((x, -RI - 3.0, 0.0)))) for x in (xa, (xa + xb) / 2, xb))
            top = max(FOOT0 + 1.0, min(OTOP, top))
        if door and xa < DOOR_W / 2 and xb > -DOOR_W / 2:
            if xa < -DOOR_W / 2:
                out.append(((xa, -RO - 0.6, FOOT0), (-DOOR_W / 2, yi, top)))
            if xb > DOOR_W / 2:
                out.append(((DOOR_W / 2, -RO - 0.6, FOOT0), (xb, yi, top)))
            out.append(((max(xa, -DOOR_W / 2), -RO - 0.6, DOOR_H), (min(xb, DOOR_W / 2), yi, top)))
            out.append(((max(xa, -DOOR_W / 2), -RO - 0.6, FOOT0), (min(xb, DOOR_W / 2), yi, 0.0)))
            continue
        out.append(((xa, -RO - 0.6, FOOT0), (xb, yi, top)))
    # The cornices inside.
    if gone is None:
        out.append(((-9.2, -RI + 0.9, 21.0), (9.2, -RI + 1.6, 23.0)))
        out.append(((-9.2, -RI + 0.9, 36.0), (9.2, -RI + 1.6, 38.0)))
    return out


def build_drum(lay, door=False, k=None):
    gone = None
    if k is not None:
        gone = drum_gone
    drum(lay, door=door, gone=gone)
    boxes = drum_boxes(door=door, gone=gone, k=k or 0)
    for lo, hi in boxes:
        if hi[2] - lo[2] < 0.5:
            continue
        lay.p.far_box(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2 - 0.4, (lo[2] + hi[2]) / 2), (hi[0] - lo[0], hi[1] - lo[1] - 0.8, hi[2] - lo[2]))
    for lo, hi in boxes:
        lay.p.solid(lo, hi)


# ---- the dome ----------------------------------------------------------------------
ROWS = [9.0, 19.0, 28.0, 36.0, 43.5, 50.5]       # the coffers' rows (deg, edges)


def sph(t, phi, r):
    return Vector((r * math.cos(phi) * math.sin(t), -r * math.cos(phi) * math.cos(t), S + r * math.sin(phi)))


def _knots(a, b, steps, rib, step):
    """A coffer's knots across a..b: [(position, level)], each step twice."""
    w = b - a
    ks = [(a, 0)]
    x = a + rib * w
    for lv in range(1, steps + 1):
        ks += [(x, lv - 1), (x, lv)]
        x += step * w
    x2 = b - rib * w - step * w * (steps - 1)
    ks2 = []
    for lv in range(steps, 0, -1):
        ks2 += [(x2, lv), (x2, lv - 1)]
        x2 += step * w
    return ks + ks2 + [(b, 0)]


def coffers(lay, t0, t1, gone=None):
    """The dome's inside over t0..t1: plain at the foot and the top, the
    coffers' rows between; a heightfield over (t, phi), recessed outward."""
    tmp = bmesh.new()
    kl, tl, bl = T._layers(tmp)
    deep = T._deep(tmp)
    nl = T._normals(tmp)
    steps = 2 if lay.mid else 3
    depth = 0.42
    rows = [(0.0, math.radians(ROWS[0]), False)]
    for a, b in zip(ROWS, ROWS[1:]):
        rows.append((math.radians(a), math.radians(b), True))
    rows.append((math.radians(ROWS[-1]), PHI_EYE, False))
    cols = 2
    tone = lay.p.tone()
    broke_faces = []
    for (pa, pb, cof) in rows:
        for c in range(cols):
            ta = t0 + (t1 - t0) * c / cols
            tb = t0 + (t1 - t0) * (c + 1) / cols
            if cof:
                kt = _knots(ta, tb, steps, 0.13, 0.08)
                kp = _knots(pa, pb, steps, 0.13, 0.08)
            else:
                n = 3 if lay.mid else 6
                kt = [(ta + (tb - ta) * i / 3, 0) for i in range(4)]
                m = max(2, int((pb - pa) * RI / (5.0 if lay.mid else 2.6)))
                kp = [(pa + (pb - pa) * i / m, 0) for i in range(m + 1)]
            grid = []
            for (pp, lp) in kp:
                row = []
                for (tt, lt) in kt:
                    d = min(lp, lt) * depth
                    v = tmp.verts.new(sph(tt, pp, RI + d))
                    v[deep] = 0.45 * min(lp, lt) / steps if cof else 0.0
                    nrm = -(sph(tt, pp, 1.0) - Vector((0, 0, S)))
                    T._set_normal(v, nl, nrm.normalized())
                    row.append(v)
                grid.append(row)
            for j in range(len(kp) - 1):
                for i in range(len(kt) - 1):
                    a, b, cc, d = grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]
                    if (a.co - cc.co).length < 1e-4 or (b.co - d.co).length < 1e-4:
                        continue
                    ctr = (a.co + b.co + cc.co + d.co) / 4
                    if gone is not None and gone(lay.world(ctr)):
                        continue
                    try:
                        f = tmp.faces.new((a, b, cc, d))
                    except ValueError:
                        continue
                    flat = abs(kp[j][0] - kp[j + 1][0]) > 1e-6 and abs(kt[i][0] - kt[i + 1][0]) > 1e-6
                    f[kl] = T.FACE if flat else T.JOINTFACE
                    f[tl] = tone * (1.0 if not cof or min(kp[j][1], kt[i][1]) < steps else 0.96)
                    if gone is not None:
                        broke_faces.append((f, (a, b, cc, d)))
    tmp.normal_update()
    # Facing the inside.
    fl = [f for f in tmp.faces if f[kl] == T.FACE]
    if fl:
        f = fl[0]
        if f.normal.dot(Vector((0, 0, S)) - f.calc_center_median()) < 0:
            for f in tmp.faces:
                f.normal_flip()
    # Where the dome broke: a raw face from the inside's edge out through the
    # shell, on each open edge whose far side fell.
    if gone is not None:
        for e in list(tmp.edges):
            if len(e.link_faces) != 1:
                continue
            a, b = e.verts
            mid = (a.co + b.co) / 2
            lf0 = e.link_faces[0]
            away = mid - lf0.calc_center_median()
            if away.length < 1e-6:
                continue
            if not gone(lay.world(mid + away.normalized() * 0.8)):
                continue
            oa = a.co + (a.co - Vector((0, 0, S))).normalized() * (RS - RI - 0.6)
            ob = b.co + (b.co - Vector((0, 0, S))).normalized() * (RS - RI - 0.6)
            va, vb = tmp.verts.new(oa), tmp.verts.new(ob)
            va[bl] = vb[bl] = a[bl] = b[bl] = 1.0
            try:
                nf = tmp.faces.new((a, b, vb, va))
            except ValueError:
                continue
            nf[kl] = T.BROKEN
            nf[tl] = tone
            nf.normal_update()
            # Toward where it fell.
            if nf.normal.dot(away) < 0:
                nf.normal_flip()
    T._append(lay.p.near, tmp)
    tmp.free()


def shell_outer(lay, t0, t1, gone=None):
    """The dome's outside: three step rings over the drum, a skin of courses
    to the eye, the eye's wall and kerb."""
    rings = [(S + 8.0, S + 11.0, RO - 1.2), (S + 11.0, S + 14.0, RO - 2.4), (S + 14.0, S + 17.0, RO - 3.8)]
    for (z0, z1, ro) in rings:
        lay.arc(ro - 3.0, ro, t0, t1, z0, z1, maxlen=4.4, chips=2, hide=("-z", "+y"), gone=gone)
    # The skin: courses by elevation on the sphere RS.
    phi0 = math.asin(17.0 / RS)
    phi1 = math.asin((math.sqrt(RS ** 2 - EYE ** 2) - 0.0) / RS)
    phi_top = math.acos((EYE + 1.6) / RS)
    n = max(2, int((phi_top - phi0) * RS / 2.7))
    for i in range(n):
        pa = phi0 + (phi_top - phi0) * i / n
        pb = phi0 + (phi_top - phi0) * (i + 1) / n
        pm = (pa + pb) / 2
        rm = RS * math.cos(pm)
        h = (pb - pa) * RS
        cnt = max(1, math.ceil(rm * (t1 - t0) / 4.4))
        cuts = [t0] + [t0 + (t1 - t0) * (k + lay.r.uniform(-0.2, 0.2)) / cnt for k in range(1, cnt)] + [t1]
        for a, b in zip(cuts, cuts[1:]):
            tc = (a + b) / 2
            c = sph(tc, pm, RS - 0.6)
            if gone is not None and gone(lay.world(c)):
                continue
            edge = gone is not None and any(gone(lay.world(sph(tc + dt, pm + dp, RS - 0.6))) for dt, dp in
                                            ((b - a, 0.0), (a - b, 0.0), (0.0, pb - pa), (0.0, pa - pb)))
            chord = 2.0 * (RS - 0.6) * math.cos(pm) * math.sin((b - a) / 2)
            lay.block(c, (chord - T.JOINT, h - T.JOINT, 1.2), chips=lay.r.randint(0, 2), hide=() if edge else ("-z",),
                      edge=edge, yaw=tc, tilt=(math.pi / 2 - pm, 0.0))
    # The eye's wall and kerb.
    zi = S + math.sqrt(RI ** 2 - EYE ** 2)
    zo = S + math.sqrt(RS ** 2 - (EYE + 1.6) ** 2)
    lay.arc(EYE, EYE + 2.2, t0, t1, zi - 0.3, zo + 0.4, maxlen=3.2, chips=2, hide=(), gone=gone)
    lay.arc(EYE - 0.3, EYE + 2.6, t0, t1, zo + 0.4, zo + 1.4, maxlen=2.6, chips=2, hide=("-z",), gone=gone)


def shell_boxes(gone=None, k=0):
    """The dome's solids: bands by elevation, each a box round its stretch of the shell, cut in slices across."""
    out = []
    # 2.5 deg bands: a box's inner lower corner stands at most about 0.5 m
    # proud of the drawn inside (5 deg bands left up to 1.9 m of solid air).
    bands = [0.0] + [2.5 * i for i in range(2, 28)] + [math.degrees(PHI_EYE)]
    rot = wedge_rot(BREACH_K + k)
    for a, b in zip(bands, bands[1:]):
        pa, pb = math.radians(a), math.radians(b)
        r_in = RI * math.cos(pb)
        r_out = max(RS * math.cos(pa), RO if a < 20.0 else 0.0)
        z0 = S + RI * math.sin(pa)
        z1 = max(S + RS * math.sin(pb), OTOP if a < 5 else 0.0)
        if a < 0.5:
            z0 = OTOP - 8.0
        half = r_out * math.tan(H0) + 0.3
        slices = [(-half, half)] if gone is None else [(-half + 2 * half * i / 3, -half + 2 * half * (i + 1) / 3) for i in range(3)]
        for xa, xb in slices:
            if gone is not None:
                pm = (pa + pb) / 2
                xm = (xa + xb) / 2
                tm = math.asin(max(-1.0, min(1.0, xm / max(1.0, RI * math.cos(pm)))))
                if shell_gone(rot @ sph(tm, pm, RI + 1.0)):
                    continue
            out.append(((xa, -r_out, z0), (xb, -r_in, z1)))
    return out


def build_shell(lay, k=None):
    gone = shell_gone if k is not None else None
    coffers(lay, -H0, H0, gone=gone)
    shell_outer(lay, -H0, H0, gone=gone)
    boxes = shell_boxes(gone=gone, k=k or 0)
    for lo, hi in boxes:
        lay.p.far_box(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2), (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
        lay.p.solid(lo, hi)


# ---- the floor and the footing ---------------------------------------------------------
FLOOR_RINGS = [0.0, 5.5, 10.5, 15.5, 20.5, 25.5, 30.5, 35.5, 41.0, RI + 0.6]


def build_floor(lay):
    r = lay.r
    lay.p.ground = -100.0
    # The middle: one stone of the round's centre disc (a sixteenth), its own shape.
    tmp = bmesh.new()
    kl, tl, bl = T._layers(tmp)
    ra = FLOOR_RINGS[1] - 0.03
    pts = [(0.0, 0.0)] + [(ra * math.sin(t), -ra * math.cos(t)) for t in (-H0 + 0.004, 0.0, H0 - 0.004)]
    top = [tmp.verts.new((x, y, -0.02)) for (x, y) in pts]
    bot = [tmp.verts.new((x, y, -0.62)) for (x, y) in pts]
    f = tmp.faces.new(top)
    f[kl] = T.FACE
    f[tl] = 0.97
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        sf = tmp.faces.new((top[j], top[i], bot[i], bot[j]))
        sf[kl] = T.JOINTFACE
        sf[tl] = 0.97
    tmp.normal_update()
    for ff in tmp.faces:
        if ff.normal.z < -0.5:
            ff.normal_flip()
    T._append(lay.p.near, tmp)
    tmp.free()
    for i, (r0, r1) in enumerate(zip(FLOOR_RINGS[1:], FLOOR_RINGS[2:])):
        rm = (r0 + r1) / 2
        n = max(1, round(rm * DT / (4.2 if i % 2 else 5.0)))
        for k in range(n):
            a = -H0 + DT * k / n
            b = -H0 + DT * (k + 1) / n
            tc = (a + b) / 2
            tilt = (0.0, 0.0)
            dz = r.uniform(-0.04, 0.02)
            if r.random() < 0.1:
                tilt = (r.uniform(-0.05, 0.05), r.uniform(-0.05, 0.05))
                dz += 0.1
            chord = 2.0 * rm * math.sin((b - a) / 2)
            lay.block((rm * math.sin(tc), -rm * math.cos(tc), -0.3 + dz), (chord - 0.06, r1 - r0 - 0.06, 0.6), chips=r.randint(0, 2),
                      hide=("-z",), yaw=tc, tilt=tilt, tone=0.92 + 0.12 * ((i + k) % 2))
    lay.p.far_box((0.0, -RI / 2 - 3.0, -1.5), (2.0 * RI * math.sin(H0) + 0.4, RI + 2.0, 3.0))
    lay.p.solid((-10.7, -RI - 0.6, -3.0), (10.7, 0.0, 0.0))


def build_footing(lay):
    zs = [-FOOT_H + 2.4 * i for i in range(6)]
    for z0, z1 in zip(zs, zs[1:]):
        lay.arc(RO - SKIN, RO + 0.6, -H0, H0, z0, z1, maxlen=5.0, chips=1, hide=("-z", "+z", "+y"))
    lay.far_arc(RI, RO + 0.6, -H0, H0, -FOOT_H, 0.0)
    lay.p.solid((-10.7, -RO - 0.8, -FOOT_H), (10.7, -RI + 0.9, 0.0))


# ---- the porch's roof ------------------------------------------------------------------
def build_porch_roof(lay):
    """On the entablature (z PORCH_TOP): the ceiling's beams under a slab, the
    pediment at the front, the roof's two slopes back into the drum."""
    r = lay.r
    zt = PORCH_TOP
    zc = zt - T.ENTABLATURE_H
    # Ceiling beams across, between the entablatures, and slabs over them; the
    # back edge runs into the drum's wall, never through to the inside.
    def back(x0, x1):
        return math.sqrt(max(0.0, (RI + 0.8) ** 2 - min(abs(x0), abs(x1), 0.0 if x0 < 0 < x1 else 99.0) ** 2))
    for i in range(8):
        y = -RO - 4.0 - i * (PORCH_FRONT - RO - 9.0) / 7.0
        lay.block((0.0, y, zt - 2.4), (2.0 * PORCH_HALF - 6.0, 1.4, 2.2), chips=1, hide=("+z",))
    for i in range(6):
        x0 = -PORCH_HALF + 2.0 * PORCH_HALF * i / 6
        x1 = -PORCH_HALF + 2.0 * PORCH_HALF * (i + 1) / 6
        yb = back(x0, x1)
        for j in range(8):
            y0 = -yb - (PORCH_FRONT - yb) * j / 8
            y1 = -yb - (PORCH_FRONT - yb) * (j + 1) / 8
            lay.block(((x0 + x1) / 2, (y0 + y1) / 2, zt + 0.6), (x1 - x0 - 0.04, y0 - y1 - 0.04, 1.2), chips=1, hide=("+z",))
    # The pediment: its floor (the horizontal cornice), the tympanum's courses, the raking cornices.
    yf = -PORCH_FRONT + 1.6
    rise = PORCH_HALF * math.tan(PITCH)
    lay.block((0.0, yf + 0.4, zt + 1.7), (2.0 * PORCH_HALF + 1.4, 3.2, 1.0), chips=2)
    nc = 5
    for i in range(nc):
        z0 = zt + 2.2 + rise * i / nc
        z1 = zt + 2.2 + rise * (i + 1) / nc
        hw = (PORCH_HALF - 1.0) * (1.0 - (i + 0.5) / nc)
        n = max(1, math.ceil(2 * hw / 4.0))
        for k in range(n):
            xa = -hw + 2 * hw * k / n
            xb = -hw + 2 * hw * (k + 1) / n
            lay.block(((xa + xb) / 2, yf + 1.2, (z0 + z1) / 2), (xb - xa - T.JOINT, 1.6, z1 - z0 - T.JOINT), chips=1)
    L = PORCH_HALF / math.cos(PITCH) + 1.0
    for s in (-1, 1):
        n = 6
        for k in range(n):
            d = L * (k + 0.5) / n
            x = s * (PORCH_HALF + 0.7 - d * math.cos(PITCH))
            z = zt + 2.2 + d * math.sin(PITCH) + 0.6
            lay.block((x, yf + 0.2, z), (L / n - 0.05, 3.6, 1.4), chips=2, tilt=(0.0, s * PITCH))
    # The roof: slabs down each slope from the ridge, front to the drum.
    rows = 9
    for s in (-1, 1):
        for j in range(rows):
            y0 = -PORCH_BACK + 2.0 - (PORCH_FRONT - PORCH_BACK - 1.0) * j / rows
            y1 = -PORCH_BACK + 2.0 - (PORCH_FRONT - PORCH_BACK - 1.0) * (j + 1) / rows
            for k in range(4):
                d = L * (k + 0.5) / 4
                x = s * (d * math.cos(PITCH))
                z = zt + 2.2 + rise - d * math.sin(PITCH) + 0.5
                lay.block((x, (y0 + y1) / 2, z), (L / 4 - 0.05, y0 - y1 - 0.05, 0.9), chips=r.randint(0, 2),
                          tilt=(0.0, s * PITCH), hide=("-z",))
    lay.p.far_box((0.0, -(PORCH_BACK + PORCH_FRONT) / 2, zt + 1.0), (2 * PORCH_HALF, PORCH_FRONT - PORCH_BACK, 2.0))
    for s in (-1, 1):
        lay.p.far_box((s * PORCH_HALF / 2, -(PORCH_BACK + PORCH_FRONT) / 2, zt + 2.2 + rise / 2), (PORCH_HALF, PORCH_FRONT - PORCH_BACK, rise),
                      tilt=(0.0, 0.0))
    lay.p.solid((-PORCH_HALF - 1.0, -PORCH_FRONT - 0.5, zt - 3.6), (PORCH_HALF + 1.0, -PORCH_BACK + 2.0, zt + 2.2))
    for i in range(4):
        hw = PORCH_HALF * (1.0 - i / 4)
        lay.p.solid((-hw, -PORCH_FRONT - 0.5, zt + 2.2 + rise * i / 4), (hw, -PORCH_BACK + 2.0, zt + 2.2 + rise * (i + 1) / 4 + 1.0))


# ---- what lies about -------------------------------------------------------------------
def build_slab(lay):
    """Two coffers on their shell, fallen: built upright about the origin, then tipped."""
    tilt = Matrix.Rotation(0.5, 4, "X") @ Matrix.Rotation(-0.25, 4, "Y")
    pc = math.radians(31.0)
    lift = sph(0.0, pc, RI)
    move = Matrix.Translation(Vector((0, 0, 3.2))) @ tilt @ Matrix.Rotation(-(math.pi / 2 - pc), 4, "X") @ Matrix.Translation(-lift)
    sub = Lay("tmp", 1, lay.mid)
    sub.p.near.free()
    sub.p.near = T.bmesh.new()
    T._layers(sub.p.near)
    t = math.radians(5.6)
    # The coffers and the shell's back, both from the dome's own pieces.
    w = sub.p.near
    coffers_band(sub, -t, t, math.radians(28.0), math.radians(36.0))
    sub.p.block(sph(0.0, pc, RI + 1.9), (2 * RI * math.sin(t) * math.cos(pc), 8.0 * math.pi / 180 * RI, 2.4), chips=4,
                tilt=(math.pi / 2 - pc, 0.0), far=False)
    T._append(lay.p.near, w, move)
    lay.p.far_box((0, 0, 2.6), (9.0, 7.0, 4.0), tilt=(0.5, -0.25))
    lay.p.solid((-5.0, -4.5, -0.5), (5.0, 4.5, 5.2))


def coffers_band(lay, t0, t1, pa, pb):
    """One band of coffers (for a fallen slab)."""
    old = ROWS[:]
    ROWS[:] = [math.degrees(pa), math.degrees(pb)]
    try:
        tmp_rows = ROWS
        tmp = bmesh.new()
        T._layers(tmp)
        # Reuse coffers() on its own Piece: rows outside the band are cut off by `gone`.
        coffers(lay, t0, t1, gone=lambda p: not (S + RI * math.sin(pa) - 0.1 < p.z < S + RS * math.sin(pb) + 0.1))
        tmp.free()
    finally:
        ROWS[:] = old


def build_heap(lay):
    """Blocks of the drum fallen in a heap: big ones bedded low, the rest on them."""
    r = lay.r
    lay.p.ground = 0.0
    core = [((0.0, 0.0, 2.2), (17.0, 12.0, 5.0)), ((-4.0, 3.0, 4.8), (9.0, 7.0, 4.0)), ((5.0, -3.0, 1.4), (12.0, 9.0, 3.0))]
    for c, s in core:
        lay.block(c, s, chips=4, tilt=(r.uniform(-0.12, 0.12), r.uniform(-0.12, 0.12)), yaw=r.uniform(-0.3, 0.3), tone=0.82)
    for i in range(34):
        a = r.uniform(0, math.tau)
        d = abs(r.gauss(0.0, 1.0)) * 6.5
        x, y = d * math.cos(a) * 1.3, d * math.sin(a)
        z = max(0.0, 6.5 - d * 0.75)
        sx, sy, sz = r.uniform(1.8, 4.2), r.uniform(1.4, 2.6), r.uniform(1.2, 2.4)
        lay.block((x, y, z + sz * 0.25), (sx, sy, sz), yaw=r.uniform(0, 3.1), tilt=(r.uniform(-0.5, 0.5), r.uniform(-0.4, 0.4)), chips=3)
    boxes = [((-9.0, -6.5, -1.0), (9.0, 6.5, 4.6)), ((-7.5, -1.0, 4.6), (2.0, 7.0, 7.4))]
    for lo, hi in boxes:
        lay.p.far_box(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2), (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
        lay.p.solid(lo, hi)


def bk(k):
    return {-2: "m2", -1: "m1", 0: "0", 1: "p1", 2: "p2"}[k]


JOBS = {
    "dome_drum": lambda: both("dome_drum", 81, build_drum, rot=wedge_rot(4)),
    "dome_drum_door": lambda: both("dome_drum_door", 82, lambda lay: build_drum(lay, door=True), rot=wedge_rot(DOOR_K), breach=True),
    "dome_shell": lambda: both("dome_shell", 83, build_shell, rot=wedge_rot(4)),
    "dome_floor": lambda: both("dome_floor", 84, build_floor, rot=wedge_rot(4)),
    "dome_footing": lambda: both("dome_footing", 85, build_footing, rot=wedge_rot(4)),
    "dome_porch_roof": lambda: both("dome_porch_roof", 86, build_porch_roof, rot=wedge_rot(DOOR_K), breach=True),
    "dome_slab": lambda: both("dome_slab", 87, build_slab, mid=False),
    "dome_heap": lambda: both("dome_heap", 88, build_heap),
}
for _k in (-2, -1, 0, 1, 2):
    JOBS["dome_drum_b" + bk(_k)] = (lambda k: lambda: both("dome_drum_b" + bk(k), 90 + k, lambda lay: build_drum(lay, k=k),
                                                          rot=wedge_rot(BREACH_K + k), breach=True, mid=abs(k) == 2))(_k)
    JOBS["dome_shell_b" + bk(_k)] = (lambda k: lambda: both("dome_shell_b" + bk(k), 100 + k, lambda lay: build_shell(lay, k=k),
                                                           rot=wedge_rot(BREACH_K + k), breach=True, mid=False))(_k)

for name, job in JOBS.items():
    if only is None or only == name or (only.endswith("*") and name.startswith(only[:-1])):
        job()
