extends "res://studies/cozy_worlds.gd"
## Walk test: the real game (studies/cozy_worlds.gd), opened on one fixed sky
## island to walk round in third person. The island is the plain's own
## irregular outline (scripts/genesis_canvas.gd `shape`, scripts/
## island_outline.gd) at its largest, a chain of mountains raised along its
## long axis with the land brush's own forms (scripts/mountain_forms.gd: a
## ridge, an alpine horn at one end, a lesser peak at the other, weathered and
## rock-tinted as a player's are), then planted with mixed trees and
## undergrowth on its land. Everything is seeded (SEED), so every launch is the
## same island; the sky round it is the game's, from the same seed.
##
## It skips the title and the first steps, keeps its places in a scratch
## folder under the temp dir (never the player's saves) and drops straight into
## walk mode on the open side, facing the mountains. V or Esc steps out to
## build as usual.
##   ./run-walk-island.command
##   godot --path . res://studies/walk_island.tscn -- --no-title
const Genesis = preload("res://scripts/genesis_canvas.gd")
const MountainForms = preload("res://scripts/mountain_forms.gd")

## The one island: its seed (outline, swells, mood, sky) and size (0..1 of
## scripts/island_outline.gd AREA; 1 is about 43 m across).
const SEED := 52417
const SIZE := 1.0
## The mountains ease back to the plain's ground over this many metres in from
## the shore, so the shore walls hang from the island's rim height.
const SHORE_EASE := 4.0
## Trees stay below this height (m); the snow starts a little over it.
const TREELINE := 4.6
## Metres kept clear of trees round where the walker starts.
const START_CLEAR := 4.5

## True once the island is raised and planted.
var island_ready := false
## True once the walker stands on the island, in walk mode.
var walk_ready := false
## What was made: the long axis, the mountains' summits, the start, counts.
var island := {}
## Launched as the app (the main scene), not instantiated by a test or probe.
var _launched := false

func _ready() -> void:
	_launched = get_tree().current_scene == self
	set_meta("no_title",true)
	if places_path == "user://cozy-worlds/places.json":
		places_path = OS.get_temp_dir().path_join("zenscape-walk-island").path_join("places.json")
	DirAccess.make_dir_recursive_absolute(places_path.get_base_dir())
	# A fresh plain every launch: nothing of the last walk is loaded.
	for file: String in ["places.json","places-previous.json"]:
		var path := places_path.get_base_dir().path_join(file)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# The plain the game opens on grows from SEED, so its mood and sky do too.
	child_entered_tree.connect(_seed_session)
	await super._ready()
	if not island_ready: await _raise_island(null)
	await _step_in()

func _seed_session(node: Node) -> void:
	if node.name != "WorldSession": return
	child_entered_tree.disconnect(_seed_session)
	node.set("launch_seed",SEED)

## Launched as the app: hold the island under the loading veil until its sky
## is ready, as a resumed world does. A test that instantiates the scene goes
## on without waiting.
func _sky_veil_wanted() -> bool:
	return _launched or super._sky_veil_wanted()

## No first steps: this scene is for walking.
func _build_first_steps() -> void:
	pass

## The island is raised under the veil, before the sky's wait.
func hold_for_sky(veil: Node = null) -> void:
	if not island_ready and veil != null: await _raise_island(veil)
	await super.hold_for_sky(veil)

# --- The island ---------------------------------------------------------------------

func _raise_island(veil: Node) -> void:
	if veil != null: veil.stage("Raising the island · growing the forest")
	while _chunk_editor.forming or (places != null and places.busy): await get_tree().process_frame
	var editor: NativeChunkEditor = _chunk_editor
	var data := editor.data
	editor.finish_stroke()
	editor.selected_object_id = -1
	editor.forming = true
	editor.formation_started.emit()
	data.begin_stroke()
	Genesis.shape(data,SEED,Vector2.ZERO,true,SIZE)
	var axes := _axes(data)
	_mountains(data,axes)
	_plant(data,axes)
	data.end_stroke()
	data._undo.clear()
	data._redo.clear()
	await editor.refresh(get_tree())
	editor.land_seed = SEED
	editor.forming = false
	# The peaks' mist sits on the mountains' flanks, as a generated range's.
	_world_visuals.peak_altitude = clampf(Array(data.heights).max()*0.6,2.0,24.0)
	_world_visuals.sync(self)
	if has_method("_refresh_habitat"): call("_refresh_habitat")
	island_ready = true
	print("walk island: %.0f m² of land, highest %.1f m, %s" % [data.land_area(),Array(data.heights).max(),str(island.counts)])

