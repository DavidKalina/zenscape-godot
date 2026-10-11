extends RefCounted
## Explicit CI self-check: release templates disallow --script/path overrides.
## The native kernel and mesh equivalence first (any scene), then the scene's
## own walk: the front door (studies/zenscape.tscn, the main scene: the title
## over the isle, Begin, on foot by the plane, the plane boards and flies,
## a clean teardown) or, run from the old game (studies/cozy_worlds.tscn),
## its hand scheme or creation shell, photo mode and main menu.
static func run(scene: Node) -> void:
	var tree := scene.get_tree()
	var kernel = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	if kernel == null or not kernel.has_method("shade"):
		push_error("FAIL: packaged native terrain kernel is unavailable")
		tree.quit(1)
		return
	print("PASS: packaged native terrain kernel loaded")
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.paint_grass(Vector2.ZERO,3.0,0.7)
	for fixture in range(3):
		if fixture == 1:
			data.reset_flat()
			await data.form_foundation(1.0,1.0)
			data.paint_tint(Vector2(-3,2),4.0,Color(0.7,0.1,0.3),0.6)
		elif fixture == 2:
			await preload("res://scripts/native_landscape_presets.gd").form(data,"horn")
			data.brush(Vector2.ZERO,4.0,0.8,"raise",0.0)
		data.native_mesh_enabled = false
		var reference := var_to_bytes(data.build_mesh(true).surface_get_arrays(0))
		data.native_mesh_enabled = true
		if var_to_bytes(data.build_mesh(true).surface_get_arrays(0)) != reference:
			push_error("FAIL: packaged native synchronous mesh differs from GDScript")
			tree.quit(1)
			return
		for workers in [0,1,2,4,8]:
			data.mesh_workers = workers
			var mesh := await data.build_mesh_budgeted(true,tree)
			if mesh == null or var_to_bytes(mesh.surface_get_arrays(0)) != reference:
				push_error("FAIL: packaged native worker mesh differs from GDScript")
				tree.quit(1)
				return
	print("PASS: packaged native mesh equivalence")
	if scene.get("front_door") != null:
		await _check_front_door(scene)
		return
	# The old game opens on the Genesis plain with a creation brush in hand.
	var deadline := Time.get_ticks_msec()+120_000
	while not bool(scene.get("shell_ready")):
		if Time.get_ticks_msec() >= deadline or scene.get("shell_ready") == null:
			push_error("FAIL: packaged startup did not reach the creation shell")
			tree.quit(1)
			return
		await tree.process_frame
	var failure := ""
	if scene.hand_only:
		failure = _check_hand_scheme(scene)
	else:
		failure = _check_creation_shell(scene)
		if failure.is_empty(): failure = _check_photo_mode(scene)
	if not failure.is_empty():
		push_error("FAIL: packaged "+failure)
		tree.quit(1)
		return
	print("PASS: packaged photo mode enter %.2f ms, leave %.2f ms" % [scene.photo.timings.enter/1000.0,scene.photo.timings.leave/1000.0])
	var hand_only: bool = scene.hand_only
	var folders: Array[String] = [scene.library_path]
	if scene.places_path.get_base_dir() != scene.library_path: folders.append(scene.places_path.get_base_dir())
	var audio_streams: Array[WeakRef] = []
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in scene.find_children("*",kind,true,false):
			if player.stream != null: audio_streams.append(weakref(player.stream))
	scene.free()
	var release_deadline := Time.get_ticks_msec()+2000
	while audio_streams.any(func(stream: WeakRef) -> bool: return stream.get_ref() != null):
		if Time.get_ticks_msec() >= release_deadline:
			push_error("FAIL: packaged audio streams retained after shutdown")
			tree.quit(1)
			return
		await tree.process_frame
	for folder in folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	print("PASS: packaged hand scheme, photo and main menu" if hand_only else "PASS: packaged creation shell, Look, Craft and main menu")
	tree.quit(0)

