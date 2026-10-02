class_name NativeChunkEditor
extends Node
## Build tools attached to the live fidelity scene. Entering Build never swaps
## the chunk, camera, environment or shader; only the controls become active.
const GROUPS := [
	["Sculpt",["raise","lower","tunnel","smooth","flatten"]],
	["Landscape",["ground","range","mountain"]],
	["Cover",["grass","blades","meadow","paint","erase"]],
	["Place",["select","explosive","tree","rock","flower","arch","bigfoot_tree","assets"]],
	["Water",["pond","waterfall"]],
]
const TOOL_TEXT := {
	"tunnel":"Aim at a mountainside and click to bore inward. Plant a charge inside, then seal the tunnel.",
	"explosive":"Plant a remote charge. Cover it with leaves or raise dirt over it, then detonate from a distance.",
	"select":"Click a placed object to edit it · Drag to move · V Select · Delete removes",
	"raise":"Build hills with slow, gentle strokes.",
	"lower":"Press valleys and hollows into the land.",
	"smooth":"Soften slopes and blend your brushwork.",
	"flatten":"Level toward the height where you click.",
	"ground":"Set a resting height, then form the whole floor.",
	"range":"Shape a ridge across the chunk, then fill its water and flora.",
	"mountain":"Click for a peak or drag a ridge. Variation reshuffles its ridges.",
	"grass":"Paint ground cover, or green the whole chunk at once.",
	"blades":"Paint standing blades over the grass.",
	"meadow":"Paint grass and wildflowers together.",
	"paint":"Brush your own colour over rock and grass.",
	"erase":"Brush away cover and placed objects. Undo restores them.",
	"tree":"Click to plant a tree. It settles onto the ground.",
	"rock":"Click to set a stone.",
	"flower":"Click for one flower or drag to plant a trail.",
	"arch":"Click to raise a stone arch.",
	"bigfoot_tree":"Click to plant the tree Bigfoot visits.",
	"assets":"Pick a piece below, then click to place it.",
	"pond":"Dig a hollow first. Hover to preview the water, then click to fill.",
	"waterfall":"Click the waterfall lip, then a lower landing point.",
	"ember":"Drop a live ember on dry ground. Wind carries the front; rain, snow and wet ground put it out.",
	"land":"Drag to raise land · Shift-drag lowers · [ ] brush size",
}
## Every numeric setting a tool offers, in the order a shell should show them.
const SETTINGS := [
	{"property":"tunnel_width","title":"Tunnel width","low":1.5,"high":4.0,"step":0.25,"unit":"m","whole":false,"modes":["tunnel"]},
	{"property":"tunnel_depth","title":"Tunnel depth","low":2.0,"high":10.0,"step":0.5,"unit":"m","whole":false,"modes":["tunnel"]},
	{"property":"blast_radius","title":"Blast radius","low":1.0,"high":6.0,"step":0.1,"unit":"m","whole":false,"modes":["explosive"]},
	{"property":"ground_elevation","title":"Ground elevation","low":-1.0,"high":8.0,"step":0.1,"unit":"","whole":false,"modes":["ground"]},
	{"property":"ground_relief","title":"Ground relief","low":0.0,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":["ground"]},
	{"property":"radius","title":"Brush size","low":0.4,"high":5.0,"step":0.05,"unit":"","whole":false,"modes":["raise","lower","smooth","flatten","grass","blades","meadow","paint","erase"]},
	{"property":"strength","title":"Strength","low":0.4,"high":5.0,"step":0.05,"unit":"","whole":false,"modes":["raise","lower","smooth","flatten","meadow","erase"]},
	{"property":"grass_amount","title":"Ground coverage","low":0.0,"high":1.0,"step":0.05,"unit":"","whole":false,"modes":["grass"]},
	{"property":"blade_amount","title":"Blade density","low":0.0,"high":1.0,"step":0.05,"unit":"","whole":false,"modes":["blades"]},
	{"property":"paint_amount","title":"Paint opacity","low":0.05,"high":1.0,"step":0.05,"unit":"","whole":false,"modes":["paint"]},
	{"property":"range_height","title":"Range height","low":0.1,"high":1.8,"step":0.05,"unit":"","whole":false,"modes":["range"]},
	{"property":"range_width","title":"Range width","low":0.3,"high":1.5,"step":0.05,"unit":"","whole":false,"modes":["range"]},
	{"property":"range_heading","title":"Range rotation","low":-180.0,"high":180.0,"step":5.0,"unit":"°","whole":false,"modes":["range"]},
	{"property":"range_variation","title":"Range variation","low":0.0,"high":999.0,"step":1.0,"unit":"","whole":true,"modes":["range"]},
	{"property":"mountain_radius","title":"Base radius","low":1.0,"high":12.0,"step":0.5,"unit":"","whole":false,"modes":["mountain"]},
	{"property":"mountain_peak","title":"Peak height","low":0.5,"high":64.0,"step":0.5,"unit":"","whole":false,"modes":["mountain"]},
	{"property":"mountain_variation","title":"Variation","low":1.0,"high":999.0,"step":1.0,"unit":"","whole":true,"modes":["mountain"]},
	{"property":"mountain_heading","title":"Ridge rotation","low":-180.0,"high":180.0,"step":5.0,"unit":"°","whole":false,"modes":["mountain"]},
	{"property":"pond_level","title":"Water level","low":-1.4,"high":12.0,"step":0.05,"unit":"","whole":false,"modes":["pond"]},
	{"property":"object_scale","title":"Object size","low":0.1,"high":5.0,"step":0.1,"unit":"","whole":false,"modes":NativeTerrainData.ASSETS+["assets"]},
	{"property":"object_heading","title":"Rotation","low":-180.0,"high":180.0,"step":5.0,"unit":"°","whole":false,"modes":["tree","rock","flower","arch","bigfoot_tree","assets"]},
	{"property":"object_width","title":"Width","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"object_height","title":"Height","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"object_depth","title":"Depth","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"object_pitch","title":"Tilt forward","low":-90.0,"high":90.0,"step":5.0,"unit":"°","whole":false,"modes":POSE_TOOLS},
	{"property":"object_roll","title":"Tilt sideways","low":-90.0,"high":90.0,"step":5.0,"unit":"°","whole":false,"modes":POSE_TOOLS},
	{"property":"object_elevation","title":"Vertical offset","low":-5.0,"high":10.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"land_radius","title":"Brush size","low":1.5,"high":9.0,"step":0.25,"unit":"","whole":false,"modes":["land"]},
	{"property":"land_strength","title":"Strength","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":["land"]},
	{"property":"land_ceiling","title":"Highest land","low":2.0,"high":24.0,"step":0.5,"unit":"m","whole":false,"modes":["land"]},
]
const POSE_TOOLS := ["tree","flower","rock","assets"]
## The one-shot commands a tool offers beside its sliders. The name is the node
## name a shell should give the button, so scripts and tests can find it.
const ACTIONS := [
	{"tool":"tunnel","name":"PlantTunnelCharge","title":"Plant charge inside","method":"plant_tunnel_charge"},
	{"tool":"tunnel","name":"SealTunnel","title":"Seal last tunnel","method":"seal_tunnel"},
	{"tool":"tunnel","name":"ReopenTunnel","title":"Reopen last tunnel","method":"reopen_tunnel"},
	{"tool":"explosive","name":"ToggleExplosiveLeaves","title":"Toggle leaf camouflage","method":"toggle_explosive_leaves"},
	{"tool":"explosive","name":"DetonateExplosives","title":"Detonate all charges","method":"detonate_explosives"},
	{"tool":"ground","name":"FormGroundFoundation","title":"Form ground foundation","method":"form_foundation"},
	{"tool":"range","name":"FormMountainLandscape","title":"Form mountain landscape","method":"form_range"},
	{"tool":"range","name":"FillLandscapeStreams","title":"Fill landscape streams","method":"fill_landscape_streams"},
	{"tool":"range","name":"FillLandscapeWaterfall","title":"Fill landscape waterfall","method":"fill_landscape_waterfall"},
	{"tool":"range","name":"PopulateLandscapeFlora","title":"Populate landscape flora","method":"fill_landscape_flora"},
	{"tool":"grass","name":"CoverChunkInGrass","title":"Cover chunk in grass","method":"cover_grass"},
	{"tool":"blades","name":"RemoveBladePatches","title":"Remove Blades-tool patches","method":"clear_blades"},
]
## A shell listens to these to keep its widgets with the tool state, which
## hotkeys and scripted edits change just as often as the controls do.
signal tool_changed(tool: String)
signal setting_changed(property: String, value: float)
signal status_changed(text: String)
signal active_changed(enabled: bool)
signal sky_toggle_requested()
signal selection_changed(id: int)
## Emitted after rendered geometry changes, including live selected-object drags.
signal play_geometry_changed()
## A painted stroke's life, for feedback that answers the hand (tremor, fog,
## wind, local grow-in). `center` is world space, `radius` world units, `mode`
## the tool; `amount` is the brush strength spent by that batch of dabs.
signal stroke_started(center: Vector3, radius: float, mode: String)
signal stroke_moved(center: Vector3, radius: float, mode: String, amount: float)
signal stroke_finished(center: Vector3, radius: float, mode: String)
var _stroke_center := Vector3.ZERO
var _stroke_radius := 0.0
var _play_geometry_signature := PackedByteArray()
var selected_object_id := -1
var selection: NativeObjectSelection
var _selection_edit := false
var _selection_drag := false
var _selection_plane_y := 0.0
var _selection_press := Vector2.ZERO
var _selection_offset := Vector2.ZERO
var scene: Node3D
var terrain: MeshInstance3D
var data := NativeTerrainData.new()
## Life that follows finished strokes (scripts/emergence.gd).
var emergence: RefCounted = preload("res://scripts/emergence.gd").new(data)
var emergence_enabled := true
var _stroke_rect := Rect2()
var _stroke_first_id := 0
var content: GardenView
var landmarks: NativeGardenLandmarks
var falls: NativeGardenFalls
var reactions: NativeDropReactions
## Placement plays a short visual reaction. Tests that compare instances turn
## it off so a committed record renders exactly as it did before.
var reactions_enabled := true
var _fall_start: Variant = null
var pond_preview = preload("res://scripts/native_pond_preview.gd").new()
var explosives: Node3D
var blast_radius := 2.6
var tunnel_width := 2.5
var tunnel_depth := 5.0
var explosive_leaf_cover := false
var catalog_asset := "broadleaf"
var object_heading := 0.0
var pond_level := -0.15
var object_angle := 0.0
var custom_tint := false
var object_tint := Color("7fb069")
var object_scale := 1.0
var object_width := 1.0
var object_height := 1.0
var object_depth := 1.0
var object_pitch := 0.0
var object_roll := 0.0
var object_elevation := 0.0
const PLACEMENT_DEFAULTS := {"object_scale":1.0,"object_heading":0.0,"object_angle":0.0,"object_width":1.0,"object_height":1.0,"object_depth":1.0,"object_pitch":0.0,"object_roll":0.0,"object_elevation":0.0,"custom_tint":false,"object_tint":Color("7fb069")}
var _placement_settings := {}
var _placement_key := ""
var save_path := "user://native-garden.json"
var active := false
var forming := false
signal formation_started
var mode := "raise"
var radius := 2.2
var strength := 2.0
var ground_elevation := 0.0
var ground_relief := 1.0
var grass_amount := 1.0
var blade_amount := 0.35
## The Paint tool's colour, held in sRGB the way every other picker here is.
var paint_color := Color("b06f4a")
var paint_amount := 0.35
var range_height := 1.0
var range_width := 1.0
var range_heading := 0.0
var range_variation := 0
var mountain_radius := 9.0
var mountain_variation := 7
var mountain_heading := 0.0
var mountain_peak := 9.0
var status := "Left drag paints · Click places · Right drag orbits\n1-4 tools · [ ] brush size · Shift [ ] strength"
var _painting := false
var placement_trail := true
var _trail_point: Variant = null
var _elapsed := 0.0
var _level := 0.0
var _material: ShaderMaterial
var _previous_override: Material
var _anchors: Array[Dictionary] = []
var _original_ground_map: Image
var _original_stream_map: Image
var _original_bird_ground: RefCounted
var _original_precip_top := 0.0
var _source_visibility := {}
var _skirt: MeshInstance3D
var _skirt_mesh: ArrayMesh
var _boulder_anchors: Array[Transform3D] = []
var _landmark_pose: Transform3D
var _last_point: Variant = null
var _map_base: Image
var _map_ground: Image
var _map_stream: Image
var _map_heights := PackedFloat32Array()
var _map_revision := -1
var _map_water_region: Variant = null
var _map_blank := false
var _map_original := false
var _map_ready := false
var _map_generation := 0
var _map_busy := false
var surface_workers := 4
var last_surface_profile := {}
var _bigfoot_mesh: Mesh
## Standalone creature scenes provide their own physical ground.
var update_encounter_ground := true
## The creation brush (scripts/land_brush.gd): broad, noisy natural landforms,
## weathered by a local erosion pass when the stroke ends.
var land_brush = preload("res://scripts/land_brush.gd").new()
## Chunk atlas (scripts/chunk_atlas.gd): the live chunk's border pin, applied
## before every refresh so no edit can open a seam, and the borders that face
## a neighbour, whose earth-block walls are cut away.
var border_pin: RefCounted = null
const AtlasView = preload("res://scripts/chunk_atlas_view.gd")
var open_sides := {}
var land_radius := 4.5
var land_strength := 1.0
var land_ceiling := 10.0
## Seeds the brush's ridge field; the owning scene sets it per world.
var land_seed := 0
## Emitted after a land stroke's erosion pass settles into the heights.
signal land_weathered(bounds: Rect2)
## The land brush's form (scripts/mountain_forms.gd FORMS): "hill" paints with
## `land_brush`; the others raise one whole mountain per press (`mountain`).
var land_form := "hill"
signal land_form_changed(id: String)
var mountain = preload("res://scripts/mountain_forms.gd").new()
var _land_lower := false
## The button holding the current land stroke; every other stroke is a left drag.
var _stroke_button := MOUSE_BUTTON_LEFT
## A right press works the brush the other way; false leaves right drags to
## the camera (the creation shell), and Shift-drag alone lowers.
var right_works_other_way := true
## Every left drag works the brush the other way, as Shift-drag does: the
## Lantern shell's Other way mode (scripts/lantern_shell.gd).
var other_way := false
## Every creation brush by id (scripts/genesis_canvas.gd `BRUSHES`). The
## "land" tool paints with whichever is in hand: land, water, meadow, forest
## or path. `land_brush` and `water_brush` are the "land" and "water" entries.
var brushes := {}
var brush_id := "land"
signal brush_changed(id: String)
## Viewport point that stands in for the OS pointer while painting, or null.
## Films drive strokes with synthetic events; in a rendered window the
## viewport's mouse position is the real cursor, which they must not move.
var pointer_override: Variant = null
## The pointer's ground point this frame, in the terrain's space, or null
## when it is off the land, over the UI or the camera is moving.
var pointer_hit: Variant = null
## The water brush (scripts/water_brush.gd): poured water is planned on a
## worker and shows while the hand pours (`_pour_live`), one undoable edit.
var water_brush = preload("res://scripts/water_brush.gd").new()
## True from a pour's release until it closes.
var water_settling := false
## Emitted when settled water lands in the world; `bounds` in plate metres.
signal water_settled(bounds: Rect2)
## The water ball (scripts/water_ball.gd): with water in hand a press
## condenses a ball that fills while held; release drops it, and its water
## settles as one pour where it lands. --pour-water brings back drag-to-pour.
var water_ball := "--pour-water" not in OS.get_cmdline_user_args()
var ball: Node3D
## m³ a ball starts with and holds at most. It fills as a pour of the same
## size and flow would (WaterBrush RATE).
const BALL_MIN_VOLUME := 0.6
const BALL_MAX_VOLUME := 24.0
## A new stream stretch that drops at least FALL_DROP m within FALL_REACH m,
## at FALL_SLOPE or steeper, becomes a waterfall; at most FALL_MAX per drop.
const FALL_DROP := 1.2
const FALL_REACH := 2.5
const FALL_SLOPE := 0.8
const FALL_MAX := 2
## A drop of at least LAKE_VOLUME m³ that spreads a pond LAKE_AREA m² across,
## or a pond that swallowed others, is a lake; a new stream at least
## RIVER_LENGTH m long makes the drop a stream.
const LAKE_AREA := 40.0
const LAKE_VOLUME := 12.0
const RIVER_LENGTH := 5.0
var ball_volume := 0.0
var _ball_holding := false
var _ball_serial := 0
## With live water the ball is the ponds' own water (`scoop_ball`): it only
## forms where water stands within SCOOP_REACH m of the press (at least
## SCOOP_DEPTH deep), and it fills by taking the water within SCOOP_RADIUS m
## under it, so the pond drops as the ball grows. The fish swimming within
## SCOOP_FISH_REACH m of it are taken up too, every SCOOP_FISH_SECONDS.
const SCOOP_REACH := 1.5
const SCOOP_DEPTH := 0.04
const SCOOP_RADIUS := 1.6
const SCOOP_FISH_REACH := 2.2
const SCOOP_FISH_SECONDS := 0.25
var _ball_scooping := false
var _scoop_fish_wait := 0.0
## Emitted when a dropped ball's water has settled: {"kind": "waterfall",
## "stream", "lake", "pond" or "soaked", "ponds", "pond_area", "merged",
## "streams", "stream_length", "falls", "fish", "volume"}.
signal ball_settled(outcome: Dictionary)

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	terrain = scene.get_node("Reference/terrain")
	terrain.add_child(pond_preview)
	data.setup(terrain.mesh)
	data.stroke_starting.connect(_join_weathering)
	data.stroke_starting.connect(_mountain_interrupted)
	# Plans run on a worker; the editor's frames must not wait for them.
	emergence.plan_on_worker = true
	_original_ground_map = scene._precipitation.ground_texture.get_image()
	_original_stream_map = scene._precipitation.stream_texture.get_image()
	_original_bird_ground = scene._bird_flight.ground
	_original_precip_top = scene._precipitation._materials[0].get_shader_parameter("top")
	_skirt = scene.get_node("Reference/skirt")
	_skirt.mesh = AtlasView.with_rim_tops(flush_deep_sides(_skirt.mesh,_skirt.position))
	_skirt_mesh = _skirt.mesh
	_landmark_pose = scene._growth._landmark.transform
	for boulder: Dictionary in scene._growth._boulders:
		_boulder_anchors.append(boulder.rest)
	for node in scene.get_node("Reference").get_children():
		if node is VisualInstance3D and node not in [terrain, _skirt]:
			_source_visibility[node] = node.visible
		if not node is MultiMeshInstance3D:
			continue
		var material := node.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		if material == null or material.get_shader_parameter("plant_growth") != true:
			continue
		var transforms: Array[Transform3D] = []
		for i in range(node.multimesh.instance_count):
			transforms.append(node.multimesh.get_instance_transform(i))
		_anchors.append({"node":node,"transforms":transforms,"source":node.multimesh})
	content = GardenView.new()
	content.name = "AuthoredGarden"
	content.data = data
	scene.add_child(content)
	landmarks = NativeGardenLandmarks.new()
	landmarks.name = "AuthoredLandmarks"
	scene.add_child(landmarks)
	falls = NativeGardenFalls.new()
	falls.name = "AuthoredFalls"
	scene.add_child(falls)
	reactions = NativeDropReactions.new()
	reactions.name = "DropReactions"
	scene.add_child(reactions)
	reactions.setup(self)
	selection = NativeObjectSelection.new()
	selection.name = "ObjectSelection"
	scene.add_child(selection)
	selection.setup(self)
	explosives = preload("res://scripts/native_explosives.gd").new()
	explosives.name = "RemoteExplosives"
	scene.add_child(explosives)
	explosives.setup(self)
	_setup_brushes()
	if flow_wanted(): _setup_flow.call_deferred()
	data.state_restored.connect(_world_restored)
	_setup_dandelions()

func _setup_brushes() -> void:
	brushes = {"land":land_brush,"water":water_brush}
	for entry: Dictionary in load("res://scripts/genesis_canvas.gd").BRUSHES:
		if not brushes.has(entry.brush_id): brushes[entry.brush_id] = load(entry.script).new()
	creation_brush().activate(self)

## The tools a shell may offer, grouped as the build panel lays them out.
func tool_groups() -> Array:
	return GROUPS

func tools() -> Array:
	var names: Array = []
	for entry: Array in GROUPS:
		names.append_array(entry[1])
	return names

## The numeric settings a tool reads, in the order a shell should show them.
func settings_for(tool: String) -> Array:
	var found: Array = []
	for entry: Dictionary in SETTINGS:
		if tool in entry.modes:
			found.append(entry)
	return found

## The one-shot commands a tool offers, in the order a shell should show them.
func actions_for(tool: String) -> Array:
	var found: Array = []
	for entry: Dictionary in ACTIONS:
		if entry.tool == tool:
			found.append(entry)
	return found

func setting_spec(property: String) -> Dictionary:
	for entry: Dictionary in SETTINGS:
		if entry.property == property:
			return entry
	return {}

## Nudge a setting from a hotkey or a control; the value snaps into the range
## the setting declares, and every listener hears where it landed.
func set_setting(property: String, number: float) -> void:
	var spec := setting_spec(property)
	if spec.is_empty():
		set(property,number)
		return
	var value := clampf(snappedf(number-spec.low,spec.step)+spec.low,spec.low,spec.high)
	set(property,value)
	if property == "object_heading":
		object_angle = deg_to_rad(object_heading)
	setting_changed.emit(property,value)

func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)

func select_tool(tool: String) -> void:
	finish_stroke()
	pond_preview.clear()
	_fall_start = null
	var next_key := catalog_asset if tool == "assets" else tool if tool in NativeTerrainData.ASSETS or tool == "waterfall" else ""
	if next_key != _placement_key:
		if not _placement_key.is_empty():
			var remembered := {}
			for property: String in PLACEMENT_DEFAULTS: remembered[property] = get(property)
			_placement_settings[_placement_key] = remembered
		if not next_key.is_empty():
			var values: Dictionary = _placement_settings.get(next_key,PLACEMENT_DEFAULTS)
			for property: String in values: set(property,values[property])
		_placement_key = next_key
	mode = tool
	if selection != null:
		selection.update_marker(selected_object_id)
	tool_changed.emit(tool)
	if tool == "land" and brushes.has(brush_id):
		_set_status(load("res://scripts/genesis_canvas.gd").brush_hint(brush_id))
	elif TOOL_TEXT.has(tool):
		_set_status(TOOL_TEXT[tool])

## Radius the terrain shader should draw for the tool in hand.
func preview_radius() -> float:
	if mode == "explosive": return blast_radius
	if mode == "land": return mountain_preview_radius() if mountain_in_hand() else brush_radius()
	if mode == "tunnel": return tunnel_width/2
	if mode == "mountain":
		return mountain_radius
	if mode == "flower":
		return 0.15*object_scale
	if mode in NativeTerrainData.ASSETS or mode == "assets":
		return 0.6*object_scale
	return radius

## The circle only reads truthfully where a footprint exists.
func preview_wanted() -> bool:
	# --modeless: no brush is in hand, so no brush ring on the land.
	if preload("res://scripts/modeless_input.gd").enabled(): return false
	if mode in ["assets","select","pond"]:
		return false
	# Pollen shows its own footprint where the cloud would settle.
	if _pollen_in_hand(): return false
	return mode != "waterfall" or _fall_start == null

func seal_tunnel() -> void:
	_set_tunnel_sealed(true)

func reopen_tunnel() -> void:
	_set_tunnel_sealed(false)

func _set_tunnel_sealed(sealed: bool) -> void:
	if forming or data.tunnels.is_empty(): return
	finish_stroke()
	data.begin_stroke()
	data.tunnels.back().sealed = sealed
	data.end_stroke()
	refresh()
	_set_status("Tunnel sealed · Charges stay buried · X to detonate." if sealed else "Tunnel open · Click inside with Explosive to place a charge.")

func plant_tunnel_charge() -> void:
	if forming or data.tunnels.is_empty() or data.tunnels.back().sealed: return
	finish_stroke()
	data.begin_stroke()
	var id := data.plant_underground(preload("res://scripts/native_tunnels.gd").charge_point(data.tunnels.back()),blast_radius)
	data.end_stroke()
	refresh()
	if id>0:
		explosives.target_id = id
		explosives._sync_list()
		_set_status("Charge planted inside · Seal last tunnel, then X to detonate.")

func detonate_explosives() -> void:
	explosives.request_detonation()

func toggle_explosive_leaves() -> void:
	explosive_leaf_cover = not explosive_leaf_cover
	explosives._sync_settings()
	_set_status("New charges: " + ("hidden under leaves" if explosive_leaf_cover else "uncovered"))

func cover_grass() -> void:
	finish_stroke()
	data.begin_stroke()
	data.grass.fill(grass_amount)
	data.end_stroke()
	refresh()

## Wipe the patches the Blades tool painted, keeping the rest of the cover.
func clear_blades() -> void:
	finish_stroke()
	data.begin_stroke()
	data.blades.fill(0.0)
	data.end_stroke()
	refresh()

func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	finish_stroke()
	pond_preview.clear()
	if enabled and scene._growth.terrain < 0.995:
		active_changed.emit(active)
		return
	_fall_start = null
	active = enabled
	active_changed.emit(active)
	selection.update_marker(selected_object_id)
	scene._orbiting = false
	if active:
		_previous_override = terrain.material_override
		_material = terrain.get_active_material(0).duplicate() as ShaderMaterial
		terrain.material_override = _material
	else:
		terrain.material_override = _previous_override
		_material = null

func handle_input(event: InputEvent) -> bool:
	if forming: return false
	if not active:
		return false
	# --modeless: a left press is never a brush stroke; the land's press is the
	# hand's (scripts/hand_reach.gd `land_pressed`).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and preload("res://scripts/modeless_input.gd").enabled():
		return false
	if event is InputEventKey and event.pressed and not event.echo and mode == "select":
		if event.keycode in [KEY_DELETE,KEY_BACKSPACE]:
			delete_selected()
			return true
		if event.keycode == KEY_D and (event.ctrl_pressed or event.meta_pressed):
			duplicate_selected()
			return true
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed):
		if event.keycode == KEY_Z:
			if event.shift_pressed: redo()
			else: undo()
			return true
		if event.keycode == KEY_Y:
			redo()
			return true
	if event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.meta_pressed:
		# With a creation brush in hand, number keys never pick craft tools; the
		# shell picks brushes with them (studies/cozy_worlds.gd `_creation_key`).
		if mode == "land" and event.keycode >= KEY_1 and event.keycode <= KEY_9: return false
		# [ ] size the brush in hand, Shift+[ ] its strength.
		if mode == "land" and brush_id != "land" and event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			_step_brush_setting(event.shift_pressed,1.0 if event.keycode == KEY_BRACKETRIGHT else -1.0)
			return true
		var tools := {KEY_V:"select",KEY_1:"raise",KEY_2:"lower",KEY_3:"smooth",KEY_4:"flatten"}
		if tools.has(event.keycode) and not event.echo:
			select_tool(tools[event.keycode])
			return true
		if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			var step := 0.25 if event.keycode == KEY_BRACKETRIGHT else -0.25
			var property := "strength" if event.shift_pressed else "radius"
			if mode == "land": property = "land_strength" if event.shift_pressed else "land_radius"
			set_setting(property,get(property)+step)
			return true
		if event.keycode == KEY_K and not event.echo and sky_toggle_requested.has_connections():
			sky_toggle_requested.emit()
			return true
	if mode == "select" and event is InputEventMouseMotion and _selection_drag:
		move_selection_pointer(event.position)
		return true
	if mode == "land" and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		return _land_press(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			finish_stroke()
			return true
		if mode == "select":
			select_object(pick_object(event.position))
			if selected_object_id > 0:
				_selection_press = event.position
				var ground: Variant = pick(event.position)
				var item := selected_object()
				_selection_plane_y = terrain.to_global(Vector3(item.x,data.sample(Vector2(item.x,item.z),data.heights),item.z)).y
				if item.asset == "log" and not data.void_faces.is_empty():
					var plane_point: Variant = Plane(Vector3.UP,_selection_plane_y).intersects_ray(scene.camera.project_ray_origin(event.position),scene.camera.project_ray_normal(event.position))
					ground = terrain.to_local(plane_point) if plane_point != null else null
				if ground == null:
					var camera: Camera3D = scene.camera
					var anchor := terrain.to_global(data.object_position(item))
					var plane_hit: Variant = Plane(Vector3.UP,anchor.y).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
					if plane_hit != null:
						ground = terrain.to_local(plane_hit)
				_selection_offset = Vector2(item.x-ground.x,item.z-ground.z) if ground != null else Vector2.ZERO
				_selection_drag = true
			return true
		place_at(event.position)
		return true
	return false

## Apply the tool in hand at a mouse point, exactly as a left press does. The
## palette's drag-and-drop commits through here so a dropped object takes the
## same record, pose and reaction a click would have given it.
func place_at(mouse: Vector2) -> bool:
	if forming or not active or mode in ["select","ground","range"]:
		return false
	var hit: Variant = pick(mouse)
	if hit == null:
		return false
	if mode == "tunnel":
		finish_stroke()
		var direction: Vector3 = terrain.global_basis.inverse()*scene.camera.project_ray_normal(mouse)
		var tunnel := preload("res://scripts/native_tunnels.gd").plan(data,hit,direction,tunnel_width,tunnel_depth)
		if tunnel.is_empty():
			_set_status("Aim into a steep mountainside with enough rock behind it. Keep tunnels separate; up to six per world.")
			return false
		data.begin_stroke()
		data.tunnels.append(tunnel)
		data.end_stroke()
		refresh()
		_set_status("Tunnel open · Plant a charge inside, then seal it.")
		return true
	if mode == "waterfall":
		var point := Vector2(hit.x,hit.z)
		if _fall_start == null:
			_fall_start = point
			_set_status("Now click the lower landing point. Change tools to cancel.")
		else:
			data.begin_stroke()
			var span := data.add_waterfall(_fall_start,point,object_scale)
			data.end_stroke()
			if span:
				_fall_start = null
				refresh()
			else:
				_set_status("Choose a lower landing with no ridge blocking the drop.")
		return true
	data.begin_stroke()
	_stroke_first_id = data.next_id
	_stroke_rect = Rect2()
	if placement_trail and trail_available():
		_painting = true
		_trail_point = Vector2(hit.x,hit.z)
		trail_dab(_trail_point)
		refresh()
		_emit_stroke(0,hit,preview_radius(),0.0)
		return true
	_level = hit.y
	_last_point = Vector2(hit.x,hit.z)
	var placed := -1
	var pond_filled := false
	if mode in NativeTerrainData.ASSETS or mode in ["pond","mountain","assets"]:
		if mode == "mountain":
			data.mountain(_last_point,mountain_radius,mountain_peak,mountain_variation,deg_to_rad(mountain_heading))
			_emit_stroke(0,hit,mountain_radius,0.0)
			_emit_stroke(2,hit,mountain_radius,0.0)
		elif mode == "pond":
			var plan: Dictionary = pond_preview.evaluate(data,_last_point,pond_level)
			if plan.vertices.is_empty(): _set_status(plan.message)
			elif data.add_pond(_last_point,pond_level): pond_filled = true
			else: _set_status("This diorama has reached its pond limit. Remove a pond before adding another.")
		else:
			if mode == "explosive" and data.ground_height(_last_point) != null and hit.y < data.ground_height(_last_point)-0.1:
				placed = data.plant_underground(hit,blast_radius)
			else:
				placed = data.place(catalog_asset if mode == "assets" else mode,_last_point,object_angle,object_scale,_placement_pose(),preload("res://scripts/native_object_pose.gd").encode_tint(object_tint.srgb_to_linear()) if custom_tint and mode in ["tree","flower","rock","assets"] else "")
			if placed > 0 and mode == "explosive":
				data.update_object(placed,{"blast_radius":blast_radius,"leaf_cover":explosive_leaf_cover})
			if placed < 0:
				_set_status("Up to 32 charges can be armed at once. Detonate or remove one first." if mode == "explosive" else "This garden has reached its object limit.")
		data.mark_objects_hand(_stroke_first_id)
		if mode == "mountain": _touch(_last_point,mountain_radius)
		elif pond_filled: _touch(_last_point,7.0)
		if data.end_stroke():
			_stroke_ended()
			_stroke_rect = Rect2()
			refresh()
			if pond_filled: _set_status("Pond filled. Dig a hollow to shape its banks; Undo removes the water.")
			if placed > 0 and reactions_enabled and mode != "explosive":
				# `placed` is the id this click just minted, and only a click
				# reaches here. Handing it to the reaction is what keeps a redo
				# or a load — which re-render records that already exist — from
				# replaying the sprout or the drop.
				var record: Dictionary = data.objects.back()
				reactions.play(record.asset,reactions.record_pose(record),record,placed)
	else:
		_painting = true
		dab(_last_point,strength/30.0)
		refresh()
		_emit_stroke(0,hit,radius,0.0)
		_emit_stroke(1,hit,radius,strength/30.0)
	return true

## Trails share the normal stroke transaction: one drag is one undo step.
func trail_available() -> bool:
	return mode in ["flower","mountain"] or (mode == "assets" and catalog_asset in ["button_flower","daisy_flower","spike_flower","umbel_flower","oxeye_daisy","buttercup","dandelion","dandelion_clock","cosmos","sunflower","poppy","lupine"])

func trail_spacing() -> float:
	return mountain_radius*0.45 if mode == "mountain" else maxf(0.2,object_scale*0.45)

func continue_trail(center: Vector2) -> void:
	if _trail_point == null:
		_trail_point = center
		trail_dab(center)
		refresh()
		return
	var previous: Vector2 = _trail_point
	var spacing := trail_spacing()
	var count := mini(128,int(previous.distance_to(center)/spacing))
	if count == 0: return
	var direction := previous.direction_to(center)
	for i in range(1,count+1):
		trail_dab(previous+direction*spacing*i)
	_trail_point = previous+direction*spacing*count
	refresh()

func trail_dab(point: Vector2) -> void:
	if mode == "mountain":
		data.mountain(point,mountain_radius,mountain_peak,mountain_variation,deg_to_rad(mountain_heading))
		_touch(point,mountain_radius)
	else:
		data.place(catalog_asset if mode == "assets" else mode,point,object_angle,object_scale,_placement_pose(),preload("res://scripts/native_object_pose.gd").encode_tint(object_tint.srgb_to_linear()) if custom_tint else "")

func pointer_in_world(mouse: Vector2) -> bool:
	if explosives != null and explosives.contains(mouse): return false
	if scene._landscape_editor != null and scene._landscape_editor.is_visible_in_tree() and scene._landscape_editor.get_global_rect().has_point(mouse): return false
	if scene._look_editor != null and scene._look_editor.is_visible_in_tree() and scene._look_editor.get_global_rect().has_point(mouse): return false
	if scene._growth.terrain < 0.995 or not scene.get_viewport().get_visible_rect().has_point(mouse):
		return false
	if scene.has_method("blocks_world_input") and scene.blocks_world_input(mouse):
		return false
	for child in scene._ui.get_children():
		if child is Control and scene._ui.visible and child.is_visible_in_tree():
			if child is NativeBuildPalette:
				if child.contains_pointer(mouse): return false
			elif child.get_global_rect().has_point(mouse):
				return false
	return true

func pick(mouse: Vector2) -> Variant:
	if not pointer_in_world(mouse):
		return null
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(mouse))
	var direction := terrain.global_basis.inverse()*camera.project_ray_normal(mouse)
	return data.ray_hit(origin,direction.normalized())

