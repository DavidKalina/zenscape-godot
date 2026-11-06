"""Build the steam train's models: a classic western train, chunky and painted.

    python3 tools/blender.py run art/blender/train/train_build.py [-- --fast] [--only=engine,tender] [--render]

Writes assets/models/train/<kind>.glb for each kind (engine, tender, box, doors,
stock, flat, open, van so far), and
in assets/models/train/ the shared textures, shader and materials, and each
glb's .import, which points every material name at its .tres. Then reads each
glb back and proves it inside its car (exits 1 if not): no wider than WIDE,
nothing above TALL or its top, nothing under the rails' tops, nothing past its
coupler, and its openings (OPENINGS) clear. Every size is a
constant in the first block: a retune is an edit there, a rerun, then
`python3 tools/godot.py --import` (smoke and drive don't reimport a glb).
--fast halves the textures. --render also renders the train in Blender, to
art/blender/train/renders/ (git-ignored).

The spec: docs/design/endless-flight/spec-steam-train.md, "The cars". Each
model's frame is its car's in scripts/endless/rail_train.gd: origin at the car's
middle on the bed, forward Blender +Y (Godot -Z), up +Z (Godot +Y), 1 unit = 1 m.
Blender (x, y, z) is Godot (x, z, -y).

The look: black iron, a red wooden cab, brass trim, the wheel centres red. One
shared set of materials for every car, coloured by the vertex colours (paint,
then grime baked in: darker low down, soot and dust): `wood` painted timber
boards, `metal` painted iron, `iron` bare running gear, `brass`, `coal`,
`glass`, `lamp` (the headlamp's glow), `dark` (insides). Textures are painted
here in numpy, light toned for the vertex colours to tint; they tile in metres.

The moving parts are their own nodes, each with its origin where code turns it:
  engine  Driver_1 (front), Driver_2: an axle each, both wheels; turn about
          local X. The right crank pin is at angle 0 (CRANK m forward of the
          axle, level with it), the left a quarter turn on (above it): quartered.
          LeadTruck (swivels about Y on curves) holding Lead_1, Lead_2.
          SideRod_R/_L: origin midway between the pins at angle 0; it moves
          with the pins (translates round a circle of CRANK, never turns).
          MainRod_R/_L: origin on the rear driver's pin, the rod running forward
          to the crosshead; it moves with the pin and turns about X so its far
          end stays on the crosshead's line (MAIN_ROD m long).
          Crosshead_R/_L: slides along Y on the cylinder's line (CYL_Z), with the
          piston rod.
          StackMouth (empty): where the smoke starts. Steam_R/_L (empties): the
          cylinder cocks, where the steam at stops comes out.
  tender  Truck_F, Truck_R (swivel about Y), each holding two wheelsets
          (Wheels_F1, Wheels_F2, Wheels_R1, Wheels_R2) that turn about X.
  cars    The same trucks, BOGIE in from each end. The boxcars' doors Door_RF,
          Door_RB, Door_LF, Door_LB (R right, F the front half), each its origin
          at its middle, sliding along Y: shut on the box, open on doors and stock.
"""
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/train"
RES = "res://assets/models/train"
RENDERS = Path(__file__).resolve().parent / "renders"

# --- The numbers --------------------------------------------------------------

# The car's frame (scripts/endless/rail_train.gd): its width, floor over the bed,
# the gap to the next car, the tallest anything stands (the bores are sized on
# it: rail_bore_shape.gd CAR_TALL), and the rails (rail_track.gd: the rail's top
# over the bed, rail centre to rail centre).
WIDE = 6.0
FLOOR = 1.4
GAP = 1.6
TALL = 9.0
RAIL_TOP = 0.84
GAUGE = 3.0
WHEEL_X = GAUGE * 0.5     # each wheel's tread on its rail's centre line

# The engine: a 4-4-0. 22 m coupler face to cab back (y -11..11), the pilot on to
# PILOT_TIP. Its colliders today are rail_train.gd `_parts("engine")`; the build
# prints the model's parts so they can be matched.
ENGINE_LONG = 22.0
PILOT_TIP = 12.2
BOILER_R = 1.5
BOILER_Z = 4.6            # its axis over the bed
BOILER_Y = (-4.6, 6.8)    # into the cab, to the smokebox
SMOKEBOX_R = 1.6
SMOKEBOX_Y = (6.7, 9.9)
STACK_Y = 8.2
STACK_TOP = 8.5
STACK_R = 1.0             # the funnel's lip
BELL_Y = 5.6
SAND_Y = 3.4
DOME_Y = 0.8
CAB_Y = (-11.0, -4.0)
CAB_FLOOR = 2.3
CAB_EAVE = 7.55
CAB_TOP = 8.5
CAB_HALF = 2.87           # the cab's sides (its trim stands 0.1 proud); the roof's eaves reach EAVE_HALF
EAVE_HALF = 3.0
DRIVER_R = 1.45
DRIVER_Y = (0.6, -2.5)    # front, rear axle
LEAD_R = 0.6
LEAD_Y = (9.0, 5.2)
LEAD_PIVOT = 7.1
CRANK = 0.55              # crank pin off the axle
CYL_X = 2.0
CYL_Z = 2.25
CYL_R = 0.5
CYL_Y = (6.2, 8.2)
CROSSHEAD_Y = 5.4         # the right crosshead with its pin at angle 0
RUNNING_Z = 3.2
ROD_X = (1.86, 2.02)      # side rod, main rod: their middle planes

# The tender: 12 m (y -6..6), a water tank with the coal heaped forward.
TENDER_LONG = 12.0
TENDER_SILL = (1.7, 2.15)   # the frame's sills, over the trucks
TENDER_TANK_TOP = 4.6
TENDER_HALF = 2.88
COAL_TOP = 6.0
COAL_BACK = -1.0          # the bunker's back board; the water hatch aft of it
TRUCK_Y = 3.2             # each truck's pivot off the middle
TRUCK_BASE = 1.8          # axle to axle
CAR_WHEEL_R = 0.55

# The cars. Each sits on two trucks BOGIE m in from its ends (rail_train.gd BOGIE),
# its sides at CAR_HALF with trim, doors and grab irons proud of them up to WIDE.
# Their solids are rail_train.gd `_parts`: the models fill those blocks.
BOGIE = 3.0
CAR_HALF = 2.86
CAR_TILE = 5.6            # the cars' boards: 0.35 m each
PLANK_TILE = 8.0          # decks and floors: 0.5 m planks
COUPLER_Z = 1.22
BOX_LONG = 24.0           # box, doors, stock
BOX_EAVE = 8.5
BOX_RIDGE = 8.8
BOX_TOP = 9.0             # the running board's top
DOOR_LONG = 10.0          # the doorway: rail_train.gd door_wide (WorldScale.opening(TOY_DOOR)),
DOOR_HIGH = 6.0           # door_high (TOY_DOOR_HIGH) up from FLOOR; the doors are half its length each
DOOR_OVER = 0.3           # the doors stand this far over the doorway's head
SLAT = 0.75               # the stock car's slats, one every SLAT up its walls (rail_train.gd SLAT)
SLAT_GAP = 0.16
FLAT_LONG = 20.0
FLAT_TOP = 2.6            # the deck (rail_train.gd DECK)
SILL_END = 2.0            # a low car's side sills over its trucks (so they show), and the
SILL_BELLY = 1.15         # fishbelly between them
OPEN_LONG = 20.0          # the gondola: sides to OPEN_TOP on a floor at OPEN_FLOOR,
OPEN_TOP = 4.2
OPEN_FLOOR = 2.3
HEAP = 0.8                # its coal heaped HEAP over the sides, inset HEAP_IN of its width
HEAP_IN = 0.7             # and length (rail_train.gd HEAP, HEAP_IN)
VAN_LONG = 14.0           # the caboose: its body (rail_train.gd: 0.9 of WIDE across, to
VAN_HALF = 2.7            # VAN_TOP), end platforms VAN_PLATFORM long under the roof,
VAN_PLATFORM = 1.2
VAN_EAVE = 5.4
VAN_TOP = 5.7
CUPOLA_HALF = (1.65, 2.0) # the cupola's roof across and along, the eaves and top
CUPOLA_EAVE = 7.2
CUPOLA_TOP = 7.5

# Colours (sRGB): paint, then the grime pulls them down low on the car.
COL = {
	"black": "2a2c31", "cab": "93301f", "wheel": "9b3322", "brass": "c9a24c", "steel": "7a7d82",
	"iron": "38393c", "cream": "e9dcbd", "roof": "3a3633", "gold": "c7a14a", "glass": "2a3440",
	"coal": "ffffff", "dark": "17130f", "lamp": "ffe7b0", "pilot": "9e3221",
	# The cars: barn red as the towns' (rail_stops.gd ELEVATOR_C), the stock car a
	# browner red, the gondola oxide, the caboose a brighter red.
	"barn": "a84d3d", "stock": "8e4a32", "oxide": "6c372b", "van": "b23a24", "deck": "8c7356",
	"floor": "7d6449", "inside": "3a2b20", "marker": "ff4026",
}

TEX_SIZE = {"wood": 512, "metal": 256, "coal": 512}
TILE = {"wood": 4.0, "metal": 4.0, "coal": 2.5}

# Each material: its shader, albedo, normal, then uniforms. The game takes no
# ambient light, so these fill the shade from the sky's hemisphere as the land's
# own surfaces do (the pirate ship's way); the glb carries names only.
MATERIALS = {
	"wood": ("surface", "train_wood", "train_wood_n", {"normal_depth": 1.0, "roughness_value": 0.8, "fill": 5.0, "rim": 0.25}),
	"metal": ("surface", "train_metal", "train_metal_n", {"normal_depth": 0.12, "roughness_value": 0.42, "metallic_value": 0.15, "fill": 4.0, "rim": 0.35}),
	"iron": ("surface", "train_metal", None, {"roughness_value": 0.5, "metallic_value": 0.45, "fill": 3.0, "rim": 0.3}),
	"brass": ("surface", "train_metal", None, {"roughness_value": 0.32, "metallic_value": 0.75, "fill": 2.5, "rim": 0.4}),
	"coal": ("surface", "train_coal", "train_coal_n", {"normal_depth": 1.4, "roughness_value": 0.55, "metallic_value": 0.1, "fill": 3.0, "rim": 0.2}),
	"glass": ("surface", None, None, {"roughness_value": 0.12, "metallic_value": 0.3, "fill": 1.2, "rim": 0.5}),
	"dark": ("surface", None, None, {"roughness_value": 0.95, "fill": 0.6, "rim": 0.0}),
	"lamp": ("lamp", None, None, {}),
}
MAT_NAMES = tuple(MATERIALS)


def srgb(h):
	h = h.lstrip("#")
	c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


PAINT = {k: srgb(v) for k, v in COL.items()}

# --- Geometry -----------------------------------------------------------------


def sstep(a, b, x):
	t = min(1.0, max(0.0, (x - a) / (b - a)))
	return t * t * (3.0 - 2.0 * t)


def grime(p, dirt):
	"""The baked darkening: low down (road dust and oil), a faint mottle."""
	if dirt <= 0.0:
		return 1.0
	low = 0.68 + 0.32 * sstep(0.9, 4.2, p.z)
	mottle = 1.0 + 0.05 * math.sin(p.x * 1.7 + p.y * 0.61) * math.sin(p.y * 0.83 - p.z * 1.9)
	return 1.0 - dirt * (1.0 - low * mottle)


def newell(pts):
	"""A polygon's normal (unnormalised), its points anticlockwise round it."""
	n = Vector((0.0, 0.0, 0.0))
	for a, b in zip(pts, pts[1:] + pts[:1]):
		n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
	return n


