extends Node3D
## What the six stubs give off (scripts/plane_idle.gd spends it, scripts/
## plane_figure.gd steps it): smoke wisps and the heat over the stubs, only
## while the engine's life runs, so a plane in flight has none of it.
##
## Wisps are soft billboards in one MultiMesh, world space (top_level), so they
## stay in the air where they were let go as the plane rocks or rolls off. Each
## has its slot for life and its seed in custom data: packing the live ones
## would renumber them and change every puff's shape at once. A puff (0 to 1)
## leaves one stub, in firing order; a strong one (ALL_FROM) is a cough from all
## six. It leaves on the prop's air (AIR_BACK, by `air`), the air drags it to a
## slow rise (DRAG_S, RISE), and it grows and thins over LIFE s. All of it is
## exact in `delta`, so the wisps hold at any frame rate.
##
## Haze is one quad a side, along the stubs and leaning up the stream, bending
## what's behind it a little (shaders/exhaust_haze.gdshader), by the engine's
## `heat`.

const WISP := preload("res://shaders/exhaust_wisp.gdshader")
const HAZE := preload("res://shaders/exhaust_haze.gdshader")

## Slots. The most ever alive stays under this at the run-up's rate.
const MOST := 48
## The throats, as the build lays them (art/blender/hero_plane/hero_plane_build.py).
const STUB_ANGLES := [1.85,2.2,2.55]
const STUB_R := 0.1755
const STUB_Z := -0.356
## An order the cylinders might fire in, as slots in `_stubs`.
const FIRING := [0,4,2,5,1,3]
const ALL_FROM := 0.45
## All in toy units (s, and per s): a puff's first size, and the rest grown by
## its end, weak to strong; its life; how fast it leaves.
const SIZE := Vector2(0.05,0.14)
const GROW := 3.2
const LIFE := Vector2(0.8,2.3)
const OUT := Vector2(0.08,0.32)
const AIR_BACK := Vector2(0.25,1.5)
const RISE := 0.11
const DRAG_S := 0.45
const JITTER := 0.012
## The haze's quad (across, along), how far it leans up from straight back.
const HAZE_SIZE := Vector2(0.16,0.34)
const HAZE_LEAN := 0.3
## How fast its pattern runs, off the air (idle's 1.0).
const HAZE_RUN := 0.7

var _mesh: MultiMesh
var _wisps: MultiMeshInstance3D
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
## Age, life, size, strength; seed apart.
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _strong := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _buffer := PackedFloat32Array()
var _next := 0
var _fire := 0
var _alive := 0
var _stubs: Array[Vector3] = []
var _ways: Array[Vector3] = []
var _haze: Array[MeshInstance3D] = []
var _haze_material: ShaderMaterial
var _clock := 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "Exhaust"
	_rng.seed = 73
	for side: float in [-1.0,1.0]:
		for a: float in STUB_ANGLES:
			var way := Vector3(sin(a*side),cos(a*side),0.0)
			_stubs.append(way*STUB_R+Vector3(0.0,0.0,STUB_Z))
			_ways.append(way)
	_pos.resize(MOST)
	_vel.resize(MOST)
	for list: String in ["_age","_life","_size","_strong","_seed"]:
		var a := PackedFloat32Array()
		a.resize(MOST)
		set(list,a)
	_buffer.resize(MOST*16)
	_build_wisps()
	_build_haze()

func _build_wisps() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mesh = MultiMesh.new()
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_custom_data = true
	_mesh.mesh = quad
	_mesh.instance_count = MOST
	_wisps = MultiMeshInstance3D.new()
	_wisps.name = "Wisps"
	_wisps.multimesh = _mesh
	_wisps.top_level = true
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# World space and few: the box only has to be somewhere the eye is.
	_wisps.custom_aabb = AABB(Vector3.ONE*-1.0e5,Vector3.ONE*2.0e5)
	var m := ShaderMaterial.new()
	m.shader = WISP
	_wisps.material_override = m
	_wisps.visible = false
	add_child(_wisps)

