"""Build the relief face (oc_relief): a cliff carved as
one giant seated lord in profile, Olmec style (after La Venta Monument 19 and
the Chalcatzingo reliefs): he sits cross-legged and leans forward, facing
right, an incense bag in his forward hand, a jade pectoral and collar, an ear
spool, a lip plug, a serpent-mask helmet whose snout juts over his brow, and
behind him a feathered serpent rising from a rattle at his back to a head
over his shoulder. Glyphs (the crossed bands, the cleft, the U) run down the
field in front of him.

The wanderer's lane is the carving's deep bosses (HOLDS): knee, bag,
armlet, pectoral, collar knot, lip plug, ear spool, the helmet's snout, the
helmet's knot, every one a SET_OFF (1.6 m) over the last and beside it, so
he jump-catches each in turn up the nose side; the rest of the carving is
shallow (SHALLOW m at most), so it never blocks his body. The Olmec climbs
the plain stone (the cliff's own collision), and at the top his hands come
over the helmet's crown, which is the cliff's lip (TOP).

Sculpt high, bake low: the sculpt is a height field (protrusion out of the
wall) on a RES m grid (about 550k triangles), made from soft-shouldered
shapes, deep bosses, incised lines and a chisel grain. It is decimated to a
low mesh of about LOW_TRIS triangles; the high is baked (in numpy, from the
height field) into
  - the low mesh's vertex colours: R occlusion (horizon AO), G convexity
    (the worn high points), B polish (the holds' lips, worn by hands);
  - two maps the game projects with one Decal over the carving: a normal
    map (the high's normals, in the wall's frame) and a cavity map (dark
    in the incisions, alpha its strength).

Conventions: 1 unit = 1 m, written in the game's frame (x right, y up, z
out of the wall toward the viewer) and turned into Blender's by `G`. The
wall plane is z = 0; the carving spans x in [-HALF_W, HALF_W], y in [0, TOP].
The origin is the bottom middle of the wall plane.

Objects (the game finds them by name):
  Relief      the low mesh (stone)
  Hold_NN     empties, one per hold: location its box's middle, scale its
              size (m); the game makes a clean walker-only box of each

    /opt/homebrew/bin/blender -b --python art/blender/city_relief/relief_build.py -- [--render=PNG] [--res=0.03] [--low=12000]

Writes assets/models/city_relief.glb and assets/textures/city_relief_{normal,cavity}.png,
printing RELIEF_TRIS; --render writes a workbench still of the low mesh.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = ""
RES = 0.03
LOW_TRIS = 12000
for a in _args:
    if a.startswith("--render="): RENDER = a.split("=", 1)[1]
    elif a.startswith("--res="): RES = float(a.split("=", 1)[1])
    elif a.startswith("--low="): LOW_TRIS = int(a.split("=", 1)[1])
GLB = ROOT / "assets/models/city_relief.glb"
TEX = ROOT / "assets/textures"

SET_OFF = 1.6
TOP = SET_OFF * 11          # 17.6 m: the cliff's lip, the helmet's crown
HALF_W = 7.0                # the carved panel is 14 m wide
SHALLOW = 0.58              # the deepest of the body's carving (m)
## The wall the bodies collide with stands this far out (m): the field
## behind it is carved deeper, so the figure's masses are inside it and
## only the holds stand out of it.
COLLIDE_Z = 0.5
MAP_W = 1024                # the baked maps' width (px); height by aspect

## The holds: [name, kind, x0, x1, top, depth (its front, m out of the
## wall), thick (down from the top)]. Each is beside the last and a SET_OFF
## over it, so one jump catches the next; two apart they stack with at
## least 1.9 m of room between (his head is 1.12 m). `kind` is its outline:
## "band" a rounded bar, "d" an oval cut flat on top, "disc" a round boss
## cut flat on top, "plaque" a trapezoid, "snout" a wedge forward.
HOLDS = [
    ["base", "band", -HALF_W, HALF_W, SET_OFF * 1, 1.4, SET_OFF],
    ["knee", "d", 0.8, 2.6, SET_OFF * 2, 1.4, 1.25],
    ["bag", "d", 2.75, 4.35, SET_OFF * 3, 1.42, 1.4],
    ["armlet", "band", 0.9, 2.4, SET_OFF * 4, 1.36, 0.85],
    ["pectoral", "plaque", 2.65, 4.0, SET_OFF * 5, 1.4, 1.25],
    ["collar", "d", 0.85, 2.35, SET_OFF * 6, 1.36, 0.95],
    ["lip_plug", "disc", 2.8, 4.1, SET_OFF * 7, 1.4, 1.05],
    ["ear_spool", "disc", 0.8, 2.3, SET_OFF * 8, 1.42, 1.35],
    ["snout", "snout", 2.6, 4.4, SET_OFF * 9, 1.4, 1.1],
    ["helmet_knot", "band", 0.75, 2.4, SET_OFF * 10, 1.38, 1.0],
]



def G(p):
    """The game's frame (y up, z out of the wall) to Blender's (z up, -y out)."""
    return Vector((p[0], -p[2], p[1]))


# ------------------------------------------------------------------ the grid
NX = int(round(HALF_W * 2 / RES)) + 1
NY = int(round(TOP / RES)) + 1
xs = np.linspace(-HALF_W, HALF_W, NX)
ys = np.linspace(0.0, TOP, NY)
X, Y = np.meshgrid(xs, ys)          # [NY, NX]


# ------------------------------------------------------------------ shapes (signed distance, < 0 inside)
def sd_box(cx, cy, hx, hy, r=0.0):
    qx = np.abs(X - cx) - (hx - r)
    qy = np.abs(Y - cy) - (hy - r)
    out = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0))
    return out + np.minimum(np.maximum(qx, qy), 0.0) - r


def sd_ellipse(cx, cy, a, b, turn=0.0):
    c, s = math.cos(turn), math.sin(turn)
    dx, dy = X - cx, Y - cy
    u = (dx * c + dy * s) / a
    v = (-dx * s + dy * c) / b
    return (np.sqrt(u * u + v * v) - 1.0) * min(a, b)


def _seg(ax, ay, bx, by):
    px, py = X - ax, Y - ay
    ex, ey = bx - ax, by - ay
    t = np.clip((px * ex + py * ey) / max(ex * ex + ey * ey, 1e-9), 0.0, 1.0)
    return np.hypot(px - ex * t, py - ey * t)


def sd_path(pts, r):
    """A stroke of radius `r` (or a list of radii, one per point) along `pts`."""
    d = np.full(X.shape, 1e9)
    for i in range(len(pts) - 1):
        ax, ay = pts[i]
        bx, by = pts[i + 1]
        ra = r[i] if isinstance(r, (list, tuple)) else r
        rb = r[i + 1] if isinstance(r, (list, tuple)) else r
        px, py = X - ax, Y - ay
        ex, ey = bx - ax, by - ay
        t = np.clip((px * ex + py * ey) / max(ex * ex + ey * ey, 1e-9), 0.0, 1.0)
        dd = np.hypot(px - ex * t, py - ey * t) - (ra + (rb - ra) * t)
        d = np.minimum(d, dd)
    return d


def taper(pts, r0, r1):
    """Radii from `r0` at the first point to `r1` at the last."""
    n = max(len(pts) - 1, 1)
    return [r0 + (r1 - r0) * i / n for i in range(len(pts))]


def sd_poly(pts):
    d = np.full(X.shape, 1e9)
    inside = np.zeros(X.shape, dtype=bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        d = np.minimum(d, _seg(ax, ay, bx, by))
        cond = ((ay > Y) != (by > Y)) & (X < (bx - ax) * (Y - ay) / ((by - ay) if by != ay else 1e-9) + ax)
        inside ^= cond
    return np.where(inside, -d, d)


def smooth_spline(pts, steps=6):
    """Catmull-Rom through `pts` (open), for flowing outlines."""
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = (np.array(p[i - 1]), np.array(p[i]), np.array(p[i + 1]), np.array(p[i + 2]))
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append((float(q[0]), float(q[1])))
    out.append(tuple(pts[-1]))
    return out


# ------------------------------------------------------------------ heights
def pillow(d, h, shoulder):
    """A soft-shouldered mass: `h` m out inside, its edge rounded over `shoulder` m."""
    t = np.clip(-d / shoulder, 0.0, 1.0)
    return h * (1.0 - (1.0 - t) ** 2)


def dome(d, h, width):
    """A rounded swell rising `h` m over `width` m in from its edge."""
    t = np.clip(-d / width, 0.0, 1.0)
    return h * np.sqrt(1.0 - (1.0 - t) ** 2)


def smax(a, b, k=0.08):
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
    return b + (a - b) * h + k * h * (1.0 - h)


Z = np.zeros(X.shape)
FIG = np.full(X.shape, 1e9)      # the figure's union (for the outline cut)


def add(d, h, shoulder=0.18, k=0.06, figure=True, shape="pillow"):
    global Z, FIG
    z = pillow(d, h, shoulder) if shape == "pillow" else dome(d, h, shoulder)
    Z = smax(Z, z, k)
    if figure:
        FIG = np.minimum(FIG, d)


GROOVES = []


def groove(pts, depth=0.07, width=0.06, spline=True):
    GROOVES.append((smooth_spline(pts) if spline and len(pts) > 2 else pts, depth, width))


# --- the frame: a raised border round the panel (the base is a hold)
frame_out = sd_box(0.0, (SET_OFF + TOP) * 0.5, HALF_W, (TOP - SET_OFF) * 0.5)
frame_in = sd_box(0.0, (SET_OFF + TOP) * 0.5 - 0.15, HALF_W - 0.5, (TOP - SET_OFF) * 0.5 - 0.5, 0.2)
frame = np.maximum(frame_out, -frame_in)
Z = np.maximum(Z, pillow(frame, 0.34, 0.12))

# --- the throne behind him: a block with a jaguar-paw cartouche
add(sd_box(-3.3, 2.75, 1.35, 1.15, 0.12), 0.34, 0.1)
groove([(-4.3, 2.0), (-4.3, 3.55), (-2.3, 3.55), (-2.3, 2.0)], 0.06, 0.05, spline=False)
for i in range(3):
    groove([(-3.95 + i * 0.5, 2.3), (-3.75 + i * 0.5, 2.8), (-3.95 + i * 0.5, 3.25)], 0.05, 0.05)

# --- the legs, crossed (a long oval), the far foot's sole at the front
add(sd_ellipse(0.35, 2.45, 2.75, 0.85, 0.02), 0.52, 0.45, shape="dome")
add(sd_ellipse(3.2, 1.95, 0.55, 0.33, -0.15), 0.46, 0.22, shape="dome")
groove([(-2.2, 1.95), (-0.4, 1.8), (1.0, 2.0)], 0.06, 0.05)
for i in range(4):
    groove([(3.35 + 0.1 * i, 1.72 + 0.1 * i), (3.55 + 0.1 * i, 1.78 + 0.1 * i)], 0.04, 0.035, spline=False)

# --- the torso, hunched forward over the legs
torso = smooth_spline([(-2.1, 2.6), (-2.35, 4.4), (-2.15, 6.4), (-1.5, 8.1), (-0.5, 9.2), (0.6, 9.85),
                       (2.6, 9.65), (3.25, 8.7), (3.4, 7.2), (3.25, 5.8), (2.9, 4.6), (2.2, 3.5), (0.4, 3.1)], 4)
add(sd_poly(torso), 0.5, 0.75, shape="dome")
groove([(-1.95, 5.2), (-1.4, 7.4), (-0.3, 8.9)], 0.045, 0.06)            # the spine's line
groove([(2.95, 5.4), (2.3, 4.3), (1.2, 3.7)], 0.055, 0.06)               # the belly's fold over the legs
groove([(2.9, 7.9), (2.3, 8.8), (1.9, 9.25)], 0.04, 0.05)                # the pectoral's cord

# --- the arm: the shoulder's swell, the upper arm down to the elbow (the
# armlet), the forearm forward to the fist on the bag's neck
add(sd_ellipse(0.55, 8.2, 1.05, 0.95), SHALLOW, 0.5, shape="dome")
add(sd_path([(0.6, 8.2), (1.15, 7.0), (1.65, 5.95)], [0.78, 0.68, 0.6]), SHALLOW, 0.4, shape="dome")
add(sd_path([(1.65, 5.95), (2.45, 5.5), (3.1, 5.3)], [0.55, 0.47, 0.42]), SHALLOW, 0.3, shape="dome")
add(sd_ellipse(3.45, 5.18, 0.52, 0.4, -0.08), SHALLOW, 0.2, shape="dome")
for i in range(3):
    groove([(3.15 + 0.2 * i, 5.42), (3.24 + 0.2 * i, 4.98)], 0.05, 0.04, spline=False)
groove([(3.0, 5.62), (3.35, 5.58), (3.7, 5.5)], 0.04, 0.04)              # the thumb

# --- the head, big and leaning forward: skull, the face in profile
head = smooth_spline([(0.55, 9.9), (0.15, 11.0), (0.1, 12.4), (0.55, 13.45), (3.6, 13.55), (3.98, 12.95),
                      (3.78, 12.55), (3.88, 12.38), (4.32, 11.95), (4.12, 11.62), (4.22, 11.4), (3.92, 11.22),
                      (4.06, 11.0), (3.85, 10.7), (3.75, 10.22), (3.2, 9.86), (2.6, 9.62), (1.6, 9.5)], 3)
add(sd_poly(head), SHALLOW, 0.65, shape="dome")
add(sd_ellipse(3.3, 12.95, 0.72, 0.2, -0.12), SHALLOW + 0.05, 0.12)       # the brow ridge
groove([(2.65, 13.15), (3.0, 13.32), (3.3, 13.12), (3.55, 13.3), (3.9, 13.05)], 0.05, 0.04)   # flame brow
add(sd_ellipse(3.3, 12.55, 0.46, 0.15, 0.06), SHALLOW - 0.06, 0.1)        # the puffy lid
groove([(2.88, 12.53), (3.28, 12.7), (3.74, 12.56), (3.3, 12.43), (2.88, 12.53)], 0.08, 0.045)  # the almond eye
add(sd_ellipse(3.95, 11.98, 0.45, 0.42), SHALLOW + 0.04, 0.25, shape="dome")   # the broad nose
groove([(3.72, 11.82), (3.98, 11.7), (4.18, 11.82)], 0.07, 0.05)          # the nostril
groove([(3.55, 12.35), (3.5, 11.85), (3.65, 11.65)], 0.04, 0.05)          # the nose's wing
add(sd_ellipse(3.85, 11.42, 0.42, 0.16, -0.05), SHALLOW + 0.03, 0.1)      # the everted upper lip
groove([(3.25, 11.18), (3.65, 11.24), (4.0, 11.24)], 0.08, 0.04)          # the mouth's line, downturned
groove([(3.15, 10.98), (3.27, 11.2)], 0.06, 0.04, spline=False)
groove([(1.2, 10.25), (2.2, 9.98), (3.1, 10.08)], 0.045, 0.06)            # the jaw
groove([(2.55, 12.15), (2.85, 11.5), (3.25, 11.58)], 0.04, 0.06)          # the cheek

# --- the helmet: a serpent mask, its eye over his brow, its snout jutting
# (the snout is a hold), cleft feathers up its band, crest swept back; its
# flat top is the cliff's lip
helmet = smooth_spline([(0.2, 12.9), (-0.45, 13.7), (-0.7, 15.2), (-0.55, 16.7), (-0.1, TOP + 0.05),
                        (3.7, TOP + 0.05), (4.3, 16.9), (4.5, 15.6), (4.4, 14.6), (3.7, 13.55), (2.0, 13.45),
                        (0.8, 13.2)], 4)
add(sd_poly(helmet), SHALLOW, 0.4, shape="dome")
groove([(-0.4, 13.75), (1.2, 14.0), (2.6, 14.4), (4.3, 14.45)], 0.07, 0.07)   # the band's lower edge
groove([(-0.6, 14.85), (0.8, 15.15), (2.6, 15.3), (4.45, 15.3)], 0.07, 0.07)  # the band's upper edge
add(sd_ellipse(3.35, 16.35, 0.55, 0.38), SHALLOW + 0.04, 0.14)                 # the mask's eye
groove([(2.85, 16.35), (3.35, 16.62), (3.85, 16.35), (3.35, 16.08), (2.85, 16.35)], 0.07, 0.05)
groove([(2.75, 16.85), (3.3, 17.05), (3.95, 16.85)], 0.05, 0.05)              # its flame brow
for i in range(4):
    x = -0.2 + i * 0.75
    groove([(x, 15.45), (x + 0.22, 15.95), (x + 0.12, 16.5)], 0.05, 0.05)       # the cleft feathers
for i, (lx, ly) in enumerate([(-2.6, 17.05), (-2.9, 16.1)]):                     # the crest, swept back
    feather = smooth_spline([(-0.3, 17.0 - i * 0.85), (-1.4, ly + 0.15), (lx, ly)], 4)
    add(sd_path(feather, taper(feather, 0.34, 0.2)), 0.4, 0.16)
    groove(feather, 0.045, 0.04)

# --- the feathered serpent behind him: the rattle low at his back, the body
# up the field, its head over his shoulder, jaws open toward his crest
spine = smooth_spline([(-5.7, 2.5), (-5.0, 3.5), (-5.4, 5.3), (-5.85, 7.5), (-5.65, 9.7), (-5.05, 11.7),
                       (-4.1, 13.1), (-3.2, 13.85)], 6)
add(sd_path(spine, 0.58), 0.46, 0.35, shape="dome")
for i in range(0, len(spine) - 2, 3):          # the belly scutes
    (ax, ay), (bx, by) = spine[i], spine[i + 1]
    nx, ny = -(by - ay), bx - ax
    ln = math.hypot(nx, ny) or 1.0
    nx, ny = nx / ln * 0.5, ny / ln * 0.5
    groove([(ax - nx * 0.2, ay - ny * 0.2), (ax + nx, ay + ny)], 0.045, 0.04, spline=False)
for i in range(3, len(spine) - 3, 3):          # the feathers off its outer flank
    (ax, ay), (bx, by) = spine[i], spine[i + 1]
    nx, ny = (by - ay), -(bx - ax)
    ln = math.hypot(nx, ny) or 1.0
    nx, ny = nx / ln, ny / ln
    # a rounded feather lobe lying back along the body (no points)
    tip = (ax + nx * 0.85 + (bx - ax) * 1.2, ay + ny * 0.85 + (by - ay) * 1.2)
    f = [(ax + nx * 0.45, ay + ny * 0.45), tip]
    add(sd_path(f, [0.26, 0.2]), 0.3, 0.14, shape="dome")
    groove(f, 0.03, 0.03, spline=False)
add(sd_ellipse(-5.95, 2.05, 0.38, 0.3, 0.4), 0.42, 0.12, shape="dome")       # the rattle
for k in range(3):
    groove([(-6.2 + 0.18 * k, 1.85 + 0.05 * k), (-6.0 + 0.18 * k, 2.25 + 0.05 * k)], 0.05, 0.035, spline=False)
upper = smooth_spline([(-3.6, 13.75), (-3.9, 14.6), (-3.2, 15.15), (-2.1, 15.05), (-1.35, 14.75), (-1.6, 14.45),
                       (-2.6, 14.35)], 4)
add(sd_poly(upper), 0.5, 0.25, shape="dome")
lower = smooth_spline([(-3.4, 13.5), (-2.3, 13.75), (-1.6, 13.9), (-1.75, 13.6), (-2.6, 13.25), (-3.5, 13.15)], 4)
add(sd_poly(lower), 0.46, 0.2, shape="dome")
add(sd_ellipse(-2.95, 14.7, 0.24, 0.17), 0.52, 0.06)                          # its eye
groove([(-3.25, 14.7), (-2.95, 14.86), (-2.65, 14.7)], 0.06, 0.04)
groove([(-1.6, 14.45), (-1.45, 14.15)], 0.06, 0.04, spline=False)            # its fang
groove([(-1.85, 13.9), (-1.95, 14.2)], 0.06, 0.04, spline=False)
for i in range(4):                                                            # its plume
    f = [(-3.7 + 0.28 * i, 15.0), (-4.3 + 0.38 * i, 15.9 + 0.12 * i)]
    add(sd_path(f, [0.17, 0.14]), 0.34, 0.1, shape="dome")

# --- glyphs down the field before him: cartouches with the crossed bands,
# the cleft, the U, the paw-wing
glyph_x = 5.75
for gi, gy in enumerate([3.3, 6.1, 8.9, 11.7, 14.5]):
    add(sd_box(glyph_x, gy, 0.62, 1.1, 0.16), 0.26, 0.08)
    groove([(glyph_x - 0.5, gy - 0.98), (glyph_x + 0.5, gy - 0.98), (glyph_x + 0.5, gy + 0.98),
            (glyph_x - 0.5, gy + 0.98), (glyph_x - 0.5, gy - 0.98)], 0.05, 0.05, spline=False)
    kind = gi % 4
    if kind == 0:     # the crossed bands
        groove([(glyph_x - 0.35, gy - 0.5), (glyph_x + 0.35, gy + 0.5)], 0.08, 0.07, spline=False)
        groove([(glyph_x + 0.35, gy - 0.5), (glyph_x - 0.35, gy + 0.5)], 0.08, 0.07, spline=False)
    elif kind == 1:   # the cleft
        groove([(glyph_x - 0.35, gy + 0.55), (glyph_x - 0.1, gy + 0.2), (glyph_x, gy + 0.45),
                (glyph_x + 0.1, gy + 0.2), (glyph_x + 0.35, gy + 0.55)], 0.08, 0.06, spline=False)
        groove([(glyph_x - 0.3, gy - 0.5), (glyph_x - 0.3, gy - 0.1), (glyph_x + 0.3, gy - 0.1), (glyph_x + 0.3, gy - 0.5)],
               0.07, 0.06, spline=False)
    elif kind == 2:   # the U
        groove([(glyph_x - 0.3, gy + 0.55), (glyph_x - 0.3, gy - 0.3), (glyph_x, gy - 0.55), (glyph_x + 0.3, gy - 0.3),
                (glyph_x + 0.3, gy + 0.55)], 0.08, 0.07)
    else:             # the paw-wing
        for k in range(3):
            groove([(glyph_x - 0.35, gy - 0.4 + k * 0.35), (glyph_x + 0.1, gy - 0.25 + k * 0.35), (glyph_x + 0.35, gy - 0.4 + k * 0.35)],
                   0.07, 0.05)

# --- the base register: the earth's band of clefts under his seat
groove([(-HALF_W + 0.3, 1.3), (HALF_W - 0.3, 1.3)], 0.06, 0.06, spline=False)
for i in range(-6, 7):
    groove([(i * 1.0 - 0.28, 0.3), (i * 1.0, 0.95), (i * 1.0 + 0.28, 0.3)], 0.06, 0.05, spline=False)

# --- the outline cut: a shadow line in the field round the figure
Z = Z - 0.12 * np.clip(1.0 - FIG / 0.2, 0.0, 1.0) * (FIG > 0.0) * (frame > 0.02) * (Y > SET_OFF + 0.05)


# --- the holds: the deep bosses (flat tops, swelling fronts), each in the
# carving's language
def _oval(kind, x0, x1, thick):
    b = thick * 0.72
    hx = (x1 - x0) * 0.5
    return (hx if kind == "d" else max(hx, b)), b


def hold_outline(kind, x0, x1, top, thick):
    cx, cy = (x0 + x1) * 0.5, top - thick * 0.5
    hx = (x1 - x0) * 0.5
    if kind == "band":
        return sd_box(cx, cy, hx, thick * 0.5, 0.1 if hx < HALF_W else 0.03)
    if kind in ("d", "disc"):
        # an oval (a circle for a disc) whose top is cut flat at `top`
        a, b = _oval(kind, x0, x1, thick)
        return np.maximum(sd_ellipse(cx, top - thick + b, a, b), Y - top)
    if kind == "plaque":
        return sd_poly([(x0 + 0.12, top), (x1 - 0.12, top), (x1, top - thick), (x0, top - thick)])
    if kind == "snout":
        return sd_poly([(x0, top), (x1 - 0.15, top), (x1, top - 0.35), (x1 - 0.45, top - thick), (x0, top - thick * 0.8)])
    raise ValueError(kind)


def hold_chord(kind, x0, x1, top, thick):
    """The flat top's span (m): where he can stand."""
    if kind in ("d", "disc"):
        a, b = _oval(kind, x0, x1, thick)
        k = math.sqrt(max(0.0, 1.0 - ((thick - b) / b) ** 2))
        return ((x0 + x1) * 0.5 - a * k, (x0 + x1) * 0.5 + a * k)
    if kind == "plaque":
        return (x0 + 0.12, x1 - 0.12)
    if kind == "snout":
        return (x0, x1 - 0.15)
    return (x0, x1)


