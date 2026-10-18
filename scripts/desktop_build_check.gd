extends RefCounted
## Explicit CI self-check: release templates disallow --script/path overrides.
## The native kernel and mesh equivalence first (any scene), then the scene's
## own walk: the front door (studies/zenscape.tscn, the main scene: the title
## over the isle, Begin, on foot by the plane, the plane boards and flies,
## a clean teardown).

const ManualLanding = preload("res://scripts/manual_landing.gd")

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
	if scene.get("front_door") == null:
		_fail(tree,"the scene has no front door")
		return
	await _check_front_door(scene)

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
	# Climbed in, it stands on its wheels; it flies only rolled off the
	# isle's edge (scripts/manual_landing.gd's dip). Steered to the nearest
	# edge through the plane's own input actions, as a player would.
	deadline = Time.get_ticks_msec()+120_000
	while not (scene.takeoff == null and scene.hand_landing.on_ground()):
		if Time.get_ticks_msec() >= deadline or not bool(scene.flying):
			_fail(tree,"the plane was not handed over on its wheels")
			return
		await tree.process_frame
	var p: Vector3 = scene.plane.position
	var best := Vector2.ZERO
	var reach := INF
	for i in range(24):
		var way := Vector2.from_angle(TAU*i/24.0)
		var d: float = ManualLanding.edge_margin(Callable(scene,"floor_at"),Vector2(p.x,p.z),way)
		if d < reach:
			reach = d
			best = way
	var want := atan2(-best.x,-best.y)
	var flew := false
	while Time.get_ticks_msec() < deadline and bool(scene.flying):
		if scene.hand_landing.flying() and not scene.hand_landing.dipping():
			flew = true
			break
		var off := angle_difference(float(scene.plane.heading),want)
		var turn := 0.0
		var brake := 0.0
		if scene.hand_landing.on_ground() and absf(off) > 0.1:
			if scene.hand_landing.phase == ManualLanding.STOPPED:
				turn = -signf(off)
				brake = 1.0
			else: turn = clampf(-off*2.0,-1.0,1.0)
		Input.action_press(&"fly_boost")
		if brake > 0.0: Input.action_press(&"fly_brake")
		else: Input.action_release(&"fly_brake")
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		if turn > 0.0: Input.action_press(&"move_right",turn)
		elif turn < 0.0: Input.action_press(&"move_left",-turn)
		await tree.process_frame
	for action in [&"fly_boost",&"fly_brake",&"move_left",&"move_right"]: Input.action_release(action)
	if not flew:
		_fail(tree,"the plane did not roll off the isle's edge and fly")
		return
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
