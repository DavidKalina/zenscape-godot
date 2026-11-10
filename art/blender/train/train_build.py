"""Build the steam train's models: a classic western train, chunky and painted.

    python3 tools/blender.py run art/blender/train/train_build.py [-- --fast] [--only=engine,tender] [--render]

Writes assets/models/train/<kind>.glb for each kind (engine, tender, box, doors,
stock, flat, open, van, logs, truss, crane, coach, smash), and
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
  logs    Body (the flat, bunks, stakes, chains), Load (the logs).
  truss   Body (the flat), Load (the truss).
  crane   Body (the flat); House (turns about Y on its turntable, its origin
          the pivot) holding Boom (its origin on the foot's pin).
  smash   As the box (its trucks low, LOW_WHEEL_R, under the corridor's floor),
          and CrackPlug_F, CrackPlug_B (F the front, Godot -Z): each holds its
          plug's shards Shard_F01.. (a board or less, each its origin at its
          middle) and Cover_F (the glow behind, facing out: hide it on a burst).
  every   Far (the far look): the whole car at rest, simpler (FAR_SEGS, plain
          wheels), one mesh; the smash car's plugs in FarPlugs. On import
          (assets/models/train/train_import.gd) Far and FarPlugs show from
          their range out, and every other node that draws only nearer
          (visibility_parent: Far), so a car switches whole. Hide Far
          (visible = false) and the parts show at every range.
"""
import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/train"
RES = "res://assets/models/train"
RENDERS = Path(__file__).resolve().parent / "renders"
PARTS_JSON = Path(__file__).resolve().parent / "train_parts.json"


def load_parts():
	"""RailTrain's colliders and openings at the default sizes, the source of them
	(rail_train.gd `_parts`, written by train_parts.gd): run that first, else read
	the last one written."""
	py = shutil.which("python3") or shutil.which("python")
	if py:
		r = subprocess.run([py, str(ROOT / "tools/godot.py"), "-s", "res://art/blender/train/train_parts.gd"],
			cwd=str(ROOT), capture_output=True, text=True)
		print(f"train_parts.gd: exit {r.returncode}")
		if r.returncode != 0:
			print("  using the last train_parts.json:", (r.stdout + r.stderr)[-800:])
	return json.loads(PARTS_JSON.read_text())


# Every car's solid boxes, plates, movers and holes (Godot frame: x0 y0 z0 x1 y1 z1).
PARTS = load_parts()["kinds"]


def _hole(kind, i=0):
	return PARTS[kind]["holes"][i]["box"]

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
STACK_TOP = 9.0           # the balloon stack's mesh dome (TALL)
STACK_R = 1.25            # its lip
LAMP_Y = (9.35, 10.75)    # the headlamp's box lantern, on its bracket over the smokebox's front
LAMP_Z = (6.3, 7.55)
BELL_Y = 5.6
SAND_Y = 3.4
DOME_Y = 0.8
CAB_Y = (-10.6, -4.2)     # low and narrow, so the boiler and stack lead
CAB_FLOOR = 2.3
CAB_EAVE = 6.95
CAB_TOP = 7.7
CAB_HALF = 2.45           # the cab's sides (its trim stands 0.1 proud); the roof's eaves reach EAVE_HALF
EAVE_HALF = 2.72
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
COUPLER_Z = 1.18          # under FLOOR: clear of a corridor's floor, end to end
BOX_LONG = 24.0           # box, doors, stock
BOX_EAVE = 8.5
BOX_RIDGE = 8.8
BOX_TOP = 9.0             # the running board's top
DOOR_LONG = _hole("doors")[5] - _hole("doors")[2]   # the doorway: rail_train.gd door_wide, door_high
DOOR_HIGH = _hole("doors")[4] - FLOOR               # up from FLOOR; the doors are half its length each
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

# The special cars: spec-steam-train.md "Settled by lane cars" and the cars
# lane's greybox (rail_train.gd _parts), which the models match block for block.
LOGS_LONG = PARTS["logs"]["long"]
LOGS_TOP = 6.5            # each bundle solid across the car, DECK..LOGS_TOP
LOG_GAP = _hole("logs")[5] - _hole("logs")[2]   # between the bundles, along the car: rail_train.gd log_gap
LOG_IN = 0.3              # each bundle this far in from the car's end (LOG_IN)
LOG_R = 0.46              # the logs: LOG_ACROSS across, LOG_ROWS up, on bunks BUNK deep
LOG_ACROSS = 6
LOG_ROWS = 4
BUNK = 0.12
TRUSS_LONG = 24.0
TRUSS_TOP = 8.5
TRUSS_DECK = 2.1          # rail_train.gd truss_floor: the panel's floor
TRUSS_SIDE = 0.5          # each side truss's thickness, in from the car's side (TRUSS_SIDE)
TRUSS_IN = 0.6            # in from the car's ends (TRUSS_IN)
CHORD = 0.4               # the top chord's depth (CHORD)
TRUSS_PANEL = 10.0        # the open middle panel along the car (door_wide)
CRANE_LONG = 20.0
CRANE_HOUSE = (-6.8, 9.0, 7.2)   # the house: back, front (Blender y), top
CRANE_HALF = 2.55         # its sides (0.85 of WIDE's half)
GANTRY_Y = (-6.6, -5.8)   # the gantry's posts and the boom's foot, along the car
BOOM_WIDE = 1.6
BOOM_LOW = 8.6            # the boom's underside: rail_train.gd boom_low (DECK + the door's height)
BOOM_TOP = 9.0
BOOM_OVER = 14.0          # past the crane's end, over its idler (the next car back)
COACH_LONG = 24.0
COACH_TOP = 8.5
COACH_PLATFORM = 4.2      # each end's platform: rail_train.gd platform
COACH_RAIL = 2.1          # the railings' top: coach_rail (the gap's floor)
HOOD = 0.4                # the roof's hoods over the platforms, this deep (the gap's head)
RAIL_BAR = 0.15
COACH_TRUCK = 6.25        # the coach's trucks' pivots off its middle: under the body, not the platforms
SMASH_WIDE = _hole("smash")[3] - _hole("smash")[0]   # the corridor: rail_train.gd smash_wide, smash_high
SMASH_HIGH = _hole("smash")[4] - FLOOR                # (the run's and the smash car's, end to end)
THRU_LONG = PARTS["thru"]["long"]       # the run's open-ended boxcar
CULVERT_LONG = PARTS["culvert"]["long"]  # the culvert car: its sections' walls out to CULVERT_SIDE,
CULVERT_SIDE = max(b[3] for b in PARTS["culvert"]["solid"] if b[0] > 0.0)   # their roof to CULVERT_TOP
CULVERT_TOP = PARTS["culvert"]["tall"]
SMASH_PLATE = 0.6         # each end's plate (its plug), this deep in from the car's end (PLATE)
PLUG_BOARD = 0.52         # the plugs' boards across, thickness
PLUG_THICK = 0.12
PLUG_GAP = 0.1            # a crack's width between two shards
LOW_WHEEL_R = 0.24        # the smash car's trucks: under its corridor's floor (FLOOR), flanges
LOW_BASE = 1.1            # and all, since the corridor runs its whole length

# The far look: every kind also carries Far, the whole car built again at rest
# with its lathes FAR_SEGS of their segments (at least FAR_LEAST) and its wheels
# plain (FAR_WHEEL segments, no spokes, flanges or counterweights), joined into
# one mesh (the smash car's plugs into FarPlugs, so its corridor's proof can set
# them aside). The ranges are set on import: assets/models/train/train_import.gd.
FAR_SEGS = 0.4
FAR_LEAST = 6
FAR_WHEEL = 12
FAR = False               # set while the far look builds

# Colours (sRGB): paint, then the grime pulls them down low on the car.
COL = {
	"black": "2a2c31", "cab": "93301f", "wheel": "9b3322", "brass": "c9a24c", "steel": "7a7d82",
	"iron": "38393c", "cream": "e9dcbd", "roof": "3a3633", "gold": "c7a14a", "glass": "2a3440",
	"coal": "ffffff", "dark": "17130f", "lamp": "ffe7b0", "pilot": "9e3221",
	# The cars: barn red as the towns' (rail_stops.gd ELEVATOR_C), the stock car a
	# browner red, the gondola oxide, the caboose a brighter red.
	"barn": "a84d3d", "stock": "8e4a32", "oxide": "6c372b", "van": "b23a24", "deck": "8c7356",
	"floor": "7d6449", "inside": "3a2b20", "marker": "ff4026",
	# The special cars: bark and cut log ends, steel truss, the crane's house and
	# its ochre boom, the coaches' deep green, the smash car's weathered red, its
	# cracks' glow, a broken board's raw wood.
	"bark": "5b4330", "logend": "d6b783", "heart": "b9905c", "stake": "5e4834",
	"girder": "5c676e", "crane": "7a2c22", "boom": "c08f2c", "coach": "1d4a30",
	"smash": "93614b", "crack": "ff7a22", "raw": "c9a87c",
	# The run's open-ended cars mustard, the gate's doors yellow on the barn red,
	# the culverts' concrete.
	"thru": "9c7430", "gate": "d9b13f", "concrete": "a7a39b",
}

TEX_SIZE = {"wood": 512, "metal": 256, "coal": 512, "concrete": 256}
TILE = {"wood": 4.0, "metal": 4.0, "coal": 2.5, "concrete": 3.0}

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
	"concrete": ("surface", "train_concrete", "train_concrete_n", {"normal_depth": 0.9, "roughness_value": 0.92, "fill": 4.0, "rim": 0.2}),
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

	def poly(self, pts, mat, col, tile=None, rot=False, uvo=(0.0, 0.0), cols=None):
		"""A flat polygon, its points anticlockwise seen from its front; uvs
		projected on the box face it most looks along, in metres over the tile.
		rot swaps u and v (the wood's seams run across instead of up); uvo is
		added to them (to set a board's seams on its edges). cols: a colour for
		each point instead of col."""
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
		cols = cols or [col] * len(pts)
		self.face([self.vert(p, uv, c) for p, uv, c in zip(pts, uvs, cols)], mat)

	def facing(self, pts, out, mat, col, **kw):
		"""poly, its points turned so it faces along `out`."""
		pts = [Vector(p) for p in pts]
		if newell(pts).dot(Vector(out)) < 0.0:
			pts = pts[::-1]
			if kw.get("cols"):
				kw["cols"] = kw["cols"][::-1]
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

	def lathe(self, o, axis, prof, mat, col, n=24, ref=None, a0=0.0, a1=math.tau, tile=None, far_n=None):
		"""Revolve prof [(r, h)] (h along the axis, from the bottom up; None for a
		hard crease) round the axis through o, a ring of n. Faces outward. For
		the far look (FAR) a ring of far_n, else FAR_SEGS of n."""
		if FAR:
			n = far_n or max(FAR_LEAST, int(round(n * FAR_SEGS)))
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


# --- Wear and small parts -----------------------------------------------------
#
# The paint worn board by board (each its own coat, faded toward its top, now
# and then one patched fresher or older), rivets, the brake gear and steps
# under a car. Fine parts are skipped in the far look.


def faded(col, k):
	"""col sun-bleached k of the way (negative: a fresher, deeper coat)."""
	lum = 0.3 * col[0] + 0.55 * col[1] + 0.15 * col[2]
	g = lum * 1.35 + 0.02
	return tuple(max(0.0, c + (g - c) * k) for c in col)


def board_tone(rng, col, vary=1.0):
	"""A board's own paint (vary: how much they differ)."""
	c = tone(col, 1.0 + rng.uniform(-0.14, 0.08) * vary)
	if rng.random() < 0.08 * vary:
		c = faded(c, -0.3) if rng.random() < 0.5 else faded(c, 0.35)
	return c


def boards(g, axis, at, a0, a1, z0, z1, out, col, rng, pitch=CAR_TILE / 16, fade=0.2, mat="wood", tile=CAR_TILE, vary=1.0):
	"""A face of upright boards, each its own paint, faded toward its top: the face
	at `axis` (0 x, 1 y) = at, a0..a1 along the other level axis, z0..z1 up,
	facing `out` (+1 or -1 along `axis`); the boards' edges on the texture's seams
	(every `pitch` from 0)."""
	lo, hi = sorted((a0, a1))
	o = (out, 0.0, 0.0) if axis == 0 else (0.0, out, 0.0)

	def quad(b0, b1):
		return [(at, b0, z0), (at, b1, z0), (at, b1, z1), (at, b0, z1)] if axis == 0 else [(b0, at, z0), (b1, at, z0), (b1, at, z1), (b0, at, z1)]
	if FAR:
		g.facing(quad(lo, hi), o, mat, col, tile=tile)
		return
	k0 = math.floor(lo / pitch + 1e-6)
	k1 = math.ceil(hi / pitch - 1e-6)
	for k in range(k0, k1):
		b0, b1 = max(lo, k * pitch), min(hi, (k + 1) * pitch)
		if b1 - b0 < 1e-4:
			continue
		c = board_tone(rng, col, vary)
		top = faded(c, fade * rng.uniform(0.5, 1.5))
		g.facing(quad(b0, b1), o, mat, c, tile=tile, cols=[c, c, top, top])


def plank_box(g, x0, x1, y0, y1, z0, z1, col, rng, skip="", fade=0.2, mat="wood", tile=CAR_TILE):
	"""A box whose upright faces are boards (`boards`); skip faces by letter as box."""
	x0, x1 = sorted((x0, x1))
	y0, y1 = sorted((y0, y1))
	for k, axis, at, a0, a1, out in (("l", 0, x0, y0, y1, -1), ("r", 0, x1, y0, y1, 1), ("b", 1, y0, x0, x1, -1), ("f", 1, y1, x0, x1, 1)):
		if k not in skip:
			boards(g, axis, at, a0, a1, z0, z1, out, col, rng, fade=fade, mat=mat, tile=tile)
	g.box(x0, x1, y0, y1, z0, z1, mat, col, skip="lrbf" + skip, tile=tile)


def rivets(g, pts, normal, r=0.055, col=None, mat="metal"):
	"""Round heads (four-sided studs) at pts on a face whose outward normal is `normal`."""
	if FAR:
		return
	col = col or PAINT["black"]
	n = Vector(normal).normalized()
	a = Vector((1.0, 0.0, 0.0)) if abs(n.x) < 0.9 else Vector((0.0, 1.0, 0.0))
	u = n.cross(a).normalized()
	v = n.cross(u)
	for p in pts:
		p = Vector(p)
		c = [p + (u * dx + v * dy) * r for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))]
		tip = p + n * r * 0.7
		for i in range(4):
			e = (c[i] + c[(i + 1) % 4]) * 0.5
			g.facing([c[i], c[(i + 1) % 4], tip], (e - p) + n * r, mat, col)


def rivet_line(g, a, b, count, normal, **kw):
	a, b = Vector(a), Vector(b)
	rivets(g, [a + (b - a) * (k / max(count - 1, 1)) for k in range(count)], normal, **kw)


def rivet_ring(g, o, R, count, y, r=0.055, col=None, a0=0.0, a1=math.tau, mat="metal"):
	"""Rivets round a barrel along y (its axis through o's x, z) at y, R out."""
	if FAR:
		return
	for k in range(count):
		a = a0 + (a1 - a0) * (k + 0.5) / count
		d = Vector((math.sin(a), 0.0, math.cos(a)))
		rivets(g, [Vector((o[0], y, o[2])) + d * R], d, r=r, col=col, mat=mat)


