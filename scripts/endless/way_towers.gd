extends Node3D
## The way towers (docs/design/endless-flight/spec-wilderness-demo.md, trunk 3,
## the pull): lone belfries, the door ruin's own, the only thing on the land
## taller than a hill that isn't one. Neither the ruin nor the coast shows from
## the start meadow. The first tower does, down the length of the bay, and from
## its foot the next two show, one on the way to the ruin, one on the way to
## the isles.
##
## Each stands from REACH m, built on a worker. Handles `way/<place>`: a move in
## the layout file wins, and a find on the handle follows. Trees keep off
## (`tree_keepouts`). Its stone is the flight's solid through LandArches `loose`.
## Only the wilderness has them: they go while the plane is anywhere else.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")

const SITES := [
	{"name":"way/bay","at":Vector2(130.0,1540.0),"yaw":PI},
	{"name":"way/south","at":Vector2(-600.0,2480.0),"yaw":0.6},
	{"name":"way/isle","at":Vector2(990.0,2700.0),"yaw":-0.9},
]
const WEATHERED := 0.55
## Stands within REACH m of the eye, gone past FREE.
const REACH := 3200.0
const FREE := 3600.0
## The tower's solid: [half width, top], stage on stage, as the buttresses step in.
const STAGES := [[13.5,24.0],[12.5,45.0],[11.5,66.0],[9.5,106.0],[7.0,120.0]]
const FOOT := 6.0
## The trees' keep-out, half a side (m).
const CLEAR := 38.0

var game: Node3D
## handle -> {name, coded, xf, seed, state ("away", "building", "up"), task, made, node, record}.
var sites := {}

func setup(g: Node3D) -> void:
	game = g
	for site: Dictionary in SITES:
		var at: Vector2 = site.at
		var coded := Transform3D(Basis(Vector3.UP,float(site.yaw)),Vector3(at.x,float(game.field.height(at.x,at.y)),at.y))
		sites[site.name] = {"name":site.name,"coded":coded,"xf":LayoutOverrides.xform(str(site.name),coded),
			"seed":absi(hash(str(site.name)))%100000,"state":"away","task":-1}

## Where a tower's foot stands (world), or Vector3.INF for no such tower.
func at(handle: String) -> Vector3:
	if not sites.has(handle): return Vector3.INF
	return (sites[handle].xf as Transform3D).origin

## TreePlan's keep-outs, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	for site: Dictionary in SITES:
		var p: Vector2 = site.at
		if p.x < x0-500.0 or p.x > x1+500.0 or p.y < z0-500.0 or p.y > z1+500.0: continue
		out.append([p,1.0,0.0,CLEAR,CLEAR])
	return out

## One frame: the towers streamed round the eye.
func step(eye: Vector3) -> void:
	var here := game.finds == null or str(game.finds.world) == "wilderness"
	for handle: String in sites:
		var site: Dictionary = sites[handle]
		var d: float = (site.xf as Transform3D).origin.distance_to(eye) if here else INF
		match str(site.state):
			"away":
				if d < REACH: _begin(site)
			"building":
				if WorkerThreadPool.is_task_completed(int(site.task)): _commit(site)
			"up":
				if d > FREE: _free(site)

func _begin(site: Dictionary) -> void:
	site.state = "building"
	RuinKit.Build.materials()
	site.task = WorkerThreadPool.add_task(_make.bind(site),false,"Way tower")

## On a worker: the piece, off the tree.
func _make(site: Dictionary) -> void:
	site.made = RuinKit.piece("belfry_tower",int(site.seed),WEATHERED)

## On the main thread: the piece in the tree, its boxes for its hulls.
func _commit(site: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	var xf: Transform3D = site.xf
	var root := Node3D.new()
	root.name = str(site.name).replace("/","_")
	root.transform = xf
	add_child(root)
	site.node = root
	LayoutOverrides.track(str(site.name),root,"piece",site.coded)
	var piece: Node3D = site.made
	site.erase("made")
	for old in piece.find_children("*","StaticBody3D",true,false):
		old.get_parent().remove_child(old)
		old.free()
	game.arches._sunlit(piece,false,false,xf.origin)
	root.add_child(piece)
	var boxes: Array = []
	var low := -FOOT
	for stage: Array in STAGES:
		var half := float(stage[0])
		boxes.append(AABB(Vector3(-half,low,-half),Vector3(half*2.0,float(stage[1])-low,half*2.0)))
		low = float(stage[1])
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	var yaw := xf.basis.get_euler().y
	site.record = {"name":str(site.name),"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":float(STAGES[0][0])+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
	game.arches.loose.append(site.record)
	GroundNative.bump_loose()
	site.state = "up"

func _free(site: Dictionary) -> void:
	game.arches.loose.erase(site.record)
	GroundNative.bump_loose()
	site.erase("record")
	if site.has("node") and is_instance_valid(site.node): (site.node as Node).queue_free()
	LayoutOverrides.entries.erase(site.name)
	site.state = "away"

func _exit_tree() -> void:
	for handle: String in sites:
		var site: Dictionary = sites[handle]
		if int(site.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(site.task))
		site.task = -1
		if site.has("made"): (site.made as Node).free()
