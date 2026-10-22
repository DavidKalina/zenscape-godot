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

## Whether the sea has its body (tall swell, whitecaps): not --sea-body=old
## nor an earlier round's flag.
static func body_wanted() -> bool:
	var a := LaunchArgs.user_args()
	return wanted() and not ("--sea-body=old" in a or "--sea-motion=old" in a or "--sea-surface=old" in a)

func _init(seed_value: int) -> void:
	land_seed = seed_value
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/endless_sea.gdshader")
	material.set_shader_parameter("sea_level",Field.SEA_Y)
	material.set_shader_parameter("detail_a",_detail(seed_value,0.022,5))
	material.set_shader_parameter("detail_b",_detail(seed_value+7,0.035,4))
	material.set_shader_parameter("depth_map",depth)
	# The surface: --sea-surface=old keeps the smooth look (no fine ripples,
	# reflections off a calmed normal); the default is ripples at several
	# scales that the reflections see nearly whole.
	if "--sea-surface=old" in LaunchArgs.user_args():
		material.set_shader_parameter("mirror_calm",0.4)
	else:
		material.set_shader_parameter("detail_strength",Vector3(0.3,0.22,0.15))
		material.set_shader_parameter("ripple_strength",Vector2(0.24,0.15))
		material.set_shader_parameter("calm_share",0.9)
		material.set_shader_parameter("path_share",0.7)
		material.set_shader_parameter("mirror_calm",0.85)
		# The motion: --sea-motion=old keeps the rigidly scrolling layers and
		# four swells (the surface round); the default is the live surface
		# (crossing swells in groups, chop that rises and fades in place,
		# peaked wavelets, glitter filtered into a sheen far off).
		if not "--sea-motion=old" in LaunchArgs.user_args():
			material.set_shader_parameter("sea_motion",1)
			material.set_shader_parameter("body_shade",1.0)
			material.set_shader_parameter("swell",0.75)
			material.set_shader_parameter("fresnel_floor",0.08)
			material.set_shader_parameter("fresnel_power",3.5)
			# The body: --sea-body=old keeps the motion round's sheet; the
			# default is a tall swell and wind sea on a finer sheet, light
			# across the wave, whitecaps, slicks and rough stretches, and the
			# finest crinkles turned down.
			if body_wanted():
				material.set_shader_parameter("sea_body",1)
				material.set_shader_parameter("detail_strength",Vector3(0.2,0.12,0.045))
				material.set_shader_parameter("wavelet_strength",0.1)
				material.set_shader_parameter("wavelet_size",Vector2(3.2,0.7))
				material.set_shader_parameter("wind_patches",Vector2(320.0,0.35))
				material.set_shader_parameter("tint_mid",Color(0.06,0.43,0.62))
				material.set_shader_parameter("tint_deep",Color(0.035,0.2,0.47))
				material.set_shader_parameter("tint_abyss",Color(0.02,0.11,0.28))
	for a: String in LaunchArgs.user_args():
		# --sea-set=name:value[;name:value]: a uniform by hand, for tuning.
		if a.begins_with("--sea-set="):
			for pair in a.get_slice("=",1).split(";"):
				var kv := pair.split(":")
				if kv.size() == 2: material.set_shader_parameter(kv[0],str_to_var(kv[1]))
		elif a == "--no-wake": material.set_shader_parameter("wake",0.0)

## The steady wind the wind sea runs along (EndlessLook's base heading, in
## radians; the wind's wander would race the far crests).
func set_wind(angle: float) -> void:
	material.set_shader_parameter("body_wind",Vector2(cos(angle),sin(angle)))
	_knobs.clear()

# --- The body's swell on the CPU (shaders/endless_sea.gdshader zs_swell_body)

