"""The colonnaded street's own pieces (lane street), in the temple kit's
stone (temple_lib). scripts/endless/street_site.gd lays them with the kit's
column, lintel, column_broken and column_drums scaled to the street's
order (S = 0.72 of the temple's).

    python tools/blender.py run art/blender/temple_kit/street_build.py [-- --only=street_arch]

Frame (Blender, z up): the street runs along x, its rows at y = +-ROW.
Every origin is on the stylobate's top (the columns' foot), at the
piece's middle, except the paving and the kerb, whose origin is on the
ground (the kerb's top KERB_H over it, the paving's PAVE_H).

World metres (laid unscaled), but `street_stump`, which is in the
temple's units like the column it is left of (laid at S).

- `street_kerb`: one bay (SEG along x) of a row's stylobate: a course of
  long blocks KERB_W wide, KERB_H proud, sunk to -KERB_DEEP.
- `street_paving`, `street_paving_broken`: one bay of the way between the
  kerbs (2*HALF_CLEAR across): slabs in running courses, a few gone; the
  broken one lost about half, the rest sunk and tipped.
- `street_arch`: an arch across the way: a pier on each stylobate, a ring
  of voussoirs springing at SPRING, the opening 2*HALF_CLEAR wide,
  CROWN clear at the middle.
- `street_lintel_cross`: a beam across the way from column to column,
  resting on their abaci (its underside at COL_TOP).
- `street_stump`: a column snapped off low: base, one drum and the split
  stub of the next (temple units).
"""

import math
import sys

import bmesh
from mathutils import Matrix, Vector

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

# The column lane's helpers (drum_bm, shatter, its Piece) without running
# its builds: it reads --only from argv when imported.
_argv = sys.argv
sys.argv = [_argv[0], "--", "--only=__none__"]
import columns_build as C  # noqa: E402
sys.argv = _argv

S = 0.72                        # the street's order against the temple's
SEG = T.BAY * S                 # 13.32: column centre to centre along a row
HALF_CLEAR = 8.0                # the way's clear half width (plinth to plinth)
ROW = HALF_CLEAR + T.PLINTH * S / 2     # 9.8: a row's column centres
KERB_W = 3.8                    # inner face at HALF_CLEAR - 0.05
KERB_H = 0.55
KERB_DEEP = 1.2
PAVE_H = 0.25
PAVE_DEEP = 0.7
COL_TOP = T.COLUMN_H * S        # 21.96 over the stylobate

# The arch across the way.
A_R = HALF_CLEAR                # 8.0, the intrados
A_RING = 1.2
A_RE = A_R + A_RING
A_SPRING = 9.0                  # over the stylobate
A_CROWN = A_SPRING + A_R        # 17.0 clear at the middle
A_THICK = 3.4                   # along the street
A_PIER = KERB_W                 # across, the stylobate's width
A_IMPOST = 0.6
A_VOUSS = 15
A_COURSES = 6
A_TOP = A_SPRING + A_RE + 0.4   # the spandrels' top
A_CORNICE = 0.8
A_PIER_COURSE = 1.3


def course_run(p, x0, x1, z, h, depth, y=0.0, length=(2.2, 3.6), chips=1, end_chips=None, hide=()):
    """Blocks along x from x0 to x1 (no far box), open joints."""
    r = p.rng
    x = x0
    while x < x1 - 0.3:
        L = min(r.uniform(*length), x1 - x)
        if x1 - (x + L) < 0.9:
            L = x1 - x
        last = x + L >= x1 - 1e-6
        c = end_chips if (last and end_chips is not None) else r.randint(0, chips)
        p.block((x + L / 2, y + r.uniform(-0.03, 0.03), z + h / 2), (L - T.JOINT, depth, h - T.JOINT),
                chips=c, far=False, hide=hide)
        x += L


# ---- the kerb ----------------------------------------------------------------
def build_kerb(seed):
    p = C.Piece("street_kerb", seed=seed)
    r = p.rng
    x = -SEG / 2
    while x < SEG / 2 - 0.3:
        L = min(r.uniform(2.2, 3.6), SEG / 2 - x)
        if SEG / 2 - (x + L) < 1.0:
            L = SEG / 2 - x
        # Each block a little off true: settled, not laid by a machine.
        dz = r.uniform(-0.06, 0.04)
        p.block((x + L / 2, r.uniform(-0.05, 0.05), (KERB_H - KERB_DEEP) / 2 + dz),
                (L - T.JOINT * 2, KERB_W, KERB_H + KERB_DEEP), yaw=r.uniform(-0.008, 0.008),
                chips=r.randint(1, 3), chip_depth=(0.12, 0.4), far=False, hide=("-z",))
        x += L
    p.far_box((0, 0, (KERB_H - KERB_DEEP) / 2), (SEG, KERB_W, KERB_H + KERB_DEEP))
    p.export()


