"""The temple kit's amphitheatre (lane arena): the bays of a ruined oval
arena, in the kit's stone (temple_lib).

    python tools/blender.py run art/blender/temple_kit/arena_build.py [-- --only=arena_outer]

The oval (scripts/endless/arena_site.gd lays it) is four arcs: the two ends
(radius R_B, 7 bays each) and the two sides (radius R_A, 8 bays each), every
bay W*2 wide on the outer wall's line. A bay is a wedge between two radial
lines; each piece is one bay's part of a ring and holds its half piers.

Frame (Blender, z up): x along the wall, +y inward (toward the arena), the
origin on the outer wall's middle line at the datum (the floor's level).
Inward, by y: the outer wall -2.5..2.5, the ring corridor 2.5..18.5, the
inner wall 18.5..21.5, the seating 21.5..39.5, then the arena.

Pieces (`_a` the sides' wedge, `_b` the ends'):
- `arena_outer`: the outer wall's ground tier: half piers, an arch 14.5 m
  wide with its crown 15.25 m up, courses to the cornice at 22 m.
- `arena_outer_broken`: the same snapped: the -x half pier and a stub of
  arch and courses, ragged (turned half round for the other hand).
- `arena_upper`, `arena_upper_broken`: the second tier, standing on the
  first (origin at its foot, 22 m up): arch 14.5 m wide, crown 12.75 m over
  the terrace, top 16 m.
- `arena_inner_a/b`: the corridor's inner wall: an arch 13 m (a) or 10.2 m
  (b) wide, crown 14.5 m, the wall up to the terrace.
- `arena_vault_a/b`: the corridor's vault (16 m across, 16 m at the walls
  and 20 m at the crown) and the terrace over it at 22 m.
- `arena_vault_broken_a/b`: what is left of it along the outer wall.
- `arena_seats_a/b`: the seating: nine steps down from 17 m by the inner
  wall to the arena's wall (5 m), its flanks and back.
- `arena_seats_broken_a/b`: the top four steps, the rest down.
- `arena_fallen`: a bay of the upper wall lying where it fell, its foot at
  the origin and its top toward -y, a little off the ground at that end.
Each has a mid LOD (`<id>_mid.glb`): the same stones, uncut.
"""

import math
import random
import sys

import bmesh
from mathutils import Matrix, Vector

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

# ---- The oval (arena_site.gd holds the same numbers) -----------------------
PHI = math.atan2(4.0, 3.0)          # where an end's arc meets a side's
H_B = PHI / 7                       # half a bay's angle at an end
H_A = (math.pi / 2 - PHI) / 8       # and on a side
R_B = 72.0                          # the outer wall's line, the ends' radius
R_A = R_B * math.tan(H_B) / math.tan(H_A)   # 119.0: the sides', so the bays match
W = R_B * math.tan(H_B)             # 9.594: half a bay on the outer line
VAR = {"a": R_A, "b": R_B}
R_WALL = 90.0                       # the outer wall's one wedge (both arcs)

ARCH_R = 7.25                       # the outer arches, 14.5 clear
TIER = 22.0                         # the ground tier's top, the terrace
SPRING = 8.0
UP_SPRING = 5.5
UP_TOP = 16.0
FOOT = -6.0                         # footings under the datum
OUT_T = 5.0                         # the outer wall's thickness
IN_Y = 20.0                         # the inner wall's middle
IN_T = 3.0
IN_R = {"a": 6.5, "b": 5.1}
V_Y0, V_Y1 = 2.5, 18.5              # the corridor
V_R = 10.0                          # the vault's radius, its centre at z V_ZC
V_ZC = 10.0
S_Y0 = 21.5                         # the seating's back
S_TOP_Y = 22.5                      # the top step's back edge
S_TOP = 17.0
S_STEPS = 9
S_TREAD = 1.8
S_RISE = 1.5
S_END = S_TOP_Y + S_TREAD * S_STEPS  # 38.7
S_WALL = 39.5                       # the arena wall's face
S_KEEP = 4                          # the broken bank's steps


def piece(name, seed, mid, ground=0.0):
    p = T.Piece(name, seed=seed)
    p.lay = random.Random(seed * 7 + 1)   # the stones' layout, the same near and mid
    p.mid = mid
    p.ground = ground
    return p


def blk(p, c, s, chips=1, **kw):
    """A block; in the mid LOD the same stone uncut."""
    kw.setdefault("tone", p.lay.uniform(0.9, 1.05))
    if p.mid:
        keep = {k: v for k, v in kw.items() if k in ("yaw", "tilt", "tone", "hide", "seen")}
        p.block(c, s, bevel=0.0, chips=0, jitter=0.0, far=False, **keep)
    else:
        p.block(c, s, chips=chips, far=False, **kw)