class Geo:
	"""A mesh by hand. A vertex given no normal takes its faces' (shared ones
	shade smooth, unshared hard); lathes give theirs exactly."""

	def __init__(self, dirt=1.0):
		self.v, self.uv, self.c, self.n, self.f, self.m = [], [], [], [], [], []
		self.dirt = dirt

	def vert(self, p, uv, col, n=None):
		p = Vector(p)
		g = grime(p, self.dirt)
		self.v.append((p.x, p.y, p.z))
		self.uv.append(uv)
		self.c.append((col[0] * g, col[1] * g, col[2] * g))
		self.n.append(None if n is None else tuple(Vector(n).normalized()))
		return len(self.v) - 1

	def face(self, ids, mat):
		self.f.append(tuple(ids))
		self.m.append(mat)

	def poly(self, pts, mat, col, tile=None, rot=False, uvo=(0.0, 0.0)):
		"""A flat polygon, its points anticlockwise seen from its front; uvs
		projected on the box face it most looks along, in metres over the tile.
		rot swaps u and v (the wood's seams run across instead of up); uvo is
		added to them (to set a board's seams on its edges)."""
		pts = [Vector(p) for p in pts]
		nrm = newell(pts)
		t = tile or TILE.get(mat, 4.0)
		ax, ay, az = abs(nrm.x), abs(nrm.y), abs(nrm.z)
		if az >= ax and az >= ay:
			uvs = [(p.x / t, p.y / t) for p in pts]
		elif ax >= ay:
			uvs = [(p.y / t, p.z / t) for p in pts]
		else:
			uvs = [(p.x / t, p.z / t) for p in pts]
		if rot:
			uvs = [(v, u) for u, v in uvs]
		uvs = [(u + uvo[0], v + uvo[1]) for u, v in uvs]
		self.face([self.vert(p, uv, col) for p, uv in zip(pts, uvs)], mat)

	def facing(self, pts, out, mat, col, **kw):
		"""poly, its points turned so it faces along `out`."""
		pts = [Vector(p) for p in pts]
		if newell(pts).dot(Vector(out)) < 0.0:
			pts = pts[::-1]
		self.poly(pts, mat, col, **kw)

	def box(self, xa, xb, ya, yb, za, zb, mat, col, skip="", **kw):
		"""An axis box; skip any of its faces by letter: l r (x), b f (y), d u (z).
		Takes poly's tile, rot and uvo."""
		x0, x1 = sorted((xa, xb))
		y0, y1 = sorted((ya, yb))
		z0, z1 = sorted((za, zb))
		faces = {
			"l": ((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)),
			"r": ((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)),
			"b": ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)),
			"f": ((x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)),
			"d": ((x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)),
			"u": ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)),
		}
		for k, pts in faces.items():
			if k not in skip:
				self.poly(pts, mat, col, **kw)

	def beam(self, p0, p1, w, h, mat, col, up=(0.0, 0.0, 1.0)):
		"""A squared bar from p0 to p1, w across, h along `up`."""
		p0, p1 = Vector(p0), Vector(p1)
		d = (p1 - p0).normalized()
		u = Vector(up)
		if abs(d.dot(u)) > 0.98:
			u = Vector((1.0, 0.0, 0.0)) if abs(d.x) < 0.9 else Vector((0.0, 1.0, 0.0))
		s = u.cross(d).normalized() * (w * 0.5)
		u = d.cross(s).normalized() * (h * 0.5)
		c0 = [p0 - s - u, p0 + s - u, p0 + s + u, p0 - s + u]
		c1 = [p1 - s - u, p1 + s - u, p1 + s + u, p1 - s + u]
		for i in range(4):
			j = (i + 1) % 4
			self.poly([c0[i], c0[j], c1[j], c1[i]], mat, col)
		self.poly([c0[3], c0[2], c0[1], c0[0]], mat, col)
		self.poly([c1[0], c1[1], c1[2], c1[3]], mat, col)

	def lathe(self, o, axis, prof, mat, col, n=24, ref=None, a0=0.0, a1=math.tau, tile=None):
		"""Revolve prof [(r, h)] (h along the axis, from the bottom up; None for a
		hard crease) round the axis through o, a ring of n. Faces outward."""
		o, d = Vector(o), Vector(axis).normalized()
		ref = Vector(ref) if ref else (Vector((0.0, 0.0, 1.0)) if abs(d.z) < 0.9 else Vector((1.0, 0.0, 0.0)))
		s = (ref - d * ref.dot(d)).normalized()
		t = d.cross(s)
		tl = tile or TILE.get(mat, 4.0)
		strips, cur = [], []
		for p in prof:
			if p is None:
				strips.append(cur)
				cur = [cur[-1]]
			else:
				cur.append(p)
		strips.append(cur)
		rmax = max(p[0] for p in prof if p is not None)
		around = (a1 - a0) * rmax / tl
		for strip in strips:
			rings = []
			run = 0.0
			for i, (r, h) in enumerate(strip):
				if i:
					run += math.hypot(r - strip[i - 1][0], h - strip[i - 1][1])
				pa = strip[max(i - 1, 0)]
				pb = strip[min(i + 1, len(strip) - 1)]
				dr, dh = pb[0] - pa[0], pb[1] - pa[1]
				ring = []
				for k in range(n + 1):
					a = a0 + (a1 - a0) * k / n
					rad = s * math.cos(a) + t * math.sin(a)
					nv = rad * dh - d * dr
					ring.append(self.vert(o + d * h + rad * r, (around * k / n, run / tl), col, nv if nv.length > 1e-9 else d))
				rings.append((r, ring))
			for (ra, A), (rb, B) in zip(rings, rings[1:]):
				for k in range(n):
					if rb < 1e-6:
						self.face([A[k], A[k + 1], B[k]], mat)
					elif ra < 1e-6:
						self.face([A[k], B[k + 1], B[k]], mat)
					else:
						self.face([A[k], A[k + 1], B[k + 1], B[k]], mat)

	def disc(self, o, axis, r, mat, col, n=24, ref=None):
		"""A flat disc facing along `axis`."""
		self.lathe(o, axis, [(r, 0.0), (0.0, 0.0)], mat, col, n, ref)

	def sheet(self, xs, ys, fn, mat, col):
		"""A height field z = fn(x, y), shaded smooth."""
		ids = [[self.vert((x, y, fn(x, y)), (x / TILE.get(mat, 4.0), y / TILE.get(mat, 4.0)), col) for x in xs] for y in ys]
		for j in range(len(ys) - 1):
			for i in range(len(xs) - 1):
				self.face([ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]], mat)


# --- To Blender ---------------------------------------------------------------

STATS = {}


def emit(name, geo, mats, parent=None, origin=(0.0, 0.0, 0.0), group=None):
	"""The mesh as an object, its origin at `origin` (in the car's frame)."""
	o = Vector(origin)
	verts = [(v[0] - o.x, v[1] - o.y, v[2] - o.z) for v in geo.v]
	me = bpy.data.meshes.new(name)
	me.from_pydata(verts, [], geo.f)
	used = sorted(set(geo.m), key=MAT_NAMES.index)
	for m in used:
		me.materials.append(mats[m])
	me.polygons.foreach_set("material_index", [used.index(m) for m in geo.m])
	me.polygons.foreach_set("use_smooth", [True] * len(geo.f))
	layer = me.uv_layers.new(name="UVMap")
	lv = np.zeros(len(me.loops), dtype=np.int32)
	me.loops.foreach_get("vertex_index", lv)
	layer.uv.foreach_set("vector", np.array(geo.uv, dtype=np.float32)[lv].ravel())
	ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
	carr = np.ones((len(geo.v), 4), dtype=np.float32)
	carr[:, :3] = np.array(geo.c, dtype=np.float32)
	ca.data.foreach_set("color", carr.ravel())
	me.color_attributes.active_color = ca
	# The normals: the given ones, else the faces' round each vertex.
	acc = [Vector((0.0, 0.0, 0.0)) for _ in geo.v]
	for f in geo.f:
		pts = [Vector(geo.v[i]) for i in f]
		fn = (pts[1] - pts[0]).cross(pts[2] - pts[0])
		if len(pts) == 4:
			fn += (pts[2] - pts[0]).cross(pts[3] - pts[0])
		for i in f:
			acc[i] += fn
	nrm = []
	for i, given in enumerate(geo.n):
		v = Vector(given) if given is not None else acc[i]
		nrm.append(tuple(v.normalized()) if v.length > 1e-12 else (0.0, 0.0, 1.0))
	me.update()
	me.normals_split_custom_set_from_vertices(nrm)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	if parent is not None:
		ob.parent = parent
		ob.location = o - parent_world(parent)
	else:
		ob.location = o
	me.calc_loop_triangles()
	key = group or name
	STATS[key] = STATS.get(key, 0) + len(me.loop_triangles)
	return ob


def parent_world(ob):
	at = Vector((0.0, 0.0, 0.0))
	while ob is not None:
		at += ob.location
		ob = ob.parent
	return at


def empty(name, at, parent=None):
	ob = bpy.data.objects.new(name, None)
	bpy.context.scene.collection.objects.link(ob)
	ob.empty_display_size = 0.5
	if parent is not None:
		ob.parent = parent
		ob.location = Vector(at) - parent_world(parent)
	else:
		ob.location = at
	return ob


# --- Running gear -------------------------------------------------------------


def spoked_wheel(g, cx, y, z, r, side, spokes, crank=None, pin_out=0.0, counter=True, tyre_w=0.32):
	"""A wheel on the axle through (y, z), its tread on x = cx; `side` +1 for the
	right (its face out to +x). Steel tyre with its flange inboard, red centre,
	spokes, a counterweight opposite the crank pin at angle `crank` (radians,
	0 forward), the pin standing out pin_out m past the face."""
	ax = (1.0, 0.0, 0.0)
	hw = tyre_w * 0.5
	o = Vector((cx, y, z))
	ri = r * 0.82
	# Tyre: profile from the inboard face to the outboard face, measured along +x.
	lo, hi = -hw, hw
	if side > 0:
		prof = [(ri, lo), (r + 0.09, lo), None, (r + 0.09, lo + 0.05), None, (r, lo + 0.07), (r, hi), None, (ri, hi)]
	else:
		prof = [(ri, lo), (r, lo), None, (r, hi - 0.07), (r + 0.09, hi - 0.05), None, (r + 0.09, hi), None, (ri, hi)]
	g.lathe(o, ax, prof, "iron", PAINT["steel"], n=28)
	# The inside of the rim, facing the axle.
	g.lathe(o, ax, [(ri, hi * 0.6), (ri, lo * 0.6)], "metal", PAINT["wheel"], n=28)
	# Hub, its cap out at the face.
	face = side * hw
	g.lathe(o, ax, [(0.0, -hw - 0.06), (r * 0.25, -hw - 0.06), (r * 0.25, hw + 0.06), (0.0, hw + 0.06)], "metal", PAINT["wheel"], n=14)
	# Spokes, in the wheel's plane, a little in from both faces.
	for k in range(spokes):
		a = (k + 0.5) / spokes * math.tau
		d = Vector((0.0, math.cos(a), math.sin(a)))
		g.beam(o + d * (r * 0.22), o + d * (ri + 0.02), r * 0.085, tyre_w * 0.6, "metal", PAINT["wheel"], up=ax)
	if crank is not None and counter:
		# The counterweight: a slab across the spokes opposite the pin, an
		# annular sector from inner to outer, e thick either side of the plane.
		c = crank + math.pi
		e = hw * 0.55
		X = Vector((1.0, 0.0, 0.0))
		outer, inner = [], []
		for k in range(7):
			a = c - 0.6 + 1.2 * k / 6
			d = Vector((0.0, math.cos(a), math.sin(a)))
			outer.append(o + d * (ri - 0.02))
			inner.append(o + d * (r * 0.42))
		wc = PAINT["wheel"]
		for k in range(6):
			oa, ob, ia, ib = outer[k], outer[k + 1], inner[k], inner[k + 1]
			g.poly([oa + X * e, ob + X * e, ib + X * e, ia + X * e], "metal", wc)
			g.poly([ia - X * e, ib - X * e, ob - X * e, oa - X * e], "metal", wc)
			g.poly([oa - X * e, ob - X * e, ob + X * e, oa + X * e], "metal", wc)
			g.poly([ib - X * e, ia - X * e, ia + X * e, ib + X * e], "metal", wc)
		g.poly([outer[0] - X * e, outer[0] + X * e, inner[0] + X * e, inner[0] - X * e], "metal", wc)
		g.poly([inner[6] - X * e, inner[6] + X * e, outer[6] + X * e, outer[6] - X * e], "metal", wc)
	if crank is not None:
		# The crank pin's boss and the pin, out past the face.
		d = Vector((0.0, math.cos(crank), math.sin(crank)))
		at = o + d * CRANK
		g.lathe(at, ax, [(0.0, face - side * 0.02), (0.2, face - side * 0.02), (0.2, face + side * 0.1), (0.0, face + side * 0.1)] if side > 0 else
			[(0.0, face - 0.1), (0.2, face - 0.1), (0.2, face + 0.02), (0.0, face + 0.02)], "iron", PAINT["steel"], n=12)
		if pin_out > 0:
			a0, a1 = (face, face + side * pin_out) if side > 0 else (face - pin_out, face)
			g.lathe(at, ax, [(0.0, min(a0, a1)), (0.09, min(a0, a1)), (0.09, max(a0, a1)), (0.0, max(a0, a1))], "iron", PAINT["steel"], n=10)


def disc_wheel(g, cx, y, z, r, side, tyre_w=0.28):
	"""A small wheel: steel tyre with its flange inboard, a dished centre, a hub."""
	ax = (1.0, 0.0, 0.0)
	hw = tyre_w * 0.5
	o = Vector((cx, y, z))
	lo, hi = -hw, hw
	ri = r * 0.84
	if side > 0:
		prof = [(ri, lo), (r + 0.07, lo), None, (r + 0.07, lo + 0.04), None, (r, lo + 0.06), (r, hi), None, (ri, hi)]
	else:
		prof = [(ri, lo), (r, lo), None, (r, hi - 0.06), (r + 0.07, hi - 0.04), None, (r + 0.07, hi), None, (ri, hi)]
	g.lathe(o, ax, prof, "iron", PAINT["steel"], n=20)
	inner, outer = lo * 0.4, hi * 0.4
	g.lathe(o, ax, [(0.0, inner - 0.08), (r * 0.3, inner - 0.08), (ri, inner), None, (ri, outer), (r * 0.3, outer + 0.08), (0.0, outer + 0.08)], "iron", PAINT["iron"], n=20)


def wheelset(name, mats, parent, y, z, r, kind="disc", crank=0.0, pin_out=(0.0, 0.0), spokes=12, group=None):
	"""An axle and its two wheels, its origin on the axle (turns about X)."""
	g = Geo(dirt=0.6)
	for side in (1.0, -1.0):
		cx = side * WHEEL_X
		if kind == "disc":
			disc_wheel(g, cx, y, z, r, side)
		else:
			c = None if crank is None else (crank if side > 0 else crank + math.pi * 0.5)
			spoked_wheel(g, cx, y, z, r, side, spokes, crank=c, pin_out=pin_out[0 if side > 0 else 1])
	g.lathe((-WHEEL_X, y, z), (1.0, 0.0, 0.0), [(0.13, 0.0), (0.13, GAUGE)], "iron", PAINT["iron"], n=8)
	return emit(name, g, mats, parent=parent, origin=(0.0, y, z), group=group)


def pin_at(axle_y, axle_z, ang):
	return Vector((0.0, axle_y + CRANK * math.cos(ang), axle_z + CRANK * math.sin(ang)))


# --- The engine ---------------------------------------------------------------


