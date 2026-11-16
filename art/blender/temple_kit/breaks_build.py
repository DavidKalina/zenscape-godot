"""The temple kit's breakable pieces (scripts/endless/temple_breaks.gd): a
cracked variant of a piece another lane builds, and what is left of it once
the plane has been through, each made from that lane's own build (the same
stones, the same seed) and then cut here.

    python tools/blender.py run art/blender/temple_kit/breaks_build.py [-- --only=aqueduct_arch_cracked]

A cracked piece is its source split along zigzag cracks (bands of height,
each cut at its own place along x), the gaps open and their faces dark, the
stone by them stained dark, the pieces sagged or slipped so the courses no
longer line up. Its solids are the
source's. What is left is the source cut back to the regions kept, the cuts
pale fresh breaks, with solids of its own.

- `aqueduct_arch_cracked`: the span cracked at the crown and by each haunch,
  its middle dropped.
- `street_column_cracked`: the column (temple units) cut twice on the slant,
  its middle and top slipped.
- `street_lintel_cross_cracked`, `street_lintel_cross_snapped`: the beam
  across the way cracked and sagged; its two ends left on the abaci.
- `agora_stoa_wall_cracked`, `agora_stoa_wall_holed`: the stoa's back wall
  bay cracked foot to top; the same bay with a ragged breach.
- `agora_lintel_cracked`: the kit's lintel cracked and sagged.
- `agora_altar_cracked`, `agora_altar_smashed`: the altar split; its lowest
  course left.
- `temple_break_chunk`: one lump of stone, about a metre, for the debris.

The bold ones (BOLD: wider, darker cracks, parts fallen out so daylight
shows, for a plane that chooses at 150 m):
- `lintel_cracked_wide`, `lintel_snapped`: the kit's lintel in three, its
  middle dropped between the sagging ends; the two ends left on the abaci.
- `column_cracked_wide`: the column cut twice, its parts slid well off.
- `theatre_stage_wall_cracked`, `theatre_stage_wall_holed`: the stage wall's
  bay split from its window's notch to its foot, the halves leaning apart;
  the bay's two edges left.
- `arena_outer_cracked`, `arena_outer_gapped`: the outer wall's bay with its
  arch's crown dropped; the two piers left.
- `arena_vault_a_cracked`: the corridor's vault, its crown strip sagged and
  part of it down.
- `arena_block_cracked`, `arena_block_holed`: a wall filling the inner
  wall's arch (`_a`), built here, cracked; its sill and jamb stubs.
- `baths_rotunda_cut`: the rotunda less two stretches of its drum (SECTIONS:
  a little north of west, north-east), which are pieces of their own:
  `baths_wall_w_cracked`, `baths_wall_ne_cracked`, each split foot to top
  with a hole high in it, and `baths_wall_w_holed`, `baths_wall_ne_holed`,
  the same stretch with a ragged breach.

To add one: an entry in VARIANTS (the source's script, its piece, the --only
it takes, the cut).
"""

import math
import runpy
import sys
from pathlib import Path

import bmesh
from mathutils import Matrix, Vector

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

HERE = Path(__file__).resolve().parent
DARK = 0.34         # a crack's faces, against the stone's tone of about 1


BOLD = 0.16         # a bold crack's faces


def _cut(bm, co, no, fresh, dark=DARK):
    """Drops what lies past the plane (the side `no` points to) and caps the
    cut: a pale fresh break, or the dark inside of a crack."""
    kind, tone, broke = T._layers(bm)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    if not geom:
        return
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no).normalized(), clear_outer=True)
    edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if not edges:
        return
    made = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    for f in made["faces"]:
        if fresh:
            f[kind] = T.BROKEN
            f[tone] = 1.0
            for v in f.verts:
                v[broke] = 1.0
        else:
            f[kind] = T.FACE
            f[tone] = dark


def _part(bm, planes, fresh, dark=DARK):
    """A copy of bm cut back by every plane in `planes` ((co, no): what `no`
    points to goes)."""
    part = bm.copy()
    for co, no in planes:
        _cut(part, co, no, fresh, dark)
    return part


