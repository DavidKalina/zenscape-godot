extends Node
## Phase 1 look pass: the same look, finished better. Contact occlusion, a
## silhouette rim and wet banks in the surface shader, shoreline foam on still
## water, hazed ridges on the sky's horizon, a per-hour grade, vignette and
## light shafts in the display-fog blend, glow that water and alpenglow can
## reach, and on Ultra a dense meadow of GPU-placed grass.
## F6 toggles the whole pass for a direct before/after.
var enabled := "--no-look-pass" not in preload("res://scripts/launch_args.gd").user_args()
## Tier from the quality setting: 0 Beauty, 1 Balanced, 2 Ultra.
var tier := 1
var ao := 0.8
var rim := 0.35
var grade := 0.55
var saturation := 1.06
var vignette := 0.16
## The light shafts' strength (shaders/reference_air_blend.gdshader); 0 for
## none. --rays=N tries another, --no-rays turns them off.
var rays := default_rays()
## The shafts' strength unless asked otherwise (was 0.22, when they only
## drew under the display-fog blend and took the air's colour).
const RAYS := 0.7
## The shafts' light at full strength: the sun's hue at this brightness.
const RAYS_LIGHT := 0.55
var ridges := 0.85
## The cloud sea under the floating plate (shaders/sky_cloud_sea.gdshaderinc):
## the backdrop the overview looks down into, below the ridges' reach.
## --no-cloud-sea leaves the old plain dome there, for a before/after.
var cloud_sea := 0.0 if _flag("--no-cloud-sea") else 1.0
## The cloud sea's style (shaders/sky_cloud_sea.gdshaderinc), the player's
## choice in Settings > Clouds, kept for every world in user://look.cfg.
## --cloud-style=opal|storybook|mystic picks one for a run (captures) and
## leaves the kept choice alone.
const CLOUD_STYLES := ["opal","storybook","mystic"]
const CLOUD_STYLE_NAMES := ["Opal","Storybook","Mystic"]
const SETTINGS_PATH := "user://look.cfg"
var cloud_style := cloud_style_from_args(preload("res://scripts/launch_args.gd").user_args() + OS.get_cmdline_args(), load_cloud_style())
## The night sky's style (shaders/night_sky.gdshaderinc, the global
## zs_night_style), chosen and kept like the clouds' in Settings > Night sky.
## --night-style=nocturne|opal|storybook|mystic picks one for a run.
const NIGHT_STYLES := ["nocturne","opal","storybook","mystic"]
const NIGHT_STYLE_NAMES := ["Nocturne","Opal","Storybook","Mystic"]
## The night until the player chooses.
const NIGHT_DEFAULT := "storybook"
var night_style := night_style_from_args(preload("res://scripts/launch_args.gd").user_args() + OS.get_cmdline_args(), load_night_style())
## The ringed planet (scripts/sky_objects.gd): off unless the player turns
## it on in Settings > Planet, kept in user://look.cfg. --sky-planet or
## --no-sky-planet for a run.
var sky_planet := sky_planet_from_args(preload("res://scripts/launch_args.gd").user_args() + OS.get_cmdline_args(), load_sky_planet())
## Where the choice is kept (tests point it elsewhere).
var settings_path := SETTINGS_PATH
## Motes of light adrift round the plate over the sea (scripts/sky_motes.gd),
## shown with the Mystic sea only.
var _motes = preload("res://scripts/sky_motes.gd").new()
## The near cloud sea (scripts/sky_sea.gd): the sea's heaps as a surface in
## the world round the eye, handing over to the dome's sea far out. It
## follows the camera and takes the sky's sea strength and style.
## --dome-sea leaves the dome's painted sea alone, for a before/after.
const SkySea = preload("res://scripts/sky_sea.gd")
var sea = SkySea.new()
var near_sea := not _flag("--dome-sea")
## The unified cloud volume (scripts/cloud_volume.gd): the near sea and the
## towers drawn as one marched body of cloud, the sea and towers keeping their
## lives and data. Null with --old-clouds or without a RenderingDevice.
const CloudVolume = preload("res://scripts/cloud_volume.gd")
var cloud_volume: Node3D = CloudVolume.new() if CloudVolume.wanted() else null
var shore := 1.0
var _scene: Node3D
## The grade alone, drawn only while native volumetric fog (the redwood and
## woodland mist) hides the display-fog blend that normally carries it.
var _grade_layer := CanvasLayer.new()
var _grade := ShaderMaterial.new()
var _water_map: Texture2D
## Dense meadow grass, retired unless requested: only `--beauty-grass`
## turns it on, at full cover on Ultra and reduced on Beauty. The user does
## not want blades by default, and its render is unfixed: on 2026-09-26 its
## tufts and flower faces drew metres wide and lying flat across the Genesis
## plain. Balanced never draws it. Off, it builds nothing (dense_grass.gd).
## See docs/scenic/grass-look.md.
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
	scene.add_child(_motes)
	scene.add_child(sea)
	if cloud_volume != null: scene.add_child(cloud_volume)
	grass.setup(scene)
	_publish_night_style()

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
	# Ultra marches the cloud deck at full resolution (docs/performance/gpu-headroom.md).
	if _scene.get("_lighting") != null: _scene._lighting.full_res_clouds = tier == 2
	if cloud_volume != null: cloud_volume.set_tier(tier)
	var fog: CanvasLayer = _scene._display_fog
	if fog != null and fog.buffer_scale != (0.75 if tier == 2 else 0.5):
		fog.buffer_scale = 0.75 if tier == 2 else 0.5
		fog.update_view()

