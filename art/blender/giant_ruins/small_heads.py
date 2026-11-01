"""The 55 m heads, the size that sat on the stomper's shoulders.

    python3 tools/blender.py run art/blender/giant_ruins/small_heads.py -- [--voxel 0.35] [--only warden_55]

These are not the 120 m heads scaled: each face is carved here in true metres,
for this size. Hard planes meet hard planes (a carver's cuts, no smin), on one
rounded mass laid in the body's stone: courses round the head's own axis, whole
stone across the face (`spare`), so joints never run through a nose. Only
elder_55 is hollow, a straight bore that a plane can fly (giant_head_build.py
ROUTES); the others' sockets are blind. Same axes as giant_head_build.py: the
face looks down -Y, Z up. Run alone this renders the stills; the game's set is
built by giant_head_build.py, which imports the pieces.
"""
import argparse
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import giant_head_build as ruin  # noqa: E402
from stomper_body_build import Dome, Mass, ease_walls, material, place, plane, shot, stage, wrapped  # noqa: E402

STONE = 0.85                                                                   # near the body's stone: a head is few courses
CALM = 0.5                                                                     # the laid stone keeps half its steps: more reads as bandages
BOUNDS = ((-38, -42, -2), (38, 36, 59))
# WorldScale.opening(TOY_BORE) at the game's plane: 2 x the toy width. 16 m across.
TOY_BORE = 8.0
BORE = TOY_BORE * 2.0
BORE_TALL = 9.0
BORE_Z = 13.8


def add(d, stone):
    return np.minimum(d, stone)


def cut(d, stone):
    return np.maximum(d, -stone)


def step(a, b, t):
    u = np.clip((t - a) / (b - a), 0, 1)
    return u * u * (3 - 2 * u)


def face_mask(f, low, high, half, front):
    """1 on the carved face, 0 on the stone laid round it."""
    return step(front + 7, front - 1, f.Y) * step(half + 4, half - 3, np.abs(f.X)) * step(low - 5, low, f.Z) * step(high + 4, high, f.Z)


class Relief:
    """A face cut the way a carver cuts one: flat shapes drawn on the front of
    the head (x, z), each standing proud or sunk of what's there, its edge one
    straight chisel slope. A shape thin enough never reaches its height, so it
    comes to a ridge, as a nose does. It rides the mass, so nothing can float
    off the surface or stab out past it."""

    def __init__(self, f):
        self.f = f
        self.x, self.z = np.meshgrid(f.xs, f.zs, indexing="ij")
        self.r = np.zeros_like(self.x)

    def edge(self, pts, pair=False):
        """Metres out of the polygon, on both sides of the face if `pair`."""
        x, z = (np.abs(self.x) if pair else self.x), self.z
        pts = np.array(pts, np.float32)
        best = np.full(x.shape, 1e9, np.float32)
        inside = np.zeros(x.shape, bool)
        for a, b in zip(pts, np.roll(pts, 1, 0)):
            e = b - a
            wx, wz = x - a[0], z - a[1]
            t = np.clip((wx * e[0] + wz * e[1]) / float(e @ e), 0, 1)
            best = np.minimum(best, (wx - e[0] * t) ** 2 + (wz - e[1] * t) ** 2)
            over = (z >= a[1]) != (z >= b[1])
            inside ^= over & (x < e[0] * wz / (e[1] if e[1] != 0 else 1e-6) + a[0])
        return np.sqrt(best) * np.where(inside, -1, 1)

    def ring(self, c, r, w):
        return np.abs(np.hypot(self.x - c[0], self.z - c[1]) - r) - w

    def up(self, sd, height, slope=1.0):
        """Proud by `height`, sunk if it is negative."""
        self.r += np.sign(height) * np.clip(-sd * slope, 0, abs(height))

    def on(self, d, depth=8.0):
        """The field with the relief on its front."""
        f = self.f
        return d - self.r[:, None, :] * step(depth, -depth, f.Y)


def sym(*side):
    """A polygon from its right side, x >= 0, top to bottom."""
    return list(side) + [(-x, z) for x, z in reversed(side) if x]