def _slab(d, a, b):
    """The planes that keep a < p.d < b (None: open that side)."""
    d = Vector(d)
    out = []
    if a is not None:
        out.append((d * a, -d))
    if b is not None:
        out.append((d * b, d))
    return out


def _band(z0, z1):
    return [((0, 0, z0), (0, 0, -1)), ((0, 0, z1), (0, 0, 1))]


def _about(pivot, angle, axis="Y"):
    return Matrix.Translation(Vector(pivot)) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-Vector(pivot))


def _new():
    out = bmesh.new()
    T._layers(out)
    return out


STAIN = 0.4         # the stone's tone at a crack's lip ...
STAIN_R = 3.0       # ... easing back to its own this far from it (m)


def _stain(bm, near, stain=STAIN, reach=STAIN_R):
    """Darkens bm's faces by how near the crack each is (`near`: a face's
    middle -> m)."""
    kind, tone, broke = T._layers(bm)
    for f in bm.faces:
        k = min(1.0, max(0.0, near(f.calc_center_median())) / reach)
        f[tone] = f[tone] * (stain + (1.0 - stain) * k)


def shattered(bm, bands, cuts, gap, mats, gone=(), band_dir=(0, 0, 1), cut_dir=(1, 0, 0), dark=DARK, stain=STAIN,
              reach=STAIN_R):
    """bm split along zigzag cracks: `bands` [(z0, z1)], `cuts` one list of
    x a crack (its place in each band), each a gap `gap` wide and dark, the
    stone by it stained; the pieces between them, -x to +x, placed by `mats`
    (a matrix a piece, or a function (band, piece) -> matrix).
    `gone`: (band, piece) pairs left out (stone already fallen). The bands
    lie along `band_dir` and the cuts along `cut_dir` (z and x)."""
    out = _new()
    bd, cd = Vector(band_dir), Vector(cut_dir)
    for k, (z0, z1) in enumerate(bands):
        xs = [c[k] for c in cuts]
        for i in range(len(cuts) + 1):
            if (k, i) in gone:
                continue
            planes = _slab(bd, z0, z1)
            if i > 0:
                planes += _slab(cd, xs[i - 1] + gap / 2, None)
            if i < len(cuts):
                planes += _slab(cd, None, xs[i] - gap / 2)
            part = _part(bm, planes, False, dark)
            _stain(part, lambda c: min(abs(c.dot(cd) - x) for x in xs) - gap / 2, stain, reach)
            T._append(out, part, mats(k, i) if callable(mats) else mats[i])
            part.free()
    return out


def cracked(bm, bands, gap, m_neg, m_pos):
    """One crack: `bands` [(z0, z1, x)]."""
    return shattered(bm, [(z0, z1) for z0, z1, _ in bands], [[x for _, _, x in bands]], gap, [m_neg, m_pos])


def kept(bm, regions, fresh=True, dark=DARK):
    """bm cut back to `regions`, each a list of planes (what a plane's
    normal points to goes), the cuts fresh breaks."""
    out = _new()
    for planes in regions:
        part = _part(bm, planes, fresh, dark)
        T._append(out, part)
        part.free()
    return out


def slipped(bm, cuts, gap, slide, lean, dark=DARK, stain=STAIN):
    """A column cut on the slant at each of `cuts` ((height, normal)), every
    part above a cut slid `slide` m down the cut's slope and leaned `lean`
    rad that way, on top of what the parts under it did."""
    out = _new()
    rest = bm
    m = Matrix.Identity(4)
    for z, no in cuts:
        n = Vector(no).normalized()
        low = _part(rest, [((0, 0, z - gap / 2), n)], False, dark)
        top = _part(rest, [((0, 0, z + gap / 2), -n)], False, dark)
        for part in (low, top):
            _stain(part, lambda c: (abs((c - Vector((0, 0, z))).dot(n)) - gap / 2) * 0.7, stain)
        T._append(out, low, m)
        low.free()
        if rest is not bm:
            rest.free()
        rest = top
        down = -(Vector((0, 0, 1)) - n * n.z).normalized()
        axis = Vector((0, 0, 1)).cross(down).normalized()
        m = m @ Matrix.Translation(down * slide) @ Matrix.Translation((0, 0, z)) @ Matrix.Rotation(lean, 4, axis) @ Matrix.Translation((0, 0, -z))
    T._append(out, rest, m)
    if rest is not bm:
        rest.free()
    return out


