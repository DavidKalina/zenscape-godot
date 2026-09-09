extends "res://studies/fidelity.gd"
## A focused inhabitant playground, separate from garden save files and the
## original rare encounter. Drag the Blender character, or carry from the tray.
var creature: CreatureActor
var _play_ui := CanvasLayer.new()
var _play_panel := PanelContainer.new()
var _message := Label.new()
var _reaction := Label3D.new()
var _pressed_creature := false
var _carrying := false
var _press_at := Vector2.ZERO
var _hold_offset := Vector3.ZERO
var _hold_plane := Plane(Vector3.UP,3.6)
var _landing_marker := MeshInstance3D.new()
var _landing_material := StandardMaterial3D.new()
var _idle_attention := 3.0

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Bigfoot Playground"
	_bigfoot.automatic_enabled = false
	_bigfoot.active = false
	_bigfoot.visible = false
	_chunk_editor.update_encounter_ground = false
	_ui.visible = false
	_chunk_editor.start_flat()
	var data := _chunk_editor.data
	data.grass.fill(0.55)
	for entry in [["tree",-3.2,-2.4,1.3],["tree",3.8,-3.3,1.0],["broadleaf",-5.0,-4.2,0.7],["rock",2.8,0.2,1.5],["rock",3.8,-0.5,0.8],["log",-3.4,1.0,0.65]]:
		data.place(entry[0],Vector2(entry[1],entry[2]),0.25,entry[3])
	for i in range(18):
		data.place("flower",Vector2(-2.5+sin(i*1.4)*0.7,2.0+cos(i*1.7)*0.6),i*0.4,0.8)
	_chunk_editor.refresh()
	_celestial.set_phase(0.48)
	_celestial.update_rig()
	_atmosphere.set_fog(0.04)
	creature = CreatureActor.new()
	creature.name = "Bigfoot"
	add_child(creature)
	creature.setup("res://assets/models/zenscape-bigfoot-interactions.glb")
	creature.footstep.connect(_ambient_audio.nature.footstep)
	_tremor.shaken.connect(creature.queue_tremor)
	# Reuse the game's lighting so the authored coat belongs to the landscape.
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	for mesh: MeshInstance3D in creature.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name:
			mesh.material_override = coat
	creature.state_changed.connect(_on_creature_state)
	creature.landed.connect(func() -> void:
		_reaction.text = "!"
		_reaction.modulate.a = 1.0)
	creature.add_child(_reaction)
	_reaction.position.y = 3.15
	_reaction.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_reaction.font_size = 72
	_reaction.pixel_size = 0.006
	_reaction.modulate = Color(1.0,0.92,0.65,0.0)
	_build_play_ui()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.015
	_landing_marker.mesh = disc
	_landing_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_landing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_landing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_landing_material.albedo_color = Color(0.65,0.95,0.65,0.5)
	_landing_marker.material_override = _landing_material
	add_child(_landing_marker)
	_landing_marker.visible = false
	target = Vector3(0,1.25,0)
	distance = 10.0
	yaw = 0.18
	polar = 1.08
	_update_camera()
	reset_creature()