def brake_gear(g, H, ztop, iron=None):
	"""Under a car's floor (its underside at ztop): the air reservoir and the brake
	cylinder either side of the centre sill, the triple valve, the train line, the
	levers and the rods out to the trucks."""
	if FAR:
		return
	iron = iron or PAINT["iron"]
	zc = ztop - 0.4
	g.lathe((1.2, -2.2, zc), (0.0, 1.0, 0.0), [(0.0, -0.04), (0.2, -0.03), (0.26, 0.06), (0.26, 2.1), (0.2, 2.19), (0.0, 2.2)], "metal", iron, n=12)
	g.lathe((-1.05, 0.7, zc), (0.0, 1.0, 0.0), [(0.0, 0.0), (0.27, 0.0), (0.27, 0.95), (0.2, 0.95), (0.2, 1.3), (0.0, 1.3)], "metal", iron, n=10)
	g.box(-1.45, -0.7, -0.6, 0.0, zc - 0.18, zc + 0.24, "metal", tone(iron, 0.85))
	g.beam((-1.05, 2.15, zc), (1.0, 2.35, zc), 0.08, 0.16, "iron", iron)
	for sy in (-1, 1):
		g.beam((0.35 * sy, sy * 2.25, zc - 0.05), (0.35 * sy, sy * (H - BOGIE - 1.2), zc - 0.12), 0.07, 0.07, "iron", iron)
	g.beam((0.5, -H + 0.35, ztop - 0.36), (0.5, H - 0.35, ztop - 0.36), 0.08, 0.08, "iron", tone(iron, 0.8))


