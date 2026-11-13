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
         step=0.8, wobble=0.035, breaks=(), floor=None, tone=None, far=False, hide=()):
    """A long cut block with a grid of vertices on its faces (every `step`
    m), so the paint's streaks and blotches and a gentle wear (`wobble` m,
    noise along the normal) show on a beam 18 m long. `breaks` (+1/-1)
    snaps that x end off as a ragged fresh break. `floor` (Blender z)
    keeps every vertex at or above it: an architrave never sags below the
    clear height under it. `hide`: faces no one sees (pressed on the next
    stone, under the course above), flattened after the wear so they cost
    one cap each (see _flatten)."""
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
    _flatten(tmp, tk, hide)
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


def _dirs(n):
    """A face normal's directions as '+x', '-z', ...: every axis it leans
    along by more than 0.3 (a flat face one, a bevel two, a corner three)."""
    return [("+" if n[i] > 0 else "-") + "xyz"[i] for i in range(3) if abs(n[i]) > 0.3]


def _flatten(bm, tk, hide):
    """Dissolves the faces no one sees into one face per side. `hide` holds
    directions ('+z', '-y') of the block's own frame, or (direction, x_max)
    for a side covered only where x < x_max (a stepped break). A face goes
    when every direction it leans along is hidden there (so a bevel between
    a hidden top and a seen front stays); fresh breaks always stay. The
    wear, chips and draws ran first, on the full grid, and the seen faces
    keep every vertex: they look as before. Points left on a straight run
    between two flattened faces go too."""
    if not hide:
        return
    bm.normal_update()
    lim = {}
    for h in hide:
        d, xm = (h, math.inf) if isinstance(h, str) else h
        lim[d] = xm
    groups = {}
    for f in bm.faces:
        if f[tk] == T.BROKEN:
            continue
        ds = _dirs(f.normal)
        if not ds:
            continue
        cx = f.calc_center_median().x
        if all(d in lim and cx < lim[d] for d in ds):
            groups.setdefault(tuple(ds), []).append(f)
    flat = set()
    for fs in groups.values():
        res = bmesh.ops.dissolve_faces(bm, faces=fs, use_verts=False)
        flat.update(res["region"])
    flat = {f for f in flat if f.is_valid}
    lone = [v for v in bm.verts if len(v.link_edges) == 2 and all(f in flat for f in v.link_faces)]
    if lone:
        bmesh.ops.dissolve_verts(bm, verts=lone)


def _drop(bm, tk, press=(), hide=()):
    """Deletes faces no one sees from a small block: every face leaning
    toward a `press` direction (the block sits flat on a stone that closes
    it there: a bar's back on the frieze), and every face whose directions
    all lie in `press` + `hide` (a bottom on the course below, but not the
    bevel between it and a seen face). Fresh breaks stay."""
    bm.normal_update()
    gone = []
    for f in bm.faces:
        if f[tk] == T.BROKEN:
            continue
        ds = _dirs(f.normal)
        if any(d in press for d in ds) or (ds and all(d in press or d in hide for d in ds)):
            gone.append(f)
    if gone:
        bmesh.ops.delete(bm, geom=gone, context="FACES")


def block(p, *a, press=(), hide=(), **k):
    """The library's block, its unseen faces dropped (_drop). The block is
    built on a scratch mesh, so the draws are the library's own."""
    near = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    try:
        out = p.block(*a, **k)
    finally:
        p.near = near
    tk = T._layers(tmp)[0]
    _drop(tmp, tk, press, hide)
    T._append(near, tmp)
    tmp.free()
    return out


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
        # In index order, not a set's: a set of BMesh elements iterates by
        # memory address, which made every build of a broken piece come out
        # different (the jostle's draws landed on other vertices, and the
        # chips after it drew a different number of times).
        bm.edges.index_update()
        edges = sorted({e for f in faces for e in f.edges}, key=lambda e: e.index)
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if f[tk] == T.BROKEN and len(f.verts) > 3])
        for f in bm.faces:
            if f[tk] == T.BROKEN:
                for v in f.verts:
                    v[tb] = 1.0
        bm.verts.index_update()
        rough = sorted({v for f in bm.faces if f[tk] == T.BROKEN for v in f.verts}, key=lambda v: v.index)
        for v in rough:
            v.co += Vector((sign * r.uniform(-0.2, 0.1), r.uniform(-0.05, 0.05), r.uniform(-0.05, 0.05)))


