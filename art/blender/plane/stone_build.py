"""Concept models for the stone plane (round 2, docs/design/plane-stone.md):
an ancient sky-builders' craft carved from the ruins' weathered basalt. No
engine, no propeller: a lodestone heart is why it flies. Wings and hull are
carved slabs held apart by thin glowing gaps; a carved rune ring floats at
the nose where the propeller was. The wing seams are the compass.

Concept only: nothing here is exported to the game. Saves the three
variants, a stand-in pilot each (plane_build.pilot) and the ruin island
(plane_build.ruin) to art/blender/plane/stone.blend; stone_render.py renders.

    /opt/homebrew/bin/blender -b --python art/blender/plane/stone_build.py

Variants, most plane-like to strangest:
  A  Swift    a monoplane, an ancient glider: long tapering shoulder wing in
              three slabs a side, a slim hull in five floating pieces, a
              cruciform tail (dorsal and ventral fins).
  B  Lintel   a biplane as a sundered gateway: the upper wing a lintel, the
              lower a threshold, no struts; a broken column stub hangs from
              the lintel over one rising from the threshold, a gap of light
              between them. A lancet fin.
  C  Feather  the strangest: five stone feathers a side fanned like a gliding
              bird's primaries, a hull of floating vertebrae, a ring tail in
              four arcs.

Conventions as plane_build.py: 1 unit = 1 m, written in the game's frame
(Y up, nose to -Z, right +X) and turned into Blender's by `G`.

Objects per variant (collection Stone_<D>): Root_<D> (pose by it); stone
parts joined per material; compass seams split by channel (Seam_<D>_<ch>
cores, Band_<D>_<ch> soft camera-facing ribbons); Ring_<D> (the rune ring,
spins about the flight axis) with RingBlur_<D>; Chamber_<D> (heart stone,
halo, light) with Needle_<D> (aim it: rotation (pitch, 0, yaw)); Wisp_<D>
(optional, aim like the needle); Seat_<D> with the pilot stand-in.

Channels (materials core_<ch> and band_<ch>, set by stone_render.compass):
  L, R  left and right wing seams (turn toward the brighter)
  UP    dorsal fin seam (A, B) or the ring tail's top arc (C)
  DN    ventral fin seam (A, B) or the ring tail's bottom arc (C)
  BK    tailplane seams: the target is behind
  RING  the nose ring's glyphs (flare when on course)
  GAP   the lodestone's pull between the slabs (steady while seated)
"""
import importlib.util
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("plane_build", HERE / "plane_build.py")
pb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pb)
G, T, C, srgb = pb.G, pb.T, pb.C, pb.srgb
Mesher, loft, hull, ring, tube, box, gem, hoop, frustum = (
    pb.Mesher, pb.loft, pb.hull, pb.ring, pb.tube, pb.box, pb.gem, pb.hoop, pb.frustum)
mat, soft_mat, lerp = pb.mat, pb.soft_mat, pb.lerp

BLEND = HERE / "stone.blend"
MIRROR = Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0))
CHANNELS = ("L", "R", "UP", "DN", "BK", "RING", "GAP")
GLOW = "ffd896"     # pale gold
GLOW_WHITE = "fff0d6"  # warm white
STONE = "59534d"    # scripts/ruin_kit.gd STONE
EDGE = "8e887e"     # ruin_kit.gd EDGE (worn edges)
LICHEN = "8e9180"


# ------------------------------------------------------------- materials
def basalt():
    """The ruins' basalt, coloured face by face as the kit does (worn tops
    toward EDGE, the odd lichen face), from a corner colour attribute."""
    if "basalt" in pb.MATS:
        return pb.MATS["basalt"]
    m = bpy.data.materials.new("basalt")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.82
    m.diffuse_color = (*srgb(STONE), 1)
    pb.MATS["basalt"] = m
    return m


def core(ch):
    """A seam's carved channel: dark gold stone that glows (Emission
    Strength is the channel's level, set by the render)."""
    col = GLOW_WHITE if ch in ("GAP",) else GLOW
    if f"core_{ch}" in pb.MATS:
        return pb.MATS[f"core_{ch}"]
    m = mat(f"core_{ch}", "6b5a3a", 0.5, emit=col, emit_strength=1.0)
    m.node_tree.nodes["Principled BSDF"].name = "core"
    return m


def band(ch):
    """A soft ribbon beside a seam, facing the chase camera: fades across
    (v) and toward its ends (u). It stands in for the game's glow at a
    distance; its strength (node glow_k) scales with the eye's distance."""
    name = f"band_{ch}"
    if name in pb.MATS:
        return pb.MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*srgb(GLOW_WHITE if ch == "GAP" else "ffe2a8"), 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    uv = nt.nodes.new("ShaderNodeUVMap")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])

    def node(op, a=None, b=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                nt.links.new(v, n.inputs[i])
        return n.outputs[0]
    # across: (1 - |2v - 1|)^1.6 ; ends: min(1, 5u, 5(1-u))
    v2 = node("MULTIPLY_ADD", sep.outputs["Y"], 2.0)
    v2.node.inputs[2].default_value = -1.0
    across = node("POWER", node("SUBTRACT", 1.0, node("ABSOLUTE", v2)), 1.6)
    ends = node("MINIMUM", node("MINIMUM", node("MULTIPLY", sep.outputs["X"], 5.0),
                                node("MULTIPLY", node("SUBTRACT", 1.0, sep.outputs["X"]), 5.0)), 1.0)
    fac = node("MULTIPLY", across, ends)
    k = nt.nodes.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.name = "glow_k"
    k.inputs[1].default_value = 1.0
    nt.links.new(fac, k.inputs[0])
    nt.links.new(k.outputs[0], em.inputs["Strength"])
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs[0])
    pb.MATS[name] = m
    return m


