"""The temple kit's hillside sanctuary (lane sanctuary): the pieces of the
stepped terraces that scripts/endless/sanctuary_site.gd lays up a slope, in
the kit's stone (temple_lib) and on its BAY. The columns, lintels, gate,
altar and rubble on the levels are the kit's own pieces.

    python tools/blender.py run art/blender/temple_kit/sanctuary_build.py [-- --only=sanctuary_wall]

A terrace wall stands on the level below it: a wall piece's origin is on that
level at the bay's middle on the wall's axis, the wall runs along x, its face
looks to -y (downhill; Godot +z) and its top is H over the origin, the level
it holds. Every wall piece goes on down SKIRT m under its origin as plain
footing courses, so it reaches ground that falls away under it.

Pieces (Blender frame, z up; Godot (x, y, z) = Blender (x, z, -y)):
- `sanctuary_wall`: one bay of retaining wall: pilasters at the bay's ends, a
  blind arched niche between them, a plinth, a cornice and a kerb.
- `sanctuary_wall_burst`: the bay burst open in a V down to its foot.
- `sanctuary_wall_stump`: the bay broken off low, ragged.
- `sanctuary_arch`: an arcade bay: two half piers and a round arch, ARCH_W
  clear by ARCH_TOP to the crown, the wall's courses over it.
- `sanctuary_arch_broken`: the arcade bay fallen: one pier to its springing
  with two arch stones, the other a stump, blocks at their feet.
- `sanctuary_slot_open`: a gateway bay: two piers the wall's whole height,
  ARCH_W clear between them, open above.
- `sanctuary_deck`: one BAY x BAY bay of a level's floor, DECK_T thick, its
  paved top at the origin's height. `sanctuary_deck_broken`: the bay with its
  +x side fallen away.
- `sanctuary_stair`: a stair bay, BAY wide and BAY deep, STAIR_RISE up from
  its origin (the middle of its foot's level) toward +y; two make a flight
  between levels. `sanctuary_stair_arch`: the flight's upper bay with a way
  through under it along x, TUNNEL_W clear by TUNNEL_H over the lower level.
- `sanctuary_spill`: the stone a burst bay threw down before it, origin as the
  wall's.
Each has a mid LOD (<piece>_mid.glb: the same stones, plain).
"""

import math
import sys

from mathutils import Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

BAY = T.BAY
HALF = BAY / 2
H = 26.0                    # one level over the next
KERB = 0.4                  # the wall's kerb over the level it holds
TOP = H + KERB
SKIRT = 16.0
WT = 3.0                    # the wall's thickness
PIER = 2.0                  # half a pier (two bays' halves make one, 4 m)
ARCH_W = BAY - 2 * PIER     # 14.5 clear
SPRING = 14.0
ARCH_R = ARCH_W / 2
ARCH_TOP = SPRING + ARCH_R  # 21.25
RING = 1.75                 # the arch stones' depth
SLOT_TOP = 21.2
DECK_T = 3.0
STAIR_RISE = 13.0
STEPS = 13
TREAD = BAY / STEPS
TUNNEL_Y = (-HALF + 2.0, HALF)      # the way under the stair, across (y)
TUNNEL_W = 14.5                     # to the wall's pilasters behind it
TUNNEL_Z = 0.5                      # its soffit over the bay's origin
TUNNEL_H = STAIR_RISE + TUNNEL_Z

SKIRTS = [(-16.0, -10.6), (-10.6, -5.3), (-5.3, 0.0)]
PLINTH = (0.0, 2.0)
ASHLAR = [(2.0 + 2.4 * i, 4.4 + 2.4 * i) for i in range(9)]     # to 23.6
CORNICE = (23.6, 25.2)
KERBC = (25.2, TOP)


