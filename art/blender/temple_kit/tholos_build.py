"""The temple kit's tholos (lane tholos): what a ruined round temple needs
that the kit lacks, in the kit's stone (temple_lib). Its columns, fallen
drums and rubble are the kit's own pieces; scripts/endless/tholos_site.gd
lays them all.

    python tools/blender.py run art/blender/temple_kit/tholos_build.py [-- --only=tholos_base]

The ring: N columns on a circle of radius RING (their centres BAY apart
along the chord for N 6), so the gaps between shafts are the kit's 14.5 m.

Pieces (Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y)). Every
piece's origin is the ring's centre on the stylobate (the columns' feet, z 0):
- `tholos_base`: the round stepped base. The stylobate's paving out to
  STYLO (a low round dais in the middle), two steps down round it (the kit's
  STEP_H and STEP_TREAD), a ledge at -PODIUM_H, and under it the retaining
  drum of coursed blocks, DRUM at its top and leaning out a little as it goes
  down to -DEPTH: it stands in a steep ridge's top, so the drum shows on the
  flanks and is buried along the crest.
- `tholos_lintel`: one bay of the ring's entablature, the kit's lintel
  (entablature_build.py's stones) bent to the ring: it spans the 360/N
  degrees centred on +x, its ends over the two columns' centres.
- `tholos_lintel_l`, `tholos_lintel_r`: the same bay at the end of a
  standing run: the frieze's and cornice's last blocks gone at its +y (l)
  or -y (r) end (Godot: its -z or +z end), the architrave left bare there.
"""

import math
import sys
from pathlib import Path

import bmesh
from mathutils import Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

HERE = Path(__file__).resolve().parent


def borrow(fname, stop):
    """Another build script's helpers without running its builds: its source
    up to `stop` (its build calls), run in a namespace of its own."""
    src = (HERE / fname).read_text()
    src = src[:src.index(stop)]
    ns = {"__name__": "tholos_borrowed_" + fname.replace(".py", "")}
    exec(compile(src, str(HERE / fname), "exec"), ns)
    return ns


E = borrow("entablature_build.py", '\nif only in ("", "lintel"):')

N = 6
RING = T.BAY / (2 * math.sin(math.pi / N))      # 18.5: the columns' circle
HALF_A = math.pi / N                            # half a bay's angle
STYLO = RING + 3.4                              # the stylobate's edge
STEP = T.STEP_TREAD
LEDGE = STYLO + 2 * STEP                        # the second step's foot, on the drum's top
DRUM = LEDGE + 1.2                              # the drum's face at its top
BATTER = 0.03                                   # the drum's lean, m out per m down
DRUM_TOP = -T.PODIUM_H
DEPTH = 46.0
DAIS = 4.2
DAIS_H = 0.4
TAU = math.tau


def scratch(p, fn):
    keep = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    try:
        fn()
    finally:
        p.near = keep
    return tmp


def slice_x(bm, xs):
    """Cuts bm's faces along the planes x = each of xs (nothing removed), so
    a long stone has points to bend at."""
    for x in xs:
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((x, 0.0, 0.0)), plane_no=Vector((1.0, 0.0, 0.0)))


def polar_block(p, a, rho, zc, size, **kw):
    """The library's block bent round the axis: its length (x) `size[0]`
    along the circle of radius `rho` centred on angle `a`, its depth (y)
    along the radius (+y outward), centred at height zc. `hide` and `seen`
    name the block's own sides, so +y is its outer face."""
    L = size[0]
    bm = scratch(p, lambda: p.block((0, 0, 0), size, far=False, **kw))
    n = int(L / (rho * 0.13))
    if n > 0:
        slice_x(bm, [-L / 2 + L * (i + 1) / (n + 1) for i in range(n)])
    for v in bm.verts:
        aa = a - v.co.x / rho
        rr = rho + v.co.y
        v.co = Vector((rr * math.cos(aa), rr * math.sin(aa), zc + v.co.z))
    T._append(p.near, bm)
    bm.free()


def ring_course(p, r_in, r_out, z0, h, length, hide, seen, chips=1, lost=None, heave=None, **kw):
    """A course of blocks round the axis between two radii, its foot at z0.
    `lost(a, rho)`: that block is gone. `heave(a, rho)`: (lift, tilt) for a
    block that has moved."""
    r = p.rng
    rho = (r_in + r_out) / 2
    n = max(3, round(TAU * rho / r.uniform(*length)))
    a0 = r.uniform(0, TAU)
    L = TAU * rho / n
    for i in range(n):
        a = a0 + (i + 0.5) * TAU / n
        if lost is not None and lost(a, rho):
            continue
        lift, tilt = heave(a, rho) if heave is not None else (0.0, (0.0, 0.0))
        polar_block(p, a, rho, z0 + h / 2 + lift, (L - T.JOINT, r_out - r_in - T.JOINT, h - T.JOINT),
                    chips=r.randint(0, chips), hide=hide, seen=seen, tilt=tilt, **kw)


