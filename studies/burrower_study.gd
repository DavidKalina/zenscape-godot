extends Node3D
## The burrower study (docs/design/endless-flight/spec-burrower.md): a small
## slice of land (scripts/burrower/burrower_land.gd: a meadow with the
## game's carpet grass, a pond, a knoll, boulders, a ruin stub, trees) flown
## by the game's plane (SkyPlane, PlaneFigure, the chase camera GlideCamera
## and its input, as studies/endless_flight.gd sets them up), its prop wash
## parting the grass (GrassReact). Here the burrowing trail's look and
## animation are worked out before any of it goes into endless flight.
##
## Keys: as endless flight (A D bank, W S pitch, mouse steers, Space boost,
## Shift brake, Q E knife edge, twice to roll); R up again over the meadow.
## Flags: --grass=X (the carpet's share, 1; 0 none), --at=x,z --alt=m
## --heading=deg (the launch).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const FlightWeight = preload("res://scripts/flight_weight.gd")
const FlightPace = preload("res://scripts/flight_pace.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Pad = preload("res://scripts/pad.gd")
const GrassReact = preload("res://scripts/endless/grass_react.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Land = preload("res://scripts/burrower/burrower_land.gd")

const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
const LOOK_LINGER := 2.5
const RUSH_FOV := 1.8
const CLOSE_IN := 0.12
const CLOSE_DOWN := 0.18

var land: Land
var plane: SkyPlane
var figure: PlaneFigure
var chase: GlideCamera
var camera: Camera3D
var react: GrassReact
var ground_scale := PlaneGroundScale.new()
var weight := FlightWeight.flag(FlightWeight.DEFAULT)
var pace := FlightPace.flag(FlightPace.DEFAULT)
## Set by a driver (tools/harness): its ticks fly the plane, not _physics_process.
var scripted := false
var flight_ready := false
var _space: PhysicsDirectSpaceState3D
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := 0
var _start := Vector3(0.0,14.0,150.0)
var _heading := 0.0
var _hint: Label

func _ready() -> void:
	Pad.ensure()
	var grass := 1.0
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--grass="): grass = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--at="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 2: _start = Vector3(float(p[0]),_start.y,float(p[1]))
		elif a.begins_with("--alt="): _start.y = a.get_slice("=",1).to_float()
		elif a.begins_with("--heading="): _heading = deg_to_rad(a.get_slice("=",1).to_float())
	_build_light()
	land = Land.new()
	add_child(land)
	var t0 := Time.get_ticks_msec()
	land.build(grass)
	print("burrower study: land built in %d ms, %d grass tufts" % [Time.get_ticks_msec()-t0,land.grass_tufts])
	if GrassReact.wanted():
		react = GrassReact.new()
		add_child(react)
		react.setup(1)
		# No gust rings (endless flight's default breeze is its eddies, not here).
		react.rings_on = false
	_build_ui()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = get_world_3d().direct_space_state
	launch(Vector3(_start.x,land.height(_start.x,_start.z)+_start.y,_start.z),_heading)
	flight_ready = true
	if not scripted and get_tree().current_scene == self and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("4f86c6")
	sky.sky_horizon_color = Color("dfe6e4")
	sky.ground_bottom_color = Color("6b7458")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("d8e0e0")
	environment.fog_density = 0.0005
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.far = 1500.0
	add_child(camera)
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.text = "A D bank  Ã‚Â·  W S pitch  Ã‚Â·  mouse steers  Ã‚Â·  Space boost  Ã‚Â·  Shift brake  Ã‚Â·  Q E knife edge (twice: roll)  Ã‚Â·  R up again"
	_hint.position = Vector2(16.0,12.0)
	_hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	_hint.add_theme_constant_override("outline_size",4)
	layer.add_child(_hint)

## Flying from `at` on `heading`, at cruise, the chase camera behind it.
func launch(at: Vector3, heading: float) -> void:
	plane = SkyPlane.new()
	plane.use_flight_speed()
	plane.use_pace(FlightPace.speed(pace))
	plane.use_weight(weight)
	plane.floor_y = -40.0
	plane.water = Land.WATER_Y
	plane.ceiling_y = 400.0
	plane.stone = func(_p: Vector3) -> bool: return true
	plane.launch(at,heading,plane.cruise(),false)
	if figure == null:
		figure = PlaneFigure.new()
		figure.name = "Plane"
		add_child(figure)
	figure.reset(plane)
	ground_scale.reset(false)
	ground_scale.apply(figure)
	figure._mark.visible = false
	chase = GlideCamera.new()
	chase.framed = true
	chase.floor_at = func(p: Vector3) -> float: return maxf(land.height(p.x,p.z),Land.WATER_Y)
	chase.reset(plane,at+(-plane.forward()*GlideCamera.BACK.x+Vector3.UP*GlideCamera.UP.x)*ground_scale.size(),camera.fov)
	chase.linger = LOOK_LINGER
	chase.use_weight(FlightWeight.knobs(weight))
	chase.close_in = CLOSE_IN
	chase.close_down = CLOSE_DOWN
	chase.speed_fov = RUSH_FOV
	chase.size = ground_scale.size()
	chase.lift = ground_scale.lift()
	var span := WorldScale.TOY_SPAN*ground_scale.size()
	chase.near = span*GlideCamera.NEAR_SPANS
	chase.extent = span*0.5
	chase.cruise = plane.cruise()/float(plane.pace_scale)
	var view := get_viewport().get_visible_rect().size
	if view.y > 0.0: chase.aspect = view.x/view.y
	_frame(0.0)

func _physics_process(delta: float) -> void:
	if flight_ready and not scripted: tick(delta,_fly_input())

## One tick with `input` (the keys', or a driver's).
func tick(delta: float, input: Dictionary) -> void:
	var was: Vector3 = plane.position
	plane.step(delta,input,Callable(land,"ground"))
	if _space != null: RuinBump.bump(_space,plane,was)
	figure.update(delta,plane,0.0,Callable(land,"ground"),false)
	_frame(delta)
	if react != null: _react(delta)

func _frame(delta: float) -> void:
	if not scripted:
		var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
		if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*maxf(delta,0.0))
		chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	chase.step(delta,plane,0.0,_solid)
	var way := chase.look-chase.eye
	if way.length() < 0.01: way = plane.forward()
	camera.global_transform = Transform3D(Basis.looking_at(way,Vector3.UP),chase.eye)
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

## Under the land or the water, for the camera to keep out of.
func _solid(p: Vector3) -> bool:
	return p.y < maxf(land.height(p.x,p.z),Land.WATER_Y)+0.3

## The prop's wash on the grass (GrassReact `step`), as endless flight's.
func _react(delta: float) -> void:
	var p: Vector3 = plane.position
	var h := land.height(p.x,p.z)
	var over := p.y-h if h > Land.WATER_Y else NAN
	var thrust := float(plane.engine)*clampf(0.6+0.4*float(plane.throttle),0.35,1.0)
	var facing := -camera.global_basis.z
	react.step(delta,camera.global_position,
		{"position": p, "forward": plane.forward(), "over": over, "thrust": thrust, "size": ground_scale.size()},
		{"way": Vector2(1.0,0.3).normalized(), "travel": 0.0, "facing": Vector2(facing.x,facing.z)},
		Callable(self,"grass_at"))

## The land's height where grass grows, else NAN.
func grass_at(x: float, z: float) -> float:
	var h := land.height(x,z)
	return h if h > Land.WATER_Y+0.25 else NAN

func _fly_input() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),"roll":_roll_asked}
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	return input

func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

## Back up over the meadow's south end, heading north.
func respawn() -> void:
	launch(Vector3(_start.x,land.height(_start.x,_start.z)+_start.y,_start.z),_heading)

func _unhandled_input(event: InputEvent) -> void:
	if not flight_ready: return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_R: respawn()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