def colour_stone(objs, seed):
    """Per-face colours on the basalt objects, as ruin_kit.gd's `_face`."""
    rng = random.Random(seed)
    base = Vector(srgb(STONE))
    edge = Vector(srgb(EDGE))
    lich = Vector(srgb(LICHEN))
    for ob in objs:
        if not ob.data.materials or ob.data.materials[0].name != "basalt":
            continue
        me = ob.data
        attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        for p in me.polygons:
            up = p.normal.z
            c = base.lerp(edge, max(0.0, up) * 0.55 * rng.uniform(0.5, 1.3) + rng.uniform(0.0, 0.2))
            if rng.random() < 0.08 and up > 0.2:
                c = c.lerp(lich, rng.uniform(0.25, 0.45))
            if up < -0.4:
                c = c * 0.78
            c = c * rng.uniform(0.84, 1.12)
            for li in p.loop_indices:
                attr.data[li].color = (c.x, c.y, c.z, 1.0)


# ------------------------------------------------------------- ribbons
class Ribbons:
    """Soft camera-facing ribbons gathered per channel (with UVs)."""

    def __init__(self):
        self.parts = {}

    def add(self, ch, pts, across, width):
        """`pts` in the game frame, `across` the ribbon's width direction."""
        self.parts.setdefault(ch, []).append((pts, across, width))

    def build(self, D, coll, parent):
        objs = []
        for ch, items in self.parts.items():
            me = bpy.data.meshes.new(f"Band_{D}_{ch}")
            b = bmesh.new()
            uvl = b.loops.layers.uv.new()
            for pts, across, width in items:
                n = len(pts)
                acr = across if isinstance(across, list) else [across] * n
                acr = [Vector(a).normalized() * width / 2 for a in acr]
                lo = [b.verts.new(G(Vector(p) - a)) for p, a in zip(pts, acr)]
                hi = [b.verts.new(G(Vector(p) + a)) for p, a in zip(pts, acr)]
                for i in range(n - 1):
                    f = b.faces.new((lo[i], lo[i + 1], hi[i + 1], hi[i]))
                    for lp, uv in zip(f.loops, ((i / (n - 1), 0), ((i + 1) / (n - 1), 0),
                                                ((i + 1) / (n - 1), 1), (i / (n - 1), 1))):
                        lp[uvl].uv = uv
            b.to_mesh(me)
            b.free()
            me.materials.append(band(ch))
            ob = bpy.data.objects.new(f"Band_{D}_{ch}", me)
            ob.visible_shadow = False
            coll.objects.link(ob)
            ob.parent = parent
            objs.append(ob)
        return objs


# ------------------------------------------------------------- slabs
def section(x, y, le, c, th):
    """A faceted slab's section: blunt leading edge, a flat-ish carved top,
    a blunt trailing edge (its rear face carries the seam), a keel line."""
    return [(x, y, le), (x, y + th * 0.85, le + 0.16 * c), (x, y + th * 0.7, le + 0.6 * c),
            (x, y + th * 0.28, le + c), (x, y - th * 0.12, le + c), (x, y - th * 0.42, le + 0.32 * c)]


def slab(ms, rb, xs, sec, M, ch, glyph=True, te=True, band_w=0.05, glyph_u=0.42, seed=0):
    """A wing-like slab between xs[0] and xs[-1] (stations), `sec(x)` its
    (y, le, chord, thick); M places it. `ch` is the seam's channel: a glyph
    channel on top and a glowing band on the rear face, plus a soft ribbon
    behind the rear face for reading at a distance."""
    stone = basalt()
    cm = core(ch) if ch else None
    rng = random.Random(seed)
    secs = []
    for i, x in enumerate(xs):
        y, le, c, th = sec(x)
        if i in (0, len(xs) - 1):
            # The cut ends: hewn, a little off square.
            le += rng.uniform(-0.004, 0.004)
        secs.append(section(x, y, le, c, th))
    loft(ms, stone, secs, M)
    if not ch:
        return
    if te:
        # The rear face's carved band.
        bsecs = []
        for x in xs:
            y, le, c, th = sec(x)
            z = le + c + 0.0012
            bsecs.append([(x, y - th * 0.05, z), (x, y + th * 0.21, z), (x, y + th * 0.21, z + 0.003), (x, y - th * 0.05, z + 0.003)])
        loft(ms, cm, bsecs, M)
        if band_w:
            pts = []
            for x in xs:
                y, le, c, th = sec(x)
                pts.append(M @ Vector((x, y + th * 0.08, le + c + 0.006)))
            across = M.to_3x3() @ Vector((0, 1, 0))
            rb.add(ch, pts, across, band_w)
    if not te and band_w:
        pts = []
        for x in xs:
            y, le, c, th = sec(x)
            pts.append(M @ Vector((x, y + th * 0.76 + 0.01, le + glyph_u * c)))
        rb.add(ch, pts, M.to_3x3() @ Vector((0, 1, 0)), band_w)
    if glyph:
        # The glyph channel on top: runs of carved strokes with breaks, a
        # short cross-stroke every other run.
        x0, x1 = xs[0], xs[-1]
        span = abs(x1 - x0)
        n = max(1, int(span / 0.06))
        step = (x1 - x0) / n
        for k in range(n):
            a = x0 + step * (k + 0.12)
            b = x0 + step * (k + 0.88)
            run = []
            for x in (a, (a + b) / 2, b):
                y, le, c, th = sec(x)
                yt = y + th * 0.76 + 0.0008
                z = le + glyph_u * c
                w = 0.006 + 0.004 * (c / 0.25)
                run.append([(x, yt - 0.002, z - w), (x, yt - 0.002, z + w), (x, yt + 0.0015, z + w), (x, yt + 0.0015, z - w)])
            loft(ms, cm, run, M)
            if k < n - 1:
                # A carved dot in the break (dash, dot, dash: runes, not
                # crosses; crosses read as military marks).
                xm = x0 + step * (k + 1)
                y, le, c, th = sec(xm)
                gem(ms, cm, 0.0045, M @ T(xm, y + th * 0.76 + 0.0005, le + glyph_u * c, s=(1.0, 0.45, 1.0)), 0)


