"""The temple kit's inner wall (lane wall): `wall_door`, one bay of coursed
wall with the tall doorway through it, and `wall_broken`, a wall end that
stands full height at one side and steps down to fallen stones at the other.

    python tools/blender.py run art/blender/temple_kit/wall_build.py [-- --seed=N]

Large ashlar on the scale of the column: a 1.2 m plinth (the column base's
height), nine courses of about 2.5 m (the drums') to the door's lintel at
24.0, the lintel's two courses and a 2.0 m top course: 13 courses to 30.5.
Stones are several metres long, flat dressed faces, open joints with worn
arrises; the depth across a face is in stones set proud or back, settled,
eroded, chipped, and a few face stones fallen out.

The wall runs along x, its faces look along +-y, 2.4 m thick. A piece's
origin is the centre of its bay on the foot line (z 0): the bay spans x
-9.25..9.25. The courses are toothed so bays interlock: course k of
`wall_door` spans x -(9.25+t_k)..(9.25+t_k), and `wall_broken`'s course k
starts at -9.25+t_k (its full-height end). The door is symmetric, so a
`wall_broken` either side of it (the left one turned 180 deg about z)
meets it course for course.
"""

import math
import sys

from mathutils import Matrix, Vector

import bmesh
import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
seed = next((int(a.split("=")[1]) for a in args if a.startswith("--seed=")), 11)

HALF = T.BAY / 2                  # 9.25
WT = T.WALL_T                      # 2.4
FOOTING = 6.0                      # plain stone under the foot line
PLINTH_H = T.BASE_H                # 1.2: the plinth course, as tall as the column's base
PLINTH_OUT = 0.15                  # how far it stands out of each face
TOOTH = 0.6                        # the courses' stagger at the bay ends
BOND = 0.9                         # no joint closer than this to one in the course below

# ---- The course table, shared by both pieces ------------------------------
# The plinth; nine courses tapering 2.62 -> 2.45 to the lintel's foot at
# DOOR_H (24.0: the low ones meet the column's drum joints within a few cm);
# the lintel's two courses; a smaller top course to COLUMN_H.
N_LOW = 9
A = 2.62
B = 2.0 * (T.DOOR_H - PLINTH_H) / N_LOW - A
COURSES = [(0.0, PLINTH_H)]
z = PLINTH_H
for i in range(N_LOW):
    h = A + (B - A) * i / (N_LOW - 1)
    COURSES.append((z, h))
    z += h
assert abs(z - T.DOOR_H) < 1e-6, z
for h in (2.3, 2.2, 2.0):
    COURSES.append((z, h))
    z += h
assert abs(z - T.COLUMN_H) < 1e-6, z


def tooth(k):
    """Course k's stagger at the bay end (0 for the plinth)."""
    return 0.0 if k == 0 else (TOOTH if k % 2 else -TOOTH)


def notch(p, bm, c, b, free, depth, kind_layer, broke_layer):
    """A spall out of an arris: the stone between two planes leaning
    together over the point c (b the arris's outward normal, `free` the
    axis it runs along) is cut away and the hole filled as a fresh break."""
    r = p.rng
    a = r.uniform(0.7, 1.5)
    ef = Vector((0.0, 0.0, 0.0))
    ef[free] = 1.0
    wob = Vector((r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15)))
    n1 = (b + ef * a * r.uniform(0.7, 1.3) + wob).normalized()
    n2 = (b - ef * a * r.uniform(0.7, 1.3) + wob).normalized()
    co = c - b * depth
    for n in (n1, n2):
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n)
    kill = [v for v in bm.verts if n1.dot(v.co - co) > 1e-4 and n2.dot(v.co - co) > 1e-4]
    if not kill:
        return
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    edges = [e for e in bm.edges if len(e.link_faces) == 1]
    made = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    for f in made["faces"]:
        f[kind_layer] = T.BROKEN
        for v in f.verts:
            v[broke_layer] = 1.0


