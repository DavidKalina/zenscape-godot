"""Build the log cabin: zenscape's placeable cabin (docs/scenic/cabin.md).

Brought over from the sky-island branch (sky/chimney-smoke), where it was the
settler's cabin; here only the cabin itself is built (no carried log, no
stump: this game has no people). The game draws it at Cabin.UNIT (0.8) of
this real size, baked into one vertex-coloured mesh (scripts/cabin.gd).

Faceted, flat-shaded low poly: solid per-material colours, warm muted woods,
no textures.

Regenerates art/blender/cabin.blend and assets/models/cabin.glb from nothing.

    /opt/homebrew/bin/blender -b --python art/blender/cabin_build.py

Conventions: 1 unit = 1 m, real-world size (zenscape draws it at 0.8).
Blender Z up; the glTF exporter converts to Godot Y up. Blender -Y (the door side) is Godot +Z.

cabin.glb is split into top-level stage nodes (the sky branch revealed them one
at a time; zenscape merges them). The names are the contract:

| Node            | What                                                      |
|-----------------|-----------------------------------------------------------|
| sill            | flat stones, the doorstep stone, the bottom log ring and the plank floor |
| course_1 .. _6  | log courses with notched, overhanging corners; door gap in the front, window gap in the +X wall |
| gables          | the stepped log gable ends, the ridge log and two purlins  |
| roof            | two pitched planes of split shakes on a deck, a ridge cap  |
| chimney         | stacked-stone chimney on the -X wall, above the ridge      |
| door            | jambs and a plank door with battens and strap hinges       |
| window          | frame, mullions, sill board and a `glow` pane (+X wall)    |
| smoke (empty)   | the top of the chimney flue                               |
| door_step (empty) | on the ground just outside the door                     |

Every mesh stage node has an identity transform: its origin is the cabin's
ground centre.

Materials are one-sided (backface culling on, so glTF doubleSided is false).
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BLEND = HERE / "cabin.blend"
MODELS = ROOT / "assets/models"
BUDGET = {"cabin": 3000}
STAGES = ["sill"] + [f"course_{k}" for k in range(1, 7)] + ["gables", "roof", "chimney", "door", "window"]

rng = random.Random(31)    # deterministic "whittling" jitter

# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def material(name, hexcol, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    rgb = srgb(hexcol)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*rgb, 1.0)
    m.use_backface_culling = True
    return m


# Warm muted woods, peeled logs, a darker roof, two stones.
MAT = {m.name: m for m in [
    material("log", "9a7448", 0.9),            # peeled wall logs, warm
    material("wood", "6b5038", 0.9),           # bark, the door planks
    material("wood_light", "8c6b48", 0.85),    # floor, frames, battens
    material("wood_cut", "b08d64", 0.85),      # sawn log ends
    material("roof", "5a3f2a", 0.95),          # split shakes, a darker weathered wood
    material("roof_under", "3e2c20", 1.0),     # the deck seen from below the eaves
    material("stone", "7f776e", 0.95),
    material("stone_dark", "6a635b", 0.95),    # every third chimney stone or so
    material("char", "2a221d", 1.0),           # the sooty flue
    material("metal", "35302b", 0.55, metal=0.6),
    material("glow", "f6e3a0", 0.6),           # Godot makes this emissive at night
]}


class Part:
    """One mesh object built with bmesh; faces tagged with named materials."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def paint(self, faces, mat):
        i = self.mi(mat)
        for f in faces:
            f.material_index = i
        return faces

    def solid(self, verts, mat):
        faces = list({f for v in verts for f in v.link_faces})
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self.paint(faces, mat)

    def loft(self, rings, mat, cap_mat=None):
        bm, segs = self.bm, len(rings[0])
        vr = [[bm.verts.new(Vector(p)) for p in r] for r in rings]
        side = []
        for p, q in zip(vr, vr[1:]):
            for i in range(segs):
                j = (i + 1) % segs
                side.append(bm.faces.new((p[i], p[j], q[j], q[i])))
        ends = [bm.faces.new(list(reversed(vr[0]))), bm.faces.new(vr[-1])]
        bmesh.ops.recalc_face_normals(bm, faces=side + ends)
        self.paint(side, mat)
        self.paint(ends, cap_mat or mat)
        return side, ends, vr

    def rod(self, a, b, profile, sides, mat, twist=0.0, rough=0.0, cap_mat=None):
        """A faceted, tapered prism from a to b. profile: (t along a->b, radius) rings."""
        a, b = Vector(a), Vector(b)
        frame = (b - a).normalized().to_track_quat("Z", "Y").to_matrix()
        rings = []
        for t, r in profile:
            c = a.lerp(b, t)
            ring = []
            for i in range(sides):
                ang = twist + 2 * math.pi * i / sides
                p = c + frame @ Vector((r * math.cos(ang), r * math.sin(ang), 0))
                if rough:
                    p += Vector([rng.uniform(-rough, rough) for _ in range(3)])
                ring.append(p)
            rings.append(ring)
        return self.loft(rings, mat, cap_mat)

    def box(self, centre, size, mat, rot_z=0.0, rot=None):
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        m = (Matrix.Translation(Vector(centre)) @ (rot or Matrix.Rotation(rot_z, 4, "Z"))
             @ Matrix.Diagonal((*size, 1.0)))
        bmesh.ops.transform(self.bm, verts=res["verts"], matrix=m)
        return self.solid(res["verts"], mat)

    def hull(self, points, mat):
        verts = [self.bm.verts.new(Vector(p)) for p in points]
        res = bmesh.ops.convex_hull(self.bm, input=verts)
        for g in res.get("geom_interior", []) + res.get("geom_unused", []):
            if isinstance(g, bmesh.types.BMVert) and g.is_valid:
                self.bm.verts.remove(g)
        verts = [v for v in verts if v.is_valid]
        return self.solid(verts, mat)

    def stone(self, centre, rx, ry, h, mat="stone", spin=0.0, n=7):
        """A flat-bottomed faceted stone: a ring at the base, a smaller one on top."""
        c = Vector(centre)
        rotm = Matrix.Rotation(spin, 3, "Z")
        pts = []
        for k in range(n):
            th = 2 * math.pi * k / n + rng.uniform(-0.2, 0.2)
            r = rng.uniform(0.85, 1.0)
            pts.append(Vector((rx * r * math.cos(th), ry * r * math.sin(th), 0.0)))
            if k % 2 == 0:
                s = rng.uniform(0.6, 0.8)
                pts.append(Vector((rx * s * math.cos(th + 0.3), ry * s * math.sin(th + 0.3),
                                   h * rng.uniform(0.85, 1.0))))
        return self.hull([c + rotm @ q for q in pts], mat)

    def finish(self, location=(0, 0, 0)):
        for f in self.bm.faces:
            f.smooth = False
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.mats:
            mesh.materials.append(MAT[m])
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = location
        scene.collection.objects.link(obj)
        return obj


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.15
    e.location = loc
    scene.collection.objects.link(e)
    return e


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons) if obj.type == "MESH" else 0