def build_engine(mats):
	root = empty("Engine", (0.0, 0.0, 0.0))
	H = ENGINE_LONG * 0.5
	g = Geo()
	blk, cab, brass, iron, steel = PAINT["black"], PAINT["cab"], PAINT["brass"], PAINT["iron"], PAINT["steel"]
	ax_y = (0.0, 1.0, 0.0)
	# Frames: two bars the length of her, and the deck under the cab.
	for s in (-1, 1):
		g.box(s * 0.85, s * 1.15, -H, 10.4, 1.3, 2.3, "metal", iron)
	g.box(-CAB_HALF, CAB_HALF, CAB_Y[0], CAB_Y[1] + 0.6, 1.85, CAB_FLOOR, "metal", blk)
	# The buffer beam, red, and the deck before the smokebox.
	g.box(-2.7, 2.7, 10.4, 11.0, 1.3, 2.45, "wood", PAINT["pilot"])
	g.box(-2.2, 2.2, SMOKEBOX_Y[1] - 0.1, 10.4, 2.3, 2.45, "metal", blk)
	# Firebox between the drivers.
	g.box(-1.1, 1.1, -4.3, -1.3, 2.0, 3.6, "metal", blk)
	# Boiler, its brass bands, the smokebox and its door.
	g.lathe((0.0, BOILER_Y[0], BOILER_Z), ax_y, [(BOILER_R, 0.0), (BOILER_R, BOILER_Y[1] - BOILER_Y[0])], "metal", blk, n=32)
	for y in (-3.2, -0.9, 2.4, 4.7, 6.45):
		g.lathe((0.0, y, BOILER_Z), ax_y, [(BOILER_R - 0.02, -0.07), (BOILER_R + 0.035, -0.06), (BOILER_R + 0.035, 0.06), (BOILER_R - 0.02, 0.07)], "brass", brass, n=32)
	sb0, sb1 = SMOKEBOX_Y
	g.lathe((0.0, sb0, BOILER_Z), ax_y, [(BOILER_R - 0.05, 0.0), (SMOKEBOX_R, 0.0), None, (SMOKEBOX_R, sb1 - sb0), None, (SMOKEBOX_R * 0.86, sb1 - sb0)], "metal", blk, n=32)
	g.lathe((0.0, sb1, BOILER_Z), ax_y, [(SMOKEBOX_R * 0.86, 0.0), (SMOKEBOX_R * 0.84, 0.08), None, (SMOKEBOX_R * 0.8, 0.08), (SMOKEBOX_R * 0.6, 0.16), (0.0, 0.2)], "metal", blk, n=32)
	g.lathe((0.0, sb1, BOILER_Z), ax_y, [(SMOKEBOX_R * 0.8, 0.0), (SMOKEBOX_R * 0.86, 0.03), (SMOKEBOX_R * 0.86, 0.1), (SMOKEBOX_R * 0.8, 0.12)], "brass", brass, n=32)
	# The door's middle: a boss and its handle across, and the hinge straps.
	g.lathe((0.0, sb1 + 0.18, BOILER_Z), ax_y, [(0.0, 0.0), (0.2, 0.0), (0.2, 0.12), (0.0, 0.16)], "brass", brass, n=14)
	g.beam((-0.55, sb1 + 0.36, BOILER_Z + 0.05), (0.55, sb1 + 0.36, BOILER_Z - 0.05), 0.07, 0.07, "brass", brass, up=(0.0, 1.0, 0.0))
	for dz in (-0.6, 0.6):
		g.box(-SMOKEBOX_R * 0.75, 0.0, sb1 + 0.12, sb1 + 0.17, BOILER_Z + dz - 0.06, BOILER_Z + dz + 0.06, "iron", iron)
	# The saddle down to the cylinders.
	g.box(-1.6, 1.6, sb0 + 0.1, sb0 + 1.9, 1.9, BOILER_Z - 1.0, "metal", blk)
	# The funnel stack: a column flaring to a wide lip, its mouth dark.
	top = STACK_TOP
	base = BOILER_Z + SMOKEBOX_R - 0.05
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [
		(0.66, -0.3), (0.66, 0.12), None, (0.66, 0.2), (0.44, 0.32), None, (0.42, 0.32), (0.42, 0.95),
		(0.5, 1.2), (0.72, 1.55), (0.9, 1.85), (STACK_R, top - base - 0.2), None, (STACK_R + 0.05, top - base - 0.2),
		(STACK_R + 0.05, top - base), None, (STACK_R - 0.08, top - base), (STACK_R - 0.12, top - base - 0.25)], "metal", blk, n=28)
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [(STACK_R - 0.12, top - base - 0.25), (0.0, top - base - 0.5)], "dark", PAINT["dark"], n=28)
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [(0.425, 0.95), (0.45, 0.97), (0.45, 1.07), (0.44, 1.1)], "brass", brass, n=24)
	# Headlamp: a big box lamp on a bracket over the smokebox's front.
	lz = BOILER_Z + SMOKEBOX_R - 0.15
	g.box(-0.42, 0.42, 9.15, 10.0, lz - 0.05, lz + 0.25, "metal", blk)
	g.box(-0.62, 0.62, 9.0, 10.15, lz + 0.25, lz + 1.45, "metal", blk, skip="f")
	g.box(-0.63, 0.63, 9.15, 10.0, lz + 0.42, lz + 1.28, "wood", cab)
	g.box(-0.75, 0.75, 8.9, 10.3, lz + 1.45, lz + 1.56, "metal", blk)
	g.lathe((0.0, 9.55, lz + 1.56), (0.0, 0.0, 1.0), [(0.14, 0.0), (0.14, 0.28), None, (0.24, 0.28), (0.24, 0.36), (0.0, 0.4)], "metal", blk, n=10)
	lens_z = lz + 0.85
	g.lathe((0.0, 10.15, lens_z), ax_y, [(0.58, 0.0), (0.58, 0.06), None, (0.44, 0.08), None, (0.42, 0.0)], "brass", brass, n=24)
	g.lathe((0.0, 10.15, lens_z), ax_y, [(0.42, 0.0), (0.3, 0.04), (0.0, 0.06)], "lamp", PAINT["lamp"], n=24)
	g.box(-0.6, 0.6, 10.12, 10.15, lz + 0.25, lz + 1.45, "metal", blk)
	# The bell in its yoke.
	bz = BOILER_Z + BOILER_R - 0.05
	for s in (-1, 1):
		g.box(s * 0.5, s * 0.6, BELL_Y - 0.08, BELL_Y + 0.08, bz - 0.1, bz + 1.0, "brass", brass)
	g.box(-0.6, 0.6, BELL_Y - 0.08, BELL_Y + 0.08, bz + 0.92, bz + 1.02, "brass", brass)
	g.lathe((0.0, BELL_Y, bz), (0.0, 0.0, 1.0), [(0.47, 0.22), (0.47, 0.3), (0.38, 0.42), (0.3, 0.62), (0.26, 0.82), (0.2, 0.92), (0.0, 0.96)], "brass", brass, n=20)
	g.lathe((0.0, BELL_Y, bz), (0.0, 0.0, 1.0), [(0.0, 0.25), (0.45, 0.25)], "dark", PAINT["dark"], n=20)
	# Sand dome and steam dome, black with brass caps; the whistle.
	def dome(y, foot, rr, h, cap):
		zfoot = BOILER_Z + math.sqrt(max(BOILER_R ** 2 - foot ** 2, 0.0)) - bz
		g.lathe((0.0, y, bz), (0.0, 0.0, 1.0), [(foot, zfoot - 0.02), (foot * 0.95, 0.02), (rr, 0.2), (rr, cap)], "metal", blk, n=28)
		g.lathe((0.0, y, bz), (0.0, 0.0, 1.0), [(rr + 0.03, cap - 0.02), (rr + 0.03, cap + 0.06), None, (rr, cap + 0.06), (rr * 0.88, h - 0.2), (rr * 0.6, h - 0.06), (0.0, h)], "brass", brass, n=28)
	dome(SAND_Y, 0.9, 0.66, 0.92, 0.55)
	dome(DOME_Y, 1.05, 0.8, 1.27, 0.78)
	g.lathe((0.0, CAB_Y[1] + 0.35, bz - 0.15), (0.0, 0.0, 1.0), [(0.07, 0.0), (0.07, 0.4), None, (0.14, 0.4), (0.14, 0.8), (0.0, 0.85)], "brass", brass, n=12)
	# Cylinders, their steam chests, the guide bars.
	c0, c1 = CYL_Y
	for s in (-1, 1):
		x = s * CYL_X
		g.lathe((x, c0, CYL_Z), ax_y, [(0.0, -0.06), (CYL_R + 0.03, -0.06), (CYL_R + 0.03, 0.12), None, (CYL_R, 0.12), (CYL_R, c1 - c0 - 0.12), None, (CYL_R + 0.03, c1 - c0 - 0.12), (CYL_R + 0.03, c1 - c0 + 0.06), (0.0, c1 - c0 + 0.06)], "metal", blk, n=20)
		for yy in (c0 - 0.06, c1 + 0.06):
			g.lathe((x, yy, CYL_Z), ax_y, [(CYL_R + 0.035, -0.03), (CYL_R + 0.035, 0.03)], "brass", brass, n=20)
		g.box(x - 0.36, x + 0.36, c0 + 0.12, c1 - 0.12, CYL_Z + CYL_R - 0.05, CYL_Z + CYL_R + 0.38, "metal", blk)
		g.box(x - 0.39, x + 0.39, c0 + 0.08, c1 - 0.08, CYL_Z + CYL_R + 0.38, CYL_Z + CYL_R + 0.44, "brass", brass)
		g.box(s * 1.15, s * (CYL_X - 0.3), c0 + 0.3, c1 - 0.3, CYL_Z - 0.3, CYL_Z + 0.35, "metal", blk)
		for dz in (-0.2, 0.2):
			g.box(x - 0.06, x + 0.06, 4.0, c0, CYL_Z + dz - 0.05, CYL_Z + dz + 0.05, "iron", steel)
		g.box(x - 0.1, x + 0.1, 3.95, 4.15, CYL_Z - 0.34, CYL_Z + 0.34, "iron", steel)
	# Running boards over the drivers, their splashers, the handrails.
	for s in (-1, 1):
		x0, x1 = s * 1.4, s * 2.42
		g.box(x0, x1, CAB_Y[1], c0 + 0.1, RUNNING_Z - 0.06, RUNNING_Z + 0.06, "metal", blk)
		g.box(x1 - s * 0.04, x1, CAB_Y[1], c0 + 0.1, RUNNING_Z - 0.26, RUNNING_Z - 0.06, "wood", PAINT["pilot"])
		g.box(x0, x1, c0 + 0.1, SMOKEBOX_Y[1] - 0.1, CYL_Z + CYL_R + 0.44, CYL_Z + CYL_R + 0.52, "metal", blk)
		for dy in DRIVER_Y:
			splasher(g, s, dy)
		hx = s * (BOILER_R + 0.16)
		hz = BOILER_Z + 0.55
		g.beam((hx, CAB_Y[1], hz), (hx, SMOKEBOX_Y[1] - 0.2, hz), 0.06, 0.06, "brass", brass)
		for y in (CAB_Y[1] + 1.6, 1.8, 4.2, 7.6):
			g.beam((s * (BOILER_R - 0.05), y, hz), (hx, y, hz), 0.05, 0.05, "iron", steel)
	# The pilot: red slats raked down from the beam to a V at the rails.
	top_z, foot_z, back = 2.3, 0.98, 11.0
	reach = PILOT_TIP - back
	half = 2.6
	for i in range(-7, 8):
		x = i * half / 7.4
		yb = back + (reach - 0.1) * (1.0 - abs(x) / half)
		g.beam((x, back, top_z), (x, yb, foot_z), 0.13, 0.11, "wood", PAINT["pilot"], up=(0.0, 1.0, 1.0))
	for s in (-1, 1):
		g.beam((s * half, back + 0.02, foot_z), (0.0, PILOT_TIP - 0.1, foot_z), 0.16, 0.14, "metal", iron)
		g.beam((s * half, back + 0.05, top_z), (s * half, back + 0.05, foot_z), 0.14, 0.14, "metal", iron)
	g.beam((0.0, back, top_z), (0.0, PILOT_TIP - 0.08, foot_z), 0.16, 0.16, "metal", iron, up=(1.0, 0.0, 0.0))
	g.box(-2.6, 2.6, back, back + 0.14, top_z - 0.12, top_z + 0.02, "metal", iron)
	build_cab(g)
	emit("Body", g, mats, parent=root, group="engine body")
	# The leading truck and its wheels.
	truck = empty("LeadTruck", (0.0, LEAD_PIVOT, RAIL_TOP + LEAD_R), parent=root)
	tg = Geo(dirt=0.8)
	lz = RAIL_TOP + LEAD_R
	for s in (-1, 1):
		x = s * (WHEEL_X + 0.32)
		tg.box(x - 0.08, x + 0.08, LEAD_Y[1] - 0.5, LEAD_Y[0] + 0.5, lz - 0.1, lz + 0.18, "metal", iron)
		for y in LEAD_Y:
			tg.box(x - 0.14, x + 0.14, y - 0.22, y + 0.22, lz - 0.22, lz + 0.22, "metal", iron)
	tg.box(-1.0, 1.0, LEAD_PIVOT - 0.35, LEAD_PIVOT + 0.35, lz + 0.05, lz + 0.4, "metal", iron)
	tg.box(-WHEEL_X - 0.3, WHEEL_X + 0.3, LEAD_PIVOT - 0.18, LEAD_PIVOT + 0.18, lz - 0.05, lz + 0.2, "metal", iron)
	emit("LeadTruckFrame", tg, mats, parent=truck, origin=(0.0, LEAD_PIVOT, lz), group="engine running gear")
	for i, y in enumerate(LEAD_Y):
		wheelset(f"Lead_{i + 1}", mats, truck, y, lz, LEAD_R, kind="spoked", crank=None, spokes=10, group="engine running gear")
	# Drivers: quartered, the pins out to carry the rods.
	dz = RAIL_TOP + DRIVER_R
	for i, y in enumerate(DRIVER_Y):
		out = 0.42 if i == 1 else 0.28
		wheelset(f"Driver_{i + 1}", mats, root, y, dz, DRIVER_R, kind="spoked", crank=0.0, pin_out=(out, out), spokes=14, group="engine running gear")
	# The rods at angle 0, each side's pins a quarter turn apart.
	for side, ang, tag in ((1.0, 0.0, "R"), (-1.0, math.pi * 0.5, "L")):
		pf, pr = pin_at(DRIVER_Y[0], dz, ang), pin_at(DRIVER_Y[1], dz, ang)
		xs = side * ROD_X[0]
		rg = Geo(dirt=0.3)
		a, b = Vector((xs, pr.y, pr.z)), Vector((xs, pf.y, pf.z))
		rg.beam(a, b, 0.12, 0.24, "iron", PAINT["steel"])
		for p in (a, b):
			rg.lathe(p - Vector((0.07, 0, 0)), (1.0, 0.0, 0.0), [(0.0, 0.0), (0.24, 0.0), (0.24, 0.14), (0.0, 0.14)], "iron", PAINT["steel"], n=12)
		emit(f"SideRod_{tag}", rg, mats, parent=root, origin=(a + b) * 0.5, group="engine running gear")
		# The crosshead on the cylinder's line, the main rod from the rear pin to it.
		xm = side * ROD_X[1]
		ych = pr.y + math.sqrt(MAIN_ROD ** 2 - (CYL_Z - pr.z) ** 2)
		ch = Geo(dirt=0.3)
		x = side * CYL_X
		ch.box(x - 0.09, x + 0.09, ych - 0.3, ych + 0.3, CYL_Z - 0.15, CYL_Z + 0.15, "iron", PAINT["steel"])
		ch.lathe((x, ych + 0.3, CYL_Z), ax_y, [(0.08, 0.0), (0.08, PISTON_ROD)], "iron", PAINT["steel"], n=8)
		emit(f"Crosshead_{tag}", ch, mats, parent=root, origin=(x, ych, CYL_Z), group="engine running gear")
		mg = Geo(dirt=0.3)
		p0, p1 = Vector((xm, pr.y, pr.z)), Vector((xm, ych, CYL_Z))
		mg.beam(p0, p1, 0.12, 0.26, "iron", PAINT["steel"])
		mg.lathe(p0 - Vector((0.07, 0, 0)), (1.0, 0.0, 0.0), [(0.0, 0.0), (0.27, 0.0), (0.27, 0.14), (0.0, 0.14)], "iron", PAINT["steel"], n=12)
		mg.lathe(p1 - Vector((0.07, 0, 0)), (1.0, 0.0, 0.0), [(0.0, 0.0), (0.18, 0.0), (0.18, 0.14), (0.0, 0.14)], "iron", PAINT["steel"], n=10)
		emit(f"MainRod_{tag}", mg, mats, parent=root, origin=p0, group="engine running gear")
	# The anchors for code.
	empty("StackMouth", (0.0, STACK_Y, STACK_TOP), parent=root)
	for side, tag in ((1.0, "R"), (-1.0, "L")):
		empty(f"Steam_{tag}", (side * CYL_X, CYL_Y[1] + 0.1, CYL_Z - CYL_R - 0.05), parent=root)
	return root


