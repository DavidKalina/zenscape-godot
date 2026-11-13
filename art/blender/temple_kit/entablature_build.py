"""The temple kit's entablature (lane entablature): the beam over one bay
of columns, and the same bay where the beam has failed.

    python tools/blender.py run art/blender/temple_kit/entablature_build.py [-- --only=lintel]

Both pieces share the column's frame: the origin is on the stylobate (the
surface the columns stand on) at the bay's middle, so the two columns that
carry it stand at x = -BAY/2 and +BAY/2 (Blender; Godot the same x) and the
beam's underside is at COLUMN_H (30.5). Bays chain along x every BAY; each
bay's architrave, frieze and cornice end at the column centres, so the
joints between bays land over the columns.

  lintel         architrave (two slabs deep, a taenia band with regulae),
                 a Doric frieze (triglyphs over each column and three more
                 between, square metopes), a cornice in front and back
                 halves with a cap course; one front corona block and two
                 cap blocks are gone.
  lintel_broken  the beam failed: a stub on the column at -BAY/2 juts out
                 with a stepped, ragged break (architrave furthest, then
                 frieze, then cornice); the rest lies cracked on the ground
                 below, one architrave piece leaning on the shaft of the
                 column at +BAY/2 (top 4.8 m). Nothing stands over 5 m.
"""

import math
import sys

import bmesh
from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), "")

H = T.BAY / 2                          # 9.25: a column centre
Z0 = T.COLUMN_H                        # 30.5: the beam's underside
ARCH_H = 2.9                           # the architrave's face ...
TAENIA_H = T.ARCHITRAVE_H - ARCH_H     # ... and its band on top (0.3)
Z_FRIEZE = Z0 + T.ARCHITRAVE_H         # 33.7
Z_CORNICE = Z_FRIEZE + T.FRIEZE_H      # 36.3
CORONA_H = 1.1
CAP_H = T.CORNICE_H - CORONA_H         # 0.6
D = T.ENTABLATURE_D / 2                # 2.6: the architrave's face
FRIEZE_D = D - 0.2                     # the metopes sit back 0.2
CORNICE_D = D + 0.6                    # 3.2: the corona's face
CAP_D = CORNICE_D - 0.3
TRI_W = 2.0                            # a triglyph: three bars 0.5, grooves 0.25
TRIGLYPHS = [-H + i * T.BAY / 4 for i in range(5)]   # metopes 2.625 x 2.6


# ---- helpers the library lacks (named in Notes for merge) ----------------