# ================================================================ cabin layout
# Gable-front cabin: the door in the front gable wall (Blender -Y), the ridge
# along Y, the eave walls on the sides (X). Front/back logs lie along X at
# whole steps, side logs along Y half a step higher, so the corners lap.
W, D = 2.6, 3.2           # outside of the walls (x, y), without the corner overhang
R = 0.14                  # log radius
XC, YC = W / 2 - R, D / 2 - R   # wall centrelines
OVER = 0.2                # log ends past the outer wall face
STEP = 0.29               # course height
STONE_H = 0.06            # the flat stones under the sill
Z0 = STONE_H + R          # front/back sill log centre
LOG_SIDES = 7
PITCH = math.radians(40)
TP = math.tan(PITCH)
RIDGE_U = (Z0 + STEP * 6.5 + R + 0.005) + XC * TP   # roof underside at the ridge
EAVE_X = W / 2 + 0.34     # roof edge, sideways
ROOF_Y = D / 2 + OVER + 0.22   # roof edge, front and back
DOOR_HW = 0.42            # half width of the door gap
DOOR_TOP = Z0 + STEP * 7 - R   # the first gable log is the lintel
DOOR_BOT = Z0 + R
WIN_Y = (-0.62, 0.16)     # window gap in the +X wall, along Y
WIN_COURSES = (2, 3)      # side courses cut for the window
CHIM_Y = 0.45             # chimney on the -X wall, towards the back