PISTON_ROD = 1.9          # the piston rod, forward of the crosshead (into the cylinder at either end of the stroke)
MAIN_ROD = math.hypot(CROSSHEAD_Y - (DRIVER_Y[1] + CRANK), CYL_Z - (RAIL_TOP + DRIVER_R))


def splasher(g, s, ay):
	"""A curved cover over a driver where it rises through the running board."""
	az = RAIL_TOP + DRIVER_R
	rr = DRIVER_R + 0.12
	if az + rr <= RUNNING_Z + 0.06:
		return
	lim = math.asin(min(1.0, (RUNNING_Z - az) / rr))
	a0, a1 = lim, math.pi - lim
	n = 12
	xi, xo = s * (WHEEL_X - 0.24), s * (WHEEL_X + 0.24)
	arc = [Vector((0.0, ay + rr * math.cos(a0 + (a1 - a0) * k / n), az + rr * math.sin(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]
	blk = PAINT["black"]
	for a, b in zip(arc, arc[1:]):
		q = [Vector((xi, a.y, a.z)), Vector((xi, b.y, b.z)), Vector((xo, b.y, b.z)), Vector((xo, a.y, a.z))]
		g.poly(q if s > 0 else q[::-1], "metal", blk)
	for x, plus in ((xo, s > 0), (xi, s < 0)):
		pts = [Vector((x, p.y, p.z)) for p in arc]
		mid = Vector((x, ay, RUNNING_Z))
		for a, b in zip(pts, pts[1:]):
			tri = [mid, a, b] if plus else [mid, b, a]
			g.poly(tri, "metal", blk)
	# A brass beading round the outer edge.
	for a, b in zip(arc, arc[1:]):
		g.beam(Vector((xo, a.y, a.z)), Vector((xo, b.y, b.z)), 0.05, 0.05, "brass", PAINT["brass"], up=(1.0, 0.0, 0.0))


def build_cab(g):
	"""The tall wooden cab: red boards, cream trim, dark glass, an arched roof."""
	y0, y1 = CAB_Y
	cab, cream, glass = PAINT["cab"], PAINT["cream"], PAINT["glass"]
	w = CAB_HALF
	t = 0.14
	# Walls: the sides, the front round the boiler, the back.
	for s in (-1, 1):
		g.box(s * (w - t), s * w, y0, y1, CAB_FLOOR, CAB_EAVE, "wood", cab)
	g.box(-w, w, y1 - t, y1, CAB_FLOOR, CAB_EAVE, "wood", cab, skip="b")
	g.box(-w, w, y0, y0 + t, CAB_FLOOR, CAB_EAVE, "wood", cab, skip="f")
	# Side windows: glass panes, cream frames, a sill band and the corner posts.
	wz0, wz1 = 5.0, 6.85
	for s in (-1, 1):
		x = s * (w + 0.012)
		for wy0, wy1 in ((-6.7, -5.0), (-8.8, -7.1)):
			q = [Vector((x, wy0, wz0)), Vector((x, wy1, wz0)), Vector((x, wy1, wz1)), Vector((x, wy0, wz1))]
			g.poly(q if s > 0 else q[::-1], "glass", glass)
			xf = s * (w + 0.04)
			for a, b in (((wy0, wz0), (wy1, wz0)), ((wy0, wz1), (wy1, wz1)), ((wy0, wz0), (wy0, wz1)), ((wy1, wz0), (wy1, wz1)), (((wy0 + wy1) * 0.5, wz0), ((wy0 + wy1) * 0.5, wz1))):
				g.beam((xf, a[0], a[1]), (xf, b[0], b[1]), 0.1, 0.1, "wood", cream, up=(1.0, 0.0, 0.0))
		# The doorway aft, dark, framed.
		q = [Vector((x, -10.65, CAB_FLOOR + 0.25)), Vector((x, -9.2, CAB_FLOOR + 0.25)), Vector((x, -9.2, wz1)), Vector((x, -10.65, wz1))]
		g.poly(q if s > 0 else q[::-1], "dark", PAINT["dark"])
		xf = s * (w + 0.04)
		for a, b in (((-10.65, CAB_FLOOR + 0.25), (-10.65, wz1)), ((-9.2, CAB_FLOOR + 0.25), (-9.2, wz1)), ((-10.65, wz1), (-9.2, wz1))):
			g.beam((xf, a[0], a[1]), (xf, b[0], b[1]), 0.12, 0.12, "wood", cream, up=(1.0, 0.0, 0.0))
		# Sill band, eave band, corner posts.
		g.box(s * w, s * (w + 0.05), y0, y1, wz0 - 0.32, wz0 - 0.18, "wood", cream)
		g.box(s * w, s * (w + 0.05), y0, y1, CAB_EAVE - 0.22, CAB_EAVE - 0.08, "wood", cream)
		for y in (y0 + 0.07, y1 - 0.07):
			g.box(s * (w - 0.02), s * (w + 0.05), y - 0.09, y + 0.09, CAB_FLOOR, CAB_EAVE, "wood", cream)
	# Front windows either side of the boiler, and the back's.
	for yf, face in ((y1 + 0.012, 1.0), (y0 - 0.012, -1.0)):
		for s in (-1, 1):
			xa, xb = sorted((s * 1.72, s * 2.55))
			q = [Vector((xa, yf, 5.35)), Vector((xa, yf, 6.85)), Vector((xb, yf, 6.85)), Vector((xb, yf, 5.35))]
			g.poly(q if face > 0 else q[::-1], "glass", glass)
			yy = yf + face * 0.03
			for a, b in (((xa, 5.35), (xb, 5.35)), ((xa, 6.85), (xb, 6.85)), ((xa, 5.35), (xa, 6.85)), ((xb, 5.35), (xb, 6.85))):
				g.beam((a[0], yy, a[1]), (b[0], yy, b[1]), 0.1, 0.1, "wood", cream, up=(0.0, 1.0, 0.0))
	# The roof: an arc through the eaves and the crown, a little proud all round.
	rise = CAB_TOP - CAB_EAVE
	R = (EAVE_HALF ** 2 + rise ** 2) / (2.0 * rise)
	cz = CAB_TOP - R
	half_ang = math.asin(EAVE_HALF / R)
	n = 14
	ry0, ry1 = y0 - 0.3, y1 + 0.25
	thick = 0.14
	top_pts, bot_pts = [], []
	for k in range(n + 1):
		a = -half_ang + 2.0 * half_ang * k / n
		d = Vector((math.sin(a), 0.0, math.cos(a)))
		top_pts.append(Vector((0.0, 0.0, cz)) + d * R)
		bot_pts.append(Vector((0.0, 0.0, cz)) + d * (R - thick))
	roof = PAINT["roof"]
	tl = TILE["metal"]
	for pts, sgn in ((top_pts, 1.0), (bot_pts, -1.0)):
		row0 = [g.vert((p.x, ry0, p.z), (p.x / tl, ry0 / tl), roof, (p - Vector((0, 0, cz))) * sgn) for p in pts]
		row1 = [g.vert((p.x, ry1, p.z), (p.x / tl, ry1 / tl), roof, (p - Vector((0, 0, cz))) * sgn) for p in pts]
		for k in range(n):
			if sgn > 0:
				g.face([row0[k], row0[k + 1], row1[k + 1], row1[k]], "metal")
			else:
				g.face([row0[k + 1], row0[k], row1[k], row1[k + 1]], "metal")
	for y, sgn in ((ry0, -1.0), (ry1, 1.0)):
		for k in range(n):
			q = [Vector((top_pts[k].x, y, top_pts[k].z)), Vector((top_pts[k + 1].x, y, top_pts[k + 1].z)), Vector((bot_pts[k + 1].x, y, bot_pts[k + 1].z)), Vector((bot_pts[k].x, y, bot_pts[k].z))]
			g.poly(q if sgn > 0 else q[::-1], "metal", roof)
	for k, sgn in ((0, -1.0), (n, 1.0)):
		q = [Vector((top_pts[k].x, ry0, top_pts[k].z)), Vector((top_pts[k].x, ry1, top_pts[k].z)), Vector((bot_pts[k].x, ry1, bot_pts[k].z)), Vector((bot_pts[k].x, ry0, bot_pts[k].z))]
		g.poly(q if sgn < 0 else q[::-1], "metal", roof)
	# A gable under the arc front and back, red boards up to the roof.
	for y, sgn in ((y1, 1.0), (y0, -1.0)):
		pts = [Vector((p.x * (w / EAVE_HALF), y, p.z - thick)) for p in top_pts]
		mid = Vector((0.0, y, CAB_EAVE - 0.05))
		for a, b in zip(pts, pts[1:]):
			g.poly([mid, a, b] if sgn > 0 else [mid, b, a], "wood", cab)


# --- The tender ---------------------------------------------------------------


def build_tender(mats):
	root = empty("Tender", (0.0, 0.0, 0.0))
	H = TENDER_LONG * 0.5
	g = Geo()
	blk, gold, iron = PAINT["black"], PAINT["gold"], PAINT["iron"]
	w = TENDER_HALF
	# The frame's sills, the tank, its rolled top edge.
	g.box(-w + 0.1, w - 0.1, -H, H, TENDER_SILL[0], TENDER_SILL[1], "metal", iron)
	g.box(-w, w, -H + 0.08, H - 0.1, TENDER_SILL[1], TENDER_TANK_TOP, "metal", blk)
	# Steps at the front corners, and the drawbar's pocket.
	for s in (-1, 1):
		g.box(s * (w - 0.5), s * (w - 0.05), H - 0.55, H - 0.1, TENDER_SILL[0] - 0.45, TENDER_SILL[0] - 0.37, "metal", iron)
		g.box(s * (w - 0.12), s * (w - 0.05), H - 0.55, H - 0.48, TENDER_SILL[0] - 0.45, TENDER_SILL[0], "metal", iron)
	g.box(-w - 0.06, w + 0.06, -H + 0.02, H - 0.04, TENDER_TANK_TOP - 0.12, TENDER_TANK_TOP + 0.02, "metal", blk)
	# The gold line round each side, and across the back.
	z0, z1, lw = TENDER_SILL[1] + 0.35, TENDER_TANK_TOP - 0.4, 0.09
	for s in (-1, 1):
		x = s * (w + 0.012)
		ya, yb = -H + 0.55, H - 0.6
		for (p, q) in (((ya, z0), (yb, z0)), ((ya, z1), (yb, z1)), ((ya, z0), (ya, z1)), ((yb, z0), (yb, z1))):
			g.beam((x, p[0], p[1]), (x, q[0], q[1]), 0.01, lw, "brass", gold, up=(0.0, 0.0, 1.0) if p[1] == q[1] else (0.0, 1.0, 0.0))
	yb = -H + 0.08 - 0.012
	for (p, q) in (((-w + 0.5, z0), (w - 0.5, z0)), ((-w + 0.5, z1), (w - 0.5, z1)), ((-w + 0.5, z0), (-w + 0.5, z1)), ((w - 0.5, z0), (w - 0.5, z1))):
		g.beam((p[0], yb, p[1]), (q[0], yb, q[1]), lw, 0.01, "brass", gold, up=(0.0, 1.0, 0.0))
	# Coal boards round the bunker, flared a little; its back board.
	cb = TENDER_TANK_TOP + 0.95
	for s in (-1, 1):
		x0 = s * (w - 0.06)
		x1 = s * (w + 0.04)
		g.box(x0, x1, COAL_BACK, H - 0.15, TENDER_TANK_TOP, cb, "metal", blk)
		g.box(x0 - s * 0.02, x1 + s * 0.04, COAL_BACK, H - 0.15, cb - 0.08, cb + 0.04, "brass", PAINT["brass"])
	g.box(-w + 0.04, w - 0.04, COAL_BACK - 0.12, COAL_BACK, TENDER_TANK_TOP, cb + 0.3, "metal", blk)
	# The front: the coal gate low, the shovel plate.
	g.box(-1.3, 1.3, H - 0.25, H - 0.1, TENDER_TANK_TOP - 0.2, TENDER_TANK_TOP + 0.35, "metal", blk)
	# The water hatch aft.
	hy = (-H + COAL_BACK) * 0.5
	g.lathe((0.0, hy, TENDER_TANK_TOP), (0.0, 0.0, 1.0), [(0.66, 0.0), (0.66, 0.22), None, (0.7, 0.22), (0.7, 0.3), (0.5, 0.34), (0.0, 0.36)], "metal", blk, n=20)
	g.lathe((0.0, hy, TENDER_TANK_TOP), (0.0, 0.0, 1.0), [(0.665, 0.12), (0.665, 0.2)], "brass", PAINT["brass"], n=20)
	g.box(-0.08, 0.08, hy + 0.7, hy + 0.95, TENDER_TANK_TOP + 0.25, TENDER_TANK_TOP + 0.45, "brass", PAINT["brass"])
	# The tank's top deck aft of the bunker.
	g.box(-w, w, -H + 0.08, COAL_BACK - 0.12, TENDER_TANK_TOP, TENDER_TANK_TOP + 0.04, "metal", iron)
	emit("Body", g, mats, parent=root, group="tender body")
	# The coal: a heap in the bunker, lumpy, with loose lumps on top.
	coal = Geo(dirt=0.0)
	rng = np.random.default_rng(7)
	jit = rng.uniform(-1.0, 1.0, 4096)

	def heap(x, y):
		ax_ = max(0.0, math.cos(math.pi * 0.5 * min(1.0, abs(x) / (w - 0.02)))) ** 0.7
		if y < 0.8:
			by = 0.55 + 0.45 * sstep(COAL_BACK, 0.8, y)
		elif y > 4.2:
			by = 1.0 - 0.7 * sstep(4.2, H - 0.15, y)
		else:
			by = 1.0
		k = int((x * 7.3 + 40.0) * 13.0 + (y * 5.1 + 40.0) * 7.0) % 4096
		lump = 0.07 * jit[k] + 0.05 * math.sin(x * 3.1 + y * 2.3) * math.sin(y * 3.7 - x * 1.3)
		return TENDER_TANK_TOP + 0.15 + (COAL_TOP - 0.12 - TENDER_TANK_TOP - 0.15) * ax_ * by + lump * ax_
	xs = [-w + 0.03 + (2 * w - 0.06) * i / 22 for i in range(23)]
	ys = [COAL_BACK + 0.01 + (H - 0.16 - COAL_BACK) * j / 26 for j in range(27)]
	coal.sheet(xs, ys, heap, "coal", PAINT["coal"])
	for i in range(40):
		x = rng.uniform(-w * 0.7, w * 0.7)
		y = rng.uniform(COAL_BACK + 0.4, H - 0.6)
		r = rng.uniform(0.12, 0.26)
		lump(coal, Vector((x, y, min(heap(x, y) - r * 0.2, COAL_TOP - r * 0.95))), r, rng)
	emit("Coal", coal, mats, parent=root, group="tender body")
	# The trucks: archbar sideframes, journal boxes, a bolster; disc wheels.
	trucks(root, mats, TRUCK_Y, "tender running gear")
	return root


def lump(g, c, r, rng):
	"""A coal lump: a squashed, jittered octahedron, hard faced."""
	pts = [Vector((1, 0, 0)), Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((0, 0, -1))]
	pts = [c + Vector((p.x * r * rng.uniform(0.7, 1.3), p.y * r * rng.uniform(0.7, 1.3), p.z * r * rng.uniform(0.5, 0.9))) for p in pts]
	for a, b, cc in ((0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)):
		g.poly([pts[a], pts[b], pts[cc]], "coal", PAINT["coal"])


def car_truck(g, ty, wz):
	"""A freight truck's frame round its two axles (the cars share it)."""
	iron = PAINT["iron"]
	hb = TRUCK_BASE * 0.5
	for s in (-1, 1):
		x = s * (WHEEL_X + 0.3)
		# Arch bars: a top bar arched over, a straight bottom bar, the journal boxes.
		g.beam((x, ty - hb - 0.3, wz + 0.22), (x, ty - 0.45, wz + 0.42), 0.1, 0.1, "metal", iron)
		g.beam((x, ty - 0.45, wz + 0.42), (x, ty + 0.45, wz + 0.42), 0.1, 0.1, "metal", iron)
		g.beam((x, ty + 0.45, wz + 0.42), (x, ty + hb + 0.3, wz + 0.22), 0.1, 0.1, "metal", iron)
		g.beam((x, ty - hb - 0.2, wz - 0.12), (x, ty - 0.45, wz - 0.32), 0.1, 0.1, "metal", iron)
		g.beam((x, ty - 0.45, wz - 0.32), (x, ty + 0.45, wz - 0.32), 0.1, 0.1, "metal", iron)
		g.beam((x, ty + 0.45, wz - 0.32), (x, ty + hb + 0.2, wz - 0.12), 0.1, 0.1, "metal", iron)
		for dy in (-hb, hb):
			g.box(x - 0.15, x + 0.15, ty + dy - 0.2, ty + dy + 0.2, wz - 0.17, wz + 0.26, "metal", iron)
		# The springs under the bolster's end.
		g.box(x - 0.14, x + 0.14, ty - 0.38, ty + 0.38, wz - 0.3, wz + 0.15, "metal", iron)
		g.box(x - 0.18, x + 0.18, ty - 0.45, ty - 0.33, wz - 0.32, wz + 0.42, "metal", iron)
		g.box(x - 0.18, x + 0.18, ty + 0.33, ty + 0.45, wz - 0.32, wz + 0.42, "metal", iron)
	g.box(-WHEEL_X - 0.3, WHEEL_X + 0.3, ty - 0.3, ty + 0.3, wz + 0.12, wz + 0.42, "metal", iron)


def trucks(root, mats, ty, group):
	"""A car's two trucks, their pivots ty either side of its middle: Truck_F and
	Truck_R (swivel about Y), each its frame and two wheelsets (turn about X)."""
	wz = RAIL_TOP + CAR_WHEEL_R
	for tag, y in (("F", ty), ("R", -ty)):
		truck = empty(f"Truck_{tag}", (0.0, y, wz), parent=root)
		tg = Geo(dirt=0.8)
		car_truck(tg, y, wz)
		emit(f"TruckFrame_{tag}", tg, mats, parent=truck, origin=(0.0, y, wz), group=group)
		for i, dy in enumerate((TRUCK_BASE * 0.5, -TRUCK_BASE * 0.5)):
			wheelset(f"Wheels_{tag}{i + 1}", mats, truck, y + dy, wz, CAR_WHEEL_R, kind="disc", group=group)


# --- The cars -----------------------------------------------------------------
#
# Every car shares the trucks (car_truck, disc wheelsets), the end beams and
# couplers, the materials and the cream trim. Their nodes: Body (the gondola's
# Coal too); Truck_F, Truck_R as the tender's; the boxcars' doors Door_RF, Door_RB,
# Door_LF, Door_LB (R the right side, F the front half), each its origin at its
# middle, sliding along Y: shut over the doorway on the box, slid open over the
# walls on the doors and stock cars.


def car_ends(g, H, z0, z1, col, half=CAR_HALF):
	"""Each end's beam across the car (z0..z1) and its coupler on a draft pocket,
	reaching into the gap short of its middle."""
	iron = PAINT["iron"]
	for s in (-1, 1):
		y = s * H
		g.box(-half, half, y - s * 0.3, y, z0, z1, "wood", col)
		if z0 > COUPLER_Z + 0.1:
			g.box(-0.36, 0.36, y - s * 0.6, y, COUPLER_Z - 0.16, z0, "metal", iron)
		g.box(-0.2, 0.2, y, y + s * 0.4, COUPLER_Z - 0.12, COUPLER_Z + 0.12, "metal", iron)
		g.box(-0.32, 0.32, y + s * 0.4, y + s * 0.68, COUPLER_Z - 0.24, COUPLER_Z + 0.2, "metal", iron)


def truss_rods(g, H, ztop):
	"""Under a long car's floor, between its trucks: the centre sill, and four
	rods down from over the trucks to two queen posts and a needle beam."""
	iron = PAINT["iron"]
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, ztop - 0.32, ztop, "metal", iron)
	ya = H - BOGIE - TRUCK_BASE * 0.5 - CAR_WHEEL_R - 0.3
	yq = ya * 0.36
	zq = 0.98
	for x in (-2.0, -0.85, 0.85, 2.0):
		pts = [(x, -ya, ztop - 0.06), (x, -yq, zq), (x, yq, zq), (x, ya, ztop - 0.06)]
		for a, b in zip(pts, pts[1:]):
			g.beam(a, b, 0.07, 0.07, "iron", iron)
		for y in (-yq, yq):
			g.box(x - 0.06, x + 0.06, y - 0.06, y + 0.06, zq - 0.06, ztop - 0.2, "metal", iron)
	for y in (-yq, yq):
		g.box(-2.3, 2.3, y - 0.14, y + 0.14, ztop - 0.24, ztop, "wood", PAINT["inside"])


def side_sills(g, H, top, col, xo=CAR_HALF + 0.08, depth=0.28):
	"""A low car's side sills: a fishbelly, shallow over the trucks (they show
	under it) and deep between them; the top at `top`, under the deck."""
	ty = H - BOGIE
	y1 = ty - TRUCK_BASE * 0.5 - CAR_WHEEL_R - 0.15
	y0 = max(y1 - 2.0, 0.5)
	pts = [(-H, SILL_END), (-y1, SILL_END), (-y0, SILL_BELLY), (y0, SILL_BELLY), (y1, SILL_END), (H, SILL_END)]
	for s in (-1, 1):
		xa, xb = s * xo, s * (xo - depth)
		for (ya, za), (yb, zb) in zip(pts, pts[1:]):
			g.facing([(xa, ya, za), (xa, yb, zb), (xa, yb, top), (xa, ya, top)], (s, 0, 0), "wood", col, tile=CAR_TILE)
			g.facing([(xb, ya, za), (xb, yb, zb), (xb, yb, top), (xb, ya, top)], (-s, 0, 0), "wood", col, tile=CAR_TILE)
			g.facing([(xa, ya, za), (xa, yb, zb), (xb, yb, zb), (xb, ya, za)], (0, -(zb - za) * 0.1, -1), "wood", col, tile=CAR_TILE)


def gable_roof(g, half, eave, ridge, y0, y1, col, gables=None, wall=None, wall_half=None, th=0.1):
	"""A shallow pitched roof over x +-half from its eaves to its ridge, y0..y1,
	th thick; under it the gables (at the y's in `gables`) in the wall's paint."""
	for s in (-1, 1):
		top = [(s * half, y0, eave), (s * half, y1, eave), (0.0, y1, ridge), (0.0, y0, ridge)]
		up = Vector((s * (ridge - eave), 0.0, half))
		g.facing(top, up, "metal", col)
		g.facing([(x, y, z - th) for x, y, z in top], -up, "metal", col)
		g.facing([(s * half, y0, eave - th), (s * half, y1, eave - th), (s * half, y1, eave), (s * half, y0, eave)], (s, 0, 0), "metal", col)
		for y, f in ((y0, -1), (y1, 1)):
			g.facing([(s * half, y, eave - th), (s * half, y, eave), (0.0, y, ridge), (0.0, y, ridge - th)], (0, f, 0), "metal", col)
	# Each gable from the wall's top (inside the roof's edge there) to under the ridge.
	for y in gables or ():
		f = 1 if y > 0 else -1
		g.facing([(-wall_half, y, eave), (wall_half, y, eave), (0.0, y, ridge - th)], (0, f, 0), "wood", wall, tile=CAR_TILE)


def ladder(g, x, ya, yb, za, zb, step=0.5):
	"""Grab irons up a car's side (x its face; they stand 0.1 off it)."""
	s = 1 if x > 0 else -1
	z = za
	while z <= zb + 1e-6:
		g.box(x, x + s * 0.1, ya, yb, z - 0.03, z + 0.03, "metal", PAINT["iron"])
		z += step


def window(g, x0, x1, y0, y1, z0, z1, out, frame=0.1, mullion=False):
	"""Dark glass in a cream frame on a wall face (the box x0..x1, y0..y1 is the
	pane, flat along `out`'s axis), the frame standing a little proud."""
	cream, glass = PAINT["cream"], PAINT["glass"]
	o = Vector(out)
	if abs(o.x) > 0.5:
		x = x0
		g.facing([(x, y0, z0), (x, y1, z0), (x, y1, z1), (x, y0, z1)], o, "glass", glass)
		xf = x + o.x * 0.03
		bars = [((y0, z0), (y1, z0)), ((y0, z1), (y1, z1)), ((y0, z0), (y0, z1)), ((y1, z0), (y1, z1))]
		if mullion:
			bars.append((((y0 + y1) * 0.5, z0), ((y0 + y1) * 0.5, z1)))
		for a, b in bars:
			g.beam((xf, a[0], a[1]), (xf, b[0], b[1]), frame, frame, "wood", cream, up=(1.0, 0.0, 0.0))
	else:
		y = y0
		g.facing([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], o, "glass", glass)
		yf = y + o.y * 0.03
		bars = [((x0, z0), (x1, z0)), ((x0, z1), (x1, z1)), ((x0, z0), (x0, z1)), ((x1, z0), (x1, z1))]
		if mullion:
			bars.append((((x0 + x1) * 0.5, z0), ((x0 + x1) * 0.5, z1)))
		for a, b in bars:
			g.beam((a[0], yf, a[1]), (b[0], yf, b[1]), frame, frame, "wood", cream, up=(0.0, 1.0, 0.0))


def corner_posts(g, half, ye, z0, z1, col, wide=0.2, proud=0.05):
	"""A post wrapping each of a body's four corners."""
	for sx in (-1, 1):
		for sy in (-1, 1):
			g.box(sx * (half - wide), sx * (half + proud), sy * (ye - wide), sy * (ye + proud), z0, z1, "wood", col)


def slats(g, x0, x1, y0, y1, z0, z1, col):
	"""Horizontal boards with gaps (SLAT apart) between z0 and z1 over the box
	x0..x1, y0..y1; their seams along them. Returns the top of the last board."""
	t = 16.0 * SLAT
	z = z0
	top = z0
	while z + SLAT - SLAT_GAP <= z1 + 1e-6:
		g.box(x0, x1, y0, y1, z, z + SLAT - SLAT_GAP, "wood", col, rot=True, tile=t, uvo=(0.08 / 16.0 - z0 / t, 0.0))
		top = z + SLAT - SLAT_GAP
		z += SLAT
	return top


def car_door(name, mats, root, s, ya, yb, col, slatted=False, group=None):
	"""A sliding door on side s (+1 the right) over ya..yb: boards (or slats on a
	dark back) in a cream frame with a Z brace; its origin at its middle."""
	g = Geo()
	za, zb = FLOOR + 0.04, FLOOR + DOOR_HIGH + DOOR_OVER
	x0, x1 = s * (CAR_HALF + 0.06), s * (CAR_HALF + 0.1)
	if slatted:
		g.box(x0, s * (CAR_HALF + 0.07), ya, yb, za, zb, "wood", PAINT["inside"])
		slats(g, s * (CAR_HALF + 0.07), x1, ya, yb, za, zb, col)
	else:
		g.box(x0, x1, ya, yb, za, zb, "wood", col, tile=CAR_TILE)
	cream = PAINT["cream"]
	xf0, xf1 = x1, s * (CAR_HALF + 0.135)
	fw = 0.2
	zm = (za + zb) * 0.5
	for z in (za, zm - fw * 0.5, zb - fw):
		g.box(xf0, xf1, ya, yb, z, z + fw, "wood", cream, rot=True)
	for y in (ya, yb - fw):
		g.box(xf0, xf1, y, y + fw, za + fw, zb - fw, "wood", cream)
	xm = (xf0 + xf1) * 0.5
	for a, b in (((ya + fw, za + fw), (yb - fw, zm - fw * 0.5)), ((ya + fw, zm + fw * 0.5), (yb - fw, zb - fw))):
		g.beam((xm, a[0], a[1]), (xm, b[0], b[1]), fw * 0.8, abs(xf1 - xf0), "wood", cream, up=(1.0, 0.0, 0.0))
	emit(name, g, mats, parent=root, origin=(s * (CAR_HALF + 0.09), (ya + yb) * 0.5, (za + zb) * 0.5), group=group)


def build_boxcar(mats, kind):
	"""The boxcars: `box` its doors shut, `doors` slid open, `stock` slatted with
	its doors open. The doorway (DOOR_LONG x DOOR_HIGH from FLOOR, across the car)
	is clear on the open ones: its floor, the walls' faces and the head lined dark."""
	root = empty(kind.capitalize(), (0.0, 0.0, 0.0))
	H = BOX_LONG * 0.5
	w = CAR_HALF
	paint = PAINT["stock"] if kind == "stock" else PAINT["barn"]
	cream, iron, inside = PAINT["cream"], PAINT["iron"], PAINT["inside"]
	d = DOOR_LONG * 0.5
	head = FLOOR + DOOR_HIGH
	ye = H - 0.12
	g = Geo()
	car_ends(g, H, 1.05, FLOOR, paint)
	truss_rods(g, H, FLOOR)
	spans = [(-ye, ye)] if kind == "box" else [(-ye, -d), (d, ye)]
	for ya, yb in spans:
		if kind == "stock":
			t = 0.16
			ia = ya + t if ya == -ye else ya
			ib = yb - t if yb == ye else yb
			g.box(-(w - t), w - t, ia, ib, FLOOR, BOX_EAVE, "wood", inside, skip="u" + ("f" if yb == -d else "") + ("b" if ya == d else ""))
			for s in (-1, 1):
				top = slats(g, s * (w - t), s * w, ya, yb, FLOOR, BOX_EAVE - 0.4, paint)
				g.box(s * (w - t), s * w, ya, yb, top + SLAT_GAP, BOX_EAVE, "wood", paint, tile=CAR_TILE)
			for end in (ya, yb):
				if abs(abs(end) - ye) < 1e-6:
					f = 1 if end > 0 else -1
					top = slats(g, -w, w, f * (ye - t), f * ye, FLOOR, BOX_EAVE - 0.4, paint)
					g.box(-w, w, f * (ye - t), f * ye, top + SLAT_GAP, BOX_EAVE, "wood", paint, tile=CAR_TILE)
		else:
			skip = "u" + ("f" if yb == -d else "") + ("b" if ya == d else "")
			g.box(-w, w, ya, yb, FLOOR, BOX_EAVE, "wood", paint, skip=skip, tile=CAR_TILE)
	if kind != "box":
		g.box(-w, w, -d, d, FLOOR - 0.18, FLOOR, "wood", PAINT["floor"], skip="bf", tile=PLANK_TILE)
		g.box(-w, w, -d, d, head, BOX_EAVE, "wood", paint, skip="bfud", tile=CAR_TILE)
		iw = w - 0.16 if kind == "stock" else w
		for y, f in ((-d, 1), (d, -1)):
			g.facing([(-iw, y, FLOOR), (iw, y, FLOOR), (iw, y, head), (-iw, y, head)], (0, f, 0), "wood", inside)
		g.facing([(-w, -d, head), (w, -d, head), (w, d, head), (-w, d, head)], (0, 0, -1), "wood", inside)
	# Trim: corner posts and an eave band in cream, an iron sill band, the door
	# track, ladders by each end.
	corner_posts(g, w, ye, FLOOR, BOX_EAVE, cream)
	for s in (-1, 1):
		g.box(s * w, s * (w + 0.05), -ye, ye, BOX_EAVE - 0.38, BOX_EAVE - 0.08, "wood", cream, rot=True)
		for ya, yb in spans:
			g.box(s * w, s * (w + 0.05), ya, yb, FLOOR, FLOOR + 0.22, "metal", iron)
		g.box(s * w, s * (w + 0.12), -2 * d - 0.3, 2 * d + 0.3, head + DOOR_OVER + 0.02, head + DOOR_OVER + 0.16, "metal", iron)
		for sy in (-1, 1):
			ya, yb = sorted((sy * (ye - 0.85), sy * (ye - 0.3)))
			ladder(g, s * w, ya, yb, FLOOR + 0.55, BOX_EAVE - 0.6)
	# The roof: tin over boards, ribbed, a running board along its ridge; the
	# brake wheel over the back end.
	roof = PAINT["roof"]
	gable_roof(g, WIDE * 0.5 - 0.02, BOX_EAVE, BOX_RIDGE, -H + 0.02, H - 0.02, roof, gables=(-ye, ye), wall=paint, wall_half=w)
	y = -H + 0.9
	while y < H - 0.5:
		for s in (-1, 1):
			g.beam((s * (WIDE * 0.5 - 0.05), y, BOX_EAVE + 0.01), (0.0, y, BOX_RIDGE + 0.01), 0.09, 0.07, "metal", roof)
		y += 1.5
	for y in range(-10, 11, 4):
		g.box(-0.3, 0.3, y - 0.08, y + 0.08, BOX_RIDGE - 0.04, BOX_TOP - 0.12, "wood", PAINT["deck"])
	g.box(-0.42, 0.42, -H + 0.05, H - 0.05, BOX_TOP - 0.12, BOX_TOP, "wood", PAINT["deck"])
	by = -H - 0.14
	g.beam((0.9, by, FLOOR + 0.6), (0.9, by, BOX_RIDGE + 0.03), 0.07, 0.07, "iron", iron)
	g.lathe((0.9, by, BOX_RIDGE), (0.0, 0.0, 1.0), [(0.26, 0.0), (0.34, 0.0), (0.34, 0.06), (0.26, 0.06), (0.26, 0.0)], "metal", iron, n=16)
	for a in (0.0, math.pi / 3, 2 * math.pi / 3):
		dv = Vector((math.cos(a), math.sin(a), 0.0)) * 0.3
		c = Vector((0.9, by, BOX_RIDGE + 0.03))
		g.beam(c - dv, c + dv, 0.05, 0.05, "metal", iron)
	emit("Body", g, mats, parent=root, group=f"{kind} body")
	# The doors: shut over the doorway, or slid open over the walls fore and aft.
	for s, side in ((1, "R"), (-1, "L")):
		spots = (("F", 0.0, d), ("B", -d, 0.0)) if kind == "box" else (("F", d, 2 * d), ("B", -2 * d, -d))
		for half, ya, yb in spots:
			car_door(f"Door_{side}{half}", mats, root, s, ya, yb, paint, slatted=kind == "stock", group=f"{kind} body")
	trucks(root, mats, H - BOGIE, f"{kind} running gear")
	return root


def build_flat(mats):
	"""The flatcar: a plank deck on fishbelly sills, stake pockets down its sides."""
	root = empty("Flat", (0.0, 0.0, 0.0))
	H = FLAT_LONG * 0.5
	paint, iron = PAINT["barn"], PAINT["iron"]
	base = FLAT_TOP - 0.16
	g = Geo()
	side_sills(g, H, base, paint)
	car_ends(g, H, SILL_END - 0.15, base, paint, half=WIDE * 0.5 - 0.04)
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, base - 0.5, base, "metal", iron)
	g.box(-WIDE * 0.5 + 0.04, WIDE * 0.5 - 0.04, -H, H, base, FLAT_TOP, "wood", PAINT["deck"], tile=PLANK_TILE, rot=True)
	for s in (-1, 1):
		y = -H + 1.0
		while y < H - 0.5:
			g.box(s * (CAR_HALF + 0.08), s * (WIDE * 0.5 - 0.005), y - 0.12, y + 0.12, base - 0.3, base, "metal", iron)
			y += 2.0
	emit("Body", g, mats, parent=root, group="flat body")
	trucks(root, mats, H - BOGIE, "flat running gear")
	return root


def build_open(mats):
	"""The coal gondola: plank sides between iron stakes on a flatcar's frame,
	its coal heaped over them (inside rail_train.gd's heap block)."""
	root = empty("Open", (0.0, 0.0, 0.0))
	H = OPEN_LONG * 0.5
	paint, iron = PAINT["oxide"], PAINT["iron"]
	w = CAR_HALF
	t = 0.14
	ye = H - 0.06
	base = OPEN_FLOOR
	g = Geo()
	side_sills(g, H, base, paint)
	car_ends(g, H, SILL_END - 0.15, base, paint)
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, base - 0.5, base, "metal", iron)
	g.box(-w, w, -ye, ye, base - 0.12, base, "wood", paint, skip="u")
	plank = {"rot": True, "tile": 16 * 0.35, "uvo": (-base / (16 * 0.35), 0.0)}
	for s in (-1, 1):
		g.box(s * (w - t), s * w, -ye, ye, base, OPEN_TOP - 0.1, "wood", paint, **plank)
		g.box(s * (w - t - 0.03), s * (w + 0.05), -ye - 0.03, ye + 0.03, OPEN_TOP - 0.1, OPEN_TOP, "metal", iron)
		y = -ye + 1.0
		while y < ye - 0.5:
			g.box(s * w, s * (w + 0.1), y - 0.09, y + 0.09, SILL_END - 0.05, OPEN_TOP - 0.1, "metal", iron)
			y += 2.0
	for sy in (-1, 1):
		g.box(-(w - t), w - t, sy * (ye - t), sy * ye, base, OPEN_TOP - 0.1, "wood", paint, **plank)
		g.box(-w, w, sy * (ye - t - 0.03), sy * (ye + 0.03), OPEN_TOP - 0.1, OPEN_TOP, "metal", iron)
		for x in (-1.6, 0.0, 1.6):
			g.box(x - 0.09, x + 0.09, sy * ye, sy * (ye + 0.08), base, OPEN_TOP - 0.1, "metal", iron)
	corner_posts(g, w, ye, base, OPEN_TOP - 0.1, iron, wide=0.12, proud=0.08)
	emit("Body", g, mats, parent=root, group="open body")
	# The coal: level just under the rim, heaped flat topped to HEAP over it
	# inside the heap's block, lumpy, loose lumps on it.
	coal = Geo(dirt=0.0)
	rng = np.random.default_rng(11)
	jit = rng.uniform(-1.0, 1.0, 4096)
	hx, hy = WIDE * 0.5 * HEAP_IN, H * HEAP_IN
	rim = OPEN_TOP - 0.2
	peak = OPEN_TOP + HEAP

	def heap(x, y):
		p = (1.0 - sstep(hx - 0.5, hx + 0.35, abs(x))) * (1.0 - sstep(hy - 0.8, hy + 1.4, abs(y)))
		k = int((x * 7.3 + 40.0) * 13.0 + (y * 5.1 + 40.0) * 7.0) % 4096
		lump_ = 0.06 * jit[k] + 0.04 * math.sin(x * 3.1 + y * 2.3) * math.sin(y * 3.7 - x * 1.3)
		return rim + 0.04 * jit[k] * (1.0 - p) + (peak - rim - 0.1) * p + lump_ * p
	xs = [-(w - t) + 0.01 + (2 * (w - t) - 0.02) * i / 22 for i in range(23)]
	ys = [-(ye - t) + 0.01 + (2 * (ye - t) - 0.02) * j / 44 for j in range(45)]
	coal.sheet(xs, ys, heap, "coal", PAINT["coal"])
	for i in range(50):
		x = rng.uniform(-hx * 0.85, hx * 0.85)
		y = rng.uniform(-hy * 0.9, hy * 0.9)
		r = rng.uniform(0.12, 0.26)
		lump(coal, Vector((x, y, min(heap(x, y) - r * 0.2, peak - r * 0.95))), r, rng)
	emit("Coal", coal, mats, parent=root, group="open body")
	trucks(root, mats, H - BOGIE, "open running gear")
	return root


