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
	"land":"Drag to raise land · Shift or right drag lowers · [ ] brush size",
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
var land_radius := 4.5
var land_strength := 1.0
var land_ceiling := 10.0
## Seeds the brush's ridge field; the owning scene sets it per world.
var land_seed := 0
## Emitted after a land stroke's erosion pass settles into the heights.
signal land_weathered(bounds: Rect2)
var _land_lower := false
## The button holding the current land stroke; every other stroke is a left drag.
var _stroke_button := MOUSE_BUTTON_LEFT
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
## The water brush (scripts/water_brush.gd): poured water is planned on a
## worker and shows while the hand pours (`_pour_live`), one undoable edit.
var water_brush = preload("res://scripts/water_brush.gd").new()
## True from a pour's release until it closes.
var water_settling := false
## Emitted when settled water lands in the world; `bounds` in plate metres.
signal water_settled(bounds: Rect2)

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	terrain = scene.get_node("Reference/terrain")
	terrain.add_child(pond_preview)
	data.setup(terrain.mesh)
	data.stroke_starting.connect(_join_weathering)
	# Plans run on a worker; the editor's frames must not wait for them.
	emergence.plan_on_worker = true
	_original_ground_map = scene._precipitation.ground_texture.get_image()
	_original_stream_map = scene._precipitation.stream_texture.get_image()
	_original_bird_ground = scene._bird_flight.ground
	_original_precip_top = scene._precipitation._materials[0].get_shader_parameter("top")
	_skirt = scene.get_node("Reference/skirt")
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
	if mode == "land": return brush_radius()
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
	if mode in ["assets","select","pond"]:
		return false
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
	return mode in ["flower","mountain"] or (mode == "assets" and catalog_asset in ["button_flower","daisy_flower","spike_flower","umbel_flower"])

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

func _process(delta: float) -> void:
	# Emergence refreshes yield like a stroke's settle: the worker samples
	# instances and the budget spreads the rest, so a step never stalls a frame.
	if not forming and emergence.advance(delta):
		refresh(get_tree())
	_warm_face_probes()
	if forming or not active:
		pond_preview.clear()
		return
	if (_painting or _selection_drag) and (not Input.is_mouse_button_pressed(_stroke_button) or scene._growth.terrain < 0.995):
		finish_stroke()
	var pointer: Vector2 = pointer_override if pointer_override != null else scene.get_viewport().get_mouse_position()
	var hit: Variant = pick(pointer) if not scene._orbiting and not scene._panning else null
	if mode == "pond":
		var message: String = pond_preview.hover(data,hit,pond_level,delta)
		if not message.is_empty() and message != status: _set_status(message)
	_material.set_shader_parameter("brush_visible",hit != null and preview_wanted())
	if hit != null:
		var center := Vector2(hit.x,hit.z)
		_material.set_shader_parameter("brush_center",center)
		_material.set_shader_parameter("brush_radius",preview_radius())
		if _painting and placement_trail and trail_available():
			continue_trail(center)
			_emit_stroke(1,hit,preview_radius(),delta)
		elif _painting and mode == "land":
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
	_selection_drag = false
	end_selection_edit()
	if not _painting:
		return
	_painting = false
	_trail_point = null
	_elapsed = 0.0
	_last_point = null
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
## stroke_finished signal can take it over.
func _stroke_ended(kind := "") -> void:
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
	_lift_anchors(original)
	if frame_tree != null:
		await budget.checkpoint()
		if not current.call(): return _finish_refresh(false)
	sync_visibility()
	_rebuild_skirt()
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
	var rim_unchanged := true
	for i in range(data.points.size()):
		var point := data.points[i]
		if maxf(absf(point.x),absf(point.y)) > 13.9999 and data.heights[i] != data.original_heights[i]:
			rim_unchanged = false
			break
	if rim_unchanged:
		_skirt.mesh = _skirt_mesh
		return
	# Deform the original faceted earth sides, keeping their base and material.
	# The captured rim extends 0.2 units beyond the terrain's outer edge.
	var arrays := _skirt_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var low := _skirt_mesh.get_aabb().position.y
	var high := _skirt_mesh.get_aabb().end.y
	for i in range(vertices.size()):
		var world := _skirt.to_global(vertices[i])
		var local := terrain.to_local(world)
		var point := Vector2(local.x,local.z).clamp(Vector2(-14,-14),Vector2(14,14))
		vertices[i].y += data.delta_at(point) * clampf((vertices[i].y-low)/(high-low),0.0,1.0)
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3):
			normals[i+j] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,_skirt_mesh.surface_get_material(0))
	_skirt.mesh = mesh

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
	return brush_id if mode == "land" else mode

## A left press paints and a right press works the other way (Shift either
## way): land rises and lowers, forest grows and clears, and so on.
## A press that misses the land, or holds Alt, falls through to the camera, so
## the sky still orbits with either button.
func _land_press(event: InputEventMouseButton) -> bool:
	if not event.pressed:
		if _painting and event.button_index == _stroke_button: finish_stroke()
		return _painting or event.button_index == MOUSE_BUTTON_LEFT
	if _painting or event.alt_pressed: return _painting
	var hit: Variant = pick(event.position)
	if hit == null: return false
	_stroke_button = event.button_index
	_land_lower = event.button_index == MOUSE_BUTTON_RIGHT
	var brush = creation_brush()
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
		if data.end_stroke() and pour.rect.has_area():
			# Grass creeps out from new shores (scripts/emergence.gd).
			_stroke_rect = pour.rect
			_stroke_ended("water")
			_stroke_rect = Rect2()
			water_settled.emit(pour.rect)
	_hold_reflections()

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
var land_settling := false
var _weather_job: RefCounted
var _weather_generation := 0
var _weather_heights := PackedFloat32Array()
var _weather_region := Rect2()

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
	if result.moved and not forming and data.heights == _weather_heights:
		data.heights = result.heights
		land_weathered.emit(_weather_region)
	_settle_pending = true
	if settle: _settle_stroke()

func _drop_weathering() -> void:
	_weather_generation += 1
	_weather_job = null
	land_settling = false
	emergence.ground_settling = false

func _join_weathering() -> void:
	if _weather_job != null: _land_weathering(false)