## Microseconds the last frame's emergence step took, for profiles.
var last_emergence_usec := 0

func _process(delta: float) -> void:
	# Emergence refreshes yield like a stroke's settle: the worker samples
	# instances and the budget spreads the rest, so a step never stalls a frame.
	var began := Time.get_ticks_usec()
	var stepped: bool = not forming and emergence.advance(delta)
	last_emergence_usec = Time.get_ticks_usec()-began
	if stepped: refresh(get_tree())
	_warm_face_probes()
	_flow_process(delta)
	if forming or not active:
		pond_preview.clear()
		pointer_hit = null
		return
	if (_painting or _selection_drag) and (not Input.is_mouse_button_pressed(_stroke_button) or scene._growth.terrain < 0.995):
		finish_stroke()
	var pointer: Vector2 = pointer_override if pointer_override != null else scene.get_viewport().get_mouse_position()
	var hit: Variant = pick(pointer) if not scene._orbiting and not scene._panning else null
	pointer_hit = hit
	if mode == "pond":
		var message: String = pond_preview.hover(data,hit,pond_level,delta)
		if not message.is_empty() and message != status: _set_status(message)
	# A held water ball shows where it will land with its own mark.
	_material.set_shader_parameter("brush_visible",hit != null and preview_wanted() and (ball == null or ball.state == "idle"))
	if _ball_holding:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or scene._growth.terrain < 0.995: _ball_release()
		else: _ball_step(hit,delta)
	_handful_process(hit,delta)
	_flower_paint_process(hit,delta)
	if _painting and _mountain_holding: _mountain_step(pointer,delta)
	if gust != null: _gust_process(hit)
	if can != null and hit != null: can.pointer = hit
	if hit != null:
		var center := Vector2(hit.x,hit.z)
		_material.set_shader_parameter("brush_center",center)
		_material.set_shader_parameter("brush_radius",preview_radius())
		if _painting and placement_trail and trail_available():
			continue_trail(center)
			_emit_stroke(1,hit,preview_radius(),delta)
		elif _painting and mode == "land":
			# A held mountain steps above, even off the terrain.
			if not _mountain_holding:
				_land_step(center,delta)
				_emit_stroke(1,hit,brush_radius(),brush_strength()*delta)
		elif _painting:
			_elapsed += minf(delta,0.05)
			if _elapsed >= 1.0/30.0:
				var previous: Vector2 = _last_point if _last_point != null else center
				var dabs := maxi(1,ceili(previous.distance_to(center)/(radius*0.15)))
				for i in range(1,dabs+1):
					dab(previous.lerp(center,float(i)/dabs),strength*_elapsed/dabs)
				refresh()
				_emit_stroke(1,hit,radius,strength*_elapsed)
				_elapsed = 0.0
				_last_point = center
	else:
		_last_point = null
		_trail_point = null
		_elapsed = 0.0

## A recipe world's first sculpting dab needs the per-face slope probes. They
## are dropped whenever the sample cache fills, and resolving them on the main
## thread cost that dab about 70 ms, so keep them ready on a worker instead.
var _warming_probes := false
func _warm_face_probes() -> void:
	if _warming_probes or forming or data._recipe == null or data._face_probe.size() == data._face_center.size()*4: return
	_warming_probes = true
	await data._prepare_face_probes(get_tree())
	_warming_probes = false

func finish_pointer_gesture() -> void:
	if _selection_drag or _painting:
		finish_stroke()

func finish_stroke() -> void:
	if _ball_holding: _ball_release()
	if _handful_holding: _handful_release()
	if flower_paint != null: paint_flowers_end()
	_selection_drag = false
	end_selection_edit()
	if not _painting:
		return
	_painting = false
	_trail_point = null
	_elapsed = 0.0
	_last_point = null
	if _mountain_holding:
		_mountain_holding = false
		_stroke_button = MOUSE_BUTTON_LEFT
		_mountain_rise()
		return
	# The land brush weathers on a worker; the settle waits for it to land.
	var region: Rect2 = land_brush.bounds
	var weathering: Callable = land_brush.weather_job(data) if mode == "land" and brush_id == "land" else Callable()
	var weathered := _weather_land()
	_stroke_button = MOUSE_BUTTON_LEFT
	data.mark_objects_hand(_stroke_first_id)
	# A pour keeps its undo step open until its last plan lands.
	var pouring: bool = mode == "land" and creation_brush().settles
	var changed := data.end_stroke() if not pouring else false
	# Weathering lands after the last light dab, so the settle refresh pays it.
	if weathered: _settle_pending = true
	if changed and weathering.is_valid(): _weather_async(weathering,region)
	else: _settle_stroke()
	if changed: _stroke_ended()
	_stroke_rect = Rect2()
	stroke_finished.emit(_stroke_center,_stroke_radius,stroke_mode())
	if pouring: _release_pour()

## Hand a finished stroke's ground to emergence. Kept as one call so the
## stroke_finished signal can take it over. The player's ground is tended:
## live water changing there soon after grows too (`_flow_moved`).
func _stroke_ended(kind := "") -> void:
	_tend(_stroke_rect)
	if emergence_enabled and _stroke_rect.has_area():
		emergence.on_region_changed(_stroke_rect,stroke_mode() if kind.is_empty() else kind)