func _build_haze() -> void:
	_haze_material = ShaderMaterial.new()
	_haze_material.shader = HAZE
	var quad := QuadMesh.new()
	quad.size = HAZE_SIZE
	var up := Vector3(0.0,HAZE_LEAN,1.0).normalized()
	for side: float in [-1.0,1.0]:
		var q := MeshInstance3D.new()
		q.mesh = quad
		q.material_override = _haze_material
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var first := 0 if side < 0.0 else 3
		var at := (_stubs[first]+_stubs[first+1]+_stubs[first+2])/3.0
		var across := up.cross(Vector3.UP).normalized()
		q.transform = Transform3D(Basis(across,up,across.cross(up)),at+up*HAZE_SIZE.y*0.5)
		q.visible = false
		_haze.append(q)
		add_child(q)

## One frame: `to_world` the figure's frame, `heat` and `air` the engine's
## (scripts/plane_idle.gd), `puffs` this frame's.
func step(delta: float, to_world: Transform3D, heat: float, air: float, puffs: Array[float]) -> void:
	var size := to_world.basis.get_scale().x
	for k: float in puffs: _puff(k,to_world,size,air)
	_age_all(delta)
	var hot := heat > 0.01
	for q in _haze: q.visible = hot
	if hot:
		_clock += delta*HAZE_RUN*(1.0+air)
		_haze_material.set_shader_parameter("clock",_clock)
		_haze_material.set_shader_parameter("amount",heat)

## Back to nothing at once (the plane was put somewhere new).
func clear() -> void:
	_age.fill(0.0)
	_life.fill(0.0)
	_alive = 0
	_wisps.visible = false
	for q in _haze: q.visible = false

## The world moved under it.
func shift_by(by: Vector3) -> void:
	for i in range(MOST): _pos[i] += by

func _puff(k: float, to_world: Transform3D, size: float, air: float) -> void:
	k = clampf(k,0.0,1.0)
	var back := to_world.basis.z.normalized()
	var strong := k >= ALL_FROM
	for n in range(_stubs.size() if strong else 1):
		var stub: int = FIRING[_fire%FIRING.size()]
		_fire += 1
		var i := _next
		_next = (_next+1)%MOST
		var scatter := Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0))
		_pos[i] = to_world*(_stubs[stub]+scatter*JITTER)
		var out := to_world.basis.orthonormalized()*_ways[stub]*lerpf(OUT.x,OUT.y,k)
		var v := out+back*lerpf(AIR_BACK.x,AIR_BACK.y,air)+scatter*0.05
		_vel[i] = v*size
		_age[i] = 0.0
		_life[i] = lerpf(LIFE.x,LIFE.y,k)*_rng.randf_range(0.8,1.2)
		_size[i] = lerpf(SIZE.x,SIZE.y,k)*_rng.randf_range(0.8,1.2)*size
		_strong[i] = k
		_seed[i] = _rng.randf()

func _age_all(delta: float) -> void:
	var keep := exp(-delta/DRAG_S)
	var carried := DRAG_S*(1.0-keep)
	_alive = 0
	var at := 0
	for i in range(MOST):
		var alive := _age[i] < _life[i]
		var t := 0.0
		var s := 0.0
		var o := Vector3.ZERO
		if alive:
			var rise := Vector3.UP*RISE*_size[i]/SIZE.x
			var over := _vel[i]-rise
			_pos[i] += rise*delta+over*carried
			_vel[i] = rise+over*keep
			_age[i] += delta
			t = clampf(_age[i]/_life[i],0.0,1.0)
			s = _size[i]*(1.0+GROW*(1.0-(1.0-t)*(1.0-t)))
			o = _pos[i]
			_alive += 1
		# Row by row, as a MultiMesh keeps a 3D transform; then custom data.
		_buffer[at] = s
		_buffer[at+1] = 0.0
		_buffer[at+2] = 0.0
		_buffer[at+3] = o.x
		_buffer[at+4] = 0.0
		_buffer[at+5] = s
		_buffer[at+6] = 0.0
		_buffer[at+7] = o.y
		_buffer[at+8] = 0.0
		_buffer[at+9] = 0.0
		_buffer[at+10] = s
		_buffer[at+11] = o.z
		_buffer[at+12] = t
		_buffer[at+13] = _seed[i]
		_buffer[at+14] = _strong[i]
		_buffer[at+15] = 0.0
		at += 16
	var shown := _alive > 0
	if shown or _wisps.visible: _mesh.buffer = _buffer
	_wisps.visible = shown
