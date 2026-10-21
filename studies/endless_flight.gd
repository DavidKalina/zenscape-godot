extends Node3D
## Endless flight, round 1 (docs/design/endless-flight/round-1-handoff.md):
## the game's plane over endless streamed land. It starts in the air, in
## the plane the aqueduct isle flies (scripts/sky_plane.gd at the game's
## speed, the hand landing scripts/manual_landing.gd, the figure scripts/
## plane_figure.gd and its ground scale, the chase camera scripts/
## glide_camera.gd), flown by the same keys, mouse and pad. Under it the
## land streams in chunks round the camera (scripts/endless/land_stream.gd
## over scripts/endless/land_field.gd): rolling hills, a few mountains,
## coast and sea, and broad flat meadows to put it down on. Land on the
## turf as on the isle; stopped, Space (Boost) rolls it off again. Getting
## out comes in a later round.
##
## Keys: WASD or the left stick bank and pitch (W nose down), the mouse
## steers, Space boost, Shift brake, Q E held knife edge (twice quick a
## barrel roll, or click), F flaps, hold right mouse to look round, F1 the
## numbers, R back up into the air over where it is, Esc lets the mouse go.
##
##   ./run-endless-flight.command [--seed=7]
##   godot --path . res://studies/endless_flight.tscn -- --no-title [--seed=7] [--at=x,z] [--heading=deg] [--alt=m]
##
## Flags: --seed=N the land (1), --at=x,z where it starts (0,0),
## --heading=deg clockwise from -z (0; `sun` toward the sun), --alt=m over
## the ground (45), --numbers opens with F1's numbers shown, --uncapped
## turns vsync and the frame cap off (the fps is then the frame's cost).
## The look (scripts/endless/endless_look.gd): --mood=ID one of its
## moods (alpine_morning), --hour=H the sun's hour (the mood's), --day the
## hour runs, --plain-look round one's plain sky and colours; T steps to the
## next quarter of the day, L to the next mood. The clouds (scripts/endless/
## endless_clouds.gd): --no-clouds, --cloud-cover=X (1); C turns them off
## and on. The grass carpet (scripts/endless/endless_grass.gd): --no-grass,
## --grass=X (its density, 1), --grass-range=M (how far the tufts reach,
## 230), --grass-lod=x,y,z,w (its rings, 16,30,150,230), --no-flowers,
## --grass-fine=X (the near ring's fine tuft at X of the isle's density,
## 1.2; 0: the isle's own tuft), --grass-patches=X (how much of the ground's
## patches the tufts carry, 1), --grass-set= / --far-set= / --ground-set=
## name=value (a shader setting, for tuning by hand), --flower-drifts=X
## (how many flower drifts, 1; 0 or --no-drifts: round 4's), --grass-regions=X
## (how strongly the grass's colour regions show, 1; 0 or --no-regions:
## one palette); G turns it off and on.

