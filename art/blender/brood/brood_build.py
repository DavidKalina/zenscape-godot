"""Build the brood's stone guy (scripts/brood/stone_guy.gd, stone_guy_body.gd,
docs/design/brood/body-contract.md): a knee-high lump of stone with a head,
stub arms ending in big fists and stub legs.

The greybox's silhouette, kept: a squat block trunk as wide as he is tall
less a quarter, a head a little forward with a heavy brow, stub arms hanging
outside the trunk, stub legs. Units are his height H (1 here); the game
scales the glb to BroodKnobs.tall() (a share of the wanderer's height,
scripts/world_scale.gd), so no metre figure lives here.

Sculpt high, bake low (docs/art/model-budget.md):
  - Each piece is a rounded box (a superquadric). The LOW mesh samples it on
    a coarse grid with the big shape only (lumps, the brow, big chips, the
    eye pits) so the outline is chipped for real; ~1.5k triangles.
  - The HIGH mesh samples the same surface ~100x finer and adds the fine
    detail: cracks (Voronoi cell borders, two scales), small chips (cells
    knocked in flat along the edges), pits and grain. Its vertex colours are
    the paint: stone with a little warm and cool, dark grime in the cracks
    and chips, moss in the crevices that face up, worn light edges, dark
    eye pits and mouth crack.
  - Cycles bakes the high onto the low's UVs: the colour (EMIT), a tangent
    normal map and AO (each piece baked apart, so the AO is the stone's
    own crevices and holds in any pose). The AO is multiplied into the
    colour. 512 px each, embedded in the glb.

Rig (Blender +Y his front, +Z up; glTF turns it to Godot -Z forward). The
origin is his middle, his soles at -0.5.
  root  body (about his feet: the squash)  trunk  head
                                           trunk  arm.S  hand.S
                                     body  leg.S  foot.S
Every piece is one rigid vertex group on its bone, in one skinned mesh (one
draw call a guy). Clips: brood_clips.py.

    python tools/blender.py run art/blender/brood/brood_build.py -- [--out=DIR] [--blend] [--render=DIR] [--sheets=a,b] [--tex=512]

Writes assets/models/brood_stone_guy.glb and brood_clips.json (or into
DIR), printing BROOD_TRIS; --render=DIR writes Workbench stills there
(a turntable and a sheet a clip).
"""
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, Matrix, noise

V = Vector
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import brood_clips as bc  # noqa: E402

_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ROOT / "assets/models"
SAVE_BLEND = False
RENDER = None
SHEETS = None
TEX = 512
for a in _args:
    if a.startswith("--out="): OUT = Path(a.split("=", 1)[1])
    elif a == "--blend": SAVE_BLEND = True
    elif a.startswith("--render="): RENDER = Path(a.split("=", 1)[1])
    elif a.startswith("--sheets="): SHEETS = set(a.split("=", 1)[1].split(","))
    elif a.startswith("--tex="): TEX = int(a.split("=", 1)[1])