class Lay:
    """Blocks for one piece at one LOD: the near's are cut and chipped, the
    mid's plain boxes. Layout draws come from `r`, never the piece's rng, so
    both LODs lay the same stones."""

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
            self.p.block(c, s, chips=4, chip_depth=(0.3, 0.9), far=False, **kw)
        else:
            self.p.block(c, s, chips=chips, far=False, hide=hide, **kw)

    def run(self, x0, x1, z0, z1, depth, y=0.0, maxlen=4.2, keep=None, chips=1, hide=("-z", "+z")):
        """A course's blocks from x0 to x1; `keep(x, z)` drops a block, and
        one beside or under a dropped one is broken."""
        if x1 - x0 < 0.45:
            return
        n = max(1, math.ceil((x1 - x0) / maxlen))
        cuts = [x0] + [x0 + (x1 - x0) * (i + self.r.uniform(-0.18, 0.18)) / n for i in range(1, n)] + [x1]
        zc = (z0 + z1) / 2
        for a, b in zip(cuts, cuts[1:]):
            xc = (a + b) / 2
            if keep is not None and not keep(xc, zc):
                continue
            edge = keep is not None and not (keep(a - 1.5, zc) and keep(b + 1.5, zc) and keep(xc, z1 + 1.2))
            self.block((xc, y, zc), (b - a - T.JOINT, depth, z1 - z0 - T.JOINT), chips=self.r.randint(0, chips),
                       hide=hide, edge=edge)

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


# ---- the retaining wall ---------------------------------------------------------
def niche_half(z):
    """The blind niche's half width at height z (0: none)."""
    if z < PLINTH[1] or z > 19.0:
        return 0.0
    if z < 14.5:
        return 4.5
    return math.sqrt(max(0.0, 4.5 ** 2 - (z - 14.5) ** 2))


def wall_courses(lay, keep=None, niche=True, x0=-HALF, x1=HALF, pil=True):
    """The wall's stones between x0 and x1: footing, plinth, ashlar with the
    niche set back, pilasters at the bay's ends, cornice, kerb."""
    for (a, b) in SKIRTS:
        lay.run(x0, x1, a, b, WT + 0.6, maxlen=9.5, keep=keep, chips=0)
    lay.run(x0, x1, PLINTH[0], PLINTH[1], WT + 0.8, maxlen=5.0, keep=keep, chips=2)
    pa, pb = (x0 + 1.5, x1 - 1.5) if pil else (x0, x1)
    for (a, b) in ASHLAR:
        zc = (a + b) / 2
        hw = niche_half(zc) if niche else 0.0
        if hw > 0.6:
            lay.run(pa, -hw, a, b, WT, keep=keep)
            lay.run(-hw, hw, a, b, WT - 1.4, y=0.7, keep=keep)
            lay.run(hw, pb, a, b, WT, keep=keep)
        else:
            lay.run(pa, pb, a, b, WT, keep=keep)
    if pil:
        for xc in (x0 + 0.75, x1 - 0.75):
            for (a, b) in ((2.0, 6.8), (6.8, 11.6), (11.6, 16.4), (16.4, 21.2), (21.2, 23.6)):
                if keep is None or keep(xc, (a + b) / 2):
                    edge = keep is not None and not keep(xc, b + 1.2)
                    lay.block((xc, 0.0, (a + b) / 2), (1.5 - T.JOINT, WT + 1.0, b - a - T.JOINT), chips=1,
                              hide=("-z", "+z"), edge=edge)
    lay.run(x0, x1, CORNICE[0], CORNICE[1], WT + 1.2, maxlen=5.0, keep=keep, chips=2, hide=("-z",))
    lay.run(x0, x1, KERBC[0], KERBC[1], WT, maxlen=3.4, keep=keep, chips=2, hide=("-z",))


def build_wall(lay):
    wall_courses(lay)
    y0, y1 = -WT / 2, WT / 2
    lay.far_boxes([((-HALF, y0, -SKIRT), (-4.5, y1, TOP)), ((4.5, y0, -SKIRT), (HALF, y1, TOP)),
                   ((-4.5, y0, 19.0), (4.5, y1, TOP)), ((-4.5, y0, -SKIRT), (4.5, y1, 2.0)),
                   ((-4.5, y0 + 1.4, 2.0), (4.5, y1, 19.0)),
                   ((-HALF, y0 - 0.5, 2.0), (-HALF + 1.5, y1 + 0.5, 23.6)), ((HALF - 1.5, y0 - 0.5, 2.0), (HALF, y1 + 0.5, 23.6)),
                   ((-HALF, y0 - 0.6, 23.6), (HALF, y1 + 0.6, 25.2))])
    lay.solids([((-HALF, -WT / 2 - 0.2, -SKIRT), (HALF, WT / 2 + 0.2, TOP))])


