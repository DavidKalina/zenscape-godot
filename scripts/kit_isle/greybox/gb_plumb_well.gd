extends "res://scripts/kit_isle/motif_greybox.gd"
## The Plumb Well in the generator: studies/greybox/plumb_well.gd's layout,
## the same geometry in the same frame, so the column's chain keeps the
## study's numbers: walk off the cap into oculus 1, the leaf throws you into
## the plumb wall and down the slot, the seesaw's block flings you down
## oculus 3, the slabs go, the head at the foot gulps you and blasts you
## south out of rim S.
##
## What the study left to "whatever the generator hung there" is part of the
## motif now: the head's blast comes down into a CATCHING CANNON on the
## cannon terrace under rim S (its
## mouth where the blast comes down, as the cannon yard's station 4), which
## fires him east, off the terrace's edge, down onto the landing (the
## catching isle). The rim out is the landing's far (east) edge. Missed, the
## terrace still catches him and the cannon is a cannon: climb in, fire.
## The cap is the rim in.
##
## Turf pass (below `parts`): the cap, the foot, the terrace and the landing
## are KitLand islands at the greybox's tops; the shaft's masonry is cut
## stone collided as the greybox's boxes. `--well-grey` builds the grey
## boxes (A/B).

# --- The study's numbers, verbatim (studies/greybox/plumb_well.gd) -------------------
const PUMP := 1.5
const H := 9.0
const FOOT_DROP := 8.0
const THICK := 1.5
const WALL_Z := 12.0
const PLATES := [
	{"name":"1  the cap","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP+3.0*H,
		"holes":[Rect2(-1.8,8.1,3.6,3.9)],"tiers":[]},
	{"name":"2  the leaf plate","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP+2.0*H,
		"holes":[Rect2(-2.0,8.6,4.0,3.4)],"tiers":[]},
	{"name":"3  the seesaw plate","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP+H,
		"holes":[Rect2(-4.0,1.5,12.1,10.5)],"tiers":[]},
	{"name":"4  the loose floor","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP,
		"holes":[Rect2(-5.0,3.1,6.0,5.4)],"tiers":[]},
	{"name":"5  the foot (the head's)","rect":Rect2(-14.0,-4.0,28.0,16.0),"top":0.0,"holes":[],
		"tiers":[{"rect":Rect2(7.0,4.0,6.0,6.0),"rise":0.9}]},
]
const SPINE := {"at":Vector2(6.0,-4.0),"radius":1.2}
const WALLS := [
	{"name":"plumb wall","rect":Rect2(-16.0,WALL_Z,32.0,1.0),"bottom":-THICK,"top":FOOT_DROP+3.0*H},
	{"name":"kerb","rect":Rect2(-1.6,9.5,0.7,2.5),"bottom":FOOT_DROP+H-THICK,"top":FOOT_DROP+H},
]
const WINDLASS := {"at":Vector2(4.0,10.5),"radius":0.6,"rise":1.6}
const TRAPS := [
	{"name":"leaf","script":"flip","at":Vector3(0.0,FOOT_DROP+2.0*H,11.2),"yaw":0.0,
		"knobs":{"count":1,"length":2.4,"width":3.6,"gap":0.0,"stagger":0.0,"period":3.0,"underside":"safe","speedup":0.0}},
	{"name":"seesaw","script":"drop","at":Vector3(8.1,FOOT_DROP+H,WALL_Z-1.25),"yaw":90.0,
		"knobs":{"length":9.0,"hook":3.6,"plate":true,"fuse":0.5,"ledge":0.0,"cap_mul":1.0,"along":0.15,"veer":0.45}},
	{"name":"slabs","script":"voussoirs","at":Vector3(-2.0,FOOT_DROP,8.5),"yaw":0.0,
		"knobs":{"count":3,"length":1.8,"width":5.96}},
]
const HEAD_AT := Vector3(-2.4,0.0,6.7)
## New in the generator: `lock_angle` 0.6 (the head's 0.16) keeps it from
## notching toward a body that comes down a little off its face (it tracks
## past lock_angle x 0.6), so its blast always goes due south, into the
## cannon's mouth (a notch of 8-14 deg sent 4 of 10 column runs wide).
const ENEMIES := [
	{"name":"head","script":"inhaler_head","at":HEAD_AT,"face":Vector2(0.0,-1.0),
		"knobs":{"route":[HEAD_AT,HEAD_AT+Vector3(0.5,0.0,0.0)],"lock_angle":0.6}},
]

