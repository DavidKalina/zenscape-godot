extends "res://studies/bigfoot_life.gd"
## A tactile, preset-first playground. The tree owns elasticity and contact;
## this scene owns gestures and the resident's response to player interference.
var mischief: Node
var loose_props: Node3D
var water_play: Node3D
var _wet_hold := false
var _water_reaction := false
var _offended_time := 0.0
var spring_tree: PlaySpringTree
var _tree_drag := false
var _drag_plane := Plane()
var _drag_origin := Vector3.ZERO
var _attention_time := 0.0
var _mischief_count := 0
var _tree_hit := false
var _hover_tree := false
var _tension_bar := ProgressBar.new()
var _cursor_hint := Label.new()
var _play_ready := false
var _braced := false

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · A little mischief"
	_enrich_clearing()
	spring_tree = preload("res://scripts/play_spring_tree.gd").new()
	add_child(spring_tree)
	spring_tree.position = Vector3(0,0,3.7)
	spring_tree.position.y = _chunk_editor.data.ground_height(Vector2(0,3.7))
	# A modest foreground tree, framed by the existing ridge, falls and pool.
	_celestial.look.choose("Meadow")
	_celestial.look.set_value("ambient_energy",1.2)
	_celestial.set_phase(0.46)
	_celestial.update_rig()
	_atmosphere.set_fog(0.045)
	target = Vector3(0,1.7,1.0)
	distance = 16.5
	yaw = 0.15
	polar = 1.05
	_auto_orbit = false
	_update_camera()
	var column := _play_panel.get_child(0)
	column.get_child(0).text = "A little mischief"
	column.get_child(1).text = "Grab loose stones, logs or boulders. Swing and release to throw.\nDunk Bigfoot in the pool · Pull the tree\nRight drag to orbit · Scroll to zoom"
	_message.text = "A quiet afternoon. For now."
	_mode_button.hide()
	_tool_button.text = "Hands · switch to wind"
	_tool_button.pressed.connect(_tool_changed)
	_wind_hint.text = "Hands · P pause · R reset"
	# The life scene's extra investigation button makes a useful tree invitation.
	_curious_button.text = "Show him the tree"
	_tension_bar.custom_minimum_size = Vector2(190,5)
	_tension_bar.max_value = 1.0
	_tension_bar.show_percentage = false
	_wind_panel.get_child(0).add_child(_tension_bar)
	_tension_bar.hide()
	_play_ui.add_child(_cursor_hint)
	_cursor_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_hint.add_theme_color_override("font_color",Color("ffe7ac"))
	_cursor_hint.add_theme_color_override("font_shadow_color",Color("19251d"))
	_cursor_hint.add_theme_constant_override("shadow_offset_x",1)
	_cursor_hint.add_theme_constant_override("shadow_offset_y",2)
	var light := OptionButton.new()
	for label in ["Meadow light", "Amber evening", "Rose dusk"]: light.add_item(label)
	light.focus_mode = Control.FOCUS_NONE
	light.item_selected.connect(func(index: int) -> void:
		_celestial.look.choose(["Meadow","Autumn","Dusk"][index])
		_celestial.set_phase([0.46,0.64,0.71][index])
		_celestial.update_rig())
	_wind_panel.get_child(0).add_child(light)
	water_play = preload("res://scripts/play_water_mischief.gd").new()
	add_child(water_play)
	water_play.setup(self)
	creature.water_splash.connect(water_play.splash)
	loose_props = preload("res://scripts/play_loose_props.gd").new()
	add_child(loose_props)
	loose_props.setup(self)
	mischief = preload("res://scripts/bigfoot_mischief.gd").new()
	add_child(mischief)
	mischief.setup(self)
	var play_button := Button.new()
	play_button.text = "Let him play"
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.pressed.connect(func() -> void:
		if not _paused and not mischief.busy():
			if not mischief.invite(): _show_reaction("?","Nothing within reach just now."))
	column.add_child(play_button)
	_play_ready = true