def stirrups(g, H, w, ztop, iron=None):
	"""A stirrup step under each corner of a car (its side at w, its floor's underside at ztop)."""
	if FAR:
		return
	iron = iron or PAINT["iron"]
	za = max(ztop - 0.62, RAIL_TOP - 0.1)
	for sx in (-1, 1):
		x = sx * (w + 0.06)
		for sy in (-1, 1):
			y = sy * (H - 0.5)
			for dy in (-0.2, 0.2):
				g.beam((x, y + dy, ztop + 0.02), (x, y + dy, za), 0.05, 0.05, "iron", iron)
			g.beam((x, y - 0.22, za), (x, y + 0.22, za), 0.07, 0.05, "iron", iron)


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
	if FAR:
		# The far look: the steel tyre round a plain painted centre.
		g.lathe(o, ax, [(ri, -hw), (r, -hw), None, (r, hw), None, (ri, hw)], "iron", PAINT["steel"], far_n=FAR_WHEEL)
		g.lathe(o, ax, [(0.0, -hw * 0.6), (ri, -hw * 0.6)], "metal", PAINT["wheel"], far_n=FAR_WHEEL)
		g.lathe(o, ax, [(ri, hw * 0.6), (0.0, hw * 0.6)], "metal", PAINT["wheel"], far_n=FAR_WHEEL)
		return
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
	if FAR:
		# The far look: a plain disc, its tread steel.
		g.lathe(o, ax, [(r, lo), (r, hi)], "iron", PAINT["steel"], far_n=FAR_WHEEL)
		g.lathe(o, ax, [(0.0, lo * 0.4), (r, lo * 0.4)], "iron", PAINT["iron"], far_n=FAR_WHEEL)
		g.lathe(o, ax, [(r, hi * 0.4), (0.0, hi * 0.4)], "iron", PAINT["iron"], far_n=FAR_WHEEL)
		return
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
	dz = RAIL_TOP + DRIVER_R
	# Frames: two bars the length of her inside the wheels, the deck under the cab.
	for s in (-1, 1):
		g.box(s * 0.85, s * 1.15, -H, 10.4, 1.3, 2.3, "metal", iron)
	g.box(-CAB_HALF, CAB_HALF, CAB_Y[0] - 0.4, CAB_Y[1] + 0.6, 1.85, CAB_FLOOR, "metal", blk)
	# Over each driver's axlebox in the frame's jaws, a leaf spring hung under the
	# running board; an equaliser between the two springs on its fulcrum.
	for s in (-1, 1):
		x = s * 1.0
		for dy in DRIVER_Y:
			g.box(x - 0.22, x + 0.22, dy - 0.34, dy + 0.34, dz - 0.3, dz + 0.32, "metal", tone(iron, 0.85))
			for k, (half, z0) in enumerate(((0.95, 2.66), (0.8, 2.73), (0.65, 2.8), (0.5, 2.87))):
				g.box(x - 0.16, x + 0.16, dy - half, dy + half, z0, z0 + 0.065, "iron", tone(steel, 0.8 + 0.05 * k))
			g.box(x - 0.12, x + 0.12, dy - 0.12, dy + 0.12, dz + 0.3, 2.66, "iron", iron)
		g.beam((x, DRIVER_Y[0] - 0.95, 2.72), (x, DRIVER_Y[1] + 0.95, 2.72), 0.12, 0.18, "iron", iron)
		g.box(x - 0.1, x + 0.1, sum(DRIVER_Y) * 0.5 - 0.12, sum(DRIVER_Y) * 0.5 + 0.12, 2.3, 2.66, "iron", iron)
		# A brake shoe behind each driver on its tread, hung from the frame.
		for dy in DRIVER_Y:
			xs = s * (WHEEL_X + 0.08)
			arc = [Vector((xs, dy + (DRIVER_R + 0.07) * math.cos(a), dz + (DRIVER_R + 0.07) * math.sin(a))) for a in (math.radians(150 + 12 * k) for k in range(6))]
			for a, b in zip(arc, arc[1:]):
				g.beam(a, b, 0.16, 0.12, "iron", iron, up=(1.0, 0.0, 0.0))
			g.beam(arc[2], (s * 1.15, dy - DRIVER_R * 0.6, 2.3), 0.07, 0.07, "iron", iron)
	# The buffer beam, red, and the deck before the smokebox.
	g.box(-2.7, 2.7, 10.4, 11.0, 1.3, 2.45, "wood", PAINT["pilot"])
	g.box(-2.7, 2.7, 10.38, 10.42, 2.38, 2.45, "brass", brass)
	g.box(-2.2, 2.2, SMOKEBOX_Y[1] - 0.1, 10.4, 2.3, 2.45, "metal", blk)
	rivet_line(g, (-2.5, 11.0, 1.45), (2.5, 11.0, 1.45), 14, (0, 1, 0), r=0.045)
	# Firebox between the drivers, its ashpan under.
	g.box(-1.1, 1.1, -4.3, -1.3, 2.0, 3.6, "metal", blk)
	g.box(-0.95, 0.95, -4.1, -1.6, 1.55, 2.0, "metal", iron)
	# Boiler: black lagging, brass bands each with its rivets; the smokebox and its door.
	g.lathe((0.0, BOILER_Y[0], BOILER_Z), ax_y, [(BOILER_R, 0.0), (BOILER_R, BOILER_Y[1] - BOILER_Y[0])], "metal", blk, n=32)
	for y in (-3.2, -0.9, 1.7, 4.0, 6.45):
		g.lathe((0.0, y, BOILER_Z), ax_y, [(BOILER_R - 0.02, -0.07), (BOILER_R + 0.035, -0.06), (BOILER_R + 0.035, 0.06), (BOILER_R - 0.02, 0.07)], "brass", brass, n=32)
	sb0, sb1 = SMOKEBOX_Y
	g.lathe((0.0, sb0, BOILER_Z), ax_y, [(BOILER_R - 0.05, 0.0), (SMOKEBOX_R, 0.0), None, (SMOKEBOX_R, sb1 - sb0), None, (SMOKEBOX_R * 0.86, sb1 - sb0)], "metal", blk, n=32)
	rivet_ring(g, (0.0, 0.0, BOILER_Z), SMOKEBOX_R, 28, sb0 + 0.12)
	rivet_ring(g, (0.0, 0.0, BOILER_Z), SMOKEBOX_R, 28, sb1 - 0.12)
	rivet_ring(g, (0.0, 0.0, BOILER_Z), BOILER_R, 24, BOILER_Y[0] + 1.0, r=0.045)
	g.lathe((0.0, sb1, BOILER_Z), ax_y, [(SMOKEBOX_R * 0.86, 0.0), (SMOKEBOX_R * 0.84, 0.08), None, (SMOKEBOX_R * 0.8, 0.08), (SMOKEBOX_R * 0.6, 0.16), (0.0, 0.2)], "metal", blk, n=32)
	g.lathe((0.0, sb1, BOILER_Z), ax_y, [(SMOKEBOX_R * 0.8, 0.0), (SMOKEBOX_R * 0.86, 0.03), (SMOKEBOX_R * 0.86, 0.1), (SMOKEBOX_R * 0.8, 0.12)], "brass", brass, n=32)
	# The door: its brass number plate, the dogs round its rim, the hinge straps, a handle.
	g.lathe((0.0, sb1 + 0.17, BOILER_Z + 0.1), ax_y, [(0.0, 0.0), (0.42, 0.0), (0.45, 0.04), (0.42, 0.08), (0.0, 0.09)], "brass", brass, n=20)
	g.lathe((0.0, sb1 + 0.24, BOILER_Z + 0.1), ax_y, [(0.0, 0.0), (0.32, 0.0), (0.32, 0.03), (0.0, 0.03)], "metal", blk, n=20)
	for k in range(8):
		a = (k + 0.5) / 8 * math.tau
		c = Vector((math.cos(a), 0.0, math.sin(a)))
		p = Vector((0.0, sb1 + 0.12, BOILER_Z)) + c * (SMOKEBOX_R * 0.78)
		g.box(p.x - 0.045, p.x + 0.045, p.y - 0.06, p.y + 0.06, p.z - 0.045, p.z + 0.045, "metal", tone(blk, 1.4))
	g.beam((-0.4, sb1 + 0.3, BOILER_Z - 0.35), (0.4, sb1 + 0.3, BOILER_Z - 0.35), 0.07, 0.07, "brass", brass, up=(0.0, 1.0, 0.0))
	for dz_ in (-0.7, 0.7):
		g.box(-SMOKEBOX_R * 0.78, 0.0, sb1 + 0.12, sb1 + 0.17, BOILER_Z + dz_ - 0.07, BOILER_Z + dz_ + 0.07, "iron", iron)
	# A handrail round the smokebox's front, on stanchions.
	hr = SMOKEBOX_R + 0.14
	arc = [Vector((hr * math.sin(a), sb1 - 0.25, BOILER_Z + hr * math.cos(a))) for a in (math.radians(-62 + 124 * k / 10) for k in range(11))]
	for a, b in zip(arc, arc[1:]):
		g.beam(a, b, 0.055, 0.055, "brass", brass, up=(0.0, 1.0, 0.0))
	# Marker lamps on the smokebox's sides.
	for s in (-1, 1):
		g.box(s * 1.18, s * 1.5, sb1 - 0.5, sb1 - 0.15, BOILER_Z + 0.75, BOILER_Z + 1.15, "metal", blk)
		g.facing([(s * 1.505, sb1 - 0.45, BOILER_Z + 0.82), (s * 1.505, sb1 - 0.2, BOILER_Z + 0.82), (s * 1.505, sb1 - 0.2, BOILER_Z + 1.08), (s * 1.505, sb1 - 0.45, BOILER_Z + 1.08)], (s, 0, 0), "lamp", srgb("8fe0a0"))
	# The saddle down to the cylinders.
	g.box(-1.6, 1.6, sb0 + 0.1, sb0 + 1.9, 1.9, BOILER_Z - 1.0, "metal", blk)
	# The balloon stack: a column, a brass band, the flare to its rolled lip, the
	# spark arrester's mesh domed over it.
	top = STACK_TOP
	base = BOILER_Z + SMOKEBOX_R - 0.05
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [
		(0.72, -0.3), (0.72, 0.1), None, (0.78, 0.1), (0.78, 0.22), None, (0.6, 0.22), (0.55, 0.3), (0.55, 0.8), None,
		(0.58, 0.95), (0.7, 1.2), (0.9, 1.5), (1.1, 1.85), (1.22, 2.15), (STACK_R - 0.02, 2.4)], "metal", blk, n=32)
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [(0.55, 0.8), (0.6, 0.82), (0.6, 0.93), (0.57, 0.95)], "brass", brass, n=28)
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [(STACK_R - 0.04, 2.4), (STACK_R + 0.06, 2.42), None, (STACK_R + 0.06, 2.56), None, (STACK_R - 0.04, 2.58)], "brass", brass, n=32)
	g.lathe((0.0, STACK_Y, base), (0.0, 0.0, 1.0), [(STACK_R - 0.04, 2.58), (0.9, 2.72), (0.45, 2.81), (0.0, top - base)], "dark", tone(PAINT["iron"], 0.7), n=32)
	for k in range(8):
		a = k / 8 * math.tau
		d = Vector((math.cos(a), math.sin(a), 0.0))
		p0 = Vector((0.0, STACK_Y, 0.0)) + d * (STACK_R - 0.06)
		p1 = Vector((0.0, STACK_Y, 0.0)) + d * 0.05
		g.beam((p0.x, p0.y, base + 2.6), (p1.x, p1.y, top - 0.05), 0.04, 0.04, "metal", blk)
	# The headlamp: a big box lantern on a bracket over the smokebox's front, a
	# brass bezel round its lens, number boards either side, a peaked roof and
	# its chimney.
	lz0, lz1 = LAMP_Z
	ly0, ly1 = LAMP_Y
	g.box(-0.62, 0.62, ly0 - 0.05, ly1 + 0.05, base, lz0, "metal", blk)
	g.beam((0.0, sb1 + 0.05, BOILER_Z + 0.9), (0.0, ly1 - 0.05, lz0 - 0.02), 0.14, 0.14, "metal", blk)
	g.box(-0.72, 0.72, ly0, ly1, lz0, lz1, "metal", blk, skip="f")
	for s in (-1, 1):
		g.box(s * 0.72, s * 0.75, ly0 + 0.3, ly1 - 0.3, lz0 + 0.4, lz1 - 0.35, "glass", PAINT["glass"])
		g.box(s * 0.7, s * 0.78, ly0, ly0 + 0.08, lz0, lz1, "brass", brass)
		g.box(s * 0.7, s * 0.78, ly1 - 0.08, ly1, lz0, lz1, "brass", brass)
	g.box(-0.72, 0.72, ly1 - 0.02, ly1, lz0, lz1, "metal", blk)
	lc = (lz0 + lz1) * 0.5
	g.lathe((0.0, ly1, lc), ax_y, [(0.66, 0.0), (0.66, 0.1), None, (0.56, 0.14), None, (0.53, 0.0)], "brass", brass, n=28)
	g.lathe((0.0, ly1, lc), ax_y, [(0.53, 0.0), (0.38, 0.06), (0.0, 0.09)], "lamp", PAINT["lamp"], n=28)
	for z in (lz0, lz1 - 0.06):
		g.box(-0.76, 0.76, ly0 - 0.04, ly1 + 0.04, z, z + 0.06, "brass", brass)
	for s in (-1, 1):
		g.facing([(s * 0.82, ly0 - 0.1, lz1 + 0.05), (s * 0.82, ly1 + 0.1, lz1 + 0.05), (0.0, ly1 + 0.1, lz1 + 0.35), (0.0, ly0 - 0.1, lz1 + 0.35)], (s * 0.3, 0.0, 0.82), "metal", blk)
	for y, f in ((ly0 - 0.1, -1), (ly1 + 0.1, 1)):
		g.facing([(-0.82, y, lz1 + 0.05), (0.82, y, lz1 + 0.05), (0.0, y, lz1 + 0.35)], (0, f, 0), "metal", blk)
	cy = (ly0 + ly1) * 0.5
	g.lathe((0.0, cy, lz1 + 0.25), (0.0, 0.0, 1.0), [(0.13, 0.0), (0.13, 0.32), None, (0.24, 0.32), (0.24, 0.4), (0.0, 0.47)], "metal", blk, n=10)
	# The bell in its yoke.
	bz = BOILER_Z + BOILER_R - 0.05
	for s in (-1, 1):
		g.box(s * 0.5, s * 0.6, BELL_Y - 0.08, BELL_Y + 0.08, bz - 0.1, bz + 1.0, "brass", brass)
	g.box(-0.6, 0.6, BELL_Y - 0.08, BELL_Y + 0.08, bz + 0.92, bz + 1.02, "brass", brass)
	g.lathe((0.0, BELL_Y, bz), (0.0, 0.0, 1.0), [(0.47, 0.22), (0.47, 0.3), (0.38, 0.42), (0.3, 0.62), (0.26, 0.82), (0.2, 0.92), (0.0, 0.96)], "brass", brass, n=20)
	g.lathe((0.0, BELL_Y, bz), (0.0, 0.0, 1.0), [(0.0, 0.25), (0.45, 0.25)], "dark", PAINT["dark"], n=20)
	# Sand dome and steam dome, black with brass caps; the safety valves on the
	# steam dome, the whistle before the cab.
	def dome(y, foot, rr, h, cap):
		zfoot = BOILER_Z + math.sqrt(max(BOILER_R ** 2 - foot ** 2, 0.0)) - bz
		g.lathe((0.0, y, bz), (0.0, 0.0, 1.0), [(foot, zfoot - 0.02), (foot * 0.95, 0.02), (rr, 0.2), (rr, cap)], "metal", blk, n=28)
		g.lathe((0.0, y, bz), (0.0, 0.0, 1.0), [(rr + 0.03, cap - 0.02), (rr + 0.03, cap + 0.06), None, (rr, cap + 0.06), (rr * 0.88, h - 0.2), (rr * 0.6, h - 0.06), (0.0, h)], "brass", brass, n=28)
	dome(SAND_Y, 0.9, 0.66, 0.92, 0.55)
	dome(DOME_Y, 1.05, 0.8, 1.27, 0.78)
	for dx in (-0.22, 0.22):
		g.lathe((dx, DOME_Y - 0.1, bz + 1.12), (0.0, 0.0, 1.0), [(0.09, 0.0), (0.09, 0.18), (0.12, 0.2), (0.12, 0.26), (0.0, 0.3)], "brass", brass, n=10)
	g.lathe((0.0, CAB_Y[1] + 0.3, bz - 0.15), (0.0, 0.0, 1.0), [(0.07, 0.0), (0.07, 0.38), None, (0.15, 0.38), (0.15, 0.78), (0.0, 0.84)], "brass", brass, n=12)
	# Cylinders, their steam chests, the guide bars; drain cocks under them.
	c0, c1 = CYL_Y
	for s in (-1, 1):
		x = s * CYL_X
		g.lathe((x, c0, CYL_Z), ax_y, [(0.0, -0.06), (CYL_R + 0.03, -0.06), (CYL_R + 0.03, 0.12), None, (CYL_R, 0.12), (CYL_R, c1 - c0 - 0.12), None, (CYL_R + 0.03, c1 - c0 - 0.12), (CYL_R + 0.03, c1 - c0 + 0.06), (0.0, c1 - c0 + 0.06)], "metal", blk, n=20)
		for yy in (c0 - 0.06, c1 + 0.06):
			g.lathe((x, yy, CYL_Z), ax_y, [(CYL_R + 0.035, -0.03), (CYL_R + 0.035, 0.03)], "brass", brass, n=20)
		g.box(x - 0.36, x + 0.36, c0 + 0.12, c1 - 0.12, CYL_Z + CYL_R - 0.05, CYL_Z + CYL_R + 0.38, "metal", blk)
		g.box(x - 0.39, x + 0.39, c0 + 0.08, c1 - 0.08, CYL_Z + CYL_R + 0.38, CYL_Z + CYL_R + 0.44, "brass", brass)
		g.box(s * 1.15, s * (CYL_X - 0.3), c0 + 0.3, c1 - 0.3, CYL_Z - 0.3, CYL_Z + 0.35, "metal", blk)
		for dz_ in (-0.2, 0.2):
			g.box(x - 0.06, x + 0.06, 4.0, c0, CYL_Z + dz_ - 0.05, CYL_Z + dz_ + 0.05, "iron", steel)
		g.box(x - 0.1, x + 0.1, 3.95, 4.15, CYL_Z - 0.34, CYL_Z + 0.34, "iron", steel)
		for yy in (c0 + 0.25, c1 - 0.25):
			g.beam((x, yy, CYL_Z - CYL_R + 0.02), (x, yy - 0.05, CYL_Z - CYL_R - 0.32), 0.05, 0.05, "brass", brass)
	# Running boards over the drivers, their red valance, the splashers, the
	# handrails on stanchions down the boiler.
	for s in (-1, 1):
		x0, x1 = s * 1.4, s * 2.42
		g.box(x0, x1, CAB_Y[1], c0 + 0.1, RUNNING_Z - 0.06, RUNNING_Z + 0.06, "metal", blk)
		g.box(x1 - s * 0.04, x1, CAB_Y[1], c0 + 0.1, RUNNING_Z - 0.3, RUNNING_Z - 0.06, "wood", PAINT["pilot"])
		g.box(x1 - s * 0.045, x1 + s * 0.005, CAB_Y[1], c0 + 0.1, RUNNING_Z - 0.31, RUNNING_Z - 0.27, "brass", brass)
		g.box(x0, x1, c0 + 0.1, SMOKEBOX_Y[1] - 0.1, CYL_Z + CYL_R + 0.44, CYL_Z + CYL_R + 0.52, "metal", blk)
		for dy in DRIVER_Y:
			splasher(g, s, dy)
		hx = s * (BOILER_R + 0.16)
		hz = BOILER_Z + 0.55
		g.beam((hx, CAB_Y[1], hz), (hx, SMOKEBOX_Y[1] - 0.25, hz), 0.06, 0.06, "brass", brass)
		for y in (CAB_Y[1] + 1.4, 1.2, 3.6, 6.2, 8.4):
			g.beam((s * (BOILER_R - 0.05), y, hz), (hx, y, hz), 0.05, 0.05, "iron", steel)
		# The feed pipe from the cab along the boiler to its check valve.
		pts = [(s * 1.6, CAB_Y[1], 3.75), (s * 1.62, -1.5, 3.75), (s * 1.62, 1.9, 3.95), (s * 1.52, 2.6, 4.35)]
		for a, b in zip(pts, pts[1:]):
			g.beam(a, b, 0.09, 0.09, "brass", tone(brass, 0.85))
		g.box(s * 1.42, s * 1.6, 2.5, 2.75, 4.25, 4.5, "brass", brass)
		# The sand pipes from the sand dome down the boiler to the rail before the
		# front driver.
		pts = [(s * 0.8, SAND_Y, bz + 0.25), (s * 1.2, SAND_Y - 0.05, BOILER_Z + 1.0), (s * 1.52, SAND_Y - 0.1, BOILER_Z + 0.3),
			(s * 1.6, SAND_Y - 0.15, RUNNING_Z + 0.08), (s * 1.6, DRIVER_Y[0] + DRIVER_R + 0.3, RUNNING_Z - 0.1), (s * 1.55, DRIVER_Y[0] + DRIVER_R + 0.2, 1.05)]
		for a, b in zip(pts, pts[1:]):
			g.beam(a, b, 0.05, 0.05, "iron", tone(iron, 1.2))
	# The air pump on the right by the cab, its pipe to the boiler; the reach rod
	# on the left from the cab to the reversing arm.
	ap = (2.0, -3.25)
	g.lathe((ap[0], ap[1], RUNNING_Z + 0.06), (0.0, 0.0, 1.0), [(0.0, 0.0), (0.3, 0.0), (0.3, 0.75), None, (0.24, 0.75), (0.24, 0.9), None,
		(0.3, 0.9), (0.3, 1.6), (0.2, 1.72), (0.0, 1.75)], "metal", blk, n=14)
	for z in (RUNNING_Z + 0.1, RUNNING_Z + 0.8, RUNNING_Z + 1.55):
		g.lathe((ap[0], ap[1], z), (0.0, 0.0, 1.0), [(0.32, 0.0), (0.32, 0.08)], "brass", brass, n=14)
	g.beam((ap[0] - 0.2, ap[1], RUNNING_Z + 1.3), (1.45, ap[1] + 0.4, BOILER_Z + 0.4), 0.08, 0.08, "brass", tone(brass, 0.85))
	g.beam((-1.7, CAB_Y[1], BOILER_Z - 0.3), (-1.7, -0.9, BOILER_Z - 0.55), 0.08, 0.1, "iron", steel)
	# The pilot: red slats raked down from the beam to a V at the rails, an iron
	# frame round them, the drawbar at its nose.
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
		g.beam((s * half, back + 0.05, top_z), (0.0, PILOT_TIP - 0.12, foot_z + 0.5), 0.09, 0.09, "metal", iron)
	g.beam((0.0, back, top_z), (0.0, PILOT_TIP - 0.08, foot_z), 0.16, 0.16, "metal", iron, up=(1.0, 0.0, 0.0))
	g.box(-2.6, 2.6, back, back + 0.14, top_z - 0.12, top_z + 0.02, "metal", iron)
	g.box(-0.18, 0.18, back + 0.1, PILOT_TIP - 0.25, 1.55, 1.7, "metal", iron)
	g.box(-0.3, 0.3, PILOT_TIP - 0.45, PILOT_TIP - 0.2, 1.45, 1.78, "metal", iron)
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
	"""The wooden cab, low and narrow behind the boiler: red boards each its own
	coat, a raised panel under the windows lined in cream with a brass number
	plate, framed windows, the side's entry and the gangway at the back open on
	the backhead and the fire's glow, an arched roof proud all round with its
	ventilator and gutters."""
	y0, y1 = CAB_Y
	cab, cream, glass, brass, dark = PAINT["cab"], PAINT["cream"], PAINT["glass"], PAINT["brass"], PAINT["dark"]
	w = CAB_HALF
	t = 0.14
	rng = np.random.default_rng(31)
	wz0, wz1 = 4.75, 6.35
	inner = tone(PAINT["inside"], 0.8)
	# The walls: boards outside, dark inside. The sides; the front round the
	# boiler; the back two posts and a header either side of the gangway.
	for s in (-1, 1):
		plank_box(g, s * (w - t), s * w, y0, y1, CAB_FLOOR, CAB_EAVE, cab, rng, skip="ud" + ("l" if s > 0 else "r"), fade=0.15)
		g.facing([(s * (w - t), y0, CAB_FLOOR), (s * (w - t), y1, CAB_FLOOR), (s * (w - t), y1, CAB_EAVE), (s * (w - t), y0, CAB_EAVE)], (-s, 0, 0), "dark", inner)
	plank_box(g, -w, w, y1 - t, y1, CAB_FLOOR, CAB_EAVE, cab, rng, skip="udb", fade=0.15)
	g.facing([(-w, y1 - t, CAB_FLOOR), (w, y1 - t, CAB_FLOOR), (w, y1 - t, CAB_EAVE), (-w, y1 - t, CAB_EAVE)], (0, -1, 0), "dark", inner)
	gw = 1.5
	for s in (-1, 1):
		plank_box(g, s * gw, s * (w - t), y0, y0 + t, CAB_FLOOR, CAB_EAVE, cab, rng, skip="ud", fade=0.15)
	plank_box(g, -gw, gw, y0, y0 + t, 6.1, CAB_EAVE, cab, rng, skip="u", fade=0.15)
	# Inside: the deck, the backhead (the boiler's end) with its gauges and the
	# fire door glowing, the reverser.
	g.box(-w + t, w - t, y0, y1 - t, CAB_FLOOR - 0.05, CAB_FLOOR, "wood", PAINT["deck"], tile=PLANK_TILE, rot=True)
	g.disc((0.0, BOILER_Y[0] + 0.02, BOILER_Z), (0.0, -1.0, 0.0), BOILER_R, "metal", tone(PAINT["black"], 1.3), n=24)
	g.box(-0.55, 0.55, BOILER_Y[0] - 0.05, BOILER_Y[0] + 0.02, 2.75, 3.75, "metal", PAINT["black"])
	g.facing([(-0.4, BOILER_Y[0] - 0.06, 2.9), (0.4, BOILER_Y[0] - 0.06, 2.9), (0.4, BOILER_Y[0] - 0.06, 3.6), (-0.4, BOILER_Y[0] - 0.06, 3.6)], (0, -1, 0), "lamp", PAINT["crack"])
	for x in (-0.6, 0.6):
		g.lathe((x, BOILER_Y[0] - 0.02, 5.35), (0.0, -1.0, 0.0), [(0.0, 0.0), (0.2, 0.0), (0.2, 0.06), (0.0, 0.08)], "brass", brass, n=12)
	g.beam((-1.6, y1 - 0.6, CAB_FLOOR), (-1.45, y1 - 0.9, 3.6), 0.08, 0.08, "iron", PAINT["steel"])
	# Each side: two framed windows, the entry aft (dark, framed), a raised panel
	# lined in cream under the windows with the brass number plate, the sill and
	# eave bands, corner posts, the grab iron at the entry.
	for s in (-1, 1):
		x = s * (w + 0.012)
		xf = s * (w + 0.04)
		for wy0, wy1 in ((y1 - 1.75, y1 - 0.45), (y1 - 3.45, y1 - 2.15)):
			q = [Vector((x, wy0, wz0)), Vector((x, wy1, wz0)), Vector((x, wy1, wz1)), Vector((x, wy0, wz1))]
			g.poly(q if s > 0 else q[::-1], "glass", glass)
			for a, b in (((wy0, wz0), (wy1, wz0)), ((wy0, wz1), (wy1, wz1)), ((wy0, wz0), (wy0, wz1)), ((wy1, wz0), (wy1, wz1)), (((wy0 + wy1) * 0.5, wz0), ((wy0 + wy1) * 0.5, wz1)), ((wy0, (wz0 + wz1) * 0.5), (wy1, (wz0 + wz1) * 0.5))):
				g.beam((xf, a[0], a[1]), (xf, b[0], b[1]), 0.09, 0.09, "wood", cream, up=(1.0, 0.0, 0.0))
		ey0, ey1 = y0 + 0.25, y1 - 3.95
		q = [Vector((x, ey0, CAB_FLOOR + 0.2)), Vector((x, ey1, CAB_FLOOR + 0.2)), Vector((x, ey1, wz1)), Vector((x, ey0, wz1))]
		g.poly(q if s > 0 else q[::-1], "dark", dark)
		for a, b in (((ey0, CAB_FLOOR + 0.2), (ey0, wz1)), ((ey1, CAB_FLOOR + 0.2), (ey1, wz1)), ((ey0, wz1), (ey1, wz1))):
			g.beam((xf, a[0], a[1]), (xf, b[0], b[1]), 0.12, 0.1, "wood", cream, up=(1.0, 0.0, 0.0))
		g.beam((s * (w + 0.08), ey0 + 0.15, CAB_FLOOR + 0.5), (s * (w + 0.08), ey0 + 0.15, wz1 - 0.3), 0.06, 0.06, "brass", brass)
		g.beam((s * (w + 0.08), ey1 - 0.15, CAB_FLOOR + 0.5), (s * (w + 0.08), ey1 - 0.15, wz1 - 0.3), 0.06, 0.06, "brass", brass)
		pz0, pz1, py0, py1 = CAB_FLOOR + 0.35, wz0 - 0.45, y1 - 3.45, y1 - 0.45
		for a, b in (((py0, pz0), (py1, pz0)), ((py0, pz1), (py1, pz1)), ((py0, pz0), (py0, pz1)), ((py1, pz0), (py1, pz1))):
			g.beam((s * (w + 0.02), a[0], a[1]), (s * (w + 0.02), b[0], b[1]), 0.05, 0.05, "wood", cream, up=(1.0, 0.0, 0.0))
		cy, cz = (py0 + py1) * 0.5, (pz0 + pz1) * 0.5
		for rr, xo, col, mat in ((1.0, 0.03, brass, "brass"), (0.8, 0.045, tone(PAINT["cab"], 0.55), "metal")):
			pts = [Vector((s * (w + xo), cy + 0.62 * rr * math.cos(a), cz + 0.36 * rr * math.sin(a))) for a in (k / 16 * math.tau for k in range(16))]
			g.facing(pts, (s, 0, 0), mat, col)
		for k in range(5):
			yy = cy - 0.3 + 0.15 * k
			g.box(s * (w + 0.045), s * (w + 0.06), yy - 0.03, yy + 0.03, cz - 0.15, cz + 0.15, "brass", brass)
		g.box(s * w, s * (w + 0.05), y0, y1, wz0 - 0.3, wz0 - 0.16, "wood", cream)
		g.box(s * w, s * (w + 0.05), y0, y1, CAB_EAVE - 0.22, CAB_EAVE - 0.08, "wood", cream)
		for y in (y0 + 0.07, y1 - 0.07):
			g.box(s * (w - 0.02), s * (w + 0.05), y - 0.09, y + 0.09, CAB_FLOOR, CAB_EAVE, "wood", cream)
		# The steps under the entry.
		for z in (1.05, 1.7):
			g.box(s * (w - 0.35), s * (w + 0.05), y0 + 0.3, y0 + 0.85, z, z + 0.07, "wood", PAINT["deck"])
		for y in (y0 + 0.32, y0 + 0.83):
			g.box(s * (w - 0.02), s * (w + 0.03), y - 0.03, y + 0.03, 1.05, CAB_FLOOR - 0.45, "iron", PAINT["iron"])
	# Front windows either side of the boiler.
	yf = y1 + 0.012
	for s in (-1, 1):
		xa, xb = sorted((s * 1.62, s * 2.25))
		q = [Vector((xa, yf, 5.2)), Vector((xa, yf, 6.4)), Vector((xb, yf, 6.4)), Vector((xb, yf, 5.2))]
		g.poly(q, "glass", glass)
		for a, b in (((xa, 5.2), (xb, 5.2)), ((xa, 6.4), (xb, 6.4)), ((xa, 5.2), (xa, 6.4)), ((xb, 5.2), (xb, 6.4))):
			g.beam((a[0], yf + 0.03, a[1]), (b[0], yf + 0.03, b[1]), 0.09, 0.09, "wood", cream, up=(0.0, 1.0, 0.0))
	# The roof: an arc through the eaves and the crown, proud all round, gutters
	# along its eaves, the ventilator on its crown.
	rise = CAB_TOP - CAB_EAVE
	R = (EAVE_HALF ** 2 + rise ** 2) / (2.0 * rise)
	cz = CAB_TOP - R
	half_ang = math.asin(EAVE_HALF / R)
	n = 14
	ry0, ry1 = y0 - 0.35, y1 + 0.3
	thick = 0.12
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
		x = top_pts[k].x
		g.box(x - 0.07, x + 0.07, ry0, ry1, top_pts[k].z - 0.14, top_pts[k].z - 0.02, "metal", tone(roof, 0.8))
	g.box(-0.55, 0.55, y0 + 2.2, y0 + 4.0, CAB_TOP - 0.06, CAB_TOP + 0.04, "metal", tone(roof, 1.15))
	g.box(-0.65, 0.65, y0 + 2.1, y0 + 4.1, CAB_TOP + 0.04, CAB_TOP + 0.1, "metal", tone(roof, 1.25))
	# A gable under the arc front and back, red up to the roof.
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
	# The tank's top deck aft of the bunker, its tool box, the back-up lamp, grab
	# irons at the back corners; rivets down the tank's seams; the brake gear.
	g.box(-w, w, -H + 0.08, COAL_BACK - 0.12, TENDER_TANK_TOP, TENDER_TANK_TOP + 0.04, "metal", iron)
	g.box(-1.1, 1.1, -H + 0.25, -H + 0.95, TENDER_TANK_TOP + 0.04, TENDER_TANK_TOP + 0.55, "wood", tone(PAINT["black"], 1.6))
	g.box(-1.15, 1.15, -H + 0.2, -H + 1.0, TENDER_TANK_TOP + 0.55, TENDER_TANK_TOP + 0.62, "metal", blk)
	g.box(1.55, 2.05, -H + 0.12, -H + 0.55, TENDER_TANK_TOP + 0.04, TENDER_TANK_TOP + 0.6, "metal", blk)
	g.lathe((1.8, -H + 0.12, TENDER_TANK_TOP + 0.32), (0.0, -1.0, 0.0), [(0.18, 0.0), (0.18, 0.04), None, (0.15, 0.05), (0.0, 0.06)], "lamp", PAINT["lamp"], n=14)
	for s in (-1, 1):
		g.beam((s * (w + 0.06), -H + 0.35, TENDER_SILL[1] + 0.3), (s * (w + 0.06), -H + 0.35, TENDER_TANK_TOP - 0.3), 0.05, 0.05, "brass", PAINT["brass"])
		for z in (TENDER_SILL[1] + 0.12, TENDER_TANK_TOP - 0.2):
			rivet_line(g, (s * (w + 0.005), -H + 0.25, z), (s * (w + 0.005), H - 0.3, z), 30, (s, 0, 0), r=0.045)
		for y in (-H + 0.3, H - 0.35):
			rivet_line(g, (s * (w + 0.005), y, TENDER_SILL[1] + 0.25), (s * (w + 0.005), y, TENDER_TANK_TOP - 0.3), 6, (s, 0, 0), r=0.045)
	for z in (TENDER_SILL[1] + 0.12, TENDER_TANK_TOP - 0.2):
		rivet_line(g, (-w + 0.2, -H + 0.08 - 0.005, z), (w - 0.2, -H + 0.08 - 0.005, z), 16, (0, -1, 0), r=0.045)
	brake_gear(g, H, TENDER_SILL[0])
	stirrups(g, H, w - 0.1, TENDER_SILL[0])
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


