extends "res://scripts/kit_isle/motif_greybox.gd"
## The Rootbound Cut (card: docs/design/roguelike/brainstorm/round2/motif-
## m1-rootbound-cut.md, its "Place (round 2)" section): a PLACE, built
## land first on the kit's terrain and look. One low whale-back hill of
## turf (KitLand.island) that the makers were sawing apart with straight
## trenches across it when they stopped: a haul road sunk along its spine
## (the body's beat), a north comb of crisp trenches (three sawn clean out
## through the flank), a south comb more ragged, a deep cut through the
## mound's foot, the south-
## west end caved into a terraced ravine, and at the west end the quarry
## court where a colossal head lies half cut out of the knoll, face to the
## sky, its nape still in the rock. Arrival from the east rim, a grass lawn
## where the finished blocks wait on their skid rails.
##
## Everything is in ONE table, LAYOUT: the hill (outline, crest, fall),
## the cuts (each a polyline of (x, floor y, z) and a width, or a rect and
## a floor; the ground is the hill, less every cut, and the ravine's
## terraces), the mound, the head, the blocks, the hoist jibs, the kit pieces,
## the rims, spots and the body's patrol. The motif's frame: x west (0) to
## east (140), z north (-) to south (+), y the hill's datum.
##
## STAND-INs (the card's kit asks and one enemy change), each labelled
## where it is built:
##   - the Root Curtain: two plain swing ropes (g.rope) as climb-outs,
##     each tied to a makers' hoist jib (a basalt post on the rib, its beam
##     over the slot);
##   - the Rib piece: none needed, the ribs are the terrain left between
##     the cuts (KitLand cliffs, grabbable lips);
##   - the banyan and its ring of stones: removed for now (round 2
##     feedback); its mound stays;
##   - the headless body's patrol: today a whole body roams any way; a
##     small node here (Patrol) turns it along the haul road between
##     waypoints while it is unaware (its own sight, chase, climb and leap
##     untouched).
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
## The hoist jibs: the post's height and side, the beam's section.
const JIB_TALL := 2.4
const JIB_POST := 0.7
const JIB_BEAM := 0.45
## How far a block or piece is sunk under the lowest ground beneath it.
const SINK := 0.15

const SO := RuinKit.SET_OFF
const TURF_SEED := 5300
## The hill's keel (m under its datum) and the spurs' reach (KitLand
## ring_sides: the last ring 0.92 deep x 1.15, a spur 0.3 more).
const DEPTH := 16.0
const KEEL_REACH := 1.4
## The occupancy's sampling (m) over the hill.
const OCC_STEP := 4.0

