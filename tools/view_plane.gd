extends SceneTree
## The plane up close (scripts/plane_figure.gd), for judging its look: it
## flies straight through an open sky, rocking a little in the air, while
## the camera circles it, so the paint's shine, the pilot and the scarf can
## be seen from every side. Rendered only when asked for (needs a window):
##   Godot --windowed --path . -s res://tools/view_plane.gd
## Keys: drag to turn the camera, wheel to come closer, 0-4 the livery on the
## wanderer's model (0 its own; 1-4 traffic's colours and wear, repainted, as
## the shop does), Up/Down the speed, R a barrel roll, P parks it, Space
## stops the circling.
## With --shots=DIR it saves stills round the plane into DIR and quits.
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")

var stage: Node3D
var figure: Node3D
var flight := SkyTraffic.Flight.new()
var camera: Camera3D
var livery := 0
var orbit := Vector2(0.6,0.25)
var distance := 2.6
var circling := true
var clock := 0.0
var dragging := false
## Seconds into a barrel roll, or negative when not rolling.
var rolling := -1.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("6f9fcf")
	sky.sky_horizon_color = Color("dfe6e4")
	sky.ground_bottom_color = Color("c9d4d6")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.current = true
	root.window_input.connect(_on_input)
	flight.speed = 14.0
	_build()
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots = arg.trim_prefix("--shots=")
	if shots != "": await _shoot(shots)

func _build() -> void:
	if figure != null: figure.free()
	figure = PlaneFigure.new()
	stage.add_child(figure)
	if livery > 0:
		var colours: Dictionary = SkyTraffic.LIVERIES[livery-1]
		figure.repaint(colours)
		figure.set_wear(float(colours.get("wear",0.0)))
	figure.reset(flight)

func _process(delta: float) -> bool:
	if figure == null: return false
	clock += delta
	if not figure.parked:
		flight.bank = sin(clock*0.5)*0.35+sin(clock*1.3)*0.08
		if rolling >= 0.0:
			rolling += delta
			flight.spin = TAU*smoothstep(0.0,1.1,rolling)
			if rolling > 1.1:
				rolling = -1.0
				flight.spin = 0.0
		flight.pitch = sin(clock*0.45)*0.05
		flight.velocity = flight.forward()*flight.speed
		flight.position += flight.velocity*delta
		figure.update(delta,flight,0.0,Callable(),false)
	if circling: orbit.x += delta*0.25
	var at: Vector3 = figure.position
	var offset := Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))*distance
	camera.look_at_from_position(at+offset,at+Vector3.UP*0.1)
	return false

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT: dragging = button.pressed
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1.0,distance*0.9)
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(12.0,distance*1.1)
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		orbit.x -= motion.relative.x*0.008
		orbit.y = clampf(orbit.y+motion.relative.y*0.006,-1.2,1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key >= KEY_0 and key <= KEY_4:
			livery = key-KEY_0
			_build()
		elif key == KEY_UP: flight.speed = minf(flight.speed+2.0,30.0)
		elif key == KEY_DOWN: flight.speed = maxf(flight.speed-2.0,0.0)
		elif key == KEY_SPACE: circling = not circling
		elif key == KEY_R and rolling < 0.0: rolling = 0.0
		elif key == KEY_P:
			if figure.parked: figure.reset(flight)
			else: figure.park(PlaneFigure.pose(flight.position,flight.heading,0.12,0.0))

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	circling = false
	var views := {"rear-chase":Vector3(0.0,0.3,2.6),"side":Vector3(1.57,0.12,2.0),"front-quarter":Vector3(2.4,0.2,2.2),"pilot-close":Vector3(0.9,0.35,1.1),"above":Vector3(0.4,1.1,2.6)}
	for label: String in views:
		var view: Vector3 = views[label]
		orbit = Vector2(view.x,view.y)
		distance = view.z
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw
		var path := dir.path_join(label+".png")
		root.get_texture().get_image().save_png(path)
		print("PLANE VIEW still ",path)
	quit()
