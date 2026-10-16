extends Node3D
## The hall rise study (docs/design/hall-rise.md): the Sundered hall (the
## moments set piece, greybox) rising out of the cloud sea in a few big
## chunks, each whole, one after another (scripts/hall_rise.gd), to judge
## how it feels to watch: from an orbit or hover camera, a free camera, or
## the game's plane on its way in.
##
## The hall stands as the sky world stands it (turn 0, the cloud sea at
## SEA_Y as in the game), but low: its lowest stone RISE_CLEAR over the
## cloud top, so the breakthrough is close under the plane's line of sight
## (`--hall-y=20` stands it at the moments world's height, 125 m up). The
## plane flies as the game's does (scripts/sky_plane.gd, the chase camera,
## the ruins' bump: scripts/ruin_bump.gd).
##
##   R              play the rise again (Shift+R: build it again too)
##   Enter          every chunk in place at once
##   C              camera: orbit, free, the plane (F: into the plane and out)
##   [ ]            slower, quicker (0.25x to 2x; \ back to 1x)
##   O              orbit: turn by itself or hold (a hover)
##   M              the moments (gold) and the line (white dots) on or off
##   Orbit: drag with the left mouse, the wheel zooms. Free: hold the right
##   mouse to look, W A S D, Q E down and up, Shift quick. Plane: as the
##   game's (the hint on screen). Esc frees the mouse.
##
##   ./run-hall-rise.command [--watch=plane] [--rise-speed=7] ...
##   godot --path . res://studies/hall_rise.tscn -- --no-title [flags]
## Flags: --watch=orbit|free|plane (the camera to start in), --wait (don't
## start till R), --loop=<s> (again this long after each one settles),
## --rise=<m> (the hall's lowest stone over the cloud top: the rise is this
## plus the chunk's height plus `under`), --hall-y=<m> (the entry's height
## over home instead), and the rise's own (scripts/hall_rise.gd `options`):
## --rise-speed=<m/s>, --chunk-gap=<s>, --rise-ease=<m>, --rise-over=<m>,
## --rise-settle=<s>, --rise-from=apse|gate, --keels, --stones,
## --build-upfront=<s>, --build-cost=<s>.
## Stills (opens a window; local only, captures/ is ignored): --capture=<dir>
## [--capture-at=0.5,2,4,...] (rise seconds) [--orbit-yaw=<rad>]
## [--orbit-dist=<m>] [--orbit-pitch=<rad>] [--hover]: saves a still at each
## time from the camera it starts in and quits.

