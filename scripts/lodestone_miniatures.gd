extends RefCounted
## The places a lodestone holds in miniature (scripts/lodestone.gd), built
## from the real set pieces' own code at their own size (metres), for the
## lodestone to stand on its stone at a few thousandths of it:
##   sundered  the Sundered hall (scripts/sundered_hall.gd plans it): its
##             west front, the gate piece, with the first six bays of its
##             nave (the hall's far detail, scripts/sundered_build.gd
##             `far`), torn off at the sixth; across a gap of open sky, a
##             step up, the next stretch of nave on its own shard of
##             island, torn at both ends. The torn hall across islands is
##             the place's signature.
##   aqueduct  an aqueduct of the ruin kit (scripts/ruin_kit_aqueduct.gd
##             `run`): three spans striding across the stone, the last
##             snapped in mid-air, its channel spilling a thread of water
##             to the rubble under the break; past it, on a shard of its
##             own, a pier stump standing on in the sky.
## `build(kind)` gives {node (the place, metres, its ground at y 0), top
## (the stone's top outline, PackedVector2Array, x z metres), shards
## ([{outline, at (the shard's top, metres), depth}]), threads ([{at (the
## lip, metres), fall (m)}]), centre (Vector2, x z: the place's middle),
## reach (the place's half extent across, m), haze ({heights, fringe}),
## name, triangles}. The node's meshes keep the set piece's vertex colours;
## the lodestone dresses them in its miniature material.
##
## Cost: the hall's far detail is cheap (~2k triangles a stretch); the
## aqueduct is the kit's own stone at the least growth (RuinKit
## `set_detail` 0), ~24k triangles, its arches the reason to keep it.

const Sundered = preload("res://scripts/sundered_hall.gd")
const SunderedBuild = preload("res://scripts/sundered_build.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")

const KINDS := ["sundered","aqueduct"]
const NAMES := {"sundered":"The Sundered hall","aqueduct":"The broken aqueduct"}
## The Sundered hall's seed (the plan's), the gate's bays kept, the gap of
## open sky to the next stretch (m), its bays and how far it steps up (m).
const HALL_SEED := 1
const GATE_BAYS := 6
const HALL_GAP := 16.0
const NEXT_BAYS := 4
const NEXT_STEP := 6.0
## The aqueduct's seed, spans, the broken one, its weathering.
const AQ_SEED := 3
const AQ_SPANS := 3
const AQ_BREAK := 2
const AQ_WEATHERED := 0.35

static func build(kind: String) -> Dictionary:
	match kind:
		"aqueduct": return _aqueduct()
	return _sundered()

static func _sundered() -> Dictionary:
	var plan: Dictionary = Sundered.layout(HALL_SEED,0.0)
	var root := Node3D.new()
	root.name = "SunderedMini"
	var gate: Dictionary = _sliced(plan.pieces[0],GATE_BAYS)
	var gate_node := MeshInstance3D.new()
	gate_node.name = "Gate"
	gate_node.mesh = SunderedBuild.far(gate)
	root.add_child(gate_node)
	var gate_length: float = gate.length
	var next: Dictionary = _sliced(plan.pieces[1],NEXT_BAYS,true)
	var next_node := MeshInstance3D.new()
	next_node.name = "Next"
	next_node.mesh = SunderedBuild.far(next)
	# Turned as the plan turns it from the gate, stood across the gap and a
	# step up.
	var turn: Basis = (plan.pieces[1].frame as Transform3D).basis
	next_node.transform = Transform3D(turn,Vector3(gate_length+HALL_GAP,NEXT_STEP,(plan.pieces[1].frame as Transform3D).origin.z*0.3))
	root.add_child(next_node)
	var half := SunderedBuild.BED_HALF+2.5
	var top := _oblong(Vector2(-Sundered.FORECOURT-3.0,gate_length+2.0),half,HALL_SEED)
	var next_length: float = next.length
	var shard_outline := _oblong(Vector2(-2.0,next_length+2.0),half*0.92,HALL_SEED+5)
	var shard_middle := next_node.transform*Vector3(0.0,0.0,0.0)
	var shards := [{"outline":shard_outline,"transform":Transform3D(turn,shard_middle),"depth":34.0,"seed":HALL_SEED+5}]
	var left := -Sundered.FORECOURT-3.0
	var right := (next_node.transform*Vector3(next_length+2.0,0.0,0.0)).x
	return {"node":root,"top":top,"shards":shards,"threads":[],"centre":Vector2((left+right)*0.5,0.0),
		"reach":(right-left)*0.5,"height":Hall.ROOF_TOP+Hall.GABLE_RISE+NEXT_STEP,
		"haze":{"heights":Vector2(-4.0,7.0),"fringe":Vector2((right-left)*0.42,(right-left)*0.62)},
		"name":NAMES.sundered,"triangles":_triangles(root)}