## THE LAYOUT. Sizes from the pilot (scripts/pilot_motor.gd at the
## wanderer's size, RuinKit's Scale): run 4.8 m/s, a running hop reaches
## about 2.4 m flat, the long jump about 4.2 m, a plain jump catches a lip
## RuinKit.GRAB_TOP (1.875) up, the pump CHAIN_TOP (2.575), a climbing
## step SET_OFF (1.6). Slots: 2.2-2.6 wide hopped (a short hop is caught
## by the far lip), 2.8-3.2 long-jumped; walls 4-6 m (out by a ramp end,
## a cross-cut, a root rope or the road). The body (whole, ~10 m, 4.4 m
## broad, eyes ~9.6 m up) walks the 9 m haul road; from it a 5 m wall hides
## a pilot in a slot unless it looks down the slot.
const LAYOUT := {
	# The island's rim (resampled by KitLand, about +-0.3 m): a bay in the
	# north flank, the south-west caved in to the ravine.
	"outline":[Vector2(1.0,-4.0),Vector2(3.0,-15.0),Vector2(9.0,-24.0),Vector2(20.0,-29.0),Vector2(31.0,-27.0),
		Vector2(38.0,-30.0),Vector2(52.0,-31.5),Vector2(66.0,-33.0),Vector2(82.0,-31.0),Vector2(97.0,-32.5),
		Vector2(110.0,-30.0),Vector2(122.0,-27.0),Vector2(130.0,-20.0),Vector2(134.0,-9.0),Vector2(135.0,3.0),
		Vector2(132.0,14.0),Vector2(124.0,23.0),Vector2(110.0,28.5),Vector2(94.0,31.0),Vector2(80.0,31.5),
		Vector2(70.0,30.0),Vector2(62.0,27.0),Vector2(54.0,24.5),Vector2(44.0,23.5),Vector2(33.0,23.0),
		Vector2(21.0,20.5),Vector2(11.0,14.0),Vector2(4.0,6.0)],
	# The whale-back: its crest along x [x, y], falling `fall` m at |z| =
	# `half`: the east lawn low, the comb rising west to the banyan, the
	# knoll the head is cut from highest.
	"crest":[[0.0,7.0],[16.0,7.0],[24.0,6.0],[40.0,4.4],[56.0,4.8],[72.0,5.4],[90.0,4.2],[106.0,2.6],[120.0,0.8],[136.0,0.2]],
	"fall":5.0,"half":30.0,
	# The mound (added to the hill; the banyan's, the tree removed for now).
	"mound":[Vector2(69.0,16.0),10.0,1.8],
	# The cuts. Lines: {name, pts [(x, depth, z)...], w, rag (edge wobble,
	# m)}: the floor is the uncut whale-back (no mound) over the cut's
	# axis less its depth, lerped along; a depth of 0 is a ramp out. Rects:
	# {name, rect, y (absolute), rag}.
	"lines":[
		{"name":"road","w":9.0,"rag":0.5,"pts":[Vector3(121.0,0.0,1.5),Vector3(110.0,4.2,0.5),Vector3(98.0,4.4,-0.4),
			Vector3(84.0,4.5,0.6),Vector3(68.0,4.5,-0.6),Vector3(54.0,4.4,0.3),Vector3(46.0,4.4,0.0),Vector3(40.0,4.4,0.0)]},
		# The north comb: crisp, but no two alike. N2, N5, N8 sawn out
		# through the flank; N4 stopped mid-stroke; N7 half filled by a
		# slump; two stubs where a cut was started and left.
		{"name":"N1","w":2.6,"rag":0.25,"pts":[Vector3(111.0,4.0,-4.0),Vector3(110.2,4.6,-11.0),Vector3(108.6,4.6,-17.0),Vector3(107.6,0.0,-27.0)]},
		{"name":"N2","w":2.0,"rag":0.15,"pts":[Vector3(101.5,4.4,-4.2),Vector3(101.2,4.8,-13.0),Vector3(102.6,5.0,-22.0),Vector3(103.4,5.0,-34.0)]},
		{"name":"N2b","w":2.0,"rag":0.25,"pts":[Vector3(107.4,1.8,-20.5),Vector3(106.8,2.2,-26.0)]},
		{"name":"N3","w":3.0,"rag":0.30,"pts":[Vector3(93.6,4.3,-4.5),Vector3(94.0,3.4,-11.5),Vector3(94.1,4.8,-12.6),Vector3(95.6,4.8,-17.0),Vector3(98.0,0.0,-27.5)]},
		{"name":"N4","w":2.2,"rag":0.25,"pts":[Vector3(88.5,4.4,-4.5),Vector3(87.8,3.4,-12.0),Vector3(87.6,2.0,-15.5)]},
		{"name":"N5","w":2.8,"rag":0.25,"pts":[Vector3(80.2,4.4,-4.6),Vector3(79.6,5.4,-9.0),Vector3(78.4,5.4,-20.0),Vector3(76.0,5.2,-34.0)]},
		{"name":"N5b","w":2.2,"rag":0.30,"pts":[Vector3(86.0,2.6,-21.0),Vector3(82.6,2.6,-27.5)]},
		{"name":"N6","w":2.2,"rag":0.25,"pts":[Vector3(72.6,4.6,-4.6),Vector3(72.0,4.8,-12.0),Vector3(69.4,4.8,-21.0)]},
		{"name":"N7","w":2.6,"rag":0.25,"pts":[Vector3(64.0,4.5,-4.6),Vector3(64.6,4.8,-10.0),Vector3(65.2,1.8,-13.6),Vector3(66.0,4.8,-17.0),Vector3(67.2,0.0,-28.0)]},
		{"name":"N8","w":2.6,"rag":0.30,"pts":[Vector3(57.0,4.3,-4.6),Vector3(56.4,4.6,-13.0),Vector3(54.0,4.6,-24.0),Vector3(52.8,4.6,-34.0)]},
		{"name":"N9","w":2.4,"rag":0.30,"pts":[Vector3(47.6,4.2,-4.6),Vector3(47.2,4.6,-10.0),Vector3(46.6,4.6,-16.0),Vector3(46.2,0.0,-27.0)]},
		# North cross-cuts, every few ribs.
		{"name":"X1","w":2.0,"rag":0.30,"pts":[Vector3(110.0,4.6,-14.0),Vector3(101.2,4.8,-14.0)]},
		{"name":"X2","w":2.0,"rag":0.30,"pts":[Vector3(102.0,5.0,-18.5),Vector3(94.7,4.8,-18.5)]},
		{"name":"X3","w":2.0,"rag":0.30,"pts":[Vector3(78.8,5.4,-16.0),Vector3(72.0,4.8,-16.0)]},
		{"name":"X4","w":2.0,"rag":0.30,"pts":[Vector3(64.6,4.8,-11.0),Vector3(56.4,4.6,-11.0)]},
		# The south comb: ragged; S4, S5 and the tunnel roofed by the roots,
		# S5 and S6 broken out into the ravine.
		{"name":"S1","w":2.4,"rag":0.35,"pts":[Vector3(107.0,4.0,4.6),Vector3(107.6,4.8,10.0),Vector3(109.0,4.8,17.0),Vector3(110.6,0.0,27.0)]},
		{"name":"S2","w":2.2,"rag":0.40,"pts":[Vector3(98.6,4.2,4.6),Vector3(97.6,4.8,10.0),Vector3(94.6,4.2,19.0)]},
		{"name":"S3","w":3.2,"rag":0.40,"pts":[Vector3(89.0,4.4,4.6),Vector3(89.6,5.2,9.0),Vector3(90.4,5.2,18.0),Vector3(92.0,0.0,28.5)]},
		{"name":"S4","w":2.6,"rag":0.45,"pts":[Vector3(81.0,4.4,4.6),Vector3(80.6,4.8,9.0),Vector3(79.4,4.8,20.0)]},
		{"name":"tunnel","w":2.6,"rag":0.50,"pts":[Vector3(80.4,4.8,11.0),Vector3(69.0,4.8,9.8),Vector3(58.6,4.8,11.0)]},
		{"name":"S5","w":2.6,"rag":0.50,"pts":[Vector3(58.4,4.3,4.6),Vector3(58.8,4.8,10.0),Vector3(59.6,4.8,16.0),Vector3(60.2,4.4,21.0)]},
		{"name":"S6","w":2.4,"rag":0.60,"pts":[Vector3(51.0,4.2,4.6),Vector3(49.0,4.6,12.0),Vector3(45.8,5.0,18.0)]},
		# Rib tops slumped where a rib fell in (a broken notch, ragged).
		{"name":"slump1","w":4.5,"rag":0.70,"pts":[Vector3(79.0,2.0,-25.0),Vector3(73.0,2.4,-27.0)]},
		{"name":"slump2","w":3.6,"rag":0.70,"pts":[Vector3(106.5,1.8,21.0),Vector3(99.0,2.2,23.0)]},
		{"name":"slump3","w":3.0,"rag":0.70,"pts":[Vector3(55.0,1.6,-20.0),Vector3(48.0,1.6,-21.0)]},
		{"name":"XS1","w":2.0,"rag":0.40,"pts":[Vector3(89.8,5.2,14.5),Vector3(80.2,4.8,14.5)]},
	],
	# The quarry court round the head (the road's floor), the benches up
	# its north-west corner to the knoll (each SO over the last).
	"rects":[
		{"name":"court","rect":Rect2(27.0,-7.0,19.0,21.0),"y":0.0,"rag":0.5},
		{"name":"court_n","rect":Rect2(34.0,-12.0,12.0,5.5),"y":0.0,"rag":0.4},
		{"name":"bench1","rect":Rect2(30.0,-16.5,4.2,9.8),"y":SO,"rag":0.3},
		{"name":"bench2","rect":Rect2(26.0,-16.5,4.2,9.8),"y":SO*2.0,"rag":0.3},
		{"name":"bench3","rect":Rect2(22.0,-16.5,4.2,9.8),"y":SO*3.0,"rag":0.3},
	],
	# The caved south-west: from x0 to x1, its first edge at z = edge +
	# swing sin(x k); terraces `band` m wide, the first `drop` under the
	# crest, each SO lower, `deep` at most.
	"ravine":{"x0":4.0,"x1":62.0,"edge":10.0,"swing":2.5,"k":0.13,"band":4.5,"drop":4.6,"deep":10.0},
	# Rubble islets broken off the ravine (blob: middle, radius, top).
	"islets":[[Vector2(30.0,29.5),4.0,-6.4],[Vector2(47.0,28.5),3.0,-7.6],[Vector2(15.0,24.5),3.4,-4.8]],
	# The head: its chin's foot (the pivot), chin to crown (m), tipped back
	# (deg) so it faces up and east (toward the arrival).
	"head":{"chin":Vector3(37.0,-3.4,0.0),"tall":16.0,"tilt":55.0},
	# The makers' basalt (GiantStone): [name, (x, lift, z), size, yaw,
	# roll (deg), runes, on] its foot `lift` over the ground ("ground") or
	# the uncut hill ("hill": jammed across a slot).
	"blocks":[
		["yard_a",Vector3(122.0,0.32,9.0),Vector3(3.2,2.2,2.2),4.0,0.0,true,"ground"],
		["yard_b",Vector3(126.5,0.32,9.4),Vector3(3.0,2.2,2.4),-3.0,0.0,false,"ground"],
		["yard_tipped",Vector3(129.0,-0.3,13.4),Vector3(3.2,2.2,2.2),18.0,74.0,false,"ground"],
		["jammed_N2",Vector3(101.1,-1.4,-9.5),Vector3(4.6,1.7,1.9),2.0,6.0,false,"hill"],
		["road_block",Vector3(92.0,0.3,-3.4),Vector3(3.4,2.0,2.0),8.0,0.0,true,"ground"],
		["road_tipped",Vector3(74.0,0.1,3.7),Vector3(3.0,1.8,2.0),-14.0,22.0,false,"ground"],
		["N6_block",Vector3(69.9,0.0,-19.6),Vector3(2.0,2.0,2.6),17.0,0.0,false,"ground"],
		["N5_fallen",Vector3(78.6,-0.2,-19.0),Vector3(2.2,1.6,3.0),12.0,31.0,false,"ground"],
		["chin_step",Vector3(42.2,0.0,0.8),Vector3(1.8,1.55,3.2),-6.0,0.0,false,"ground"],
		["jaw_step",Vector3(40.3,0.0,0.6),Vector3(2.0,2.95,3.0),3.0,0.0,true,"ground"],
		["lip_wedge",Vector3(38.7,0.0,0.4),Vector3(1.2,4.35,3.0),4.0,0.0,false,"ground"],
		["court_block",Vector3(43.0,0.0,-9.0),Vector3(3.0,2.0,2.2),24.0,0.0,true,"ground"],
		["ravine_a",Vector3(24.0,-0.4,16.5),Vector3(2.6,1.8,2.2),35.0,18.0,false,"ground"],
		["ravine_b",Vector3(38.0,-0.5,21.0),Vector3(3.0,1.8,2.0),-20.0,40.0,false,"ground"],
	],
	# Skid rails (low worn runners, walked over): [(x, lift, z), length, yaw].
	"rails":[[Vector3(124.0,0.0,7.6),14.0,0.0],[Vector3(124.0,0.0,10.8),14.0,0.0],
		[Vector3(90.0,0.0,-3.4),12.0,0.0],[Vector3(76.0,0.0,3.7),10.0,0.0]],
	# STAND-IN Root Curtain: climb-out ropes tied to the makers' hoist jibs:
	# [tip (x, z) over the slot, post (x, z) on the rib], the beam
	# JIB_TALL over the post's ground.
	"jibs":[[Vector2(79.3,-12.0),Vector2(82.2,-12.0)],[Vector2(90.2,16.0),Vector2(93.0,16.0)]],
	# Kit pieces: [id, seed, weathered, at (x, z), yaw, sink, on]: seated on
	# the lowest ground under them, or a lid ("hill") on the rib tops.
	"kit":[
		["hall_slab",TURF_SEED+41,0.6,Vector2(96.6,13.0),72.0,0.4,"hill"],
		["hall_column",TURF_SEED+42,0.7,Vector2(118.0,-12.0),70.0,0.3],
		["tomb_chest",TURF_SEED+43,0.5,Vector2(44.0,6.0),-70.0,0.0],
		["fallen_pier",TURF_SEED+44,0.8,Vector2(30.0,19.5),40.0,0.2],
		["fallen_pier",TURF_SEED+45,0.8,Vector2(50.0,21.0),-25.0,0.2],
		["aqueduct_stump",TURF_SEED+46,0.7,Vector2(114.0,15.0),-90.0,0.3],
	],
	# The body's beat on the road (STAND-IN patrol, x z), and where it is set down.
	"patrol":[Vector2(102.0,-0.3),Vector2(78.0,0.2),Vector2(54.0,0.3)],
	"body":{"at":Vector2(96.0,-0.2),"face":Vector2(-1.0,0.0)},
}