# --- New in the generator: the cannon terrace and the landing ------------------------
## The cannon terrace under rim S (its top), and the catching cannon on it:
## the cannon yard's head station turned to this head (its blast south):
## the cannon 2.02 m west of the head's line, 15.9 m out, 6 m down, aimed
## east (heading -90 deg), so its mouth sits where the blast comes down.
const TERRACE_Y := -6.0
const TERRACE := Rect2(-12.0,-16.0,18.0,11.2)
const CANNON_AT := Vector3(HEAD_AT.x-2.02,TERRACE_Y,HEAD_AT.z-15.9)
const CANNON_HEADING := -PI*0.5
## The landing: where the cannon's rest shot (40 deg, notch 2) comes down,
## 8 m under the terrace (Cannon.landing_for: x 19.46 at z -9.2), a pad
## round it; the rim out on its east edge.
const LANDING_Y := -14.0
const LANDING := Rect2(13.0,-16.0,14.0,11.5)

const LABELS := [
	[Vector3(0.0,FOOT_DROP+3.0*H+2.5,8.0),"CAP · oculus 1 (rope-worn lip) against the plumb wall · 9 m to the leaf"],
	[Vector3(4.0,FOOT_DROP+3.0*H+3.0,10.5),"STAND-IN: windlass (a drum; no hook or rope)"],
	[Vector3(-8.0,FOOT_DROP+3.0*H+3.0,12.5),"PLUMB WALL (every oculus runs down it in one line)"],
	[Vector3(0.0,FOOT_DROP+2.0*H+6.0,8.0),"THE WHOLE COLUMN: walk off into oculus 1 -> leaf hands you into the slot -> seesaw fuse, block, fling south -> slabs go -> the head -> the cannon"],
	[Vector3(0.0,FOOT_DROP+2.0*H+3.5,9.0),"PLATE 2: THE LEAF (flips every 3 s; caught on it, you are thrown into the wall and down the 0.8 m slot)"],
	[Vector3(4.0,FOOT_DROP+H+5.5,10.5),"PLATE 3: THE SEESAW DROP (lie or stand on its far plate 0.5 s: flung south down oculus 3)"],
	[Vector3(-1.2,FOOT_DROP+H+1.2,10.5),"kerb"],
	[Vector3(-2.0,FOOT_DROP+3.5,4.0),"PLATE 4: LOOSE SLABS (they go a beat after you land)"],
	[Vector3(-2.0,5.5,8.5),"THE FOOT: the inhaler head, watching the slabs"],
	[Vector3(-2.0,3.0,-3.0),"RIM S · let the head swallow you: its blast drops you into the cannon below"],
	[Vector3(-4.4,TERRACE_Y+4.0,-12.0),"CANNON TERRACE · the catching cannon fires you east, down onto the landing"],
	[Vector3(20.0,LANDING_Y+3.0,-9.0),"THE LANDING · the way on leaves its east edge"],
	[Vector3(10.0,2.4,7.0),"masons' gallery (a bench tier, 0.9 m)"],
	[Vector3(6.0,FOOT_DROP+H+3.0,-4.0),"the spine (wall-kick up the column)"],
]

func slug() -> String:
	return "plumb_well"

func isle_name() -> String:
	return "The Plumb Well"

func epithet() -> String:
	return "Where they lowered the stone, the stone still waits to be lowered."

func brief() -> String:
	return "Run off the cap into the oculus by the wall, pull back onto the leaf, then let the column take you: leaf, seesaw, slabs, the head.\nLet the head swallow you: its blast drops you into the cannon below, which fires you on."

## The study's station 1 (the cap, oculus 1 ahead).
func start() -> Vector3:
	return Vector3(0.0,FOOT_DROP+3.0*H,2.0)

## The study's _structure, from the table, plus the terrace and the landing.
func parts() -> Array:
	var out: Array = []
	for pl: Dictionary in PLATES:
		var rect: Rect2 = pl.rect
		var top: float = pl.top
		var holes: Array[Rect2] = []
		for h: Rect2 in pl.holes: holes.append(h)
		for r: Rect2 in _floor_rects(rect,holes): out.append(["box",r,top-THICK,top,"floor"])
		for h: Rect2 in holes:
			for r: Rect2 in [Rect2(h.position.x-0.4,h.position.y-0.4,h.size.x+0.8,0.4),Rect2(h.position.x-0.4,h.end.y,h.size.x+0.8,0.4),
					Rect2(h.position.x-0.4,h.position.y,0.4,h.size.y),Rect2(h.end.x,h.position.y,0.4,h.size.y)]:
				if r.position.y >= WALL_Z-0.01: continue
				out.append(["box",r,top-0.05,top+0.02,"lip"])
		for t: Dictionary in pl.tiers: out.append(["box",t.rect,top,top+float(t.rise),"grey"])
		out.append(["label",Vector3(rect.position.x+4.0,top+0.8,rect.position.y+3.0),"PLATE %s · top %d m" % [pl.name,int(top)]])
	var top_all: float = PLATES[0].top
	out.append(["cyl",SPINE.at,float(SPINE.radius),-THICK,top_all,"grey"])
	for w: Dictionary in WALLS: out.append(["box",w.rect,float(w.bottom),float(w.top),"wall"])
	out.append(["cyl",WINDLASS.at,float(WINDLASS.radius),top_all,top_all+float(WINDLASS.rise),"dark"])
	out.append(["box",TERRACE,TERRACE_Y-2.0,TERRACE_Y,"floor"])
	out.append(["box",LANDING,LANDING_Y-2.0,LANDING_Y,"pad"])
	for l: Array in LABELS: out.append(["label",l[0],l[1]])
	return out

