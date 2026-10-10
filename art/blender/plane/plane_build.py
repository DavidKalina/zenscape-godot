"""Concept models for the plane's ruin redesign: three directions for how
the little biplane belongs to the gothic ruins, each carrying the lodestone
cradle on the centre of the top wing (docs/design/plane-redesign.md).

Concept only: nothing here is exported to the game. The three planes, a
stand-in pilot (head and shoulders, as scripts/plane_pilot.gd seats them)
and a small gothic ruin on a sky island for context are saved to
art/blender/plane/plane.blend; plane_render.py renders the shots.

    /opt/homebrew/bin/blender -b --python art/blender/plane/plane_build.py

Directions:
  A  Salvager    the pilot's warm wood-and-cream biplane, patched with what
                 the ruins gave: a carved basalt cowl ring (a rose-window
                 rim), quatrefoil wing marks, pointed-arch tracery laths in
                 the wing bays, and the cradle on a salvaged column capital.
  B  Builders'   a craft of the ancient sky-builders: bronze and pale stone,
                 a rose-window cowl, wings whose trailing edges are an
                 arcade of pointed arches, a lancet fin, millstone wheels,
                 the cradle ringed by a low tracery corona.
  C  Belfry      an abbey's own plane: dark oak and painted vellum (red and
                 slate-blue manuscript bands), a bronze bell for a cowl,
                 slate-tiled turtle deck, the stone hung in a little
                 bell-cote window.

Conventions as art/blender/pilot/pilot_build.py: 1 unit = 1 m, the plane at
the game's size (scripts/plane_figure.gd: 1.4 m upper span, nose to tail
about 1.45 m). Parts are written in the game's frame (Y up, nose to -Z) and
turned into Blender's (Z up, nose to +Y) by `G`.

Objects per direction (collection Plane_<D>): Root_<D> (empty, pose the
plane by it), the fixed parts joined per material, Prop_<D>, and the cradle:
Hoop_<D> (turns about the wing's up axis, yaw), Stone_<D> (child of the hoop,
tips about its pins, pitch), Glow_<D> (halo and wisps, child of the stone)
and StoneLight_<D>. Pilot objects are named Pilot_*, so tri counts can
leave them out.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
BLEND = HERE / "plane.blend"

# ------------------------------------------------------------- the frame
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def G(p):
    return Vector((p[0], -p[2], p[1]))


def T(x=0.0, y=0.0, z=0.0, rx=0.0, ry=0.0, rz=0.0, s=(1, 1, 1)):
    """A transform in the game's frame (Godot's YXZ euler order)."""
    rot = (Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
           @ Matrix.Rotation(rz, 4, "Z"))
    sc = Matrix.Diagonal((s[0], s[1], s[2], 1.0))
    return Matrix.Translation((x, y, z)) @ rot @ sc


# ------------------------------------------------------------- materials
def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


MATS = {}


def mat(name, hexcol, rough=0.6, metal=0.0, coat=0.0, emit=None, emit_strength=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if coat:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.35
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        b.inputs["Emission Strength"].default_value = emit_strength
    m.diffuse_color = (*srgb(hexcol), 1)
    MATS[name] = m
    return m


def soft_mat(name, hexcol, strength, power=2.5, alpha=1.0, along=False):
    """A soft glow: emission fading to clear at the silhouette (`along`:
    fading along the mesh's U instead, for the wisps)."""
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    m.use_backface_culling = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*srgb(hexcol), 1)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    if along:
        uv = nt.nodes.new("ShaderNodeUVMap")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(uv.outputs["UV"], sep.inputs[0])
        # alpha = (1-u)^power * (1-|2v-1|^2) * alpha
        inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        nt.links.new(sep.outputs["X"], inv.inputs[1])
        pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"
        pw.inputs[1].default_value = power
        nt.links.new(inv.outputs[0], pw.inputs[0])
        v2 = nt.nodes.new("ShaderNodeMath"); v2.operation = "MULTIPLY_ADD"
        v2.inputs[1].default_value = 2.0; v2.inputs[2].default_value = -1.0
        nt.links.new(sep.outputs["Y"], v2.inputs[0])
        sq = nt.nodes.new("ShaderNodeMath"); sq.operation = "POWER"; sq.inputs[1].default_value = 2.0
        nt.links.new(v2.outputs[0], sq.inputs[0])
        edge = nt.nodes.new("ShaderNodeMath"); edge.operation = "SUBTRACT"; edge.inputs[0].default_value = 1.0
        nt.links.new(sq.outputs[0], edge.inputs[1])
        a = nt.nodes.new("ShaderNodeMath"); a.operation = "MULTIPLY"
        nt.links.new(pw.outputs[0], a.inputs[0]); nt.links.new(edge.outputs[0], a.inputs[1])
        fac = a
    else:
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.5
        inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        nt.links.new(lw.outputs["Facing"], inv.inputs[1])
        pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"
        pw.inputs[1].default_value = power
        nt.links.new(inv.outputs[0], pw.inputs[0])
        fac = pw
    k = nt.nodes.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.name = "glow_k"
    k.inputs[1].default_value = alpha * strength
    nt.links.new(fac.outputs[0], k.inputs[0])
    nt.links.new(k.outputs[0], em.inputs["Strength"])
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs[0])
    MATS[name] = m
    return m


# ------------------------------------------------------------- geometry
class Mesher:
    """Geometry gathered per material, then made one object per material."""

    def __init__(self):
        self.bms = {}

    def bm(self, m):
        if m.name not in self.bms:
            self.bms[m.name] = (bmesh.new(), m)
        return self.bms[m.name][0]

    def build(self, name, coll, parent=None, smooth=False):
        objs = []
        for key, (b, m) in self.bms.items():
            bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-6)
            bmesh.ops.recalc_face_normals(b, faces=b.faces)
            me = bpy.data.meshes.new(f"{name}_{key}")
            b.to_mesh(me)
            b.free()
            for p in me.polygons:
                p.use_smooth = smooth
            ob = bpy.data.objects.new(f"{name}_{key}", me)
            me.materials.append(m)
            coll.objects.link(ob)
            if parent:
                ob.parent = parent
            objs.append(ob)
        self.bms = {}
        return objs


def _verts(b, pts, M):
    return [b.verts.new(G(M @ Vector(p))) for p in pts]


def loft(ms, m, sections, M=Matrix(), cap=True, closed=True):
    """Quads between consecutive sections (each a list of points, the same
    count), capped at both ends."""
    b = ms.bm(m)
    rings = [_verts(b, s, M) for s in sections]
    n = len(sections[0])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            q = [r0[i], r0[j], r1[j], r1[i]]
            if len({v.co.to_tuple(7) for v in q}) >= 3:
                try:
                    b.faces.new(q if len({v.co.to_tuple(7) for v in q}) == 4 else _dedupe(q))
                except ValueError:
                    pass
    if cap:
        for r in (rings[0], rings[-1]):
            if len({v.co.to_tuple(6) for v in r}) >= 3:
                try:
                    b.faces.new(r)
                except ValueError:
                    pass


def _dedupe(q):
    out = []
    for v in q:
        if not any((v.co - o.co).length < 1e-7 for o in out):
            out.append(v)
    return out


def ring(z, rx, ry, sides, x=0.0, y=0.0, phase=0.5, jitter=0.0, rng=None):
    pts = []
    for i in range(sides):
        a = math.tau * (i + phase) / sides
        j = 1.0 + (rng.uniform(-jitter, jitter) if rng else 0.0)
        pts.append((x + math.cos(a) * rx * j, y + math.sin(a) * ry * j, z))
    return pts


