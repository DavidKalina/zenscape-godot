"""The lighthouse on Light Rock, in the temple kit's stone (temple_lib).

    python tools/blender.py run art/blender/coast/lighthouse_build.py [-- --seed=N]

Writes assets/models/lighthouse_stone.glb and lighthouse_stone.boxes.json
(the flight's solids, Godot frame, as temple_lib writes them). The old
model (coast_build.py, lighthouse.glb) stays for `--lighthouse=old`.

A tapering tower of big coursed stone with open joints, limewashed in
bands of white and red that have flaked to the stone in places; a square
stepped plinth with a stair to the door; small deep windows up the shaft;
a corbelled gallery with an iron rail; a glazed lantern with an iron frame
and a verdigris cap and vent; a low limewashed keeper's house with a slate
roof against the tower's west side.

Frame (Blender, z up): origin on the rock under the tower's axis, the door
facing -y (Godot +z), the house on -x. The lamp at z = LAMP
(scripts/endless/coast_sites.gd LAMP_Y). Godot (x, y, z) = Blender (x, z, -y).

The glb holds four meshes: `lighthouse_stone` (near, the kit's stone
shader, its paint in the vertex colours), `lighthouse_stone_far` (far LOD,
the same shader), `lighthouse_iron` and `lighthouse_glass` (near only, their
own small materials in coast_sites.gd). Colour is per vertex, linear.
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "temple_kit"))
import temple_lib as T  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SEED = next((int(a.split("=")[1]) for a in args if a.startswith("--seed=")), 11)

NAME = "lighthouse_stone"
OUT = T.ROOT / "assets" / "models"
LAMP = 50.0

# ---- The shape (metres, Blender frame) -----------------------------------
PLINTH_TOP = 3.2           # the paving round the tower's foot; the door's sill
PLINTH_HALF = 10.6         # the plinth's top course, half its side
SHAFT_TOP = 43.6           # where the corbels start
R_FOOT = 9.0               # the shaft's radius at the plinth
R_TOP = 6.1                # at the corbels
CORBEL_H = 0.8
CORBELS = 3                # tiers, each 0.7 m further out
DECK_Z = SHAFT_TOP + CORBEL_H * CORBELS     # 46.0, the gallery slab's foot
DECK_T = 0.6
DECK_TOP = DECK_Z + DECK_T                  # 46.6
DECK_R = 8.4
RAIL_R = 8.05
RAIL_H = 1.15
LANTERN_R = 3.7
LANTERN_WALL = DECK_TOP + 1.2               # 47.8: the stone drum under the glass
GLASS_TOP = 52.4
CAP_TOP = 55.0
DOOR_A = -math.pi / 2      # the door faces -y
DOOR_W = 1.8
DOOR_H = 3.4
BLOCK_DEPTH = 0.16         # how far a face block's chamfer runs back into the joint

# Colour coats (sRGB): limewash and the red, both old.
LIME = (0.95, 0.94, 0.90)
RED = (0.50, 0.23, 0.18)
CORE = (0.20, 0.18, 0.16)      # deep in a joint, the dark behind a window
WOOD = (0.24, 0.17, 0.11)      # the door, old tarred boards
SLATE = (0.30, 0.31, 0.33)
IRON = (0.085, 0.085, 0.08)
RUST = (0.32, 0.17, 0.09)
VERDIGRIS = (0.33, 0.50, 0.42)
GLASS = (0.20, 0.25, 0.27)

# Face kinds beyond temple_lib's FACE, JOINTFACE, BROKEN.
K_CORE, K_SLATE, K_WOOD, K_DARK = 20, 21, 22, 23


def r_at(z):
    """The shaft's radius at height z: a taper drawn in at the waist."""
    t = max(0.0, min(1.0, (z - PLINTH_TOP) / (SHAFT_TOP - PLINTH_TOP)))
    return R_FOOT - (R_FOOT - R_TOP) * (1.25 * t - 0.25 * t * t * t)


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# The shaft's courses, bottom up: taller low, finer high.
COURSES = []
_z = PLINTH_TOP
while _z < SHAFT_TOP - 0.5:
    h = 1.72 - 0.42 * (_z - PLINTH_TOP) / (SHAFT_TOP - PLINTH_TOP)
    h = min(h, SHAFT_TOP - _z)
    if SHAFT_TOP - (_z + h) < 0.6:
        h = SHAFT_TOP - _z
    COURSES.append((_z, h))
    _z += h

# The bands: course index ranges painted red (the rest limewash), snapped to
# course joints so a band's edge follows the stones.
def _band_edges():
    want = [(10.5, 16.5), (22.5, 28.5), (34.0, 39.5)]
    edges = []
    for lo, hi in want:
        a = min(range(len(COURSES)), key=lambda i: abs(COURSES[i][0] - lo))
        b = min(range(len(COURSES)), key=lambda i: abs(COURSES[i][0] - hi))
        edges.append((COURSES[a][0], COURSES[b][0]))
    return edges


RED_BANDS = _band_edges()


def coat_at(p):
    """Which coat a point of the tower or house wears: None (bare stone),
    LIME or RED."""
    x, y, z = p
    rr = math.hypot(x, y)
    if x < -7.2 and z < 9.5 and z > -0.4 and rr > 7.0:
        return LIME                                # the keeper's house
    if PLINTH_TOP - 0.05 < z < DECK_TOP + 0.05 and rr < DECK_R + 0.3:
        for lo, hi in RED_BANDS:
            if lo - 0.02 < z < hi + 0.02:
                return RED
        return LIME
    return None


