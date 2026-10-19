extends RefCounted
## The haul home's stretch (docs/design/carry/spec-carry.md, task 7): the
## flight out west from the wreck cluster's strip, about 700 m (some 40 s at
## the game's cruise), through open sky with things to hit. The plane leaves
## the strip's west rim (x 20) heading -x along z ~12 and the stretch runs,
## east to west:
##   rocks_a    a field of floating rocks, one on the line to dodge
##   gate_a     two rock spires, a gap of opening(GATE_A_TOY) between them
##   islet_a    over land: a low islet under the line, a clear landing run
##              along it, a few ruins on its rims (off the run)
##   span_a     a broken aqueduct (three spans, the last snapped, its water
##              spilling) standing across the line on rock roots: thread
##              its middle arch (the kit's CLEAR, an opening on 4.7)
##   debris     drifting chunks over open sky: rocks and broken masonry
##              bobbing, sliding and turning slowly
##   span_b     one broken span adrift among them, its arch on the line
##   islet_b    over land again: a second low islet and its landing run
##   gate_e     a rock arch: two spires and a lintel rock, opening(GATE_E_TOY)
##   rocks_e    a last few rocks, then open sky
## Every piece is named `wreck_cluster/stretch/<piece>` for the world view
## (studies/wreck_cluster.gd `_place_piece`); the islets are world-view
## islands (`island/stretch_islet_a`, `island/stretch_islet_b`). The rocks
## and spans are stone the plane bumps off (layer 1), no turf: nothing to
## land on but the islets, each with a clear run long enough to land by hand.
## Built in the wreck cluster study unless --no-stretch.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The line the stretch is laid round (world): the strip's west rim, then
## each stage's middle. Drivers fly it; the pieces are laid off it.
const LINE := [Vector3(20.0,34.0,15.0),Vector3(-45.0,37.0,12.0),Vector3(-105.0,37.0,12.0),
	Vector3(-200.0,32.0,11.0),Vector3(-290.0,33.0,12.0),Vector3(-380.0,34.0,12.0),
	Vector3(-430.0,34.0,12.0),Vector3(-545.0,34.0,16.0),Vector3(-640.0,35.0,16.0),Vector3(-700.0,36.0,16.0)]

## The gaps' toy widths (scripts/world_scale.gd `opening`): 10 m and 8 m at
## the defaults (the plane spans 2.8).
const GATE_A_TOY := 5.0
const GATE_E_TOY := 4.0
## The most a boulder's rim stands past its radius (its jitter), so a gap
## sized from the radii stays at least its opening.
const JUT := 1.12

## The islets: tops well under the line (it runs 12-14 m over them), each
## with a clear run along its length: islet_a about 115 m along z 11
## (x -258..-143), islet_b about 100 m along z 16 (x -597..-497). Their
## ruins stand on the rims, clear of the run (RUN_HALF either side).
const ISLET_A_TOP := 20.0
const ISLET_B_TOP := 22.0
const RUN_HALF := 6.0

static func islet_a_outline() -> Array:
	return [Vector2(-266.0,12.0),Vector2(-262.0,3.0),Vector2(-248.0,-1.5),Vector2(-225.0,-3.5),Vector2(-195.0,-4.5),
		Vector2(-168.0,-2.5),Vector2(-148.0,0.5),Vector2(-136.0,5.0),Vector2(-133.0,12.0),Vector2(-137.0,19.5),
		Vector2(-150.0,24.0),Vector2(-175.0,27.5),Vector2(-205.0,28.0),Vector2(-232.0,26.0),Vector2(-252.0,23.0),
		Vector2(-263.0,19.0)]

static func islet_b_outline() -> Array:
	return [Vector2(-604.0,16.0),Vector2(-600.0,7.0),Vector2(-585.0,3.0),Vector2(-560.0,1.5),Vector2(-530.0,2.5),
		Vector2(-505.0,5.0),Vector2(-492.0,10.0),Vector2(-489.0,17.0),Vector2(-494.0,25.0),Vector2(-510.0,30.5),
		Vector2(-540.0,32.0),Vector2(-570.0,31.0),Vector2(-592.0,27.0),Vector2(-602.0,22.0)]

