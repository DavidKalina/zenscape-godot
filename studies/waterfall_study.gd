extends Node3D
## The waterfall look study: a 40 m rock wall with a dark 20 x 15 m opening,
## a thick marched plume of a fall with its spray (shaders/waterfall_volume.gdshader)
## pouring over a lip and covering the opening, and a pool at the base with a foam ring.
## Keys 1 front, 2 angle, 3 close, 4 graze (low, along the wall), 5 base, 6 fly
## (the camera flies through the fall into the opening, over and over); mouse
## drag orbits, wheel zooms, WASD pans the look-at point, Q/E down/up.
## Flag: --view=front|angle|close|graze|base|fly.

const WALL_H := 40.0
const WALL_W := 70.0
const OPEN_W := 20.0
const OPEN_H := 15.0
const HANG := 3.5
const FRONT_Z := 4.0
const BOX := Vector3(54.0, 44.0, 32.0)
# The fall's shape (the shaders' own defaults, set on both so they agree).
const HALF_W := 11.5
const SPREAD := 4.5
const THROW := 3.0
# The box runs back into the rock (hidden there) so the water can come over
# the wall top from behind; below the top it keeps 0.3 m off the wall face.
const BOX_Z0 := -6.0
# The fly view: a line through the fall into the opening, at this speed (m/s).
const FLY_FROM := Vector3(-2.5, 7.5, 34.0)
const FLY_TO := Vector3(-1.5, 6.5, -10.0)
const FLY_SPEED := 22.0

var _cam: Camera3D
var _target := Vector3(0, 18, 0)
var _yaw := 0.0
var _pitch := 0.15
var _dist := 80.0
var _drag := false
var _mat: ShaderMaterial
var _sun: DirectionalLight3D
var _fly := false
## How far along the fly line (0..1); a driver may set it with fly_at.
var fly_t := 0.0

func _ready() -> void:
	_build_env()
	_build_land()
	_build_fall()
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 1000.0
	add_child(_cam)
	_cam.make_current()
	var v := "front"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view="): v = a.substr(7)
	_preset(v)

func _preset(v: String) -> void:
	_fly = v == "fly"
	if _fly:
		fly_at(0.0)
		return
	match v:
		"angle":
			_target = Vector3(0, 16, 0)
			_yaw = deg_to_rad(48)
			_pitch = 0.2
			_dist = 70.0
		"graze":
			_target = Vector3(0, 14, 2.0)
			_yaw = deg_to_rad(84)
			_pitch = 0.02
			_dist = 75.0
		"base":
			_target = Vector3(0, 2.0, 4.5)
			_yaw = deg_to_rad(28)
			_pitch = 0.14
			_dist = 24.0
		"close":
			_target = Vector3(-6, 8, HANG)
			_yaw = deg_to_rad(22)
			_pitch = 0.08
			_dist = 16.0
		_:
			_target = Vector3(0, 18, 0)
			_yaw = 0.0
			_pitch = 0.12
			_dist = 85.0
	_place_cam()

## The camera at `t` (0..1) along the fly line, looking along it.
func fly_at(t: float) -> void:
	fly_t = t
	_cam.position = FLY_FROM.lerp(FLY_TO, t)
	_cam.look_at(_cam.position + (FLY_TO - FLY_FROM).normalized() + Vector3(0, -0.02, 0))

func _place_cam() -> void:
	_cam.position = _target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.look_at(_target)

func _build_env() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.35, 0.55, 0.85)
	sky.sky_horizon_color = Color(0.75, 0.85, 0.95)
	sky.ground_horizon_color = Color(0.6, 0.65, 0.65)
	var s := Sky.new()
	s.sky_material = sky
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)

func _box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	m.mesh = b
	m.position = pos
	add_child(m)