func _build_play_ui() -> void:
	add_child(_play_ui)
	_play_ui.add_child(_play_panel)
	_play_panel.position = Vector2(18,18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.065,0.055,0.94)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	_play_panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	_play_panel.add_child(column)
	var title := Label.new()
	title.text = "A little company"
	title.add_theme_font_size_override("font_size",23)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Grab Bigfoot by the head. Click to get his attention.\nRight drag to orbit · Scroll to zoom · Esc to set him back"
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for entry in [["Pick up",_carry_from_tray],["Call him",_call_creature],["Reset",reset_creature]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	_message.add_theme_font_size_override("font_size",13)
	_message.text = "He seems curious about this place."
	column.add_child(_message)

func _on_creature_state(value: CreatureActor.State) -> void:
	match value:
		CreatureActor.State.HELD: _message.text = "Easy there! Find a clear patch to set him down."
		CreatureActor.State.STUMBLING: _message.text = "Whoa—finding his balance…"
		CreatureActor.State.LANDING: _message.text = "Finding his feet…"
		CreatureActor.State.ALERT:
			_message.text = "You have his attention."
			_reaction.text = "?"
			_reaction.modulate.a = 1.0
		CreatureActor.State.IDLE: _message.text = "He seems curious about this place."

func reset_creature() -> void:
	if creature == null: return
	creature.reset_at(Vector3.ZERO)
	creature.rotation.y = 0.0
	_pressed_creature = false
	_carrying = false
	_landing_marker.visible = false
	_idle_attention = 3.0

func _call_creature() -> void:
	creature.notice(camera.global_position)

func _over_controls(mouse: Vector2) -> bool:
	return _play_ui.visible and _play_panel.get_global_rect().has_point(mouse)

func _ground_at(mouse: Vector2) -> Variant:
	if _over_controls(mouse) or not get_viewport().get_visible_rect().has_point(mouse): return null
	return _chunk_editor.pick(mouse)

func pick_creature(mouse: Vector2) -> bool:
	if creature == null or _over_controls(mouse): return false
	var ray := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	# Skinned meshes do not update their source AABB as bones animate. A body
	# capsule-sized box provides a stable grab target through every clip.
	var inverse := creature.global_transform.affine_inverse()
	var hit: Variant = AABB(Vector3(-0.65,0,-0.45),Vector3(1.3,2.9,0.9)).intersects_ray(inverse*ray,(inverse.basis*direction).normalized())
	if hit == null: return false
	var ground: Variant = _ground_at(mouse)
	return ground == null or ray.distance_to(creature.global_transform*hit) <= ray.distance_to(ground)+0.1

func valid_landing(point: Vector3) -> bool:
	if not point.is_finite(): return false
	var data := _chunk_editor.data
	for offset in [Vector2.ZERO,Vector2(0.3,0),Vector2(-0.3,0),Vector2(0,0.3),Vector2(0,-0.3)]:
		var height: Variant = data.ground_height(Vector2(point.x,point.z)+offset)
		if height == null or absf(height-point.y) > 0.22: return false
	for item: Dictionary in data.objects:
		if item.asset in ["flower","grass_tuft","reeds","bank_grass"]: continue
		var reach := 0.45+0.35*float(item.scale)
		if Vector2(item.x-point.x,item.z-point.z).length() < reach: return false
	return true

func _begin_carry(mouse: Vector2) -> void:
	if not creature.pick_up(): return
	_hold_plane = Plane(Vector3.UP,creature.global_position.y+creature.grasp_height+0.9)
	_hold_offset = -Vector3.UP*creature.grasp_height
	_carrying = true

func _carry_from_tray() -> void:
	_begin_carry(get_viewport().get_mouse_position())

func _update_carry(mouse: Vector2, delta: float) -> void:
	var at: Variant = _hold_plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if at != null and not _over_controls(mouse):
		var destination: Vector3 = at+_hold_offset
		creature.move_held(creature.global_position.lerp(destination,1.0-exp(-22.0*delta)),delta)
	var ground: Variant = _carried_ground(mouse)
	_landing_marker.visible = ground != null
	if ground != null:
		_landing_marker.position = ground+Vector3.UP*0.025
		_landing_material.albedo_color = Color(0.55,0.92,0.60,0.6) if valid_landing(ground) else Color(0.95,0.40,0.28,0.6)

func _carried_ground(mouse: Vector2) -> Variant:
	if _over_controls(mouse) or not get_viewport().get_visible_rect().has_point(mouse): return null
	var point := creature.global_position
	var height: Variant = _chunk_editor.data.ground_height(Vector2(point.x,point.z))
	return Vector3(point.x,height,point.z) if height != null else null

func _drop(mouse: Vector2) -> void:
	var ground: Variant = _carried_ground(mouse)
	var valid := ground != null and valid_landing(ground)
	creature.release_at(ground if valid else null)
	_carrying = false
	_pressed_creature = false
	_landing_marker.visible = false
	if not valid: _message.text = "Not enough room there. Back to his safe spot."

func _input(event: InputEvent) -> void:
	super._input(event)
	if creature == null: return
	if event is InputEventMouseMotion and _pressed_creature and not _carrying:
		if event.position.distance_to(_press_at) >= 5.0: _begin_carry(_press_at)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _pressed_creature:
			if _carrying: _drop(event.position)
			else: _call_creature()
			_pressed_creature = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if creature.is_held():
			creature.release_at(null)
		_carrying = false
		_pressed_creature = false
		_landing_marker.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if creature == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _carrying: _drop(event.position)
			elif pick_creature(event.position):
				_pressed_creature = true
				_press_at = event.position
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_creature()
		return
	if event is InputEventKey: return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	_bigfoot.visible = false
	if creature == null: return
	_reaction.modulate.a = maxf(0.0,_reaction.modulate.a-delta*0.65)
	if _carrying:
		_update_carry(get_viewport().get_mouse_position(),minf(delta,0.05))
	else:
		_idle_attention -= delta
		if _idle_attention <= 0 and creature.state == CreatureActor.State.IDLE:
			creature.notice(Vector3(-3.2,2.0,-2.4) if int(Time.get_ticks_msec()/1000)%2 == 0 else camera.global_position)
			_idle_attention = 7.0