def gap_plate(ms, x, sec, M, w=0.004):
    """The light in a gap between two slabs: a thin glowing plate, inset."""
    y, le, c, th = sec(x)
    s = section(0, y, le, c, th)
    cy = sum(p[1] for p in s) / 6
    cz = sum(p[2] for p in s) / 6
    k = 0.82
    loft(ms, core("GAP"), [[(xx, cy + (p[1] - cy) * k, cz + (p[2] - cz) * k) for p in s] for xx in (x - w, x + w)], M)


def wing(ms, rb, slabs, sec, ch, M=Matrix(), per=4, band_w=0.05, glyph=True, seed=0, gaps=True, te=True, glyph_u=0.42):
    """Slabs [(x0, x1), ...] along a span; a gap plate between neighbours."""
    for i, (x0, x1) in enumerate(slabs):
        xs = [lerp(x0, x1, k / per) for k in range(per + 1)]
        slab(ms, rb, xs, sec, M, ch, glyph=glyph, te=te, band_w=band_w, glyph_u=glyph_u, seed=seed + i)
    if gaps:
        for (a0, a1), (b0, b1) in zip(slabs, slabs[1:]):
            gap_plate(ms, (a1 + b0) / 2, sec, M)


def keel_section(z, hw, top, bot, rng=None, j=0.0):
    """A carved hull's section: a flat deck, chined sides, a sharp keel
    (a sky-boat's, not a tube's)."""
    pts = [(-0.55 * hw, top), (0.55 * hw, top), (hw, 0.3 * top), (0.6 * hw, 0.55 * bot),
           (0.0, bot), (-0.6 * hw, 0.55 * bot), (-hw, 0.3 * top)]
    if rng:
        pts = [(x * (1 + rng.uniform(-j, j)), y * (1 + rng.uniform(-j, j))) for x, y in pts]
    return [(x, y, z) for x, y in pts]


SLANT = 0.3  # the hull's cuts lean back with height (z += SLANT * y): broken, not sawn


def keel(ms, prof, seed=1, j=0.04, M=Matrix(), m=None, cut=(True, True)):
    """A hull piece lofted through keel sections (z, half width, deck, keel);
    `cut` slants its first and last ends like a break."""
    rng = random.Random(seed)
    secs = [keel_section(z, max(hw, 1e-4), top, bot, rng, j) for z, hw, top, bot in prof]
    for i, flag in ((0, cut[0]), (-1, cut[1])):
        if flag:
            secs[i] = [(x, y, z + SLANT * y) for x, y, z in secs[i]]
    loft(ms, m or basalt(), secs, M)


def keel_gap(ms, z, hw, top, bot):
    loft(ms, core("GAP"), [[(x, y, zz + SLANT * y) for x, y, zz in keel_section(zz0, hw * 0.8, top * 0.8, bot * 0.8)]
                           for zz0 in (z - 0.004, z + 0.004)])


def keel_trough(ms, z0, z1, hw, top, bot, wall=0.022):
    """The heart chamber: a keel piece open over the top, a U of stone."""
    outer = [(hw, 0.3 * top), (0.6 * hw, 0.55 * bot), (0.0, bot), (-0.6 * hw, 0.55 * bot), (-hw, 0.3 * top)]
    outer = [(hw * 0.9, top * 0.85)] + outer + [(-hw * 0.9, top * 0.85)]
    inner = []
    for x, y in reversed(outer):
        inner.append((x - math.copysign(wall, x) if abs(x) > wall else 0.0, max(y + wall * 1.1, bot + wall * 1.4) if y < 0 else y))
    poly = outer + inner
    loft(ms, basalt(), [[(x, y, z + SLANT * y) for x, y in poly] for z in (z0, z1)])


def hull_piece(ms, rings_, sides=8, jitter=0.06, seed=1, M=Matrix()):
    hull(ms, basalt(), rings_, sides, M, jitter=jitter, seed=seed)


def hull_gap(ms, z, rx, ry, sides=8):
    hull(ms, core("GAP"), [(z - 0.004, rx * 0.8, ry * 0.8), (z + 0.004, rx * 0.8, ry * 0.8)], sides)


def trough(ms, z0, z1, rx, ry, rim=0.3, wall=0.24, M=Matrix()):
    """An open-topped stone trough (the heart chamber): a U of the hull's
    section, open over the top."""
    n = 9
    out = []
    a0, a1 = math.pi - rim, math.tau + rim
    for i in range(n):
        a = a0 + (a1 - a0) * i / (n - 1)
        out.append((math.cos(a) * rx, math.sin(a) * ry))
    inn = [(x * (1 - wall), y * (1 - wall) + 0.006) for x, y in reversed(out)]
    poly = out + inn
    loft(ms, basalt(), [[(x, y, z) for x, y in poly] for z in (z0, z1)], M)