GLB = OUT / "brood_stone_guy.glb"
rng = random.Random(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexrgb(h):
    return V([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# Paint (sRGB). STONE is the greybox's BroodKnobs.STONE, a touch warmer.
STONE = hexrgb("b3b0a8")
STONE_WARM = hexrgb("b5ac9a")
STONE_COOL = hexrgb("a3a8ad")
GRIME = hexrgb("4a463f")
MOSS = hexrgb("5d6b34")
MOSS_DRY = hexrgb("7d7f45")
EDGE = hexrgb("d6d2c8")
EYE = hexrgb("15130f")

# ------------------------------------------------------------------ the joints
# (H units; the greybox's pivots, scripts/brood/stone_guy.gd `_build`.)
JOINT = {
    "root": (0, 0, -0.5),
    "body": (0, 0, -0.5),
    "trunk": (0, 0, -0.16),
    "head": (0, 0.04, 0.2),
    "arm_l": (-0.40, 0.0, 0.14), "arm_r": (0.40, 0.0, 0.14),
    "hand_l": (-0.445, 0.0, -0.03), "hand_r": (0.445, 0.0, -0.03),
    "leg_l": (-0.18, 0.0, -0.21), "leg_r": (0.18, 0.0, -0.21),
    "foot_l": (-0.185, 0.0, -0.35), "foot_r": (0.185, 0.0, -0.35),
}


def sgnpow(x, e):
    return math.copysign(abs(x) ** e, x)


class Piece:
    """A rounded box: centre c, half-sizes h, exponents (e_up, e_round),
    `taper` (x and y times 1 + taper*z/h.z), `shear` (y += shear*z/h.z),
    on `bone`; `cuts` the low cube's cuts an edge (the high: HIGH_CUTS)."""

    def __init__(self, name, bone, c, h, e=(0.5, 0.45), taper=0.0, shear=0.0, cuts=3, seed=0, extra=None, hi=40):
        self.name, self.bone = name, bone
        self.c, self.h = V(c), V(h)
        self.e, self.taper, self.shear = e, taper, shear
        self.cuts, self.seed, self.hi = cuts, seed, hi
        self.extra = extra   # extra(pc, p, u, n) -> (big disp, paint dict)

    def project(self, q):
        """A point of the cube [-1, 1]^3 out onto the rounded box: the
        point and its unit coords (cx, cy, cz in -1..1)."""
        e1, e2 = self.e
        ax, ay, az = max(abs(q.x), 1e-6), max(abs(q.y), 1e-6), max(abs(q.z), 1e-6)
        f = (ax ** (2 / e2) + ay ** (2 / e2)) ** (e2 / e1) + az ** (2 / e1)
        u = q / (f ** (e1 / 2))
        k = 1.0 + self.taper * u.z
        p = V((u.x * self.h.x * k, u.y * self.h.y * k + self.shear * u.z * self.h.y, u.z * self.h.z))
        return self.c + p, u


def edge_of(u):
    a = sorted([abs(u.x), abs(u.y), abs(u.z)])
    return a[1]   # the second largest: ~0 mid-face, ~1 on an edge


# ------------------------------------------------------------------ the sculpt
def cell(p, scale, seed):
    """F1, F2 and the nearest cell's random 0..1 (Voronoi)."""
    d, pts = noise.voronoi(p * scale + V((seed * 17.1, seed * 3.7, seed * 9.3)), distance_metric="DISTANCE")
    c0 = pts[0]
    h = math.sin(c0.x * 12.9898 + c0.y * 78.233 + c0.z * 37.719) * 43758.5453
    return d[0], d[1], h - math.floor(h)


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def big_disp(pc, p, u, n):
    """The low mesh's share (H): lumps and big chips on the edges."""
    s = pc.seed
    lump = 0.018 * noise.fractal(p * 3.2 + V((s, 0, 0)), 0.8, 2.0, 3)
    f1, f2, r = cell(p, 3.0, s + 1)
    ed = edge_of(u)
    chip = -0.03 * (ed ** 3) if r < 0.32 else 0.0
    d = lump + chip
    paint = {"chip": 1.0 if chip < -0.005 else 0.0}
    if pc.extra:
        dd, pp = pc.extra(pc, p, u, n)
        d += dd
        paint.update(pp)
    return d, paint


def fine_disp(pc, p, u, n):
    """The high mesh's own detail (H, mostly inward) and the cavity it makes."""
    s = pc.seed
    f1, f2, r = cell(p, 6.5, s + 2)
    crack = 1.0 - smooth(0.0, 0.05, f2 - f1)
    crack *= smooth(0.42, 0.68, noise.noise(p * 2.5 + V((0, s, 0))) * 0.5 + 0.5)   # cracks broken up
    g1, g2, gr = cell(p, 15.0, s + 3)
    hair = (1.0 - smooth(0.0, 0.03, g2 - g1)) * 0.5 * smooth(0.45, 0.7, noise.noise(p * 3.1 + V((s, 0, 2))) * 0.5 + 0.5)
    ed = edge_of(u)
    c1, c2, cr = cell(p, 9.0, s + 4)
    nick = (0.012 * smooth(0.55, 0.9, ed)) if cr < 0.3 else 0.0
    pit = smooth(0.68, 0.85, noise.noise(p * 24.0 + V((s, s, 0))) * 0.5 + 0.5)
    grain = 0.0018 * noise.noise(p * 70.0)
    d = -0.02 * crack - 0.006 * hair - nick - 0.004 * pit + grain
    cav = min(1.0, crack * 1.0 + hair * 0.35 + pit * 0.2 + (nick > 0) * 0.25)
    return d, cav


def paint(pc, p, u, n, cav, pd):
    s = pc.seed
    tone = noise.noise(p * 4.0 + V((s, 2 * s, 0))) * 0.5 + 0.5
    col = STONE_COOL.lerp(STONE_WARM, smooth(0.25, 0.75, tone))
    col = col.lerp(STONE, 0.4)
    speck = noise.noise(p * 40.0)
    col = col * (1.0 + 0.03 * speck)
    ed = edge_of(u)
    col = col.lerp(EDGE, 0.35 * smooth(0.7, 1.0, ed) * (1.0 - cav))
    if pd.get("chip", 0.0) > 0.0:
        col = col.lerp(EDGE, 0.2)
    col = col.lerp(GRIME, 0.6 * cav)
    # moss: in the crevices, more on what faces up, in patches
    patch = smooth(0.42, 0.62, noise.noise(p * 2.2 + V((5 * s, 0, 1))) * 0.5 + 0.5)
    up = smooth(-0.1, 0.8, n.z)
    m = smooth(0.3, 0.75, cav * 0.8 + up * 0.35 + 0.15 * noise.noise(p * 11.0)) * patch
    m = max(m, 0.55 * patch * up * smooth(0.55, 0.8, noise.noise(p * 7.0 + V((0, 0, 3))) * 0.5 + 0.5))
    moss = MOSS.lerp(MOSS_DRY, smooth(0.3, 0.7, noise.noise(p * 9.0) * 0.5 + 0.5))
    col = col.lerp(moss, min(m, 0.9))
    if pd.get("eye", 0.0) > 0.0:
        col = col.lerp(EYE, pd["eye"])
    if pd.get("mouth", 0.0) > 0.0:
        col = col.lerp(GRIME * 0.6, pd["mouth"])
    return col


# ------------------------------------------------------------------ the head's face
def head_extra(pc, p, u, n):
    """The brow (a ridge over the eyes), the eye pits under it, a mouth crack."""
    d = 0.0
    out = {}
    front = smooth(0.35, 0.85, u.y)
    brow = front * math.exp(-((u.z - 0.42) / 0.16) ** 2) * (1.0 - 0.25 * abs(u.x))
    d += 0.05 * brow
    eye = 0.0
    for sx in (-0.42, 0.42):
        r2 = ((u.x - sx) / 0.2) ** 2 + ((u.z - 0.12) / 0.17) ** 2
        eye = max(eye, front * math.exp(-r2 * 2.0))
    d -= 0.03 * eye
    out["eye"] = smooth(0.3, 0.7, eye)
    mouth = front * math.exp(-((u.z + 0.35) / 0.06) ** 2) * smooth(0.75, 0.3, abs(u.x))
    d -= 0.012 * mouth
    out["mouth"] = smooth(0.2, 0.6, mouth) * 0.8
    return d, out


def fist_extra(pc, p, u, n):
    """Knuckles: three bumps across the front of the fist."""
    d = 0.0
    if u.y > 0.2 and u.z < 0.2:
        for kx in (-0.55, 0.0, 0.55):
            r2 = ((u.x - kx) / 0.28) ** 2 + ((u.z + 0.35) / 0.3) ** 2
            d += 0.012 * math.exp(-r2 * 2.0) * smooth(0.2, 0.8, u.y)
    return d, {}


# ------------------------------------------------------------------ the pieces
PIECES = [
    # The trunk: a block wider at the shoulders, a little belly forward.
    Piece("trunk", "trunk", (0, 0.0, 0.0), (0.36, 0.26, 0.24), e=(0.4, 0.38), taper=0.08, shear=-0.04,
          cuts=5, seed=1, hi=64),
    Piece("head", "head", (0, 0.1, 0.355), (0.215, 0.205, 0.17), e=(0.45, 0.42), taper=-0.06, shear=0.08,
          cuts=4, seed=2, extra=head_extra, hi=56),
]
for sd, sg in (("l", -1.0), ("r", 1.0)):
    PIECES += [
        Piece(f"arm_{sd}", f"arm_{sd}", (sg * 0.415, 0.0, 0.08), (0.08, 0.085, 0.12), e=(0.55, 0.5), taper=0.1,
              cuts=2, seed=3 if sd == "l" else 4, hi=30),
        Piece(f"fist_{sd}", f"hand_{sd}", (sg * 0.43, 0.015, -0.14), (0.1, 0.105, 0.12), e=(0.45, 0.45), taper=-0.08,
              cuts=3, seed=5 if sd == "l" else 6, extra=fist_extra, hi=36),
        Piece(f"leg_{sd}", f"leg_{sd}", (sg * 0.18, 0.0, -0.3), (0.095, 0.1, 0.11), e=(0.55, 0.5), cuts=2,
              seed=7 if sd == "l" else 8, hi=30),
        Piece(f"foot_{sd}", f"foot_{sd}", (sg * 0.19, 0.045, -0.44), (0.11, 0.145, 0.065), e=(0.42, 0.42), taper=-0.1,
              cuts=2, seed=9 if sd == "l" else 10, hi=36),
    ]


def build(pc, cuts, high, offset):
    """The piece's mesh (offset for the bake); vertex paint on the high."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    units = {}
    for v in bm.verts:
        p, u = pc.project(v.co.copy())
        v.co = p
        units[v] = u
    bm.normal_update()
    # displace along the undisplaced normal
    base_n = {v: v.normal.copy() for v in bm.verts}
    base_p = {v: v.co.copy() for v in bm.verts}
    cols = {}
    for v in bm.verts:
        p, n, u = base_p[v], base_n[v], units[v]
        d, pd = big_disp(pc, p, u, n)
        cav = 0.0
        if high:
            fd, cav = fine_disp(pc, p, u, n)
            d += fd
        v.co = p + n * d + V(offset)
        if high:
            cols[v] = (paint(pc, p, u, n, cav, pd), )
    me = bpy.data.meshes.new(pc.name + ("_hi" if high else "_lo"))
    if high:
        lay = bm.loops.layers.color.new("paint")
        for f in bm.faces:
            for lp in f.loops:
                c = cols[lp.vert][0]
                lp[lay] = (srgb_to_linear(max(c.x, 0)), srgb_to_linear(max(c.y, 0)), srgb_to_linear(max(c.z, 0)), 1.0)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new(me.name, me)
    scene.collection.objects.link(ob)
    return ob


def join(obs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


# Each piece baked apart: piece i sits OFF*i along x for the bake.
OFF = 3.0
lows, highs = [], []
for i, pc in enumerate(PIECES):
    off = (OFF * i, 0, 0)
    lo = build(pc, pc.cuts, False, off)
    vg = lo.vertex_groups.new(name=pc.bone)
    vg.add(list(range(len(lo.data.vertices))), 1.0, "REPLACE")
    lo["piece"] = i
    lows.append(lo)
    hi = build(pc, pc.hi, True, off)
    highs.append(hi)
    print("BROOD_PIECE", pc.name, "low tris", sum(len(p.vertices) - 2 for p in lo.data.polygons),
          "high verts", len(hi.data.vertices))

low = join(lows, "StoneGuy")
high = join(highs, "StoneGuyHigh")
TRIS = sum(len(p.vertices) - 2 for p in low.data.polygons)
print("BROOD_TRIS", TRIS, "high tris", sum(len(p.vertices) - 2 for p in high.data.polygons))

# ------------------------------------------------------------------ UVs
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012, area_weight=0.0)
try:
    bpy.ops.uv.pack_islands(rotate=True, margin=0.01)
except Exception as ex:
    print("BROOD_PACK", ex)
bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ the bake
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg: bg.inputs[0].default_value = (1, 1, 1, 1)
try:
    world.light_settings.distance = 0.12
except Exception:
    pass

hm = bpy.data.materials.new("paint")
hm.use_nodes = True
nt = hm.node_tree
nt.nodes.clear()
at = nt.nodes.new("ShaderNodeVertexColor")
at.layer_name = "paint"
em = nt.nodes.new("ShaderNodeEmission")
df = nt.nodes.new("ShaderNodeBsdfDiffuse")
mix = nt.nodes.new("ShaderNodeAddShader")
mo = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(at.outputs["Color"], em.inputs["Color"])
nt.links.new(at.outputs["Color"], df.inputs["Color"])
nt.links.new(em.outputs[0], mix.inputs[0])
nt.links.new(df.outputs[0], mix.inputs[1])
nt.links.new(mix.outputs[0], mo.inputs["Surface"])
high.data.materials.append(hm)


def image(name, noncolor):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    return img


IMG = {"albedo": image("brood_stone_albedo", False), "normal": image("brood_stone_normal", True),
       "ao": image("brood_stone_ao", True)}

lm = bpy.data.materials.new("brood_stone")
lm.use_nodes = True
lnt = lm.node_tree
bsdf = lnt.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.95
tex_a = lnt.nodes.new("ShaderNodeTexImage")
tex_a.image = IMG["albedo"]
tex_n = lnt.nodes.new("ShaderNodeTexImage")
tex_n.image = IMG["normal"]
nmap = lnt.nodes.new("ShaderNodeNormalMap")
tex_ao = lnt.nodes.new("ShaderNodeTexImage")
tex_ao.image = IMG["ao"]
low.data.materials.append(lm)


def bake_to(key, kind, **kw):
    lnt.nodes.active = {"albedo": tex_a, "normal": tex_n, "ao": tex_ao}[key]
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.035
    scene.render.bake.max_ray_distance = 0.08
    scene.render.bake.margin = 6
    bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.035,
                        max_ray_distance=0.08, margin=6, **kw)
    print("BROOD_BAKED", key)


scene.cycles.samples = 1
bake_to("albedo", "EMIT")
scene.cycles.samples = 4
bake_to("normal", "NORMAL", normal_space="TANGENT")
scene.cycles.samples = 48
bake_to("ao", "AO")

import numpy as np  # noqa: E402
px = TEX * TEX * 4
alb = np.empty(px, dtype=np.float32)
IMG["albedo"].pixels.foreach_get(alb)
ao = np.empty(px, dtype=np.float32)
IMG["ao"].pixels.foreach_get(ao)
alb = alb.reshape(-1, 4)
aoc = ao.reshape(-1, 4)[:, :1]
alb[:, :3] *= 0.6 + 0.4 * aoc
IMG["albedo"].pixels.foreach_set(alb.ravel())
OUT.mkdir(parents=True, exist_ok=True)
BAKE = HERE / "bake"     # the maps as files too (the glb embeds its own)
BAKE.mkdir(exist_ok=True)
(BAKE / ".gdignore").write_text("")
for key, img in IMG.items():
    img.filepath_raw = str(BAKE / f"{img.name}.png")
    img.file_format = "PNG"
    img.save()
print("BROOD_AO mean", round(float(aoc.mean()), 3), "min", round(float(aoc.min()), 3))

# the AO's in the colour now: the low's material is colour + normal
lnt.links.new(tex_a.outputs["Color"], bsdf.inputs["Base Color"])
lnt.links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
lnt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
lnt.nodes.remove(tex_ao)
bpy.data.objects.remove(high)

# back together: each piece's verts back from its bake spot
gidx = {g.index: g.name for g in low.vertex_groups}
off_of = {pc.bone: V((OFF * i, 0, 0)) for i, pc in enumerate(PIECES)}
for v in low.data.vertices:
    g = gidx[v.groups[0].group]
    v.co -= off_of[g]
low.data.update()
zs = [v.co.z for v in low.data.vertices]
xs = [v.co.x for v in low.data.vertices]
print("BROOD_BOUNDS z", round(min(zs), 3), round(max(zs), 3), "x", round(min(xs), 3), round(max(xs), 3))

# ------------------------------------------------------------------ the rig
J = {k: V(v) for k, v in JOINT.items()}
UP = V((0, 0, 1))
BONES = {
    "root": (J["root"], J["root"] + V((0, 0.15, 0)), None),
    "body": (J["body"], J["body"] + UP * 0.2, "root"),
    "trunk": (J["trunk"], J["head"], "body"),
    "head": (J["head"], J["head"] + UP * 0.3, "trunk"),
}
for sd in ("l", "r"):
    BONES[f"arm_{sd}"] = (J[f"arm_{sd}"], J[f"hand_{sd}"], "trunk")
    BONES[f"hand_{sd}"] = (J[f"hand_{sd}"], J[f"hand_{sd}"] - UP * 0.24, f"arm_{sd}")
    BONES[f"leg_{sd}"] = (J[f"leg_{sd}"], J[f"foot_{sd}"], "body")
    BONES[f"foot_{sd}"] = (J[f"foot_{sd}"], J[f"foot_{sd}"] + V((0, 0.12, -0.14)), f"leg_{sd}")
arm_data = bpy.data.armatures.new("StoneGuyRig")
rig = bpy.data.objects.new("StoneGuyRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (hd, tl, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = hd, tl
    b.roll = 0.0
    b.use_deform = name != "root"
    eb[name] = b
for name, (hd, tl, parent) in BONES.items():
    if parent:
        eb[name].parent = eb[parent]
        eb[name].use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
low.parent = rig
low.modifiers.new("Rig", "ARMATURE").object = rig

# sockets: empties on bones (the contract's names)
SOCKETS = {
    "hand_l": ("hand_l", J["hand_l"] + V((0, 0.04, -0.2))),
    "hand_r": ("hand_r", J["hand_r"] + V((0, 0.04, -0.2))),
    "head": ("head", V((0, 0.1, 0.55))),
    "eyes": ("head", V((0, 0.3, 0.41))),
    "load": ("trunk", V((0, 0.0, 0.62))),
}
sockets = []
for nm, (bone, p) in SOCKETS.items():
    e = bpy.data.objects.new("socket_" + nm, None)
    e.empty_display_size = 0.05
    scene.collection.objects.link(e)
    e.location = p
    bpy.context.view_layer.update()
    mw = e.matrix_world.copy()
    e.parent = rig
    e.parent_type = "BONE"
    e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = mw
    sockets.append(e)
print("BROOD_RIG bones", len(BONES))

# ------------------------------------------------------------------ clips
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
KRIG = bc.Rig(rig, JOINT)
CLIPS = bc.clips()
ACTIONS = {c.name: bc.bake(KRIG, c) for c in CLIPS}
bc.reset(rig)
table = {"fps": bc.FPS, "tris": TRIS, "clips": {c.name: c.table() for c in CLIPS},
         # sockets: the bone and the spot (Blender model space, H) at rest
         "sockets": {k: {"bone": v[0], "at": [round(x, 4) for x in v[1]]} for k, v in SOCKETS.items()}}
(OUT / "brood_clips.json").write_text(json.dumps(table, indent=1) + "\n")
print("BROOD_TABLE", OUT / "brood_clips.json")

if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "brood.blend"))

# ------------------------------------------------------------------ export
bpy.ops.object.select_all(action="DESELECT")
for ob in [low, rig]: ob.select_set(True)
bpy.context.view_layer.objects.active = rig
scene.render.fps = bc.FPS
scene.render.fps_base = 1.0
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=False, export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_frame_step=1, export_def_bones=False,
                          export_materials="EXPORT", export_image_format="AUTO",
                          export_normals=True, export_tangents=False, export_extras=False, export_texcoords=True)
print("BROOD_EXPORTED", GLB)

# ------------------------------------------------------------------ stills
if RENDER:
    RENDER.mkdir(parents=True, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    shd = scene.display.shading
    shd.light = "STUDIO"
    shd.color_type = "TEXTURE"
    shd.show_cavity = True
    shd.cavity_type = "BOTH"
    shd.show_shadows = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 1.2
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for tr_ in rig.animation_data.nla_tracks:
        tr_.mute = True

    def shoot(path, eye, at_, lens=50, res=(360, 420)):
        cam.location = V(eye)
        cam.rotation_euler = (V(at_) - V(eye)).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.render.resolution_x, scene.render.resolution_y = res
        cam_data.lens = lens
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(str(path), check_existing=False)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        bpy.data.images.remove(img)
        return a

    def save(a, fp):
        out = bpy.data.images.new(fp.stem, a.shape[1], a.shape[0])
        out.pixels = a.ravel()
        out.filepath_raw = str(fp)
        out.file_format = "PNG"
        out.save()

    bc.reset(rig)
    cells = []
    for ang in (0, 40, 90, 150, 180, 270):
        a = math.radians(ang)
        cells.append(shoot(RENDER / "_cell.png", (math.sin(a) * 3.4, math.cos(a) * 3.4, 0.7), (0, 0, 0.02)))
    save(np.concatenate(cells, axis=1), RENDER / "turntable.png")
    save(shoot(RENDER / "_cell.png", (0.9, 1.6, 0.75), (0, 0.05, 0.25), lens=60, res=(700, 700)), RENDER / "close.png")
    print("BROOD_STILLS", RENDER)
    N = 6
    views = [((1.5, 1.9, 0.7), (0, 0, 0.05)), ((2.4, 0.0, 0.3), (0, 0, 0.05))]
    for c in CLIPS:
        if SHEETS and c.name not in SHEETS:
            continue
        times = [c.length * j / N for j in range(N)] if c.loop else sorted({k[0] for k in c.keys})
        rows = []
        for eye, at_ in views:
            row = []
            for t in times:
                KRIG.apply(c, t)
                bpy.context.view_layer.update()
                row.append(shoot(RENDER / "_cell.png", eye, at_, lens=42, res=(300, 360)))
            rows.append(np.concatenate(row, axis=1))
        save(np.concatenate(rows[::-1], axis=0), RENDER / f"clip_{c.name}.png")
        print("BROOD_SHEET", c.name)
    bc.reset(rig)
