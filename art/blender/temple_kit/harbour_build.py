"""The temple kit's ruined harbour (lane harbour): the sea gate astride its
mouth and its fallen stone, the moles, the quay and the ship sheds, in the
kit's stone (temple_lib). scripts/endless/harbour_site.gd lays them in the
cove on the inland sea's west shore. The columns standing in the water are
the kit's own.

    python tools/blender.py run art/blender/temple_kit/harbour_build.py [-- --only=harbour_gate]

Every piece's origin is at the sea's level (Blender z 0), so the site lays
them all at LandField.SEA_Y. Blender frame, z up; Godot (x, y, z) = Blender
(x, z, -y).

Pieces:
- `harbour_gate`: two hollow towers GX either side of the origin along x,
  from the bed (FOOT) up battered bases to BASE_TOP, then shafts 2 SH_X wide
  with string courses, slits and an arcade at the top stage; the north (+x)
  one to N_TOP with its cornice and a beacon platform's stump, the south one
  broken off ragged near S_BREAK. One arch of radius R springs from their
  inner faces at YS (crown R + YS over the water), voussoirs three across,
  an archivolt and a keystone; the upper works over it to ATTIC, with a
  breach from BREACH_Z through them over the crown. The sea (-y) stains and
  weeds their feet (SeaPiece).
- `harbour_gate_fallen`: masses of the gate's stone in the shallows: a run
  of voussoirs, a tower's corner, blocks; origin on the bed.
- `harbour_mole`, `harbour_mole_broken`: MOLE_L of mole along x, MOLE_W wide,
  its deck MOLE_TOP over the water, the parapet on its -y (seaward) side, down
  to z -30. The broken one has its deck and parapet thrown down on one side.
- `harbour_quay`, `harbour_quay_steps`: a BAY of quay wall along x, its face
  on y 0 looking -y (the water), QUAY_TOP over it, 12 m deep behind; the
  second with a flight of steps down into the water.
- `harbour_shed`, `harbour_shed_broken`: one ship shed: a barrel-vaulted
  slip SHED_P wide (its left wall included; the clear SHED_CLEAR) and SHED_L
  long along +y, from the sea end (y 0, floor SHED_Z0 under the water) up to
  the land end (floor SHED_Z1). Open at both ends. Side by side they share
  walls; `harbour_shed_end` is the last one's right wall. The broken one's
  vault has fallen in over its middle.
Each has a mid LOD (<piece>_mid.glb).
"""

import math
import sys

from mathutils import Matrix, Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

BAY = T.BAY

# ---- the moles, quay and sheds -------------------------------------------------------
MOLE_L = 19.0
MOLE_W = 14.0
MOLE_TOP = 3.5
MOLE_FOOT = -30.0
QUAY_TOP = 2.5
QUAY_D = 12.0
QUAY_FOOT = -14.0
SHED_P = 1.5 * BAY          # 27.75: one shed's pitch
SHED_WT = 3.0               # its wall
SHED_CLEAR = SHED_P - SHED_WT
SHED_L = 3.0 * BAY          # 55.5
SHED_Z0 = -4.5              # the floor at the sea end
SHED_Z1 = 3.5               # and at the land end
SHED_SPRING = 10.0          # the vault's springing over the floor
SHED_R = SHED_CLEAR / 2     # 12.375
SHED_SHELL = 1.6
SHED_FILL = 18.0            # the fill between the vaults, over the floor
SHED_XC = (-SHED_P / 2 + SHED_WT + SHED_P / 2) / 2   # the vault's axis (x), 1.5
SHED_SEGS = 6
SHED_FOOT = -12.0


def shed_floor(y):
    return SHED_Z0 + (SHED_Z1 - SHED_Z0) * y / SHED_L


SHED_SLOPE = math.atan((SHED_Z1 - SHED_Z0) / SHED_L)


class Lay:
    """Blocks for one piece at one LOD: the near's cut and chipped, the mid's
    plain boxes; `mid` also coarsens the lofted stone. Layout draws come from
    `r`, never the piece's rng, so both LODs lay the same stones."""

    def __init__(self, name, seed, mid):
        self.p = T.Piece(name, seed=seed)
        self.p.ground = 0.0
        self.r = T.random.Random(seed * 31 + 7)
        self.mid = mid

    def block(self, c, s, chips=1, hide=(), edge=False, **kw):
        if self.mid:
            self.p.block(c, s, bevel=0.0, chips=0, jitter=0.0, far=False, hide=hide,
                         **{k: v for k, v in kw.items() if k in ("yaw", "tilt", "tone")})
            return
        if edge:
            self.p.block(c, s, chips=4, chip_depth=(0.3, 0.9), far=False, hide=hide, **kw)
        else:
            self.p.block(c, s, chips=chips, far=False, hide=hide, **kw)

    def run(self, a0, a1, z0, z1, depth, at=0.0, along="x", maxlen=4.2, keep=None, chips=1,
            hide=("-z", "+z"), tilt=None, zf=None):
        """A course's blocks along x (or y) from a0 to a1, centred on `at`
        across; `keep(a, z)` drops a block. `zf(a)` lifts each block (a
        sloping course) and `tilt` leans it along y."""
        if a1 - a0 < 0.45:
            return
        n = max(1, math.ceil((a1 - a0) / maxlen))
        cuts = [a0] + [a0 + (a1 - a0) * (i + self.r.uniform(-0.18, 0.18)) / n for i in range(1, n)] + [a1]
        zc = (z0 + z1) / 2
        for a, b in zip(cuts, cuts[1:]):
            ac = (a + b) / 2
            if keep is not None and not keep(ac, zc):
                continue
            edge = keep is not None and not (keep(a - 1.5, zc) and keep(b + 1.5, zc) and keep(ac, z1 + 1.2))
            lift = zf(ac) if zf is not None else 0.0
            ln = b - a - T.JOINT
            if along == "x":
                c, s = (ac, at, zc + lift), (ln, depth, z1 - z0 - T.JOINT)
            else:
                c, s = (at, ac, zc + lift), (depth, ln / (math.cos(tilt) if tilt else 1.0), z1 - z0 - T.JOINT)
            kw = {"tilt": (tilt, 0.0)} if tilt else {}
            self.block(c, s, chips=self.r.randint(0, chips), hide=hide, edge=edge, **kw)

    def far_boxes(self, boxes):
        for lo, hi in boxes:
            self.p.far_box(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2),
                           (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))

    def solids(self, boxes):
        for lo, hi in boxes:
            self.p.solid(lo, hi)

    def export(self, name):
        if self.mid:
            self.p.export(mid_of=name)
        else:
            self.p.export()


def both(name, seed, fn):
    for mid in (False, True):
        lay = Lay(name, seed, mid)
        fn(lay)
        lay.export(name)


# ---- the sea gate's numbers -----------------------------------------------------------
GX = 50.0                   # each tower's middle, either side of the origin along x
FOOT = -36.0                # the towers' foot on the bed
BASE_TOP = 12.0             # the battered base's top, the plinth course over it
PLINTH = 1.6
SH_X = 12.0                 # the tower's shaft: half across x
SH_Y = 12.0                 # and along y
SKIN = 3.0                  # the shell's thickness (the towers are hollow)
YS = 40.0                   # the arch's springing (the impost's top)
R = GX - SH_X               # 38: the arch springs from the towers' inner faces
RING = 5.5
RO = R + RING
RHW = 8.5                   # the ring's half depth along y
AHW = 7.5                   # the upper works' half depth
ATTIC = 96.0                # the upper works' top, under their cornice
BREACH_Z = 85.0             # the breach's floor over the crown
N_TOP = 130.0               # the north tower's top, under its cornice
S_BREAK = 116.0             # the south tower's broken top, about
COURSE = 2.2
COURSE_HI = 3.0             # the shafts' courses over the springing
STRINGS = (40.0, 68.0, 96.0)  # string courses round the shafts (tops)