HOLD_MASK = np.zeros(X.shape)
POLISH = np.zeros(X.shape)
for name, kind, x0, x1, top, depth, thick in HOLDS:
    cx, cy = (x0 + x1) * 0.5, top - thick * 0.5
    d = hold_outline(kind, x0, x1, top, thick)
    if name == "base":
        z = pillow(d, depth, 0.08)
    else:
        z = pillow(d, depth, 0.24)
        bump = np.clip(1.0 - np.hypot((X - cx) / ((x1 - x0) * 0.55), (Y - cy) / (thick * 0.6)), 0.0, 1.0)
        z = z + 0.06 * bump * (d < 0)
    Z = np.maximum(Z, z)
    HOLD_MASK = np.maximum(HOLD_MASK, (d < 0) * 1.0)
    POLISH = np.maximum(POLISH, (d < 0.02) * np.clip(1.0 - (top - Y) / 0.4, 0.0, 1.0))
    if name == "bag":
        groove([(x0 + 0.3, top - 0.28), (x1 - 0.3, top - 0.28)], 0.07, 0.06, spline=False)   # the tie
        groove([(cx - 0.32, top - 0.75), (cx, top - 1.05), (cx + 0.32, top - 0.75)], 0.06, 0.05)  # the paw mark
    elif name == "pectoral":
        groove([(x0 + 0.3, top - 0.2), (x1 - 0.3, top - 0.2), (x1 - 0.22, top - 1.05), (x0 + 0.22, top - 1.05),
                (x0 + 0.3, top - 0.2)], 0.05, 0.05, spline=False)
        groove([(cx - 0.25, top - 0.4), (cx + 0.25, top - 0.85)], 0.06, 0.05, spline=False)
        groove([(cx + 0.25, top - 0.4), (cx - 0.25, top - 0.85)], 0.06, 0.05, spline=False)
    elif name in ("armlet", "helmet_knot"):
        for k in range(1, 4):
            xx = x0 + (x1 - x0) * k / 4
            groove([(xx, top - 0.1), (xx, top - thick + 0.1)], 0.06, 0.05, spline=False)
    elif name == "collar":
        for k in range(-1, 2):
            groove([(cx + k * 0.42 - 0.18, top - 0.15), (cx + k * 0.42, top - thick * 0.75), (cx + k * 0.42 + 0.18, top - 0.15)],
                   0.05, 0.05)
    elif name == "ear_spool":
        sy = top - thick * 0.55
        Z = Z - 0.3 * np.clip(1.0 - np.hypot(X - cx, Y - sy) / 0.36, 0.0, 1.0) ** 0.5 * (d < 0)
        groove([(cx - 0.55, sy), (cx, sy + 0.55), (cx + 0.55, sy), (cx, sy - 0.55), (cx - 0.55, sy)], 0.05, 0.05)
    elif name == "lip_plug":
        groove([(cx - 0.4, top - thick * 0.5), (cx + 0.4, top - thick * 0.5)], 0.05, 0.05, spline=False)
    elif name == "snout":
        groove([(x1 - 0.35, top - 0.22), (x1 - 0.2, top - 0.5)], 0.07, 0.05, spline=False)       # its nostril
        for k in range(3):
            groove([(x0 + 0.35 + 0.38 * k, top - thick * 0.82), (x0 + 0.47 + 0.38 * k, top - thick * 0.55)], 0.06, 0.05,
                   spline=False)                                                                  # its fangs


