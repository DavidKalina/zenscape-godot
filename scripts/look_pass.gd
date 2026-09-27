extends Node
## Phase 1 look pass: the same look, finished better. Contact occlusion, a
## silhouette rim and wet banks in the surface shader, shoreline foam on still
## water, hazed ridges on the sky's horizon, a per-hour grade, vignette and
## light shafts in the display-fog blend, glow that water and alpenglow can
## reach, and on Ultra a dense meadow of GPU-placed grass.
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
var ridges := 0.85
var shore := 1.0
var _scene: Node3D
## The grade alone, drawn only while native volumetric fog (the redwood and
## woodland mist) hides the display-fog blend that normally carries it.
var _grade_layer := CanvasLayer.new()
var _grade := ShaderMaterial.new()
var _water_map: Texture2D
## Dense meadow grass: full on Ultra, and at reduced density on Beauty while
## `beauty_grass` is on. Off by default until its first render is fixed: on
## 2026-09-26 its tufts and flower faces drew metres wide and lying flat
## across the Genesis plain. `--beauty-grass` turns it on. Balanced never
## draws it, so the Mac keeps a cheap tier. See docs/scenic/grass-look.md.
var grass = preload("res://scripts/dense_grass.gd").new()
var beauty_grass := _flag("--beauty-grass") and not (_flag("--no-beauty-grass") or _flag("--classic-grass"))
var _last_update := 0
## The grass setup last logged, so the log line prints once at startup and
## again only when the tier or the dense grass changes.
var _grass_logged := -1

func setup(scene: Node3D) -> void:
	_scene = scene
	# In the tree so it is freed with the scene, along with what it holds.
	name = "LookPass"
	scene.add_child(self)
	_grade.shader = preload("res://shaders/look_grade.gdshader")
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _grade
	_grade_layer.name = "LookGrade"
	_grade_layer.layer = 0
	_grade_layer.visible = false
	_grade_layer.add_child(rect)
	scene.add_child(_grade_layer)
	grass.setup(scene)

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
	_update_ridges(on)
	var now := Time.get_ticks_usec()
	grass.set_reduced(tier != 2)
	var dense := enabled and (tier == 2 or (tier == 0 and beauty_grass))
	grass.update(dense, 0.0 if _last_update == 0 else (now - _last_update) / 1000000.0)
	_log_grass(dense)
	_last_update = now
	RenderingServer.global_shader_parameter_set("zs_look_shore", shore * on)
	# The chunk editor updates this texture in place; a regrow may replace it.
	var water_map: Texture2D = _scene._precipitation.ground_texture
	if water_map != null and water_map != _water_map:
		_water_map = water_map
		RenderingServer.global_shader_parameter_set("zs_water_map", water_map)
	var fog: CanvasLayer = _scene._display_fog
	var blended := fog != null and fog.visible
	_grade_layer.visible = enabled and not blended
	var target: ShaderMaterial = fog.blend if blended else _grade
	target.set_shader_parameter("grade_strength", grade * on)
	target.set_shader_parameter("vignette", vignette * on)
	target.set_shader_parameter("grade_saturation", saturation)
	# Highlights lean toward the hour's sun, shadows toward its sky: warm and
	# cool at golden hour, nearly neutral at noon and under overcast.
	target.set_shader_parameter("grade_highlight", _tint(celestial.aerial_sun_color, 0.35))
	target.set_shader_parameter("grade_shadow", _tint(celestial.state.get("zs_hemi_sky",Vector3.ONE), 0.22))
	# Native fog draws its own shafts from the lights' volumetric energy.
	if not blended: return
	var blend: ShaderMaterial = fog.blend
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

static func _flag(name: String) -> bool:
	return name in OS.get_cmdline_user_args() or name in OS.get_cmdline_args()

## Say which grass is on, so a film or a play session can tell: the tier,
## whether the dense GPU meadow draws and at what cover, and which tuft.
func _log_grass(dense: bool) -> void:
	var state := tier * 2 + int(dense)
	if state == _grass_logged: return
	_grass_logged = state
	var cover := "off"
	if dense: cover = "full cover" if tier == 2 else "reduced cover (--beauty-grass)"
	elif tier == 0: cover = "off (--beauty-grass turns it on)"
	elif tier == 1: cover = "off on Balanced"
	var line := "Grass: tier %s, dense meadow %s, tufts %s" % [["Beauty","Balanced","Ultra"][clampi(tier,0,2)], cover, preload("res://scripts/grass_tuft_mesh.gd").describe()]
	print(line)

## The sky's horizon ridges follow the world: its terrain seed picks the
## skyline and its relief how tall the hills stand.
func _update_ridges(on: float) -> void:
	var sky: ShaderMaterial = _scene._environment.sky.sky_material if _scene._environment.sky != null else null
	if sky == null: return
	var editor = _scene.get("_chunk_editor")
	var settings: Dictionary = editor.data._recipe_settings if editor != null else {}
	var state := Vector3(ridges * on, float(int(settings.get("seed", 0)) % 997), clampf(float(settings.get("relief", 1.0)), 0.5, 1.4))
	if sky.get_meta("look_ridges", Vector3(-1, -1, -1)) == state: return
	sky.set_meta("look_ridges", state)
	sky.set_shader_parameter("horizon_ridges", state.x)
	sky.set_shader_parameter("horizon_seed", state.y)
	sky.set_shader_parameter("horizon_relief", state.z)

## A color's hue at unit luminance, pulled `amount` of the way from white.
func _tint(color: Variant, amount: float) -> Vector3:
	var value := Vector3(color.x, color.y, color.z) if color is Vector3 else Vector3(color.r, color.g, color.b)
	var luma := value.dot(Vector3(0.2126, 0.7152, 0.0722))
	if luma <= 0.0001: return Vector3.ONE
	return Vector3.ONE.lerp(value / luma, amount)