def chip(p, bm, corner, size, depth, kind_layer, broke_layer):
    """Knocks a corner or an arris off a box centred on the origin. Unlike
    T.Piece._chip (whose cut faces the direction from the block's centre,
    which on a long block slices its whole end away), the cut faces out of
    the faces the point lies on: a corner's three, an arris's two."""
    r = p.rng
    n = Vector((0.0, 0.0, 0.0))
    free = []
    for i in range(3):
        if abs(abs(corner[i]) - size[i] / 2) < 1e-4:
            n[i] = math.copysign(1.0, corner[i])
        else:
            free.append(i)
    if n.length < 0.5 or len(free) > 1:
        return
    n = n.normalized()
    if free:
        # On an arris: a V notch (two cuts) so the break stays local
        # instead of running the block's length.
        notch(p, bm, Vector(corner), n, free[0], depth, kind_layer, broke_layer)
        return
    n = (n + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)))).normalized()
    co = Vector(corner) - n * depth
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n, clear_outer=True)
    cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if not cut:
        return
    made = bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    for f in made["faces"]:
        f[kind_layer] = T.BROKEN
        for v in f.verts:
            v[broke_layer] = 1.0


# ---- A wall block: the library's block, with its chips biased to the faces
# and the open joints' arrises, so a raking light finds them. ---------------
def wblock(p, center, size, yaw=0.0, tilt=(0.0, 0.0), bevel=0.12, chips=1, face_chips=1,
           chip_depth=(0.25, 0.7), jitter=0.012, tone=None, far=False, kind=T.FACE,
           edge=None):
    """A cut block like T.Piece.block, its faces flat. `face_chips` corners
    are knocked off the faces that show (+-y) at their arrises; `edge` (+1
    or -1) forces one chip on that x end (a door reveal, a broken end)."""
    r = p.rng
    sx, sy, sz = size
    tmp = bmesh.new()
    tk, tt, tb = T._layers(tmp)
    bmesh.ops.create_cube(tmp, size=1.0)
    for v in tmp.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    t = p.tone() if tone is None else tone
    for f in tmp.faces:
        f[tk] = kind
        f[tt] = t
    if bevel > 0.0:
        b = min(bevel * r.uniform(0.7, 1.4), 0.3 * min(size))
        res = bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=1,
                              profile=0.5, affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f[tk] = T.JOINTFACE
            f[tt] = t
    corners = []
    for _ in range(chips):
        c = Vector((r.choice((-1, 1)) * sx / 2, r.choice((-1, 1)) * sy / 2, r.choice((-1, 1)) * sz / 2))
        axis = r.randrange(4)
        if axis < 3:
            c[axis] *= r.uniform(-0.7, 0.7)
        corners.append(c)
    for _ in range(face_chips):
        # On a face (y), along its top/bottom arris or at a vertical joint.
        c = Vector((r.choice((-1, 1)) * sx / 2, r.choice((-1, 1)) * sy / 2, r.choice((-1, 1)) * sz / 2))
        if r.random() < 0.6:
            c.x *= r.uniform(-0.8, 0.8)
        else:
            c.z *= r.uniform(-0.6, 0.6)
        corners.append(c)
    if edge is not None:
        corners.append(Vector((edge * sx / 2, r.choice((-1, 1)) * sy / 2, sz / 2 * r.uniform(-0.8, 0.8))))
    for c in corners:
        d = r.uniform(*chip_depth) * min(1.0, min(size) / 1.2)
        chip(p, tmp, c, size, d, tk, tb)
        for f in tmp.faces:
            f[tt] = t
    if corners:
        # The notches' cutting planes split faces far from the notch: merge
        # the flat pieces back (the export triangulates what's left).
        bmesh.ops.dissolve_limit(tmp, angle_limit=math.radians(0.5), verts=list(tmp.verts),
                                 edges=list(tmp.edges), delimit={"NORMAL"})
    if jitter > 0.0:
        for v in tmp.verts:
            v.co += Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1, 1))) * jitter
    m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(yaw, 4, "Z")
         @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X"))
    T._append(p.near, tmp, m)
    tmp.free()
    if far:
        p.far_box(center, size, yaw=yaw, tilt=tilt, tone=t)