const Field = preload("res://scripts/endless/land_field.gd")
const LandStream = preload("res://scripts/endless/land_stream.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Pad = preload("res://scripts/pad.gd")
const EndlessLook = preload("res://scripts/endless/endless_look.gd")
const EndlessGrass = preload("res://scripts/endless/endless_grass.gd")

const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
const LOOK_LINGER := 2.5
## The sky and the haze: the fog thickens from FOG_BEGIN m to FOG_END m,
## inside the land's far edge (LandStream ROOT_REACH root chunks out).
const HORIZON := Color("cfdde6")
const FOG_BEGIN := 900.0
const FOG_END := 7000.0
const FOG_DENSITY := 0.00028
const SEA_COLOUR := Color("2f6f8f")
const SEA_SIZE := 40000.0
## The plane's start over the ground (m), and the eye's clearance over it.
const START_ALT := 45.0
const EYE_CLEAR := 0.6

## True once the land under the start stands and it flies (the harness
## waits on it: tools/harness/drive.gd `open`).
var walk_ready := false
var seed := 1
var land: Node3D
var field: RefCounted
var camera: Camera3D
var plane: RefCounted
var plane_figure: Node3D
var chase: RefCounted
var hand_landing := ManualLanding.new()
var ground_scale := PlaneGroundScale.new()
var flaps := false
var sea: MeshInstance3D
## The look (sky, light, haze, ground, sea), or null under --plain-look.
var look: Node3D
## The grass carpet round the eye (off at the start under --no-grass), or
## null under --plain-look.
var grass: Node3D
var flown := 0.0
var _start := Vector2.ZERO
var _heading := 0.0
var _face_sun := false
var _numbers := false
var _alt := START_ALT
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := -100000
var _hud: Label
var _hint: Label

func _ready() -> void:
	Pad.ensure()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--seed="): seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--at="):
			var p := arg.get_slice("=",1).split(",")
			if p.size() >= 2: _start = Vector2(float(p[0]),float(p[1]))
		elif arg == "--heading=sun": _face_sun = true
		elif arg.begins_with("--heading="): _heading = -deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--alt="): _alt = float(arg.get_slice("=",1))
		elif arg == "--numbers": _numbers = true
		elif arg == "--uncapped":
			# No vsync and no cap, so the numbers' fps is the frame's cost.
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
	field = Field.new(seed)
	if EndlessLook.wanted():
		look = EndlessLook.new()
		add_child(look)
		look.setup(seed)
		sea = look.sea
		_build_camera()
		if _face_sun:
			var s: Vector3 = look.celestial.state.zs_sun_direction
			_heading = atan2(-s.x,-s.z)
	else:
		_build_light()
		_build_sea()
	land = LandStream.new()
	land.name = "Land"
	add_child(land)
	land.setup(seed,look.ground if look != null else null)
	if look != null:
		grass = EndlessGrass.new()
		grass.setup(seed,look.ground)
		add_child(grass)
		grass.set_enabled(EndlessGrass.wanted())
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	_build_ui()
	_hud.visible = _numbers
	# The land round the start first, so it starts over ground that stands.
	var eye := Vector3(_start.x,_start_height(),_start.y)
	camera.global_position = eye
	var took: float = land.prime(eye)
	_launch(Vector3(_start.x,_start_height(),_start.y),_heading)
	if grass != null and grass.enabled: grass.prime(camera.global_position)
	walk_ready = true
	print("endless flight: seed %d, the land stood in %.2f s (%d chunks)" % [seed,took,int(land.counts().standing)])
	if get_tree().current_scene == self and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _start_height() -> float:
	return maxf(field.height(_start.x,_start.y),Field.SEA_Y)+_alt

# --- The world ------------------------------------------------------------------------

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5d8fc4")
	sky.sky_horizon_color = HORIZON
	sky.ground_bottom_color = Color("6f8a99")
	sky.ground_horizon_color = HORIZON
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = HORIZON
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.6
	# The Compatibility renderer has no depth fog: its exponential fog's
	# density, thin enough to read the far land.
	environment.fog_density = FOG_DENSITY
	environment.fog_aerial_perspective = 0.5
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	_build_camera()

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.near = 0.1
	# With the look, the haze is all sky by its end: nothing past it shows,
	# and the aerial perspective reads the sharp sky there (Godot picks the
	# radiance's blur by depth over the far plane).
	camera.far = EndlessLook.FOG_END*1.04 if look != null else FOG_END*2.2
	add_child(camera)
	camera.current = true

## The sea: one wide sheet at sea level that follows the eye.
func _build_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SEA_SIZE,SEA_SIZE)
	var m := StandardMaterial3D.new()
	m.albedo_color = SEA_COLOUR
	m.roughness = 0.12
	m.metallic_specular = 0.7
	mesh.material = m
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = mesh
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position.y = Field.SEA_Y
	add_child(sea)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16,12)
	_hud.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_hud.add_theme_constant_override("outline_size",4)
	_hud.visible = false
	layer.add_child(_hud)
	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -40.0
	_hint.offset_left = 16.0
	_hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_hint.add_theme_constant_override("outline_size",4)
	_hint.text = "A D bank  ·  W S pitch  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  Q E knife edge (twice: roll)  ·  F flaps  ·  land on the meadows  ·  R up again  ·  C clouds  ·  G grass  ·  F1 numbers"
	layer.add_child(_hint)