## character_study's `_floor_rects`: a room's floor round its holes.
static func _floor_rects(room: Rect2, all_holes: Array[Rect2]) -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for h in all_holes: if h.intersects(room): holes.append(h)
	var xs := [room.position.x,room.end.x]
	for h in holes: xs.append_array([h.position.x,h.end.x])
	xs.sort()
	var out: Array[Rect2] = []
	for i in range(xs.size()-1):
		var x0: float = xs[i]
		var x1: float = xs[i+1]
		if x1-x0 < 0.001: continue
		var cuts: Array = []
		for h in holes:
			if h.position.x < x1-0.001 and h.end.x > x0+0.001: cuts.append(Vector2(h.position.y,h.end.y))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var z := room.position.y
		for c: Vector2 in cuts:
			if c.x > z+0.001: out.append(Rect2(x0,z,x1-x0,c.x-z))
			z = maxf(z,c.y)
		if room.end.y > z+0.001: out.append(Rect2(x0,z,x1-x0,room.end.y-z))
	return out

## In on the cap's south edge (the oculus by the wall 21 m ahead), out off
## the landing's east edge (where the cannon's shot comes down).
func rims() -> Array:
	return [
		{"name":"cap","at":Vector3(0.0,FOOT_DROP+3.0*H,-13.0),"face":Vector3(0.0,0.0,-1.0),"run_up":8.0,"lip":1.0},
		{"name":"landing","at":Vector3(LANDING.end.x-1.0,LANDING_Y,LANDING.get_center().y),"face":Vector3(1.0,0.0,0.0),"run_up":12.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"foot","at":Vector3(2.0,0.0,2.0),"room":6.0},
		{"kind":"cover","name":"spine","at":Vector3(6.0,FOOT_DROP+H,-6.0),"room":1.2},
		{"kind":"perch","name":"gallery","at":Vector3(10.0,0.9,7.0),"room":2.0},
		{"kind":"perch","name":"landing","at":Vector3(18.0,LANDING_Y,-12.0),"room":3.0},
	]

func heads() -> Array:
	var out: Array = []
	for e: Dictionary in ENEMIES: out.append({"name":e.name,"at":e.at,"face":e.face,"knobs":e.knobs})
	return out

const FlipTrap = preload("res://scripts/traps/trap_flip.gd")
const DropTrap = preload("res://scripts/traps/trap_seesaw_drop.gd")
const VoussoirTrap = preload("res://scripts/traps/trap_voussoirs.gd")

## The three traps (the study's classes and knobs) and the catching cannon.
func live(g: Node) -> void:
	var scripts := {"flip":FlipTrap,"drop":DropTrap,"voussoirs":VoussoirTrap}
	for t: Dictionary in TRAPS:
		var trap: Node3D = (scripts[t.script] as GDScript).new()
		trap.configure(t.knobs)
		trap.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(t.yaw))),g.w(t.at))
		g.trap(trap)
	# The stage makes its CannonField after the greybox isles' live bits
	# (layer_stage.gd), so the cannon goes in once the stage is built.
	var at: Vector3 = g.w(CANNON_AT)
	var add := func() -> void:
		if is_instance_valid(g) and g.cannons() != null: g.cannons().add_cannon(at,CANNON_HEADING)
	if g.cannons() != null: add.call()
	else: add.call_deferred()

# --- Turf pass: the land and the stone --------------------------------------------------
## Ground the sky sees (the cap, the foot, the cannon terrace, the landing)
## is KitLand islands, flat at the greybox's tops to the centimetre; the
## shaft's masonry (plates 2-4, the plumb wall, the kerb, the spine, oculus
## 1's collar, the masons' bench, the windlass posts) is cut stone in the
## giant's basalt (giant_stone.gd), each collided as its greybox walk box.
## The rune line on the plumb wall shortens plate by plate (the card's
## mystery). `--well-grey` builds the grey boxes instead (A/B checks).