## The islets as rows of the cluster's lands (studies/wreck_cluster_art.gd
## `lands`: name, outline, ground, depth, seed, cliffs, rim).
static func lands() -> Array:
	return [
		["stretch_islet_a",islet_a_outline(),func(_x: float, _z: float) -> float: return ISLET_A_TOP,30.0,461,Rect2(),ISLET_A_TOP],
		["stretch_islet_b",islet_b_outline(),func(_x: float, _z: float) -> float: return ISLET_B_TOP,26.0,463,Rect2(),ISLET_B_TOP],
	]

## The rock each islet hangs under its rim (studies/wreck_cluster_art.gd
## `hangs`): a blade under islet_a's run with three fangs, a shorter
## leaning keel under islet_b.
static func hangs() -> Dictionary:
	return {
		"stretch_islet_a":{"rings":[[4.0,0.93],[10.0,0.8],[17.0,0.62],[22.0,0.48]],"fangs":[30.0,36.0,26.0],"spread":0.5},
		"stretch_islet_b":{"rings":[[4.0,0.92],[9.0,0.78],[15.0,0.58]],"fangs":[26.0,21.0],"spread":0.45,"lean":Vector2(3.0,-2.0)},
	}

## Islet `spec` (a row of `lands`) built as the cluster builds its lands
## (Art `build_land`), hanging its own rock (`hangs`), its sides collided
## as drawn.
static func build_land(spec: Array) -> Node3D:
	var Art: GDScript = load("res://studies/wreck_cluster_art.gd")
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"sides":false,"name":"wreck_cluster/stretch/"+str(spec[0]).trim_prefix("stretch_")}
	var node := KitLand.island(d)
	node.name = "Land_"+str(spec[0]).to_pascal_case()
	var hang: Dictionary = hangs()[str(spec[0])]
	var rings: Array = Art.hang_rings(d,hang)
	var drawn: MeshInstance3D = Art.hang_rock(rings,hang,int(spec[4])).node("Mesh")
	node.add_child(drawn)
	KitLand.collide_sides(node,drawn,true)
	return node