def burst_gone(x, z):
    return z > -4.0 and abs(x - 1.0) < 2.5 + (z + 4.0) * 0.36 + 1.3 * noise.noise(Vector((x * 0.21, z * 0.17, 3.3)))


def build_burst(lay):
    wall_courses(lay, keep=lambda x, z: not burst_gone(x, z))
    y0, y1 = -WT / 2 - 0.2, WT / 2 + 0.2
    boxes = [((-HALF, y0, -SKIRT), (-4.6, y1, 7.0)), ((-HALF, y0, 7.0), (-7.4, y1, 16.0)),
             ((5.8, y0, -SKIRT), (HALF, y1, 4.5)), ((7.9, y0, 4.5), (HALF, y1, 11.0)),
             ((-4.6, y0, -SKIRT), (5.8, y1, -4.0))]
    lay.far_boxes(boxes)
    lay.solids(boxes)


def stump_gone(x, z):
    return z > 8.0 + 0.3 * x + 3.5 * noise.noise(Vector((x * 0.16, 1.7, 0.4)))


def build_stump(lay):
    wall_courses(lay, keep=lambda x, z: not stump_gone(x, z), niche=False)
    y0, y1 = -WT / 2 - 0.2, WT / 2 + 0.2
    boxes = [((-HALF, y0, -SKIRT), (0.0, y1, 5.5)), ((0.0, y0, -SKIRT), (HALF, y1, 9.0))]
    lay.far_boxes(boxes)
    lay.solids(boxes)


# ---- the arcade -----------------------------------------------------------------
def pier_courses(lay, side, top, keep=None):
    """Half a pier (side -1 or 1) from the footing to `top`."""
    xa, xb = (-HALF, -HALF + PIER) if side < 0 else (HALF - PIER, HALF)
    for (a, b) in SKIRTS:
        lay.run(xa, xb, a, b, WT + 0.6, keep=keep, chips=0)
    lay.run(xa, xb, PLINTH[0], PLINTH[1], WT + 0.8, keep=keep, chips=2)
    for (a, b) in ASHLAR:
        if a >= top - 0.01:
            break
        impost = abs(b - SPRING) < 0.01 and top <= SPRING + 0.01
        lay.run(xa, xb, a, b, WT + (0.7 if impost else 0.0), keep=keep, chips=2, hide=("-z",) if impost else ("-z", "+z"))

def voussoirs(lay, which):
    n = 11
    rm = ARCH_R + RING / 2
    for i in which:
        a = -math.pi / 2 + (i + 0.5) * math.pi / n
        lay.block((rm * math.sin(a), 0.0, SPRING + rm * math.cos(a)), (2.0 * (ARCH_R + RING) * math.tan(math.pi / n / 2) - 0.05, WT + 0.3, RING),
                  tilt=(0.0, a), chips=1)


def arch_solids():
    y0, y1 = -WT / 2 - 0.2, WT / 2 + 0.2
    out = [((-HALF, y0, -SKIRT), (-ARCH_R, y1, SPRING)), ((ARCH_R, y0, -SKIRT), (HALF, y1, SPRING))]
    for (a, b) in ((14.0, 16.5), (16.5, 18.5), (18.5, 20.0), (20.0, 20.8)):
        hw = math.sqrt(max(0.0, ARCH_R ** 2 - (b - SPRING) ** 2))
        out.append(((-HALF, y0, a), (-hw, y1, b)))
        out.append(((hw, y0, a), (HALF, y1, b)))
    out.append(((-HALF, y0, 20.8), (HALF, y1, TOP)))
    return out


def build_arch(lay):
    for side in (-1, 1):
        pier_courses(lay, side, SPRING)
    voussoirs(lay, range(11))
    ro = ARCH_R + RING
    for (a, b) in ASHLAR:
        if a < SPRING - 0.01:
            continue
        xe = math.sqrt(max(0.0, ro ** 2 - (b - SPRING) ** 2))
        if xe < 0.5:
            lay.run(-HALF, HALF, a, b, WT)
        else:
            lay.run(-HALF, -xe, a, b, WT, maxlen=5.0)
            lay.run(xe, HALF, a, b, WT, maxlen=5.0)
    lay.run(-HALF, HALF, CORNICE[0], CORNICE[1], WT + 1.2, maxlen=5.0, chips=2, hide=("-z",))
    lay.run(-HALF, HALF, KERBC[0], KERBC[1], WT, maxlen=3.4, chips=2, hide=("-z",))
    boxes = arch_solids()
    lay.far_boxes(boxes)
    lay.solids(boxes)


