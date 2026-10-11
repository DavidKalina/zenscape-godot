extends Node3D
## The unified cloud volume (default; `--old-clouds` for the old renderers): the near cloud sea
## (scripts/sky_sea.gd) and the towering cumulus (scripts/sky_towers.gd)
## drawn as one raymarched body of cloud instead of a box each, so a tower
## rises out of the sea as the same cloud, shades the heaps round its foot,
## and can be flown into, through and out of without a seam.
##
## The march runs on the camera's compositor (scripts/cloud_volume_effect
## .gd, shaders/cloud_volume_march.glsl) at half the render size each axis
## after the opaque pass, resolved over frames (shaders/
## cloud_volume_resolve.glsl), and is drawn into the scene by a sheet over
## the screen (shaders/cloud_volume_composite.gdshader) in the see-through
## pass at the near sea's render priority, coloured there in the sky's own
## palettes and the player's sea style.
##
## The sea and the towers keep their lives and data: the sea still follows
## the eye and bakes its envelope and swells, the towers still rise, stand
## and wane, bake their bodies and lift the glide in their thermals, and
## every CPU query (`fade`, `depth`, `in_cloud`) is theirs as before. Only
## their own drawing is switched off (`_hide`), and their textures and
## uniforms are read from them each frame (`update`). The look pass
## (scripts/look_pass.gd) makes this unless --old-clouds is given and updates it
## after the near sea.

const SkySea = preload("res://scripts/sky_sea.gd")
const CloudVolumeEffect = preload("res://scripts/cloud_volume_effect.gd")
const CumulusNoise = preload("res://scripts/cumulus_noise.gd")
## On by default; this flag brings back the old near sea and towers. With no
## RenderingDevice (headless, the Compatibility renderer) there is no compute
## pass, so the old ones draw too.
const OLD_FLAG := "--old-clouds"
## Drawn where the near sea drew (SkySea RENDER_PRIORITY): before the
## towers' old slot, the streaks and wisps.
const RENDER_PRIORITY := SkySea.RENDER_PRIORITY
## At most this many towers marched (nearest first; each brings its own
## body texture), and wake points (CloudWakes COUNT: the whole trail).
const TOWERS := 4
const WAKES := 32
## How much of this frame's march goes into a pixel: one marched this
## frame, and one only upsampled from the march round it (the rest last
## frame's, reprojected).
const MARCHED_BLEND := 0.5
const UPSAMPLED_BLEND := 0.08
## The wakes looked for round the eye (m).
const WAKE_REACH := 900.0
## The weather map's square round the eye: the sea's reach and this much
## past it (m) each side.
const WEATHER_PAST := 200.0
## Where the cloud's shade on the land splits (m): shade from cloud on high
## (towers) and from the heaps below it, so land over the heaps' crowns
## takes only the towers'.
const SHADE_SPLIT := -55.0
## Per quality tier (LookPass tier: 0 Beauty, 1 Balanced, 2 Ultra): march
## steps, light taps toward the sun, the march's scale (2: half the render
## each axis, a pixel of each 2x2 block a frame; 1: every pixel), and the
## fine octaves near the eye.
const TIERS := [
	[120,6,2,1],
	[88,4,2,0],
	[150,6,2,1],
]
## The weather map is redrawn every this many frames, the shade on the
## land every this many (every frame for now; a lighter tier may skip).
const WEATHER_EVERY := 1
const SHADE_EVERY := 1
## --cloud-full-res marches every pixel every frame, at any tier.
const FULL_RES_FLAG := "--cloud-full-res"