def both(p, fn):
    """fn over the piece's near and far meshes."""
    for name in ("near", "far"):
        old = getattr(p, name)
        setattr(p, name, fn(old))
        old.free()


# ---- the cuts ---------------------------------------------------------------

def arch_cracked(p):
    # Three cracks: by each haunch and at the crown. The two middle pieces
    # have dropped and turned in, the outer two sag after them; the channel's
    # walls over the middle are down already, a notch in the skyline.
    bands = [(-70.0, -6.0), (-6.0, -3.3), (-3.3, -1.8), (-1.8, 5.0)]
    cuts = [[-5.3, -4.1, -5.0, -4.2], [0.2, 0.2, 1.3, 0.3], [5.4, 4.3, 5.2, 4.5]]
    mats = [_about((-7.25, 0, -6.0), 0.04),
            Matrix.Translation((0.0, 0.12, -1.25)) @ _about((-2.0, 0, -3.0), 0.11),
            Matrix.Translation((0.0, -0.15, -0.95)) @ _about((2.6, 0, -3.0), -0.09),
            _about((7.25, 0, -6.0), -0.035)]
    both(p, lambda bm: shattered(bm, bands, cuts, 0.75, mats, gone={(3, 1), (3, 2)}))


def column_cracked(p):
    cuts = [(9.5, (0.6, 0.12, 1.0)), (19.5, (-0.5, 0.25, 1.0))]
    both(p, lambda bm: slipped(bm, cuts, 0.9, 1.25, 0.035))


def beam_cracked(p):
    bands = [(0.0, 23.3, 0.9), (23.3, 40.0, 2.3)]
    both(p, lambda bm: cracked(bm, bands, 0.9, _about((-9.8, 0, 22.0), 0.1), _about((9.8, 0, 22.0), -0.075)))


def beam_snapped(p):
    regions = [[((-7.9, 0, 23.4), (1.0, 0.0, 0.4))], [((7.5, 0, 23.4), (-1.0, 0.0, -0.3))]]
    both(p, lambda bm: kept(bm, regions))
    lo, hi = p.boxes[0]
    p.boxes = [((lo[0], lo[1], lo[2]), (-7.6, hi[1], hi[2])), ((7.6, lo[1], lo[2]), (hi[0], hi[1], hi[2]))]


WALL_BANDS = [(-20.0, 5.0, -1.0), (5.0, 11.0, 1.3), (11.0, 18.0, -0.9), (18.0, 25.0, 1.6), (25.0, 32.0, -0.4),
              (32.0, 38.0, 1.1), (38.0, 60.0, 0.1)]


def wall_cracked(p):
    # The +x side pushed 0.3 m out of the wall's face and dropped a little.
    both(p, lambda bm: cracked(bm, WALL_BANDS, 1.1, Matrix.Identity(4), Matrix.Translation((0.05, -0.35, -0.3))))


# The breach: [(z0, z1, left edge, right edge)], foot to its ragged head.
BREACH = [(0.0, 5.0, -6.2, 6.0), (5.0, 10.0, -5.4, 6.6), (10.0, 15.0, -5.9, 5.2), (15.0, 19.0, -4.3, 4.0),
          (19.0, 22.5, -2.3, 2.5)]


def wall_holed(p):
    regions = [[((0, 0, 0.0), (0, 0, 1))], [((0, 0, 22.5), (0, 0, -1))]]
    for z0, z1, a, b in BREACH:
        regions.append(_band(z0, z1) + [((a, 0, 0), (1, 0, 0))])
        regions.append(_band(z0, z1) + [((b, 0, 0), (-1, 0, 0))])
    both(p, lambda bm: kept(bm, regions))
    lo, hi = p.boxes[0]
    p.boxes = [((lo[0], lo[1], lo[2]), (-6.0, hi[1], hi[2])), ((6.0, lo[1], lo[2]), (hi[0], hi[1], hi[2])),
               ((-6.0, lo[1], lo[2]), (6.0, hi[1], 0.0)), ((-6.0, lo[1], 21.0), (6.0, hi[1], hi[2]))]


