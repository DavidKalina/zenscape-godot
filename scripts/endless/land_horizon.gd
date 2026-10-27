extends Node
## The land's shadows past the sun's shadow map, and its sky shade
## (docs/design/endless-flight/horizon-shadows-demo.md). The sun's map reaches
## SHADOW_REACH (EndlessLook) and only the near chunks cast into it, so a
## range never shades the valley past it. Here a square of the field's heights
## round the eye (SIDE m, TEXELS a side, made on a worker) is marched on the
## GPU (shaders/land_horizon_bake.gdshader, a SubViewport) for the land's
## horizon toward the key light's bearing, and in eight ways for how much sky
## each spot sees. The land reads it (shaders/land_horizon.gdshaderinc, the
## zs_horizon globals) against the light's height each frame, so the shadows
## slide as the sun sinks.
##
## The square is made again when the eye has gone MOVE of its side from its
## middle; the march again when the light's bearing has turned TURN degrees.
## Each march goes into the other of two viewports and fades in over the last
## for FADE s, so neither pops.
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
const TURN := 0.25
const FADE := 1.0
## Occluders nearer a spot than this (m) are left to the sun's own map near
## the eye (the march's far-only horizon, blue).
const NEAR := 220.0

static func wanted() -> bool:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--terrain-shadows="): return a.get_slice("=",1) != "0"
	return false

var on := true
var side := SIDE
var texels := TEXELS
## Added to the eye (m, xz): a driver moves the square without the camera.
var eye_shift := Vector2.ZERO
var _seed := 0
var _views: Array[SubViewport] = []
var _bakes: Array[ShaderMaterial] = []
## The viewport shown as the newest march, and how far it has faded in.
var _now := 0
var _fade := 1.0
var _task := -1
var _made: Dictionary = {}
var _made_lock := Mutex.new()
## The newest heights and their square (corner xz, side), and whether a march
## of them is still owed.
var _heights: Texture2D
var _heights_at := Vector4.ZERO
var _due := false
## The squares drawn now (corner xz, side, 1 when drawn) and the light's
## bearing the newest was marched for.
var _at := Vector4.ZERO
var _was_at := Vector4.ZERO
var _bearing := Vector2.ZERO
var _key := Vector3.UP
var _asked_at := Vector2.INF

func setup(land_seed: int) -> void:
	name = "Horizon"
	_seed = land_seed
	side = SIDE*LandStream.view()
	if not Field.new(land_seed)._native: texels = TEXELS_SLOW
	for i in 2:
		var view := SubViewport.new()
		view.size = Vector2i(texels,texels)
		view.disable_3d = true
		view.transparent_bg = false
		# Half floats: the horizon's tangent runs past 1.
		view.use_hdr_2d = true
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(view)
		var rect := ColorRect.new()
		rect.size = Vector2(texels,texels)
		var bake := ShaderMaterial.new()
		bake.shader = preload("res://shaders/land_horizon_bake.gdshader")
		bake.set_shader_parameter("sea_y",Field.SEA_Y)
		bake.set_shader_parameter("near",NEAR)
		rect.material = bake
		view.add_child(rect)
		_views.append(view)
		_bakes.append(bake)
	_publish()

func _exit_tree() -> void:
	if _task >= 0: WorkerThreadPool.wait_for_task_completion(_task)
	RenderingServer.global_shader_parameter_set("zs_horizon_at",Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("zs_horizon_was_at",Vector4.ZERO)

func toggle() -> void:
	on = not on
	print("terrain shadows %s" % ("on" if on else "off"))
	_publish()

## One frame: a new square asked for when the eye has wandered, a finished
## one taken, the march redone when the light (`key`, sun or moon) has turned
## (once the last has faded in), the fade carried on.
func step(eye: Vector3, key: Vector3, delta: float) -> void:
	_key = key.normalized()
	var middle := Vector2(eye.x,eye.z)+eye_shift
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
		if not made.is_empty():
			var image := Image.create_from_data(texels,texels,false,Image.FORMAT_RF,(made.heights as PackedFloat32Array).to_byte_array())
			_heights = ImageTexture.create_from_image(image)
			var corner: Vector2 = made.corner
			_heights_at = Vector4(corner.x,corner.y,side,1.0)
			_due = true
	var bearing := Vector2(_key.x,_key.z).normalized()
	if _at.w > 0.0 and bearing.dot(_bearing) < cos(deg_to_rad(TURN)): _due = true
	_fade = minf(_fade+delta/FADE,1.0)
	if _due and _fade >= 1.0 and _heights != null:
		_due = false
		_march(bearing)
	_publish()

## The march into the viewport not shown, which becomes the newest; the one
## shown fades out under it.
func _march(bearing: Vector2) -> void:
	var into := 1-_now if _at.w > 0.0 else _now
	var bake := _bakes[into]
	bake.set_shader_parameter("heights",_heights)
	bake.set_shader_parameter("texel",side/texels)
	bake.set_shader_parameter("light",_key)
	_views[into].render_target_update_mode = SubViewport.UPDATE_ONCE
	_bearing = bearing
	_was_at = _at
	_at = _heights_at
	_fade = 0.0 if _was_at.w > 0.0 else 1.0
	_now = into
	RenderingServer.global_shader_parameter_set("zs_horizon",_views[_now].get_texture())
	RenderingServer.global_shader_parameter_set("zs_horizon_was",_views[1-_now].get_texture())

func _publish() -> void:
	var shown := 1.0 if on and _at.w > 0.0 else 0.0
	var was := (1.0-smoothstep(0.0,1.0,_fade)) if _was_at.w > 0.0 else 0.0
	RenderingServer.global_shader_parameter_set("zs_horizon_at",Vector4(_at.x,_at.y,_at.z,shown))
	RenderingServer.global_shader_parameter_set("zs_horizon_was_at",Vector4(_was_at.x,_was_at.y,_was_at.z,was))
	RenderingServer.global_shader_parameter_set("zs_horizon_key",_key)

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
