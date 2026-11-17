"""The temple kit's great bridge (lane bridge): one stone arch over the gorge
south-west of the agora (seed 1), with a gate tower on each bank and its deck
broken through over the east haunch. scripts/endless/bridge_site.gd lays the
pieces in the bridge's own frame; they are built here already in place, in
the kit's stone (temple_lib).

    python tools/blender.py run art/blender/temple_kit/bridge_build.py [-- --only=bridge_crown]

The frame (Blender, z up; Godot (x, y, z) = Blender (x, z, -y)): x along the
span (u: 0 the arch's middle, + the east bank), y across, z the world's
height (the site's root sits at y 0). Every piece but the towers is modelled
where it stands; the west haunch is the east one turned half round.

Pieces:
- `bridge_crown`: the arch ring's crown (|u| < CROWN), the solid spandrel
  over it, the deck and its parapets.
- `bridge_haunch`: one haunch (u CROWN..ABUT): the ring, an open spandrel of
  two bays (a pier, a small vault over each bay), the deck.
- `bridge_haunch_broken`: the same with the deck, the outer bay's vault, half
  the inner one and the pier's top fallen: a breach BREACH_W wide at the deck.
- `bridge_abut_e`, `bridge_abut_w`: each bank's abutment, the ring's
  skewback and the deck out to the gate tower, stepped down to the land
  (GROUND_E / GROUND_W, sampled from seed 1's land).
- `bridge_tower`, `bridge_tower_broken`: a gate tower over the deck, origin
  on the deck's paving at the tower's middle; a gate GATE_W clear by GATE_TOP
  along x. The broken one has lost its -y top.
Each has a mid LOD (<piece>_mid.glb: the same stones, plain).
"""

import math
import sys

from mathutils import Vector, noise

import temple_lib as T

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = next((a.split("=")[1] for a in args if a.startswith("--only=")), None)

# ---- The bridge's numbers (bridge_site.gd keeps the same) ---------------------------
YS = 36.0                   # the ring's springing
R = 58.0                    # its intrados radius: 116 m clear
RING = 5.0
RO = R + RING
HW = 7.5                    # half the deck's width (the spandrels', the abutments')
RING_HW = 7.9               # the ring stands a little proud of the spandrel
YD = 104.0                  # the deck's paving
SOFFIT = 101.0              # under the deck's bed
CROWN = 29.5                # the solid spandrel's end
PIER = (40.5, 43.0)         # the open spandrel's pier
ABUT = 63.0                 # the abutment's face over the ring
BAYS = ((CROWN, PIER[0]), (PIER[1], ABUT))   # the open bays: 11 and (the flown one) 20 clear
VT = 1.2                    # a small vault's ring
# Each bay's vault: [middle, radius (half the bay), springing (its crown's back meets the bed)].
VAULTS = [((a + b) / 2, (b - a) / 2, SOFFIT - VT - (b - a) / 2 + 0.5) for a, b in BAYS]
VS = min(v[2] for v in VAULTS)  # the lower springing (the outer bay's, 90.3)
# Where a vault's band of fill or its boxes break, as parts of its radius.
VAULT_BANDS = (0.37, 0.69, 0.91)
TOWER_U = 84.0              # the gate towers' middles (u)
TOWER_HU = 7.0              # half their length along u
TOWER_HW = 13.0             # half their width
GATE_HW = HW                # the gate: 15 clear
GATE_S = 16.0               # its springing over the deck
GATE_TOP = GATE_S + GATE_HW # 23.5
TOWER_H = 41.2
BREACH = (40.5, 63.0)       # the broken haunch's breach at the deck
COURSE = 2.4

# Seed 1's land under each abutment: the lowest ground across (|v| < 9) at
# u = 54, 55, ... 94 (bridge_site.gd's frame; scratch land dump, 2 m grid).
GROUND_E = [19.8, 22.9, 24.8, 27.1, 31.5, 36.0, 40.6, 44.4, 46.2, 47.8, 50.1, 52.0, 53.7, 56.1, 59.1, 63.8, 66.6,
            67.5, 69.7, 70.2, 72.0, 75.0, 78.3, 82.4, 84.3, 85.0, 85.8, 87.4, 88.8, 90.7, 92.6, 94.8, 92.9, 91.6,
            91.1, 89.6, 87.6, 87.0, 87.3, 87.1, 85.7]