func _touch(point: Vector2, reach: float) -> void:
	var area := Rect2(point-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
	_stroke_rect = _stroke_rect.merge(area) if _stroke_rect.has_area() else area

## `phase` 0 starts, 1 moves, 2 finishes; `hit` is terrain-local.
func _emit_stroke(phase: int, hit: Vector3, size: float, amount: float) -> void:
	_stroke_center = terrain.to_global(hit)
	_stroke_radius = size*terrain.global_basis.get_scale().x
	match phase:
		0: stroke_started.emit(_stroke_center,_stroke_radius,stroke_mode())
		1: stroke_moved.emit(_stroke_center,_stroke_radius,stroke_mode(),amount)
		_: stroke_finished.emit(_stroke_center,_stroke_radius,stroke_mode())

func undo() -> void:
	_history_step(false)

func redo() -> void:
	_history_step(true)

func _history_step(forward: bool) -> void:
	if forming: return
	# A pour closes on what is showing, so undo takes it back whole.
	_commit_pour()
	explosives.clear_effects()
	_fall_start = null
	finish_stroke()
	if handful != null: handful.settle_now()
	if spring != null: spring.land_now()
	if clay != null: clay.finish_now()
	_land_mountain()
	# A land stroke's weathering belongs to the world being left.
	_drop_weathering()
	if scene.has_method("_finish_fire_stroke"): scene._finish_fire_stroke()
	var history: Array = data._redo if forward else data._undo
	if history.is_empty(): return
	var operation := {}
	for key in ["fire","explosion"]:
		if history.back().get(key,false): operation[key] = true
	var saved_scene: Dictionary = history.back().get("favorite_scene",{})
	var inverse := NativeGardenStore.capture(scene) if not saved_scene.is_empty() else {}
	if data.redo() if forward else data.undo():
		var other: Array = data._undo if forward else data._redo
		other.back().merge(operation)
		if forward and operation.get("explosion",false) and scene.has_method("_continue_blast_fire"):
			var field: FireField = scene._fire_field
			if field.active(): scene._continue_blast_fire()
		if not saved_scene.is_empty():
			other.back()["favorite_scene"] = inverse
		refresh()
		if not saved_scene.is_empty(): _restore_favorite_scene(saved_scene)

func _restore_favorite_scene(state: Dictionary) -> void:
	var panel_visible: bool = scene._landscape_editor != null and scene._landscape_editor.visible
	NativeGardenStore.restore(scene,state)
	scene._update_camera()
	if panel_visible: scene._landscape_editor.show()

func restore_landscape_favorite(library: RefCounted,id: String,live := true) -> bool:
	if forming: return false
	finish_stroke()
	var prepared: Dictionary = library.prepare(scene,id)
	if prepared.is_empty():
		_set_status("Could not open that favorite. Your landscape is unchanged.")
		return false
	forming = true
	formation_started.emit()
	_fall_start = null
	selected_object_id = -1
	data.begin_stroke()
	data._before["favorite_scene"] = NativeGardenStore.capture(scene)
	data._restore(prepared.terrain)
	data.end_stroke()
	await refresh(get_tree() if live else null)
	_restore_favorite_scene(prepared.scene)
	forming = false
	_set_status("Favorite restored · Undo restores your previous landscape and look.")
	return true

var last_refresh_usec := {}
var refresh_stage := ""
var _refresh_generation := 0

## Optional publication hook runs before yielding, as each visual source swaps.
## Destruction uses it to reveal already prepared debris in the same frame.
## False means a stage was rejected or superseded. Earlier stages can already
## be visible; callers requiring a complete transaction must retry or abandon it.
var refresh_pending := 0
func refresh(frame_tree: SceneTree = null, on_publish: Callable = Callable()) -> bool:
	if border_pin != null: border_pin.apply(data)
	if frame_tree == null and not on_publish.is_valid() and _light_refresh_ready():
		return await _refresh_light()
	refresh_pending += 1
	_refresh_generation += 1
	var generation := _refresh_generation
	# Invalidate older downstream work before this request waits on its mesh.
	content.cancel_rebuild()
	_map_generation += 1
	last_refresh_usec.clear()
	refresh_stage = "mesh"
	var stage_start := Time.get_ticks_usec()
	preload("res://scripts/world_reference_props.gd").before_refresh(self)
	pond_preview.clear()
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	if not forming: _set_status("Garden changed · Save to keep your work.")
	var target_data := data
	var snapshot_start := Time.get_ticks_usec()
	var inputs: Dictionary = data._snapshot() if frame_tree != null else {}
	last_refresh_usec.input_snapshot = Time.get_ticks_usec()-snapshot_start
	var current := _refresh_current.bind(generation,target_data,inputs)
	var prepared_mesh: ArrayMesh = await target_data.build_mesh_budgeted(false,frame_tree)
	if prepared_mesh == null or not current.call(): return _finish_refresh(false)
	terrain.mesh = data.play_mesh(prepared_mesh)
	if on_publish.is_valid(): on_publish.call("terrain")
	if not current.call(): return _finish_refresh(false)
	last_refresh_usec["mesh_elapsed"] = Time.get_ticks_usec()-stage_start
	refresh_stage = "anchors"
	stage_start = Time.get_ticks_usec()
	var original := data.heights == data.original_heights
	# Anchors and skirt follow the heights alone. Growth and cover refreshes
	# (emergence steps) leave them where the last refresh lifted them.
	var lift_key := _lift_key()
	var lifted := lift_key != _lifted_for
	if lifted: _lift_anchors(original)
	# Hide what the plate replaces in the same frame the anchors show it: a
	# yield between the two drew the source chunk's whole forest for a frame
	# on a blank plate (the flicker when a pollen cloud settled).
	sync_visibility()
	if frame_tree != null and lifted:
		await budget.checkpoint()
		if not current.call(): return _finish_refresh(false)
	if lifted:
		_rebuild_skirt()
		_lifted_for = lift_key
	if frame_tree != null:
		await budget.checkpoint()
		if not current.call(): return _finish_refresh(false)
	last_refresh_usec["anchors_elapsed"] = Time.get_ticks_usec()-stage_start
	refresh_stage = "content"
	stage_start = Time.get_ticks_usec()
	if not await content.rebuild(false,frame_tree) or not current.call(): return _finish_refresh(false)
	if on_publish.is_valid(): on_publish.call("content")
	if not current.call(): return _finish_refresh(false)
	if frame_tree != null:
		await budget.checkpoint()
		if not current.call(): return _finish_refresh(false)
	last_refresh_usec["content_elapsed"] = Time.get_ticks_usec()-stage_start
	refresh_stage = "landmarks"
	stage_start = Time.get_ticks_usec()
	_settle_bedding_cover()
	landmarks.rebuild(data)
	falls.rebuild(data)
	if on_publish.is_valid(): on_publish.call("landmarks")
	if not current.call(): return _finish_refresh(false)
	if frame_tree != null:
		await budget.checkpoint()
		if not current.call(): return _finish_refresh(false)
	last_refresh_usec["landmarks_elapsed"] = Time.get_ticks_usec()-stage_start
	refresh_stage = "maps"
	stage_start = Time.get_ticks_usec()
	var fall_count := 0
	for item: Dictionary in data.objects:
		if item.asset == "waterfall":
			fall_count += 1
	if falls.get_child_count()/2 < fall_count:
		_set_status("A waterfall is blocked or submerged. Lower the obstruction or undo.")
	# Existing habitat/rain/fog consumers keep the same texture object.
	if not await _update_surface_maps(original,frame_tree) or not current.call(): return _finish_refresh(false)
	last_refresh_usec["maps_elapsed"] = Time.get_ticks_usec()-stage_start
	refresh_stage = "post_maps"
	stage_start = Time.get_ticks_usec()
	if update_encounter_ground and terrain.mesh != _bigfoot_mesh:
		_bigfoot_mesh = terrain.mesh
		if frame_tree != null: _setup_encounter_ground(terrain.mesh)
		else: scene._bigfoot.ground.setup(terrain)
	var encounter_pose: Variant = null
	for item: Dictionary in data.objects:
		if item.asset == "bigfoot_tree":
			encounter_pose = Transform3D(Basis(Vector3.UP,item.angle).scaled(Vector3.ONE*item.scale),data.object_position(item))
			break
	scene._bigfoot.set_authored_tree(encounter_pose)
	scene._bird_flight.ground = _original_bird_ground if original else data
	scene._atmosphere.update_ground_bounds(terrain,original)
	scene._precipitation.set_ceiling(_original_precip_top if original else scene._atmosphere._summit.y + scene._precipitation.SKY_CLEARANCE)
	if scene._display_fog != null:
		scene._display_fog.update_view()
	if selection != null:
		if selected_object().is_empty():
			selected_object_id = -1
		selection.update_marker(selected_object_id)
		selection_changed.emit(selected_object_id)
	if not current.call(): return _finish_refresh(false)
	last_refresh_usec["post_maps_elapsed"] = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()

	_notify_play_geometry()
	if not current.call(): return _finish_refresh(false)
	refresh_stage = ""

	return _finish_refresh(true)

## A yielding refresh buckets the encounter ground's triangles on a worker
## (about 3-4 ms on the main thread) and adopts them a frame or two later,
## unless a newer terrain mesh has been published meanwhile.
func _setup_encounter_ground(mesh: Mesh) -> void:
	var ground = scene._bigfoot.ground
	var prepared: Dictionary = ground.prepare(terrain)
	var job = preload("res://scripts/background_work.gd").new()
	var built: Dictionary = await job.run(func() -> Dictionary: return preload("res://scripts/reference_ground.gd").build(prepared),get_tree())
	if _bigfoot_mesh == mesh and is_instance_valid(scene) and scene._bigfoot.ground == ground: ground.adopt(built)

## The heights (and rim state) anchors and skirt were last lifted for.
var _lifted_for: Array = []

## Copies, not the live arrays: a packed array held in the key is the same
## array the data edits in place, so the key would always match and a change
## made outside a stroke (erosion at the rim) left the sides standing proud.
func _lift_key() -> Array:
	return [data,data.heights.duplicate(),data.blank,open_sides.duplicate(),data.void_faces.is_empty()]

func _finish_refresh(published: bool) -> bool:
	refresh_pending -= 1
	if published:
		_settle_pending = false
		_settled_objects_revision = data.objects_revision
		_settled_blades = data.blades.duplicate()
		_settled_meadow = data.meadow.duplicate()
	return published

## The source chunk's own plants, boulders and landmark ride the sculpted ground.
func _lift_anchors(original: bool) -> void:
	for entry in _anchors:
		if data.blank:
			continue
		var node: MultiMeshInstance3D = entry.node
		if original:
			node.multimesh = entry.source
			continue
		if node.multimesh == entry.source:
			node.multimesh = entry.source.duplicate()
		for i in range(entry.transforms.size()):
			var transform: Transform3D = entry.transforms[i]
			var world := node.to_global(transform.origin)
			var local := terrain.to_local(world)
			world.y += data.delta_at(Vector2(local.x,local.z))
			transform.origin = node.to_local(world)
			node.multimesh.set_instance_transform(i,transform)
	for node: VisualInstance3D in _source_visibility:
		node.visible = _source_visibility[node]
	for i in range(_boulder_anchors.size()):
		var rest := _boulder_anchors[i]
		rest.origin.y += data.delta_at(Vector2(rest.origin.x, rest.origin.z))
		scene._growth._boulders[i].rest = rest
	var landmark := _landmark_pose
	landmark.origin.y += data.delta_at(Vector2(landmark.origin.x, landmark.origin.z))
	scene._growth._landmark.transform = landmark
	scene._growth.publish()

## A held brush publishes only what it visibly moves: terrain faces, and the
## plants, props and landmarks standing on them. The water flood and surfaces,
## surface maps, atmosphere bounds, collision and navigation wait for the full
## refresh `finish_stroke` starts. That refresh diffs every cache against the
## last full one, so it settles on exactly what a full refresh per dab leaves.
## Painted cover shows on the terrain faces and fills in with plants at release.
## Edits only instances can show - object records, standing blades, or meadow
## on the source chunk, whose faces ignore it - keep the full path per dab.
var _settle_pending := false
var _settled_objects_revision := -1
var _settled_blades := PackedFloat32Array()
var _settled_meadow := PackedFloat32Array()

func _light_refresh_ready(shaping := false) -> bool:
	if not (_painting or shaping) or forming or not content._view_ready: return false
	return data.objects_revision == _settled_objects_revision and data.blades == _settled_blades and (data.blank or data.meadow == _settled_meadow)

func _refresh_light() -> bool:
	refresh_pending += 1
	_refresh_generation += 1
	# Supersede a settle still yielding from an earlier stroke. It re-runs at
	# this stroke's end over the union of both.
	content.cancel_rebuild()
	_map_generation += 1
	last_refresh_usec.clear()
	var stage_start := Time.get_ticks_usec()
	preload("res://scripts/world_reference_props.gd").before_refresh(self)
	pond_preview.clear()
	_set_status("Garden changed · Save to keep your work.")
	data.defer_shoreline = true
	terrain.mesh = data.play_mesh(data.build_mesh())
	data.defer_shoreline = false
	last_refresh_usec["mesh_elapsed"] = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	_lift_anchors(data.heights == data.original_heights)
	sync_visibility()
	_rebuild_skirt()
	_lifted_for = _lift_key()
	last_refresh_usec["anchors_elapsed"] = Time.get_ticks_usec()-stage_start
	stage_start = Time.get_ticks_usec()
	if not content.lift_instances():
		# The lift cannot be localised; rebuild the view from the records.
		content.discard_cache()
		refresh_pending -= 1
		return await refresh()
	_settle_bedding_cover()
	landmarks.lift(data)
	last_refresh_usec["content_elapsed"] = Time.get_ticks_usec()-stage_start
	# Tell play systems once, on the stroke's first dab, so carried props and
	# walking routes let go before the ground moves under them; they hear
	# again when the stroke settles.
	stage_start = Time.get_ticks_usec()
	if not _settle_pending:
		_settle_pending = true
		_notify_play_geometry()
	last_refresh_usec["notify_elapsed"] = Time.get_ticks_usec()-stage_start
	refresh_pending -= 1
	return true

func _settle_stroke() -> void:
	if _settle_pending and not forming:
		refresh(get_tree())

func _refresh_current(generation: int, target: NativeTerrainData, inputs: Dictionary) -> bool:
	if generation != _refresh_generation or data != target: return false
	var began := Time.get_ticks_usec()
	var matches := true
	for field in inputs:
		var value: Variant = data._recipe_settings if field == "terrain_recipe" else data.get(field)
		if value != inputs[field]:
			matches = false
			break
	# Direct edits need not bump object revisions. Even if content was already
	# published, the next ordinary refresh must rebuild it from current inputs.
	if not matches: content.discard_cache()
	last_refresh_usec.input_validation = last_refresh_usec.get("input_validation",0)+Time.get_ticks_usec()-began
	return matches

## Rebuild everything from the records, ignoring every incremental cache. The
## incremental path must land on exactly this result; the regression test drives
## a stroke both ways and compares the meshes, instances and map bytes.
## A leaf bed presses the original soft bank cover flat beneath it. Derive this
## from bed records on every refresh: deleting/moving/undoing a bed restores the
## source cover, and the imported MultiMesh resource is never mutated.
func _settle_bedding_cover() -> void:
	var beds: Array[Dictionary] = []
	for record in data.objects:
		if record.asset == "leaf_bed": beds.append(record)
	if beds.is_empty() or data.blank: return
	for entry in _anchors:
		var node: MultiMeshInstance3D = entry.node
		if node.name not in ["mesh-14","mesh-15"]: continue
		node.multimesh = node.multimesh.duplicate()
		for i in range(node.multimesh.instance_count):
			var pose := node.multimesh.get_instance_transform(i)
			var root := node.to_global(pose.origin)
			for bed in beds:
				var center := data.object_position(bed)
				var size := NativeObjectPose.decode_basis(bed.pose).get_scale() if bed.has("pose") else Vector3.ONE*float(bed.scale)
				if Vector2(root.x-center.x,root.z-center.z).length()>maxf(size.x,size.z)+0.3 or absf(root.y-center.y)>0.6: continue
				var normal := NativeObjectPose.decode_basis(bed.pose).y.normalized() if bed.has("pose") else Vector3.UP
				if normal.y<0.4: continue
				# Lay the cover along the bed's fitted bank plane. Flattening each
				# clump horizontally would leave its downhill edge over the bed.
				root.y = center.y-(normal.x*(root.x-center.x)+normal.z*(root.z-center.z))/normal.y-0.04
				pose.origin = node.to_local(root)
				pose.basis = Basis(Quaternion(Vector3.UP,normal))*Basis.from_scale(Vector3(1,0.015,1))*pose.basis
				node.multimesh.set_instance_transform(i,pose)
				break

func force_refresh() -> void:
	data.discard_cache()
	content.discard_cache()
	falls.discard_cache()
	_map_ready = false
	_bigfoot_mesh = null
	refresh()

## Resample only the map pixels the edit can reach. The height pass is kept in
## `_map_base`; both overlays are per-pixel functions of that base, so repainting
## the changed rectangle over the previous finished maps reproduces them exactly.
## Large live edits use private worker images; fewer than 256 pixels finish
## synchronously so a tiny patch cannot yield while mutating the live cache.
func _update_surface_maps(original: bool, frame_tree: SceneTree = null) -> bool:
	_map_generation += 1
	var generation := _map_generation
	var target := data
	if frame_tree != null:
		while _map_busy:
			await frame_tree.process_frame
			if generation != _map_generation or data != target: return false
	last_surface_profile = {}
	var size := _original_ground_map.get_width()
	var reusable: bool = _map_ready and _map_blank == data.blank and _map_original == original
	var water_changed: bool = not _map_ready or _map_revision != content.revision
	var water_region: Variant = _surface_water_region() if water_changed else _map_water_region
	var region: Variant = data.moved_region(_map_heights) if reusable else null
	if reusable and water_changed:
		# Restore both the old and new overlay footprints, including removals and
		# shrinking shores. A content revision need not invalidate the whole map.
		region = _merge_surface_regions(region,_merge_surface_regions(_map_water_region,water_region))
	if region is bool and reusable:
		_map_revision = content.revision
		_map_water_region = water_region
		return true
	var clip := Rect2i(0,0,size,size)
	if region != null:
		var low: Vector2 = (region.position+Vector2.ONE*16.0)/32.0*float(size)-Vector2.ONE*0.5
		var high: Vector2 = (region.end+Vector2.ONE*16.0)/32.0*float(size)-Vector2.ONE*0.5
		clip = Rect2i(Vector2i(clampi(floori(low.x),0,size),clampi(floori(low.y),0,size)),Vector2i.ZERO)
		clip = clip.expand(Vector2i(clampi(ceili(high.x)+1,0,size),clampi(ceili(high.y)+1,0,size)))
	var image: Image
	var streams: Image
	if frame_tree != null and clip.get_area() >= 256:
		_map_busy = true
		var sampled_heights := data.heights.duplicate()
		var sampled_revision := content.revision
		var sampled_blank := data.blank
		var base: Image = _original_ground_map.duplicate() if region == null else _map_base
		var previous_ground: Image = base if region == null else _map_ground
		var previous_stream: Image = _original_stream_map if region == null else _map_stream
		var samples := GardenSurfaceMap.stream_samples(content._stream_nodes)
		var prepared: Dictionary = await preload("res://scripts/native_surface_samples.gd").build_parallel(data,original,_original_ground_map,_original_stream_map,base,previous_ground,previous_stream,content.pond_vertices,samples,clip,frame_tree,surface_workers)
		_map_busy = false
		if generation != _map_generation or data != target: return false
		if data.heights != sampled_heights or content.revision != sampled_revision or data.blank != sampled_blank: return false
		_map_base = prepared.base
		image = prepared.ground
		streams = prepared.stream
		last_surface_profile = {"workers":prepared.workers,"worker":prepared.worker,"submit_usec":prepared.submit_usec,"worker_usec":prepared.worker_usec}
	else:
		if region == null:
			_map_base = _original_ground_map.duplicate()
		for z in range(clip.position.y,clip.end.y):
			for x in range(clip.position.x,clip.end.x):
				if original and not data.blank:
					continue
				var point := (Vector2(x,z)+Vector2.ONE*0.5)/float(size)*32.0-Vector2.ONE*16.0
				var height: Variant = data.height_at(point.x,point.y)
				var value := Color(-1000,-1000,-1000,-1000) if data.blank else _original_ground_map.get_pixel(x,z)
				value.g = float(height) if height != null else -1000.0
				value.r = maxf(value.g,value.a)
				_map_base.set_pixel(x,z,value)
		if region == null:
			image = _map_base.duplicate()
			streams = _original_stream_map.duplicate()
			if data.blank:
				streams.fill(Color(0,0,0,0))
		else:
			image = _map_ground
			streams = _map_stream
			for z in range(clip.position.y,clip.end.y):
				for x in range(clip.position.x,clip.end.x):
					image.set_pixel(x,z,_map_base.get_pixel(x,z))
					streams.set_pixel(x,z,Color(0,0,0,0) if data.blank else _original_stream_map.get_pixel(x,z))
		GardenSurfaceMap.paint_water(image,content.pond_vertices,clip)
		GardenSurfaceMap.paint_streams(image,streams,content._stream_nodes,clip)
	scene._precipitation.ground_texture.update(image)
	scene._precipitation.stream_texture.update(streams)
	_map_ground = image
	_map_stream = streams
	_map_heights = data.heights.duplicate()
	_map_revision = content.revision
	_map_water_region = water_region
	_map_blank = data.blank
	_map_original = original
	_map_ready = true

	return true

## Bounds use the same coordinates as GardenSurfaceMap's triangle samplers.
## false is an empty overlay; null requests the conservative full-map fallback.
func _surface_water_region() -> Variant:
	var region: Variant = false
	for vertex: Vector3 in content.pond_vertices:
		if not vertex.is_finite(): return null
		var point := Vector2(vertex.x,vertex.z)
		region = region.expand(point) if region is Rect2 else Rect2(point,Vector2.ZERO)
	for node: MeshInstance3D in content._stream_nodes:
		if not is_instance_valid(node) or node.mesh == null: return null
		var box: AABB = node.transform*node.mesh.get_aabb()
		if not box.position.is_finite() or not box.end.is_finite(): return null
		var reach := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
		region = _merge_surface_regions(region,reach)
	return region

func _merge_surface_regions(a: Variant,b: Variant) -> Variant:
	if a == null or b == null: return null
	if a is bool: return b
	if b is bool: return a
	return a.merge(b)

func _placement_pose() -> Dictionary:
	if mode not in ["tree","flower","rock","assets"] or (object_width == 1.0 and object_height == 1.0 and object_depth == 1.0 and object_pitch == 0.0 and object_roll == 0.0 and object_elevation == 0.0):
		return {}
	var basis := Basis.from_euler(Vector3(deg_to_rad(object_pitch),object_angle,deg_to_rad(object_roll)))
	basis = basis.scaled_local(Vector3(object_width,object_height,object_depth)*object_scale)
	return preload("res://scripts/native_object_pose.gd").make(basis,object_elevation)

## Palette actions use the yielding path; offline callers can still form a
## complete world synchronously. Lock writes until all dependent views agree.
func perform_action(method: String) -> void:
	if forming: return
	if method == "form_range": await form_range(true)
	elif method == "form_foundation": await form_foundation(true)
	else: call(method)

func form_range(live := false) -> void:
	if forming: return
	finish_stroke()
	_fall_start = null
	forming = live
	if live:
		formation_started.emit()
		_set_status("Forming mountain landscape…")
	data.begin_stroke()
	await data.form_range(range_height,range_width,deg_to_rad(range_heading),range_variation,get_tree() if live else null)
	data.end_stroke()
	await refresh(get_tree() if live else null)
	forming = false
	_set_status("Mountain landscape formed, including basin and stream beds. Paint and place to dress it.")

func form_foundation(live := false) -> void:
	if forming: return
	finish_stroke()
	_fall_start = null
	forming = live
	if live:
		formation_started.emit()
		_set_status("Forming ground…")
	data.begin_stroke()
	await data.form_foundation(ground_elevation,ground_relief,get_tree() if live else null)
	data.end_stroke()
	await refresh(get_tree() if live else null)
	forming = false
	_set_status("Ground formed. Grass paints its surface; sculpting changes its height.")

func start_flat() -> void:
	if forming: return
	_fall_start = null
	finish_stroke()
	data.begin_stroke()
	data.reset_flat()
	data.end_stroke()
	refresh()

func _rebuild_skirt() -> void:
	_skirt.visible = data.void_faces.is_empty()
	if not _skirt.visible: return
	# The sides' strata, the same as cut ground's (scripts/strata.gd).
	var placing := terrain.global_transform.affine_inverse()*_skirt.global_transform
	preload("res://scripts/strata.gd").for_seed(land_seed).apply(_skirt_mesh.surface_get_material(0) as ShaderMaterial,placing.origin)
	var mesh := skirt_mesh_for(data)
	_skirt.mesh = mesh if open_sides.is_empty() else AtlasView.cut_sides(mesh,_skirt.position,open_sides)

## The faceted earth sides fitted to `source`'s rim: the editor's own land, or
## a plain baked off to the side for the flip's underside
## (scripts/diorama_flip.gd). The sides are sliced across at every rim point
## (`_rim_slices`) and their top written at the land's own edge height there;
## between rim points the land's edge runs straight, as the sliced top does,
## so grass and side meet flush all the way round, on a fresh plate and after
## a cut. Lower down the sides follow the rim's change, easing to nothing at
## their foot. Built again only when the rim moves.
func skirt_mesh_for(source: NativeTerrainData) -> ArrayMesh:
	var placing := terrain.global_transform.affine_inverse()*_skirt.global_transform
	var rim := PackedFloat32Array()
	for i in _rim_ids(source): rim.append(source.heights[i])
	var fitted_key := [source,source.points.size(),rim,_skirt_mesh,placing]
	if _skirt_fitted_key == fitted_key: return _skirt_fitted
	var planes := _rim_slices(source)
	var key := [planes,placing]
	if _skirt_sliced_for != key:
		_skirt_sliced_for = key
		# The sides' foot and the underside under the land never move: only
		# the sides themselves are sliced.
		_skirt_sliced = _sliced_soup(_skirt_mesh.surface_get_arrays(0),placing,planes,SIDES_HALF-1.0)
	var arrays: Array = _skirt_sliced.duplicate()
	var vertices: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	arrays[Mesh.ARRAY_NORMAL] = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Each sliced vertex's weight and the face it reads stand while the
	# slicing does; a stroke only moves heights, read here as `delta_at` reads
	# them.
	var reads := _skirt_reads_for(source,key,vertices)
	var at: PackedInt32Array = reads[0]
	var ids: PackedInt32Array = reads[1]
	var bary: PackedFloat64Array = reads[2]
	var heights := source.heights
	var original := source.original_heights
	for k in range(at.size()):
		var a := ids[k*3]
		var b := ids[k*3+1]
		var c := ids[k*3+2]
		var u := bary[k*3]
		var v := bary[k*3+1]
		var current := u*heights[a]+v*heights[b]+(1.0-u-v)*heights[c]
		var was := u*original[a]+v*original[b]+(1.0-u-v)*original[c]
		vertices[at[k]].y += (current-was)*bary[k*3+2]
	# The top sits on the land's edge, and each vertex carries its rim top
	# (the land's edge height above it, in the mesh's own space) for the
	# strata (the earth-sides switch in shaders/reference_surface.gdshader).
	var high := _skirt_mesh.get_aabb().end.y
	# The terrain's frame to the mesh's own, in height (the sides only sit
	# lower than the land; they are not turned or scaled).
	var lift := placing.affine_inverse().origin.y
	var rim_ids: PackedInt32Array = reads[3]
	var rim_bary: PackedFloat64Array = reads[4]
	var authored: PackedVector3Array = _skirt_sliced[Mesh.ARRAY_VERTEX]
	var tops := PackedVector2Array()
	tops.resize(vertices.size())
	for i in range(vertices.size()):
		var a := rim_ids[i*3]
		if a < 0:
			tops[i] = Vector2(high,1.0)
			continue
		var u := rim_bary[i*2]
		var v := rim_bary[i*2+1]
		var top := u*heights[a]+v*heights[rim_ids[i*3+1]]+(1.0-u-v)*heights[rim_ids[i*3+2]]+lift
		tops[i] = Vector2(top,1.0)
		if authored[i].y >= high-0.001: vertices[i].y = top
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3):
			normals[i+j] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = tops
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,_skirt_mesh.surface_get_material(0))
	_skirt_fitted_key = fitted_key
	_skirt_fitted = mesh
	return mesh