def base_half(z):
    """The battered base's half (x, y) at z: 15.5 x 16.5 at the low water,
    13 x 14 at its top."""
    t = max(0.0, min(1.0, (z + 6.0) / (BASE_TOP + 6.0)))
    return 15.5 - 2.5 * t, 16.5 - 2.5 * t


def intrados(x):
    return YS + math.sqrt(max(0.0, R * R - x * x)) if abs(x) < R else YS


def extrados(x):
    return YS + math.sqrt(max(0.0, RO * RO - x * x)) if abs(x) < RO else YS


def breach_half(z, face):
    """Half the breach's width at z on a face (-1 front, 1 back): it widens
    upward, ragged."""
    if z < BREACH_Z:
        return -1.0
    return 11.5 + 0.55 * (z - BREACH_Z) + 1.6 * noise.noise(Vector((z * 0.21, face * 3.1, 9.0)))


def s_break(u, face):
    """The south tower's broken top over a point `u` along a face (from the
    face's middle), higher toward the sea's corner."""
    k = "fblr".index(face)
    tilt = {"f": 0.35, "b": 0.35, "l": -0.3, "r": -0.3}[face] * u
    return S_BREAK + 5.0 * noise.noise(Vector((u * 0.19, k * 2.3, 4.0))) + tilt


class SeaPiece(T.Piece):
    """A piece whose foot stands in the sea: stained dark and grown with weed
    where the tide washes it, under the kit's own weathering."""

    def paint(self, bm, far=False):
        # The kit's rain streaks, half as dark: up 140 m of tower they turn it grey.
        stain = T.STAIN
        T.STAIN = T.mix(T.STAIN, T.STONE, 0.5)
        try:
            col = super().paint(bm, far=far)
        finally:
            T.STAIN = stain
        weed = T.srgb_to_linear((0.17, 0.19, 0.10))
        wet = T.srgb_to_linear((0.30, 0.31, 0.26))
        salt = T.srgb_to_linear((0.70, 0.69, 0.62))
        for f in bm.faces:
            for loop in f.loops:
                p = loop.vert.co
                if p.z > 9.0:
                    continue
                c = loop[col][:3]
                n = noise.noise(Vector((p.x * 0.35, p.y * 0.35, p.z * 0.9 + 3.0)))
                band = max(0.0, min(1.0, (6.5 + 1.5 * n - p.z) / 3.5))
                c = T.mix(c, wet, 0.55 * band)
                w = max(0.0, min(1.0, (1.6 + 1.2 * n - p.z) / 1.4))
                c = T.mix(c, weed, 0.85 * w)
                # A pale salt line at the top of the wet band.
                s = max(0.0, 1.0 - abs(p.z - (6.8 + 1.2 * n)) / 0.5) * (0.5 + 0.5 * n)
                c = T.mix(c, salt, 0.3 * max(0.0, s))
                loop[col] = tuple(c) + (1.0,)
        return col


class SeaLay(Lay):
    def __init__(self, name, seed, mid):
        super().__init__(name, seed, mid)
        self.p = SeaPiece(name, seed=seed)
        self.p.ground = 0.0


def both_sea(name, seed, fn):
    for mid in (False, True):
        lay = SeaLay(name, seed, mid)
        fn(lay)
        lay.export(name)


def cuts_of(lay, a0, a1, maxlen):
    n = max(1, math.ceil((a1 - a0) / maxlen))
    return [a0] + [a0 + (a1 - a0) * (i + lay.r.uniform(-0.18, 0.18)) / n for i in range(1, n)] + [a1]


def face_run(lay, a0, a1, z0, z1, depth, at, along, holes=(), keep=None, maxlen=4.6, chips=2,
             hide=("-z", "+z"), jut=0.0, bevel=None):
    """A course of one face of a shell between a0 and a1 (along x or y),
    with `holes` [(a_mid, half, hz0, hz1)] left open: the jambs cut clean, a
    long lintel over each. Returns the kept intervals [(a, b)]."""
    zc = (z0 + z1) / 2
    segs = [(a0, a1)]
    lintels = []
    for (hm, hh, hz0, hz1) in holes:
        if hz0 <= zc <= hz1:
            nxt = []
            for (a, b) in segs:
                if hm + hh <= a or hm - hh >= b:
                    nxt.append((a, b))
                    continue
                if hm - hh > a:
                    nxt.append((a, hm - hh))
                if hm + hh < b:
                    nxt.append((hm + hh, b))
            segs = nxt
        elif hz1 < z0 + 0.05 and z0 - hz1 < COURSE * 0.9:
            nxt = []
            for (a, b) in segs:
                la, lb = max(a, hm - hh - 1.2), min(b, hm + hh + 1.2)
                if lb - la < 0.5:
                    nxt.append((a, b))
                    continue
                lintels.append((la, lb))
                if la > a:
                    nxt.append((a, la))
                if lb < b:
                    nxt.append((lb, b))
            segs = nxt
    kept = []
    for (a, b) in segs + lintels:
        if b - a < 0.45:
            continue
        cuts = [a, b] if (a, b) in lintels else cuts_of(lay, a, b, maxlen)
        run_a = None
        for u, v in zip(cuts, cuts[1:]):
            ac = (u + v) / 2
            if keep is not None and not keep(ac, zc):
                if run_a is not None:
                    kept.append((run_a, u))
                    run_a = None
                continue
            ln = v - u - T.JOINT
            d = depth + (0.5 if (a, b) in lintels else 0.0)
            atj = at
            if along == "x":
                c, s = (ac, atj, zc), (ln, d, z1 - z0 - T.JOINT)
            else:
                c, s = (atj, ac, zc), (d, ln, z1 - z0 - T.JOINT)
            kw = {} if bevel is None else {"bevel": bevel}
            lay.block(c, s, chips=lay.r.randint(0, chips), hide=hide, **kw)
            if run_a is None:
                run_a = u
        if run_a is not None:
            kept.append((run_a, cuts[-1]))
    return kept


def shell_course(lay, cx, hx, hy, z0, z1, holes=None, keep=None, maxlen=4.6, chips=2, inner=False, t=SKIN, bevel=None):
    """One course of a hollow tower's shell: front (-y), back (+y) and the two
    sides (x = cx -+ hx). `holes[face]`, faces "f", "b", "l", "r"; `keep(face,
    a, z)` drops a block. `inner` shows the shell's inside (where it is open)."""
    holes = holes or {}
    hid = () if inner else None
    for face, at, sy in (("f", -hy + t / 2, -1), ("b", hy - t / 2, 1)):
        kp = (lambda a, z, fc=face: keep(fc, a, z)) if keep else None
        face_run(lay, cx - hx, cx + hx, z0, z1, t, at, "x", holes.get(face, ()), kp, maxlen, chips,
                 hide=hid if hid is not None else ("+y" if sy < 0 else "-y",), bevel=bevel)
    for face, at, sx in (("l", cx - hx + t / 2, -1), ("r", cx + hx - t / 2, 1)):
        kp = (lambda a, z, fc=face: keep(fc, a, z)) if keep else None
        face_run(lay, -hy + t, hy - t, z0, z1, t, at, "y", holes.get(face, ()), kp, maxlen, chips,
                 hide=hid if hid is not None else ("+x" if sx < 0 else "-x",), bevel=bevel)