def row(p, x0, x1, z, h, depth, y, length=(2.6, 4.6), chips=1, end_chips=None, **kw):
    """A course along x from x0 to x1, its foot at z."""
    x = x0
    while x < x1 - 0.3:
        L = min(p.lay.uniform(*length), x1 - x)
        if x1 - (x + L) < 1.1:
            L = x1 - x
        last = x + L >= x1 - 1e-6
        c = end_chips if (last and end_chips is not None) else p.lay.randint(0, chips)
        blk(p, (x + L / 2, y + p.lay.uniform(-0.03, 0.03), z + h / 2), (L - T.JOINT, depth, h - T.JOINT), chips=c, **kw)
        x += L


def voussoir(p, th, R, ring, n, spring, depth, y, chips):
    """One wedge of an arch's ring at angle th (from +x, up)."""
    rm = R + ring / 2
    tang = rm * math.pi / n - T.JOINT
    real = p.near
    tmp = bmesh.new()
    T._layers(tmp)
    p.near = tmp
    blk(p, (0, 0, 0), (ring - 0.02, depth, tang), chips=chips, chip_depth=(0.1, 0.35))
    p.near = real
    for v in tmp.verts:
        v.co.z *= (rm + v.co.x) / rm
    m = Matrix.Translation((rm * math.cos(th), y, spring + rm * math.sin(th))) @ Matrix.Rotation(-th, 4, "Y")
    T._append(real, tmp, m)
    tmp.free()


def arch_slices(R, spring, step, x_lo=None, x_hi=None):
    """[(xa, xb, bottom)]: an opening's soffit as boxes, each one's bottom
    the soffit's lowest over it."""
    x_lo = -R if x_lo is None else x_lo
    x_hi = R if x_hi is None else x_hi
    xs = [R * math.cos(math.radians(a)) for a in range(0, 91, step)]
    out = []
    for k in range(len(xs) - 1):
        a, b = xs[k + 1], xs[k]
        z = spring + math.sqrt(max(0.0, R * R - b * b))
        out.append((a, b, z))
        out.append((-b, -a, z))
    return [(max(a, x_lo), min(b, x_hi), z) for a, b, z in out if min(b, x_hi) > max(a, x_lo) + 0.05]


def taper(p, R, y0):
    """Makes the piece its bay's wedge: built `half` wide at y0, every x
    scaled by its y's share of the radius. The solids take the wider end."""
    for bm in (p.near, p.far):
        for v in bm.verts:
            v.co.x *= (R - v.co.y) / (R - y0)
    out = []
    for lo, hi in p.boxes:
        f0 = (R - lo[1]) / (R - y0)
        f1 = (R - hi[1]) / (R - y0)
        out.append(((min(lo[0] * f0, lo[0] * f1), lo[1], lo[2]), (max(hi[0] * f0, hi[0] * f1), hi[1], hi[2])))
    p.boxes = out