class Light(T.Piece):
    """A Piece whose paint lays the old limewash and red over the stone and
    knows the lighthouse's own kinds (core, slate, wood, dark)."""

    def paint(self, bm, far=False):
        bm.normal_update()
        kind, tone, broke = T._layers(bm)
        col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        for f in bm.faces:
            k = f[kind]
            t = f[tone]
            nz = f.normal.z
            fc = f.calc_center_median()
            for loop in f.loops:
                v = loop.vert
                p = v.co
                h = p.z - self.ground
                if k == K_CORE:
                    # Deep in a joint; where the tower is washed, the wash
                    # has run into the joint too, so the courses read
                    # without every stone ringed in black.
                    coat = coat_at(fc)
                    c = CORE if coat is None else T.mix(CORE, tuple(x * 0.62 for x in coat), 0.7)
                    loop[col] = T.srgb_to_linear(c) + (1.0,)
                    continue
                if k == K_DARK:
                    loop[col] = T.srgb_to_linear(tuple(c * 0.45 for c in CORE)) + (1.0,)
                    continue
                if k == K_WOOD:
                    g = noise.noise(Vector((p.x * 3.0, p.y * 3.0, p.z * 0.3))) * 0.5 + 0.5
                    c = T.mix(WOOD, (0.36, 0.30, 0.22), 0.4 * g)
                    loop[col] = T.srgb_to_linear(c) + (1.0,)
                    continue
                if k == K_SLATE:
                    c = tuple(x * t for x in SLATE)
                    m = noise.noise(Vector((p.x * 0.7, p.y * 0.7, p.z * 0.7 + 3.0))) * 0.5 + 0.5
                    c = T.mix(c, (0.62, 0.62, 0.52), 0.45 * max(0.0, m - 0.45) / 0.55)  # lichen
                    c = T.mix(c, T.MOSS, 0.5 * max(0.0, m - 0.7) / 0.3)
                    loop[col] = T.srgb_to_linear(c) + (1.0,)
                    continue
                if far and fc.z > DECK_TOP + 0.05 and math.hypot(fc.x, fc.y) < LANTERN_R + 0.6:
                    c = VERDIGRIS if fc.z > GLASS_TOP + 0.3 else (GLASS if fc.z > LANTERN_WALL + 0.1 else T.STONE)
                    loop[col] = T.srgb_to_linear(c) + (1.0,)
                    continue
                if far and fc.z > 5.4 and fc.x < -7.4 and fc.z < 9.5:
                    loop[col] = T.srgb_to_linear(SLATE) + (1.0,)
                    continue
                c = tuple(x * t for x in T.STONE)
                if k == T.JOINTFACE and not far:
                    c = T.mix(c, T.CREVICE, 0.35 if nz < 0.5 else 0.15)
                fresh = v[broke] if not far else 0.0
                if not far:
                    c = T.mix(c, T.STONE_FRESH, 0.75 * fresh)
                # The coat: limewash or red, gone in flakes to the stone.
                coat = coat_at(fc)
                if coat is not None and nz < 0.6:
                    flake = (noise.noise(Vector((p.x * 0.33, p.y * 0.33, p.z * 0.45 + 7.0))) * 0.6
                             + noise.noise(Vector((p.x * 1.4, p.y * 1.4, p.z * 1.6 + 2.0))) * 0.4)
                    # More gone low (spray and boots) and on the red.
                    lose = 0.2 + 0.2 * (1.0 - smooth(PLINTH_TOP, 14.0, p.z)) + (0.08 if coat is RED else 0.0)
                    keep = smooth(lose - 0.08, lose + 0.12, flake * 0.5 + 0.5 - 0.15) * (1.0 - fresh)
                    # Per block: its own wash, a little thinner or thicker.
                    shade = 0.9 + 0.12 * (t - 0.97) / 0.11
                    wash = tuple(x * shade for x in coat)
                    if coat is RED:
                        # Faded: the red chalky and pinked where the sun has had it.
                        fade = noise.noise(Vector((p.x * 0.12, p.y * 0.12, p.z * 0.2 + 1.0))) * 0.5 + 0.5
                        wash = T.mix(wash, (0.62, 0.43, 0.37), 0.5 * fade)
                    if k == T.JOINTFACE:
                        keep *= 0.55
                    if far:
                        keep = 0.78
                    c = T.mix(c, wash, 0.92 * keep)
                # Rain streaks: long vertical runs, darker under ledges.
                streak = noise.noise(Vector((p.x * 0.9, p.y * 0.9, p.z * 0.08)))
                streak = max(0.0, streak) * (1.0 - max(0.0, nz))
                c = T.mix(c, T.STAIN, 0.42 * streak)
                # Run-off under the gallery: rust and soot from the iron.
                if p.z < SHAFT_TOP and nz < 0.5:
                    a = math.atan2(p.y, p.x)
                    run = max(0.0, noise.noise(Vector((math.cos(a) * 4.0, math.sin(a) * 4.0, 0.3))))
                    run *= smooth(SHAFT_TOP - 16.0, SHAFT_TOP, p.z)
                    c = T.mix(c, (0.40, 0.30, 0.22), 0.55 * run)
                blot = noise.noise(Vector((p.x * 0.18 + 11.0, p.y * 0.18, p.z * 0.18)))
                c = tuple(x * (1.0 + 0.08 * blot) for x in c)
                # Damp at the foot.
                c = T.mix(c, T.GROUND_DAMP, 0.6 * max(0.0, 1.0 - h / 1.2))
                m = noise.noise(Vector((p.x * 0.6, p.y * 0.6, p.z * 0.6 + 5.0))) * 0.5 + 0.5
                up = max(0.0, nz - 0.45) / 0.55
                low = max(0.0, 1.0 - h / 1.4)
                moss = max(up * (0.3 + 0.6 * m), low * m * 0.7)
                moss = max(0.0, min(1.0, (moss - 0.4) * 1.6))
                c = T.mix(c, T.MOSS, moss * (0.75 if not far else 0.5))
                loop[col] = T.srgb_to_linear(c) + (1.0,)
        return col


p = Light(NAME, seed=SEED)
rng = p.rng
p.ground = 0.6


def new_layers(bm):
    return T._layers(bm)