def fb_z(k):
    return Z0 + STEP * k


def side_z(k):
    return Z0 + STEP * (k + 0.5) if k > 0 else Z0 + STEP * 0.5


def log(p, a, b, r=R, cap_mat="wood_cut", mat="log"):
    """A wall log from a to b: seven facets, a slight taper and whittled jitter."""
    taper = rng.uniform(0.93, 0.98)
    tw = rng.uniform(0, math.pi)
    if rng.random() < 0.5:
        prof = [(0, r), (1, r * taper)]
    else:
        prof = [(0, r * taper), (1, r)]
    return p.rod(a, b, prof, LOG_SIDES, mat, twist=tw, rough=0.006, cap_mat=cap_mat)


def wall_logs(p, k):
    """The four logs of course k (0 = sill), split round the door and window."""
    zf, zs = fb_z(k), side_z(k)
    xe, ye = W / 2 + OVER, D / 2 + OVER
    # back wall, whole
    log(p, (-xe, YC, zf), (xe, YC, zf))
    # front wall: the door gap from course 1 up
    if k == 0:
        log(p, (-xe, -YC, zf), (xe, -YC, zf))
    else:
        log(p, (-xe, -YC, zf), (-DOOR_HW, -YC, zf))
        log(p, (DOOR_HW, -YC, zf), (xe, -YC, zf))
    # side walls; the window gap in the +X wall
    log(p, (-XC, -ye, zs), (-XC, ye, zs))
    if k in WIN_COURSES:
        log(p, (XC, -ye, zs), (XC, WIN_Y[0], zs))
        log(p, (XC, WIN_Y[1], zs), (XC, ye, zs))
    else:
        log(p, (XC, -ye, zs), (XC, ye, zs))


def build_sill():
    p = Part("sill")
    # flat stones under the four corners and the middle of each wall
    for x in (-1, 1):
        for y in (-1, 1):
            p.stone((x * XC, y * YC, 0), 0.24, 0.2, STONE_H + 0.012, spin=rng.uniform(0, 3))
    for y in (-1, 1):
        p.stone((0.55 * (1 if y < 0 else -1), y * YC, 0), 0.2, 0.17, STONE_H + 0.01,
                spin=rng.uniform(0, 3))
    for x in (-1, 1):   # the side sill rides half a step up: a taller pier
        p.stone((x * XC, 0.1, 0), 0.19, 0.2, side_z(0) - R + 0.012, spin=rng.uniform(0, 3), n=6)
    # the doorstep, a broad flat stone
    p.stone((0.0, -D / 2 - 0.2, 0), 0.38, 0.2, 0.09, spin=0.05, n=8)
    wall_logs(p, 0)
    # plank floor at the threshold, inside the ring
    top = Z0 + R - 0.01
    n = 5
    span = 2 * (XC - R * 0.4)
    for i in range(n):
        x = -span / 2 + span * (i + 0.5) / n
        p.box((x + rng.uniform(-0.01, 0.01), 0, top - 0.025),
              (span / n - 0.015, 2 * (YC - R * 0.4), 0.05), "wood_light",
              rot_z=rng.uniform(-0.006, 0.006))
    return p.finish()


def build_course(k):
    p = Part(f"course_{k}")
    wall_logs(p, k)
    return p.finish()