func slug() -> String:
	return "rootbound_cut"

func isle_name() -> String:
	return "The Rootbound Cut"

func epithet() -> String:
	return "They stopped mid-stroke, and the roots finished the job."

func brief() -> String:
	return "Cross the comb to the head at the west end: run the rib tops (open), slip the slots and the root tunnel (hidden),\nor take the haul road where the overseer walks. Its eyes are on the road; the slots hide you unless it looks down one."

## The landing lawn, a little in from the east rim.
func start() -> Vector3:
	return Vector3(127.0,ground(127.0,2.0),2.0)

func rims() -> Array:
	return [
		{"name":"landing","at":Vector3(132.6,ground(132.6,1.0),1.0),"face":Vector3(1.0,0.0,0.0),"run_up":14.0,"lip":1.6},
		# A way in too (never out: every route ends at the head's knoll):
		# the north flank's rib top between N8 and N7.
		{"name":"north_flank","at":Vector3(61.0,ground(61.0,-30.0),-30.0),"face":Vector3(0.0,0.0,-1.0),"run_up":9.0,"lip":1.4,"way":"in"},
		{"name":"knoll","at":Vector3(3.4,ground(3.4,-2.0),-2.0),"face":Vector3(-1.0,0.0,0.0),"run_up":16.0,"lip":1.6},
	]