def plain(p, center, size, far=False):
    """Plain stone, no wear: the footing under the foot line."""
    p.block(center, size, bevel=0.0, chips=0, jitter=0.0, far=far)


def wall_stone(p, x0, x1, z0, h, recess=0.0, edge=None, out=0.0, chips=None):
    """One stone of the wall face between x0 and x1, a course of height h
    from z0: its two faces set proud or back a few cm each, some settled or
    leaning, a weathered one eroded back more; `recess` (m, sign = which
    face) leaves only the back leaf, dark, as if its face stone had fallen
    out."""
    r = p.rng
    L = x1 - x0
    front = r.uniform(-0.05, 0.05) + out
    back = r.uniform(-0.05, 0.05) + out
    if r.random() < 0.14:
        front -= r.uniform(0.08, 0.2)        # a soft bed, eroded back
    if r.random() < 0.14:
        back -= r.uniform(0.08, 0.2)
    tone = p.tone()
    if recess > 0:
        front -= recess
        tone *= 0.72
    elif recess < 0:
        back += recess
        tone *= 0.72
    depth = WT + front + back
    cy = (front - back) / 2
    yaw = r.uniform(-0.007, 0.007)
    tilt = (r.uniform(-0.004, 0.004), r.uniform(-0.003, 0.003))
    sink = 0.0
    if r.random() < 0.2:
        # Settled: leaning out of true a little, sunk into its joint.
        tilt = (r.uniform(-0.016, 0.016), r.uniform(-0.006, 0.006))
        sink = r.uniform(0.005, 0.015)
    fc = r.choice((1, 1, 2, 2, 3))
    wblock(p, ((x0 + x1) / 2, cy, z0 + h / 2 - sink), (L - T.JOINT, depth, h - T.JOINT),
           yaw=yaw, tilt=tilt, chips=r.randint(0, 2) if chips is None else chips, face_chips=fc,
           edge=edge, tone=tone)


def spans(r, x0, x1, h, below=(), lo=None, hi=None):
    """Cut x0..x1 into stone lengths for a course of height h: several
    metres each, now and then a very long one, and no joint within BOND of
    a joint in the course below (`below`)."""
    lo = lo or h * 1.8
    hi = hi or h * 3.3
    out = []
    x = x0
    while x < x1 - 0.3:
        for _ in range(12):
            L = r.uniform(lo, hi)
            if r.random() < 0.15:
                L = r.uniform(hi, hi * 1.45)     # a very long stone
            L = min(L, x1 - x)
            if x1 - (x + L) < lo * 0.6:
                L = x1 - x
            e = x + L
            if e >= x1 - 1e-6 or all(abs(e - j) > BOND for j in below):
                break
        out.append((x, e))
        x = e
    return out


def joints(sp):
    return [b for (a, b) in sp[:-1]]


def lay_course(p, k, x0, x1, below=(), recess_at=None, skip=(), last_edge=None):
    """Course k's stones from x0 to x1. `recess_at` is a set of stone
    indices that lose their face leaf; `skip` stones missing outright.
    Returns the stones' x spans."""
    r = p.rng
    z0, h = COURSES[k]
    sp = spans(r, x0, x1, h, below)
    for i, (a, b) in enumerate(sp):
        if i in skip:
            continue
        rec = 0.0
        if recess_at and i in recess_at:
            rec = r.choice((-1, 1)) * r.uniform(0.5, 1.1)
        wall_stone(p, a, b, z0, h, recess=rec, edge=last_edge if i == len(sp) - 1 else None)
    return sp