const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
## The toy plane's span and the game's sizes (scripts/world_scale.gd).
const WorldScale = preload("res://scripts/world_scale.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Pad = preload("res://scripts/pad.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SEA := preload("res://shaders/hall_rise_sea.gdshader")

## The cloud sea's base (the game's: scripts/sky_flight.gd SEA_Y), and how
## far (m) the hall's lowest stone stands over the cloud top by default.
const SEA_Y := -105.0
const RISE_CLEAR := 14.0
## The rise's cloud top sits this far over the sea mesh's base (its
## heaps rise to the shader's `heap`).
const SEA_TOP := 3.0
## The plane starts this far out on the hall's way in, this far up.
const PLANE_OUT := 260.0
const PLANE_UP := 8.0
## The orbit camera: distance (m), its pitch (rad, down), turn rate.
const ORBIT := Vector3(190.0,0.26,0.07)
const ORBIT_ZOOM := Vector2(40.0,600.0)
const FREE_SPEED := Vector2(30.0,120.0)
const LOOK := 0.0025
const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
const SPEEDS := [0.25,0.5,0.75,1.0,1.25,1.5,2.0]
const PLANE_HINT := "Plane  ·  %.0f m/s  ·  bumps %d  ·  A D bank  ·  W S pitch  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  hold Q E knife edge  ·  F out"

## Set by tests: nothing waits on the mouse, nothing plays by itself.
var scripted := false
var rise: Node3D
var camera: Camera3D
var mode := "orbit"
var auto_turn := true
var orbit_yaw := 0.6
var orbit_pitch := ORBIT.y
var orbit_dist := ORBIT.x
var free_at := Vector3(0.0,30.0,120.0)
var free_yaw := 0.0
var free_pitch := -0.15
var time_scale := 1.0
var loop := -1.0
var _loop_left := -1.0
var plane: RefCounted
var figure: Node3D
var chase := GlideCamera.new()
var bumps := 0
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := 0
var _sea: MeshInstance3D
var _hud: Label
var _keys: Label
var _marks: Node3D
var _dragging := false
var _opts := {}
var _hall_y := NAN
var _clear := RISE_CLEAR
var _capture := ""
var _capture_at: Array = [0.5,1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.5,9.5,10.5,11.5,13.0]

func _ready() -> void:
	Pad.ensure()
	var args := LaunchArgs.user_args()
	_opts = Rise.options(args)
	var wait := false
	for a: String in args:
		if a.begins_with("--watch=") and a.get_slice("=",1) in ["orbit","free","plane"]: mode = a.get_slice("=",1)
		elif a == "--wait": wait = true
		elif a.begins_with("--loop="): loop = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--hall-y="): _hall_y = float(a.get_slice("=",1))
		elif a.begins_with("--rise="): _clear = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--capture="): _capture = a.get_slice("=",1)
		elif a.begins_with("--capture-at="):
			_capture_at = []
			for t: String in a.get_slice("=",1).split(","): _capture_at.append(float(t))
		elif a.begins_with("--orbit-yaw="): orbit_yaw = float(a.get_slice("=",1))
		elif a.begins_with("--orbit-dist="): orbit_dist = float(a.get_slice("=",1))
		elif a.begins_with("--orbit-pitch="): orbit_pitch = float(a.get_slice("=",1))
		elif a == "--hover": auto_turn = false
	_build_light()
	_build_sea()
	if is_nan(_hall_y): _hall_y = hall_y_for(_clear,_opts)
	rise = Rise.new()
	rise.position = Vector3(0.0,_hall_y,0.0)
	rise.sea_y = SEA_Y+SEA_TOP-_hall_y
	rise.plane_box = _plane_box
	add_child(rise)
	rise.setup(_opts)
	rise.finished.connect(_on_finished)
	_build_marks()
	_build_ui()
	var start_mode := mode
	mode = "orbit"
	if start_mode == "plane": board()
	elif start_mode == "free": mode = "free"
	if not scripted and not wait: rise.play()
	if not scripted and get_tree().current_scene == self and mode != "orbit": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("hall rise: %d chunks, %.1f s planned, the entry %.1f m over home, the cloud top %.1f m under it (the build on a worker)" % [rise.chunks.size(),float(rise.plan.length),_hall_y,-rise.sea_y])
	if _capture != "": _take_captures()

## The entry's height over home that stands the hall's lowest stone `clear`
## m over the cloud top.
static func hall_y_for(clear: float, opts: Dictionary) -> float:
	var lowest := INF
	for c: Dictionary in RisePlan.make(opts).chunks: lowest = minf(lowest,float(c.lo.y))
	return SEA_Y+SEA_TOP+clear-lowest

## Stills at each of `_capture_at` (rise seconds), then quits.
func _take_captures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://"+_capture) if not _capture.begins_with("/") else _capture)
	var dir := ProjectSettings.globalize_path("res://"+_capture) if not _capture.begins_with("/") else _capture
	for k in range(_capture_at.size()):
		while float(rise.clock) < float(_capture_at[k]) and (float(rise.done_at) < 0.0 or float(rise.clock) < float(_capture_at[k])):
			await get_tree().process_frame
			if float(rise.done_at) >= 0.0 and float(rise.clock) < float(_capture_at[k]): rise.clock += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%02d_%s_t%04.1f.png" % [dir,k,mode,float(rise.clock)]
		image.save_png(path)
		print("capture: ",path)
	get_tree().quit()

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5f93c9")
	sky.sky_horizon_color = Color("dce7ee")
	sky.ground_bottom_color = Color("b9c4d2")
	sky.ground_horizon_color = Color("dce7ee")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("dce7ee")
	environment.fog_density = 0.00035
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.far = 5000.0
	add_child(camera)
	camera.current = true

## The cloud sea: an opaque floor of heaps that follows the eye.
func _build_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(5000.0,5000.0)
	mesh.subdivide_width = 260
	mesh.subdivide_depth = 260
	var m := ShaderMaterial.new()
	m.shader = SEA
	mesh.material = m
	_sea = MeshInstance3D.new()
	_sea.name = "CloudSea"
	_sea.mesh = mesh
	_sea.position = Vector3(0.0,SEA_Y,0.0)
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea.custom_aabb = AABB(Vector3(-2500,-5,-2500),Vector3(5000,20,5000))
	add_child(_sea)

## The moments (gold) and the natural line (white dots), to see that they
## still fit; shown once the hall has settled.
func _build_marks() -> void:
	_marks = Node3D.new()
	_marks.name = "Marks"
	_marks.visible = false
	rise.add_child(_marks)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0,0.82,0.3)
	gold.emission_enabled = true
	gold.emission = Color(1.0,0.82,0.3)
	gold.emission_energy_multiplier = 0.8
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(1,1,1,0.8)
	for m: Dictionary in Plan.moments(RisePlan.LAYOUT):
		_ball(m.at,0.6,gold)
	for p: Vector3 in Plan.line(RisePlan.LAYOUT): _ball(p,0.18,white)