def rune_ring(D, coll, root, z, r, wide=0.03, deep=0.026):
    """The rune ring at the nose, where the propeller was: a carved basalt
    ring with glyphs on both faces, floating ahead of the nose. Ring_<D>
    spins about the flight axis; RingBlur_<D> (a soft annulus) shows its
    speed."""
    rob = bpy.data.objects.new(f"Ring_{D}", None)
    coll.objects.link(rob)
    rob.parent = root
    rob.location = G((0, 0, z))
    ms = Mesher()
    rng = random.Random(3)
    # Eight voussoirs, each slightly hewn, joined tight (it spins as one).
    for i in range(8):
        a0, a1 = math.tau * i / 8 + 0.008, math.tau * (i + 1) / 8 - 0.008
        secs = []
        for a in [lerp(a0, a1, k / 4) for k in range(5)]:
            cc, ss = math.cos(a), math.sin(a)
            j = 1 + rng.uniform(-0.03, 0.03)
            ri, ro = r - wide / 2, r + wide / 2 * j
            secs.append([(cc * ri, ss * ri, -deep / 2), (cc * ro, ss * ro, -deep / 2 * 0.8),
                         (cc * ro, ss * ro, deep / 2 * 0.8), (cc * ri, ss * ri, deep / 2)])
        loft(ms, basalt(), secs)
    # Glyphs on both faces: a bar, then a pair of dots, round the ring.
    g = core("RING")
    for i in range(12):
        a = math.tau * (i + 0.5) / 12
        for face in (-1, 1):
            fz = face * (deep / 2 + 0.0008)
            if i % 2 == 0:
                box(ms, g, (0.016, 0.005, 0.002), T(math.cos(a) * r, math.sin(a) * r, fz, rz=a))
            else:
                for d in (-0.005, 0.005):
                    box(ms, g, (0.005, 0.005, 0.002), T(math.cos(a) * (r + d), math.sin(a) * (r + d), fz, rz=a))
    objs = ms.build(f"RingMesh_{D}", coll, rob)
    colour_stone(objs, 5)
    # The blur: a soft annulus over the ring's sweep (not spinning).
    rb = Ribbons()
    pts = []
    n = 40
    for i in range(n + 1):
        a = math.tau * i / n
        pts.append(((math.cos(a) * r, math.sin(a) * r, z)))
    # A ring ribbon: across is radial, so build it by hand.
    me = bpy.data.meshes.new(f"RingBlur_{D}")
    b = bmesh.new()
    uvl = b.loops.layers.uv.new()
    lo, hi = [], []
    for i in range(n + 1):
        a = math.tau * i / n
        cc, ss = math.cos(a), math.sin(a)
        lo.append(b.verts.new(G((cc * (r - wide), ss * (r - wide), z - 0.016))))
        hi.append(b.verts.new(G((cc * (r + wide), ss * (r + wide), z - 0.016))))
    for i in range(n):
        f = b.faces.new((lo[i], lo[i + 1], hi[i + 1], hi[i]))
        # u runs half-way round twice so the ends' fade sits nowhere: keep
        # u in the middle (0.5) for an even ring.
        for lp, uv in zip(f.loops, ((0.5, 0), (0.5, 0), (0.5, 1), (0.5, 1))):
            lp[uvl].uv = uv
    b.to_mesh(me)
    b.free()
    blur = mat_ring_blur()
    me.materials.append(blur)
    ob = bpy.data.objects.new(f"RingBlur_{D}", me)
    ob.visible_shadow = False
    coll.objects.link(ob)
    ob.parent = root
    return rob


def mat_ring_blur():
    if "ring_blur" in pb.MATS:
        return pb.MATS["ring_blur"]
    m = band("RING").copy()
    m.name = "ring_blur"
    pb.MATS["ring_blur"] = m
    return m


def heart_and_needle(D, coll, root, at, needle_up=0.07, needle_len=0.13):
    """The heart chamber's contents: the lodestone (a hewn dark stone with
    gold seams and a warm core) hovering in the trough, and over it the
    needle, a slim double-ended basalt spindle with a glowing north tip,
    floating free and turning to the target (Needle_<D>)."""
    ch = bpy.data.objects.new(f"Chamber_{D}", None)
    coll.objects.link(ch)
    ch.parent = root
    ch.location = G(at)
    ms = Mesher()
    rock = mat("lodestone", "1e1c1b", 0.6, emit="ffd99a", emit_strength=0.12)
    seam = mat("lodestone_seam", "e8c27a", 0.5, emit="ffd896", emit_strength=2.2)
    rng = random.Random(9)
    b = ms.bm(rock)
    res = bmesh.ops.create_icosphere(b, subdivisions=1, radius=0.034, matrix=C @ T(s=(1.0, 0.85, 1.15)))
    for v in res["verts"]:
        v.co *= rng.uniform(0.86, 1.12)
    for z, r in ((-0.006, 0.033), (0.014, 0.029)):
        loft(ms, seam, [ring(z - 0.003, r, r * 0.85, 7), ring(z + 0.003, r, r * 0.85, 7)], T(rx=0.3))
    ms.build(f"Heart_{D}", coll, ch)
    gm = Mesher()
    halo = soft_mat("halo", "ffe2a8", 1.0, power=3.0, alpha=0.3)
    hb = gm.bm(halo)
    bmesh.ops.create_uvsphere(hb, u_segments=20, v_segments=12, radius=0.06, matrix=C)
    for ob in gm.build(f"HeartHalo_{D}", coll, ch, smooth=True):
        ob.visible_shadow = False
    light = bpy.data.lights.new(f"HeartLight_{D}", "POINT")
    light.energy = 0.6
    light.color = srgb("ffe2a8")
    light.shadow_soft_size = 0.02
    lo = bpy.data.objects.new(f"HeartLight_{D}", light)
    coll.objects.link(lo)
    lo.parent = ch
    lo.location = G((0, 0.01, 0))

    nd = bpy.data.objects.new(f"Needle_{D}", None)
    coll.objects.link(nd)
    nd.parent = ch
    nd.location = G((0, needle_up, 0))
    nm = Mesher()
    L = needle_len
    needle = mat("needle", "2a2725", 0.45)
    tip = mat("needle_tip", "f0d49a", 0.4, emit="ffe4b8", emit_strength=4.0)
    # A four-sided spindle (diamond section), long axis along -Z (north).
    secs = [ring(z, r, r * 0.7, 4, phase=0.0) for z, r in ((L * 0.5, 0.0008), (L * 0.18, 0.0075), (0.0, 0.0105), (-L * 0.18, 0.0075))]
    loft(nm, needle, secs)
    loft(nm, tip, [secs[-1], ring(-L * 0.5, 0.0006, 0.0006, 4, phase=0.0)])
    # A gold band at the balance point.
    loft(nm, seam, [ring(-0.003, 0.0118, 0.0083, 4, phase=0.0), ring(0.003, 0.0118, 0.0083, 4, phase=0.0)])
    nm.build(f"NeedleMesh_{D}", coll, nd)
    return ch


