extends "res://scripts/kit_isle/motif_greybox.gd"
## The Plumb Well in the generator: studies/greybox/plumb_well.gd's layout
## (card: docs/design/roguelike/brainstorm/round1/motif-m4-plumb-well.md),
## the same geometry in the same frame, so the column's chain keeps the
## study's numbers: walk off the cap into oculus 1, the leaf throws you into
## the plumb wall and down the slot, the seesaw's block flings you down
## oculus 3, the slabs go, the head at the foot gulps you and blasts you
## south out of rim S.
##
## What the study left to "whatever the generator hung there" is part of the
## motif now: the head's blast comes down into a CATCHING CANNON on the
## cannon terrace under rim S (docs/design/roguelike/cannon-catch.md: its
## mouth where the blast comes down, as the cannon yard's station 4), which
## fires him east, off the terrace's edge, down onto the landing (the
## catching isle). The rim out is the landing's far (east) edge. Missed, the
## terrace still catches him and the cannon is a cannon: climb in, fire.
## The cap is the rim in.

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
