class_name NativeChunkEditor
extends Node
## Build tools attached to the live fidelity scene. Entering Build never swaps
## the chunk, camera, environment or shader; only the controls become active.
const GROUPS := [
	["Sculpt",["raise","lower","smooth","flatten"]],
	["Landscape",["ground","range","mountain"]],
	["Cover",["grass","blades","meadow","paint","erase"]],
	["Place",["tree","rock","flower","arch","bigfoot_tree","assets"]],
	["Water",["pond","waterfall"]],
]
const TOOL_TEXT := {
	"raise":"Build hills with slow, gentle strokes.",
	"lower":"Press valleys and hollows into the land.",
	"smooth":"Soften slopes and blend your brushwork.",
	"flatten":"Level toward the height where you click.",
	"ground":"Set a resting height, then form the whole floor.",
	"range":"Shape a ridge across the chunk, then fill its water and flora.",
	"mountain":"Click to raise a peak. Variation reshuffles its ridges.",
	"grass":"Paint ground cover, or green the whole chunk at once.",
	"blades":"Paint standing blades over the grass.",
	"meadow":"Paint grass and wildflowers together.",
	"paint":"Brush your own colour over rock and grass.",
	"erase":"Brush away cover and placed objects. Undo restores them.",
	"tree":"Click to plant a tree. It settles onto the ground.",
	"rock":"Click to set a stone.",
	"flower":"Click to plant one flower. Zoom in for the detail.",
	"arch":"Click to raise a stone arch.",
	"bigfoot_tree":"Click to plant the tree Bigfoot visits.",
	"assets":"Pick a piece below, then click to place it.",
	"pond":"Dig a hollow, then click inside to fill it.",
	"waterfall":"Click the waterfall lip, then a lower landing point.",
}
## Every numeric setting a tool offers, in the order a shell should show them.
const SETTINGS := [
	{"property":"ground_elevation","title":"Ground elevation","low":-1.0,"high":8.0,"step":0.1,"unit":"","whole":false,"modes":["ground"]},
	{"property":"ground_relief","title":"Ground relief","low":0.0,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":["ground"]},
	{"property":"radius","title":"Brush size","low":0.4,"high":5.0,"step":0.05,"unit":"","whole":false,"modes":["raise","lower","smooth","flatten","grass","blades","meadow","paint","erase","pond"]},
	{"property":"strength","title":"Strength","low":0.4,"high":5.0,"step":0.05,"unit":"","whole":false,"modes":["raise","lower","smooth","flatten","meadow","erase"]},
	{"property":"grass_amount","title":"Ground coverage","low":0.0,"high":1.0,"step":0.05,"unit":"","whole":false,"modes":["grass"]},
	{"property":"blade_amount","title":"Blade density","low":0.0,"high":1.0,"step":0.05,"unit":"","whole":false,"modes":["blades"]},
	{"property":"paint_amount","title":"Paint opacity","low":0.05,"high":1.0,"step":0.05,"unit":"","whole":false,"modes":["paint"]},
	{"property":"range_height","title":"Range height","low":0.1,"high":1.8,"step":0.05,"unit":"","whole":false,"modes":["range"]},
	{"property":"range_width","title":"Range width","low":0.3,"high":1.5,"step":0.05,"unit":"","whole":false,"modes":["range"]},
	{"property":"range_heading","title":"Range rotation","low":-180.0,"high":180.0,"step":5.0,"unit":"°","whole":false,"modes":["range"]},
	{"property":"range_variation","title":"Range variation","low":0.0,"high":999.0,"step":1.0,"unit":"","whole":true,"modes":["range"]},
	{"property":"mountain_radius","title":"Mountain base radius","low":1.0,"high":12.0,"step":0.5,"unit":"","whole":false,"modes":["mountain"]},
	{"property":"mountain_peak","title":"Peak height","low":0.5,"high":24.0,"step":0.5,"unit":"","whole":false,"modes":["mountain"]},
	{"property":"mountain_variation","title":"Variation","low":1.0,"high":999.0,"step":1.0,"unit":"","whole":true,"modes":["mountain"]},
	{"property":"mountain_heading","title":"Ridge rotation","low":-180.0,"high":180.0,"step":5.0,"unit":"°","whole":false,"modes":["mountain"]},
	{"property":"pond_level","title":"Pond surface height","low":-1.4,"high":12.0,"step":0.05,"unit":"","whole":false,"modes":["pond"]},
	{"property":"object_scale","title":"Object size","low":0.1,"high":5.0,"step":0.1,"unit":"","whole":false,"modes":NativeTerrainData.ASSETS+["assets"]},
	{"property":"object_heading","title":"Rotation","low":-180.0,"high":180.0,"step":5.0,"unit":"°","whole":false,"modes":["tree","rock","flower","arch","bigfoot_tree","assets"]},
	{"property":"object_width","title":"Width","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"object_height","title":"Height","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"object_depth","title":"Depth","low":0.25,"high":3.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
	{"property":"object_pitch","title":"Tilt forward","low":-90.0,"high":90.0,"step":5.0,"unit":"°","whole":false,"modes":POSE_TOOLS},
	{"property":"object_roll","title":"Tilt sideways","low":-90.0,"high":90.0,"step":5.0,"unit":"°","whole":false,"modes":POSE_TOOLS},
	{"property":"object_elevation","title":"Vertical offset","low":-5.0,"high":10.0,"step":0.05,"unit":"","whole":false,"modes":POSE_TOOLS},
]
const POSE_TOOLS := ["tree","flower","rock","assets"]
## A shell listens to these to keep its widgets with the tool state, which
## hotkeys and scripted edits change just as often as the controls do.
signal tool_changed(tool: String)
signal setting_changed(property: String, value: float)
signal status_changed(text: String)
signal active_changed(enabled: bool)
signal sky_toggle_requested()
var scene: Node3D
var terrain: MeshInstance3D
var data := NativeTerrainData.new()
var content: GardenView
var landmarks: NativeGardenLandmarks
var falls: NativeGardenFalls
var reactions: NativeDropReactions
## Placement plays a short visual reaction. Tests that compare instances turn
## it off so a committed record renders exactly as it did before.
var reactions_enabled := true
var _fall_start: Variant = null
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
var save_path := "user://native-garden.json"
var active := false
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
var _map_blank := false
var _map_original := false
var _map_ready := false
var _bigfoot_mesh: Mesh

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	terrain = scene.get_node("Reference/terrain")
	data.setup(terrain.mesh)
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
	_fall_start = null
	mode = tool
	tool_changed.emit(tool)
	if TOOL_TEXT.has(tool):
		_set_status(TOOL_TEXT[tool])

## Radius the terrain shader should draw for the tool in hand.
func preview_radius() -> float:
	if mode == "mountain":
		return mountain_radius
	if mode == "flower":
		return 0.15*object_scale
	if mode in NativeTerrainData.ASSETS or mode == "assets":
		return 0.6*object_scale
	return radius

## The circle only reads truthfully where a footprint exists.
func preview_wanted() -> bool:
	if mode == "assets":
		return false
	return mode != "waterfall" or _fall_start == null

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
	if enabled and scene._growth.terrain < 0.995:
		active_changed.emit(active)
		return
	_fall_start = null
	active = enabled
	active_changed.emit(active)
	scene._orbiting = false
	if active:
		_previous_override = terrain.material_override
		_material = terrain.get_active_material(0).duplicate() as ShaderMaterial
		terrain.material_override = _material
	else:
		terrain.material_override = _previous_override
		_material = null

func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed):
		if event.keycode == KEY_Z:
			if event.shift_pressed: redo()
			else: undo()
			return true
		if event.keycode == KEY_Y:
			redo()
			return true
	if event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.meta_pressed:
		var tools := {KEY_1:"raise",KEY_2:"lower",KEY_3:"smooth",KEY_4:"flatten"}
		if tools.has(event.keycode) and not event.echo:
			select_tool(tools[event.keycode])
			return true
		if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			var step := 0.25 if event.keycode == KEY_BRACKETRIGHT else -0.25
			var property := "strength" if event.shift_pressed else "radius"
			set_setting(property,get(property)+step)
			return true
		if event.keycode == KEY_K and not event.echo and sky_toggle_requested.has_connections():
			sky_toggle_requested.emit()
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			finish_stroke()
			return true
		place_at(event.position)
		return true
	return false

## Apply the tool in hand at a mouse point, exactly as a left press does. The
## palette's drag-and-drop commits through here so a dropped object takes the
## same record, pose and reaction a click would have given it.
func place_at(mouse: Vector2) -> bool:
	if not active:
		return false
	var hit: Variant = pick(mouse)
	if hit == null:
		return false
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
	_level = hit.y
	_last_point = Vector2(hit.x,hit.z)
	var placed := -1
	if mode in NativeTerrainData.ASSETS or mode in ["pond","mountain","assets"]:
		if mode == "mountain":
			data.mountain(_last_point,mountain_radius,mountain_peak,mountain_variation,deg_to_rad(mountain_heading))
		elif mode == "pond":
			if not data.add_pond(_last_point,pond_level):
				_set_status("Dig a hollow, then set water below its banks.")
		else:
			placed = data.place(catalog_asset if mode == "assets" else mode,_last_point,object_angle,object_scale,_placement_pose(),preload("res://scripts/native_object_pose.gd").encode_tint(object_tint.srgb_to_linear()) if custom_tint and mode in ["tree","flower","rock","assets"] else "")
			if placed < 0:
				_set_status("This garden has reached its object limit.")
		if data.end_stroke():
			refresh()
			if placed > 0 and reactions_enabled:
				var record: Dictionary = data.objects.back()
				reactions.play(record.asset,reactions.record_pose(record),record)
	else:
		_painting = true
		dab(_last_point,strength/30.0)
		refresh()
	return true

func pick(mouse: Vector2) -> Variant:
	if scene._growth.terrain < 0.995:
		return null
	if not scene.get_viewport().get_visible_rect().has_point(mouse):
		return null
	for child in scene._ui.get_children():
		if child is Control and scene._ui.visible and child.is_visible_in_tree() and child.get_global_rect().has_point(mouse):
			return null
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(mouse))
	var direction := terrain.global_basis.inverse()*camera.project_ray_normal(mouse)
	return data.ray_hit(origin,direction.normalized())