## The island's middle, long axis and half-extents along it and across it,
## from its land points.
func _axes(data: NativeTerrainData) -> Dictionary:
	var land := PackedVector2Array()
	for i in range(data.points.size()):
		if data.shore_distance.is_empty() or data.shore_distance[i] >= 0.0: land.append(data.points[i])
	var middle := Vector2.ZERO
	for p in land: middle += p
	middle /= maxf(land.size(),1.0)
	var xx := 0.0
	var zz := 0.0
	var xz := 0.0
	for p in land:
		var d := p-middle
		xx += d.x*d.x
		zz += d.y*d.y
		xz += d.x*d.y
	var along := Vector2.from_angle(0.5*atan2(2.0*xz,xx-zz))
	var across := Vector2(-along.y,along.x)
	var reach := Vector4(INF,-INF,INF,-INF)
	for p in land:
		var d := p-middle
		reach.x = minf(reach.x,d.dot(along))
		reach.y = maxf(reach.y,d.dot(along))
		reach.z = minf(reach.z,d.dot(across))
		reach.w = maxf(reach.w,d.dot(across))
	return {"middle":middle,"along":along,"across":across,"reach":reach}

## A ridge down the island's long axis, set to one side so the other stays
## open, an alpine horn at one end and a lesser peak at the other, each risen
## and weathered as the land brush's mountains are, then eased back to the
## plain's ground near the shore.
func _mountains(data: NativeTerrainData, axes: Dictionary) -> void:
	var base := data.heights.duplicate()
	var middle: Vector2 = axes.middle
	var along: Vector2 = axes.along
	var across: Vector2 = axes.across
	var reach: Vector4 = axes.reach
	# The mountains stand on the narrower side of the long axis.
	var side := -1.0 if -reach.z < reach.w else 1.0
	var spine := middle+across*side*(absf(reach.z if side < 0.0 else reach.w)*0.38)
	var length := reach.y-reach.x
	var forms := MountainForms.new()
	forms.prepare(data,SEED)
	var summits := []
	# [form, press, aim, brush size, strength]
	var specs := [
		["ridge",spine+along*(length*0.02),spine+along*(length*0.27),4.0,2.0],
		["alpine",spine+along*(reach.y*0.62)+across*side*0.6,spine+along*(reach.y*0.62+3.6),5.0,2.0],
		["alpine",spine+along*(reach.x*0.58),spine+along*(reach.x*0.58-1.8),3.5,1.4],
	]
	for spec: Array in specs:
		var at: Vector2 = data.nearest_land(spec[1],SHORE_EASE+2.0)
		if at == Vector2.INF: continue
		forms.begin(data,spec[0],at,spec[3],spec[4],along)
		forms.aim(data,at+(spec[2]-spec[1]))
		forms.settle(data)
		var weathering: Callable = forms.weather_job(data)
		if weathering.is_valid():
			var result: Dictionary = weathering.call()
			if result.moved: data.heights = result.heights
			if result.has("tint") and result.tint.size() == data.tint.size(): data.tint = result.tint
		forms.active = false
		summits.append({"form":spec[0],"at":at,"height":forms.height})
	var heights := data.heights
	for i in range(heights.size()):
		var inland := data.shore_distance[i] if not data.shore_distance.is_empty() else INF
		heights[i] = base[i] if inland < 0.0 else lerpf(base[i],heights[i],smoothstep(0.0,SHORE_EASE,inland))
	data.heights = heights
	island = {"middle":middle,"along":along,"across":across,"side":side,"spine":spine,"summits":summits}