func update(camera: Camera3D, celestial) -> void:
	var on := 1.0 if enabled else 0.0
	RenderingServer.global_shader_parameter_set("zs_look_ao", ao * on)
	RenderingServer.global_shader_parameter_set("zs_look_rim", rim * on)
	_update_ridges(on)
	_update_cloud_sea(on)
	_update_near_sea(camera)
	_update_cloud_volume(camera, celestial)
	_update_sky_planet()
	var now := Time.get_ticks_usec()
	grass.set_reduced(tier != 2)
	var dense := enabled and beauty_grass and tier != 1
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
	# Night's rod-lit shift, by the hour and the moon (studies/celestial.gd).
	var night: Vector4 = celestial.get("night_grade") if celestial.get("night_grade") != null else Vector4.ZERO
	target.set_shader_parameter("grade_night", Vector4(night.x * on, night.y, night.z, night.w))
	# The light shafts, on whichever of the two draws the grade: the native
	# woodland mist hides the blend whenever the plate has woods, which is
	# most of play, so the standalone grade gathers them too, from the same
	# depth copy (studies/surface_depth.gd).
	var depth: Texture2D = fog.depth.texture if fog != null else null
	if depth != null and _grade.get_shader_parameter("surface_depth") != depth:
		_grade.set_shader_parameter("surface_depth", depth)
	var sun: Vector3 = celestial.state.get("zs_sun_direction",Vector3.UP)
	var ahead := enabled and tier != 1 and depth != null and sun.y > -0.05 and not camera.is_position_behind(camera.global_position + sun * 400.0)
	target.set_shader_parameter("rays_strength", rays if ahead else 0.0)
	if ahead:
		var screen: Vector2 = camera.unproject_position(camera.global_position + sun * 400.0) / camera.get_viewport().get_visible_rect().size
		# Shafts fade as the sun sinks or hides behind cloud.
		var cloud: float = celestial.cloud
		var strength := smoothstep(-0.05, 0.12, sun.y) * (1.0 - minf(cloud * 1.2, 0.9))
		target.set_shader_parameter("rays_sun", Vector3(screen.x, screen.y, strength))
		# The sun's own light (gold low, near white high), not the air's.
		var sun_light: Vector3 = celestial.state.get("zs_cloud_sun",Vector3.ONE)
		target.set_shader_parameter("rays_color", sun_light / maxf(maxf(sun_light.x,sun_light.y),maxf(sun_light.z,0.001)) * RAYS_LIGHT)

static func _flag(name: String) -> bool:
	return name in preload("res://scripts/launch_args.gd").user_args() or name in OS.get_cmdline_args()

## The shafts' strength for this run: RAYS, --rays=N, or none with --no-rays.
static func default_rays() -> float:
	return 0.0 if _flag("--no-rays") else _arg_float("--rays=", RAYS)

static func _arg_float(prefix: String, fallback: float) -> float:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return float(arg.trim_prefix(prefix))
	return fallback

## Say which grass is on, so a film or a play session can tell: the tier,
## whether the dense GPU meadow draws and at what cover, and which tuft.
func _log_grass(dense: bool) -> void:
	var state := tier * 2 + int(dense)
	if state == _grass_logged: return
	_grass_logged = state
	var cover := "off"
	if dense: cover = "full cover" if tier == 2 else "reduced cover (--beauty-grass)"
	elif tier == 1: cover = "off on Balanced"
	else: cover = "off (retired; --beauty-grass turns it on)"
	var line := "Grass: tier %s, dense meadow %s, tufts %s" % [["Beauty","Balanced","Ultra"][clampi(tier,0,2)], cover, preload("res://scripts/grass_tuft_mesh.gd").describe()]
	print(line)