def recess(lay, cx, hx, hy, face, hole, t=SKIN):
    """The dark of a slit's depth: a block behind the opening, inside the shell."""
    hm, hh, z0, z1 = hole
    tone = 0.42
    if face in ("f", "b"):
        y = (-hy + t + 0.5) if face == "f" else (hy - t - 0.5)
        lay.block((hm, y, (z0 + z1) / 2), (2 * hh + 1.4, 1.0, z1 - z0 + 1.2), chips=0, tone=tone)
    else:
        x = (cx - hx + t + 0.5) if face == "l" else (cx + hx - t - 0.5)
        lay.block((x, hm, (z0 + z1) / 2), (1.0, 2 * hh + 1.4, z1 - z0 + 1.2), chips=0, tone=tone)


def ring_band(lay, cx, hx, hy, z0, z1, jut, chips=1):
    """A string course or cornice round a shaft: a ring of blocks proud by `jut`."""
    t = 2.2
    hx2, hy2 = hx + jut, hy + jut
    face_run(lay, cx - hx2, cx + hx2, z0, z1, t, -hy2 + t / 2, "x", maxlen=6.0, chips=chips, hide=("+y",))
    face_run(lay, cx - hx2, cx + hx2, z0, z1, t, hy2 - t / 2, "x", maxlen=6.0, chips=chips, hide=("-y",))
    face_run(lay, -hy2 + t, hy2 - t, z0, z1, t, cx - hx2 + t / 2, "y", maxlen=6.0, chips=chips, hide=("+x",))
    face_run(lay, -hy2 + t, hy2 - t, z0, z1, t, cx + hx2 - t / 2, "y", maxlen=6.0, chips=chips, hide=("-x",))


def tower_holes(sx):
    """The openings up one tower, per face: slits, then the arcade at the top
    (north) or the ragged stage under the break (south). Face a-coordinates:
    x for f/b, y for l/r."""
    cx = sx * GX
    outer = "r" if sx > 0 else "l"
    inner_f = "l" if sx > 0 else "r"
    holes = {"f": [], "b": [], "l": [], "r": []}
    for f in ("f", "b"):
        holes[f] += [(cx, 1.1, 21.0, 32.0), (cx, 1.1, 48.0, 61.2)]
        holes[f] += [(cx - 4.5, 1.1, 74.0, 87.0), (cx + 4.5, 1.1, 74.0, 87.0)]
    holes[outer] += [(0.0, 1.1, 26.0, 37.0), (0.0, 1.1, 50.0, 61.2), (0.0, 1.1, 75.0, 87.0)]
    # The top stage: an arcade of two tall openings on every face.
    for f in ("f", "b"):
        holes[f] += [(cx - 4.4, 2.6, 104.5, 119.5), (cx + 4.4, 2.6, 104.5, 119.5)]
    for f in (outer, inner_f):
        holes[f] += [(-4.4, 2.6, 104.5, 119.5), (4.4, 2.6, 104.5, 119.5)]
    return holes


def arch_head(lay, cx, hx, hy, face, hm, hh, zs, t=SKIN):
    """A round head of voussoirs over an opening (centre hm, half hh), springing at zs."""
    n = 7
    rr = hh + 0.7
    for i in range(n):
        a = -math.pi / 2 + (i + 0.5) * math.pi / n
        u = hm + rr * math.sin(a)
        z = zs + rr * math.cos(a)
        chord = 2.0 * (hh + 1.4) * math.tan(math.pi / n / 2)
        if face in ("f", "b"):
            y = -hy + t / 2 - 0.15 if face == "f" else hy - t / 2 + 0.15
            lay.block((u, y, z), (chord, t + 0.3, 1.4), tilt=(0.0, a), chips=1, hide=("-x", "+x"))
        else:
            x = cx - hx + t / 2 - 0.15 if face == "l" else cx + hx - t / 2 + 0.15
            lay.block((x, u, z), (t + 0.3, chord, 1.4), tilt=(-a, 0.0), chips=1, hide=("-y", "+y"))


def shaft_zs():
    """The shaft's courses from the plinth up: (z0, z1, kind), kind "c" a
    course, "s" a string course."""
    out = []
    z = BASE_TOP + PLINTH
    while z < N_TOP - 0.01:
        s = next((st for st in STRINGS if st - 1.3 <= z + 0.01 < st), None)
        if s is not None and z < s - 0.05:
            out.append((z, s, "s"))
            z = s
            continue
        nxt = min(z + (COURSE if z < YS else COURSE_HI), N_TOP)
        nxt_s = next((st - 1.3 for st in STRINGS if z < st - 1.3 < nxt), None)
        if nxt_s is not None:
            nxt = nxt_s
        if nxt - z < 0.6:
            out[-1] = (out[-1][0], nxt, out[-1][2]) if out else (z, nxt, "c")
        else:
            out.append((z, nxt, "c"))
        z = nxt
    return out


