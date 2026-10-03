extends "res://scripts/clay_tools/clay_tool.gd"
## The trash can, "Clear": the easy way to take away anything set on the
## land. Like the Brush it paints (the clay's paint, scripts/land_clay.gd
## State.PAINT): press and hold or drag, and every object whose foot is within
## the can's reach (trees, rocks, shrubs, flowers, logs, leaf beds...) goes,
## flying up into its mouth and shrinking away. Waterfalls, explosives and
## Bigfoot's tree stay. **Shift** spares the big things (BIG: trees, boulders,
## arches): only the small stuff goes.
##
## One press is one undo step: the clay opens it at the press and closes it at
## the release, and the records go from the land's objects inside it. The
## ground each stood on turns hand-made (as the hand's pluck keeps it bare,
## scripts/hand_reach.gd `_keep_bare`), so emergence does not grow it straight
## back. Fallen branches (scripts/dead_wood.gd) and blown leaves
## (scripts/wind_leaf_litter.gd) are swept too; they are the world's own
## passing litter, not the land's, so no undo brings them back.

## Its reach (m) round the pointer at the middle pip.
const RADIUS := 1.4
## What it never takes, and what Shift spares.
const KEPT := ["waterfall","bigfoot_tree","explosive"]
const BIG := ["tree","layered_tree","redwood","broadleaf","snag","birch","willow","juniper","joshua","cactus","rock","boulder_1","boulder_2","boulder_3","boulder_4","arch"]
## The flight into the mouth: seconds, and at most this many in the air.
const SUCK_SECONDS := 0.45
const MAX_FLYING := 48
## Seconds between its sounds while it takes things.
const SOUND_GAP := 0.12

## The stand-in: a faceted bin held mouth down, in the icon's tint
## (scripts/hud_icons.gd "trash"), banded darker, its mouth dark, a handle
## standing over its base.
const TINT := Color("7d9465")
const BAND := Color("3f5236")
const MOUTH := Color("1c241b")
const TILT := -10.0
const BODY_RADIUS := 0.24
const BODY_HEIGHT := 0.46

## Ids taken this press, and what is flying: {"node", "from" (Transform3D,
## world), "t"}.
var taken: Array[int] = []
var _flying: Array[Dictionary] = []
var _quiet := 0.0
var _spare_big := false

func id() -> String: return "trash"
func gesture(_verb: String) -> String: return "press"
func prop_tilt() -> float: return TILT
func dirt_share(_verb: String) -> float: return 0.0
func turns_lip(_verb: String) -> bool: return false
func stroke_radius() -> float: return RADIUS*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*RADIUS
func paints() -> bool: return true

## Whether it takes asset `kind` (with Shift, `spare_big`).
static func takes(kind: String, spare_big := false) -> bool:
	return not kind in KEPT and not (spare_big and kind in BIG)

func reset() -> void:
	lift = 0.0
	taken = []

func paint_begin(fine: bool) -> String:
	taken = []
	_spare_big = fine
	return "clear_small" if fine else "clear"

func paint_dab(_heights: PackedFloat32Array, q: Vector2, _work: float) -> float:
	var radius := stroke_radius()
	var editor: Node = clay.editor
	var data: NativeTerrainData = editor.data
	var going: Array[Dictionary] = []
	for item: Dictionary in data.objects:
		if not takes(str(item.asset),_spare_big): continue
		if Vector2(float(item.x),float(item.z)).distance_to(q) <= radius: going.append(item)
	_sweep_litter(q,radius)
	if going.is_empty(): return 0.0
	var reach: Node = clay.scene.get("hand_reach")
	var play: Variant = clay.scene.get("world_play")
	var ids := {}
	var big := false
	for item in going:
		var at := int(item.id)
		ids[at] = true
		big = big or str(item.asset) in BIG
		# Its drawn parts fly before its record goes.
		if reach != null and reach.has_method("_plant_parts"):
			for part: Dictionary in reach._plant_parts(at): _fly(part.mesh,part.material,part.transform)
		if play != null and play._active.has(at):
			var node: Variant = play._active[at]
			play._active.erase(at)
			if is_instance_valid(node): node.queue_free()
		var root := Vector2(float(item.x),float(item.z))
		if reach != null and reach.has_method("_keep_bare"): reach._keep_bare(root,NativeTerrainData.object_source(item) == "emerged")
		else: data.provenance[data.meadow_cell(root)] = NativeTerrainData.SOURCE_HAND
	var kept: Array[Dictionary] = []
	for item: Dictionary in data.objects:
		if not ids.has(int(item.id)): kept.append(item)
	data.objects.assign(kept)
	data.objects_revision += 1
	var gone: Array = ids.keys()
	taken.append_array(gone)
	if editor.get("dandelions") != null: editor.dandelions.cleared(gone)
	editor.content.paint_hide(gone)
	clay.touch(q,radius)
	if _quiet <= 0.0:
		clay.sound(&"crumble" if big else &"plant",q,0.8 if big else 0.5)
		_quiet = SOUND_GAP
	return 0.0