def build_van(mats):
	"""The caboose: a red body with windows, open end platforms with railings
	under its roof, a cupola; marker lamps at the back."""
	root = empty("Van", (0.0, 0.0, 0.0))
	H = VAN_LONG * 0.5
	paint, cream, iron = PAINT["van"], PAINT["cream"], PAINT["iron"]
	w = VAN_HALF - 0.1
	ye = H - VAN_PLATFORM
	g = Geo()
	car_ends(g, H, 1.05, FLOOR, paint, half=w)
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, FLOOR - 0.3, FLOOR, "metal", iron)
	g.box(-w, w, -ye, ye, FLOOR, VAN_EAVE, "wood", paint, skip="u", tile=CAR_TILE)
	corner_posts(g, w, ye, FLOOR, VAN_EAVE, cream, wide=0.16)
	for s in (-1, 1):
		g.box(s * w, s * (w + 0.05), -ye, ye, VAN_EAVE - 0.32, VAN_EAVE - 0.06, "wood", cream, rot=True)
		g.box(s * w, s * (w + 0.05), -ye, ye, FLOOR, FLOOR + 0.22, "metal", iron)
		for y0, y1 in ((-4.6, -3.4), (3.4, 4.6), (-0.6, 0.6)):
			window(g, s * (w + 0.01), 0, y0, y1, 3.2, 4.4, (s, 0, 0), mullion=True)
	# The platforms: a plank deck, an end railing, a grab iron and a step each side.
	for sy in (-1, 1):
		g.box(-w, w, sy * ye, sy * (H - 0.3), FLOOR - 0.14, FLOOR, "wood", PAINT["deck"], tile=PLANK_TILE, rot=True)
		yr = sy * (H - 0.16)
		for x in (-w + 0.08, -0.95, 0.95, w - 0.08):
			g.beam((x, yr, FLOOR), (x, yr, FLOOR + 1.05), 0.08, 0.08, "iron", iron)
		for z in (FLOOR + 0.55, FLOOR + 1.05):
			g.beam((-w + 0.08, yr, z), (w - 0.08, yr, z), 0.07, 0.07, "iron", iron)
		for s in (-1, 1):
			g.beam((s * (w - 0.08), sy * (ye + 0.1), FLOOR + 1.05), (s * (w - 0.08), yr, FLOOR + 1.05), 0.07, 0.07, "iron", iron)
			g.beam((s * (w + 0.02), sy * (ye + 0.12), FLOOR + 0.3), (s * (w + 0.02), sy * (ye + 0.12), VAN_EAVE - 0.5), 0.06, 0.06, "iron", iron)
			g.box(s * (w - 0.45), s * (w + 0.04), sy * (ye + 0.15), sy * (H - 0.4), 0.98, 1.06, "wood", PAINT["deck"])
			for y in (sy * (ye + 0.2), sy * (H - 0.45)):
				g.box(s * (w - 0.05), s * w, y - 0.04, y + 0.04, 0.98, FLOOR - 0.14, "metal", iron)
		# The end wall's door (a window in it) and a window either side.
		yf = sy * (ye + 0.01)
		g.facing([(-0.65, yf, FLOOR + 0.05), (0.65, yf, FLOOR + 0.05), (0.65, yf, 4.1), (-0.65, yf, 4.1)], (0, sy, 0), "wood", PAINT["inside"])
		window(g, -0.42, 0.42, sy * (ye + 0.02), 0, 3.0, 3.85, (0, sy, 0))
		for a, b in (((-0.72, FLOOR), (-0.72, 4.18)), ((0.72, FLOOR), (0.72, 4.18)), ((-0.72, 4.18), (0.72, 4.18))):
			g.beam((a[0], sy * (ye + 0.04), a[1]), (b[0], sy * (ye + 0.04), b[1]), 0.14, 0.06, "wood", cream, up=(0.0, 1.0, 0.0))
		for x0, x1 in ((-2.1, -1.3), (1.3, 2.1)):
			window(g, x0, x1, sy * (ye + 0.02), 0, 3.2, 4.2, (0, sy, 0))
	# The marker lamps on the back corners, red lenses back and out.
	for s in (-1, 1):
		x0, x1 = sorted((s * 1.95, s * 2.35))
		yb = -ye - 0.42
		g.box(x0, x1, yb, -ye, 4.35, 4.8, "metal", PAINT["black"])
		g.facing([(x0 + 0.06, yb - 0.005, 4.43), (x1 - 0.06, yb - 0.005, 4.43), (x1 - 0.06, yb - 0.005, 4.72), (x0 + 0.06, yb - 0.005, 4.72)], (0, -1, 0), "lamp", PAINT["marker"])
		xo = x1 + 0.005 if s > 0 else x0 - 0.005
		g.facing([(xo, yb + 0.08, 4.43), (xo, -ye - 0.08, 4.43), (xo, -ye - 0.08, 4.72), (xo, yb + 0.08, 4.72)], (s, 0, 0), "lamp", PAINT["marker"])
		g.lathe((s * 2.15, yb + 0.21, 4.8), (0.0, 0.0, 1.0), [(0.1, 0.0), (0.1, 0.12), (0.0, 0.18)], "metal", PAINT["black"], n=8)
	roof = PAINT["roof"]
	gable_roof(g, VAN_HALF, VAN_EAVE, VAN_TOP, -H, H, roof, gables=(-ye, ye), wall=paint, wall_half=w)
	# The cupola: windows round it, cream trim, its own roof.
	cx, cy = CUPOLA_HALF[0] - 0.13, CUPOLA_HALF[1] - 0.15
	g.box(-cx, cx, -cy, cy, VAN_EAVE, CUPOLA_EAVE, "wood", paint, skip="ud", tile=CAR_TILE)
	corner_posts(g, cx, cy, VAN_EAVE, CUPOLA_EAVE, cream, wide=0.14)
	for s in (-1, 1):
		for y0, y1 in ((-1.45, -0.2), (0.2, 1.45)):
			window(g, s * (cx + 0.01), 0, y0, y1, 6.05, 6.9, (s, 0, 0), frame=0.08)
		window(g, -0.85, 0.85, s * (cy + 0.01), 0, 6.05, 6.9, (0, s, 0), frame=0.08, mullion=True)
		g.box(s * cx, s * (cx + 0.05), -cy, cy, CUPOLA_EAVE - 0.22, CUPOLA_EAVE - 0.04, "wood", cream, rot=True)
	gable_roof(g, CUPOLA_HALF[0], CUPOLA_EAVE, CUPOLA_TOP, -CUPOLA_HALF[1], CUPOLA_HALF[1], roof, gables=(-cy, cy), wall=paint, wall_half=cx)
	emit("Body", g, mats, parent=root, group="van body")
	trucks(root, mats, H - BOGIE, "van running gear")
	return root