def build_arch_broken(lay):
    r = lay.r
    left = lambda x, z: z < 15.2 + 1.6 * noise.noise(Vector((x * 0.5, z * 0.2, 9.1)))
    right = lambda x, z: z < 4.6 + 0.6 * (x - 8.0)
    pier_courses(lay, -1, 16.4, keep=left)
    pier_courses(lay, 1, 9.2, keep=right)
    voussoirs(lay, (0, 1))
    # What fell: arch stones and course blocks by the piers' feet, low.
    for i in range(11):
        sx, sy, sz = r.uniform(1.6, 3.0), r.uniform(1.4, 2.6), r.uniform(1.0, 1.8)
        x = r.uniform(-6.5, 7.0)
        y = r.uniform(-6.5, 5.0)
        if abs(y) < 2.2 and abs(x) < 4.0:
            y += 3.5 if y > 0 else -3.5
        lay.block((x, y, sz * 0.25), (sx, sy, sz), yaw=r.uniform(0, 3.1), tilt=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3)),
                  chips=3)
    y0, y1 = -WT / 2 - 0.2, WT / 2 + 0.2
    boxes = [((-HALF, y0, -SKIRT), (-ARCH_R, y1, 15.0)), ((ARCH_R, y0, -SKIRT), (HALF, y1, 4.6))]
    lay.far_boxes(boxes)
    lay.solids(boxes + [((-7.0, -7.0, -1.0), (7.5, -2.5, 1.4)), ((-7.0, 2.5, -1.0), (7.5, 5.5, 1.4))])


def build_slot(lay, beam):
    for side in (-1, 1):
        pier_courses(lay, side, SLOT_TOP if beam else 23.6)
        xa, xb = (-HALF, -HALF + PIER) if side < 0 else (HALF - PIER, HALF)
        if not beam:
            lay.run(xa, xb, CORNICE[0], CORNICE[1], WT + 1.2, chips=3, hide=("-z",))
            if side < 0:
                lay.run(xa, xb, KERBC[0], KERBC[1], WT, chips=3, hide=("-z",))
    y0, y1 = -WT / 2 - 0.2, WT / 2 + 0.2
    if beam:
        # The beam: three long stones on the piers' heads, the middle one settled.
        for (a, b, dz) in ((-HALF, -3.2, 0.0), (-3.2, 3.4, -0.22), (3.4, HALF, 0.0)):
            lay.block(((a + b) / 2, 0.0, (SLOT_TOP + 23.6) / 2 + dz), (b - a - T.JOINT, WT + 0.4, 23.6 - SLOT_TOP - T.JOINT), chips=2)
        lay.run(-HALF, HALF, CORNICE[0], CORNICE[1], WT + 1.2, maxlen=5.0, chips=2, hide=("-z",))
        lay.run(-HALF, HALF, KERBC[0], KERBC[1], WT, maxlen=3.4, chips=2, hide=("-z",))
        boxes = [((-HALF, y0, -SKIRT), (-ARCH_R, y1, SLOT_TOP)), ((ARCH_R, y0, -SKIRT), (HALF, y1, SLOT_TOP)),
                 ((-HALF, y0, SLOT_TOP - 0.3), (HALF, y1, TOP))]
    else:
        boxes = [((-HALF, y0, -SKIRT), (-ARCH_R, y1, TOP)), ((ARCH_R, y0, -SKIRT), (HALF, y1, 25.2))]
    lay.far_boxes(boxes)
    lay.solids(boxes)


# ---- the levels' floor ------------------------------------------------------------
def deck_slabs(r):
    """[(x0, x1, y0, y1)]: the bay's paving, four rows of four."""
    out = []
    ys = [-HALF] + [-HALF + BAY * (i + r.uniform(-0.15, 0.15)) / 4 for i in range(1, 4)] + [HALF]
    for ya, yb in zip(ys, ys[1:]):
        xs = [-HALF] + [-HALF + BAY * (i + r.uniform(-0.2, 0.2)) / 4 for i in range(1, 4)] + [HALF]
        for xa, xb in zip(xs, xs[1:]):
            out.append((xa, xb, ya, yb))
    return out