def disc(bm, rho, z, kind, tone, segments=48, r_in=0.0, z_in=None):
    """A flat round face looking up (a ring from r_in; a cone with z_in)."""
    tk, tt, _ = T._layers(bm)
    outer = [bm.verts.new((math.cos(TAU * i / segments) * rho, math.sin(TAU * i / segments) * rho, z))
             for i in range(segments)]
    if r_in <= 0.0:
        fs = [bm.faces.new(outer)]
    else:
        zi = z if z_in is None else z_in
        inner = [bm.verts.new((math.cos(TAU * i / segments) * r_in, math.sin(TAU * i / segments) * r_in, zi))
                 for i in range(segments)]
        fs = []
        for i in range(segments):
            j = (i + 1) % segments
            fs.append(bm.faces.new((inner[i], outer[i], outer[j], inner[j])))
    for f in fs:
        f[tk] = kind
        f[tt] = tone


def wall(bm, r0, z0, r1, z1, kind, tone, segments=48):
    """A plain round wall looking out, r0 at z0 (its foot) to r1 at z1."""
    tk, tt, _ = T._layers(bm)
    lo = [bm.verts.new((math.cos(TAU * i / segments) * r0, math.sin(TAU * i / segments) * r0, z0)) for i in range(segments)]
    hi = [bm.verts.new((math.cos(TAU * i / segments) * r1, math.sin(TAU * i / segments) * r1, z1)) for i in range(segments)]
    for i in range(segments):
        j = (i + 1) % segments
        f = bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        f[tk] = kind
        f[tt] = tone


def near_angle(a, b):
    return abs(math.atan2(math.sin(a - b), math.cos(a - b)))