# ---- The shaft's face stones ----------------------------------------------
def face_stone(a0, a1, z0, z1, segs=None, proud=0.0, chips=0):
    """One face stone of a round course: its outer face from angle a0 to a1
    and z0 to z1, following the taper, pillowed a little proud in the
    middle, its arrises chamfered back into an open joint. Only the face
    and its chamfers are built: the joint shows the dark core behind."""
    bm = p.near
    kind, tone, broke = new_layers(bm)
    t = p.tone()
    span = (a1 - a0) * r_at(z0)
    segs = segs or max(2, int(round(span / 0.9)))
    ch = rng.uniform(0.05, 0.1)      # the chamfer, at the face
    j = T.JOINT / 2
    # Corners knocked off: (i-end 0/1, top 0/1, depth).
    bites = []
    for _ in range(chips):
        bites.append((rng.randrange(2), rng.randrange(2), rng.uniform(0.05, 0.14)))

    def at(a, z, inset, out=0.0):
        rad = r_at(z) - inset + out
        return Vector((math.cos(a) * rad, math.sin(a) * rad, z))

    # The face grid: columns along the arc, rows 0..2 up (middle pillowed).
    da = (j + ch) / r_at(z0)
    angs = [a0 + da + (a1 - a0 - 2 * da) * i / segs for i in range(segs + 1)]
    zs = [z0 + j + ch, (z0 + z1) / 2, z1 - j - ch]
    grid = []
    for ri, z in enumerate(zs):
        row = []
        for ci, a in enumerate(angs):
            pillow = 0.0
            if ri == 1 and 0 < ci < segs:
                pillow = 0.025 + 0.03 * rng.random()
            nz = noise.noise(Vector((math.cos(a) * 4.0, math.sin(a) * 4.0, z * 2.0))) * 0.015
            co = at(a, z, 0.0, proud + pillow + nz)
            bv = 0.0
            for (end, top, d) in bites:
                ce = 0 if end == 0 else segs
                cz = 0 if top == 0 else 2
                w = max(0.0, 1.0 - (abs(ci - ce) / max(1, segs * 0.5) + abs(ri - cz) / 2.0))
                if w > 0.0:
                    co -= Vector((math.cos(a), math.sin(a), 0.0)) * d * w
                    bv = max(bv, w)
            v = bm.verts.new(co)
            v[broke] = bv
            row.append(v)
        grid.append(row)
    faces = []
    for ri in range(2):
        for ci in range(segs):
            f = bm.faces.new((grid[ri][ci], grid[ri][ci + 1], grid[ri + 1][ci + 1], grid[ri + 1][ci]))
            f[kind] = T.FACE
            f[tone] = t
            faces.append(f)
    # The chamfer ring: from the face's rim back into the joint.
    rim = ([grid[0][ci] for ci in range(segs + 1)] + [grid[1][segs]]
           + [grid[2][ci] for ci in range(segs, -1, -1)] + [grid[1][0]])
    back = []
    for v in rim:
        co = v.co
        a = math.atan2(co.y, co.x)
        z = co.z
        # Push out to the joint line and back into the wall.
        if abs(z - zs[0]) < 1e-4:
            z = z0 + j
        elif abs(z - zs[2]) < 1e-4:
            z = z1 - j
        if abs(a - angs[0]) < 1e-6:
            a = a0 + j / r_at(z0)
        elif abs(a - angs[-1]) < 1e-6:
            a = a1 - j / r_at(z0)
        nb = bm.verts.new(at(a, z, BLOCK_DEPTH))
        nb[broke] = v[broke]
        back.append(nb)
    n = len(rim)
    for i in range(n):
        k2 = (i + 1) % n
        f = bm.faces.new((rim[k2], rim[i], back[i], back[k2]))
        f[kind] = T.JOINTFACE
        f[tone] = t


def core_ring(z0, z1, gaps=(), segs=40, inset=BLOCK_DEPTH + 0.02):
    """The dark core behind a course's face stones (what an open joint
    shows), with holes where the course has openings."""
    bm = p.near
    kind, tone, broke = new_layers(bm)
    if gaps:
        g = sorted(((ga - hw) % math.tau, 2 * hw) for ga, hw in gaps)
        spans = []
        for i, (g0, w) in enumerate(g):
            nxt = g[(i + 1) % len(g)][0]
            a = g0 + w
            b = nxt if nxt > a else nxt + math.tau
            spans.append((a, b))
    else:
        spans = [(0.0, math.tau)]
    step = math.tau / segs
    for a, b in spans:
        n = max(1, int(math.ceil((b - a) / step)))
        for k in range(n):
            a0 = a + (b - a) * k / n
            a1 = a + (b - a) * (k + 1) / n
            vs = [bm.verts.new((math.cos(q) * (r_at(z) - inset), math.sin(q) * (r_at(z) - inset), z))
                  for q, z in ((a0, z0), (a1, z0), (a1, z1), (a0, z1))]
            f = bm.faces.new(vs)
            f[kind] = K_CORE
            f[tone] = 1.0


def recess(a, hw, z0, z1, depth, back_kind=K_DARK, sill=True):
    """An opening's deep reveal through the wall at angle a, half width hw
    (m at the face), from z0 to z1: stone sides, sill and head, and a back
    of `back_kind` (dark, or the door's boards)."""
    bm = p.near
    kind, tone, broke = new_layers(bm)
    t = p.tone()
    c, s = math.cos(a), math.sin(a)
    tang = Vector((-s, c, 0.0))
    out = Vector((c, s, 0.0))

    def pt(side, z, d):
        return out * (r_at(z) - d) + tang * side * hw + Vector((0, 0, z))

    d0 = 0.0
    d1 = depth
    quads = [
        ((pt(-1, z0, d0), pt(-1, z0, d1), pt(-1, z1, d1), pt(-1, z1, d0)), T.FACE),   # left side
        ((pt(1, z0, d1), pt(1, z0, d0), pt(1, z1, d0), pt(1, z1, d1)), T.FACE),       # right side
        ((pt(-1, z1, d0), pt(-1, z1, d1), pt(1, z1, d1), pt(1, z1, d0)), T.JOINTFACE),  # head
        ((pt(-1, z0, d1), pt(-1, z0, d0), pt(1, z0, d0), pt(1, z0, d1)), T.FACE),      # sill
        ((pt(-1, z0, d1), pt(1, z0, d1), pt(1, z1, d1), pt(-1, z1, d1)), back_kind),   # back
    ]
    for q, k in quads:
        f = bm.faces.new([bm.verts.new(v) for v in q])
        f[kind] = k
        f[tone] = t
    return out, tang


# The door and the windows: (angle, half width at the face, z0, z1).
WINDOWS = []
for i, (zc, a) in enumerate(((11.0, 1.15), (18.6, -2.6), (26.0, 0.1), (32.8, 2.75), (39.0, -1.2))):
    WINDOWS.append((DOOR_A + a, 0.42, zc - 0.7, zc + 0.7))

def gaps_of(z0, z1):
    rz = r_at(z0)
    gaps = []
    if z0 < PLINTH_TOP + DOOR_H - 0.1:
        gaps.append((DOOR_A, DOOR_W / 2 / rz))
    for (wa, whw, wz0, wz1) in WINDOWS:
        if z0 < wz1 - 0.1 and z1 > wz0 + 0.1:
            gaps.append((wa, whw / rz))
    return gaps