def plinth(p, x0, x1):
    """The plinth course: long low stones standing out of both faces."""
    r = p.rng
    for a, b in spans(r, x0, x1, PLINTH_H, lo=4.0, hi=7.0):
        L = b - a
        dy = r.uniform(-0.03, 0.03)
        wblock(p, ((a + b) / 2, dy, PLINTH_H / 2), (L - T.JOINT, WT + 2 * PLINTH_OUT, PLINTH_H - T.JOINT),
               bevel=0.14, chips=r.randint(1, 2), face_chips=r.randint(1, 2), chip_depth=(0.15, 0.4))


def footing(p, x0, x1):
    """Two courses of plain stone, 6 m under the foot line, so no gap shows
    where the ground falls away."""
    r = p.rng
    for zc in (-FOOTING + 1.5, -1.5):
        x = x0
        while x < x1 - 0.5:
            L = min(r.uniform(4.0, 6.5), x1 - x)
            if x1 - (x + L) < 1.5:
                L = x1 - x
            plain(p, (x + L / 2, 0.0, zc), (L - T.JOINT, WT + 2 * PLINTH_OUT + 0.1, 3.0 - T.JOINT))
            x += L
    p.far_box(((x0 + x1) / 2, 0.0, -FOOTING / 2), (x1 - x0, WT + 0.4, FOOTING))


# ---- wall_door ------------------------------------------------------------
def build_door():
    p = T.Piece("wall_door", seed=seed)
    p.ground = 0.0
    r = p.rng
    dw = T.DOOR_W / 2                       # 7.0
    # The lintel: the first two courses whose foot is at least DOOR_H.
    L = next(k for k, (z0, h) in enumerate(COURSES) if z0 >= T.DOOR_H - 1e-6)
    lintel_z = COURSES[L][0]
    lintel_h = COURSES[L][1] + COURSES[L + 1][1]
    lintel_x = HALF - TOOTH                 # 8.65: both its courses reach this far

    footing(p, -HALF, HALF)
    # The threshold: worn slabs flush with the foot line.
    x = -dw - 0.4
    for wv in (4.6, 5.2, 5.0):
        wblock(p, (x + wv / 2, 0.0, -0.3), (wv - T.JOINT, WT + 0.3, 0.6 - T.JOINT), bevel=0.12,
               chips=2, face_chips=0, chip_depth=(0.1, 0.25))
        x += wv
    plinth(p, -HALF, -dw)
    plinth(p, dw, HALF)

    # The jambs: one quoin a course each side, long and short in turn, set
    # out a little from the wall and chipped at the reveal. One has lost
    # its face leaf, one is eroded deep.
    lost = (r.choice((-1, 1)), r.randint(2, L - 3))
    for k in range(1, L):
        z0, h = COURSES[k]
        e = HALF + tooth(k)
        for s in (-1, 1):
            a, b = (-e, -dw) if s < 0 else (dw, e)
            rec = r.choice((-1, 1)) * r.uniform(0.45, 0.7) if (s, k) == lost else 0.0
            # The reveal is the left quoin's +x end, the right one's -x end.
            wall_stone(p, a, b, z0, h, out=0.035, edge=-s, recess=rec)
    # The lintel: one massive block over the opening, bearing on both jambs.
    wblock(p, (0.0, r.uniform(-0.02, 0.02), lintel_z + lintel_h / 2),
           (2 * lintel_x - T.JOINT, WT + 0.12, lintel_h - T.JOINT),
           bevel=0.14, chips=3, face_chips=4, chip_depth=(0.25, 0.6), jitter=0.015)
    for k in (L, L + 1):
        if tooth(k) > 0:
            z0, h = COURSES[k]
            for s in (-1, 1):
                a, b = sorted((s * lintel_x, s * (HALF + tooth(k))))
                wall_stone(p, a, b, z0, h)
    # Over the lintel to the top: full courses, a face stone fallen out and
    # a stone gone from the top.
    top = len(COURSES) - 1
    gone = {}
    below = [-lintel_x, lintel_x]
    for k in range(L + 2, top + 1):
        e = HALF + tooth(k)
        skip = (1,) if k == top else ()
        recess = {2} if k == top else None
        sp = lay_course(p, k, -e, e, below=below, recess_at=recess, skip=skip)
        below = joints(sp)
        if k == top:
            gone[k] = [s for i, s in enumerate(sp) if i not in skip]

    # The far LOD: the jambs, the band over the door, the top course by its
    # stones (so the missing one stays a notch), the plinth, footing.
    # The jambs and band reach the long tooth (9.85), so a chained
    # wall_broken's short-toothed courses leave no slit between the boxes.
    far_top = COURSES[top][0]
    fe = HALF + TOOTH
    for s in (-1, 1):
        p.far_box((s * (fe + dw) / 2, 0.0, lintel_z / 2), (fe - dw, WT + 0.1, lintel_z))
    p.far_box((0.0, 0.0, (lintel_z + far_top) / 2), (2 * fe, WT, far_top - lintel_z))
    for k, sp in gone.items():
        z0, h = COURSES[k]
        for a, b in sp:
            p.far_box(((a + b) / 2, 0.0, z0 + h / 2), (b - a, WT, h))

    # The flight's solids: two jambs, the band over the door, the footing
    # under the threshold. The doorway itself is open.
    y = WT / 2 + PLINTH_OUT
    p.solid((-HALF, -y, -FOOTING), (-dw, y, lintel_z))
    p.solid((dw, -y, -FOOTING), (HALF, y, lintel_z))
    p.solid((-HALF, -y, lintel_z), (HALF, y, T.COLUMN_H))
    p.solid((-dw, -y, -FOOTING), (dw, y, 0.0))
    print(f"WALL door: clear {2 * dw:.2f} wide x {lintel_z:.2f} high, lintel {2 * lintel_x:.2f} x {lintel_h:.2f}, "
          f"{len(COURSES)} courses")
    p.export()


