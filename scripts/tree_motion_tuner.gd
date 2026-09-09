extends CanvasLayer
## Worktree animation controls. F8 compares the shared motion in the real world.
var panel := PanelContainer.new()
var status := Label.new()
var profiles := OptionButton.new()
var replay_tree: PlaySpringTree
var replay_time := -1.0
var replay_pull := Vector3.ZERO
var idle_watch := 0.0
var character_status := Label.new()

func _ready() -> void:
	add_to_group("tree_motion_tuner")
	visible = get_parent().get("owner_scene") == null
	layer = 30
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(get_viewport().get_visible_rect().size.x-330,90)
	get_viewport().size_changed.connect(func() -> void: panel.position.x = get_viewport().get_visible_rect().size.x-330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202d29")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Tree personality · F8"
	title.add_theme_font_size_override("font_size",21)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Pull a tree, then compare its rebound."
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)
	for label in ["Original", "Supple", "Cartoony"]: profiles.add_item(label)
	profiles.selected = PlaySpringTree.motion_style
	profiles.item_selected.connect(func(index: int) -> void:
		_cancel_replay()
		PlaySpringTree.motion_style = index
		status.text = "Original · sliders affect the other styles." if index == 0 else "Same world · "+["Original","Supple","Cartoony"][index]
		for tree in get_tree().get_nodes_in_group("spring_trees"): tree.reset())
	column.add_child(profiles)
	_slider(column,"Release speed",0.65,1.5,func(value: float) -> void: PlaySpringTree.release_speed = value)
	_slider(column,"Crown lag",0.0,1.5,func(value: float) -> void: PlaySpringTree.crown_lag = value)
	_slider(column,"Bounce",0.65,1.4,func(value: float) -> void: PlaySpringTree.rebound = value)
	var replay := Button.new()
	replay.text = "Replay last pull"
	replay.pressed.connect(_replay)
	column.add_child(replay)
	status.text = "Cartoony motion is active across this game."
	status.add_theme_font_size_override("font_size",12)
	column.add_child(status)
	column.add_child(HSeparator.new())
	var character_title := Label.new()
	character_title.text = "Bigfoot · personality"
	character_title.add_theme_font_size_override("font_size",19)
	column.add_child(character_title)
	var character_profiles := OptionButton.new()
	for label in ["Original Bigfoot", "Buoyant & curious"]: character_profiles.add_item(label)
	character_profiles.selected = 1 if CreatureActor.PERSONALITY.enabled else 0
	character_profiles.item_selected.connect(func(index: int) -> void:
		CreatureActor.PERSONALITY.enabled = index == 1
		for actor: CreatureActor in get_tree().get_nodes_in_group("personality_actors"):
			actor.set_personality(index == 1))
	column.add_child(character_profiles)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for entry in [["Watch idle",_watch_idle],["Take a stroll",_stroll],["Close-up",_close_up]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		actions.add_child(button)
	var interaction_row := HBoxContainer.new()
	column.add_child(interaction_row)
	var interaction := OptionButton.new()
	for label in ["Lift & toss log", "Throw stone", "Pull tree"]: interaction.add_item(label)
	interaction_row.add_child(interaction)
	var perform := Button.new()
	perform.text = "Try it"
	perform.pressed.connect(func() -> void: _perform_action(["log","stone","tree"][interaction.selected]))
	interaction_row.add_child(perform)
	character_status.text = "A heavier step. A curious pause."
	character_status.add_theme_font_size_override("font_size",12)
	column.add_child(character_status)

func _slider(column: VBoxContainer, title: String, low: float, high: float, change: Callable) -> void:
	var label := Label.new()
	label.text = title+" · 1.00"
	label.add_theme_font_size_override("font_size",13)
	column.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = 1.0
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s · %.2f" % [title,value]
		change.call(value))
	column.add_child(slider)

func contains(mouse: Vector2) -> bool:
	return visible and panel.get_global_rect().has_point(mouse)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		visible = not visible
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and not contains(event.position): _cancel_replay()