# --- Textures -----------------------------------------------------------------


def spectral(h, w, beta, seed, sx=1.0, sy=1.0):
	"""Tileable noise, 0..1 about 0.5, 1/f^beta; sx > 1 stretches it along x."""
	rng = np.random.default_rng(seed)
	f = np.fft.rfft2(rng.standard_normal((h, w)).astype(np.float32))
	fy = np.fft.fftfreq(h)[:, None] * h / max(h, w) * sy
	fx = np.fft.rfftfreq(w)[None, :] * w / max(h, w) * sx
	r = np.sqrt(fx * fx + fy * fy)
	r[0, 0] = 1e9
	out = np.fft.irfft2(f / (r ** beta), s=(h, w))
	out = (out - out.mean()) / (out.std() + 1e-9)
	return np.clip(out * 0.2 + 0.5, 0.0, 1.0).astype(np.float32)


def nsst(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def normal_from(hgt, strength):
	gx = np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)
	gy = np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)
	nx, ny, nz = -gx * strength, gy * strength, np.ones_like(hgt)
	l = np.sqrt(nx * nx + ny * ny + nz * nz)
	return np.stack((nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5), axis=-1)


def paint_wood(W):
	"""Painted boards, upright (their seams along v): near white, for the vertex
	colours to tint. A board is 0.25 m at the 4 m tile."""
	v, u = np.mgrid[0:W, 0:W].astype(np.float32) / W
	boards = 16
	col_f = u * boards
	bid = np.floor(col_f).astype(np.int32)
	frac = col_f - bid
	rng = np.random.default_rng(31)
	tint = rng.uniform(-1.0, 1.0, boards)[bid % boards]
	grain = spectral(W, W, 0.9, 32, sx=1.0, sy=24.0)
	grain2 = spectral(W, W, 0.6, 33, sx=1.0, sy=40.0)
	wear = spectral(W, W, 1.6, 34)
	seam = np.maximum(nsst(0.07, 0.0, frac), nsst(0.93, 1.0, frac))
	base = 0.9 + 0.04 * tint + 0.08 * (grain - 0.5) + 0.05 * (grain2 - 0.5)
	base = base * (1.0 - 0.45 * seam)
	# Paint worn thin here and there: the grain shows through a little more.
	worn = nsst(0.6, 0.75, wear)
	base = base * (1.0 - 0.08 * worn * (1.0 - grain))
	col = np.clip(np.stack((base, base * 0.985, base * 0.965), axis=-1), 0, 1)
	hgt = 0.6 * (1.0 - seam) + 0.15 * (grain - 0.5)
	return col, hgt