def slab(p, center, size, yaw=0.0, tilt=(0.0, 0.0), bevel=T.BEVEL, chips=2, chip_depth=(0.15, 0.45),
         step=0.8, wobble=0.035, breaks=(), floor=None, tone=None, far=False):
    """A long cut block with a grid of vertices on its faces (every `step`
    m), so the paint's streaks and blotches and a gentle wear (`wobble` m,
    noise along the normal) show on a beam 18 m long. `breaks` (+1/-1)
    snaps that x end off as a ragged fresh break. `floor` (Blender z)
    keeps every vertex at or above it: an architrave never sags below the
    clear height under it."""
    r = p.rng
    sx, sy, sz = size
    tmp = bmesh.new()
    tk, tt, tb = T._layers(tmp)
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    t = p.tone() if tone is None else tone
    for f in tmp.faces:
        f[tk] = T.FACE
    if bevel > 0.0:
        b = min(bevel * r.uniform(0.7, 1.4), 0.3 * min(size))
        res = bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=1, profile=0.5,
                              affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f[tk] = T.JOINTFACE
    for axis in range(3):
        n = int(size[axis] / step)
        if n < 1:
            continue
        edges = []
        for e in tmp.edges:
            d = e.verts[1].co - e.verts[0].co
            if abs(d[axis]) > 0.5 * size[axis] and abs(d[axis]) > 0.95 * d.length:
                edges.append(e)
        if edges:
            bmesh.ops.subdivide_edges(tmp, edges=edges, cuts=n, use_grid_fill=True)
    tmp.normal_update()
    seed = Vector((r.uniform(0, 100), r.uniform(0, 100), r.uniform(0, 100)))
    for v in tmp.verts:
        w = noise.noise(v.co * 0.7 + seed) * 0.7 + noise.noise(v.co * 2.1 + seed) * 0.3
        v.co += v.normal * (w * wobble - wobble * 0.3)
    for sign in breaks:
        _break_end(p, tmp, sign, size, tk, tb)
    for _ in range(chips):
        # The library's chip aims its cut from the block's centre, which on
        # a beam 18 m long slices the whole end off; here the cut faces
        # out of the corner or the edge it bites.
        s = Vector((r.choice((-1, 1)), r.choice((-1, 1)), r.choice((-1, 1))))
        corner = Vector((s.x * sx / 2, s.y * sy / 2, s.z * sz / 2))
        n = Vector((s.x * 0.8, s.y, s.z))
        d = r.uniform(*chip_depth) * min(1.0, min(size) / 0.8)
        if r.random() < 0.65:
            # A bite out of a long arris: a plane would take the whole edge,
            # so the arris's vertices near the spot are pushed in instead.
            cx = s.x * sx / 2 * r.uniform(-0.9, 0.9)
            reach = r.uniform(0.6, 1.4)
            for v in tmp.verts:
                fx = 1.0 - abs(v.co.x - cx) / reach
                fy = 1.0 - abs(v.co.y - corner.y) / max(0.2, 2.5 * d)
                fz = 1.0 - abs(v.co.z - corner.z) / max(0.2, 2.5 * d)
                w = min(fx, fy, fz)
                if w <= 0.0:
                    continue
                w = w ** 0.6
                v.co.y -= s.y * d * w * r.uniform(0.7, 1.0)
                v.co.z -= s.z * d * w * r.uniform(0.7, 1.0)
                v[tb] = max(v[tb], w)
            continue
        n = (n.normalized() + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)))).normalized()
        d = r.uniform(*chip_depth) * min(1.0, min(size) / 0.8)
        _cut(tmp, corner - n * d, n, tk, tb)
    for f in tmp.faces:
        f[tt] = t
    m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
         @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X"))
    if floor is not None:
        for v in tmp.verts:
            w = m @ v.co
            if w.z < floor:
                v.co = m.inverted() @ Vector((w.x, w.y, floor))
    T._append(p.near, tmp, m)
    tmp.free()
    if far:
        p.far_box(center, size, yaw=yaw, tilt=tilt, tone=t)


def _cut(bm, co, n, tk, tb):
    """Cuts bm by the plane (co, n), drops what lies past it and fills the
    hole as a fresh break."""
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n, clear_outer=True)
    cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if not cut:
        return
    made = bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    for f in made["faces"]:
        f[tk] = T.BROKEN
        for v in f.verts:
            v[tb] = 1.0


def _break_end(p, bm, sign, size, tk, tb):
    """Snaps the block's x end (`sign`) off: three cutting planes at odd
    angles a little way in, each hole filled as a fresh break, then the
    break's faces poked and pushed in and out so it reads rough."""
    r = p.rng
    sx, sy, sz = size
    for k in range(3):
        co = Vector((sign * (sx / 2 - r.uniform(0.15, 0.7)), r.uniform(-sy / 3, sy / 3), r.uniform(-sz / 3, sz / 3)))
        n = Vector((sign * 1.0, r.uniform(-0.9, 0.9), r.uniform(-0.9, 0.9))).normalized()
        _cut(bm, co, n, tk, tb)
    broken = [f for f in bm.faces if f[tk] == T.BROKEN and len(f.verts) > 3]
    if broken:
        res = bmesh.ops.poke(bm, faces=broken)
        for f in res["faces"]:
            f[tk] = T.BROKEN
        # Split the break's edges once more so it has points to jostle.
        faces = [f for f in bm.faces if f[tk] == T.BROKEN]
        edges = list({e for f in faces for e in f.edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if f[tk] == T.BROKEN and len(f.verts) > 3])
        for f in bm.faces:
            if f[tk] == T.BROKEN:
                for v in f.verts:
                    v[tb] = 1.0
        rough = {v for f in bm.faces if f[tk] == T.BROKEN for v in f.verts}
        for v in rough:
            v.co += Vector((sign * r.uniform(-0.2, 0.1), r.uniform(-0.05, 0.05), r.uniform(-0.05, 0.05)))