prev_gaps = []
for ci, (z0, h) in enumerate(COURSES):
    z1 = z0 + h
    rz = r_at(z0)
    gaps = gaps_of(z0, z1)
    # Lay the course round from a staggered start; a course with a gap
    # starts at the gap's edge and stops at its other edge.
    L_mean = rng.uniform(3.3, 4.3)
    cuts = []
    if gaps:
        ga, ghw = gaps[0]
        start = ga + ghw
        end = ga - ghw + math.tau
    elif prev_gaps:
        # Over the door or a window: one long stone centred on it, the lintel.
        ga, ghw = prev_gaps[0]
        half = ghw + 0.75 / rz
        start = ga - half
        end = start + math.tau
        cuts.append((start, ga + half))
    else:
        start = (ci * 0.5 + rng.uniform(-0.2, 0.2)) * (L_mean / rz)
        end = start + math.tau
    a = cuts[-1][1] if cuts else start
    while a < end - 1e-6:
        L = rng.uniform(0.75, 1.25) * L_mean / rz
        if end - (a + L) < 0.55 * L_mean / rz:
            L = end - a
        cuts.append((a, a + L))
        a += L
    for (a0, a1) in cuts:
        # Skip the stones inside a gap (the gaps after the first one).
        mid = (a0 + a1) / 2
        clipped = []
        lo = a0
        for (ga, ghw) in gaps[1:]:
            # The gap's span, unwrapped near this stone.
            g0 = ga - ghw
            while g0 < a0 - math.pi:
                g0 += math.tau
            while g0 > a0 + math.pi:
                g0 -= math.tau
            g1 = g0 + 2 * ghw
            if g1 > lo and g0 < a1:
                if g0 - lo > 0.25 / rz:
                    clipped.append((lo, g0))
                lo = max(lo, g1)
        if a1 - lo > 0.25 / rz:
            clipped.append((lo, a1))
        for (b0, b1) in clipped:
            chips = rng.choice((0, 0, 1, 1, 2))
            proud = rng.uniform(-0.03, 0.04) - (0.06 if rng.random() < 0.08 else 0.0)
            face_stone(b0, b1, z0, z1, proud=proud, chips=chips)
    core_ring(z0, z1, gaps=gaps)
    prev_gaps = gaps

# The openings' reveals, deep through the wall; the door's boards set in.
recess(DOOR_A, DOOR_W / 2, PLINTH_TOP, max(c[0] + c[1] for c in COURSES if c[0] < PLINTH_TOP + DOOR_H - 0.1), 1.1, back_kind=K_WOOD)
for (wa, whw, wz0, wz1) in WINDOWS:
    # The window's gap is whole courses; the reveal fills the courses it cuts.
    zz0 = max(c[0] for c in COURSES if c[0] <= wz0 + 0.1 + 1e-6) if any(c[0] <= wz0 + 0.1 for c in COURSES) else wz0
    zz1 = min(c[0] + c[1] for c in COURSES if c[0] + c[1] >= wz1 - 0.1)
    recess(wa, whw, zz0, zz1, 1.2)
    # A projecting sill stone under each window.
    c, s = math.cos(wa), math.sin(wa)
    rr = r_at(zz0)
    p.block((c * (rr + 0.08), s * (rr + 0.08), zz0 - 0.09), (2 * whw + 0.5, 0.36, 0.18),
            yaw=wa + math.pi / 2, chips=1, chip_depth=(0.05, 0.12), far=False)

# The door: boards and iron straps, a step of a threshold, a lintel stone.
door_courses = [c for c in COURSES if c[0] < PLINTH_TOP + DOOR_H - 0.1]
door_top = door_courses[-1][0] + door_courses[-1][1]
c, s = math.cos(DOOR_A), math.sin(DOOR_A)
rr = r_at(PLINTH_TOP)
for k in range(5):
    x = -DOOR_W / 2 + 0.06 + (DOOR_W - 0.12) * (k + 0.5) / 5
    p.block((c * (rr - 1.02) - s * x, s * (rr - 1.02) + c * x, (PLINTH_TOP + door_top) / 2),
            ((DOOR_W - 0.12) / 5 - 0.02, 0.1, door_top - PLINTH_TOP - 0.05),
            yaw=DOOR_A + math.pi / 2, bevel=0.015, chips=0, jitter=0.004, kind=K_WOOD, far=False)

# ---- The plinth: a square stepped base, a stair up to the door -----------
def lay(x0, x1, z, h, depth, off, yaw, chips=1, length=(2.0, 3.4), kind=T.FACE):
    """A straight course of blocks along a side: x along the side from x0
    to x1, `off` the side's distance out from the centre, turned `yaw`."""
    m = Matrix.Rotation(yaw, 4, "Z")
    x = x0
    while x < x1 - 0.3:
        L = min(rng.uniform(*length), x1 - x)
        if x1 - (x + L) < 0.8:
            L = x1 - x
        cen = m @ Vector((x + L / 2, off, z + h / 2))
        p.block(tuple(cen), (L - T.JOINT, depth, h - T.JOINT), yaw=yaw, chips=rng.randint(0, chips),
                far=False, kind=kind)
        x += L


PLINTH = [(-4.0, 2.4, 11.4), (-1.6, 2.2, 11.0), (0.6, 1.95, PLINTH_HALF + 0.25)]
for i, (z, h, half) in enumerate(PLINTH):
    for side in range(4):
        # Each side runs from one corner and stops short of the next, which
        # the next side's first stone turns (a pinwheel, so they interlock).
        lay(-half, half - 1.2, z, h, 1.2, -half + 0.6, side * math.pi / 2, chips=2)
    p.far_box((0, 0, z + h / 2), (2 * half, 2 * half, h))