func _ball(at: Vector3, r: float, mat: Material) -> void:
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r*2.0
	ball.mesh = s
	ball.material_override = mat
	ball.position = at
	_marks.add_child(ball)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16,12)
	_keys = Label.new()
	_keys.anchor_top = 1.0
	_keys.anchor_bottom = 1.0
	_keys.position = Vector2(16,-64)
	for l: Label in [_hud,_keys]:
		l.add_theme_font_size_override("font_size",16)
		l.add_theme_color_override("font_color",Color(0.08,0.09,0.12))
		l.add_theme_color_override("font_outline_color",Color(1,1,1,0.85))
		l.add_theme_constant_override("outline_size",6)
		layer.add_child(l)
	_keys.text = "R again (Shift+R rebuilt)  ·  Enter all in place  ·  C camera  ·  F plane  ·  [ ] slower quicker  ·  O orbit turns/holds  ·  M moments  ·  Esc mouse"

func _physics_process(delta: float) -> void:
	tick(delta)

func _process(delta: float) -> void:
	if mode == "free": _free_move(delta)

## One frame: the rise (at the study's speed), the plane, the camera.
func tick(delta: float) -> void:
	rise.advance(delta*time_scale)
	if _loop_left >= 0.0:
		_loop_left -= delta
		if _loop_left < 0.0: replay()
	if mode == "plane": _fly(delta)
	elif mode == "orbit": _orbit(delta)
	_sea.position = Vector3(snappedf(camera.global_position.x,20.0),SEA_Y,snappedf(camera.global_position.z,20.0))
	_swell_sea()
	_show_hud()

## The sea heaves where a chunk is about to break through (world metres).
func _swell_sea() -> void:
	var s: Array[Vector4] = rise.swells()
	var out := []
	for v: Vector4 in s:
		var w: Vector3 = rise.to_global(Vector3(v.x,0.0,v.y))
		out.append(Vector4(w.x,w.z,v.z,v.w))
	while out.size() < Rise.SWELLS: out.append(Vector4.ZERO)
	var m := (_sea.mesh as PrimitiveMesh).material as ShaderMaterial
	m.set_shader_parameter("swells",out)
	m.set_shader_parameter("swell_count",s.size())

func replay(rebuild := false) -> void:
	_loop_left = -1.0
	_marks.visible = false
	if rebuild: rise.setup(_opts)
	rise.play()

func _on_finished() -> void:
	_marks.visible = _marks.get_meta(&"wanted",true)
	if loop >= 0.0: _loop_left = loop

func _show_hud() -> void:
	var g: Dictionary = rise.progress()
	var build := "build %d/%d" % [g.built,g.total]
	if float(g.build) >= 0.0: build += " in %.2f s (first %.2f s)" % [g.build,g.first]
	var line := "Hall rise  ·  %.1f / %.1f s  ·  risen %d/%d  ·  still %d  ·  %s  ·  %s" % [g.clock,g.length,g.risen,g.total,g.set,g.chunk,build]
	if float(g.stall) > 0.0: line += "  ·  held %.2f s for the build" % g.stall
	if bool(g.waiting): line += "  ·  WAITING ON THE BUILD"
	if float(g.done) >= 0.0: line += "  ·  settled at %.1f s" % g.done
	line += "\nCamera: %s%s  ·  speed %.2fx" % [mode,(" (turning)" if auto_turn else " (hover)") if mode == "orbit" else "",time_scale]
	if mode == "plane": line += "\n"+PLANE_HINT % [float(plane.speed),bumps]
	_hud.text = line

# --- Cameras -------------------------------------------------------------------------

## The hall's middle (world): the orbit's centre.
func centre() -> Vector3:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for c: Dictionary in rise.chunks:
		if c.id == "stones": continue
		lo = lo.min(c.lo)
		hi = hi.max(c.hi)
	return rise.to_global((lo+hi)*0.5)

func _orbit(delta: float) -> void:
	if auto_turn and not _dragging: orbit_yaw += ORBIT.z*delta
	var c := centre()
	var eye := c+Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_dist
	camera.global_transform = Transform3D(Basis.looking_at(c-eye,Vector3.UP),eye)
	camera.fov = GlideCamera.FOV

func _free_move(delta: float) -> void:
	var way := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): way.z -= 1.0
	if Input.is_key_pressed(KEY_S): way.z += 1.0
	if Input.is_key_pressed(KEY_A): way.x -= 1.0
	if Input.is_key_pressed(KEY_D): way.x += 1.0
	if Input.is_key_pressed(KEY_E): way.y += 1.0
	if Input.is_key_pressed(KEY_Q): way.y -= 1.0
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	way += Vector3(stick.x,0.0,stick.y)
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	free_yaw -= right.x*STICK_LOOK*delta
	free_pitch = clampf(free_pitch-right.y*STICK_LOOK*delta,-1.4,1.4)
	var basis := Basis(Vector3.UP,free_yaw)*Basis(Vector3.RIGHT,free_pitch)
	var speed := FREE_SPEED.y if Input.is_key_pressed(KEY_SHIFT) else FREE_SPEED.x
	free_at += basis*way*speed*delta
	camera.global_transform = Transform3D(basis,free_at)
	camera.fov = GlideCamera.FOV