var effect := CloudVolumeEffect.new()
var material := ShaderMaterial.new()
var sheet := MeshInstance3D.new()
var camera: Camera3D
var sea: Node
var towers: Node
var wakes: Node
var celestial
var motion_time := 0.0
## The glide's flight over the sea (scripts/sky_flight.gd `flight`, the
## global zs_sea_flight): w how far the heaps part under a falling glide.
var sea_flight := Vector4.ZERO
## How many towers and wake points went to the march last frame.
var tower_count := 0
var wake_count := 0
## Off, the sea and the towers draw themselves again (`set_enabled`, for a
## before/after in one run).
var enabled := true
## The quality tier (`set_tier`) and its row of TIERS.
var tier := 0
var quality: Array = TIERS[0]
var full_res := FULL_RES_FLAG in preload("res://scripts/launch_args.gd").user_args()
## The storm's lightning (studies/lightning.gd: `flash`, `flash_position`),
## lighting the cloud from within; null where there is none.
var lightning: Object
## The weather map's square this frame: corner xz, side (m).
var weather_corner := Vector2.ZERO
var weather_side := 0.0
var _frame := 0
var _prev_view := Projection.IDENTITY
var _prev_lens := Vector2.ONE
var _has_prev := false

static func wanted() -> bool:
	return not OLD_FLAG in preload("res://scripts/launch_args.gd").user_args() and RenderingServer.get_rendering_device() != null

func _init() -> void:
	name = "CloudVolume"
	material.shader = preload("res://shaders/cloud_volume_composite.gdshader")
	material.render_priority = RENDER_PRIORITY
	material.set_shader_parameter("cloud_light",effect.resolved_a)
	material.set_shader_parameter("cloud_shape",effect.resolved_b)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	sheet.name = "Sheet"
	sheet.mesh = quad
	sheet.material_override = material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.ignore_occlusion_culling = true
	# Drawn over the whole screen wherever the camera looks: never culled.
	sheet.custom_aabb = AABB(Vector3.ONE*-1e6,Vector3.ONE*2e6)
	sheet.visible = false
	add_child(sheet)

func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_before_draw):
		RenderingServer.frame_pre_draw.connect(_before_draw)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw):
		RenderingServer.frame_pre_draw.disconnect(_before_draw)
	_detach()
	_publish_shade(false)

## Each frame, after the near sea has followed the eye: the camera, the
## sea, and the scene's cloud host (scripts/cloud_host.gd: the old game's
## SkyIslands, or a laid sky's host), whose towers and wakes it reads.
func update(view: Camera3D, near_sea: Node, host: Node, sky, time: float, flight := Vector4.ZERO) -> void:
	sea_flight = flight
	if view != camera:
		_detach()
		camera = view
		_attach()
	sea = near_sea
	celestial = sky
	motion_time = time
	towers = host.get("towers") if host != null else null
	wakes = host.get("wakes") if host != null else null
	if not enabled:
		sheet.visible = false
		return
	_hide()
	var sea_on: bool = sea != null and sea.visible
	sheet.visible = camera != null and (sea_on or (towers != null and towers.get("built") is Dictionary and not (towers.built as Dictionary).is_empty()))

## The quality tier (LookPass tier: 0 Beauty, 1 Balanced, 2 Ultra).
func set_tier(index: int) -> void:
	tier = clampi(index,0,TIERS.size()-1)
	quality = TIERS[tier]

## The march's scale this frame: 2 half the render each axis, 1 every pixel.
func march_scale() -> int:
	return 1 if full_res else int(quality[2])

## Turns the volume on or off; off, the sea and the towers draw themselves.
func set_enabled(on: bool) -> void:
	if on == enabled: return
	enabled = on
	if on:
		_attach()
		effect.history_ok = false
		_has_prev = false
		return
	_detach()
	sheet.visible = false
	_publish_shade(false)
	if sea != null and sea is MeshInstance3D: (sea as MeshInstance3D).mesh = sea.get("_box")
	if towers != null and towers.get("built") is Dictionary:
		for b: Dictionary in (towers.built as Dictionary).values():
			var node: Node3D = b.get("node")
			if node == null or not is_instance_valid(node): continue
			var volume := node.get_node_or_null("Volume") as Node3D
			if volume != null: volume.visible = true

