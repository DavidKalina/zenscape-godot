extends "res://scripts/kit_isle/motif_greybox.gd"
## The Warden's Well in the generator: studies/greybox/wardens_well.gd's
## LAYOUT (card: docs/design/roguelike/brainstorm/round1/motif-m5-wardens-
## well.md), the same geometry in the same frame, so the head-to-head relay
## keeps the study's numbers: stand on the dais lip, head 1 blasts you north
## down onto cell 1, your skid ends square on head 2's face, head 2 blasts you
## west down onto the exit rim. The study's stand-in exit rim is part of the
## motif here (head 2's blast lands you on it) and the rim out is its far
## (west) edge, where a generated crossing attaches. The flooded entry's
## south edge is the rim in.
##
## One link the study lacked (docs/design/roguelike/cannon-catch.md): a
## catching cannon down in void 2, under cell 1's west edge on head 2's line.
## A missed relay (head 2 asleep, or taken off by its headless body) leaves
## you on cell 1 with no way on; step off its west edge into the cannon's
## mouth and it fires you west onto the exit rim. Head 2's blast flies over
## it going away from its mouth, so it never catches the relay.
const SLAB := 3.0
const Y_DAIS := 0.0
const Y_CELL := -4.0
const Y_EXIT := -11.0
const H1 := Vector3(0.0,Y_DAIS,8.0)
const LIP := 6.0
const H2 := Vector3(4.5,Y_CELL,-14.9)
## The catching cannon: its base on a pier in void 2, under cell 1's west
## edge on head 2's line (z of H2), heading west (PI/2), rest aim (40 deg,
## notch 2). Its mouth is at about (-5.0, -10.4, -14.9), 1.5 m past cell 1's
## edge and 6.4 m under it: a drop from the hang on the edge (x about -3.9,
## measured) comes down 1.1 m from it, a run off the edge (about x -6.4 at
## its height) 1.4 m; its rest shot lands at about x -18.6 on the exit rim
## (Cannon.landing_for), 7.6 m in from its east edge.
const CANNON_AT := Vector3(-3.0,-13.0,-14.9)
const CANNON_HEADING := PI*0.5
## Its funnel widened (the default 2.64 m) so both of those turn in; the
## radius that swallows is the default's.
const CANNON_KNOBS := {"catch_pull":4.0}