# ---- wall_broken ----------------------------------------------------------
def fallen(p, x, y, size, base, broken):
    """A wall stone lying where it fell: sunk in the turf if on the ground,
    tipped more if it landed on another; `broken` splits it in two parts
    lying apart, each chipped at the break."""
    r = p.rng
    sink = r.uniform(0.12, 0.35) * size[2] if base == 0.0 else r.uniform(0.0, 0.2)
    steep = 0.08 if base == 0.0 else 0.3
    yaw = r.uniform(0, math.pi)
    if not broken:
        zc = base + size[2] / 2 - sink
        wblock(p, (x, y, zc), size, yaw=yaw, tilt=(r.uniform(-steep, steep), r.uniform(-steep, steep)),
               chips=r.randint(2, 3), face_chips=r.randint(1, 2), far=size[0] > 2.5)
        return [(x, y, max(size[0], size[1]) / 2, zc + size[2] / 2, size)]
    f = r.uniform(0.35, 0.6)
    parts = []
    d = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    gap = r.uniform(0.3, 1.2)
    for s, frac in ((-1, f), (1, 1.0 - f)):
        lx = size[0] * frac
        # The part's centre along the stone, the gap between, nudged off line.
        off = s * (size[0] / 2 - lx / 2 + gap / 2)
        c = (x + d.x * off, y + d.y * off + r.uniform(-0.4, 0.4))
        tz = r.uniform(-0.12, 0.12)
        psize = (lx, size[1], size[2])
        zc = base + psize[2] / 2 - sink + abs(tz) * lx * 0.3
        wblock(p, (c[0], c[1], zc), psize, yaw=yaw + r.uniform(-0.25, 0.25),
               tilt=(r.uniform(-steep, steep), tz), chips=2, face_chips=1, edge=-s,
               chip_depth=(0.3, 0.8), far=lx > 2.5)
        parts.append((c[0], c[1], max(lx, size[1]) / 2, zc + psize[2] / 2, psize))
    return parts