## Walk the creation shell the way a player first meets it. Returns what
## failed, or "" when every step held.
static func _check_creation_shell(scene: Node) -> String:
	var editor: Node = scene._chunk_editor
	var palette: Control = scene.creation_palette
	if not scene._has_world or not scene.places.plain or not editor.data.blank:
		return "startup did not open on the Genesis plain"
	var ids: Array = scene.brush_ids
	if palette == null or not palette.is_visible_in_tree() or ids.is_empty() or palette.brush_ids() != ids:
		return "creation palette is missing or does not list the registered brushes"
	for id: String in ids:
		if not palette.buttons.has(id) or not palette.buttons[id].is_visible_in_tree():
			return "creation palette has no button for brush "+id
	if not scene._creating() or editor.held_brush() != ids[0] or not palette.buttons[ids[0]].button_pressed:
		return "launch did not put the first brush in hand"
	var rail: Control = scene._build_palette.get("_tool_rail")
	if rail != null and rail.is_visible_in_tree():
		return "craft rail is showing in creation mode"
	# Look puts the brush away: nothing paints and a press falls to the camera.
	palette.look_button.pressed.emit()
	if not scene.looking or editor.active or scene._creating() or not palette.look_button.button_pressed:
		return "Look did not put the brush away"
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_viewport().get_visible_rect().size*0.5
	var revision: PackedFloat32Array = editor.data.heights.duplicate()
	scene._unhandled_input(press)
	var orbiting: bool = scene._orbiting
	var release := press.duplicate()
	release.pressed = false
	scene._input(release)
	if editor._painting or editor.data.heights != revision or not orbiting:
		return "a press while looking painted instead of turning the camera"
	palette.buttons[ids[0]].pressed.emit()
	if scene.looking or not scene._creating() or editor.held_brush() != ids[0]:
		return "picking the brush did not end Look"
	# Every registered brush goes into the editor's hand from its button.
	for id: String in ids:
		palette.buttons[id].pressed.emit()
		if not scene._creating() or editor.held_brush() != id or not palette.buttons[id].button_pressed:
			return "picking brush "+id+" did not put it in hand"
	palette.buttons[ids[0]].pressed.emit()
	# Craft opens the fine tools behind one control; Create returns to the brush.
	scene._build_button.pressed.emit()
	if not scene.crafting or not editor.active or rail == null or not rail.is_visible_in_tree() or palette.is_visible_in_tree():
		return "Craft did not open the fine tools"
	scene._build_button.pressed.emit()
	if scene.crafting or not scene._creating() or rail.is_visible_in_tree() or not palette.is_visible_in_tree():
		return "Create did not return to the brush"
	# The main menu covers the shell and gives it back.
	scene.show_menu()
	if scene._menu == null or not scene._menu.visible or palette.is_visible_in_tree():
		return "main menu is missing"
	scene.close_menu()
	if scene._menu.visible or not palette.is_visible_in_tree() or not scene._creating():
		return "closing the main menu did not return to the brush"
	return ""

## The hand scheme (scripts/modeless_input.gd), the default product: no brush
## bar or Photo button, the hand at work on the Genesis plain, P for photo
## and Esc for the main menu. Returns what failed, or "".
static func _check_hand_scheme(scene: Node) -> String:
	var editor: Node = scene._chunk_editor
	var palette: Control = scene.creation_palette
	var photo: Node = scene.get("photo")
	if not scene._has_world or not scene.places.plain or not editor.data.blank:
		return "startup did not open on the Genesis plain"
	if scene.hand_reach == null or not scene._creating():
		return "launch did not put the hand to work"
	if palette == null or palette.bar.visible or palette.photo_group.visible:
		return "hand scheme still shows the brush bar or the Photo button"
	var heights: PackedFloat32Array = editor.data.heights.duplicate()
	if photo == null or not scene._creation_key(_key(KEY_P)) or not photo.active or editor.active or not photo.chrome_hidden():
		return "P did not open photo mode"
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_viewport().get_visible_rect().size*Vector2(0.5,0.4)
	var yaw: float = photo._goal.yaw
	var used: bool = photo.handle(press)
	var drag := InputEventMouseMotion.new()
	drag.position = press.position+Vector2(80,0)
	drag.relative = Vector2(80,0)
	used = photo.handle(drag) and used
	var release := press.duplicate()
	release.pressed = false
	release.position = drag.position
	used = photo.handle(release) and used
	if not used or editor._painting or editor.data.heights != heights or is_equal_approx(photo._goal.yaw,yaw):
		return "a drag in photo mode did not turn the camera, or painted"
	photo.handle(_key(KEY_P))
	if photo.active or not scene._creating():
		return "P did not return from photo mode to the hand"
	if not scene._creation_key(_key(KEY_ESCAPE)) or scene._menu == null or not scene._menu.visible:
		return "Esc did not open the main menu"
	scene.close_menu()
	if scene._menu.visible or not scene._creating():
		return "closing the main menu did not return to the hand"
	return ""

static func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	return key

