extends "res://studies/wind_playground.gd"
## A living inhabitant shares the editable chunk. Only navigation is suspended
## while geometry is rebuilt; wind, animations and carrying remain responsive.
const Navigation = preload("res://scripts/creature_navigation.gd")
const Brain = preload("res://scripts/creature_brain.gd")
var navigation = Navigation.new()
var brain = Brain.new()
var _world_dirty := false
var _refresh_phase := 0
var _habitat_blocked := false
var _waiting_for_ground := false
var _navigation_ready := false
var _reset_pending := false
var last_collision_rebuild_usec := 0
var _curious_button := Button.new()

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · A little life"
	process_physics_priority = -20
	if navigation is Node: add_child(navigation)
	if brain is Node: add_child(brain)
	navigation.rebuild(_chunk_editor.data, play_collisions.can_stand)
	_navigation_ready = true
	brain.setup(creature, navigation, _interests)
	brain.reaction.connect(_show_reaction)
	_chunk_editor.play_geometry_changed.connect(_geometry_changed)
	_chunk_editor.formation_started.connect(_geometry_changed)
	_idle_attention = INF
	gust_tool = false
	_tool_button.text = "Grab / call Bigfoot"
	var column := _play_panel.get_child(0)
	column.get_child(0).text = "A little life"
	column.get_child(1).text = "Bigfoot explores while you build. Grab his head or call him over.\nRight drag to orbit · Scroll to zoom · P pause"
	_curious_button.text = "Something interesting?"
	_curious_button.focus_mode = Control.FOCUS_NONE
	_curious_button.pressed.connect(_investigate_interest)
	column.add_child(_curious_button)
	_message.text = "He has a whole little world to explore."
	_mode_button.text = "Build while he explores"
	_wind_hint.custom_minimum_size.x = 200
	_wind_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_geometry_changed()

func _investigate_interest() -> void:
	var interests := _interests()
	if not interests.is_empty():
		var interest: Dictionary = interests[0]
		brain.investigate(interest.position, false, interest.id)

func toggle_build() -> void:
	_aim_start = null
	gust_visuals.clear_aim()
	if _carrying: _drop(Vector2(-1,-1))
	building = not building
	_chunk_editor.set_active(building)
	_ui.visible = building
	_play_panel.visible = not building
	_mode_button.text = "Watch Bigfoot" if building else "Build while he explores"
	_wind_hint.text = "He's exploring as you build · Esc to watch" if building else "Grab him or try a gust · P pause"

func _process(delta: float) -> void:
	_idle_attention = INF
	super._process(delta)
	if creature == null: return
	creature.set_physics_process(not _paused)
	if creature.wind_body != null:
		creature.wind_body.freeze = _paused or not creature.wind_body.active

func _play_physics_enabled() -> bool:
	return true

func _physics_process(delta: float) -> void:
	if creature == null or _paused or not wind.is_inside_tree(): return
	if _atmosphere != null:
		var strength: float = _atmosphere._air_strength * _atmosphere.gust_at(_atmosphere._wind_time) * 3.0
		wind.ambient_velocity = Vector3(cos(_atmosphere._air_angle),0,sin(_atmosphere._air_angle))*strength
	wind.advance(delta)
	if _chunk_editor.forming: return
	if _world_dirty:
		creature.stop_walking()
		_world_dirty = false
		var collision_began := Time.get_ticks_usec()
		play_collisions.rebuild(_chunk_editor.data)
		last_collision_rebuild_usec = Time.get_ticks_usec()-collision_began
		_refresh_phase = 1
		return
	if _refresh_phase == 1:
		# Physics sees replacement shapes on this next boundary, before clearance.
		navigation.begin_rebuild(_chunk_editor.data,play_collisions.can_stand,CreatureNavigation.STEP,CreatureNavigation.MAX_RISE,true)
		_refresh_phase = 2
	if _refresh_phase == 2:
		if not navigation.advance_rebuild(2000): return
		_refresh_phase = 0
		_reconcile_ground()
		brain.world_changed()
		if _reset_pending and not _habitat_blocked:
			reset_creature()
	if not _habitat_blocked:
		brain.advance(delta)

func _geometry_changed() -> void:
	_world_dirty = true
	if creature != null and creature.has_method("stop_walking"):
		creature.stop_walking()