def paint_metal(W):
	"""Painted iron: a faint mottle and streaks running down."""
	mott = spectral(W, W, 1.4, 41)
	streak = spectral(W, W, 0.8, 42, sx=1.0, sy=8.0)
	base = 0.92 + 0.07 * (mott - 0.5) + 0.06 * (streak - 0.5)
	col = np.clip(np.stack((base, base, base * 0.99), axis=-1), 0, 1)
	hgt = 0.3 * (mott - 0.5)
	return col, hgt


def paint_coal(W):
	"""Coal: lumps (each a dome round its seed point), dark, their tops glinting."""
	rng = np.random.default_rng(51)
	n = 420
	px = rng.uniform(0, 1, n).astype(np.float32)
	py = rng.uniform(0, 1, n).astype(np.float32)
	size = rng.uniform(0.6, 1.4, n).astype(np.float32)
	v, u = np.mgrid[0:W, 0:W].astype(np.float32) / W
	best = np.full((W, W), 9.0, dtype=np.float32)
	second = np.full((W, W), 9.0, dtype=np.float32)
	tone = np.zeros((W, W), dtype=np.float32)
	tones = rng.uniform(0.0, 1.0, n).astype(np.float32)
	for i in range(n):
		dx = np.abs(u - px[i])
		dx = np.minimum(dx, 1.0 - dx)
		dy = np.abs(v - py[i])
		dy = np.minimum(dy, 1.0 - dy)
		d = np.sqrt(dx * dx + dy * dy) / size[i]
		closer = d < best
		second = np.where(closer, best, np.minimum(second, d))
		tone = np.where(closer, tones[i], tone)
		best = np.where(closer, d, best)
	edge = second - best
	hgt = np.clip(edge * 18.0, 0.0, 1.0)
	fine = spectral(W, W, 0.7, 52)
	base = 0.11 + 0.07 * tone + 0.05 * (fine - 0.5)
	base = base * (0.55 + 0.45 * hgt)
	glint = nsst(0.7, 1.0, hgt) * nsst(0.55, 0.8, fine) * 0.14
	b = base + glint
	col = np.clip(np.stack((b, b * 1.0, b * 1.04), axis=-1), 0, 1)
	return col, hgt + 0.2 * (fine - 0.5)


def save_tex(name, rgb, data=False):
	"""To a JPEG (small in the repo), the pixels as painted: no colour management."""
	OUT.mkdir(parents=True, exist_ok=True)
	h, w = rgb.shape[:2]
	img = bpy.data.images.new(name, w, h, alpha=False)
	if data:
		img.colorspace_settings.name = "Non-Color"
	px = np.dstack((rgb, np.ones((h, w), dtype=np.float32)))[::-1].astype(np.float32)
	img.pixels.foreach_set(px.ravel())
	img.update()
	path = OUT / (name + ".jpg")
	img.filepath_raw = str(path)
	img.file_format = "JPEG"
	bpy.context.scene.render.image_settings.quality = 90
	img.save()
	bpy.data.images.remove(img)
	return path


SHADER_SURFACE = """shader_type spatial;
// Written by art/blender/train/train_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (the pirate ship's surface), so a stock
// material would go black out of the sun. Albedo: the tile times the vertex
// colour (the paint, its grime baked in).
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_depth = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform float fill = 1.6;
uniform float rim = 0.3;
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	if (normal_depth > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
"""
SHADER_LAMP = """shader_type spatial;
// Written by art/blender/train/train_build.py: the headlamp's lens, lit.
render_mode unshaded, shadows_disabled;
void fragment() {
	ALBEDO = COLOR.rgb * 1.6;
}
"""


def write_materials():
	OUT.mkdir(parents=True, exist_ok=True)
	(OUT / "train_surface.gdshader").write_text(SHADER_SURFACE)
	(OUT / "train_lamp.gdshader").write_text(SHADER_LAMP)
	for name, (shader, alb, nrm, params) in MATERIALS.items():
		ext = [f'[ext_resource type="Shader" path="{RES}/train_{shader}.gdshader" id="1"]']
		lines = ['shader = ExtResource("1")']
		for key, tex, i in (("albedo_tex", alb, 2), ("normal_tex", nrm, 3)):
			if tex:
				ext.append(f'[ext_resource type="Texture2D" path="{RES}/{tex}.jpg" id="{i}"]')
				lines.append(f'shader_parameter/{key} = ExtResource("{i}")')
		for k, v in params.items():
			lines.append(f"shader_parameter/{k} = {v}")
		text = '[gd_resource type="ShaderMaterial" format=3]\n\n' + "\n".join(ext) + "\n\n[resource]\n" + "\n".join(lines) + "\n"
		(OUT / f"{name}.tres").write_text(text)


def make_mats(scale):
	print("painting textures...")
	for name, fn in (("wood", paint_wood), ("metal", paint_metal), ("coal", paint_coal)):
		c, h = fn(int(TEX_SIZE[name] * scale))
		save_tex(f"train_{name}", c)
		save_tex(f"train_{name}_n", normal_from(h, 4.0 if name != "coal" else 6.0), data=True)
	write_materials()
	return {name: bpy.data.materials.new(name) for name in MAT_NAMES}


IMPORT_PARAMS = """nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
"""


def write_import(kind):
	"""The glb's .import: every material name pointed at its shared .tres. A uid
	Godot gave it before is kept."""
	path = OUT / f"{kind}.glb.import"
	uid = ""
	if path.exists():
		for line in path.read_text().splitlines():
			if line.startswith("uid="):
				uid = line + "\n"
	mats = ",\n".join(
		f'"{m}": {{\n"use_external/enabled": true,\n"use_external/fallback_path": "{RES}/{m}.tres",\n"use_external/path": "{RES}/{m}.tres"\n}}'
		for m in MAT_NAMES)
	text = ('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n' + uid
		+ f'\n[deps]\n\nsource_file="{RES}/{kind}.glb"\n\n[params]\n\n' + IMPORT_PARAMS
		+ '_subresources={\n"materials": {\n' + mats + '\n}\n}\n')
	path.write_text(text)


# --- Export and proof ---------------------------------------------------------


def select_tree(root):
	bpy.ops.object.select_all(action="DESELECT")
	stack = [root]
	while stack:
		ob = stack.pop()
		ob.select_set(True)
		stack.extend(ob.children)


def export(kind, root):
	OUT.mkdir(parents=True, exist_ok=True)
	select_tree(root)
	bpy.ops.export_scene.gltf(
		filepath=str(OUT / f"{kind}.glb"), export_format="GLB", use_selection=True, export_apply=False,
		export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
		export_normals=True, export_tangents=False, export_animations=False, export_cameras=False, export_lights=False,
		export_image_format="NONE", export_morph=False, export_skins=False)
	write_import(kind)


def read_glb(path):
	raw = Path(path).read_bytes()
	jlen = struct.unpack_from("<I", raw, 12)[0]
	doc = json.loads(raw[20:20 + jlen].decode("utf8"))
	blen = struct.unpack_from("<I", raw, 20 + jlen)[0]
	return doc, raw[28 + jlen:28 + jlen + blen]


def accessor(doc, bin_, i):
	a = doc["accessors"][i]
	v = doc["bufferViews"][a["bufferView"]]
	comp = {5126: "f4", 5125: "u4", 5123: "u2", 5121: "u1"}[a["componentType"]]
	n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
	off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
	return np.frombuffer(bin_, dtype=comp, count=a["count"] * n, offset=off).reshape(-1, n)