## The sea's and the towers' own drawing off; their lives go on.
func _hide() -> void:
	if sea != null and sea is MeshInstance3D and (sea as MeshInstance3D).mesh != null:
		(sea as MeshInstance3D).mesh = null
	if towers != null and towers.get("built") is Dictionary:
		for b: Dictionary in (towers.built as Dictionary).values():
			var node: Node3D = b.get("node")
			if node == null or not is_instance_valid(node): continue
			var volume := node.get_node_or_null("Volume") as Node3D
			if volume != null and volume.visible: volume.visible = false

func _attach() -> void:
	if camera == null: return
	var compositor := camera.compositor
	if compositor == null:
		compositor = Compositor.new()
		camera.compositor = compositor
	var effects := compositor.compositor_effects
	if not effects.has(effect):
		effects.append(effect)
		compositor.compositor_effects = effects

func _detach() -> void:
	if camera == null or not is_instance_valid(camera) or camera.compositor == null: return
	var effects := camera.compositor.compositor_effects
	if effects.has(effect):
		effects.erase(effect)
		camera.compositor.compositor_effects = effects

## True once the camera's compositor carries the march.
func attached() -> bool:
	return camera != null and camera.compositor != null and camera.compositor.compositor_effects.has(effect)

# --- Each frame, just before drawing --------------------------------------------------

func _before_draw() -> void:
	if camera == null or not is_instance_valid(camera) or not sheet.visible: return
	var window := camera.get_window()
	var viewport := camera.get_viewport()
	var physical := Vector2(window.size) if window != null else Vector2(1280,720)
	var scale := viewport.scaling_3d_scale if viewport != null else 1.0
	effect.resize(Vector2i((physical*scale).round()),march_scale())
	_fill()