def lintel_cracked(p):
    bands = [(0.0, 33.7, -0.9), (33.7, 36.3, 0.7), (36.3, 60.0, -0.4)]
    both(p, lambda bm: cracked(bm, bands, 1.0, _about((-9.25, 0, 30.5), 0.11), _about((9.25, 0, 30.5), -0.085)))


def altar_cracked(p):
    bands = [(-5.0, 1.6, 0.9), (1.6, 4.2, -0.7), (4.2, 20.0, 0.5)]
    both(p, lambda bm: cracked(bm, bands, 0.7, _about((-5.3, 0, -0.4), -0.035), _about((5.3, 0, -0.4), 0.06)))


def altar_smashed(p):
    both(p, lambda bm: kept(bm, [[((0, 0, 0.85), (0.06, 0.03, 1.0))]]))
    p.boxes = [((-5.3, -3.5, -0.4), (5.3, 3.5, 0.8)), ((5.8, -2.0, -0.2), (8.6, 4.0, 0.9))]


# ---- the bold cuts ----------------------------------------------------------
STAIN_BOLD = 0.62   # a bold crack's lips, easing back over BOLD_R m
BOLD_R = 1.6


def split_boxes(boxes, inside, cell=1.0):
    """The solids cut into cells of about `cell` and sorted by `inside`(x, y,
    z) at each one's middle: (those inside, the rest), runs along z joined."""
    got = ([], [])
    for lo, hi in boxes:
        n = [max(1, int(math.ceil((hi[i] - lo[i]) / cell - 1e-6))) for i in range(3)]
        d = [(hi[i] - lo[i]) / n[i] for i in range(3)]
        for i in range(n[0]):
            for j in range(n[1]):
                run = None
                for k in range(n[2] + 1):
                    c = (lo[0] + (i + 0.5) * d[0], lo[1] + (j + 0.5) * d[1], lo[2] + (k + 0.5) * d[2])
                    side = None if k == n[2] else (0 if inside(*c) else 1)
                    if run is not None and run[0] != side:
                        got[run[0]].append(((lo[0] + i * d[0], lo[1] + j * d[1], lo[2] + run[1] * d[2]),
                                            (lo[0] + (i + 1) * d[0], lo[1] + (j + 1) * d[1], lo[2] + k * d[2])))
                        run = None
                    if run is None and side is not None:
                        run = (side, k)
    return _joined(got[0]), _joined(got[1])


def _joined(boxes):
    """Boxes that share a face whole, joined (along y, then x)."""
    for ax in (1, 0):
        o1, o2 = [i for i in range(3) if i != ax]
        boxes = sorted(boxes, key=lambda b: (round(b[0][o1], 3), round(b[1][o1], 3), round(b[0][o2], 3), round(b[1][o2], 3), b[0][ax]))
        out = []
        for lo, hi in boxes:
            if out:
                plo, phi = out[-1]
                if (abs(plo[o1] - lo[o1]) < 1e-4 and abs(phi[o1] - hi[o1]) < 1e-4 and abs(plo[o2] - lo[o2]) < 1e-4
                        and abs(phi[o2] - hi[o2]) < 1e-4 and abs(phi[ax] - lo[ax]) < 1e-4):
                    out[-1] = (plo, tuple(hi[i] if i == ax else phi[i] for i in range(3)))
                    continue
            out.append((tuple(lo), tuple(hi)))
        boxes = out
    return boxes


def lintel_cracked_wide(p):
    # In three: the ends sag about their abaci, the middle has dropped between them.
    bands = [(0.0, 33.7), (33.7, 36.3), (36.3, 60.0)]
    cuts = [[-3.4, -2.2, -3.0], [2.4, 3.6, 2.8]]
    mats = [_about((-9.25, 0, 30.5), 0.13), Matrix.Translation((0.2, 0.5, -2.3)) @ _about((0, 0, 34.0), -0.1),
            _about((9.25, 0, 30.5), -0.1)]
    both(p, lambda bm: shattered(bm, bands, cuts, 1.5, mats, dark=BOLD, stain=STAIN_BOLD, reach=BOLD_R))


