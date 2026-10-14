extends "res://scripts/kit_isle/motif_greybox.gd"
## The Sunken Giant in the generator: studies/greybox/sunken_giant.gd's
## LAYOUT (card: docs/design/roguelike/brainstorm/round1/motif-m2-sunken-
## giant.md), the same geometry in the same frame, so its climb and its
## chains keep the study's numbers. The study's stand-in catching pad for
## the next isle is the giant's knee here (head 2's blast lands you on it),
## and the rim out is the knee's far edge, where a generated crossing
## attaches. The fingertips are the rim in.
##
## Turf pass (the card's "Turf pass"): built as kit terrain and carved
## stone, not grey boxes. Three KitLand islands (hand, torso, knee) whose
## ground functions are the greybox tiers (the fingertip pad; the elbow
## ledge, the chest's four set-offs, the shoulder deck; the knee), so their
## steps are the kit's cliffs with real lips, turf on top, hanging rock and
## a keel under; the body (knuckles, forearm, elbow block, chest, stair
## stones, neck stump, chimney fins, the niche, the columns, the thumb) in
## the Olmec's basalt (scripts/kit_isle/greybox/giant_stone.gd), each
## collided as its greybox walk box. The LAYOUT stays the one table: the
## occupancy is still computed from it (plus the keels, `_solids`).
## `--giant-grey` builds the grey boxes instead (A/B checks).

# --- The study's numbers, verbatim (studies/greybox/sunken_giant.gd) ------------------
const GRAB := RuinKit.GRAB_TOP
const CHAIN := RuinKit.CHAIN_TOP
const SO := RuinKit.SET_OFF
const Y_K1 := GRAB-0.15
const Y_K2 := Y_K1+CHAIN-0.375
const Y_K3 := Y_K2+SO
const FOREARM_RISE := 4.0
const Y_END := Y_K3+FOREARM_RISE
const Y_ELBOW := Y_END-SO
const Y_T1 := Y_ELBOW+SO
const Y_T2 := Y_T1+SO
const Y_T3 := Y_T2+SO
const Y_T4 := Y_T3+SO
const SHAFT_TALL := 6.0
const Y_DECK := Y_T4+SHAFT_TALL
const Y_NECK := Y_DECK+SO*6.0
const ROPE := 5.6
const Y_ANCHOR := Y_END+0.9+ROPE
const GAP := 5.2