def low_truck(g, ty, wz):
	"""A low truck's frame round its two small axles (the smash car's: all of it
	under FLOOR, where its corridor's floor is)."""
	iron = PAINT["iron"]
	hb = LOW_BASE * 0.5
	for s in (-1, 1):
		x = s * (WHEEL_X + 0.24)
		g.box(x - 0.07, x + 0.07, ty - hb - 0.35, ty + hb + 0.35, wz + 0.12, wz + 0.26, "metal", iron)
		g.box(x - 0.07, x + 0.07, ty - hb - 0.1, ty + hb + 0.1, wz - 0.16, wz - 0.06, "metal", iron)
		for dy in (-hb, hb):
			g.box(x - 0.13, x + 0.13, ty + dy - 0.16, ty + dy + 0.16, wz - 0.14, wz + 0.2, "metal", iron)
	g.box(-WHEEL_X - 0.24, WHEEL_X + 0.24, ty - 0.22, ty + 0.22, wz + 0.08, wz + 0.26, "metal", iron)


def trucks(root, mats, ty, group, low=False):
	"""A car's two trucks, their pivots ty either side of its middle: Truck_F and
	Truck_R (swivel about Y), each its frame and two wheelsets (turn about X).
	`low`: small wheels on a low frame (LOW_WHEEL_R, LOW_BASE)."""
	r, base, frame = (LOW_WHEEL_R, LOW_BASE, low_truck) if low else (CAR_WHEEL_R, TRUCK_BASE, car_truck)
	wz = RAIL_TOP + r
	for tag, y in (("F", ty), ("R", -ty)):
		truck = empty(f"Truck_{tag}", (0.0, y, wz), parent=root)
		tg = Geo(dirt=0.8)
		frame(tg, y, wz)
		emit(f"TruckFrame_{tag}", tg, mats, parent=truck, origin=(0.0, y, wz), group=group)
		for i, dy in enumerate((base * 0.5, -base * 0.5)):
			wheelset(f"Wheels_{tag}{i + 1}", mats, truck, y + dy, wz, r, kind="disc", group=group)


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


def truss_rods(g, H, ztop, ty=None):
	"""Under a long car's floor, between its trucks (their pivots ty off the
	middle): the centre sill, and four rods down from over the trucks to two queen
	posts and a needle beam."""
	iron = PAINT["iron"]
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, ztop - 0.32, ztop, "metal", iron)
	ya = (H - BOGIE if ty is None else ty) - TRUCK_BASE * 0.5 - CAR_WHEEL_R - 0.3
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


def side_sills(g, H, top, col, xo=CAR_HALF + 0.08, depth=0.28, end=SILL_END, belly=SILL_BELLY):
	"""A low car's side sills: a fishbelly, shallow over the trucks (they show
	under it, its underside at `end`) and deep between them (to `belly`); the top
	at `top`, under the deck."""
	ty = H - BOGIE
	y1 = ty - TRUCK_BASE * 0.5 - CAR_WHEEL_R - 0.15
	y0 = max(y1 - 2.0, 0.5)
	pts = [(-H, end), (-y1, end), (-y0, belly), (y0, belly), (y1, end), (H, end)]
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


def slats(g, x0, x1, y0, y1, z0, z1, col, rng=None):
	"""Horizontal boards with gaps (SLAT apart) between z0 and z1 over the box
	x0..x1, y0..y1; their seams along them, each its own coat (rng). Returns the
	top of the last board."""
	t = 16.0 * SLAT
	z = z0
	top = z0
	while z + SLAT - SLAT_GAP <= z1 + 1e-6:
		c = board_tone(rng, col) if rng is not None else col
		g.box(x0, x1, y0, y1, z, z + SLAT - SLAT_GAP, "wood", c, rot=True, tile=t, uvo=(0.08 / 16.0 - z0 / t, 0.0))
		top = z + SLAT - SLAT_GAP
		z += SLAT
	return top


def car_door(name, mats, root, s, ya, yb, col, slatted=False, group=None, frame=None, seed=0, stripes=None):
	"""A sliding door on side s (+1 the right) over ya..yb: boards (or slats on a
	dark back) in a frame (cream) with a Z brace, its rollers on the track over it
	and a latch bar; its origin at its middle."""
	g = Geo()
	rng = np.random.default_rng(seed)
	za, zb = FLOOR + 0.04, FLOOR + DOOR_HIGH + DOOR_OVER
	x0, x1 = s * (CAR_HALF + 0.06), s * (CAR_HALF + 0.1)
	if slatted:
		g.box(x0, s * (CAR_HALF + 0.07), ya, yb, za, zb, "wood", PAINT["inside"])
		slats(g, s * (CAR_HALF + 0.07), x1, ya, yb, za, zb, col, rng)
	else:
		plank_box(g, x0, x1, ya, yb, za, zb, col, rng, skip="l" if s > 0 else "r")
	cream = frame or PAINT["cream"]
	if not FAR:
		for y in (ya + 0.5, yb - 0.5):
			g.lathe((s * (CAR_HALF + 0.1), y, zb + 0.1), (s, 0.0, 0.0), [(0.0, 0.0), (0.13, 0.0), (0.13, 0.035), (0.0, 0.035)], "metal", PAINT["iron"], n=8)
		g.box(s * (CAR_HALF + 0.11), s * (CAR_HALF + 0.14), (ya + yb) * 0.5 - 0.6, (ya + yb) * 0.5 + 0.6, FLOOR + 2.6, FLOOR + 2.7, "metal", PAINT["iron"])
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
	# The gate's leaves: black chevrons down the edge they meet on (at y = stripes).
	if stripes is not None and not FAR:
		xs = s * (CAR_HALF + 0.137)
		f = 1.0 if abs(stripes - ya) < abs(stripes - yb) else -1.0
		z = za + 0.25
		while z + 0.3 < zb - 0.2:
			pts = [(xs, stripes, z), (xs, stripes + f * 0.55, z + 0.3), (xs, stripes + f * 0.55, z + 0.6), (xs, stripes, z + 0.3)]
			g.facing(pts, (s, 0, 0), "metal", PAINT["black"])
			z += 0.75
	emit(name, g, mats, parent=root, origin=(s * (CAR_HALF + 0.09), (ya + yb) * 0.5, (za + zb) * 0.5), group=group)