func spots() -> Array:
	var eye := head_eye()
	return [
		{"kind":"arena","name":"haul_road","at":Vector3(80.0,ground(80.0,0.0),0.0),"room":4.0},
		{"kind":"cover","name":"mound_cut","at":Vector3(69.0,ground(69.0,9.8),9.8),"room":1.2},
		{"kind":"cover","name":"north_slot","at":Vector3(101.2,ground(101.2,-16.0),-16.0),"room":1.0},
		{"kind":"perch","name":"eye","at":eye,"room":1.2},
	]

## A place: the land is the layout; no grey parts.
func parts() -> Array:
	return []

# --- The ground ------------------------------------------------------------------------

## The hill's crest at x.
static func crest(x: float) -> float:
	var c: Array = LAYOUT.crest
	if x <= float(c[0][0]): return float(c[0][1])
	for i in range(c.size()-1):
		var a: Array = c[i]
		var b: Array = c[i+1]
		if x <= float(b[0]): return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
	return float(c[c.size()-1][1])

## The whale-back alone (what the cuts' depths are under).
static func base(x: float, z: float) -> float:
	var dz := clampf(z/float(LAYOUT.half),-1.2,1.2)
	return crest(x)-float(LAYOUT.fall)*dz*dz

## The uncut hill: the whale-back and the banyan's mound.
static func hill(x: float, z: float) -> float:
	# The rib tops are not level: the old hill's swells under the turf.
	var y := base(x,z)+0.45*sin(x*0.31+z*0.17)*sin(z*0.23-x*0.07+1.3)+0.25*sin(x*0.71-z*0.53)
	var m: Array = LAYOUT.mound
	var r := Vector2(x,z).distance_to(m[0])/float(m[1])
	if r < 1.0: y += float(m[2])*(1.0-smoothstep(0.0,1.0,r))
	return y