func _process(delta: float) -> void:
	if not active:
		return
	if _painting and (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or scene._growth.terrain < 0.995):
		finish_stroke()
	var hit: Variant = pick(scene.get_viewport().get_mouse_position()) if not scene._orbiting and not scene._panning else null
	_material.set_shader_parameter("brush_visible",hit != null and preview_wanted())
	if hit != null:
		var center := Vector2(hit.x,hit.z)
		_material.set_shader_parameter("brush_center",center)
		_material.set_shader_parameter("brush_radius",preview_radius())
		if _painting:
			_elapsed += minf(delta,0.05)
			if _elapsed >= 1.0/30.0:
				var previous: Vector2 = _last_point if _last_point != null else center
				var dabs := maxi(1,ceili(previous.distance_to(center)/(radius*0.15)))
				for i in range(1,dabs+1):
					dab(previous.lerp(center,float(i)/dabs),strength*_elapsed/dabs)
				refresh()
				_elapsed = 0.0
				_last_point = center
	else:
		_last_point = null
		_elapsed = 0.0

func finish_stroke() -> void:
	if not _painting:
		return
	_painting = false
	_elapsed = 0.0
	_last_point = null
	data.end_stroke()

func undo() -> void:
	_fall_start = null
	finish_stroke()
	if data.undo():
		refresh()