GROUND_W = [25.4, 27.4, 30.1, 32.7, 35.4, 37.5, 39.6, 41.9, 44.0, 46.9, 50.4, 53.6, 57.2, 60.9, 64.0, 66.6, 67.3,
            66.9, 66.4, 70.5, 78.0, 80.2, 84.4, 89.4, 94.1, 94.8, 95.1, 95.4, 95.8, 96.4, 96.9, 97.4, 97.7, 97.6,
            97.5, 97.8, 98.2, 99.6, 101.1, 102.4, 103.6]


def ground(table, a, b):
    """The lowest ground under |u| a..b."""
    i0 = max(0, int(math.floor(a)) - 54)
    i1 = min(len(table) - 1, int(math.ceil(b)) - 54)
    return min(table[i0:i1 + 1]) if i1 >= i0 else table[-1]


def extrados(x):
    return YS + math.sqrt(max(0.0, RO * RO - x * x))


class Lay:
    """Blocks for one piece at one LOD (as sanctuary_build.py): the near's cut
    and chipped, the mid's plain boxes; layout draws come from `r`."""

    def __init__(self, name, seed, mid):
        self.p = T.Piece(name, seed=seed)
        self.p.ground = -1000.0
        self.r = T.random.Random(seed * 31 + 7)
        self.mid = mid

    def block(self, c, s, chips=1, hide=(), edge=False, **kw):
        if self.mid:
            self.p.block(c, s, bevel=0.0, chips=0, jitter=0.0, far=False, hide=hide,
                         **{k: v for k, v in kw.items() if k in ("yaw", "tilt", "tone")})
            return
        if edge:
            self.p.block(c, s, chips=4, chip_depth=(0.3, 0.9), far=False, **{k: v for k, v in kw.items() if k != "hide"})
        else:
            self.p.block(c, s, chips=chips, far=False, hide=hide, **kw)

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

    def cuts(self, a, b, maxlen, jit=0.18):
        n = max(1, math.ceil((b - a) / maxlen))
        return [a] + [a + (b - a) * (i + self.r.uniform(-jit, jit)) / n for i in range(1, n)] + [b]

    def course(self, x0, x1, z0, z1, k=0, maxlen=4.2, keep=None, chips=1, y0=-HW, y1=HW, hide=("-z", "+z"),
               bottom=None, ends=(True, True)):
        """One course of the bridge's masonry, x0..x1 along, z0..z1 high,
        y0..y1 across in stones of ~5 m (staggered by the course's index k).
        `bottom(xa, xb)` lifts a stone's foot (onto the ring's back); `keep(x,
        z)` drops a stone, one beside a dropped one is ragged. `ends`: whether
        the course's first and last stones show their ends."""
        if x1 - x0 < 0.45 or z1 - z0 < 0.3:
            return
        xs = self.cuts(x0, x1, maxlen)
        w = y1 - y0
        n = max(1, round(w / 5.0))
        if k % 2 and n > 1:
            ys = [y0, y0 + w / (2 * n)] + [y0 + w / (2 * n) + w * i / n for i in range(1, n)] + [y1]
        else:
            ys = [y0 + w * i / n for i in range(n + 1)]
        for i, (a, b) in enumerate(zip(xs, xs[1:])):
            zb = z0 if bottom is None else max(z0, bottom(a, b))
            if z1 - zb < 0.3:
                continue
            xc, zc = (a + b) / 2, (zb + z1) / 2
            if keep is not None and not keep(xc, zc):
                continue
            edge = keep is not None and not (keep(a - 1.5, zc) and keep(b + 1.5, zc) and keep(xc, z1 + 1.2))
            hx = []
            if i > 0 or not ends[0]:
                hx.append("-x")
            if i < len(xs) - 2 or not ends[1]:
                hx.append("+x")
            for j, (ya, yb) in enumerate(zip(ys, ys[1:])):
                hy = []
                if j > 0:
                    hy.append("-y")
                if j < len(ys) - 2:
                    hy.append("+y")
                self.block((xc, (ya + yb) / 2, zc), (b - a - T.JOINT, yb - ya - T.JOINT, z1 - zb - T.JOINT),
                           chips=self.r.randint(0, chips), hide=tuple(hide) + tuple(hx) + tuple(hy), edge=edge)