var _skirt_fitted_key: Array = []
var _skirt_fitted: ArrayMesh

## The land's edge, metres from the middle: the terrain's rim points stand on
## it, and the earth sides' top ring is laid along it.
const SIDES_HALF := 14.0
## How much of the authored sides' lean past the edge they keep: up to
## 0.11 m out at the foot, which the grass's edge hides from above.
const SIDES_BATTER := 0.25

## The authored earth sides (the scene's Reference/skirt) made flush and deep.
## As authored they lean out past the land's edge (up to 0.43 m) under a flat
## 0.2 m lip at the rim's height, a brown frame that stood proud round the
## grass. Here the top ring stands on the edge itself, the lip gone, and each
## vertex below it keeps a quarter of its reach (SIDES_BATTER), so the sides
## keep their facets as a slight outward batter. Leaning inward instead, they
## would stand under an overhang of grass that shades a sunlit side. Below
## their top ring the sides are stretched down so their foot stands at
## NativeTerrainData.SLAB_BASE, under the deepest dig. `offset` is where the
## mesh sits in the terrain's frame.
static func flush_deep_sides(source: ArrayMesh, offset: Vector3) -> ArrayMesh:
	var arrays := _sliced_soup(source.surface_get_arrays(0),Transform3D(Basis(),offset),[PackedFloat32Array(),PackedFloat32Array()])
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var high := source.get_aabb().end.y
	var low := source.get_aabb().position.y
	# The stretch pivots at the highest ring under the top.
	var pivot := low
	for v in vertices:
		if v.y < high-0.01: pivot = maxf(pivot,v.y)
	var base := NativeTerrainData.SLAB_BASE-offset.y
	var stretch := (pivot-base)/maxf(pivot-low,0.01)
	for i in range(vertices.size()):
		var v := vertices[i]
		var top := v.y >= high-0.001
		var p := v+offset
		for axis in [0,2]:
			var reach := absf(p[axis])-SIDES_HALF
			if reach > 0.0: p[axis] = signf(p[axis])*(SIDES_HALF if top else SIDES_HALF+reach*SIDES_BATTER)
		v = p-offset
		if v.y < pivot: v.y = pivot+(v.y-pivot)*stretch
		vertices[i] = v
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,vertices.size()-2,3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,source.surface_get_material(0))
	return mesh

## The planes the earth sides are sliced across, so their top can follow the
## land's edge point for point: every rim point along each side (planes
## across the x sides are z planes, and the other way round), but not the
## corners, where the other sides' facets stand. Every facet is sliced by the
## same planes, so the sides stay closed. Returns [x planes, z planes], plate
## metres, sorted. The triangulation's points never move, so this holds while
## the source does.
func _rim_slices(source: NativeTerrainData) -> Array:
	if _rim_slices_key == [source,source.points.size()]: return _rim_slices_found
	var found := [{},{}]
	var order := _rim_sides(source)
	for s in range(4):
		var into: Dictionary = found[1 if s < 2 else 0]
		for i in order[s]:
			var point := source.points[i]
			var at := point.y if s < 2 else point.x
			if absf(at) < SIDES_HALF-0.1: into[snappedf(at,0.0001)] = true
	_rim_slices_found = []
	for axis in found:
		var values := PackedFloat32Array(axis.keys())
		values.sort()
		_rim_slices_found.append(values)
	_rim_slices_key = [source,source.points.size()]
	return _rim_slices_found
var _rim_slices_key: Array = []
var _rim_slices_found: Array = []

var _skirt_sliced_for: Array = []
var _skirt_sliced: Array = []
var _skirt_reads_key: Array = []
var _skirt_reads: Array = []
var _rim_ids_key: Array = []
var _rim_ids_found := PackedInt32Array()

## The land's rim points (indices), in index order. The triangulation's points
## never move sideways, so this holds while the source does.
func _rim_ids(source: NativeTerrainData) -> PackedInt32Array:
	if _rim_ids_key == [source,source.points.size()]: return _rim_ids_found
	_rim_ids_found = PackedInt32Array()
	for i in range(source.points.size()):
		var point := source.points[i]
		if maxf(absf(point.x),absf(point.y)) > 13.9999: _rim_ids_found.append(i)
	_rim_ids_key = [source,source.points.size()]
	return _rim_ids_found

## Each side's (0 -x, 1 +x, 2 -z, 3 +z) rim point indices, sorted along it.
var _rim_sides_key: Array = []
var _rim_sides_found: Array = []
func _rim_sides(source: NativeTerrainData) -> Array:
	if _rim_sides_key == [source,source.points.size()]: return _rim_sides_found
	var sides: Array = [[],[],[],[]]
	for i in _rim_ids(source):
		var point := source.points[i]
		if absf(point.x) > 13.9999: sides[0 if point.x < 0.0 else 1].append(Vector2(point.y,i))
		if absf(point.y) > 13.9999: sides[2 if point.y < 0.0 else 3].append(Vector2(point.x,i))
	_rim_sides_found = []
	for side: Array in sides:
		side.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		_rim_sides_found.append(PackedInt32Array(side.map(func(item: Vector2) -> int: return int(item.y))))
	_rim_sides_key = [source,source.points.size()]
	return _rim_sides_found

## Which sliced sides' vertices move with the land, and how: [vertex indices,
## the three height ids each reads, and per vertex (u, v, weight)]. The foot
## (weight 0) and points off the land read nothing and stay put. Then, for
## every vertex, the land's edge point it hangs under: the three height ids
## (-1 where the edge cannot be read) and (u, v), so its rim top is read by
## arithmetic alone.
func _skirt_reads_for(source: NativeTerrainData, sliced_key: Array, vertices: PackedVector3Array) -> Array:
	var key := [sliced_key,_skirt_mesh,source,source.points.size()]
	if _skirt_reads_key == key: return _skirt_reads
	var placing: Transform3D = sliced_key[1]
	var low := _skirt_mesh.get_aabb().position.y
	var high := _skirt_mesh.get_aabb().end.y
	var at := PackedInt32Array()
	var ids := PackedInt32Array()
	var bary := PackedFloat64Array()
	for i in range(vertices.size()):
		var weight := clampf((vertices[i].y-low)/(high-low),0.0,1.0)
		if weight <= 0.0: continue
		var local := placing*vertices[i]
		var point := Vector2(local.x,local.z).clamp(Vector2(-14,-14),Vector2(14,14))
		# `sample` resolves and memoises the face; take its answer as is.
		if source.sample(point,source.heights) == null: continue
		var slot: int = source._locate_cache[point]
		var face: int = source._locate_face[slot]
		at.append(i)
		ids.append_array([source.vertex_ids[face],source.vertex_ids[face+1],source.vertex_ids[face+2]])
		bary.append_array([source._locate_u[slot],source._locate_v[slot],weight])
	var rim_ids := PackedInt32Array()
	var rim_bary := PackedFloat64Array()
	for i in range(vertices.size()):
		var local := placing*vertices[i]
		var point := Vector2(local.x,local.z).clamp(Vector2(-SIDES_HALF,-SIDES_HALF),Vector2(SIDES_HALF,SIDES_HALF))
		var edge := AtlasView.rim_point(point,SIDES_HALF)
		if source.sample(edge,source.heights) == null:
			rim_ids.append_array([-1,-1,-1])
			rim_bary.append_array([0.0,0.0])
			continue
		var slot: int = source._locate_cache[edge]
		var face: int = source._locate_face[slot]
		rim_ids.append_array([source.vertex_ids[face],source.vertex_ids[face+1],source.vertex_ids[face+2]])
		rim_bary.append_array([source._locate_u[slot],source._locate_v[slot]])
	_skirt_reads_key = key
	_skirt_reads = [at,ids,bary,rim_ids,rim_bary]
	return _skirt_reads

## A triangle soup's arrays (indexed arrays are unrolled) with every triangle
## cut by the planes `planes` ([x values, z values] in plate metres, read
## through `placing`) and fanned back into triangles. Every per-vertex array
## is interpolated along the cut edges. A triangle lying wholly within
## `keep` metres of the middle (the larger of |x| and |z|) is left whole.
static func _sliced_soup(source: Array, placing: Transform3D, planes: Array, keep := 0.0) -> Array:
	var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var indices: Variant = source[Mesh.ARRAY_INDEX]
	var order := PackedInt32Array()
	if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty(): order = indices
	else: order = PackedInt32Array(range(positions.size()))
	var count := positions.size()
	# The per-vertex arrays: [slot, components].
	var slots := []
	for slot in range(Mesh.ARRAY_MAX):
		if slot == Mesh.ARRAY_INDEX or source[slot] == null: continue
		var size: int = source[slot].size()
		if size > 0 and size % count == 0: slots.append([slot,size/count])
	var vertex := func(i: int) -> Array:
		var values := []
		for entry: Array in slots:
			var array: Variant = source[entry[0]]
			if entry[1] == 1: values.append(array[i])
			else: values.append(array.slice(i*entry[1],(i+1)*entry[1]))
		return values
	var mix := func(a: Array, b: Array, t: float) -> Array:
		var values := []
		for k in range(slots.size()):
			var x: Variant = a[k]
			var y: Variant = b[k]
			if x is Vector3 or x is Vector2 or x is Color: values.append(x.lerp(y,t))
			elif x is float: values.append(lerpf(x,y,t))
			elif x is PackedFloat32Array:
				var mixed := PackedFloat32Array(x)
				for c in range(mixed.size()): mixed[c] = lerpf(x[c],y[c],t)
				values.append(mixed)
			else: values.append(x if t < 0.5 else y)
		return values
	var at := slots.map(func(entry: Array) -> int: return entry[0]).find(Mesh.ARRAY_VERTEX)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for entry: Array in slots:
		var empty: Variant = source[entry[0]].duplicate()
		empty.resize(0)
		out[entry[0]] = empty
	for f in range(0,order.size()-2,3):
		var pieces := [[vertex.call(order[f]),vertex.call(order[f+1]),vertex.call(order[f+2])]]
		var inside := true
		for k in range(3):
			var p: Vector3 = placing*positions[order[f+k]]
			if maxf(absf(p.x),absf(p.z)) >= keep: inside = false
		for axis in (range(2) if not inside else []):
			var cuts: PackedFloat32Array = planes[axis]
			if cuts.is_empty(): continue
			var coordinate := func(v: Array) -> float:
				var p: Vector3 = placing*(v[at] as Vector3)
				return p.x if axis == 0 else p.z
			var next := []
			for piece: Array in pieces:
				var low := INF
				var high := -INF
				for v: Array in piece:
					low = minf(low,coordinate.call(v))
					high = maxf(high,coordinate.call(v))
				for c in cuts:
					if c <= low+0.001 or c >= high-0.001: continue
					var below := []
					var above := []
					for k in range(piece.size()):
						var a: Array = piece[k]
						var b: Array = piece[(k+1)%piece.size()]
						var da: float = coordinate.call(a)-c
						var db: float = coordinate.call(b)-c
						if da <= 0.0: below.append(a)
						if da >= 0.0: above.append(a)
						if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
							var middle: Array = mix.call(a,b,da/(da-db))
							below.append(middle)
							above.append(middle)
					if below.size() >= 3: next.append(below)
					piece = above
					if piece.size() < 3: break
				if piece.size() >= 3: next.append(piece)
			pieces = next
		for piece: Array in pieces:
			for k in range(1,piece.size()-1):
				for v: Array in [piece[0],piece[k],piece[k+1]]:
					for s in range(slots.size()):
						if slots[s][1] == 1: out[slots[s][0]].append(v[s])
						else: out[slots[s][0]].append_array(v[s])
	return out

func dab(point: Vector2, amount: float) -> void:
	if mode in ["grass","blades","meadow","paint","erase"]: data.mark_hand(point,radius)
	else: _touch(point,radius)
	match mode:
		"grass": data.paint_grass(point,radius,grass_amount)
		"blades": data.paint_blades(point,radius,blade_amount)
		"meadow": data.paint_meadow(point,radius,amount)
		"paint": data.paint_tint(point,radius,paint_color.srgb_to_linear(),paint_amount)
		"erase":
			data.paint_grass(point,radius,0.0)
			data.paint_blades(point,radius,0.0)
			data.paint_meadow(point,radius,-amount)
			data.erase_tint(point,radius,amount)
			data.erase_objects(point,radius)
		_: data.brush(point,radius,amount,mode,_level)

func save_garden() -> bool:
	if forming: return false
	finish_stroke()
	if scene.has_method("flush_world_play"): scene.flush_world_play()
	var document := data.to_document()
	document.scene_state = NativeGardenStore.capture(scene)
	var temporary := save_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		_set_status("Could not save. Your garden is still open.")
		return false
	file.store_string(JSON.stringify(document,"",true,true))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary,save_path) != OK:
		_set_status("Could not finish saving. Please try again.")
		return false
	_set_status("Garden saved.")
	return true

func open_garden() -> bool:
	if forming: return false
	_fall_start = null
	var file := FileAccess.open(save_path,FileAccess.READ)
	if file == null:
		_set_status("No saved garden to open yet.")
		return false
	if file.get_length() > 16000000:
		_set_status("This garden file is too large to open.")
		return false
	var document: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not document is Dictionary or not NativeGardenStore.valid(scene,document.get("scene_state")):
		_set_status("Could not read this garden. Your open garden is unchanged.")
		return false
	finish_stroke()
	if not data.load_document(document):
		_set_status("This garden does not match the chunk. Your open garden is unchanged.")
		return false
	selected_object_id = -1
	refresh()
	NativeGardenStore.restore(scene,document.scene_state)
	_set_status("Garden opened.")
	return true

func sync_visibility() -> void:
	preload("res://scripts/world_reference_props.gd").hide_replaced(self)
	if data.blank:
		for node: VisualInstance3D in _source_visibility:
			node.visible = false

func fill_landscape_streams() -> void:
	if forming: return
	finish_stroke()
	data.begin_stroke()
	var accepted:=data.fill_landscape_streams()
	data.end_stroke()
	if accepted:
		refresh()
		_set_status("Landscape streams filled. Save preserves their courses.")
	else:
		_set_status("Form a mountain landscape first; its stream must fit inside the chunk.")

func fill_landscape_flora() -> void:
	if forming: return
	finish_stroke()
	data.begin_stroke()
	var accepted: bool=data.fill_landscape_flora()
	data.end_stroke()
	if accepted:
		refresh()
		_set_status("Landscape flora populated. Save preserves every plant, log and boulder.")
	else:
		_set_status("Form a mountain landscape first.")

func fill_landscape_waterfall() -> void:
	if forming: return
	finish_stroke()
	data.begin_stroke()
	var accepted:=data.fill_landscape_waterfall()
	data.end_stroke()
	if accepted:
		refresh()
		_set_status("Landscape waterfall filled. Save preserves it.")
	else:
		_set_status("Form a mountain landscape first.")

# --- Editing existing authored objects ---------------------------------------
func selected_object() -> Dictionary:
	return data.object_by_id(selected_object_id)

func select_object(id: int) -> void:
	finish_stroke()
	reactions.finish_all()
	var item := data.object_by_id(id)
	selected_object_id = id if not item.is_empty() and item.asset != "waterfall" else -1
	selection.update_marker(selected_object_id)
	selection_changed.emit(selected_object_id)

func pick_object(mouse: Vector2) -> int:
	return selection.pick(mouse)

func begin_selection_edit() -> void:
	if _selection_edit or selected_object_id < 0:
		return
	data.begin_stroke()
	_selection_edit = true