def warden_55(f):
    """Long and stern: a tall crown set in from the brow, a slot of an eye under
    one straight brow, a long wedge of a nose, a plain square beard."""
    jaw = Mass(f, ((-2, 0, 1, 17.5, 21), (12, 0, 1, 19.5, 22), (26, 0, 2, 21, 23), (38, 0, 3, 21, 23), (43, 0, 3, 19, 22)), 2.5, 1.25)
    crown = Mass(f, ((39, 0, 4, 20.5, 22.5), (47, 0, 5, 18.5, 20.5), (56, 0, 6, 15.5, 17.5)), 1.5, 1.2)
    d = jaw.field()
    for s in (-1, 1):
        d = np.maximum(d, plane(f, (s * 0.7, -0.7, 0), (s * 15, -19, 0)))      # the cheek's plane
    d = np.maximum(d, plane(f, (0, -1, 0.03), (0, -20, 22)))                   # the face's plane
    c = crown.field()
    d = add(d, c)
    d = add(d, np.maximum(jaw.field() - 1.4, np.abs(f.Z - 40.2) - 1.8))        # the crown's band, a hard ledge
    d = cut(d, np.maximum(np.abs(f.Z - 48.5) - 0.55, -c - 1.0))                 # a ring cut round the crown
    r = Relief(f)
    r.up(r.edge(sym((16.5, 37.2), (17, 33.6), (3, 33.0), (0, 31.5))), 2.2, 2.5)  # the brow, one bar
    eye = r.edge(((4.2, 32.6), (16.4, 32.8), (16.8, 29.6), (5.0, 29.0)), True)
    r.up(eye, -4.6, 1.6)
    r.up(r.edge(((6.6, 31.6), (14.4, 31.5), (14.6, 30.4), (6.8, 30.2)), True), 2.0, 2.0)  # the lid, a long slit
    r.up(r.edge(sym((1.5, 33.5), (2.6, 29), (5.6, 16.4), (4.0, 14.6), (0, 14.2))), 8.4, 1.3)  # the nose, a wedge
    r.up(r.edge(((3.4, 14.5), (5.2, 16.6), (6.2, 15.6), (4.6, 13.6)), True), -1.6, 2.5)
    r.up(r.edge(sym((10.5, 12.6), (10.8, 10.3), (0, 10.3))), 1.8, 2.0)         # upper lip
    r.up(r.edge(sym((9.0, 9.7), (8.4, 7.9), (0, 7.6))), 1.6, 2.0)              # lower lip
    r.up(r.edge(sym((10.5, 10.45), (10.5, 9.55))), -1.6, 6.0)                  # the mouth, shut
    beard = r.edge(sym((10.5, 6.6), (11.5, -3), (0, -3)))
    r.up(beard, 3.6, 2.5)
    for x in (-7.5, -3.75, 0.0, 3.75, 7.5):
        r.up(r.edge(((x - 0.5, 6.6), (x + 0.5, 6.6), (x + 0.5, -3), (x - 0.5, -3))), -1.4, 2.5)  # its grooves
    d = r.on(d)
    for s in (-1, 1):
        d = add(d, f.box((s * 22, 5, 21), (2.2, 6, 10), 0.4))                  # slab ear
        d = cut(d, f.box((s * 23.7, 5, 21), (1.0, 3.6, 7), 0.3))
    parts = [(jaw.field(), jaw), (c, crown)]
    return d, parts, face_mask(f, 1, 37, 17, -18)


