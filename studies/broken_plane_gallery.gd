extends Node3D
## Broken plane gallery: the pilot's plane as it is found, broken, its six
## lost parts (scripts/plane_parts.gd) missing and the damage showing where
## each was (scripts/plane_figure.gd `set_missing`), then mended a part at
## a time. Four planes stand parked in a row on the grass: broken, two
## parts found, four found, and mended (the figure as built, untouched).
## The found parts on the partly mended ones keep their faint glow. Pick a
## plane to look at it close, find its next part to watch it seat (it eases
## in, settles, flashes warm with a brass ring of light and a puff), and
## cycle it through the states.
##   Drag     orbit          Wheel   zoom
##   Tab      next plane (and back to all four)   1-4 a plane, 0 all four
##   Space    find the plane's next part           S   its next state
##   R        every plane back as it began         G   keep the glow on
##   N        day / night
##   ./run-broken-plane.command [--night] [--plane=0] [--yaw=0.3] [--pitch=0.2]
##       [--distance=4] [--look=x,y,z] [--find=1] [--hold]
##   godot --path . res://studies/broken_plane_gallery.tscn -- --capture=out.png
## --look= is a point on the picked plane, in its own frame (m, unscaled),
## to look at close. --find=n finds n parts on the picked plane, one after
## another, from a moment after it opens. --capture=<png> waits
## --capture-after= seconds (1.5), saves the view and quits.
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")

## The states, in the row's order: a name and the parts still missing.
const STATES := [
	{"name":"Broken","missing":["propeller","wheel","cowl","fin","wingtip","windscreen"]},
	{"name":"Two parts found","missing":["wheel","cowl","fin","wingtip"]},
	{"name":"Four parts found","missing":["wheel","wingtip"]},
	{"name":"Mended","missing":[]},
]
## The row: the planes' spacing (m), their size, and their heading (rad),
## turned so their right side, nose and cockpit face the camera.
const STEP := 3.3
const SCALE := 1.7
const HEADING := -2.2
## The camera on all four, and on one plane.
const ALL_FOCUS := Vector3(0.0,0.55,0.0)
const ALL_DISTANCE := 12.5
const ONE_DISTANCE := 4.2
## Seconds between finds with --find.
const FIND_EVERY := 0.95
## The daylight, and the night's (the hemisphere the folk paint is lit by,
## shaders/folk_surface.gdshaderinc).
const DAY_HEMI := [Vector3(0.28269485,0.4541367,0.6909623),Vector3(0.06847817,0.08437621,0.05126946),0.55825]
const NIGHT_HEMI := [Vector3(0.12,0.17,0.3),Vector3(0.03,0.035,0.05),0.3]

var _planes: Array[Node3D] = []
var _state: Array[int] = []
var _labels: Array[Label3D] = []
var _picked := -1
var _yaw := 0.25
var _pitch := 0.22
var _distance := ALL_DISTANCE
var _focus := ALL_FOCUS
var _look := Vector3.INF
var _night := false
var _hold := false
var _camera: Camera3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _ground: StandardMaterial3D
var _help: Label
var _capture := ""
var _capture_after := 1.5
var _distance_set := false

func _ready() -> void:
	var finds := 0
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--night": _night = true
		elif arg == "--hold": _hold = true
		elif arg.begins_with("--plane="): _picked = clampi(int(arg.get_slice("=",1)),-1,STATES.size()-1)
		elif arg.begins_with("--yaw="): _yaw = float(arg.get_slice("=",1))
		elif arg.begins_with("--pitch="): _pitch = float(arg.get_slice("=",1))
		elif arg.begins_with("--distance="):
			_distance = float(arg.get_slice("=",1))
			_distance_set = true
		elif arg.begins_with("--look="):
			var at := arg.get_slice("=",1).split(",")
			if at.size() == 3: _look = Vector3(float(at[0]),float(at[1]),float(at[2]))
		elif arg.begins_with("--find="): finds = int(arg.get_slice("=",1))
		elif arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
		elif arg.begins_with("--capture-after="): _capture_after = float(arg.get_slice("=",1))
	_build_world()
	for i in range(STATES.size()):
		var label := Label3D.new()
		label.text = STATES[i].name
		label.pixel_size = 0.3/64.0
		label.font_size = 48
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 0
		label.position = Vector3((i-1.5)*STEP,2.05,0.0)
		add_child(label)
		_labels.append(label)
		_planes.append(null)
		_state.append(i)
		_stand(i)
	_pick(_picked,_distance_set)
	_light(_night)
	if finds > 0: _find_some(finds)
	if not _capture.is_empty():
		await get_tree().create_timer(_capture_after).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture)
		get_tree().quit()

## Plane `i` parked anew in its state: broken, the parts it has found put
## back on at once (keeping their faint glow); the mended one as built.
func _stand(i: int) -> void:
	if _planes[i] != null: _planes[i].queue_free()
	var plane := PlaneFigure.new()
	add_child(plane)
	var pitch := PlaneStrip.REST_PITCH
	var at := Vector3((i-1.5)*STEP,SCALE*(PlaneStrip.contact(pitch)-PlaneStrip.FIGURE_DROP),0.0)
	plane.park(Transform3D(Basis.from_euler(Vector3(pitch,HEADING,0.0))*Basis.from_scale(Vector3.ONE*SCALE),at))
	plane.hold_glow = _hold
	var missing: Array = STATES[_state[i]].missing
	if not missing.is_empty() and missing.size() < PlaneFigure.FOUND.size():
		plane.set_missing(PlaneFigure.FOUND)
		for id: String in PlaneFigure.FOUND:
			if not missing.has(id): plane.set_found(id,false)
	else:
		plane.set_missing(missing)
	_planes[i] = plane
	_labels[i].text = STATES[_state[i]].name

