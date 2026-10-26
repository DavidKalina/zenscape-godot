extends Node
## The look's per-frame part (docs/design/endless-flight/clean-look-handoff.md):
## the tints the shaders read (zs_cl_warm, zs_cl_cool, zs_cl_haze_mid,
## zs_cl_haze_far), set each frame from the published light, the Environment's
## clear-then-thick haze and light glow, and the grade pass (clean_post.gd) on
## the camera where there is a RenderingDevice. There are no switches: it is
## the game's look. Built by studies/endless_flight.gd after the EndlessLook,
## which the title world shares.

const CleanPost = preload("res://scripts/endless/clean_post.gd")

## The Environment's haze: clear to FOG_BEGIN m, then thicker through the
## middle distance, bluer by the aerial share.
const FOG_BEGIN := 260.0
const FOG_CURVE := 0.52
const FOG_AERIAL := 0.7
const GLOW := 0.06

var look: Node3D
var camera: Camera3D
var post: CompositorEffect
var _env: Environment
var _applied := false

func setup(look_node: Node3D, view: Camera3D) -> void:
	name = "CleanLook"
	look = look_node
	camera = view
	_env = look.environment
	if CleanPost.available():
		post = CleanPost.new()
		post.camera = camera
		post.attach()
	_tints()
	_apply()

func _apply() -> void:
	_applied = true
	if _env == null: return
	_env.fog_depth_begin = FOG_BEGIN
	_env.fog_depth_curve = FOG_CURVE
	_env.fog_aerial_perspective = FOG_AERIAL
	_env.glow_intensity = GLOW

## The clean look's tints from the published light (celestial.state), each
## frame: the sun side from the key's colour, the shade from the sky's fill,
## the distance planes and the grade from both and the haze. Hue only, eased
## toward the plain colour, so the strength stays what the look chose.
## (At alpine_morning, hour 9.6, they come to the round 2 constants.)
const LUMA := Vector3(0.2126,0.7152,0.0722)
static func _rel(c: Vector3) -> Vector3:
	return c / maxf(c.dot(LUMA),0.02)

func _tints() -> void:
	if look == null or look.get("celestial") == null: return
	var st: Dictionary = look.celestial.state
	if not (st.has("zs_key_irradiance") and st.has("zs_hemi_sky")): return
	var sun_y := (st.zs_sun_direction as Vector3).y if st.has("zs_sun_direction") else 0.5
	var low := smoothstep(0.45,0.1,sun_y)
	var sun_rel := _rel(st.zs_key_irradiance)
	var sky_rel := _rel(st.zs_hemi_sky)
	var warm := Vector3.ONE.lerp(sun_rel,lerpf(0.12,0.30,low))
	var cool := Vector3.ONE.lerp(sky_rel,0.66)*Vector3(1.0,0.885,1.0)
	var haze := Vector3.ONE
	if _env != null:
		var h := _env.fog_light_color.srgb_to_linear()
		haze = _rel(Vector3(h.r,h.g,h.b)).clamp(Vector3(0.35,0.35,0.35),Vector3(2.2,2.2,2.2))
	var mid := Vector3.ONE.lerp(haze,0.12)*0.95
	var far := Vector3.ONE.lerp(haze,0.22)*0.84
	_publish_vec("zs_cl_warm",warm)
	_publish_vec("zs_cl_cool",cool)
	_publish_vec("zs_cl_haze_mid",mid)
	_publish_vec("zs_cl_haze_far",far)
	if post != null:
		post.tint_warm = Vector3.ONE.lerp(sun_rel,lerpf(0.15,0.28,low))*Vector3(1.0,1.03,1.0)
		post.tint_cool = Vector3.ONE.lerp(sky_rel,0.22)*Vector3(0.975,0.975,1.0)

static func _publish_vec(n: String, v: Vector3) -> void:
	RenderingServer.global_shader_parameter_set(n,v)

func _process(_delta: float) -> void:
	_tints()
	# Once more on the first frame, after the look's own set-up has settled.
	if not _applied: _apply()

func _exit_tree() -> void:
	if post != null: post.free_buffers()