const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")

const TURF_SEED := 4400
## The islands' keels (m under their tops).
const CAP_DEPTH := 3.0
const FOOT_DEPTH := 8.0
const TERRACE_DEPTH := 5.0
const LANDING_DEPTH := 6.0
## Oculus 1's stone collar (m round the hole) and how far the cap's turf
## keeps back from the hole under it: the turf's wobbled edge stays under
## the collar, so the hole's edge is the collar's, exact.
const COLLAR := 1.2
const TURF_BACK := 0.8
## The collar stands this proud of the turf (no z-fight).
const PROUD := 0.03

static func cap_top() -> float:
	return float(PLATES[0].top)

## The cap's ground: the plate with a notch round oculus 1 (open north,
## onto the plumb wall).
static func cap_outline() -> Array:
	var r: Rect2 = PLATES[0].rect
	var h: Rect2 = (PLATES[0].holes[0] as Rect2).grow(TURF_BACK)
	return [Vector2(r.position.x,r.position.y),Vector2(r.end.x,r.position.y),Vector2(r.end.x,r.end.y),
		Vector2(h.end.x,r.end.y),Vector2(h.end.x,h.position.y),Vector2(h.position.x,h.position.y),
		Vector2(h.position.x,r.end.y),Vector2(r.position.x,r.end.y)]

static func foot_outline() -> Array:
	return _rounded(PLATES[4].rect,1.0)

static func terrace_outline() -> Array:
	return _rounded(TERRACE,1.6)

static func landing_outline() -> Array:
	return _rounded(LANDING,1.6)

## A rect's outline with its corners cut `cut` m.
static func _rounded(r: Rect2, cut: float) -> Array:
	var a := r.position
	var b := r.end
	return [Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),
		Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)]

## The worn ways: the cap from its rim to the oculus, the foot from the
## head to rim S, across the landing to its rim.
static func paths() -> Array:
	return [[Vector2(0.0,-13.0),Vector2(0.0,7.0)],[Vector2(-2.4,5.0),Vector2(-2.4,-3.5)],
		[Vector2(15.0,-9.2),Vector2(26.0,-10.0)]]

func grey_flag() -> String:
	return "--well-grey"

func turf_seed() -> int:
	return TURF_SEED

func turf_paths() -> Array:
	return paths()

## Measured headless (the turf build).
func turf_cost() -> int:
	return 350

func flora_site() -> KitFlora.Site:
	var site := super.flora_site()
	# Rays from over the cap down past the landing (the plates are stone).
	site.ray = Vector2(top()+60.0,LANDING_Y-8.0)
	return site

func warm_turf() -> void:
	warm_look()
	GiantStone.warm()

## The islands, flat at the greybox's tops (their keels in the occupancy).
func turf_islands() -> Array:
	return [
		{"name":"Cap","outline":cap_outline(),"top":cap_top(),"depth":CAP_DEPTH,"resample":[90.0,220,64]},
		{"name":"Foot","outline":foot_outline(),"top":0.0,"depth":FOOT_DEPTH,"resample":[60.0,120,40]},
		{"name":"Terrace","outline":terrace_outline(),"top":TERRACE_Y,"depth":TERRACE_DEPTH,"resample":[50.0,90,32]},
		{"name":"Landing","outline":landing_outline(),"top":LANDING_Y,"depth":LANDING_DEPTH,"resample":[50.0,90,32]},
	]

func dress(root: Node3D) -> void:
	_stone(root)