# --- The plane ------------------------------------------------------------------------

## Flying from `at` on `heading`, at cruise, the chase camera behind it.
func _launch(at: Vector3, heading: float) -> void:
	plane = SkyPlane.new()
	plane.use_game_speed()
	plane.floor_y = Field.SEA_Y-15.0
	plane.water = Field.SEA_Y
	# The land is a heightfield: it rides up what is no cliff, and a
	# cliff's face turns it aside (SkyGlide `stone`).
	plane.stone = func(_p: Vector3) -> bool: return true
	plane.launch(at,heading,plane.cruise(),false)
	hand_landing.begin(plane)
	if plane_figure == null:
		plane_figure = PlaneFigure.new()
		plane_figure.name = "Plane"
		add_child(plane_figure)
	plane_figure.show_pilot(true)
	plane_figure.reset(plane)
	ground_scale.reset(false)
	ground_scale.apply(plane_figure)
	plane_figure._mark.visible = false
	flaps = false
	chase = GlideCamera.new()
	chase.framed = true
	chase.sight = _sight
	chase.reset(plane,at+(-plane.forward()*GlideCamera.BACK.x+Vector3.UP*GlideCamera.UP.x)*ground_scale.size(),camera.fov)
	chase.linger = LOOK_LINGER
	_size_chase()
	_frame(0.0)

func _size_chase() -> void:
	chase.size = ground_scale.size()
	chase.lift = ground_scale.lift()
	var span := WorldScale.TOY_SPAN*ground_scale.size()
	chase.near = span*GlideCamera.NEAR_SPANS
	chase.extent = span*0.5
	chase.cruise = plane.cruise()
	var view := get_viewport().get_visible_rect().size
	if view.y > 0.0: chase.aspect = view.x/view.y

## The land's height under a point, for the flight (SkyGlide `step`).
func plane_ground(p: Vector3) -> Variant:
	return field.height(p.x,p.z)

## The turf under the wheels at a world XZ point; NAN over the sea.
func floor_at(p: Vector2) -> float:
	var h: float = field.height(p.x,p.y)
	return NAN if h < Field.SEA_Y+0.2 else h

## Inside the land or the sea, for the camera to keep out of.
func _solid(p: Vector3) -> bool:
	return p.y < maxf(field.height(p.x,p.z),Field.SEA_Y)+EYE_CLEAR*0.5

## The share of the way from `from` to `to` clear of the land (GlideCamera
## `sight`), marched over the field.
func _sight(from: Vector3, to: Vector3) -> float:
	const STEPS := 10
	for i in range(1,STEPS+1):
		var t := float(i)/STEPS
		var p := from.lerp(to,t)
		if p.y < field.height(p.x,p.z): return float(i-1)/STEPS
	return 1.0

func _process(delta: float) -> void:
	if not walk_ready: return
	tick(minf(delta,1.0/20.0))

## One frame: the plane flown, drawn and followed, the land streamed round
## the eye, the sea under it.
func tick(delta: float) -> void:
	flown += delta
	var input := _fly_input(delta)
	input["flaps"] = 1.0 if flaps else 0.0
	hand_landing.step(delta,input,Callable(self,"plane_ground"),Callable(self,"floor_at"))
	plane.engine = hand_landing.engine*float(plane.sputter)
	var ground := Callable(self,"plane_ground")
	plane_figure.update(delta,plane,0.0,ground,hand_landing.would_grease(Callable(self,"floor_at")))
	ground_scale.step(delta,hand_landing.on_ground(),hand_landing.dipping(),plane)
	ground_scale.apply(plane_figure)
	plane_figure._mark.visible = false
	_size_chase()
	chase.cine = Vector3(-1.25,0.0,0.3) if hand_landing.on_ground() else Vector3.ZERO
	_frame(delta)
	land.step(camera.global_position)
	if grass != null:
		var view := get_viewport().get_camera_3d()
		grass.step((view if view != null else camera).global_position)
	if look != null: look.step(delta,camera.global_position,-camera.global_basis.z,camera)
	else: sea.position = Vector3(snappedf(camera.global_position.x,64.0),Field.SEA_Y,snappedf(camera.global_position.z,64.0))
	_show_hud()