def wall_bay(p, yc, depth, half, Ra, spring, top, foot, ring=1.4, n=17, cornice=0.8, pil=True, broken=False):
    """One bay of an arched wall: half piers at x -half and half, the arch
    between, courses to `top`. `broken`: the -x half pier and a ragged stub."""
    ya, yb = yc - depth / 2, yc + depth / 2
    span_top = top - cornice
    ncourse = max(1, round((span_top - spring) / 1.65))
    ch = (span_top - spring) / ncourse
    RE = Ra + ring
    pw = half - Ra
    lay = p.lay

    def ext_half(zt):
        d = zt - spring
        return math.sqrt(max(0.0, RE * RE - d * d))

    def stand(x):
        """How high the broken wall stands at x."""
        return spring + 0.8 * (span_top - spring) * min(1.0, max(0.0, (-x - 3.0) / (half - 3.0)))

    def reach(z):
        t = max(0.0, (z - spring) / (span_top - spring))
        return -3.0 - (half - 3.0) * t / 0.8

    sides = (-1,) if broken else (-1, 1)
    for s in sides:
        xc = s * (Ra + half) / 2
        if foot < 0:
            blk(p, (xc, yc, foot / 2), (pw, depth + 0.3, -foot), chips=0, hide=("-z",))
        npier = max(1, round((spring - 0.7) / 2.0))
        ph = (spring - 0.7) / npier
        for k in range(npier):
            blk(p, (xc + lay.uniform(-0.03, 0.03), yc, (k + 0.5) * ph), (pw - T.JOINT, depth - T.JOINT, ph - T.JOINT),
                chips=lay.randint(0, 2))
        blk(p, (xc, yc, spring - 0.35), (pw - T.JOINT, depth + 0.5, 0.7), chips=2)
    for i in range(n):
        th = math.pi * (i + 0.5) / n
        if broken and th < math.radians(122):
            continue
        edge = broken and th < math.radians(133)
        voussoir(p, th, Ra, ring, n, spring, depth - 0.04 - (0.6 if edge else 0.0), yc, 3 if edge else lay.randint(0, 2))
    for k in range(ncourse):
        zb = spring + k * ch
        zt = zb + ch
        w = ext_half(zt)
        if broken:
            xr = reach(zb) + lay.uniform(-0.8, 0.5)
            x_end = min(-w, xr) if w > 0.05 else xr
            if x_end > -half + 0.9:
                row(p, -half, x_end, zb, ch, depth, yc, end_chips=3)
            continue
        if w > 0.05:
            row(p, -half, -w, zb, ch, depth, yc)
            row(p, w, half, zb, ch, depth, yc)
        else:
            row(p, -half, half, zb, ch, depth, yc)
    if not broken and cornice > 0.0:
        row(p, -half, half, span_top, cornice, depth + 0.5, yc, length=(3.0, 5.0), chips=2)
    if pil:
        # A flat pilaster on the outer face at each bay's edge (half of it here).
        for s in sides:
            z_end = span_top if not broken else stand(-half + 0.6) - 1.0
            z = 0.0
            while z < z_end - 0.5:
                hh = min(lay.uniform(3.0, 4.2), z_end - z)
                if z_end - (z + hh) < 1.2:
                    hh = z_end - z
                blk(p, (s * (half - 0.6), ya - 0.2, z + hh / 2), (1.2 - T.JOINT, 0.6, hh - T.JOINT), chips=lay.randint(0, 2),
                    hide=("+y",))
                z += hh
            p.far_box((s * (half - 0.6), ya - 0.2, z_end / 2), (1.2, 0.6, z_end))
    # The far LOD and the solids.
    for s in sides:
        xc = s * (Ra + half) / 2
        z_top = span_top if not broken else stand(xc)
        p.far_box((xc, yc, (foot + z_top) / 2), (pw, depth, z_top - foot))
        p.solid((min(s * Ra, s * half), ya, foot), (max(s * Ra, s * half), yb, top if not broken else z_top))
    x_hi = -3.0 if broken else None
    for a, b, z in arch_slices(Ra, spring, 30, x_hi=x_hi):
        z_top = span_top if not broken else stand((a + b) / 2)
        if z_top > z + 0.4:
            p.far_box(((a + b) / 2, yc, (z + z_top) / 2), (b - a, depth, z_top - z))
    for a, b, z in arch_slices(Ra, spring, 15, x_hi=x_hi):
        z_top = top if not broken else stand(a)
        if z_top > z + 0.4:
            p.solid((a, ya, z), (b, yb, z_top))
    if not broken and cornice > 0.0:
        p.far_box((0, yc, top - cornice / 2), (2 * half, depth + 0.5, cornice))


def build_outer(p, broken=False):
    wall_bay(p, 0.0, OUT_T, W, ARCH_R, SPRING, TIER, FOOT, broken=broken)
    taper(p, R_WALL, 0.0)


def build_upper(p, broken=False):
    wall_bay(p, 0.0, OUT_T, W, ARCH_R, UP_SPRING, UP_TOP, 0.0, broken=broken)
    taper(p, R_WALL, 0.0)


def build_inner(p, var):
    R = VAR[var]
    half = W * (R - IN_Y) / R
    wall_bay(p, IN_Y, IN_T, half, IN_R[var], SPRING, TIER, FOOT, ring=1.2, n=15, pil=False)
    taper(p, R, IN_Y)


