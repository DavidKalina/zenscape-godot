extends Node
## The land's shadows past the sun's shadow map, and its sky shade
## (docs/design/endless-flight/horizon-shadows-demo.md). The sun's map reaches
## SHADOW_REACH (EndlessLook) and only the near chunks cast into it, so a
## range never shades the valley past it. Here a square of the field's heights
## round the eye (SIDE m, TEXELS a side, made on a worker) is marched on the
## GPU (shaders/land_horizon_bake.gdshader, a SubViewport) toward the key
## light, and in eight ways for how much sky each spot sees. The land reads
## the result (shaders/land_horizon.gdshaderinc, the zs_horizon globals).
##
## The square is made again when the eye has gone MOVE of its side from its
## middle; the march again when the light has turned TURN degrees.
## --terrain-shadows=1 builds it; K turns it off and on in flight.

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LandStream = preload("res://scripts/endless/land_stream.gd")

## The square's side (m, times the draw distance) and its texels a side
## (fewer without the native field: its GDScript loop is slow).
const SIDE := 16384.0
const TEXELS := 1024
const TEXELS_SLOW := 192
const MOVE := 0.125
const TURN := 0.2
## Occluders nearer a spot than this (m) are left to the sun's own map near
## the eye (the march's far-only answer, blue).
const NEAR := 220.0

static func wanted() -> bool:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--terrain-shadows="): return a.get_slice("=",1) != "0"
	return false

var on := true
var side := SIDE
var texels := TEXELS
var _seed := 0
var _viewport: SubViewport
var _bake: ShaderMaterial
var _task := -1
var _made: Dictionary = {}
var _made_lock := Mutex.new()
## The square drawn now: corner xz, side; and the light it was marched for.
var _at := Vector4.ZERO
var _light := Vector3.ZERO
var _asked_at := Vector2.INF

func setup(land_seed: int) -> void:
	name = "Horizon"
	_seed = land_seed
	side = SIDE*LandStream.view()
	if not Field.new(land_seed)._native: texels = TEXELS_SLOW
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(texels,texels)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(texels,texels)
	_bake = ShaderMaterial.new()
	_bake.shader = preload("res://shaders/land_horizon_bake.gdshader")
	_bake.set_shader_parameter("sea_y",Field.SEA_Y)
	_bake.set_shader_parameter("near",NEAR)
	rect.material = _bake
	_viewport.add_child(rect)
	RenderingServer.global_shader_parameter_set("zs_horizon",_viewport.get_texture())
	RenderingServer.global_shader_parameter_set("zs_horizon_at",Vector4.ZERO)

func _exit_tree() -> void:
	if _task >= 0: WorkerThreadPool.wait_for_task_completion(_task)
	RenderingServer.global_shader_parameter_set("zs_horizon_at",Vector4.ZERO)

func toggle() -> void:
	on = not on
	print("terrain shadows %s" % ("on" if on else "off"))
	_publish()

## One frame: a new square asked for when the eye has wandered, a finished
## one taken, the march redone when the light (`key`, sun or moon) has turned.
func step(eye: Vector3, key: Vector3) -> void:
	var middle := Vector2(eye.x,eye.z)
	var texel := side/texels
	if _task < 0 and (_asked_at == Vector2.INF or middle.distance_to(_asked_at) > side*MOVE):
		_asked_at = middle
		var corner := ((middle-Vector2.ONE*side*0.5)/texel).floor()*texel
		_task = WorkerThreadPool.add_task(_make.bind(corner,texel))
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_made_lock.lock()
		var made := _made
		_made = {}
		_made_lock.unlock()
		if not made.is_empty(): _take(made,key)
	if _at.w > 0.0 and key.normalized().dot(_light) < cos(deg_to_rad(TURN)):
		_march(key)
	_publish()

func _take(made: Dictionary, key: Vector3) -> void:
	var image := Image.create_from_data(texels,texels,false,Image.FORMAT_RF,(made.heights as PackedFloat32Array).to_byte_array())
	_bake.set_shader_parameter("heights",ImageTexture.create_from_image(image))
	_bake.set_shader_parameter("texel",side/texels)
	var corner: Vector2 = made.corner
	_at = Vector4(corner.x,corner.y,side,1.0)
	_march(key)

func _march(key: Vector3) -> void:
	_light = key.normalized()
	_bake.set_shader_parameter("light",_light)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_horizon_at",Vector4(_at.x,_at.y,_at.z,_at.w if on else 0.0))

# --- On a worker ----------------------------------------------------------------------

## The field's heights over the square from `corner`, texel by texel at
## their middles, row by row from its -z edge. Ponds, halls, tunnels and
## splits are left out: too small to shade the land from far.
func _make(corner: Vector2, texel: float) -> void:
	var began := Time.get_ticks_msec()
	var f: RefCounted = Field.new(_seed)
	f.detail = texel
	var got: Dictionary = f._grid(corner.x+texel*0.5,corner.y+texel*0.5,texel,texels,texels,0)
	print("terrain shadows: %d^2 heights in %d ms" % [texels,Time.get_ticks_msec()-began])
	_made_lock.lock()
	_made = {"heights":got.heights,"corner":corner}
	_made_lock.unlock()
