extends SceneTree
## An islander up close (scripts/islander_figure.gd), for judging the sky
## folk's look and moves: one stands on a patch of grass under an open sky
## while the camera circles, running through idle, wave, jump, hail and
## walk (walking, it toddles round a ring on the grass at its stride's pace).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . -s res://tools/view_islander.gd
## Keys: drag to turn the camera, wheel to come closer, 1-5 a move (idle,
## wave, jump, hail, walk; stops the cycling), C cycles them again, S the scarf's
## colour, Space stops the circling.
## With --shots=DIR it saves stills of each move into DIR and quits.
const IslanderFigure = preload("res://scripts/islander_figure.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
## Seconds each move runs while cycling.
const CYCLE := 5.0
## The ring it walks round (m).
const RING := 0.38

var stage: Node3D
var figure: Node3D
var camera: Camera3D
var orbit := Vector2(0.5,0.15)
var distance := 1.3
var circling := true
var cycling := true
var cycle_clock := 0.0
var scarf := 0
var dragging := false
## Where it is round the ring (radians).
var around := 0.0

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
	var grass := MeshInstance3D.new()
	grass.mesh = FacetMesh.frustum(0.7,0.65,0.06,9)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("7d9a52")
	green.roughness = 0.9
	grass.material_override = green
	grass.position = Vector3(0.0,-0.03,0.0)
	stage.add_child(grass)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.current = true
	root.window_input.connect(_on_input)
	_build()
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots = arg.trim_prefix("--shots=")
	if shots != "": await _shoot(shots)

func _build() -> void:
	var move := "idle"
	var placed := Transform3D.IDENTITY
	if figure != null:
		move = figure.move
		placed = figure.transform
		figure.free()
	figure = IslanderFigure.new(SkyTraffic.LIVERIES[scarf-1].scarf if scarf > 0 else IslanderFigure.PersonKit.SCARF)
	stage.add_child(figure)
	figure.transform = placed
	figure.play(move)

func _process(delta: float) -> bool:
	if figure == null: return false
	if cycling:
		cycle_clock += delta
		if cycle_clock >= CYCLE:
			cycle_clock = 0.0
			var moves: Array = IslanderFigure.MOVES
			figure.play(moves[(moves.find(figure.move)+1)%moves.size()])
	if figure.move == "walk":
		around += IslanderFigure.WALK_SPEED/RING*delta
		var ahead := Vector3(-sin(around),0.0,cos(around))
		figure.position = Vector3(cos(around),0.0,sin(around))*RING
		figure.rotation.y = atan2(-ahead.x,-ahead.z)
	if circling: orbit.x += delta*0.3
	var at: Vector3 = figure.position+Vector3(0.0,0.26,0.0)
	var offset := Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))*distance
	camera.look_at_from_position(at+offset,at)
	return false

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT: dragging = button.pressed
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(0.4,distance*0.9)
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(6.0,distance*1.1)
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		orbit.x -= motion.relative.x*0.008
		orbit.y = clampf(orbit.y+motion.relative.y*0.006,-0.3,1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_5:
			cycling = false
			figure.play(IslanderFigure.MOVES[key-KEY_1])
		elif key == KEY_C:
			cycling = true
			cycle_clock = 0.0
		elif key == KEY_S:
			scarf = (scarf+1)%(SkyTraffic.LIVERIES.size()+1)
			_build()
		elif key == KEY_SPACE: circling = not circling

func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	circling = false
	cycling = false
	var views := {"idle":[0.0,0.5],"wave":[0.4,0.6],"jump":[0.6,0.42],"hail":[-0.4,0.75],"walk":[1.2,1.3]}
	for label: String in views:
		figure.play(label)
		orbit = Vector2(views[label][0],0.15)
		for i in range(int(float(views[label][1])*60.0)+30): await process_frame
		await RenderingServer.frame_post_draw
		var path := dir.path_join(label+".png")
		root.get_texture().get_image().save_png(path)
		print("ISLANDER VIEW still ",path)
	quit()