# The paving round the foot: slabs in rows, cut where the shaft stands.
pz = PLINTH[-1][0] + PLINTH[-1][1]
pave_h = PLINTH_TOP - pz
yv = -PLINTH_HALF
while yv < PLINTH_HALF - 0.2:
    d = rng.uniform(1.4, 2.0)
    if PLINTH_HALF - (yv + d) < 0.8:
        d = PLINTH_HALF - yv
    xv = -PLINTH_HALF + rng.uniform(-0.5, 0.0)
    while xv < PLINTH_HALF - 0.2:
        L = rng.uniform(1.6, 2.6)
        if PLINTH_HALF - (xv + L) < 0.7:
            L = PLINTH_HALF - xv
        cx, cy = xv + L / 2, yv + d / 2
        # Skip slabs wholly under the shaft.
        far_corner = max(math.hypot(xx, yy) for xx in (xv, xv + L) for yy in (yv, yv + d))
        if far_corner > R_FOOT - 0.3:
            p.block((cx, cy, pz + pave_h / 2 - rng.uniform(0.0, 0.03)),
                    (L - 0.04, d - 0.04, pave_h), chips=rng.choice((0, 0, 1)), chip_depth=(0.06, 0.18),
                    yaw=rng.uniform(-0.01, 0.01), far=False)
        xv += L
    yv += d
p.far_box((0, 0, pz + pave_h / 2), (2 * PLINTH_HALF, 2 * PLINTH_HALF, pave_h))
# The stair: three steps up the plinth's front to the door, two cheeks.
SW = 3.6
TREAD = 0.75
for k in range(1, 5):
    zt = PLINTH_TOP - 0.8 * k
    y_in = -PLINTH_HALF - TREAD * (k - 1)
    y_out = y_in - TREAD
    # The step's nosing row, then a plain block under it down to the rock.
    lay(-SW / 2, SW / 2, zt - 0.8, 0.8, TREAD + 0.2, (y_in + y_out) / 2 - 0.1, 0.0, chips=1,
        length=(1.1, 1.9))
    if zt - 0.8 > -1.6:
        p.block((0, (y_in + y_out) / 2, (zt - 0.8 - 1.6) / 2), (SW, TREAD, zt - 0.8 + 1.6), chips=0,
                bevel=0.0, far=False, jitter=0.0)
for sx in (-1, 1):
    for lo, hi, ylen in ((-1.6, 0.8, 3.0), (0.8, 2.4, 1.5)):
        p.block((sx * (SW / 2 + 0.45), -PLINTH_HALF - ylen / 2, (lo + hi) / 2),
                (0.9, ylen, hi - lo - T.JOINT), chips=2, far=False)
p.far_box((0, -PLINTH_HALF - 1.5, 0.4), (SW + 1.8, 3.0, 4.0))

# ---- The gallery: corbels, a slab deck, the lantern's stone drum ---------
NCORB = 24
for tier in range(CORBELS):
    z0 = SHAFT_TOP + CORBEL_H * tier
    reach = 0.75 * (tier + 1)
    rr = r_at(SHAFT_TOP)
    # A ring of face stones over the corbels, painted with the tower.
    for i in range(NCORB):
        a = math.tau * i / NCORB
        c, s = math.cos(a), math.sin(a)
        L = reach + 0.6
        cen = (c * (rr + reach - L / 2), s * (rr + reach - L / 2), z0 + CORBEL_H / 2)
        w = 0.8 + 0.15 * tier
        p.block(cen, (L, w, CORBEL_H - T.JOINT), yaw=a, chips=rng.choice((0, 1)),
                chip_depth=(0.05, 0.15), far=False)
# The deck: radial slabs, closed, their outer ends a cornice.
NDECK = 22


def arc_block(r0, r1, a0, a1, z0, z1, segs=3, bevel=0.05, kind=T.FACE):
    """A closed annular-sector block with worn arrises (deck slabs, the
    lantern's drum)."""
    tmp = bmesh.new()
    tk, tt, tb = T._layers(tmp)
    t = p.tone()
    rows = []
    for rr_, zz in ((r0, z0), (r1, z0), (r1, z1), (r0, z1)):
        rows.append([tmp.verts.new((math.cos(a0 + (a1 - a0) * i / segs) * rr_,
                                    math.sin(a0 + (a1 - a0) * i / segs) * rr_, zz)) for i in range(segs + 1)])
    for k in range(4):
        lo, hi = rows[k], rows[(k + 1) % 4]
        for i in range(segs):
            tmp.faces.new((lo[i], lo[i + 1], hi[i + 1], hi[i]))
    tmp.faces.new([rows[0][0], rows[3][0], rows[2][0], rows[1][0]])
    tmp.faces.new([rows[0][-1], rows[1][-1], rows[2][-1], rows[3][-1]])
    bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
    for f in tmp.faces:
        f[tk] = kind
        f[tt] = t
    if bevel > 0:
        res = bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, profile=0.5,
                              affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f[tk] = T.JOINTFACE
            f[tt] = t
    for v in tmp.verts:
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.01
    T._append(p.near, tmp)
    tmp.free()


ga = T.JOINT / 2 / DECK_R
for i in range(NDECK):
    a0 = math.tau * i / NDECK + ga
    a1 = math.tau * (i + 1) / NDECK - ga
    arc_block(LANTERN_R - 0.2, DECK_R, a0, a1, DECK_Z, DECK_TOP, segs=3, bevel=0.06)
# The lantern's stone drum.
NL = 8
for i in range(NL):
    a0 = math.tau * i / NL + 0.01
    a1 = math.tau * (i + 1) / NL - 0.01
    arc_block(LANTERN_R - 0.45, LANTERN_R, a0, a1, DECK_TOP, LANTERN_WALL, segs=3, bevel=0.04)
# The lantern room's floor, under the glass (seen from the gallery).
p.ring((0, 0, LANTERN_WALL - 0.02), [(LANTERN_R - 0.45, 0.0), (LANTERN_R - 0.45, 0.02)], segments=24, chips=0)
p.ring((0, 0, SHAFT_TOP - 0.02), [(r_at(SHAFT_TOP) - BLOCK_DEPTH - 0.05, 0.0),
                                   (r_at(SHAFT_TOP) - BLOCK_DEPTH - 0.05, DECK_Z - SHAFT_TOP + 0.04)],
       segments=24, chips=0)

# ---- The keeper's house ----------------------------------------------------
HX0, HX1 = -20.0, -7.4     # west gable to the tower
HY0, HY1 = -4.6, 3.6       # south (door) and north walls, outer faces
WALL = 0.75
EAVES = 5.3
RIDGE = 8.7
RIDGE_Y = (HY0 + HY1) / 2
HZ0 = -1.4
hc = [(HZ0, 1.1)]
while hc[-1][0] + hc[-1][1] < EAVES - 0.1:
    z = hc[-1][0] + hc[-1][1]
    hc.append((z, min(0.95, EAVES - z)))
