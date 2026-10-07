extends SceneTree
## The pilot on foot up close (scripts/pilot_figure.gd, the Blender clips from
## art/blender/pilot/pilot_build.py), for judging its moves: it stands on a
## patch of grass under an open sky, then walks round a ring at the walk's
## run's speed, then stands again, while the camera circles.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . -s res://tools/view_pilot.gd
## Keys: drag to turn the camera, wheel to come closer, 1 stand, 2 run,
## 3 walk, 4 in between (stops the cycling), 5 skid (from a run, sliding to
## a stop), C cycles again, Space stops the circling, F follows beside it
## (side on) or not.
## With --record=DIR it saves RECORD_SECONDS of frames, side on, running then
## stopping, into DIR and quits (tile them with ffmpeg).
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const GliderFigure = preload("res://scripts/glider_figure.gd")
## Seconds standing, then running, while cycling.
const STAND := 3.0
const RUN := 5.0
## The ring it walks round (m).
const RING := 1.8
const RECORD_SECONDS := 2.0
## Seconds a skid lasts, and its slowing (m/s a second).
const SKID := 0.45
const SKID_SLOWING := 9.0

## What the figure reads of the motor.
class Motor:
	extends RefCounted
	var facing := 0.0
	var grounded := true
	var skidding := false
	var flip := -1.0
	var velocity := Vector3.ZERO
	var feet := Vector3.ZERO
	var pace := 0.0
	func speed() -> float: return pace

var stage: Node3D
var figure: Node3D
var camera: Camera3D
var motor := Motor.new()
var orbit := Vector2(0.6,0.12)
var distance := 3.2
var circling := true
var cycling := true
var follow := false
var clock := 0.0
## The pace asked for, m/s.
var want := 0.0
var around := 0.0
## Seconds of skid left.
var skid := 0.0
var _dragging := false

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
	grass.mesh = GliderFigure._frustum(RING+1.2,RING+1.1,0.06,24)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("7d9a52")
	green.roughness = 0.9
	grass.material_override = green
	grass.position = Vector3(0.0,-0.03,0.0)
	stage.add_child(grass)
	# Stones round the ring, to see the boots keep to the ground against.
	for i in range(16):
		var stone := MeshInstance3D.new()
		stone.mesh = GliderFigure._gem(0.05)
		stone.material_override = green.duplicate()
		(stone.material_override as StandardMaterial3D).albedo_color = Color("8a8279")
		var a := TAU*i/16.0
		stone.position = Vector3(cos(a),0.0,sin(a))*(RING+0.45)
		stage.add_child(stone)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.current = true
	root.window_input.connect(_on_input)
	figure = PilotFigure.new()
	stage.add_child(figure)
	_place(0.0)
	figure.settle()
	var record := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--record="): record = arg.trim_prefix("--record=")
	if record != "": await _record(record)

func _process(delta: float) -> bool:
	if figure == null: return false
	if cycling:
		clock = fmod(clock+delta,STAND+RUN)
		want = PilotFigure.RUN_SPEED if clock >= STAND else 0.0
	# Up to the pace and down again as the motor does (scripts/pilot_motor.gd);
	# skidding, it slides to a stop.
	skid = maxf(0.0,skid-delta)
	motor.skidding = skid > 0.0
	if motor.skidding: motor.pace = move_toward(motor.pace,0.0,SKID_SLOWING*delta)
	else: motor.pace = move_toward(motor.pace,want,(14.0 if want > motor.pace else 18.0)*delta)
	_place(delta)
	figure.drive(motor,delta)
	if circling and not follow: orbit.x += delta*0.25
	_aim()
	return false

## Round the ring at the motor's pace, facing the way it goes.
func _place(delta: float) -> void:
	around += motor.pace/RING*delta
	var ahead := Vector3(-sin(around),0.0,cos(around))
	figure.position = Vector3(cos(around),0.0,sin(around))*RING
	motor.facing = atan2(-ahead.x,-ahead.z)
	figure.rotation.y = motor.facing

func _aim() -> void:
	var at: Vector3 = figure.position+Vector3(0.0,0.62,0.0)
	if follow:
		# Side on, from outside the ring.
		var out := Vector3(cos(around),0.0,sin(around))
		camera.look_at_from_position(at+out*distance+Vector3(0.0,0.25,0.0),at)
		return
	var offset := Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))*distance
	camera.look_at_from_position(at+offset,at)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT: _dragging = button.pressed
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(0.8,distance*0.9)
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(10.0,distance*1.1)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		orbit.x -= motion.relative.x*0.008
		orbit.y = clampf(orbit.y+motion.relative.y*0.006,-0.3,1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				cycling = false
				want = 0.0
			KEY_2:
				cycling = false
				want = PilotFigure.RUN_SPEED
			KEY_3:
				cycling = false
				want = PilotFigure.WALK_SPEED
			KEY_4:
				cycling = false
				want = (PilotFigure.BLEND_FROM+PilotFigure.BLEND_TO)*0.5
			KEY_5:
				cycling = false
				want = 0.0
				motor.pace = maxf(motor.pace,PilotFigure.RUN_SPEED)
				skid = SKID
			KEY_C:
				cycling = true
				clock = 0.0
			KEY_SPACE: circling = not circling
			KEY_F: follow = not follow


## Side on: standing, running, then stopping, every other frame.
func _record(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	cycling = false
	follow = true
	distance = 2.6
	var frames := int(RECORD_SECONDS*60.0)
	var shot := 0
	for pace: float in [0.0,PilotFigure.RUN_SPEED,0.0]:
		want = pace
		for i in range(frames):
			await process_frame
			if i%2 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(dir.path_join("pilot_%03d.png" % shot))
				shot += 1
	print("PILOT VIEW recorded ",dir)
	quit()