def build_deck(lay, broken):
    lay.p.ground = -100.0
    r = lay.r
    lost = lambda x, y: broken and x + 0.5 * y + 3.0 * noise.noise(Vector((x * 0.2, y * 0.2, 6.6))) > 0.5
    for (xa, xb, ya, yb) in deck_slabs(r):
        xc, yc = (xa + xb) / 2, (ya + yb) / 2
        dz = r.uniform(-0.05, 0.03)
        tilt = (r.uniform(-0.01, 0.01), r.uniform(-0.01, 0.01))
        heave = r.random() < 0.12
        if lost(xc, yc):
            continue
        edge = broken and (lost(xc + 4.5, yc) or lost(xc, yc + 4.5))
        if heave or edge:
            tilt = (r.uniform(-0.07, 0.07), r.uniform(-0.07, 0.07))
            dz += 0.12
        lay.block((xc, yc, -0.3 + dz), (xb - xa - 2 * T.JOINT, yb - ya - 2 * T.JOINT, 0.6), tilt=tilt,
                  chips=4 if edge else r.randint(0, 2), hide=("-z",))
    if not broken:
        lay.block((0, 0, -0.6 - (DECK_T - 0.6) / 2), (BAY - 0.04, BAY - 0.04, DECK_T - 0.6), chips=0)
        lay.far_boxes([((-HALF, -HALF, -DECK_T), (HALF, HALF, 0.0))])
        lay.solids([((-HALF, -HALF, -DECK_T), (HALF, HALF, 0.0))])
        return
    # The bed left under the slabs that stay: two stones, their broken sides ragged.
    z = -0.6 - (DECK_T - 0.6) / 2
    lay.block((-5.6, 0.0, z), (7.3, BAY - 0.04, DECK_T - 0.6), chips=3)
    lay.block((0.2, -5.4, z), (4.2, 7.6, DECK_T - 0.6), chips=4, edge=True)
    # A slab hanging off the break.
    lay.block((1.4, 2.0, -1.6), (4.4, 4.0, 0.6), tilt=(0.1, 0.6), chips=3)
    boxes = [((-HALF, -HALF, -DECK_T), (-1.9, HALF, 0.0)), ((-1.9, -HALF, -DECK_T), (2.3, -1.6, 0.0))]
    lay.far_boxes(boxes)
    lay.solids(boxes)


# ---- the stairs -------------------------------------------------------------------
def step_stones(lay, i, z_low):
    """Step i: its tread stones, and its bed from `z_low` up to under them."""
    r = lay.r
    ya = -HALF + i * TREAD
    yc = ya + TREAD / 2
    top = float(i + 1)
    lay.run(-HALF, HALF, top - 1.0, top, TREAD - T.JOINT, y=yc, maxlen=5.2, chips=2, hide=("-z", "+y"))
    if top - 1.0 - z_low > 0.2:
        lay.block((0.0, yc, (top - 1.0 + z_low) / 2), (BAY - 0.06, TREAD - 0.02, top - 1.0 - z_low), chips=0,
                  hide=("-z", "+y"))


def stair_boxes(z_low, y_from=-HALF):
    out = []
    for (i0, i1) in ((0, 3), (3, 6), (6, 9), (9, 13)):
        ya, yb = -HALF + i0 * TREAD, -HALF + i1 * TREAD
        if yb <= y_from:
            continue
        out.append(((-HALF, max(ya, y_from), z_low), (HALF, yb, float(i1) - 0.15)))
    return out


def build_stair(lay):
    for i in range(STEPS):
        step_stones(lay, i, -SKIRT)
    boxes = stair_boxes(-SKIRT)
    lay.far_boxes(boxes)
    lay.solids(boxes)