def both(name, seed, fn):
    for mid in (False, True):
        lay = Lay(name, seed, mid)
        fn(lay)
        lay.export(name)


# ---- the ring ------------------------------------------------------------------------
NV = 72          # voussoirs over the half circle


def ring(lay, x0, x1, keep=None):
    """The main ring's voussoirs whose middles lie in x0..x1, three across."""
    rm = R + RING / 2
    for i in range(NV):
        a = -math.pi / 2 + (i + 0.5) * math.pi / NV
        x = rm * math.sin(a)
        if not (x0 <= x < x1):
            continue
        z = YS + rm * math.cos(a)
        if keep is not None and not keep(x, z):
            continue
        chord = 2.0 * RO * math.tan(math.pi / NV / 2) - 0.06
        ys = [-RING_HW, -2.6, 2.6, RING_HW] if i % 2 else [-RING_HW, -4.0, 1.2, RING_HW]
        for j, (ya, yb) in enumerate(zip(ys, ys[1:])):
            hy = ("-y",) if j > 0 else ()
            hy += ("+y",) if j < 2 else ()
            lay.block((x, (ya + yb) / 2, z), (chord, yb - ya - T.JOINT, RING), tilt=(0.0, a), chips=1,
                      hide=("-x", "+x") + hy)


def ring_far(lay, x0, x1):
    """The ring's far LOD: 36 tilted slabs."""
    rm = R + RING / 2
    n = 36
    for i in range(n):
        a = -math.pi / 2 + (i + 0.5) * math.pi / n
        x = rm * math.sin(a)
        if not (x0 <= x < x1):
            continue
        chord = 2.0 * RO * math.tan(math.pi / n / 2)
        lay.p.far_box((x, 0.0, YS + rm * math.cos(a)), (chord, 2 * RING_HW, RING), tilt=(0.0, a))


def ring_solids(x0, x1):
    out = []
    n = 30
    for i in range(n):
        a0 = -math.pi / 2 + i * math.pi / n
        a1 = a0 + math.pi / n
        xm = (R + RING / 2) * math.sin((a0 + a1) / 2)
        if not (x0 <= xm < x1):
            continue
        pts = [(rr * math.sin(a), YS + rr * math.cos(a)) for rr in (R, RO) for a in (a0, a1)]
        xs = [p[0] for p in pts]
        zs = [p[1] for p in pts]
        out.append(((min(xs), -RING_HW, min(zs)), (max(xs), RING_HW, max(zs))))
    return out


# ---- the deck ------------------------------------------------------------------------
def deck(lay, x0, x1, keep=None, parapet=(True, True)):
    """The deck from x0 to x1: its bed, paving, the cornice under its edges and
    the parapets (each side's on or off)."""
    lay.course(x0, x1, SOFFIT, YD - 0.6, 0, maxlen=4.6, keep=keep, chips=0)
    xs = lay.cuts(x0, x1, 3.8, 0.12)
    for a, b in zip(xs, xs[1:]):
        ys = [-HW + 0.9, -3.0, 0.4, 3.6, HW - 0.9] if lay.r.random() < 0.5 else [-HW + 0.9, -3.8, -0.2, 3.1, HW - 0.9]
        for ya, yb in zip(ys, ys[1:]):
            xc, yc = (a + b) / 2, (ya + yb) / 2
            if keep is not None and not keep(xc, YD - 0.3):
                continue
            tilt = (lay.r.uniform(-0.012, 0.012), lay.r.uniform(-0.012, 0.012))
            lay.block((xc, yc, YD - 0.3 + lay.r.uniform(-0.05, 0.02)), (b - a - 2 * T.JOINT, yb - ya - 2 * T.JOINT, 0.6),
                      tilt=tilt, chips=lay.r.randint(0, 2), hide=("-z",))
    for side, on in zip((-1, 1), parapet):
        lay.course(x0, x1, SOFFIT - 0.5, SOFFIT + 1.0, 1, maxlen=3.4, keep=keep, chips=2,
                   y0=side * (HW - 0.4) if side > 0 else -HW - 0.5, y1=HW + 0.5 if side > 0 else -(HW - 0.4), hide=("+z",))
        if on:
            lay.course(x0, x1, YD - 0.6, YD + 1.3, 1, maxlen=2.9, keep=keep, chips=3,
                       y0=HW - 0.9 if side > 0 else -HW, y1=HW if side > 0 else -(HW - 0.9), hide=("-z",))