def elder_55(f):
    """Broad and heavy: a cap on a hard ledge, a flat nose, thick lips round a
    mouth bored right through, and out the back of the skull."""
    jaw = Mass(f, ((-2, 0, 2, 24, 23), (10, 0, 1, 26.5, 25), (24, 0, 1, 27, 26), (36, 0, 2, 26.5, 25.5), (46, 0, 3, 26, 25)), 2.0, 1.25)
    d = jaw.field()
    for s in (-1, 1):
        d = np.maximum(d, plane(f, (s * 0.5, -0.86, -0.04), (s * 19, -22, 20)))  # the broad plane of each cheek
    cap = np.maximum(f.ell((0, 3, 36), (27.5, 26.5, 21.5)), 41.0 - f.Z)              # a cap, its rim a ledge all round
    d = add(d, cap)
    band = np.maximum(f.ell((0, 3, 36), (28.4, 27.4, 22.4)), np.abs(f.Z - 42.2) - 1.3)
    d = add(d, band)
    r = Relief(f)
    r.up(r.edge(sym((24, 36.8), (23, 29.5), (2.8, 31.5), (0, 29))), 1.5, 3.0)  # the brow's shelf
    r.up(r.edge(((4.6, 32.0), (10, 34.2), (17, 33.6), (21.6, 30.0), (14, 27.8), (7, 28.4)), True), -4.4, 1.4)  # the socket, blind
    r.up(r.edge(((6.4, 30.2), (10.5, 32.2), (15.5, 32.2), (20, 30.2), (14, 28.9), (8, 29.2)), True), 3.0, 1.1)  # the eye
    r.up(r.edge(sym((3, 33), (3.6, 29), (10, 22.8), (8.4, 20.8), (0, 20.2))), 9.0, 1.2)  # a flat, broad nose
    r.up(r.edge(((3.3, 21.6), (6.0, 22.4), (6.4, 21.0), (3.6, 20.2)), True), -2.4, 2.0)  # nostril
    half, tall = BORE / 2, BORE_TALL / 2
    r.up(r.edge(((half + 5.0, BORE_Z + tall - 1.0), (half + 1.5, BORE_Z + tall + 3.2), (3, BORE_Z + tall + 4.2), (0, BORE_Z + tall + 3.6), (-3, BORE_Z + tall + 4.2),
                 (-half - 1.5, BORE_Z + tall + 3.2), (-half - 5.0, BORE_Z + tall - 1.0), (-half, BORE_Z + tall), (half, BORE_Z + tall))), 2.8, 1.0)  # upper lip
    r.up(r.edge(((half + 5.0, BORE_Z - tall + 1.0), (half + 1.5, BORE_Z - tall - 3.6), (-half - 1.5, BORE_Z - tall - 3.6), (-half - 5.0, BORE_Z - tall + 1.0),
                 (-half, BORE_Z - tall), (half, BORE_Z - tall))), 3.2, 1.0)    # lower lip
    d = r.on(d)
    for s in (-1, 1):
        d = add(d, f.box((s * 27.5, 6, 25), (2.5, 6, 12), 0.5))                # ear
        d = cut(d, f.box((s * 29.2, 6, 26), (1.2, 3.6, 8), 0.3))
        d = add(d, f.box((s * 27.5, 6, 11), (2.8, 4.6, 3.4), 1.0))             # lobe, a plug
    d = cut(d, f.box((0, 0, BORE_Z), (BORE / 2, 70, BORE_TALL / 2), 2.0))
    parts = [(jaw.field(), jaw), (cap, Dome((0, 3, 36.5), (0, 0, 1), 24, 1.25))]
    return d, parts, face_mask(f, 2, 40, 25, -20)