FASCIAE = (0.8, 0.95, 1.15)   # the architrave's three bands, bottom up; each steps out 0.07


def architrave(p, side, ends=(H, H, H), breaks=()):
    """One face's half of the architrave (`side` -1 front, +1 back), from
    the column centre at -H to `ends` (one x per fascia, bottom up), its
    face in three fasciae stepping out as they rise. One stone, one tone:
    the fasciae are cut from it, so their seams are tight and unworn."""
    r = p.rng
    tone = p.tone()
    z = Z0 + 0.01
    for i, (h, end) in enumerate(zip(FASCIAE, ends)):
        face = D - 0.07 * (2 - i)
        L = end + H - T.JOINT
        hh = h - (T.JOINT if i == 2 else 0.01)
        slab(p, ((-H + end) / 2 + r.uniform(-0.015, 0.015), side * (face / 2 + T.JOINT / 4), z + hh / 2),
             (L, face - T.JOINT / 2, hh),
             bevel=0.035 if i < 2 else T.BEVEL, chips=(1, 1, 3)[i], chip_depth=(0.15, 0.4), breaks=breaks,
             floor=Z0 + 0.005, tone=tone, step=0.9)
        z += h


def course(p, x0, x1, z, height, depth, y=0.0, length=(2.2, 3.6), drop=(), chips=2, shift=0.025, **kw):
    """A course of blocks along x (the library's, with each block set a
    little off true and `drop` block indices left out: missing stones).
    Returns the x spans that stand, for the far LOD."""
    r = p.rng
    x = x0
    i = 0
    spans = []
    while x < x1 - 0.3:
        L = min(r.uniform(*length), x1 - x)
        if x1 - (x + L) < 0.9:
            L = x1 - x
        if i not in drop:
            p.block((x + L / 2 + r.uniform(-shift, shift), y + r.uniform(-shift, shift), z + height / 2),
                    (L - T.JOINT, depth, height - T.JOINT), yaw=r.uniform(-0.006, 0.006),
                    chips=r.randint(1, chips), far=False, **kw)
            if spans and abs(spans[-1][1] - x) < 1e-6:
                spans[-1][1] = x + L
            else:
                spans.append([x, x + L])
        x += L
        i += 1
    return spans


def far_spans(p, spans, y, z, height, depth):
    for a, b in spans:
        p.far_box(((a + b) / 2, y, z + height / 2), (b - a, depth, height))


def triglyph(p, xc, side, x_lo=-H, x_hi=H, z=Z_FRIEZE, top=None):
    """Three upright bars with grooves between, on the frieze's face
    (`side` -1 front, +1 back), clipped to [x_lo, x_hi] so a triglyph over
    a column is half in each bay (the joint runs down its middle bar)."""
    r = p.rng
    hgt = (T.FRIEZE_H if top is None else top) - 0.08
    for off in (-0.75, 0.0, 0.75):
        a = max(xc + off - 0.25, x_lo)
        b = min(xc + off + 0.25, x_hi)
        if b - a < 0.12:
            continue
        p.block(((a + b) / 2, side * (FRIEZE_D + 0.16), z + hgt / 2), (b - a - T.JOINT * 0.5, 0.34, hgt),
                bevel=0.04, chips=r.choice((0, 0, 1)), chip_depth=(0.05, 0.12), far=False)


def regula(p, xc, side, x_lo=-H, x_hi=H):
    """The little band under the taenia below each triglyph."""
    a = max(xc - TRI_W / 2, x_lo)
    b = min(xc + TRI_W / 2, x_hi)
    if b - a < 0.2:
        return
    p.block(((a + b) / 2, side * (D + 0.05), Z0 + ARCH_H - 0.14), (b - a - T.JOINT, 0.14, 0.26),
            bevel=0.03, chips=0, far=False)


# ---- lintel ---------------------------------------------------------------