## The sky's horizon ridges follow the world: its terrain seed picks the
## skyline and its relief how tall the hills stand. None while the sky
## world's ring of real ranges stands (SkyWorld `painted_ridges`): they
## showed through its notches and passes as flat grey bands.
func _update_ridges(on: float) -> void:
	var sky: ShaderMaterial = _scene._environment.sky.sky_material if _scene._environment.sky != null else null
	if sky == null: return
	var editor = _scene.get("_chunk_editor")
	var settings: Dictionary = editor.data._recipe_settings if editor != null else {}
	var state := Vector3(ridge_strength(ridges * on), float(int(settings.get("seed", 0)) % 997), clampf(float(settings.get("relief", 1.0)), 0.5, 1.4))
	if sky.get_meta("look_ridges", Vector3(-1, -1, -1)) == state: return
	sky.set_meta("look_ridges", state)
	sky.set_shader_parameter("horizon_ridges", state.x)
	sky.set_shader_parameter("horizon_seed", state.y)
	sky.set_shader_parameter("horizon_relief", state.z)

## The painted ridges' strength for a look's `strength`: none with the
## ring's real ranges standing (SkyWorld `painted_ridges`).
static func ridge_strength(strength: float) -> float:
	return strength * preload("res://scripts/sky_world.gd").painted_ridges()

## The cloud sea's strength on the sky (the sky objects copy it from there).
func _update_cloud_sea(on: float) -> void:
	var sky: ShaderMaterial = _scene._environment.sky.sky_material if _scene._environment.sky != null else null
	if sky == null: return
	var strength := cloud_sea * on
	var style := maxi(CLOUD_STYLES.find(cloud_style), 0)
	_motes.set_strength(strength if style == 2 else 0.0)
	sea.set_sea(strength if near_sea else 0.0, style)
	if sky.get_meta("look_cloud_sea_style", -1) != style:
		sky.set_meta("look_cloud_sea_style", style)
		sky.set_shader_parameter("cloud_sea_style", style)
	apply_sea_peaks(sky)
	if sky.get_meta("look_cloud_sea", -1.0) == strength: return
	sky.set_meta("look_cloud_sea", strength)
	sky.set_shader_parameter("cloud_sea", strength)

## The scene's cloud host (scripts/cloud_host.gd): the towers and the
## planes' wakes the cloud volume marches, and the islands the near sea
## parts round. A scene that has one answers `cloud_host()` (the kit isles,
## through their sky); else the old game's islands (its wanderer's
## SkyIslands) are it. Null with none, or none yet.
func cloud_host() -> Node:
	return host_of(_scene)

## A scene's cloud host, as `cloud_host` finds it.
static func host_of(scene: Node) -> Node:
	if scene == null: return null
	if scene.has_method("cloud_host"): return scene.cloud_host()
	var wanderer: Variant = scene.get("wanderer")
	return wanderer.get("islands") if wanderer is Node else null

## The near sea round the eye, under the plate and the islands over it.
func _update_near_sea(camera: Camera3D) -> void:
	if not sea.visible or camera == null: return
	sea.follow(camera, float(_scene.get("_motion_time")) if _scene.get("_motion_time") != null else 0.0)
	var islands: Node = cloud_host()
	var editor = _scene.get("_chunk_editor")
	var plate: Node3D = editor.terrain if editor != null and editor.get("terrain") is Node3D else null
	sea.set_islands(SkySea.island_spots(islands, plate, camera.global_position))
	var peaks: Node = islands.get("peaks") if islands != null else null
	sea.set_ranges(peaks.keep_spots(camera.global_position) if peaks != null and peaks.has_method("keep_spots") else [])

## The unified cloud volume, after the near sea has followed the eye.
func _update_cloud_volume(camera: Camera3D, celestial) -> void:
	if cloud_volume == null or camera == null: return
	var wanderer: Variant = _scene.get("wanderer")
	var flight: Variant = wanderer.get("sky") if wanderer is Node else null
	var sea_flight: Variant = flight.get("flight") if flight is Object else null
	cloud_volume.lightning = _scene.get("_lightning")
	cloud_volume.update(camera, sea, cloud_host(), celestial, float(_scene.get("_motion_time")) if _scene.get("_motion_time") != null else 0.0, sea_flight if sea_flight is Vector4 else Vector4.ZERO)