const BODY_LENGTH := [118.0,86.0,64.0,74.0,52.0,28.0,20.0,14.5,10.5,7.6,5.5]
const BODY_TRAIN := [0,0,0,1,1,2,2,2,2,2,2]
const BODY_TURN := [0.0,0.16,-0.22,0.0,0.3,0.0,0.38,-0.32,0.62,-0.55,0.9]
const BODY_SIZE := [0.45,0.42,0.38,0.32,0.28,0.07,0.068,0.064,0.06,0.055,0.05]
const GRAVITY := 9.81
var _knobs := {}
## The shader's defaults for what the mirror reads (a material keeps only
## what was set).
const KNOB_DEFAULTS := {"sea_body":0,"body_swell":Vector3(0.85,1.0,0.9),"swell_cross":Vector2(1.05,0.6),"swell_groups":0.9,"wind_patches":Vector2(380.0,0.35),"body_patch":Vector3(0.3,1.3,1.0),"swell_heading":Vector2(0.8,0.6),"body_wind":Vector2(1.0,0.0)}

## The sea's surface height over its rest level (m) at world `x`,`z` now:
## the body's swell (0 without the body). The shader's sheet shoves its
## points sideways, so the rest point under `x`,`z` is found by a few steps.
func height_at(x: float, z: float) -> float:
	if int(_knob("sea_body")) == 0: return 0.0
	var target := Vector2(x,z)
	var p := target
	var shift := Vector3.ZERO
	for i in 4:
		shift = _body_shift(p,_now)
		p = target-Vector2(shift.x,shift.z)
	return _body_shift(p,_now).y

func _knob(name: String) -> Variant:
	if not _knobs.has(name):
		var v: Variant = material.get_shader_parameter(name)
		if v == null: v = KNOB_DEFAULTS[name]
		_knobs[name] = v
	return _knobs[name]

static func _fract(v: float) -> float:
	return v-floorf(v)

static func _hash(p: Vector2) -> float:
	var a := _fract(p.x*0.1031)
	var b := _fract(p.y*0.1031)
	var c := a
	var d := a*(b+33.33)+b*(c+33.33)+c*(a+33.33)
	a += d
	b += d
	c += d
	return _fract((a+b)*c)

static func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p-i
	f = f*f*(Vector2(3.0,3.0)-2.0*f)
	var x0 := lerpf(_hash(i),_hash(i+Vector2(1.0,0.0)),f.x)
	var x1 := lerpf(_hash(i+Vector2(0.0,1.0)),_hash(i+Vector2(1.0,1.0)),f.x)
	return lerpf(x0,x1,f.y)

static func _rot(v: Vector2, a: float) -> Vector2:
	return Vector2(cos(a)*v.x-sin(a)*v.y,sin(a)*v.x+cos(a)*v.y)

func _body_shift(p: Vector2, t: float) -> Vector3:
	var body: Vector3 = _knob("body_swell")
	var cross: Vector2 = _knob("swell_cross")
	var groups: float = _knob("swell_groups")
	var patches: Vector2 = _knob("wind_patches")
	var bpatch: Vector3 = _knob("body_patch")
	var h0: Vector2 = Vector2(_knob("swell_heading")).normalized()
	var h1 := _rot(h0,cross.x)
	var hw: Vector2 = Vector2(_knob("body_wind")).normalized()
	var wa := Vector2(p.dot(hw),p.dot(Vector2(-hw.y,hw.x)))-Vector2(t*1.5,0.0)
	var wr := wa/Vector2(patches.x,patches.x*0.7)
	var rough := smoothstep(0.3,0.7,_noise(wr+Vector2(5.9,1.3))*0.65+_noise(wr*2.3+Vector2(2.2,9.1))*0.35)
	var wsea := lerpf(bpatch.x,bpatch.y,rough)
	var bend := (_noise(p/95.0+Vector2(t*0.01,7.1))-0.5)*2.4+(_noise(p/37.0+Vector2(2.4,t*0.015))-0.5)*0.9
	var gt := [
		_noise(Vector2(p.dot(h0)-t*6.0,p.dot(Vector2(-h0.y,h0.x)))/Vector2(260.0,420.0)+Vector2(1.7,5.3)),
		_noise(Vector2(p.dot(h1)-t*5.0,p.dot(Vector2(-h1.y,h1.x)))/Vector2(200.0,330.0)+Vector2(8.2,2.6)),
		_noise(Vector2(p.dot(hw)-t*2.6,p.dot(Vector2(-hw.y,hw.x)))/Vector2(90.0,120.0)+Vector2(3.1,6.6))]
	var dirs: Array[Vector2] = []
	var amps: Array[float] = []
	var phases: Array[float] = []
	var total := 0.0
	for i in BODY_LENGTH.size():
		var train: int = BODY_TRAIN[i]
		var h: Vector2 = h0 if train == 0 else (h1 if train == 1 else hw)
		var d := _rot(h,BODY_TURN[i])
		var length: float = BODY_LENGTH[i]
		var k := TAU/length
		var omega := sqrt(GRAVITY*k)
		var along := Vector2(p.dot(d)-0.5*omega/k*t,p.dot(Vector2(-d.y,d.x)))
		var own := _noise(along/(length*Vector2(2.6,3.4))+Vector2(i*3.7,i*1.3))
		var group := smoothstep(0.2,0.8,lerpf(gt[train],own,0.65))
		group = lerpf(1.0,0.12+1.6*group*group,groups)
		var a: float
		if train < 2: a = BODY_SIZE[i]*body.x*(cross.y/0.6 if train == 1 else 1.0)*group
		else: a = BODY_SIZE[i]*body.y*wsea*group/k
		dirs.append(d)
		amps.append(a)
		phases.append(p.dot(d)*k-omega*t+i*2.39+bend*(0.5+0.1*i))
		total += a*k
	var q := body.z/maxf(total,0.35)
	var shift := Vector3.ZERO
	for i in dirs.size():
		var c := cos(phases[i])
		shift.x += dirs[i].x*q*amps[i]*c
		shift.z += dirs[i].y*q*amps[i]*c
		shift.y += amps[i]*sin(phases[i])
	return shift