func _enrich_clearing() -> void:
	var data := _chunk_editor.data
	data.begin_stroke()
	# A deep center and gentle shore keep his head above water while paddling.
	for i in range(data.points.size()):
		var radial: float = data.points[i].distance_to(Vector2(3,0))
		data.heights[i] -= 1.5*(1.0-smoothstep(0.0,2.3,radial))
	for entry in [[-6,-5,1.2],[-3,-6,1.15],[0,-5.5,1.0],[2.5,-6,1.35],[5.7,-5.2,1.1],[7.4,-2.5,1.2],[-5,5.5,0.85],[6.8,4.8,0.8]]:
		data.place("broadleaf",Vector2(entry[0],entry[1]),float(entry[0])*0.7,float(entry[2]),{},NativeObjectPose.encode_tint(Color(0.10,0.25,0.16)))
	for i in range(22):
		var angle := i*2.399
		var point := Vector2(4.6,-1.9)+Vector2(cos(angle),sin(angle))*sqrt(float(i))*0.38
		data.place("fern" if i%3==0 else "button_flower",point,angle,0.65+float(i%4)*0.12)
	for entry in [[-2,5.7],[4.5,5.2],[-3,-2],[6,-3]]:
		data.place("shrub",Vector2(entry[0],entry[1]),0.4,0.7)
	data.end_stroke()
	_chunk_editor.refresh()
	_geometry_changed()

func _tool_changed() -> void:
	if is_instance_valid(mischief): mischief.cancel()
	cancel_tree_drag()
	if is_instance_valid(loose_props): loose_props.cancel()
	if _carrying: _cancel_water_carry()
	_tool_button.text = "Wind · switch to hands" if gust_tool else "Hands · switch to wind"

func _investigate_interest() -> void:
	if not _paused and is_instance_valid(mischief): mischief.request("tree")

func _interests() -> Array[Dictionary]:
	var interests := super._interests()
	if is_instance_valid(spring_tree):
		interests.append({"id":"spring-tree","position":spring_tree.global_position,"kind":"tree"})
	return interests

func _process(delta: float) -> void:
	super._process(delta)
	if not _play_ready: return
	var mouse := get_viewport().get_mouse_position()
	loose_props.hover(mouse)
	_hover_tree = not _paused and not gust_tool and not _carrying and loose_props.grabbed == null and loose_props.hovered == null and not _over_controls(mouse) and _pick_tree(mouse)
	spring_tree.set_highlight(_hover_tree or _tree_drag)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if _tree_drag else (Input.CURSOR_POINTING_HAND if _hover_tree else Input.CURSOR_ARROW))
	_cursor_hint.position = mouse+Vector2(20,20)
	_cursor_hint.text = "Release · Esc to forgive" if _tree_drag else ("Release to let him paddle" if _wet_hold else ("Pull me" if _hover_tree else ""))
	if loose_props.grabbed != null:
		_cursor_hint.text = "Swing and release · Esc to put it back"
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	elif loose_props.hovered != null:
		_cursor_hint.text = "Grab " + loose_props.hovered.kind
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_tension_bar.visible = _tree_drag
	_tension_bar.value = spring_tree.tension
	_wind_hint.text = "Paused · P to resume" if _paused else ("Drag ground to aim wind · P pause" if gust_tool else "Dunk him in the pool · Pull a tree · P pause · R reset")
	if _paused: return
	water_play.advance(delta)
	if _offended_time > 0.0:
		_offended_time = maxf(0.0,_offended_time-delta)
		var gaze_plane := Plane(camera.global_basis.z,creature.global_position+Vector3.UP*2.2)
		var gaze: Variant = gaze_plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		creature.track_gaze(gaze if gaze != null else camera.global_position)
	_attention_time = maxf(0,_attention_time-delta)
	brain.enabled = not mischief.busy() and not loose_props.busy() and not _tree_drag and _attention_time <= 0 and creature.state not in [CreatureActor.State.SWIMMING,CreatureActor.State.SHAKING]
	if _tree_drag and creature.can_roam():
		creature.stop_walking()
		creature.track_gaze(spring_tree.center(3.0))
		# Watchful on the first pull; arms spread to brace after repeated teasing.
		if spring_tree.tension > 0.45 and _mischief_count > 0 and not _braced:
			creature.queue_tremor(0.25)
			_braced = true