def tower(lay, sx, solids, fars):
    cx = sx * GX
    north = sx > 0
    # Under the low water: big plain stones, few.
    for (a, b) in ((FOOT, -20.0), (-20.0, -6.0)):
        hx, hy = base_half(-6.0)
        hx, hy = hx + 0.5, hy + 0.5
        shell_course(lay, cx, hx, hy, a, b, maxlen=9.0, chips=0, t=4.0, bevel=0.0)
    # The battered base, each course a little in from the one under it.
    zs = [-6.0 + (BASE_TOP + 6.0) * i / 9 for i in range(10)]
    for (a, b) in zip(zs, zs[1:]):
        hx, hy = base_half(a)
        shell_course(lay, cx, hx, hy, a, b, maxlen=5.4, chips=1)
    # The plinth: a moulded course proud of the shaft, on the base.
    ring_band(lay, cx, SH_X, SH_Y, BASE_TOP, BASE_TOP + PLINTH, 1.0)
    holes = tower_holes(sx)
    brk = (lambda face, a, z: z < s_break(a - cx if face in "fb" else a, face)) if not north else None
    top_open = 100.0
    for (z0, z1, kind) in shaft_zs():
        if not north and z0 > S_BREAK + 8.0:
            break
        if kind == "s":
            if not north and z0 > S_BREAK - 8.0:
                continue
            ring_band(lay, cx, SH_X, SH_Y, z0, z1, 0.7)
            continue
        shell_course(lay, cx, SH_X, SH_Y, z0, z1, holes=holes, keep=brk, chips=1,
                     maxlen=4.6 if z0 < YS else (6.2 if z0 < 70.0 else 7.4), inner=z0 >= top_open, bevel=None if z0 < 30.0 else 0.0)
    # The heads over the openings, the dark behind the slits.
    for face, hs in holes.items():
        for (hm, hh, hz0, hz1) in hs:
            if not north and hz1 > S_BREAK - 9.0:
                continue
            if hh > 2.0:
                arch_head(lay, cx, SH_X, SH_Y, face, hm, hh, hz1 - hh - 0.3)
            else:
                recess(lay, cx, SH_X, SH_Y, face, (hm, hh, hz0, hz1))
    # The core: the hollow's dark, so no joint or slit shows through.
    ctop = 101.0 if north else S_BREAK - 13.5
    lay.block((cx, 0.0, (-6.0 + ctop) / 2), (2 * (SH_X - SKIN) + 0.1, 2 * (SH_Y - SKIN) + 0.1, ctop + 6.0), bevel=0.0,
              chips=0, tone=0.35)
    # A floor under the open top stage (or the broken top's rubble).
    fz = 101.2 if north else S_BREAK - 13.0
    lay.block((cx, 0.0, fz), (2 * (SH_X - SKIN) + 0.4, 2 * (SH_Y - SKIN) + 0.4, 1.6), chips=3, hide=("-z",))
    if not north:
        r = lay.r
        for i in range(9):
            lay.block((cx + r.uniform(-6, 6), r.uniform(-6, 6), fz + 1.2 + r.uniform(0, 1.5)),
                      (r.uniform(2.0, 3.6), r.uniform(1.6, 3.0), r.uniform(1.0, 2.0)),
                      yaw=r.uniform(0, 3), tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), chips=3)
    if north:
        # The cornice, a parapet over it, and the stump of the beacon's platform.
        ring_band(lay, cx, SH_X, SH_Y, N_TOP, N_TOP + 1.4, 1.2)
        ring_band(lay, cx, SH_X, SH_Y, N_TOP + 1.4, N_TOP + 2.4, 1.8)
        lay.block((cx, 0.0, N_TOP + 1.2), (2 * SH_X, 2 * SH_Y, 1.6), chips=2, hide=("-z",))
        par = lambda face, a, z: noise.noise(Vector((a * 0.3, z * 0.1, 2.0 if face in "fb" else 6.0))) > -0.3
        shell_course(lay, cx, SH_X + 1.0, SH_Y + 1.0, N_TOP + 2.4, N_TOP + 4.0, keep=par, maxlen=3.0, chips=3, t=1.4, inner=True)
        bk = lambda face, a, z: z < N_TOP + 9.5 + 3.0 * noise.noise(Vector((a * 0.3, 1.0, 7.0 if face in "fb" else 3.0)))
        for z0 in (N_TOP + 2.4, N_TOP + 4.6, N_TOP + 6.8, N_TOP + 9.0, N_TOP + 11.2):
            shell_course(lay, cx, 6.5, 6.5, z0, z0 + 2.2, keep=bk, maxlen=3.4, chips=3, t=2.0, inner=True)
        lay.block((cx, 0.0, N_TOP + 7.0), (9.0, 9.0, 1.0), chips=2, tone=0.5, hide=("-z",))
    # Solids: never wider than the stone drawn.
    hx0, hy0 = base_half(-6.0)
    solids.append(((cx - hx0, -hy0, FOOT), (cx + hx0, hy0, 0.0)))
    for (a, b) in ((0.0, 4.0), (4.0, 8.0), (8.0, BASE_TOP)):
        hx, hy = base_half(b)
        solids.append(((cx - hx, -hy, a), (cx + hx, hy, b)))
    top = N_TOP + 1.4 if north else S_BREAK - 8.0
    solids.append(((cx - SH_X - 0.6, -SH_Y - 0.6, BASE_TOP), (cx + SH_X + 0.6, SH_Y + 0.6, BASE_TOP + PLINTH)))
    solids.append(((cx - SH_X, -SH_Y, BASE_TOP + PLINTH), (cx + SH_X, SH_Y, top)))
    if north:
        solids.append(((cx - SH_X - 1.0, -SH_Y - 1.0, top), (cx + SH_X + 1.0, SH_Y + 1.0, N_TOP + 2.4)))
        solids.append(((cx - 6.5, -6.5, N_TOP + 2.4), (cx + 6.5, 6.5, N_TOP + 8.0)))
    else:
        # The ragged top in four quarters, each to the lowest stone of its run.
        for (xa, xb) in ((cx - SH_X, cx), (cx, cx + SH_X)):
            lo = min([s_break(a - cx, f) for f in ("f", "b") for a in (xa, xb, (xa + xb) / 2)]
                     + [s_break(u, f) for f in ("l", "r") for u in (-SH_Y, 0.0, SH_Y)])
            solids.append(((xa, -SH_Y, top), (xb, SH_Y, max(top, lo - 2.0))))
    # The far: base, shaft, bands, dark arcade openings.
    fars.append(((cx, 0.0, (FOOT + BASE_TOP) / 2), (2 * hx0 - 1.0, 2 * hy0 - 1.0, BASE_TOP - FOOT), 1.0))
    ft = N_TOP if north else S_BREAK - 4.0
    fars.append(((cx, 0.0, (BASE_TOP + ft) / 2), (2 * SH_X, 2 * SH_Y, ft - BASE_TOP), 1.0))
    for zt in (BASE_TOP + PLINTH,) + STRINGS:
        if north or zt < S_BREAK - 8.0:
            fars.append(((cx, 0.0, zt - 0.7), (2 * SH_X + 1.6, 2 * SH_Y + 1.6, 1.4), 1.0))
    if north:
        fars.append(((cx, 0.0, N_TOP + 1.2), (2 * SH_X + 3.0, 2 * SH_Y + 3.0, 2.4), 1.0))
        fars.append(((cx, 0.0, N_TOP + 6.0), (13.0, 13.0, 8.0), 1.0))
        for (u, v) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            for k in (-4.4, 4.4):
                if u:
                    fars.append(((cx + u * (SH_X + 0.03), k, 112.0), (0.2, 5.2, 15.0), 0.3))
                else:
                    fars.append(((cx + k, v * (SH_Y + 0.03), 112.0), (5.2, 0.2, 15.0), 0.3))
    else:
        for (xa, xb, yy) in ((-SH_X, -4.0, 0.0), (-4.0, 4.0, 0.0), (4.0, SH_X, 0.0)):
            lo = min(s_break(a, f) for f in ("f", "b") for a in (xa, xb))
            fars.append(((cx + (xa + xb) / 2, 0.0, (ft + lo) / 2), (xb - xa, 2 * SH_Y, max(0.5, lo - ft)), 1.0))


NV = 56