def mourner_55(f):
    """Round and hollowed by grief: a bare dome, brows fallen to the temples
    over great blind sockets, a long thin nose, a small shut ring of a mouth."""
    skull = f.ell((0, 3, 33), (24.5, 25, 24.5))
    jaw = Mass(f, ((-2, 0, 0, 13, 15), (8, 0, -2, 15.5, 17), (20, 0, 0, 20, 21), (32, 0, 2, 23.5, 24), (44, 0, 3, 22, 23)), 3.0, 1.25)
    d = add(skull, jaw.field())
    for s in (-1, 1):
        d = np.maximum(d, plane(f, (s * 0.8, -0.58, -0.16), (s * 15.5, -17, 13)))  # the fallen cheek
    r = Relief(f)
    r.up(r.edge(((2.4, 34.6), (13, 34.6), (20.6, 28), (19, 21.6), (11, 20.8), (3.8, 25)), True), -6.0, 0.9)  # the socket, great and blind
    r.up(r.edge(((3.4, 33.6), (13, 33.8), (20.4, 27.6), (18.6, 26.2), (11, 28.8), (4.2, 28.8)), True), 3.4, 1.3)  # the lid, fallen
    r.up(r.edge(((1.0, 37.6), (5, 39.6), (13, 37.4), (21.8, 27.6), (20.4, 26.8), (12.8, 34.2), (2.4, 34.4)), True), 2.8, 1.5)  # the brow, down to the temple
    r.up(r.edge(sym((1.4, 38), (2.2, 29), (4.4, 17.6), (3.2, 15.8), (0, 15.2))), 7.6, 1.4)  # a long thin nose
    r.up(r.ring((0, 9.6), 3.9, 1.7), 2.6, 1.3)                                 # lips, a ring
    r.up(r.edge(((-2.2, 11.6), (2.2, 11.6), (2.2, 7.6), (-2.2, 7.6))), -2.2, 1.0)  # a shut well
    r.up(r.edge(sym((6.2, 4.6), (5.2, 0.2), (0, -0.8))), 2.6, 1.0)             # chin
    d = r.on(d, 7.0)
    for s in (-1, 1):
        d = add(d, f.box((s * 23.4, 6, 31), (3.0, 5, 9), 0.6))                 # long ear
        d = add(d, f.box((s * 21.4, 6, 18), (3.2, 4, 7), 0.6))                 # its lobe, drawn down by a weight
    parts = [(skull, Dome((0, 3, 33), (0.0, 0.25, 1), 22, 1.25)), (jaw.field(), jaw)]
    return d, parts, face_mask(f, 2, 40, 22, -14)


# Lost stone, placed by hand off the faces, and the fractures: (centre, radius, depth), (centre, length).
WEAR = {
    "warden_55": (((13, 13, 47), 9, 2.5), ((-18, 18, 6), 9, 3)),
    "elder_55": (((-16, 14, 47), 9, 3), ((20, 20, 5), 9, 3)),
    "mourner_55": (((-16, 16, 44), 9, 2.5), ((18, 14, 8), 9, 3)),
}
BREAKS = {
    "warden_55": (((-5, 22, 26), 30.0),),
    "elder_55": (((12, 27, 28), 26.0),),
    "mourner_55": (((6, 27, 30), 30.0),),
}
PIECES = {"warden_55": warden_55, "elder_55": elder_55, "mourner_55": mourner_55}


def carved(name, voxel):
    """(field, full, soft) of a piece."""
    seed = {"warden_55": 13, "elder_55": 23, "mourner_55": 17}[name]
    f = ruin.Field(*BOUNDS, voxel, seed)
    d, parts, spare = PIECES[name](f)
    spare = np.maximum(spare, CALM)
    full, soft = ruin.weather(f, d, stone=STONE, losses=WEAR[name], breaks=0, fractures=BREAKS[name],
                              masonry=wrapped(f, d, parts, STONE), spare=spare, chips=0.06, joint=0.7)
    return f, ease_walls(full), soft


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--voxel", type=float, default=0.35)
    ap.add_argument("--only", default=",".join(PIECES))
    ap.add_argument("--out", default="scratch/small_heads")
    args = ap.parse_args(argv)
    out = ruin.ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = stage()
    stone = material("stone", (0.20, 0.155, 0.115))
    scene.cycles.samples = 16
    names = args.only.split(",")
    for i, name in enumerate(names):
        f, full, _ = carved(name, args.voxel)
        place(name, full, f, ((i - (len(names) - 1) / 2) * 75, 0, 0), stone)
    width = max(1, len(names))
    scene.render.resolution_y = 700
    shot(scene, out, "front", (0, -300, 26), (0, 0, 26), 52 if width > 1 else 120)
    shot(scene, out, "quarter", (130, -280, 34), (0, 0, 26), 52 if width > 1 else 120)
    shot(scene, out, "low_left", (-150, -250, 8), (0, 0, 28), 52 if width > 1 else 120)


if __name__ == "__main__":
    main()