def build_boxcar(mats, kind):
	"""The boxcars: `box` its doors shut, `doors` slid open, `stock` slatted with
	its doors open, `gate` its doors shut over the doorway (RailTrain slides them
	open and shut: its movers). The doorway (DOOR_LONG x DOOR_HIGH from FLOOR,
	across the car) is clear on the open ones: its floor, the walls' faces and the
	head lined dark. `smash`: a weathered boxcar, its doors shut, a corridor down
	its length (smash_shell) and each end's plug of plank shards (smash_plug), its
	walls cracked by each end. `thru`: the run's open-ended boxcar, the corridor
	open at both ends (thru_shell), its end doors swung back flat on its sides, a
	slatted band high on its sides lighting the corridor, no side doors. Every
	board its own coat of paint."""
	root = empty(kind.capitalize(), (0.0, 0.0, 0.0))
	H = LONG[kind] * 0.5
	w = CAR_HALF
	paint = PAINT[{"stock": "stock", "smash": "smash", "thru": "thru"}.get(kind, "barn")]
	cream, iron, inside = PAINT["cream"], PAINT["iron"], PAINT["inside"]
	rng = np.random.default_rng({"box": 3, "doors": 4, "stock": 5, "gate": 6, "smash": 7, "thru": 8}[kind])
	d = DOOR_LONG * 0.5
	head = FLOOR + DOOR_HIGH
	ye = H - 0.12
	hollow = kind in ("smash", "thru")
	g = Geo()
	car_ends(g, H, 1.05, FLOOR, paint)
	truss_rods(g, H, FLOOR)
	brake_gear(g, H, FLOOR)
	stirrups(g, H, w, FLOOR)
	spans = [(-ye, ye)] if kind in ("box", "smash", "thru") else [(-ye, -d), (d, ye)]
	for ya, yb in spans:
		if kind == "smash":
			smash_shell(g, ye, paint, rng)
		elif kind == "thru":
			thru_shell(g, ye, paint, rng)
		elif kind == "stock":
			t = 0.16
			ia = ya + t if ya == -ye else ya
			ib = yb - t if yb == ye else yb
			g.box(-(w - t), w - t, ia, ib, FLOOR, BOX_EAVE, "wood", inside, skip="u" + ("f" if yb == -d else "") + ("b" if ya == d else ""))
			for s in (-1, 1):
				top = slats(g, s * (w - t), s * w, ya, yb, FLOOR, BOX_EAVE - 0.4, paint, rng)
				g.box(s * (w - t), s * w, ya, yb, top + SLAT_GAP, BOX_EAVE, "wood", paint, tile=CAR_TILE)
			for end in (ya, yb):
				if abs(abs(end) - ye) < 1e-6:
					f = 1 if end > 0 else -1
					top = slats(g, -w, w, f * (ye - t), f * ye, FLOOR, BOX_EAVE - 0.4, paint, rng)
					g.box(-w, w, f * (ye - t), f * ye, top + SLAT_GAP, BOX_EAVE, "wood", paint, tile=CAR_TILE)
		else:
			skip = "u" + ("f" if yb == -d else "") + ("b" if ya == d else "")
			plank_box(g, -w, w, ya, yb, FLOOR, BOX_EAVE, paint, rng, skip=skip)
	if kind in ("doors", "stock", "gate"):
		deck_planks(g, -w, w, -d, d, FLOOR, PAINT["floor"], rng)
		g.box(-w, w, -d, d, FLOOR - 0.18, FLOOR, "wood", PAINT["floor"], skip="bfu", tile=PLANK_TILE)
		g.box(-w, w, -d, d, head, BOX_EAVE, "wood", paint, skip="bfud", tile=CAR_TILE)
		iw = w - 0.16 if kind == "stock" else w
		for y, f in ((-d, 1), (d, -1)):
			boards(g, 1, y, -iw, iw, FLOOR, head, f, inside, rng, fade=0.0)
		g.facing([(-w, -d, head), (w, -d, head), (w, d, head), (-w, d, head)], (0, 0, -1), "wood", inside)
	# Trim: corner posts and an eave band in cream, an iron sill band, the door
	# track, ladders by each end (on the run's car, the end doors lie there).
	corner_posts(g, w, ye, FLOOR, BOX_EAVE, cream)
	for s in (-1, 1):
		g.box(s * w, s * (w + 0.05), -ye, ye, BOX_EAVE - 0.38, BOX_EAVE - 0.08, "wood", cream, rot=True)
		for ya, yb in spans:
			g.box(s * w, s * (w + 0.05), ya, yb, FLOOR, FLOOR + 0.22, "metal", iron)
			rivet_line(g, (s * (w + 0.05), ya + 0.2, FLOOR + 0.11), (s * (w + 0.05), yb - 0.2, FLOOR + 0.11), int((yb - ya) / 0.6), (s, 0, 0), r=0.035, col=iron)
		if kind != "thru":
			g.box(s * w, s * (w + 0.12), -2 * d - 0.3, 2 * d + 0.3, head + DOOR_OVER + 0.02, head + DOOR_OVER + 0.16, "metal", iron)
			for sy in (-1, 1):
				ya, yb = sorted((sy * (ye - 0.85), sy * (ye - 0.3)))
				ladder(g, s * w, ya, yb, FLOOR + 0.55, BOX_EAVE - 0.6)
	# The roof: tin over boards, ribbed, a running board along its ridge on its
	# saddles; the brake wheel over the back end (on the hollow cars beside the
	# corridor's mouth).
	roof = PAINT["roof"]
	gable_roof(g, WIDE * 0.5 - 0.02, BOX_EAVE, BOX_RIDGE, -H + 0.02, H - 0.02, roof, gables=(-ye, ye), wall=paint, wall_half=w)
	y = -H + 0.9
	while y < H - 0.5:
		rt = tone(roof, rng.uniform(0.85, 1.12))
		for s in (-1, 1):
			g.beam((s * (WIDE * 0.5 - 0.05), y, BOX_EAVE + 0.01), (0.0, y, BOX_RIDGE + 0.01), 0.09, 0.07, "metal", rt)
		y += 1.5
	yy = -H + 2.0
	while yy < H - 1.0:
		g.box(-0.3, 0.3, yy - 0.08, yy + 0.08, BOX_RIDGE - 0.04, BOX_TOP - 0.12, "wood", PAINT["deck"])
		yy += 2.0
	deck_planks(g, -0.42, 0.42, -H + 0.05, H - 0.05, BOX_TOP, PAINT["deck"], rng, depth=0.12)
	by = -H + 0.2
	bx = SMASH_WIDE * 0.5 + 0.05 if hollow else 0.9
	g.beam((bx, by, FLOOR + 0.6), (bx, by, BOX_RIDGE + 0.03), 0.07, 0.07, "iron", iron)
	g.lathe((bx, by, BOX_RIDGE), (0.0, 0.0, 1.0), [(0.26, 0.0), (0.34, 0.0), (0.34, 0.06), (0.26, 0.06), (0.26, 0.0)], "metal", iron, n=16)
	for a in (0.0, math.pi / 3, 2 * math.pi / 3):
		dv = Vector((math.cos(a), math.sin(a), 0.0)) * 0.3
		c = Vector((bx, by, BOX_RIDGE + 0.03))
		g.beam(c - dv, c + dv, 0.05, 0.05, "metal", iron)
	if kind == "smash":
		side_cracks(g, ye)
	emit("Body", g, mats, parent=root, group=f"{kind} body")
	if kind == "smash":
		for tag, f, seed in (("F", 1, 5), ("B", -1, 9)):
			smash_plug(mats, root, tag, f, ye, paint, seed)
	# The doors: shut over the doorway, or slid open over the walls fore and aft;
	# the gate's in yellow, shut (RailTrain opens them).
	if kind != "thru":
		for s, side in ((1, "R"), (-1, "L")):
			# (The gate's far look has them open: it stands still, and its doorway stays clear.)
			shut = kind in ("box", "smash") or (kind == "gate" and not FAR)
			spots = (("F", 0.0, d), ("B", -d, 0.0)) if shut else (("F", d, 2 * d), ("B", -2 * d, -d))
			for half, ya, yb in spots:
				car_door(f"Door_{side}{half}", mats, root, s, ya, yb, PAINT["gate"] if kind == "gate" else paint, slatted=kind == "stock",
					group=f"{kind} body", frame=PAINT["barn"] if kind == "gate" else cream, seed=(3 if s > 0 else 7) * 10 + (1 if half == "F" else 2) + 100 * len(kind),
					stripes=0.0 if kind == "gate" and shut else None)
	trucks(root, mats, H - BOGIE, f"{kind} running gear", low=hollow)
	return root


def deck_planks(g, x0, x1, y0, y1, z, col, rng, pitch=PLANK_TILE / 16, depth=0.0):
	"""A deck's top at z of planks across the car, each its own tone (their seams
	on the texture's, every `pitch` along y); `depth` > 0 also its sides."""
	lo, hi = sorted((y0, y1))
	if FAR:
		g.box(x0, x1, lo, hi, z - max(depth, 0.02), z, "wood", col, skip="d" if depth else "dlrbf", tile=PLANK_TILE, rot=True)
		return
	k0, k1 = math.floor(lo / pitch + 1e-6), math.ceil(hi / pitch - 1e-6)
	for k in range(k0, k1):
		b0, b1 = max(lo, k * pitch), min(hi, (k + 1) * pitch)
		if b1 - b0 < 1e-4:
			continue
		c = tone(col, rng.uniform(0.8, 1.12))
		c = faded(c, rng.uniform(0.0, 0.25))
		g.facing([(x0, b0, z), (x1, b0, z), (x1, b1, z), (x0, b1, z)], (0, 0, 1), "wood", c, tile=PLANK_TILE, rot=True)
	if depth:
		g.box(x0, x1, lo, hi, z - depth, z, "wood", col, skip="ud", tile=PLANK_TILE, rot=True)


def thru_shell(g, ye, paint, rng):
	"""The run's boxcar round its corridor (SMASH_WIDE x SMASH_HIGH from FLOOR, its
	whole length, open at both ends): boards outside to a slatted band high up
	(light through it into the corridor), lined dark inside with its posts and
	carlines, a plank floor, each end a frame round the corridor's mouth, the
	end doors swung back flat on the sides."""
	w, iw, lid = CAR_HALF, SMASH_WIDE * 0.5, FLOOR + SMASH_HIGH
	inside, cream, iron = PAINT["inside"], PAINT["cream"], PAINT["iron"]
	band = (6.45, BOX_EAVE - 0.55)
	for s in (-1, 1):
		boards(g, 0, s * w, -ye, ye, FLOOR, band[0], s, paint, rng)
		g.box(s * iw, s * w, -ye, ye, band[1], BOX_EAVE, "wood", paint, skip="ld" if s > 0 else "rd", tile=CAR_TILE)
		z = band[0]
		while z + 0.28 <= band[1] + 1e-6:
			slat_col = board_tone(rng, paint)
			g.box(s * iw, s * w, -ye, ye, z, z + 0.28, "wood", slat_col, rot=True, tile=16 * 0.28)
			z += 0.4
		# Inside: the lining, darker posts every 2 m, the ceiling's carlines.
		boards(g, 0, s * iw, -ye, ye, FLOOR, band[0], -s, inside, rng, fade=0.0)
		y = -ye + 1.0
		while y < ye - 0.5:
			x = s * (iw - 0.004)
			g.facing([(x, y - 0.1, FLOOR), (x, y + 0.1, FLOOR), (x, y + 0.1, lid), (x, y - 0.1, lid)], (-s, 0, 0), "wood", tone(inside, 0.6))
			y += 2.0
		g.facing([(s * iw, -ye, band[1]), (s * iw, ye, band[1]), (s * iw, ye, lid), (s * iw, -ye, lid)], (-s, 0, 0), "wood", inside)
		g.facing([(s * iw, -ye, FLOOR), (s * w, -ye, FLOOR), (s * w, ye, FLOOR), (s * iw, ye, FLOOR)], (0, 0, -1), "wood", paint)
		for f in (-1, 1):
			boards(g, 1, f * ye, s * iw, s * w, FLOOR, BOX_EAVE, f, paint, rng)
	for f in (-1, 1):
		boards(g, 1, f * ye, -iw, iw, lid, BOX_EAVE, f, paint, rng)
		# The mouth's frame, cream.
		yf = f * (ye + 0.03)
		for a, b in (((-iw - 0.06, FLOOR), (-iw - 0.06, lid + 0.06)), ((iw + 0.06, FLOOR), (iw + 0.06, lid + 0.06)), ((-iw - 0.06, lid + 0.06), (iw + 0.06, lid + 0.06))):
			g.beam((a[0], yf, a[1]), (b[0], yf, b[1]), 0.12, 0.06, "wood", cream, up=(0.0, 1.0, 0.0))
		# The end doors, each half the mouth, swung back on their hinges flat on the
		# side, boards in a cream frame with a Z brace, iron straps.
		for s in (-1, 1):
			x0, x1 = s * (w + 0.05), s * (w + 0.09)
			ya, yb = sorted((f * (ye - iw + 0.05), f * (ye + 0.1)))
			za, zb = FLOOR + 0.1, lid - 0.05
			g.box(x0, x1, ya, yb, za, zb, "wood", paint, tile=CAR_TILE)
			xf = s * (w + 0.125)
			for z in (za, (za + zb) * 0.5 - 0.1, zb - 0.2):
				g.box(x1, xf, ya, yb, z, z + 0.2, "wood", cream, rot=True)
			for yy in (ya, yb - 0.2):
				g.box(x1, xf, yy, yy + 0.2, za, zb, "wood", cream)
			for z in (za + 0.6, zb - 0.8):
				g.box(x1, xf + s * 0.008, ya, yb, z, z + 0.08, "metal", iron)
			g.beam(((x1 + xf) * 0.5, ya + 0.2, za + 0.2), ((x1 + xf) * 0.5, yb - 0.2, (za + zb) * 0.5 - 0.1), 0.16, abs(xf - x1), "wood", cream, up=(1.0, 0.0, 0.0))
	deck_planks(g, -iw, iw, -ye, ye, FLOOR, PAINT["floor"], rng)
	g.facing([(-iw, -ye, lid), (iw, -ye, lid), (iw, ye, lid), (-iw, ye, lid)], (0, 0, -1), "wood", inside, tile=CAR_TILE)
	y = -ye + 0.75
	while y < ye - 0.3:
		g.facing([(-iw, y - 0.08, lid - 0.004), (iw, y - 0.08, lid - 0.004), (iw, y + 0.08, lid - 0.004), (-iw, y + 0.08, lid - 0.004)], (0, 0, -1), "wood", tone(inside, 0.6))
		y += 1.5


def flat_frame(g, H, paint, top=FLAT_TOP, end=SILL_END, belly=SILL_BELLY, deck_half=WIDE * 0.5 - 0.04, pockets=True, rng=None):
	"""A flatcar's frame (the flat, and under the logs, the truss and the crane):
	fishbelly sills, the end beams, the centre sill, a plank deck across the car to
	`top` (deck_half each side), stake pockets down its sides. Returns the deck's
	underside."""
	iron = PAINT["iron"]
	base = top - 0.16
	side_sills(g, H, base, paint, end=end, belly=belly)
	car_ends(g, H, end - 0.15, base, paint, half=WIDE * 0.5 - 0.04)
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, base - 0.5, base, "metal", iron)
	deck_planks(g, -deck_half, deck_half, -H, H, top, PAINT["deck"], rng if rng is not None else np.random.default_rng(int(H * 10)), depth=top - base)
	stirrups(g, H, CAR_HALF, base)
	for s in (-1, 1) if pockets else ():
		y = -H + 1.0
		while y < H - 0.5:
			g.box(s * (CAR_HALF + 0.08), s * (WIDE * 0.5 - 0.005), y - 0.12, y + 0.12, base - 0.3, base, "metal", iron)
			y += 2.0
	return base


def build_flat(mats):
	"""The flatcar: a plank deck on fishbelly sills, stake pockets down its sides."""
	root = empty("Flat", (0.0, 0.0, 0.0))
	H = FLAT_LONG * 0.5
	g = Geo()
	flat_frame(g, H, PAINT["barn"])
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
	rng = np.random.default_rng(22)
	car_ends(g, H, 1.05, FLOOR, paint, half=w)
	g.box(-0.3, 0.3, -H + 0.3, H - 0.3, FLOOR - 0.3, FLOOR, "metal", iron)
	brake_gear(g, H, FLOOR)
	plank_box(g, -w, w, -ye, ye, FLOOR, VAN_EAVE, paint, rng, skip="u", fade=0.15)
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


# --- The special cars ---------------------------------------------------------
#
# Each matches the cars lane's greybox (rail_train.gd _parts, its solids and its
# holes) block for block; the openings (OPENINGS) are proved on the glb read back.


def tone(col, k):
	return tuple(c * k for c in col)


def arch_roof(g, half, y0, y1, under, eave, crown, col, under_col=None, n=8):
	"""A low arched roof slab over x +-half, y0..y1: flat underneath at `under`,
	its top from `eave` at the sides to `crown` in the middle; its underside drawn
	in under_col (where it shows: a hood over a platform)."""
	xs = [-half + 2.0 * half * i / n for i in range(n + 1)]
	zt = [eave + (crown - eave) * (1.0 - (x / half) ** 2) for x in xs]
	for xa, za, xb, zb in zip(xs, zt, xs[1:], zt[1:]):
		g.facing([(xa, y0, za), (xb, y0, zb), (xb, y1, zb), (xa, y1, za)], (-(zb - za), 0.0, xb - xa), "metal", col)
	for y, f in ((y0, -1), (y1, 1)):
		g.facing([(xs[0], y, under)] + [(x, y, z) for x, z in zip(xs, zt)] + [(xs[-1], y, under)], (0, f, 0), "metal", col)
	for s in (-1, 1):
		g.facing([(s * half, y0, under), (s * half, y1, under), (s * half, y1, eave), (s * half, y0, eave)], (s, 0, 0), "metal", col)
	if under_col is not None:
		g.facing([(-half, y0, under), (half, y0, under), (half, y1, under), (-half, y1, under)], (0, 0, -1), "wood", under_col, tile=CAR_TILE)


