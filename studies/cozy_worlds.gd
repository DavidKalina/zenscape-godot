extends "res://studies/diorama.gd"
## The full diorama renderer/editor, with reversible growth for regenerating the current place.
var places: Node
var places_ready := false
var places_path := "user://cozy-worlds/places.json"

func _ready() -> void:
	library_path = places_path.get_base_dir()
	recent_file = library_path.path_join("recent.cfg")
	await super._ready()
	places = preload("res://scripts/cozy_regrowth.gd").new()
	add_child(places)
	await places.setup(self)
	places_ready = places.initialized
	get_window().title = "ZenScape · Gentle regrowth"

func launch_fidelity() -> void:
	# Startup is already the fully initialized Fidelity world. The cozy flow prepares
	# a native landscape next, without opening/writing a legacy save.
	if not title_loaded:
		_has_world = true
		_before_menu_paused = false
		_menu_orbit = false
		close_menu()
		set_building(false)
		return
	super.launch_fidelity()

func _process(delta: float) -> void:
	# Formation is presentation time: keep its air and tremor alive while the
	# resident/world clock remain paused. Super applies the resulting camera
	# pose before the fog compositor reads it, so both views stay aligned.
	if places != null and places.initialized and places.busy and _paused:
		_tremor.advance(delta,false)
		_atmosphere.advance(delta,false)
		_motion_time += delta
		RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
		_precipitation.advance(delta,false,_celestial)
	super._process(delta)
	if places != null and places.holding: creature.hide()

func handle_resident_input(event: InputEvent) -> bool:
	# The build palette forwards resident gestures before the scene's _input.
	# Claim the gesture at their shared entry point so the legacy carry handler
	# cannot take Bigfoot before the regrowth controller sees the press.
	if places != null and places.handle(event):
		get_viewport().set_input_as_handled()
		return true
	return super.handle_resident_input(event)

func blocks_world_input(point: Vector2) -> bool:
	if places != null and places.blocks(point): return true
	return super.blocks_world_input(point)

func save_current() -> bool:
	if places == null or not places.initialized: return true
	if places.holding or places.busy: return false
	if not places.save_places():
		_notice.text = "Could not save this place. Please try Save again."
		return false
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_safely()
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and places != null and places.holding and not has_meta("movie_capture"):
		places.cancel_carry()
	super._notification(what)

func _quit_safely() -> void:
	if places != null and places.holding:
		await places.cancel_carry()
		while places.busy or places.holding: await get_tree().process_frame
	if places != null and places.save_places(): get_tree().quit()

func new_diorama() -> void:
	if places == null or places.busy or places.holding or _chunk_editor.forming: return
	super.new_diorama()
	if _chunk_editor.data.blank:
		_refresh_habitat()
		invite_bigfoot(Vector3(0,0,5))
		save_current()

func open_crossing_glade(chasm := false) -> void:
	if places == null or places.busy or places.holding or not save_current(): return
	# Regrowth normally saves over its active slot. Keep an ordinary Open-able
	# world before starting this separate activity, rather than replacing it.
	var previous := _chunk_editor.save_path
	_chunk_editor.save_path = library_path.path_join("Before-crossing-"+str(Time.get_unix_time_from_system())+".json")
	var saved := _chunk_editor.save_garden()
	_chunk_editor.save_path = previous
	if not saved:
		_notice.text = "Could not save the current place. Your world is still open."
		return
	super.open_crossing_glade(chasm)