HDOOR = (-14.2, -12.8)
HWIN = [(-18.6, -17.6), (-10.6, -9.6)]
NWIN = (-16.0, -15.0)


def course_span(lo_z, hi_z):
    a = max(c[0] for c in hc if c[0] <= lo_z + 1e-6)
    b = min(c[0] + c[1] for c in hc if c[0] + c[1] >= hi_z - 1e-6)
    return a, b


dz0, dz1 = course_span(0.3, 2.6)
wz0, wz1 = course_span(1.6, 3.4)
for ci, (z, h) in enumerate(hc):
    z1 = z + h
    for (y_face, sgn) in ((HY0, 1), (HY1, -1)):
        gaps = []
        if y_face == HY0 and dz0 - 1e-6 <= z < dz1 - 1e-6:
            gaps.append(HDOOR)
        if wz0 - 1e-6 <= z < wz1 - 1e-6:
            gaps += HWIN if y_face == HY0 else [NWIN]
        runs = []
        lo = HX0
        for g0, g1 in sorted(gaps):
            runs.append((lo, g0))
            lo = g1
        runs.append((lo, HX1))
        for a, b in runs:
            if b - a > 0.3:
                lay(a, b, z, h, WALL, y_face + sgn * WALL / 2, 0.0, chips=1, length=(1.0, 2.0))
    # The west gable wall (along y).
    lay(HY0 + WALL, HY1 - WALL, z, h, WALL, -(HX0 + WALL / 2), math.pi / 2, chips=1, length=(1.0, 2.0))
# The gable above the eaves, stepped in under the roof.
z = EAVES
slope = (RIDGE - EAVES) / ((HY1 - HY0) / 2)
while z < RIDGE - 0.4:
    h = 0.6
    half = ((RIDGE - (z + h)) / slope)
    if half > 0.3:
        lay(RIDGE_Y - half, RIDGE_Y + half, z, h, WALL, -(HX0 + WALL / 2), math.pi / 2, chips=0,
            length=(0.9, 1.6))
    z += h


def house_recess(x0, x1, z0, z1, yf, back_kind):
    bm = p.near
    kind, tone, broke = new_layers(bm)
    t = p.tone()
    yi = yf + WALL * (1 if yf == HY0 else -1)
    q = [
        ((x0, yf, z0), (x0, yi, z0), (x0, yi, z1), (x0, yf, z1)),
        ((x1, yi, z0), (x1, yf, z0), (x1, yf, z1), (x1, yi, z1)),
        ((x0, yf, z1), (x0, yi, z1), (x1, yi, z1), (x1, yf, z1)),
        ((x0, yi, z0), (x0, yf, z0), (x1, yf, z0), (x1, yi, z0)),
        ((x0, yi, z0), (x1, yi, z0), (x1, yi, z1), (x0, yi, z1)),
    ]
    ks = (T.FACE, T.FACE, T.JOINTFACE, T.FACE, back_kind)
    for quad, k in zip(q, ks):
        vs = [bm.verts.new(v) for v in quad]
        if yf == HY1:
            vs.reverse()
        f = bm.faces.new(vs)
        f[kind] = k
        f[tone] = t


house_recess(HDOOR[0], HDOOR[1], dz0, dz1, HY0, K_WOOD)
for g in HWIN:
    house_recess(g[0], g[1], wz0, wz1, HY0, K_DARK)
house_recess(NWIN[0], NWIN[1], wz0, wz1, HY1, K_DARK)
# Lintels over the house's openings: one long stone each.
for (g0, g1), top in ((HDOOR, dz1), (HWIN[0], wz1), (HWIN[1], wz1)):
    p.block(((g0 + g1) / 2, HY0 + WALL / 2 - 0.04, top + 0.25), (g1 - g0 + 0.9, WALL + 0.08, 0.5),
            chips=1, chip_depth=(0.05, 0.15), far=False)
p.block((-15.5, HY1 - WALL / 2 + 0.04, wz1 + 0.25), (1.9, WALL + 0.08, 0.5), chips=1, far=False)
# A step at the house door.
p.block(((HDOOR[0] + HDOOR[1]) / 2, HY0 - 0.45, dz0 - 0.2), (2.2, 0.9, 0.5), chips=2, far=False)
# The roof: rows of slates up each slope, a ridge, overhanging the walls.
OVER = 0.7
rx0, rx1 = HX0 - 0.5, HX1 + 0.2
run = (HY1 - HY0) / 2 + OVER
rise = slope * run
ang = math.atan2(rise, run)
lenslope = math.hypot(run, rise)
rows = int(lenslope / 0.42)
for sgn in (-1, 1):
    for k in range(rows):
        u = (k + 0.5) / rows
        d = run * (1 - u)        # distance out from the ridge
        yc = RIDGE_Y + sgn * d
        zc = RIDGE + 0.12 - slope * d
        x = rx0
        while x < rx1 - 0.2:
            L = min(rng.uniform(1.4, 2.6), rx1 - x)
            if rx1 - (x + L) < 0.6:
                L = rx1 - x
            p.block((x + L / 2, yc, zc + rng.uniform(-0.01, 0.01)), (L - 0.02, lenslope / rows + 0.12, 0.07),
                    tilt=(sgn * ang, 0.0), bevel=0.012, chips=rng.choice((0, 0, 0, 1)),
                    chip_depth=(0.04, 0.1), jitter=0.006, kind=K_SLATE, far=False)
            x += L
p.block(((rx0 + rx1) / 2, RIDGE_Y, RIDGE + 0.18), (rx1 - rx0, 0.42, 0.22), bevel=0.04, chips=2,
        kind=K_SLATE, far=False)
# The chimney: a stack of stones through the north slope, a cap.
cz = 4.0
while cz < RIDGE + 1.6:
    p.block((-17.0, 1.4, cz + 0.4), (1.3, 1.1, 0.78), chips=1, chip_depth=(0.05, 0.15), far=False)
    cz += 0.8
p.block((-17.0, 1.4, cz + 0.12), (1.6, 1.4, 0.24), chips=1, far=False)

# ---- The far LOD -----------------------------------------------------------
# The shaft in stacked cylinders split at the band edges, so the bands hold.
edges = [PLINTH_TOP] + [e for b in RED_BANDS for e in b] + [SHAFT_TOP]
edges = sorted(set(edges))
for a, b in zip(edges, edges[1:]):
    p.far_cylinder((0, 0, a), b - a, r_at(a), r_at(b), segments=16)