def log(g, x, y0, y1, z, r, rng):
	"""A log along the car: bark round it (the board texture's seams its furrows),
	its cut ends pale with a darker heart."""
	a = rng.uniform(0.0, math.tau)
	ref = (math.sin(a), 0.0, math.cos(a))
	g.lathe((x, y0, z), (0.0, 1.0, 0.0), [(r, 0.0), (r, y1 - y0)], "wood", tone(PAINT["bark"], rng.uniform(0.8, 1.15)), n=9, ref=ref, tile=CAR_TILE)
	for y, f in ((y0, -1.0), (y1, 1.0)):
		g.disc((x, y, z), (0.0, f, 0.0), r, "metal", tone(PAINT["logend"], rng.uniform(0.85, 1.05)), n=9, ref=ref)
		g.disc((x, y + f * 0.012, z), (0.0, f, 0.0), r * 0.55, "metal", PAINT["heart"], n=7, ref=ref)


def build_logs(mats):
	"""The log car: a flat, two bundles of logs on bunks between stakes, chained
	over the top, LOG_GAP between them, open above (slot across it). Each bundle
	fills its solid: the car's width, the deck to LOGS_TOP."""
	root = empty("Logs", (0.0, 0.0, 0.0))
	H = LOGS_LONG * 0.5
	w = WIDE * 0.5
	stake, iron = PAINT["stake"], PAINT["iron"]
	g = Geo()
	base = flat_frame(g, H, PAINT["barn"])
	load = Geo(dirt=0.45)
	rng = np.random.default_rng(23)
	gh, ends = LOG_GAP * 0.5, H - LOG_IN
	xr = w - 0.2 - LOG_R                     # the outer logs' middles
	pitch = 2.0 * xr / (LOG_ACROSS - 1)
	zr = FLAT_TOP + BUNK + LOG_R
	for ya, yb in ((-ends, -gh), (gh, ends)):
		# Stakes in the flat's pockets near the bundle's ends, a bunk across under
		# the logs at each, two chains over the top down to the deck, a binder.
		for y in (ya + 0.4, yb - 0.4):
			g.box(-w + 0.18, w - 0.18, y - 0.18, y + 0.18, FLAT_TOP, FLAT_TOP + BUNK, "wood", stake)
			for s in (-1, 1):
				g.box(s * (w - 0.16), s * w, y - 0.15, y + 0.15, base - 0.3, LOGS_TOP, "wood", stake)
		for t in (0.3, 0.7):
			y = ya + (yb - ya) * t
			ztop = zr + (LOG_ROWS - 1) * LOG_R * 1.96 + LOG_R + 0.05
			g.beam((-w + 0.2, y, ztop), (w - 0.2, y, ztop), 0.07, 0.07, "iron", iron)
			for s in (-1, 1):
				g.beam((s * (w - 0.2), y, ztop), (s * (w - 0.12), y, FLAT_TOP), 0.07, 0.07, "iron", iron)
			g.box(w - 0.15, w - 0.06, y - 0.06, y + 0.06, 4.0, 4.5, "metal", iron)
		for k in range(LOG_ROWS):
			for i in range(LOG_ACROSS):
				r = LOG_R + rng.uniform(-0.05, 0.015)
				x = -xr + i * pitch + rng.uniform(-0.03, 0.03)
				z = zr + k * LOG_R * 1.96 + (r - LOG_R) * (1.0 if k == 0 else 0.3)
				log(load, x, ya + rng.uniform(0.03, 0.25), yb - rng.uniform(0.03, 0.25), z, r, rng)
	emit("Body", g, mats, parent=root, group="logs body")
	emit("Load", load, mats, parent=root, group="logs body")
	trucks(root, mats, H - BOGIE, "logs running gear")
	return root


def build_culvert(mats):
	"""The culvert car: a low well flat, its deck the corridor's floor (FLOOR, on low
	trucks), carrying three-sided concrete box culverts end to end, their walls and
	roofs RailTrain's solid round the run's corridor (rail_train.gd CULVERTS): each
	chamfered along its top, its joint's collar at its front, lifting pockets on
	its roof, a strap over its middle down to the deck's edge, timber blocking
	along its feet."""
	root = empty("Culvert", (0.0, 0.0, 0.0))
	H = CULVERT_LONG * 0.5
	rng = np.random.default_rng(12)
	g = Geo()
	base = flat_frame(g, H, PAINT["black"], top=FLOOR, end=0.98, belly=0.8, rng=rng)
	emit("Body", g, mats, parent=root, group="culvert body")
	c = Geo(dirt=0.35)
	iw, lid = SMASH_WIDE * 0.5, FLOOR + SMASH_HIGH
	side, top, ch = CULVERT_SIDE - 0.04, CULVERT_TOP - 0.03, 0.2
	con, iron = PAINT["concrete"], PAINT["iron"]
	for b in sorted(PARTS["culvert"]["solid"], key=lambda b: b[2]):
		if abs(b[0] + iw) > 1e-3 or abs(b[1] - lid) > 1e-3:
			continue
		ya, yb = -b[5], -b[2]
		k = tone(con, rng.uniform(0.9, 1.06))
		inner = tone(k, 0.72)
		for s in (-1, 1):
			boards(c, 0, s * side, ya, yb, FLOOR, top - ch, s, k, rng, pitch=1.5, fade=-0.1, mat="concrete", tile=3.0, vary=0.35)
			c.facing([(s * iw, ya, FLOOR), (s * iw, yb, FLOOR), (s * iw, yb, lid), (s * iw, ya, lid)], (-s, 0, 0), "concrete", inner, tile=3.0)
			c.facing([(s * side, ya, top - ch), (s * side, yb, top - ch), (s * (side - ch), yb, top), (s * (side - ch), ya, top)], (s, 0, 1), "concrete", tone(k, 1.05), tile=3.0)
			# The timber blocking along its foot.
			y = ya + 0.6
			while y < yb - 0.3:
				c.box(s * side, s * (side + 0.05), y - 0.25, y + 0.25, FLOOR, FLOOR + 0.22, "wood", PAINT["deck"])
				y += 2.2
		c.facing([(-side + ch, ya, top), (side - ch, ya, top), (side - ch, yb, top), (-side + ch, yb, top)], (0, 0, 1), "concrete", tone(k, 1.08), tile=3.0)
		c.facing([(-iw, ya, lid), (iw, ya, lid), (iw, yb, lid), (-iw, yb, lid)], (0, 0, -1), "concrete", tone(inner, 0.85), tile=3.0)
		for y, f in ((ya, -1), (yb, 1)):
			end = [(-side, FLOOR), (-iw, FLOOR), (-iw, lid), (iw, lid), (iw, FLOOR), (side, FLOOR), (side, top - ch), (side - ch, top), (-side + ch, top), (-side, top - ch)]
			for poly in ([end[0], end[1], end[2], end[9]], [end[4], end[5], end[6], end[3]], [end[9], end[2], end[3], end[6], end[7], end[8]]):
				c.facing([(x, y, z) for x, z in poly], (0, f, 0), "concrete", tone(k, 0.95), tile=3.0)
		# The joint's collar at its front end, proud all round.
		if not FAR:
			yc0, yc1 = yb - 0.3, yb - 0.04
			for s in (-1, 1):
				c.box(s * side, s * (side + 0.03), yc0, yc1, FLOOR + 0.22, top - ch, "concrete", tone(k, 0.9), skip="l" if s > 0 else "r", tile=3.0)
			c.box(-side + ch, side - ch, yc0, yc1, top, top + 0.025, "concrete", tone(k, 0.9), skip="d", tile=3.0)
			# Lifting pockets on the roof, the strap over its middle with its ratchet.
			for yy in (ya + 1.2, yb - 1.5):
				for xx in (-1.2, 1.2):
					c.facing([(xx - 0.15, yy - 0.15, top + 0.004), (xx + 0.15, yy - 0.15, top + 0.004), (xx + 0.15, yy + 0.15, top + 0.004), (xx - 0.15, yy + 0.15, top + 0.004)], (0, 0, 1), "dark", PAINT["dark"])
			ym = (ya + yb) * 0.5
			c.box(-side + ch, side - ch, ym - 0.07, ym + 0.07, top, top + 0.025, "metal", iron, skip="d")
			for s in (-1, 1):
				c.beam((s * (side - ch), ym, top + 0.012), (s * (side + 0.012), ym, top - ch), 0.14, 0.025, "metal", iron, up=(s, 0.0, 1.0))
				c.box(s * side, s * (side + 0.025), ym - 0.07, ym + 0.07, FLOOR, top - ch, "metal", iron, skip="l" if s > 0 else "r")
			c.box(side - 0.02, side + 0.04, ym - 0.12, ym + 0.12, FLOOR + 1.2, FLOOR + 1.6, "metal", tone(iron, 1.3))
	emit("Load", c, mats, parent=root, group="culvert body")
	trucks(root, mats, H - BOGIE, "culvert running gear", low=True)
	return root


def build_truss(mats):
	"""A bridge truss section on a heavy flat (its deck lowered to TRUSS_DECK): two
	side trusses, a top chord over each, its middle panel open (TRUSS_PANEL along,
	the deck to under the chord), its end panels solid plates with the posts and
	braces in relief on both faces (what you see is what you hit); struts across
	the top over the middle panel's ends and the truss's ends."""
	root = empty("Truss", (0.0, 0.0, 0.0))
	H = TRUSS_LONG * 0.5
	w = WIDE * 0.5
	g = Geo()
	flat_frame(g, H, PAINT["black"], top=TRUSS_DECK, end=1.45, belly=1.05, deck_half=w - TRUSS_SIDE, pockets=False)
	t = Geo(dirt=0.5)
	steel = PAINT["girder"]
	web = tone(steel, 0.78)
	top = TRUSS_TOP - CHORD
	tl = H - TRUSS_IN
	d = TRUSS_PANEL * 0.5
	z0 = TRUSS_DECK
	for s in (-1, 1):
		xo, xi = s * w, s * (w - TRUSS_SIDE)
		xc = s * (w - TRUSS_SIDE * 0.5)
		t.box(xi, xo, -tl, tl, top, TRUSS_TOP, "metal", steel)
		t.box(xi, xo, -tl, tl, z0 - 0.35, z0, "metal", steel)
		for f in (-1, 1):
			ya, yb = sorted((f * d, f * tl))
			t.box(s * (w - 0.1), s * (w - TRUSS_SIDE + 0.1), ya, yb, z0, top, "metal", web, skip="dubf")
			# Posts: by the open panel, the middle, the end; an X in each bay.
			pin, pmid, pend = f * (d + 0.2), f * (d + tl) * 0.5, f * (tl - 0.25)
			for pc, half in ((pin, 0.2), (pmid, 0.2), (pend, 0.25)):
				t.box(xi, xo, pc - half, pc + half, z0, top, "metal", steel)
			for a, b in ((pin + f * 0.2, pmid - f * 0.2), (pmid + f * 0.2, pend - f * 0.25)):
				for za, zb in ((z0, top), (top, z0)):
					t.beam((xc, a, za), (xc, b, zb), 0.32, TRUSS_SIDE, "metal", steel, up=(1.0, 0.0, 0.0))
	for y0, y1 in ((-d - 0.4, -d), (d, d + 0.4), (-tl, -tl + 0.4), (tl - 0.4, tl)):
		t.box(-(w - TRUSS_SIDE), w - TRUSS_SIDE, y0, y1, top, TRUSS_TOP, "metal", steel)
	emit("Body", g, mats, parent=root, group="truss body")
	emit("Load", t, mats, parent=root, group="truss body")
	trucks(root, mats, H - BOGIE, "truss running gear")
	return root


def build_crane(mats):
	"""The wrecking crane on a flat: its house on a turntable (windows, a door, the
	counterweight at the front, a stack), the gantry over the house's back, and the
	boom slung back from its foot between the gantry's posts over the car behind (its
	idler), BOOM_LOW to BOOM_TOP. Nodes: Body (the flat), House (its origin on the
	turntable's pivot), Boom (in House, its origin on the foot's pin)."""
	root = empty("Crane", (0.0, 0.0, 0.0))
	H = CRANE_LONG * 0.5
	g = Geo()
	flat_frame(g, H, PAINT["black"])
	emit("Body", g, mats, parent=root, group="crane body")
	paint, cream, iron, roof = PAINT["crane"], PAINT["cream"], PAINT["iron"], PAINT["roof"]
	hb, hf, htop = CRANE_HOUSE
	pivot = (0.0, (hb + hf) * 0.5, FLAT_TOP)
	hw = CRANE_HALF - 0.09     # its walls: the windows' frames stand out to CRANE_HALF
	eave = htop - 0.25
	floor = FLAT_TOP + 0.3
	front = hf - 0.4
	hg = Geo()
	hg.lathe(pivot, (0.0, 0.0, 1.0), [(2.3, 0.0), (2.3, 0.3)], "metal", iron, n=24)
	hg.box(-hw, hw, hb, hf, floor - 0.12, floor, "metal", iron, skip="u")
	hb = hb + 0.1      # the back wall in from the roof's edge: its window's frame stands out to it
	hg.box(-hw, hw, hb, front, floor, eave, "wood", paint, skip="ud", tile=CAR_TILE)
	hg.box(-2.3, 2.3, front, hf, floor, 5.4, "metal", tone(iron, 0.8), skip="d")
	arch_roof(hg, CRANE_HALF, CRANE_HOUSE[0], hf, eave, eave + 0.03, htop, roof, under_col=PAINT["inside"])
	for sx in (-1, 1):
		for y in (hb, front):
			ya, yb = sorted((y, y - 0.18 if y > 0 else y + 0.18))
			hg.box(sx * (hw - 0.16), sx * (hw + 0.05), ya, yb, floor, eave, "wood", cream)
		hg.box(sx * hw, sx * (hw + 0.05), hb, front, eave - 0.32, eave - 0.06, "wood", cream, rot=True)
		hg.box(sx * hw, sx * (hw + 0.05), hb, front, floor, floor + 0.2, "metal", iron)
		for y0, y1 in ((5.6, 7.9), (-5.4, -3.4)):
			window(hg, sx * (hw + 0.01), 0, y0, y1, 4.8, 6.3, (sx, 0, 0), mullion=True)
		xd = sx * (hw + 0.01)
		hg.facing([(xd, -1.2, floor + 0.05), (xd, 1.2, floor + 0.05), (xd, 1.2, 6.0), (xd, -1.2, 6.0)], (sx, 0, 0), "wood", PAINT["inside"])
		for a, b in (((-1.2, floor), (-1.2, 6.0)), ((1.2, floor), (1.2, 6.0)), ((-1.2, 6.0), (1.2, 6.0))):
			hg.beam((xd + sx * 0.03, a[0], a[1]), (xd + sx * 0.03, b[0], b[1]), 0.14, 0.06, "wood", cream, up=(1.0, 0.0, 0.0))
	window(hg, -1.4, 1.4, front + 0.01, 0, 5.7, 6.6, (0, 1, 0), mullion=True)
	window(hg, -1.0, 1.0, hb - 0.01, 0, 4.8, 6.3, (0, -1, 0), mullion=True)
	hg.lathe((0.0, 7.4, eave - 0.1), (0.0, 0.0, 1.0), [(0.3, 0.0), (0.3, 1.15), (0.4, 1.27), (0.4, 1.45)], "metal", PAINT["black"], n=12)
	# The gantry: a leg each side leaning in, a cross-head, the boom's foot between.
	gy = sum(GANTRY_Y) * 0.5
	for sx in (-1, 1):
		hg.beam((sx * 1.3, gy, eave - 0.1), (sx * 1.0, gy, BOOM_TOP - 0.15), 0.32, 0.5, "metal", iron, up=(0.0, 1.0, 0.0))
		hg.box(sx * 0.5, sx * 0.78, gy - 0.3, gy + 0.3, eave - 0.1, BOOM_LOW + 0.2, "metal", iron)
	hg.box(-1.45, 1.45, gy - 0.25, gy + 0.25, BOOM_TOP - 0.3, BOOM_TOP, "metal", iron)
	pin = (0.0, gy, BOOM_LOW + 0.15)
	hg.lathe((-0.8, gy, pin[2]), (1.0, 0.0, 0.0), [(0.12, 0.0), (0.12, 1.6)], "metal", iron, n=10)
	house = emit("House", hg, mats, parent=root, origin=pivot, group="crane body")
	# The boom: a lattice girder, four chords laced on every face; its head a sheave.
	bg = Geo(dirt=0.3)
	ochre = PAINT["boom"]
	bw = BOOM_WIDE * 0.5
	y0, tip = GANTRY_Y[1] - 0.1, -(H + GAP * 0.5 + BOOM_OVER)
	for sx in (-1, 1):
		for za, zb in ((BOOM_LOW, BOOM_LOW + 0.1), (BOOM_TOP - 0.1, BOOM_TOP)):
			bg.box(sx * (bw - 0.16), sx * bw, tip, y0, za, zb, "metal", ochre)
		y = y0
		up = True
		while y - 0.5 > tip + 0.6:
			za, zb = (BOOM_LOW + 0.1, BOOM_TOP - 0.1) if up else (BOOM_TOP - 0.1, BOOM_LOW + 0.1)
			bg.beam((sx * (bw - 0.08), y, za), (sx * (bw - 0.08), y - 0.5, zb), 0.07, 0.05, "metal", ochre, up=(1.0, 0.0, 0.0))
			y -= 0.5
			up = not up
	for z in (BOOM_LOW + 0.05, BOOM_TOP - 0.05):
		y = y0
		side = -1
		while y - 1.0 > tip + 0.6:
			bg.beam((side * (bw - 0.16), y, z), (-side * (bw - 0.16), y - 1.0, z), 0.08, 0.08, "metal", ochre)
			y -= 1.0
			side = -side
	for sx in (-1, 1):
		bg.box(sx * (bw - 0.16), sx * bw, tip, tip + 0.7, BOOM_LOW, BOOM_TOP, "metal", iron)
	bg.lathe((-bw + 0.16, tip + 0.35, (BOOM_LOW + BOOM_TOP) * 0.5), (1.0, 0.0, 0.0), [(0.16, 0.0), (0.16, BOOM_WIDE - 0.32)], "metal", iron, n=10)
	emit("Boom", bg, mats, parent=house, origin=pin, group="crane body")
	trucks(root, mats, H - BOGIE, "crane running gear")
	return root


