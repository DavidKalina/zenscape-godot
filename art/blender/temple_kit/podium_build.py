"""The temple kit's podium (lane podium): the stepped platform the temple
stands on, as three pieces that snap to the bay.

    python tools/blender.py run art/blender/temple_kit/podium_build.py [-- --only=podium,podium_stair]

Layout (Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y)):
- Every piece's origin is on the ground (z 0) under a column's centre on
  the top step line. The stylobate's top (the paved top) is at z 3.0, so a
  column stands at (0, 0, 3.0).
- `podium`: one bay, x -9.25..9.25. Its steps face -y: step fronts at
  y -6.2, -4.6, -3.0 (1.0 rise, 1.6 tread). The paved top runs from the
  stylobate's edge (y -3.0) back to y 6.0; the site's floor goes on
  behind it. Bays chain along x every BAY.
- `podium_corner`: the corner column at the origin; the edge comes in
  along x from -9.25 (facing -y) and turns to run along +y (facing +x)
  to y 9.25. The side bays are `podium` turned +90 deg about z (Godot
  rotation.y = +PI/2) at (0, BAY*k). The inner corner (x < -6, y > 6) is
  left open for the site's floor.
- `podium_stair`: a bay with a flight up its middle that juts 1.6 m in
  front of the bottom step (front at y -7.8).

Each course (a step, a paving row, the footing) runs from -BAY/2 + s to
BAY/2 + s with its own shift s, so the joints at a bay's ends never line
up: chained bays show no seam.
Every piece has a plain footing to 6.5 m below its ground line.
"""

import math
import sys

import bmesh
import temple_lib as T
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = next((a.split("=")[1].split(",") for a in args if a.startswith("--only=")), None)

HB = T.BAY / 2                         # 9.25
FRONT = [-6.2, -4.6, -3.0]             # step fronts (y), steps 0..2
DEPTH = [2.0, 2.0, 2.6]                # a step block's depth (tucks under the next)
BACK = 6.0                             # the paved top's back edge
SLAB_Z = T.PODIUM_H - 0.45             # paving slabs: 0.45 thick on the core
FOOT = -6.5                            # the footing's bottom
# Each course's shift along the edge, so bay ends don't make a seam.
SHIFT = {"step0": 1.3, "step1": -0.9, "step2": 0.5, "row0": 1.7, "row1": -1.1, "row2": 0.2,
         "foot0": 2.1, "foot1": -1.6}
ROWS = [(-0.4, 1.9), (1.9, 4.0), (4.0, BACK)]   # paving rows (v0, v1)

# The pieces whose mid LOD (<id>_mid.glb) a plain run builds. Empty: the
# mids (--only=podium_mid etc.) don't yet read as the near at 50-90 m (the
# near's pale chip facets lighten its step fronts; the mid's are darker).
MIDS = ()

EARTH = 3                             # a face kind of our own: soil showing in a gap
EARTH_COL = (0.30, 0.29, 0.19)


class Podium(T.Piece):
    """A Piece that also paints EARTH faces (soil in the gaps) dark loam."""

    def paint(self, bm, far=False):
        col = super().paint(bm, far)
        kind, tone, broke = T._layers(bm)
        for f in bm.faces:
            if f[kind] != EARTH:
                continue
            for loop in f.loops:
                p = loop.vert.co
                n = T.noise.noise(Vector((p.x * 0.7, p.y * 0.7, 3.0))) * 0.5 + 0.5
                c = T.mix(EARTH_COL, T.MOSS, 0.3 + 0.5 * n)
                loop[col] = T.srgb_to_linear(c) + (1.0,)
        return col

    # On a mid build (`mid` a bmesh) the near is still built, every draw as
    # it was, and thrown away; each stone also goes into `mid` as a plain
    # box (put), and soil and quads go into both.
    mid = None

    def _targets(self):
        return [self.near] + ([self.mid] if self.mid is not None else [])

    def soil(self, fr, u0, u1, v0, v1, height, nu=5, nv=6, tuck=0.25):
        """A lumpy patch of soil over u0..u1 x v0..v1: `height(u, v)` its
        mean, its rim dropped `tuck` so it tucks under the stones round it."""
        for bm in self._targets():
            k, t, b = T._layers(bm)
            grid = []
            for i in range(nu + 1):
                row = []
                for j in range(nv + 1):
                    u = u0 + (u1 - u0) * i / nu
                    v = v0 + (v1 - v0) * j / nv
                    rim = i in (0, nu) or j in (0, nv)
                    z = height(u, v) + T.noise.noise(Vector((u * 0.9, v * 0.9, 7.0))) * 0.1 - (tuck if rim else 0.0)
                    row.append(bm.verts.new(Vector(fr.pt(u, v, z))))
                grid.append(row)
            for i in range(nu):
                for j in range(nv):
                    f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
                    f[k] = EARTH
                    f[t] = 1.0

    def quad(self, pts, kind=EARTH, tone=1.0):
        """One face (corners in order, counter-clockwise from above)."""
        for bm in self._targets():
            k, t, b = T._layers(bm)
            vs = [bm.verts.new(Vector(q)) for q in pts]
            f = bm.faces.new(vs)
            f[k] = kind
            f[t] = tone

    def backing(self, fr, u0, u1, v, z0, z1):
        """A dark wall facing the front (-v) behind a run whose blocks' ends
        are left out, so an open joint shows stone, not sky."""
        self.quad([fr.pt(u0, v, z0), fr.pt(u1, v, z0), fr.pt(u1, v, z1), fr.pt(u0, v, z1)],
                  kind=T.JOINTFACE, tone=0.8)