func end_selection_edit() -> void:
	if not _selection_edit:
		return
	_selection_edit = false
	if data.end_stroke():
		refresh()

func update_selected(changes: Dictionary) -> bool:
	if forming: return false
	if selected_object_id < 0:
		return false
	var standalone := not _selection_edit
	begin_selection_edit()
	var changed := data.update_object(selected_object_id,changes)
	if changed:
		_refresh_selected_render()
		selection_changed.emit(selected_object_id)
		_set_status("Object changed · Save to keep your work.")
	if standalone:
		end_selection_edit()
	return changed

func move_selection_pointer(mouse: Vector2) -> void:
	if not _selection_drag or mouse.distance_to(_selection_press) < 5.0 and not _selection_edit:
		return
	var ground: Variant = pick(mouse)
	if selected_object().get("asset") == "log" and not data.void_faces.is_empty():
		var hit: Variant = Plane(Vector3.UP,_selection_plane_y).intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
		ground = terrain.to_local(hit) if hit != null else null
	if ground == null:
		return
	begin_selection_edit()
	update_selected({"x":ground.x+_selection_offset.x,"z":ground.z+_selection_offset.y})

func duplicate_selected() -> int:
	if forming: return -1
	finish_stroke()
	if selected_object_id < 0:
		return -1
	data.begin_stroke()
	var id := data.duplicate_object(selected_object_id)
	# Prefer a nearby visible copy. If the chunk edge blocks it, try the other sides.
	if id > 0:
		var item := data.object_by_id(id)
		for offset in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
			if data.update_object(id,{"x":item.x+offset.x,"z":item.z+offset.y}):
				break
	data.end_stroke()
	if id < 0:
		_set_status("This garden has reached its object limit.")
		return id
	refresh()
	select_object(id)
	return id

func delete_selected() -> void:
	if forming: return
	finish_stroke()
	data.begin_stroke()
	var changed := data.remove_object(selected_object_id)
	data.end_stroke()
	if changed:
		select_object(-1)
		refresh()

func _refresh_selected_render() -> void:
	var record := selected_object()
	if record.is_empty():
		return
	content.update_object_preview(record)
	if record.asset in NativeGardenLandmarks.KINDS:
		landmarks.rebuild(data)
	selection.update_marker(selected_object_id)
	_notify_play_geometry()

func _notify_play_geometry() -> void:
	# Geometry observers ignore tint. Copy only records that need that field
	# removed instead of deep-copying the entire world on each mouse event.
	var placements := data.objects.duplicate()
	for i in range(placements.size()):
		if placements[i].has("tint"):
			placements[i] = placements[i].duplicate()
			placements[i].erase("tint")
	var signature := var_to_bytes([data.tunnels,data.heights, placements, data.ponds, data.streams, data.landscape_waterfall])
	if signature != _play_geometry_signature:
		_play_geometry_signature = signature
		play_geometry_changed.emit()

## Preset selection restores a complete world mood; variations preserve customization.
## Reuse the scene-aware favorite history so one Undo restores both terrain and mood.
func form_landscape(id: String,biome := "",live := true,variation := 37,water := "connected",apply_mood := true) -> void:
	if forming or not preload("res://scripts/native_landscape_presets.gd").PRESETS.has(id): return
	if not NativeTerrainRecipe.valid(preload("res://scripts/native_landscape_presets.gd").recipe(id,biome,variation,water)): return
	finish_stroke()
	_fall_start = null
	selected_object_id = -1
	forming = true
	formation_started.emit()
	_set_status("Forming "+preload("res://scripts/native_landscape_presets.gd").PRESETS[id].title+"…")
	data.begin_stroke()
	if apply_mood: data._before["favorite_scene"] = NativeGardenStore.capture(scene)
	await preload("res://scripts/native_landscape_presets.gd").form(data,id,biome,get_tree() if live else null,variation,water)
	data.end_stroke()
	await refresh(get_tree() if live else null)
	if apply_mood:
		scene._world_visuals.restore()
		preload("res://scripts/native_landscape_presets.gd").apply_mood(scene,id)
	forming = false
	_set_status("Landscape ready · Change its biome or colors, or sculpt it further. Undo restores your previous landscape.")

func change_landscape_biome(id: String,live := true) -> void:
	if forming or data._recipe_settings.get("kind") != "formation" or not preload("res://scripts/native_formation_shape.gd").BIOMES.has(id): return
	finish_stroke()
	forming = true
	formation_started.emit()
	_set_status("Growing "+preload("res://scripts/native_formation_shape.gd").BIOMES[id].title+"…")
	data.begin_stroke()
	await preload("res://scripts/native_landscape_presets.gd").change_biome(data,id,get_tree() if live else null)
	data.end_stroke()
	await refresh(get_tree() if live else null)
	forming = false
	_set_status("Biome changed · Terrain sculpting, water and your own placed objects are retained.")

func another_landscape(live := true) -> void:
	if forming or data._recipe_settings.get("kind") != "formation": return
	var current: Dictionary = data._recipe_settings
	# A full-period sequence visits all 1,000 variants before repeating.
	await form_landscape(current.family,current.biome,live,(int(current.variation)+137)%1000,current.get("water","connected"),false)

func change_landscape_water(water: String,live := true) -> void:
	if forming or data._recipe_settings.get("kind") != "formation": return
	var current: Dictionary = data._recipe_settings
	await form_landscape(current.family,current.biome,live,int(current.variation),water,false)

func form_inland(settings: Dictionary,live := true,apply_mood := true) -> void:
	if forming or settings.get("kind") != "inland" or not NativeTerrainRecipe.valid(settings): return
	finish_stroke()
	selected_object_id = -1
	forming = true
	formation_started.emit()
	_set_status("Forming your landscape…")
	data.begin_stroke()
	data._before["favorite_scene"] = NativeGardenStore.capture(scene)
	await preload("res://scripts/inland_landscape.gd").new().form(data,settings,get_tree() if live else null)
	data.end_stroke()
	await refresh(get_tree() if live else null)
	if apply_mood:
		var desert: bool = settings.composition in preload("res://scripts/desert_landscape.gd").KINDS
		SceneLookPresets.apply(scene,"golden_meadow" if desert else "alpine_morning",{"palette":"Desert"} if desert else {})
		scene._world_visuals.restore()
		scene._world_visuals.rock_style = 1
		scene._world_visuals.fog_density = 0.65 if settings.composition == "valley" else 0.0
		scene._world_visuals.peak_density = 0.28 if settings.composition in ["mountain","massif"] else 0.0
		scene._world_visuals.peak_altitude = clampf(Array(data.heights).max()*0.6,2.0,24.0)
	forming = false
	_set_status("Landscape ready")

# --- Creation brushes -----------------------------------------------------------
## The brush in hand while the "land" tool is.
func creation_brush() -> Variant:
	return brushes.get(brush_id,land_brush)

## Put a brush in hand, and the "land" tool with it.
func select_brush(id: String) -> bool:
	if not brushes.has(id): return false
	finish_stroke()
	if id != brush_id:
		creation_brush().deactivate(self)
		brush_id = id
		creation_brush().activate(self)
		brush_changed.emit(id)
	if mode != "land": select_tool("land")
	else: _set_status(load("res://scripts/genesis_canvas.gd").brush_hint(id))
	return true

## The creation brush in hand, or "" while the "land" tool is not.
func held_brush() -> String:
	return brush_id if mode == "land" else ""

## Land keeps its size and strength here, as settings; the others on the brush.
func brush_radius() -> float:
	return land_radius if brush_id == "land" else float(creation_brush().radius)

func brush_strength() -> float:
	return land_strength if brush_id == "land" else float(creation_brush().strength)

## A brush's size ("size") or strength ("strength") for a shell's meters:
## {value, low, high}, or {} for an unknown brush.
func brush_setting(id: String, which: String) -> Dictionary:
	if not brushes.has(id): return {}
	if id == "land":
		var spec := setting_spec("land_radius" if which == "size" else "land_strength")
		return {"value":float(get(spec.property)),"low":spec.low,"high":spec.high}
	var brush = brushes[id]
	var span: Vector2 = brush.radius_range if which == "size" else brush.strength_range
	return {"value":float(brush.radius if which == "size" else brush.strength),"low":span.x,"high":span.y}

func _step_brush_setting(strength_step: bool, direction: float) -> void:
	var brush = creation_brush()
	if strength_step:
		brush.strength = clampf(brush.strength+0.25*direction,brush.strength_range.x,brush.strength_range.y)
		setting_changed.emit("brush_strength",brush.strength)
	else:
		var step := 0.25 if brush.radius_range.y > 4.0 else 0.1
		brush.radius = clampf(brush.radius+step*direction,brush.radius_range.x,brush.radius_range.y)
		setting_changed.emit("brush_radius",brush.radius)

## The mode stroke signals carry: the brush id while a creation brush paints.
func stroke_mode() -> String:
	if mountain.active: return "mountain"
	return brush_id if mode == "land" else mode

## A left press paints and Shift-drag works the other way: land rises and
## lowers, forest grows and clears, and so on. A right press works the other
## way too only while `right_works_other_way` is on (the classic build); the
## creation shell turns it off, so right drags orbit there.
## A press that misses the land, or holds Alt, falls through to the camera, so
## the sky still orbits with either button.
func _land_press(event: InputEventMouseButton) -> bool:
	if _gust_input(event): return true
	if not event.pressed:
		if _ball_holding and event.button_index == MOUSE_BUTTON_LEFT:
			_ball_release()
			return true
		if _handful_holding and event.button_index == MOUSE_BUTTON_LEFT:
			_handful_release()
			return true
		if _painting and event.button_index == _stroke_button: finish_stroke()
		return _painting or event.button_index == MOUSE_BUTTON_LEFT
	if _ball_holding or _handful_holding: return true
	if _painting or event.alt_pressed: return _painting
	if event.button_index == MOUSE_BUTTON_RIGHT and not right_works_other_way: return false
	var hit: Variant = pick(event.position)
	if hit == null: return false
	# A mountain still rising lands before anything else is painted, and
	# pollen in the air settles first, unless this press gathers more.
	_land_mountain()
	if handful != null and not (event.button_index == MOUSE_BUTTON_LEFT and _pollen_in_hand()): handful.settle_now()
	_stroke_button = event.button_index
	_land_lower = event.button_index == MOUSE_BUTTON_RIGHT or other_way
	var brush = creation_brush()
	if mountain_in_hand() and not _land_lower and not Input.is_key_pressed(KEY_SHIFT):
		_mountain_press(hit)
		return true
	if brush_id == "water" and water_ball and not _land_lower and not Input.is_key_pressed(KEY_SHIFT):
		_ball_press(hit)
		return true
	if brush_id == "forest" and seed_handful and not _land_lower and not Input.is_key_pressed(KEY_SHIFT):
		# Pollen: gathered and released, never painted.
		_handful_press(hit)
		return true
	brush.prepare(data,land_seed)
	brush.begin()
	_stroke_first_id = data.next_id
	_painting = true
	_elapsed = 0.0
	_last_point = Vector2(hit.x,hit.z)
	# A settling brush (water) opens its undo step and refreshes when its
	# first plan shows (`_pour_live`), not per dab.
	if not brush.settles: data.begin_stroke()
	land_dab(_last_point,brush_strength()/30.0)
	if not brush.settles: refresh()
	_emit_stroke(0,hit,brush_radius(),0.0)
	return true

func land_dab(point: Vector2, amount: float) -> void:
	var lower := _land_lower or Input.is_key_pressed(KEY_SHIFT)
	# With live water the water brush's other way drains it (and its springs).
	if brush_id == "water" and lower and flow != null and flow.ready:
		flow.drain(point,brush_radius())
		return
	if brush_id == "land": land_brush.dab(data,point,land_radius,amount,lower,land_ceiling)
	else: creation_brush().dab(data,point,brush_radius(),amount,lower)
	# A pour shows while the hand pours.
	if creation_brush().settles and (_pour.is_empty() or _pour.released) and not forming: _pour_live()

## Dabs along the pointer's path at a fifth of the brush size, at most one
## refresh per 1/30 s. The rate is independent of how far the pointer moved.
func _land_step(center: Vector2, delta: float) -> void:
	_elapsed += minf(delta,0.05)
	if _elapsed < 1.0/30.0: return
	var previous: Vector2 = _last_point if _last_point != null else center
	var reach := brush_radius()
	var settles: bool = creation_brush().settles
	var dabs := clampi(ceili(previous.distance_to(center)/(reach*0.2)),1,24)
	for i in range(1,dabs+1):
		var point := previous.lerp(center,float(i)/dabs)
		land_dab(point,brush_strength()*_elapsed/dabs)
		if not settles: _touch(point,reach)
	if not settles: refresh()
	_elapsed = 0.0
	_last_point = center

## A pour (scripts/water_brush.gd) arrives while the hand pours. Every
## POUR_REPLAN seconds, once the last plan has landed, the dabs so far are
## planned again on a worker against the heights from the pour's start, and
## the latest plan shows inside the pour's one undo step: the ground moves
## first (a hollow, beds, a lip), then the water, rising on from where it
## stands. Release plans the last dabs and closes the step. A new stroke, an
## undo or a world change closes it at once on what is showing.
const POUR_REPLAN := 0.2
## Seconds a replan's reshaped ground takes to move while the hand pours; the
## release's last plan takes WATER_SHAPE_SECONDS.
const POUR_SHAPE_SECONDS := 0.3
## Seconds a pour's reshaped ground takes to move into place after release
## before its water starts to fill. Ticks at 30 Hz with light refreshes.
const WATER_SHAPE_SECONDS := 0.7
## The pour in progress: {"target", "heights", "ponds", "streams" (the world
## at its start), "shown" (the plan showing), "planned" (its dabs),
## "released", "dabs" (all of them, at release), "open", "rect", "landing"
## (a plan whose ground is moving), "shaping"}.
var _pour := {}
## True from a pour's first shown water until the refresh after it closes:
## planar reflections hold their views rather than re-setup every replan.
var water_pouring := false
var _pour_serial := 0

## The first dab of a pour starts it; a pour still settling closes first.
func _pour_live() -> void:
	_commit_pour()
	var pour := {"target":data,"released":false,"open":false,"shown":{},"planned":PackedVector3Array(),"rect":Rect2(),"shaping":false}
	_pour = pour
	# A land stroke's weathering still in flight (`_weather_async`) lands
	# first, so the pour plans on the weathered ground.
	while _weather_job != null:
		await get_tree().process_frame
		if not is_same(_pour,pour): return
	_finish_weather_ease(false)
	if forming or data != pour.target:
		_drop_pour(pour)
		return
	pour.heights = data.heights.duplicate()
	pour.ponds = data.ponds.duplicate(true)
	pour.streams = data.streams.duplicate(true)
	pour.validate = data._recipe == null
	var started := -1000000
	while is_same(_pour,pour):
		var released: bool = pour.released
		var dabs: PackedVector3Array = pour.dabs if released else water_brush.dabs
		if dabs == pour.planned:
			if released: break
			await get_tree().process_frame
			continue
		if not released and Time.get_ticks_usec()-started < int(POUR_REPLAN*1000000.0):
			await get_tree().process_frame
			continue
		started = Time.get_ticks_usec()
		var planned := dabs.duplicate()
		var detached: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
		detached.heights = pour.heights.duplicate()
		var ponds: Array = pour.ponds
		var streams: Array = pour.streams
		var validate: bool = pour.validate
		var job = preload("res://scripts/background_work.gd").new()
		var plan: Dictionary = await job.run(func() -> Dictionary: return preload("res://scripts/water_brush.gd").plan(detached,ponds,streams,planned,validate),get_tree())
		if not is_same(_pour,pour): return
		pour.planned = planned
		water_brush.last_plan_usec = plan.usec
		if forming or data != pour.target:
			_commit_pour()
			return
		# Something else moved the land or the water under the pour.
		if data.heights != pour.get("ground",pour.heights) or data.ponds != pour.get("shown_ponds",pour.ponds) or data.streams != pour.get("shown_streams",pour.streams):
			_commit_pour()
			_set_status("The land changed while the water settled. Pour again.")
			return
		if not plan.changed and not pour.open: continue
		var last: bool = pour.released and pour.dabs == planned
		if not await _show_pour(pour,plan,WATER_SHAPE_SECONDS if last else POUR_SHAPE_SECONDS): return
	if is_same(_pour,pour): _commit_pour()

## The hand lifts: the pour plans its last dabs, then closes.
func _release_pour() -> void:
	if _pour.is_empty() or _pour.released:
		if water_brush.dabs.is_empty() or forming: return
		_pour_live()
		if _pour.is_empty(): return
	_pour.released = true
	_pour.dabs = water_brush.dabs.duplicate()
	water_brush.begin()
	water_settling = true

## A press with water in hand condenses a ball over the ground point. A
## `scooped` ball holds nothing yet: it fills from the water under it.
func _ball_press(hit: Vector3, scooped := false) -> void:
	if ball == null:
		ball = preload("res://scripts/water_ball.gd").new()
		ball.name = "WaterBall"
		terrain.add_child(ball)
		ball.landed.connect(_ball_landed)
		# It lands on the terrain under itself, where its mark lies.
		ball.ground_at = func(point: Vector2) -> Variant: return data.ground_height(point)
	var life: Variant = scene.get("land_life")
	_ball_serial += 1
	# A scoop draws a pond down: its new shore is the player's doing.
	if scooped: _tend(Vector2(hit.x,hit.z),FLOW_TENDED_REACH)
	ball.condense(hit,life.material if life != null and life.get("material") != null else null,hash([land_seed,_ball_serial]),scooped)
	ball_volume = 0.0 if scooped else BALL_MIN_VOLUME
	_ball_scooping = scooped
	_scoop_fish_wait = 0.0
	_ball_holding = true
	_emit_stroke(0,hit,brush_radius(),0.0)

## While held the ball fills and follows the pointer's ground point; its mark
## lies on the ground straight below it, not below the pointer.
func _ball_step(hit: Variant, delta: float) -> void:
	const WaterBrush := preload("res://scripts/water_brush.gd")
	# The water brush's own size and flow, also for a ball gathered from the
	# sky with another brush in hand (`ball_from_sky`).
	var rate: float = WaterBrush.RATE*float(water_brush.strength)*pow(float(water_brush.radius)/WaterBrush.REFERENCE_RADIUS,2.0)
	var more := minf(rate*minf(delta,0.05),BALL_MAX_VOLUME-ball_volume)
	# A ball from the sky's cloud fills only with what the cloud has; a
	# scooped one with what stands under it.
	if ball_supply.is_valid(): more = float(ball_supply.call(more))
	elif _ball_scooping: more = _scoop(more,delta)
	ball_volume = minf(BALL_MAX_VOLUME,ball_volume+more)
	ball.hold(hit,ball_volume)

## A scooped ball takes up to `more` m³ from the water under it, and the fish
## near it, and returns the m³ it got.
func _scoop(more: float, delta: float) -> float:
	if flow == null or not flow.ready: return 0.0
	var under := Vector2(ball.position.x,ball.position.z)
	var got: float = flow.scoop(under,SCOOP_RADIUS,more)
	_scoop_fish_wait -= delta
	var life: Variant = scene.get("land_life")
	if _scoop_fish_wait <= 0.0 and life != null and life.has_method("scoop_fish") and life.get("material") != null:
		_scoop_fish_wait = SCOOP_FISH_SECONDS
		for look: Dictionary in life.scoop_fish(under,SCOOP_FISH_REACH,ball.FISH_MAX-ball.fish.size(),ball.position):
			ball.add_fish(life.material,look)
	return got

## True when live water stands near the plate point `point` for a ball to
## scoop (SCOOP_REACH, SCOOP_DEPTH).
func water_near(point: Vector2) -> bool:
	if flow == null or not flow.ready: return false
	for ring: float in [0.0,SCOOP_REACH*0.5,SCOOP_REACH]:
		for k in range(1 if ring == 0.0 else 8):
			if flow.depth_at(point+Vector2.from_angle(k*TAU/8.0)*ring) >= SCOOP_DEPTH: return true
	return false

## The water ball from the hand (the case's water, scripts/hand_materials.gd):
## with live water it scoops the water standing under the press, and only
## there: "" when it formed, "dry" when there is no water near to scoop, "busy"
## when the land cannot take a press now. Without live water it gathers out of
## the air as before.
func scoop_ball(screen_pos: Vector2) -> String:
	if flow == null or not flow.ready: return "" if ball_from_sky(screen_pos) else "busy"
	if forming or not active or _ball_holding or _painting: return "busy"
	var hit: Variant = pick(screen_pos)
	if hit == null: return "busy"
	if not water_near(Vector2(hit.x,hit.z)): return "dry"
	_land_mountain()
	_stroke_button = MOUSE_BUTTON_LEFT
	_ball_press(hit,true)
	return ""

func _ball_release() -> void:
	if not _ball_holding: return
	_ball_holding = false
	_ball_scooping = false
	ball_supply = Callable()
	# No finger pokes it: it pops on the side toward the camera, a little up,
	# where the burst is seen (a God Hand's finger sets its own).
	if ball.poke.length_squared() < 0.0001 and scene.camera != null:
		var toward: Vector3 = terrain.to_local(scene.camera.global_position)-ball.position
		if Vector2(toward.x,toward.z).length_squared() > 0.0001: ball.poke = (Vector3(toward.x,0.0,toward.z).normalized()+Vector3.UP*0.25).normalized()
	ball.release()
	_emit_stroke(2,ball.mark(),ball.radius,0.0)