def wisp(D, coll, root, at, length=1.8):
    """The optional wisp: a thin twisting ribbon from the nose toward the
    target (Wisp_<D>, aimed like the needle)."""
    wob = bpy.data.objects.new(f"Wisp_{D}", None)
    coll.objects.link(wob)
    wob.parent = root
    wob.location = G(at)
    w = soft_mat("wisp", "fff0d0", 1.0, power=1.3, alpha=0.9, along=True)
    me = bpy.data.meshes.new(f"WispMesh_{D}")
    b = bmesh.new()
    uvl = b.loops.layers.uv.new()
    n = 28
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        z = -t * length
        cx = math.sin(t * 6.0) * 0.05 * t
        cy = math.cos(t * 6.0) * 0.03 * t
        hw = 0.012 * (1 - t) ** 0.5 * min(1.0, t * 8 + 0.3) + 0.002
        left.append(b.verts.new(G((cx - hw, cy, z))))
        right.append(b.verts.new(G((cx + hw, cy, z))))
    for i in range(n):
        f = b.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
        for lp, uv in zip(f.loops, ((i / n, 0), (i / n, 1), ((i + 1) / n, 1), ((i + 1) / n, 0))):
            lp[uvl].uv = uv
    b.to_mesh(me)
    b.free()
    me.materials.append(w)
    ob = bpy.data.objects.new(f"WispMesh_{D}", me)
    ob.visible_shadow = False
    coll.objects.link(ob)
    ob.parent = wob
    return wob


def seat_pilot(D, coll, root, dy, dz):
    """plane_build's stand-in pilot (head, scarf, arms), lowered into the
    cockpit so only the head and a little scarf show."""
    seat = bpy.data.objects.new(f"Seat_{D}", None)
    coll.objects.link(seat)
    seat.parent = root
    seat.location = G((0, dy, dz))
    pb.pilot(coll, seat, D)
    return seat


def cockpit_rim(ms, y, z, rx=0.085, rz=0.1):
    """A carved stone coaming round the pilot's head."""
    secs = []
    n = 12
    for i in range(n + 1):
        a = math.tau * i / n
        cc, ss = math.cos(a), math.sin(a)
        secs.append([(cc * rx, y - 0.012, z + ss * rz), (cc * (rx + 0.018), y - 0.012, z + ss * (rz + 0.018)),
                     (cc * (rx + 0.014), y + 0.01, z + ss * (rz + 0.014)), (cc * rx, y + 0.01, z + ss * rz)])
    loft(ms, basalt(), secs, cap=False)


# ------------------------------------------------------------- A Swift
def build_A(coll, root):
    ms, rb = Mesher(), Ribbons()
    # Hull: a sailplane's pod and boom, carved: the pod deepest under the
    # heart, rising to a raised prow; broken across the heart chamber (a
    # gap of light either side) and again where the boom leaves the pod.
    keel(ms, [(-0.67, 0.004, 0.04, 0.025), (-0.61, 0.034, 0.064, -0.03), (-0.49, 0.062, 0.078, -0.082),
              (-0.3, 0.078, 0.082, -0.108), (-0.115, 0.082, 0.082, -0.116)], seed=1, cut=(False, True))
    keel_gap(ms, -0.107, 0.082, 0.082, -0.116)
    keel_trough(ms, -0.098, 0.045, 0.082, 0.082, -0.116)
    keel_gap(ms, 0.054, 0.082, 0.082, -0.112)
    keel(ms, [(0.063, 0.082, 0.082, -0.11), (0.2, 0.074, 0.078, -0.085), (0.33, 0.046, 0.064, -0.045)], seed=3)
    cockpit_rim(ms, 0.084, 0.19, 0.07, 0.085)
    keel_gap(ms, 0.34, 0.044, 0.062, -0.042)
    keel(ms, [(0.35, 0.04, 0.06, -0.038), (0.55, 0.025, 0.05, -0.016), (0.78, 0.014, 0.042, -0.003), (0.83, 0.003, 0.038, 0.0)], seed=4, cut=(True, False))

    # Wing: a long tapering glider wing, three slabs a side, a little
    # dihedral rising toward the tips, the tips swept and pointed.
    H = 0.7

    def sec(x):
        t = min(1.0, abs(x) / H)
        y = 0.05 + 0.055 * t + 0.05 * max(0.0, t - 0.7) ** 1.5
        le = -0.125 + 0.13 * t ** 1.6
        c = 0.27 - 0.2 * t ** 1.3
        if t > 0.9:
            c *= math.sqrt(max(0.0, 1 - ((t - 0.9) / 0.1) ** 2)) * 0.8 + 0.2
        th = 0.034 - 0.022 * t
        return y, le, c, th
    slabs = [(0.088, 0.3), (0.314, 0.52), (0.534, 0.7)]
    wing(ms, rb, slabs, sec, "R", per=5, band_w=0.05, seed=10)
    wing(ms, rb, slabs, sec, "L", M=MIRROR, per=5, band_w=0.05, seed=20)
    # The root gaps between the wing and the hull.
    for M in (Matrix(), MIRROR):
        gap_plate(ms, 0.08, sec, M)

    # Tail: a tailplane in two floating slabs, a dorsal fin and a ventral
    # fin (the pitch cue), each held off the boom by a gap.
    def tsec(x):
        t = abs(x) / 0.25
        return 0.012 + 0.01 * t, 0.6 + 0.07 * t ** 1.5, 0.15 - 0.08 * t, 0.018 - 0.008 * t
    for M, ch in ((Matrix(), "BK"), (MIRROR, "BK")):
        wing(ms, rb, [(0.045, 0.25)], tsec, ch, M=M, per=3, band_w=0.035, glyph=False, seed=30)
        gap_plate(ms, 0.039, tsec, M)

    def fsec(x):  # x is height here (the fin's span axis turned to +Y)
        t = max(0.0, (x - 0.045) / 0.17)
        return 0.0, 0.57 + 0.15 * t ** 1.2, 0.2 - 0.12 * t, 0.018 - 0.006 * t
    up = Matrix.Rotation(math.pi / 2, 4, "Z")
    wing(ms, rb, [(0.05, 0.215)], fsec, "UP", M=up, per=4, band_w=0.04, glyph=False, seed=40)
    gap_plate(ms, 0.043, fsec, up)

    def vsec(x):
        t = max(0.0, (x - 0.04) / 0.09)
        return 0.0, 0.62 + 0.08 * t, 0.15 - 0.07 * t, 0.016 - 0.005 * t
    dn = Matrix.Rotation(-math.pi / 2, 4, "Z")
    wing(ms, rb, [(0.04, 0.13)], vsec, "DN", M=dn, per=3, band_w=0.04, glyph=False, seed=50)
    gap_plate(ms, 0.034, vsec, dn)
    objs = ms.build(f"Stone_A", coll, root)
    colour_stone(objs, 1)
    rb.build("A", coll, root)
    rune_ring("A", coll, root, -0.72, 0.15, wide=0.024, deep=0.022)
    heart_and_needle("A", coll, root, (0, 0.035, -0.025))
    wisp("A", coll, root, (0, 0, -0.75))
    seat_pilot("A", coll, root, -0.13, -0.05)