def hull(ms, m, rings_, sides, M=Matrix(), jitter=0.0, seed=1):
    """plane_figure.gd `_hull`: rings (z, half width, half height)."""
    rng = random.Random(seed) if jitter else None
    loft(ms, m, [ring(z, max(rx, 1e-4), max(ry, 1e-4), sides, jitter=jitter, rng=rng)
                 for z, rx, ry in rings_], M)


def tube(ms, m, a, b, r0, r1=None, sides=6, M=Matrix()):
    a, b = Vector(a), Vector(b)
    r1 = r0 if r1 is None else r1
    d = (b - a).normalized()
    u = d.cross(Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))).normalized()
    v = d.cross(u)
    secs = []
    for c, r in ((a, r0), (b, r1)):
        secs.append([tuple(c + (u * math.cos(math.tau * (i + 0.5) / sides)
                                 + v * math.sin(math.tau * (i + 0.5) / sides)) * r)
                     for i in range(sides)])
    loft(ms, m, secs, M)


def frustum(ms, m, r0, r1, h, sides, M=Matrix()):
    """plane_figure.gd's GliderFigure._frustum: along Y, centred."""
    tube(ms, m, (0, -h / 2, 0), (0, h / 2, 0), r0, r1, sides, M)


def box(ms, m, size, M=Matrix()):
    x, y, z = size[0] / 2, size[1] / 2, size[2] / 2
    loft(ms, m, [[(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z)],
                 [(-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]], M)


def prism(ms, m, section, x0, x1, M=Matrix()):
    """A prism along X from x0 to x1; `section` its outline in (z, y)."""
    loft(ms, m, [[(x, y, z) for z, y in section] for x in (x0, x1)], M)


def gem(ms, m, r, M=Matrix(), sub=1):
    b = ms.bm(m)
    bmesh.ops.create_icosphere(b, subdivisions=sub, radius=r, matrix=C @ M)


def hoop(ms, m, radius, wide, deep, segs, M=Matrix(), arc=(0.0, math.tau)):
    """A ring in the local XY plane round Z: `wide` radially, `deep` along Z."""
    full = abs(arc[1] - arc[0] - math.tau) < 1e-6
    secs = []
    n = segs if full else segs + 1
    for i in range(n):
        a = arc[0] + (arc[1] - arc[0]) * i / segs
        c, s = math.cos(a), math.sin(a)
        secs.append([((radius + dr) * c, (radius + dr) * s, dz)
                     for dr, dz in ((-wide / 2, -deep / 2), (wide / 2, -deep / 2),
                                    (wide / 2, deep / 2), (-wide / 2, deep / 2))])
    if full:
        secs.append(secs[0])
    loft(ms, m, secs, M, cap=not full)


def strip(ms, m, pts, w, h, M=Matrix()):
    """A lath along a polyline (points in the frame), `w` across in X, `h`
    up from the points."""
    loft(ms, m, [[(p[0] - w / 2, p[1], p[2]), (p[0] + w / 2, p[1], p[2]),
                  (p[0] + w / 2, p[1] + h, p[2]), (p[0] - w / 2, p[1] + h, p[2])] for p in pts], M)


def strip_z(ms, m, pts, w, h, M=Matrix()):
    """A lath along a polyline running mostly across X: `w` wide in Z."""
    loft(ms, m, [[(p[0], p[1], p[2] - w / 2), (p[0], p[1], p[2] + w / 2),
                  (p[0], p[1] + h, p[2] + w / 2), (p[0], p[1] + h, p[2] - w / 2)] for p in pts], M)


# ------------------------------------------------------------- the wings
AIRFOIL_TOP = [(0.0, 0.0), (0.04, 0.42), (0.14, 0.78), (0.3, 1.0), (0.55, 0.86), (0.8, 0.5), (1.0, 0.08)]
AIRFOIL_UNDER = [(1.0, -0.02), (0.6, -0.135), (0.25, -0.22), (0.06, -0.2)]


def lerp(a, b, t):
    return a + (b - a) * t


def interp(table, u):
    for (u0, v0), (u1, v1) in zip(table, table[1:]):
        if u0 <= u <= u1:
            return lerp(v0, v1, (u - u0) / (u1 - u0) if u1 > u0 else 0)
    return table[-1][1]


class Wing:
    """plane_figure.gd `_wing`: tapered, rounded at the tips, an airfoil's
    section, the cloth sagging between ribs. `scallop` cuts the trailing
    edge between ribs into pointed arches (an arcade, seen from behind)."""

    def __init__(self, half, root, tip, thick, ribs, y, zc, round_from=0.86,
                 sag=0.18, scallop=0.0):
        self.half, self.root, self.tip, self.thick = half, root, tip, thick
        self.ribs, self.y, self.zc, self.inner = ribs, y, zc, half * round_from
        self.sag, self.scallop = sag, scallop
        self.rib_x = [self.inner * k / ribs for k in range(-ribs, ribs + 1)]

    def shape(self, x):
        """(leading edge z, chord, thickness, cut) at x."""
        ax = abs(x)
        c = lerp(self.root, self.tip, ax / self.half)
        th = self.thick
        f = 1.0
        if ax > self.inner:
            t = min(1.0, (ax - self.inner) / (self.half - self.inner))
            f = math.sqrt(max(0.0, 1 - t * t))
        le = self.zc - c * 0.45 * f
        cut = 1.0
        if self.scallop and ax < self.inner:
            step = self.inner / self.ribs
            ph = (ax % step) / step  # 0 at a rib, 0.5 mid-bay
            d = 1 - abs(ph - 0.5) * 2  # 0 at ribs, 1 mid-bay
            cut = 1 - self.scallop * (1 - (1 - d) ** 1.8)
        return le, c * max(f, 0.05), th * max(f, 0.15), cut

    def sagged(self, x):
        if abs(x) > self.inner:
            return 0.0
        step = self.inner / self.ribs
        ph = (abs(x) % step) / step
        return math.sin(ph * math.pi)

    def section(self, x):
        le, c, th, cut = self.shape(x)
        s = self.sagged(x)
        pts = []
        for u, v in AIRFOIL_TOP:
            uu = min(u, cut) if u < 0.999 else cut
            pts.append((x, self.y + v * th * (1 - self.sag * s), le + uu * c))
        for u, v in AIRFOIL_UNDER:
            uu = min(u, cut) if u > 0.001 else u
            pts.append((x, self.y + v * th * (1 - 0.1 * s), le + uu * c))
        return pts

    def stations(self, lo=None, hi=None):
        xs = set()
        step = self.inner / self.ribs
        k = 8 if self.scallop else 2
        for i in range(-self.ribs * k, self.ribs * k + 1):
            xs.add(round(step * i / k, 6))
        for q in (0.0, 0.4, 0.7, 0.88, 0.97):
            for h in (-1, 1):
                xs.add(round(h * (self.inner + (self.half - self.inner) * q), 6))
        lo = -self.half * 0.985 if lo is None else lo
        hi = self.half * 0.985 if hi is None else hi
        xs = sorted(x for x in xs if lo - 1e-6 <= x <= hi + 1e-6)
        return xs

    def build(self, ms, m, lo=None, hi=None, M=Matrix()):
        loft(ms, m, [self.section(x) for x in self.stations(lo, hi)], M)

    def top(self, x, z):
        le, c, th, cut = self.shape(x)
        u = min(max((z - le) / c, 0.0), 1.0)
        return self.y + interp(AIRFOIL_TOP, u) * th * (1 - self.sag * self.sagged(x))

    def top_line(self, x, u0=0.0, u1=1.0, n=7, lift=0.0015):
        le, c, th, cut = self.shape(x)
        out = []
        for i in range(n):
            u = lerp(u0, min(u1, cut), i / (n - 1))
            z = le + u * c
            out.append((x, self.top(x, z) + lift, z))
        return out

    def decal(self, ms, m, x, z, r, lift=0.002, sides=14, M=Matrix()):
        pts = [(x + math.cos(math.tau * i / sides) * r, z + math.sin(math.tau * i / sides) * r)
               for i in range(sides)]
        loft(ms, m, [[(px, self.top(px, pz) + lift - 0.0012, pz) for px, pz in pts],
                     [(px, self.top(px, pz) + lift, pz) for px, pz in pts]], M)

    def poly_decal(self, ms, m, pts, lift=0.002, M=Matrix()):
        loft(ms, m, [[(px, self.top(px, pz) + lift - 0.0012, pz) for px, pz in pts],
                     [(px, self.top(px, pz) + lift, pz) for px, pz in pts]], M)


def quatrefoil(ms, m, wing, x, z, r, lift, M=Matrix()):
    for a in range(4):
        ang = math.tau * a / 4 + math.pi / 4
        wing.decal(ms, m, x + math.cos(ang) * r * 0.45, z + math.sin(ang) * r * 0.45, r * 0.5, lift, 10, M)


def pointed_arch(x0, x1, base, rise, n=6):
    """Points (x, z) along a pointed arch from x0 to x1, springing at z=base
    and rising `rise` toward -z (forward), apex mid-way."""
    mid = (x0 + x1) / 2
    half = (x1 - x0) / 2
    out = []
    for i in range(n + 1):
        t = i / n
        if t <= 0.5:
            s = t * 2
            x = lerp(x0, mid, 1 - math.cos(s * math.pi / 2) ** 1.0 * 0 - (1 - s))
            x = x0 + half * s
            z = base - rise * math.sin(s * math.pi / 2) ** 0.7
        else:
            s = (1 - t) * 2
            x = x1 - half * s
            z = base - rise * math.sin(s * math.pi / 2) ** 0.7
        out.append((x, z))
    return out


# ------------------------------------------------------------- the plane
SPAN, LOWER_SPAN, CHORD, TIP_CHORD, THICK, RIBS = 1.4, 1.26, 0.28, 0.22, 0.028, 7
LOWER_Y, UPPER_Y, STAGGER = -0.1, 0.3, -0.06
BODY = [(-0.47, 0.13, 0.135), (-0.36, 0.142, 0.15), (-0.1, 0.146, 0.158), (0.1, 0.14, 0.15),
        (0.3, 0.105, 0.12), (0.52, 0.06, 0.085), (0.72, 0.016, 0.05)]
# The lodestone cradle: the stone's middle in the plane's frame. It stands
# high enough over the upper wing (0.3) to clear the pilot's head (top about
# 0.39 at z 0.24) seen from the chase camera (5.2 m back, 1.6 up).
CRADLE = Vector((0.0, 0.455, -0.07))
HOOP_R = 0.082
STONE_LEN = 0.19


def pilot(coll, parent, root):
    """A stand-in for scripts/plane_pilot.gd's pilot (person_kit.gd parts):
    jacket, fleece collar, red scarf, faceted head in a leather cap and
    brass goggles. Not redesigned: only so the cockpit reads at scale."""
    ms = Mesher()
    jacket = mat("pilot_jacket", "4a2a1e", 0.6, coat=0.2)
    fleece = mat("pilot_fleece", "e6d8bb", 0.95)
    scarf = mat("pilot_scarf", "d9573a", 0.95)
    skin = mat("pilot_skin", "e8c39e", 0.8)
    leather = mat("pilot_leather", "5e3522", 0.55, coat=0.3)
    brass = mat("brass", "d6ad62", 0.33, 0.85)
    lens = mat("pilot_lens", "3b6370", 0.1, 0.0, coat=1.0)
    k = 0.92
    S = T(0, 0.11, 0.24, s=(k, k, k))
    up = Matrix.Rotation(-math.pi / 2, 4, "X")
    hull(ms, jacket, [(0.0, 0.07, 0.055), (0.08, 0.085, 0.062), (0.125, 0.092, 0.058), (0.152, 0.05, 0.04)], 8, S @ up)
    frustum(ms, fleece, 0.07, 0.056, 0.03, 10, S @ T(0, 0.138, 0.006, s=(1, 1, 0.92)))
    gem(ms, scarf, 0.05, S @ T(0, 0.15, 0, s=(1.3, 0.55, 1.2)))
    H = S @ T(0, 0.185, 0) @ T(s=(0.9, 0.9, 0.9))
    frustum(ms, skin, 0.026, 0.023, 0.05, 6, S @ T(0, 0.17, 0))
    mid = T(0, 0.055, 0)
    hull(ms, skin, [(-0.08, 0.03, 0.03), (-0.05, 0.064, 0.064), (0.0, 0.075, 0.075), (0.045, 0.066, 0.068), (0.078, 0.03, 0.034)], 8, H @ mid @ up)
    hull(ms, leather, [(-0.005, 0.081, 0.083), (0.04, 0.073, 0.076), (0.072, 0.045, 0.048), (0.09, 0.0, 0.0)], 8, H @ mid @ T(0, 0.012, 0.012) @ up)
    for side in (-1, 1):
        gem(ms, leather, 0.03, H @ mid @ T(0.078 * side, -0.02, 0.007, s=(0.45, 1.3, 0.9)))
        frustum(ms, brass, 0.025, 0.025, 0.014, 8, H @ mid @ T(0.03 * side, 0.012, -0.073, rx=math.pi / 2, ry=0.35 * side))
        frustum(ms, lens, 0.019, 0.019, 0.016, 8, H @ mid @ T(0.031 * side, 0.012, -0.076, rx=math.pi / 2, ry=0.35 * side))
    frustum(ms, leather, 0.085, 0.085, 0.016, 10, H @ mid @ T(0, 0.012, 0.01))
    # Arms down to the stick, and a short scarf tail streaming back.
    for side in (-1, 1):
        tube(ms, jacket, (0.085 * side, 0.125, 0.0), (0.06 * side, 0.07, -0.06), 0.018, 0.016, 5, S)
    loft(ms, scarf, [[(-0.02 + 0.01 * i, 0.15 - 0.012 * i, 0.06 + 0.07 * i), (0.02 + 0.01 * i, 0.15 - 0.012 * i, 0.06 + 0.07 * i),
                      (0.02 + 0.01 * i, 0.145 - 0.012 * i, 0.06 + 0.07 * i), (-0.02 + 0.01 * i, 0.145 - 0.012 * i, 0.06 + 0.07 * i)]
                     for i in range(6)], S)
    return ms.build(f"Pilot_{root}", coll, parent)


def plane(D, coll):
    rng = random.Random(7)
    root = bpy.data.objects.new(f"Root_{D}", None)
    coll.objects.link(root)
    ms = Mesher()
    brass = mat("brass", "d6ad62", 0.33, 0.85)
    steel = mat("steel", "3b3430", 0.4, 1.0)
    glass = mat("glass", "c9dde0", 0.05, 0.0, coat=1.0)
    if D == "A":
        body = mat("A_wood", "8f5234", 0.32, coat=0.25)
        dark = mat("A_dark", "6b3b28", 0.32, coat=0.25)
        trim = mat("A_trim", "c8643b", 0.32, coat=0.25)
        cloth = mat("A_cloth", "f3ead6", 0.5, coat=0.35)
        stone = mat("A_stone", "6a645c", 0.9)
        stone_edge = mat("A_stone_edge", "8e887e", 0.85)
        metal = mat("A_bronze", "a9783f", 0.35, 1.0)
        leather = mat("A_leather", "5e3522", 0.55, coat=0.3)
        rib = dark
        wheel_tyre, wheel_face = steel, cloth
    elif D == "B":
        body = mat("B_bronze", "7d5a35", 0.38, 1.0)
        dark = mat("B_verdigris", "5f8a7a", 0.7, 0.3)
        trim = mat("B_stone", "b3aa9b", 0.85)
        cloth = mat("B_vellum", "e7dfcd", 0.6, coat=0.15)
        stone = mat("B_basalt", "59534d", 0.9)
        stone_edge = mat("B_stone_edge", "8e887e", 0.85)
        metal = mat("B_brightbronze", "c49a5a", 0.3, 1.0)
        leather = mat("B_leather", "4a3a2c", 0.6)
        rib = metal
        wheel_tyre, wheel_face = stone, trim
    else:
        body = mat("C_oak", "5c3a24", 0.4, coat=0.6)
        dark = mat("C_slate", "414652", 0.55)
        trim = mat("C_red", "a63a2b", 0.45, coat=0.4)
        cloth = mat("C_vellum", "efe3c4", 0.55, coat=0.2)
        stone = mat("C_basalt", "5f5952", 0.9)
        stone_edge = mat("C_stone_edge", "8e887e", 0.85)
        metal = mat("C_bellbronze", "9a6e3a", 0.33, 1.0)
        leather = mat("C_leather", "5e3522", 0.55, coat=0.3)
        blue = mat("C_blue", "3d5873", 0.5, coat=0.3)
        ochre = mat("C_ochre", "c9a24a", 0.4, 0.6)
        rib = body
        wheel_tyre, wheel_face = steel, cloth

    # --- body
    if D == "B":
        # A slimmer bronze hull in riveted bands, pale stone keel and spine.
        hull(ms, body, BODY, 10)
        for z in (-0.3, -0.05, 0.2, 0.45):
            r = [(rz, rx, ry) for rz, rx, ry in BODY]
            rx = interp([(a, b) for a, b, c in BODY], z) + 0.004
            ry = interp([(a, c) for a, b, c in BODY], z) + 0.004
            hull(ms, dark, [(z - 0.012, rx, ry), (z + 0.012, rx, ry)], 10)
        # The spine: a pale stone ridge from the cockpit back to the fin.
        loft(ms, trim, [[(-0.02, interp([(a, c) for a, b, c in BODY], z) - 0.01, z), (0.02, interp([(a, c) for a, b, c in BODY], z) - 0.01, z),
                         (0.012, interp([(a, c) for a, b, c in BODY], z) + 0.012, z), (-0.012, interp([(a, c) for a, b, c in BODY], z) + 0.012, z)]
                        for z in (0.36, 0.45, 0.55, 0.65)])
    elif D == "C":
        hull(ms, body, BODY, 8)
        # Painted bands: red and slate-blue round the body before the tail.
        for z, mm in ((0.38, trim), (0.43, blue)):
            rx = interp([(a, b) for a, b, c in BODY], z) + 0.003
            ry = interp([(a, c) for a, b, c in BODY], z) + 0.003
            hull(ms, mm, [(z - 0.02, rx, ry), (z + 0.02, rx * 0.97, ry * 0.97)], 8)
    else:
        hull(ms, body, BODY, 10)
        hull(ms, trim, [(0.42, 0.104, 0.12), (0.47, 0.097, 0.11)], 10)
        # A patch: a riveted bronze plate over the side, salvaged.
        for side in (-1, 1):
            loft(ms, metal, [[(0.143 * side, -0.03, z), (0.143 * side, 0.06, z), (0.152 * side, 0.06, z), (0.152 * side, -0.03, z)] for z in (0.02, 0.14)])
            for zz in (0.03, 0.13):
                for yy in (-0.02, 0.05):
                    gem(ms, brass, 0.006, T(0.153 * side, yy, zz))

    # --- the cowl
    if D == "A":
        # A rose-window rim of carved basalt round the nose: twelve
        # voussoir blocks with brass bolts, a dark face, the brass spinner.
        hull(ms, trim, [(-0.6, 0.12, 0.12), (-0.55, 0.14, 0.145), (-0.47, 0.143, 0.149), (-0.44, 0.139, 0.146)], 12)
        for i in range(12):
            a0, a1 = math.tau * i / 12 + 0.02, math.tau * (i + 1) / 12 - 0.02
            secs = []
            for a in (a0, a1):
                c, s = math.cos(a), math.sin(a)
                secs.append([(c * 0.098, s * 0.098, -0.64), (c * 0.152, s * 0.152, -0.64), (c * 0.152, s * 0.152, -0.58), (c * 0.11, s * 0.11, -0.565)])
            loft(ms, stone if i % 2 else stone_edge, secs)
            a = (a0 + a1) / 2
            gem(ms, brass, 0.008, T(math.cos(a) * 0.126, math.sin(a) * 0.126, -0.643))
        frustum(ms, steel, 0.1, 0.1, 0.006, 12, T(0, 0, -0.62, rx=math.pi / 2))
    elif D == "B":
        # A rose window for a cowl: a stone rim, twelve tracery spokes in
        # bronze round a petalled stone rose, the spinner its boss.
        hull(ms, body, [(-0.6, 0.118, 0.118), (-0.55, 0.14, 0.145), (-0.47, 0.143, 0.149), (-0.44, 0.139, 0.146)], 12)
        hoop(ms, trim, 0.13, 0.032, 0.05, 24, T(0, 0, -0.615))
        frustum(ms, dark, 0.114, 0.114, 0.006, 12, T(0, 0, -0.608, rx=math.pi / 2))
        for i in range(12):
            a = math.tau * i / 12
            c, s = math.cos(a), math.sin(a)
            tube(ms, metal, (c * 0.05, s * 0.05, -0.622), (c * 0.115, s * 0.115, -0.622), 0.006, 0.006, 4)
            # Trefoil lobes between the spokes, out at the rim.
            a2 = a + math.tau / 24
            gem(ms, trim, 0.016, T(math.cos(a2) * 0.098, math.sin(a2) * 0.098, -0.62, s=(1, 1, 0.5)), 0)
        hoop(ms, metal, 0.05, 0.012, 0.03, 12, T(0, 0, -0.622))
    else:
        # A bronze bell, mouth forward: flaring to a thick lip, a raised
        # band and the crown into the body.
        hull(ms, metal, [(-0.66, 0.0, 0.0), (-0.66, 0.115, 0.115), (-0.645, 0.168, 0.168), (-0.62, 0.17, 0.17), (-0.6, 0.152, 0.152), (-0.54, 0.142, 0.147), (-0.47, 0.142, 0.149), (-0.44, 0.139, 0.146)], 12)
        hull(ms, ochre, [(-0.525, 0.148, 0.152), (-0.51, 0.148, 0.152)], 12)
        frustum(ms, steel, 0.11, 0.11, 0.006, 12, T(0, 0, -0.655, rx=math.pi / 2))
    # Spinner
    hull(ms, brass, [(-0.76, 0.0, 0.0), (-0.73, 0.03, 0.03), (-0.67, 0.052, 0.052), (-0.63, 0.056, 0.056)], 8)
    # Exhaust pipes (A only keeps them; B and C are quieter).
    if D == "A":
        for side in (-1, 1):
            for i in range(3):
                z = -0.56 + 0.045 * i
                tube(ms, steel, (0.12 * side, -0.05, z), (0.168 * side, -0.075, z + 0.03), 0.009, sides=5)
            tube(ms, steel, (0.168 * side, -0.075, -0.53), (0.152 * side, -0.098, -0.22), 0.011, sides=5)

    # --- the cockpit
    hull(ms, dark if D != "B" else stone, [(-0.12, 0.095, 0.06), (0.12, 0.095, 0.06)], 8, T(0, 0.15, 0.22))
    frustum(ms, leather, 0.108, 0.096, 0.03, 12, T(0, 0.2, 0.22, s=(1, 1, 1.3)))
    deck = T(0, 0.17, 0.33, rx=0.2)
    if D == "C":
        # Slate tiles laid down the turtle deck in overlapping rows.
        hull(ms, dark, [(0.0, 0.052, 0.05), (0.1, 0.04, 0.035), (0.27, 0.0, 0.0)], 8, deck)
        for row in range(4):
            z = 0.02 + row * 0.06
            w = lerp(0.05, 0.012, z / 0.27)
            for k in range(-2, 3):
                x = (k + (0.5 if row % 2 else 0)) * w * 0.42
                if abs(x) > w * 0.9:
                    continue
                y = lerp(0.052, 0.0, z / 0.27) * math.sqrt(max(0, 1 - (x / (w + 1e-4)) ** 2)) + 0.004
                box(ms, dark, (w * 0.4, 0.004, 0.05), deck @ T(x, y, z, rx=-0.15))
    else:
        hull(ms, dark if D == "A" else body, [(0.0, 0.052, 0.05), (0.1, 0.04, 0.035), (0.27, 0.0, 0.0)], 8, deck)
    prism(ms, glass, [(0.0, 0.0), (0.005, 0.0), (0.027, 0.068), (0.022, 0.068)], -0.055, 0.055, T(0, 0.2, 0.1))
    for side in (-1, 1):
        tube(ms, brass, (0.056 * side, 0.2, 0.1), (0.056 * side, 0.268, 0.124), 0.004, sides=4)
    tube(ms, brass, (-0.056, 0.268, 0.124), (0.056, 0.268, 0.124), 0.003, sides=4)

    # --- the wings
    up = Wing(SPAN / 2, CHORD, TIP_CHORD, THICK, RIBS, UPPER_Y, STAGGER,
              scallop=0.22 if D == "B" else 0.0)
    lo = Wing(LOWER_SPAN / 2, CHORD, TIP_CHORD, THICK, RIBS, LOWER_Y, 0.0,
              scallop=0.22 if D == "B" else 0.0)
    for w in (up, lo):
        r = w.half * 0.8
        if D == "A":
            w.build(ms, cloth, -r, r)
            w.build(ms, trim, -w.half, -r)
            w.build(ms, trim, r, w.half)
        elif D == "B":
            w.build(ms, cloth)
            # Bronze leading edge and rib caps: the arcade's piers.
            le_pts = []
            for x in w.stations():
                le_, c_, th_, cut_ = w.shape(x)
                le_pts.append((x, w.y + th_ * 0.15, le_ - 0.002))
            strip_z(ms, metal, le_pts, 0.016, 0.012)
            for x in w.rib_x:
                strip(ms, metal, w.top_line(x, 0.0, 1.0, 7, 0.0005), 0.008, 0.004)
        else:
            w.build(ms, cloth)
            # Manuscript bands: red and slate blue near each tip, an ochre
            # rule between, and a red band along the leading edge.
            for side in (-1, 1):
                for (x0, x1), mm in (((0.72, 0.8), trim), ((0.8, 0.83), ochre), ((0.83, 0.9), blue)):
                    xa, xb = x0 * w.half * side, x1 * w.half * side
                    xs = sorted((xa, xb))
                    pts = []
                    for x in (xs[0], xs[1]):
                        le_, c_, th_, cut_ = w.shape(x)
                        pts.append((x, le_ + 0.01))
                    for x in (xs[1], xs[0]):
                        le_, c_, th_, cut_ = w.shape(x)
                        pts.append((x, le_ + c_ - 0.01))
                    w.poly_decal(ms, mm, pts, 0.002)
            for x in w.rib_x:
                strip(ms, body, w.top_line(x, 0.0, 1.0, 7, 0.0005), 0.006, 0.0025)
    if D == "A":
        # Quatrefoils for roundels, and pointed-arch tracery laths in the
        # bays between ribs at the trailing edge (salvaged window tracery).
        for side in (-1, 1):
            x = SPAN * 0.3 * side
            le_, c_, th_, cut_ = up.shape(x)
            z = le_ + c_ * 0.42
            quatrefoil(ms, dark, up, x, z, 0.12, 0.0018)
            quatrefoil(ms, trim, up, x, z, 0.09, 0.0026)
            up.decal(ms, cloth, x, z, 0.02, 0.0034, 10)
        for w in (up,):
            for x in w.rib_x:
                strip(ms, rib, w.top_line(x, 0.0, 1.0, 7, 0.0005), 0.006, 0.003)
            for i in range(len(w.rib_x) - 1):
                x0, x1 = w.rib_x[i], w.rib_x[i + 1]
                if abs((x0 + x1) / 2) < 0.12:
                    continue
                le_, c_, th_, cut_ = w.shape((x0 + x1) / 2)
                base = le_ + c_ * 0.97
                pts = [(x, w.top(x, z) + 0.0006, z) for x, z in pointed_arch(x0, x1, base, c_ * 0.42, 8)]
                strip_z(ms, rib, pts, 0.005, 0.0025)
    if D == "B":
        # A rose on each upper wing for a roundel: stone ring, bronze spokes.
        for side in (-1, 1):
            x = SPAN * 0.3 * side
            le_, c_, th_, cut_ = up.shape(x)
            z = le_ + c_ * 0.4
            up.decal(ms, dark, x, z, 0.06, 0.0018, 16)
            up.decal(ms, cloth, x, z, 0.045, 0.0026, 16)
            for i in range(8):
                a = math.tau * i / 8
                gem(ms, metal, 0.008, T(x + math.cos(a) * 0.03, up.top(x, z) + 0.004, z + math.sin(a) * 0.03), 0)
            up.decal(ms, metal, x, z, 0.012, 0.0034, 8)
    if D == "C":
        for side in (-1, 1):
            x = SPAN * 0.3 * side
            le_, c_, th_, cut_ = up.shape(x)
            z = le_ + c_ * 0.42
            quatrefoil(ms, blue, up, x, z, 0.1, 0.0018)
            up.decal(ms, ochre, x, z, 0.022, 0.003, 10)

    # --- struts, wires, undercarriage
    strut_m = dark if D != "B" else metal
    for side in (-1, 1):
        out = SPAN * 0.34 * side
        for dz in (-0.075, 0.075):
            tube(ms, strut_m, (out, LOWER_Y, dz), (out, UPPER_Y, dz + STAGGER), 0.008, sides=5)
        for dz in (-0.05, 0.05):
            tube(ms, strut_m, (0.09 * side, 0.14, -0.25 + dz), (0.13 * side, UPPER_Y, STAGGER + dz), 0.007, sides=5)
        for dz in (-0.06, 0.06):
            tube(ms, steel, (out, UPPER_Y, STAGGER + dz), (0.15 * side, LOWER_Y, dz), 0.0028, sides=3)
            tube(ms, steel, (out, LOWER_Y, dz), (0.14 * side, UPPER_Y, STAGGER + dz), 0.0028, sides=3)
        tube(ms, strut_m, (0.07 * side, -0.14, -0.38), (0.165 * side, -0.33, -0.28), 0.009, sides=5)
        tube(ms, strut_m, (0.07 * side, -0.14, -0.17), (0.165 * side, -0.33, -0.28), 0.009, sides=5)
        wh = T(0.2 * side, -0.33, -0.28, rz=math.pi / 2)
        if D == "B":
            # Millstones: pale stone discs, a bronze hub, carved spokes.
            frustum(ms, trim, 0.08, 0.08, 0.04, 12, wh)
            for i in range(6):
                a = math.tau * i / 6
                box(ms, stone, (0.008, 0.012, 0.11), wh @ T(0, 0.02 * (1 if side > 0 else -1) * 0 + 0.016, 0, ry=a))
            frustum(ms, metal, 0.02, 0.014, 0.06, 8, wh)
        else:
            frustum(ms, wheel_tyre, 0.08, 0.08, 0.038, 14, wh)
            frustum(ms, wheel_face, 0.058, 0.058, 0.044, 14, wh)
            frustum(ms, brass, 0.02, 0.014, 0.06, 8, wh)
    tube(ms, strut_m, (-0.17, -0.33, -0.28), (0.17, -0.33, -0.28), 0.008, sides=5)
    tube(ms, strut_m, (0.0, -0.03, 0.58), (0.0, -0.11, 0.66), 0.01, sides=5)

    # --- the tail
    tail_y, tail_z = 0.03, 0.58
    if D == "B":
        # A lancet window for a fin: a pointed arch in bronze, its light
        # pale stone, a mullion up the middle.
        arch = [(-0.1, 0.0), (0.1, 0.0), (0.1, 0.16)]
        for i in range(1, 6):
            t = i / 6
            arch.append((lerp(0.1, 0.0, t), 0.16 + 0.12 * math.sin(t * math.pi / 2)))
        prism(ms, metal, arch, -0.007, 0.007, T(0, tail_y, tail_z))
        inner = [(z * 0.82, y * 0.82 + 0.02) for z, y in arch]
        prism(ms, trim, inner, -0.0085, 0.0085, T(0, tail_y, tail_z + 0.005))
        box(ms, metal, (0.019, 0.22, 0.008), T(0, tail_y + 0.12, tail_z + 0.01))
        prism(ms, cloth, [(0.1, -0.04), (0.15, -0.04), (0.165, 0.1), (0.13, 0.2), (0.1, 0.22)], -0.005, 0.005, T(0, tail_y, tail_z))
    elif D == "C":
        # A banner for a fin: red, swallow-tailed, a blue quatrefoil.
        prism(ms, trim, [(-0.1, 0.0), (0.12, 0.0), (0.16, 0.26), (0.11, 0.21), (0.06, 0.27), (-0.03, 0.2)], -0.006, 0.006, T(0, tail_y, tail_z))
        for side in (-1, 1):
            for k in range(4):
                a = math.tau * k / 4 + math.pi / 4
                frustum(ms, blue, 0.02, 0.02, 0.002, 8, T(0.0065 * side, tail_y + 0.12 + math.sin(a) * 0.016, tail_z + 0.03 + math.cos(a) * 0.016, rz=math.pi / 2))
            frustum(ms, ochre, 0.009, 0.009, 0.003, 6, T(0.007 * side, tail_y + 0.12, tail_z + 0.03, rz=math.pi / 2))
    else:
        prism(ms, trim, [(-0.1, 0.0), (0.1, 0.0), (0.1, 0.2), (0.065, 0.24), (0.02, 0.25), (-0.03, 0.2)], -0.006, 0.006, T(0, tail_y, tail_z))
        prism(ms, cloth, [(0.1, -0.04), (0.15, -0.04), (0.165, 0.1), (0.145, 0.19), (0.1, 0.2)], -0.005, 0.005, T(0, tail_y, tail_z))
        # A cream lancet painted on the fin.
        for side in (-1, 1):
            pts = [(0.03, 0.04), (0.07, 0.04), (0.07, 0.13), (0.05, 0.18), (0.03, 0.13)]
            prism(ms, cloth, pts, 0.006 * side, 0.0075 * side, T(0, tail_y, tail_z - 0.04))
    tail = Wing(0.25, 0.13, 0.1, 0.016, 3, tail_y, tail_z + 0.04, scallop=0.15 if D == "B" else 0.0)
    tail.build(ms, cloth)

    # --- the cradle's mount: per direction, standing on the upper wing.
    wing_top = up.top(0.0, CRADLE.z)
    base = Vector((CRADLE.x, wing_top, CRADLE.z))
    pin_y = CRADLE.y - HOOP_R - 0.01  # the hoop's yaw pin, under the hoop
    if D == "A":
        # A salvaged column capital, upside down for a plinth: a square
        # abacus bolted to the wing, an octagonal bell tapering up to the
        # brass pin, a leaf ring of carved stone round it.
        box(ms, stone, (0.11, 0.022, 0.11), T(base.x, base.y + 0.011, base.z))
        box(ms, stone_edge, (0.095, 0.006, 0.095), T(base.x, base.y + 0.025, base.z))
        hull(ms, stone, [(0.0, 0.046, 0.046), (0.03, 0.038, 0.038), (0.055, 0.028, 0.028)], 8, T(base.x, base.y + 0.028, base.z, rx=-math.pi / 2), jitter=0.06, seed=3)
        for i in range(8):
            a = math.tau * (i + 0.5) / 8
            gem(ms, stone_edge, 0.014, T(base.x + math.cos(a) * 0.043, base.y + 0.036, base.z + math.sin(a) * 0.043, s=(1, 1.4, 1)), 0)
        for sx in (-1, 1):
            for sz in (-1, 1):
                gem(ms, brass, 0.006, T(base.x + 0.045 * sx, base.y + 0.023, base.z + 0.045 * sz), 0)
        tube(ms, brass, (base.x, base.y + 0.08, base.z), (base.x, pin_y, base.z), 0.012, 0.009, 8)
        # The horizon ring: a brass armillary circle on two arms, compass
        # notches at the four points.
        H = T(CRADLE.x, CRADLE.y - 0.012, CRADLE.z, rx=math.pi / 2)
        hoop(ms, brass, HOOP_R + 0.024, 0.01, 0.006, 32, H)
        for i in range(4):
            a = math.tau * i / 4
            gem(ms, brass if i else trim, 0.009, T(CRADLE.x + math.cos(a) * (HOOP_R + 0.03), CRADLE.y - 0.012, CRADLE.z + math.sin(a) * (HOOP_R + 0.03)), 0)
        for side in (-1, 1):
            tube(ms, brass, (base.x + 0.035 * side, base.y + 0.075, base.z), (base.x + (HOOP_R + 0.024) * side, CRADLE.y - 0.012, base.z), 0.0045, sides=5)
    elif D == "B":
        # A cone of stone rising from the wing, ringed at the top by a low
        # corona of pointed-arch tracery in bronze; inside it the hoop.
        hull(ms, trim, [(0.0, 0.07, 0.07), (0.02, 0.06, 0.06), (0.07, 0.03, 0.03), (0.09, 0.024, 0.024)], 12, T(base.x, base.y, base.z, rx=-math.pi / 2))
        tube(ms, metal, (base.x, base.y + 0.085, base.z), (base.x, pin_y, base.z), 0.012, 0.009, 8)
        ry = CRADLE.y - 0.03
        R = HOOP_R + 0.03
        hoop(ms, metal, R, 0.01, 0.008, 36, T(CRADLE.x, ry, CRADLE.z, rx=math.pi / 2))
        hoop(ms, metal, R, 0.008, 0.006, 36, T(CRADLE.x, ry + 0.035, CRADLE.z, rx=math.pi / 2))
        for i in range(12):
            a0 = math.tau * i / 12
            a1 = math.tau * (i + 1) / 12
            # A pointed arch from pier to pier round the ring.
            pts = []
            for k in range(7):
                t = k / 6
                a = lerp(a0, a1, t)
                h = 0.03 * math.sin(min(t, 1 - t) * math.pi) ** 0.7
                pts.append((CRADLE.x + math.cos(a) * R, ry + 0.004 + h, CRADLE.z + math.sin(a) * R))
            loft(ms, metal, [[(p[0], p[1] - 0.002, p[2]), (p[0], p[1] + 0.002, p[2]),
                              (p[0] * 0.96, p[1] + 0.002, CRADLE.z + (p[2] - CRADLE.z) * 0.96), (p[0] * 0.96, p[1] - 0.002, CRADLE.z + (p[2] - CRADLE.z) * 0.96)] for p in pts])
            tube(ms, metal, (CRADLE.x + math.cos(a0) * R, ry, CRADLE.z + math.sin(a0) * R), (CRADLE.x + math.cos(a0) * R, ry + 0.035, CRADLE.z + math.sin(a0) * R), 0.003, sides=4)
        for i in range(6):
            a = math.tau * i / 6
            tube(ms, metal, (base.x + math.cos(a) * 0.03, base.y + 0.07, base.z + math.sin(a) * 0.03),
                 (CRADLE.x + math.cos(a) * R, ry, CRADLE.z + math.sin(a) * R), 0.0035, sides=4)
    else:
        # A bell-cote: two slender oak posts on a slate step, a pointed
        # arch over the hoop, a small gable cap; the stone hangs in it.
        box(ms, dark, (0.2, 0.014, 0.07), T(base.x, base.y + 0.007, base.z))
        post_h = CRADLE.y + HOOP_R + 0.02
        for side in (-1, 1):
            x = (HOOP_R + 0.028) * side
            box(ms, body, (0.018, post_h - base.y, 0.03), T(x, (post_h + base.y) / 2, base.z))
            tube(ms, brass, (x, CRADLE.y - 0.0, base.z), (x * 0.82, CRADLE.y, base.z), 0.004, sides=5)
        arch = []
        X = HOOP_R + 0.028
        for k in range(9):
            t = k / 8
            if t <= 0.5:
                s = t * 2
                x = -X + X * s
            else:
                s = (1 - t) * 2
                x = X - X * s
            y = post_h + 0.06 * math.sin(s * math.pi / 2) ** 0.75
            arch.append((x, y, base.z))
        loft(ms, body, [[(p[0], p[1] - 0.007, p[2] - 0.015), (p[0], p[1] + 0.007, p[2] - 0.015),
                         (p[0], p[1] + 0.007, p[2] + 0.015), (p[0], p[1] - 0.007, p[2] + 0.015)] for p in arch])
        # The little cap: red slate gable over the arch's apex.
        prism(ms, trim, [(-0.025, 0.0), (0.025, 0.0), (0.0, 0.028)], -0.03, 0.03, T(0, post_h + 0.05, base.z, ry=math.pi / 2))
        # A yaw pin under the hoop, from a brass boss on the step.
        tube(ms, brass, (base.x, base.y + 0.014, base.z), (base.x, pin_y, base.z), 0.01, 0.008, 8)

    fixed = ms.build(f"Plane_{D}", coll, root)

    # --- the propeller
    prop = bpy.data.objects.new(f"Prop_{D}", None)
    coll.objects.link(prop)
    prop.parent = root
    prop.location = G((0, 0, -0.68))
    pm = Mesher()
    varnish = mat("propwood", "7a4429", 0.3, coat=0.9)
    tip_m = brass if D != "B" else metal
    for turn in (0.0, math.pi):
        lay = T(rz=turn) @ T(ry=0.32) @ T(rx=-math.pi / 2)
        hull(pm, varnish, [(0.0, 0.012, 0.009), (0.04, 0.026, 0.008), (0.16, 0.024, 0.006), (0.235, 0.017, 0.005)], 6, lay)
        hull(pm, tip_m, [(0.232, 0.0175, 0.0055), (0.262, 0.012, 0.0045), (0.27, 0.004, 0.003)], 6, lay)
    for ob in pm.build(f"PropMesh_{D}", coll, prop):
        ob.location = (0, 0, 0)

    cradle(D, coll, root, metal if D != "A" else brass, trim)
    pilot(coll, root, D)
    return root


def cradle(D, coll, root, metal, accent):
    """The gimbal: a hoop standing across the wing (seen face-on from
    behind, a ring round the stone), turning about the wing's up axis on the
    mount's pin; the stone between its two pins, tipping up and down. Two
    claws on each pin hold the stone's waist; the hoop carries a pointer
    notch at its top so even the empty cradle shows which way it rests."""
    brass = MATS["brass"]
    hoop_ob = bpy.data.objects.new(f"Hoop_{D}", None)
    coll.objects.link(hoop_ob)
    hoop_ob.parent = root
    hoop_ob.location = G(CRADLE)
    hm = Mesher()
    hoop(hm, metal, HOOP_R, 0.012, 0.014, 28)
    # Bottom yaw pin cup, side pins, claws, and a crown pointer on top.
    frustum(hm, metal, 0.012, 0.016, 0.014, 8, T(0, -HOOP_R - 0.008, 0))
    for side in (-1, 1):
        tube(hm, metal, (side * (HOOP_R - 0.004), 0, 0), (side * (HOOP_R + 0.012), 0, 0), 0.009, 0.007, 8)
    gem(hm, accent if D != "B" else MATS["B_stone"], 0.011, T(0, HOOP_R + 0.008, 0, s=(0.8, 1.4, 0.8)), 0)
    # Fine inner ring of the hoop: a gothic touch, cusps inward (A, B) or
    # bell-ropes (C) kept small so the ring stays clean.
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        if abs(math.cos(a)) > 0.9:
            continue
        gem(hm, metal, 0.006, T(math.cos(a) * (HOOP_R - 0.009), math.sin(a) * (HOOP_R - 0.009), 0, s=(1, 1, 0.6)), 0)
    hm.build(f"HoopMesh_{D}", coll, hoop_ob)
    # The pin sockets: a brass cup on each pin, open toward the middle,
    # where the stone's collar clicks in.
    sm0 = Mesher()
    for side in (-1, 1):
        tube(sm0, brass, (side * (HOOP_R - 0.004), 0, 0), (side * (HOOP_R - 0.022), 0, 0), 0.007, 0.012, 8)
    sm0.build(f"Sockets_{D}", coll, hoop_ob)

    # The stone: a dark lodestone spindle, hand-hewn (jittered facets), a
    # bright tip forward, glowing seams in two bands and a soft halo.
    st = bpy.data.objects.new(f"Stone_{D}", None)
    coll.objects.link(st)
    st.parent = hoop_ob
    sm = Mesher()
    rock = mat("lodestone", "1e1c1b", 0.6, emit="ffd99a", emit_strength=0.12)
    seam = mat("lodestone_seam", "e8c27a", 0.5, emit="ffd896", emit_strength=2.2)
    tipm = mat("lodestone_tip", "f0d49a", 0.4, emit="ffe4b8", emit_strength=3.5)
    L = STONE_LEN
    rng = random.Random(11)
    rings_ = [(L * 0.42, 0.011, 0.011), (L * 0.3, 0.025, 0.023), (L * 0.08, 0.034, 0.031),
              (-L * 0.14, 0.03, 0.028), (-L * 0.3, 0.016, 0.015)]
    sections = [ring(z, rx, ry, 6, jitter=0.12, rng=rng, phase=0.5 + 0.08 * i) for i, (z, rx, ry) in enumerate(rings_)]
    loft(sm, rock, sections)
    # The tip: a glowing point forward.
    loft(sm, tipm, [sections[-1], ring(-L * 0.5, 0.0005, 0.0005, 6)])
    # Seams: thin bright bands round the waist.
    for z, r in ((L * 0.06, 0.039), (-L * 0.2, 0.03)):
        loft(sm, seam, [ring(z - 0.006, r, r * 0.93, 6), ring(z + 0.006, r, r * 0.93, 6)])
    sm.build(f"StoneMesh_{D}", coll, st)
    # Its collar: a brass band round the waist with two stub trunnions that
    # sit in the hoop's sockets; it tips with the stone.
    cm = Mesher()
    hoop(cm, brass, 0.036, 0.006, 0.012, 6, T(rz=0.0) @ Matrix.Rotation(0.0, 4, "X"))
    for side in (-1, 1):
        tube(cm, brass, (side * 0.033, 0, 0), (side * (HOOP_R - 0.02), 0, 0), 0.006, 0.005, 6)
    cm.build(f"Collar_{D}", coll, st)

    glow = bpy.data.objects.new(f"Glow_{D}", None)
    coll.objects.link(glow)
    glow.parent = st
    gm = Mesher()
    halo = soft_mat("halo", "ffe2a8", 1.0, power=3.0, alpha=0.3)
    b = gm.bm(halo)
    bmesh.ops.create_uvsphere(b, u_segments=24, v_segments=14, radius=0.1, matrix=C @ T(0, 0, -0.02, s=(1, 1, 1.3)))
    gm.build(f"Halo_{D}", coll, glow, smooth=True)
    # Wisps: two twisting ribbons streaming from the tip toward the target.
    wisp = soft_mat("wisp", "fff0d0", 1.0, power=1.3, alpha=0.9, along=True)
    for k, ph in enumerate((0.0, math.pi / 2)):
        me = bpy.data.meshes.new(f"Wisp_{D}_{k}")
        wb = bmesh.new()
        uvl = wb.loops.layers.uv.new()
        n = 24
        length = 1.1
        left, right = [], []
        for i in range(n + 1):
            t = i / n
            z = -L * 0.5 - t * length
            cx = math.sin(t * 7.0 + ph) * 0.03 * t
            cy = math.cos(t * 7.0 + ph) * 0.03 * t
            w = 0.007 * (1 - t) ** 0.5 * min(1.0, t * 8 + 0.3) + 0.0015
            ax = (math.cos(ph + t * 2.0), math.sin(ph + t * 2.0))
            left.append(wb.verts.new(G((cx - ax[0] * w, cy - ax[1] * w, z))))
            right.append(wb.verts.new(G((cx + ax[0] * w, cy + ax[1] * w, z))))
        for i in range(n):
            f = wb.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
            for lp, uv in zip(f.loops, ((i / n, 0), (i / n, 1), ((i + 1) / n, 1), ((i + 1) / n, 0))):
                lp[uvl].uv = uv
        wb.to_mesh(me)
        wb.free()
        me.materials.append(wisp)
        for p in me.polygons:
            p.use_smooth = True
        ob = bpy.data.objects.new(f"Wisp_{D}_{k}", me)
        coll.objects.link(ob)
        ob.parent = glow
        ob.visible_shadow = False
    for ob in glow.children:
        ob.visible_shadow = False
    light = bpy.data.lights.new(f"StoneLight_{D}", "POINT")
    light.energy = 1.2
    light.color = srgb("ffe2a8")
    light.shadow_soft_size = 0.03
    lo = bpy.data.objects.new(f"StoneLight_{D}", light)
    coll.objects.link(lo)
    lo.parent = st


# ------------------------------------------------------------- the ruin
def ruin(coll):
    """The sky island the ruin vignette stands on: a grass top over a
    faceted rock keel. The ruin itself is the game's own kit
    (scripts/ruin_kit.gd), exported by ruin_export.gd and imported by
    plane_render.py, so the planes are judged beside the real stone."""
    rng = random.Random(4)
    root = bpy.data.objects.new("Root_Ruin", None)
    coll.objects.link(root)
    ms = Mesher()
    grass = mat("ruin_grass", "56693a", 0.95)
    rock = mat("ruin_rock", "4a4540", 0.95)
    top = ring(0, 19.0, 15.0, 13, jitter=0.1, rng=rng)
    pts = [(x, 0.0, y + 4.0) for x, y, _ in top]
    keel = []
    for depth, k in ((-0.8, 1.0), (-4.0, 0.82), (-9.0, 0.55), (-14.0, 0.3), (-18.0, 0.05)):
        keel.append([(x * k * rng.uniform(0.9, 1.1), depth + rng.uniform(-0.6, 0.6), 4.0 + (z - 4.0) * k * rng.uniform(0.9, 1.1)) for x, _, z in pts])
    loft(ms, rock, keel)
    loft(ms, grass, [[(x, -0.8, z) for x, _, z in pts], [(x, -0.05, z) for x, _, z in pts]])
    ms.build("Island", coll, root)
    return root


# ------------------------------------------------------------- build all
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for D in ("A", "B", "C"):
        coll = bpy.data.collections.new(f"Plane_{D}")
        scene.collection.children.link(coll)
        plane(D, coll)
    rc = bpy.data.collections.new("Ruin")
    scene.collection.children.link(rc)
    ruin(rc)
    # Tri counts (pilot left out; glow and wisps counted apart).
    for D in ("A", "B", "C"):
        tris = {"plane": 0, "cradle": 0, "stone": 0, "glow": 0, "pilot": 0}
        for ob in bpy.data.collections[f"Plane_{D}"].objects:
            if ob.type != "MESH":
                continue
            n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            name = ob.name
            if name.startswith("Pilot"):
                tris["pilot"] += n
            elif name.startswith(("Halo", "Wisp")):
                tris["glow"] += n
            elif name.startswith("StoneMesh"):
                tris["stone"] += n
            elif name.startswith(("HoopMesh", "Sockets", "Collar")):
                tris["cradle"] += n
            else:
                tris["plane"] += n
        print(f"PLANE_TRIS {D} {tris}")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print("saved", BLEND)


if __name__ == "__main__":
    main()