def node_matrix(n):
	t = n.get("translation", (0, 0, 0))
	q = n.get("rotation", (0, 0, 0, 1))
	s = n.get("scale", (1, 1, 1))
	x, y, z, w = q
	r = np.array((
		(1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
		(2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
		(2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y))))
	m = np.eye(4)
	m[:3, :3] = r * np.array(s)
	m[:3, 3] = t
	return m


def node_points(doc, bin_):
	"""Each mesh node's vertices in the glb's (Godot's) frame: {name: array n,3}."""
	out = {}

	def walk(i, pm):
		n = doc["nodes"][i]
		m = pm @ node_matrix(n)
		if "mesh" in n:
			pts = []
			for pr in doc["meshes"][n["mesh"]]["primitives"]:
				pos = accessor(doc, bin_, pr["attributes"]["POSITION"]).astype(np.float64)
				pts.append(pos @ m[:3, :3].T + m[:3, 3])
			out[n.get("name", f"node{i}")] = np.concatenate(pts)
		for c in n.get("children", ()):
			walk(c, m)
	for i in doc["scenes"][0]["nodes"]:
		walk(i, np.eye(4))
	return out


# How far past its coupler face each kind may reach (m, Godot z): the engine's
# pilot runs on ahead of its 22 m to PILOT_TIP (the train's nose); nothing goes
# into the gap's far half behind.
LONG = {"engine": ENGINE_LONG, "tender": TENDER_LONG, "box": BOX_LONG, "doors": BOX_LONG, "stock": BOX_LONG,
	"flat": FLAT_LONG, "open": OPEN_LONG, "van": VAN_LONG}
REACH = {k: (L * 0.5 + GAP * 0.5,) * 2 for k, L in LONG.items()}
REACH["engine"] = (PILOT_TIP, ENGINE_LONG * 0.5 + GAP * 0.5)
# Each kind's top over the bed: the spec's table (and rail_train.gd CARS).
TOP = {"engine": STACK_TOP, "tender": COAL_TOP, "box": BOX_TOP, "doors": BOX_TOP, "stock": BOX_TOP,
	"flat": FLAT_TOP, "open": OPEN_TOP + HEAP, "van": CUPOLA_TOP}
# The openings that must be clear (Godot frame: x0, y0, z0, x1, y1, z1): the
# doorway across the doors and stock cars (rail_train.gd door_wide x door_high).
DOORWAY = (-WIDE * 0.5, FLOOR, -DOOR_LONG * 0.5, WIDE * 0.5, FLOOR + DOOR_HIGH, DOOR_LONG * 0.5)
OPENINGS = {"doors": {"doorway": DOORWAY}, "stock": {"doorway": DOORWAY}}
TRUCK_NODES = ("Truck_F", "Truck_R", "TruckFrame_F", "TruckFrame_R", "Wheels_F1", "Wheels_F2", "Wheels_R1", "Wheels_R2")
DOOR_NODES = ("Door_RF", "Door_RB", "Door_LF", "Door_LB")
WANT = {"engine": ("Body", "Driver_1", "Driver_2", "Lead_1", "Lead_2", "LeadTruck", "SideRod_R", "SideRod_L",
		"MainRod_R", "MainRod_L", "Crosshead_R", "Crosshead_L", "StackMouth", "Steam_R", "Steam_L"),
	"tender": ("Body", "Coal") + TRUCK_NODES,
	"box": ("Body",) + DOOR_NODES + TRUCK_NODES, "doors": ("Body",) + DOOR_NODES + TRUCK_NODES,
	"stock": ("Body",) + DOOR_NODES + TRUCK_NODES, "flat": ("Body",) + TRUCK_NODES,
	"open": ("Body", "Coal") + TRUCK_NODES, "van": ("Body",) + TRUCK_NODES}


def node_tris(doc, bin_):
	"""Every mesh node's triangles in the glb's (Godot's) frame: {name: array n,3,3}."""
	out = {}

	def walk(i, pm):
		n = doc["nodes"][i]
		m = pm @ node_matrix(n)
		if "mesh" in n:
			tris = []
			for pr in doc["meshes"][n["mesh"]]["primitives"]:
				pos = accessor(doc, bin_, pr["attributes"]["POSITION"]).astype(np.float64) @ m[:3, :3].T + m[:3, 3]
				idx = accessor(doc, bin_, pr["indices"]).ravel().astype(np.int64)
				tris.append(pos[idx].reshape(-1, 3, 3))
			out[n.get("name", f"node{i}")] = np.concatenate(tris)
		for c in n.get("children", ()):
			walk(c, m)
	for i in doc["scenes"][0]["nodes"]:
		walk(i, np.eye(4))
	return out


def opening_clear(doc, bin_, box, eps=0.01):
	"""The nodes with a triangle in the box (its corners, edge middles or centre
	more than eps inside it): {name: count}."""
	lo = np.array(box[:3]) + eps
	hi = np.array(box[3:]) - eps
	hits = {}
	for name, t in node_tris(doc, bin_).items():
		pts = np.concatenate([t, (t[:, [0, 1, 2]] + t[:, [1, 2, 0]]) * 0.5, t.mean(1, keepdims=True)], axis=1)
		inside = np.all((pts > lo) & (pts < hi), axis=2).any(axis=1)
		if inside.any():
			hits[name] = int(inside.sum())
	return hits


def prove(kind):
	"""Read the glb back: inside its car. Prints each part's box (Godot frame:
	x right, y up, z back) for the colliders to match. True if it fails."""
	doc, bin_ = read_glb(OUT / f"{kind}.glb")
	parts = node_points(doc, bin_)
	bad = False
	front, back = REACH[kind]
	allp = np.concatenate(list(parts.values()))
	lo, hi = allp.min(0), allp.max(0)
	print(f"{kind}: {len(doc['nodes'])} nodes; all within x {lo[0]:.2f}..{hi[0]:.2f}, y {lo[1]:.2f}..{hi[1]:.2f}, z {lo[2]:.2f}..{hi[2]:.2f}")
	for name, p in sorted(parts.items()):
		a, b = p.min(0), p.max(0)
		print(f"  {name:16s} x {a[0]:6.2f}..{b[0]:5.2f}  y {a[1]:5.2f}..{b[1]:5.2f}  z {a[2]:6.2f}..{b[2]:6.2f}")
	checks = (
		(hi[0] <= WIDE * 0.5 + 1e-3 and lo[0] >= -WIDE * 0.5 - 1e-3, f"wider than WIDE {WIDE}"),
		(hi[1] <= min(TALL, TOP[kind]) + 1e-3, f"taller than its top {TOP[kind]}"),
		(lo[1] >= RAIL_TOP - 0.15, "under the rails' tops"),
		(lo[2] >= -front - 1e-3, f"past its front ({front})"),
		(hi[2] <= back + 1e-3, f"past its back ({back})"),
	)
	for ok, what in checks:
		if not ok:
			print(f"FAIL {kind}: {what}")
			bad = True
	for what, box in OPENINGS.get(kind, {}).items():
		hits = opening_clear(doc, bin_, box)
		if hits:
			print(f"FAIL {kind}: the {what} isn't clear: " + ", ".join(f"{n} ({c} triangles)" for n, c in hits.items()))
			bad = True
		else:
			print(f"  the {what} is clear: x {box[0]:.1f}..{box[3]:.1f}, y {box[1]:.1f}..{box[4]:.1f}, z {box[2]:.1f}..{box[5]:.1f}")
	names = {n.get("name") for n in doc["nodes"]}
	for w in WANT[kind]:
		if w not in names:
			print(f"FAIL {kind}: no node {w}")
			bad = True
	mats = sorted({m.get("name") for m in doc.get("materials", [])})
	print(f"  materials: {', '.join(mats)}")
	return bad


# --- A render in Blender ------------------------------------------------------


def render(kinds):
	"""The engine and tender coupled on a short track, in a plain sky: 3/4, side
	and front. Off the written glbs, so what renders is what the game loads."""
	RENDERS.mkdir(parents=True, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
		try:
			scene.render.engine = engine
			break
		except TypeError:
			continue
	scene.eevee.taa_render_samples = 48
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "Medium High Contrast"
	scene.render.resolution_x, scene.render.resolution_y = 1600, 900
	at = 0.0
	prev = None
	col_name = "Color"
	for kind in kinds:
		before = set(bpy.data.objects)
		bpy.ops.import_scene.gltf(filepath=str(OUT / f"{kind}.glb"))
		new = set(bpy.data.objects) - before
		if prev is not None:
			at -= LONG[prev] * 0.5 + GAP + LONG[kind] * 0.5
		for ob in new:
			if ob.parent is None:
				ob.location.y += at
			if ob.type == "MESH" and ob.data.color_attributes:
				col_name = ob.data.color_attributes[0].name
		prev = kind
	# Materials: the tile times the vertex colour.
	imgs = {}
	for m in list(bpy.data.materials):
		name = m.name.split(".")[0]
		if name not in MATERIALS:
			continue
		shader, alb, nrm, params = MATERIALS[name]
		try:
			m.use_nodes = True
		except AttributeError:
			pass
		nt = m.node_tree
		for node in list(nt.nodes):
			nt.nodes.remove(node)
		outn = nt.nodes.new("ShaderNodeOutputMaterial")
		pb = nt.nodes.new("ShaderNodeBsdfPrincipled")
		nt.links.new(pb.outputs[0], outn.inputs["Surface"])
		col = nt.nodes.new("ShaderNodeAttribute")
		col.attribute_name = col_name
		if shader == "lamp":
			pb.inputs["Emission Color"].default_value = (1.0, 0.9, 0.6, 1.0)
			pb.inputs["Emission Strength"].default_value = 6.0
			continue
		mul = nt.nodes.new("ShaderNodeVectorMath")
		mul.operation = "MULTIPLY"
		nt.links.new(col.outputs["Color"], mul.inputs[0])
		if alb:
			tex = nt.nodes.new("ShaderNodeTexImage")
			if alb not in imgs:
				imgs[alb] = bpy.data.images.load(str(OUT / f"{alb}.jpg"))
			tex.image = imgs[alb]
			nt.links.new(tex.outputs["Color"], mul.inputs[1])
		else:
			mul.inputs[1].default_value = (1.0, 1.0, 1.0)
		nt.links.new(mul.outputs[0], pb.inputs["Base Color"])
		pb.inputs["Roughness"].default_value = params.get("roughness_value", 0.9)
		pb.inputs["Metallic"].default_value = params.get("metallic_value", 0.0)
		if nrm:
			ni = nt.nodes.new("ShaderNodeTexImage")
			ni.image = bpy.data.images.load(str(OUT / f"{nrm}.jpg"))
			ni.image.colorspace_settings.name = "Non-Color"
			nm = nt.nodes.new("ShaderNodeNormalMap")
			nm.inputs["Strength"].default_value = params.get("normal_depth", 1.0) * 0.6
			nt.links.new(ni.outputs["Color"], nm.inputs["Color"])
			nt.links.new(nm.outputs["Normal"], pb.inputs["Normal"])
	# The ground, the ballast, sleepers and rails.
	g = Geo(dirt=0.0)
	end = min(-70.0, at - LONG[kinds[-1]] * 0.5 - 40.0)
	g.box(-60, 60, end, 50, -0.3, 0.0, "dark", srgb("6f8a4f"))
	g.box(-2.8, 2.8, end, 50, 0.0, 0.35, "dark", srgb("7a736b"))
	y = end
	while y < 50:
		g.box(-2.3, 2.3, y - 0.25, y + 0.25, 0.27, 0.49, "dark", srgb("4a3828"))
		y += 1.6
	for s in (-1, 1):
		g.box(s * WHEEL_X - 0.15, s * WHEEL_X + 0.15, end, 50, 0.49, RAIL_TOP, "iron", srgb("5a5c60"))
	ground = bpy.data.materials.new("ground")
	try:
		ground.use_nodes = True
	except AttributeError:
		pass
	gn = ground.node_tree
	for node in list(gn.nodes):
		gn.nodes.remove(node)
	go = gn.nodes.new("ShaderNodeOutputMaterial")
	gp = gn.nodes.new("ShaderNodeBsdfPrincipled")
	gp.inputs["Roughness"].default_value = 0.95
	gn.links.new(gp.outputs[0], go.inputs["Surface"])
	vc = gn.nodes.new("ShaderNodeAttribute")
	vc.attribute_name = "Col"
	gn.links.new(vc.outputs["Color"], gp.inputs["Base Color"])
	emit("Ground", g, {n: ground for n in MAT_NAMES})
	# Sky and sun.
	world = bpy.data.worlds.new("sky")
	scene.world = world
	try:
		world.use_nodes = True
	except AttributeError:
		pass
	bg = world.node_tree.nodes.get("Background") or world.node_tree.nodes.new("ShaderNodeBackground")
	bg.inputs["Color"].default_value = (*srgb("a9c3dc"), 1.0)
	bg.inputs["Strength"].default_value = 1.1
	wo = world.node_tree.nodes.get("World Output") or world.node_tree.nodes.new("ShaderNodeOutputWorld")
	world.node_tree.links.new(bg.outputs[0], wo.inputs["Surface"])
	sun_d = bpy.data.lights.new("sun", "SUN")
	sun_d.energy = 4.2
	sun_d.angle = math.radians(2.0)
	sun_d.color = srgb("fff0da")
	sun = bpy.data.objects.new("sun", sun_d)
	scene.collection.objects.link(sun)
	sun.rotation_euler = (math.radians(50), 0.0, math.radians(-35))
	cam_d = bpy.data.cameras.new("cam")
	cam_d.clip_end = 600
	cam = bpy.data.objects.new("cam", cam_d)
	scene.collection.objects.link(cam)
	scene.camera = cam

	def shoot(name, eye, look, lens=35):
		cam.location = eye
		d = Vector(look) - Vector(eye)
		cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
		cam_d.lens = lens
		scene.render.filepath = str(RENDERS / f"{name}.png")
		bpy.ops.render.render(write_still=True)
		print("rendered", scene.render.filepath)
	if "engine" in kinds:
		shoot("train_3q", (24.0, 26.0, 9.0), (0.0, -2.0, 4.0))
		shoot("train_side", (34.0, -6.0, 4.5), (0.0, -6.0, 4.0), lens=30)
		shoot("engine_front", (9.0, 30.0, 5.5), (0.0, 5.0, 4.0), lens=45)
	cars = [k for k in kinds if k not in ("engine", "tender")]
	if cars:
		# The cars' stretch of the line, from its front end to its back.
		y0 = 0.0
		y = 0.0
		for i, kind in enumerate(kinds):
			if i:
				y -= LONG[kinds[i - 1]] * 0.5 + GAP + LONG[kind] * 0.5
			if kind == cars[0]:
				y0 = y + LONG[kind] * 0.5
		y1 = at - LONG[kinds[-1]] * 0.5
		mid = (y0 + y1) * 0.5
		span = y0 - y1
		shoot("cars_3q", (span * 0.55, mid + span * 0.45, span * 0.22), (0.0, mid, 3.5), lens=35)
		shoot("cars_side", (span * 0.9, mid, 4.5), (0.0, mid, 4.0), lens=35)


# --- Main ---------------------------------------------------------------------

BUILDERS = {"engine": build_engine, "tender": build_tender, "box": lambda m: build_boxcar(m, "box"),
	"doors": lambda m: build_boxcar(m, "doors"), "stock": lambda m: build_boxcar(m, "stock"),
	"flat": build_flat, "open": build_open, "van": build_van}


def fresh_mats():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.view_settings.view_transform = "Standard"
	return {name: bpy.data.materials.new(name) for name in MAT_NAMES}


def main():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	only = None
	for a in args:
		if a.startswith("--only="):
			only = a.split("=", 1)[1].split(",")
	fresh_mats()
	make_mats(0.5 if "--fast" in args else 1.0)
	bad = False
	built = []
	for kind, fn in BUILDERS.items():
		if only and kind not in only:
			continue
		print(f"building {kind}...")
		mats = fresh_mats()
		root = fn(mats)
		bpy.context.view_layer.update()
		export(kind, root)
		bad |= prove(kind)
		built.append(kind)
	print("triangles:", ", ".join(f"{k} {v}" for k, v in STATS.items()), f"(all {sum(STATS.values())})")
	if "--render" in args:
		render(built)
	sys.exit(1 if bad else 0)


main()