def build_vault(p, var, broken=False):
    R = VAR[var]
    y0 = (V_Y0 + V_Y1) / 2
    half = W * (R - y0) / R
    lay = p.lay
    ring = 1.0
    N = 9
    phi = math.asin((V_Y1 - V_Y0) / 2 / V_R)
    rm = V_R + ring / 2
    width = 2 * V_R * math.tan(phi / N)
    keep = 3 if broken else N
    for i in range(keep):
        th = -phi + (i + 0.5) * 2 * phi / N
        L = 2 * half / 4
        cuts = [-half] + [x for x in (-half + (i % 2) * L / 2 + L * j for j in range(1, 5)) if x < half - 0.5] + [half]
        edge = broken and i == keep - 1
        for xa, xb in zip(cuts[:-1], cuts[1:]):
            if edge and lay.random() < 0.4:
                continue
            blk(p, ((xa + xb) / 2, y0 + rm * math.sin(th), V_ZC + rm * math.cos(th)), (xb - xa - T.JOINT, width - T.JOINT, ring),
                tilt=(-th, 0.0), chips=3 if edge else lay.randint(0, 1))
    # The terrace's slabs and the fill under its edges.
    ys = [V_Y0, 6.5, 10.5, 14.5, V_Y1]
    for k in range(1 if broken else 4):
        row(p, -half, half, TIER - 1.0, 1.0, ys[k + 1] - ys[k] - T.JOINT, (ys[k] + ys[k + 1]) / 2, length=(4.0, 6.0),
            chips=3 if broken else 1)
    for yc in ((V_Y0 + 1.35,) if broken else (V_Y0 + 1.35, V_Y1 - 1.35)):
        row(p, -half, half, 19.2, 1.8, 2.7, yc, length=(5.0, 8.0), chips=0, hide=("+z",))
    if broken:
        p.far_box((0, (V_Y0 + 7.0) / 2, 19.5), (2 * half, 7.0 - V_Y0, 5.0))
        edges = [V_Y0, 4.0, 6.0, 7.5]
    else:
        p.far_box((0, y0, 20.5), (2 * half, V_Y1 - V_Y0, 3.0))
        p.far_box((0, V_Y0 + 1.25, 17.75), (2 * half, 2.5, 2.5))
        p.far_box((0, V_Y1 - 1.25, 17.75), (2 * half, 2.5, 2.5))
        edges = [V_Y0, 4.0, 6.0, 8.5, 12.5, 15.0, 17.0, V_Y1]
    for ya, yb in zip(edges[:-1], edges[1:]):
        far = max(abs(ya - y0), abs(yb - y0))
        z = V_ZC + math.sqrt(max(0.0, V_R * V_R - far * far))
        p.solid((-half, ya, z), (half, yb, TIER))
    taper(p, R, y0)


def build_seats(p, var, broken=False):
    R = VAR[var]
    y0 = (S_Y0 + S_WALL) / 2
    half = W * (R - y0) / R
    lay = p.lay
    steps = S_KEEP if broken else S_STEPS
    # The back wall, seen through the inner wall's arch.
    blk(p, (0, S_Y0 + 0.55, FOOT / 2), (2 * half, 0.9, -FOOT), chips=0, hide=("-z", "+y"))
    for c in range(5):
        row(p, -half, half, c * 3.4, 3.4, 0.9, S_Y0 + 0.55, length=(4.0, 6.5), hide=("+y",))
    p.far_box((0, S_Y0 + 0.5, (FOOT + S_TOP) / 2), (2 * half, 1.0, S_TOP - FOOT))
    p.solid((-half, S_Y0 + 0.1, FOOT), (half, S_TOP_Y, S_TOP))
    # The steps.
    for k in range(steps):
        ya = S_TOP_Y + S_TREAD * k
        zt = S_TOP - S_RISE * k
        edge = broken and k == steps - 1
        x1 = half * lay.uniform(-0.1, 0.5) if edge else half
        row(p, -half, x1, zt - 1.6, 1.6, S_TREAD + 0.25, ya + S_TREAD / 2 - 0.12, length=(3.5, 6.0), chips=2,
            end_chips=3 if edge else None, hide=() if edge else ("-z", "-y"))
        p.far_box(((x1 - half) / 2, ya + S_TREAD / 2, (zt - 2.0) / 2), (x1 + half, S_TREAD, zt + 2.0), tone=lay.uniform(0.9, 1.05))
        p.solid((-half, ya, FOOT), (x1, ya + S_TREAD, zt))
    y_end = S_TOP_Y + S_TREAD * steps
    # The flanks: courses under the steps' ends, on the bay's radial sides.
    for s in (-1, 1):
        blk(p, (s * (half - 0.6), (S_TOP_Y + y_end) / 2, FOOT / 2), (1.2, y_end - S_TOP_Y, -FOOT), chips=0,
            hide=("-z", "+z"))
        z = 0.0
        while z < S_TOP - 1.6 - 0.2:
            k_last = min(steps - 1, int((S_TOP - 1.6 - z) / S_RISE))
            ye = S_TOP_Y + S_TREAD * (k_last + 1)
            hh = min(S_RISE, S_TOP - 1.6 - z)
            y = S_TOP_Y
            while y < ye - 0.3:
                L = min(lay.uniform(3.6, 5.6), ye - y)
                if ye - (y + L) < 1.4:
                    L = ye - y
                blk(p, (s * (half - 0.6), y + L / 2, z + hh / 2), (1.2, L - T.JOINT, hh - T.JOINT), chips=lay.randint(0, 1),
                    hide=("-z", "-x" if s > 0 else "+x"))
                y += L
            z += hh
    if broken:
        # The break: a ragged face under the last step left.
        zt = S_TOP - S_RISE * (steps - 1) - 1.6
        n = 4
        for c in range(n):
            row(p, -half + 1.2, half - 1.2, c * zt / n, zt / n, lay.uniform(1.0, 2.2), y_end - 0.9 + lay.uniform(-0.3, 0.5),
                length=(3.0, 5.5), chips=3, end_chips=3)
    else:
        # The arena's wall and its cap.
        blk(p, (0, (S_END + S_WALL) / 2, FOOT / 2), (2 * half, S_WALL - S_END, -FOOT), chips=0, hide=("-z", "-y"))
        for c in range(3):
            row(p, -half, half, c * 5.0 / 3, 5.0 / 3, S_WALL - S_END, (S_END + S_WALL) / 2, length=(3.5, 6.0), chips=2,
                hide=("-y",))
        row(p, -half, half, 5.0, 0.7, 1.1, S_WALL - 0.5, length=(2.5, 4.0), chips=2)
        p.far_box((0, (S_END + S_WALL) / 2, (FOOT + 5.7) / 2), (2 * half, S_WALL - S_END, 5.7 - FOOT))
        p.solid((-half, S_END, FOOT), (half, S_WALL, 5.7))
    taper(p, R, y0)