# ---- the base -----------------------------------------------------------------
def build_base(seed):
    p = T.Piece("tholos_base", seed=seed)
    p.ground = -1000.0
    r = p.rng
    TOP_ONLY = dict(hide=("-z", "+x", "-x", "+y", "-y"), seen=("+z",))
    RISER = dict(hide=("-z", "+x", "-x", "-y"), seen=("+z", "+y"))
    FACE_ONLY = dict(hide=("-z", "+z", "+x", "-x", "-y"), seen=("+y",))

    def worn(a, rho):
        """0..1: how far the base has gone here; most on the -x side (Godot's
        west), where the columns fell."""
        n = noise.noise(Vector((math.cos(a) * rho * 0.11 + 3.1, math.sin(a) * rho * 0.11, 0.7)))
        west = max(0.0, 1.0 - near_angle(a, math.pi) / 1.1) * max(0.0, (rho - 9.0) / 12.0)
        return n * 0.5 + 0.5 + 0.45 * west

    def lost_paving(a, rho):
        return worn(a, rho) > 0.82

    def heave(a, rho):
        w = worn(a, rho)
        if w < 0.66:
            return (r.uniform(-0.03, 0.02), (r.uniform(-0.01, 0.01), r.uniform(-0.01, 0.01)))
        t = (w - 0.6) * 0.45
        return (t * 0.5, (r.choice((-1, 1)) * t * r.uniform(0.5, 1.0), r.choice((-1, 1)) * t * r.uniform(0.2, 0.6)))

    # What shows where a slab is gone, and through the open joints.
    disc(p.near, STYLO - 0.3, -0.42, T.JOINTFACE, 0.62)
    # The dais: a round stone and a ring of slabs round it, standing DAIS_H proud.
    p.ring((0, 0, -0.2), [(1.5, 0.0), (1.5, DAIS_H + 0.2 - 0.05), (1.44, DAIS_H + 0.2)], segments=24, chips=2)
    ring_course(p, 1.52, DAIS, -0.3, DAIS_H + 0.3, (2.2, 2.8), chips=2, **RISER)
    # The paving: rings of slabs out to the stylobate's rim.
    edges = [DAIS + (STYLO - 2.4 - DAIS) * i / 6 for i in range(7)]
    for r_in, r_out in zip(edges, edges[1:]):
        ring_course(p, r_in, r_out, -0.6, 0.6, (2.6, 3.6), chips=2, chip_depth=(0.08, 0.3),
                    lost=lost_paving, heave=heave, **TOP_ONLY)
    # The stylobate's rim and the two steps: each a ring whose top and riser show.
    for i in range(3):
        r_out = STYLO + i * STEP
        r_in = r_out - (2.4 if i == 0 else STEP + 0.3)
        ring_course(p, r_in, r_out, -i * T.STEP_H - T.STEP_H, T.STEP_H, (3.2, 4.6), chips=3, chip_depth=(0.12, 0.45),
                    lost=(lambda a, rho, i=i: worn(a, rho) > (0.97 - 0.05 * i)), heave=None, **RISER)
        # Behind a lost step block.
        wall(p.near, r_in + 0.2, -i * T.STEP_H - T.STEP_H, r_in + 0.2, -i * T.STEP_H, T.JOINTFACE, 0.62)
    # The ledge: the drum's top course, standing a little proud of the wall.
    ring_course(p, LEDGE - 0.3, DRUM + 0.25, DRUM_TOP - 1.2, 1.2, (3.6, 5.0), chips=3, chip_depth=(0.15, 0.5), **RISER)
    # The drum: courses down to -DEPTH, leaning out as they go; a few blocks gone.
    z = DRUM_TOP - 1.2
    k = 0
    while z > -DEPTH + 0.01:
        h = min(r.choice((2.0, 2.2, 2.4, 2.6)), z + DEPTH)
        if z - h + DEPTH < 1.2:
            h = z + DEPTH
        face = DRUM + BATTER * (DRUM_TOP - (z - h / 2))
        ring_course(p, face - 1.1, face, z - h, h, (4.0, 6.0), chips=2, chip_depth=(0.12, 0.5),
                    lost=(lambda a, rho, k=k: noise.noise(Vector((a * 9.0, k * 1.7, 4.4))) > 0.62), **FACE_ONLY)
        z -= h
        k += 1
    back0 = DRUM + BATTER * (DRUM_TOP + DEPTH) - 0.8
    wall(p.near, back0, -DEPTH, DRUM - 0.8, DRUM_TOP - 1.2, T.JOINTFACE, 0.62)

    # The far LOD: the drum, the ledge, the steps and the stylobate as plain rounds.
    def far_round(r0, z0, r1, z1, top_in):
        wall(p.far, r0, z0, r1, z1, T.FACE, 1.0, segments=32)
        disc(p.far, r1, z1, T.FACE, 1.0, segments=32, r_in=top_in)

    far_round(DRUM + BATTER * (DEPTH + DRUM_TOP), -DEPTH, DRUM, DRUM_TOP, LEDGE)
    far_round(LEDGE, DRUM_TOP, LEDGE, -2 * T.STEP_H, STYLO + STEP)
    far_round(STYLO + STEP, -2 * T.STEP_H, STYLO + STEP, -T.STEP_H, STYLO)
    far_round(STYLO, -T.STEP_H, STYLO, 0.0, DAIS)
    far_round(DAIS, 0.0, DAIS, DAIS_H, 0.0)

    # The flight's solids: each round as strips along x.
    def strips(rho, z0, z1, n):
        w = 2 * rho / n
        for i in range(n):
            x0 = -rho + i * w
            xm = x0 + w / 2
            half = math.sqrt(max(0.0, rho * rho - xm * xm)) if 0 < i < n - 1 else math.sqrt(rho * rho - (rho - w) ** 2) * 0.72
            p.solid((x0, -half, z0), (x0 + w, half, z1))

    strips(DRUM + BATTER * (DEPTH + DRUM_TOP) * 0.5, -DEPTH, DRUM_TOP, 8)
    strips(STYLO + STEP, DRUM_TOP, -T.STEP_H, 8)
    strips(STYLO, -T.STEP_H, 0.0, 8)
    p.solid((-DAIS * 0.75, -DAIS * 0.75, 0.0), (DAIS * 0.75, DAIS * 0.75, DAIS_H))
    p.export()