def build_stair_arch(lay):
    ya, yb = TUNNEL_Y
    floor = -STAIR_RISE - 1.0
    for i in range(STEPS):
        y0 = -HALF + i * TREAD
        over = y0 + TREAD > ya + 0.01
        step_stones(lay, i, TUNNEL_Z + 0.9 if over and i >= 2 else TUNNEL_Z)
    # The front pier under the first steps, its face to the way through.
    for (a, b) in ((floor, -9.0), (-9.0, -4.6), (-4.6, TUNNEL_Z)):
        lay.run(-HALF, HALF, a, b, ya + HALF - 0.02, y=(-HALF + ya) / 2, maxlen=5.0, chips=1, hide=("-z", "+z"))
    # The soffit: beams across the way, side by side along x.
    n = 5
    for k in range(n):
        xa, xb = -HALF + k * BAY / n, -HALF + (k + 1) * BAY / n
        lay.block(((xa + xb) / 2, (ya + yb) / 2, TUNNEL_Z + 0.45), (xb - xa - T.JOINT, yb - ya, 0.9), chips=1)
    boxes = [((-HALF, -HALF, floor), (HALF, ya, 2.0))]
    for (i0, i1) in ((1, 5), (5, 9), (9, 13)):
        boxes.append(((-HALF, max(ya, -HALF + i0 * TREAD), TUNNEL_Z), (HALF, -HALF + i1 * TREAD, float(i1) - 0.15)))
    lay.far_boxes(boxes)
    lay.solids(boxes)


# ---- what a burst wall spilled -----------------------------------------------------
def build_spill(lay):
    """A fan of fallen stone before a burst bay: origin as the wall's, the
    heap from the breach (y 2) down to y -17, 11 m deep at the wall."""
    r = lay.r
    # The heap's body: big stones leaning down the fall, bedded in each other.
    core = [((0.5, -1.0, 4.0), (11.0, 7.0, 9.0), 0.5), ((-0.5, -6.5, 2.2), (14.0, 7.0, 6.0), 0.45),
            ((0.8, -11.5, 0.6), (16.5, 6.5, 3.6), 0.4)]
    for c, s, lean in core:
        lay.block(c, s, tilt=(-lean, r.uniform(-0.06, 0.06)), yaw=r.uniform(-0.12, 0.12), chips=4, tone=0.8)
    # The stones on it and out past its foot.
    for i in range(30):
        y = r.uniform(-17.0, 1.5)
        spread = 4.5 + (1.5 - y) * 0.42
        x = max(-spread, min(spread, r.gauss(0.5, spread * 0.5)))
        z = max(0.0, 9.5 * (1.0 - (1.5 - y) / 15.0)) * max(0.0, 1.0 - (abs(x - 0.5) / (spread + 1.0)) ** 2)
        sx, sy, sz = r.uniform(1.6, 3.6), r.uniform(1.4, 2.8), r.uniform(1.0, 2.0)
        lay.block((x, y, z + sz * 0.2), (sx, sy, sz), yaw=r.uniform(0, 3.1), tilt=(r.uniform(-0.5, 0.2), r.uniform(-0.35, 0.35)),
                  chips=3)
    boxes = [((-5.5, -4.5, -1.0), (6.5, 2.0, 8.5)), ((-7.5, -10.0, -1.0), (7.5, -4.5, 5.0)), ((-9.0, -15.5, -1.0), (9.5, -10.0, 2.4))]
    lay.far_boxes(boxes)
    lay.solids(boxes)


JOBS = {
    "sanctuary_wall": lambda: both("sanctuary_wall", 61, build_wall),
    "sanctuary_wall_burst": lambda: both("sanctuary_wall_burst", 62, build_burst),
    "sanctuary_wall_stump": lambda: both("sanctuary_wall_stump", 63, build_stump),
    "sanctuary_arch": lambda: both("sanctuary_arch", 64, build_arch),
    "sanctuary_arch_broken": lambda: both("sanctuary_arch_broken", 65, build_arch_broken),
    "sanctuary_slot_open": lambda: both("sanctuary_slot_open", 67, lambda lay: build_slot(lay, False)),
    "sanctuary_deck": lambda: both("sanctuary_deck", 68, lambda lay: build_deck(lay, False)),
    "sanctuary_deck_broken": lambda: both("sanctuary_deck_broken", 69, lambda lay: build_deck(lay, True)),
    "sanctuary_stair": lambda: both("sanctuary_stair", 70, build_stair),
    "sanctuary_stair_arch": lambda: both("sanctuary_stair_arch", 71, build_stair_arch),
    "sanctuary_spill": lambda: both("sanctuary_spill", 72, build_spill),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