func _cancel_replay() -> void:
	if replay_time>=0.0 and is_instance_valid(replay_tree): replay_tree.cancel()
	replay_time = -1.0

func _replay() -> void:
	_cancel_replay()
	var owner = get_parent()
	if owner.get("mischief") != null: owner.mischief.cancel()
	replay_tree = null
	for tree: PlaySpringTree in get_tree().get_nodes_in_group("spring_trees"):
		if tree.last_grab_msec>=0 and (replay_tree == null or tree.last_grab_msec>replay_tree.last_grab_msec): replay_tree = tree
	if replay_tree == null:
		status.text = "Grab any tree first."
		return
	replay_pull = replay_tree.last_pull
	replay_tree.reset()
	replay_tree.begin_grab()
	replay_time = 0.0
	status.text = "Same pull · "+["Original","Supple","Cartoony"][PlaySpringTree.motion_style]

func _physics_process(delta: float) -> void:
	if idle_watch>0.0:
		if get_parent().get("_paused") != true:
			idle_watch -= delta
			get_parent()._attention_time = maxf(get_parent()._attention_time,0.2)
	if replay_time<0.0: return
	if get_parent().get("_paused") == true:
		_cancel_replay()
		return
	if not is_instance_valid(replay_tree):
		replay_time = -1.0
		return
	replay_time += delta
	replay_tree.drag_to(replay_pull*smoothstep(0.0,0.55,replay_time))
	if replay_time>=0.95:
		replay_tree.release()
		replay_time = -1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _cancel_replay()

func _creature() -> CreatureActor:
	return get_parent().creature

func _prepare_character() -> bool:
	if get_parent().get("_paused") == true or not _creature().can_roam():
		character_status.text = "Let him finish, then try again."
		return false
	get_parent().mischief.cancel()
	get_parent().mischief._cooldown = 20.0
	get_parent().brain.reset_behavior()
	return true

func _watch_idle() -> void:
	if not _prepare_character(): return
	_creature().stop_walking()
	_creature()._gaze_weight = 0.0
	_creature().player.play("Idle",0.15)
	_creature().player.seek(0.0,true)
	get_parent().brain._wait = 18.0
	idle_watch = 18.0
	character_status.text = "Watching his full idle · 18 seconds"

func _stroll() -> void:
	if not _prepare_character(): return
	idle_watch = 0.0
	get_parent()._attention_time = 0.0
	var actor := _creature()
	var navigation = get_parent().navigation
	var right: Vector3 = get_parent().camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	for direction in [right,-right,Vector3.FORWARD,Vector3.BACK]:
		var destination: Variant = navigation.nearest_safe(actor.global_position+direction*4.5)
		if destination == null or actor.global_position.distance_to(destination)<2.5: continue
		var route: PackedVector3Array = navigation.path(actor.global_position,destination)
		if route.is_empty(): continue
		var brain = get_parent().brain
		brain._route = route
		brain._waypoint = 0
		brain._destination = destination
		brain._interest_id = ""
		brain._tracks_object = false
		brain.speed = 0.65
		brain.phase = CreatureBrain.Phase.MOVE
		brain.enabled = true
		character_status.text = "Taking a stroll · try both styles"
		return
	character_status.text = "He needs a clearer patch to walk across."

func _close_up() -> void:
	var scene = get_parent().get("owner_scene")
	if scene == null: scene = get_parent()
	scene.target = _creature().global_position+Vector3.UP*1.4
	scene.distance = 8.0
	scene.yaw = _creature().rotation.y+0.5
	scene.polar = 1.2
	scene._auto_orbit = false
	scene._update_camera()

func _perform_action(kind: String) -> void:
	if not _prepare_character(): return
	idle_watch = 30.0
	get_parent()._attention_time = 30.0
	character_status.text = "Watch him approach, gather, and release."
	if not get_parent().mischief.request(kind):
		character_status.text = "He needs a reachable "+kind+" nearby."