def ring_arch(lay, solids, fars):
    """The great arch: voussoirs three across, an archivolt band over them,
    a keystone at the crown."""
    rm = R + RING / 2
    for i in range(NV):
        a = -math.pi / 2 + (i + 0.5) * math.pi / NV
        x = rm * math.sin(a)
        z = YS + rm * math.cos(a)
        chord = 2.0 * RO * math.tan(math.pi / NV / 2) - 0.06
        key = i in (NV // 2 - 1, NV // 2)
        ys = [-RHW, -3.0, 2.4, RHW] if i % 2 else [-RHW, -4.2, 1.4, RHW]
        for j, (ya, yb) in enumerate(zip(ys, ys[1:])):
            hy = ("-y",) if j > 0 else ()
            hy += ("+y",) if j < 2 else ()
            lay.block((x, (ya + yb) / 2, z), (chord, yb - ya - T.JOINT, RING + (0.8 if key else 0.0)),
                      tilt=(0.0, a), chips=0, hide=("-x", "+x") + hy)
    # The archivolt: a band of thin stones on the ring's back, proud on each face.
    n2 = 40
    for i in range(n2):
        a = -math.pi / 2 + (i + 0.5) * math.pi / n2
        rb = RO + 0.6
        x = rb * math.sin(a)
        if abs(x) > R - 0.5 and math.cos(a) < 0.2:
            continue
        chord = 2.0 * (RO + 1.2) * math.tan(math.pi / n2 / 2) - 0.06
        lay.block((x, 0.0, YS + rb * math.cos(a)), (chord, 2 * RHW + 1.6, 1.2), tilt=(0.0, a), chips=2, hide=("-x", "+x"))
    n = 72
    for i in range(n):
        a0 = -math.pi / 2 + i * math.pi / n
        a1 = a0 + math.pi / n
        pts = [(rr * math.sin(a), YS + rr * math.cos(a)) for rr in (R, RO) for a in (a0, a1)]
        xs = [p[0] for p in pts]
        zs = [p[1] for p in pts]
        if min(xs) > R or max(xs) < -R:
            continue
        # Its foot never under the soffit drawn: the intrados where it is highest
        # over the box (at the box's x nearest the crown).
        x0, x1 = max(min(xs), -R), min(max(xs), R)
        near = 0.0 if x0 < 0.0 < x1 else min(abs(x0), abs(x1))
        solids.append(((x0, -RHW, max(intrados(near), YS)), (x1, RHW, max(zs))))
    for i in range(30):
        a = -math.pi / 2 + (i + 0.5) * math.pi / 30
        chord = 2.0 * RO * math.tan(math.pi / 30 / 2)
        fars.append(((rm * math.sin(a), 0.0, YS + rm * math.cos(a)), (chord, 2 * RHW, RING + 1.0), 1.0, a))


def upper_works(lay, solids, fars):
    """The spandrels and the attic over the arch, in courses on the ring's
    back, to ATTIC; the breach through them over the crown; a cornice."""
    zs = []
    z = YS + 1.5
    while z < ATTIC - 0.1:
        zs.append((z, min(z + COURSE, ATTIC)))
        z += COURSE
    for (z0, z1) in zs:
        for face in (-1, 1):
            # Two leaves, front and back, each showing one face.
            at = face * (AHW - 1.6)
            def keep(a, zc, z0=z0, face=face):
                bh = breach_half(zc, face)
                return abs(a) > bh
            cuts_ok = []
            cuts = cuts_of(lay, -R, R, 4.4 if z0 < 70 else 5.0)
            run = None
            kept = []
            for u, v in zip(cuts, cuts[1:]):
                ac = (u + v) / 2
                lo = max(intrados(u), intrados(v), intrados(0.0) if u < 0.0 < v else 0.0) + 1.0
                ok = z0 >= lo and z1 > extrados(ac) - 0.6 and keep(ac, (z0 + z1) / 2)
                if not ok:
                    if run is not None:
                        kept.append((run, u))
                        run = None
                    continue
                kw = {"bevel": 0.0} if z0 > 62.0 else {}
                lay.block((ac, at, (z0 + z1) / 2), (v - u - T.JOINT, 3.2, z1 - z0 - T.JOINT),
                          chips=lay.r.randint(0, 2 if z0 < 62.0 else 1), hide=("+y" if face < 0 else "-y",), **kw)
                if run is None:
                    run = u
            if run is not None:
                kept.append((run, cuts[-1]))
            for (a, b) in kept:
                solids.append(((a, face * AHW if face < 0 else 0.0, z0), (b, 0.0 if face < 0 else AHW, z1)))
        # The fill between the leaves, seen only from above in the breach: the
        # top of the course under the breach's floor.
    # The core between the leaves, in slices over the ring's back.
    n = 16
    for i in range(n):
        a, b = -R + 2 * R * i / n, -R + 2 * R * (i + 1) / n
        lo = max(intrados(a), intrados(b)) + 0.5
        bh = breach_half(BREACH_Z + 1.0, 1)
        hi = BREACH_Z - 0.6 if min(abs(a), abs(b)) < bh + 3.0 else ATTIC - 0.6
        if hi > lo:
            lay.block(((a + b) / 2, 0.0, (lo + hi) / 2), (b - a, 2 * AHW - 3.2, hi - lo), bevel=0.0, chips=0, tone=0.4)
    # The breach's floor: rubble on the course under it, and the core's top.
    lay.block((0.0, 0.0, BREACH_Z - 0.6), (30.0, 2 * AHW - 3.0, 1.4), chips=3, hide=("-z",))
    r = lay.r
    for i in range(10):
        lay.block((r.uniform(-11, 11), r.uniform(-4, 4), BREACH_Z + r.uniform(0.2, 1.0)),
                  (r.uniform(2.0, 3.8), r.uniform(1.6, 3.0), r.uniform(0.9, 1.8)),
                  yaw=r.uniform(0, 3), tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), chips=3)
    # The breach's cheeks: the core's cut faces between the leaves.
    for sx in (-1, 1):
        for z0 in range(int(BREACH_Z), int(ATTIC), 3):
            bh = max(breach_half(z0 + 1.5, -1), breach_half(z0 + 1.5, 1)) + 1.0
            lay.block((sx * (bh + 1.5), 0.0, z0 + 1.5), (3.0, 2 * AHW - 3.0, 3.0 - T.JOINT), chips=2,
                      hide=("-z", "+z", "-y", "+y"), tone=0.85)
    # The attic's cornice and its string course over the crown, where not fallen.
    for face in (-1, 1):
        keep = lambda a, z, face=face: abs(a) > breach_half(ATTIC, face) + 1.5
        face_run(lay, -R, R, ATTIC, ATTIC + 1.6, 2.4, face * (AHW + 0.3 - 1.2), "x", keep=keep,
                 maxlen=3.6, chips=3, hide=("-z", "+y" if face < 0 else "-y"))
        keep2 = lambda a, z, face=face: abs(a) > breach_half(84.0, face) - 1.0 and z > extrados(a) - 0.5
        face_run(lay, -R, R, 83.4, 84.6, 1.6, face * (AHW + 0.4 - 0.8), "x", keep=keep2,
                 maxlen=3.6, chips=2, hide=("-z", "+y" if face < 0 else "-y"))
    for sx in (-1, 1):
        a0 = sx * (breach_half(ATTIC, 1) + 2.0)
        lay.block(((a0 + sx * R) / 2, 0.0, ATTIC - 0.2), (abs(sx * R - a0), 2 * AHW - 2.0, 1.2), chips=2, hide=("-z",))
    # The far: slices of the upper works over the ring's back.
    n = 19
    for i in range(n):
        a, b = -R + 2 * R * i / n, -R + 2 * R * (i + 1) / n
        lo = min(extrados(a), extrados(b)) - 0.5
        hi = ATTIC + 1.6
        bh = breach_half(BREACH_Z + 4.0, 1)
        if max(abs(a), abs(b)) < bh + 2.0:
            hi = BREACH_Z
        elif min(abs(a), abs(b)) < breach_half(ATTIC, 1):
            hi = BREACH_Z + (min(abs(a), abs(b)) - 11.5) / 0.55
        if hi > lo:
            fars.append((((a + b) / 2, 0.0, (lo + hi) / 2), (b - a, 2 * AHW, hi - lo), 1.0))


# ---- the fallen blocks ------------------------------------------------------------
def chunk(lay, c, yaw, tilt, cells, cell, solids, tone=None):
    """Blocks bound in one fallen mass: `cells` (i, j, k) of size `cell`, laid
    about `c`, the whole turned by yaw and tilted."""
    m = (Matrix.Translation(Vector(c)) @ Matrix.Rotation(yaw, 4, "Z")
         @ Matrix.Rotation(tilt[1], 4, "Y") @ Matrix.Rotation(tilt[0], 4, "X"))
    pts = []
    for (i, j, k) in cells:
        o = Vector((i * cell[0], j * cell[1], k * cell[2]))
        p = m @ o
        lay.block(tuple(p), (cell[0] - T.JOINT, cell[1] - T.JOINT, cell[2] - T.JOINT), yaw=yaw, tilt=tilt,
                  chips=lay.r.randint(1, 3), tone=tone)
        for dx in (-0.5, 0.5):
            for dy in (-0.5, 0.5):
                for dz in (-0.5, 0.5):
                    pts.append(m @ (o + Vector((dx * cell[0], dy * cell[1], dz * cell[2]))))
    # A solid: the middle of the mass (the hull shrunk to 70%).
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    mid = (lo + hi) / 2
    hs = (hi - lo) * 0.35
    solids.append((tuple(mid - hs), tuple(mid + hs)))