## The ball hit the ground: its water settles as one pour from where it
## landed (`_pour_live`), in one undo step, and remembers its fish. With live
## water it feeds the simulation instead (`_flow_landed`).
func _ball_landed(point: Vector2, volume: float, fish: Array) -> void:
	if forming or data.ground_height(point) == null: return
	if flow != null and flow.ready:
		_flow_landed(point,volume,fish)
		return
	water_brush.drop(point,volume)
	_release_pour()
	if not _pour.is_empty(): _pour.ball = {"point":point,"volume":volume,"fish":fish}

## Before a ball's pour closes: steep stretches of its new streams become
## waterfalls (object records, inside the pour's undo step), and the pour is
## named for what the land made of it.
func _ball_falls(pour: Dictionary) -> Dictionary:
	const WaterBrush := preload("res://scripts/water_brush.gd")
	var plan: Dictionary = pour.get("shown",{})
	var falls := 0
	for entry: Dictionary in plan.get("added_streams",[]):
		if falls >= FALL_MAX: break
		var points: Array = entry.record.pts
		var best := {}
		for i in range(points.size()):
			var a := Vector2(points[i].x,points[i].z)
			for j in range(i+1,points.size()):
				var b := Vector2(points[j].x,points[j].z)
				var run := a.distance_to(b)
				if run > FALL_REACH: break
				var drop := float(points[i].h)-float(points[j].h)
				if drop >= FALL_DROP and drop >= run*FALL_SLOPE and drop > float(best.get("drop",0.0)):
					best = {"from":a,"to":b,"drop":drop}
		if best.is_empty(): continue
		var width := clampf(float(entry.record.width)*1.6,0.4,1.4)
		if data.add_waterfall(best.from,best.to,width): falls += 1
	var added: Array = plan.get("added",[])
	var area := 0.0
	var center: Vector2 = pour.ball.point
	for entry: Dictionary in added:
		var cells: float = float(entry.cells.size())*WaterBrush.GRID*WaterBrush.GRID
		if cells > area:
			area = cells
			center = Vector2(entry.record.x,entry.record.z)
	var merged: bool = data.ponds.size() < pour.ponds.size()+added.size()
	var streams: int = plan.get("added_streams",[]).size()
	var longest := 0.0
	for entry: Dictionary in plan.get("added_streams",[]):
		var length := 0.0
		var points: Array = entry.record.pts
		for i in range(1,points.size()): length += Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length()
		longest = maxf(longest,length)
	var kind := "soaked"
	if falls > 0: kind = "waterfall"
	elif longest >= RIVER_LENGTH: kind = "stream"
	elif (area >= LAKE_AREA and float(pour.ball.volume) >= LAKE_VOLUME) or merged: kind = "lake"
	elif not added.is_empty(): kind = "pond"
	return {"kind":kind,"ponds":added.size(),"pond_area":snappedf(area,0.01),"merged":merged,"streams":streams,"stream_length":snappedf(longest,0.01),"falls":falls,"center":center,
		"fish":pour.ball.fish.size(),"volume":snappedf(float(pour.ball.volume),0.01)}

## The ball's fish go to the pond it made (LandLife `carry_fish`), and the
## status line says what the water became.
func _ball_settled(pour: Dictionary, outcome: Dictionary) -> void:
	var life: Variant = scene.get("land_life")
	if life != null and not pour.ball.fish.is_empty() and int(outcome.ponds) > 0: life.carry_fish(outcome.center,pour.ball.fish)
	var said := {"waterfall":"The water fell, and gathered below.","stream":"The water found a way down.","lake":"The water spread into a lake.","pond":"The water gathered in a pond.","soaked":"The ground drank the water."}
	_set_status(said[outcome.kind])
	ball_settled.emit(outcome)

# --- Live water ------------------------------------------------------------------
## Live water (scripts/water_flow.gd, docs/scenic/water-flow.md): under
## --modeless, or anywhere with --water-flow, a dropped water ball feeds a
## shallow-water simulation instead of the one-shot plan: on high or steep
## ground it becomes a spring, elsewhere its water goes once, and the water
## then runs, pools and spills as the land lets it, following every change
## to the land. --planned-water keeps the plan (scripts/water_brush.gd).
var flow: RefCounted
var flow_view: Node3D
## Seconds between reads of the standing water for life and emergence, and
## the least time between two reports of changed ponds (`water_settled`).
const FLOW_READ_SECONDS := 1.0
const FLOW_REPORT_SECONDS := 3.0
## A pond whose area moves by FLOW_AREA_CHANGE m² (or appears, or goes)
## is reported.
const FLOW_AREA_CHANGE := 2.0
## Seconds a ball's fish wait for a pond to form before they are gone.
const FLOW_FISH_SECONDS := 90.0
## Metres from its landing a ball's fish look for a pond.
const FLOW_FISH_REACH := 12.0
## Growth follows the player (docs/scenic/emergence.md "Whose water"): a
## changed pond goes to emergence only where it meets the player's own work
## of the last FLOW_TENDED_SECONDS, a stroke's rect or FLOW_TENDED_REACH m
## round a ball's landing, the can's stream or a planted spring. Rain, runoff,
## old springs grow nothing; life still reads every change (`water_settled`).
const FLOW_TENDED_SECONDS := 75.0
const FLOW_TENDED_REACH := 5.0
const FLOW_TENDED_MAX := 96
var _flow_read := 0.0
var _flow_reported := 0.0
var _flow_pools: Array = []
## Changed ponds since the last report: all of them, and the tended ones.
var _flow_changed := Rect2()
var _flow_grown := Rect2()
## The player's recent work: [{"rect", "until"}] on `_flow_clock`.
var _flow_tended: Array[Dictionary] = []
## After a restore the next read is only the baseline: the ponds then
## standing are not news.
var _flow_baseline := true
## Fish waiting for a pond: [{"point", "fish", "until"}].
var _flow_fish: Array[Dictionary] = []
var _flow_clock := 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: data.release_listeners()

static func flow_wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--planned-water" in args: return false
	return "--water-flow" in args or preload("res://scripts/modeless_input.gd").enabled()

func _setup_flow() -> void:
	flow = preload("res://scripts/water_flow.gd").new(data)
	await flow.setup(get_tree())
	flow_view = preload("res://scripts/water_flow_view.gd").new()
	flow_view.name = "LiveWater"
	content.add_child(flow_view)
	flow_view.setup(flow,content._water_material,content._stream_material,scene)

## Steps the water at its fixed rate, redraws it, and now and then reads the
## ponds it makes for life and emergence.
func _flow_process(delta: float) -> void:
	if flow == null or not flow.ready: return
	flow.paused = forming
	# The sky's rain and snow (and the snow globe's, added to it) reach the water.
	var precipitation: Variant = scene.get("_precipitation") if scene != null else null
	if precipitation != null:
		var fall := minf(1.0,precipitation.state.x+precipitation.state.y)
		var phase: float = precipitation.surface_weather.snow_phase
		flow.runoff.rain = fall*(1.0-phase)
		flow.runoff.snowing = fall*phase
		flow.runoff.snow_phase = phase
	# The wind tool's gusts push the water while they blow.
	flow.wind = gust if gust != null and (not gust.gusts.is_empty() or not gust.wakes.is_empty()) else null
	flow.advance(delta)
	flow_view.update(delta)
	_flow_clock += delta
	_flow_read += delta
	_flow_reported += delta
	if _flow_read < FLOW_READ_SECONDS or forming: return
	_flow_read = 0.0
	_read_flow_pools()

func _read_flow_pools() -> void:
	var pools: Array = flow.pools()
	flow_view.pools = pools
	emergence.flow_wet = flow.wet_mask()
	# The can's stream is the player's water while it runs.
	if can != null and can.landing != Vector2.INF and float(can.flow_share) > 0.0: _tend(can.landing,FLOW_TENDED_REACH)
	_flow_tended = _flow_tended.filter(func(tended: Dictionary) -> bool: return float(tended.until) > _flow_clock)
	# What moved: new ponds, ponds gone, ponds that grew or shrank.
	if not _flow_baseline:
		for pool: Dictionary in pools:
			var before := _nearest_pool(_flow_pools,pool)
			if before.is_empty() or absf(float(before.area)-float(pool.area)) >= FLOW_AREA_CHANGE: _flow_moved(pool.rect)
		for pool: Dictionary in _flow_pools:
			if _nearest_pool(pools,pool).is_empty(): _flow_moved(pool.rect)
	_flow_baseline = false
	_flow_pools = pools
	# A ball's fish go to the pond nearest where it landed.
	var life: Variant = scene.get("land_life")
	for waiting: Dictionary in _flow_fish.duplicate():
		var home := {}
		for pool: Dictionary in pools:
			var reach := Vector2(pool.x,pool.z).distance_to(waiting.point)
			if reach <= FLOW_FISH_REACH and (home.is_empty() or reach < Vector2(home.x,home.z).distance_to(waiting.point)): home = pool
		if not home.is_empty() and life != null: life.carry_fish(Vector2(home.x,home.z),waiting.fish)
		if not home.is_empty() or _flow_clock > float(waiting.until): _flow_fish.erase(waiting)
	if _flow_changed.has_area() and _flow_reported >= FLOW_REPORT_SECONDS and not _painting:
		# Grass creeps out from the new shores of the player's water
		# (scripts/emergence.gd), and life reads all the water again
		# (scripts/land_life.gd).
		var rect := _flow_changed.grow(1.0)
		var grown := _flow_grown.grow(1.0) if _flow_grown.has_area() else Rect2()
		_flow_changed = Rect2()
		_flow_grown = Rect2()
		_flow_reported = 0.0
		if emergence_enabled and grown.has_area(): emergence.on_region_changed(grown,"water")
		water_settled.emit(rect)

## A pond changed under `rect`: news for life, and for emergence where the
## player's recent work meets it.
func _flow_moved(rect: Rect2) -> void:
	_flow_changed = _flow_changed.merge(rect) if _flow_changed.has_area() else rect
	if not _tended(rect): return
	_flow_grown = _flow_grown.merge(rect) if _flow_grown.has_area() else rect