def build_broken():
    p = T.Piece("wall_broken", seed=seed + 100)
    p.ground = 0.0
    r = p.rng
    top = len(COURSES) - 1

    # Where each course ends: a ragged diagonal from the full-height stretch
    # at the left (x ~ -4.5 at the top) down to the plinth at the right end
    # of the bay; each course may jut past the trend by a stone or fall
    # short, but never overhangs the one below by more than 1.2 m.
    ends = []
    drift = 0.0
    for k, (z0, h) in enumerate(COURSES):
        f = (z0 + h) / T.COLUMN_H
        trend = HALF + 0.6 - f ** 0.85 * 15.0
        drift = drift * 0.5 + r.uniform(-1.8, 1.8)
        e = trend + drift
        if r.random() < 0.25:
            e += r.uniform(1.2, 2.6)          # a stone jutting out
        elif r.random() < 0.18:
            e -= r.uniform(1.5, 3.0)          # a bite out of the edge
        if k > 0:
            e = min(e, ends[-1] + 1.2)
        e = min(e, HALF + 1.5)
        ends.append(e)
    # The lowest courses run the bay.
    ends[0] = HALF + 0.2
    ends[1] = max(ends[1], HALF - 0.6)
    plan = list(ends)

    footing(p, -HALF, HALF)
    plinth(p, -HALF, ends[0])
    below = []
    for k in range(1, top + 1):
        x0 = -HALF + tooth(k)
        x1 = ends[k]
        if x1 - x0 < 1.6:
            ends[k] = x0
            below = []
            continue
        z0, h = COURSES[k]
        sp = spans(r, x0, x1, h, below)
        below = joints(sp)
        n = len(sp)
        for i, (a, b) in enumerate(sp):
            last = i == n - 1
            near_edge = b > x1 - 6.0
            rec = 0.0
            above = plan[k + 1] if k < top else -HALF
            if near_edge and not last and i > 0 and above < a - 0.3 and r.random() < 0.35:
                continue                      # gone, with nothing over it
            if near_edge and not last and r.random() < 0.25:
                rec = r.choice((-1, 1)) * r.uniform(0.5, 1.1)
            if last:
                # The stone at the broken end: slipped out a little, askew,
                # its end knocked about.
                dx = r.uniform(0.0, 0.3)
                yaw = r.uniform(-0.06, 0.06)
                tilt = (r.uniform(-0.035, 0.035), r.uniform(-0.05, 0.015))
                bl = b - a
                over = plan[k + 1] if k < top else -HALF
                if bl > 2.6 and over < a + bl * 0.5 and r.random() < 0.4:
                    bl *= r.uniform(0.55, 0.8)    # broken short
                wblock(p, (a + bl / 2 + dx, r.uniform(-0.1, 0.1), z0 + h / 2),
                       (bl - T.JOINT, WT + r.uniform(-0.12, 0.04), h - T.JOINT), yaw=yaw, tilt=tilt,
                       chips=2, face_chips=2, chip_depth=(0.3, 0.8), edge=1)
                ends[k] = a + bl + dx
            else:
                wall_stone(p, a, b, z0, h, recess=rec)

    # A few stones fallen onto the steps of the broken edge, lying askew.
    for k in range(2, top - 1):
        tread = ends[k] - max(ends[k + 1], -HALF + tooth(k + 1))
        if tread > 2.4 and r.random() < 0.45:
            z0, h = COURSES[k]
            sx = r.uniform(1.6, min(3.4, tread))
            sz = r.uniform(0.9, 1.6)
            x = ends[k] - tread / 2 + r.uniform(-0.3, 0.3)
            wblock(p, (x, r.uniform(-0.3, 0.3), z0 + h + sz / 2 - 0.03),
                   (sx, r.uniform(1.4, 2.2), sz), yaw=r.uniform(-0.4, 0.4),
                   tilt=(r.uniform(-0.08, 0.08), r.uniform(-0.1, 0.1)), chips=3, face_chips=1)

    # The fallen courses along both faces under the broken edge: whole and
    # broken wall stones, big first, a few spalls on and between them.
    placed = []

    def rest(x, y, rad):
        under = [t for (px, py, pr, t, _s) in placed if math.hypot(px - x, py - y) < pr + rad * 0.5]
        return max(under) * 0.8 if under else 0.0

    rubble = []
    for i in range(22):
        big = i < 13
        side = r.choice((-1, 1))
        x = r.triangular(-3.0, HALF + 4.5, 6.0)
        if big:
            ch = r.uniform(2.0, 2.6)
            size = (r.uniform(2.8, 6.0), ch, r.uniform(2.0, WT))   # on its face or its bed
            if r.random() < 0.5:
                size = (size[0], size[2], size[1])
        else:
            size = (r.uniform(0.7, 1.6), r.uniform(0.6, 1.3), r.uniform(0.4, 0.9))
        rad = max(size[0], size[1]) / 2
        y = side * (WT / 2 + 0.4 + rad * 0.5 + (r.random() ** 1.6) * 7.0)
        base = rest(x, y, rad)
        if big and base > 2.2:
            base = 0.0
            y += side * 2.5
        if big:
            parts = fallen(p, x, y, size, base, broken=r.random() < 0.4)
        else:
            sink = r.uniform(0.15, 0.4) * size[2] if base == 0.0 else r.uniform(0.0, 0.15)
            zc = base + size[2] / 2 - sink
            wblock(p, (x, y, zc), size, yaw=r.uniform(0, math.pi),
                   tilt=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)), bevel=0.08,
                   chips=r.randint(1, 3), face_chips=0, chip_depth=(0.15, 0.4))
            parts = [(x, y, rad, zc + size[2] / 2, size)]
        placed.extend(parts)
        if big:
            rubble.extend(parts)

    # The far LOD: each course to where it ends; the footing (above).
    for k in range(0, top + 1):
        z0, h = COURSES[k]
        x0 = -HALF + tooth(k)
        if ends[k] - x0 > 0.5:
            p.far_box(((x0 + ends[k]) / 2, 0.0, z0 + h / 2), (ends[k] - x0, WT if k else WT + 0.3, h))

    # The flight's solids: the wall in steps of two courses, each to the
    # mean end of its courses; the fallen stones on each face as one low box.
    y = WT / 2 + PLINTH_OUT
    for k in range(0, top + 1, 2):
        ks = range(k, min(k + 2, top + 1))
        e = sum(ends[j] for j in ks) / len(ks)
        z0 = COURSES[k][0] if k else -FOOTING
        z1 = COURSES[ks[-1]][0] + COURSES[ks[-1]][1]
        if e > -HALF + 0.5:
            p.solid((-HALF, -y, z0), (min(e, HALF + 1.5), y, z1))
    for side in (-1, 1):
        rs = [b for b in rubble if (b[1] > 0) == (side > 0)]
        if not rs:
            continue
        xs = [b[0] for b in rs]
        ys = [abs(b[1]) + b[2] * 0.6 for b in rs]
        tops = sorted(b[3] for b in rs)
        h = tops[int(len(tops) * 0.6)]
        ylo, yhi = WT / 2, max(ys)
        lo = (min(xs) - 1.0, ylo if side > 0 else -yhi, -0.5)
        hi = (max(xs) + 1.0, yhi if side > 0 else -ylo, h)
        p.solid(lo, hi)
    print("WALL broken: course ends " + " ".join(f"{e:.1f}" for e in ends)
          + f"; {len(rubble)} fallen stone parts, {len(placed)} pieces in all")
    p.export()


build_door()
build_broken()