# What a block set in the platform never shows (block(hide=, seen=)): a
# step block's bed and back (under the next step / the paving) and every
# bevel and corner that leans that way; its ends stay, an open joint shows
# them. A slab: its bed and the bevels round it.
STEP_HIDE, STEP_SEEN = ("-z", "+y"), ("+z", "-y")
SLAB_HIDE, SLAB_SEEN = ("-z",), ("+z",)


def run_hide(base, j, n, keep=()):
    """`base` for block j of a run of n; the run's end blocks hide nothing
    (a bay's end shows them standing alone, overhanging), and `keep` sides
    always show."""
    if j == 0 or j == n - 1:
        return ()
    return tuple(sorted(set(base) - set(keep)))


class Frame:
    """A 2D frame on the ground: local u along the edge, v back into the
    platform (front at -v), turned `a` rad about z at (ox, oy)."""

    def __init__(self, a=0.0, ox=0.0, oy=0.0):
        self.a, self.ox, self.oy = a, ox, oy

    def pt(self, u, v, z=0.0):
        c, s = math.cos(self.a), math.sin(self.a)
        return (self.ox + c * u - s * v, self.oy + s * u + c * v, z)

    def aabb(self, u0, u1, v0, v1, z0, z1):
        xs, ys = [], []
        for u in (u0, u1):
            for v in (v0, v1):
                x, y, _ = self.pt(u, v)
                xs.append(x)
                ys.append(y)
        return (min(xs), min(ys), z0), (max(xs), max(ys), z1)


def lay(rng, u0, u1, length):
    """Cuts u0..u1 into block lengths: [(u_centre, L)]."""
    out = []
    u = u0
    while u < u1 - 0.3:
        L = min(rng.uniform(*length), u1 - u)
        if u1 - (u + L) < 1.0:
            L = u1 - u
        out.append([u + L / 2, L])
        u += L
    return out


def emit(p, fr, u, v, z, size, yaw=0.0, tilt=(0.0, 0.0), **kw):
    """A block by its local centre (u, v, z) and size (along u, along v, z)."""
    put(p, fr.pt(u, v, z), size, yaw=fr.a + yaw, tilt=tilt, **kw)


def put(p, center, size, yaw=0.0, tilt=(0.0, 0.0), **kw):
    """p.block (no far box); on a mid build also the stone as a mid_box,
    in its tone."""
    p.block(center, size, yaw=yaw, tilt=tilt, far=False, **kw)
    if p.mid is not None:
        kind, tone, _ = T._layers(p.near)
        p.near.faces.ensure_lookup_table()
        mid_box(p.mid, center, size, yaw, tilt, p.near.faces[-1][tone], kw.get("bevel", T.BEVEL),
                kw.get("kind", T.FACE), kw.get("hide", ()))


def mid_box(bm, center, size, yaw, tilt, tone, bevel, kind, hide):
    """A stone for the mid LOD: a plain box, no chips, its top's four edges
    chamfered `bevel` (painted as joints, as the near's bevels are: the
    course and joint lines), its `hide` sides (and their chamfers) left
    out; placed as block() places it."""
    sx, sy, sz = (s / 2 for s in size)
    hide = set(hide)
    b = 0.0 if "+z" in hide or bevel <= 0.0 else min(bevel, 0.3 * min(size))
    tmp = bmesh.new()
    tk, tt, _ = T._layers(tmp)

    def ring(z, d):
        return [tmp.verts.new((x, y, z)) for x, y in ((-sx + d, -sy + d), (sx - d, -sy + d), (sx - d, sy - d), (-sx + d, sy - d))]

    def face(vs, k):
        f = tmp.faces.new(vs)
        f[tk] = k
        f[tt] = tone

    bot, edge, top = ring(-sz, 0.0), ring(sz - b, 0.0), ring(sz, b)
    if "+z" not in hide:
        face(top, kind)
    for name, (i, j) in (("-y", (0, 1)), ("+x", (1, 2)), ("+y", (2, 3)), ("-x", (3, 0))):
        if name in hide:
            continue
        if b > 0.0:
            face([edge[i], edge[j], top[j], top[i]], T.JOINTFACE)
        face([bot[i], bot[j], (edge if b > 0.0 else top)[j], (edge if b > 0.0 else top)[i]], kind)
    if "-z" not in hide:
        face(list(reversed(bot)), kind)
    bmesh.ops.remove_doubles(tmp, verts=list(tmp.verts), dist=1e-5)
    unused = [v for v in tmp.verts if not v.link_faces]
    if unused:
        bmesh.ops.delete(tmp, geom=unused, context="VERTS")
    m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
         @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X"))
    T._append(bm, tmp, m)
    tmp.free()


def settle(rng):
    """How an old block sits: a touch low, a touch turned, a touch out."""
    return dict(dz=-rng.uniform(0.0, 0.07), yaw=rng.uniform(-0.01, 0.01), dv=rng.uniform(-0.05, 0.05),
                tip=rng.uniform(-0.012, 0.012))