p.far_cylinder((0, 0, SHAFT_TOP), DECK_Z - SHAFT_TOP, r_at(SHAFT_TOP), DECK_R - 0.5, segments=16)
p.far_cylinder((0, 0, DECK_Z), DECK_T, DECK_R, DECK_R, segments=16)
p.far_cylinder((0, 0, DECK_TOP), LANTERN_WALL - DECK_TOP, LANTERN_R, LANTERN_R, segments=10)
p.far_cylinder((0, 0, LANTERN_WALL + 0.02), GLASS_TOP - LANTERN_WALL, LANTERN_R - 0.2, LANTERN_R - 0.2, segments=10)
p.far_cylinder((0, 0, GLASS_TOP + 0.35), CAP_TOP - GLASS_TOP, LANTERN_R + 0.3, 0.6, segments=10)
p.far_cylinder((0, 0, CAP_TOP + 0.3), 1.2, 0.55, 0.2, segments=6)
# The house: walls, the roof's two slopes.
p.far_box(((HX0 + HX1) / 2, (HY0 + HY1) / 2, (HZ0 + EAVES) / 2), (HX1 - HX0, HY1 - HY0, EAVES - HZ0))
for sgn in (-1, 1):
    p.far_box(((rx0 + rx1) / 2, RIDGE_Y + sgn * run / 2, RIDGE + 0.1 - rise / 2 + 0.05),
              (rx1 - rx0, lenslope, 0.25), tilt=(sgn * ang, 0.0))
p.far_box((-17.0, 1.4, (4.0 + cz) / 2 + 0.2), (1.3, 1.1, cz - 4.0 + 0.4))

# ---- The iron and the glass (near only, their own materials) --------------
iron = bmesh.new()
glass = bmesh.new()
icol = iron.loops.layers.float_color.new("Col")
gcol = glass.loops.layers.float_color.new("Col")


def tube(bm, colour_of, pts, rad, n=5, closed=False):
    """A thin round bar along the points."""
    rings = []
    for i, q in enumerate(pts):
        q = Vector(q)
        a = Vector(pts[i - 1] if i > 0 else pts[0])
        b = Vector(pts[i + 1] if i + 1 < len(pts) else pts[-1])
        if closed:
            a = Vector(pts[i - 1])
            b = Vector(pts[(i + 1) % len(pts)])
        d = (b - a).normalized()
        u = d.orthogonal().normalized()
        w = d.cross(u)
        rings.append([bm.verts.new(q + (u * math.cos(k * math.tau / n) + w * math.sin(k * math.tau / n)) * rad)
                      for k in range(n)])
    m = len(rings) if closed else len(rings) - 1
    for i in range(m):
        lo, hi = rings[i], rings[(i + 1) % len(rings)]
        for k in range(n):
            f = bm.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
            colour_of(f)
    return rings