def lintel_snapped(p):
    regions = [[((-5.4, 0, 34.0), (1.0, 0.0, 0.45))], [((5.7, 0, 34.0), (-1.0, 0.0, -0.3))]]
    both(p, lambda bm: kept(bm, regions))
    p.boxes = split_boxes(p.boxes, lambda x, y, z: abs(x) > 5.6, 0.9)[0]


def column_wide(p):
    cuts = [(8.5, (0.7, 0.15, 1.0)), (18.5, (-0.6, 0.3, 1.0))]
    both(p, lambda bm: slipped(bm, cuts, 1.5, 1.7, 0.05, dark=BOLD, stain=STAIN_BOLD))


STAGE_BANDS = [(-6.0, 4.8), (4.8, 9.6), (9.6, 14.4), (14.4, 19.2), (19.2, 24.0), (24.0, 40.0)]
# What is left of the bay: [(z0, z1, the -x stub's edge, the +x stub's edge)].
STAGE_BREACH = [(0.0, 4.8, -3.5, 3.8), (4.8, 9.6, -4.0, 3.3), (9.6, 14.4, -3.3, 3.7), (14.4, 19.2, -3.8, 3.2),
                (19.2, 24.0, -3.2, 3.5), (24.0, 40.0, -3.6, 3.4)]


def stage_cracked(p):
    # One wide crack down from the window's notch to the foot, open to the
    # sky behind; the two halves lean apart, the +x one pushed out of the face
    # and dropped.
    cuts = [[-0.5, 0.9, -0.8, 0.7, -0.4, 0.0]]
    mats = [_about((-5.0, 0, 0.0), 0.03), Matrix.Translation((0.0, -0.9, -0.6)) @ _about((5.0, 0, 0.0), -0.035)]
    both(p, lambda bm: shattered(bm, STAGE_BANDS, cuts, 1.9, mats, dark=BOLD, stain=STAIN_BOLD, reach=BOLD_R))


def stage_holed(p):
    regions = [[((0, 0, 0.0), (0, 0, 1))]]
    for z0, z1, a, b in STAGE_BREACH:
        regions.append(_band(z0, z1) + _slab((1, 0, 0), None, a))
        regions.append(_band(z0, z1) + _slab((1, 0, 0), b, None))
    both(p, lambda bm: kept(bm, regions))
    p.boxes = split_boxes(p.boxes, lambda x, y, z: z < 0.0 or abs(x) > 3.6, 1.2)[0]


def outer_cracked(p):
    # The crown between two cracks has dropped into the arch and turned; the
    # courses over it are down, a notch in the top; the piers lean apart.
    bands = [(-10.0, 12.5), (12.5, 16.0), (16.0, 19.0), (19.0, 30.0)]
    cuts = [[-4.6, -4.4, -3.4, -4.3], [4.5, 4.7, 3.6, 4.1]]
    mats = [_about((-9.6, 0, 0.0), 0.025), Matrix.Translation((0.3, 0.4, -2.4)) @ _about((0, 0, 17.0), 0.14),
            _about((9.6, 0, 0.0), -0.03)]
    both(p, lambda bm: shattered(bm, bands, cuts, 1.4, mats, gone={(3, 1)}, dark=BOLD, stain=STAIN_BOLD, reach=BOLD_R))


OUTER_GAP = [(-10.0, 9.0, -5.9, 5.9), (9.0, 12.5, -5.6, 5.9), (12.5, 16.0, -4.9, 5.4), (16.0, 19.0, -6.2, 5.0),
             (19.0, 30.0, -5.5, 6.4)]


def outer_gapped(p):
    regions = []
    for z0, z1, a, b in OUTER_GAP:
        regions.append(_band(z0, z1) + _slab((1, 0, 0), None, a))
        regions.append(_band(z0, z1) + _slab((1, 0, 0), b, None))
    both(p, lambda bm: kept(bm, regions))
    p.boxes = split_boxes(p.boxes, lambda x, y, z: abs(x) > 5.6, 1.0)[0]