def step_course(p, fr, i, u0, u1, hurt=None, end_broken=None, hide=STEP_HIDE):
    """Step i (0 bottom .. 2 the stylobate) along u0..u1. `hurt(index, n,
    spec) -> bool` may change a block (or return False to drop it), and
    set spec["keep"] to sides of it that show (see run_hide)."""
    r = p.rng
    z0 = T.STEP_H * i
    blocks = lay(r, u0, u1, (2.6, 4.6) if i < 2 else (2.4, 3.8))
    for j, (uc, L) in enumerate(blocks):
        s = settle(r)
        spec = dict(u=uc, L=L, v=FRONT[i] + DEPTH[i] / 2 + s["dv"], z=z0 + T.STEP_H / 2 + s["dz"],
                    yaw=s["yaw"], tilt=(s["tip"], s["tip"] * 0.5), H=T.STEP_H - r.uniform(0.0, 0.04),
                    chips=r.randint(1, 3), chip_depth=(0.15, 0.45), bevel=r.uniform(0.06, 0.11))
        if hurt is not None and hurt(j, len(blocks), spec) is False:
            continue
        # spec["hide"] / spec["seen"] (set by `hurt`) override run_hide, for
        # a run's end block whose end is closed (a corner).
        emit(p, fr, spec["u"], spec["v"], spec["z"], (spec["L"] - T.JOINT, DEPTH[i] - T.JOINT, spec["H"] - T.JOINT),
             yaw=spec["yaw"], tilt=spec["tilt"], chips=spec["chips"], chip_depth=spec["chip_depth"],
             bevel=spec["bevel"], hide=spec.get("hide", run_hide(hide, j, len(blocks), spec.get("keep", ()))),
             seen=spec.get("seen", STEP_SEEN))
    lo_u, hi_u = u0, u1
    p.far_box(_mid(fr, (lo_u + hi_u) / 2, FRONT[i] + DEPTH[i] / 2, z0 + T.STEP_H / 2),
              (hi_u - lo_u, DEPTH[i], T.STEP_H), yaw=fr.a)


def _mid(fr, u, v, z):
    return fr.pt(u, v, z)


def broken_end(p, fr, i, u_end, side, spec_v):
    """A step block's broken end: a low chipped stump where the corner was,
    and the piece that came off lying in front."""
    r = p.rng
    z0 = T.STEP_H * i
    emit(p, fr, u_end, spec_v, z0 + 0.28, (0.9, DEPTH[i] - 0.3, 0.56), chips=3, chip_depth=(0.2, 0.35),
         bevel=0.1, hide=("-z", "+y"))
    # The fallen corner on the step (or ground) below.
    zb = T.STEP_H * max(0, i - 1) if i > 0 else 0.0
    emit(p, fr, u_end + side * 0.4, FRONT[i] - 0.75, zb + 0.3, (1.0, 0.8, 0.62), yaw=r.uniform(-0.6, 0.6),
         tilt=(r.uniform(-0.25, 0.25), r.uniform(-0.3, 0.3)), chips=3, chip_depth=(0.15, 0.3), bevel=0.1)


def core(p, fr, u0, u1, v_back=BACK):
    """The hidden fill behind the step blocks, so an open joint shows stone."""
    for i, (v0, z0, z1) in enumerate(((FRONT[0] + 0.2, -0.3, 0.95), (FRONT[1] + 0.2, 0.95, 1.95),
                                       (FRONT[2] + 0.2, 1.95, SLAB_Z))):
        emit(p, fr, (u0 + u1) / 2, (v0 + v_back) / 2, (z0 + z1) / 2, (u1 - u0, v_back - v0, z1 - z0),
             bevel=0.0, chips=0, jitter=0.0, kind=T.JOINTFACE, tone=0.8)


def footing(p, fr, u0, u1, front=FRONT[0], v_back=BACK, shift=(True, True), end_out=False, inset=0.0):
    """The plain footing to 6.5 m under the ground line: two courses of
    big rough blocks, the top one stepping 0.15 m out of the steps' face.
    `shift` per end: False holds that end fixed (a corner); `end_out`
    steps the u1 end out too (the corner's side face)."""
    r = p.rng
    for key, z0, z1, out in (("foot0", -3.2, 0.0, 0.15), ("foot1", FOOT, -3.2, 0.3)):
        s = SHIFT[key]
        a = u0 + (s if shift[0] else 0.0)
        b = u1 + (s if shift[1] else 0.0) + (out if end_out else 0.0)
        blocks = lay(r, a, b, (4.0, 6.5))
        # Below ground only the outer faces: the top course's front and
        # lip, the lower one's front; a dark wall behind the joints.
        base = ("-z", "+y", "-x", "+x") + (("+z",) if key == "foot1" else ())
        for j, (uc, L) in enumerate(blocks):
            v0 = front - out - r.uniform(0.0, 0.08)
            emit(p, fr, uc, (v0 + v_back) / 2, (z0 + z1) / 2, (L - 0.05, v_back - v0, z1 - z0),
                 bevel=0.0, chips=0, jitter=0.03, tone=r.uniform(0.75, 0.9),
                 hide=tuple(set(run_hide(base, j, len(blocks))) | set(base) - {"-x", "+x"}))
        # `inset`: the wall stops short of the run's ends (inside the end
        # blocks), so it never reaches past the stone.
        p.backing(fr, a + inset, b - inset, front - out + 0.35, z0, z1)
        p.far_box(fr.pt((a + b) / 2, (front - out + v_back) / 2, (z0 + z1) / 2),
                  (b - a, v_back - front + out, z1 - z0), yaw=fr.a)


