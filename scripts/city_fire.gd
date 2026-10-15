extends Node3D
## One fire of the city kit's fire pieces (scripts/city_kit_fires.gd,
## docs/design/roguelike/city-fires-round1.md): what burns in a cresset's
## bowl, on a beacon tower's crown, at a runnel's running front, or spilled
## on the ground. Soft things only, on the campfire's shaders, so the city's
## fires and the hearths are one fire:
##
##   flames   a few flame cards (shaders/campfire_flame.gdshader), one
##            MultiMesh: a body of tongues and licks torn off the tip
##   coals    a glowing bed (shaders/campfire_coals.gdshader), `bed` m across
##   halo     a soft camera-facing glow (shaders/stone_lamp_halo.gdshader):
##            the orange dot that reads through the haze from far off
##   embers   sparks rising and cooling (shaders/fire_ember.gdshader), a
##            small capped pool, only while the camera is within EMBER_NEAR
##   light    one OmniLight3D, a warm flicker (two noises: a slow breath and
##            a quick lick), shadowed only if `shadows`
##
## `lit` eases the fire in and out: lighting it flares (a burst of embers,
## the flame overshooting its height) then settles. The fire is a look; the
## sight's light and the beacon are the piece's (city_kit_fires.gd).
## Sizes are the flame's height (m) and the bed's width (m).

const FLAME_SHADER := preload("res://shaders/campfire_flame.gdshader")
const COALS_SHADER := preload("res://shaders/campfire_coals.gdshader")
const HALO_SHADER := preload("res://shaders/stone_lamp_halo.gdshader")
const EMBER_SHADER := preload("res://shaders/fire_ember.gdshader")

const COLOR := Color(1.0,0.6,0.28)
## The tongues of one fire, at flame height 1 and bed width 1: (x, z)
## offset, height share, phase, kind (0 a body of flame, 1 a lick).
const TONGUES := [
	[Vector2(0.0,0.0),1.0,0.0,0],
	[Vector2(0.22,0.1),0.72,0.31,0],
	[Vector2(-0.2,-0.12),0.66,0.57,0],
	[Vector2(-0.05,0.24),0.55,0.79,0],
	[Vector2(0.12,-0.22),0.5,0.17,0],
	[Vector2(0.0,0.0),1.0,0.13,1],
	[Vector2(0.06,-0.04),0.9,0.46,1],
	[Vector2(-0.06,0.04),0.94,0.78,1],
]
## How long (s) lighting takes to flare and settle, and dousing to die.
const IGNITE := 0.9
const DIE := 0.6
## The flare's overshoot on the flame's height.
const FLARE := 0.45
## Embers: at most, per second at height 1, how near the camera (m) they fly.
const EMBER_CAP := 28
const EMBER_RATE := 9.0
const EMBER_NEAR := 70.0
const EMBER_BURST := 16

## The flame's height (m), the bed's width (m).
@export var flame := 1.2
@export var bed := 1.6
## The light: its reach (m), energy at full, and whether it casts shadows.
@export var light_range := 14.0
@export var light_energy := 3.0
@export var shadows := false
## The halo's width (m) and strength.
@export var halo := 5.0
@export var halo_glow := 0.55
## How lively the light's flicker is (0 steady).
@export var flicker := 1.0
## Embers on (a runnel's front has none of its own).
@export var embers := true

## Burning (eased in `_process`). `light()` / `douse()`.
var lit := false
## 0 out .. 1 burning; over 1 while it flares.
var heat := 0.0
## How many times it was lit (for checks).
var lightings := 0

var flames: MultiMeshInstance3D
var coals: MultiMeshInstance3D
var glow: MeshInstance3D
var sparks: MultiMeshInstance3D
var omni: OmniLight3D
var _flame_mat := ShaderMaterial.new()
var _coal_mat := ShaderMaterial.new()
var _halo_mat := ShaderMaterial.new()
var _spark_mat := ShaderMaterial.new()
var _since := 99.0
var _clock := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _pool: Array[Dictionary] = []
var _debt := 0.0
var _burst := 0
var _built := false

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	_rng.seed = hash(get_instance_id())
	_noise.seed = _rng.randi()
	_noise.frequency = 0.9
	_clock = _rng.randf()*50.0
	_flame_mat.shader = FLAME_SHADER
	_flame_mat.set_shader_parameter("intensity",1.15)
	_coal_mat.shader = COALS_SHADER
	_coal_mat.set_shader_parameter("strength",1.4)
	_halo_mat.shader = HALO_SHADER
	_halo_mat.set_shader_parameter("tint",COLOR)
	_spark_mat.shader = EMBER_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	flames = _batch("Flames",quad,_flame_mat,true)
	flames.multimesh.instance_count = TONGUES.size()
	for k in TONGUES.size():
		var t: Array = TONGUES[k]
		var o: Vector2 = t[0]
		flames.multimesh.set_instance_transform(k,Transform3D(Basis.IDENTITY,Vector3(o.x*bed*0.5,0.0,o.y*bed*0.5)))
		flames.multimesh.set_instance_color(k,Color(float(t[3]),0.0,0.0,1.0))
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE
	coals = _batch("Coals",disc,_coal_mat,true)
	coals.multimesh.instance_count = 1
	coals.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*bed),Vector3(0.0,0.01,0.0)))
	coals.multimesh.set_instance_custom_data(0,Color(_rng.randf(),0.0,0.0,0.0))
	coals.multimesh.set_instance_color(0,Color(1,1,1,1))
	glow = MeshInstance3D.new()
	glow.name = "Halo"
	glow.mesh = quad
	glow.material_override = _halo_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.scale = Vector3.ONE*halo
	glow.position = Vector3(0.0,flame*0.45,0.0)
	add_child(glow)
	sparks = _batch("Embers",quad,_spark_mat,false)
	sparks.top_level = true
	sparks.transform = Transform3D.IDENTITY
	sparks.multimesh.instance_count = EMBER_CAP
	sparks.multimesh.visible_instance_count = 0
	omni = OmniLight3D.new()
	omni.name = "Light"
	omni.light_color = COLOR
	omni.omni_range = light_range
	omni.omni_attenuation = 1.2
	omni.shadow_enabled = shadows
	omni.shadow_bias = 0.06
	omni.light_specular = 0.35
	omni.position = Vector3(0.0,flame*0.85,0.0)
	add_child(omni)
	_show(0.0)