func _frame(delta: float) -> void:
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*delta)
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	chase.step(delta,plane,0.0,_solid)
	camera.global_position = chase.eye
	var way: Vector3 = chase.look-chase.eye
	if way.length() < 0.01: way = plane.forward()
	camera.look_at(camera.global_position+way,Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD,chase.roll)
	camera.fov = chase.fov

## The plane's input, as the isle reads it (studies/kit_isle.gd `_fly_input`).
func _fly_input(_delta: float) -> Dictionary:
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

## Back up into the air over where it is, on the heading it had.
func respawn() -> void:
	var at: Vector3 = plane.position
	_start = Vector2(at.x,at.z)
	_launch(Vector3(at.x,_start_height(),at.z),float(plane.heading))

func _unhandled_input(event: InputEvent) -> void:
	if not walk_ready: return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif Pad.pressed(event,&"fly_land"): flaps = not flaps
	elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F: flaps = not flaps
			KEY_F1: _hud.visible = not _hud.visible
			KEY_R: respawn()
			KEY_T:
				if look != null: look.next_hour()
			KEY_L:
				if look != null: look.next_mood()
			KEY_C:
				if look != null and look.clouds != null: look.clouds.set_enabled(not look.clouds.enabled)
			KEY_G:
				if grass != null: grass.set_enabled(not grass.enabled)
			KEY_Q: _lean_tapped(-1.0)
			KEY_E: _lean_tapped(1.0)
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _cloud_note() -> String:
	if look.clouds == null: return "  ·  no clouds"
	if not look.clouds.enabled: return "  ·  clouds off (C)"
	return "  ·  in cloud" if look.clouds.in_cloud(camera.global_position) else ""

func _show_hud() -> void:
	if not _hud.visible: return
	var p: Vector3 = plane.position
	var c: Dictionary = land.counts()
	var s: Dictionary = land.stats
	# The GPU's own time, where the driver reports it (not on Metal).
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_hud.text = "seed %d  ·  %s  ·  %.1f m/s  ·  %.0f m over the ground  ·  flaps %s\nat %.0f, %.0f  ·  %d fps (%.1f ms)%s%s\nland: %d drawn, %d standing, %d wanted, %d building, %d queued, %d colliders\nbuilt %d (%.1f ms each on a worker), slowest commit %.2f ms%s" % [
		seed,ManualLanding.NAMES[hand_landing.phase],float(plane.speed),p.y-maxf(field.height(p.x,p.z),Field.SEA_Y),"down" if flaps else "up",
		p.x,p.z,Engine.get_frames_per_second(),1000.0/maxf(Engine.get_frames_per_second(),1.0),
		("  ·  gpu %.2f ms" % gpu) if gpu > 0.0 else "",
		("  ·  %s, %05.2f h%s" % [look.mood_title(),look.hour(),_cloud_note()]) if look != null else "",
		int(c.drawn),int(c.standing),int(c.wanted),int(c.in_flight),int(c.queued),int(c.colliders),
		int(s.built),float(s.build_ms)/maxf(float(s.built),1.0),float(s.slowest_commit_ms),_grass_note()]

func _grass_note() -> String:
	if grass == null: return ""
	if not grass.enabled: return "\ngrass off (G)"
	var g: Dictionary = grass.counts()
	var gs: Dictionary = grass.stats
	return "\ngrass: %d cells, %d building, %d queued, %dk plants  ·  %.0f ms a cell on a worker, slowest stand %.2f ms" % [
		int(g.cells),int(g.building),int(g.queued),int(g.instances)/1000,float(gs.grow_ms)/maxf(float(gs.grown),1.0),float(gs.slowest_stand_ms)]
