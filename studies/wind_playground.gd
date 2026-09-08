extends "res://studies/bigfoot_playground.gd"
## A reproducible garden with play/build modes sharing the same terrain.
const WindField = preload("res://scripts/local_wind_field.gd")
const Collisions = preload("res://scripts/native_play_collisions.gd")
const Landscape = preload("res://scripts/wind_demo_landscape.gd")
var wind := WindField.new()
var play_collisions := Collisions.new()
var building := false
var gust_tool := true
var gust_strength := 20.0
var gust_radius := 8.0
var gust_duration := 1.4
var _aim_start: Variant = null
var _aim_end := Vector3.ZERO
var _wind_panel := PanelContainer.new()
var _mode_button := Button.new()
var _tool_button := Button.new()
var _aim_mesh := MeshInstance3D.new()
var _home := Vector3.ZERO
var _wind_hint := Label.new()

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Wind Playground"
	_home = Landscape.populate(_chunk_editor)
	add_child(wind)
	add_child(play_collisions)
	play_collisions.rebuild(_chunk_editor.data)
	creature.enable_wind(wind, _probe_ground, _probe_safe)
	creature.reset_at(_home)
	_chunk_editor.set_active(false)
	_chunk_editor.active_changed.connect(func(enabled: bool) -> void:
		if building != enabled: toggle_build())
	_build_wind_ui()
	var play_column := _play_panel.get_child(0)
	play_column.get_child(0).text = "A little weather"
	play_column.get_child(1).text = "Drag the ground to aim wind. Switch tools to grab Bigfoot.\nRight drag to orbit · Scroll to zoom · R to reset him"
	add_child(_aim_mesh)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.80, 0.95, 0.79)
	_aim_mesh.material_override = material
	_aim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target = Vector3(0, 1.3, -0.8)
	distance = 19.0
	yaw = 0.25
	polar = 0.98
	_update_camera()
	_message.text = "Drag across the ground to aim a gust."

func _build_wind_ui() -> void:
	_play_ui.add_child(_wind_panel)
	_wind_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_wind_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 245, 18)
	var column := VBoxContainer.new()
	_wind_panel.add_child(column)
	_wind_hint.text = "Drag ground to aim · P pause"
	column.add_child(_wind_hint)
	_mode_button.text = "Build this garden"
	_mode_button.pressed.connect(toggle_build)
	column.add_child(_mode_button)
	_tool_button.text = "Gust tool · on"
	_tool_button.pressed.connect(func() -> void:
		gust_tool = not gust_tool
		_aim_start = null
		_aim_mesh.mesh = null
		_tool_button.text = "Gust tool · on" if gust_tool else "Grab / call Bigfoot")
	column.add_child(_tool_button)
	var powers := OptionButton.new()
	for label in ["Breeze · brace", "Gust · tumble", "Blast · stronger"]: powers.add_item(label)
	powers.select(1)
	powers.item_selected.connect(func(index: int) -> void: gust_strength = [5.0,20.0,28.0][index])
	column.add_child(powers)
	var demo := Button.new()
	demo.text = "Try a gust"
	demo.pressed.connect(demo_gust)
	column.add_child(demo)
	for control in [_mode_button, _tool_button, powers, demo]: control.focus_mode = Control.FOCUS_NONE

func demo_gust() -> void:
	if building: toggle_build()
	wind.emit_gust(creature.global_position + Vector3.UP, Vector3(1,0,-0.25), gust_strength, gust_radius, gust_duration)

func toggle_build() -> void:
	_aim_start = null
	_aim_mesh.mesh = null
	wind.clear()
	if _carrying: _drop(Vector2(-1,-1))
	building = not building
	if building:
		creature.reset_at(creature._safe_position)
		creature.set_physics_process(false)
	else:
		play_collisions.rebuild(_chunk_editor.data)
		var safe: Variant = _probe_safe(creature.global_position)
		if safe == null:
			for point: Vector2 in _chunk_editor.data.points:
				safe = _probe_safe(Vector3(point.x,0,point.y))
				if safe != null: break
		if safe == null:
			building = true
			_message.text = "Make a dry, level clearing before returning to play."
			_wind_hint.text = "Make a dry, level clearing first."
			_chunk_editor.set_active(true)
			return
		_home = safe
		creature.reset_at(_home)
		creature.set_physics_process(true)
	_chunk_editor.set_active(building)
	_ui.visible = building
	_play_panel.visible = not building
	_mode_button.text = "Play with the wind" if building else "Build this garden"
	_wind_hint.text = "Edit the garden · Esc to play" if building else "Drag ground to aim · P pause"