func paint_end(_tapped: bool) -> void:
	_spare_big = false

## Fallen branches lying in reach go up the mouth; blown leaves in reach are
## lost (they fade and grow back under their trees in time, as blown away).
func _sweep_litter(q: Vector2, radius: float) -> void:
	var terrain: Node3D = clay.editor.terrain
	var world := terrain.to_global(clay.ground_at(q))
	var reach_world := radius*terrain.global_basis.get_scale().x
	var wood: Variant = clay.scene.get("dead_wood")
	if wood != null and wood.has_method("sweep"):
		for node: Node3D in wood.sweep(world,reach_world): _fly_node(node)
	var litter: Variant = clay.scene.get("_leaf_litter")
	if litter != null and is_instance_valid(litter) and litter.has_method("sweep"):
		litter.sweep(world,reach_world)

## A drawn part (world transform) flies into the mouth.
func _fly(mesh: Mesh, material: Material, from: Transform3D) -> void:
	if mesh == null or _flying.size() >= MAX_FLYING: return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material != null: node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	clay.editor.terrain.add_child(node)
	node.global_transform = from
	_flying.append({"node":node,"from":from,"t":0.0})

## A node of its own (a fallen branch) flies into the mouth.
func _fly_node(node: Node3D) -> void:
	if not is_instance_valid(node): return
	var from := node.global_transform
	if _flying.size() >= MAX_FLYING:
		node.queue_free()
		return
	node.reparent(clay.editor.terrain)
	node.top_level = true
	node.visible = true
	node.global_transform = from
	_flying.append({"node":node,"from":from,"t":0.0})

## The flights draw in, quickening and shrinking, turning as they go.
func frame(delta: float) -> void:
	_quiet -= delta
	if _flying.is_empty(): return
	var mouth: Variant = clay.prop_point(Vector3.ZERO)
	var into: Vector3 = clay.editor.terrain.to_global(mouth) if mouth != null else Vector3.INF
	var still: Array[Dictionary] = []
	for flight in _flying:
		var node: Node3D = flight.node
		if not is_instance_valid(node): continue
		flight.t = float(flight.t)+delta/SUCK_SECONDS
		if flight.t >= 1.0:
			node.queue_free()
			continue
		var from: Transform3D = flight.from
		var k: float = flight.t*flight.t
		var to: Vector3 = into if into != Vector3.INF else from.origin+Vector3.UP*1.5
		var spin := Basis(Vector3.UP,k*TAU*0.6)
		var shrink := maxf(1.0-k,0.02)
		node.global_transform = Transform3D(spin*from.basis.scaled(Vector3.ONE*shrink),from.origin.lerp(to,k))
		still.append(flight)
	_flying = still

func busy() -> bool: return not _flying.is_empty()

## Whatever is still flying is gone at once.
func finish() -> void:
	for flight in _flying:
		if is_instance_valid(flight.node): (flight.node as Node).queue_free()
	_flying = []

## A faceted bin held mouth down: an eight-sided body widening to its mouth,
## two dark bands, the dark mouth, and a loop handle over its base.
func build_prop() -> Node3D:
	var root := Node3D.new()
	var middle := Vector3(0.0,-BODY_HEIGHT*0.5,0.0)
	root.add_child(part(_prism(8,1.15),TINT,middle,Vector3(BODY_RADIUS,BODY_HEIGHT,BODY_RADIUS)))
	for at in [0.28,0.72]:
		var r := BODY_RADIUS*lerpf(1.0,1.15,at)*1.04
		root.add_child(part(_prism(8),BAND,Vector3(0.0,-BODY_HEIGHT*at,0.0),Vector3(r,0.03,r)))
	var lip := BODY_RADIUS*1.15
	root.add_child(part(_prism(8),BAND,Vector3(0.0,-BODY_HEIGHT,0.0),Vector3(lip*1.06,0.04,lip*1.06)))
	root.add_child(part(_prism(8),MOUTH,Vector3(0.0,-BODY_HEIGHT-0.022,0.0),Vector3(lip*0.92,0.01,lip*0.92)))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.8
	handle.outer_radius = 1.0
	handle.rings = 10
	handle.ring_segments = 5
	root.add_child(part(handle,BAND,Vector3(0.0,0.02,0.0),Vector3.ONE*0.12,Vector3(0.0,0.0,PI*0.5)))
	return root

## An upright n-sided prism, unit radius and height, widening to `foot` of
## its radius at the bottom.
static func _prism(sides: int, foot := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = foot
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh
