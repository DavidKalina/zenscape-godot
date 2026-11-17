"""The temple kit's shared library (docs/design/temple-kit/spec-temple-kit.md).

Every piece of the kit is built by one script per lane (`<lane>_build.py`)
that imports this module, so the stone, the joints, the wear and the export
are the same across the kit. Run a build with

    python tools/blender.py run art/blender/temple_kit/column_build.py

Usage (a lane's build script):

    import temple_lib as T

    p = T.Piece("lintel", seed=7)          # one piece, its own random wear
    # A course of cut blocks: along x from -9.25 to 9.25, its foot at z 28,
    # 1.25 m high, 5.2 m deep (y), blocks 2.2-3.6 m long with open joints.
    p.course(x0=-9.25, x1=9.25, z=28.0, height=1.25, depth=5.2)
    # One block by its centre and size (x, y, z), turned `yaw` rad about z;
    # `chips` corners knocked off, `bevel` the worn arris, `tilt` (rad)
    # for a block lying askew. Each call also adds a plain box to the far
    # LOD (far=False to skip it, e.g. small rubble).
    p.block((0, 0, 30), (3.0, 5.2, 1.6), chips=3)
    # A fluted drum (a column's), its foot at `base`: see column_build.py.
    p.drum((0, 0, 1.2), 2.5, 2.0, 1.95, chips=1)
    # A ring (round mouldings: torus, echinus): radii and heights in pairs.
    p.ring((0, 0, 0.6), [(2.3, 0.0), (2.45, 0.3), (2.3, 0.6)])
    # The far LOD by hand, when a block's plain box isn't enough:
    p.far_cylinder((0, 0, 1.2), 27.5, 2.0, 1.7)
    p.far_box((0, 0, 30), (18.5, 5.2, 7.5))
    # The flight's solids, few and coarse, in Blender's frame (z up):
    p.solid((-2.6, -2.6, 0.0), (2.6, 2.6, 30.5))
    p.export()      # assets/models/temple_kit/lintel.glb + lintel.boxes.json

Rules the export keeps for the Godot side (scripts/temple_kit.gd):
- The glb holds two meshes, `<piece>` (near) and `<piece>_far`. Colour is
  per vertex (linear, alpha 1); no textures. The game draws them with
  shaders/temple_stone.gdshader.
- Blender frame: z up, the piece's origin on the ground (or the surface it
  stands on) at its snap point. glTF turns that into Godot's y up:
  Godot (x, y, z) = Blender (x, z, -y).
- `<piece>.boxes.json` holds the solids already in Godot's frame
  ([x, y, z, sx, sy, sz] = AABB position and size) and the triangle counts.

The kit's numbers (the spec's contract) are the constants below. Every
piece snaps to BAY: column centres sit on a BAY grid on the stylobate.
"""

import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[3]
MODELS = ROOT / "assets" / "models" / "temple_kit"

# ---- The contract (metres) ----------------------------------------------
BAY = 18.5                 # column centre to centre
COLUMN_D = 4.0             # shaft diameter at its foot
COLUMN_D_TOP = 3.4         # at its neck
PLINTH = 5.0               # the base's square plinth, its side
PLINTH_H = 0.6
TORUS_H = 0.6              # the round moulding on the plinth
BASE_H = PLINTH_H + TORUS_H
DRUM_H = 2.5               # one shaft drum
DRUMS = 11
SHAFT_H = DRUM_H * DRUMS   # 27.5
ECHINUS_H = 1.0
ABACUS = 5.2               # the capital's square slab, its side
ABACUS_H = 0.8
CAPITAL_H = ECHINUS_H + ABACUS_H
COLUMN_H = BASE_H + SHAFT_H + CAPITAL_H   # 30.5: the lintel's underside
FLUTES = 20
# The entablature over the columns (lane entablature), from COLUMN_H up.
ARCHITRAVE_H = 3.2
FRIEZE_H = 2.6
CORNICE_H = 1.7
ENTABLATURE_H = ARCHITRAVE_H + FRIEZE_H + CORNICE_H  # 7.5
ENTABLATURE_D = ABACUS     # the architrave's depth; the cornice juts 0.6 m more each side
# The podium (lane podium): steps up to the stylobate, column feet at z 0.
STEP_H = 1.0
STEP_TREAD = 1.6
STEPS = 3
PODIUM_H = STEP_H * STEPS  # the stylobate's top over the ground
# The inner wall (lane wall).
WALL_T = 2.4
COURSE_H = 1.25
DOOR_W = 14.0              # clear, at least; the plane fits with room
DOOR_H = 24.0
# Clear gaps (derived): between two shafts BAY - COLUMN_D = 14.5 at the foot,
# BAY - ABACUS = 13.3 at the capitals (the narrowest); under a lintel
# COLUMN_H = 30.5, over twice the shaft gap.
JOINT = 0.03               # the open joint between blocks / drums
BEVEL = 0.06               # a worn arris