## The study's LAYOUT, verbatim but for the exit rim's label (no longer a
## stand-in) and the cannon's pier and notes.
const LAYOUT := {
	"masses": [
		{"name": "hall", "rect": Rect2(-20.0, 1.2, 40.0, 28.8), "top": Y_DAIS-0.4,
		 "tiers": [[Rect2(-12.0, 1.2, 24.0, 12.8), Y_DAIS]],
		 "water": [[Rect2(-20.0, 14.0, 40.0, 16.0), 0.3]],
		 "label": [Vector3(-12.0, 0.6, 20.0), "FLOODED ENTRY (wading) - the hall's drowned floor"]},
		{"name": "cell 1", "rect": Rect2(-3.5, -18.0, 12.0, 11.7), "top": Y_CELL, "tiers": [],
		 "label": [Vector3(5.5, Y_CELL+1.6, -8.0), "CELL 1  (4 m down the well)"]},
		{"name": "plank", "rect": Rect2(8.5, -16.0, 2.5, 2.0), "top": Y_CELL, "tiers": []},
		{"name": "cell 2", "rect": Rect2(11.0, -21.0, 10.0, 10.0), "top": Y_CELL, "tiers": [],
		 "label": [Vector3(16.0, Y_CELL+1.6, -16.0), "CELL 2  (cache; by the plank)"]},
		{"name": "exit rim", "rect": Rect2(-34.0, -34.0, 23.0, 29.0), "top": Y_EXIT, "tiers": [],
		 "label": [Vector3(-20.0, Y_EXIT+1.6, -12.0), "EXIT RIM  (7 m under cell 1; the way on leaves its west edge)"]},
	],
	"pieces": [
		{"kind": "cyl", "name": "column W", "at": Vector2(-3.0, 5.6), "r": 1.0, "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "cyl", "name": "column E", "at": Vector2(3.0, 5.6), "r": 1.0, "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "box", "name": "lip post W", "rect": Rect2(-1.65, 2.6, 0.9, 0.8), "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "box", "name": "exit kerb", "rect": Rect2(-34.0, -5.3, 23.0, 0.3), "bottom": Y_EXIT, "top": Y_EXIT+0.5},
		{"kind": "box", "name": "chest 1", "rect": Rect2(5.5, -8.5, 2.0, 1.2), "bottom": Y_CELL, "top": Y_CELL+1.0},
		{"kind": "box", "name": "chest 2", "rect": Rect2(17.0, -20.6, 2.0, 1.2), "bottom": Y_CELL, "top": Y_CELL+1.0},
	],
	## The catching cannon's pier (grey, not walked: nothing reaches its top).
	"pier": [Rect2(CANNON_AT.x-1.5, CANNON_AT.z-1.5, 3.0, 3.0), CANNON_AT.y-4.0, CANNON_AT.y],
	"heads": [
		{"name": "head 1", "at": H1, "face": Vector2(0.0, -1.0), "knobs": {"size": 3.0}},
		{"name": "head 2 (small)", "at": H2, "face": Vector2(-1.0, 0.0), "knobs": {"size": 2.0}},
	],
	"notes": [
		[H1+Vector3(0.0, 5.0, 0.0), "HEAD 1 - stand on the lip and it blasts you north, down onto cell 1"],
		[H2+Vector3(0.0, 4.0, 0.0), "HEAD 2 (small) - your skid ends on its face; it winds up and blasts you WEST"],
		[Vector3(0.0, 2.0, -2.5), "VOID 1: 7.5 m across, 4 m down to cell 1"],
		[Vector3(-7.0, Y_CELL+2.0, -14.0), "VOID 2: 7.5 m across, 7 m down to the exit rim"],
		[Vector3(-2.2, 3.2, 1.8), "LIP POST: head 1 cannot see you behind it; step out east onto the lip"],
		[H1+Vector3(0.0, 3.0, -LIP), "LIP: on head 1's axis it draws you in and fires you dead north"],
		[CANNON_AT+Vector3(0.0, 4.6, 0.0), "CATCHING CANNON: missed the relay? step off cell 1 here, it fires you onto the exit rim"],
	],
}

func slug() -> String:
	return "wardens_well"

func isle_name() -> String:
	return "The Warden's Well"

func epithet() -> String:
	return "Nobody leaves. They are posted."

func brief() -> String:
	return "The heads are the only way across. Step out from behind the lip post onto the lip and hold still:\nhead 1 spits you down onto cell 1, into head 2's face; hold still again and it spits you west to the exit rim.\nMissed it? Step off cell 1's west edge into the cannon below."

## The study's station 1 (the flooded entry).
func start() -> Vector3:
	return Vector3(-8.0,Y_DAIS-0.4,24.0)

func parts() -> Array:
	var out: Array = []
	for m: Dictionary in LAYOUT.masses:
		out.append(["box",m.rect,float(m.top)-SLAB,m.top,"floor"])
		for t: Array in m.tiers: out.append(["box",t[0],float(m.top)-SLAB,t[1],"grey"])
		for w: Array in m.get("water",[]):
			var r: Rect2 = w[0]
			out.append(["box",r,float(m.top)-SLAB,m.top,"dark"])
			out.append(["water",r,m.top,float(m.top)+float(w[1])])
		if m.has("label"): out.append(["label",m.label[0],m.label[1]])
	for p: Dictionary in LAYOUT.pieces:
		if p.kind == "cyl": out.append(["cyl",p.at,p.r,p.bottom,p.top,"grey"])
		else: out.append(["box",p.rect,p.bottom,p.top,"lip"])
	out.append(["box",LAYOUT.pier[0],LAYOUT.pier[1],LAYOUT.pier[2],"dark"])
	for n: Array in LAYOUT.notes: out.append(["label",n[0],n[1]])
	return out

## In at the flooded entry's south edge (the study's start), out off the
## exit rim's west edge (head 2's blast and the cannon's shot land you on it).
func rims() -> Array:
	return [
		{"name":"entry","at":Vector3(-8.0,Y_DAIS-0.4,29.0),"face":Vector3(0.0,0.0,1.0),"run_up":12.0,"lip":1.0},
		{"name":"exit","at":Vector3(-33.0,Y_EXIT,-19.5),"face":Vector3(-1.0,0.0,0.0),"run_up":15.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"dais","at":Vector3(-7.0,Y_DAIS,8.0),"room":4.0},
		{"kind":"cover","name":"column_w","at":Vector3(-3.0,Y_DAIS,4.2),"room":1.0},
		{"kind":"cover","name":"column_e","at":Vector3(3.0,Y_DAIS,4.2),"room":1.0},
		{"kind":"perch","name":"cell_2","at":Vector3(16.0,Y_CELL,-15.0),"room":3.0},
	]

## Both heads posted on a one-point route (their own spot), as the study.
func heads() -> Array:
	var out: Array = []
	for h: Dictionary in LAYOUT.heads:
		var knobs: Dictionary = (h.knobs as Dictionary).duplicate()
		knobs["route"] = [h.at]
		out.append({"name":h.name,"at":h.at,"face":h.face,"knobs":knobs})
	return out

## The catching cannon in void 2. Added a frame late: the stage makes its
## CannonField after the greybox isles' live bits (layer_stage.gd).
func live(g: Node) -> void:
	var add := func() -> void:
		if is_instance_valid(g) and g.cannons() != null: g.cannons().add_cannon(g.w(CANNON_AT),CANNON_HEADING,CANNON_KNOBS)
	add.call_deferred()

# --- Turf pass: the land and the stone --------------------------------------------------
## The card's turf pass (the motif-turf skill), in place: four KitLand
## islands whose ground is the greybox's tiers to the centimetre (the hall:
## the drowned floor at -0.4 and the dais at 0; cell 1; cell 2; the exit
## rim), turf on top, hanging rock and a keel under; the hall's drowned half
## a KitWater sheet; the columns, the lip post, the exit kerb, the plank and
## the cannon's pier in the Olmec basalt (giant_stone.gd: the heads' own
## stone), each collided as its greybox walk box; the two caches RuinKit
## carved chests. The LAYOUT stays the one table (the occupancy is computed
## from it, plus the keels). `--wardens-well-grey` builds the grey boxes
## instead (A/B checks).

const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const KitWater = preload("res://scripts/kit_isle/kit_water.gd")

const TURF_SEED := 5200
## The islands' keels (m under their datum).
const HALL_DEPTH := 8.0
const CELL_DEPTH := 5.0
const EXIT_DEPTH := 10.0
## How far a keel's spurs can hang under top-depth (as the giant's).
const KEEL_REACH := 1.4
## The water's top over the drowned floor (the greybox's 0.3 m).
const WATER_TOP := Y_DAIS-0.4+0.3

static func grey() -> bool:
	return preload("res://scripts/launch_args.gd").user_args().has("--wardens-well-grey")

## The hall's ground: the dais at 0, the drowned floor at -0.4.
static func hall_ground(x: float, z: float) -> float:
	return Y_DAIS if absf(x) <= 12.0 and z <= 14.0 else Y_DAIS-0.4

static func _rounded(r: Rect2, cut: float) -> Array:
	var a := r.position
	var b := r.end
	return [Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),
		Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)]