## The picked plane (-1 all four); keep `distance` as it is if asked.
func _pick(i: int, keep_distance := false) -> void:
	_picked = i
	if i < 0:
		_focus = ALL_FOCUS
		if not keep_distance: _distance = ALL_DISTANCE
	else:
		var plane := _planes[i]
		_focus = plane.transform*(_look if _look != Vector3.INF else Vector3(0.0,0.05,0.0))
		if not keep_distance: _distance = ONE_DISTANCE
	_update_help()

## The picked plane (all four: the first still missing a part).
func _target() -> int:
	if _picked >= 0: return _picked
	for i in range(_planes.size()):
		if not _planes[i].missing().is_empty(): return i
	return 0

## Finds the plane's next missing part, in the found parts' order.
func _find_next() -> void:
	var plane := _planes[_target()]
	for id: String in PlaneFigure.FOUND:
		if plane.is_missing(id):
			plane.set_found(id)
			break
	_update_help()

func _find_some(count: int) -> void:
	await get_tree().create_timer(0.3).timeout
	for k in range(count):
		_find_next()
		await get_tree().create_timer(FIND_EVERY).timeout

func _update_help() -> void:
	if _help == null: return
	var on: String = "all four" if _picked < 0 else STATES[_state[_picked]].name+" ("+str(_picked+1)+")"
	var plane := _planes[_target()] if not _planes.is_empty() and _planes[0] != null else null
	var left: String = "" if plane == null else "  ·  missing: "+(", ".join(PackedStringArray(plane.missing())) if not plane.missing().is_empty() else "nothing")
	_help.text = "Broken plane · %s%s\nTab / 1-4 / 0 pick · Space find next part · S next state · R reset · G keep glow (%s) · N night · Drag orbit · Wheel zoom" % [on,left,"on" if _hold else "off"]

func _build_world() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = Color("e6d9c4")
	_env.ambient_light_sky_contribution = 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	_env.tonemap_exposure = 0.9
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.03
	_env.glow_hdr_threshold = 1.1
	_env.fog_enabled = true
	_env.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0,-30.0,0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)
	# A meadow to park on.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0,60.0)
	ground.mesh = plane
	_ground = StandardMaterial3D.new()
	_ground.roughness = 1.0
	ground.material_override = _ground
	add_child(ground)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	add_child(_camera)
	var layer := CanvasLayer.new()
	_help = Label.new()
	_help.position = Vector2(24.0,20.0)
	layer.add_child(_help)
	add_child(layer)

## The gallery's light, by day or at night: the sky, the sun (or the moon),
## the meadow and the folk paint's hemisphere.
func _light(night: bool) -> void:
	_night = night
	_sky.sky_top_color = Color("0d1830") if night else Color("2c5a8e")
	_sky.sky_horizon_color = Color("27365a") if night else Color("9db4c8")
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color("10182a") if night else Color("5f7d9c")
	_env.fog_light_color = _sky.sky_horizon_color
	_env.ambient_light_energy = 0.15 if night else 0.45
	_sun.light_color = Color("aabbe0") if night else Color("fff1dc")
	_sun.light_energy = 0.3 if night else 1.15
	_ground.albedo_color = Color("2c3a2a") if night else Color("8e9f68")
	var hemi: Array = NIGHT_HEMI if night else DAY_HEMI
	RenderingServer.global_shader_parameter_set("zs_hemi_sky",hemi[0])
	RenderingServer.global_shader_parameter_set("zs_hemi_ground",hemi[1])
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",hemi[2])
	for label in _labels: label.modulate = Color("e8e0d0") if night else Color("3a2f24")
	_help.add_theme_color_override("font_color",Color("c8c0b0") if night else Color("3a2f24"))
	_update_help()

func _process(delta: float) -> void:
	var k := minf(1.0,delta*4.0)
	var d := lerpf(_camera.position.distance_to(_focus),_distance,k) if _camera.position != Vector3.ZERO else _distance
	var aim := _focus if _camera.position == Vector3.ZERO else (_camera.get_meta("aim",_focus) as Vector3).lerp(_focus,k)
	_camera.set_meta("aim",aim)
	_camera.position = aim+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*d
	_camera.look_at(aim)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x*0.008
		_pitch = clampf(_pitch+event.relative.y*0.006,-0.1,1.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = maxf(0.8,_distance*0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = minf(30.0,_distance*1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB: _pick(_picked+1 if _picked+1 < _planes.size() else -1)
			KEY_0: _pick(-1)
			KEY_1, KEY_2, KEY_3, KEY_4: _pick(event.keycode-KEY_1)
			KEY_SPACE: _find_next()
			KEY_S:
				var i := _target()
				_state[i] = (_state[i]+1)%STATES.size()
				_planes[i].set_missing(STATES[_state[i]].missing)
				_labels[i].text = STATES[_state[i]].name
				_update_help()
			KEY_R:
				for i in range(_planes.size()):
					_state[i] = i
					_stand(i)
				_pick(_picked)
			KEY_G:
				_hold = not _hold
				for plane in _planes: plane.hold_glow = _hold
				_update_help()
			KEY_N: _light(not _night)