def build_coach(mats):
	"""A passenger coach, deep green with gold lines: its body between the end
	platforms (COACH_PLATFORM each), railed round to COACH_RAIL, under the hoods of
	its arched roof (HOOD deep); end doors, windows down each side. Two coaches
	coupled leave the gap between their end walls, over the railings and under the
	hoods. Its trucks are under the body (COACH_TRUCK), off the platforms."""
	root = empty("Coach", (0.0, 0.0, 0.0))
	H = COACH_LONG * 0.5
	w = CAR_HALF
	ye = H - COACH_PLATFORM - 0.1      # its end walls: their doors' frames stand out to the gap
	eave = COACH_TOP - HOOD
	paint, gold, cream, iron, brass = PAINT["coach"], PAINT["gold"], PAINT["cream"], PAINT["iron"], PAINT["brass"]
	g = Geo()
	rng = np.random.default_rng(21)
	car_ends(g, H, 1.05, FLOOR, paint, half=w)
	truss_rods(g, H, FLOOR, ty=COACH_TRUCK)
	brake_gear(g, COACH_TRUCK + BOGIE, FLOOR)
	for s in (-1, 1):
		g.box(s * (w - 0.25), s * w, -H + 0.3, H - 0.3, FLOOR - 0.3, FLOOR, "metal", iron, skip="u")
	plank_box(g, -w, w, -ye, ye, FLOOR, eave, paint, rng, skip="ud", fade=0.12)
	corner_posts(g, w, ye, FLOOR, eave, tone(paint, 0.7), wide=0.14, proud=0.04)
	for s in (-1, 1):
		for z0, z1 in ((3.3, 3.5), (7.05, 7.2)):
			g.box(s * w, s * (w + 0.04), -ye, ye, z0, z1, "brass", gold)
		g.box(s * w, s * (w + 0.05), -ye, ye, FLOOR, FLOOR + 0.22, "metal", iron)
		n = 7
		for k in range(n):
			yc = -ye + 0.6 + (2.0 * ye - 1.2) * (k + 0.5) / n
			window(g, s * (w + 0.01), 0, yc - 0.62, yc + 0.62, 4.3, 6.6, (s, 0, 0))
	for f in (-1, 1):
		yw = f * ye
		# The end wall: its door (a window in it) and a window either side.
		g.facing([(-0.9, yw + f * 0.01, FLOOR + 0.05), (0.9, yw + f * 0.01, FLOOR + 0.05), (0.9, yw + f * 0.01, 6.4), (-0.9, yw + f * 0.01, 6.4)], (0, f, 0), "wood", PAINT["inside"])
		window(g, -0.55, 0.55, yw + f * 0.02, 0, 4.4, 5.9, (0, f, 0))
		for a, b in (((-0.9, FLOOR), (-0.9, 6.4)), ((0.9, FLOOR), (0.9, 6.4)), ((-0.9, 6.4), (0.9, 6.4))):
			g.beam((a[0], yw + f * 0.04, a[1]), (b[0], yw + f * 0.04, b[1]), 0.14, 0.06, "wood", cream, up=(0.0, 1.0, 0.0))
		for x0, x1 in ((-2.3, -1.4), (1.4, 2.3)):
			window(g, x0, x1, yw + f * 0.02, 0, 4.3, 6.6, (0, f, 0))
		g.box(-w, w, yw + f * 0.005, yw + f * 0.045, 7.05, 7.2, "brass", gold)
		# The platform: a plank deck, railed round (brass top rail, iron posts and a
		# mid rail), a step down each side.
		ya, yb = sorted((yw, f * (H - 0.02)))
		g.box(-w, w, ya, yb, FLOOR - 0.14, FLOOR, "wood", PAINT["deck"], tile=PLANK_TILE, rot=True)
		ytop = COACH_RAIL - 0.05
		yr = f * (H - RAIL_BAR * 0.5)
		xr = WIDE * 0.5 - RAIL_BAR * 0.5
		for s in (-1, 1):
			g.beam((s * xr, yw + f * 0.05, ytop), (s * xr, yr, ytop), 0.08, 0.08, "brass", brass)
			g.beam((s * xr, yw + f * 0.05, FLOOR + 0.35), (s * xr, yr, FLOOR + 0.35), 0.06, 0.06, "iron", iron)
			for y in (yw + f * 0.15, (yw + yr) * 0.5, yr):
				g.beam((s * xr, y, FLOOR), (s * xr, y, ytop), 0.07, 0.07, "iron", iron)
			ys = sorted((f * (H - 1.7), f * (H - 0.5)))
			g.box(s * (w - 0.5), s * (w + 0.06), ys[0], ys[1], 0.94, 1.02, "wood", PAINT["deck"])
			for y in ys:
				g.box(s * (w - 0.03), s * (w + 0.03), y - 0.03, y + 0.03, 0.94, FLOOR - 0.14, "metal", iron)
		g.beam((-xr, yr, ytop), (xr, yr, ytop), 0.08, 0.08, "brass", brass)
		g.beam((-xr, yr, FLOOR + 0.35), (xr, yr, FLOOR + 0.35), 0.06, 0.06, "iron", iron)
		for x in (-1.0, 1.0):
			g.beam((x, yr, FLOOR), (x, yr, ytop), 0.07, 0.07, "iron", iron)
	arch_roof(g, WIDE * 0.5, -H, H, eave, eave + 0.1, COACH_TOP, PAINT["roof"], under_col=PAINT["inside"])
	emit("Body", g, mats, parent=root, group="coach body")
	trucks(root, mats, COACH_TRUCK, "coach running gear")
	return root


def smash_shell(g, ye, paint, rng):
	"""The smash car's walls round its corridor (SMASH_WIDE x SMASH_HIGH from FLOOR,
	its whole length): a boxcar's outside, lined dark inside, a plank floor, each
	end's face a frame round its plug's hole."""
	w, iw, lid = CAR_HALF, SMASH_WIDE * 0.5, FLOOR + SMASH_HIGH
	inside = PAINT["inside"]
	for s in (-1, 1):
		boards(g, 0, s * w, -ye, ye, FLOOR, BOX_EAVE, s, paint, rng, fade=0.3)
		g.facing([(s * iw, -ye, FLOOR), (s * iw, ye, FLOOR), (s * iw, ye, lid), (s * iw, -ye, lid)], (-s, 0, 0), "wood", inside, tile=CAR_TILE)
		g.facing([(s * iw, -ye, FLOOR), (s * w, -ye, FLOOR), (s * w, ye, FLOOR), (s * iw, ye, FLOOR)], (0, 0, -1), "wood", paint)
		for f in (-1, 1):
			y = f * ye
			boards(g, 1, y, s * iw, s * w, FLOOR, BOX_EAVE, f, paint, rng, fade=0.3)
	for f in (-1, 1):
		y = f * ye
		boards(g, 1, y, -iw, iw, lid, BOX_EAVE, f, paint, rng, fade=0.3)
	g.facing([(-iw, -ye, lid), (iw, -ye, lid), (iw, ye, lid), (-iw, ye, lid)], (0, 0, -1), "wood", inside, tile=CAR_TILE)
	yf = BOX_LONG * 0.5 - 0.3      # short of the end beams (their tops are FLOOR too)
	g.facing([(-iw, -yf, FLOOR), (iw, -yf, FLOOR), (iw, yf, FLOOR), (-iw, yf, FLOOR)], (0, 0, 1), "wood", PAINT["floor"], tile=PLANK_TILE, rot=True)


def crack_stroke(g, s, x, y, z, way, rng, steps, width=0.11, branch=True):
	"""A jagged crack glowing on a side wall (x its face, s its side), from (y, z)
	on along `way` (+1 or -1 along the car), tapering, a branch off it."""
	glow = PAINT["crack"]
	a = rng.uniform(-0.6, 0.6)
	p = Vector((y, z))
	for i in range(steps):
		a = max(-1.1, min(1.1, a + rng.uniform(-0.7, 0.7)))
		q = p + Vector((way * math.cos(a), math.sin(a))) * rng.uniform(0.3, 0.55)
		q.y = max(FLOOR + 0.3, min(BOX_EAVE - 0.5, q.y))
		w0 = width * (1.0 - i / steps) + 0.02
		w1 = width * (1.0 - (i + 1) / steps) + 0.02
		n = Vector((-(q - p).y, (q - p).x)).normalized()
		pts = [p - n * w0 * 0.5, q - n * w1 * 0.5, q + n * w1 * 0.5, p + n * w0 * 0.5]
		g.facing([(x, v.x, v.y) for v in pts], (s, 0, 0), "lamp", glow)
		if branch and i == steps // 2:
			crack_stroke(g, s, x, q.x, q.y, way, rng, 3, width=w1, branch=False)
		p = q


def side_cracks(g, ye):
	"""Cracks glowing down the smash car's sides from each end, where it bursts."""
	rng = np.random.default_rng(17)
	x = CAR_HALF + 0.056
	for s in (-1, 1):
		for f in (-1, 1):
			for z in (3.4, 6.2):
				crack_stroke(g, s, s * x, f * (ye - 0.3), z + rng.uniform(-0.4, 0.4), -f, rng, 7)