def paving(p, fr, u0, u1, keep=None, hurt=None, **kw):
    """The paved top: rows of slabs from the stylobate back. `keep(u, v)`
    True where a slab must stay flat (under a column); `hurt(spec)` may
    change a slab, set spec["crack"], or return False to drop it."""
    _paving_span(p, fr, lambda s: (u0 + s, u1 + s), keep=keep, hurt=hurt, **kw)


def _cracked(p, fr, spec):
    """A slab split across, the halves settled apart and tipped."""
    r = p.rng
    cut = r.uniform(0.35, 0.6) * spec["L"]
    gap = 0.07
    a_u = spec["u"] - spec["L"] / 2 + cut / 2
    b_u = spec["u"] - spec["L"] / 2 + cut + gap + (spec["L"] - cut - gap) / 2
    for uc, L, tip, dz in ((a_u, cut, 0.04, -0.03), (b_u, spec["L"] - cut - gap, -0.05, -0.07)):
        emit(p, fr, uc, spec["v"], spec["z"] + dz, (L - T.JOINT, spec["D"] - T.JOINT, 0.45), yaw=spec["yaw"] + r.uniform(-0.03, 0.03),
             tilt=(r.uniform(-0.03, 0.03), tip), chips=2, chip_depth=(0.08, 0.14), bevel=0.06)
    p.quad([fr.pt(spec["u"] - spec["L"] / 2 + cut - 0.1, spec["v"] - spec["D"] / 2, SLAB_Z + 0.12),
            fr.pt(spec["u"] - spec["L"] / 2 + cut + gap + 0.1, spec["v"] - spec["D"] / 2, SLAB_Z + 0.12),
            fr.pt(spec["u"] - spec["L"] / 2 + cut + gap + 0.1, spec["v"] + spec["D"] / 2, SLAB_Z + 0.12),
            fr.pt(spec["u"] - spec["L"] / 2 + cut - 0.1, spec["v"] + spec["D"] / 2, SLAB_Z + 0.12)])


def hole(p, fr, spec, depth=0.18):
    """A slab gone: soil a little below the top, and a crumb or two."""
    r = p.rng
    u0, u1 = spec["u"] - spec["L"] / 2 - 0.05, spec["u"] + spec["L"] / 2 + 0.05
    v0, v1 = spec["v"] - spec["D"] / 2 - 0.05, spec["v"] + spec["D"] / 2 + 0.05
    z = T.PODIUM_H - depth
    p.soil(fr, u0, u1, v0, v1, lambda u, v: z, nu=3, nv=2, tuck=0.12)
    for _ in range(r.randint(1, 2)):
        emit(p, fr, r.uniform(u0 + 0.4, u1 - 0.4), r.uniform(v0 + 0.4, v1 - 0.4), z + 0.12,
             (r.uniform(0.4, 0.8), r.uniform(0.3, 0.6), 0.25), yaw=r.uniform(0, 3), tilt=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)),
             chips=2, chip_depth=(0.06, 0.1), bevel=0.05)


def column_zone(cu):
    """True for a slab under (or next to) a column's plinth: it stays flat."""
    return lambda spec: abs(spec["u"] - cu) - spec["L"] / 2 < 2.8 and spec["v"] - spec["D"] / 2 < 2.8


def tilted(spec, r, lift=0.09):
    """A slab heaved by roots: one edge up."""
    spec["tilt"] = (r.choice((-1, 1)) * lift / spec["D"], r.uniform(-0.03, 0.03))
    spec["z"] += lift * 0.4
    spec["yaw"] += r.uniform(-0.04, 0.04)


def step_solids(p, fr, u0, u1, front=FRONT, v_back=BACK):
    for i in range(3):
        z0 = FOOT if i == 0 else T.STEP_H * i
        lo, hi = fr.aabb(u0, u1, front[i], v_back, z0, T.STEP_H * (i + 1))
        p.solid(lo, hi)


# ---------------------------------------------------------------------------
def start(name, seed, mid):
    """A Podium; with `mid` a mid build (see Podium.mid)."""
    p = Podium(name, seed=seed)
    if mid:
        p.mid = bmesh.new()
        T._layers(p.mid)
    return p


def finish(p):
    """Exports the piece, or on a mid build only its mid (<name>_mid.glb)."""
    if p.mid is None:
        p.export()
        return
    p.near.free()
    p.near, p.mid = p.mid, None
    p.export(mid_of=p.name)