func _physics_process(delta: float) -> void:
	if is_instance_valid(mischief):
		mischief.advance(delta)
		if mischief.busy(): brain.enabled = false
	if is_instance_valid(loose_props): loose_props.advance(delta)
	super._physics_process(delta)
	if not _play_ready or _paused: return
	if creature.state == CreatureActor.State.WIND:
		var body_point: Vector3 = creature.wind_body.global_position
		var surface: Variant = water_play.surface_at(body_point)
		if surface != null and body_point.y<surface.y+0.25:
			var shore: Variant = water_play.shore_from(body_point)
			if shore != null:
				creature.pick_up()
				creature.global_position = surface-Vector3.UP*1.65
				creature.enter_water(surface.y,shore)
				brain.enabled = false
	var previous := spring_tree.bend
	spring_tree.advance(delta)
	loose_props.tree_sweep(previous,delta)
	var contact := Vector3.ZERO if mischief.tree_protected else spring_tree.sweep_contact(previous,creature.global_position+Vector3.UP*1.6,delta)
	if contact.length() > 0.0 and creature.receive_impulse((contact*23.0+Vector3.UP*65.0).limit_length(240.0)):
		_tree_hit = true
		_attention_time = 4.0
		_show_reaction("!", "He was absolutely not expecting that.")

func _pick_tree(mouse: Vector2) -> bool:
	if camera.is_position_behind(spring_tree.global_position): return false
	var ground: Variant = _ground_at(mouse)
	var max_distance: float = camera.project_ray_origin(mouse).distance_to(ground)+0.2 if ground != null else INF
	return spring_tree.pick(camera,mouse,max_distance)

func begin_tree_drag(mouse: Vector2) -> void:
	if _paused or gust_tool or _carrying: return
	if is_instance_valid(mischief):
		mischief.cancel()
		mischief.tree_protected = false
	_tree_drag = true
	_braced = false
	_drag_plane = Plane(camera.global_basis.z,spring_tree.center(3.0))
	var hit: Variant = _drag_plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	_drag_origin = hit if hit != null else spring_tree.center(3.0)
	spring_tree.begin_grab()
	brain.enabled = false
	creature.stop_walking()
	creature.notice(spring_tree.center(3.0))
	_show_reaction("?" if _mischief_count == 0 else "!", "That's his tree." if _mischief_count == 0 else "He recognizes that look in your cursor.")

func move_tree_drag(mouse: Vector2) -> void:
	if not _tree_drag: return
	var hit: Variant = _drag_plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if hit != null: spring_tree.drag_to(hit-_drag_origin)

func release_tree_drag() -> void:
	if not _tree_drag: return
	_tree_drag = false
	var strength := spring_tree.tension
	spring_tree.release()
	_attention_time = 2.8
	if strength > 0.12:
		_mischief_count += 1
		_show_reaction("!", "A suspicious rustle…" if strength < 0.4 else "He's keeping an eye on those branches.")
	else:
		_show_reaction("?", "Just a little tickle.")

func cancel_tree_drag() -> void:
	if not is_instance_valid(spring_tree) or not _tree_drag: return
	_tree_drag = false
	spring_tree.cancel()
	_attention_time = 0
	brain.enabled = true
	_cursor_hint.text = ""

func _input(event: InputEvent) -> void:
	if is_instance_valid(loose_props) and loose_props.grabbed != null:
		if event is InputEventMouseMotion:
			loose_props.move_grab(event.position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _paused or _over_controls(event.position) or not get_viewport().get_visible_rect().has_point(event.position): loose_props.cancel()
			else: loose_props.release()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_P,KEY_R]: loose_props.cancel()
	if _tree_drag:
		if event is InputEventMouseMotion:
			move_tree_drag(event.position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _over_controls(event.position) or not get_viewport().get_visible_rect().has_point(event.position): cancel_tree_drag()
			else: release_tree_drag()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_P,KEY_R]: cancel_tree_drag()
	super._input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not _play_ready:
		super._unhandled_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _paused and not gust_tool and not _carrying and not _over_controls(event.position):
		var loose: RigidBody3D = loose_props.pick(event.position)
		if loose != null and not pick_creature(event.position):
			loose_props.begin_grab(loose,event.position)
			get_viewport().set_input_as_handled()
			return
		if not pick_creature(event.position) and _pick_tree(event.position):
			begin_tree_drag(event.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_P,KEY_R]: cancel_tree_drag()
	if _paused and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: return
	super._unhandled_input(event)