## A cut's edge wobble at (x, z): `rag` m, two waves (crisp to ragged).
static func _wob(x: float, z: float, rag: float, k: int) -> float:
	return rag*(0.6*sin(0.83*x+1.31*z+k*1.7)+0.4*sin(2.1*x-1.7*z+k*0.9))

static var _cut_boxes: Array = []
## Each line cut's points' floors (absolute), as `_line_cut_boxes` makes them.
static var _cut_floors: Array = []
static var _box_lock := Mutex.new()

## Each line cut's box (x, z), grown by its half width and rag.
static func _line_cut_boxes() -> Array:
	_box_lock.lock()
	if _cut_boxes.is_empty():
		for c: Dictionary in LAYOUT.lines:
			var pts: Array = c.pts
			var r := Rect2(Vector2(pts[0].x,pts[0].z),Vector2.ZERO)
			for p: Vector3 in pts: r = r.expand(Vector2(p.x,p.z))
			_cut_boxes.append(r.grow(float(c.w)*0.5+float(c.rag)+0.1))
			var floors := PackedFloat32Array()
			for p: Vector3 in pts: floors.append(base(p.x,p.z)-p.y)
			_cut_floors.append(floors)
	var out := _cut_boxes
	_box_lock.unlock()
	return out

## The floor of line cut `c` at (x, z), or INF outside it.
static func _line_floor(c: Dictionary, x: float, z: float, k: int) -> float:
	var pts: Array = c.pts
	var floors: PackedFloat32Array = _cut_floors[k]
	var half := float(c.w)*0.5+_wob(x,z,float(c.rag),k)
	# The nearest segment's floor (a joint's round end must not carry its
	# floor along the next segment).
	var best := INF
	var near := INF
	var q := Vector2(x,z)
	for i in range(pts.size()-1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i+1]
		var a2 := Vector2(a.x,a.z)
		var d := Vector2(b.x,b.z)-a2
		var t := clampf((q-a2).dot(d)/d.length_squared(),0.0,1.0)
		var off := (a2+d*t).distance_to(q)
		if off <= half and off < near-0.001:
			near = off
			best = lerpf(floors[i],floors[i+1],t)
	return best

## The ravine's terrace at (x, z), or INF outside it.
static func _ravine(x: float, z: float) -> float:
	var r: Dictionary = LAYOUT.ravine
	if x < float(r.x0) or x > float(r.x1): return INF
	# The caved edge bends out toward the ravine's east end (it narrows).
	var east := smoothstep(float(r.x1)-12.0,float(r.x1),x)*8.0
	var west := (1.0-smoothstep(float(r.x0),float(r.x0)+10.0,x))*6.0
	var edge := float(r.edge)+float(r.swing)*sin(x*float(r.k)+0.5)+east+west+0.6*sin(z*0.9+x*0.4)
	if z < edge: return INF
	var band := int(floor((z-edge)/float(r.band)))
	var c := crest(x)
	return maxf(c-float(r.drop)-SO*band,c-float(r.deep))

## The ground at (x, z) in the motif's frame.
static func ground(x: float, z: float) -> float:
	var y := hill(x,z)
	var boxes := _line_cut_boxes()
	var lines: Array = LAYOUT.lines
	for k in range(lines.size()):
		if not (boxes[k] as Rect2).has_point(Vector2(x,z)): continue
		y = minf(y,_line_floor(lines[k],x,z,k))
	var j := 0
	for c: Dictionary in LAYOUT.rects:
		j += 1
		var rg := float(c.rag)
		var r: Rect2 = (c.rect as Rect2).grow(_wob(x,z,rg,40+j))
		if r.has_point(Vector2(x,z)): y = minf(y,float(c.y))
	y = minf(y,_ravine(x,z))
	return y

# --- The head ------------------------------------------------------------------------------

## The head's place: its chin's foot at the pivot, faced east (+X) and
## tipped back `tilt` so it looks up, scaled to `tall`.
static func head_frame() -> Transform3D:
	var h: Dictionary = LAYOUT.head
	var s := float(h.tall)/HeadLook.MODEL_HEIGHT
	var b := Basis(Vector3.UP,-PI*0.5)*Basis(Vector3.RIGHT,deg_to_rad(float(h.tilt)))
	return Transform3D(b.scaled(Vector3.ONE*s),h.chin)

## The carved eye's socket (the perch): the model's left eye.
static func head_eye() -> Vector3:
	return head_frame()*Vector3(0.37,1.62,-1.12)

# --- The kit and the look ----------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(top(),KitLand.wear_of(paths()))
	site.ray = Vector2(top()+40.0,top()-12.0)
	return site

func flora_seed() -> int:
	return TURF_SEED+9

func life_script() -> Script:
	return KitLife