def build_podium(mid=False):
    p = start("podium", 11, mid)
    r = p.rng
    fr = Frame()

    def hurt0(j, n, spec):
        # Step 0: one block's end broken off, its corner lying in front.
        if j == 2:
            spec["L"] -= 0.95
            spec["u"] -= 0.475
            broken_end(p, fr, 0, spec["u"] + spec["L"] / 2 + 0.47, 1, spec["v"])
        return True

    def hurt1(j, n, spec):
        # Step 1: a block slipped forward and turned, sunk at one end.
        if j == 0:
            spec["v"] -= 0.2
            spec["yaw"] += 0.035
            spec["z"] -= 0.05
            spec["tilt"] = (0.0, 0.02)
            spec["keep"] = ("-z",)          # slipped forward: its bed's front edge shows
        return True

    def hurt2(j, n, spec):
        # The stylobate: one edge block cracked and dropped at the far end.
        if j == n - 1:
            spec["tilt"] = (-0.025, 0.0)
            spec["z"] -= 0.06
            spec["chips"] = 3
        return True

    for i, h in enumerate((hurt0, hurt1, hurt2)):
        s = SHIFT["step%d" % i]
        step_course(p, fr, i, -HB + s, HB + s, hurt=h)
    core(p, fr, -HB, HB)

    picked = {"hole": (1, 1), "tilt": (2, 3), "crack": (0, 3), "hole2": (2, 0), "tilt2": (1, 4)}

    def hurt_pav(spec):
        key = (spec["row"], spec["j"])
        if key in (picked["hole"], picked["hole2"]):
            hole(p, fr, spec)
            return False
        if key in (picked["tilt"], picked["tilt2"]):
            tilted(spec, r)
        if key == picked["crack"]:
            spec["crack"] = True
        return True

    paving(p, fr, -HB, HB, keep=column_zone(0.0), hurt=hurt_pav)
    footing(p, fr, -HB, HB)
    step_solids(p, fr, -HB, HB)
    finish(p)


def build_corner(mid=False):
    p = start("podium_corner", 12, mid)
    r = p.rng
    front = Frame()
    side = Frame(a=math.pi / 2)
    # Steps: the front run takes the outer corner block of each step; the
    # side run starts behind it.
    for i in range(3):
        s = SHIFT["step%d" % i]
        corner_u = -FRONT[i]

        def hurt_f(j, n, spec, i=i):
            if i == 0 and j == n - 1:
                # The outer corner of the bottom step: broken, sunk.
                spec["z"] -= 0.08
                spec["tilt"] = (0.02, -0.03)
                spec["chips"] = 3
                spec["chip_depth"] = (0.3, 0.5)
            # The corner block (j == n - 1) keeps every face: trimming its
            # bed and back (tried) changed how its outer arris shades at 60 m.
            return True

        def hurt_s(j, n, spec, i=i):
            if i == 1 and j == 1:
                spec["v"] -= 0.16
                spec["yaw"] -= 0.03
            if j == 0:
                # The side run's first block starts behind the corner block:
                # its bed and back go as an inner block's; its start end stays.
                spec["hide"] = STEP_HIDE
            return True

        step_course(p, front, i, -HB + s, corner_u, hurt=hurt_f)
        step_course(p, side, i, FRONT[i] + DEPTH[i], HB + s, hurt=hurt_s)
    # A fallen block off the outer corner, lying on the ground.
    put(p, (7.4, -7.0, 0.42), (2.3, 1.0, 0.95), yaw=0.5, tilt=(0.1, 0.32), chips=3, chip_depth=(0.2, 0.4))
    # The core, stepped per level: the front strip to each step's side
    # face, and the side strip behind it.
    for i, (z0, z1) in enumerate(((-0.3, 0.95), (0.95, 1.95), (1.95, SLAB_Z))):
        f0 = FRONT[i] + 0.2
        for fr, (u0, u1) in ((front, (-HB, -f0)), (side, (BACK, HB))):
            lo, hi = fr.aabb(u0, u1, f0, BACK, z0, z1)
            put(p, ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (z0 + z1) / 2), (hi[0] - lo[0], hi[1] - lo[1], z1 - z0),
                bevel=0.0, chips=0, jitter=0.0, kind=T.JOINTFACE, tone=0.8, hide=("-z",))
    # Paving: the front rows to the side stylobate's inner edge (x 0.4),
    # then the side rows from y 6 on.
    inner = FRONT[2] + DEPTH[2]          # -0.4
    picked_f = {(1, 0): "hole", (2, 2): "tilt"}
    picked_s = {(0, 1): "crack", (1, 1): "tilt"}

    def hurt_pf(spec):
        what = picked_f.get((spec["row"], spec["j"]))
        if what == "hole":
            hole(p, front, spec)
            return False
        if what == "tilt":
            tilted(spec, r)
        return True

    def hurt_ps(spec):
        what = picked_s.get((spec["row"], spec["j"]))
        if what == "crack":
            spec["crack"] = True
        if what == "tilt":
            tilted(spec, r)
        return True

    paving_to(p, front, -HB, -inner, keep=column_zone(0.0), hurt=hurt_pf, fixed=(False, True))
    paving_from(p, side, BACK, HB, hurt=hurt_ps, fixed=(True, False))
    # The footing: front strip to the corner, side strip behind it.
    footing(p, front, -HB, -FRONT[0], shift=(True, False), end_out=True, inset=0.1)
    footing(p, side, BACK, HB, shift=(False, True), inset=0.1)
    # Solids.
    step_solids(p, front, -HB, -FRONT[0])
    for i in range(3):
        z0 = FOOT if i == 0 else T.STEP_H * i
        lo, hi = side.aabb(BACK, HB, FRONT[i], BACK, z0, T.STEP_H * (i + 1))
        p.solid(lo, hi)
    finish(p)


def paving_to(p, fr, u0, u_end, **kw):
    """Paving rows that run from u0 + their shift to a fixed end (a corner)."""
    _paving_span(p, fr, lambda s: (u0 + s, u_end), **kw)