def vault_cracked(p):
    # Cracks along the corridor either side of the crown (y 10.5): the crown's
    # strip sagged, a stretch of it down; the inner wall's side tipped after it.
    bands = [(-12.0, -5.2), (-5.2, -0.6), (-0.6, 4.4), (4.4, 12.0)]
    cuts = [[7.4, 8.5, 7.1, 8.2], [12.8, 13.9, 12.5, 13.6]]

    def mats(k, i):
        if i == 0:
            return Matrix.Identity(4)
        if i == 2:
            return _about((0, 18.5, 20.0), -0.1, "X")
        return Matrix.Translation((0.0, 0.0, -1.5 - 0.4 * (k % 2))) @ _about((0, 10.5, 21.0), 0.1 if k % 2 else -0.08, "X")

    both(p, lambda bm: shattered(bm, bands, cuts, 1.3, mats, gone={(1, 1)}, band_dir=(1, 0, 0), cut_dir=(0, 1, 0), dark=BOLD,
                                 stain=STAIN_BOLD))


# The wall in the arena's inner arch (arena_build.py's IN_R a, SPRING, IN_Y).
BLOCK_R, BLOCK_SPRING, BLOCK_Y, BLOCK_T = 6.5, 8.0, 20.0, 1.8
BLOCK_BANDS = [(-2.0, 3.2), (3.2, 6.3), (6.3, 9.4), (9.4, 12.5), (12.5, 20.0)]
# What is left: the sill's top a stretch of x, then the jambs' stubs.
BLOCK_SILL = [(-7.0, -4.9, 4.2), (-4.9, -2.4, 0.9), (-2.4, 0.6, 0.4), (0.6, 3.1, 0.75), (3.1, 5.2, 0.5), (5.2, 7.0, 2.9)]


def _block_source(name):
    """The whole wall: courses to the arch's soffit (cut round it on its tangents)."""
    p = T.Piece(name, seed=93)
    p.ground = 0.0
    z = -1.0
    while z < BLOCK_SPRING + BLOCK_R:
        p.course(-BLOCK_R - 0.2, BLOCK_R + 0.2, z, 1.55, BLOCK_T, y=BLOCK_Y, length=(1.8, 3.2), chips=2)
        z += 1.55
    planes = _slab((1, 0, 0), -BLOCK_R - 0.05, BLOCK_R + 0.05)
    for k in range(13):
        a = math.pi * (k + 0.5) / 13
        n = Vector((math.cos(a), 0, math.sin(a)))
        planes.append((Vector((0, 0, BLOCK_SPRING)) + n * (BLOCK_R + 0.05), n))
    both(p, lambda bm: kept(bm, [planes], fresh=False))
    for a, b, zt in ((-6.5, -5.2, 11.9), (-5.2, -3.2, 13.6), (-3.2, 3.2, 14.5), (3.2, 5.2, 13.6), (5.2, 6.5, 11.9)):
        p.solid((a, BLOCK_Y - BLOCK_T / 2, -1.0), (b, BLOCK_Y + BLOCK_T / 2, zt))
    return p


def build_block_cracked():
    p = _block_source("arena_block_cracked")
    # Split in three; the middle pushed toward the corridor and sunk, with a
    # hole at mid height and its head under the crown gone.
    cuts = [[-2.6, -1.5, -2.8, -1.7, -2.3], [2.0, 3.1, 1.7, 2.8, 2.2]]
    mats = [_about((-6.5, BLOCK_Y, 0.0), 0.03), Matrix.Translation((0.15, -0.7, -0.5)), _about((6.5, BLOCK_Y, 0.0), -0.035)]
    both(p, lambda bm: shattered(bm, BLOCK_BANDS, cuts, 1.3, mats, gone={(4, 1), (2, 1)}, dark=BOLD, stain=STAIN_BOLD, reach=BOLD_R))
    p.export()


def build_block_holed():
    p = _block_source("arena_block_holed")
    regions = [_slab((1, 0, 0), a, b) + [((0, 0, zt), (0.15 if k % 2 else -0.2, 0, 1))] for k, (a, b, zt) in enumerate(BLOCK_SILL)]
    both(p, lambda bm: kept(bm, regions))
    p.boxes = [((a, BLOCK_Y - BLOCK_T / 2, -1.0), (b, BLOCK_Y + BLOCK_T / 2, zt)) for a, b, zt in BLOCK_SILL]
    p.export()