def lathe(bm, colour_of, profile, segs, closed_top=True):
    """A solid of revolution from [(radius, z), ...] bottom up."""
    rows = [[bm.verts.new((math.cos(math.tau * i / segs) * r, math.sin(math.tau * i / segs) * r, z))
             for i in range(segs)] for r, z in profile]
    for lo, hi in zip(rows, rows[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            colour_of(bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
    if closed_top:
        colour_of(bm.faces.new(rows[-1]))
    colour_of(bm.faces.new(list(reversed(rows[0]))))


def painter(layer, base, rust=0.0, streak_top=None):
    def colour_of(f):
        for loop in f.loops:
            q = loop.vert.co
            c = base
            if rust > 0.0:
                n = noise.noise(Vector((q.x * 1.3, q.y * 1.3, q.z * 0.7))) * 0.5 + 0.5
                c = T.mix(c, RUST, rust * max(0.0, n - 0.35) / 0.65)
            if streak_top is not None:
                n = max(0.0, noise.noise(Vector((q.x * 2.0, q.y * 2.0, q.z * 0.15))))
                c = T.mix(c, (0.20, 0.25, 0.22), 0.5 * n)
            loop[layer] = T.srgb_to_linear(c) + (1.0,)
    return colour_of


iron_paint = painter(icol, IRON, rust=0.6)
cap_paint = painter(icol, VERDIGRIS, streak_top=True)
glass_paint = painter(gcol, GLASS)
# The gallery's rail: stanchions and two rails.
NPOST = 32
rail_z = DECK_TOP
for i in range(NPOST):
    a = math.tau * i / NPOST
    c, s = math.cos(a), math.sin(a)
    tube(iron, iron_paint, [(c * RAIL_R, s * RAIL_R, rail_z - 0.02), (c * RAIL_R, s * RAIL_R, rail_z + RAIL_H)],
         0.04, n=4)
for hz, rad in ((RAIL_H, 0.045), (RAIL_H * 0.5, 0.03)):
    pts = [(math.cos(math.tau * i / 64) * RAIL_R, math.sin(math.tau * i / 64) * RAIL_R, rail_z + hz) for i in range(64)]
    tube(iron, iron_paint, pts, rad, n=4, closed=True)
# The lantern: the glazing's frame, a cornice, the dome with ribs, the vent.
NG = 10
GR = LANTERN_R - 0.25
for i in range(NG):
    a = math.tau * (i + 0.5) / NG
    c, s = math.cos(a), math.sin(a)
    tube(iron, iron_paint, [(c * GR, s * GR, LANTERN_WALL - 0.05), (c * GR, s * GR, GLASS_TOP + 0.05)], 0.08, n=4)
for hz in (LANTERN_WALL + 0.05, (LANTERN_WALL + GLASS_TOP) / 2 + 0.6, GLASS_TOP - 0.05):
    pts = [(math.cos(math.tau * (i + 0.5) / NG) * (GR + 0.02), math.sin(math.tau * (i + 0.5) / NG) * (GR + 0.02), hz)
           for i in range(NG)]
    tube(iron, iron_paint, pts, 0.05, n=4, closed=True)
lathe(iron, iron_paint, [(GR - 0.05, GLASS_TOP), (LANTERN_R + 0.35, GLASS_TOP + 0.1),
                         (LANTERN_R + 0.35, GLASS_TOP + 0.35)], NG * 2, closed_top=False)
lathe(iron, cap_paint, [(LANTERN_R + 0.35, GLASS_TOP + 0.35), (LANTERN_R + 0.1, GLASS_TOP + 0.6),
                        (2.6, GLASS_TOP + 1.5), (1.3, GLASS_TOP + 2.25), (0.6, CAP_TOP)], NG * 2)
for i in range(NG):
    a = math.tau * (i + 0.5) / NG
    prof = [(LANTERN_R + 0.37, GLASS_TOP + 0.36), (LANTERN_R + 0.12, GLASS_TOP + 0.62),
            (2.62, GLASS_TOP + 1.52), (1.32, GLASS_TOP + 2.27), (0.62, CAP_TOP)]
    tube(iron, cap_paint, [(math.cos(a) * r, math.sin(a) * r, z + 0.03) for r, z in prof], 0.06, n=3)
# The vent: a drum, a hood, a ball, the vane's rod.
lathe(iron, cap_paint, [(0.5, CAP_TOP - 0.05), (0.5, CAP_TOP + 0.7), (0.95, CAP_TOP + 0.75),
                        (0.4, CAP_TOP + 1.2), (0.12, CAP_TOP + 1.35)], 12)
lathe(iron, iron_paint, [(0.001, CAP_TOP + 1.3), (0.2, CAP_TOP + 1.42), (0.2, CAP_TOP + 1.55), (0.001, CAP_TOP + 1.7)], 8)
tube(iron, iron_paint, [(0, 0, CAP_TOP + 1.6), (0, 0, CAP_TOP + 3.2)], 0.04, n=4)
tube(iron, iron_paint, [(-0.6, 0, CAP_TOP + 2.9), (0.9, 0, CAP_TOP + 2.9)], 0.025, n=3)
v = [iron.verts.new(q) for q in ((0.9, 0.0, CAP_TOP + 2.6), (1.5, 0.0, CAP_TOP + 2.75), (1.5, 0.0, CAP_TOP + 3.05),
                                  (0.9, 0.0, CAP_TOP + 3.2))]
iron_paint(iron.faces.new(v))
iron_paint(iron.faces.new(list(reversed([iron.verts.new(x.co) for x in v]))))
# The lamp's works inside: a pedestal and the lens's brass frame (seen through the glass).
lathe(iron, iron_paint, [(0.5, LANTERN_WALL), (0.35, LANTERN_WALL + 0.3), (0.25, LAMP - 1.2), (0.6, LAMP - 1.1)], 8)
# The panes.
for i in range(NG):
    a0 = math.tau * (i + 0.5) / NG
    a1 = math.tau * (i + 1.5) / NG
    q = [(math.cos(a) * GR, math.sin(a) * GR, z) for a, z in
         ((a0, LANTERN_WALL), (a1, LANTERN_WALL), (a1, GLASS_TOP), (a0, GLASS_TOP))]
    glass_paint(glass.faces.new([glass.verts.new(x) for x in q]))
# The lens: a stack of glass rings round the lamp (the glass material glows).
lathe(glass, painter(gcol, (1.0, 0.86, 0.55)), [(0.55, LAMP - 1.1), (0.95, LAMP - 0.6), (1.05, LAMP),
                                                 (0.95, LAMP + 0.6), (0.55, LAMP + 1.1)], 12)


# ---- Solids (Blender frame, z up): few and coarse ------------------------
def box(lo, hi):
    p.solid(lo, hi)


box((-11.4, -11.4, -4.0), (11.4, 11.4, PLINTH_TOP))
box((-SW / 2 - 0.9, -PLINTH_HALF - 3.7, -1.6), (SW / 2 + 0.9, -PLINTH_HALF, PLINTH_TOP - 0.8))
stacks = [PLINTH_TOP, 13.0, 23.0, 33.0, SHAFT_TOP]
for a, b in zip(stacks, stacks[1:]):
    s = 0.92 * r_at(a)
    box((-s, -s, a), (s, s, b))
box((-DECK_R, -DECK_R, SHAFT_TOP), (DECK_R, DECK_R, DECK_TOP + RAIL_H))
box((-LANTERN_R - 0.35, -LANTERN_R - 0.35, DECK_TOP), (LANTERN_R + 0.35, LANTERN_R + 0.35, CAP_TOP + 1.7))
box((HX0, HY0, HZ0), (HX1, HY1, EAVES))
box((rx0, RIDGE_Y - run, EAVES), (rx1, RIDGE_Y + run, EAVES + rise * 0.5))
box((rx0, RIDGE_Y - run * 0.5, EAVES + rise * 0.5), (rx1, RIDGE_Y + run * 0.5, RIDGE + 0.3))
box((-17.7, 0.8, RIDGE), (-16.3, 2.1, cz + 0.25))


# ---- Export ------------------------------------------------------------------
def plain_object(bm, name, mat_name):
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.set_sharp_from_angle(angle=math.radians(35.0))
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name))
    return ob, sum(len(q.vertices) - 2 for q in me.polygons)


for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
near, near_tris = p._object(p.near, NAME, False)
far, far_tris = p._object(p.far, NAME + "_far", True)
iron_ob, iron_tris = plain_object(iron, "lighthouse_iron", "lighthouse_iron")
glass_ob, glass_tris = plain_object(glass, "lighthouse_glass", "lighthouse_glass")
glb = OUT / f"{NAME}.glb"
bpy.ops.export_scene.gltf(
    filepath=str(glb), export_format="GLB", use_selection=False, export_apply=False,
    export_yup=True, export_materials="EXPORT", export_vertex_color="NAME", export_vertex_color_name="Col",
    export_all_vertex_colors=False,
    export_normals=True, export_tangents=False, export_animations=False, export_cameras=False,
    export_lights=False, export_morph=False, export_skins=False)
boxes = []
for lo, hi in p.boxes:
    boxes.append([round(lo[0], 3), round(lo[2], 3), round(-hi[1], 3),
                  round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)])
info = {"piece": NAME, "boxes": boxes, "tris": near_tris, "far_tris": far_tris,
        "iron_tris": iron_tris, "glass_tris": glass_tris, "lamp": LAMP, "courses": len(COURSES)}
(OUT / f"{NAME}.boxes.json").write_text(json.dumps(info, indent=1) + "\n")
print(f"LIGHTHOUSE {NAME}: {near_tris} tris stone, {iron_tris} iron, {glass_tris} glass, {far_tris} far, "
      f"{len(boxes)} boxes, {len(COURSES)} courses -> {glb}")
p.near.free()
p.far.free()
iron.free()
glass.free()