def paving_from(p, fr, u_start, u1, **kw):
    _paving_span(p, fr, lambda s: (u_start, u1 + s), **kw)


def _paving_span(p, fr, span, keep=None, hurt=None, rows=ROWS, keys=None, fixed=(False, False)):
    """Rows of slabs; `keys` their SHIFT names (row0.. by default). A
    slab's bed and the bevels round it are left out, except under a
    heaved slab and at a run's ends (a bay's end shows them overhanging),
    unless that end is `fixed` (closed by stone, at a corner)."""
    r = p.rng
    keys = keys or ["row%d" % i for i in range(len(rows))]
    lo_all, hi_all = 1e9, -1e9
    for ri, (v0, v1) in enumerate(rows):
        a, b = span(SHIFT[keys[ri]])
        lo_all, hi_all = min(lo_all, a), max(hi_all, b)
        slabs = lay(r, a, b, (1.8, 3.4))
        for j, (uc, L) in enumerate(slabs):
            spec = dict(u=uc, L=L, v=(v0 + v1) / 2, D=v1 - v0, z=SLAB_Z + 0.225 - r.uniform(0.0, 0.03),
                        yaw=r.uniform(-0.006, 0.006), tilt=(0.0, 0.0), chips=r.randint(0, 2), row=ri, j=j)
            if hurt is not None and (keep is None or not keep(spec)):
                if hurt(spec) is False:
                    continue
            if spec.get("crack"):
                _cracked(p, fr, spec)
                continue
            closed = j == 0 and fixed[0] or j == len(slabs) - 1 and fixed[1]
            hide = (SLAB_HIDE if closed else run_hide(SLAB_HIDE, j, len(slabs))) if spec["tilt"] == (0.0, 0.0) else ()
            emit(p, fr, spec["u"], spec["v"], spec["z"], (spec["L"] - T.JOINT, spec["D"] - T.JOINT, 0.45),
                 yaw=spec["yaw"], tilt=spec["tilt"], chips=spec["chips"], chip_depth=(0.08, 0.14), bevel=0.06,
                 hide=hide, seen=SLAB_SEEN)
    p.far_box(fr.pt((lo_all + hi_all) / 2, (rows[0][0] + rows[-1][1]) / 2, SLAB_Z + 0.225),
              (hi_all - lo_all, rows[-1][1] - rows[0][0], 0.45), yaw=fr.a)


# ---------------------------------------------------------------------------
# podium_floor: a bay of the paved top only, for the platform's inside.
FLOOR_FRONT = FRONT[2]                       # -3.0: where a podium's stylobate starts
FLOOR_ROWS = [(FLOOR_FRONT, ROWS[0][0])] + ROWS  # a paving row where the stylobate was
FLOOR_KEYS = ["rowf", "row0", "row1", "row2"]
SHIFT["rowf"] = -0.6
FLOOR_END = 0.6                              # the coursed blocks at each end of the fill


def build_floor(mid=False):
    """One bay of the platform's floor: the paved top from y -3.0 (a
    podium's stylobate front) back to 6.0 at the same height (3.0), on a
    hidden core and a footing, no steps. The origin is podium's (the ground
    under a column's centre on the top step line), so it swaps for a podium
    bay one for one; a column stands on it at (0, 0, 3.0)."""
    p = start("podium_floor", 14, mid)
    r = p.rng
    fr = Frame()
    # The fill under the paving; its ends are coursed stone (below).
    emit(p, fr, 0.0, (FLOOR_FRONT + BACK) / 2, (-0.3 + SLAB_Z) / 2,
         (2 * (HB - FLOOR_END), BACK - FLOOR_FRONT, SLAB_Z + 0.3),
         bevel=0.0, chips=0, jitter=0.0, kind=T.JOINTFACE, tone=0.8)
    p.far_box(fr.pt(0.0, (FLOOR_FRONT + BACK) / 2, SLAB_Z / 2), (2 * HB, BACK - FLOOR_FRONT, SLAB_Z), yaw=fr.a)
    picked = {(0, 5): "hole", (3, 1): "hole", (1, 5): "tilt", (2, 0): "tilt", (3, 4): "crack"}

    def hurt_pav(spec):
        what = picked.get((spec["row"], spec["j"]))
        if "--debug" in args and what:
            print("FLOOR", what, spec["row"], spec["j"], "u %.2f L %.2f" % (spec["u"], spec["L"]))
        if what == "hole":
            hole(p, fr, spec)
            return False
        if what == "tilt":
            tilted(spec, r)
        if what == "crack":
            spec["crack"] = True
        return True

    _paving_span(p, fr, lambda s: (-HB + s, HB + s), keep=column_zone(0.0), hurt=hurt_pav,
                 rows=FLOOR_ROWS, keys=FLOOR_KEYS)
    footing(p, fr, -HB, HB, front=FLOOR_FRONT)
    # The fill's ends, where a run of floor stops at an open slot: three
    # courses of rough blocks showing only their end faces (and the top
    # course its top, where a paving row stops short), joints open onto
    # the fill.
    for side in (-1, 1):
        out, inner = ("+x", "-x") if side > 0 else ("-x", "+x")
        for c, (z0, z1) in enumerate(((0.0, 1.0), (1.0, 2.0), (2.0, SLAB_Z))):
            for vc, Lv in lay(r, FLOOR_FRONT, BACK, (2.2, 3.6)):
                hide = ("-z", "-y", "+y", inner) + (("+z",) if c < 2 else ())
                emit(p, fr, side * (HB - FLOOR_END / 2), vc, (z0 + z1) / 2,
                     (FLOOR_END, Lv - T.JOINT, z1 - z0 - T.JOINT), bevel=0.0, chips=0, jitter=0.02,
                     tone=r.uniform(0.8, 0.95), hide=hide)
    # The solid: one box, flat at the top (3.0) like a podium's stylobate and paving.
    lo, hi = fr.aabb(-HB, HB, FLOOR_FRONT, BACK, FOOT, T.PODIUM_H)
    p.solid(lo, hi)
    finish(p)


