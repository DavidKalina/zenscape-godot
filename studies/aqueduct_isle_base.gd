extends RefCounted
## The aqueduct isle's art as one build (studies/aqueduct_isle.gd `_build_art`,
## docs/design/roguelike/loading-screen-round2.md): its islands, aqueduct,
## castellum, hill, stairs, stone circle, floating stones, islets, heel stone,
## pieces and stumps built into a node, touching nothing else, the collision
## parts and the nodes the scene keeps handed back in fields. So the isle store
## (scripts/roguelike/isle_store.gd) can keep it as it keeps a motif isle (a
## helper builds it once, the game loads it), and the scene applies the parts
## and fields as it did. The same calls in the same order as before.
const Art = preload("res://studies/aqueduct_isle_art.gd")
## (The scene's script, for its seeds and lists: loaded, not preloaded, as
## it preloads this.)
static var Isle: GDScript:
	get: return load("res://studies/aqueduct_isle.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## What the build hands back.
var art: Node3D
var near: Node3D
var far: Node3D
var islets: Array = []
var stair: Node3D
var kit_stairs: Node3D
var circle: Node3D
## The collision parts, in the order the scene stood them: the aqueduct's,
## the castellum's, the stumps'.
var parts: Array = []
## (The isle store's recipe: one isle, no seed, no knobs.)
var isle_seed := -1
var knobs := {}
var built_ms := 0

func id() -> String:
	return "aqueduct_base"

func family() -> bool:
	return false

func sockets() -> Array:
	return []

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	RuinKit.materials()

func build(into: Node3D) -> void:
	var began := Time.get_ticks_msec()
	art = into
	near = Art.island(Art.NEAR,30.0,Isle.SEED,Art.ground,Art.TOP,true)
	near.name = "NearIsland"
	art.add_child(near)
	far = Art.island(Art.FAR,20.0,Isle.SEED+1,Art.base)
	far.name = "FarIsland"
	art.add_child(far)
	var built: Dictionary = Art.aqueduct(Isle.SEED)
	art.add_child(built.node)
	# Its channel's water, in the world's frame (none with --old-water: the
	# old film is the aqueduct's own).
	if built.water != null: art.add_child(built.water)
	parts.append_array(built.parts)
	var castellum: Dictionary = Art.castellum(Isle.SEED+2)
	art.add_child(castellum.node)
	parts.append_array(castellum.parts)
	art.add_child(Art.buttress(Isle.SEED+3))
	art.add_child(Art.rubble_heap(Isle.SEED+6))
	art.add_child(Art.hill_walls(Isle.SEED+7))
	stair = RuinKit.grand_stair(Isle.STAIR_SEED,Isle.STAIR_WEATHERED)
	stair.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Art.STAIR_AT)
	art.add_child(stair)
	kit_stairs = RuinKit.stairs(Isle.STEPS_SEED,Isle.STAIR_WEATHERED)
	kit_stairs.transform = Art.stairs_frame()
	art.add_child(kit_stairs)
	circle = RuinKit.stone_circle(Isle.CIRCLE_SEED,Isle.LANDMARK_WEATHERED,[Art.MISSING])
	circle.transform = Art.circle_transform()
	art.add_child(circle)
	art.add_child(Art.floating_stones(Isle.SEED+10))
	islets = Art.islets(Isle.SEED+11)
	for islet: Node3D in islets: art.add_child(islet)
	art.add_child(Art.heel_stone(Isle.SEED+8))
	for spec: Array in Isle.pieces():
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = spec[3]
		var z: float = spec[4]
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Art.ground(x,z),z))
		art.add_child(piece)
	art.add_child(_stumps())
	built_ms = Time.get_ticks_msec()-began

## The stepping stumps (studies/aqueduct_isle.gd `stumps`): an older
## arcade's piers, coursed solid to their tops, mossed and tufted there,
## their feet broken off under the islands; collided as clean boxes (into
## `parts`).
func _stumps() -> Node3D:
	var b := RuinKit.Build.new(Isle.SEED+5,0.6,"Stumps")
	b.settle = Aqueduct.SETTLE
	for s: Array in Isle.stumps():
		var x: float = s[0]
		var z0: float = s[1]
		var z1: float = s[2]
		var high: float = float(s[3])-Art.TOP
		var foot := -7.0-absf(z0)*0.1
		var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,Art.TOP,(z0+z1)*0.5))
		var line := func(_x: float) -> float: return high
		RuinKit._courses(b,pose,-absf(z1-z0)*0.5,absf(z1-z0)*0.5,foot,line,1.2,Callable(),0.55)
		b.frame = pose
		Art._broken_foot(b,0.0,foot)
		b.frame = Transform3D.IDENTITY
		for i in range(5):
			Art._tuft(b,Vector3(x+b.rng.randf_range(-0.9,0.9),Art.TOP+high,b.rng.randf_range(z1,z0)),0.3,4)
		parts.append(["box",Rect2(x-1.2,minf(z0,z1),2.4,absf(z1-z0)),Art.TOP+foot,float(s[3]),"lip"])
	var node := b.finish()
	node.get_node("Body").free()
	return node