func _batch(label: String, mesh: Mesh, material: Material, colours: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	node.multimesh.use_colors = colours
	node.multimesh.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shaders draw the cards off their points: room round them.
	node.custom_aabb = AABB(Vector3(-bed-flame,-0.5,-bed-flame),Vector3(bed+flame,flame*2.5+1.0,bed+flame)*2.0)
	add_child(node)
	return node

## Lit now: it flares, sparks burst, then it settles.
func light() -> void:
	_build()
	if lit: return
	lit = true
	lightings += 1
	_since = 0.0
	_burst = EMBER_BURST

## Out now (eased).
func douse() -> void:
	if not lit: return
	lit = false
	_since = 0.0

## Lit at once, no flare (a fire burning when the place stands).
func burn() -> void:
	_build()
	lit = true
	lightings += 1
	_since = 99.0
	heat = 1.0
	_show(1.0)

func _process(delta: float) -> void:
	if not _built: return
	var dt := clampf(delta,0.0,0.1)
	_since += dt
	_clock += dt
	if lit:
		# Flares past full, then settles (an ease-out with one overshoot).
		var u := clampf(_since/IGNITE,0.0,1.0)
		heat = 1.0+FLARE*sin(u*PI)*(1.0-u*0.4) if u < 1.0 else 1.0
		heat *= smoothstep(0.0,0.18,_since)
	else:
		heat = move_toward(heat,0.0,dt/DIE)
	_show(heat)
	if heat <= 0.001 and _pool.is_empty(): return
	_flame_mat.set_shader_parameter("time",_clock)
	_coal_mat.set_shader_parameter("time",_clock)
	_spark_mat.set_shader_parameter("time",_clock)
	# The light: a slow breath and a quick lick, both brief, never a strobe.
	var n := _noise.get_noise_1d(_clock*2.2)*0.6+_noise.get_noise_1d(_clock*7.5+31.0)*0.4
	omni.light_energy = light_energy*heat*(1.0+n*0.28*flicker)
	omni.position = Vector3(n*0.05*flame,flame*(0.85+n*0.04),0.0)
	_embers(dt)

## The fire drawn at `h` (0 out .. 1 burning, over 1 flaring).
func _show(h: float) -> void:
	var on := h > 0.001
	flames.visible = on
	glow.visible = on
	omni.visible = on
	coals.visible = true
	_coal_mat.set_shader_parameter("strength",1.4*clampf(h,0.0,1.2) if on else 0.0)
	coals.visible = on
	_halo_mat.set_shader_parameter("glow",halo_glow*clampf(h,0.0,1.3))
	if not on: return
	var mm := flames.multimesh
	for k in TONGUES.size():
		var t: Array = TONGUES[k]
		mm.set_instance_custom_data(k,Color(float(t[2]),float(t[1])*flame*h,0.0,0.0))

## Sparks off the fire, rising and cooling, near the camera only; a burst
## when it is lit.
func _embers(dt: float) -> void:
	if not embers: return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := cam == null or cam.global_position.distance_to(global_position) < EMBER_NEAR
	var at := global_position+Vector3.UP*flame*0.3
	if near and heat > 0.05:
		_debt += EMBER_RATE*flame*clampf(heat,0.0,1.0)*dt
		_debt += float(_burst)
		_burst = 0
	while _debt >= 1.0:
		_debt -= 1.0
		if _pool.size() >= EMBER_CAP: continue
		var s := flame
		_pool.append({"p":at+Vector3(_rng.randf_range(-0.3,0.3)*bed,0.0,_rng.randf_range(-0.3,0.3)*bed),
			"v":Vector3(_rng.randf_range(-0.5,0.5),_rng.randf_range(1.4,3.0)*sqrt(s),_rng.randf_range(-0.5,0.5)),
			"age":0.0,"life":_rng.randf_range(1.0,2.4),"seed":_rng.randf(),"size":0.07*clampf(s,0.6,2.0)})
	_debt = minf(_debt,4.0)
	var mm := sparks.multimesh
	var count := 0
	for i in range(_pool.size()-1,-1,-1):
		var e: Dictionary = _pool[i]
		e.age += dt
		if e.age >= e.life:
			_pool.remove_at(i)
			continue
		var v: Vector3 = e.v
		# Lifted by the heat, wandering: a slow curl.
		v.y -= 0.6*dt
		v.x += sin(_clock*3.0+float(e.seed)*20.0)*1.2*dt
		v.z += cos(_clock*2.6+float(e.seed)*13.0)*1.2*dt
		e.v = v
		e.p += v*dt
	for e: Dictionary in _pool:
		var u: float = e.age/e.life
		mm.set_instance_transform(count,Transform3D(Basis.IDENTITY,e.p))
		mm.set_instance_custom_data(count,Color(e.seed,e.size,smoothstep(1.0,0.55,u),1.0-u))
		count += 1
	mm.visible_instance_count = count
	sparks.visible = count > 0
	# Top level at the origin: its box is in the world's frame.
	if count > 0: sparks.custom_aabb = AABB(at-Vector3(6,1,6),Vector3(12,14,12))