# ---- the paving ----------------------------------------------------------------
def build_paving(name, seed, lose, tip):
    """Slabs in courses across the way, each course its own width, the
    slabs' joints staggered. `lose`: the share gone (in patches); `tip`:
    how far the rest are sunk and tipped."""
    p = C.Piece(name, seed=seed)
    r = p.rng
    ph = r.uniform(0, 100)
    y = -HALF_CLEAR + 0.05
    while y < HALF_CLEAR - 0.35:
        W = min(r.uniform(1.4, 2.3), HALF_CLEAR - 0.05 - y)
        if HALF_CLEAR - 0.05 - (y + W) < 0.8:
            W = HALF_CLEAR - 0.05 - y
        x = -SEG / 2 + r.uniform(-1.2, 0.0)
        while x < SEG / 2 - 0.2:
            L = r.uniform(1.6, 3.0)
            a, b = max(x, -SEG / 2), min(x + L, SEG / 2)
            x += L
            if b - a < 0.5:
                continue
            cx, cy = (a + b) / 2, y + W / 2
            # Patches, not salt: a slow noise decides where the paving went.
            gone = (math.sin(cx * 0.31 + ph) + math.sin(cy * 0.47 + ph * 1.7) + math.sin((cx + cy) * 0.23)) / 3
            if gone > 1.0 - 2.0 * lose + r.uniform(-0.25, 0.25):
                continue
            sink = r.uniform(0.0, 0.18) * tip
            p.block((cx, cy, PAVE_H - (PAVE_H + PAVE_DEEP) / 2 - sink + r.uniform(-0.03, 0.03)),
                    (b - a - T.JOINT * 2, W - T.JOINT * 2, PAVE_H + PAVE_DEEP),
                    yaw=r.uniform(-0.02, 0.02) * (1 + tip * 3),
                    tilt=(r.uniform(-0.015, 0.015) * (1 + tip * 4), r.uniform(-0.015, 0.015) * (1 + tip * 4)),
                    chips=r.randint(0, 2) + (1 if tip > 0.5 else 0), chip_depth=(0.1, 0.35), far=False,
                    hide=("-z",))
        y += W
    p.far_box((0, 0, (PAVE_H - PAVE_DEEP) / 2), (SEG, 2 * HALF_CLEAR, PAVE_H + PAVE_DEEP))
    p.export()


# ---- the arch across the way ------------------------------------------------
def wedge(p, theta, depth, chips):
    """One voussoir of the arch (the aqueduct's, sized for the street)."""
    rm = A_R + A_RING / 2
    tang = rm * math.pi / A_VOUSS - T.JOINT
    real = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    p.block((0, 0, 0), (A_RING - 0.02, depth, tang), chips=chips, far=False, chip_depth=(0.08, 0.3))
    p.near = real
    for v in tmp.verts:
        v.co.z *= (rm + v.co.x) / rm
    m = Matrix.Translation((rm * math.cos(theta), 0.0, A_SPRING + rm * math.sin(theta))) @ Matrix.Rotation(-theta, 4, "Y")
    T._append(real, tmp, m)
    tmp.free()


def ext_half(zt):
    d = zt - A_SPRING
    return math.sqrt(max(0.0, A_RE * A_RE - d * d))


def intra_z(x):
    return A_SPRING + math.sqrt(max(0.0, A_R * A_R - x * x))