## [name, outline, ground, top, depth, seed offset]. Corners cut only: the
## lip, the skid lane and both landings are mid-edge.
static func islands() -> Array:
	return [
		["Hall",_rounded(Rect2(-20.0,1.2,40.0,28.8),2.0),func(x: float, z: float) -> float: return hall_ground(x,z),Y_DAIS-0.4,HALL_DEPTH,0],
		["Cell1",_rounded(Rect2(-3.5,-18.0,12.0,11.7),1.2),func(_x: float, _z: float) -> float: return Y_CELL,Y_CELL,CELL_DEPTH,1],
		["Cell2",_rounded(Rect2(11.0,-21.0,10.0,10.0),1.2),func(_x: float, _z: float) -> float: return Y_CELL,Y_CELL,CELL_DEPTH,2],
		["ExitRim",_rounded(Rect2(-34.0,-34.0,23.0,29.0),2.5),func(_x: float, _z: float) -> float: return Y_EXIT,Y_EXIT,EXIT_DEPTH,3],
	]

## The worn ways: the entry to the lip, the skid lane on cell 1, the exit
## rim from the landing to the way on, the plank.
static func paths() -> Array:
	return [[Vector2(-8.0,24.0),Vector2(-2.0,4.0),Vector2(0.0,2.0)],[Vector2(0.0,-7.0),Vector2(0.0,-14.9),Vector2(3.0,-14.9)],
		[Vector2(-12.5,-14.9),Vector2(-20.0,-14.0),Vector2(-33.0,-19.5)],[Vector2(8.0,-15.0),Vector2(14.0,-15.5)]]

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return TURF_SEED+9

func life_script() -> Script:
	return null if grey() else KitLife

func warm() -> void:
	super.warm()
	if grey(): return
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()
	GiantStone.warm()
	# The water's base material comes from a scene: loaded here, on the main thread.
	KitWater.material({"tea":0.35})

## The greybox's solids and the keels under the four islands (their spurs'
## reach), so the occupancy keeps the generator off the rock.
func _solids() -> Array:
	var out := super._solids()
	if grey(): return out
	for land: Array in islands():
		var ring: Array = land[1]
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		out.append([box.grow(-1.0),float(land[3])-float(land[4])*KEEL_REACH,float(land[3]),null])
	return out

## Measured headless (the turf build).
func build_cost() -> int:
	return 0 if grey() else BUILD_MS

const BUILD_MS := 300