## Mark the player's water or land work: `rect`, or `reach` m round a point.
func _tend(at: Variant, reach := 0.0) -> void:
	var rect: Rect2 = at if at is Rect2 else Rect2(at-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
	if not rect.has_area(): return
	if _flow_tended.size() >= FLOW_TENDED_MAX: _flow_tended.pop_front()
	_flow_tended.append({"rect":rect,"until":_flow_clock+FLOW_TENDED_SECONDS})

func _tended(rect: Rect2) -> bool:
	for tended: Dictionary in _flow_tended:
		if (tended.rect as Rect2).intersects(rect,true): return true
	return false

## Undo, load and new worlds take the ground away (as the pollen's): the
## ponds read so far, their changes, the player's recent water and the fish
## waiting for a pond were the world left's, so the next read is only a
## baseline. A ball still out, the can's stream and a pour not yet shown go
## with them, rather than land on the world that replaced it.
func _world_restored(_state: Dictionary) -> void:
	_flow_pools = []
	_flow_changed = Rect2()
	_flow_grown = Rect2()
	_flow_tended.clear()
	_flow_fish.clear()
	_flow_baseline = true
	_flow_read = 0.0
	_flow_reported = 0.0
	if ball != null: ball.vanish()
	_ball_holding = false
	_ball_scooping = false
	ball_supply = Callable()
	if can != null: can.stop()
	if not _pour.is_empty() and not _pour.open:
		_drop_pour(_pour)
		water_brush.begin()

## The pool in `pools` over the same water as `pool` (its deepest point
## inside the other's bounds), or {}.
static func _nearest_pool(pools: Array, pool: Dictionary) -> Dictionary:
	for other: Dictionary in pools:
		if (other.rect as Rect2).grow(0.3).has_point(Vector2(pool.x,pool.z)) or (pool.rect as Rect2).grow(0.3).has_point(Vector2(other.x,other.z)): return other
	return {}

## A ball landed with live water: a spring or a burst (scripts/water_flow.gd
## `drop`), and its fish wait for the pond the water makes.
func _flow_landed(point: Vector2, volume: float, fish: Array) -> void:
	var kind: String = flow.drop(point,volume)
	if kind.is_empty(): return
	var bed: Dictionary = flow.last_bed
	_tend_water(point,bed)
	if not fish.is_empty(): _flow_fish.append({"point":bed.get("pool",point),"fish":fish.duplicate(),"until":_flow_clock+FLOW_FISH_SECONDS})
	_set_status("A spring rises where the water landed." if kind == "spring" else "The water runs where the land takes it.")
	ball_settled.emit({"kind":kind,"volume":snappedf(volume,0.01),"fish":fish.size(),"center":point,"pool":bed.get("pool",point)})
	if not bed.is_empty(): _wear_spring_bed(bed)

## The player's water came down at `point`: round it, the way it runs down
## (WaterFlow `descent`) and a spring's bed and pool are tended (`_tend`).
func _tend_water(point: Vector2, bed: Dictionary) -> void:
	_tend(point,FLOW_TENDED_REACH)
	var course: PackedVector3Array = flow.descent(data,point).points
	if course.size() > 1:
		var run := Rect2(Vector2(course[0].x,course[0].z),Vector2.ZERO)
		for p in course: run = run.expand(Vector2(p.x,p.z))
		_tend(run.grow(FLOW_TENDED_REACH*0.5))
		_tend(Vector2(course[-1].x,course[-1].z),FLOW_TENDED_REACH)
	if bed.is_empty(): return
	_tend(bed.rect)
	_tend(bed.pool,FLOW_TENDED_REACH)

## Seconds a spring's bed takes to settle into the ground (`_wear_spring_bed`).
const SPRING_BED_SECONDS := 1.2

## Shows a spring's bed (WaterFlow `spring_bed`), already in the data and its
## undo step, wearing in with light refreshes at 30 Hz, as a pour's ground
## moves. The water follows the ground as it goes. A stroke that starts
## meanwhile, an undo or a new world stops it, the stroke on the finished bed.
func _wear_spring_bed(bed: Dictionary) -> void:
	var from: PackedFloat32Array = bed.from.duplicate()
	var final: PackedFloat32Array = bed.heights
	var moved := PackedInt32Array()
	for i in range(mini(final.size(),from.size())):
		if absf(final[i]-from[i]) > 0.0005: moved.append(i)
	var target := data
	# Shared with the handlers (a lambda keeps its own copy of a local).
	var wear := {"shown":final,"gone":false}
	var finish := func() -> void:
		if not wear.gone and target.heights == wear.shown: target.heights = final.duplicate()
	var restored := func(_state: Dictionary) -> void: wear.gone = true
	target.stroke_starting.connect(finish)
	target.state_restored.connect(restored)
	# A recipe world's first sculpt shades its whole mesh; the yielding refresh
	# does that on workers (as `_shape_pour`).
	if data._recipe == null or data._mesh_sculpted:
		data.heights = from.duplicate()
		wear.shown = data.heights
		var elapsed := 0.0
		var since_tick := 1.0
		while elapsed < SPRING_BED_SECONDS:
			await get_tree().process_frame
			if wear.gone or data != target or data.heights != wear.shown or forming: break
			var step := minf(get_process_delta_time(),0.05)
			elapsed += step
			since_tick += step
			if since_tick < 1.0/30.0: continue
			since_tick = 0.0
			if not _light_refresh_ready(true): break
			var t := smoothstep(0.0,1.0,clampf(elapsed/SPRING_BED_SECONDS,0.0,1.0))
			var heights := data.heights
			for i in moved: heights[i] = lerpf(from[i],final[i],t)
			data.heights = heights
			wear.shown = heights
			_refresh_light()
	target.stroke_starting.disconnect(finish)
	target.state_restored.disconnect(restored)
	if wear.gone or data != target or data.heights != wear.shown or forming: return
	data.heights = final.duplicate()
	_stroke_rect = bed.rect
	_stroke_ended("water")
	_stroke_rect = Rect2()
	await refresh(get_tree())

## Where a held ball's water comes from: called with the m³ it would take this
## frame, it returns what it gives (the sky's cloud, scripts/sky_cloud.gd
## `supply`). Unset, the ball fills at the brush's rate. Cleared at release.
var ball_supply := Callable()

## Water in hand from the sky (--modeless, scripts/hand_reach.gd): a tuft
## torn from the sky's cloud and carried over the land condenses a water ball
## there, held until the button is let go, as the water brush's press does.
## True when the ball was taken.
func ball_from_sky(screen_pos: Vector2) -> bool:
	if forming or not active or _ball_holding or _painting: return false
	var hit: Variant = pick(screen_pos)
	if hit == null: return false
	_land_mountain()
	_stroke_button = MOUSE_BUTTON_LEFT
	_ball_press(hit)
	return true

## Still water's surface as triangles (three points each) in plate metres:
## the ponds the view drew, and the live water's still part. For the life
## survey (scripts/life_survey.gd).
func still_water_triangles() -> PackedVector3Array:
	var soup: PackedVector3Array = content.pond_vertices.duplicate()
	if flow_view != null: soup.append_array(flow_view.still_triangles())
	return soup

# --- Watering can ----------------------------------------------------------------
## The watering can's stream (scripts/watering_can.gd): with the can in hand
## (the tool roll's "can", scripts/hand_materials.gd CAN) a press pours into
## the live water under the can's rose until the button comes up, and held
## still on high ground plants a spring (`_can_spring`).
var can: Node3D

## A press with the can on the land at `screen_pos`: `scale` is the size in
## hand, `fine` a sprinkle. False when there is no live water to pour into or
## the land is busy.
func can_in_hand(screen_pos: Vector2, scale: float, fine: bool) -> bool:
	if flow == null or not flow.ready or forming or not active or _ball_holding or _painting: return false
	var hit: Variant = pick(screen_pos)
	if hit == null: return false
	_land_mountain()
	if can == null:
		can = preload("res://scripts/watering_can.gd").new()
		can.name = "WateringCan"
		can.flow = flow
		can.clay = clay
		can.ground_at = func(point: Vector2) -> Variant: return data.ground_height(point)
		can.spring_planted.connect(_can_spring)
		terrain.add_child(can)
	can.press(hit,scale,fine)
	_emit_stroke(0,hit,0.8*scale,0.0)
	return true

## The can held still on high ground: a spring rises there, its course and
## pool worn as a ball's spring's are, in one undo step.
func _can_spring(point: Vector2) -> void:
	if not flow.plant_spring(point,maxf(float(can.poured),2.0)): return
	_set_status("A spring rises where the water fell.")
	preload("res://scripts/clay_sound.gd").cue_at(&"water_splash",terrain.to_global(Vector3(point.x,float(data.ground_height(point)),point.y)),0.6)
	var bed: Dictionary = flow.last_bed
	_tend_water(point,bed)
	ball_settled.emit({"kind":"spring","volume":snappedf(float(can.poured),0.01),"fish":0,"center":point,"pool":bed.get("pool",point)})
	if not bed.is_empty(): _wear_spring_bed(bed)

# --- Wind gust -------------------------------------------------------------------
## The wind tool (scripts/wind_gust.gd, docs/scenic/wind-gust.md): with wind
## in hand a press starts a blow and its mark shows the promised gust while
## the hand drags; release sends it along the swipe, or, not moved, bursts
## round the press. It changes no land, so it takes no undo step.
var gust: Node3D

## Presses and releases with wind in hand. True when the gust took the event.
func _gust_input(event: InputEventMouseButton) -> bool:
	if gust != null and gust.aiming():
		if not event.pressed and event.button_index == _stroke_button: gust.release()
		return true
	if not event.pressed or brush_id != "wind" or _painting or _ball_holding or event.alt_pressed: return false
	if event.button_index == MOUSE_BUTTON_RIGHT and not right_works_other_way: return false
	var hit: Variant = pick(event.position)
	if hit == null: return false
	_land_mountain()
	_stroke_button = event.button_index
	_make_gust()
	var brush = creation_brush()
	gust.press(hit,brush.radius,brush.strength)
	return true

func _make_gust() -> void:
	if gust == null:
		gust = preload("res://scripts/wind_gust.gd").new()
		gust.name = "WindGust"
		terrain.add_child(gust)
		gust.ground_at = func(point: Vector2) -> Variant: return data.ground_height(point)
		gust.scene = scene
		if dandelions != null: dandelions.gust = gust
		gust.atmosphere = scene.get("_atmosphere")
		gust.lightning = scene.get("_lightning")
		var resident: Variant = scene.get("_resident_wind")
		if resident != null and resident.get("field") != null: gust.field = resident.field
		data.state_restored.connect(func(_state: Dictionary) -> void: gust.clear())
		# The plate's bounds, which never move: lanes stop short of the edge.
		var low := Vector2(INF,INF)
		var high := -low
		for point: Vector2 in data.points:
			low = low.min(point)
			high = high.max(point)
		gust.land = Rect2(low,high-low)

# --- The dandelion's round -----------------------------------------------------------
## Seed clocks shed on the air and come round again, and a few of their seeds
## take near the flowers already standing (scripts/dandelion_seeds.gd,
## docs/scenic/dandelions.md). Life spreading, not a tool.
var dandelions: Node3D

func _setup_dandelions() -> void:
	dandelions = preload("res://scripts/dandelion_seeds.gd").new()
	dandelions.name = "DandelionSeeds"
	dandelions.data = data
	dandelions.view = content
	dandelions.scene = scene
	dandelions.sowing_for = _flower_sowing
	# Never into an open stroke (its undo step is the player's), nor while a
	# world is being made.
	dandelions.held = func() -> bool: return forming or not data._before.is_empty()
	terrain.add_child(dandelions)
	content.instances_published.connect(dandelions.land_changed)
	data.state_restored.connect(func(_state: Dictionary) -> void: dandelions.restored())

## A swipe through the sky (scripts/sky_wind.gd): a gust at `power` (0..1)
## blown across the land along `heading` (plate x, z), from the land's upwind
## side, SKY_GUST_HALF m either side of its line. False when the land is busy.
func gust_from_sky(heading: Vector2, power: float) -> bool:
	if forming or not active or heading.length_squared() < 0.000001: return false
	_make_gust()
	heading = heading.normalized()
	var land: Rect2 = gust.land
	var middle := land.get_center()
	# Back from the middle, upwind, to just inside the land's edge.
	var back := INF
	if absf(heading.x) > 0.0001: back = minf(back,(middle.x-land.position.x)/absf(heading.x))
	if absf(heading.y) > 0.0001: back = minf(back,(middle.y-land.position.y)/absf(heading.y))
	back = maxf(back-SKY_GUST_INSET,0.0)
	var origin := middle
	var ground: Variant = null
	# Walk in toward the middle until there is ground under it.
	while back >= 0.0:
		origin = middle-heading*back
		ground = data.ground_height(origin)
		if ground != null: break
		back -= 1.0
	if ground == null: return false
	gust.send_lane(Vector3(origin.x,float(ground),origin.y),heading,power,SKY_GUST_HALF)
	return true

## Wind dragged from the sky onto the land (--modeless, scripts/sky_wind.gd):
## the wind tool is taken in hand where the pointer meets the ground, as the
## wind brush's press does, carrying the flick's `heading` (plate x, z) and
## `power` (0..1). From there it is the Feather's wind (scripts/wind_gust.gd
## "The wake"): a drag on blows along the path the pointer takes while it
## moves, as hard as it moves, and dies away on release; a still hold bursts.
## The Feather's own press on the land comes here too, with no flick. True
## when the tool was taken. `half` (m) is the wake's half-width when the
## Feather sets it (scripts/hand_materials.gd); below 0 it is the wind brush's.
func gust_in_hand(screen_pos: Vector2, heading: Vector2, power: float, half := -1.0) -> bool:
	if forming or not active or _painting or _ball_holding or _handful_holding: return false
	if gust != null and gust.aiming(): return false
	var hit: Variant = pick(screen_pos)
	if hit == null: return false
	_land_mountain()
	_stroke_button = MOUSE_BUTTON_LEFT
	_make_gust()
	var brush = brushes.get("wind")
	if half < 0.0: half = float(brush.radius) if brush != null else SKY_GUST_HALF
	gust.press(hit,half,float(brush.strength) if brush != null else 1.0,true)
	gust.carry(heading,power)
	return true

## A sky gust's half-width (m) and how far inside the land's edge it starts.
const SKY_GUST_HALF := 5.0
const SKY_GUST_INSET := 2.0

## While the hand blows the mark is the only shape under it; a release
## missed (the button up off the window) lets the gust go.
func _gust_process(hit: Variant) -> void:
	if not gust.aiming(): return
	if forming or scene._growth.terrain < 0.995:
		gust.cancel()
		return
	if not Input.is_mouse_button_pressed(_stroke_button):
		gust.release()
		return
	_material.set_shader_parameter("brush_visible",false)
	gust.aim(hit)

## Show `plan` inside the pour's open undo step: the ground moves first, then
## the water lands and the yielding refresh publishes it. False when the pour
## closed meanwhile.
func _show_pour(pour: Dictionary, plan: Dictionary, seconds: float) -> bool:
	if not pour.open:
		data.begin_stroke()
		data.stroke_starting.connect(_commit_pour)
		pour.open = true
		pour.objects = data.objects.duplicate(true)
		_pour_serial += 1
		water_pouring = true
	var ground: PackedFloat32Array = plan.get("heights",pour.heights)
	if data.heights != ground:
		pour.landing = plan
		if not await _shape_pour(pour,ground,seconds): return false
		pour.erase("landing")
	_set_pour_water(pour,plan)
	await refresh(get_tree())
	return is_same(_pour,pour)

## Move the ground toward `final` with light refreshes at 30 Hz.
func _shape_pour(pour: Dictionary, final: PackedFloat32Array, seconds: float) -> bool:
	var from := data.heights.duplicate()
	var moved := PackedInt32Array()
	for i in range(mini(final.size(),from.size())):
		if absf(final[i]-from[i]) > 0.0005: moved.append(i)
	# A recipe world's first sculpt shades its whole mesh (about 40 ms on the
	# main thread in a light refresh); the yielding refresh does it on workers.
	if data._recipe != null and not data._mesh_sculpted: moved.clear()
	var elapsed := 0.0
	var since_tick := 0.0
	var last := Time.get_ticks_usec()
	pour.shaping = true
	while elapsed < seconds and not moved.is_empty():
		await get_tree().process_frame
		if not is_same(_pour,pour): return false
		if data != pour.target or forming:
			_commit_pour()
			return false
		var now := Time.get_ticks_usec()
		var step := minf((now-last)/1000000.0,0.05)
		last = now
		elapsed += step
		since_tick += step
		if since_tick < 1.0/30.0: continue
		since_tick = 0.0
		if not _light_refresh_ready(true): break
		var t := smoothstep(0.0,1.0,clampf(elapsed/seconds,0.0,1.0))
		var heights := data.heights
		for i in moved: heights[i] = lerpf(from[i],final[i],t)
		data.heights = heights
		pour.ground = heights
		_refresh_light()
	pour.shaping = false
	return true

## Put a plan's ground, ponds and streams in the data and withdraw the plants
## its water covers (only those: plants an earlier plan covered come back),
## with fill births that carry on from the water already showing.
func _set_pour_water(pour: Dictionary, plan: Dictionary) -> void:
	_pour_births(pour,plan)
	data.heights = plan.get("heights",pour.heights)
	data.ponds.assign(plan.ponds)
	data.streams.assign(plan.streams)
	if pour.get("drowned",false):
		data.objects.assign(pour.objects.duplicate(true))
		data.objects_revision += 1
	pour.drowned = emergence.drown(plan.added,plan.added_streams)
	pour.shown = plan
	pour.ground = data.heights
	pour.shown_ponds = data.ponds.duplicate(true)
	pour.shown_streams = data.streams.duplicate(true)
	if plan.changed: pour.rect = pour.rect.merge(plan.rect) if pour.rect.has_area() else plan.rect

## A pond the pour already raised rises on from the level showing, as fast as
## it was rising (the shader lowers it drop·(1-f)², f over FILL_SECONDS). A
## stream the pour already runs keeps its front. New water waits its delay.
func _pour_births(pour: Dictionary, plan: Dictionary) -> void:
	const WaterBrush := preload("res://scripts/water_brush.gd")
	var fill: float = WaterBrush.FILL_SECONDS
	var now: float = preload("res://scripts/emergence.gd").time
	var births: Dictionary = content.water_births
	var shown: Dictionary = pour.shown
	var stamped := {}
	for entry: Dictionary in plan.added:
		var key := GardenView.water_key(entry.record)
		var level := float(entry.record.level)
		var birth := {"born":now+float(entry.delay),"drop":float(entry.drop)}
		var seed := WaterBrush.cell_of(Vector2(entry.record.x,entry.record.z))
		for before: Dictionary in shown.get("added",[]):
			if not (entry.cells.has(WaterBrush.cell_of(Vector2(before.record.x,before.record.z))) or before.cells.has(seed)): continue
			var was: Dictionary = births.get(GardenView.water_key(before.record),{})
			if not was.has("drop"): continue
			if GardenView.water_key(before.record) == key:
				birth = was
				break
			var at := maxf(now,float(was.born))
			var f := clampf((at-float(was.born))/fill,0.0,1.0)
			var remaining := float(was.drop)*(1.0-f)*(1.0-f)
			var rise := level-(float(before.record.level)-remaining)
			if rise <= 0.0:
				birth = {"born":at,"drop":0.0}
				break
			# As fast as it was rising, or faster when the new rise needs it.
			var g := 1.0 if f <= 0.0 or remaining < 0.0001 else minf(1.0,(1.0-f)*rise/remaining)
			birth = {"born":at-(1.0-g)*fill,"drop":rise/(g*g)}
			break
		stamped[key] = birth
	for entry: Dictionary in plan.added_streams:
		var key := GardenView.water_key(entry.record)
		var birth := {"born":now+float(entry.delay),"seconds":float(entry.seconds)}
		var head := Vector2(entry.record.pts[0].x,entry.record.pts[0].z)
		for before: Dictionary in shown.get("added_streams",[]):
			var was: Dictionary = births.get(GardenView.water_key(before.record),{})
			if not was.has("seconds") or Vector2(before.record.pts[0].x,before.record.pts[0].z).distance_to(head) > 1.2: continue
			birth.born = minf(float(birth.born),float(was.born))
			break
		stamped[key] = birth
	births.merge(stamped,true)

## Close the pour's undo step on what is showing (landing a plan whose ground
## is still moving), hand its ground to emergence and settle.
func _commit_pour() -> void:
	var pour := _pour
	if pour.is_empty(): return
	_drop_pour(pour)
	# Closed while the hand still pours (an undo, another stroke): the rest of
	# the stroke starts a new pour.
	if not pour.released: water_brush.begin()
	if not pour.open: return
	if data == pour.target:
		if pour.has("landing"):
			_set_pour_water(pour,pour.landing)
			refresh(get_tree())
		var outcome := _ball_falls(pour) if pour.has("ball") else {}
		if int(outcome.get("falls",0)) > 0: refresh(get_tree())
		if not outcome.is_empty(): _ball_settled(pour,outcome)
		if data.end_stroke() and pour.rect.has_area():
			# Grass creeps out from new shores (scripts/emergence.gd).
			_stroke_rect = pour.rect
			_stroke_ended("water")
			_stroke_rect = Rect2()
			water_settled.emit(pour.rect)
	_hold_reflections()

## Take back what a still click just laid (a double-click's first click,
## scripts/camera_rig.gd `_retract_click`): a pour or a rising mountain it
## started closes first, since both keep their undo step open after release
## (a pour that has not shown yet is simply dropped). Then the step it left,
## if any, is undone and kept off redo. `last` is the newest undo step before
## the click. True when a step was taken back.
func retract_click(last: Variant) -> bool:
	if forming: return false
	if not _pour.is_empty(): _commit_pour()
	if mountain.active: _mountain_interrupted()
	if data._undo.is_empty() or is_same(data._undo.back(),last): return false
	undo()
	if not data._redo.is_empty(): data._redo.pop_back()
	return true

func _drop_pour(pour: Dictionary) -> void:
	if is_same(_pour,pour): _pour = {}
	water_settling = false
	if is_instance_valid(pour.target) and pour.target.stroke_starting.is_connected(_commit_pour): pour.target.stroke_starting.disconnect(_commit_pour)

## Reflections re-setup once, when the pour's last refresh has published.
func _hold_reflections() -> void:
	var serial := _pour_serial
	while refresh_pending > 0:
		await get_tree().process_frame
		if serial != _pour_serial: return
	if serial == _pour_serial: water_pouring = false

## Release work for the creation brushes other than land, inside the stroke's
## transaction: stones along a path, clearing a forest. It says which ground
## emergence answers. True when the settle refresh must publish it. Land
## weathers on a worker instead (`_weather_async`).
func _weather_land() -> bool:
	if mode != "land" or brush_id == "land": return false
	var brush = creation_brush()
	# A settling brush (water) has nothing to finish here; its pour closes it.
	if brush.settles or not brush.has_bounds: return false
	_stroke_rect = brush.finish(data)
	return true

## A land stroke's weathering (land_brush.gd `weather_job`) runs on a worker
## from the heights at release, and the stroke's settle refresh starts when it
## lands, a few frames on. It lands after `end_stroke`, outside the undo step,
## which still holds the ground from before the stroke, so one undo removes
## the land and its weathering together. Anything that opens a new transaction
## first joins it (`data.stroke_starting`), so a quick second stroke starts
## from weathered ground. Undo, a regrow or any other height change drops it.
##
## Weathering that lands on its own (a spring's or a mountain's, nothing
## pressing) is not swapped in at once: the ground and its rock colour ease
## from the release's to the weathered over WEATHER_EASE_SECONDS, shown through
## the light refresh, so the gullies wear in rather than appearing in a frame.
## Anything that would have joined the weathering takes the eased ground whole.
const WEATHER_EASE_SECONDS := 1.2
var land_settling := false
var _weather_job: RefCounted
var _weather_generation := 0
var _weather_heights := PackedFloat32Array()
var _weather_region := Rect2()
var _weather_ease := {}

func _weather_async(job: Callable, region: Rect2) -> void:
	_drop_weathering()
	_weather_generation += 1
	var generation := _weather_generation
	_weather_heights = data.heights
	_weather_region = region
	var work: RefCounted = preload("res://scripts/background_work.gd").new()
	work.start(job)
	_weather_job = work
	land_settling = true
	emergence.ground_settling = true
	# Dropped or joined work still runs out here, so it never blocks a frame.
	while generation == _weather_generation and not work.completed():
		await get_tree().process_frame
	if generation == _weather_generation: _land_weathering(true)
	while work.active() and not work.completed():
		await get_tree().process_frame
	if work.active(): work.finish()

## Publish finished (or, joining, finishing) weathering. `settle` starts the
## stroke's settle refresh; a joining stroke leaves that to its own release.
func _land_weathering(settle: bool) -> void:
	var job: RefCounted = _weather_job
	_drop_weathering()
	if job == null: return
	# A stroke that opens while the worker still runs waits for it here, so
	# it starts from weathered ground rather than dropping the weathering.
	var result: Dictionary = job.finish() if job.completed() else job.wait()
	land_brush.last_weather_usec = result.usec
	var fresh := not forming and data.heights == _weather_heights
	var heights: PackedFloat32Array = result.heights if result.moved and fresh else data.heights
	# A mountain's rock colour (scripts/mountain_forms.gd) comes with it.
	var tint: PackedFloat32Array = result.tint if fresh and result.has("tint") else data.tint
	if settle and fresh and (result.moved or tint != data.tint) and _light_refresh_ready(true):
		_ease_weathering(heights,tint,result.moved)
		return
	if result.moved and fresh:
		data.heights = heights
		land_weathered.emit(_weather_region)
	data.tint = tint
	_settle_pending = true
	if settle: _settle_stroke()

## Ease the land from the ground at release to the weathered `heights` and
## `tint`, then settle as a landing does. The ease stops where it stands if
## the heights change under it (an undo, a regrow), and any joining stroke
## or pour takes it whole (`_finish_weather_ease`).
func _ease_weathering(heights: PackedFloat32Array, tint: PackedFloat32Array, moved: bool) -> void:
	var from_h := data.heights
	var from_t := data.tint
	var moved_h := PackedInt32Array()
	for i in range(mini(heights.size(),from_h.size())):
		if heights[i] != from_h[i]: moved_h.append(i)
	var moved_t := PackedInt32Array()
	if tint.size() == from_t.size():
		for i in range(tint.size()):
			if tint[i] != from_t[i]: moved_t.append(i)
	var ease := {"heights":heights,"tint":tint,"moved":moved,"region":_weather_region}
	_weather_ease = ease
	land_settling = true
	emergence.ground_settling = true
	var t := 0.0
	var written := from_h
	while true:
		await get_tree().process_frame
		if not is_same(_weather_ease,ease): return
		if forming or data.heights != written:
			_weather_ease = {}
			land_settling = false
			emergence.ground_settling = false
			return
		t += get_process_delta_time()/WEATHER_EASE_SECONDS
		if t >= 1.0:
			_finish_weather_ease(true)
			return
		var k := smoothstep(0.0,1.0,t)
		var h := from_h.duplicate()
		for i in moved_h: h[i] = lerpf(from_h[i],heights[i],k)
		data.heights = h
		written = h
		if not moved_t.is_empty():
			var c := from_t.duplicate()
			for i in moved_t: c[i] = lerpf(from_t[i],tint[i],k)
			data.tint = c
		if refresh_pending == 0: _refresh_light()

## Put the easing weathering down whole. `settle` starts the settle refresh.
func _finish_weather_ease(settle: bool) -> void:
	var ease := _weather_ease
	if ease.is_empty(): return
	_weather_ease = {}
	land_settling = false
	emergence.ground_settling = false
	data.heights = ease.heights
	if ease.tint.size() == data.tint.size() or data.tint.is_empty(): data.tint = ease.tint
	if ease.moved: land_weathered.emit(ease.region)
	_settle_pending = true
	if settle: _settle_stroke()

func _drop_weathering() -> void:
	_weather_generation += 1
	_weather_job = null
	_weather_ease = {}
	land_settling = false
	emergence.ground_settling = false

func _join_weathering() -> void:
	_finish_weather_ease(false)
	if _weather_job != null: _land_weathering(false)

# --- Mountain forms ---------------------------------------------------------------
## A land press with a mountain form in hand raises one whole mountain
## (scripts/mountain_forms.gd): the drag sets its spread and height, it rises
## while held and finishes rising after release (`_mountain_rise`), then lands
## (`_land_mountain`): its undo step closes and its weathering and rock
## colour run on a worker through `_weather_async`, as a land stroke's do.
## Anything that opens a new transaction lands a rising mountain first, so
## one undo always takes a whole mountain.
var _mountain_holding := false
## The land spring (scripts/land_spring.gd, `--modeless`) when there is one:
## a pull or a springing land settles before anything else changes the ground.
var spring: Node = null
## Land as clay (scripts/land_clay.gd, `--modeless`) when there is one: a
## stroke or pinch in hand closes before anything else changes the ground.
var clay: Node = null
var _mountain_generation := 0
var _mountain_plane := 0.0
var _mountain_poured := Rect2()
var _mountain_elapsed := 0.0

## What the God Hand (scripts/god_hand.gd) is doing with the tool in hand:
## "pinch" while land rises, "press" while it is lowered, "cup" while a
## water ball is held, "sprinkle" while pollen is laid, "" otherwise ("cup"
## and "sprinkle" show the hand only under `--hand-everywhere`). Wind,
## meadow and path have no gesture yet.
func hand_gesture() -> String:
	if _ball_holding: return "cup"
	if _handful_holding: return "sprinkle"
	if _mountain_holding: return "pinch"
	# Wind in hand from the sky: the open hand blows.
	if gust != null and gust.aiming(): return "void"
	if _painting and mode == "land" and brush_id == "land":
		return "press" if _land_lower or Input.is_key_pressed(KEY_SHIFT) else "pinch"
	return ""

## Where the God Hand works when it is not under the pointer: the summit of
## a mountain rising under a held press, which the pinch holds and pulls up
## however far the drag goes. The highest of the centre and a ring round it,
## so a volcano is held by its rim. Plate coordinates, or null.
func hand_work_point() -> Variant:
	if not _mountain_holding or not mountain.active: return null
	var best: Variant = null
	for k in range(9):
		var p: Vector2 = mountain.center
		if k > 0: p += Vector2.RIGHT.rotated(TAU*k/8.0)*mountain.spread*0.2
		var h: Variant = data.ground_height(p)
		if h != null and (best == null or float(h) > best.y): best = Vector3(p.x,float(h),p.y)
	return best

func mountain_in_hand() -> bool:
	return mode == "land" and brush_id == "land" and land_form != "hill"

func select_land_form(id: String) -> bool:
	if not id in mountain.form_ids(): return false
	if id != land_form:
		finish_stroke()
		land_form = id
		land_form_changed.emit(id)
	if brush_id == "land" and mode == "land": _set_status(str(mountain.form_entry(id).hint))
	return true

## Step through the land forms (1 again in the creation shell).
func cycle_land_form(step := 1) -> void:
	select_land_form(mountain.cycled(land_form,step))

## The circle the terrain shader draws: the spread a press would start from,
## or the rising mountain's.
func mountain_preview_radius() -> float:
	if _mountain_holding: return mountain.spread
	var shape: Dictionary = mountain.SHAPES[land_form]
	return clampf(land_radius*shape.spread.z,shape.spread.x,shape.spread.y)

func _mountain_press(hit: Vector3) -> void:
	_land_mountain()
	mountain.prepare(data,land_seed)
	_mountain_generation += 1
	_stroke_first_id = data.next_id
	_painting = true
	_mountain_holding = true
	_mountain_elapsed = 0.0
	_last_point = Vector2(hit.x,hit.z)
	_mountain_plane = hit.y
	data.begin_stroke()
	var right: Vector3 = terrain.global_basis.inverse()*scene.camera.global_basis.x
	mountain.begin(data,land_form,_last_point,land_radius,land_strength,Vector2(right.x,right.z))
	_mountain_feel(0)

## The pointer on the press's ground plane, so the rising flank under it never
## shrinks the drag. Null when the ray misses the plane.
func _mountain_aim(pointer: Vector2) -> Variant:
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(pointer))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(pointer)).normalized()
	var hit: Variant = Plane(Vector3.UP,_mountain_plane).intersects_ray(origin,direction)
	return Vector2(hit.x,hit.z) if hit != null else null