# ---- The stone's colours (sRGB; written linear) --------------------------
STONE = (0.76, 0.71, 0.61)       # pale warm limestone
STONE_FRESH = (0.86, 0.81, 0.71) # a fresh break, paler
CREVICE = (0.34, 0.30, 0.25)     # deep in a joint
STAIN = (0.52, 0.50, 0.44)       # rain streaks and damp, grey
MOSS = (0.42, 0.47, 0.26)        # on what looks up
GROUND_DAMP = (0.50, 0.49, 0.38) # the splash band at the foot

FACE, JOINTFACE, BROKEN = 0, 1, 2   # face kinds: cut face, arris/joint, fresh break
DEEP_DARK = 0.75                    # how dark a `deep` vertex (the bottom of a shaft's joint) goes


def srgb_to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def _layers(bm):
    kind = bm.faces.layers.int.get("kind") or bm.faces.layers.int.new("kind")
    tone = bm.faces.layers.float.get("tone") or bm.faces.layers.float.new("tone")
    broke = bm.verts.layers.float.get("broke") or bm.verts.layers.float.new("broke")
    return kind, tone, broke


def _deep(bm, make=True):
    """The optional vertex layer `deep` (0..1): how far into an open joint a
    vertex sits; paint() darkens toward CREVICE by it. Absent = 0."""
    lay = bm.verts.layers.float.get("deep")
    if lay is None and make:
        lay = bm.verts.layers.float.new("deep")
    return lay


NORMAL_LAYERS = ("nx", "ny", "nz")


def _normals(bm, make=True):
    """Optional vertex layers nx, ny, nz: a vertex's given normal (all 0 =
    none). export() writes it as the custom normal of that vertex's corners
    on cut faces (FACE); every other corner keeps the auto normal."""
    lays = [bm.verts.layers.float.get(k) for k in NORMAL_LAYERS]
    if lays[0] is None:
        if not make:
            return None
        lays = [bm.verts.layers.float.new(k) for k in NORMAL_LAYERS]
    return lays


def _set_normal(v, lays, n):
    for lay, x in zip(lays, n):
        v[lay] = x


def _append(dst, src, matrix=None):
    """Copies src's verts and faces (with the kit's layers) into dst."""
    dk, dt, db = _layers(dst)
    sk, st, sb = _layers(src)
    sd = _deep(src, make=False)
    dd = _deep(dst) if sd is not None else None
    sn = _normals(src, make=False)
    dn = _normals(dst) if sn is not None else None
    rot = matrix.to_3x3() if matrix is not None else None
    vmap = {}
    for v in src.verts:
        co = matrix @ v.co if matrix is not None else v.co.copy()
        nv = dst.verts.new(co)
        nv[db] = v[sb]
        if sd is not None:
            nv[dd] = v[sd]
        if sn is not None:
            n = Vector([v[x] for x in sn])
            if rot is not None and n.length > 0.0:
                n = (rot @ n).normalized()
            _set_normal(nv, dn, n)
        vmap[v] = nv
    for f in src.faces:
        try:
            nf = dst.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        nf[dk] = f[sk]
        nf[dt] = f[st]