## The shaft's masonry: drawn as one mesh of cut stone, collided as the
## greybox's walk boxes.
func _stone(root: Node3D) -> void:
	var m: RefCounted = GiantStone.mesher()
	var solids := Node3D.new()
	solids.name = "Walk"
	root.add_child(solids)
	# Plates 2-4: cut-stone floors round their oculi (the greybox's rects),
	# slabs about 4 m, those at a hole a shade lighter (the rope-worn lip).
	for i in range(1,4):
		var pl: Dictionary = PLATES[i]
		var top: float = pl.top
		var holes: Array[Rect2] = []
		for h: Rect2 in pl.holes: holes.append(h)
		for r: Rect2 in _floor_rects(pl.rect,holes):
			_walk(solids,r,top-THICK,top)
			_slabs(m,r,top-THICK,top,holes)
	# Oculus 1's collar on the cap (the hole's exact edge; the turf under it).
	var o1: Rect2 = PLATES[0].holes[0]
	for r: Rect2 in [Rect2(o1.position.x-COLLAR,o1.position.y-COLLAR,o1.size.x+COLLAR*2.0,COLLAR),
			Rect2(o1.position.x-COLLAR,o1.position.y,COLLAR,o1.size.y),Rect2(o1.end.x,o1.position.y,COLLAR,o1.size.y)]:
		_block(m,solids,r,cap_top()-THICK,cap_top()+PROUD,0.12,NAN,1.12)
	# The plumb wall, the kerb, the spine.
	for w: Dictionary in WALLS:
		_block(m,solids,w.rect,float(w.bottom),float(w.top),0.2 if str(w.name) == "plumb wall" else 0.1)
	var centre: Vector2 = SPINE.at
	var radius := float(SPINE.radius)
	_walk_cyl(solids,centre,radius,-THICK,cap_top())
	m.cylinder(Transform3D(Basis.IDENTITY,Vector3(centre.x,(cap_top()-THICK)*0.5,centre.y)),radius,cap_top()+THICK,16,0.14,-THICK)
	# The rune line on the plumb wall (its south face, over the oculus
	# line), shorter plate by plate, ending over the head.
	var lengths := [12.0,9.0,6.0,4.0,2.4]
	for i in range(PLATES.size()):
		var y := float(PLATES[i].top)+2.6
		var half: float = lengths[i]*0.5
		m.runes(Vector3(-half,y,WALL_Z),Vector3(half,y,WALL_Z),Vector3.UP,Vector3(0,0,-1),11.0+i)
	# The masons' bench on the foot.
	var bench: Dictionary = PLATES[4].tiers[0]
	_block(m,solids,bench.rect,-0.3,float(bench.rise),0.15,0.0)
	# The windlass: two stone posts and a wooden drum, collided as the
	# greybox's drum.
	var wc: Vector2 = WINDLASS.at
	var wr := float(WINDLASS.radius)
	var rise := float(WINDLASS.rise)
	_walk_cyl(solids,wc,wr,cap_top(),cap_top()+rise)
	for sx: float in [-1.0,1.0]:
		var post := Rect2(wc.x+sx*wr-0.16,wc.y-0.16,0.32,0.32)
		m.box(_at(post,cap_top()-0.2,cap_top()+rise),_size(post,cap_top()-0.2,cap_top()+rise),0.05,cap_top())
	var body := MeshInstance3D.new()
	body.name = "Stone"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.24,0.17,0.11)
	bark.roughness = 1.0
	var drum := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.36
	dm.bottom_radius = 0.36
	dm.height = wr*2.0
	dm.radial_segments = 12
	drum.mesh = dm
	drum.transform = Transform3D(Basis(Vector3.BACK,PI*0.5),Vector3(wc.x,cap_top()+rise-0.45,wc.y))
	drum.material_override = bark
	root.add_child(drum)

## A floor rect laid as slabs about 4 m long; a slab at a hole a shade
## lighter (the rope-worn lip).
static func _slabs(m: RefCounted, r: Rect2, bottom: float, high: float, holes: Array[Rect2]) -> void:
	var along_x := r.size.x >= r.size.y
	var length := r.size.x if along_x else r.size.y
	var n := maxi(int(round(length/4.0)),1)
	for k in range(n):
		var s := Rect2(r.position.x+r.size.x*k/n,r.position.y,r.size.x/n,r.size.y) if along_x else Rect2(r.position.x,r.position.y+r.size.y*k/n,r.size.x,r.size.y/n)
		var worn := false
		for h: Rect2 in holes:
			if s.grow(0.05).intersects(h): worn = true
		m.box(_at(s,bottom,high),_size(s,bottom,high),0.1,bottom,1.1 if worn else 1.0)

static func _block(m: RefCounted, solids: Node3D, r: Rect2, bottom: float, high: float, bevel: float, foot := NAN, tone := 1.0) -> void:
	_walk(solids,r,bottom,high)
	m.box(_at(r,bottom,high),_size(r,bottom,high),bevel,foot,tone)

static func _at(r: Rect2, bottom: float, high: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y))

static func _size(r: Rect2, bottom: float, high: float) -> Vector3:
	return Vector3(r.size.x,high-bottom,r.size.y)

## A walk box (the greybox's), collided only.
static func _walk(solids: Node3D, r: Rect2, bottom: float, high: float) -> void:
	var body := StaticBody3D.new()
	body.transform = _at(r,bottom,high)
	var c := CollisionShape3D.new()
	c.shape = _box_shape(_size(r,bottom,high))
	body.add_child(c)
	solids.add_child(body)

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