def build_lintel():
    p = T.Piece("lintel", seed=11)
    r = p.rng
    L = T.BAY - T.JOINT
    # The architrave: two stones side by side, each the bay's length,
    # meeting over the column centres, faced in three fasciae. Their
    # underside is the clear height.
    for side in (-1, 1):
        architrave(p, side)
        # The taenia: a band jutting along the top of each face.
        slab(p, (0.0, side * (D - 0.15), Z0 + ARCH_H + TAENIA_H / 2), (L, 0.54, TAENIA_H - T.JOINT * 0.5),
             bevel=0.04, chips=1, chip_depth=(0.05, 0.1), step=1.2, wobble=0.015)
        for xc in TRIGLYPHS:
            regula(p, xc, side)
    # The frieze: a core course, triglyphs proud of it on both faces.
    course(p, -H, H, Z_FRIEZE, T.FRIEZE_H, 2 * FRIEZE_D, length=(2.6, 4.2), chips=2, chip_depth=(0.15, 0.4))
    for side in (-1, 1):
        for xc in TRIGLYPHS:
            triglyph(p, xc, side)
    # The cornice: the corona in front and back halves, the cap set back on
    # it; one front corona block and the cap over it gone, another cap
    # block gone at the back.
    zc = Z_CORNICE
    front = course(p, -H, H, zc, CORONA_H, CORNICE_D - T.JOINT / 2, y=-CORNICE_D / 2, drop=(3,),
                   chips=3, chip_depth=(0.2, 0.5))
    back = course(p, -H, H, zc, CORONA_H, CORNICE_D - T.JOINT / 2, y=CORNICE_D / 2, chips=3, chip_depth=(0.2, 0.5))
    # The cap over the missing corona block must go too; spans tell where.
    gap = [(a1, b0) for (a0, a1), (b0, b1) in zip(front, front[1:])]
    cap_front = _cap(p, -1, gap)
    cap_back = _cap(p, 1, [], drop=(1,))

    # The far LOD: architrave and frieze as one box, the cornice by the
    # spans that stand.
    p.far_box((0, 0, Z0 + (T.ARCHITRAVE_H + T.FRIEZE_H) / 2), (T.BAY, 2 * D, T.ARCHITRAVE_H + T.FRIEZE_H))
    far_spans(p, front, -CORNICE_D / 2, zc, CORONA_H, CORNICE_D)
    far_spans(p, back, CORNICE_D / 2, zc, CORONA_H, CORNICE_D)
    far_spans(p, cap_front, -CAP_D / 2, zc + CORONA_H, CAP_H, CAP_D)
    far_spans(p, cap_back, CAP_D / 2, zc + CORONA_H, CAP_H, CAP_D)

    # The flight's solids: the beam, and the cornice wider over it.
    p.solid((-H, -D, Z0), (H, D, Z_CORNICE))
    p.solid((-H, -CORNICE_D, Z_CORNICE), (H, CORNICE_D, Z0 + T.ENTABLATURE_H))
    p.export()


def _cap(p, side, gaps, drop=(), x0=-H, x1=H):
    """The cap course on one half of the corona, leaving out any block
    that would sit over a gap in the corona under it."""
    r = p.rng
    spans = []
    x = x0
    i = 0
    z = Z_CORNICE + CORONA_H
    while x < x1 - 0.3:
        L = min(r.uniform(2.4, 3.8), x1 - x)
        if x1 - (x + L) < 0.9:
            L = x1 - x
        over_gap = any(x < b and x + L > a for a, b in gaps)
        if i not in drop and not over_gap:
            p.block((x + L / 2 + r.uniform(-0.03, 0.03), side * CAP_D / 2 + r.uniform(-0.03, 0.03), z + CAP_H / 2),
                    (L - T.JOINT, CAP_D - T.JOINT / 2, CAP_H - T.JOINT), yaw=r.uniform(-0.008, 0.008),
                    chips=r.randint(1, 3), chip_depth=(0.1, 0.25), far=False)
            if spans and abs(spans[-1][1] - x) < 1e-6:
                spans[-1][1] = x + L
            else:
                spans.append([x, x + L])
        x += L
        i += 1
    return spans


# ---- lintel_broken --------------------------------------------------------

