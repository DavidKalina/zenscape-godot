extends SceneTree
## Rope bridges alive (scripts/rope_bridge.gd), rendered: on the showcase
## cluster (--showcase) the pilot is set down by the farm's rope bridge to
## the wood and runs across it behind the chase camera ("cross"); runs back
## seen from the side, jumping at the middle ("side"); then stands while a
## strong wind blows, seen along the span and from the side ("gust"). Each
## saved frame prints the bridge's deepest sink and its sway at the middle.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_rope_bridge.gd \
##     -- --no-title --showcase [--out=captures/rope-bridge] [--every=4]
var scene: Node3D
var eye: Node
var out := "captures/rope-bridge"
var every := 4
var _view := {}
var _bridge: MeshInstance3D
var _lead: Dictionary
var _held: Camera3D

func _initialize() -> void:
	run.call_deferred()

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	var sim: RefCounted = _bridge.sim
	print("ROPE %s deepest %.3f sway %.3f rattle %.4f feet %s" % [label,sim.deepest(),sim.sway(0.5),sim.rattle,str(eye.motor.feet.snapped(Vector3.ONE*0.01))])

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--every="): every = int(argument.trim_prefix("--every="))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("rope bridge capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = OS.get_temp_dir().path_join("rope-bridge-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	scene.world_clock.running = false
	scene.world_clock.set_time(scene.world_clock.day,WorldClock.hour_for_phase(0.62))
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await process_frame
	eye._launch(6.0,false)
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await process_frame
	var field: Node3D = islands.clusters
	field.plan_now("showcase")
	var stood: Dictionary = field.members_of("showcase")
	# The rope bridge and the member whose frame it is in.
	for b: Dictionary in stood.values():
		for child in (b.node as Node3D).get_children():
			if child.get("sim") != null:
				_bridge = child
				_lead = b
	if _bridge == null:
		push_error("no live rope bridge on the showcase")
		quit(1)
		return
	RenderingServer.frame_pre_draw.connect(_aim)
	var a: Vector3 = _bridge.a
	var b: Vector3 = _bridge.b
	var way := Vector2(b.x-a.x,b.z-a.z).normalized()
	print("ROPE bridge on %s span %.1f m nodes %d" % [_lead.node.name,_bridge.span,_bridge.sim.nodes])
	# Set down a little back from its near end, facing along it.
	var start := a-Vector3(way.x,0.0,way.y)*1.2
	eye.glide.position = islands.islets.place(_lead)+start+Vector3.UP*0.3
	eye.glide.heading = atan2(-way.x,-way.y)
	eye.glide.speed = 0.5
	eye._perch(_lead)
	eye.motor.reset(eye.motor.feet,eye.glide.heading,0.0)
	eye._yaw = eye.glide.heading
	for i in range(90): await process_frame
	# Across behind the chase camera.
	Input.action_press(&"move_forward")
	for i in range(150):
		await process_frame
		if i % every == 0: await still("cross_%03d" % i)
	Input.action_release(&"move_forward")
	for i in range(60): await process_frame
	# Back, seen from the side, a jump at the middle.
	var mid := a.lerp(b,0.5)
	var across: Vector3 = _bridge.across
	_view = {"eye":mid+across*7.5+Vector3.UP*0.6,"look":mid+Vector3.DOWN*0.3}
	Input.action_press(&"move_forward")
	var jumped := false
	var goal := a-Vector3(way.x,0.0,way.y)*1.5
	for i in range(240):
		if eye.perch.is_empty(): break
		var world: Vector3 = (eye.perch.node as Node3D).to_global(eye.motor.feet)
		var local: Vector3 = _lead.node.to_local(world)
		var t: float = Vector2(local.x-a.x,local.z-a.z).dot(way)/float(_bridge.span)
		# Steered for the middle line, then on to the near end.
		var aim := a.lerp(b,clampf(t-0.15,0.0,1.0)) if t > 0.05 else goal
		var to := Vector2(aim.x-local.x,aim.z-local.z)
		eye._yaw = atan2(-to.x,-to.y)
		await process_frame
		if not jumped and t < 0.55:
			jumped = true
			Input.action_press(&"walk_jump")
		if jumped and i % 12 == 0: Input.action_release(&"walk_jump")
		if i % every == 0: await still("side_%03d" % i)
		if t < -0.15: break
	Input.action_release(&"move_forward")
	Input.action_release(&"walk_jump")
	# Stood still in a strong wind, along the span then from the side.
	var air: Variant = scene.get("_atmosphere")
	if air != null:
		# Strong air, blowing across the span.
		air.strength = 1.6
		air._air_strength = 1.6
		air.swell = 0.4
		var flat: Vector3 = _lead.node.global_basis*_bridge.across
		air._air_angle = atan2(flat.z,flat.x)
	_view = {"eye":a-Vector3(way.x,0.0,way.y)*3.0+Vector3.UP*1.6,"look":b+Vector3.DOWN*0.6}
	for i in range(120):
		await process_frame
		if i % (every*2) == 0: await still("gust_along_%03d" % i)
	_view = {"eye":mid+across*9.0+Vector3.UP*2.0,"look":mid}
	for i in range(120):
		await process_frame
		if i % (every*2) == 0: await still("gust_side_%03d" % i)
	print("ROPE done")
	quit(0)

## Before each draw, a held view (in the bridge member's frame) is taken
## by a camera of the capture's own, made current over the chase camera.
func _aim() -> void:
	if _view.is_empty() or _lead.is_empty():
		if _held != null and _held.current: scene.camera.make_current()
		return
	if _held == null:
		_held = Camera3D.new()
		_held.fov = 60.0
		_held.far = scene.camera.far
		_held.environment = scene.camera.environment
		_held.attributes = scene.camera.attributes
		_held.compositor = scene.camera.compositor
		scene.camera.get_parent().add_child(_held)
	var node: Node3D = _lead.node
	var at: Vector3 = node.to_global(_view.eye)
	var look: Vector3 = node.to_global(_view.look)
	_held.global_transform = Transform3D(Basis.looking_at(look-at,Vector3.UP),at)
	if not _held.current: _held.make_current()