## The march's parameters (shaders/cloud_volume_march.glsl Params) and the
## resolve's, and the composite's few, from the camera, the sea, the towers
## and the sky as they stand this frame.
func _fill() -> void:
	var p := effect.march_params
	p.fill(0.0)
	var xf := camera.global_transform
	var aspect := 16.0/9.0
	var window := camera.get_window()
	if window != null and window.size.y > 0: aspect = float(window.size.x)/window.size.y
	var tan_y := tan(deg_to_rad(camera.fov)*0.5)
	var tan_x := tan_y*aspect
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		tan_x = tan_y
		tan_y = tan_x/aspect
	_put_transform(p,0,xf)
	var eye := xf.origin
	var sun: Vector3 = Vector3.UP
	var moon: Vector3 = Vector3.DOWN
	if celestial != null and celestial.get("state") is Dictionary:
		sun = celestial.state.get("zs_sun_direction",Vector3.UP)
		moon = celestial.state.get("zs_moon_direction",Vector3.DOWN)
	# The deep night the sea's veil follows: night under a clear sky.
	var night := 0.0
	if celestial != null and celestial.get("state") is Dictionary:
		night = float(celestial.state.get("zs_night",0.0))*float(celestial.state.get("zs_celestial_clear",1.0))
	var dull: float = float(celestial.get("cloud")) if celestial != null and celestial.get("cloud") != null else 0.0
	var part := sea_flight.w
	var key := sun.normalized().lerp(moon.normalized(),smoothstep(0.05,-0.1,sun.normalized().y)).normalized()
	_put4(p,16,Vector4(tan_x,tan_y,camera.near,camera.far))
	_put4(p,20,Vector4(eye.x,eye.y,eye.z,motion_time))
	_put4(p,24,Vector4(sun.x,sun.y,sun.z,dull))
	_put4(p,28,Vector4(key.x,key.y,key.z,part))
	var strength := 0.0
	var style := 0
	if sea != null and sea.visible:
		var m: ShaderMaterial = sea.material
		strength = float(m.get_shader_parameter("cloud_sea"))
		style = int(m.get_shader_parameter("cloud_sea_style"))
		_put4(p,32,Vector4(SkySea.FLOOR,SkySea.TALL,float(sea.reach),strength))
		var has_noise: Variant = m.get_shader_parameter("has_noise")
		_put4(p,36,Vector4(eye.x,eye.z,0.55,float(has_noise) if has_noise != null else 0.0))
		_put4(p,40,_v4(m.get_shader_parameter("envelope_at")))
		_put4(p,44,_v4(m.get_shader_parameter("swells_at")))
		var spots: Variant = m.get_shader_parameter("islands")
		if spots is PackedVector4Array:
			for i in range(mini((spots as PackedVector4Array).size(),8)): _put4(p,52+i*4,spots[i])
	else:
		_put4(p,32,Vector4(SkySea.FLOOR,SkySea.TALL,SkySea.REACH,0.0))
	var bodies := []
	var noise: Texture = CumulusNoise.request()
	if noise != null and p[39] < 0.5: p[39] = 1.0
	tower_count = 0
	if towers != null and towers.get("built") is Dictionary:
		var list := []
		for b: Dictionary in (towers.built as Dictionary).values():
			var node: Node3D = b.get("node")
			if node == null or not is_instance_valid(node) or float(b.get("wane",0.0)) >= 1.0: continue
			list.append(b)
		list.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return (a.node as Node3D).global_position.distance_squared_to(eye) < (c.node as Node3D).global_position.distance_squared_to(eye))
		for b: Dictionary in list.slice(0,TOWERS):
			var m: ShaderMaterial = b.material
			var i := tower_count
			var at := (b.node as Node3D).global_position
			_put4(p,84+i*4,Vector4(at.x,at.y,at.z,float(m.get_shader_parameter("strength"))))
			var mid: Vector3 = m.get_shader_parameter("box_mid")
			var half: Vector3 = m.get_shader_parameter("box_half")
			var shift: Vector3 = m.get_shader_parameter("noise_shift")
			_put4(p,100+i*4,Vector4(mid.x,mid.y,mid.z,float(m.get_shader_parameter("morph"))))
			_put4(p,116+i*4,Vector4(half.x,half.y,half.z,float(m.get_shader_parameter("wane"))))
			_put4(p,132+i*4,Vector4(shift.x,shift.y,shift.z,float(m.get_shader_parameter("lift"))))
			_put4(p,148+i*4,Vector4(float(m.get_shader_parameter("sea")),float(m.get_shader_parameter("top")),0.0,0.0))
			bodies.append(m.get_shader_parameter("body"))
			tower_count += 1
	wake_count = 0
	if wakes != null and wakes.has_method("near_box"):
		var top := SkySea.FLOOR+600.0
		var middle := Vector3(eye.x,(SkySea.FLOOR+top)*0.5,eye.z)
		var near: Array = wakes.near_box(middle,Vector3(WAKE_REACH,(top-SkySea.FLOOR)*0.5,WAKE_REACH),motion_time,WAKES)
		wake_count = int(near[2])
		for i in range(wake_count):
			_put4(p,180+i*4,near[0][i])
			_put4(p,308+i*4,near[1][i])
	_put4(p,48,Vector4(_frame,tower_count,wake_count,night))
	# The weather map's square, snapped to its texels so it never swims;
	# moved only on a frame it is redrawn, so the march always reads it
	# where it was drawn.
	var weather_due := _frame%WEATHER_EVERY == 0 or weather_side == 0.0
	var shade_due := _frame%SHADE_EVERY == 0
	if weather_due:
		var reach_now: float = float(sea.reach) if sea != null else SkySea.REACH
		weather_side = (reach_now+WEATHER_PAST)*2.0
		var texel := weather_side/CloudVolumeEffect.WEATHER_TEXELS
		weather_corner = ((Vector2(eye.x,eye.z)-Vector2.ONE*weather_side*0.5)/texel).floor()*texel
	_put4(p,164,Vector4(weather_corner.x,weather_corner.y,weather_side,CloudVolumeEffect.WEATHER_TEXELS))
	_put4(p,168,Vector4(quality[0],quality[1],march_scale(),quality[3]))
	var flash := Vector4.ZERO
	if lightning != null and is_instance_valid(lightning) and lightning.get("flash") != null:
		var at: Vector3 = lightning.get("flash_position")
		flash = Vector4(at.x,at.y,at.z,float(lightning.get("flash")))
	_put4(p,172,flash)
	_put4(p,176,Vector4(SHADE_SPLIT,CloudVolumeEffect.SHADOW_TEXELS,1.0 if weather_due else 0.0,1.0 if shade_due else 0.0))
	# The land reads the shade map the frame after it is drawn (it is drawn
	# after the land), at the square it was drawn over.
	var shading: bool = sea != null and strength > 0.0 or tower_count > 0
	if _shade_drawn != Vector4.ZERO or not shading: _publish_shade(shading,key,_shade_drawn)
	_shade_drawn = Vector4(weather_corner.x,weather_corner.y,weather_side,1.0) if shade_due and shading else Vector4.ZERO
	_frame = (_frame+1)%4096
	var sea_material: ShaderMaterial = sea.material if sea != null else null
	# The bakes only once drawn (their render targets are made by then).
	var baked := sea_material != null and p[43] > 0.5
	effect.set_inputs(sea_material.get_shader_parameter("envelope") if baked else null,
		sea_material.get_shader_parameter("swells") if sea_material != null and p[47] > 0.5 else null,noise,bodies)
	# The resolve: this frame's camera, last frame's view.
	var r := effect.resolve_params
	_put_transform(r,0,xf)
	_put_projection(r,16,_prev_view)
	_put4(r,32,Vector4(tan_x,tan_y,UPSAMPLED_BLEND,1.0 if _has_prev else 0.0))
	_put4(r,36,Vector4(_prev_lens.x,_prev_lens.y,0.0,0.0))
	_put4(r,40,Vector4(eye.x,eye.y,eye.z,p[48]))
	_put4(r,44,Vector4(camera.near,camera.far,MARCHED_BLEND,march_scale()))
	if not _has_prev: effect.history_ok = false
	_prev_view = Projection(xf.affine_inverse())
	_prev_lens = Vector2(tan_x,tan_y)
	_has_prev = true
	material.set_shader_parameter("cloud_sea",strength)
	material.set_shader_parameter("cloud_sea_style",style)
	material.set_shader_parameter("reach",float(sea.reach) if sea != null else SkySea.REACH)
	material.set_shader_parameter("floor_y",SkySea.FLOOR)
	material.set_shader_parameter("key_light",key)
	sheet.global_position = eye