## A piece of the plan cut to its first `bays` bays, torn at its far end
## (and at its near end too if `torn_start`).
static func _sliced(piece: Dictionary, bays: int, torn_start := false) -> Dictionary:
	var out := piece.duplicate()
	var plans: Array = []
	for i in range(mini(bays,(piece.plans as Array).size())):
		plans.append((piece.plans[i] as Dictionary).duplicate())
	var last: Dictionary = plans[plans.size()-1]
	last.torn = int(last.get("torn",0)) | 2
	if torn_start: plans[0].torn = int(plans[0].get("torn",0)) | 1
	out.plans = plans
	out.length = Hall.BAY*plans.size()
	out.last = false
	return out

static func _aqueduct() -> Dictionary:
	RuinKit.set_detail(0.0)
	var run: Node3D = Aqueduct.run(AQ_SEED,AQ_WEATHERED,AQ_SPANS,AQ_BREAK,false)
	RuinKit.set_detail(1.0)
	RuinKit.forget_arrays(run)
	run.name = "AqueductMini"
	var body := run.get_node_or_null("Body")
	if body != null: body.free()
	# The kit's own spill and pool are drawn for the world's scale; the
	# miniature has its own thread.
	var lip := Vector3.INF
	for child in run.get_children():
		for name: String in ["Spill","Pool"]:
			var n := child.get_node_or_null(name)
			if n != null: n.free()
		if child.has_meta("walk") and child.name.begins_with("AqueductBroken"):
			var walk: Dictionary = (child.get_meta("walk") as Array)[0]
			lip = (child as Node3D).transform*(walk.to as Vector3)+Vector3(0.05,Aqueduct.WATER-0.05,0.0)
	var stump: Node3D = Aqueduct.stump(AQ_SEED+40,0.5)
	stump.name = "Stump"
	var stump_body := stump.get_node_or_null("Body")
	if stump_body != null: stump_body.free()
	var length: float = Aqueduct.SPAN*AQ_SPANS
	var stump_at := Vector3(length+6.5,-3.0,1.2)
	stump.position = stump_at
	run.add_child(stump)
	var top := _oblong(Vector2(-4.5,length+0.5),6.2,AQ_SEED)
	var shards := [{"outline":_oblong(Vector2(-3.2,3.2),3.0,AQ_SEED+9),"transform":Transform3D(Basis.IDENTITY,stump_at),"depth":9.0,"seed":AQ_SEED+9}]
	var threads := []
	if lip.is_finite(): threads.append({"at":lip,"fall":lip.y-0.2})
	var left := -4.5
	var right := stump_at.x+3.2
	return {"node":run,"top":top,"shards":shards,"threads":threads,"centre":Vector2((left+right)*0.5,0.0),
		"reach":(right-left)*0.5,"height":Aqueduct.DECK+1.0,
		"haze":{"heights":Vector2(-1.5,3.5),"fringe":Vector2((right-left)*0.45,(right-left)*0.65)},
		"name":NAMES.aqueduct,"triangles":_triangles(run)}

## An oblong outline from x `span.x` to `span.y`, `half` across, its ends
## rounded and its edge a little ragged (x z, metres).
static func _oblong(span: Vector2, half: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"lodestone top"])
	var out := PackedVector2Array()
	var middle := (span.x+span.y)*0.5
	var long := (span.y-span.x)*0.5
	var count := 16
	for k in range(count):
		var a := TAU*k/count+rng.randf_range(-0.08,0.08)
		var c := cos(a)
		var s := sin(a)
		# A squared ellipse: full along its sides, rounded at its ends.
		var r := pow(pow(absf(c),3.0)+pow(absf(s),3.0),-1.0/3.0)*rng.randf_range(0.9,1.04)
		out.append(Vector2(middle+c*long*r,s*half*r))
	return out

static func _triangles(root: Node) -> int:
	var count := 0
	for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		for s in range(node.mesh.get_surface_count()):
			var indices: int = node.mesh.surface_get_array_index_len(s)
			count += (indices if indices > 0 else node.mesh.surface_get_array_len(s))/3
	return count