def deck_solids(x0, x1, parapet=(True, True)):
    out = [((x0, -HW, SOFFIT), (x1, HW, YD))]
    for side, on in zip((-1, 1), parapet):
        if on:
            out.append(((x0, HW - 0.9, YD), (x1, HW, YD + 1.3)) if side > 0 else ((x0, -HW, YD), (x1, -(HW - 0.9), YD + 1.3)))
    return out


# ---- the crown -----------------------------------------------------------------------
SPANDREL_Z = [88.4, 90.6, 92.8, 95.0, 97.2, 99.2, SOFFIT]


def build_crown(lay):
    ring(lay, -CROWN, CROWN)
    for k, (z0, z1) in enumerate(zip(SPANDREL_Z, SPANDREL_Z[1:])):
        if z1 - YS >= RO:
            xa = 0.0
        else:
            xa = math.sqrt(RO * RO - (z1 - YS) ** 2)
        if xa >= CROWN:
            continue
        foot = lambda a, b: extrados(max(abs(a), abs(b))) - 0.2
        if xa < 0.5:
            lay.course(-CROWN, CROWN, z0, z1, k, bottom=foot, maxlen=3.4)
        else:
            lay.course(xa, CROWN, z0, z1, k, bottom=foot, maxlen=3.4)
            lay.course(-CROWN, -xa, z0, z1, k, bottom=foot, maxlen=3.4)
    deck(lay, -CROWN, CROWN)
    ring_far(lay, -CROWN, CROWN)
    far = [((x0, -HW, extrados(max(abs(x0), abs(x1)))), (x1, HW, YD)) for x0, x1 in
           ((-CROWN, -20.0), (-20.0, -10.0), (-10.0, 10.0), (10.0, 20.0), (20.0, CROWN))]
    far += [((-CROWN, -HW, YD), (CROWN, -HW + 0.9, YD + 1.3)), ((-CROWN, HW - 0.9, YD), (CROWN, HW, YD + 1.3))]
    lay.far_boxes(far)
    sol = ring_solids(-CROWN, CROWN)
    sol += [((x0, -HW, extrados(max(abs(x0), abs(x1))) - 1.0), (x1, HW, SOFFIT)) for x0, x1 in
            ((-CROWN, -24.0), (-24.0, -16.0), (-16.0, -8.0), (-8.0, 8.0), (8.0, 16.0), (16.0, 24.0), (24.0, CROWN))]
    sol += deck_solids(-CROWN, CROWN)
    lay.solids(sol)


# ---- the haunch ----------------------------------------------------------------------
def vault(lay, xm, vr, vs, keep=None):
    """A small vault over a bay (xm its middle, vr its radius, vs its springing), across the whole width."""
    n = 9 if vr < 8.0 else 11
    rm = vr + VT / 2
    for i in range(n):
        a = -math.pi / 2 + (i + 0.5) * math.pi / n
        x, z = xm + rm * math.sin(a), vs + rm * math.cos(a)
        if keep is not None and not keep(x, z):
            continue
        chord = 2.0 * (vr + VT) * math.tan(math.pi / n / 2) - 0.05
        for ya, yb in ((-HW, -2.4), (-2.4, 2.6), (2.6, HW)):
            lay.block((x, (ya + yb) / 2, z), (chord, yb - ya - T.JOINT, VT), tilt=(0.0, a), chips=1,
                      hide=("-x", "+x") + (("-y",) if ya > -HW else ()) + (("+y",) if yb < HW else ()))