class Piece:
    """One kit piece: a near mesh, a far LOD, its solids, then `export()`."""

    def __init__(self, name, seed=1):
        self.name = name
        self.rng = random.Random(seed)
        self.near = bmesh.new()
        self.far = bmesh.new()
        _layers(self.near)
        _layers(self.far)
        self.boxes = []
        # The ground the piece stands on (Blender z), for the damp band and
        # the moss's reach; a lane on the podium may raise it.
        self.ground = 0.0

    # -- helpers ----------------------------------------------------------
    def tone(self):
        """A block's own shade: no two stones quite alike."""
        return self.rng.uniform(0.86, 1.08)

    def _chip(self, bm, corner, size, depth, kind_layer, broke_layer):
        """Knocks a corner off: cuts bm with a plane through `corner`'s
        neighbourhood and fills the hole as a fresh break."""
        r = self.rng
        n = Vector(corner).normalized()
        n = (n + Vector((r.uniform(-0.45, 0.45), r.uniform(-0.45, 0.45), r.uniform(-0.45, 0.45)))).normalized()
        co = Vector(corner) - n * depth
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n, clear_outer=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if not cut:
            return
        made = bmesh.ops.holes_fill(bm, edges=cut, sides=0)
        for f in made["faces"]:
            f[kind_layer] = BROKEN
            for v in f.verts:
                v[broke_layer] = 1.0

    # -- blocks -----------------------------------------------------------
    @staticmethod
    def _unseen_faces(bm, hide, seen=None):
        """A block's faces (in its own frame, a convex cut box) nobody sees.
        A face's sides are the axes its normal leans along (a face 1, a
        bevel 2, a corner 3). Without `seen`: the faces that lean only
        toward `hide` sides. With `seen`: every face that leans toward a
        `hide` side and toward no `seen` one (so the bevels between a hidden
        side and one in neither set, deep in a joint, go too)."""
        hide = set(hide)
        bm.normal_update()
        out = []
        for f in bm.faces:
            n = f.normal
            sides = {("+" if n[i] > 0 else "-") + "xyz"[i] for i in range(3) if abs(n[i]) > 0.3}
            if not sides:
                continue
            if seen is None and sides <= hide or seen is not None and sides & hide and not sides & set(seen):
                out.append(f)
        return out

    def block(self, center, size, yaw=0.0, tilt=(0.0, 0.0), bevel=BEVEL, chips=2,
              chip_depth=(0.12, 0.45), jitter=0.012, tone=None, far=True, kind=FACE, hide=(), seen=None):
        """A cut block, centre and size (x, y, z), worn arrises and `chips`
        corners knocked off. `tilt` (about x, about y) for a fallen one.
        `hide`: sides nobody sees ("-z", "+y", ... in the block's own frame,
        before yaw and tilt): their faces are left out, and so are the bevels
        and corners (and chips) that touch only hidden sides; with `seen`
        (the sides that show in full) also those touching a hidden side and
        no seen one. The stone is cut and worn as without `hide` (same
        random draws), then trimmed."""
        r = self.rng
        sx, sy, sz = size
        tmp = bmesh.new()
        tk, tt, tb = _layers(tmp)
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
        t = self.tone() if tone is None else tone
        for f in tmp.faces:
            f[tk] = kind
            f[tt] = t
        if bevel > 0.0:
            b = min(bevel * r.uniform(0.6, 1.5), 0.3 * min(size))
            res = bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=1,
                                  profile=0.5, affect="EDGES", clamp_overlap=True)
            for f in res["faces"]:
                f[tk] = JOINTFACE
                f[tt] = t
        for _ in range(chips):
            corner = Vector((r.choice((-1, 1)) * sx / 2, r.choice((-1, 1)) * sy / 2, r.choice((-1, 1)) * sz / 2))
            # Sometimes along an edge rather than at a corner.
            axis = r.randrange(4)
            if axis < 3:
                corner[axis] *= r.uniform(-0.7, 0.7)
            d = r.uniform(*chip_depth) * min(1.0, min(size) / 0.8)
            self._chip(tmp, corner, size, d, tk, tb)
            for f in tmp.faces:
                f[tt] = t
        unseen = self._unseen_faces(tmp, hide, seen) if hide else []
        if jitter > 0.0:
            for v in tmp.verts:
                v.co += Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1, 1))) * jitter
        if unseen:
            bmesh.ops.delete(tmp, geom=unseen, context="FACES")
        m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
             @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X"))
        _append(self.near, tmp, m)
        tmp.free()
        if far:
            self.far_box(center, size, yaw=yaw, tilt=tilt, tone=t)

    def course(self, x0, x1, z, height, depth, y=0.0, length=(2.2, 3.6), chips=1, far=True, **kw):
        """A course of blocks along x from x0 to x1, its foot at z, centred
        on y, `depth` thick, with open joints (JOINT) between them."""
        r = self.rng
        x = x0
        while x < x1 - 0.3:
            L = min(r.uniform(*length), x1 - x)
            if x1 - (x + L) < 0.9:
                L = x1 - x
            self.block((x + L / 2, y, z + height / 2), (L - JOINT, depth, height - JOINT),
                       chips=r.randint(0, chips), far=False, **kw)
            x += L
        if far:
            self.far_box(((x0 + x1) / 2, y, z + height / 2), (x1 - x0, depth, height))

    # -- round work --------------------------------------------------------
    def shaft(self, base, drums, drum_h, r_foot, r_neck, flutes=FLUTES, samples=2, flute_depth=0.17,
              chamfer=0.07, groove=0.05, chips=(1, 2, 2, 3), bite=(0.15, 0.5), shift=0.06, yaw=0.0):
        """A standing shaft of `drums` fluted drums, its foot's centre at
        `base`, tapering r_foot -> r_neck, as one mesh: each drum's flank
        (two rings, `samples` points per flute, its faces given the true
        flute's normals so even two points shade round) and between drums
        one shared groove ring (the flute's outline `chamfer` + `groove` m
        in) that both chamfers run into, painted dark (`deep`). Looks like
        a stack of drum()s with open joints at about a quarter of the
        triangles: no end caps (faces in the joint), no flute detail beyond
        what the outline and the light need. The shaft's foot and top rings
        sit on the planes of what is under and over it (a torus's top, an
        echinus's foot), which must cover them. Same draws from the rng per
        drum as drum() (`chips` a choice per drum)."""
        r = self.rng
        bx0, by0, bz0 = base
        n = flutes * samples
        m = n
        span = math.tau / flutes
        slope = (r_neck - r_foot) / (drums * drum_h)
        bk, bt, bb = _layers(self.near)
        bd = _deep(self.near)
        nrm = _normals(self.near)
        info = []
        for i in range(drums):
            nch = r.choice(chips)
            dx = r.uniform(-shift, shift)
            dy = r.uniform(-shift, shift)
            t = self.tone()
            bites = [(r.uniform(0, math.tau), r.uniform(0.15, 0.5), r.uniform(*bite), r.random() < 0.6)
                     for _ in range(nch)]
            info.append((dx, dy, t, bites))

        def rad_at(z):
            return r_foot + (r_neck - r_foot) * (z - bz0) / (drums * drum_h)

        def bitten(bites, a, top, depth_w, z_w):
            dr = dz = 0.0
            broke = 0.0
            for (ba, hw, d, at_top) in bites:
                if at_top != top:
                    continue
                da = math.atan2(math.sin(a - ba), math.cos(a - ba))
                w = max(0.0, 1.0 - abs(da) / hw)
                if w <= 0.0:
                    continue
                w = w ** 0.7
                dr -= d * w * depth_w
                dz += (-1 if top else 1) * d * 0.6 * w * z_w
                broke = max(broke, w)
            return dr, dz, broke

        def flute_normal(a, u, rad):
            """The true fluted surface's normal at angle a, u across the
            flute (0 one arris, 1 the next)."""
            drda = -flute_depth * math.pi * math.cos(math.pi * u) / span
            nv = Vector((math.cos(a), math.sin(a), 0.0)) - Vector((-math.sin(a), math.cos(a), 0.0)) * (drda / rad)
            nv.z = -slope
            return nv.normalized()

        def flank(i, z, top):
            """A flank ring: (R, L), the vertex each face starting / ending
            at point k uses (two at an arris, its sides' normals apart)."""
            dx, dy, t, bites = info[i]
            ring, left = [], []
            for k in range(n):
                a = yaw + math.tau * k / n
                u = (k % samples) / samples
                rad = rad_at(z) - flute_depth * math.sin(math.pi * u)
                rad += noise.noise(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, z * 0.9))) * 0.035
                dr, dz, broke = bitten(bites, a, top, 0.7, 1.0)
                co = (bx0 + dx + math.cos(a) * (rad + dr), by0 + dy + math.sin(a) * (rad + dr), z + dz)
                v = self.near.verts.new(co)
                v[bb] = broke
                if broke < 0.3:
                    _set_normal(v, nrm, flute_normal(a, u, rad))
                ring.append(v)
                if k % samples == 0:
                    w = self.near.verts.new(co)
                    w[bb] = broke
                    if broke < 0.3:
                        _set_normal(w, nrm, flute_normal(a, 1.0, rad))
                    left.append(w)
                else:
                    left.append(v)
            return ring, left

        def groove_ring(j, z):
            # Between drum j-1 (its top) and drum j (its foot); the ends of
            # the shaft have one neighbour.
            below = info[j - 1] if j > 0 else None
            above = info[j] if j < drums else None
            nb = [x for x in (below, above) if x is not None]
            dx = sum(x[0] for x in nb) / len(nb)
            dy = sum(x[1] for x in nb) / len(nb)
            ring = []
            for k in range(m):
                a = yaw + math.tau * k / m
                rad = rad_at(z) - flute_depth * math.sin(math.pi * (k % samples) / samples) - chamfer - groove
                rad += noise.noise(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, z * 0.9))) * 0.035
                dr = 0.0
                broke = 0.0
                for x, top in ((below, True), (above, False)):
                    if x is None:
                        continue
                    d_, _, b_ = bitten(x[3], a, top, 1.0, 0.0)
                    dr = min(dr, d_)
                    broke = max(broke, b_)
                v = self.near.verts.new((bx0 + dx + math.cos(a) * (rad + dr), by0 + dy + math.sin(a) * (rad + dr), z))
                v[bb] = broke
                v[bd] = 1.0
                ring.append(v)
            return ring

        def band(lo, hi, kind, t):
            """Faces between two rings round the axis, any counts (a zipper
            by angle), outward."""
            i = j = 0
            nl, nh = len(lo), len(hi)
            while i < nl or j < nh:
                if j >= nh or (i < nl and (i + 1) / nl <= (j + 1) / nh):
                    f = self.near.faces.new((lo[i % nl], lo[(i + 1) % nl], hi[j % nh]))
                    i += 1
                else:
                    f = self.near.faces.new((lo[i % nl], hi[(j + 1) % nh], hi[j % nh]))
                    j += 1
                f[bk] = kind
                f[bt] = t

        def quads(lo, hi, kind, t):
            (lr, ll), (hr, hl) = lo, hi
            for k in range(n):
                k1 = (k + 1) % n
                f = self.near.faces.new((lr[k], ll[k1], hl[k1], hr[k]))
                f[bk] = kind
                f[bt] = t

        top_z = bz0 + drums * drum_h
        g = groove_ring(0, bz0)
        for i in range(drums):
            z0 = bz0 + i * drum_h
            t = info[i][2]
            f0 = flank(i, z0 + JOINT / 2 + chamfer, False)
            f1 = flank(i, z0 + drum_h - JOINT / 2 - chamfer, True)
            g1 = groove_ring(i + 1, top_z if i == drums - 1 else z0 + drum_h)
            band(g, f0[0], JOINTFACE, t)
            quads(f0, f1, FACE, t)
            band(f1[0], g1, JOINTFACE, t)
            g = g1

    def drum(self, base, height, r0, r1, flutes=FLUTES, flute_depth=0.13, chamfer=0.07,
             chips=1, bite=(0.12, 0.4), samples=4, yaw=None, tone=None, shift=0.03, caps=(True, True),
             true_normals=False):
        """A fluted drum, its foot's centre at `base`, radius r0 at the foot
        and r1 at the top (the shaft's taper), sharp arrises between the
        flutes, the ends chamfered so the joint between drums reads open.
        `chips` bites out of its top or bottom edge; set slightly off true
        (`shift` m, a turn) as old drums sit. `caps` (foot, top): False
        leaves that end open, for an end no one can see. `true_normals`
        (as shaft()): the flank's faces take the true flute's normals
        (custom split normals, each arris vertex split in two, one per
        side), so samples=2 shades as round as the default's 4-6; the
        flank is then open along each arris (a seam of twin vertices: a
        bisect across it must weld its cut). Same draws from the rng either
        way. (A standing stack of drums: shaft(), cheaper.)"""
        r = self.rng
        bx, by, bz = base
        bx += r.uniform(-shift, shift)
        by += r.uniform(-shift, shift)
        yaw = r.uniform(0, math.tau) if yaw is None else yaw
        t = self.tone() if tone is None else tone
        n = flutes * samples
        # The drum's bites: (angle, half width, depth, at top?).
        bites = [(r.uniform(0, math.tau), r.uniform(0.15, 0.5), r.uniform(*bite), r.random() < 0.6)
                 for _ in range(chips)]
        bk, bt, bb = _layers(self.near)
        nrm = _normals(self.near) if true_normals else None
        span = math.tau / flutes
        slope = (r1 - r0) / height

        def flute_normal(a, u, rad):
            # The true fluted surface's normal at angle a, u across the flute.
            drda = -flute_depth * math.pi * math.cos(math.pi * u) / span
            nv = Vector((math.cos(a), math.sin(a), 0.0)) - Vector((-math.sin(a), math.cos(a), 0.0)) * (drda / rad)
            nv.z = -slope
            return nv.normalized()

        zs = [(0.0, chamfer), (chamfer, 0.0), (height - chamfer, 0.0), (height, chamfer)]
        rings = []
        lefts = []
        for zi, (z, inset) in enumerate(zs):
            ring = []
            left = []
            rad_here = r0 + (r1 - r0) * (z / height)
            for i in range(n):
                a = yaw + math.tau * i / n
                u = (i % samples) / samples
                rad = rad_here - flute_depth * math.sin(math.pi * u) - inset
                rad += noise.noise(Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, (bz + z) * 0.9))) * 0.035
                zz = z
                broke = 0.0
                for (ba, hw, d, top) in bites:
                    da = math.atan2(math.sin(a - ba), math.cos(a - ba))
                    w = max(0.0, 1.0 - abs(da) / hw)
                    if w <= 0.0:
                        continue
                    w = w ** 0.7
                    end = (zi >= 2) if top else (zi <= 1)
                    if end:
                        rad -= d * w * (1.0 if zi in (0, 3) else 0.7)
                        zz += (-1 if top else 1) * d * 0.6 * w * (1.0 if zi in (1, 2) else 0.3)
                        broke = max(broke, w)
                co = (bx + math.cos(a) * rad, by + math.sin(a) * rad, bz + zz)
                v = self.near.verts.new(co)
                v[bb] = broke
                ring.append(v)
                if nrm is None or zi in (0, 3):
                    left.append(v)
                    continue
                # The flank: the true flute's normal; an arris vertex gets a
                # twin carrying the previous flute's side.
                if broke < 0.3:
                    _set_normal(v, nrm, flute_normal(a, u, rad_here))
                if i % samples == 0:
                    w = self.near.verts.new(co)
                    w[bb] = broke
                    if broke < 0.3:
                        _set_normal(w, nrm, flute_normal(a, 1.0, rad_here))
                    left.append(w)
                else:
                    left.append(v)
            rings.append(ring)
            lefts.append(left)
        for zi in range(3):
            lo, hi = rings[zi], rings[zi + 1]
            for i in range(n):
                j = (i + 1) % n
                if zi == 1:
                    vs = (lo[i], lefts[1][j], lefts[2][j], hi[i])
                else:
                    vs = (lo[i], lo[j], hi[j], hi[i])
                f = self.near.faces.new(vs)
                f[bk] = FACE if zi == 1 else JOINTFACE
                f[bt] = t
        for ring, z, flip, cap in ((rings[0], 0.0, True, caps[0]), (rings[3], height, False, caps[1])):
            if not cap:
                continue
            c = self.near.verts.new((bx, by, bz + z))
            for i in range(n):
                j = (i + 1) % n
                vs = (c, ring[j], ring[i]) if flip else (c, ring[i], ring[j])
                f = self.near.faces.new(vs)
                f[bk] = JOINTFACE
                f[bt] = t

    def ring(self, base, profile, segments=48, tone=None, chips=1, bite=(0.1, 0.3), far=False, caps=(True, True)):
        """A turned moulding (a torus, an echinus): `profile` is
        [(radius, z), ...] from the bottom up, revolved round `base`.
        `caps` (bottom, top): False leaves that end open (it sits on, or
        under, something that covers it)."""
        r = self.rng
        bx, by, bz = base
        t = self.tone() if tone is None else tone
        bites = [(r.uniform(0, math.tau), r.uniform(0.2, 0.6), r.uniform(*bite)) for _ in range(chips)]
        bk, bt, bb = _layers(self.near)
        rows = []
        top_i = len(profile) - 1
        for pi, (rad0, z) in enumerate(profile):
            row = []
            for i in range(segments):
                a = math.tau * i / segments
                rad = rad0 + noise.noise(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, (bz + z) * 1.3))) * 0.03
                broke = 0.0
                for (ba, hw, d) in bites:
                    da = math.atan2(math.sin(a - ba), math.cos(a - ba))
                    w = max(0.0, 1.0 - abs(da) / hw)
                    if w > 0 and 0 < pi < top_i:
                        rad -= d * w
                        broke = max(broke, w)
                v = self.near.verts.new((bx + math.cos(a) * rad, by + math.sin(a) * rad, bz + z))
                v[bb] = broke
                row.append(v)
            rows.append(row)
        for pi in range(len(rows) - 1):
            lo, hi = rows[pi], rows[pi + 1]
            for i in range(segments):
                j = (i + 1) % segments
                f = self.near.faces.new((lo[i], lo[j], hi[j], hi[i]))
                f[bk] = FACE
                f[bt] = t
        for row, z, flip, cap in ((rows[0], profile[0][1], True, caps[0]), (rows[-1], profile[-1][1], False, caps[1])):
            if not cap:
                continue
            c = self.near.verts.new((bx, by, bz + z))
            for i in range(segments):
                j = (i + 1) % segments
                f = self.near.faces.new((c, row[j], row[i]) if flip else (c, row[i], row[j]))
                f[bk] = JOINTFACE
                f[bt] = t
        if far:
            self.far_cylinder(base, profile[-1][1] - profile[0][1], max(p[0] for p in profile), max(p[0] for p in profile))

    # -- the far LOD -------------------------------------------------------
    def far_box(self, center, size, yaw=0.0, tilt=(0.0, 0.0), tone=1.0):
        tmp = bmesh.new()
        tk, tt, tb = _layers(tmp)
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        for f in tmp.faces:
            f[tk] = FACE
            f[tt] = tone
        m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
             @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X"))
        _append(self.far, tmp, m)
        tmp.free()

    def far_cylinder(self, base, height, r0, r1, segments=10, tone=1.0, matrix=None):
        """A plain tapered cylinder for the far LOD; `matrix` places it (a
        fallen drum: a rotation about its foot)."""
        tmp = bmesh.new()
        tk, tt, tb = _layers(tmp)
        lo, hi = [], []
        for i in range(segments):
            a = math.tau * i / segments
            lo.append(tmp.verts.new((math.cos(a) * r0, math.sin(a) * r0, 0.0)))
            hi.append(tmp.verts.new((math.cos(a) * r1, math.sin(a) * r1, height)))
        for i in range(segments):
            j = (i + 1) % segments
            tmp.faces.new((lo[i], lo[j], hi[j], hi[i]))
        tmp.faces.new(list(reversed(lo)))
        tmp.faces.new(hi)
        for f in tmp.faces:
            f[tk] = FACE
            f[tt] = tone
        m = Matrix.Translation(Vector(base)) @ (matrix if matrix is not None else Matrix.Identity(4))
        _append(self.far, tmp, m)
        tmp.free()

    # -- solids ------------------------------------------------------------
    def solid(self, lo, hi):
        """One of the flight's solids, an axis-aligned box in Blender's
        frame (z up), corners lo and hi. Few and coarse."""
        self.boxes.append((tuple(lo), tuple(hi)))

    # -- colour and export -------------------------------------------------
    def paint(self, bm, far=False):
        """Per-corner colour: the block's tone, dark joints, pale fresh
        breaks, rain streaks down the faces, damp at the foot, moss on
        what looks up."""
        bm.normal_update()
        kind, tone, broke = _layers(bm)
        deep = _deep(bm, make=False)
        col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        stone = STONE
        for f in bm.faces:
            k = f[kind]
            t = f[tone]
            nz = f.normal.z
            for loop in f.loops:
                v = loop.vert
                p = v.co
                c = tuple(x * t for x in stone)
                if k == JOINTFACE and not far:
                    c = mix(c, CREVICE, 0.35 if nz < 0.5 else 0.15)
                if deep is not None and not far:
                    c = mix(c, CREVICE, DEEP_DARK * v[deep])
                if not far:
                    c = mix(c, STONE_FRESH, 0.75 * v[broke])
                # Rain streaks: long vertical runs, darker under ledges.
                streak = noise.noise(Vector((p.x * 0.9, p.y * 0.9, p.z * 0.08)))
                streak = max(0.0, streak) * (1.0 - max(0.0, nz))
                c = mix(c, STAIN, 0.55 * streak)
                # Broad blotches over the whole piece.
                blot = noise.noise(Vector((p.x * 0.18 + 11.0, p.y * 0.18, p.z * 0.18)))
                c = tuple(x * (1.0 + 0.10 * blot) for x in c)
                # Damp at the foot.
                h = p.z - self.ground
                c = mix(c, GROUND_DAMP, 0.6 * max(0.0, 1.0 - h / 1.2))
                # Moss on what looks up, in patches; on ledges and the foot.
                m = noise.noise(Vector((p.x * 0.6, p.y * 0.6, p.z * 0.6 + 5.0))) * 0.5 + 0.5
                up = max(0.0, nz - 0.45) / 0.55
                low = max(0.0, 1.0 - h / 1.4)
                moss = max(up * (0.35 + 0.65 * m), low * m * 0.7)
                moss = max(0.0, min(1.0, (moss - 0.35) * 1.6))
                c = mix(c, MOSS, moss * (0.85 if not far else 0.6) * getattr(self, "moss_amount", 1.0))
                loop[col] = srgb_to_linear(c) + (1.0,)
        return col

    def _object(self, bm, name, far):
        self.paint(bm, far=far)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        me.color_attributes.active_color = me.color_attributes["Col"]
        given = None
        if "nx" in me.attributes and not far:
            xs = [[d.value for d in me.attributes[k].data] for k in NORMAL_LAYERS]
            kinds = [d.value for d in me.attributes["kind"].data]
            given = (xs, kinds)
        for a in ("kind", "tone", "broke", "deep") + NORMAL_LAYERS:
            if a in me.attributes:
                me.attributes.remove(me.attributes[a])
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        me.set_sharp_from_angle(angle=math.radians(40.0 if not far else 30.0))
        me.update()
        if given is not None:
            (nx, ny, nz), kinds = given
            corner = [tuple(c.vector) for c in me.corner_normals]
            for poly in me.polygons:
                if kinds[poly.index] != FACE:
                    continue
                for li in poly.loop_indices:
                    vi = me.loops[li].vertex_index
                    if nx[vi] or ny[vi] or nz[vi]:
                        corner[li] = (nx[vi], ny[vi], nz[vi])
            me.normals_split_custom_set(corner)
            me.update()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        mat = bpy.data.materials.get("temple_stone") or bpy.data.materials.new("temple_stone")
        me.materials.append(mat)
        return ob, sum(len(p.vertices) - 2 for p in me.polygons)

    def export(self, mid_of=None):
        """Writes <name>.glb (meshes <name>, <name>_far) and
        <name>.boxes.json. With `mid_of` (a piece's id) this Piece is that
        piece's mid LOD instead: <mid_of>_mid.glb holding one mesh,
        <mid_of>_mid, its count added to <mid_of>.boxes.json as mid_tris.
        (A file of its own: scripts/temple_kit.gd takes every mesh in a
        piece's .glb not named *_far as the near one.)"""
        for ob in list(bpy.data.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        MODELS.mkdir(parents=True, exist_ok=True)
        if mid_of is not None:
            mid, mid_tris = self._object(self.near, mid_of + "_mid", False)
            glb = MODELS / f"{mid_of}_mid.glb"
            self._gltf(glb)
            side = MODELS / f"{mid_of}.boxes.json"
            info = json.loads(side.read_text())
            info["mid_tris"] = mid_tris
            side.write_text(json.dumps(info, indent=1) + "\n")
            print(f"TEMPLE {mid_of}_mid: {mid_tris} tris -> {glb}")
            self.near.free()
            self.far.free()
            return
        near, near_tris = self._object(self.near, self.name, False)
        far, far_tris = self._object(self.far, self.name + "_far", True)
        glb = MODELS / f"{self.name}.glb"
        self._gltf(glb)
        self._sidecar(glb, near_tris, far_tris)

    def _gltf(self, glb):
        bpy.ops.export_scene.gltf(
            filepath=str(glb), export_format="GLB", use_selection=False, export_apply=False,
            export_yup=True, export_materials="EXPORT", export_vertex_color="NAME", export_vertex_color_name="Col",
            export_all_vertex_colors=False,
            export_normals=True, export_tangents=False, export_animations=False, export_cameras=False,
            export_lights=False, export_morph=False, export_skins=False)

    def _sidecar(self, glb, near_tris, far_tris):
        boxes = []
        for lo, hi in self.boxes:
            # Godot (x, y, z) = Blender (x, z, -y).
            boxes.append([round(lo[0], 3), round(lo[2], 3), round(-hi[1], 3),
                          round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)])
        info = {"piece": self.name, "boxes": boxes, "tris": near_tris, "far_tris": far_tris}
        (MODELS / f"{self.name}.boxes.json").write_text(json.dumps(info, indent=1) + "\n")
        print(f"TEMPLE {self.name}: {near_tris} tris near, {far_tris} far, {len(boxes)} boxes -> {glb}")
        self.near.free()
        self.far.free()