## The body's sheet: SkyBelow's rings, finer near the eye (`step` m cells,
## `cells` of them each way of the middle, doubling ring by ring to `reach`).
static var _body_sheet: ArrayMesh
static func sheet(step := 1.0, cells := 48, reach := 9000.0) -> ArrayMesh:
	if _body_sheet != null: return _body_sheet
	var vertices := PackedVector3Array()
	var index := {}
	var faces := PackedInt32Array()
	var unit := step*0.5
	var at := func(p: Vector2) -> int:
		var key := Vector2i(roundi(p.x/unit),roundi(p.y/unit))
		if index.has(key): return index[key]
		var id := vertices.size()
		vertices.append(Vector3(p.x,0.0,p.y))
		index[key] = id
		return id
	var n := cells
	var level := 0
	var size := step
	while true:
		var hole := n/2 if level > 0 else 0
		for j in range(-n,n):
			for i in range(-n,n):
				if level > 0 and i >= -hole and i < hole and j >= -hole and j < hole: continue
				var corners: Array[Vector2] = [Vector2(i,j)*size,Vector2(i+1,j)*size,Vector2(i+1,j+1)*size,Vector2(i,j+1)*size]
				var ring: Array[Vector2] = []
				for e in range(4):
					ring.append(corners[e])
					if level > 0 and _on_hole(corners[e],corners[(e+1)%4],hole*size): ring.append((corners[e]+corners[(e+1)%4])*0.5)
				if ring.size() == 4:
					var ids := [at.call(ring[0]),at.call(ring[1]),at.call(ring[2]),at.call(ring[3])]
					faces.append_array([ids[0],ids[1],ids[2],ids[0],ids[2],ids[3]])
				else:
					var middle: int = at.call((corners[0]+corners[2])*0.5)
					for e in range(ring.size()): faces.append_array([middle,at.call(ring[e]),at.call(ring[(e+1)%ring.size()])])
		if n*size >= reach: break
		level += 1
		size *= 2.0
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = faces
	_body_sheet = ArrayMesh.new()
	_body_sheet.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _body_sheet

static func _on_hole(a: Vector2, b: Vector2, edge: float) -> bool:
	if is_equal_approx(a.x,b.x) and is_equal_approx(absf(a.x),edge): return absf(a.y) <= edge+0.01 and absf(b.y) <= edge+0.01
	if is_equal_approx(a.y,b.y) and is_equal_approx(absf(a.y),edge): return absf(a.x) <= edge+0.01 and absf(b.x) <= edge+0.01
	return false

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
	var low := 1.0-smoothstep(WAKE_LOW,WAKE_HIGH,plane.y-Field.SEA_Y-height_at(plane.x,plane.z))
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
