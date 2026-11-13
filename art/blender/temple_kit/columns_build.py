"""The temple kit's lane `columns`: a column broken off a third of the way up
(`column_broken`) and what fell from one (`column_drums`).

    python tools/blender.py run art/blender/temple_kit/columns_build.py [-- --only=column_broken]

Helpers here the library may absorb (Notes for merge):
- `placed(p, matrix, fn)`: runs any of Piece's near-mesh builders (drum, ring)
  into a scratch bmesh and appends it through `matrix`, so a drum can lie on
  its side, tilt, or sink.
- `shatter(bm, ...)`: cuts a closed mesh with a few planes near its top and
  fills each cut as a rough fresh break (poked and jittered), for a drum
  that split rather than one sawn flat.
"""

import math
import sys

import bmesh
from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

R_FOOT = T.COLUMN_D / 2
R_NECK = T.COLUMN_D_TOP / 2


def radius_at(i):
    """The shaft's radius at the foot of drum i (0 = the lowest)."""
    return R_FOOT + (R_NECK - R_FOOT) * i / T.DRUMS


# ---- helpers (for the library) ------------------------------------------
def scratch(p, fn):
    """Runs a Piece builder that writes into p.near into a fresh bmesh
    instead, and returns that bmesh (the caller appends and frees it)."""
    keep = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    try:
        fn()
    finally:
        p.near = keep
    return tmp


def placed(p, matrix, fn):
    tmp = scratch(p, fn)
    T._append(p.near, tmp, matrix)
    tmp.free()


def shatter(p, bm, cuts, rough=0.12):
    """Cuts bm with each plane in `cuts` ((point, normal), keeping the side
    the normal points away from) and fills the cut as a fresh break, poked
    and jittered so it reads split, not sawn."""
    kind, tone, broke = T._layers(bm)
    t = next(iter(bm.faces))[tone] if bm.faces else 1.0
    for cut_ in cuts:
        co, no = cut_[0], cut_[1]
        hidden = len(cut_) > 2 and cut_[2] == "hidden"   # a face another part covers: left flat
        no = Vector(no).normalized()
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=no, clear_outer=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if not cut:
            continue
        made = bmesh.ops.holes_fill(bm, edges=cut, sides=0)["faces"]
        for f in made:
            f[kind] = T.BROKEN
            f[tone] = t
            for v in f.verts:
                v[broke] = 1.0
        if not hidden:
            for f in made:
                rough_face(p, bm, f, no, rough)


class Piece(T.Piece):
    """The library's piece, its fresh breaks kept pale over the moss and
    streaks paint() lays on (a break faces up as often as not here)."""

    def paint(self, bm, far=False):
        col = super().paint(bm, far=far)
        if far:
            return col
        kind, tone, broke = T._layers(bm)
        for f in bm.faces:
            if f[kind] != T.BROKEN:
                continue
            fresh = T.srgb_to_linear(tuple(x * f[tone] for x in T.STONE_FRESH))
            for loop in f.loops:
                w = 0.7 * loop.vert[broke]
                c = loop[col]
                loop[col] = tuple(c[i] + (fresh[i] - c[i]) * w for i in range(3)) + (1.0,)
        return col


def rough_face(p, bm, f, no, rough, rings=3):
    """Replaces a flat break face by rings drawn in from its rim toward its
    middle (lerped, so they can't fold out of a star-shaped rim), each
    vertex pushed along the cut's normal by noise that grows from the rim
    in: hollows and lips, a split, not a sawn face."""
    r = p.rng
    kind, tone, broke = T._layers(bm)
    t = f[tone]
    rim = list(f.verts)
    c = sum((v.co for v in rim), Vector()) / len(rim)
    ph = Vector((r.uniform(0, 50), r.uniform(0, 50), r.uniform(0, 50)))
    bm.faces.remove(f)

    def push(co, w):
        n1 = noise.noise((co + ph) * 1.3)
        n2 = noise.noise((co + ph) * 3.7)
        return co + no * (n1 * 1.4 + n2 * 0.45) * rough * w

    rows = [rim]
    for k in range(1, rings + 1):
        s = k / (rings + 1)
        row = []
        for v in rim:
            nv = bm.verts.new(push(v.co.lerp(c, s), min(1.0, s * 2.2)))
            nv[broke] = 1.0
            row.append(nv)
        rows.append(row)
    mid = bm.verts.new(push(c, 1.0) + no * r.uniform(-rough, rough * 0.5))
    mid[broke] = 1.0
    for v in rim:
        v[broke] = 1.0
    made = []
    n = len(rim)
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            try:
                made.append(bm.faces.new((a[i], a[j], b[j], b[i])))
            except ValueError:
                pass
    last = rows[-1]
    for i in range(n):
        try:
            made.append(bm.faces.new((last[i], last[(i + 1) % n], mid)))
        except ValueError:
            pass
    for g in made:
        g[kind] = T.BROKEN
        g[tone] = t