def build_lintel_broken():
    p = T.Piece("lintel_broken", seed=23)
    r = p.rng
    # The stub on the column at -H, its break stepped: the architrave's
    # front slab reaches furthest, the back one shorter, the frieze and the
    # cornice shorter again.
    front_end, back_end = -3.4, -5.1
    for side, end in ((-1, front_end), (1, back_end)):
        # The stone broke in steps along its fasciae: the lowest band
        # reaches furthest, each one above it snapped shorter.
        ends = (end, end - r.uniform(0.6, 1.0), end - r.uniform(1.4, 2.0))
        architrave(p, side, ends=ends, breaks=(1,))
        tend = ends[2] - r.uniform(0.3, 0.6)
        slab(p, ((-H + tend) / 2, side * (D - 0.15), Z0 + ARCH_H + TAENIA_H / 2), (tend + H, 0.54, TAENIA_H - T.JOINT * 0.5),
             bevel=0.04, chips=1, chip_depth=(0.08, 0.15), step=1.2, wobble=0.015)
        regula(p, -H, side)
    # The frieze: one whole block on the column and a broken one beyond.
    fz = Z_FRIEZE
    p.block((-H + 1.5, 0, fz + T.FRIEZE_H / 2), (3.0 - T.JOINT, 2 * FRIEZE_D, T.FRIEZE_H - T.JOINT), chips=2)
    slab(p, (-H + 3.0 + 1.0, 0.0, fz + 1.0), (2.0 - T.JOINT, 2 * FRIEZE_D, 2.0), chips=1, breaks=(1,),
         step=1.0, wobble=0.03, far=True)
    for side in (-1, 1):
        triglyph(p, -H, side)
    triglyph(p, TRIGLYPHS[1], -1, x_hi=TRIGLYPHS[1] - 0.3, top=2.1)   # a bar and a half, broken short
    # The cornice: a block each side on the column, the front one shifted
    # out and tipped a little where the frieze under it gave.
    zc = Z_CORNICE
    p.block((-H + 1.4, -CORNICE_D / 2, zc + CORONA_H / 2), (2.8 - T.JOINT, CORNICE_D - T.JOINT, CORONA_H - T.JOINT),
            chips=3, chip_depth=(0.2, 0.5))
    slab(p, (-H + 2.9 + 0.8, -CORNICE_D / 2 - 0.25, zc + CORONA_H / 2 - 0.06), (1.6, CORNICE_D - 0.1, CORONA_H - T.JOINT),
         yaw=0.04, tilt=(0.0, 0.05), chips=1, breaks=(1,), step=1.0, wobble=0.02, far=True)
    p.block((-H + 1.9, CORNICE_D / 2, zc + CORONA_H / 2), (3.8 - T.JOINT, CORNICE_D - T.JOINT, CORONA_H - T.JOINT),
            chips=3, chip_depth=(0.2, 0.5))
    p.block((-H + 1.3, -CAP_D / 2, zc + CORONA_H + CAP_H / 2), (2.6 - T.JOINT, CAP_D, CAP_H - T.JOINT), chips=2,
            chip_depth=(0.1, 0.22))
    p.block((-H + 1.6, CAP_D / 2, zc + CORONA_H + CAP_H / 2), (3.2 - T.JOINT, CAP_D, CAP_H - T.JOINT), chips=2,
            chip_depth=(0.1, 0.22))
    # The stub's far LOD by hand (blocks added their own boxes above).
    p.far_box(((-H + front_end) / 2, -D / 2, Z0 + T.ARCHITRAVE_H / 2), (front_end + H, D, T.ARCHITRAVE_H))
    p.far_box(((-H + back_end) / 2, D / 2, Z0 + T.ARCHITRAVE_H / 2), (back_end + H, D, T.ARCHITRAVE_H))

    # ---- what fell: the rest of the beam, cracked, under where it was.
    # Architrave pieces lie on their broad faces, sunk a little, cracked.
    fall = [
        # (centre, size, yaw, tilt, breaks): the front slab's remainder.
        ((-3.2, -4.6, 1.15), (4.6, 2.9, 2.6), 0.22, (0.06, -0.05), (-1, 1)),
        ((1.4, -5.6, 1.10), (4.0, 2.9, 2.6), -0.35, (-0.08, 0.04), (-1,)),
        # The back slab's: one beside the stub's column, one tipped on edge.
        ((-2.0, 3.9, 1.20), (5.0, 2.6, 2.9), -0.12, (0.04, 0.06), (1,)),
    ]
    for c, s, yaw, tilt, br in fall:
        slab(p, c, s, yaw=yaw, tilt=tilt, chips=3, chip_depth=(0.2, 0.5), breaks=br, step=1.0, wobble=0.04, far=True)
    # The piece that came down on its end and leans on the far column's
    # shaft (x = H - 2, z 2.7), its top 4.8 m up.
    phi = math.radians(35.0)
    slab(p, (4.46, 0.5, 2.30), (5.0, 2.6, 2.6), tilt=(0.0, -phi), chips=2, breaks=(-1,), step=1.0, wobble=0.04, far=True)
    # Frieze blocks tumbled and a triglyph bar or two among them.
    for c, s, yaw, tilt in (((4.6, -3.4, 1.0), (2.6, 2.4, 2.4), 0.5, (0.12, 0.0)),
                            ((-0.9, 7.2, 0.85), (3.1, 2.2, 2.2), 1.2, (0.0, 0.18)),
                            ((5.4, 4.6, 0.75), (2.2, 2.4, 1.9), -0.4, (0.25, 0.1))):
        p.block(c, s, yaw=yaw, tilt=tilt, chips=3, chip_depth=(0.25, 0.6))
    for c, yaw in (((2.7, 1.8, 0.2), 0.9), ((-5.0, -1.3, 0.2), -0.3)):
        p.block(c, (2.3, 0.5, 0.36), yaw=yaw, tilt=(0.0, 0.1), chips=1, chip_depth=(0.05, 0.12), far=False)
    # Cornice blocks: one split in two, the rest scattered wide.
    for c, s, yaw, tilt in (((-5.6, -8.2, 0.42), (2.9, 3.0, 1.1), 0.3, (0.0, 0.05)),
                            ((-3.3, -9.0, 0.36), (2.0, 3.0, 1.05), 0.55, (0.08, -0.12)),
                            ((6.6, -7.4, 0.4), (3.3, 3.2, 1.1), -0.6, (-0.15, 0.0)),
                            ((2.6, 8.1, 0.5), (3.0, 3.1, 1.1), 0.9, (0.0, 0.0)),
                            ((-6.0, 6.8, 0.26), (2.5, 2.8, 0.6), -0.2, (0.1, 0.05))):
        p.block(c, s, yaw=yaw, tilt=tilt, chips=3, chip_depth=(0.2, 0.45))
    # Spalls and rubble round them.
    for _ in range(14):
        a = r.uniform(0, math.tau)
        rad = r.uniform(2.0, 9.0)
        c = (r.uniform(-5.5, 6.0), math.sin(a) * rad, 0.0)
        s = (r.uniform(0.35, 1.1), r.uniform(0.3, 0.9), r.uniform(0.25, 0.6))
        p.block((c[0], c[1], s[2] * 0.35), s, yaw=r.uniform(0, math.tau), tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)),
                bevel=0.05, chips=2, chip_depth=(0.08, 0.2), far=False)

    # The flight's solids: the stub, and the fallen heaps as low boxes.
    p.solid((-H, -D, Z0), (front_end, 0.0, Z_CORNICE))
    p.solid((-H, 0.0, Z0), (back_end, D, Z_CORNICE))
    p.solid((-H, -CORNICE_D, Z_CORNICE), (-H + 4.6, CORNICE_D, Z0 + T.ENTABLATURE_H))
    p.solid((-6.0, -7.2, 0.0), (6.4, -2.0, 2.8))       # the front slab's pieces, a frieze block
    p.solid((-4.8, 2.4, 0.0), (1.4, 8.5, 2.9))         # the back slab's piece, a frieze block
    p.solid((2.9, -0.9, 0.0), (7.3, 1.9, 4.8))         # the leaning piece
    p.solid((3.8, 3.2, 0.0), (7.2, 6.0, 2.3))          # a frieze block
    p.solid((-7.4, -10.2, 0.0), (8.6, -6.2, 1.3))      # cornice blocks, front
    p.solid((-7.6, 5.4, 0.0), (4.6, 9.8, 1.3))         # cornice blocks, back
    p.export()


if only in ("", "lintel"):
    build_lintel()
if only in ("", "lintel_broken"):
    build_lintel_broken()
