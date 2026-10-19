extends Node3D
## Whiteouts (a prototype; scripts/plane_weather.gd owns it as `whiteout`):
## in a storm cell's or the front's thick core, now and then a short
## stretch (LENGTH s) where the murk closes in round the plane until only
## tens of metres are seen: the isles and the horizon gone, cloud racing
## past, the rain thick, lightning lighting the murk from inside without
## its channel seen. Then it opens out again into the storm air.
##
##   the murk   `murk` (0 to 1), eased in over CLOSE s and out over OPEN s;
##              drawn by a sheet over the screen (shaders/
##              storm_whiteout.gdshader) after the cloud, the far rain and
##              the bolts (RENDER_PRIORITY), under the near rain. Others read
##              `murk` (plane_weather's, each frame), e.g. the dragon's
##              sightings for a close one.
##   on its own while the plane is in a core (`core` past CORE), one comes
##              after a wait drawn round EVERY s (a mean); after one ends
##              none comes for REST s.
##   lightning  FLASHES flashes inside the murk near the plane, a beat
##              after it closes and now and then while it lasts
##              (scripts/plane_lightning.gd `strike_over`, "inside").
## `drop` drops one on the plane now (M in the sandbox). Flags:
##   --whiteout-at=<frames>   one that many frames in
##   --whiteout-hold=<0..1>   it held at that murk (for stills)
##   --whiteout-every=<s>     the mean wait in a core (0: none on their own)
const LENGTH := Vector2(4.0,15.0)
const CLOSE := 1.4
const OPEN := 1.8
const CORE := 0.9
const EVERY := 18.0
const REST := 25.0
## The flashes in it: the mean wait (s), how far off (m), and the first's
## delay after it closes (s).
const FLASH_EVERY := 3.5
const FLASH_OFF := Vector2(50.0,150.0)
const FIRST_FLASH := Vector2(0.8,2.0)
## Over the bolts (5) and the rain's veils (10); the near rain over it.
const RENDER_PRIORITY := 20

var murk := 0.0
## The one under way: its time and length (s); `length` 0: none.
var _t := 0.0
var _length := 0.0
var _flash_wait := 0.0
var _wait := 0.0
var _rest := 0.0
var every := EVERY
var count := 0
var flashes := 0
var lightning: Node3D
var _scene: Node3D
var _rng := RandomNumberGenerator.new()
var _sheet := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _drop_at := -1
var _hold := -1.0
var _frames := 0

func setup(scene: Node3D) -> void:
	name = "StormWhiteout"
	_scene = scene
	_rng.randomize()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		var a := str(arg)
		if a.begins_with("--whiteout-at="): _drop_at = int(a.get_slice("=",1))
		elif a.begins_with("--whiteout-hold="): _hold = clampf(float(a.get_slice("=",1)),0.0,1.0)
		elif a.begins_with("--whiteout-every="): every = maxf(0.0,float(a.get_slice("=",1)))
	_wait = _draw_wait()
	_material.shader = preload("res://shaders/storm_whiteout.gdshader")
	_material.render_priority = RENDER_PRIORITY
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	_sheet.name = "Murk"
	_sheet.mesh = quad
	_sheet.material_override = _material
	_sheet.top_level = true
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.ignore_occlusion_culling = true
	_sheet.custom_aabb = AABB(Vector3.ONE*-1e6,Vector3.ONE*2e6)
	_sheet.visible = false
	add_child(_sheet)

func _draw_wait() -> float:
	return -log(1.0-_rng.randf()*0.98)*every if every > 0.0 else INF

## Whether one is under way.
func active() -> bool:
	return _length > 0.0

## One on the plane now (`length` s; <0 draws one).
func drop(length := -1.0) -> void:
	_length = length if length > 0.0 else _rng.randf_range(LENGTH.x,LENGTH.y)
	_t = 0.0
	_flash_wait = _rng.randf_range(FIRST_FLASH.x,FIRST_FLASH.y)+CLOSE
	count += 1

## Each frame: `core` is how deep in a cell's or the front's core the plane
## is (their storm_at, 0 to 1), `wind` the air's (m/s) for the wisps.
func step(delta: float, core: float, wind: Vector3) -> void:
	_frames += 1
	if _frames == _drop_at: drop(LENGTH.y if _hold >= 0.0 else -1.0)
	if active():
		_t += delta
		murk = smoothstep(0.0,CLOSE,_t)*(1.0-smoothstep(_length-OPEN,_length,_t))
		_flashes(delta)
		if _t >= _length:
			_length = 0.0
			_rest = REST
	else:
		murk = 0.0
		_rest -= delta
		if core > CORE and _rest <= 0.0 and _drop_at < 0:
			_wait -= delta
			if _wait <= 0.0:
				drop()
				_wait = _draw_wait()
	if _hold >= 0.0 and active():
		murk = _hold
		_t = minf(_t,_length*0.5)
	_sheet.visible = murk > 0.001
	if not _sheet.visible: return
	_material.set_shader_parameter("murk",murk)
	_material.set_shader_parameter("drift",wind)
	if lightning != null:
		_material.set_shader_parameter("flash",lightning.flash)
		_material.set_shader_parameter("flash_at",lightning.flash_position)

func _flashes(delta: float) -> void:
	if lightning == null or murk < 0.5: return
	_flash_wait -= delta
	if _flash_wait > 0.0: return
	_flash_wait = maxf(-log(1.0-_rng.randf()*0.98)*FLASH_EVERY,0.7)
	var camera: Camera3D = _scene.get("camera")
	if camera == null: return
	var eye := camera.global_position
	var a := _rng.randf_range(-PI,PI)
	var spot := eye+Vector3(cos(a),0.0,sin(a))*_rng.randf_range(FLASH_OFF.x,FLASH_OFF.y)
	# "inside" over a placed spot flashes 60 to 280 m over `root_y`: round
	# the plane's height.
	lightning.strike_over(spot,"inside",eye.y-170.0,eye.y)
	flashes += 1
