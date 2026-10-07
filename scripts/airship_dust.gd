extends Node3D
## The dust and pebbles an islet sheds as an airship tears it free (scripts/
## sky_airship.gd): soft faceted puffs of earth billowing off its rim and
## rock, never fading but swelling and shrinking away, as the pilot's puffs
## do (scripts/pilot_puffs.gd, shaders/pilot_puff.gdshader); and faceted
## pebbles tumbling down off its underside toward the cloud sea, shrinking
## away as they fall. Both are one MultiMesh each, in the airship's frame
## (home coordinates), so a swap of the world's origin carries them along.

const PilotPuffs = preload("res://scripts/pilot_puffs.gd")
const SHADER := preload("res://shaders/pilot_puff.gdshader")

## Puffs and pebbles at once at most (the oldest is reused).
const PUFFS := 96
const PEBBLES := 64
## A puff's life (s, least and most), how fast its throw dies, how fast it
## sinks (m/s) as it billows, and how much it swells over its life.
const PUFF_LIFE := Vector2(2.2,4.0)
const DRAG := 1.4
const SINK := 0.35
const SWELL := 1.8
## A pebble's life (s), its fall's pull (m/s²) and its speed at most.
const PEBBLE_LIFE := Vector2(3.0,5.0)
const GRAVITY := 9.8
const TERMINAL := 22.0
const EARTH := Color(0.74,0.66,0.54)
const STONE := Color(0.52,0.48,0.44)

var _puffs: MultiMeshInstance3D
var _pebbles: MultiMeshInstance3D
## Per slot: [at, velocity, age, life, size, turn, tumble] in plain arrays.
var _p := {}
var _s := {}
var _rng := RandomNumberGenerator.new()
## Alive now, for probes.
var alive := 0

func _init() -> void:
	name = "Dust"
	_rng.randomize()
	_puffs = _pool(PUFFS,_material(1.2,0.7),_p)
	_pebbles = _pool(PEBBLES,_material(1.0,0.35),_s)
	_puffs.name = "Puffs"
	_pebbles.name = "Pebbles"
	set_process(false)

func _material(fill: float, rim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("fill",fill)
	m.set_shader_parameter("rim",rim)
	return m

func _pool(count: int, material: Material, into: Dictionary) -> MultiMeshInstance3D:
	var ball := PilotPuffs._ball()
	ball.surface_set_material(0,material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = ball
	multi.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Anywhere in the sky round the ship.
	node.custom_aabb = AABB(Vector3(-4000.0,-400.0,-4000.0),Vector3(8000.0,800.0,8000.0))
	add_child(node)
	into.at = PackedVector3Array()
	into.velocity = PackedVector3Array()
	into.age = PackedFloat32Array()
	into.life = PackedFloat32Array()
	into.size = PackedFloat32Array()
	into.turn = PackedVector3Array()
	into.tumble = PackedFloat32Array()
	for list in [into.at,into.velocity,into.age,into.life,into.size,into.turn,into.tumble]: list.resize(count)
	into.next = 0
	for i in range(count): multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	return node

## A puff of dust at `at` thrown at `velocity`, `size` m across at most.
func puff(at: Vector3, velocity: Vector3, size: float) -> void:
	var i := _take(_p,_puffs,EARTH.lightened(_rng.randf_range(0.0,0.12)))
	_p.at[i] = at
	_p.velocity[i] = velocity
	_p.life[i] = _rng.randf_range(PUFF_LIFE.x,PUFF_LIFE.y)
	_p.size[i] = size
	set_process(true)

## A pebble let go at `at` with `velocity`, `size` m across.
func pebble(at: Vector3, velocity: Vector3, size: float) -> void:
	var i := _take(_s,_pebbles,STONE.lightened(_rng.randf_range(-0.1,0.15)))
	_s.at[i] = at
	_s.velocity[i] = velocity
	_s.life[i] = _rng.randf_range(PEBBLE_LIFE.x,PEBBLE_LIFE.y)
	_s.size[i] = size
	set_process(true)

func _take(pool: Dictionary, node: MultiMeshInstance3D, tint: Color) -> int:
	var i: int = pool.next
	pool.next = (i+1)%(pool.age as PackedFloat32Array).size()
	pool.age[i] = 0.0
	pool.turn[i] = Vector3(_rng.randf_range(-PI,PI),_rng.randf_range(-PI,PI),_rng.randf_range(-PI,PI))
	pool.tumble[i] = _rng.randf_range(-2.5,2.5)
	node.multimesh.set_instance_color(i,tint)
	return i

## Every puff and pebble gone at once.
func clear() -> void:
	for pool: Dictionary in [_p,_s]:
		for i in range((pool.life as PackedFloat32Array).size()): pool.life[i] = 0.0
	for node: MultiMeshInstance3D in [_puffs,_pebbles]:
		for i in range(node.multimesh.instance_count): node.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	alive = 0
	set_process(false)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	alive = 0
	var multi := _puffs.multimesh
	for i in range((_p.life as PackedFloat32Array).size()):
		if _p.life[i] <= 0.0: continue
		_p.age[i] += delta
		var u: float = _p.age[i]/_p.life[i]
		if u >= 1.0:
			_p.life[i] = 0.0
			multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),_p.at[i]))
			continue
		alive += 1
		var v: Vector3 = _p.velocity[i]*exp(-DRAG*delta)
		_p.velocity[i] = v
		_p.at[i] += (v+Vector3.DOWN*SINK*u)*delta
		var turn: Vector3 = _p.turn[i]
		turn.y += float(_p.tumble[i])*0.3*delta
		_p.turn[i] = turn
		var grow := 1.0-pow(1.0-minf(u/0.12,1.0),3.0)
		var size: float = float(_p.size[i])*(0.35+0.65*grow)*(1.0+SWELL*u)*pow(1.0-u,0.8)
		multi.set_instance_transform(i,Transform3D(Basis.from_euler(turn).scaled_local(Vector3(size,size*0.85,size)),_p.at[i]))
	multi = _pebbles.multimesh
	for i in range((_s.life as PackedFloat32Array).size()):
		if _s.life[i] <= 0.0: continue
		_s.age[i] += delta
		var u: float = _s.age[i]/_s.life[i]
		if u >= 1.0:
			_s.life[i] = 0.0
			multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),_s.at[i]))
			continue
		alive += 1
		var v: Vector3 = _s.velocity[i]
		v.y = maxf(v.y-GRAVITY*delta,-TERMINAL)
		_s.velocity[i] = v
		_s.at[i] += v*delta
		var turn: Vector3 = _s.turn[i]
		turn += Vector3(1.0,0.7,0.4)*float(_s.tumble[i])*delta
		_s.turn[i] = turn
		var size: float = float(_s.size[i])*(1.0-smoothstep(0.6,1.0,u))
		multi.set_instance_transform(i,Transform3D(Basis.from_euler(turn).scaled_local(Vector3(size,size*0.7,size*0.85)),_s.at[i]))
	if alive == 0: set_process(false)