## The Opal sea's painted distant peaks off while the sky world's ring of
## real ranges stands (SkyWorld `sea_peaks`), in the overview and the glide.
static func apply_sea_peaks(sky: ShaderMaterial) -> void:
	var peaks: float = preload("res://scripts/sky_world.gd").sea_peaks()
	if sky.get_meta("look_sea_peaks", -1.0) == peaks: return
	sky.set_meta("look_sea_peaks", peaks)
	sky.set_shader_parameter("sea_peaks", peaks)

## Paints the cloud sea in `style` (one of CLOUD_STYLES) from the next
## update; `keep` saves it as the player's choice.
func set_cloud_style(style: String, keep := true) -> void:
	if style not in CLOUD_STYLES: return
	cloud_style = style
	if keep: save_cloud_style(style, settings_path)
	if _scene != null: _update_cloud_sea(1.0 if enabled else 0.0)

## The player's kept cloud style, Opal until they choose.
static func load_cloud_style(path := SETTINGS_PATH) -> String:
	return _load_style("clouds", CLOUD_STYLES, path)

static func save_cloud_style(style: String, path := SETTINGS_PATH) -> void:
	_save_style("clouds", style, path)

## --cloud-style=NAME among `args`, when it names a style; else `kept`.
static func cloud_style_from_args(args: PackedStringArray, kept: String) -> String:
	return _style_from_args("--cloud-style=", CLOUD_STYLES, args, kept)

## Paints the night sky in `style` (one of NIGHT_STYLES); `keep` saves it
## as the player's choice.
func set_night_style(style: String, keep := true) -> void:
	if style not in NIGHT_STYLES: return
	night_style = style
	if keep: save_night_style(style, settings_path)
	_publish_night_style()

func _publish_night_style() -> void:
	RenderingServer.global_shader_parameter_set("zs_night_style", maxi(NIGHT_STYLES.find(night_style), 0))

## Shows or hides the planet from the next update; `keep` saves the choice.
func set_sky_planet(on: bool, keep := true) -> void:
	sky_planet = on
	if keep:
		var file := ConfigFile.new()
		file.load(settings_path)
		file.set_value("sky", "planet", on)
		file.save(settings_path)
	if _scene != null: _update_sky_planet()

func _update_sky_planet() -> void:
	var lighting = _scene.get("_lighting")
	var objects = lighting.sky_objects if lighting != null else null
	if objects == null or objects.planet == null: return
	if objects.planet.visible != sky_planet: objects.planet.visible = sky_planet

## The player's kept planet choice, off until they turn it on.
static func load_sky_planet(path := SETTINGS_PATH) -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK: return false
	return bool(file.get_value("sky", "planet", false))

## --sky-planet / --no-sky-planet among `args`; else `kept`.
static func sky_planet_from_args(args: PackedStringArray, kept: bool) -> bool:
	if "--no-sky-planet" in args: return false
	if "--sky-planet" in args: return true
	return kept

## The player's kept night style, Storybook until they choose.
static func load_night_style(path := SETTINGS_PATH) -> String:
	return _load_style("night", NIGHT_STYLES, path, NIGHT_DEFAULT)

static func save_night_style(style: String, path := SETTINGS_PATH) -> void:
	_save_style("night", style, path)

## --night-style=NAME among `args`, when it names a style; else `kept`.
static func night_style_from_args(args: PackedStringArray, kept: String) -> String:
	return _style_from_args("--night-style=", NIGHT_STYLES, args, kept)

## A style kept under `section` in the settings file; `fallback` (the
## first of `styles` unless given) when none or an unknown one is kept.
static func _load_style(section: String, styles: Array, path: String, fallback := "") -> String:
	if fallback.is_empty(): fallback = styles[0]
	var file := ConfigFile.new()
	if file.load(path) != OK: return fallback
	var style := String(file.get_value(section, "style", fallback))
	return style if style in styles else fallback

static func _save_style(section: String, style: String, path: String) -> void:
	var file := ConfigFile.new()
	file.load(path)
	file.set_value(section, "style", style)
	file.save(path)

static func _style_from_args(prefix: String, styles: Array, args: PackedStringArray, kept: String) -> String:
	for arg: String in args:
		if arg.begins_with(prefix):
			var style := arg.get_slice("=", 1).to_lower()
			if style in styles: return style
			push_warning("%s expected %s, not %s" % [prefix, ", ".join(styles), style])
	return kept

## A color's hue at unit luminance, pulled `amount` of the way from white.
func _tint(color: Variant, amount: float) -> Vector3:
	var value := Vector3(color.x, color.y, color.z) if color is Vector3 else Vector3(color.r, color.g, color.b)
	var luma := value.dot(Vector3(0.2126, 0.7152, 0.0722))
	if luma <= 0.0001: return Vector3.ONE
	return Vector3.ONE.lerp(value / luma, amount)