func cycle_camera() -> void:
	match mode:
		"orbit":
			free_at = camera.global_position
			var f := -camera.global_basis.z
			free_yaw = atan2(-f.x,-f.z)
			free_pitch = asin(clampf(f.y,-1.0,1.0))
			mode = "free"
		"free": board()
		"plane": leave()

# --- The plane -----------------------------------------------------------------------

## Into the plane, PLANE_OUT m out on the hall's way in, flying at it.
func board() -> void:
	plane = SkyPlane.new()
	plane.floor_y = SEA_Y
	plane.launch(Vector3(0.0,_hall_y+PLANE_UP,PLANE_OUT),0.0,SkyPlane.CRUISE_SPEED,false)
	if figure == null:
		figure = PlaneFigure.new()
		figure.name = "Plane"
		add_child(figure)
	figure.visible = true
	figure.reset(plane)
	figure._mark.visible = false
	chase = GlideCamera.new()
	chase.reset(plane,plane.position-plane.forward()*6.0+Vector3.UP*2.0,camera.fov)
	bumps = 0
	mode = "plane"
	if not scripted: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func leave() -> void:
	mode = "orbit"
	if figure != null: figure.visible = false
	plane = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## The plane's box in the rise's frame (none out of the plane).
func _plane_box() -> AABB:
	if plane == null or mode != "plane": return AABB()
	var half := Vector3.ONE*(WorldScale.TOY_SPAN*0.5+0.3)
	return AABB(rise.to_local(plane.position)-half,half*2.0)

func plane_ground(_p: Vector3) -> Variant:
	return SEA_Y

func _fly(delta: float) -> void:
	var input := _fly_input(delta)
	var was: Vector3 = plane.position
	plane.step(delta,input,plane_ground)
	if RuinBump.bump(get_world_3d().direct_space_state,plane,was): bumps += 1
	figure.update(delta,plane,0.0,plane_ground,false)
	figure._mark.visible = false
	chase.step(delta,plane,0.0,_inside_stone)
	camera.global_transform = Transform3D(Basis.looking_at(chase.look-chase.eye,Vector3.UP),chase.eye)
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

func _inside_stone(p: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = p
	query.collision_mask = RuinBump.LAYER
	return not get_world_3d().direct_space_state.intersect_point(query,1).is_empty()

func _fly_input(delta: float) -> Dictionary:
	if scripted: return {}
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*delta)
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
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

# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_R:
				replay((event as InputEventKey).shift_pressed)
				return
			KEY_ENTER, KEY_KP_ENTER:
				rise.finish_now()
				_on_finished()
				return
			KEY_C:
				cycle_camera()
				return
			KEY_F:
				if mode == "plane": leave()
				else: board()
				return
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				var at := SPEEDS.find(time_scale)
				if at < 0: at = 3
				at = clampi(at+(1 if key == KEY_BRACKETRIGHT else -1),0,SPEEDS.size()-1)
				time_scale = SPEEDS[at]
				return
			KEY_BACKSLASH:
				time_scale = 1.0
				return
			KEY_O:
				auto_turn = not auto_turn
				return
			KEY_M:
				var wanted := not bool(_marks.get_meta(&"wanted",true))
				_marks.set_meta(&"wanted",wanted)
				_marks.visible = wanted and float(rise.done_at) >= 0.0
				return
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				return
			KEY_Q:
				if mode == "plane": _lean_tapped(-1.0)
			KEY_E:
				if mode == "plane": _lean_tapped(1.0)
	if mode == "plane":
		if Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
		elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
		elif Pad.pressed(event,&"fly_land"): leave()
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
			else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif mode == "orbit":
		if event is InputEventMouseButton:
			var b := event as InputEventMouseButton
			if b.button_index == MOUSE_BUTTON_LEFT: _dragging = b.pressed
			elif b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed: orbit_dist = clampf(orbit_dist*0.9,ORBIT_ZOOM.x,ORBIT_ZOOM.y)
			elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed: orbit_dist = clampf(orbit_dist/0.9,ORBIT_ZOOM.x,ORBIT_ZOOM.y)
		elif event is InputEventMouseMotion and _dragging:
			orbit_yaw -= event.relative.x*LOOK
			orbit_pitch = clampf(orbit_pitch+event.relative.y*LOOK,-0.2,1.3)
	elif mode == "free":
		if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
			free_yaw -= event.relative.x*LOOK
			free_pitch = clampf(free_pitch-event.relative.y*LOOK,-1.4,1.4)
