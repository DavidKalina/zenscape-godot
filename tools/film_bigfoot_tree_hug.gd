extends SceneTree
## Isolated production performance. Space: pause; arrows: scrub; R: replay.
## Run with -- --film to write a deterministic 30 fps sequence and hero pose.
const Fixture = preload("res://tests/test_bigfoot_environment.gd")
const LIFE = preload("res://scripts/bigfoot_environment.gd")
const FRAME_DIR := "/private/tmp/bigfoot-tree-hug-frames"
const LEAD_IN := 0.45
const REST := 0.85
const STEP := 1.0 / 60.0
class InputBridge extends Node:
	var callback: Callable
	func _input(event: InputEvent) -> void: callback.call(event)
var stage := Node3D.new()
var world: Node3D
var life: Node
var clock_time := 0.0
var duration := 9.0
var running := true
var started := false
var film := false
var timeline := HSlider.new()
var status := Label.new()
var pause_button := Button.new()
var scrubbing := false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.title = "Bigfoot / A shy tree peek"
	root.size = Vector2i(1280,960)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.msaa_3d = Viewport.MSAA_4X
	root.add_child(stage)
	var input_bridge := InputBridge.new()
	input_bridge.callback = _input
	stage.add_child(input_bridge)
	_build_stage()
	world = Fixture.World.new()
	stage.add_child(world)
	for child in [world.creature,world.brain,world.routine,world._lightning]: world.add_child(child)
	world.creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	world.creature.set_process(false)
	# Fur color is stored in vertex colors; the imported GLB material is white.
	var coat := StandardMaterial3D.new()
	coat.vertex_color_use_as_albedo = true
	coat.roughness = 0.95
	for mesh: MeshInstance3D in world.creature.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	world.brain.setup(world.creature,world.navigation,Callable())
	life = LIFE.new()
	world.add_child(life)
	life.setup(world)
	life.autonomous = false
	world.habitat.interests = [{"id":"hug-study","kind":"tree","position":Vector3(0,0,0.89),"bounds":AABB(Vector3(-0.25,0,0.64),Vector3(0.5,4.4,0.5))}]
	film = "--film" in OS.get_cmdline_user_args()
	_build_controls()
	_reset()
	if film:
		await _capture()
	else:
		while true:
			await process_frame
			if running and not scrubbing:
				_advance(minf(root.get_process_delta_time(),0.05))
				if clock_time>=LEAD_IN+duration+REST: _reset()
			_update_controls()

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("aebeb6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce6e3")
	environment.environment.ambient_light_energy = 0.62
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46,-34,0)
	sun.light_color = Color("ffe2b2")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,130,0)
	fill.light_color = Color("d7eaff")
	fill.light_energy = 0.5
	stage.add_child(fill)
	var ground := PlaneMesh.new()
	ground.size = Vector2(200,200)
	_mesh(ground,Vector3(0,-0.015,0),Color("7c947c"))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.27
	trunk.height = 5.0
	trunk.radial_segments = 12
	_mesh(trunk,Vector3(0,2.5,0.89),Color("76614d"))
	# Small quiet details anchor the feet without obscuring contact or silhouette.
	for i in range(7):
		var root_mesh := CylinderMesh.new()
		root_mesh.top_radius = 0.055
		root_mesh.bottom_radius = 0.1
		root_mesh.height = 0.62
		root_mesh.radial_segments = 5
		var angle := float(i)*TAU/7.0
		var root_piece := _mesh(root_mesh,Vector3(sin(angle)*0.24,0.07,0.89+cos(angle)*0.24),Color("76614d"))
		root_piece.rotation = Vector3(cos(angle)*1.25,0,-sin(angle)*1.25)
	for i in range(14):
		var pebble := SphereMesh.new()
		pebble.radius = 0.06+float(i%3)*0.025
		pebble.height = pebble.radius*0.75
		pebble.radial_segments = 7
		pebble.rings = 3
		var angle := float(i)*2.399
		var distance := 1.55+float(i%4)*0.3
		_mesh(pebble,Vector3(sin(angle)*distance,0.02,0.5+cos(angle)*distance),Color("9ca58c"))
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(1.4,3.4,8.5)
	camera.look_at(Vector3(0,1.65,0.28))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.current = true