def build_gables():
    p = Part("gables")
    k = 7
    ye = D / 2 + 0.02
    while fb_z(k) + R * 0.2 < RIDGE_U - 0.2:
        z = fb_z(k)
        for y in (-YC, YC):
            side, ends, vr = log(p, (-W / 2 - OVER, y, z), (W / 2 + OVER, y, z))
            # trim each end to the roof line, so the cut face follows the slope
            for ring in (vr[0], vr[-1]):
                for v in ring:
                    lim = (RIDGE_U - 0.012 - v.co.z) / TP
                    v.co.x = math.copysign(min(abs(v.co.x), lim), v.co.x)
        k += 1
    # ridge log and a purlin each side, poking out under the roof's front and back
    yl = ROOF_Y - 0.08
    rr = 0.12
    log(p, (0, -yl, RIDGE_U - rr), (0, yl, RIDGE_U - rr), r=rr)
    for s in (-1, 1):
        x = s * 0.68
        zr = RIDGE_U - abs(x) * TP - 0.1
        log(p, (x, -yl, zr), (x, yl, zr), r=0.1)
    del ye
    return p.finish()


def build_roof():
    p = Part("roof")
    c, s = math.cos(PITCH), math.sin(PITCH)
    ridge = Vector((0, 0, RIDGE_U))
    LU = EAVE_X / c                      # slope length, ridge to eave
    EXP, SH_L, SH_T, LIFT = 0.53, 0.72, 0.035, 0.05
    for side in (1, -1):
        u = Vector((side * c, 0, -s))    # down the slope
        n = Vector((side * s, 0, c))     # out of the roof
        v = Vector((0, side, 0))
        rot = Matrix((u, v, n)).transposed().to_4x4()
        # the deck: a slab the shakes lie on; its edge gives the eaves some weight
        p.box(ridge + u * (LU / 2 + 0.01) + n * 0.025, (LU + 0.02, 2 * ROOF_Y, 0.05), "roof_under",
              rot=rot)
        # rows of split shakes, from the eave up; each row's butt overlaps the row below
        rows = math.ceil((LU - 0.12) / EXP)
        for r in range(rows):
            s_butt = LU + 0.04 - r * EXP
            s_top = max(0.0, s_butt - SH_L)
            y = -ROOF_Y - 0.04
            stagger = (r % 2) * 0.22
            widths = []
            while y < ROOF_Y + 0.04:
                w = rng.uniform(0.44, 0.66) if widths or not stagger else stagger
                w = min(w, ROOF_Y + 0.04 - y)
                if w < 0.12 and widths:
                    widths[-1] += w
                    break
                widths.append(w)
                y += w
            y = -ROOF_Y - 0.04
            for w in widths:
                y0, y1 = y + 0.008, y + w - 0.008
                y += w
                drop = rng.uniform(-0.03, 0.03)          # ragged butts
                lift = LIFT + rng.uniform(-0.01, 0.012)
                b = s_butt + drop
                pts = []
                for sv, h in ((s_top, 0.05), (b, 0.05 + lift)):
                    for yy in (y0, y1):
                        for t in (0.0, SH_T):
                            pts.append(ridge + u * sv + Vector((0, yy, 0))
                                       + n * (h + t + rng.uniform(-0.004, 0.004)))
                p.hull(pts, "roof")
        # a ridge board along the top of each side, lapping the other
        p.box(ridge + u * 0.1 + n * 0.13 + Vector((0, 0, 0.01)), (0.26, 2 * ROOF_Y + 0.06, 0.05),
              "wood", rot=rot)
    return p.finish()


CHIM_TOP = RIDGE_U + 0.36