func _reconcile_ground() -> void:
	var location: Variant = navigation.nearest_safe(creature.global_position)
	_habitat_blocked = location == null
	if _habitat_blocked:
		creature.stop_walking()
		if not creature.is_held():
			creature.pick_up()
			_waiting_for_ground = true
		_show_reaction("?", "He needs a dry, open patch of ground. Make a clearing or carry him.")
		return
	_home = location
	# A held creature never teleports when the ground beneath him is edited.
	# Its invalid-release fallback still must follow the new habitat.
	var fallback: Variant = navigation.nearest_safe(creature._safe_position)
	creature._safe_position = fallback if fallback != null else location
	if creature.is_held():
		if _waiting_for_ground and not _carrying:
			_waiting_for_ground = false
			creature.reset_at(location)
			_show_reaction("!", "A clearing! Back on his feet.")
		return
	# Landing/recovery retain a future destination, which may have been edited
	# even when his current feet still have room. Never finish into stale ground.
	var destination: Variant = null
	if creature.state == CreatureActor.State.LANDING: destination = creature.land_position
	if creature.state == CreatureActor.State.RECOVERING: destination = creature._recover_to.origin
	if destination != null:
		var future_ground: Variant = _probe_ground(destination)
		if not navigation.is_safe(destination) or future_ground == null or absf(future_ground.y-destination.y) > 0.25:
			creature.reset_at(location)
			_show_reaction("!", "That spot changed. He's found somewhere clear.")
			return
	var ground: Variant = _probe_ground(creature.global_position)
	if not navigation.is_safe(creature.global_position) or ground == null or absf(ground.y-creature.global_position.y) > 0.25:
		# Preserve a physical tumble when its supporting floor remains valid.
		if creature.state != CreatureActor.State.WIND or ground == null or not navigation.is_safe(ground) or ground.y > creature.global_position.y+0.45:
			creature.reset_at(location)
			_show_reaction("!", "The ground changed! He steps somewhere clear.")
	elif creature.state in [CreatureActor.State.IDLE, CreatureActor.State.ALERT]:
		creature.global_position.y = ground.y
		creature._safe_position = ground

func _interests() -> Array[Dictionary]:
	var interests: Array[Dictionary] = []
	for item: Dictionary in _chunk_editor.data.objects:
		var kind: String = item.asset
		if kind in ["flower", "grass_tuft", "bank_grass", "reeds"]: continue
		interests.append({"id":"object:%d" % item.id, "position":_chunk_editor.data.object_position(item), "kind":kind})
	for i in range(_chunk_editor.data.ponds.size()):
		var pond: Dictionary = _chunk_editor.data.ponds[i]
		interests.append({"id":"pond:%s:%s" % [pond.x,pond.z], "position":Vector3(pond.x,pond.level,pond.z), "kind":"pond"})
	return interests

func _on_creature_state(value: CreatureActor.State) -> void:
	# The brain owns attention symbols; ALERT must not overwrite its ! with ?.
	match value:
		CreatureActor.State.HELD: _message.text = "Easy there! Find a clear patch to set him down."
		CreatureActor.State.LANDING: _message.text = "Finding his feet…"
		CreatureActor.State.WIND: _show_reaction("!", "Whoa!")
		CreatureActor.State.RECOVERING: _message.text = "Give him a moment to find his feet."

func _show_reaction(symbol: String, text: String) -> void:
	_reaction.show_reaction(symbol)
	_message.text = text

func _call_creature() -> void:
	if brain == null or not brain.is_inside_tree(): return
	var point := camera.global_position
	var toward := Vector3(point.x,creature.global_position.y,point.z)-creature.global_position
	if toward.length() > 3.0: toward = toward.normalized()*3.0
	brain.investigate(creature.global_position+toward, true, "player-call")

func _begin_carry(mouse: Vector2) -> void:
	if _waiting_for_ground and creature.is_held():
		_waiting_for_ground = false
		_hold_plane = Plane(Vector3.UP,creature.global_position.y+creature.grasp_height+0.9)
		_hold_offset = -Vector3.UP*creature.grasp_height
		_carrying = true
		return
	super._begin_carry(mouse)

func _drop(mouse: Vector2) -> void:
	if _world_dirty or _refresh_phase != 0:
		_show_reaction("?", "A moment while the ground settles…")
		return
	if _habitat_blocked:
		_show_reaction("?", "Make a dry, open clearing before putting him down.")
		return
	super._drop(mouse)

func valid_landing(point: Vector3) -> bool:
	if not super.valid_landing(point): return false
	# Clearance calls native collisions directly, so this shares wet-course and
	# stream exclusions without recursing through this placement callback.
	return not _navigation_ready or navigation.is_safe(point)

func reset_creature() -> void:
	if _world_dirty or _refresh_phase != 0 or _habitat_blocked:
		_reset_pending = true
		_show_reaction("?", "He'll reset once there's safe, settled ground.")
		return
	_reset_pending = false
	super.reset_creature()
	if brain != null and brain.is_inside_tree(): brain.reset_behavior()

func _input(event: InputEvent) -> void:
	if (_habitat_blocked or _world_dirty or _refresh_phase != 0) and creature != null and creature.is_held() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_carrying = false
		_pressed_creature = false
		_landing_marker.visible = false
		_waiting_for_ground = true
		_show_reaction("?", "Make a clearing and he'll find his feet again.")
		get_viewport().set_input_as_handled()
		return
	super._input(event)