HAUNCH_Z = [VS, 94.2, 96.6, 99.0, SOFFIT]


def breach_top(x):
    """The broken haunch's stone stands up to here (less up to 1.6 of noise)."""
    if x < PIER[0]:
        return 92.0 + 2.2 * (PIER[0] - x)
    if x <= PIER[1] + 0.5:
        return 92.0
    return 86.0


def haunch(lay, broken):
    gone = None
    if broken:
        def gone_at(x, z):
            return z > breach_top(x) + 1.6 * noise.noise(Vector((x * 0.23, z * 0.19, 4.4)))
        gone = gone_at
    keep = (lambda x, z: not gone(x, z)) if gone else None
    ring(lay, CROWN, RO + 0.1)
    # The pier, from the ring's back to the vaults' springing, then on up in the fill.
    z = extrados(PIER[1]) - 0.3
    k = 0
    while z < VS - 0.01:
        z1 = VS if VS - z < 3.4 else z + COURSE
        lay.course(PIER[0], PIER[1], z, z1, k, maxlen=4.0, keep=keep, chips=1)
        z, k = z1, k + 1
    for xm, vr, vs in VAULTS:
        vault(lay, xm, vr, vs, keep=keep)
    (m0, _, _), (m1, _, _) = VAULTS

    def half_open(vr, vs, z):
        """Half the bay's opening (the vault's back) at the top of a band up to z."""
        if z <= vs:
            return vr
        return math.sqrt(max(0.0, (vr + VT) ** 2 - (z - vs) ** 2))

    for k, (z0, z1) in enumerate(zip(HAUNCH_Z, HAUNCH_Z[1:])):
        x0 = half_open(VAULTS[0][1], VAULTS[0][2], z1)
        x1 = half_open(VAULTS[1][1], VAULTS[1][2], z1)
        segs = []
        for a, b in ((CROWN, m0 - x0), (m0 + x0, m1 - x1), (m1 + x1, ABUT)):
            if b - a > 0.3:
                segs.append((a, b))
        for a, b in segs:
            # The crown's courses end at CROWN; its first stone over the bay shows its face.
            lay.course(max(a, CROWN), b, z0, z1, k + 1, maxlen=3.6, keep=keep, ends=(a > CROWN + 0.1, b < ABUT - 0.1))
    if broken:
        dk = lambda x, z: x < BREACH[0] + 1.2 * noise.noise(Vector((z * 0.4, x * 0.3, 1.9)))
        deck(lay, CROWN, BREACH[0] + 1.6, keep=dk)
        # What hangs at the break: a slab of the bed tipped down into the breach.
        lay.block((BREACH[0] + 1.6, 3.0, SOFFIT - 0.8), (4.2, 5.0, 1.6), tilt=(0.15, 0.55), chips=3)
        lay.block((BREACH[0] + 0.8, -4.1, SOFFIT - 1.4), (3.4, 4.4, 1.5), tilt=(-0.2, 0.75), chips=3)
    else:
        deck(lay, CROWN, ABUT)
    ring_far(lay, CROWN, RO + 0.1)
    y0, y1 = -HW, HW
    pier_top = 93.6 if broken else SOFFIT
    far = [((PIER[0], y0, extrados(PIER[1])), (PIER[1], y1, pier_top))]
    sol = ring_solids(CROWN, RO + 0.1)
    sol.append(((PIER[0], y0, extrados(PIER[1]) - 1.0), (PIER[1], y1, pier_top)))
    # Over each bay: the vault's back and the fill, in bands.
    for bi, ((m, vr, vs), (ba, bb)) in enumerate(zip(VAULTS, BAYS)):
        zs = [vs] + [vs + f * vr for f in VAULT_BANDS] + [SOFFIT]
        for z0, z1 in zip(zs, zs[1:]):
            hw = math.sqrt(max(0.0, vr * vr - (z1 - vs) ** 2)) if z1 - vs < vr else 0.0
            if broken and bi == 1:
                continue
            out = [((ba, y0, z0), (m - hw, y1, z1)), ((m + hw, y0, z0), (bb, y1, z1))] if hw > 0.3 else \
                [((ba, y0, z0), (bb, y1, z1))]
            if broken:
                # What stands of the inner bay: each box cut down to the breach at its inner end.
                cut = []
                for lo, hi in out:
                    top = min(hi[2], breach_top(lo[0]) + 1.6)
                    if top > lo[2] + 0.2:
                        cut.append((lo, (hi[0], hi[1], top)))
                out = cut
            far += out
            sol += out
    if broken:
        far += deck_solids(CROWN, BREACH[0])
        sol += deck_solids(CROWN, BREACH[0])
    else:
        far += deck_solids(CROWN, ABUT)
        sol += deck_solids(CROWN, ABUT)
    lay.far_boxes(far)
    lay.solids(sol)