def build_chimney():
    """Stacked stones against the -X wall: a broad firebox, a shoulder, a stack."""
    p = Part("chimney")
    x_wall = -W / 2 + 0.02
    z = 0.0
    layers = []
    while z < CHIM_TOP - 0.08:
        h = rng.uniform(0.2, 0.28)
        if CHIM_TOP - (z + h) < 0.12:
            h = CHIM_TOP - z
        if z < 1.3:
            dx, dy = 0.7, 0.9            # the firebox
        elif z < 1.75:
            f = (z - 1.3) / 0.45
            dx, dy = 0.7 - 0.2 * f, 0.9 - 0.34 * f
        else:
            dx, dy = 0.5, 0.56           # the stack
        layers.append((z, h, dx, dy))
        z += h
    for i, (z, h, dx, dy) in enumerate(layers):
        # two or three stones per course, the joints shifting, so it reads as laid stone
        cuts = sorted(rng.uniform(0.3, 0.7) for _ in range(1 if dy < 0.7 else rng.choice((1, 2))))
        if len(cuts) == 2 and cuts[1] - cuts[0] < 0.25:
            cuts = [0.5]
        edges = [0.0] + cuts + [1.0]
        for e0, e1 in zip(edges, edges[1:]):
            y0 = CHIM_Y - dy / 2 + dy * e0 + 0.008
            y1 = CHIM_Y - dy / 2 + dy * e1 - 0.008
            out = rng.uniform(-0.015, 0.035)         # some stones stand proud
            xo = x_wall - dx - out
            z0, z1 = z + 0.006 * (z > 0), z + h - 0.006
            ch = rng.uniform(0.035, 0.06)             # chamfer on the outer edges
            pts = [Vector((x_wall, y0, z0)), Vector((x_wall, y1, z0)),
                   Vector((x_wall, y0, z1)), Vector((x_wall, y1, z1))]
            pts += [Vector((xo + ch * 0.4, y0 + 0.02, zz)) for zz in (z0, z1)]   # a bevel at one end
            for yy, zz in ((y0 + ch, z0 + ch * 0.6), (y1 - ch, z0 + ch * 0.6),
                           (y0 + ch, z1 - ch * 0.6), (y1 - ch, z1 - ch * 0.6)):
                pts.append(Vector((xo, yy, zz)))
            pts.append(Vector((xo - rng.uniform(0.0, 0.03), (y0 + y1) / 2 + rng.uniform(-0.04, 0.04),
                               (z0 + z1) / 2 + rng.uniform(-0.03, 0.03))))
            for q in pts[4:]:
                q += Vector([rng.uniform(-0.01, 0.01) for _ in range(3)])
            p.hull(pts, "stone_dark" if rng.random() < 0.35 else "stone")
    # a flat cap stone and the sooty flue mouth
    top = layers[-1][0] + layers[-1][1]
    cx = x_wall - 0.25
    p.box((cx, CHIM_Y, top + 0.04), (0.6, 0.66, 0.08), "stone_dark", rot_z=0.04)
    p.box((cx, CHIM_Y, top + 0.081), (0.24, 0.28, 0.004), "char", rot_z=0.04)
    obj = p.finish()
    smoke = empty("smoke", (round(cx, 3), CHIM_Y, round(top + 0.09, 3)))
    return obj, smoke


def build_door():
    p = Part("door")
    yf = -YC
    hgt = DOOR_TOP - DOOR_BOT
    zc = (DOOR_TOP + DOOR_BOT) / 2
    # jambs over the cut log ends, and a lintel board
    for x in (-1, 1):
        p.box((x * (DOOR_HW + 0.03), yf, zc), (0.07, 2 * R + 0.04, hgt), "wood_light")
    p.box((0, yf, DOOR_TOP - 0.02), (2 * DOOR_HW + 0.14, 2 * R + 0.04, 0.06), "wood_light")
    # the door: four planks set a little back from the outer face
    planks = 4
    dw = 2 * DOOR_HW - 0.02
    yd = yf + 0.02
    for i in range(planks):
        x = -dw / 2 + dw * (i + 0.5) / planks
        p.box((x, yd, zc - 0.01), (dw / planks - 0.012, 0.05, hgt - 0.03 + rng.uniform(-0.02, 0.0)),
              "wood")
    # battens and a brace on the outside
    yb = yd - 0.04
    for z in (DOOR_BOT + 0.3, DOOR_TOP - 0.3):
        p.box((0, yb, z), (dw - 0.06, 0.035, 0.11), "wood_light")
    span = (DOOR_TOP - 0.3) - (DOOR_BOT + 0.3)
    ang = math.atan2(span, dw - 0.2)
    p.box((0, yb, zc), (math.hypot(span, dw - 0.2) - 0.06, 0.03, 0.1), "wood_light",
          rot=Matrix.Rotation(ang, 4, "Y"))
    # strap hinges on the left, a latch on the right
    for z in (DOOR_BOT + 0.3, DOOR_TOP - 0.3):
        p.box((-dw / 2 + 0.17, yb - 0.022, z), (0.34, 0.012, 0.045), "metal")
    p.box((dw / 2 - 0.12, yb - 0.03, zc), (0.05, 0.05, 0.05), "metal")
    return p.finish()