# The rotunda's stretches that break: name -> (azimuth (degrees from +x toward
# +y, Blender), half width (m)); each from the footing up to SECTION_TOP.
SECTIONS = {"w": (171.0, 7.0), "ne": (38.0, 7.0)}
SECTION_TOP = 20.0
SECTION_BANDS = [(-12.0, 2.0), (2.0, 6.0), (6.0, 10.0), (10.0, 14.0), (14.0, 18.0), (18.0, 21.0)]
# The breach: [(z0, z1, its edges across)].
SECTION_BREACH = [(0.0, 4.0, -5.0, 4.6), (4.0, 8.0, -4.2, 5.2), (8.0, 12.0, -5.1, 4.0), (12.0, 15.0, -3.6, 3.8),
                  (15.0, 17.5, -2.2, 2.4)]


def _section(key):
    """(across, out): the stretch's unit vectors."""
    a = math.radians(SECTIONS[key][0])
    return Vector((-math.sin(a), math.cos(a), 0.0)), Vector((math.cos(a), math.sin(a), 0.0))


def _in_section(key, x, y, z):
    t, r = _section(key)
    return abs(x * t.x + y * t.y) < SECTIONS[key][1] and x * r.x + y * r.y > 0.0 and z < SECTION_TOP


def _section_planes(key):
    t, r = _section(key)
    w = SECTIONS[key][1]
    return _slab(t, -w, w) + _slab(r, 0.0, None) + _slab((0, 0, 1), None, SECTION_TOP)


def rotunda_cut(p):
    def cut(bm):
        first = bm
        for key in SECTIONS:
            t, r = _section(key)
            w = SECTIONS[key][1]
            new = kept(bm, [_slab(r, None, 0.0), _slab(r, 0.0, None) + _slab(t, None, -w), _slab(r, 0.0, None) + _slab(t, w, None),
                            _slab(r, 0.0, None) + _slab(t, -w, w) + _slab((0, 0, 1), SECTION_TOP, None)], fresh=False)
            if bm is not first:
                bm.free()
            bm = new
        return bm

    both(p, cut)
    p.boxes = split_boxes(p.boxes, lambda x, y, z: any(_in_section(k, x, y, z) for k in SECTIONS), 1.5)[1]


def _section_only(p, key):
    planes = _section_planes(key)
    both(p, lambda bm: kept(bm, [planes], fresh=False))
    p.boxes = split_boxes(p.boxes, lambda x, y, z: _in_section(key, x, y, z), 1.5)[0]


def section_cracked(key):
    def fn(p):
        _section_only(p, key)
        t, r = _section(key)
        cuts = [[-2.8, -1.6, -3.0, -1.8, -2.6, -2.0], [2.4, 3.4, 2.0, 3.0, 2.2, 2.8]]
        mats = [Matrix.Translation(r * 0.15), Matrix.Translation(r * 1.1 + Vector((0, 0, -0.6))), Matrix.Translation(r * -0.1)]
        both(p, lambda bm: shattered(bm, SECTION_BANDS, cuts, 1.5, mats, gone={(4, 1)}, cut_dir=t, dark=BOLD, stain=STAIN_BOLD, reach=BOLD_R))
    return fn


def section_holed(key):
    def fn(p):
        _section_only(p, key)
        t, r = _section(key)
        regions = [_slab((0, 0, 1), None, 0.0), _slab((0, 0, 1), 17.5, None)]
        for z0, z1, a, b in SECTION_BREACH:
            regions.append(_band(z0, z1) + _slab(t, None, a))
            regions.append(_band(z0, z1) + _slab(t, b, None))
        both(p, lambda bm: kept(bm, regions))

        def left(x, y, z):
            u = x * t.x + y * t.y
            for z0, z1, a, b in SECTION_BREACH:
                if z0 <= z < z1:
                    return u < a or u > b
            return True
        p.boxes = split_boxes(p.boxes, left, 1.0)[0]
    return fn


