extends Node
## Phase 1 look pass: the same look, finished better. Contact occlusion and a
## silhouette rim in the surface shader, a per-hour grade, vignette and light
## shafts in the display-fog blend, and glow that water and alpenglow can reach.
## F6 toggles the whole pass for a direct before/after.
var enabled := "--no-look-pass" not in OS.get_cmdline_user_args()
## Tier from the quality setting: 0 Beauty, 1 Balanced, 2 Ultra.
var tier := 1
var ao := 0.8
var rim := 0.35
var grade := 0.55
var saturation := 1.06
var vignette := 0.16
var rays := 0.22
var _scene: Node3D

func setup(scene: Node3D) -> void:
	_scene = scene

func toggle() -> void:
	enabled = not enabled
	apply_tier(tier)

## Glow, SSAO, MSAA and fog resolution follow the tier; the shader terms are
## cheap enough to run in all of them.
func apply_tier(index: int) -> void:
	tier = index
	var environment: Environment = _scene._environment
	var rich := enabled and tier != 1
	environment.glow_enabled = rich or (not enabled and tier == 0)
	environment.glow_intensity = 0.3 if enabled else 0.12
	environment.glow_hdr_threshold = 1.0 if enabled else 1.8
	environment.glow_bloom = 0.0
	for level in range(7): environment.set_glow_level(level, 1.0 if (level in [2,3,4] if enabled else level in [2,4]) else 0.0)
	# The reference materials take no ambient light, so SSAO only touches the
	# direct term; Ultra keeps it for that last bit of crease shading.
	environment.ssao_enabled = tier == 2 or (not enabled and tier == 0)
	_scene.get_viewport().msaa_3d = Viewport.MSAA_4X if tier == 2 else Viewport.MSAA_2X
	var fog: CanvasLayer = _scene._display_fog
	if fog != null and fog.buffer_scale != (0.75 if tier == 2 else 0.5):
		fog.buffer_scale = 0.75 if tier == 2 else 0.5
		fog.update_view()

func update(camera: Camera3D, celestial) -> void:
	var on := 1.0 if enabled else 0.0
	RenderingServer.global_shader_parameter_set("zs_look_ao", ao * on)
	RenderingServer.global_shader_parameter_set("zs_look_rim", rim * on)
	var fog: CanvasLayer = _scene._display_fog
	if fog == null: return
	var blend: ShaderMaterial = fog.blend
	blend.set_shader_parameter("grade_strength", grade * on)
	blend.set_shader_parameter("vignette", vignette * on)
	blend.set_shader_parameter("grade_saturation", saturation)
	# Highlights lean toward the hour's sun, shadows toward its sky: warm and
	# cool at golden hour, nearly neutral at noon and under overcast.
	blend.set_shader_parameter("grade_highlight", _tint(celestial.aerial_sun_color, 0.35))
	blend.set_shader_parameter("grade_shadow", _tint(celestial.state.get("zs_hemi_sky",Vector3.ONE), 0.22))
	var sun: Vector3 = celestial.state.get("zs_sun_direction",Vector3.UP)
	var ahead := enabled and tier != 1 and sun.y > -0.05 and not camera.is_position_behind(camera.global_position + sun * 400.0)
	blend.set_shader_parameter("rays_strength", rays if ahead else 0.0)
	if ahead:
		var screen: Vector2 = camera.unproject_position(camera.global_position + sun * 400.0) / camera.get_viewport().get_visible_rect().size
		# Shafts fade as the sun sinks or hides behind cloud.
		var cloud: float = celestial.cloud
		var strength := smoothstep(-0.05, 0.12, sun.y) * (1.0 - minf(cloud * 1.2, 0.9))
		blend.set_shader_parameter("rays_sun", Vector3(screen.x, screen.y, strength))
		blend.set_shader_parameter("rays_color", _tint(celestial.aerial_sun_color, 1.0) * 0.6)

## A color's hue at unit luminance, pulled `amount` of the way from white.
func _tint(color: Variant, amount: float) -> Vector3:
	var value := Vector3(color.x, color.y, color.z) if color is Vector3 else Vector3(color.r, color.g, color.b)
	var luma := value.dot(Vector3(0.2126, 0.7152, 0.0722))
	if luma <= 0.0001: return Vector3.ONE
	return Vector3.ONE.lerp(value / luma, amount)