# ------------------------------------------------------------- B Lintel
def build_B(coll, root):
    ms, rb = Mesher(), Ribbons()
    # A deeper sky-boat hull, the prow raised, broken across the heart
    # chamber and where the tail leaves the body.
    keel(ms, [(-0.64, 0.004, 0.075, 0.06), (-0.6, 0.04, 0.084, 0.0), (-0.5, 0.075, 0.088, -0.07), (-0.34, 0.09, 0.088, -0.11),
              (-0.13, 0.095, 0.088, -0.122)], seed=1, cut=(False, True))
    keel_gap(ms, -0.121, 0.095, 0.088, -0.122)
    keel_trough(ms, -0.112, 0.03, 0.095, 0.088, -0.122)
    keel_gap(ms, 0.04, 0.095, 0.088, -0.12)
    keel(ms, [(0.05, 0.095, 0.088, -0.118), (0.22, 0.088, 0.086, -0.1), (0.34, 0.07, 0.078, -0.07)], seed=3)
    cockpit_rim(ms, 0.09, 0.19, 0.072, 0.085)
    keel_gap(ms, 0.352, 0.07, 0.078, -0.07)
    keel(ms, [(0.364, 0.068, 0.076, -0.066), (0.56, 0.042, 0.06, -0.035), (0.74, 0.02, 0.045, -0.01), (0.78, 0.004, 0.042, 0.0)], seed=4, cut=(True, False))

    # The lintel (upper wing): straight, square-cut, a carved slab; three
    # pieces: a centre over the hull and two a side.
    def usec(x):
        t = abs(x) / 0.7
        y = 0.31 + 0.025 * max(0.0, t - 0.75) / 0.25
        c = 0.27 - 0.05 * t
        c = c if t < 0.94 else c - 0.07 * (t - 0.94) / 0.06
        return y, -0.21 + (0.27 - c) * 0.3, c, 0.038 - 0.01 * t
    wing(ms, rb, [(-0.17, 0.17)], usec, None, per=6, band_w=0.0, glyph=False)
    # The centre piece's seam is both channels: left half L, right half R.
    for M, ch in ((Matrix(), "R"), (MIRROR, "L")):
        slab_seam_only(ms, rb, [lerp(0.0, 0.17, k / 3) for k in range(4)], usec, M, ch)
        wing(ms, rb, [(0.184, 0.44), (0.454, 0.7)], usec, ch, M=M, per=4, band_w=0.05, seed=10)
        gap_plate(ms, 0.177, usec, M)

    # The threshold (lower wing): shorter, behind, under the hull.
    def lsec(x):
        t = abs(x) / 0.6
        c = 0.24 - 0.04 * t
        c = c if t < 0.93 else c - 0.06 * (t - 0.93) / 0.07
        return -0.085 + 0.025 * t, -0.13 + (0.24 - c) * 0.3, c, 0.034 - 0.008 * t
    for M, ch in ((Matrix(), "R"), (MIRROR, "L")):
        wing(ms, rb, [(0.104, 0.36), (0.374, 0.6)], lsec, ch, M=M, per=4, band_w=0.035, seed=20)
        gap_plate(ms, 0.097, lsec, M)

    # The sundered column: a stub hanging from the lintel, a stub rising
    # from the threshold, octagonal with a necking ring, a gap of light
    # between them where the shaft broke.
    for side in (-1, 1):
        x = 0.4 * side
        frustum(ms, basalt(), 0.026, 0.03, 0.085, 8, T(x, 0.255, -0.09))
        frustum(ms, basalt(), 0.036, 0.036, 0.016, 8, T(x, 0.302, -0.09))
        frustum(ms, basalt(), 0.03, 0.026, 0.07, 8, T(x, -0.02, -0.035, rz=0.0))
        frustum(ms, basalt(), 0.037, 0.037, 0.014, 8, T(x, -0.05, -0.035))
        # Broken faces: jagged tops.
        gem(ms, basalt(), 0.022, T(x, 0.21, -0.088, s=(1.1, 0.5, 1.1)), 0)
        gem(ms, basalt(), 0.022, T(x, 0.016, -0.037, s=(1.1, 0.5, 1.1)), 0)
        # The light between: two crossed soft ribbons.
        pts = [(x, 0.03 + (0.2 - 0.03) * k / 6, lerp(-0.037, -0.088, k / 6)) for k in range(7)]
        rb.add("GAP", pts, (1, 0, 0), 0.05)
        rb.add("GAP", pts, (0, 0, 1), 0.05)

    # Tail: a lancet fin (a pointed arch), a ventral keel, the tailplane.
    def tsec(x):
        t = abs(x) / 0.26
        c = 0.15 if t < 0.85 else 0.15 - 0.06 * (t - 0.85) / 0.15
        return 0.015, 0.6 + (0.15 - c) * 0.5, c, 0.02
    for M in (Matrix(), MIRROR):
        wing(ms, rb, [(0.05, 0.26)], tsec, "BK", M=M, per=3, band_w=0.035, glyph=False, seed=30)
        gap_plate(ms, 0.044, tsec, M)

    def fsec(x):
        t = max(0.0, min(1.0, (x - 0.055) / 0.2))
        # A pointed arch: the chord closes to a point at the top.
        c = 0.17 * math.sqrt(max(0.0, 1 - t ** 2.2)) + 0.004
        return 0.0, 0.575 + (0.17 - c) * 0.5, c, 0.02
    up = Matrix.Rotation(math.pi / 2, 4, "Z")
    wing(ms, rb, [(0.06, 0.255)], fsec, "UP", M=up, per=6, band_w=0.04, glyph=False, seed=40)
    gap_plate(ms, 0.053, fsec, up)

    def vsec(x):
        t = max(0.0, (x - 0.05) / 0.08)
        return 0.0, 0.6 + 0.07 * t, 0.13 - 0.06 * t, 0.018
    dn = Matrix.Rotation(-math.pi / 2, 4, "Z")
    wing(ms, rb, [(0.05, 0.13)], vsec, "DN", M=dn, per=3, band_w=0.04, glyph=False, seed=50)
    gap_plate(ms, 0.043, vsec, dn)
    objs = ms.build("Stone_B", coll, root)
    colour_stone(objs, 2)
    rb.build("B", coll, root)
    rune_ring("B", coll, root, -0.69, 0.16, wide=0.026, deep=0.024)
    heart_and_needle("B", coll, root, (0, 0.035, -0.04))
    wisp("B", coll, root, (0, 0, -0.7))
    seat_pilot("B", coll, root, -0.115, -0.05)