func build(into: Node3D) -> void:
	if grey():
		super.build(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "WardensWell"
	into.add_child(root)
	var hall_wet := func(mid: Vector2, _y: float) -> float:
		return 1.0 if mid.y > 14.0 and absf(mid.x) < 20.0 else 0.0
	var tone := KitLook.turf(TURF_SEED,KitLand.wear_of(paths()),hall_wet)
	for spec: Array in islands():
		var land := KitLand.island({"outline":spec[1],"seed":TURF_SEED+int(spec[5]),"ground":spec[2],
			"top":spec[3],"depth":spec[4],"hang":true,"resample":[40.0,110,40],"tone":tone})
		land.name = str(spec[0])
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	# The drowned half of the hall: still water, wading deep.
	var water := KitWater.still({"level":WATER_TOP,"ground":func(x: float, z: float) -> float: return hall_ground(x,z),
		"rect":Rect2(-20.0,14.0,40.0,16.0),"inside":func(p: Vector2) -> bool: return Rect2(-19.6,14.0,39.2,15.6).has_point(p),
		"tea":0.35,"cell":1.0,"name":"Flood"})
	root.add_child(water)
	_stone(root)
	built_ms = Time.get_ticks_msec()-began

## An island's hanging sides collided as drawn (the giant's): a body falling
## past a flank meets it.
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

## The stone: drawn as one mesh of the heads' basalt, collided as the
## greybox's walk boxes.
func _stone(root: Node3D) -> void:
	var m: RefCounted = GiantStone.mesher()
	var solids := Node3D.new()
	solids.name = "Walk"
	root.add_child(solids)
	for p: Dictionary in LAYOUT.pieces:
		if str(p.name).begins_with("chest"): continue
		if p.kind == "cyl":
			var c: Vector2 = p.at
			var r := float(p.r)
			var y0 := float(p.bottom)-0.3
			var y1 := float(p.top)
			_walk_cyl(solids,c,r,y0,y1)
			m.cylinder(Transform3D(Basis.IDENTITY,Vector3(c.x,(y0+y1)*0.5,c.y)),r,y1-y0,14,0.14,float(p.bottom))
			# A capital: the column carried a beam once.
			var cap := Rect2(c-Vector2.ONE*r*1.25,Vector2.ONE*r*2.5)
			_walk(solids,cap,y1,y1+0.4)
			m.box(_at(cap,y1,y1+0.4),_size(cap,y1,y1+0.4),0.1)
		else:
			var rect: Rect2 = p.rect
			var bottom := float(p.bottom)-0.3
			_walk(solids,rect,bottom,float(p.top))
			m.box(_at(rect,bottom,float(p.top)),_size(rect,bottom,float(p.top)),0.08 if rect.size.y < 0.5 else 0.15,float(p.bottom))
	# The plank between the cells: a slab, its ends set into both.
	var plank: Rect2 = (LAYOUT.masses[2].rect as Rect2).grow_individual(0.6,0.0,0.6,0.0)
	_walk(solids,plank,Y_CELL-0.7,Y_CELL)
	m.box(_at(plank,Y_CELL-0.7,Y_CELL),_size(plank,Y_CELL-0.7,Y_CELL),0.12)
	# The cannon's pier, a band of runes round its head on the sides seen.
	var pier: Rect2 = LAYOUT.pier[0]
	var p0 := float(LAYOUT.pier[1])
	var p1 := float(LAYOUT.pier[2])
	_walk(solids,pier,p0,p1)
	m.box(_at(pier,p0,p1),_size(pier,p0,p1),0.3)
	var band := p1-0.6
	var a := pier.position
	var b := pier.end
	m.runes(Vector3(a.x,band,b.y),Vector3(b.x,band,b.y),Vector3.UP,Vector3(0,0,1),1.0)
	m.runes(Vector3(a.x,band,a.y),Vector3(a.x,band,b.y),Vector3.UP,Vector3(-1,0,0),2.0)
	var body := MeshInstance3D.new()
	body.name = "Stone"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())
	# The caches: carved chests where the greybox's boxes stood.
	for p: Dictionary in LAYOUT.pieces:
		if not str(p.name).begins_with("chest"): continue
		var rect: Rect2 = p.rect
		var chest: Node3D = RuinKit.piece("tomb_chest",TURF_SEED+20+int(rect.position.x),0.4)
		chest.position = Vector3(rect.get_center().x,float(p.bottom),rect.get_center().y)
		root.add_child(chest)

static func _at(r: Rect2, bottom: float, high: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y))

static func _size(r: Rect2, bottom: float, high: float) -> Vector3:
	return Vector3(r.size.x,high-bottom,r.size.y)

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