## The pieces: [layout name (under wreck_cluster/), node, world foot, yaw
## (deg)], for the study's `_place_piece`.
static func built() -> Array:
	var out: Array = []
	# rocks_a: [x, y, z, radius], one (rock_03) on the line.
	var rocks_a := [[-12.0,46.0,0.0,5.0],[-28.0,29.0,32.0,6.0],[-44.0,37.0,13.0,3.2],[-56.0,49.0,27.0,4.0],
		[-63.0,27.0,-6.0,5.0],[-76.0,42.0,3.0,2.6],[-86.0,31.0,31.0,4.5]]
	for i in range(rocks_a.size()):
		var r: Array = rocks_a[i]
		out.append(["stretch/rock_a%02d" % (i+1),boulder(471+i,Vector3(r[3],r[3]*0.8,r[3]*0.9)),Vector3(r[0],r[1],r[2]),float(i*47%360)])
	# gate_a: two spires either side of z 12.
	out.append(["stretch/gate_a",gate(481,WorldScale.opening(GATE_A_TOY),false),Vector3(-105.0,37.0,12.0),0.0])
	# islet_a's ruins, on its rims.
	out.append(["stretch/islet_a_pier",RuinKit.piece("pier",483,0.4),Vector3(-232.0,ISLET_A_TOP,-0.5),20.0])
	out.append(["stretch/islet_a_fallen",RuinKit.piece("fallen_pier",484,0.4),Vector3(-190.0,ISLET_A_TOP,0.5),80.0])
	out.append(["stretch/islet_a_wall",RuinKit.piece("lancet_wall",485,0.45),Vector3(-178.0,ISLET_A_TOP,24.0),180.0])
	# span_a: a run of three across the line at x -290, its middle arch
	# centred on z 12 (the run along local +x turned to world -z).
	var run := Aqueduct.run(487,0.35,3,2,false)
	out.append(["stretch/span_a",rooted(run,489),Vector3(-290.0,27.0,12.0+Aqueduct.SPAN*1.5),90.0])
	# debris: [x, y, z, radius, masonry?]
	var bits := [[-318.0,37.0,6.0,1.6,false],[-332.0,31.0,20.0,2.2,false],[-347.0,40.0,14.0,1.2,true],
		[-360.0,34.0,2.0,2.6,false],[-372.0,29.0,17.0,1.4,true],[-388.0,38.0,9.0,1.8,false],
		[-401.0,33.0,25.0,2.0,false],[-414.0,41.0,4.0,1.3,true],[-452.0,36.0,18.0,2.4,false],
		[-466.0,30.0,8.0,1.5,true],[-476.0,42.0,22.0,1.9,false]]
	for i in range(bits.size()):
		var b: Array = bits[i]
		var body: Node3D = block(501+i,float(b[3])) if bool(b[4]) else boulder(501+i,Vector3(b[3],b[3]*0.75,b[3]*0.85))
		out.append(["stretch/debris_%02d" % (i+1),Drift.make(body,511+i),Vector3(b[0],b[1],b[2]),float(i*61%360)])
	# span_b: one broken span adrift, its arch on the line.
	var lone: Node3D = RuinKit.piece("aqueduct_broken",521,0.45)
	out.append(["stretch/span_b",rooted(lone,523),Vector3(-430.0,27.0,12.0),90.0])
	# islet_b's ruins.
	out.append(["stretch/islet_b_arch",RuinKit.piece("arch",531,0.35),Vector3(-560.0,ISLET_B_TOP,28.5),0.0])
	out.append(["stretch/islet_b_buttress",RuinKit.piece("buttress",532,0.4),Vector3(-528.0,ISLET_B_TOP,5.0),180.0])
	out.append(["stretch/islet_b_chest",RuinKit.piece("tomb_chest",533,0.4),Vector3(-583.0,ISLET_B_TOP,6.0),15.0])
	# gate_e: the rock arch.
	out.append(["stretch/gate_e",gate(541,WorldScale.opening(GATE_E_TOY),true),Vector3(-640.0,35.0,16.0),0.0])
	var rocks_e := [[-662.0,44.0,2.0,4.0],[-676.0,28.0,30.0,5.0],[-694.0,38.0,12.0,2.8]]
	for i in range(rocks_e.size()):
		var r: Array = rocks_e[i]
		out.append(["stretch/rock_e%02d" % (i+1),boulder(551+i,Vector3(r[3],r[3]*0.8,r[3]*0.9)),Vector3(r[0],r[1],r[2]),float(i*83%360)])
	return out

# --- Pieces ---------------------------------------------------------------------

## A floating rock: a lumpy, faceted stone `radii` (x, y, z) about its
## middle, its underside drawn down KEEL times as deep into a hanging point,
## its top banded like the isles' turf edge; one convex body (layer 1, the
## plane bumps off it; the walker stands on it).
const KEEL := 1.7
static func boulder(seed_value: int, radii: Vector3, keel := KEEL) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings := 8
	var around := 11
	var lean := Vector2(rng.randf_range(-0.25,0.25),rng.randf_range(-0.25,0.25))*radii.x
	var pts: Array = []
	var top_y := radii.y*0.62
	for k in range(1,rings):
		var t := float(k)/rings*PI
		var y := cos(t)*radii.y
		if y > 0.0: y *= 0.62
		else: y *= keel
		var ring: Array = []
		var shift := lean*maxf(-cos(t),0.0)
		for j in range(around):
			var a := (float(j)+rng.randf_range(-0.2,0.2))/around*TAU
			var s := sin(t)*rng.randf_range(0.86,JUT)
			ring.append(Vector3(cos(a)*radii.x*s+shift.x,y+rng.randf_range(-0.08,0.08)*radii.y,sin(a)*radii.z*s+shift.y))
		pts.append(ring)
	var top := Vector3(rng.randf_range(-0.1,0.1)*radii.x,top_y,0.0)
	var bottom := Vector3(lean.x,-radii.y*keel,lean.y)
	var rock := KitLook.RockMesh.new()
	var mid := Vector3(0.0,0.0,0.0)
	var face := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var centre := (a+b+c)/3.0
		rock.add([a,b,c],top_y,centre-Vector3(mid.x,clampf(centre.y,-radii.y,radii.y*0.3),mid.z),rng.randf_range(0.85,1.15))
	for j in range(around):
		var r0: Array = pts[0]
		face.call(top,r0[j],r0[(j+1)%around])
		var rl: Array = pts[pts.size()-1]
		face.call(bottom,rl[(j+1)%around],rl[j])
	for k in range(pts.size()-1):
		var a: Array = pts[k]
		var b: Array = pts[k+1]
		for j in range(around):
			var n := (j+1)%around
			face.call(a[j],b[j],b[n])
			face.call(a[j],b[n],a[n])
	var body := StaticBody3D.new()
	body.name = "Rock"
	body.collision_layer = 1
	body.add_child(rock.node("Mesh"))
	var hull := PackedVector3Array([top,bottom])
	for ring: Array in pts:
		for p: Vector3 in ring: hull.append(p)
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = hull
	shape.shape = convex
	body.add_child(shape)
	return body

