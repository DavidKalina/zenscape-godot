extends Node3D
## The hall chain study (docs/design/hall-chain.md): the hall rise study's
## Sundered hall (greybox) rising out of the cloud sea, then, once the plane
## is far enough along it, the next one rising ahead off its exit, and the
## next, for as long as you fly (scripts/hall_chain.gd). Past a cap the
## oldest sinks back into the cloud.
##
## It starts in the plane, 170 m out on the first hall's way in, the first
## hall rising. Fly the line through it and out of the apse: the next hall
## (mirrored, so it swings you back the other way) is coming up out of the
## cloud dead ahead, and a short straight run carries you into its gate.
##
##   R              the chain again from the first hall (Shift+R: a new seed)
##   N              set the next hall rising now
##   P              autopilot on or off (flies the route; any stick takes over)
##   Enter          every hall up now in place at once
##   C              camera: plane, orbit (the newest hall), free (F: plane in or out)
##   [ ]            slower, quicker (0.25x to 2x; \ back to 1x)
##   O              orbit: turn by itself or hold
##   M              the route (white dots) and the trigger spots (gold) on or off
##   Esc            frees the mouse
##
##   ./run-hall-chain.command [--chain-at=0.4] [--chain-gap=70] ...
##   godot --path . res://studies/hall_chain.tscn -- --no-title [flags]
## Flags: --watch=plane|orbit|free (the camera to start in, plane), --autopilot,
## --rise=<m> (the first hall's lowest stone over the cloud top, 14), the
## chain's (scripts/hall_chain.gd `options`): --chain-at=<0-1>,
## --chain-gap=<m>, --chain-turn=<deg>, --chain-climb=<m>, --chain-keep=<n>,
## --chain-seed=<n>, --chain-mirror=on|off, and the rise's (scripts/hall_rise.gd `options`).
## Stills (opens a window; local only, captures/ is ignored): --capture=<dir>
## [--capture-at=2,6,...] (study seconds): a still at each, then it quits.