def drum_bm(p, i, chips, samples=6, shift=0.0, yaw=None, tone=None):
    """Drum i of the shaft (its taper), its foot at the origin."""
    return scratch(p, lambda: p.drum((0, 0, T.JOINT / 2), T.DRUM_H - T.JOINT, radius_at(i), radius_at(i + 1),
                                     chips=chips, yaw=yaw, shift=shift, samples=samples, flute_depth=0.17,
                                     bite=(0.15, 0.55), tone=tone))


def lie(axis_yaw, roll=0.0, pitch=0.0):
    """A drum's frame lying down: its axis (local z) laid along `axis_yaw`
    in the ground plane, turned `roll` about its own axis, then its far end
    raised by `pitch`. The drum's foot centre stays at the origin."""
    return (Matrix.Rotation(axis_yaw, 4, "Z") @ Matrix.Rotation(-pitch, 4, "Y")
            @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Rotation(roll, 4, "Z"))


# ---- column_broken -------------------------------------------------------
def column_broken(seed=11):
    p = Piece("column_broken", seed=seed)
    r = p.rng
    # The base, as the standing column's.
    p.block((0, 0, T.PLINTH_H / 2), (T.PLINTH, T.PLINTH, T.PLINTH_H), bevel=0.09, chips=3,
            chip_depth=(0.2, 0.5))
    p.ring((0, 0, T.PLINTH_H), [(R_FOOT + 0.15, 0.0), (R_FOOT + 0.38, 0.12), (R_FOOT + 0.45, 0.3),
                                (R_FOOT + 0.38, 0.48), (R_FOOT + 0.05, T.TORUS_H)], segments=56, chips=2,
           bite=(0.12, 0.3))

    # Three whole drums, the upper two walked off true by the fall that
    # took the rest: slid sideways and rocked on their beds.
    z = T.BASE_H
    off = Vector((0.0, 0.0))
    lean = [(0.0, 0.0), (0.012, -0.006), (0.028, -0.014)]
    slide = [Vector((0, 0)), Vector((0.10, 0.04)), Vector((0.24, 0.12))]
    for i in range(3):
        off = slide[i]
        ax, ay = lean[i]
        m = (Matrix.Translation((off.x, off.y, z)) @ Matrix.Rotation(ax, 4, "X") @ Matrix.Rotation(ay, 4, "Y"))
        bm = drum_bm(p, i, chips=r.choice((1, 2, 3)), shift=0.0)
        T._append(p.near, bm, m)
        bm.free()
        z += T.DRUM_H

    # The fourth drum split as the column fell: a stepped, jagged top, low
    # on the side it fell toward (+x), a tooth standing on the other.
    top_m = (Matrix.Translation((0.34, 0.16, z)) @ Matrix.Rotation(0.04, 4, "X")
             @ Matrix.Rotation(-0.02, 4, "Y"))
    t = p.tone()
    H = T.DRUM_H
    # One drum split by shared planes into three parts that abut: the low
    # shelf (the whole round under P1), the step (the back half, P1 to P2)
    # and the tooth (a wedge of the back edge, P2 to P3).
    def neg(c):
        return (c[0], tuple(-x for x in c[1]), "hidden")
    P1 = ((0, 0, 0.75), (0.24, 0.05, 1.0))
    P2 = ((0, 0, 1.55), (0.16, -0.10, 1.0))
    S1 = ((0.35, 0, 0), (1.0, 0.25, 0.0))
    S1b = ((0.35, -0.7, 0), (0.7, -1.0, 0.0))
    S2 = ((-0.55, 0, 0), (1.0, -0.35, 0.0))
    S3 = ((-0.9, 0.95, 0), (0.25, 1.0, 0.0))
    P3 = ((-1.3, 0, 2.3), (0.55, 0.25, 1.0))
    parts = ([P1, ((1.2, -0.9, 0.62), (0.45, -0.35, 1.0))],
             [neg(P1), S1, S1b, P2],
             [neg(P2), S1, S1b, S2, S3, P3])
    for k, cuts in enumerate(parts):
        bm = drum_bm(p, 3, chips=(1 if k == 0 else 0), tone=t, yaw=0.3)
        shatter(p, bm, cuts, rough=0.26 - 0.03 * k)
        T._append(p.near, bm, top_m)
        bm.free()

    # Spalls from the break at the foot, on the side it fell.
    for k in range(5):
        a_ = r.uniform(-0.9, 0.9)
        d = r.uniform(3.0, 5.2)
        s = r.uniform(0.35, 0.8)
        p.block((math.cos(a_) * d, math.sin(a_) * d, s * 0.3), (s * 1.3, s, s * 0.7), yaw=r.uniform(0, 3),
                tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), bevel=0.04, chips=2,
                chip_depth=(0.05, 0.15), far=False, kind=T.FACE)

    # Far LOD: the base and the stump to a mean break height, with the step.
    p.far_cylinder((0, 0, T.PLINTH_H), T.TORUS_H + 3 * T.DRUM_H + 0.9, R_FOOT + 0.1, radius_at(3.4), segments=12)
    p.far_box((0, 0, T.PLINTH_H / 2), (T.PLINTH, T.PLINTH, T.PLINTH_H))
    p.far_box((-0.6, 0.15, z + 1.2), (1.4, 2.4, 1.5), yaw=0.3)
    stump_top = z + 0.85
    # Solids: the plinth, the stump to its shelf, the tooth.
    h = T.PLINTH / 2
    p.solid((-h, -h, 0.0), (h, h, T.BASE_H))
    s = R_FOOT * 0.9
    p.solid((-s, -s, T.BASE_H), (s + 0.3, s + 0.15, stump_top))
    p.solid((-1.5, -1.0, stump_top), (0.2, 1.3, z + 2.2))
    p.export()