FASCIAE = (0.8, 0.95, 1.15)   # the architrave's three bands, bottom up; each steps out 0.07


def architrave(p, side, ends=(H, H, H), breaks=(), top_to=None, inner_to=math.inf):
    """One face's half of the architrave (`side` -1 front, +1 back), from
    the column centre at -H to `ends` (one x per fascia, bottom up), its
    face in three fasciae stepping out as they rise. One stone, one tone:
    the fasciae are cut from it, so their seams are tight and unworn.
    Unseen and flattened: the inner face (on the other stone, to x
    `inner_to`), each fascia's top (under the next, to x `top_to[i]`; the
    whole length by default) and the upper two fasciae's bottoms (on the
    one below, which reaches as far or further). The soffit stays whole."""
    r = p.rng
    tone = p.tone()
    z = Z0 + 0.01
    inner = "-y" if side > 0 else "+y"
    top_to = top_to or (math.inf,) * 3
    for i, (h, end) in enumerate(zip(FASCIAE, ends)):
        face = D - 0.07 * (2 - i)
        L = end + H - T.JOINT
        hh = h - (T.JOINT if i == 2 else 0.01)
        cx = (-H + end) / 2 + r.uniform(-0.015, 0.015)
        hide = [(inner, inner_to - cx), ("+z", top_to[i] - cx)] + (["-z"] if i > 0 else [])
        slab(p, (cx, side * (face / 2 + T.JOINT / 4), z + hh / 2),
             (L, face - T.JOINT / 2, hh),
             bevel=0.035 if i < 2 else T.BEVEL, chips=(1, 1, 3)[i], chip_depth=(0.15, 0.4), breaks=breaks,
             floor=Z0 + 0.005, tone=tone, step=0.9, hide=hide)
        z += h


def course(p, x0, x1, z, height, depth, y=0.0, length=(2.2, 3.6), drop=(), chips=2, shift=0.025,
           press=(), **kw):
    """A course of blocks along x (the library's, with each block set a
    little off true and `drop` block indices left out: missing stones).
    Returns the x spans that stand, for the far LOD. `press`: sides closed
    by a neighbour (_drop)."""
    r = p.rng
    x = x0
    i = 0
    spans = []
    while x < x1 - 0.3:
        L = min(r.uniform(*length), x1 - x)
        if x1 - (x + L) < 0.9:
            L = x1 - x
        if i not in drop:
            block(p, (x + L / 2 + r.uniform(-shift, shift), y + r.uniform(-shift, shift), z + height / 2),
                  (L - T.JOINT, depth, height - T.JOINT), yaw=r.uniform(-0.006, 0.006),
                  chips=r.randint(1, chips), far=False, press=press, **kw)
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
        # Its back sits on the frieze, its foot on the taenia: neither is seen.
        block(p, ((a + b) / 2, side * (FRIEZE_D + 0.16), z + hgt / 2), (b - a - T.JOINT * 0.5, 0.34, hgt),
              bevel=0.04, chips=r.choice((0, 0, 1)), chip_depth=(0.05, 0.12), far=False,
              press=("-y" if side > 0 else "+y",), hide=("-z",))