# name: (the source's script, its piece, the args that build only that piece, the cut).
VARIANTS = {
    "aqueduct_arch_cracked": ("aqueduct_build.py", "aqueduct_arch", ["--only=aqueduct_arch"], arch_cracked),
    "street_column_cracked": ("column_build.py", "column", [], column_cracked),
    "street_lintel_cross_cracked": ("street_build.py", "street_lintel_cross", ["--only=street_lintel_cross"], beam_cracked),
    "street_lintel_cross_snapped": ("street_build.py", "street_lintel_cross", ["--only=street_lintel_cross"], beam_snapped),
    "agora_stoa_wall_cracked": ("agora_build.py", "agora_stoa_wall", ["--only=agora_stoa_wall"], wall_cracked),
    "agora_stoa_wall_holed": ("agora_build.py", "agora_stoa_wall", ["--only=agora_stoa_wall"], wall_holed),
    "agora_lintel_cracked": ("entablature_build.py", "lintel", ["--only=lintel"], lintel_cracked),
    "agora_altar_cracked": ("agora_build.py", "agora_altar", ["--only=agora_altar"], altar_cracked),
    "agora_altar_smashed": ("agora_build.py", "agora_altar", ["--only=agora_altar"], altar_smashed),
    "lintel_cracked_wide": ("entablature_build.py", "lintel", ["--only=lintel"], lintel_cracked_wide),
    "lintel_snapped": ("entablature_build.py", "lintel", ["--only=lintel"], lintel_snapped),
    "column_cracked_wide": ("column_build.py", "column", [], column_wide),
    "theatre_stage_wall_cracked": ("theatre_build.py", "theatre_stage_wall", ["--only=theatre_stage_wall"], stage_cracked),
    "theatre_stage_wall_holed": ("theatre_build.py", "theatre_stage_wall", ["--only=theatre_stage_wall"], stage_holed),
    "arena_outer_cracked": ("arena_build.py", "arena_outer", ["--only=arena_outer"], outer_cracked),
    "arena_outer_gapped": ("arena_build.py", "arena_outer", ["--only=arena_outer"], outer_gapped),
    "arena_vault_a_cracked": ("arena_build.py", "arena_vault_a", ["--only=arena_vault_a"], vault_cracked),
    "baths_rotunda_cut": ("baths_build.py", "baths_rotunda", ["--only=baths_rotunda"], rotunda_cut),
    "baths_wall_w_cracked": ("baths_build.py", "baths_rotunda", ["--only=baths_rotunda"], section_cracked("w")),
    "baths_wall_w_holed": ("baths_build.py", "baths_rotunda", ["--only=baths_rotunda"], section_holed("w")),
    "baths_wall_ne_cracked": ("baths_build.py", "baths_rotunda", ["--only=baths_rotunda"], section_cracked("ne")),
    "baths_wall_ne_holed": ("baths_build.py", "baths_rotunda", ["--only=baths_rotunda"], section_holed("ne")),
}

# name: its builder, for a piece with no source in another lane's build.
BUILT = {"arena_block_cracked": build_block_cracked, "arena_block_holed": build_block_holed}


def _wanted(name):
    """--only=name, or --only=prefix* for several."""
    return only is None or only == name or (only.endswith("*") and name.startswith(only[:-1]))


def build_variant(name):
    """Runs the source's build with every export caught: the source piece is
    renamed, cut and written as `name`; nothing else is written."""
    script, source, script_args, fn = VARIANTS[name]
    real = T.Piece.export

    def export(self, mid_of=None):
        if self.name != source or mid_of is not None:
            self.near.free()
            self.far.free()
            return
        self.name = name
        fn(self)
        real(self)

    argv = sys.argv
    T.Piece.export = export
    sys.argv = [argv[0], "--"] + script_args
    try:
        runpy.run_path(str(HERE / script), run_name="temple_breaks_source")
    finally:
        T.Piece.export = real
        sys.argv = argv


def build_chunk():
    p = T.Piece("temple_break_chunk", seed=71)
    p.ground = -100.0
    p.block((0, 0, 0), (1.0, 0.8, 0.7), chips=4, chip_depth=(0.2, 0.42), bevel=0.04)
    p.export()


for name in VARIANTS:
    if _wanted(name):
        build_variant(name)
for name in BUILT:
    if _wanted(name):
        BUILT[name]()
if only is None or only == "temple_break_chunk":
    build_chunk()