# ---------------------------------------------------------------------------
STAIR_HALF = 6.0                # the flight's half width (12 m)
CHEEK = 1.2                      # a cheek wall's width
RISE, TREAD, NSTEP = 0.25, 0.4, 12
STAIR_FRONT = FRONT[0] - 1.6     # -7.8: the flight juts one tread of the big steps


def stair_top(v):
    """The flight's tread height at v (0 in front of it)."""
    if v < STAIR_FRONT:
        return 0.0
    k = min(NSTEP - 1, int((v - STAIR_FRONT) / TREAD))
    return RISE * (k + 1)


def build_stair(mid=False):
    p = start("podium_stair", 13, mid)
    r = p.rng
    fr = Frame()
    edge = STAIR_HALF + CHEEK          # 7.2
    # The big steps either side of the flight; the stylobate runs across.
    for i in range(2):
        s = SHIFT["step%d" % i]

        def hurt_r(j, n, spec, i=i):
            # The block against the collapsed cheek: its end broken.
            if j == 0 and i == 0:
                spec["chips"] = 3
                spec["chip_depth"] = (0.3, 0.5)
            return True

        step_course(p, fr, i, -HB + s, -edge)
        step_course(p, fr, i, edge, HB + s, hurt=hurt_r)
    step_course(p, fr, 2, -HB + SHIFT["step2"], HB + SHIFT["step2"])
    core(p, fr, -HB, HB)

    # The flight: twelve fine steps, each a course of blocks; the right
    # side's upper steps gone where the cheek came down. A block's bed
    # (on the step below and the core) and back (under the next step) go
    # as a big step's do, except where the step below or above is gone
    # over it (the hole shows them) and at a run's ends. Which blocks are
    # gone is only known once the flight is laid, so it is laid twice:
    # a dry run into a throwaway mesh, then again from the same draws.
    def flight(gone_before):
        gone = {}
        for k in range(NSTEP):
            v0 = STAIR_FRONT + TREAD * k
            D = TREAD + 0.25
            top = RISE * (k + 1)
            blocks = lay(r, -STAIR_HALF, STAIR_HALF, (1.6, 3.2))
            for j, (uc, L) in enumerate(blocks):
                lost = uc > 2.2 and 3 <= k <= 9 and r.random() < 0.8
                if lost:
                    gone.setdefault(k, []).append((uc - L / 2, uc + L / 2))
                    continue
                s = settle(r)
                hide = ()
                if gone_before is not None:
                    a, b = uc - L / 2 - 0.1, uc + L / 2 + 0.1

                    def open_at(kk):
                        return any(x0 < b and a < x1 for x0, x1 in gone_before.get(kk, ()))
                    keep = (("-z",) if open_at(k - 1) else ()) + (("+y",) if open_at(k + 1) else ())
                    hide = run_hide(STEP_HIDE, j, len(blocks), keep)
                emit(p, fr, uc, v0 + D / 2 + s["dv"] * 0.5, top - 0.25 + s["dz"] * 0.4, (L - T.JOINT, D - T.JOINT, 0.5 - T.JOINT),
                     yaw=s["yaw"], chips=r.randint(0, 2), chip_depth=(0.06, 0.14), bevel=0.05, hide=hide, seen=STEP_SEEN)
        return gone

    real, state, mid = p.near, r.getstate(), p.mid
    p.near, p.mid = bmesh.new(), None
    T._layers(p.near)
    gone = flight(None)
    p.near.free()
    p.near, p.mid = real, mid
    r.setstate(state)
    flight(gone)
    # The flight's core, under its treads.
    for v0, z1 in ((-6.9, 0.6), (-5.3, 1.6), (-3.7, 2.6)):
        emit(p, fr, 0.0, (v0 + FRONT[2]) / 2, z1 / 2 - 0.15, (2 * STAIR_HALF, FRONT[2] - v0, z1 + 0.3),
             bevel=0.0, chips=0, jitter=0.0, kind=T.JOINTFACE, tone=0.8)
    p.far_box(fr.pt(0.0, (STAIR_FRONT + FRONT[2]) / 2, 0.75), (2 * edge, FRONT[2] - STAIR_FRONT, 1.5), yaw=fr.a)
    p.far_box(fr.pt(0.0, (FRONT[0] + FRONT[2]) / 2, 2.0), (2 * edge, FRONT[2] - FRONT[0], 1.0), yaw=fr.a)
    # Soil on the slope where the right side's steps are gone.
    sv0, sv1 = STAIR_FRONT + TREAD * 3, STAIR_FRONT + TREAD * 10
    p.soil(fr, 2.0, 7.0, sv0, sv1, lambda u, v: 0.8 + (v - sv0) / (sv1 - sv0) * 1.8 - 0.1 * (u - 2.0) / 5.0,
           nu=5, nv=7)

    # The cheek walls: three stepped lengths, coursed, capped. The left
    # stands; the right is down to its first course.
    for side in (-1, 1):
        uc = side * (STAIR_HALF + CHEEK / 2)
        for j in range(3):
            v0 = STAIR_FRONT + 1.6 * j
            courses = j + 1
            if side == 1:
                courses = 1 if j == 0 else 0
            for c in range(courses):
                # The cheek keeps every face: its blocks' chips (up to 0.3 m)
                # open the faces they abut (tried: hiding the backs and tops
                # under the next length and the caps showed holes at 6 m).
                emit(p, fr, uc + r.uniform(-0.02, 0.02), v0 + 0.8, c + 0.5, (CHEEK - T.JOINT, 1.6 - T.JOINT, 1.0 - T.JOINT),
                     yaw=r.uniform(-0.01, 0.01), chips=r.randint(1, 2), chip_depth=(0.12, 0.3), bevel=0.08)
            if side == -1:
                emit(p, fr, uc, v0 + 0.8, courses + 0.3, (CHEEK + 0.15, 1.6 - T.JOINT, 0.6 - T.JOINT),
                     chips=2, chip_depth=(0.12, 0.25), bevel=0.12)
        if side == -1:
            p.far_box(fr.pt(uc, STAIR_FRONT + 2.4, 1.8), (CHEEK, 4.8, 3.6), yaw=fr.a)
    # The spill: the right cheek's courses and caps, and the steps they
    # broke, tumbled down the flight's right side and out onto the ground.
    spill = [(5.4, -4.2, 0.5), (4.6, -5.0, 0.0), (6.8, -5.6, 0.0), (3.6, -6.0, 0.0), (5.6, -6.8, 0.0),
             (7.9, -7.3, 0.0), (4.4, -7.6, 0.0), (6.4, -8.5, 0.0), (8.6, -8.9, 0.0), (3.2, -8.8, 0.0),
             (5.3, -9.6, 0.0), (7.3, -10.2, 0.0)]
    for n, (u, v, lift) in enumerate(spill):
        big = n % 3 != 2
        size = (r.uniform(1.0, 1.7), r.uniform(0.9, 1.3), r.uniform(0.6, 1.0)) if big else \
            (r.uniform(0.5, 0.9), r.uniform(0.4, 0.7), r.uniform(0.3, 0.5))
        ground = stair_top(v) if abs(u) < STAIR_HALF else (0.0 if v < FRONT[0] else 1.0)
        if u > 2.2 and -6.6 < v < -3.8:
            ground = max(0.9, stair_top(v) - 0.6)
        # Every face kept: tipped up to 26 deg, no face of a spilled block
        # lies wholly under the soil (checked corner by corner) or the ground.
        emit(p, fr, u, v, ground + size[2] * 0.45 + lift, size, yaw=r.uniform(0, math.pi),
             tilt=(r.uniform(-0.35, 0.35), r.uniform(-0.45, 0.45)), chips=3, chip_depth=(0.15, 0.35), bevel=0.1)
        if big:
            p.far_box(fr.pt(u, v, ground + size[2] * 0.45), size, yaw=fr.a + 0.6 * n)

    def hurt_pav(spec):
        key = (spec["row"], spec["j"])
        if key == (1, 4):
            hole(p, fr, spec)
            return False
        if key in ((2, 1), (0, 0)):
            tilted(spec, r)
        if key == (2, 4):
            spec["crack"] = True
        return True

    paving(p, fr, -HB, HB, keep=column_zone(0.0), hurt=hurt_pav)
    footing(p, fr, -HB, HB, inset=0.1)
    # The footing under the flight's jut.
    emit(p, fr, 0.0, (STAIR_FRONT - 0.15 + FRONT[0]) / 2, -3.25, (2 * edge, FRONT[0] - STAIR_FRONT + 0.15, 6.5),
         bevel=0.0, chips=0, jitter=0.02, tone=0.82)
    # Solids: the big steps, and the flight as six boxes (one per two
    # treads, its lower tread's top), plus the standing cheek.
    step_solids(p, fr, -HB, HB)
    for j in range(6):
        v0 = STAIR_FRONT + 2 * TREAD * j
        lo, hi = fr.aabb(-edge, edge, v0, FRONT[2], FOOT if j == 0 else 0.0, RISE * (2 * j + 1))
        p.solid(lo, hi)
    for j in range(3):
        lo, hi = fr.aabb(-edge, -STAIR_HALF, STAIR_FRONT + 1.6 * j, FRONT[2], 0.0, j + 1.6)
        p.solid(lo, hi)
    finish(p)


# A piece, then its mid (--only=podium_mid builds podium's mid alone).
for name, fn in (("podium", build_podium), ("podium_corner", build_corner), ("podium_stair", build_stair),
                 ("podium_floor", build_floor)):
    if ONLY is None or name in ONLY:
        fn()
    if (ONLY is None and name in MIDS) or (ONLY is not None and name + "_mid" in ONLY):
        fn(mid=True)