func _mesh(mesh: Mesh, point: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	instance.material_override = material
	stage.add_child(instance)
	return instance

func _build_controls() -> void:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var title := Label.new()
	title.text = "A SHY TREE PEEK"
	title.position = Vector2(42,32)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("243c35"))
	overlay.add_child(title)
	status.position = Vector2(43,66)
	status.add_theme_font_size_override("font_size",16)
	status.add_theme_color_override("font_color",Color("385047"))
	overlay.add_child(status)
	var row := HBoxContainer.new()
	row.position = Vector2(42,895)
	row.size = Vector2(1196,34)
	row.add_theme_constant_override("separation",16)
	overlay.add_child(row)
	pause_button.text = "Pause"
	pause_button.pressed.connect(func() -> void: running = not running)
	row.add_child(pause_button)
	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(_reset)
	row.add_child(replay)
	timeline.min_value = 0
	timeline.max_value = LEAD_IN+duration+REST
	timeline.step = STEP
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.drag_started.connect(func() -> void: scrubbing = true)
	timeline.drag_ended.connect(func(_changed: bool) -> void: scrubbing = false)
	timeline.value_changed.connect(_seek)
	row.add_child(timeline)
	row.visible = not film

func _reset() -> void:
	life.cancel()
	# Replaying and seeking must evaluate the same seeded performance.
	life._hug_count = 0
	world.creature.reset_at(Vector3.ZERO)
	world.creature.rotation = Vector3.ZERO
	world.creature.player.seek(0.0,true)
	world.creature._gaze_weight = 0.0
	world.creature._gaze_yaw = 0.0
	world.creature._gaze_pitch = 0.0
	clock_time = 0.0
	started = false

func _start_hug() -> void:
	started = true
	life.active = "tree_hug"
	life._duration = 9.0
	life.target = world.habitat.interests[0].duplicate()
	life.target.center = Vector3(0,0,0.89)
	life.target.radius = 0.25
	life.target.contact_height = 1.75
	life._look = Vector3(0,1.9,0.89)
	life._perform()
	duration = life._duration
	timeline.max_value = LEAD_IN+duration+REST

func _advance(dt: float) -> void:
	clock_time += dt
	if not started and clock_time>=LEAD_IN: _start_hug()
	life.advance(dt)
	world.creature.advance(dt)

func _seek(value: float) -> void:
	_reset()
	while clock_time+STEP<=value: _advance(STEP)
	if value-clock_time>0.00001: _advance(value-clock_time)
	_update_controls()

func _update_controls() -> void:
	timeline.set_value_no_signal(clock_time)
	pause_button.text = "Pause" if running else "Play"
	status.text = "Shy tree peek  /  %.1f s" % maxf(clock_time-LEAD_IN,0.0)

func _input(event: InputEvent) -> void:
	if film or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: running = not running
		KEY_R: _reset()
		KEY_LEFT:
			running = false
			_seek(maxf(0.0,clock_time-0.1))
		KEY_RIGHT:
			running = false
			_seek(minf(LEAD_IN+duration+REST,clock_time+0.1))
		KEY_ESCAPE: quit()

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	# A shorter variant must not leave old trailing frames in the next movie.
	for file_name in DirAccess.get_files_at(FRAME_DIR):
		if file_name.ends_with(".png") and file_name.get_basename().is_valid_int():
			DirAccess.remove_absolute(FRAME_DIR+"/"+file_name)
	DirAccess.make_dir_recursive_absolute("res://docs/bigfoot-tree-hug")
	var frame := 0
	var saved_pose := false
	while clock_time<LEAD_IN+duration+REST:
		_advance(STEP)
		_advance(STEP)
		_update_controls()
		await process_frame
		RenderingServer.force_draw(false)
		var picture := root.get_texture().get_image()
		picture.save_png(FRAME_DIR+"/%04d.png" % frame)
		if not saved_pose and clock_time>LEAD_IN+duration*0.46:
			picture.save_png("res://docs/bigfoot-tree-hug/pose.png")
			saved_pose = true
		frame += 1
	print("TREE HUG STUDY: saved ",frame," frames at 30 fps to ",FRAME_DIR)
	life.cancel()
	stage.queue_free()
	await process_frame
	quit()
