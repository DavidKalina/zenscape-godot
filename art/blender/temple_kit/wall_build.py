"""The temple kit's inner wall (lane wall): `wall_door`, one bay of coursed
wall with the tall doorway through it, and `wall_broken`, a wall end that
stands full height at one side and steps down to rubble at the other.

    python tools/blender.py run art/blender/temple_kit/wall_build.py [-- --seed=N]

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
PLINTH_H = 1.0                     # the plinth course at the foot
PLINTH_OUT = 0.15                  # how far it stands out of each face
TOOTH = 0.6                        # the courses' stagger at the bay ends

# ---- The course table, shared by both pieces ------------------------------
# The plinth, then 23 courses tall low and smaller higher (1.55 -> 1.02 m),
# to the column height (30.5).
N = 23
A = 1.55
B = 2.0 * (T.COLUMN_H - PLINTH_H) / N - A
COURSES = [(0.0, PLINTH_H)]
z = PLINTH_H
for i in range(N):
    h = A + (B - A) * i / (N - 1)
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
def wblock(p, center, size, yaw=0.0, tilt=(0.0, 0.0), bevel=0.07, chips=1, face_chips=1,
           chip_depth=(0.10, 0.38), jitter=0.012, tone=None, far=False, kind=T.FACE,
           edge=None, boss=0.0):
    """A cut block like T.Piece.block. `face_chips` corners are knocked off
    the faces that show (+-y) at their arrises; `edge` (+1 or -1) forces one
    chip on that x end (a door reveal, a broken end)."""
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
        b = min(bevel * r.uniform(0.7, 1.5), 0.3 * min(size))
        res = bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=1,
                              profile=0.5, affect="EDGES", clamp_overlap=True)
        for f in res["faces"]:
            f[tk] = T.JOINTFACE
            f[tt] = t
    if boss > 0.0:
        # Each wall face as a dressed panel inside a drafted margin: the
        # panel stands out a few cm, a little out of true, so a raking
        # light draws the margin round every stone.
        faces = [f for f in tmp.faces if abs(f.normal.y) > 0.9 and f.calc_area() > 0.2]
        for f in faces:
            m = min(r.uniform(0.07, 0.14), 0.25 * min(sx, sz))
            res = bmesh.ops.inset_individual(tmp, faces=[f], thickness=m, depth=boss * r.uniform(0.5, 1.2))
            for g in res["faces"]:
                g[tk] = T.JOINTFACE
                g[tt] = t
            for v in f.verts:
                v.co.y += math.copysign(r.uniform(-0.6, 0.6) * boss, f.normal.y)
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
        d = r.uniform(*chip_depth) * min(1.0, min(size) / 0.8)
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


def wall_stone(p, x0, x1, z0, h, recess=0.0, edge=None, out=0.0, **kw):
    """One stone of the wall face between x0 and x1, a course of height h
    from z0: its two faces set proud or back a few cm each, a weathered one
    recessed more; `recess` (m, sign = which face) leaves only the back
    leaf, as if its face stone had fallen out."""
    r = p.rng
    L = x1 - x0
    front = r.uniform(-0.045, 0.045) + out
    back = r.uniform(-0.045, 0.045) + out
    if r.random() < 0.12:
        front -= r.uniform(0.08, 0.16)       # a soft bed, eroded back
    if r.random() < 0.12:
        back -= r.uniform(0.08, 0.16)
    if recess > 0:
        front -= recess
    elif recess < 0:
        back += recess
    depth = WT + front + back
    cy = (front - back) / 2
    yaw = r.uniform(-0.006, 0.006)
    tilt = (r.uniform(-0.006, 0.006), r.uniform(-0.004, 0.004))
    wblock(p, ((x0 + x1) / 2, cy, z0 + h / 2), (L - T.JOINT, depth, h - T.JOINT),
           yaw=yaw, tilt=tilt, chips=r.randint(0, 1), face_chips=r.choice((1, 1, 2, 3)),
           chip_depth=(0.18, 0.55), edge=edge, boss=kw.pop("boss", r.uniform(0.025, 0.05)), **kw)


def lay_course(p, k, x0, x1, recess_at=None, skip=(), length=None, last_edge=None):
    """Course k's stones from x0 to x1, lengths in proportion to the course
    height (bigger stones low). `recess_at` is a set of stone indices that
    lose their face leaf; `skip` stones missing outright. Returns the
    stones' x spans."""
    r = p.rng
    z0, h = COURSES[k]
    lo, hi = length or (h * 1.7, h * 2.8)
    spans = []
    x = x0
    while x < x1 - 0.3:
        L = min(r.uniform(lo, hi), x1 - x)
        if x1 - (x + L) < 0.8:
            L = x1 - x
        spans.append((x, x + L))
        x += L
    for i, (a, b) in enumerate(spans):
        if i in skip:
            continue
        rec = 0.0
        if recess_at and i in recess_at:
            rec = r.choice((-1, 1)) * r.uniform(0.35, 0.9)
        wall_stone(p, a, b, z0, h, recess=rec, edge=last_edge if i == len(spans) - 1 else None)
    return spans