func _build_land() -> void:
	var rock := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.noise = FastNoiseLite.new()
	nt.noise.frequency = 0.02
	nt.seamless = true
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.28, 0.25, 0.22), Color(0.52, 0.47, 0.41)])
	nt.color_ramp = ramp
	rock.albedo_texture = nt
	rock.uv1_triplanar = true
	rock.uv1_scale = Vector3(0.05, 0.05, 0.05)
	rock.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.015, 0.02)
	dark.roughness = 1.0
	var depth := 12.0
	var hw := OPEN_W * 0.5
	var side_w := (WALL_W - OPEN_W) * 0.5
	# The wall, in pieces around the opening (front face at z = 0).
	_box(Vector3(-hw - side_w * 0.5, WALL_H * 0.5, -depth * 0.5), Vector3(side_w, WALL_H, depth), rock)
	_box(Vector3(hw + side_w * 0.5, WALL_H * 0.5, -depth * 0.5), Vector3(side_w, WALL_H, depth), rock)
	_box(Vector3(0, OPEN_H + (WALL_H - OPEN_H) * 0.5, -depth * 0.5), Vector3(OPEN_W, WALL_H - OPEN_H, depth), rock)
	# A dark liner for the recess: back, sides, ceiling.
	var lin := 0.2
	_box(Vector3(0, OPEN_H * 0.5, -depth + lin * 0.5), Vector3(OPEN_W, OPEN_H, lin), dark)
	_box(Vector3(-hw + lin * 0.5, OPEN_H * 0.5, -depth * 0.5), Vector3(lin, OPEN_H, depth), dark)
	_box(Vector3(hw - lin * 0.5, OPEN_H * 0.5, -depth * 0.5), Vector3(lin, OPEN_H, depth), dark)
	_box(Vector3(0, OPEN_H - lin * 0.5, -depth * 0.5), Vector3(OPEN_W, lin, depth), dark)
	# The lip the water pours over, jutting out to the sheet.
	_box(Vector3(0, WALL_H - 0.5, HANG * 0.5), Vector3(OPEN_W + 2.0, 1.0, HANG + 0.4), rock)
	# Ground and pool.
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.25, 0.27, 0.22)
	ground.roughness = 1.0
	_box(Vector3(0, -0.5, 20), Vector3(220, 1.0, 160), ground)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.42, 0.5)
	water.roughness = 0.15
	_box(Vector3(0, 0.02, HANG + 12.0), Vector3(56, 0.1, 32), water)

func _build_fall() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/waterfall_volume.gdshader")
	_mat.set_shader_parameter("box_size", BOX)
	_mat.set_shader_parameter("box_z0", BOX_Z0)
	_mat.set_shader_parameter("wall_top", WALL_H)
	_mat.set_shader_parameter("front_z", FRONT_Z)
	_mat.set_shader_parameter("lip_y", WALL_H + 1.2)
	_mat.set_shader_parameter("half_width", HALF_W)
	_mat.set_shader_parameter("spread", SPREAD)
	_mat.set_shader_parameter("throw_out", THROW)
	# After the pool's foam (which writes no depth): the fall writes depth, and
	# its spray would cut the foam behind it.
	_mat.render_priority = 1
	_mat.set_shader_parameter("sun_dir", _sun.global_transform.basis.z)
	var bm := BoxMesh.new()
	bm.size = BOX
	bm.material = _mat
	var m := MeshInstance3D.new()
	m.mesh = bm
	m.position = Vector3(0, BOX.y * 0.5, BOX_Z0 + BOX.z * 0.5)
	m.custom_aabb = AABB(-BOX * 0.5, BOX)
	add_child(m)
	# The disturbed ring on the pool.
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/waterfall_pool.gdshader")
	# The pool's foam starts where the churn mound ends (the fall's front at
	# the foot, plus its lean, plus the mound's reach: the shader's defaults).
	pm.set_shader_parameter("front_z", FRONT_Z + THROW)
	pm.set_shader_parameter("half_width", HALF_W)
	pm.set_shader_parameter("spread", SPREAD)
	pm.set_shader_parameter("mound_reach", 2.6)
	var pl := PlaneMesh.new()
	pl.size = Vector2(56, 32)
	pl.material = pm
	var pi := MeshInstance3D.new()
	pi.mesh = pl
	pi.position = Vector3(0, 0.09, HANG + 12.0)
	add_child(pi)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_RIGHT or b.button_index == MOUSE_BUTTON_LEFT:
			_drag = b.pressed
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(3.0, _dist * 0.9)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(250.0, _dist * 1.1)
		_place_cam()
	elif e is InputEventMouseMotion and _drag:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.005
		_pitch = clampf(_pitch + mm.relative.y * 0.005, -0.2, 1.4)
		_place_cam()
	elif e is InputEventKey and e.pressed:
		match (e as InputEventKey).keycode:
			KEY_1: _preset("front")
			KEY_2: _preset("angle")
			KEY_3: _preset("close")
			KEY_4: _preset("graze")
			KEY_5: _preset("base")
			KEY_6: _preset("fly")

func _process(delta: float) -> void:
	if _fly:
		fly_at(fmod(fly_t + delta * FLY_SPEED / FLY_FROM.distance_to(FLY_TO), 1.0))
		return
	var f := (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
	var r := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	var u := (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	if f != 0.0 or r != 0.0 or u != 0.0:
		var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
		var rt := Vector3(cos(_yaw), 0, -sin(_yaw))
		_target += (fwd * f + rt * r + Vector3.UP * u) * 20.0 * delta
		_place_cam()