## The study's LAYOUT, verbatim but for the catching pad (now the knee) and
## the labels that named it a stand-in.
const LAYOUT := {
	"masses":[
		{"name":"HAND · fingertip landing, then knuckles (jump, pump, jump)","base":-4.0,"tiers":[
			[Rect2(-13.0,-5.0,10.0,10.0),0.0,"pad"],
			[Rect2(-3.0,-5.0,6.0,10.0),Y_K1,"lip"],
			[Rect2(3.0,-5.0,3.0,10.0),Y_K2,"lip"],
			[Rect2(6.0,-5.0,3.0,10.0),Y_K3,"lip"]]},
		{"name":"FOREARM END · the beam stops, the gap begins","base":3.0,"tiers":[
			[Rect2(23.0,-8.0,3.0,28.0),Y_END,"lip"]]},
		{"name":"ELBOW LEDGE (2)","base":0.0,"tiers":[
			[Rect2(23.0+3.0+GAP,-8.0,5.8,28.0),Y_ELBOW,"lip"]]},
		{"name":"CHEST · four set-offs, then the shaft floor","base":0.0,"tiers":[
			[Rect2(37.0,-8.0,3.0,28.0),Y_T1,"lip"],
			[Rect2(40.0,-8.0,3.0,28.0),Y_T2,"lip"],
			[Rect2(43.0,-8.0,3.0,28.0),Y_T3,"lip"],
			[Rect2(46.0,-8.0,3.0,28.0),Y_T4,"lip"],
			[Rect2(49.0,-1.4,4.0,2.8),Y_T4,"grey"]]},
		{"name":"SHOULDER DECK (3) = the lap · rim (4) out south-east (orange)","base":0.0,"tiers":[
			[Rect2(49.0,-14.0,43.0,12.6),Y_DECK,"grey"],
			[Rect2(49.0,1.4,43.0,11.6),Y_DECK,"grey"],
			[Rect2(53.0,-1.4,39.0,2.8),Y_DECK,"grey"],
			[Rect2(49.0,13.0,27.0,1.0),Y_DECK,"grey"],
			[Rect2(76.0,13.0,16.0,1.0),Y_DECK,"lip"]]},
		{"name":"BROKEN STAIR round the neck (slow way)","base":0.0,"tiers":[
			[Rect2(50.0,-14.0,2.0,4.0),Y_DECK+SO,"lip"],
			[Rect2(52.0,-14.0,2.0,4.0),Y_DECK+SO*2.0,"lip"],
			[Rect2(54.0,-14.0,2.0,4.0),Y_DECK+SO*3.0,"lip"],
			[Rect2(56.0,-14.0,2.0,4.0),Y_DECK+SO*4.0,"lip"],
			[Rect2(58.0,-14.0,2.0,4.0),Y_DECK+SO*5.0,"lip"]]},
		{"name":"NECK STUMP (summit) · chimney fins","base":0.0,"tiers":[
			[Rect2(60.0,-14.0,16.0,10.0),Y_NECK,"grey"],
			[Rect2(65.0,-4.0,1.0,4.0),Y_NECK,"grey"],
			[Rect2(68.2,-4.0,1.0,4.0),Y_NECK,"grey"]]},
		{"name":"cover: chest niche (stone, blocks a mouth)","base":0.0,"tiers":[
			[Rect2(60.5,-4.0,3.0,1.6),Y_DECK+2.6,"grey"]]},
		{"name":"THE KNEE · head 2's blast lands you here; the way on leaves its far (south) edge","base":0.0,"tiers":[
			[Rect2(72.0,16.0,24.0,18.0),Y_DECK-2.0,"pad"]]},
		{"name":"P thumb perch","base":0.0,"tiers":[
			[Rect2(42.0,22.0,6.0,4.0),11.0,"pad"]]},
	],
	"cyls":[
		[Vector2(68.0,-9.0),3.4,Y_NECK,Y_NECK+0.12,"pad"],
		[Vector2(50.8,10.0),0.9,0.0,Y_DECK+4.5,"grey"],
		[Vector2(57.0,4.0),0.9,0.0,Y_DECK+4.5,"grey"],
		[Vector2(63.0,12.5),0.9,0.0,Y_DECK+4.5,"grey"],
		[Vector2(68.0,3.5),0.9,0.0,Y_DECK+4.5,"grey"],
	],
	"oboxes":[
		[Vector3(68.0,Y_NECK+0.6,-9.0),Vector3(1.4,1.2,1.0),0.0,"lip"],
		[Vector3(24.5,(Y_END+Y_ANCHOR+0.4)*0.5,-2.4),Vector3(0.8,Y_ANCHOR+0.4-Y_END,0.8),0.0,"dark"],
		[Vector3(34.0,(Y_ELBOW+Y_ANCHOR+0.4)*0.5,-2.4),Vector3(0.8,Y_ANCHOR+0.4-Y_ELBOW,0.8),0.0,"dark"],
		[Vector3(29.25,Y_ANCHOR+0.2,-2.4),Vector3(10.2,0.4,0.8),0.0,"dark"],
		[Vector3(27.0,Y_ANCHOR+0.2,-1.2),Vector3(0.6,0.4,2.8),0.0,"dark"],
	],
	"ramps":[
		[Vector3(9.0,Y_K3,0.0),Vector3(23.0,Y_END,0.0),5.0,"grey"],
	],
	"ropes":[
		{"anchor":Vector3(27.0,Y_ANCHOR,0.0),"length":ROPE},
	],
	"traps":[
		{"kind":"updraft","rect":Rect2(66.0,-4.0,2.2,4.0),"bottom":Y_DECK,"top":Y_NECK},
	],
	"enemies":[
		{"id":"head1","at":Vector3(66.0,Y_DECK,8.0),"face":Vector2(-1.0,0.0),
			"knobs":{"route":[Vector3(64.5,0.0,8.0),Vector3(68.0,0.0,8.0)]}},
		{"id":"head2","at":Vector3(86.0,Y_DECK,1.0),"face":Vector2(0.0,1.0),
			"knobs":{"route":[Vector3(86.0,0.0,1.0)]}},
	],
	"labels":[
		[Vector3(-8.0,2.2,-5.0),"1 · FINGERTIPS · landing rim, the drop is behind you"],
		[Vector3(4.5,Y_K3+2.0,-5.0),"KNUCKLES: jump (1.7), PUMP (2.2), jump (1.6)"],
		[Vector3(16.0,8.8,-3.5),"FOREARM: walk the beam"],
		[Vector3(27.0,Y_ANCHOR+1.6,0.0),"STAND-IN: root cable = plain swing rope on a dark gantry (gap 5.2, 1.6 down)"],
		[Vector3(40.0,Y_T4+2.5,-5.0),"CHEST: four set-offs"],
		[Vector3(51.0,Y_DECK+2.0,0.0),"KICK SHAFT 2.8 wide, 6 tall"],
		[Vector3(60.0,Y_DECK+7.0,5.0),"SHOULDER DECK = THE LAP · two real (ground-bound) inhaler heads"],
		[Vector3(55.0,Y_DECK+3.0,-14.0),"BROKEN STAIR (slow way to the neck)"],
		[Vector3(67.1,Y_DECK+5.0,-2.0),"CHIMNEY 2.2 wide (wall-kick) / STAND-IN updraft: stand still in it"],
		[Vector3(68.0,Y_NECK+2.8,-9.0),"NECK STUMP · tomb chest (reward)"],
		[Vector3(84.0,Y_DECK+2.4,13.5),"RIM (4): head 2 blasts you out over it, onto the knee"],
		[Vector3(86.0,Y_DECK+5.0,1.0),"HEAD 2 · sits still, facing south over head 1's landing"],
		[Vector3(45.0,12.6,24.0),"P THUMB PERCH (a fall-out catch)"],
		[Vector3(46.0,Y_T4+7.0,-6.0),"CHAIN 1 (accident): head 1 gulps you on the lap, blasts you back DOWN onto the elbow ledge (2) or the chest steps"],
		[Vector3(64.0,Y_DECK+9.0,8.0),"CHAIN 2: stand east of head 1, hold still: gulped, blasted east into head 2's sight, hold still again: out over rim (4)"],
		[Vector3(67.0,Y_NECK+5.0,-2.0),"CHAIN 3: chimney updraft to the summit"],
	],
}

func slug() -> String:
	return "sunken_giant"

## The landmark of its neighbourhood (one a neighbourhood, never the greed isle).
func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Sunken Giant"

func epithet() -> String:
	return "He knelt to be buried and the oak took the rest."

func brief() -> String:
	return "Climb him: knuckles (jump, pump), the forearm, the rope gap, the chest, the kick shaft.\nOn the lap, let the heads pass you: stand east of head 1 and hold still, get eaten twice, ride out onto the knee."

func start() -> Vector3:
	return Vector3(-11.5,0.0,0.0)

func parts() -> Array:
	var out: Array = []
	for mass: Dictionary in LAYOUT.masses:
		for t: Array in mass.tiers: out.append(["box",t[0],mass.base,t[1],t[2]])
		var r: Rect2 = mass.tiers[0][0]
		out.append(["label",Vector3(r.get_center().x,float(mass.tiers[0][1])+0.9,r.position.y-0.6),mass.name])
	for c: Array in LAYOUT.cyls: out.append(["cyl",c[0],c[1],c[2],c[3],c[4]])
	for o: Array in LAYOUT.oboxes: out.append(["obox",o[0],o[1],o[2],o[3]])
	for ramp: Array in LAYOUT.ramps: out.append(["ramp",ramp[0],ramp[1],ramp[2],ramp[3]])
	for l: Array in LAYOUT.labels: out.append(["label",l[0],l[1]])
	return out

## In at the fingertips (the drop behind you), out off the knee's far edge
## (where head 2's blast lands you).
func rims() -> Array:
	return [
		{"name":"fingertips","at":Vector3(-12.0,0.0,0.0),"face":Vector3(-1.0,0.0,0.0),"run_up":8.5,"lip":1.0},
		{"name":"knee","at":Vector3(84.0,Y_DECK-2.0,33.0),"face":Vector3(0.0,0.0,1.0),"run_up":15.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"lap","at":Vector3(70.0,Y_DECK,8.0),"room":6.0},
		{"kind":"cover","name":"chest_niche","at":Vector3(62.0,Y_DECK,-2.6),"room":1.4},
		{"kind":"cover","name":"lap_column","at":Vector3(57.0,Y_DECK,2.6),"room":1.0},
		{"kind":"perch","name":"thumb","at":Vector3(45.0,11.0,24.0),"room":2.0},
		{"kind":"perch","name":"neck","at":Vector3(68.0,Y_NECK,-9.0),"room":3.4},
	]

func heads() -> Array:
	var out: Array = []
	for e: Dictionary in LAYOUT.enemies: out.append({"name":e.id,"at":e.at,"face":e.face,"knobs":e.knobs})
	return out

## The root cable (a plain swing rope) and the chimney's stand-in updraft,
## the study's own trap class (on turf its blue box faded to a breath).
func live(g: Node) -> void:
	for r: Dictionary in LAYOUT.ropes: g.rope(g.w(r.anchor),float(r.length))
	var study: GDScript = load(study_path())
	for t: Dictionary in LAYOUT.traps:
		var v: Node3D = study.Updraft.new()
		v.rect = g.wr(t.rect)
		v.bottom = float(t.bottom)+float(g.offset.y)
		v.top = float(t.top)+float(g.offset.y)
		g.trap(v)
		if not grey():
			for mesh: Node in v.find_children("*","MeshInstance3D",true,false):
				var mat := (mesh as MeshInstance3D).material_override as StandardMaterial3D
				if mat != null: mat.albedo_color = Color(0.8,0.9,1.0,0.06)

# --- Turf pass: the land and the stone --------------------------------------------------

const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")

const TURF_SEED := 4100
## The chest: the carved breastplate between the set-offs and the deck, its
## west face the greybox deck's (x 49), the kick shaft cut through it
## (|z| < SHAFT, to x CHEST_E), its east end a block to SHAFT_END. The
## terrain under it steps up to the deck at STEP (inside the stone), and
## round the shaft's end (|z| < HOLE, to x HOLE_END), so the kit's leaning
## cliff faces stay hidden in the stone and the shaft's walls are the
## stone's own, plumb, at the greybox's 2.8 m.
const CHEST_W := 49.0
const CHEST_E := 53.0
const SHAFT := 1.4
const SHAFT_END := 54.4
const STEP := 52.0
const HOLE := 2.6
const HOLE_END := 54.0
## The islands' keels (m under their datum).
const HAND_DEPTH := 7.0
const TORSO_DEPTH := 14.0
const KNEE_DEPTH := 12.0
## How far a keel's spurs can hang under top-depth (KitLand ring_sides:
## the last ring 0.92 deep x 1.15, a spur 0.3 more), for the occupancy.
const KEEL_REACH := 1.4
## The forearm beam's thickness under its walked top (m).
const FOREARM_THICK := 2.6
## The thumb's foot (m; the greybox's stood on 0).
const THUMB_FOOT := 8.0

static func grey() -> bool:
	return preload("res://scripts/launch_args.gd").user_args().has("--giant-grey")

## The hand's ground: the fingertip pad, flat at 0 (the knuckles stand on it).
static func hand_outline() -> Array:
	return _rounded(Rect2(-13.0,-5.6,23.0,11.2),1.6)