## Trees in groves (conifers up the slopes, broadleaf, birch and juniper
## lower), and undergrowth over the land: grass tufts, ferns and leaf beds in
## the woods, shrubs, flower drifts in the open, boulders on the slopes, the odd
## log, stump and mushroom. Only on land, in from the shore, off the steeps
## and the snow, and clear of where the walker starts.
func _plant(data: NativeTerrainData, axes: Dictionary) -> void:
	data.objects.clear()
	data.objects_revision += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+1709
	var groves := FastNoiseLite.new()
	groves.seed = SEED+31
	groves.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	groves.frequency = 0.085
	var drifts := FastNoiseLite.new()
	drifts.seed = SEED+47
	drifts.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	drifts.frequency = 0.16
	var start := _start_spot(data,axes)
	island.start = start
	var counts := {}
	var trees: Array[Vector2] = []
	var half := Plate.HALF-1.0
	for attempt in range(2600):
		var p := Vector2(rng.randf_range(-half,half),rng.randf_range(-half,half))
		var grove := groves.get_noise_2d(p.x,p.y)
		var roll := rng.randf()
		var kind_roll := rng.randf()
		var size_roll := rng.randf()
		var angle := rng.randf()*TAU
		if not _plantable(data,p,1.4,0.85) or p.distance_to(start) < START_CLEAR: continue
		var h := float(data.ground_height(p))
		if h > TREELINE: continue
		# Groves, and a scatter of lone trees in the open.
		if grove < -0.05 and roll > 0.08: continue
		var close := false
		for other in trees:
			if p.distance_squared_to(other) < 2.1*2.1:
				close = true
				break
		if close: continue
		var high := smoothstep(0.9,3.0,h)
		var kind := "tree"
		if kind_roll > 0.3+0.6*high:
			kind = "broadleaf" if kind_roll < 0.62+0.25*high else "birch" if kind_roll < 0.9 else "juniper"
		var size := lerpf(0.8,1.25,size_roll)
		var tint := ""
		match kind:
			"tree": tint = NativeObjectPose.encode_tint(Color("3e7a44").srgb_to_linear()*lerpf(0.82,1.08,roll))
			"broadleaf":
				size = lerpf(1.1,1.6,size_roll)
				tint = NativeObjectPose.encode_tint(Color("6f9c46").srgb_to_linear()*lerpf(0.82,1.08,roll))
			"birch": size = lerpf(1.0,1.4,size_roll)
			"juniper": size = lerpf(0.9,1.3,size_roll)
		if _put(data,kind,p,angle,size,tint,counts): trees.append(p)
		if trees.size() >= 110: break
	for attempt in range(1600):
		var p := Vector2(rng.randf_range(-half,half),rng.randf_range(-half,half))
		var roll := rng.randf()
		var size_roll := rng.randf()
		var angle := rng.randf()*TAU
		if not _plantable(data,p,0.7,1.2): continue
		var h := float(data.ground_height(p))
		if h > TREELINE+1.2: continue
		var slope := _slope(data,p)
		var wooded := false
		for tree in trees:
			if p.distance_squared_to(tree) < 2.4*2.4:
				wooded = true
				break
		var drift := drifts.get_noise_2d(p.x,p.y)
		var kind := "grass_tuft"
		if slope > 0.55 or h > TREELINE: kind = "boulder_%d" % (1+int(roll*4.0)%4) if roll < 0.55 else "grass_tuft"
		elif wooded:
			kind = "fern" if roll < 0.42 else "leaf_bed" if roll < 0.52 else "mushroom" if roll < 0.6 else "log" if roll < 0.63 else "stump" if roll < 0.66 else "shrub" if roll < 0.76 else "grass_tuft"
		elif drift > 0.05:
			kind = ["daisy_flower","buttercup","oxeye_daisy","lupine","button_flower"][int(roll*5.0)%5]
		else:
			kind = "shrub" if roll < 0.12 else "boulder_%d" % (1+int(roll*40.0)%4) if roll < 0.17 else "spike_flower" if roll < 0.22 else "grass_tuft"
		if p.distance_to(island.start) < 1.6 and not kind in ["grass_tuft","daisy_flower","buttercup","oxeye_daisy","button_flower"]: continue
		var size := lerpf(0.35,0.7,size_roll) if kind.begins_with("boulder") else lerpf(0.65,1.1,size_roll)
		_put(data,kind,p,angle,size,"",counts)
	data.objects_revision += 1
	island.counts = counts

func _put(data: NativeTerrainData, kind: String, p: Vector2, angle: float, size: float, tint: String, counts: Dictionary) -> bool:
	if data.place(kind,p,angle,size,{},tint) < 0: return false
	data.objects.back()["landscape"] = true
	counts[kind] = int(counts.get(kind,0))+1
	return true

## On the land, `inset` m in from the shore, no steeper than `steep`.
func _plantable(data: NativeTerrainData, p: Vector2, inset: float, steep: float) -> bool:
	if not data.has_land(p) or data.ground_height(p) == null: return false
	var inland: Variant = data.sample(p,data.shore_distance) if not data.shore_distance.is_empty() else INF
	if inland == null or float(inland) < inset: return false
	return _slope(data,p) <= steep

func _slope(data: NativeTerrainData, p: Vector2) -> float:
	var s := []
	for offset: Vector2 in [Vector2(0.25,0),Vector2(-0.25,0),Vector2(0,0.25),Vector2(0,-0.25)]:
		var h: Variant = data.ground_height(p+offset)
		if h == null: return INF
		s.append(float(h))
	return Vector2(s[0]-s[1],s[2]-s[3]).length()/0.5

## Open ground on the far side of the island from the mountains, looking
## across at them.
func _start_spot(data: NativeTerrainData, axes: Dictionary) -> Vector2:
	var reach: Vector4 = axes.reach
	var side: float = island.side
	var open := absf(reach.w if side < 0.0 else reach.z)
	var want: Vector2 = axes.middle-axes.across*side*open*0.45
	var at := data.nearest_land(want,3.0)
	return at if at != Vector2.INF else axes.middle

# --- Walking ------------------------------------------------------------------------

## Set the pilot down on the start and step in, facing the mountains.
func _step_in() -> void:
	while wanderer == null or not wanderer.can_enter(): await get_tree().process_frame
	var start: Vector2 = island.start
	var look: Vector2 = (island.spine as Vector2)-start
	# The camera sits behind the pilot: its yaw points back from where it looks.
	yaw = atan2(-look.x,-look.y)+wanderer._turn()
	wanderer.place(Vector3(start.x,0.0,start.y))
	wanderer.enter()
	walk_ready = wanderer.active