def build_window():
    p = Part("window")
    xw = XC
    y0, y1 = WIN_Y
    zb = side_z(WIN_COURSES[0] - 1) + R
    zt = side_z(WIN_COURSES[-1] + 1) - R
    yc, zc = (y0 + y1) / 2, (zb + zt) / 2
    wy, hz = y1 - y0, zt - zb
    t = 0.06
    # frame boards over the cut log ends
    for y in (y0 + t / 2 - 0.01, y1 - t / 2 + 0.01):
        p.box((xw, y, zc), (2 * R + 0.04, t, hz + 0.04), "wood_light")
    p.box((xw, yc, zt - t / 2 + 0.01), (2 * R + 0.04, wy + 0.04, t), "wood_light")
    # the sill board sticks out under the pane
    p.box((xw + 0.06, yc, zb + 0.015), (2 * R + 0.14, wy + 0.12, 0.05), "wood_light")
    # the pane: warm, emissive in game
    p.box((xw + 0.02, yc, zc), (0.03, wy - 2 * t + 0.02, hz - t - 0.02), "glow")
    # a cross of glazing bars in front of it
    xo = xw + 0.045
    p.box((xo, yc, zc), (0.025, 0.035, hz - t), "wood")
    p.box((xo, yc, zc + 0.01), (0.025, wy - 2 * t, 0.035), "wood")
    return p.finish()


def build_cabin():
    objs = [build_sill()]
    objs += [build_course(k) for k in range(1, 7)]
    objs += [build_gables(), build_roof()]
    chim, smoke = build_chimney()
    objs += [chim, build_door(), build_window()]
    step = empty("door_step", (0.0, -D / 2 - 0.5, 0.0))
    return objs + [smoke, step]


# ================================================================ build + export
BUILDERS = {"cabin": build_cabin}
report = {}
groups = {}
for name, build in BUILDERS.items():
    objs = build()
    groups[name] = objs
    coll = bpy.data.collections.new(name)
    scene.collection.children.link(coll)
    for o in objs:
        scene.collection.objects.unlink(o)
        coll.objects.link(o)
    n = sum(tris(o) for o in objs)
    pts = [o.matrix_world @ v.co for o in objs if o.type == "MESH" for v in o.data.vertices]
    lo = Vector([min(q[i] for q in pts) for i in range(3)])
    hi = Vector([max(q[i] for q in pts) for i in range(3)])
    report[name] = dict(triangles=n, size=tuple(round(x, 3) for x in hi - lo),
                        min=tuple(round(x, 3) for x in lo), max=tuple(round(x, 3) for x in hi))
    assert n <= BUDGET[name], (name, n)

cabin = {o.name: o for o in groups["cabin"]}
for s in STAGES:
    o = cabin[s]
    assert o.type == "MESH" and o.matrix_world == Matrix.Identity(4), s
    print("CABIN_STAGE", s, "triangles", tris(o))
for e in ("smoke", "door_step"):
    assert cabin[e].type == "EMPTY", e
    print("CABIN_EMPTY", e, "blender", tuple(round(x, 3) for x in cabin[e].location),
          "godot", (round(cabin[e].location.x, 3), round(cabin[e].location.z, 3),
                    round(-cabin[e].location.y, 3)))
assert any(m.name == "glow" for m in cabin["window"].data.materials)
for name in report:
    assert report[name]["min"][2] >= -0.01, (name, report[name])
print("CABIN_FOOTPRINT walls", W, "x", D, "eaves", round(side_z(6) + R, 3),
      "ridge", round(RIDGE_U, 3), "door clear", round(DOOR_TOP - DOOR_BOT, 3),
      "door width", round(2 * DOOR_HW, 3))
for name, r in report.items():
    print("CABIN_REPORT", name, r)

bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

MODELS.mkdir(parents=True, exist_ok=True)
for name, objs in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = MODELS / f"{name}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
        export_apply=False, export_animations=False, export_materials="EXPORT",
        export_normals=True, export_extras=False)
    print("CABIN_EXPORTED", path)