# ---- the ring's entablature ---------------------------------------------------
def build_lintel(name, seed, ragged=0, mid=False):
    """entablature_build.py's lintel, stone for stone, then bent to the ring.
    `ragged` (+1 / -1): the frieze and cornice gone at the bay's +y / -y end
    (built at -x, mirrored for -1)."""
    H = E["H"]
    Z0 = E["Z0"]
    D = E["D"]
    Z_FRIEZE, Z_CORNICE = E["Z_FRIEZE"], E["Z_CORNICE"]
    CORNICE_D, CORONA_H, CAP_D, CAP_H = E["CORNICE_D"], E["CORONA_H"], E["CAP_D"], E["CAP_H"]
    p = T.Piece(name, seed=seed)
    if mid:
        p.mid = bmesh.new()
        T._layers(p.mid)
    L = T.BAY - T.JOINT
    for side in (-1, 1):
        E["architrave"](p, side)
        E["slab"](p, (0.0, side * (D - 0.15), Z0 + E["ARCH_H"] + E["TAENIA_H"] / 2), (L, 0.54, E["TAENIA_H"] - T.JOINT * 0.5),
                  bevel=0.04, chips=1, chip_depth=(0.05, 0.1), step=1.2, wobble=0.015,
                  hide=("-y" if side > 0 else "+y", "-z"))
        for xc in E["TRIGLYPHS"]:
            E["regula"](p, xc, side)
    frieze = E["course"](p, -H, H, Z_FRIEZE, T.FRIEZE_H, 2 * E["FRIEZE_D"], length=(2.6, 4.2), chips=2,
                         chip_depth=(0.15, 0.4), drop=(0,) if ragged else ())
    x_from = frieze[0][0]
    for side in (-1, 1):
        for xc in E["TRIGLYPHS"]:
            if xc + 1.0 > x_from:
                E["triglyph"](p, xc, side, x_lo=x_from)
    front = E["course"](p, -H, H, Z_CORNICE, CORONA_H, CORNICE_D - T.JOINT / 2, y=-CORNICE_D / 2,
                        drop=(0, 1, 2) if ragged else (3,), chips=3, chip_depth=(0.2, 0.5), press=("+y",))
    back = E["course"](p, -H, H, Z_CORNICE, CORONA_H, CORNICE_D - T.JOINT / 2, y=CORNICE_D / 2,
                       drop=(0, 1) if ragged else (), chips=3, chip_depth=(0.2, 0.5))

    def gaps(spans):
        g = [(a1, b0) for (a0, a1), (b0, b1) in zip(spans, spans[1:])]
        if spans[0][0] > -H + 1e-6:
            g.append((-H, spans[0][0]))
        return g

    cap_front = E["_cap"](p, -1, gaps(front))
    cap_back = E["_cap"](p, 1, gaps(back), drop=() if ragged else (1,))
    p.far_box((0, 0, Z0 + T.ARCHITRAVE_H / 2), (T.BAY, 2 * D, T.ARCHITRAVE_H))
    p.far_box(((x_from + H) / 2, 0, Z_FRIEZE + T.FRIEZE_H / 2), (H - x_from, 2 * D, T.FRIEZE_H))
    E["far_spans"](p, front, -CORNICE_D / 2, Z_CORNICE, CORONA_H, CORNICE_D)
    E["far_spans"](p, back, CORNICE_D / 2, Z_CORNICE, CORONA_H, CORNICE_D)
    E["far_spans"](p, cap_front, -CAP_D / 2, Z_CORNICE + CORONA_H, CAP_H, CAP_D)
    E["far_spans"](p, cap_back, CAP_D / 2, Z_CORNICE + CORONA_H, CAP_H, CAP_D)
    if mid:
        p.near.free()
        p.near = p.mid
    # Bent: x along the bay becomes the angle (-x toward +angle, which keeps
    # the faces' winding), y the way out from the ring's circle.
    cuts = [-H + T.BAY * i / 8 for i in range(1, 8)]
    for bm in (p.near, p.far):
        if bm is not p.near or mid:
            slice_x(bm, cuts)
        if ragged < 0:
            for v in bm.verts:
                v.co.x = -v.co.x
            bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
        for v in bm.verts:
            a = -v.co.x / H * HALF_A
            rr = RING + v.co.y
            v.co = Vector((rr * math.cos(a), rr * math.sin(a), v.co.z))
    # The flight's solids: the beam in short boxes along its arc.
    parts = 6
    for i in range(parts):
        a0 = -HALF_A + 2 * HALF_A * i / parts
        a1 = a0 + 2 * HALF_A / parts
        pts = [(rr * math.cos(a), rr * math.sin(a)) for a in (a0, a1, (a0 + a1) / 2) for rr in (RING - D, RING + D)]
        lo = (min(q[0] for q in pts), min(q[1] for q in pts), Z0)
        hi = (max(q[0] for q in pts), max(q[1] for q in pts), Z0 + T.ENTABLATURE_H)
        p.solid(lo, hi)
    if mid:
        p.export(mid_of=name)
    else:
        p.export()


JOBS = {
    "tholos_base": lambda: build_base(61),
    "tholos_lintel": lambda: (build_lintel("tholos_lintel", 62), build_lintel("tholos_lintel", 62, mid=True)),
    "tholos_lintel_l": lambda: (build_lintel("tholos_lintel_l", 63, ragged=1),
                                build_lintel("tholos_lintel_l", 63, ragged=1, mid=True)),
    "tholos_lintel_r": lambda: (build_lintel("tholos_lintel_r", 64, ragged=-1),
                                build_lintel("tholos_lintel_r", 64, ragged=-1, mid=True)),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