## The worn ways: the haul road's middle, the north margin.
static func paths() -> Array:
	var road: Array = []
	for p: Vector3 in LAYOUT.lines[0].pts: road.append(Vector2(p.x,p.z))
	return [road,[Vector2(128.0,-6.0),Vector2(112.0,-26.0),Vector2(80.0,-27.0),Vector2(46.0,-27.5),Vector2(24.0,-22.0),Vector2(6.0,-4.0)]]

static var _head_mesh: Mesh = null
static var _head_shape: ConcavePolygonShape3D = null

## The materials, the head's dressed mesh and its collision, the oak: made
## on the main thread before a worker builds.
func warm() -> void:
	super.warm()
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()
	GiantStone.warm()
	_line_cut_boxes()
	if _head_mesh == null:
		var model: Node3D = (load(HeadLook.MODEL) as PackedScene).instantiate()
		var stone := RuinKit.Style.stone_of(GiantStone.STONE_SEED) if RuinKit.Style.ruled() else Color("5a5d63")
		var faces := PackedVector3Array()
		var merged := ArrayMesh.new()
		for part_name: String in ["Head","Jaw"]:
			var part := model.get_node(part_name) as MeshInstance3D
			var dressed: ArrayMesh = HeadLook._dressed(part.mesh,stone,part.position)
			for s in range(dressed.get_surface_count()):
				var arrays := dressed.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in range(verts.size()): verts[i] += part.position
				arrays[Mesh.ARRAY_VERTEX] = verts
				merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			for f: Vector3 in part.mesh.get_faces(): faces.append(f+part.position)
		model.free()
		var mat := HeadLook.stone_material()
		for s in range(merged.get_surface_count()): merged.surface_set_material(s,mat)
		_head_mesh = merged
		_head_shape = ConcavePolygonShape3D.new()
		_head_shape.set_faces(faces)

## Measured headless on this Mac (2026-10-14): 1.9 s, 1.85 s of it the
## hill's KitLand island (its ground function is this script's GDScript).
func build_cost() -> int:
	return 1900

## The keel under the hill and the islets, the head, the tree, sampled.
func _solids() -> Array:
	var out: Array = []
	var ring: Array = LAYOUT.outline
	var poly := PackedVector2Array(ring)
	var box := Rect2(ring[0],Vector2.ZERO)
	for p: Vector2 in ring: box = box.expand(p)
	var x := box.position.x
	while x < box.end.x:
		var z := box.position.y
		while z < box.end.y:
			var cell := Rect2(x,z,OCC_STEP,OCC_STEP)
			var mid := cell.get_center()
			if Geometry2D.is_point_in_polygon(mid,poly) or KitLand.edge_distance(mid,poly) < OCC_STEP:
				var high := -INF
				for c: Vector2 in [cell.position,cell.end,Vector2(cell.position.x,cell.end.y),Vector2(cell.end.x,cell.position.y),mid]:
					high = maxf(high,hill(c.x,c.y))
				out.append([cell,crest(70.0)-DEPTH*KEEL_REACH,high+1.0,null])
			z += OCC_STEP
		x += OCC_STEP
	for i: Array in LAYOUT.islets:
		var c: Vector2 = i[0]
		var r := float(i[1])
		out.append([Rect2(c-Vector2.ONE*r,Vector2.ONE*r*2.0),float(i[2])-r*2.2,float(i[2])+0.5,null])
	# The head's brow over the land.
	out.append([Rect2(22.0,-8.0,20.0,16.0),-3.0,10.0,null])
	return out

# --- The build -------------------------------------------------------------------------

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	if _head_mesh == null: warm()
	var root := Node3D.new()
	root.name = "RootboundCut"
	into.add_child(root)
	var tone := KitLook.turf(TURF_SEED,KitLand.wear_of(paths()))
	var ring: Array = LAYOUT.outline
	var box := Rect2(ring[0],Vector2.ZERO)
	for p: Vector2 in ring: box = box.expand(p)
	var land := KitLand.island({"outline":ring,"seed":TURF_SEED,"ground":func(x: float, z: float) -> float: return ground(x,z),
		"top":crest(70.0),"depth":DEPTH,"cliffs":box.grow(1.0),"fine":1.3,"hang":true,"resample":[80.0,260,64],"tone":tone})
	land.name = "Hill"
	_collide_sides(land)
	root.add_child(land)
	turf(land)
	var k := 0
	for i: Array in LAYOUT.islets:
		var c: Vector2 = i[0]
		var y := float(i[2])
		var islet := KitLand.island({"outline":KitLand.blob(c,float(i[1]),TURF_SEED+60+k),"seed":TURF_SEED+60+k,
			"ground":func(_x: float, _z: float) -> float: return y,"top":y,"depth":float(i[1])*2.0,"hang":true,"resample":[20.0,40,24],"tone":tone})
		islet.name = "Rubble%d" % k
		root.add_child(islet)
		turf(islet)
		k += 1
	_stone(root)
	_head(root)
	_kit(root)
	built_ms = Time.get_ticks_msec()-began