const Chain = preload("res://scripts/hall_chain.gd")
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const Rise = preload("res://scripts/hall_rise.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
## The toy plane's span and the game's sizes (scripts/world_scale.gd).
const WorldScale = preload("res://scripts/world_scale.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Pad = preload("res://scripts/pad.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SEA := preload("res://shaders/hall_rise_sea.gdshader")

## The cloud sea's base (the game's, as the hall rise study), its top over
## that, the first hall's lowest stone over the top.
const SEA_Y := -105.0
const SEA_TOP := 3.0
const RISE_CLEAR := 14.0
## The plane starts this far (m) before the first hall's way in, this far up.
const PLANE_OUT := 170.0
const PLANE_UP := 2.0
## F into the plane with the newest hall up: this far before its way in.
const BOARD_OUT := 60.0
const ORBIT := Vector3(220.0,0.3,0.07)
const ORBIT_ZOOM := Vector2(40.0,900.0)
const FREE_SPEED := Vector2(30.0,120.0)
const LOOK := 0.0025
const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
## Mouse look over this (rad a frame, about 12 pixels) takes over from the
## autopilot.
const AUTO_LOOK := 0.03
const SPEEDS := [0.25,0.5,0.75,1.0,1.25,1.5,2.0]
const PLANE_HINT := "Plane  ·  %.0f m/s  ·  bumps %d  ·  A D bank  ·  W S pitch  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  hold Q E knife edge  ·  P autopilot%s  ·  F out"

## Set by tests: nothing waits on the mouse.
var scripted := false
var chain: Node3D
var camera: Camera3D
var mode := "plane"
var auto_turn := true
var orbit_yaw := 0.6
var orbit_pitch := ORBIT.y
var orbit_dist := ORBIT.x
var free_at := Vector3(0.0,30.0,120.0)
var free_yaw := 0.0
var free_pitch := -0.15
var time_scale := 1.0
var plane: RefCounted
var figure: Node3D
var chase := GlideCamera.new()
var bumps := 0
var autopilot := false
var route_at := 0
var clock := 0.0
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := 0
var _sea: MeshInstance3D
var _hud: Label
var _keys: Label
var _marks: Node3D
var _marks_on := false
var _marked := -1
var _dragging := false
var _capture := ""
var _capture_at: Array = [2.0,5.0,9.0,13.0,18.0,22.0,26.0,30.0]

func _ready() -> void:
	Pad.ensure()
	var args := LaunchArgs.user_args()
	var rise_opts := Rise.options(args)
	var clear := RISE_CLEAR
	for a: String in args:
		if a.begins_with("--watch=") and a.get_slice("=",1) in ["orbit","free","plane"]: mode = a.get_slice("=",1)
		elif a == "--autopilot": autopilot = true
		elif a.begins_with("--rise="): clear = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--capture="): _capture = a.get_slice("=",1)
		elif a.begins_with("--capture-at="):
			_capture_at = []
			for t: String in a.get_slice("=",1).split(","): _capture_at.append(float(t))
		elif a.begins_with("--orbit-yaw="): orbit_yaw = float(a.get_slice("=",1))
		elif a.begins_with("--orbit-dist="): orbit_dist = float(a.get_slice("=",1))
		elif a.begins_with("--orbit-pitch="): orbit_pitch = float(a.get_slice("=",1))
	_build_light()
	_build_sea()
	chain = Chain.new()
	chain.sea_top = SEA_Y+SEA_TOP
	chain.clear = clear
	chain.plane_box = _plane_box
	add_child(chain)
	chain.configure(Chain.options(args),rise_opts)
	chain.reset()
	_marks = Node3D.new()
	_marks.name = "Marks"
	_marks.visible = false
	add_child(_marks)
	_build_ui()
	var start_mode := mode
	mode = "orbit"
	if start_mode == "plane": board(true)
	elif start_mode == "free": mode = "free"
	if not scripted and get_tree().current_scene == self and mode != "orbit": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("hall chain: next at %.0f%% of the line, gap %.0f m, turn +-%.0f deg, climb +-%.0f m, keep %d, seed %d" % [float(chain.cfg.at)*100.0,chain.cfg.gap,chain.cfg.turn,chain.cfg.climb,chain.cfg.keep,chain.cfg.seed])
	if _capture != "": _take_captures()

func _take_captures() -> void:
	var dir := ProjectSettings.globalize_path("res://"+_capture) if not _capture.begins_with("/") else _capture
	DirAccess.make_dir_recursive_absolute(dir)
	for k in range(_capture_at.size()):
		while clock < float(_capture_at[k]): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%02d_%s_t%04.1f.png" % [dir,k,mode,clock]
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

## The cloud sea: the hall rise study's, 5 km across and following the eye,
## so it covers the chain wherever it has got to.
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
	_keys.text = "R again (Shift+R new seed)  ·  N next hall now  ·  P autopilot  ·  Enter all in place  ·  C camera  ·  F plane  ·  [ ] slower quicker  ·  O orbit  ·  M route  ·  Esc mouse"

func _physics_process(delta: float) -> void:
	tick(delta)

func _process(delta: float) -> void:
	if mode == "free": _free_move(delta)

## One frame: the chain (at the study's speed), the plane, the camera.
func tick(delta: float) -> void:
	clock += delta
	chain.advance(delta*time_scale,plane.position if plane != null and mode == "plane" else null)
	if mode == "plane": _fly(delta)
	elif mode == "orbit": _orbit(delta)
	_sea.position = Vector3(snappedf(camera.global_position.x,20.0),SEA_Y,snappedf(camera.global_position.z,20.0))
	_swell_sea()
	if _marks_on and _marked != int(chain.made)+int(chain.route_base): _draw_marks()
	_show_hud()

func _swell_sea() -> void:
	var s: Array[Vector4] = chain.swells(camera.global_position)
	var out := []
	for v: Vector4 in s: out.append(v)
	while out.size() < Rise.SWELLS: out.append(Vector4.ZERO)
	var m := (_sea.mesh as PrimitiveMesh).material as ShaderMaterial
	m.set_shader_parameter("swells",out)
	m.set_shader_parameter("swell_count",s.size())

## The chain again from the first hall; the plane back at the start.
func replay(new_seed := false) -> void:
	chain.reset(int(chain.cfg.seed)+1 if new_seed else -1)
	route_at = 0
	if mode == "plane": board(true)

func _show_hud() -> void:
	var s: Dictionary = chain.status()
	var spawn: Dictionary = s.spawn
	var line := "Hall chain  ·  hall %d  ·  made %d  ·  standing %d  ·  sinking %d  ·  next at %.0f%%: %.0f%% along" % [int(s.newest)+1,s.made,s.standing,s.sinking,float(s.at)*100.0,float(s.progress)*100.0]
	if not spawn.is_empty(): line += "  ·  last spawn %.2f ms (worst frame %.2f ms)" % [float(spawn.total)/1000.0,maxf(float(spawn.setup),float(spawn.frame))/1000.0]
	var newest: Dictionary = chain.halls[-1] if not chain.halls.is_empty() else {}
	if not newest.is_empty():
		var g: Dictionary = newest.rise.progress()
		line += "\nNewest: %.1f / %.1f s  ·  risen %d/%d  ·  still %d" % [g.clock,g.length,g.risen,g.total,g.set]
		if bool(g.waiting): line += "  ·  WAITING ON THE BUILD"
	line += "\nCamera: %s  ·  speed %.2fx  ·  gap %.0f m  ·  turn +-%.0f°  ·  climb +-%.0f m  ·  keep %d  ·  seed %d" % [mode,time_scale,chain.cfg.gap,chain.cfg.turn,chain.cfg.climb,chain.cfg.keep,chain.cfg.seed]
	if mode == "plane": line += "\n"+PLANE_HINT % [float(plane.speed),bumps," ON" if autopilot else ""]
	_hud.text = line

## The route (white) and each hall's trigger spot (gold), redrawn as the
## chain grows.
func _draw_marks() -> void:
	_marked = int(chain.made)+int(chain.route_base)
	for c in _marks.get_children(): c.queue_free()
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(1,1,1,0.8)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0,0.82,0.3)
	gold.emission_enabled = true
	gold.emission = Color(1.0,0.82,0.3)
	var dot := SphereMesh.new()
	dot.radius = 0.25
	dot.height = 0.5
	for p: Vector3 in chain.route:
		var b := MeshInstance3D.new()
		b.mesh = dot
		b.material_override = white
		b.position = p
		_marks.add_child(b)
	var ball := SphereMesh.new()
	ball.radius = 1.2
	ball.height = 2.4
	for h: Dictionary in chain.halls:
		var b := MeshInstance3D.new()
		b.mesh = ball
		b.material_override = gold
		b.position = ChainPlan.xform(h.pose)*ChainPlan.local(trigger_point(),ChainPlan.hand_of(h.pose))
		_marks.add_child(b)

## The trigger spot on the hall's line (station metres): `at` of the way.
func trigger_point() -> Vector3:
	var l := ChainPlan.line()
	var want := float(chain.cfg.at)*ChainPlan.line_length()
	var run := 0.0
	for k in range(1,l.size()):
		var seg := l[k].distance_to(l[k-1])
		if run+seg >= want: return l[k-1].lerp(l[k],(want-run)/maxf(seg,1e-6))
		run += seg
	return l[-1]

# --- Cameras -------------------------------------------------------------------------

## The newest hall's middle (world): the orbit's centre.
func centre() -> Vector3:
	if chain.halls.is_empty(): return Vector3.ZERO
	var h: Dictionary = chain.halls[-1]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for c: Dictionary in h.rise.chunks:
		lo = lo.min(c.lo)
		hi = hi.max(c.hi)
	return (h.rise as Node3D).to_global((lo+hi)*0.5)

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
		"plane": leave()
		"orbit":
			free_at = camera.global_position
			var f := -camera.global_basis.z
			free_yaw = atan2(-f.x,-f.z)
			free_pitch = asin(clampf(f.y,-1.0,1.0))
			mode = "free"
		"free": board()

# --- The plane -----------------------------------------------------------------------

## Into the plane: at the start (PLANE_OUT before the first hall's way in)
## with `at_start`, else BOARD_OUT before the newest hall's way in.
func board(at_start := false) -> void:
	plane = SkyPlane.new()
	plane.floor_y = SEA_Y
	var from: Vector3
	var head: float
	if at_start or chain.halls.is_empty():
		var s: Array = chain.start(PLANE_OUT)
		from = s[0]
		head = s[1]
		route_at = chain.route_base
	else:
		var pose: Dictionary = chain.halls[-1].pose
		head = ChainPlan.in_heading(pose)
		from = ChainPlan.approach_of(pose)-ChainPlan.ahead(head)*BOARD_OUT
		route_at = _route_index_of(ChainPlan.approach_of(pose))
	plane.launch(from+Vector3.UP*PLANE_UP,head,SkyPlane.CRUISE_SPEED,false)
	plane.velocity = plane.forward()*float(plane.speed)
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

func _route_index_of(p: Vector3) -> int:
	var best: int = chain.route_base
	var d := INF
	for k in range(chain.route.size()):
		var e: float = (chain.route[k] as Vector3).distance_to(p)
		if e < d:
			d = e
			best = chain.route_base+k
	return best

func leave() -> void:
	mode = "orbit"
	if figure != null: figure.visible = false
	plane = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## The plane's box (world; none out of the plane).
func _plane_box() -> AABB:
	if plane == null or mode != "plane": return AABB()
	var half := Vector3.ONE*(WorldScale.TOY_SPAN*0.5+0.3)
	return AABB((plane.position as Vector3)-half,half*2.0)

func plane_ground(_p: Vector3) -> Variant:
	return SEA_Y

func _fly(delta: float) -> void:
	var input := _fly_input(delta)
	if autopilot:
		var got: Array = chain.steer(plane,route_at)
		route_at = got[1]
		if input.is_empty() or _idle(input) or clock < 1.0: input = got[0]
		else: autopilot = false
	var was: Vector3 = plane.position
	plane.step(delta,input,plane_ground)
	if RuinBump.bump(get_world_3d().direct_space_state,plane,was): bumps += 1
	figure.update(delta,plane,0.0,plane_ground,false)
	figure._mark.visible = false
	chase.step(delta,plane,0.0,_inside_stone)
	camera.global_transform = Transform3D(Basis.looking_at(chase.look-chase.eye,Vector3.UP),chase.eye)
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

## No deliberate stick, keys or mouse in it (the autopilot keeps flying; a
## pixel or two of mouse jitter, or the warp as the mouse is captured,
## doesn't count).
static func _idle(input: Dictionary) -> bool:
	return absf(float(input.get("turn",0.0))) < 0.3 and absf(float(input.get("pitch",0.0))) < 0.3 and (input.get("look",Vector2.ZERO) as Vector2).length() < AUTO_LOOK \
		and is_zero_approx(float(input.get("lean",0.0))) and is_zero_approx(float(input.get("roll",0.0))) and float(input.get("boost",0.0)) < 0.3 and float(input.get("brake",0.0)) < 0.3

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
			KEY_N:
				chain.spawn_next()
				return
			KEY_P:
				autopilot = not autopilot
				return
			KEY_ENTER, KEY_KP_ENTER:
				for h: Dictionary in chain.halls:
					if not h.rise.sinking: h.rise.finish_now()
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
				_marks_on = not _marks_on
				_marks.visible = _marks_on
				if _marks_on: _draw_marks()
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