func _probe_ground(point: Vector3) -> Variant:
	var height: Variant = _chunk_editor.data.ground_height(Vector2(point.x,point.z))
	return Vector3(point.x,height,point.z) if height != null else null

func _probe_safe(point: Vector3) -> Variant:
	var ground: Variant = _probe_ground(point)
	return ground if ground != null and valid_landing(ground) else null

func valid_landing(point: Vector3) -> bool:
	if not super.valid_landing(point): return false
	if play_collisions.is_inside_tree() and not play_collisions.can_stand(point): return false
	for pond: Dictionary in _chunk_editor.data.ponds:
		if point.y < float(pond.level) + 0.05 and GardenWater.covers(_chunk_editor.data.pond_surface(pond), Vector2(point.x,point.z)):
			return false
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if creature == null: return
	creature.set_process(not _paused)
	creature.set_physics_process(_play_physics_enabled() and not _paused)
	if creature.wind_body != null:
		creature.wind_body.freeze = _paused or not _play_physics_enabled() or not creature.wind_body.active

func _play_physics_enabled() -> bool:
	return not building

func _over_controls(mouse: Vector2) -> bool:
	if _wind_panel.is_inside_tree() and _wind_panel.get_global_rect().has_point(mouse): return true
	return super._over_controls(mouse) if not building else not _chunk_editor.pointer_in_world(mouse)

func _physics_process(delta: float) -> void:
	if building or _paused or _atmosphere == null or not wind.is_inside_tree(): return
	var strength: float = _atmosphere._air_strength * _atmosphere.gust_at(_atmosphere._wind_time) * 3.0
	wind.ambient_velocity = Vector3(cos(_atmosphere._air_angle),0,sin(_atmosphere._air_angle))*strength
	wind.advance(delta)

func _input(event: InputEvent) -> void:
	super._input(event)
	if _aim_start == null: return
	if event is InputEventMouseMotion:
		var hit: Variant = Plane(Vector3.UP,_aim_start.y).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
		if hit != null:
			_aim_end = hit
			_draw_aim()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_aim_start = null
		_aim_mesh.mesh = null
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var direction: Vector3 = _aim_end - _aim_start
		if direction.length() > 0.3 and not _over_controls(event.position):
			wind.emit_gust(_aim_start + Vector3.UP, direction, gust_strength, gust_radius, gust_duration)
		_aim_start = null
		_aim_mesh.mesh = null
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_paused = not _paused
			_wind_hint.text = "Paused · P to resume" if _paused else "Drag ground to aim · P pause"
			return
		if event.keycode == KEY_ESCAPE and building:
			toggle_build()
			return
	if building:
		if _chunk_editor.handle_input(event): return
	elif gust_tool and not _carrying and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _over_controls(event.position):
			_aim_start = _ground_at(event.position)
			if _aim_start != null: _aim_end = _aim_start
		return
	super._unhandled_input(event)

func _draw_aim() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var start: Vector3 = _aim_start + Vector3.UP*0.12
	var end := _aim_end + Vector3.UP*0.12
	var direction := (end-start).normalized()
	var side := direction.cross(Vector3.UP)*0.3
	for point in [start,end,end,end-direction*0.6+side,end,end-direction*0.6-side]: mesh.surface_add_vertex(point)
	mesh.surface_end()
	_aim_mesh.mesh = mesh

func reset_creature() -> void:
	super.reset_creature()
	if creature != null: creature.reset_at(_home)
	if wind.is_inside_tree(): wind.clear()