## The hill's hanging sides collided as drawn (the body climbs them; a fall
## past a flank meets it), as the Sunken Giant's.
static func _collide_sides(land: Node3D) -> void:
	var sides := land.get_node_or_null("Mesh") as MeshInstance3D
	if sides == null or sides.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(sides.mesh.get_faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	land.add_child(body)

## The makers' blocks and rails in the Olmec basalt, each collided as drawn.
func _stone(root: Node3D) -> void:
	var m: RefCounted = GiantStone.mesher()
	var solids := Node3D.new()
	solids.name = "Blocks"
	root.add_child(solids)
	for b: Array in LAYOUT.blocks:
		var p: Vector3 = b[1]
		var size: Vector3 = b[2]
		var turn := Basis(Vector3.UP,deg_to_rad(float(b[3])))*Basis(Vector3.BACK,deg_to_rad(float(b[4])))
		# Seated: its lowest corner `lift` over the lowest ground under its
		# footprint, sunk SINK (a jammed one: its middle on the uncut hill).
		var half := (turn.x*size.x*0.5).abs()+(turn.y*size.y*0.5).abs()+(turn.z*size.z*0.5).abs()
		var mid_y := hill(p.x,p.z)+p.y+size.y*0.5 if b[6] == "hill" else _lowest(Vector2(p.x,p.z),Vector2(half.x,half.z),0.0)-SINK+p.y+half.y
		var place := Transform3D(turn,Vector3(p.x,mid_y,p.z))
		m.box(place,size,0.22)
		_walk_shape(solids,place,size)
		if b[5]:
			# The tallies: the same count on every block (the same glyphs).
			var face := place.basis.z.normalized()
			var side := place.basis.x.normalized()
			var c := place.origin+face*(size.z*0.5)-side*(size.x*0.4)+Vector3.UP*(-size.y*0.15)
			m.runes(c,c+side*size.x*0.8,Vector3.UP,face,7.0)
	for r: Array in LAYOUT.rails:
		var p: Vector3 = r[0]
		var turn := Basis(Vector3.UP,deg_to_rad(float(r[2])))
		var size := Vector3(float(r[1]),0.36,0.62)
		var reach := (turn.x*size.x*0.5).abs()+(turn.z*size.z*0.5).abs()
		var place := Transform3D(turn,Vector3(p.x,_lowest(Vector2(p.x,p.z),Vector2(reach.x,reach.z),0.0)-SINK+p.y+0.18,p.z))
		m.box(place,size,0.1,NAN,0.92)
		_walk_shape(solids,place,size)
	# STAND-IN Root Curtain anchors: the makers' hoist jibs, a post on the
	# rib and its beam out over the slot (the rope hangs from its tip).
	for j: Array in LAYOUT.jibs:
		var tip: Vector2 = j[0]
		var post: Vector2 = j[1]
		var foot := _lowest(post,Vector2.ONE*JIB_POST*0.5,0.0)-SINK*2.0
		var top := ground(post.x,post.y)+JIB_TALL
		var at := Transform3D(Basis.IDENTITY,Vector3(post.x,(foot+top)*0.5,post.y))
		var size := Vector3(JIB_POST,top-foot,JIB_POST)
		m.box(at,size,0.12)
		_walk_shape(solids,at,size)
		var from := Vector3(post.x,top+JIB_BEAM*0.5,post.y)
		var to := Vector3(tip.x,top+JIB_BEAM*0.5,tip.y)
		var along := (to-from).normalized()
		var beam := Transform3D(Basis(along,Vector3.UP,along.cross(Vector3.UP)),(from+to)*0.5+along*0.15)
		var beam_size := Vector3(from.distance_to(to)+JIB_POST,JIB_BEAM,JIB_BEAM)
		m.box(beam,beam_size,0.08)
		_walk_shape(solids,beam,beam_size).name = "JibBeam_%d" % int(tip.x)
	var body := MeshInstance3D.new()
	body.name = "Basalt"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())

## The colossal head, half cut from the knoll (its own model, the inhaler
## head's, dressed in the same stone), collided as drawn.
func _head(root: Node3D) -> void:
	var head := MeshInstance3D.new()
	head.name = "ColossalHead"
	head.mesh = _head_mesh
	head.transform = head_frame()
	root.add_child(head)
	var body := StaticBody3D.new()
	body.name = "HeadBody"
	body.transform = head_frame()
	var holder := CollisionShape3D.new()
	holder.shape = _head_shape
	body.add_child(holder)
	root.add_child(body)

## The kit's pieces, each set on the ground under its middle.
func _kit(root: Node3D) -> void:
	for spec: Array in LAYOUT.kit:
		var piece: Node3D = RuinKit.piece(spec[0],int(spec[1]),float(spec[2]))
		if piece == null: continue
		var c: Vector2 = spec[3]
		piece.name = "%s_%d" % [str(spec[0]),int(spec[1])]
		var turn := Basis(Vector3.UP,deg_to_rad(float(spec[4])))
		# Seated on the lowest ground under its drawn footprint, less its sink.
		var lid: bool = spec.size() > 6 and spec[6] == "hill"
		var low := ground(c.x,c.y)
		var mesh := piece.get_node_or_null("Mesh") as MeshInstance3D
		if lid:
			# On the lips either side: the lower of the two rib tops.
			low = INF
			for side: float in [-1.0,1.0]: low = minf(low,hill(c.x+turn.z.x*side*2.6,c.y+turn.z.z*side*2.6))
		elif mesh != null:
			var box := mesh.get_aabb()
			for corner: Vector3 in [box.position,box.position+Vector3(box.size.x,0,0),box.position+Vector3(0,0,box.size.z),box.position+Vector3(box.size.x,0,box.size.z)]:
				var w := turn*corner
				low = minf(low,ground(c.x+w.x,c.y+w.z))
		piece.transform = Transform3D(turn,Vector3(c.x,low-float(spec[5]),c.y))
		root.add_child(piece)

