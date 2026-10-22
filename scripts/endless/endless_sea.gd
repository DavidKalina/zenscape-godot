extends RefCounted
## The endless flight's sea material (shaders/endless_sea.gdshader) and what
## it reads from the CPU (docs/design/endless-flight/water-handoff.md):
##
##   depth map   the land's height over DEPTH_SIDE m round the eye, baked on
##               a worker whenever the eye strays DEPTH_MOVE m, so the water
##               is coloured by its real depth from any height.
##   chop        two seamless noise normal maps, made once.
##   wake        the plane's last WAKE_POINTS points while it flies low over
##               the water (one every WAKE_STEP m), with the time it passed
##               and how low it was.
##
## `--water=old` keeps the earlier sea (shaders/sky_ocean.gdshader).

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const DEPTH_TEXELS := 512
const DEPTH_SIDE := 4096.0
const DEPTH_MOVE := 900.0
const WAKE_POINTS := 40
## A point every WAKE_EVERY s of flight (and at least WAKE_STEP m on), so
## the trail spans WAKE_POINTS*WAKE_EVERY s; points older than WAKE_LIFE s
## drop off. The V's arms ride out at WAKE_SPREAD of the plane's speed.
const WAKE_EVERY := 0.12
const WAKE_STEP := 0.6
const WAKE_LIFE := 4.8
const WAKE_SPREAD := 0.3
## The wake starts under WAKE_HIGH m over the water and is full by WAKE_LOW.
const WAKE_HIGH := 7.0
const WAKE_LOW := 1.6

var material: ShaderMaterial
var land_seed := 0
var depth := ImageTexture.new()
var depth_at := Vector4.ZERO
var _task := -1
var _image: Image
var _next := Vector4.ZERO
var _trail: Array[Vector4] = []
var _now := 0.0
var _last := Vector2.INF
var _speed := 0.0
var _last_time := 0.0

## Whether the new sea is wanted (not --water=old).
static func wanted() -> bool:
	return not "--water=old" in LaunchArgs.user_args()

func _init(seed_value: int) -> void:
	land_seed = seed_value
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/endless_sea.gdshader")
	material.set_shader_parameter("sea_level",Field.SEA_Y)
	material.set_shader_parameter("detail_a",_detail(seed_value,0.022,5))
	material.set_shader_parameter("detail_b",_detail(seed_value+7,0.035,4))
	material.set_shader_parameter("depth_map",depth)
	for a: String in LaunchArgs.user_args():
		# --sea-set=name:value[;name:value]: a uniform by hand, for tuning.
		if a.begins_with("--sea-set="):
			for pair in a.get_slice("=",1).split(";"):
				var kv := pair.split(":")
				if kv.size() == 2: material.set_shader_parameter(kv[0],str_to_var(kv[1]))
		elif a == "--no-wake": material.set_shader_parameter("wake",0.0)

static func _detail(seed_value: int, frequency: float, octaves: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.45
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex

## One frame: the depth map round `eye`, the wake from the plane at `plane`.
func step(delta: float, eye: Vector3, plane: Vector3) -> void:
	_now += delta
	_depth(eye)
	_wake(plane)

func _depth(eye: Vector3) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_take()
	var middle := Vector2(depth_at.x,depth_at.y)+Vector2.ONE*depth_at.z*0.5
	var want := depth_at.w < 0.5 or Vector2(eye.x,eye.z).distance_to(middle) > DEPTH_MOVE
	if not want or _task >= 0: return
	var texel := DEPTH_SIDE/DEPTH_TEXELS
	var corner := ((Vector2(eye.x,eye.z)-Vector2.ONE*DEPTH_SIDE*0.5)/texel).floor()*texel
	_next = Vector4(corner.x,corner.y,DEPTH_SIDE,1.0)
	var s := land_seed
	if depth_at.w < 0.5:
		_image = depth_image(s,corner)
		_take()
	else:
		_task = WorkerThreadPool.add_task(func() -> void: _image = depth_image(s,corner),false,"Sea depth map")

func _take() -> void:
	if _image == null: return
	if depth.get_image() != null and depth.get_size() == Vector2(_image.get_size()): depth.update(_image)
	else: depth.set_image(_image)
	depth_at = _next
	material.set_shader_parameter("depth_at",depth_at)

## The land's height (world y) per texel over the square at `corner`.
static func depth_image(seed_value: int, corner: Vector2) -> Image:
	var field := Field.new(seed_value)
	var n := DEPTH_TEXELS
	var texel := DEPTH_SIDE/n
	var data := PackedFloat32Array()
	data.resize(n*n)
	for j in n:
		for i in n:
			data[j*n+i] = field.height(corner.x+(i+0.5)*texel,corner.y+(j+0.5)*texel)
	return Image.create_from_data(n,n,false,Image.FORMAT_RF,data.to_byte_array())

func _wake(plane: Vector3) -> void:
	var low := 1.0-smoothstep(WAKE_LOW,WAKE_HIGH,plane.y-Field.SEA_Y)
	var at := Vector2(plane.x,plane.z)
	# The newest point rides with the plane, so the wake starts under it; it
	# is left behind for good once WAKE_STEP m past the one before.
	if _last.is_finite():
		_speed = lerpf(_speed,at.distance_to(_last)/maxf(_now-_last_time,1e-3),0.2)
	_last = at
	_last_time = _now
	var point := Vector4(at.x,at.y,_now,low)
	var since := _trail[1] if _trail.size() >= 2 else Vector4.ZERO
	if _trail.size() < 2 or (_now-since.z > WAKE_EVERY and at.distance_to(Vector2(since.x,since.y)) > WAKE_STEP):
		_trail.push_front(point)
		if _trail.size() > WAKE_POINTS: _trail.pop_back()
	else:
		_trail[0] = point
	while not _trail.is_empty() and _now-_trail[-1].z > WAKE_LIFE: _trail.pop_back()
	var any := false
	for p in _trail:
		if p.w > 0.0: any = true
	var count := _trail.size() if any else 0
	var points := PackedVector4Array()
	points.resize(WAKE_POINTS)
	for i in count: points[i] = _trail[i]
	material.set_shader_parameter("wake_points",points)
	material.set_shader_parameter("wake_count",count)
	material.set_shader_parameter("wake_now",_now)
	var spread := clampf(_speed*WAKE_SPREAD,1.5,12.0)
	material.set_shader_parameter("wake_spread",spread)
	var reach := 0.0
	for i in count: reach = maxf(reach,at.distance_to(Vector2(_trail[i].x,_trail[i].y))+6.0+spread*1.3*(_now-_trail[i].z))
	material.set_shader_parameter("wake_head",Vector4(at.x,at.y,low,reach))

## Waits for a worker still baking (before the sea is freed).
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