def plinth(p, x0, x1):
    """The plinth course: long low stones standing out of both faces."""
    r = p.rng
    x = x0
    while x < x1 - 0.3:
        L = min(r.uniform(3.0, 4.6), x1 - x)
        if x1 - (x + L) < 1.0:
            L = x1 - x
        dy = r.uniform(-0.03, 0.03)
        wblock(p, (x + L / 2, dy, PLINTH_H / 2), (L - T.JOINT, WT + 2 * PLINTH_OUT, PLINTH_H - T.JOINT),
               bevel=0.1, chips=r.randint(1, 2), face_chips=r.randint(1, 2), chip_depth=(0.12, 0.3))
        x += L


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
    # out a little from the wall and chipped at the reveal.
    for k in range(1, L):
        z0, h = COURSES[k]
        e = HALF + tooth(k)
        for s in (-1, 1):
            a, b = (-e, -dw) if s < 0 else (dw, e)
            # The reveal is the left quoin's +x end, the right one's -x end.
            wall_stone(p, a, b, z0, h, out=0.035, edge=-s)
    # The lintel: one massive block over the opening, bearing on both jambs.
    wblock(p, (0.0, r.uniform(-0.02, 0.02), lintel_z + lintel_h / 2),
           (2 * lintel_x - T.JOINT, WT + 0.12, lintel_h - T.JOINT),
           bevel=0.1, chips=3, face_chips=4, chip_depth=(0.15, 0.45), jitter=0.015, boss=0.05)
    for k in (L, L + 1):
        if tooth(k) > 0:
            z0, h = COURSES[k]
            for s in (-1, 1):
                a, b = sorted((s * lintel_x, s * (HALF + tooth(k))))
                wall_stone(p, a, b, z0, h)
    # Over the lintel to the top: full courses, a face stone fallen out of
    # one and a stone or two gone from the top.
    top = len(COURSES) - 1
    gone = {}
    for k in range(L + 2, top + 1):
        e = HALF + tooth(k)
        recess = {2} if k == L + 3 else ({4} if k == L + 5 else None)
        skip = ()
        if k == top:
            skip = (2, 3)
        elif k == top - 1:
            skip = (3,)
        spans = lay_course(p, k, -e, e, recess_at=recess, skip=skip)
        if k == top or k == top - 1:
            gone[k] = [s for i, s in enumerate(spans) if i not in skip]

    # The far LOD: the jambs, the band over the door, the top courses by
    # their stones (so the missing ones stay notches), the plinth, footing.
    far_top = COURSES[top - 1][0]
    for s in (-1, 1):
        p.far_box((s * (HALF + dw) / 2, 0.0, lintel_z / 2), (HALF - dw, WT + 0.1, lintel_z))
    p.far_box((0.0, 0.0, (lintel_z + far_top) / 2), (2 * HALF, WT, far_top - lintel_z))
    for k, spans in gone.items():
        z0, h = COURSES[k]
        for a, b in spans:
            p.far_box(((a + b) / 2, 0.0, z0 + h / 2), (b - a, WT, h))

    # The flight's solids: two jambs, the band over the door, the footing
    # under the threshold. The doorway itself is open.
    y = WT / 2 + PLINTH_OUT
    p.solid((-HALF, -y, -FOOTING), (-dw, y, lintel_z))
    p.solid((dw, -y, -FOOTING), (HALF, y, lintel_z))
    p.solid((-HALF, -y, lintel_z), (HALF, y, T.COLUMN_H))
    p.solid((-dw, -y, -FOOTING), (dw, y, 0.0))
    print(f"WALL door: clear {2 * dw:.2f} wide x {lintel_z:.2f} high, lintel {2 * lintel_x:.2f} x {lintel_h:.2f}")
    p.export()