# --- the incisions, cut into whatever they cross (V-section)
for pts, depth, width in GROOVES:
    d = sd_path(pts, 0.0)
    Z = Z - depth * np.clip(1.0 - d / width, 0.0, 1.0) ** 1.5

# --- the chisel grain: two octaves of value noise, and the worn high points
rng = np.random.default_rng(29)


def value_noise(scale):
    gx = int(HALF_W * 2 / scale) + 3
    gy = int(TOP / scale) + 3
    g = rng.random((gy, gx))
    fx = (X + HALF_W) / scale
    fy = Y / scale
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[iy, ix] * (1 - tx) + g[iy, ix + 1] * tx
    b = g[iy + 1, ix] * (1 - tx) + g[iy + 1, ix + 1] * tx
    return a * (1 - ty) + b * ty


Z = Z + (value_noise(0.35) - 0.5) * 0.03 + (value_noise(0.11) - 0.5) * 0.012
Z = np.maximum(Z, -0.18)
print("RELIEF_HIGH grid", NX, NY, "tris", (NX - 1) * (NY - 1) * 2, "z", round(float(Z.min()), 3), round(float(Z.max()), 3))

# ------------------------------------------------------------------ bake (numpy, from the high)
# Normals of the high in the wall's frame.
dzdx = np.gradient(Z, RES, axis=1)
dzdy = np.gradient(Z, RES, axis=0)
NRM = np.dstack([-dzdx, -dzdy, np.ones_like(Z)])
NRM /= np.linalg.norm(NRM, axis=2, keepdims=True)