def smash_plug(mats, root, tag, f, ye, paint, seed):
	"""An end's plug (f +1 the front): upright boards filling the corridor's mouth,
	flush with the end, broken across along jagged cracks into shards of a board
	or less, two battens behind, and behind them the glow (Cover_<tag>, facing out)
	showing through the cracks. All inside the end's plate (SMASH_PLATE deep).
	CrackPlug_<tag> holds them, each shard (Shard_<tag>NN) its origin at its middle."""
	rng = np.random.default_rng(seed)
	iw, lid = SMASH_WIDE * 0.5, FLOOR + SMASH_HIGH
	n = round(SMASH_WIDE / PLUG_BOARD)
	bw = SMASH_WIDE / n
	yo, yi = f * ye, f * (ye - PLUG_THICK)
	plug = empty(f"CrackPlug_{tag}", (0.0, f * (BOX_LONG * 0.5 - SMASH_PLATE * 0.5), (FLOOR + lid) * 0.5), parent=root)
	# The cracks: jagged lines across runs of boards, their heights at every
	# board's edges and middle (k: half boards from the left).
	lines = []
	for zc, a, b in ((4.9, 0, n), (6.8, 0, n // 2 + 1), (3.0, n // 2 - 1, n), (7.6, n // 2 + 2, n), (2.5, 0, 3)):
		zs = zc + rng.uniform(-0.3, 0.3)
		pts = {}
		for k in range(2 * a, 2 * b + 1):
			pts[k] = min(lid - 0.45, max(FLOOR + 0.5, zs + rng.uniform(-0.25, 0.25)))
			zs += rng.uniform(-0.18, 0.18)
		lines.append((a, b, pts))
	wood, raw, back = paint, PAINT["raw"], PAINT["inside"]
	tile = 16.0 * bw
	count = 0

	def shard(poly, broke, name):
		nonlocal count
		sg = Geo()
		front = [(x, yo, z) for x, z in poly]
		sg.facing(front, (0, f, 0), "wood", wood, tile=tile)
		sg.facing([(x, yi, z) for x, z in poly], (0, -f, 0), "wood", back, tile=tile)
		for i, (p, q) in enumerate(zip(poly, poly[1:] + poly[:1])):
			out = (q[1] - p[1], 0.0, -(q[0] - p[0]))
			sg.facing([(p[0], yo, p[1]), (q[0], yo, q[1]), (q[0], yi, q[1]), (p[0], yi, p[1])], out, "wood", raw if broke[i] else wood)
		mid = Vector(np.array(sg.v).mean(axis=0))
		count += 1
		emit(f"Shard_{tag}{count:02d}", sg, mats, parent=plug, origin=mid, group="smash plugs")

	for i in range(n):
		x0, x1 = -iw + bw * i, -iw + bw * (i + 1)
		if i == n // 2 - 1:
			x1 -= PLUG_GAP * 0.5      # the split down the middle
		if i == n // 2:
			x0 += PLUG_GAP * 0.5
		xm = (x0 + x1) * 0.5
		cuts = sorted((tuple(pts[k] for k in (2 * i, 2 * i + 1, 2 * i + 2)) for a, b, pts in lines if a <= i < b), key=lambda c: c[1])
		kept = []
		for c in cuts:
			if not kept or min(c[j] - kept[-1][j] for j in range(3)) > 0.7:
				kept.append(c)
		g2 = PLUG_GAP * 0.5
		edges = [None] + kept + [None]
		for lo, hi in zip(edges, edges[1:]):
			bottom = [(x0, FLOOR), (x1, FLOOR)] if lo is None else [(x0, lo[0] + g2), (xm, lo[1] + g2), (x1, lo[2] + g2)]
			top = [(x1, lid), (x0, lid)] if hi is None else [(x1, hi[2] - g2), (xm, hi[1] - g2), (x0, hi[0] - g2)]
			poly = bottom + top
			nb, nt = len(bottom), len(top)
			broke = [lo is not None] * (nb - 1) + [False] + [hi is not None] * (nt - 1) + [False]
			shard(poly, broke, None)
	# Two battens behind the boards, split down the middle with them.
	yb = f * (ye - PLUG_THICK - 0.14)
	for z0, z1 in ((3.2, 3.55), (6.4, 6.75)):
		for xa, xb in ((-iw + 0.05, -PLUG_GAP * 0.5), (PLUG_GAP * 0.5, iw - 0.05)):
			sg = Geo()
			sg.box(xa, xb, yi, yb, z0, z1, "wood", tone(PAINT["inside"], 1.4), tile=CAR_TILE)
			count += 1
			emit(f"Shard_{tag}{count:02d}", sg, mats, parent=plug, origin=((xa + xb) * 0.5, (yi + yb) * 0.5, (z0 + z1) * 0.5), group="smash plugs")
	# The glow behind, brightest in the middle, facing out (from inside, the
	# cracks show the day).
	cg = Geo(dirt=0.0)
	yc = f * (BOX_LONG * 0.5 - SMASH_PLATE + 0.1)
	k = 6
	ids = []
	for j in range(k + 1):
		row = []
		for i in range(k + 1):
			x = -iw + SMASH_WIDE * i / k
			z = FLOOR + SMASH_HIGH * j / k
			fall = 1.0 - min(1.0, math.hypot(x / iw, (z - (FLOOR + lid) * 0.5) / (SMASH_HIGH * 0.5)) * 0.75)
			row.append(cg.vert((x, yc, z), (0.0, 0.0), tone(PAINT["crack"], 0.35 + 0.65 * fall)))
		ids.append(row)
	for j in range(k):
		for i in range(k):
			quad = [ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]]
			cg.face(quad[::-1] if f > 0 else quad, "lamp")
	emit(f"Cover_{tag}", cg, mats, parent=plug, origin=(0.0, yc, (FLOOR + lid) * 0.5), group="smash plugs")
	print(f"plug {tag}: {count} shards")

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


def paint_concrete(W):
	"""Precast concrete: a soft mottle, aggregate speckle, the form boards' lines
	every fifth of the tile, a few drips down from them."""
	rng = np.random.default_rng(61)
	mott = spectral(W, W, 1.6, 62)
	fine = spectral(W, W, 0.2, 63)
	drip = spectral(W, W, 0.9, 64, sx=1.0, sy=10.0)
	v = np.arange(W)[:, None] / W
	lines = np.exp(-((((v * 2.0) % 1.0) - 0.5) * W / 2.0 / 1.0) ** 2)
	base = 0.9 + 0.08 * (mott - 0.5) + 0.07 * (fine - 0.5) - 0.015 * lines - 0.05 * np.clip(drip - 0.6, 0.0, 1.0)
	speck = rng.random((W, W)) < 0.012
	base = np.where(speck, base * 0.82, base)
	col = np.clip(np.stack((base, base * 0.99, base * 0.96), axis=-1), 0, 1)
	hgt = 0.25 * (fine - 0.5) - 0.4 * lines - 0.2 * speck
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
	for name, fn in (("wood", paint_wood), ("metal", paint_metal), ("coal", paint_coal), ("concrete", paint_concrete)):
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
import_script/path="res://assets/models/train/train_import.gd"
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


def far_lod(kind, fn, mats, root):
	"""The far look: the car built again (FAR) and joined into one mesh, Far, under
	root, in the car's frame; the smash car's plugs into FarPlugs."""
	global FAR
	keep = dict(STATS)
	FAR = True
	try:
		far_root = fn(mats)
	finally:
		FAR = False
	STATS.clear()
	STATS.update(keep)
	bpy.context.view_layer.update()
	tree, stack = [], [far_root]
	while stack:
		ob = stack.pop()
		tree.append(ob)
		stack.extend(ob.children)
	names = [ob.name for ob in tree]
	parts = {"Far": [], "FarPlugs": []}
	for ob in tree:
		if ob.type == "MESH":
			parts["FarPlugs" if ob.name.startswith(("Shard_", "Cover_")) else "Far"].append(ob)
	made = []
	for name, obs in parts.items():
		if not obs:
			continue
		target = bpy.data.objects.new(name, bpy.data.meshes.new(name))
		bpy.context.scene.collection.objects.link(target)
		bpy.ops.object.select_all(action="DESELECT")
		for ob in obs:
			ob.select_set(True)
		target.select_set(True)
		bpy.context.view_layer.objects.active = target
		bpy.ops.object.join()
		target.parent = root
		# The joined mesh keeps the parts' colours and uvs but not which is active
		# (the glb takes the active colour only).
		me = target.data
		col = me.color_attributes.get("Col")
		if col is not None:
			me.color_attributes.active_color = col
			me.color_attributes.render_color_index = list(me.color_attributes).index(col)
		if "UVMap" in me.uv_layers:
			me.uv_layers.active = me.uv_layers["UVMap"]
			me.uv_layers["UVMap"].active_render = True
		target.data.calc_loop_triangles()
		STATS[f"{kind} {name}"] = len(target.data.loop_triangles)
		made.append(target.name)
	for n in names:
		ob = bpy.data.objects.get(n)
		if ob is not None and n not in made:
			bpy.data.objects.remove(ob)
	bpy.context.view_layer.update()


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
# pilot runs on ahead of its 22 m to PILOT_TIP (the train's nose), the crane's
# boom back over its idler BOOM_OVER past its end; else nothing goes into the
# gap's far half.
LONG = {k: v["long"] for k, v in PARTS.items()}
LONG["engine"] = ENGINE_LONG
REACH = {k: (L * 0.5 + GAP * 0.5,) * 2 for k, L in LONG.items()}
REACH["engine"] = (PILOT_TIP, ENGINE_LONG * 0.5 + GAP * 0.5)
BOOM_TIP = CRANE_LONG * 0.5 + GAP * 0.5 + BOOM_OVER
REACH["crane"] = (CRANE_LONG * 0.5 + GAP * 0.5, BOOM_TIP)
# Each kind's top over the bed: rail_train.gd CARS.
TOP = {k: v["tall"] for k, v in PARTS.items()}
TOP["open"] = OPEN_TOP + HEAP
# The openings that must be clear (Godot frame: x0, y0, z0, x1, y1, z1): every
# hole of rail_train.gd `_parts` (PARTS: the doorways, the log gap, the truss's
# middle panel, under the crane's boom, each coach's half of the gap between two,
# the run's and the smash car's corridors out to the coupling's middle), named
# by the way it is flown; and the sky over the truss's middle panel.
W2 = WIDE * 0.5
OPENINGS = {k: {f"{h['way']} opening {i + 1}": tuple(h["box"]) for i, h in enumerate(v["holes"])} for k, v in PARTS.items()}
OPENINGS["truss"]["sky over the middle panel"] = (-W2 + TRUSS_SIDE, TRUSS_TOP - CHORD, -TRUSS_PANEL * 0.5, W2 - TRUSS_SIDE, TALL, TRUSS_PANEL * 0.5)
# Nodes an opening doesn't count: the smash car's plugs fill its corridor's ends
# (its plates), the gate's doors its doorway when shut (its movers).
OPEN_SKIP = {"smash": ("Shard_", "Cover_", "FarPlugs"), "gate": ("Door_",)}
# Nodes that must lie inside a box (Godot frame): each plug in its plate
# (rail_train.gd plates: the corridor's mouth, SMASH_PLATE deep), F the front;
# each gate door in its leaf's mover, shut.
SMASH_H = BOX_LONG * 0.5
PLATE_F, PLATE_B = (tuple(b) for b in PARTS["smash"]["plates"])
CONTAIN = {"smash": {"Shard_F": PLATE_F, "Cover_F": PLATE_F, "Shard_B": PLATE_B, "Cover_B": PLATE_B}}
_movers = [m["box"] for m in PARTS["gate"]["movers"]]
CONTAIN["gate"] = {name: tuple(min(b[i] for b in boxes) if i < 3 else max(b[i] for b in boxes) for i in range(6))
	for name, boxes in (("Door_R", [b for b in _movers if b[0] > 0]), ("Door_L", [b for b in _movers if b[0] < 0]))}
TRUCK_NODES = ("Truck_F", "Truck_R", "TruckFrame_F", "TruckFrame_R", "Wheels_F1", "Wheels_F2", "Wheels_R1", "Wheels_R2")
DOOR_NODES = ("Door_RF", "Door_RB", "Door_LF", "Door_LB")
WANT = {"engine": ("Body", "Driver_1", "Driver_2", "Lead_1", "Lead_2", "LeadTruck", "SideRod_R", "SideRod_L",
		"MainRod_R", "MainRod_L", "Crosshead_R", "Crosshead_L", "StackMouth", "Steam_R", "Steam_L"),
	"tender": ("Body", "Coal") + TRUCK_NODES,
	"box": ("Body",) + DOOR_NODES + TRUCK_NODES, "doors": ("Body",) + DOOR_NODES + TRUCK_NODES,
	"stock": ("Body",) + DOOR_NODES + TRUCK_NODES, "gate": ("Body",) + DOOR_NODES + TRUCK_NODES,
	"flat": ("Body",) + TRUCK_NODES, "thru": ("Body",) + TRUCK_NODES, "culvert": ("Body", "Load") + TRUCK_NODES,
	"open": ("Body", "Coal") + TRUCK_NODES, "van": ("Body",) + TRUCK_NODES,
	"logs": ("Body", "Load") + TRUCK_NODES, "truss": ("Body", "Load") + TRUCK_NODES,
	"crane": ("Body", "House", "Boom") + TRUCK_NODES, "coach": ("Body",) + TRUCK_NODES,
	"smash": ("Body", "CrackPlug_F", "CrackPlug_B", "Cover_F", "Cover_B", "Shard_F01", "Shard_B01") + DOOR_NODES + TRUCK_NODES + ("FarPlugs",)}
WANT = {k: v + ("Far",) for k, v in WANT.items()}
# What you see is what you hit: every vertex of the model within SEEN_TOL m of
# RailTrain's solid (its boxes, plates and movers shut and open), or under its
# floor in the coupling's room (the couplers and drawgear, where nothing flies).
SEEN_TOL = 0.15


def seen_not_hit(kind, pts):
	"""The nodes with vertices outside RailTrain's solid for `kind` (pts: node_points):
	{name: (count, the worst one's distance off it, that vertex)}."""
	K = PARTS[kind]
	boxes = list(K["solid"]) + list(K["plates"])
	for m in K["movers"]:
		b, d = m["box"], m["slide"]
		boxes += [b, [b[0] + d[0], b[1] + d[1], b[2] + d[2], b[3] + d[0], b[4] + d[1], b[5] + d[2]]]
	h = LONG[kind] * 0.5 + GAP * 0.5
	boxes.append([-1.2, -2.0, -max(h, REACH[kind][0]), 1.2, FLOOR, h])
	B = np.array(boxes, dtype=np.float64)
	lo, hi = B[:, :3] - SEEN_TOL, B[:, 3:] + SEEN_TOL
	out = {}
	for name, p in pts.items():
		inside = np.zeros(len(p), dtype=bool)
		for i in range(len(B)):
			inside |= np.all((p >= lo[i]) & (p <= hi[i]), axis=1)
		if inside.all():
			continue
		q = p[~inside]
		d = np.full(len(q), np.inf)
		for i in range(len(B)):
			d = np.minimum(d, np.linalg.norm(np.maximum(np.maximum(lo[i] - q, q - hi[i]), 0.0), axis=1))
		out[name] = (len(q), float(d.max()), q[int(d.argmax())])
	return out


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


def tris_in_box(t, lo, hi):
	"""Which triangles (n, 3, 3) cut into the open box lo..hi: the separating axis
	test (the box's 3 axes, the triangle's normal, the 9 edge crosses), exact for
	a triangle spanning the box with no corner inside it."""
	c, e = (lo + hi) * 0.5, (hi - lo) * 0.5
	v = t - c
	f = np.stack([v[:, 1] - v[:, 0], v[:, 2] - v[:, 1], v[:, 0] - v[:, 2]], axis=1)
	hit = np.all(v.max(1) > -e, axis=1) & np.all(v.min(1) < e, axis=1)

	def apart(a):
		p = np.einsum("nk,nvk->nv", a, v)
		r = np.abs(a) @ e
		return ((p.min(1) >= r) | (p.max(1) <= -r)) & (np.linalg.norm(a, axis=1) > 1e-12)
	hit &= ~apart(np.cross(f[:, 0], f[:, 1]))
	for i in range(3):
		for j in range(3):
			hit &= ~apart(np.cross(np.broadcast_to(np.eye(3)[i], f[:, j].shape), f[:, j]))
	return hit


def opening_clear(doc, bin_, box, eps=0.01, skip=()):
	"""The nodes with a triangle cutting more than eps into the box (names starting
	with any of `skip` aside): {name: count}."""
	lo = np.array(box[:3]) + eps
	hi = np.array(box[3:]) - eps
	hits = {}
	for name, t in node_tris(doc, bin_).items():
		if name.startswith(tuple(skip)):
			continue
		inside = tris_in_box(t, lo, hi)
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
		hits = opening_clear(doc, bin_, box, skip=OPEN_SKIP.get(kind, ()))
		if hits:
			print(f"FAIL {kind}: the {what} isn't clear: " + ", ".join(f"{n} ({c} triangles)" for n, c in hits.items()))
			bad = True
		else:
			print(f"  the {what} is clear: x {box[0]:.1f}..{box[3]:.1f}, y {box[1]:.1f}..{box[4]:.1f}, z {box[2]:.1f}..{box[5]:.1f}")
	off = seen_not_hit(kind, parts)
	for name, (n, worst, at) in sorted(off.items()):
		print(f"FAIL {kind}: {name} is seen but not hit: {n} vertices off the solid, the worst {worst:.2f} m at ({at[0]:.2f}, {at[1]:.2f}, {at[2]:.2f})")
		bad = True
	if not off:
		print(f"  every vertex within {SEEN_TOL} m of the solid (seen is hit)")
	for prefix, box in CONTAIN.get(kind, {}).items():
		inner = {n: p for n, p in parts.items() if n.startswith(prefix)}
		out = [n for n, p in inner.items() if (p.min(0) < np.array(box[:3]) - 1e-3).any() or (p.max(0) > np.array(box[3:]) + 1e-3).any()]
		if not inner or out:
			print(f"FAIL {kind}: {prefix}* not inside its box: " + (", ".join(out) if out else "none found"))
			bad = True
		else:
			print(f"  {len(inner)} {prefix}* inside x {box[0]:.1f}..{box[3]:.1f}, y {box[1]:.1f}..{box[4]:.1f}, z {box[2]:.1f}..{box[5]:.1f}")
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
		for ob in [o for o in new if o.name.startswith("Far")]:
			new.discard(ob)
			bpy.data.objects.remove(ob)
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
	"gate": lambda m: build_boxcar(m, "gate"), "thru": lambda m: build_boxcar(m, "thru"), "culvert": build_culvert,
	"doors": lambda m: build_boxcar(m, "doors"), "stock": lambda m: build_boxcar(m, "stock"),
	"flat": build_flat, "open": build_open, "van": build_van, "logs": build_logs, "truss": build_truss,
	"crane": build_crane, "coach": build_coach, "smash": lambda m: build_boxcar(m, "smash")}


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
		far_lod(kind, fn, mats, root)
		bpy.context.view_layer.update()
		export(kind, root)
		bad |= prove(kind)
		built.append(kind)
	print("triangles:", ", ".join(f"{k} {v}" for k, v in STATS.items()), f"(all {sum(STATS.values())})")
	if "--render" in args:
		render(built)
	sys.exit(1 if bad else 0)


main()