def tumble(p, m):
    """Lays the built piece over by `m`; its solids cut into slices so
    their boxes stay close."""
    for bm in (p.near, p.far):
        bmesh.ops.transform(bm, matrix=m, verts=list(bm.verts))
    out = []
    for lo, hi in p.boxes:
        z = lo[2]
        while z < hi[2] - 0.01:
            z1 = min(z + 2.5, hi[2])
            cs = [m @ Vector((x, y, zz)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for zz in (z, z1)]
            out.append((tuple(min(c[i] for c in cs) for i in range(3)), tuple(max(c[i] for c in cs) for i in range(3))))
            z = z1
    p.boxes = out


def build_fallen(p):
    wall_bay(p, 0.0, OUT_T, W, ARCH_R, UP_SPRING, UP_TOP, 0.0, pil=False, cornice=0.0)
    lean = math.radians(83.0)
    rise = OUT_T / 2 * math.sin(lean) - 0.7
    tumble(p, Matrix.Translation((0.0, 0.0, rise)) @ Matrix.Rotation(lean, 4, "X"))


JOBS = {
    "arena_outer": (41, lambda p: build_outer(p), 0.0),
    "arena_outer_broken": (42, lambda p: build_outer(p, True), 0.0),
    "arena_upper": (43, lambda p: build_upper(p), -100.0),
    "arena_upper_broken": (44, lambda p: build_upper(p, True), -100.0),
    "arena_inner_a": (45, lambda p: build_inner(p, "a"), 0.0),
    "arena_inner_b": (46, lambda p: build_inner(p, "b"), 0.0),
    "arena_vault_a": (47, lambda p: build_vault(p, "a"), -100.0),
    "arena_vault_b": (48, lambda p: build_vault(p, "b"), -100.0),
    "arena_vault_broken_a": (49, lambda p: build_vault(p, "a", True), -100.0),
    "arena_vault_broken_b": (50, lambda p: build_vault(p, "b", True), -100.0),
    "arena_seats_a": (51, lambda p: build_seats(p, "a"), 0.0),
    "arena_seats_b": (52, lambda p: build_seats(p, "b"), 0.0),
    "arena_seats_broken_a": (53, lambda p: build_seats(p, "a", True), 0.0),
    "arena_seats_broken_b": (54, lambda p: build_seats(p, "b", True), 0.0),
    "arena_fallen": (55, lambda p: build_fallen(p), 0.0),
}

for name, (seed, fn, ground) in JOBS.items():
    if only is None or only == name:
        for mid in (False, True):
            p = piece(name, seed, mid, ground)
            fn(p)
            p.export(mid_of=name if mid else None)