# ---- column_drums --------------------------------------------------------
def column_drums(seed=23):
    """A column that toppled toward +x: its drums in a rough line where they
    landed, the capital beyond them. Origin: where the column stood, so it
    pairs with column_broken at the same point (the stump fell toward +x);
    the line runs from 8 m to 28 m out."""
    p = Piece("column_drums", seed=seed)
    r = p.rng
    far_r = []

    def lying(i, foot, axis_yaw, roll, pitch=0.0, sink=0.0, chips=3):
        """Drum i lying with its foot-face centre at `foot` (x, y), its axis
        along axis_yaw, resting on the ground (sunk `sink` m)."""
        rad = (radius_at(i) + radius_at(i + 1)) / 2
        z = rad - 0.06 - sink
        bm = drum_bm(p, i, chips=chips, yaw=roll)
        m = Matrix.Translation((foot[0], foot[1], z)) @ lie(axis_yaw, 0.0, pitch)
        T._append(p.near, bm, m)
        bm.free()
        p.far_cylinder((0, 0, 0), T.DRUM_H, radius_at(i), radius_at(i + 1), segments=10,
                       matrix=Matrix.Translation((foot[0], foot[1], z)) @ lie(axis_yaw, 0.0, pitch))
        far_r.append(rad)
        return z, rad

    # The column came down whole and burst at its joints: the drums lie
    # where they landed, in a line along the fall, axes along it, each
    # knocked a little aside and turned, gaps where they parted. They run
    # from ~8 m out, the capital (the top, 30 m up) farthest.
    # 1: on its side, half sunk in the turf.
    lying(5, (8.2, -0.2), 0.06, 0.4, sink=0.9, chips=2)
    # 2 and 3: on their sides, nearly end to end, 3 slewed.
    lying(6, (10.95, 0.25), -0.08, 1.7, sink=0.05, chips=3)
    lying(7, (13.75, 0.75), 0.20, 3.1, sink=0.08, chips=3)
    # 4: came down end first and leans back against 3's end, its foot
    # dug in: tilted 0.7 rad toward the stump.
    q = 0.7
    bm = drum_bm(p, 8, chips=3, yaw=2.6)
    rr = radius_at(8)
    m4 = (Matrix.Translation((19.3, 1.45, rr * math.sin(q) - 0.25)) @ Matrix.Rotation(-q, 4, "Y")
          @ Matrix.Rotation(0.05, 4, "X"))
    T._append(p.near, bm, m4)
    bm.free()
    p.far_cylinder((0, 0, 0), T.DRUM_H, radius_at(8), radius_at(9), segments=10, matrix=m4)

    # The capital, beyond: thrown farthest, landed upside down on its
    # abacus, tipped so one edge is dug in and the echinus's bowl shows.
    # Built upright (echinus foot at z 0, abacus top at 1.8), turned over
    # about its middle, tipped, lowered so the low edge sinks ~0.3 m.
    cap_m = (Matrix.Translation((24.6, -0.6, 1.40)) @ Matrix.Rotation(0.5, 4, "Z")
             @ Matrix.Rotation(0.35, 4, "Y") @ Matrix.Rotation(math.pi, 4, "X")
             @ Matrix.Translation((0, 0, -(T.ECHINUS_H + T.ABACUS_H) / 2)))
    RT = R_NECK
    placed(p, cap_m, lambda: p.ring((0, 0, 0), [(RT - 0.05, 0.0), (RT + 0.05, 0.12), (RT + 0.45, 0.4),
                                                (RT + 0.85, 0.75), (RT + 0.9, T.ECHINUS_H)],
                                    segments=48, chips=3, bite=(0.15, 0.45)))
    # The abacus through block(): it carries its own matrix by centre/yaw/tilt,
    # so build it in a scratch piece-bmesh and place it with the same matrix.
    keep_far = p.far
    p.far = bmesh.new()
    T._layers(p.far)
    placed(p, cap_m, lambda: p.block((0, 0, T.ECHINUS_H + T.ABACUS_H / 2), (T.ABACUS, T.ABACUS, T.ABACUS_H),
                                     bevel=0.08, chips=4, chip_depth=(0.25, 0.6)))
    T._append(keep_far, p.far, cap_m)
    p.far.free()
    p.far = keep_far
    p.far_cylinder((0, 0, 0), T.ECHINUS_H, RT, RT + 0.9, segments=10, matrix=cap_m)

    # Spalls where things struck: chips by the drums and the capital.
    for (cx, cy, n) in ((10.8, -2.3, 3), (16.4, -1.4, 3), (21.0, -2.2, 3), (22.5, 3.0, 2)):
        for _ in range(n):
            s = r.uniform(0.3, 0.7)
            p.block((cx + r.uniform(-1.5, 1.5), cy + r.uniform(-1.2, 1.2), s * 0.25), (s * 1.4, s, s * 0.6),
                    yaw=r.uniform(0, 3), tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), bevel=0.04,
                    chips=2, chip_depth=(0.05, 0.15), far=False)

    # Solids: each drum and the capital as a box around what stands proud
    # of the grass (coarse; the plane only needs the bulk).
    p.solid((8.1, -2.1, -0.3), (10.8, 1.8, 2.9))        # 1, half sunk
    p.solid((10.8, -1.7, 0.0), (16.6, 3.0, 3.7))        # 2 and 3
    p.solid((16.3, -0.4, -0.3), (20.8, 3.3, 4.0))       # 4, leaning on 3
    p.solid((21.4, -3.6, -0.3), (27.8, 2.4, 3.4))       # the capital
    p.export()


if only in (None, "column_broken"):
    column_broken()
if only in (None, "column_drums"):
    column_drums()