def slab_seam_only(ms, rb, xs, sec, M, ch):
    """The seam (glyphs, rear band, ribbon) of a slab built elsewhere."""
    cm = core(ch)
    bsecs = []
    pts = []
    for x in xs:
        y, le, c, th = sec(x)
        z = le + c + 0.0012
        bsecs.append([(x, y - th * 0.05, z), (x, y + th * 0.21, z), (x, y + th * 0.21, z + 0.003), (x, y - th * 0.05, z + 0.003)])
        pts.append(M @ Vector((x, y + th * 0.08, le + c + 0.006)))
    loft(ms, cm, bsecs, M)
    rb.add(ch, pts, M.to_3x3() @ Vector((0, 1, 0)), 0.05)
    a, b = xs[0] + 0.012, xs[-1] - 0.01
    run = []
    for x in (a, (a + b) / 2, b):
        y, le, c, th = sec(x)
        yt = y + th * 0.76 + 0.0008
        z = le + 0.42 * c
        run.append([(x, yt - 0.002, z - 0.009), (x, yt - 0.002, z + 0.009), (x, yt + 0.0015, z + 0.009), (x, yt + 0.0015, z - 0.009)])
    loft(ms, cm, run, M)


# ------------------------------------------------------------- C Feather
def build_C(coll, root):
    ms, rb = Mesher(), Ribbons()
    # The hull: a spine of carved vertebrae (keel slices, a dorsal nub on
    # the small ones), a gap of light between each; the heart hangs in an
    # open cage of two ribs between the shoulder and the cockpit.
    keel(ms, [(-0.68, 0.003, 0.05, 0.035), (-0.63, 0.03, 0.06, -0.01), (-0.54, 0.055, 0.066, -0.05)], seed=1, cut=(False, True))
    verts = [(-0.525, -0.43, 0.062, 0.068, -0.062), (-0.41, -0.12, 0.075, 0.072, -0.085),
             (0.065, 0.3, 0.078, 0.075, -0.085), (0.325, 0.42, 0.055, 0.062, -0.05),
             (0.445, 0.53, 0.04, 0.05, -0.032), (0.555, 0.63, 0.026, 0.04, -0.018)]
    prev = (-0.54, 0.055, 0.066, -0.05)
    for i, (z0, z1, hw, top, bot) in enumerate(verts):
        k = 0.82
        keel(ms, [(z0, hw * k, top * k, bot * k), (z0 + 0.02, hw, top, bot), (z1 - 0.02, hw, top, bot), (z1, hw * k, top * k, bot * k)], seed=10 + i)
        if z1 - z0 < 0.12:
            gem(ms, basalt(), 0.018, T(0, top + 0.008, (z0 + z1) / 2, s=(0.6, 1.0, 1.4)), 0)
        if i != 2:
            keel_gap(ms, (prev[0] + z0) / 2 if i else -0.535, hw, top, bot)
        prev = (z1, hw, top, bot)
    keel_trough(ms, -0.1, -0.075, 0.075, 0.072, -0.085)
    keel_trough(ms, 0.02, 0.045, 0.075, 0.072, -0.085)
    keel(ms, [(-0.11, 0.015, -0.07, -0.095), (-0.03, 0.022, -0.068, -0.1), (0.055, 0.015, -0.07, -0.095)], seed=9, cut=(False, False))
    cockpit_rim(ms, 0.08, 0.19, 0.07, 0.08)

    # Feathers: five a side, fanned like a gliding bird's primaries, the
    # long ones split once with a gap of light.
    feathers = [(-0.37, -0.06, 0.58), (-0.31, 0.1, 0.63), (-0.25, 0.26, 0.6), (-0.19, 0.44, 0.5), (-0.135, 0.64, 0.38)]

    def fsec_for(L):
        def fsec(x):
            t = min(1.0, max(0.0, x / L))
            w = 0.135 * (1 - t ** 2.4) ** 0.6 + 0.012
            th = 0.022 - 0.012 * t
            y = 0.012 * t + 0.03 * t ** 2
            return y, -w * 0.45, w, th
        return fsec
    for side, ch in ((1, "R"), (-1, "L")):
        for k, (z, ang, L) in enumerate(feathers):
            M = T(0.085 * side, 0.035 + 0.006 * k, z, ry=-ang, rz=0.08) if side > 0 else \
                MIRROR @ T(0.085, 0.035 + 0.006 * k, z, ry=-ang, rz=0.08)
            fsec = fsec_for(L)
            if L > 0.5:
                cut = L * 0.52
                wing(ms, rb, [(0.012, cut - 0.007), (cut + 0.007, L * 0.985)], fsec, ch, M=M, per=4, band_w=0.03, te=False, glyph_u=0.45, seed=60 + k)
            else:
                wing(ms, rb, [(0.012, L * 0.985)], fsec, ch, M=M, per=5, band_w=0.03, te=False, glyph_u=0.45, seed=60 + k)
            gap_plate(ms, 0.006, fsec, M, w=0.003)

    # Tail feathers (BK): two a side, small, swept.
    for side in (1, -1):
        for k, (z, ang, L) in enumerate(((0.5, 0.35, 0.2), (0.56, 0.6, 0.15))):
            M = T(0.04, 0.0, z, ry=-ang) if side > 0 else MIRROR @ T(0.04, 0.0, z, ry=-ang)

            def tsec(x, L=L):
                t = min(1.0, x / L)
                w = 0.06 * (1 - t ** 2) ** 0.6 + 0.01
                return 0.0, -w * 0.4, w, 0.014 - 0.006 * t
            wing(ms, rb, [(0.008, L * 0.98)], tsec, "BK", M=M, per=3, band_w=0.03, glyph=False, seed=70 + k)

    # The ring tail: four arcs (top UP, bottom DN, left L, right R), gaps of
    # light between them, glyph bands on their rear faces. It floats
    # behind the last bead, held by nothing.
    zt, R, wide, deep = 0.69, 0.09, 0.022, 0.03
    arcs = (("UP", math.pi / 2), ("L", math.pi), ("DN", 1.5 * math.pi), ("R", 0.0))
    for ch, mid in arcs:
        a0, a1 = mid - math.pi / 4 + 0.07, mid + math.pi / 4 - 0.07
        secs = []
        n = 6
        for i in range(n + 1):
            a = lerp(a0, a1, i / n)
            cc, ss = math.cos(a), math.sin(a)
            ri, ro = R - wide / 2, R + wide / 2
            secs.append([(cc * ri, ss * ri, zt - deep / 2), (cc * ro, ss * ro, zt - deep / 2),
                         (cc * ro, ss * ro, zt + deep / 2), (cc * ri, ss * ri, zt + deep / 2)])
        loft(ms, basalt(), secs)
        # The rear face's band.
        bs = []
        pts = []
        for i in range(n + 1):
            a = lerp(a0 + 0.04, a1 - 0.04, i / n)
            cc, ss = math.cos(a), math.sin(a)
            bs.append([(cc * (R - 0.007), ss * (R - 0.007), zt + deep / 2 + 0.0012), (cc * (R + 0.007), ss * (R + 0.007), zt + deep / 2 + 0.0012),
                       (cc * (R + 0.007), ss * (R + 0.007), zt + deep / 2 + 0.004), (cc * (R - 0.007), ss * (R - 0.007), zt + deep / 2 + 0.004)])
            pts.append((cc * R, ss * R, zt + deep / 2 + 0.008))
        loft(ms, core(ch), bs)
        # Ribbon: across is radial; approximate with the arc's mid radial.
        rb.add(ch, pts, [(p[0], p[1], 0.0) for p in pts], 0.035)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        cc, ss = math.cos(a), math.sin(a)
        box(ms, core("GAP"), (0.006, wide * 0.8, deep * 0.8), T(cc * R, ss * R, zt, rz=a))
    objs = ms.build("Stone_C", coll, root)
    colour_stone(objs, 3)
    rb.build("C", coll, root)
    rune_ring("C", coll, root, -0.73, 0.15, wide=0.022, deep=0.022)
    heart_and_needle("C", coll, root, (0, -0.01, -0.028), needle_up=0.085)
    wisp("C", coll, root, (0, 0, -0.73))
    seat_pilot("C", coll, root, -0.13, -0.05)