def build_fallen(lay):
    """Masses of the gate's stone thrown into the shallows: a run of the arch's
    voussoirs still bound together, a corner of a tower, attic blocks. The
    origin is the bed; the masses reach ~12 m over it, through the surface."""
    solids = []
    r = lay.r
    # A piece of the ring: five voussoirs on a curve, lying on its side.
    for i in range(5):
        a = -0.35 + i * 0.17
        x = 20.0 * math.sin(a)
        z = 20.0 * math.cos(a) - 14.0
        lay.block((x - 2.0, 4.0, z + 1.0), (3.6, 7.5, 5.5), tilt=(0.0, a), yaw=0.1, chips=2)
    solids.append(((-10.0, 1.0, 0.0), (6.0, 7.0, 7.0)))
    # A corner of a tower, three courses still bound, leaning.
    chunk(lay, (-12.0, -8.0, 4.0), 0.4, (0.35, -0.2), [(i, j, k) for i in range(3) for j in range(2) for k in range(3)
                                                       if not (i == 2 and j == 1 and k == 2)], (3.6, 3.0, 2.2), solids)
    chunk(lay, (9.0, -10.0, 3.0), -0.7, (-0.15, 0.5), [(i, 0, k) for i in range(4) for k in range(4) if i + k < 6],
          (3.0, 3.0, 2.2), solids)
    # Single blocks, some breaking the surface, some just under.
    for i in range(14):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(6.0, 20.0)
        s = (r.uniform(2.6, 4.8), r.uniform(2.0, 3.4), r.uniform(1.8, 2.6))
        zc = r.uniform(0.5, 9.0)
        c = (d * math.cos(a), d * math.sin(a), zc)
        lay.block(c, s, yaw=r.uniform(0, 3), tilt=(r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5)), chips=3)
        solids.append(((c[0] - s[0] * 0.3, c[1] - s[1] * 0.3, c[2] - s[2] * 0.3), (c[0] + s[0] * 0.3, c[1] + s[1] * 0.3, c[2] + s[2] * 0.3)))
    # Underneath, the heap's foot down to a deeper bed.
    for i in range(6):
        c = (r.uniform(-14, 10), r.uniform(-12, 8), -4.0)
        lay.block(c, (6.0, 5.0, 8.0), yaw=r.uniform(0, 3), chips=0, hide=("-z",))
    if not lay.mid:
        lay.far_boxes([((-14.0, -14.0, -6.0), (12.0, 8.0, 6.0))])
    lay.solids(solids)


def build_gate(lay):
    solids = []
    fars = []
    for sx in (-1, 1):
        tower(lay, sx, solids, fars)
    ring_arch(lay, solids, fars)
    upper_works(lay, solids, fars)
    # Fallen stones at the south tower's foot, out of the way through.
    r = lay.r
    for i in range(8):
        c = (-GX + r.uniform(-14, 14), -SH_Y - r.uniform(6.0, 14.0), r.uniform(-2.0, 1.8))
        s = (r.uniform(3.0, 5.0), r.uniform(2.4, 3.6), r.uniform(2.0, 3.0))
        if abs(c[0]) < R + 6.0:
            c = (-(R + 6.0) - r.uniform(0, 6), c[1], c[2])
        lay.block(c, s, yaw=r.uniform(0, 3), tilt=(r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5)), chips=3)
        solids.append(((c[0] - s[1] * 0.4, c[1] - s[1] * 0.4, c[2] - s[2] * 0.3), (c[0] + s[1] * 0.4, c[1] + s[1] * 0.4, c[2] + s[2] * 0.3)))
    if not lay.mid:
        for f in fars:
            if len(f) == 4:
                lay.p.far_box(f[0], f[1], tilt=(0.0, f[3]), tone=f[2])
            else:
                lay.p.far_box(f[0], f[1], tone=f[2])
    lay.solids(solids)


# ---- the moles -------------------------------------------------------------------
def build_mole(lay, broken):
    h = MOLE_L / 2
    w = MOLE_W / 2
    gone = (lambda x, z: not (z > 0.8 and x + 2.5 * noise.noise(Vector((x * 0.2, z * 0.3, 2.2))) > -2.0)) if broken else None
    for (a, b) in ((MOLE_FOOT, -18.0), (-18.0, -9.0)):
        lay.run(-h, h, a, b, MOLE_W, maxlen=9.5, chips=0)
    zs = [-9.0, -7.3, -5.7, -4.2, -2.8, -1.4, 0.0, 1.2, 2.4]
    for (a, b) in zip(zs, zs[1:]):
        lay.run(-h, h, a, b, MOLE_W, maxlen=4.4, keep=gone, chips=2)
    # The deck: two rows of slabs, a kerb on the harbour side.
    for (y0, y1) in ((-w, -0.2), (-0.2, w - 1.0)):
        lay.run(-h, h, 2.4, MOLE_TOP, y1 - y0, at=(y0 + y1) / 2, maxlen=3.4, keep=gone, chips=2, hide=("-z",))
    lay.run(-h, h, 2.4, MOLE_TOP + 0.5, 1.0, at=w - 0.5, maxlen=2.8, keep=gone, chips=2, hide=("-z",))
    # The parapet on the seaward side, broken here and there.
    par = lambda x, z: noise.noise(Vector((x * 0.13, 7.7, 1.0))) > -0.25 and (gone is None or gone(x, 2.0))
    lay.run(-h, h, MOLE_TOP, MOLE_TOP + 1.3, 2.0, at=-w + 1.0, maxlen=3.6, keep=par, chips=2)
    par2 = lambda x, z: par(x, z) and noise.noise(Vector((x * 0.21, 3.3, 5.0))) > -0.1
    lay.run(-h, h, MOLE_TOP + 1.3, MOLE_TOP + 2.5, 2.0, at=-w + 1.0, maxlen=3.6, keep=par2, chips=3)
    r = lay.r
    if broken:
        # What fell: deck slabs and parapet stones tumbled off the seaward side.
        for i in range(9):
            x = r.uniform(-h + 2, 2.0)
            y = -w - r.uniform(1.0, 6.0)
            lay.block((x, y, r.uniform(-1.5, 0.3)), (r.uniform(2.2, 4.0), r.uniform(1.6, 3.0), r.uniform(1.0, 1.8)),
                      yaw=r.uniform(0, 3), tilt=(r.uniform(-0.5, 0.5), r.uniform(-0.4, 0.4)), chips=3)
    if not lay.mid:
        lay.far_boxes([((-h, -w, MOLE_FOOT), (h, w, MOLE_TOP if not broken else 0.8)), ((-h, -w, MOLE_TOP), (h, -w + 2.0, MOLE_TOP + 2.0))])
    if broken:
        lay.solids([((-h, -w, MOLE_FOOT), (h, w, 0.8)), ((-h, -w, 0.8), (-2.0, w, MOLE_TOP)),
                    ((-h, -w, MOLE_TOP), (-2.0, -w + 2.0, MOLE_TOP + 2.5))])
    else:
        lay.solids([((-h, -w, MOLE_FOOT), (h, w, MOLE_TOP)), ((-h, -w, MOLE_TOP), (h, -w + 2.0, MOLE_TOP + 2.5))])