def build_arch(seed):
    """Spans along Blender x (the layout turns it across the way)."""
    p = C.Piece("street_arch", seed=seed)
    p.ground = -KERB_H
    r = p.rng
    hy = A_THICK / 2
    x_in, x_out = A_R, A_R + A_PIER
    for s in (-1, 1):
        # The pier: coursed, two blocks a course, the split turning.
        n = round((A_SPRING - A_IMPOST + KERB_H) / A_PIER_COURSE)
        h = (A_SPRING - A_IMPOST + KERB_H) / n
        for k in range(n):
            zb = -KERB_H + k * h
            if k % 2 == 0:
                cut = r.uniform(-0.5, 0.5)
                xm = s * (x_in + x_out) / 2 + cut
                blocks = [(((s * x_in + xm) / 2, 0, zb + h / 2), (abs(xm - s * x_in) - T.JOINT, A_THICK - T.JOINT, h - T.JOINT)),
                          (((s * x_out + xm) / 2, 0, zb + h / 2), (abs(s * x_out - xm) - T.JOINT, A_THICK - T.JOINT, h - T.JOINT))]
            else:
                cut = r.uniform(-0.3, 0.3)
                blocks = [((s * (x_in + x_out) / 2, (-hy + cut) / 2, zb + h / 2), (A_PIER - T.JOINT, hy + cut - T.JOINT, h - T.JOINT)),
                          ((s * (x_in + x_out) / 2, (hy + cut) / 2, zb + h / 2), (A_PIER - T.JOINT, hy - cut - T.JOINT, h - T.JOINT))]
            for c, sz in blocks:
                p.block(c, sz, chips=r.randint(0, 2), far=False, hide=("-z",) if k == 0 else ())
        # The impost band the ring springs from.
        p.block((s * (x_in + x_out) / 2, 0, A_SPRING - A_IMPOST / 2), (A_PIER + 0.4, A_THICK + 0.4, A_IMPOST),
                chips=2, far=False)
        p.far_box((s * (x_in + x_out) / 2, 0, (A_SPRING - KERB_H) / 2), (A_PIER, A_THICK, A_SPRING + KERB_H))
        p.solid((min(s * x_in, s * x_out), -hy, -KERB_H), (max(s * x_in, s * x_out), hy, A_SPRING))
        # Over the impost the pier carries on as the spandrel's end.
        course_run(p, min(s * x_in, s * x_out), max(s * x_in, s * x_out), A_SPRING, A_TOP - A_SPRING, A_THICK,
                   length=(1.4, 2.4))
    for i in range(A_VOUSS):
        th = math.pi * (i + 0.5) / A_VOUSS
        # The keystone a little proud and the ring's stones weathered unevenly.
        wedge(p, th, A_THICK - 0.04 + (0.25 if i == A_VOUSS // 2 else 0.0), chips=r.randint(0, 2))
    cour = (A_TOP - A_SPRING) / A_COURSES
    for k in range(A_COURSES):
        zb = A_SPRING + k * cour
        w = ext_half(zb + cour)
        if w <= 0.05:
            course_run(p, -A_R, A_R, zb, cour, A_THICK - 0.1, length=(1.4, 2.6))
            continue
        if w < A_R - 0.4:
            course_run(p, -A_R, -w, zb, cour, A_THICK - 0.1, length=(1.2, 2.4))
            course_run(p, w, A_R, zb, cour, A_THICK - 0.1, length=(1.2, 2.4))
    # The cornice, broken short at one end (a weathered top, not a ruler).
    x_end = x_out - r.uniform(1.0, 3.0)
    course_run(p, -x_out + 0.3, x_end, A_TOP, A_CORNICE, A_THICK + 0.6, length=(1.8, 3.0), chips=2, end_chips=3)
    # Far LOD and solids: the soffit in steps, the band over it.
    xs = [A_R * math.cos(math.radians(a)) for a in range(0, 91, 15)]
    for k in range(len(xs) - 1):
        a, b = xs[k + 1], xs[k]
        z = intra_z(b)
        for lo, hi in ((a, b), (-b, -a)):
            p.far_box(((lo + hi) / 2, 0, (z + A_TOP) / 2), (hi - lo, A_THICK, A_TOP - z))
            p.solid((lo, -hy, z), (hi, hy, A_TOP))
    for s in (-1, 1):
        p.far_box((s * (x_in + x_out) / 2, 0, (A_SPRING + A_TOP) / 2), (A_PIER, A_THICK, A_TOP - A_SPRING))
        p.solid((min(s * x_in, s * x_out), -hy, A_SPRING), (max(s * x_in, s * x_out), hy, A_TOP))
    p.far_box(((x_end - x_out + 0.3) / 2, 0, A_TOP + A_CORNICE / 2), (x_end + x_out - 0.3, A_THICK + 0.6, A_CORNICE))
    p.solid((-x_out, -hy - 0.3, A_TOP), (x_end, hy + 0.3, A_TOP + A_CORNICE))
    p.export()


# ---- the beam across the way -------------------------------------------------
def build_lintel_cross(seed):
    """Across Blender x, from the -x row's abacus to the +x one's."""
    p = C.Piece("street_lintel_cross", seed=seed)
    p.ground = -40.0
    r = p.rng
    half = ROW + T.ABACUS * S / 2
    arch_h, depth = 2.3, 2.9
    # Three long stones meeting over the way, each set a little off.
    joints = [-half, -half / 3 + r.uniform(-0.6, 0.6), half / 3 + r.uniform(-0.6, 0.6), half]
    for k in range(3):
        a, b = joints[k], joints[k + 1]
        p.block(((a + b) / 2, r.uniform(-0.05, 0.05), COL_TOP + arch_h / 2 + r.uniform(-0.03, 0.02)),
                (b - a - T.JOINT * 2, depth, arch_h - T.JOINT), yaw=r.uniform(-0.01, 0.01),
                chips=r.randint(2, 4), chip_depth=(0.15, 0.45), far=False)
    # A fascia step along its face and a worn crown course, short.
    course_run(p, -half + 0.4, half - r.uniform(0.6, 2.5), COL_TOP + arch_h, 0.7, depth + 0.5,
               length=(2.4, 4.0), chips=2, end_chips=3)
    p.far_box((0, 0, COL_TOP + (arch_h + 0.7) / 2), (2 * half, depth + 0.3, arch_h + 0.7))
    p.solid((-half, -depth / 2 - 0.25, COL_TOP), (half, depth / 2 + 0.25, COL_TOP + arch_h + 0.7))
    p.export()


# ---- a low stump ---------------------------------------------------------------
def build_stump(seed):
    """A column snapped off low (temple units: laid at S)."""
    p = C.Piece("street_stump", seed=seed)
    r = p.rng
    p.block((0, 0, T.PLINTH_H / 2), (T.PLINTH, T.PLINTH, T.PLINTH_H), bevel=0.09, chips=3, chip_depth=(0.2, 0.5))
    p.ring((0, 0, T.PLINTH_H), [(C.R_FOOT + 0.15, 0.0), (C.R_FOOT + 0.38, 0.12), (C.R_FOOT + 0.45, 0.3),
                                (C.R_FOOT + 0.38, 0.48), (C.R_FOOT + 0.05, T.TORUS_H)], segments=C.SEG, chips=2,
           bite=(0.12, 0.3), caps=(False, True))
    z = T.BASE_H
    bm = C.drum_bm(p, 0, chips=2, caps=(False, True))
    T._append(p.near, bm, Matrix.Translation((0, 0, z)))
    bm.free()
    z += T.DRUM_H
    # The next drum split across, high on one side, low on the other.
    bm = C.drum_bm(p, 1, chips=1, yaw=1.1)
    C.shatter(p, bm, [((0, 0, 1.0), (0.3, 0.1, 1.0)), ((-0.6, 0, 1.7), (0.5, -0.2, 1.0))], rough=0.24)
    T._append(p.near, bm, Matrix.Translation((0.12, 0.05, z)) @ Matrix.Rotation(0.02, 4, "X"))
    bm.free()
    for k in range(4):
        a_ = r.uniform(0, math.tau)
        d = r.uniform(3.0, 4.6)
        s = r.uniform(0.35, 0.75)
        C.spall(p, (math.cos(a_) * d, math.sin(a_) * d, s * 0.3), (s * 1.3, s, s * 0.7), r.uniform(0, 3),
                (r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)))
    p.far_box((0, 0, T.PLINTH_H / 2), (T.PLINTH, T.PLINTH, T.PLINTH_H))
    p.far_cylinder((0, 0, T.PLINTH_H), T.TORUS_H + T.DRUM_H + 1.3, C.R_FOOT + 0.1, C.radius_at(1.5), segments=12)
    h = T.PLINTH / 2
    p.solid((-h, -h, 0.0), (h, h, T.BASE_H))
    s = C.R_FOOT * 0.9
    p.solid((-s, -s, T.BASE_H), (s, s, z + 1.2))
    p.export()


JOBS = {
    "street_kerb": lambda: build_kerb(51),
    "street_paving": lambda: build_paving("street_paving", 52, lose=0.07, tip=0.15),
    "street_paving_broken": lambda: build_paving("street_paving_broken", 53, lose=0.45, tip=1.0),
    "street_arch": lambda: build_arch(54),
    "street_lintel_cross": lambda: build_lintel_cross(55),
    "street_stump": lambda: build_stump(56),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