## The lowest ground under a footprint `reach` (x, z half sizes) round
## `c`: its corners, edges' middles and middle.
static func _lowest(c: Vector2, reach: Vector2, _unused: float) -> float:
	var low := INF
	for u: float in [-1.0,0.0,1.0]:
		for v: float in [-1.0,0.0,1.0]:
			low = minf(low,ground(c.x+u*reach.x,c.y+v*reach.y))
	return low

## A jib's rope anchor: under its beam's tip.
static func jib_anchor(j: Array) -> Vector3:
	var tip: Vector2 = j[0]
	var post: Vector2 = j[1]
	return Vector3(tip.x,ground(post.x,post.y)+JIB_TALL,tip.y)

static func _walk_shape(solids: Node3D, place: Transform3D, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = place
	var c := CollisionShape3D.new()
	c.shape = _box_shape(size)
	body.add_child(c)
	solids.add_child(body)
	return body

static func _walk_cyl(solids: Node3D, centre: Vector2, radius: float, bottom: float, high: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(centre.x,(bottom+high)*0.5,centre.y)
	var c := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = high-bottom
	c.shape = shape
	body.add_child(c)
	solids.add_child(body)

# --- What moves ------------------------------------------------------------------------

## The overseer (a whole headless body, its head on, its chase on) set down
## on the road, its STAND-IN patrol, and the ropes on the hoist jibs.
func live(g: Node) -> void:
	for j: Array in LAYOUT.jibs:
		var anchor := jib_anchor(j)
		var tip: Vector2 = j[0]
		g.rope(g.w(anchor),anchor.y-ground(tip.x,tip.y)-1.3)
	var b: Dictionary = LAYOUT.body
	var b2: Vector2 = b.at
	var at: Vector3 = g.w(Vector3(b2.x,ground(b2.x,b2.y)+0.1,b2.y))
	var body: Node3D = g.enemy(HeadlessBody,at,b.face,{"chase":1,"routes":0,"seed":TURF_SEED})
	var head: Node3D = g.enemy(InhalerHead,at,b.face,{})
	var patrol := Patrol.new()
	patrol.name = "Patrol_STANDIN"
	for p: Vector2 in LAYOUT.patrol: patrol.beat.append(g.w(Vector3(p.x,ground(p.x,p.y),p.y)))
	patrol.post = at
	patrol.field = g.stage.enemies
	patrol.wear(body,head)
	g.add_child(patrol)

## STAND-IN: the overseer's rounds. A whole body unaware roams any way
## (scripts/enemies/headless_body.gd `_pick_way`); this turns it, while it
## listens or roams and is not hunting, toward the next point of its beat
## along the haul road, back and forth. Its sight, chase, climb, leap and
## return are its own. After the stage's reset (R) it finds the body and
## head set down again and puts the head back on.
class Patrol extends Node:
	var beat: Array[Vector3] = []
	var post := Vector3.ZERO
	var field: Node = null
	var body: Node3D = null
	var head: Node3D = null
	var leg := 1
	var dir := 1
	## Counted, for checks: beats turned at, frames steered.
	var turns := 0
	var steered := 0
	## The land under its post stood (a rendered yard builds the art on a
	## worker after the stage is set: till then it is held at its post).
	var landed := false

	func wear(b: Node3D, h: Node3D) -> void:
		body = b
		head = h
		if body != null and head != null: body.make_whole(head)

	func _physics_process(_delta: float) -> void:
		if body == null or not is_instance_valid(body) or head == null or not is_instance_valid(head):
			_refind()
			return
		if not landed:
			var stone: StaticBody3D = body.body
			landed = field.floor_under(post,2.0,6.0,stone.get_rid() if stone != null else RID()) > -INF
			if not landed:
				body.position = post
				body.vel = Vector3.ZERO
				return
		if not body.whole or body.hunting: return
		if not (str(body.state) in ["listen","roam"]): return
		var to: Vector3 = beat[leg]
		var flat := Vector2(to.x-body.position.x,to.z-body.position.z)
		if flat.length() < 3.0:
			if leg+dir < 0 or leg+dir >= beat.size(): dir = -dir
			leg += dir
			turns += 1
			to = beat[leg]
			flat = Vector2(to.x-body.position.x,to.z-body.position.z)
		body._heading = PilotMotor.facing_of(flat.normalized())
		steered += 1

	func _refind() -> void:
		if field == null: return
		body = null
		head = null
		for e: Node3D in field.enemies:
			if not is_instance_valid(e): continue
			if e.has_method("make_whole") and e.position.distance_to(post) < 6.0: body = e
			elif e.has_method("mouth") and e.position.distance_to(post) < 12.0: head = e
		if body != null and head != null:
			body.make_whole(head)
			landed = false
			leg = 1
			dir = 1