# ---- the abutments -------------------------------------------------------------------
COLS = [(54.5, 58.0), (58.0, ABUT), (ABUT, 66.5), (66.5, 70.0), (70.0, 73.5), (73.5, 77.0), (77.0, 80.5),
        (80.5, 84.0), (84.0, 87.5), (87.5, 91.0)]


def abutment(lay, side, table):
    """One bank's abutment (side +1 east, -1 west), modelled where it stands."""
    s = side
    far = []
    sol = []
    for ci, (a, b) in enumerate(COLS):
        g = ground(table, a, b) - 3.0
        top = YS + 0.2 if b <= ABUT else SOFFIT
        if a >= ABUT:
            # The face over the ring: the first column's courses step up the ring's back.
            pass
        z = math.floor(g / COURSE) * COURSE
        k = 0
        while z < top - 0.01:
            z1 = min(top, z + COURSE)
            if top - z1 < 0.6:
                z1 = top
            # A course shows its ends where its neighbour column is shorter.
            prev = COLS[ci - 1] if ci > 0 else None
            nxt = COLS[ci + 1] if ci + 1 < len(COLS) else None
            def stands(col, zz):
                if col is None:
                    return False
                ta = YS + 0.2 if col[1] <= ABUT else SOFFIT
                return ground(table, *col) - 3.0 <= zz and zz < ta
            inner = stands(prev, z1 - 0.1)
            outer = stands(nxt, z1 - 0.1)
            lo, hi = (a, b) if s > 0 else (-b, -a)
            ends = (not inner, not outer) if s > 0 else (not outer, not inner)
            lay.course(lo, hi, z, z1, k + int(a), maxlen=3.6, chips=1 if z1 > g + 6 else 0, ends=ends)
            z = z1
            k += 1
        lo, hi = (a, b) if s > 0 else (-b, -a)
        far.append(((lo, -HW, g), (hi, HW, top)))
        sol.append(((lo, -HW, g), (hi, HW, top)))
    # The deck out to the tower, and under it through the gate.
    x0, x1 = ABUT, TOWER_U + TOWER_HU
    if s > 0:
        deck(lay, x0, TOWER_U - TOWER_HU)
        deck(lay, TOWER_U - TOWER_HU, x1, parapet=(False, False))
        far += deck_solids(x0, TOWER_U - TOWER_HU) + deck_solids(TOWER_U - TOWER_HU, x1, (False, False))
        sol += deck_solids(x0, TOWER_U - TOWER_HU) + deck_solids(TOWER_U - TOWER_HU, x1, (False, False))
    else:
        deck(lay, -(TOWER_U - TOWER_HU), -x0)
        deck(lay, -x1, -(TOWER_U - TOWER_HU), parapet=(False, False))
        far += deck_solids(-(TOWER_U - TOWER_HU), -x0) + deck_solids(-x1, -(TOWER_U - TOWER_HU), (False, False))
        sol += deck_solids(-(TOWER_U - TOWER_HU), -x0) + deck_solids(-x1, -(TOWER_U - TOWER_HU), (False, False))
    lay.far_boxes(far)
    lay.solids(sol)


