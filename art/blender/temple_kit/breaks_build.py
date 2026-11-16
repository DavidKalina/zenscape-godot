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


def _cut(bm, co, no, fresh):
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
            f[tone] = DARK


def _part(bm, planes, fresh):
    """A copy of bm cut back by every plane in `planes` ((co, no): what `no`
    points to goes)."""
    part = bm.copy()
    for co, no in planes:
        _cut(part, co, no, fresh)
    return part


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


def _stain(bm, near):
    """Darkens bm's faces by how near the crack each is (`near`: a face's
    middle -> m)."""
    kind, tone, broke = T._layers(bm)
    for f in bm.faces:
        k = min(1.0, near(f.calc_center_median()) / STAIN_R)
        f[tone] = f[tone] * (STAIN + (1.0 - STAIN) * k)


def shattered(bm, bands, cuts, gap, mats, gone=()):
    """bm split along zigzag cracks: `bands` [(z0, z1)], `cuts` one list of
    x a crack (its place in each band), each a gap `gap` wide and dark, the
    stone by it stained; the pieces between them, -x to +x, placed by `mats`.
    `gone`: (band, piece) pairs left out (stone already fallen)."""
    out = _new()
    for k, (z0, z1) in enumerate(bands):
        zm = (z0 + z1) / 2
        xs = [c[k] for c in cuts]
        for i in range(len(cuts) + 1):
            if (k, i) in gone:
                continue
            planes = _band(z0, z1)
            if i > 0:
                planes.append(((xs[i - 1] + gap / 2, 0, zm), (-1, 0, 0)))
            if i < len(cuts):
                planes.append(((xs[i] - gap / 2, 0, zm), (1, 0, 0)))
            part = _part(bm, planes, False)
            _stain(part, lambda c: min(abs(c.x - x) for x in xs) - gap / 2)
            T._append(out, part, mats[i])
            part.free()
    return out


def cracked(bm, bands, gap, m_neg, m_pos):
    """One crack: `bands` [(z0, z1, x)]."""
    return shattered(bm, [(z0, z1) for z0, z1, _ in bands], [[x for _, _, x in bands]], gap, [m_neg, m_pos])


def kept(bm, regions):
    """bm cut back to `regions`, each a list of planes (what a plane's
    normal points to goes), the cuts fresh breaks."""
    out = _new()
    for planes in regions:
        part = _part(bm, planes, True)
        T._append(out, part)
        part.free()
    return out


def slipped(bm, cuts, gap, slide, lean):
    """A column cut on the slant at each of `cuts` ((height, normal)), every
    part above a cut slid `slide` m down the cut's slope and leaned `lean`
    rad that way, on top of what the parts under it did."""
    out = _new()
    rest = bm
    m = Matrix.Identity(4)
    for z, no in cuts:
        n = Vector(no).normalized()
        low = _part(rest, [((0, 0, z - gap / 2), n)], False)
        top = _part(rest, [((0, 0, z + gap / 2), -n)], False)
        for part in (low, top):
            _stain(part, lambda c: (abs((c - Vector((0, 0, z))).dot(n)) - gap / 2) * 0.7)
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
}


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
    if only is None or only == name:
        build_variant(name)
if only is None or only == "temple_break_chunk":
    build_chunk()