func _mountain_step(pointer: Vector2, delta: float) -> void:
	var aim: Variant = _mountain_aim(pointer)
	if aim != null: mountain.aim(data,aim)
	_mountain_tick(delta)

## Rise at the paint loop's 30 Hz, each tick one light refresh.
func _mountain_tick(delta: float) -> bool:
	_mountain_elapsed += minf(delta,0.05)
	if _mountain_elapsed < 1.0/30.0: return false
	var speed: float = mountain.advance(data,_mountain_elapsed)
	if _painting: refresh()
	elif _light_refresh_ready(true): _refresh_light()
	else: return true
	_mountain_feel(1,speed,_mountain_elapsed)
	_mountain_elapsed = 0.0
	return false

## After release: finish rising, then land.
func _mountain_rise() -> void:
	var generation := _mountain_generation
	var last := Time.get_ticks_usec()
	while mountain.active and not mountain.risen():
		await get_tree().process_frame
		if generation != _mountain_generation or not mountain.active: return
		var now := Time.get_ticks_usec()
		# The view cannot take a light refresh (it is rebuilding): land now.
		if _mountain_tick((now-last)/1000000.0): break
		last = now
	if generation == _mountain_generation: _land_mountain()

## Close the rising mountain's undo step at its full height, and hand its
## weathering to a worker and its ground to emergence.
func _land_mountain() -> void:
	if not mountain.active: return
	_mountain_generation += 1
	if _mountain_holding:
		_mountain_holding = false
		_painting = false
		_stroke_button = MOUSE_BUTTON_LEFT
	mountain.settle(data)
	var region: Rect2 = mountain.bounds
	var weathering: Callable = mountain.weather_job(data)
	data.mark_objects_hand(_stroke_first_id)
	var changed := data.end_stroke()
	_mountain_elapsed = 0.0
	_stroke_rect = region.grow(1.0)
	if changed and weathering.is_valid(): _weather_async(weathering,region)
	else: _settle_stroke()
	if changed: _stroke_ended("land")
	_stroke_rect = Rect2()
	_mountain_feel(2)
	mountain.active = false

## Another transaction is opening while a mountain rises: land it, weathered.
func _mountain_interrupted() -> void:
	if not mountain.active: return
	_land_mountain()
	_join_weathering()

## REGEN-POLISH SWAP: the one place a mountain's rumble and fog are driven.
## `phase` 0 press, 1 a rising tick (`speed` 0..1 of its quickest, over
## `seconds`), 2 landed. With WorldRumble (feature/regen-polish,
## scripts/world_rumble.gd, `scene.world_rumble`) it holds a heavy rolling
## rumble for the whole rise and pours fog off the flanks; without it the
## stroke signals' rate drives StrokeFeedback's tremor instead. The stroke
## signals go out either way (as "mountain": fog reveal, swell, gusts, the
## thump and GenesisAudio's rumble voice).
func _mountain_feel(phase: int, speed := 0.0, seconds := 0.0) -> void:
	var rumble: Node = scene.get("world_rumble") as Node
	var at := Vector3(mountain.center.x,mountain.ground,mountain.center.y)
	var heft := clampf(mountain.height/10.0,0.4,1.0)
	var flank := Rect2(mountain.center-Vector2.ONE*mountain.spread*1.3,Vector2.ONE*mountain.spread*2.6)
	match phase:
		0:
			_emit_stroke(0,at,mountain.spread,0.0)
			if rumble != null:
				rumble.hold(&"mountain",0.5*heft)
				rumble.pour_fog(flank,RISE_FOG_SECONDS)
				_mountain_poured = flank
		1:
			if rumble != null:
				rumble.hold(&"mountain",clampf((0.45+0.55*speed)*heft,0.0,1.0))
				# A drag that outgrew the pour spreads it again.
				if not _mountain_poured.encloses(flank.grow(-1.0)):
					rumble.pour_fog(flank,RISE_FOG_SECONDS)
					_mountain_poured = flank
			_emit_stroke(1,at,mountain.spread,0.0 if rumble != null else 2.0*seconds*maxf(speed,0.35)*heft)
		_:
			if rumble != null: rumble.release(&"mountain")
			_emit_stroke(2,at,mountain.spread,0.0)
## Seconds the poured fog holds before draining, from press or regrowth.
const RISE_FOG_SECONDS := 4.0

# --- Pollen -------------------------------------------------------------------
## Seed (scripts/seed_throw.gd, docs/scenic/brushes.md "Pollen"): with
## forest in hand, holding the button fills a handful and throws it at the
## pointer, a throw every second or so (the God Hand's, when it is out), and
## release throws the last of it. Seeds fly on real momentum and the wind and
## land where they land; you throw it, the world decides what becomes of it.
## When a sowing's last seed is down its seeds raise the forest wish round
## them (ForestBrush `sow`) as one undo step, and go to emergence, where the
## land decides what takes and grows (Emergence `_fertility`). Shift-drag
## still clears as before, --paint-forest brings back drag-to-paint, and
## --pollen-veil the veil laid in the air along the sweep
## (scripts/pollen_cloud.gd), which the throws replaced.
var seed_handful := "--paint-forest" not in OS.get_cmdline_user_args()
var handful: Node3D
var _handful_holding := false
var _handful_serial := 0
## Settled clouds waiting for no other stroke to be open.
var _settled_clouds: Array[Dictionary] = []
## The last cloud sown, for probes: the cloud (Pollen `settled`) with its
## "bounds" and "changed".
var last_sowing := {}

## True while pollen is the forest tool in hand and a press would gather it.
func _pollen_in_hand() -> bool:
	return mode == "land" and brush_id == "forest" and seed_handful and not other_way and not Input.is_key_pressed(KEY_SHIFT)

func _make_pollen() -> void:
	# The hand scheme flings the veil from a tree (docs/scenic/sky-cloud.md
	# "Seeds"); the brush throws seed.
	var veil := "--pollen-veil" in OS.get_cmdline_user_args() or preload("res://scripts/modeless_input.gd").enabled()
	handful = (preload("res://scripts/pollen_cloud.gd") if veil else preload("res://scripts/seed_throw.gd")).new()
	handful.name = "Pollen"
	handful.scene = scene
	terrain.add_child(handful)
	handful.settled.connect(_pollen_settled)
	handful.ground_at = func(p: Vector2) -> float:
		var h: Variant = data.ground_height(p)
		return float(h) if h != null else NAN
	handful.takes = func(p: Vector2) -> bool: return emergence.takes(p)
	# Undo, load and new worlds take the ground away: sprouts and clouds still
	# out go with it. An undo settles the clouds first (_history_step).
	data.state_restored.connect(func(_state: Dictionary) -> void:
		_handful_holding = false
		_settled_clouds.clear()
		handful.withdraw())

func _handful_press(hit: Vector3, forest: Variant = null, kind := "") -> void:
	if handful == null: _make_pollen()
	_handful_serial += 1
	if forest == null: forest = creation_brush()
	forest.prepare(data,land_seed)
	var family: String = kind if not kind.is_empty() else emergence.seed_family(Vector2(hit.x,hit.z))
	handful.set("seed_kind",kind)
	handful.gather(hit,forest.radius,forest.strength,family,hash([land_seed,_handful_serial]))
	# No stroke starts: the brush feel's swell would raise the very wind the
	# cloud drifts on. The settled cloud reports its stroke (`_write_cloud`).
	_handful_holding = true

## Aiming shows a click's footprint under the pointer; a held veil is laid
## along the pointer's way. Settled veils are written once no other stroke is
## open.
func _handful_process(hit: Variant, delta: float) -> void:
	var aiming := _pollen_in_hand() and not _painting and not forming and active
	if handful == null:
		if not aiming or hit == null: return
		_make_pollen()
	handful.hover(hit if aiming else null,float(brushes.forest.radius))
	if _handful_holding:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or scene._growth.terrain < 0.995: _handful_release()
		else: handful.hold(hit)
	while not _settled_clouds.is_empty() and data._before.is_empty() and not forming:
		_write_cloud(_settled_clouds.pop_front())

## A tree flicked in the hand (--modeless, scripts/hand_reach.gd): its spores
## burst from `crown` (plate) and fly `reach` m along `direction` (plate, unit)
## from its foot `base`, laid as a veil along that line and let go at once, at
## `strength` times the forest brush's. `kind` is the tree they came from ("":
## the stand decides). The line stops where the land does. True when it flew.
func fling_from_tree(base: Vector3, crown: Vector3, direction: Vector2, reach: float, kind: String, strength: float) -> bool:
	if forming or not active or _ball_holding or _handful_holding or _painting: return false
	var path := []
	var d := FLING_FROM
	while d <= reach:
		var at := Vector2(base.x,base.z)+direction*d
		var ground: Variant = data.ground_height(at)
		if ground == null: break
		path.append(Vector3(at.x,float(ground),at.y))
		d += FLING_STEP
	if path.is_empty(): return false
	_land_mountain()
	if handful == null: _make_pollen()
	_handful_serial += 1
	var forest = brushes.forest
	forest.prepare(data,land_seed)
	var family: String = kind if not kind.is_empty() else emergence.seed_family(Vector2(base.x,base.z))
	handful.set("seed_kind",kind)
	var velocity := Vector3(direction.x,0.0,direction.y)*reach*FLING_SPEED+Vector3.UP*FLING_LOFT
	handful.fling(crown,velocity,path,forest.radius,forest.strength*strength,family,hash([land_seed,_handful_serial]))
	return true

## Seeds from the materials tray (scripts/hand_materials.gd): a press with
## seeds in hand lays the forest brush's veil from the pointer's ground point,
## as the Forest brush's press does, held until the button is let go; the wind
## and the land then decide. `kind` is the tree the seeds are of (an emergence
## tree kind: "broadleaf", "tree", "willow", "birch"), stamped on the veil as a
## flicked tree's spores are, so its sprouts lean to that kind as far as the
## ground allows (Emergence `_heir_kind`); "" lets the stand pick. True when
## the veil was taken.
##
## Flower seed (a FlowerSowing slot: "wildflower", "dandelion", "poppy",
## "cosmos", "sunflower") lays its own lighter veil instead, `size` times its
## radius (the materials' pips), stamped with the slot; where it settles the
## ground decides what takes and it comes up as a drift (`_write_flowers`).
func sow_from_hand(screen_pos: Vector2, kind := "", size := 1.0) -> bool:
	if forming or not active or _ball_holding or _handful_holding or _painting: return false
	var hit: Variant = pick(screen_pos)
	if hit == null: return false
	_land_mountain()
	if FlowerSowing.has(kind): return _flower_press(hit,kind,size)
	_handful_press(hit,brushes.forest,kind)
	return true

## Flower seed from the hand: the veil (scripts/pollen_cloud.gd) in the
## seed's own look, closer-falling and carried further by the air
## (FlowerSowing SPREAD, CARRY), its sprouts showing where the ground takes
## flower seed. False without the veil (the classic brush's seed throw).
func _flower_press(hit: Vector3, kind: String, size: float) -> bool:
	if handful == null: _make_pollen()
	if not handful.has_method("toss"): return false
	_handful_serial += 1
	handful.set("seed_kind",kind)
	var sowing := _flower_sowing(kind)
	var look := {"colour":FlowerSowing.look(kind),"spread":FlowerSowing.SPREAD,"carry":FlowerSowing.CARRY,"takes":func(p: Vector2) -> bool: return sowing.suits(p)}
	handful.gather(hit,FlowerSowing.RADIUS*size,FlowerSowing.STRENGTH,"",hash([land_seed,_handful_serial]),look)
	_handful_holding = true
	return true

## The sowing of flower `kind` on this world's ground: its wetness from the
## live water and the emergence blend, its habitat from the blend.
func _flower_sowing(kind: String) -> RefCounted:
	var sowing := FlowerSowing.new(data,kind,land_seed)
	var depths := PackedFloat32Array()
	if flow != null and flow.ready: depths = flow.kernel.get_depth()
	var live: RefCounted = flow if not depths.is_empty() else null
	sowing.wet = func(p: Vector2) -> bool:
		if live != null:
			var cell: int = live.cell_at(p)
			if cell >= 0 and cell < depths.size() and depths[cell] >= FLOWER_WET_DEPTH: return true
		return emergence._blend != null and emergence._wet(p)
	sowing.habitat = func(p: Vector2) -> String: return str(emergence._blend.pick(p)) if emergence._blend != null else ""
	return sowing
## Live water at least this deep (m) keeps flower seed off.
const FLOWER_WET_DEPTH := 0.02
const FlowerSowing = preload("res://scripts/flower_sowing.gd")

# --- Painting flowers ------------------------------------------------------------
## Flowers painted from the hand (scripts/flower_paint.gd, docs/scenic/
## handful.md "Flower seed"): with a flower slot in hand a press on the land
## paints. The press opens one undo step and lays a tap's dab; each frame the
## held press paints along the pointer's way (`_flower_paint_process`), and
## what it places shows that frame through the view's paint preview
## (GardenView `paint_preview`, `paint_hide`), with no refresh while the button
## is down; the release lays the ground's faint wash, closes the step and
## settles the view once (a yielding refresh: its instances are sampled on a
## worker). The stroke in hand, or null.
var flower_paint: RefCounted = null
const FlowerPaint = preload("res://scripts/flower_paint.gd")
## The last stroke's summary (FlowerPaint `finish`, with "changed"), and the
## main-thread microseconds each painted frame took, for probes.
var last_paint := {}
var paint_usec: Array[int] = []

## Paint flower `slot` from the hand at `screen_pos`, the brush `size` times
## its own (the roll's pips), thinning instead when `thinning` (Shift). True
## when the stroke began.
func paint_flowers_begin(screen_pos: Vector2, slot: String, size := 1.0, thinning := false) -> bool:
	if forming or not active or _ball_holding or _handful_holding or _painting or flower_paint != null: return false
	if not FlowerSowing.has(slot): return false
	var hit: Variant = pick(screen_pos)
	if hit == null: return false
	_land_mountain()
	paint_usec.clear()
	var began := Time.get_ticks_usec()
	data.begin_stroke()
	_handful_serial += 1
	flower_paint = FlowerPaint.new(_flower_sowing(slot),size,thinning,hash([land_seed,_handful_serial,7919]))
	_show_paint(flower_paint.press(Vector2(hit.x,hit.z)))
	paint_usec.append(Time.get_ticks_usec()-began)
	return true

func _show_paint(made: Dictionary) -> void:
	if not made.records.is_empty(): content.paint_preview(made.records)
	if not made.removed.is_empty():
		if dandelions != null: dandelions.cleared(made.removed)
		content.paint_hide(made.removed)

## Each frame while the flowers' press is held: paint under the pointer.
func _flower_paint_process(hit: Variant, delta: float) -> void:
	if flower_paint == null: return
	# Undone or reloaded under the brush: the stroke is gone with its step.
	if data._before.is_empty() or forming:
		flower_paint = null
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or scene._growth.terrain < 0.995:
		paint_flowers_end()
		return
	if hit == null:
		flower_paint.lift()
		return
	var began := Time.get_ticks_usec()
	_show_paint(flower_paint.stroke(Vector2(hit.x,hit.z),delta))
	paint_usec.append(Time.get_ticks_usec()-began)

## The flowers' press comes up: the wash, one undo step, one settle.
func paint_flowers_end() -> void:
	if flower_paint == null: return
	var stroke: RefCounted = flower_paint
	flower_paint = null
	if data._before.is_empty(): return
	var began := Time.get_ticks_usec()
	var summary: Dictionary = stroke.finish()
	summary.finish_usec = Time.get_ticks_usec()-began
	began = Time.get_ticks_usec()
	summary.changed = data.end_stroke()
	summary.end_stroke_usec = Time.get_ticks_usec()-began
	began = Time.get_ticks_usec()
	_settle_pending = true
	_settle_stroke()
	summary.settle_call_usec = Time.get_ticks_usec()-began
	var bounds: Rect2 = summary.bounds
	var middle := bounds.get_center()
	var ground: Variant = data.ground_height(middle)
	_emit_stroke(2,Vector3(middle.x,float(ground) if ground != null else 0.0,middle.y),bounds.size.length()*0.5,0.0)
	last_paint = summary

## A stone set down by the hand (the materials tray), placed as the rock
## tool's click places one (`set_objects`).
func set_stone(point: Vector2, size: float, angle: float, after: Variant = null) -> Variant:
	return set_objects([{"asset":"rock","point":point,"size":size,"angle":angle}],after)

## Things set down by the hand (the materials tray, scripts/hand_materials.gd):
## stones, wildflowers, reeds. Each of `items` ({"asset", "point" (plate x, z),
## "size", "angle"}) is placed as the build palette's click places one, marked
## hand work, all in one undo step, and arrives as NativeDropReactions has it
## (a stone falls, a plant sprouts). `after` is the undo step of the last set
## down in the same drag: while that is still the step under this one, this
## one folds into it, so a scattering drag undoes as one. Returns the undo step
## they lie in, or null when none was placed.
func set_objects(items: Array, after: Variant = null) -> Variant:
	if forming or not active or _painting: return null
	_land_mountain()
	data.begin_stroke()
	var placed: Array[int] = []
	for item: Dictionary in items:
		if data.ground_height(item.point) == null: continue
		var id := data.place(item.asset,item.point,float(item.angle),float(item.size))
		if id < 0: continue
		data.mark_objects_hand(id)
		placed.append(id)
	if not data.end_stroke() or placed.is_empty(): return null
	var step: Dictionary = data._undo.back()
	if after != null and data._undo.size() >= 2 and is_same(data._undo[-2],after):
		data._undo.pop_back()
		step = after
	# The arrival starts the frame they are drawn, before they can sit still.
	refresh(get_tree(),func(stage: String) -> void:
		if stage != "content" or not reactions_enabled: return
		for id in placed:
			var index := data._object_index(id)
			if index >= 0: reactions.play(str(data.objects[index].asset),reactions.record_pose(data.objects[index]),data.objects[index],id))
	return step

## A flicked tree's veil starts FLING_FROM m out from its foot, with a knot
## each FLING_STEP m; its spores leave the crown at FLING_SPEED times the
## reach a second, lofted FLING_LOFT m/s.
const FLING_FROM := 1.0
const FLING_STEP := 0.5
const FLING_SPEED := 1.4
const FLING_LOFT := 2.0

func _handful_release() -> void:
	if not _handful_holding: return
	_handful_holding = false
	handful.release()

func _pollen_settled(cloud: Dictionary) -> void:
	if forming: return
	_settled_clouds.append(cloud)
	if data._before.is_empty(): _write_cloud(_settled_clouds.pop_front())

## A settled cloud's seeds ask for forest, as one undo step, and go to
## emergence, which grows the forest out from them as the land allows.
func _write_cloud(cloud: Dictionary) -> void:
	if FlowerSowing.has(str(cloud.get("kind",""))):
		_write_flowers(cloud)
		return
	var forest = brushes.get("forest")
	var seeds: PackedVector2Array = cloud.seeds
	if forest == null or seeds.is_empty(): return
	forest.prepare(data,land_seed)
	# The brush knows the editor only while it is in hand; a veil from the sky
	# or a tree (the hand scheme) sows with it out of hand.
	var in_hand: Node = forest.editor
	forest.editor = self
	forest.begin()
	data.begin_stroke()
	for p in seeds: forest.sow(data,p)
	var bounds: Rect2 = forest.finish(data)
	forest.editor = in_hand
	var changed := data.end_stroke()
	_settle_pending = true
	_settle_stroke()
	if changed and emergence_enabled and bounds.has_area(): emergence.on_region_changed(bounds,"forest",seeds,str(cloud.get("kind","")))
	var middle := bounds.get_center()
	_emit_stroke(2,Vector3(middle.x,float(data.sample(middle,data.heights)),middle.y),bounds.size.length()*0.5,0.0)
	last_sowing = cloud.duplicate()
	last_sowing.bounds = bounds
	last_sowing.changed = changed

## A settled veil of flower seed: where its motes came down the ground
## decides, and what takes comes up as a drift of the seed's kind, blooming in
## the order it landed (scripts/flower_sowing.gd `grow`), one undo step.
func _write_flowers(cloud: Dictionary) -> void:
	var points: PackedVector2Array = cloud.get("points",PackedVector2Array())
	if points.is_empty(): return
	var sowing := _flower_sowing(str(cloud.kind))
	data.begin_stroke()
	var grown: Dictionary = sowing.grow(points,cloud.get("times",PackedFloat32Array()),int(cloud.get("id",0))+_handful_serial*7919,preload("res://scripts/emergence.gd").time)
	var changed := data.end_stroke()
	_settle_pending = true
	_settle_stroke()
	var bounds: Rect2 = grown.bounds
	var middle := bounds.get_center()
	_emit_stroke(2,Vector3(middle.x,float(data.sample(middle,data.heights)),middle.y),bounds.size.length()*0.5,0.0)
	last_sowing = cloud.duplicate()
	last_sowing.bounds = bounds
	last_sowing.changed = changed
	last_sowing.flowers = grown