# ---- the gate towers ------------------------------------------------------------------
SKIRT = 30.0
TOWER_Z = [-SKIRT + 3.0 * i for i in range(10)] + [0.0, 2.4, 4.8, 7.2, 9.6, 12.0, 14.4, 16.0, 18.4, 20.8, 23.2, 25.6,
           28.0, 30.4, 32.8, 35.2, 37.0, 38.6, TOWER_H]


def tower(lay, broken):
    """A gate tower, origin on the deck's paving at its middle."""
    r = lay.r

    def gone(x, y, z):
        if not broken:
            return False
        n = 2.2 * noise.noise(Vector((x * 0.21, y * 0.17, z * 0.09 + 3.0)))
        top = 44.0 if y > 4.0 else 44.0 - (4.0 - y) * 1.7
        return z > top + n
    hu = TOWER_HU
    for k, (z0, z1) in enumerate(zip(TOWER_Z, TOWER_Z[1:])):
        below = z1 <= 0.01
        chips = 0 if below else 2
        if z1 <= GATE_S + 0.01:
            # The legs, either side of the gate (and under the deck).
            for sgn in (-1, 1):
                ya, yb = (GATE_HW, TOWER_HW) if sgn > 0 else (-TOWER_HW, -GATE_HW)
                keep = lambda x, z, ya=ya, yb=yb: not gone(x, (ya + yb) / 2, z)
                lay.course(-hu, hu, z0, z1, k, maxlen=3.6 if not below else 7.0, chips=chips, y0=ya, y1=yb, keep=keep,
                           hide=("-z", "+z"))
            continue
        if z0 >= 36.9:
            # The cornice and the battlements.
            if z1 <= 38.61:
                for sgn in (-1, 1):
                    pass
                keep = lambda x, z: True
                ys = [-TOWER_HW - 0.6, -6.0, 0.0, 6.0, TOWER_HW + 0.6]
                for ya, yb in zip(ys, ys[1:]):
                    for x0, x1 in ((-hu - 0.6, -2.0), (-2.0, 2.4), (2.4, hu + 0.6)):
                        if gone((x0 + x1) / 2, (ya + yb) / 2, (z0 + z1) / 2):
                            continue
                        lay.block(((x0 + x1) / 2, (ya + yb) / 2, (z0 + z1) / 2), (x1 - x0 - T.JOINT, yb - ya - T.JOINT, z1 - z0 - T.JOINT),
                                  chips=2, hide=("-z",))
            else:
                # Merlons round the top's edge.
                for (cx, cy, sx, sy) in [(x, -TOWER_HW + 0.7, 2.6, 1.4) for x in (-5.2, 0.0, 5.2)] + \
                                        [(x, TOWER_HW - 0.7, 2.6, 1.4) for x in (-5.2, 0.0, 5.2)] + \
                                        [(-hu + 0.7, y, 1.4, 2.6) for y in (-8.4, -2.8, 2.8, 8.4)] + \
                                        [(hu - 0.7, y, 1.4, 2.6) for y in (-8.4, -2.8, 2.8, 8.4)]:
                    if gone(cx, cy, (z0 + z1) / 2):
                        continue
                    lay.block((cx, cy, (z0 + z1) / 2), (sx, sy, z1 - z0 - T.JOINT), chips=2, hide=("-z",))
            continue
        # Over the gate's springing: the courses, cut by the arch.
        ro = GATE_HW + 1.5
        ye = math.sqrt(max(0.0, ro * ro - (z1 - GATE_S) ** 2))
        segs = [(-TOWER_HW, -ye), (ye, TOWER_HW)] if ye > 0.4 else [(-TOWER_HW, TOWER_HW)]
        for ya, yb in segs:
            # A course along y here: blocks laid along y (turned), two deep along x.
            ys = lay.cuts(ya, yb, 3.4)
            for i, (a, b) in enumerate(zip(ys, ys[1:])):
                for x0, x1 in ((-hu, 0.0), (0.0, hu)):
                    if gone((x0 + x1) / 2, (a + b) / 2, (z0 + z1) / 2):
                        continue
                    hide = ["-z", "+z", "+x" if x0 < 0 else "-x"]
                    lay.block(((x0 + x1) / 2, (a + b) / 2, (z0 + z1) / 2), (x1 - x0 - T.JOINT, b - a - T.JOINT, z1 - z0 - T.JOINT),
                              chips=r.randint(0, 2), hide=tuple(hide))
    # The gate's arch: voussoirs across y, a barrel along x.
    n = 11
    rm = GATE_HW + 0.75
    for i in range(n):
        a = -math.pi / 2 + (i + 0.5) * math.pi / n
        y, z = rm * math.sin(a), GATE_S + rm * math.cos(a)
        if gone(0.0, y, z):
            continue
        chord = 2.0 * (GATE_HW + 1.5) * math.tan(math.pi / n / 2) - 0.05
        for x0, x1 in ((-hu - 0.3, -2.3), (-2.3, 2.3), (2.3, hu + 0.3)):
            lay.block(((x0 + x1) / 2, y, z), (x1 - x0 - T.JOINT, chord, 1.5), tilt=(-a, 0.0), chips=1,
                      hide=("-y", "+y") + (("-x",) if x0 > -hu else ()) + (("+x",) if x1 < hu else ()))
    # The far LOD and the solids: legs, the mass over the gate (stepped), the top.
    far = []
    sol = []
    for sgn in (-1, 1):
        ya, yb = (GATE_HW, TOWER_HW) if sgn > 0 else (-TOWER_HW, -GATE_HW)
        top = 38.6 if not broken or sgn > 0 else 26.0
        far.append(((-hu, ya, -SKIRT), (hu, yb, top)))
        sol.append(((-hu, ya, -SKIRT), (hu, yb, top)))
    for z0, z1 in ((GATE_S, GATE_S + 3.5), (GATE_S + 3.5, GATE_S + 5.8), (GATE_S + 5.8, GATE_TOP + 1.0)):
        hy = math.sqrt(max(0.0, GATE_HW ** 2 - (z1 - GATE_S) ** 2))
        if broken:
            far += [((-hu, hy, z0), (hu, GATE_HW, z1))]
            sol += [((-hu, hy, z0), (hu, GATE_HW, z1))]
        else:
            far += [((-hu, -GATE_HW, z0), (hu, -hy, z1)), ((-hu, hy, z0), (hu, GATE_HW, z1))]
            sol += [((-hu, -GATE_HW, z0), (hu, -hy, z1)), ((-hu, hy, z0), (hu, GATE_HW, z1))]
    if broken:
        far += [((-hu, 0.0, GATE_TOP + 1.0), (hu, TOWER_HW, 38.6)), ((-hu, -5.0, GATE_TOP + 1.0), (hu, 0.0, 34.0))]
        sol += [((-hu, 0.0, GATE_TOP + 1.0), (hu, TOWER_HW, 38.6)), ((-hu, -5.0, GATE_TOP + 1.0), (hu, 0.0, 34.0))]
    else:
        far += [((-hu, -GATE_HW, GATE_TOP + 1.0), (hu, GATE_HW, 38.6))]
        sol += [((-hu, -GATE_HW, GATE_TOP + 1.0), (hu, GATE_HW, 38.6))]
    lay.far_boxes(far)
    lay.solids(sol)


JOBS = {
    "bridge_crown": lambda: both("bridge_crown", 81, build_crown),
    "bridge_haunch": lambda: both("bridge_haunch", 82, lambda lay: haunch(lay, False)),
    "bridge_haunch_broken": lambda: both("bridge_haunch_broken", 83, lambda lay: haunch(lay, True)),
    "bridge_abut_e": lambda: both("bridge_abut_e", 84, lambda lay: abutment(lay, 1, GROUND_E)),
    "bridge_abut_w": lambda: both("bridge_abut_w", 85, lambda lay: abutment(lay, -1, GROUND_W)),
    "bridge_tower": lambda: both("bridge_tower", 86, lambda lay: tower(lay, False)),
    "bridge_tower_broken": lambda: both("bridge_tower_broken", 87, lambda lay: tower(lay, True)),
}

for name, job in JOBS.items():
    if only is None or only == name:
        job()