## Photo mode from the palette and from P: the brush goes away, the chrome
## hides, a drag turns the composed camera without painting, and P or Esc
## returns to the brush or to Look. Returns what failed, or "".
static func _check_photo_mode(scene: Node) -> String:
	var editor: Node = scene._chunk_editor
	var palette: Control = scene.creation_palette
	var photo: Node = scene.get("photo")
	var ids: Array = scene.brush_ids
	if photo == null or palette.get("photo_button") == null or not palette.photo_button.is_visible_in_tree():
		return "creation palette has no Photo button"
	var fov: float = scene.camera.fov
	var heights: PackedFloat32Array = editor.data.heights.duplicate()
	palette.photo_button.pressed.emit()
	if not photo.active or editor.active or scene._creating() or not photo.layer.visible or not photo.chrome_hidden():
		return "Photo did not put the brush away and hide the chrome"
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_viewport().get_visible_rect().size*Vector2(0.5,0.4)
	var yaw: float = photo._goal.yaw
	var used: bool = photo.handle(press)
	var drag := InputEventMouseMotion.new()
	drag.position = press.position+Vector2(80,0)
	drag.relative = Vector2(80,0)
	used = photo.handle(drag) and used
	var release := press.duplicate()
	release.pressed = false
	release.position = drag.position
	used = photo.handle(release) and used
	if not used or editor._painting or editor.data.heights != heights or is_equal_approx(photo._goal.yaw,yaw):
		return "a drag in photo mode did not turn the camera, or painted"
	photo.step_lens(1)
	if photo._fov_goal >= fov-1.0:
		return "the photo lens did not step to a longer focal length"
	photo.set_ground(true)
	if not photo.ground or not photo.get("_goal").has("eye"):
		return "photo mode's ground eye did not start"
	photo.set_ground(false)
	var file: String = photo.file_name()
	if not file.begins_with("ZenScape") or not file.ends_with(".png") or photo.folder().is_empty():
		return "photo file name or folder is missing: "+file
	photo.handle(_key(KEY_P))
	if photo.active or photo.layer.visible or not scene._creating() or editor.held_brush() != ids[0] or not palette.is_visible_in_tree():
		return "P did not return from photo mode to the brush"
	# From Look, P opens photo mode and Esc goes back to Look.
	scene.set_looking(true)
	if not scene._creation_key(_key(KEY_P)) or not photo.active:
		return "P while looking did not open photo mode"
	photo.handle(_key(KEY_ESCAPE))
	if photo.active or not scene.looking or editor.active or not palette.is_visible_in_tree():
		return "Esc did not return from photo mode to Look"
	scene.select_brush(ids[0])
	if not scene._creating():
		return "picking the brush after photo mode did not put it in hand"
	return ""

## The front door (scripts/kit_isle/front_door.gd) as a player first meets
## it: the isle up under the title, Begin, on foot by the parked plane, the
## plane boarded and off the turf, then the scene freed with its sounds let
## go. Prints the two front-door markers tools/verify_desktop_export.py
## looks for, and quits with the verdict.
static func _check_front_door(scene: Node) -> void:
	var tree := scene.get_tree()
	var door: Node = scene.front_door
	var deadline := Time.get_ticks_msec()+600_000
	while not (bool(scene.isle_up) and bool(door.titled)):
		if Time.get_ticks_msec() >= deadline:
			_fail(tree,"startup did not reach the title over the isle")
			return
		await tree.process_frame
	var title: Control = door.title
	if title == null or not title.is_visible_in_tree() or door.begin_button == null or not door.begin_button.has_focus():
		_fail(tree,"title is missing, or Begin is not in reach")
		return
	if not bool(scene.scripted) or bool(scene.flying) or not bool(scene.parked):
		_fail(tree,"the pilot is not held under the title by the parked plane")
		return
	var eye: Vector3 = scene.camera.global_position
	for i in range(10): await tree.process_frame
	if scene.camera.global_position.distance_to(eye) < 0.001:
		_fail(tree,"the title's camera does not orbit the isle")
		return
	print("PASS: packaged front door title over the isle")
	door.begin_button.pressed.emit()
	await tree.process_frame
	if bool(door.titled) or bool(scene.scripted) or not scene.by_plane():
		_fail(tree,"Begin did not put the pilot on foot by the plane")
		return
	scene.board_parked()
	if not bool(scene.flying):
		_fail(tree,"the parked plane did not board")
		return
	var ground: float = scene.parked_at.y
	deadline = Time.get_ticks_msec()+120_000
	while not (bool(scene.flying) and scene.plane != null and float(scene.plane.position.y) > ground+4.0):
		if Time.get_ticks_msec() >= deadline or not bool(scene.flying):
			_fail(tree,"the plane did not take off from the isle")
			return
		await tree.process_frame
	var audio_streams: Array[WeakRef] = []
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in scene.find_children("*",kind,true,false):
			if player.stream != null: audio_streams.append(weakref(player.stream))
	scene.free()
	var release_deadline := Time.get_ticks_msec()+2000
	while audio_streams.any(func(stream: WeakRef) -> bool: return stream.get_ref() != null):
		if Time.get_ticks_msec() >= release_deadline:
			_fail(tree,"audio streams retained after shutdown")
			return
		await tree.process_frame
	print("PASS: packaged walk, plane and teardown")
	tree.quit(0)

static func _fail(tree: SceneTree, what: String) -> void:
	push_error("FAIL: packaged "+what)
	tree.quit(1)