# Horizon occlusion: in 12 ways, the steepest rise within REACH m.
REACH = 1.2
ao = np.zeros(Z.shape)
dirs = 12
for k in range(dirs):
    a = 2 * math.pi * k / dirs
    dx, dy = math.cos(a), math.sin(a)
    best = np.zeros(Z.shape)
    steps = 10
    for s in range(1, steps + 1):
        dist = REACH * (s / steps) ** 1.5
        ox, oy = int(round(dx * dist / RES)), int(round(dy * dist / RES))
        sh = np.roll(np.roll(Z, -oy, axis=0), -ox, axis=1)
        rise = (sh - Z) / max(dist, 1e-3)
        best = np.maximum(best, rise)
    ao += 1.0 - np.sin(np.arctan(best))
ao /= dirs
# Cavity: the height's Laplacian over a small and a wider reach.
def blur(a, r):
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


cav_fine = Z - blur(Z, 3)
cav_wide = Z - blur(Z, 12)
convex = np.clip(cav_fine * 9.0 + cav_wide * 2.0, -1.0, 1.0)


def sample(arr, px, py):
    fx = (np.asarray(px) + HALF_W) / RES
    fy = np.asarray(py) / RES
    ix = np.clip(np.floor(fx).astype(int), 0, NX - 2)
    iy = np.clip(np.floor(fy).astype(int), 0, NY - 2)
    tx = np.clip(fx - ix, 0.0, 1.0)
    ty = np.clip(fy - iy, 0.0, 1.0)
    a = arr[iy, ix] * (1 - tx) + arr[iy, ix + 1] * tx
    b = arr[iy + 1, ix] * (1 - tx) + arr[iy + 1, ix + 1] * tx
    return a * (1 - ty) + b * ty