func _on_creature_state(value: CreatureActor.State) -> void:
	super._on_creature_state(value)
	if value == CreatureActor.State.SWIMMING:
		_water_reaction = true
		_show_reaction("!", "An entirely unplanned bath.")
	elif value == CreatureActor.State.SHAKING:
		_show_reaction("…", "Stand back. He is sharing the water.")
	elif _water_reaction and value == CreatureActor.State.ALERT:
		_water_reaction = false
		_offended_time = 3.0
		_attention_time = 3.0
		creature.notice(camera.global_position)
		_show_reaction("…", "He knows exactly who did that.")
	if _tree_hit and value == CreatureActor.State.ALERT:
		_tree_hit = false
		_attention_time = 2.0
		creature.notice(camera.global_position)
		_show_reaction("…", "He's fairly sure you had something to do with that.")

func reset_creature() -> void:
	if is_instance_valid(mischief): mischief.reset()
	if is_instance_valid(loose_props): loose_props.reset()
	cancel_tree_drag()
	if is_instance_valid(spring_tree): spring_tree.reset()
	_tree_hit = false
	_water_reaction = false
	_offended_time = 0.0
	_wet_hold = false
	if is_instance_valid(water_play): water_play.clear()
	_mischief_count = 0
	super.reset_creature()

func _begin_carry(mouse: Vector2) -> void:
	if _paused: return
	if is_instance_valid(mischief): mischief.cancel()
	if is_instance_valid(loose_props): loose_props.cancel()
	_water_reaction = false
	_offended_time = 0.0
	_wet_hold = false
	super._begin_carry(mouse)

func _update_carry(mouse: Vector2, delta: float) -> void:
	if _paused: return
	var pool: Variant = water_play.pick(mouse) if is_instance_valid(water_play) else null
	if pool == null:
		_wet_hold = false
		super._update_carry(mouse,delta)
		return
	var ground: Variant = _probe_ground(pool)
	if ground == null: return
	var destination: Vector3 = pool-Vector3.UP*1.65
	destination.y = maxf(destination.y,ground.y)
	creature.move_held(creature.global_position.lerp(destination,1.0-exp(-12.0*delta)),delta)
	_landing_marker.visible = true
	_landing_marker.position = pool+Vector3.UP*0.04
	_landing_material.albedo_color = Color(0.4,0.9,1.0,0.65)
	_cursor_hint.text = "Splish splash · release to let him paddle"
	if creature.global_position.y < pool.y-0.6 and not _wet_hold:
		_wet_hold = true
		water_play.splash(pool,1.0)
		_show_reaction("!", "He did not pack a swimsuit.")

func _drop(mouse: Vector2) -> void:
	if _paused: return
	if is_instance_valid(water_play) and not _world_dirty and _refresh_phase == 0 and water_play.pick(mouse) != null:
		var surface: Variant = water_play.surface_at(creature.global_position)
		var shore: Variant = water_play.shore_from(creature.global_position) if surface != null else null
		if shore != null and creature.enter_water(surface.y,shore):
			_carrying = false
			_pressed_creature = false
			_wet_hold = false
			_landing_marker.visible = false
			brain.enabled = false
			return
	super._drop(mouse)

func _cancel_water_carry() -> void:
	if creature != null and _carrying:
		creature.release_at(null)
		_carrying = false
		_pressed_creature = false
		_wet_hold = false
		_landing_marker.visible = false


func _carry_from_tray() -> void:
	if _paused: return
	cancel_tree_drag()
	super._carry_from_tray()

func _call_creature() -> void:
	if not _paused:
		if is_instance_valid(mischief): mischief.cancel()
		super._call_creature()

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not bool(get_meta("movie_capture",false)):
		if is_instance_valid(mischief): mischief.cancel()
		if is_instance_valid(loose_props): loose_props.cancel()
		cancel_tree_drag()
		_cancel_water_carry()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _probe_safe(point: Vector3) -> Variant:
	var safe: Variant = super._probe_safe(point)
	if safe != null or not is_instance_valid(loose_props): return safe
	# A rolling prop can occupy the old landing point without a terrain edit.
	# Use current clearance when choosing recovery, not the last static home.
	var nearby: Variant = navigation.nearest_safe(point)
	return nearby if nearby != null and valid_landing(nearby) else null