func redo() -> void:
	_fall_start = null
	finish_stroke()
	if data.redo():
		refresh()

func refresh() -> void:
	_set_status("Garden changed · Save to keep your work.")
	terrain.mesh = data.build_mesh()
	var original := data.heights == data.original_heights
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
	sync_visibility()
	_rebuild_skirt()
	content.rebuild()
	landmarks.rebuild(data)
	falls.rebuild(data)
	var fall_count := 0
	for item: Dictionary in data.objects:
		if item.asset == "waterfall":
			fall_count += 1
	if falls.get_child_count()/2 < fall_count:
		_set_status("A waterfall is blocked or submerged. Lower the obstruction or undo.")
	# Existing habitat/rain/fog consumers keep the same texture object.
	_update_surface_maps(original)
	if terrain.mesh != _bigfoot_mesh:
		_bigfoot_mesh = terrain.mesh
		scene._bigfoot.ground.setup(terrain)
	var encounter_pose: Variant = null
	for item: Dictionary in data.objects:
		if item.asset == "bigfoot_tree":
			encounter_pose = Transform3D(Basis(Vector3.UP,item.angle).scaled(Vector3.ONE*item.scale),data.object_position(item))
			break
	scene._bigfoot.set_authored_tree(encounter_pose)
	scene._bird_flight.ground = _original_bird_ground if original else data
	scene._atmosphere.update_ground_bounds(terrain,original)
	scene._precipitation.set_ceiling(_original_precip_top if original else scene._atmosphere._summit.y+5.0)
	if scene._display_fog != null:
		scene._display_fog.update_view()