# ---- the quay ------------------------------------------------------------------
def build_quay(lay, steps):
    h = BAY / 2
    yd = QUAY_D
    notch = (lambda x, z: not (abs(x) < 4.2 and z > -1.4)) if steps else None
    lay.run(-h, h, QUAY_FOOT, -5.0, yd, at=yd / 2, maxlen=9.0, chips=0)
    zs = [-5.0, -3.6, -2.3, -1.1, 0.1, 1.3, QUAY_TOP - 0.6]
    for (a, b) in zip(zs, zs[1:]):
        lay.run(-h, h, a, b, 3.0, at=1.5, maxlen=4.0, keep=notch, chips=2)
        lay.run(-h, h, a, b, yd - 3.0, at=3.0 + (yd - 3.0) / 2, maxlen=9.0, keep=notch, chips=0, hide=("-z", "+z"))
    # The coping: long stones along the face, then the paving behind.
    lay.run(-h, h, QUAY_TOP - 0.6, QUAY_TOP, 2.2, at=1.1, maxlen=3.2, keep=notch, chips=3, hide=("-z",))
    for (y0, y1) in ((2.2, 6.5), (6.5, yd)):
        lay.run(-h, h, QUAY_TOP - 0.6, QUAY_TOP - 0.05, y1 - y0, at=(y0 + y1) / 2, maxlen=3.6, keep=notch, chips=1, hide=("-z",))
    r = lay.r
    if steps:
        n = 8
        back = 7.5
        for i in range(n):
            zt = -1.4 + (i + 1) * (QUAY_TOP - 0.45 + 1.4) / n
            y0 = i * back / n
            lay.block((0.0, (y0 + back) / 2, (zt - 1.4) / 2), (8.36, back - y0 - 0.04, zt + 1.4), chips=1, hide=("-z",))
        lay.block((0.0, (back + yd) / 2, (QUAY_TOP - 1.4) / 2), (8.36, yd - back - 0.04, QUAY_TOP + 1.4), chips=1, hide=("-z",))
        lay.run(-4.2, 4.2, -5.0, -1.4, yd, at=yd / 2, maxlen=4.2, chips=0)
    else:
        # A bollard.
        lay.block((r.uniform(-5, 5), 2.6, QUAY_TOP + 0.7), (1.4, 1.4, 1.5), chips=3)
    if not lay.mid:
        lay.far_boxes([((-h, 0.0, QUAY_FOOT), (h, yd, QUAY_TOP))])
    lay.solids([((-h, 0.0, QUAY_FOOT), (h, yd, QUAY_TOP))])


# ---- the ship sheds ----------------------------------------------------------------
def build_shed(lay, broken):
    hp = SHED_P / 2
    xw0, xw1 = -hp, -hp + SHED_WT
    xc = SHED_XC
    R = SHED_R
    seg = SHED_L / SHED_SEGS
    tan_s = math.tan(SHED_SLOPE)
    fallen = (lambda y: 17.0 < y < 39.5) if broken else (lambda y: False)
    # The wall, in horizontal courses stepping up the slope, under a sloping impost.
    wall_side(lay, xw0, xw1, broken)
    # The floor: a sloping slip, plain under the water, paved above it.
    for i in range(SHED_SEGS):
        y0, y1 = i * seg, (i + 1) * seg
        yc = (y0 + y1) / 2
        zt = shed_floor(yc)
        if zt < -0.6:
            lay.block((xc, yc, (zt + SHED_FOOT) / 2), (SHED_CLEAR + 0.02, seg / math.cos(SHED_SLOPE), zt - SHED_FOOT),
                      chips=0, tilt=(SHED_SLOPE, 0.0), hide=("-z",))
        else:
            lay.block((xc, yc, (zt - 0.6 + SHED_FOOT) / 2), (SHED_CLEAR + 0.02, seg / math.cos(SHED_SLOPE), zt - 0.6 - SHED_FOOT),
                      chips=0, tilt=(SHED_SLOPE, 0.0), hide=("-z", "+z"))
            for k in range(4):
                xa = -hp + SHED_WT + SHED_CLEAR * k / 4
                for yy in (y0 + seg * 0.25, y0 + seg * 0.75):
                    lay.block((xa + SHED_CLEAR / 8, yy, shed_floor(yy) - 0.3 + lay.r.uniform(-0.05, 0.05)),
                              (SHED_CLEAR / 4 - 0.06, seg / 2 - 0.06, 0.6), tilt=(SHED_SLOPE + lay.r.uniform(-0.02, 0.02), 0.0),
                              chips=lay.r.randint(0, 2), hide=("-z",))
    # The vault: a shell of voussoir courses, the end rings proud.
    vault(lay, xc, R, fallen)
    # The fill between the vaults, both sides, up to SHED_FILL over the floor.
    band = [0.0, 1.6, 3.2, 4.8, 6.4, 8.0]
    ext = lambda hh: math.sqrt(max(0.0, (R + SHED_SHELL) ** 2 - hh * hh))
    keep_fill = lambda y, z: not fallen(y) and noise.noise(Vector((y * 0.12, z * 0.3, 4.0))) > -0.45 + 0.08 * z
    for (a, b) in zip(band, band[1:]):
        e = ext(b)
        for (x0, x1) in ((-hp, xc - e), (xc + e, hp)):
            if x1 - x0 < 0.4:
                continue
            lay.run(0.0, SHED_L, SHED_SPRING + a, SHED_SPRING + b, x1 - x0, at=(x0 + x1) / 2, along="y", maxlen=4.7,
                    keep=keep_fill if b > 3.3 else (lambda y, z: not fallen(y) or z < SHED_SPRING + 2.0),
                    chips=2, tilt=SHED_SLOPE, zf=shed_floor, hide=("-z",))
    r = lay.r
    if broken:
        for i in range(16):
            y = r.uniform(19.0, 38.0)
            x = xc + r.uniform(-9.0, 9.0)
            sz = r.uniform(1.2, 2.2)
            lay.block((x, y, shed_floor(y) + sz * 0.3), (r.uniform(2.0, 3.6), r.uniform(1.6, 3.0), sz), yaw=r.uniform(0, 3),
                      tilt=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4)), chips=3)
    if not lay.mid:
        boxes = []
        for i in range(SHED_SEGS):
            y0, y1 = i * seg, (i + 1) * seg
            z0 = shed_floor(y0)
            boxes.append(((xw0, y0, SHED_FOOT), (xw1, y1, z0 + SHED_SPRING)))
            boxes.append(((xw1, y0, SHED_FOOT), (hp, y1, z0)))
            if not fallen((y0 + y1) / 2):
                boxes.append(((-hp, y0, z0 + SHED_SPRING), (xc - R * 0.55, y1, z0 + SHED_SPRING + 8.0)))
                boxes.append(((xc + R * 0.55, y0, z0 + SHED_SPRING), (hp, y1, z0 + SHED_SPRING + 8.0)))
                boxes.append(((-hp, y0, z0 + SHED_SPRING + 8.0), (hp, y1, z0 + SHED_SPRING + R + SHED_SHELL)))
        lay.far_boxes(boxes)
    lay.solids(shed_solids(broken, fallen))


