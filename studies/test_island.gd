extends "res://studies/cozy_worlds.gd"
## Test island: the real game (studies/cozy_worlds.gd) cut down to one small
## square sky island, alone, for trying the pilot on foot (scripts/
## pilot_motor.gd, pilot_figure.gd, pilot_wake.gd, pilot_ledge.gd, through
## scripts/wanderer_eye.gd). Most of it is a field of wheat drilled in the
## game's own rows (scripts/flower_sowing.gd "wheat"), with a grass margin
## round it, three trees, a pond to wade into and swim in and a few tufts and
## ferns; every shore is an open rim to hang from.
##
## Nothing of the sky world is made: the walker's glide is off from the start
## (wanderer_eye.gd `glide_enabled`), so no sky islands, islets, peaks,
## cumulus, planes or traffic, and walking off the rim sets him back on the
## land as the plate clamp does. Everything is seeded (SEED). It skips the
## title and the first steps, keeps its places in a scratch folder under the
## temp dir and drops straight into walk mode at the edge of the wheat, facing
## into it. V or Esc steps out to build as usual.
##   ./run-test-island.command
##   godot --path . res://studies/test_island.tscn -- --no-title
const Genesis = preload("res://scripts/genesis_canvas.gd")
const IslandOutline = preload("res://scripts/island_outline.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const WandererEye = preload("res://scripts/wanderer_eye.gd")

const SEED := 61873
## The island: a square HALF m each way (a plate grid line, so its shore runs
## straight along the faces).
const HALF := 12.0
## The wheat's field (plate x, z; the land round it is a grass margin) and
## how close its sown landings stand (m; well over FlowerSowing FULL a m²).
const FIELD := Rect2(-8.5,-9.5,12.5,19.0)
const SOW_STEP := 0.25
## The pond: its middle, the bowl's radius and depth (m), and how far under
## the bowl's lowest edge its water stands. The middle, about 1.3 m, is
## deeper than the walker's WADE: he swims there (about 1.9 m round); the
## shelf round it is wadeable.
const POND := Vector2(7.6,-6.4)
const POND_RADIUS := 3.6
const POND_DEPTH := 1.4
const POND_BELOW_RIM := 0.1
## The trees: [kind, at, size, tint].
const TREES := [
	["broadleaf",Vector2(8.4,-1.6),1.35,"6f9c46"],
	["birch",Vector2(6.4,3.4),1.2,""],
	["tree",Vector2(8.8,7.0),1.15,"3e7a44"],
]
## Where the walker starts (in the margin, the wheat's edge just ahead) and
## the way he faces.
const START := Vector2(-9.8,0.4)
const FACING := Vector2(1.0,0.0)

## True once the island is raised and planted.
var island_ready := false
## True once the walker stands on the island, in walk mode.
var walk_ready := false
## What was made: the start, the pond, counts.
var island := {}
## Launched as the app (the main scene), not instantiated by a test or probe.
var _launched := false

func _ready() -> void:
	_launched = get_tree().current_scene == self
	set_meta("no_title",true)
	if places_path == "user://cozy-worlds/places.json":
		places_path = OS.get_temp_dir().path_join("zenscape-test-island").path_join("places.json")
	DirAccess.make_dir_recursive_absolute(places_path.get_base_dir())
	# A fresh plain every launch: nothing of the last walk is loaded.
	for file: String in ["places.json","places-previous.json"]:
		var path := places_path.get_base_dir().path_join(file)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	child_entered_tree.connect(_seed_session)
	child_entered_tree.connect(_ground_walker)
	await super._ready()
	if not island_ready: await _raise_island(null)
	await _step_in()

func _seed_session(node: Node) -> void:
	if node.name != "WorldSession": return
	child_entered_tree.disconnect(_seed_session)
	node.set("launch_seed",SEED)

## The walker without the glide, before its setup makes the sky: no islands,
## islets, cumulus, planes or traffic round this one.
func _ground_walker(node: Node) -> void:
	if node.get_script() != WandererEye: return
	child_entered_tree.disconnect(_ground_walker)
	node.set("glide_enabled",false)

## Launched as the app: the island is raised under the loading veil. A test
## that instantiates the scene goes on without it.
func _sky_veil_wanted() -> bool:
	return _launched or super._sky_veil_wanted()

## No first steps: this scene is for walking.
func _build_first_steps() -> void:
	pass

## The island is raised under the veil (there is no sky to wait for).
func hold_for_sky(veil: Node = null) -> void:
	if not island_ready and veil != null: await _raise_island(veil)
	await super.hold_for_sky(veil)

# --- The island ---------------------------------------------------------------------

func _raise_island(veil: Node) -> void:
	if veil != null: veil.stage("Raising the island · sowing the wheat")
	while _chunk_editor.forming or (places != null and places.busy): await get_tree().process_frame
	var editor: NativeChunkEditor = _chunk_editor
	var data := editor.data
	editor.finish_stroke()
	editor.selected_object_id = -1
	editor.forming = true
	editor.formation_started.emit()
	data.begin_stroke()
	# The plain's own swells and grass carpet, on the square.
	Genesis.shape(data,SEED,Vector2.ZERO,true,-1.0,IslandOutline.square(data._face_center,HALF))
	data.objects.clear()
	data.objects_revision += 1
	var counts := {}
	_pond(data)
	_fill_pond(editor)
	_wheat(editor,counts)
	_plant(editor,counts)
	data.end_stroke()
	data._undo.clear()
	data._redo.clear()
	await editor.refresh(get_tree())
	editor.land_seed = SEED
	editor.forming = false
	if has_method("_refresh_habitat"): call("_refresh_habitat")
	island.start = START
	island.counts = counts
	island_ready = true
	print("test island: %.0f m² of land, the pond %.1f m³ to %.2f m, %s" % [data.land_area(),float(island.pond.get("volume",0.0)),float(island.pond.get("level",0.0)),str(counts)])

## A smooth bowl dug in the ground, for the pond (`_fill_pond`): sunk from
## the lowest ground round its edge, so the water it holds stays in it.
func _pond(data: NativeTerrainData) -> void:
	var rim := INF
	for k in range(24): rim = minf(rim,float(data.ground_height(POND+Vector2.RIGHT.rotated(k*TAU/24.0)*POND_RADIUS)))
	var heights := data.heights
	for i in range(heights.size()):
		var d := data.points[i].distance_to(POND)
		if d >= POND_RADIUS: continue
		heights[i] = minf(heights[i],rim-POND_DEPTH*smoothstep(0.0,1.0,1.0-d/POND_RADIUS))
	data.heights = heights
	island.pond = {"at":POND,"level":rim-POND_BELOW_RIM}

## The bowl filled with live water (scripts/water_flow.gd), laid level at
## once over its hollow's cells (WaterFlow `hollow`, as the watering can's
## lift fills one, and the Island tool's lake keeps its level), POND_BELOW_RIM
## under the bowl's lowest edge.
func _fill_pond(editor: NativeChunkEditor) -> void:
	var flow: RefCounted = editor.flow
	if flow == null or not flow.ready: return
	# One step reads the new ground under the water's grid (the land as it
	# stands in the open stroke).
	flow.run(1)
	var ground: PackedFloat32Array = flow.grounds()
	var depth: PackedFloat32Array = flow.depths()
	var found: Dictionary = flow.hollow(POND,ground)
	if found.is_empty(): return
	var level := minf(float(island.pond.level),float(found.sill))
	var volume := 0.0
	for c: int in found.cells:
		var rise := maxf(level-ground[c]-depth[c],0.0)
		depth[c] += rise
		volume += rise*flow.cell*flow.cell
	flow.kernel.set_depth(depth)
	island.pond.merge({"level":level,"volume":volume})

## The wheat, sown as the hand sows it (FlowerSowing `grow`): its landings laid
## thick over FIELD, so the drift stands full there and feathers at its edge,
## drilled in the slot's own rows, the ground under it washed, none in the
## pond. Grown already, not blooming in.
func _wheat(editor: NativeChunkEditor, counts: Dictionary) -> void:
	var data := editor.data
	var sowing := FlowerSowing.new(data,"wheat",SEED)
	# Kept out of the pond, as the hand's sowing is (its editor's live water).
	sowing.wet = editor._paint_wet()
	var landings := PackedVector2Array()
	var times := PackedFloat32Array()
	for z in range(int(FIELD.size.y/SOW_STEP)+1):
		for x in range(int(FIELD.size.x/SOW_STEP)+1):
			landings.append(FIELD.position+Vector2(x,z)*SOW_STEP)
			times.append(0.0)
	var grown: Dictionary = sowing.grow(landings,times,0,0.0)
	for item: Dictionary in data.objects:
		item.erase("born")
		item["landscape"] = true
	for kind: String in grown.kinds: counts[kind] = int(counts.get(kind,0))+int(grown.kinds[kind])

## The trees, and a few grass tufts and ferns in the margin round the wheat,
## kept off the pond and the start.
func _plant(editor: NativeChunkEditor, counts: Dictionary) -> void:
	var data := editor.data
	var wet := editor._paint_wet()
	for spec: Array in TREES:
		var tint := NativeObjectPose.encode_tint(Color(spec[3]).srgb_to_linear()) if spec[3] != "" else ""
		_put(data,spec[0],spec[1],float(spec[1].x),spec[2],tint,counts)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+1709
	var field := FIELD.grow(0.4)
	for attempt in range(400):
		var p := Vector2(rng.randf_range(-HALF,HALF),rng.randf_range(-HALF,HALF))
		var roll := rng.randf()
		var size := rng.randf_range(0.7,1.1)
		var angle := rng.randf()*TAU
		if field.has_point(p) or wet.call(p) or p.distance_to(START) < 1.4: continue
		if not data.has_land(p) or data.sample(p,data.shore_distance) == null or float(data.sample(p,data.shore_distance)) < 0.6: continue
		var by_tree := TREES.any(func(spec: Array) -> bool: return p.distance_to(spec[1]) < 2.4)
		if TREES.any(func(spec: Array) -> bool: return p.distance_to(spec[1]) < 0.7): continue
		var kind := "fern" if by_tree and roll < 0.6 else "grass_tuft"
		if roll > 0.25 and not by_tree: continue
		_put(data,kind,p,angle,size,"",counts)
	data.objects_revision += 1

func _put(data: NativeTerrainData, kind: String, p: Vector2, angle: float, size: float, tint: String, counts: Dictionary) -> bool:
	if data.place(kind,p,angle,size,{},tint) < 0: return false
	data.objects.back()["landscape"] = true
	counts[kind] = int(counts.get(kind,0))+1
	return true

# --- Walking ------------------------------------------------------------------------

## Set the pilot down at the wheat's edge and step in, facing into it.
func _step_in() -> void:
	while wanderer == null or not wanderer.can_enter(): await get_tree().process_frame
	# The camera sits behind the pilot: its yaw points back from where it looks.
	yaw = atan2(-FACING.x,-FACING.y)+wanderer._turn()
	wanderer.place(Vector3(START.x,0.0,START.y))
	wanderer.enter()
	walk_ready = wanderer.active
	print("test island: walking %.2f s from launch" % (Time.get_ticks_msec()/1000.0))