## A broken block of masonry, `size` its rough half extent: a dressed stone
## tumbled loose (a kit fallen pier's drum, cut short), for the debris.
static func block(seed_value: int, size: float) -> Node3D:
	var node: Node3D = RuinKit.piece("fallen_pier",seed_value,0.6)
	var box := AABB()
	var mesh := node.find_children("*","MeshInstance3D",true,false)
	if not mesh.is_empty(): box = (mesh[0] as MeshInstance3D).get_aabb()
	var holder := Node3D.new()
	holder.name = "Masonry"
	var reach := maxf(box.get_longest_axis_size(),0.1)
	holder.scale = Vector3.ONE*clampf(size*2.6/reach,0.15,1.0)
	node.position = -box.get_center()
	holder.add_child(node)
	return holder

## Two rock spires either side of the piece's middle along z, `opening` m
## clear between their nearest rims at any height; with `lintel` a long
## rock laid across their heads, so it reads as an arch.
static func gate(seed_value: int, opening: float, lintel: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Gate"
	var r := 4.0
	var tall := 11.0
	# Past each rim's jitter and its keel's lean (a quarter radius).
	var off := opening*0.5+r*(JUT+0.25)+0.3
	for side: float in [-1.0,1.0]:
		var spire := boulder(seed_value+int(side+1.0),Vector3(r,tall,r),1.25)
		spire.position = Vector3(0.0,0.0,side*off)
		root.add_child(spire)
	if lintel:
		var cap := boulder(seed_value+5,Vector3(3.2,2.6,off+r*0.8),1.0)
		cap.position = Vector3(0.0,tall*0.62+1.4,0.0)
		root.add_child(cap)
	return root

## An aqueduct piece or run standing on rock: a floating rock under each
## pier's foot (its meta "feet"), so the spans read as hung in the sky.
static func rooted(piece: Node3D, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Span"
	root.add_child(piece)
	var feet: Array = piece.get_meta("feet",[])
	for i in range(feet.size()):
		var f: Vector3 = feet[i]
		var stone := boulder(seed_value+i,Vector3(2.6,2.2,3.2),2.4)
		stone.position = f+Vector3(0.0,-0.4,0.0)
		root.add_child(stone)
	return root

## A drifting piece: its child bobs, slides and turns slowly about where it
## was placed (the node the world view moves stays put).
class Drift extends Node3D:
	var bob := 1.5
	var slide := 3.0
	var period := 8.0
	var spin := 0.1
	var phase := 0.0
	var _t := 0.0
	var _held: Node3D

	static func make(body: Node3D, seed_value: int) -> Node3D:
		var d := Drift.new()
		d.name = "Drift"
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		d.bob = rng.randf_range(0.8,2.2)
		d.slide = rng.randf_range(1.5,4.0)
		d.period = rng.randf_range(7.0,12.0)
		d.spin = rng.randf_range(-0.18,0.18)
		d.phase = rng.randf()*TAU
		d._held = body
		d.add_child(body)
		return d

	func _physics_process(delta: float) -> void:
		_t += delta
		var w := TAU/period
		_held.position = Vector3(sin(_t*w*0.5+phase)*slide*0.4,sin(_t*w+phase)*bob,cos(_t*w*0.5+phase)*slide)
		_held.rotation = Vector3(sin(_t*w*0.3)*0.15,_t*spin,cos(_t*w*0.4)*0.1)