# The maps (rows top-down in the image: y from TOP down).
MAP_H = int(round(MAP_W * TOP / (HALF_W * 2)))
mx = np.linspace(-HALF_W, HALF_W, MAP_W)
my = np.linspace(TOP, 0.0, MAP_H)
MX, MY = np.meshgrid(mx, my)
n_map = np.dstack([sample(NRM[:, :, i], MX, MY) for i in range(3)])
n_map /= np.linalg.norm(n_map, axis=2, keepdims=True)
cav_map = np.clip(-sample(cav_fine, MX, MY) * 14.0, 0.0, 1.0) ** 0.8
ao_map = sample(ao, MX, MY)


def save_png(path, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(path.stem, width=w, height=h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    # Blender's pixels run bottom-up.
    img.pixels.foreach_set(np.ascontiguousarray(rgba[::-1].astype(np.float32)).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save()
    print("RELIEF_MAP", path, w, h)


# The normal map in the decal's way (OpenGL: +x right, +y up, +z out).
save_png(TEX / "city_relief_normal.png", np.dstack([n_map[:, :, 0] * 0.5 + 0.5, n_map[:, :, 1] * 0.5 + 0.5,
                                                   n_map[:, :, 2] * 0.5 + 0.5, np.ones(MX.shape)]))
# The cavity: dark stone, alpha its share (the incisions and the crevices).
dark = np.clip(cav_map * 0.85 + (1.0 - ao_map) * 0.6, 0.0, 1.0)
save_png(TEX / "city_relief_cavity.png", np.dstack([np.full(MX.shape, 0.08), np.full(MX.shape, 0.075),
                                                   np.full(MX.shape, 0.07), dark]))

# ------------------------------------------------------------------ the high and the low
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
scene = bpy.context.scene

verts = np.zeros((NY * NX, 3), dtype=np.float32)
verts[:, 0] = X.ravel()
verts[:, 1] = -Z.ravel()        # Blender's -y is out of the wall
verts[:, 2] = Y.ravel()
ii, jj = np.meshgrid(np.arange(NX - 1), np.arange(NY - 1))
i0 = (jj * NX + ii).ravel()
quads = np.stack([i0, i0 + 1, i0 + 1 + NX, i0 + NX], axis=1)
me = bpy.data.meshes.new("Relief")
me.vertices.add(len(verts))
me.vertices.foreach_set("co", verts.ravel())
me.loops.add(quads.size)
me.loops.foreach_set("vertex_index", quads.ravel().astype(np.int32))
me.polygons.add(len(quads))
me.polygons.foreach_set("loop_start", (np.arange(len(quads)) * 4).astype(np.int32))
me.update(calc_edges=True)
me.validate()
ob = bpy.data.objects.new("Relief", me)
scene.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
high_tris = len(quads) * 2
# Flat stretches first (the field, the hold tops), then collapse to the budget.
mod = ob.modifiers.new("planar", "DECIMATE")
mod.decimate_type = "DISSOLVE"
mod.angle_limit = math.radians(1.5)
bpy.ops.object.modifier_apply(modifier="planar")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
tris_now = len(ob.data.polygons)
mod = ob.modifiers.new("collapse", "DECIMATE")
mod.decimate_type = "COLLAPSE"
mod.ratio = min(1.0, LOW_TRIS / max(tris_now, 1))
bpy.ops.object.modifier_apply(modifier="collapse")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
low = ob.data
low_tris = len(low.polygons)
for p in low.polygons: p.use_smooth = True
print("RELIEF_TRIS high", high_tris, "planar", tris_now, "low", low_tris)

# The bake onto the low's vertices: R occlusion, G convexity, B polish.
co = np.zeros(len(low.vertices) * 3, dtype=np.float32)
low.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
gx, gy = co[:, 0], co[:, 2]
r = sample(ao, gx, gy)
g = np.clip(sample(convex, gx, gy) * 0.5 + 0.5, 0.0, 1.0)
b = sample(POLISH, gx, gy)
attr = low.color_attributes.new("AO", "BYTE_COLOR", "POINT")
cols = np.stack([r, g, b, np.ones_like(r)], axis=1).astype(np.float32)
attr.data.foreach_set("color", cols.ravel())
low.color_attributes.active_color = attr
try:
    low.color_attributes.render_color_index = low.color_attributes.active_color_index
except Exception:
    pass
print("RELIEF_AO", round(float(r.min()), 3), round(float(r.mean()), 3), round(float(r.max()), 3))

# The holds as empties: location the box's middle, scale its size.
holds = []
for i, (name, kind, x0, x1, top, depth, thick) in enumerate(HOLDS):
    e = bpy.data.objects.new("Hold_%02d_%s" % (i, name), None)
    a, b = hold_chord(kind, x0, x1, top, thick)
    mid = ((a + b) * 0.5, top - thick * 0.5, (COLLIDE_Z + depth) * 0.5)
    e.location = G(mid)
    e.scale = (b - a, depth - COLLIDE_Z, thick)   # Blender's (x, y, z) = the game's (x, z, y)
    scene.collection.objects.link(e)
    holds.append(e)
    print("RELIEF_HOLD", name, "x %.2f..%.2f top %.2f out %.2f..%.2f" % (a, b, top, COLLIDE_Z, depth))
# The wall: its top middle, on the plane the bodies collide with; scale the
# carved panel's size.
wall = bpy.data.objects.new("Wall", None)
wall.location = G((0.0, TOP, COLLIDE_Z))
wall.scale = (HALF_W * 2, 1.0, TOP)
scene.collection.objects.link(wall)
holds.append(wall)

bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
for e in holds: e.select_set(True)
bpy.context.view_layer.objects.active = ob
GLB.parent.mkdir(parents=True, exist_ok=True)
kw = dict(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
          export_apply=False, export_animations=False, export_materials="NONE",
          export_normals=True, export_extras=False)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("RELIEF_EXPORTED", GLB)

# ------------------------------------------------------------------ a still
if RENDER:
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 1000
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 40
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = G((0.0, TOP * 0.5, 0.0))
    cam.location = G((6.0, TOP * 0.45, 26.0))
    d = target - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = RENDER
    bpy.ops.render.render(write_still=True)
    print("RELIEF_RENDERED", RENDER)