# ---- wall_broken ----------------------------------------------------------
def build_broken():
    p = T.Piece("wall_broken", seed=seed + 100)
    p.ground = 0.0
    r = p.rng
    top = len(COURSES) - 1

    # Where each course ends: a ragged diagonal from the full-height stretch
    # at the left (x -5.5 at the top) down to a few courses at the right
    # end of the bay; each course may jut past the trend or fall short,
    # but never overhangs the one below by more than 0.7 m.
    ends = []
    drift = 0.0
    for k, (z0, h) in enumerate(COURSES):
        f = (z0 + h) / T.COLUMN_H
        trend = HALF + 0.6 - f ** 0.85 * 15.5
        drift = drift * 0.6 + r.uniform(-1.6, 1.6)
        e = trend + drift
        if r.random() < 0.22:
            e += r.uniform(0.8, 2.0)          # a stone jutting out
        elif r.random() < 0.15:
            e -= r.uniform(1.0, 2.5)          # a bite out of the edge
        if k > 0:
            e = min(e, ends[-1] + 0.7)
        e = min(e, HALF + 1.5)
        ends.append(e)
    # The lowest courses run the bay and end in a few loose stones.
    ends[0] = HALF + 0.2
    ends[1] = max(ends[1], HALF - 0.4)
    plan = list(ends)

    footing(p, -HALF, HALF)
    plinth(p, -HALF, ends[0])
    for k in range(1, top + 1):
        x0 = -HALF + tooth(k)
        x1 = ends[k]
        if x1 - x0 < 0.8:
            ends[k] = x0
            continue
        spans = []
        x = x0
        z0, h = COURSES[k]
        lo, hi = h * 1.7, h * 2.8
        while x < x1 - 0.3:
            Lg = min(r.uniform(lo, hi), x1 - x)
            if x1 - (x + Lg) < 0.8:
                Lg = x1 - x
            spans.append((x, x + Lg))
            x += Lg
        n = len(spans)
        for i, (a, b) in enumerate(spans):
            last = i == n - 1
            near_edge = b > x1 - 4.0
            rec = 0.0
            above = plan[k + 1] if k < top else -HALF
            if near_edge and not last and i > 0 and above < a - 0.3 and r.random() < 0.3:
                continue                      # gone, with nothing over it
            if near_edge and not last and r.random() < 0.22:
                rec = r.choice((-1, 1)) * r.uniform(0.4, 1.0)
            if last:
                # The stone at the broken end: slipped out a little, askew,
                # its end knocked about.
                dx = r.uniform(0.0, 0.25)
                yaw = r.uniform(-0.07, 0.07)
                tilt = (r.uniform(-0.04, 0.04), r.uniform(-0.06, 0.02))
                bl = b - a
                over = plan[k + 1] if k < top else -HALF
                if bl > 1.6 and over < a + bl * 0.5 and r.random() < 0.35:
                    bl *= r.uniform(0.55, 0.8)    # broken short
                wblock(p, (a + bl / 2 + dx, r.uniform(-0.08, 0.08), z0 + h / 2),
                       (bl - T.JOINT, WT + r.uniform(-0.1, 0.04), h - T.JOINT), yaw=yaw, tilt=tilt,
                       chips=2, face_chips=2, chip_depth=(0.15, 0.45), edge=1)
                ends[k] = a + bl + dx
            else:
                wall_stone(p, a, b, z0, h, recess=rec)

    # A few stones fallen onto the steps of the broken edge, lying askew.
    for k in range(2, top - 1):
        tread = ends[k] - max(ends[k + 1], -HALF + tooth(k))
        if tread > 1.4 and r.random() < 0.4:
            z0, h = COURSES[k]
            sx = r.uniform(0.9, min(2.2, tread))
            sz = r.uniform(0.5, 0.9)
            x = ends[k] - tread / 2 + r.uniform(-0.3, 0.3)
            wblock(p, (x, r.uniform(-0.4, 0.4), z0 + h + sz / 2 - 0.03),
                   (sx, r.uniform(1.0, 1.8), sz), yaw=r.uniform(-0.5, 0.5),
                   tilt=(r.uniform(-0.12, 0.12), r.uniform(-0.15, 0.15)), chips=3, face_chips=1,
                   chip_depth=(0.1, 0.3))

    # The rubble: the fallen courses heaped along both faces under the
    # broken edge, the bigger stones first, smaller ones on and between.
    placed = []

    def rest(x, y, rad):
        under = [t for (px, py, pr, t) in placed if math.hypot(px - x, py - y) < pr + rad * 0.6]
        return max(under) * 0.82 if under else 0.0

    rubble = []
    for i in range(84):
        big = i < 46
        side = r.choice((-1, 1))
        x = r.triangular(-4.5, HALF + 3.5, 5.0)
        if big:
            size = (r.uniform(1.6, 3.2), r.uniform(1.1, 2.4), r.uniform(0.9, 1.4))
        else:
            size = (r.uniform(0.45, 1.3), r.uniform(0.4, 1.1), r.uniform(0.3, 0.8))
        rad = max(size[0], size[1]) / 2
        y = side * (WT / 2 + 0.25 + rad * 0.5 + (r.random() ** 2.0) * 5.5)
        base = rest(x, y, rad)
        sink = r.uniform(0.15, 0.45) * size[2] if base == 0.0 else r.uniform(0.0, 0.25)
        zc = base + size[2] / 2 - sink
        steep = 0.12 if base == 0.0 else 0.4
        tilt = (r.uniform(-steep, steep), r.uniform(-steep, steep))
        wblock(p, (x, y, zc), size, yaw=r.uniform(0, math.pi), tilt=tilt, bevel=0.06,
               chips=r.randint(1, 3) if big else r.randint(0, 2), face_chips=0, chip_depth=(0.12, 0.4),
               far=big and size[0] > 2.0)
        top_z = zc + size[2] / 2
        placed.append((x, y, rad, top_z))
        if big:
            rubble.append((x, y, size, top_z))

    # The far LOD: each course to where it ends; the footing (above).
    for k in range(0, top + 1):
        z0, h = COURSES[k]
        x0 = -HALF + tooth(k)
        if ends[k] - x0 > 0.5:
            p.far_box(((x0 + ends[k]) / 2, 0.0, z0 + h / 2), (ends[k] - x0, WT if k else WT + 0.3, h))

    # The flight's solids: the wall in steps of three courses, each to the
    # mean end of its courses; the rubble on each face as one low box.
    y = WT / 2 + PLINTH_OUT
    for k in range(0, top + 1, 3):
        ks = range(k, min(k + 3, top + 1))
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
        ys = [abs(b[1]) + max(b[2][0], b[2][1]) * 0.3 for b in rs]
        tops = sorted(b[3] for b in rs)
        h = tops[int(len(tops) * 0.6)]
        ylo, yhi = WT / 2, max(ys)
        lo = (min(xs) - 0.5, ylo if side > 0 else -yhi, -0.5)
        hi = (max(xs) + 0.5, yhi if side > 0 else -ylo, h)
        p.solid(lo, hi)
    print("WALL broken: course ends " + " ".join(f"{e:.1f}" for e in ends))
    p.export()


build_door()
build_broken()