## The torso's ground (its frame's x, z): the elbow ledge, the chest's four
## set-offs, the floor behind the chest stone, the shoulder deck.
static func torso_ground(x: float, z: float) -> float:
	if x < 37.0: return Y_ELBOW
	if x < 40.0: return Y_T1
	if x < 43.0: return Y_T2
	if x < 46.0: return Y_T3
	if x < STEP: return Y_T4
	if x < HOLE_END and absf(z) < HOLE: return Y_T4
	return Y_DECK

## The elbow ledge and the set-offs (x 31.2-49, z -8 to 20), the chest and
## the deck (x 49-92, z -14 to 14).
static func torso_outline() -> Array:
	return [Vector2(31.2,-8.0),Vector2(CHEST_W,-8.0),Vector2(CHEST_W,-14.0),Vector2(92.0,-14.0),
		Vector2(92.0,14.0),Vector2(CHEST_W,14.0),Vector2(CHEST_W,20.0),Vector2(31.2,20.0)]

## The knee: head 2's catch (x 72-96, z 16-34), flat 2 m under the deck.
static func knee_outline() -> Array:
	return _rounded(Rect2(72.0,16.0,24.0,18.0),2.0)

## A rect's outline with its corners cut `cut` m.
static func _rounded(r: Rect2, cut: float) -> Array:
	var a := r.position
	var b := r.end
	return [Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),
		Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)]

## The worn ways: the pad to the knuckles, across the elbow ledge, the deck
## from the shaft's mouth past the heads.
static func paths() -> Array:
	return [[Vector2(-12.5,0.0),Vector2(-3.5,0.0)],[Vector2(31.8,0.0),Vector2(36.6,0.0)],
		[Vector2(55.0,0.0),Vector2(62.0,6.0),Vector2(72.0,8.0),Vector2(84.0,6.0)]]

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return TURF_SEED+9

## The kit isles' life at its defaults (undergrowth, butterflies, fireflies,
## the wind's loose bits; no birds or tokens of its own).
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

## The greybox's solids and the keels under the three islands (their
## spurs' reach), so the occupancy keeps the generator off the rock.
func _solids() -> Array:
	var out := super._solids()
	if grey(): return out
	for keel: Array in [[hand_outline(),0.0,HAND_DEPTH],[torso_outline(),Y_ELBOW,TORSO_DEPTH],[knee_outline(),Y_DECK-2.0,KNEE_DEPTH]]:
		var ring: Array = keel[0]
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		out.append([box.grow(-1.0),float(keel[1])-float(keel[2])*KEEL_REACH,float(keel[1]),null])
	# The forearm beam's underside.
	out.append([Rect2(9.0,-2.5,14.0,5.0),Y_K3-FOREARM_THICK,Y_END,null])
	return out

## Measured headless on the Windows PC (the turf build, 2026-10-13).
func build_cost() -> int:
	return 0 if grey() else 750