## Rebuild everything from the records, ignoring every incremental cache. The
## incremental path must land on exactly this result; the regression test drives
## a stroke both ways and compares the meshes, instances and map bytes.
func force_refresh() -> void:
	data.discard_cache()
	content.discard_cache()
	_map_ready = false
	_bigfoot_mesh = null
	refresh()

## Resample only the map pixels the edit can reach. The height pass is kept in
## `_map_base`; both overlays are per-pixel functions of that base, so repainting
## the changed rectangle over the previous finished maps reproduces them exactly.
func _update_surface_maps(original: bool) -> void:
	var size := _original_ground_map.get_width()
	var reusable: bool = _map_ready and _map_revision == content.revision and _map_blank == data.blank and _map_original == original
	var region: Variant = data.moved_region(_map_heights) if reusable else null
	if region is bool and reusable:
		return
	var clip := Rect2i(0,0,size,size)
	if region != null:
		var low: Vector2 = (region.position+Vector2.ONE*16.0)/32.0*float(size)-Vector2.ONE*0.5
		var high: Vector2 = (region.end+Vector2.ONE*16.0)/32.0*float(size)-Vector2.ONE*0.5
		clip = Rect2i(Vector2i(clampi(floori(low.x),0,size),clampi(floori(low.y),0,size)),Vector2i.ZERO)
		clip = clip.expand(Vector2i(clampi(ceili(high.x)+1,0,size),clampi(ceili(high.y)+1,0,size)))
	else:
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
	var image: Image
	var streams: Image
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
	_map_blank = data.blank
	_map_original = original
	_map_ready = true

func _placement_pose() -> Dictionary:
	if mode not in ["tree","flower","rock","assets"] or (object_width == 1.0 and object_height == 1.0 and object_depth == 1.0 and object_pitch == 0.0 and object_roll == 0.0 and object_elevation == 0.0):
		return {}
	var basis := Basis.from_euler(Vector3(deg_to_rad(object_pitch),object_angle,deg_to_rad(object_roll)))
	basis = basis.scaled_local(Vector3(object_width,object_height,object_depth)*object_scale)
	return preload("res://scripts/native_object_pose.gd").make(basis,object_elevation)

func form_range() -> void:
	finish_stroke()
	_fall_start = null
	data.begin_stroke()
	data.form_range(range_height,range_width,deg_to_rad(range_heading),range_variation)
	data.end_stroke()
	refresh()
	_set_status("Mountain landscape formed, including basin and stream beds. Paint and place to dress it.")

func form_foundation() -> void:
	finish_stroke()
	_fall_start = null
	data.begin_stroke()
	data.form_foundation(ground_elevation,ground_relief)
	data.end_stroke()
	refresh()
	_set_status("Ground formed. Grass paints its surface; sculpting changes its height.")

func start_flat() -> void:
	_fall_start = null
	finish_stroke()
	data.begin_stroke()
	data.reset_flat()
	data.end_stroke()
	refresh()

func _rebuild_skirt() -> void:
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
	finish_stroke()
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
	refresh()
	NativeGardenStore.restore(scene,document.scene_state)
	_set_status("Garden opened.")
	return true

func sync_visibility() -> void:
	if data.blank:
		for node: VisualInstance3D in _source_visibility:
			node.visible = false

func fill_landscape_streams() -> void:
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
	finish_stroke()
	data.begin_stroke()
	var accepted:=data.fill_landscape_waterfall()
	data.end_stroke()
	if accepted:
		refresh()
		_set_status("Landscape waterfall filled. Save preserves it.")
	else:
		_set_status("Form a mountain landscape first.")
