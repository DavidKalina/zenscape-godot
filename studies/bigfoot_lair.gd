extends "res://studies/bigfoot_cave.gd"
## Playable cutaway study. Surface routines remain the source of occupancy.
var lair: Node3D
var inspecting := false
var _resident_layer := 1
var _surface_view := {}
var _inspect_button: Button
var _room_camera_environment := Environment.new()

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Bigfoot's lair"
	lair = preload("res://scripts/bigfoot_lair_room.gd").new()
	lair.position = Vector3(5,-8,7)
	add_child(lair)
	routine.cave.rest_anchor = lair.bed
	_room_camera_environment.background_mode = Environment.BG_COLOR
	_room_camera_environment.background_color = Color("171c22")
	_room_camera_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_room_camera_environment.ambient_light_color = Color("b8bdc8")
	_room_camera_environment.ambient_light_energy = 0.45
	for entry in [["Inspect lair",_toggle_lair],["Another rock arrangement",_redress]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		_life_status.get_parent().add_child(button)
		if entry[0] == "Inspect lair": _inspect_button = button
	camera.cull_mask = 1
	if "--inspect-lair" in OS.get_cmdline_user_args(): _toggle_lair()

func _redress() -> void:
	lair.redress(lair.seed_value+1)

func _toggle_lair() -> void:
	inspecting = not inspecting
	if inspecting:
		_surface_view = {"target":target,"distance":distance,"yaw":yaw,"polar":polar,"auto_orbit":_auto_orbit}
		_auto_orbit = false
		target = lair.position+Vector3(0,1.6,0)
		distance = 18
		yaw = 0.18
		polar = 1.06
		camera.cull_mask = 4
		camera.environment = _room_camera_environment
	else:
		target = _surface_view.target
		distance = _surface_view.distance
		yaw = _surface_view.yaw
		polar = _surface_view.polar
		_auto_orbit = _surface_view.auto_orbit
		camera.cull_mask = 1
		camera.environment = null
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_inspect_button.text = "Return to forest" if inspecting else "Inspect lair"
	_update_camera()

func _process(delta: float) -> void:
	super._process(delta)
	if lair == null: return
	lair.drips.advance(delta,_paused)
	var inside: bool = routine.cave.concealed
	var desired_layer := 4 if inside else 1
	if desired_layer != _resident_layer:
		_set_resident_layer(creature,desired_layer)
		_resident_layer = desired_layer
	creature.visible = resident_enabled and not _habitat_blocked and _growth.terrain>=0.995 and (inspecting if inside else not inspecting)
	if inspecting:
		_life_status.text = "Bigfoot's lair · %s · P pause" % ("paused" if _paused else "sleeping" if inside else "out in the forest")

func _set_resident_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D: node.layers = layer
	for child in node.get_children(): _set_resident_layer(child,layer)

func _focus_cave() -> void:
	if inspecting: _toggle_lair()
	super._focus_cave()

func _focus_resting_spot() -> void:
	if inspecting: _toggle_lair()
	super._focus_resting_spot()

func _focus_bigfoot() -> void:
	if routine != null and routine.cave.concealed and lair != null:
		if not inspecting: _toggle_lair()
		target = lair.bed.global_position+Vector3.UP
		_update_camera()
		return
	if inspecting: _toggle_lair()
	super._focus_bigfoot()

func _reset_camera(reference_pose := false) -> void:
	if inspecting: _toggle_lair()
	super._reset_camera(reference_pose)