def regula(p, xc, side, x_lo=-H, x_hi=H):
    """The little band under the taenia below each triglyph."""
    a = max(xc - TRI_W / 2, x_lo)
    b = min(xc + TRI_W / 2, x_hi)
    if b - a < 0.2:
        return
    block(p, ((a + b) / 2, side * (D + 0.05), Z0 + ARCH_H - 0.14), (b - a - T.JOINT, 0.14, 0.26),
          bevel=0.03, chips=0, far=False, press=("-y" if side > 0 else "+y",), hide=("+z",))


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
             bevel=0.04, chips=1, chip_depth=(0.05, 0.1), step=1.2, wobble=0.015,
             hide=("-y" if side > 0 else "+y", "-z"))
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
    # The two halves meet in the middle: the back half's inner face closes
    # the joint, so the front half's goes. (The back half keeps its own: a
    # joint with no face on either side shows the sky through it.)
    front = course(p, -H, H, zc, CORONA_H, CORNICE_D - T.JOINT / 2, y=-CORNICE_D / 2, drop=(3,),
                   chips=3, chip_depth=(0.2, 0.5), press=("+y",))
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
        # Unseen only where the stone above or beside still stands: each
        # fascia's top to the next one's break (the top one's to the taenia's,
        # drawn just after, at least 0.6 shorter, and the frieze's end), the
        # front stone's inner face as far as the back stone reaches (its
        # fasciae end 0 to 2 m short of back_end), the back's all along.
        architrave(p, side, ends=ends, breaks=(1,), top_to=(ends[1], ends[2], min(ends[2] - 0.6, -H + 3.0)),
                   inner_to=back_end - 2.0 if side < 0 else math.inf)
        tend = ends[2] - r.uniform(0.3, 0.6)
        # Its foot on the fascia (longer), its inner face under the frieze
        # (to the whole block's end).
        tx = (-H + tend) / 2
        slab(p, (tx, side * (D - 0.15), Z0 + ARCH_H + TAENIA_H / 2), (tend + H, 0.54, TAENIA_H - T.JOINT * 0.5),
             bevel=0.04, chips=1, chip_depth=(0.08, 0.15), step=1.2, wobble=0.015,
             hide=(("-y" if side > 0 else "+y", -H + 3.0 - tx), "-z"))
        regula(p, -H, side)
    # The frieze: one whole block on the column. The broken one beyond it
    # (x -6.25..-4.25) came down: its back half had nothing under it (the
    # back architrave is snapped off at -6.8 and shorter), so it lies on
    # the ground under the stub, with the cornice block it carried and its
    # broken triglyph bar. (Same sizes and draws as when they stood.)
    fz = Z_FRIEZE
    p.block((-H + 1.5, 0, fz + T.FRIEZE_H / 2), (3.0 - T.JOINT, 2 * FRIEZE_D, T.FRIEZE_H - T.JOINT), chips=2)
    slab(p, (-3.4, 0.8, 0.8), (2.0 - T.JOINT, 2 * FRIEZE_D, 2.0), yaw=1.3, tilt=(0.06, -0.08), chips=1, breaks=(1,),
         step=1.0, wobble=0.03, far=True, hide=("-z",))
    for side in (-1, 1):
        triglyph(p, -H, side)
    # The bar and a half, broken short: the half is clipped away, the bar
    # lies on its side by the frieze block.
    r_chips = r.choice((0, 0, 1))
    block(p, (-1.6, -1.7, 0.16), (0.5 - T.JOINT * 0.5, 0.34, 2.1 - 0.08), yaw=0.15, tilt=(0.0, 1.52),
          bevel=0.04, chips=r_chips, chip_depth=(0.05, 0.12), far=False)
    # The cornice: a block each side on the column; the front one's broken
    # neighbour fell with the frieze block under it.
    zc = Z_CORNICE
    # The front corona and cap blocks' inner faces are on the back ones,
    # which reach further.
    block(p, (-H + 1.4, -CORNICE_D / 2, zc + CORONA_H / 2), (2.8 - T.JOINT, CORNICE_D - T.JOINT, CORONA_H - T.JOINT),
          chips=3, chip_depth=(0.2, 0.5), press=("+y",))
    slab(p, (0.6, -0.3, 0.42), (1.6, CORNICE_D - 0.1, CORONA_H - T.JOINT),
         yaw=0.3, tilt=(0.05, -0.06), chips=1, breaks=(1,), step=1.0, wobble=0.02, far=True,
         hide=("-z",))
    p.block((-H + 1.9, CORNICE_D / 2, zc + CORONA_H / 2), (3.8 - T.JOINT, CORNICE_D - T.JOINT, CORONA_H - T.JOINT),
            chips=3, chip_depth=(0.2, 0.5))
    block(p, (-H + 1.3, -CAP_D / 2, zc + CORONA_H + CAP_H / 2), (2.6 - T.JOINT, CAP_D, CAP_H - T.JOINT), chips=2,
          chip_depth=(0.1, 0.22), press=("+y",))
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
        slab(p, c, s, yaw=yaw, tilt=tilt, chips=3, chip_depth=(0.2, 0.5), breaks=br, step=1.0, wobble=0.04, far=True,
             hide=("-z",))   # the face it lies on, sunk in the ground
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
    p.solid((-6.0, -2.0, 0.0), (2.0, 2.4, 2.0))        # the stub's broken frieze block, its cornice, a bar
    p.export()


if only in ("", "lintel"):
    build_lintel()
if only in ("", "lintel_broken"):
    build_lintel_broken()