## The cloud's shade on the land (shaders/cloud_volume_shadow.gdshaderinc):
## the shade map, its square, and the light and the sea's feet it looks up
## from; off, the land takes none.
## What the land was last told (zs_cloud_shadow_at): corner xz, side, on;
## and the square of the shade map drawn last frame, still to tell it.
var shade_at := Vector4.ZERO
var _shade_drawn := Vector4.ZERO
var _shade_published := false
func _publish_shade(on: bool, light := Vector3.UP, square := Vector4.ZERO) -> void:
	if not on:
		if _shade_published: RenderingServer.global_shader_parameter_set("zs_cloud_shadow_at",Vector4.ZERO)
		_shade_published = false
		shade_at = Vector4.ZERO
		return
	if not _shade_published:
		RenderingServer.global_shader_parameter_set("zs_cloud_shadow",effect.shadow)
	_shade_published = true
	shade_at = square
	RenderingServer.global_shader_parameter_set("zs_cloud_shadow_at",shade_at)
	RenderingServer.global_shader_parameter_set("zs_cloud_shadow_light",Vector4(light.x,light.y,light.z,SkySea.FLOOR))

static func _v4(value: Variant) -> Vector4:
	return value if value is Vector4 else Vector4.ZERO

static func _put4(p: PackedFloat32Array, at: int, v: Vector4) -> void:
	p[at] = v.x
	p[at+1] = v.y
	p[at+2] = v.z
	p[at+3] = v.w

## A transform as a column-major mat4.
static func _put_transform(p: PackedFloat32Array, at: int, xf: Transform3D) -> void:
	_put_projection(p,at,Projection(xf))

static func _put_projection(p: PackedFloat32Array, at: int, m: Projection) -> void:
	_put4(p,at,m.x)
	_put4(p,at+4,m.y)
	_put4(p,at+8,m.z)
	_put4(p,at+12,m.w)