def shed_solids(broken, fallen):
    hp = SHED_P / 2
    xw0, xw1 = -hp, -hp + SHED_WT
    xc, R = SHED_XC, SHED_R
    seg = SHED_L / SHED_SEGS
    out = []
    for i in range(SHED_SEGS):
        y0, y1 = i * seg, (i + 1) * seg
        zlo, zhi = shed_floor(y0), shed_floor(y1)
        out.append(((xw0, y0, SHED_FOOT), (xw1, y1, zhi + SHED_SPRING + 0.2)))
        out.append(((xw1, y0, SHED_FOOT), (hp, y1, zhi)))
        if fallen((y0 + y1) / 2):
            continue
        zs = zlo + SHED_SPRING
        for (a, b) in ((0.0, 4.0), (4.0, 7.0), (7.0, 9.4), (9.4, 11.0)):
            hw = math.sqrt(max(0.0, R * R - b * b))
            out.append(((-hp, y0, zs + a), (xc - hw, y1, zs + b)))
            out.append(((xc + hw, y0, zs + a), (hp, y1, zs + b)))
        out.append(((-hp, y0, zs + 11.0), (hp, y1, zhi + SHED_SPRING + R + SHED_SHELL)))
    return out


def wall_side(lay, x0, x1, broken, top=None):
    """A shed's wall from x0 to x1: courses stepping up with the slope, under
    a sloping impost at the vault's springing (or to `top` over the floor)."""
    seg = SHED_L / SHED_SEGS
    yc = (x0 + x1) / 2
    wt = x1 - x0
    for i in range(SHED_SEGS):
        y0, y1 = i * seg, (i + 1) * seg
        lid = shed_floor(y1) + (top if top is not None else SHED_SPRING - 1.4)
        lay.block((yc, (y0 + y1) / 2, (SHED_FOOT - 6.0) / 2), (wt, seg - T.JOINT, -6.0 - SHED_FOOT), chips=0,
                  hide=("-z", "+z"))
        z = -6.0
        while z < lid - 0.3:
            zt = min(z + 1.8, lid)
            lay.run(y0, y1, z, zt, wt, at=yc, along="y", maxlen=4.8, chips=2)
            z = zt
    if top is None:
        lay.run(0.0, SHED_L, SHED_SPRING - 1.4, SHED_SPRING + 0.2, wt + 0.8, at=yc, along="y", maxlen=4.7, chips=2,
                tilt=SHED_SLOPE, zf=shed_floor, hide=("-z",))


def vault(lay, xc, R, fallen):
    """The barrel vault over the slip: a shell SHED_SHELL thick in voussoir
    courses (joints painted dark), springing at shed_floor + SHED_SPRING,
    and a ring of proud voussoirs at each open end."""
    bm = lay.p.near
    kind, tone, broke = T._layers(bm)
    deep = T._deep(bm)
    r = lay.r
    nv = 13
    nring = 12
    mid = lay.mid
    ths = []
    for k in range(nv):
        a0, a1 = math.pi * k / nv, math.pi * (k + 1) / nv
        if mid:
            ths += [(a0, False)]
        else:
            e = 0.05
            ths += [(a0, True), (a0 + e, False), (a1 - e, False)]
    ths.append((math.pi, True if not mid else False))
    ys = []
    seg = SHED_L / nring
    for k in range(nring):
        b0, b1 = k * seg, (k + 1) * seg
        if mid:
            ys += [(b0, False)]
        else:
            ys += [(b0, True), (b0 + 0.12, False), (b1 - 0.12, False)]
    ys.append((SHED_L, not mid))
    tones = {}

    def pt(th, y, rad):
        zs = shed_floor(y) + SHED_SPRING
        return Vector((xc - rad * math.cos(th), y, zs + rad * math.sin(th)))

    for surface, rad0, sgn in (("in", R, 1.0), ("out", R + SHED_SHELL, -1.0)):
        grid = []
        for (y, gy) in ys:
            row = []
            for (th, gt) in ths:
                g = gy or gt
                rad = rad0 + (sgn * 0.12 if g and not mid else 0.0)
                rad += 0.05 * noise.noise(Vector((th * 3.0, y * 0.3, rad0)))
                v = bm.verts.new(pt(th, y, rad))
                v[deep] = 1.0 if g and not mid else 0.0
                row.append(v)
            grid.append(row)
        for i in range(len(ys) - 1):
            ym = (ys[i][0] + ys[i + 1][0]) / 2
            if fallen(ym):
                continue
            for j in range(len(ths) - 1):
                key = (int(ym // seg), int(((ths[j][0] + ths[j + 1][0]) / 2) // (math.pi / nv)))
                if key not in tones:
                    tones[key] = r.uniform(0.86, 1.06)
                f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
                gj = ys[i][1] or ys[i + 1][1] or ths[j][1] or ths[j + 1][1]
                f[kind] = T.JOINTFACE if gj and not mid else T.FACE
                f[tone] = tones[key]
                f.normal_update()
                th = (ths[j][0] + ths[j + 1][0]) / 2
                axis = Vector((xc, ym, shed_floor(ym) + SHED_SPRING))
                outward = f.normal.dot(pt(th, ym, rad0) - axis) > 0
                if outward != (surface == "out"):
                    f.normal_flip()
    # The proud rings at the open ends (and where the vault broke off).
    ends = [0.0, SHED_L]
    if fallen(SHED_L / 2):
        ends += [17.0 - 0.6, 39.5 + 0.6]
    for y in ends:
        dy = 1.2 if y < SHED_L / 2 else -1.2
        if 10.0 < y < 45.0:
            dy = -dy
        rm = R + SHED_SHELL / 2
        broken_ring = 10.0 < y < 45.0
        for k in range(nv):
            if broken_ring and r.random() < 0.35:
                continue
            th = math.pi * (k + 0.5) / nv
            c = pt(th, y + dy / 2, rm)
            wdt = 2.0 * (R + SHED_SHELL + 0.3) * math.tan(math.pi / nv / 2) - 0.05
            lay.block(tuple(c), (wdt, abs(dy), SHED_SHELL + 0.5), tilt=(0.0, th - math.pi / 2), chips=1)


def build_shed_end(lay):
    hp = SHED_P / 2
    wall_side(lay, hp, hp + SHED_WT, False, top=SHED_FILL)
    seg = SHED_L / SHED_SEGS
    if not lay.mid:
        lay.far_boxes([((hp, i * seg, SHED_FOOT), (hp + SHED_WT, (i + 1) * seg, shed_floor((i + 1) * seg) + SHED_FILL)) for i in range(SHED_SEGS)])
    lay.solids([((hp, i * seg, SHED_FOOT), (hp + SHED_WT, (i + 1) * seg, shed_floor((i + 1) * seg) + SHED_FILL)) for i in range(SHED_SEGS)])


JOBS = {
    "harbour_gate": lambda: both_sea("harbour_gate", 91, build_gate),
    "harbour_gate_fallen": lambda: both_sea("harbour_gate_fallen", 92, build_fallen),
    "harbour_mole": lambda: both("harbour_mole", 84, lambda lay: build_mole(lay, False)),
    "harbour_mole_broken": lambda: both("harbour_mole_broken", 85, lambda lay: build_mole(lay, True)),
    "harbour_quay": lambda: both("harbour_quay", 86, lambda lay: build_quay(lay, False)),
    "harbour_quay_steps": lambda: both("harbour_quay_steps", 87, lambda lay: build_quay(lay, True)),
    "harbour_shed": lambda: both("harbour_shed", 88, lambda lay: build_shed(lay, False)),
    "harbour_shed_broken": lambda: both("harbour_shed_broken", 89, lambda lay: build_shed(lay, True)),
    "harbour_shed_end": lambda: both("harbour_shed_end", 90, build_shed_end),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