# ------------------------------------------------------------- build all
def tri_count(objs):
    return sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in objs if ob.type == "MESH")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for D, fn in (("A", build_A), ("B", build_B), ("C", build_C)):
        coll = bpy.data.collections.new(f"Stone_{D}")
        scene.collection.children.link(coll)
        root = bpy.data.objects.new(f"Root_{D}", None)
        coll.objects.link(root)
        fn(coll, root)
    rc = bpy.data.collections.new("Ruin")
    scene.collection.children.link(rc)
    pb.ruin(rc)
    for D in "ABC":
        groups = {"stone": [], "seams": [], "bands": [], "ring": [], "heart+needle": [], "wisp": [], "pilot": []}
        for ob in bpy.data.collections[f"Stone_{D}"].objects:
            if ob.type != "MESH":
                continue
            n = ob.name
            if n.startswith("Pilot"):
                groups["pilot"].append(ob)
            elif n.startswith("Band_"):
                groups["bands"].append(ob)
            elif n.startswith(("RingMesh", "RingBlur")):
                groups["ring"].append(ob)
            elif n.startswith(("Heart", "NeedleMesh")):
                groups["heart+needle"].append(ob)
            elif n.startswith("WispMesh"):
                groups["wisp"].append(ob)
            elif "core_" in n:
                groups["seams"].append(ob)
            else:
                groups["stone"].append(ob)
        print(f"STONE_TRIS {D} " + " ".join(f"{k}={tri_count(v)}" for k, v in groups.items()))
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print("saved", BLEND)


if __name__ == "__main__":
    main()