## Turf on the tiers, the body in stone.
func build(into: Node3D) -> void:
	if grey():
		super.build(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "SunkenGiant"
	into.add_child(root)
	var tone := KitLook.turf(TURF_SEED,KitLand.wear_of(paths()))
	var hand := KitLand.island({"outline":hand_outline(),"seed":TURF_SEED,"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":HAND_DEPTH,"hang":true,"resample":[40.0,90,32],"tone":tone})
	hand.name = "Hand"
	var torso := KitLand.island({"outline":torso_outline(),"seed":TURF_SEED+1,"ground":func(x: float, z: float) -> float: return torso_ground(x,z),
		"top":Y_ELBOW,"depth":TORSO_DEPTH,"cliffs":Rect2(30.5,-14.5,62.5,35.0),"fine":1.2,"hang":true,"resample":[60.0,220,32],"tone":tone})
	torso.name = "Torso"
	var knee := KitLand.island({"outline":knee_outline(),"seed":TURF_SEED+2,"ground":func(_x: float, _z: float) -> float: return Y_DECK-2.0,
		"top":Y_DECK-2.0,"depth":KNEE_DEPTH,"hang":true,"resample":[40.0,100,32],"tone":tone})
	knee.name = "Knee"
	for land: Node3D in [hand,torso,knee]:
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	_stone(root)
	built_ms = Time.get_ticks_msec()-began

## An island's hanging sides collided as drawn ("Sides"): KitLand draws
## them only, and the greybox's masses were solid down to their base, so
## the headless bodies climbed the giant's flanks to the heads (and a fall
## past a flank meets it). As the Stair to the Clouds' mesa collides its own.
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

## The body: drawn as one mesh of the giant's stone, collided as the
## greybox's walk boxes.
func _stone(root: Node3D) -> void:
	var m: RefCounted = GiantStone.mesher()
	var solids := Node3D.new()
	solids.name = "Walk"
	root.add_child(solids)
	# The fist: three knuckle rows, each four fingers (drawn), one box each.
	for row: Array in [[-3.0,6.0,Y_K1],[3.0,3.0,Y_K2],[6.0,3.0,Y_K3]]:
		var x0: float = row[0]
		var w: float = row[1]
		var y: float = row[2]
		_walk(solids,Rect2(x0,-5.0,w,10.0),-0.6,y)
		for k in 4:
			var z := -5.0+2.5*k+1.25
			m.box(Transform3D(Basis.IDENTITY,Vector3(x0+w*0.5,(y-0.6)*0.5,z)),Vector3(w,y+0.6,2.44),0.32,0.0)
	# The forearm: a beam whose top is the greybox ramp, thicker under it.
	var low := Vector3(9.0,Y_K3,0.0)
	var high := Vector3(23.0,Y_END,0.0)
	var along := (high-low).normalized()
	var side := Vector3.UP.cross(along).normalized()
	var up := along.cross(side).normalized()
	var beam := Transform3D(Basis(side,up,along),(low+high)*0.5-up*FOREARM_THICK*0.5)
	var beam_size := Vector3(5.0,FOREARM_THICK,low.distance_to(high)+0.02)
	_walk_shape(solids,beam,beam_size)
	m.box(beam,beam_size,0.5)
	# The elbow block (the forearm's end).
	_block(m,solids,Rect2(23.0,-8.0,3.0,28.0),3.0,Y_END,0.4)
	# The chest: two courses of slabs either side of the shaft, its east end.
	var mid := Y_T4+2.8
	for half: Rect2 in [Rect2(CHEST_W,-14.0,CHEST_E-CHEST_W,14.0-SHAFT),Rect2(CHEST_W,SHAFT,CHEST_E-CHEST_W,14.0-SHAFT)]:
		_walk(solids,half,Y_T4-0.4,Y_DECK)
		for course: Array in [[Y_T4-0.4,mid,0],[mid,Y_DECK,1]]:
			var z := half.position.y
			var k: int = course[2]
			while z < half.end.y-0.01:
				var length := minf(4.2 if k%2 == 0 else 3.6,half.end.y-z)
				var slab := Rect2(CHEST_W,z,CHEST_E-CHEST_W,length)
				m.box(_at(slab,course[0],course[1]),_size(slab,course[0],course[1]),0.3,Y_T4)
				z += length
				k += 1
	_block(m,solids,Rect2(CHEST_E,-HOLE-0.1,SHAFT_END-CHEST_E,2.0*(HOLE+0.1)),Y_T4-0.4,Y_DECK,0.25,Y_T4)
	# The broken stair round the neck.
	for k in 5: _block(m,solids,Rect2(50.0+2.0*k,-14.0,2.0,4.0),Y_DECK-0.3,Y_DECK+SO*(k+1),0.18,Y_DECK)
	# The neck stump, cut clean, a band of runes round it under the cut.
	_block(m,solids,Rect2(60.0,-14.0,16.0,10.0),Y_DECK-0.3,Y_NECK,0.5,Y_DECK)
	var band := Y_NECK-1.35
	m.runes(Vector3(60.0,band,-14.0),Vector3(76.0,band,-14.0),Vector3.UP,Vector3(0,0,-1),1.0)
	m.runes(Vector3(76.0,band,-14.0),Vector3(76.0,band,-4.0),Vector3.UP,Vector3(1,0,0),2.0)
	m.runes(Vector3(60.0,band,-4.0),Vector3(60.0,band,-14.0),Vector3.UP,Vector3(-1,0,0),3.0)
	for span: Vector2 in [Vector2(60.4,65.0),Vector2(66.0,68.2),Vector2(69.2,75.6)]:
		m.runes(Vector3(span.y,band,-4.0),Vector3(span.x,band,-4.0),Vector3.UP,Vector3(0,0,1),4.0+span.x)
	# The chimney's fins, plumb (the throat 2.2 wide), and the chest niche.
	_block(m,solids,Rect2(65.0,-4.0,1.0,4.0),Y_DECK-0.3,Y_NECK,0.1,Y_DECK)
	_block(m,solids,Rect2(68.2,-4.0,1.0,4.0),Y_DECK-0.3,Y_NECK,0.1,Y_DECK)
	_block(m,solids,Rect2(60.5,-4.0,3.0,1.6),Y_DECK-0.3,Y_DECK+2.6,0.2,Y_DECK)
	# The columns on the lap (cover), the greybox's cylinders.
	for c: Array in LAYOUT.cyls:
		var centre: Vector2 = c[0]
		var r := float(c[1])
		if r > 1.0: continue
		var y0 := Y_DECK-0.3
		var y1 := float(c[3])
		_walk_cyl(solids,centre,r,y0,y1)
		m.cylinder(Transform3D(Basis.IDENTITY,Vector3(centre.x,(y0+y1)*0.5,centre.y)),r,y1-y0,12,0.14,Y_DECK)
	# The summit's floor ring, the raw cut (paler), and the tomb chest.
	_walk_cyl(solids,Vector2(68.0,-9.0),3.4,Y_NECK-0.2,Y_NECK+0.12)
	m.cylinder(Transform3D(Basis.IDENTITY,Vector3(68.0,Y_NECK-0.04,-9.0)),3.4,0.32,24,0.06,Y_NECK-2.0,1.25)
	var chest: Node3D = RuinKit.piece("tomb_chest",TURF_SEED+20,0.3)
	chest.position = Vector3(68.0,Y_NECK+0.12,-9.0)
	root.add_child(chest)
	# The thumb (a fall-out catch).
	_block(m,solids,Rect2(42.0,22.0,6.0,4.0),THUMB_FOOT,11.0,0.4)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())
	# The root cable's gantry (stand-in: dark roots, not yet a kit piece).
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.2,0.15,0.11)
	bark.roughness = 1.0
	for o: Array in LAYOUT.oboxes:
		if o[3] != "dark": continue
		var place := Transform3D(Basis(Vector3.UP,deg_to_rad(float(o[2]))),o[0])
		_walk_shape(solids,place,o[1])
		var root_mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = o[1]
		root_mesh.mesh = bm
		root_mesh.transform = place
		root_mesh.material_override = bark
		root.add_child(root_mesh)

## A block drawn and collided (its rect x z, bottom, top).
static func _block(m: RefCounted, solids: Node3D, r: Rect2, bottom: float, high: float, bevel: float, foot := NAN) -> void:
	_walk(solids,r,bottom,high)
	m.box(_at(r,bottom,high),_size(r,bottom,high),bevel,foot)

static func _at(r: Rect2, bottom: float, high: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y))

static func _size(r: Rect2, bottom: float, high: float) -> Vector3:
	return Vector3(r.size.x,high-bottom,r.size.y)

## A walk box (the greybox's), collided only.
static func _walk(solids: Node3D, r: Rect2, bottom: float, high: float) -> void:
	_walk_shape(solids,_at(r,bottom,high),_size(r,bottom,high))

static func _walk_shape(solids: Node3D, place: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.transform = place
	var c := CollisionShape3D.new()
	c.shape = _box_shape(size)
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
