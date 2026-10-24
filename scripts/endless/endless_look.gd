extends Node3D
## The endless flight's look (docs/design/endless-flight/look-round-1-handoff.md):
## the isle's sky and light over the endless land, a carpeted ground and a
## sea, all as the isles' own rig draws them, sized for kilometres.
##
##   sky and light  scripts/landscape_lighting.gd (the reference sky, ACES,
##                  glow, the sun and rim lights) driven by studies/
##                  celestial.gd (the sun's ring, its colour, the sky's
##                  gradient, the hemisphere fill the surfaces read), on a
##                  fixed hour or a running day. The sky's own cloud deck is
##                  off (zs_cloud x 0): the clouds come as their own pass.
##   haze           depth fog whose colour is the sky's own behind each pixel
##                  (aerial perspective 1), so the far land and sea melt into
##                  the horizon instead of meeting a wall; the sun's scatter
##                  in it looking toward the sun.
##   shadows        the sun's, in four splits out to SHADOW_REACH m.
##   ground         shaders/endless_ground.gdshader on every chunk.
##   sea            shaders/endless_sea.gdshader (scripts/endless/
##                  endless_sea.gd: depth-coloured, mirrored, foam and the
##                  plane's wake; --water=old: shaders/sky_ocean.gdshader)
##                  on SkyBelow's ringed sheet, following the eye.
##   wind           the shared wind globals (zs_wind_*, zs_gust_distance)
##                  the grass sheen and the sea's chop ride.
##
## The mood: one of the isles' look presets (scripts/scene_look_presets.gd:
## the palette's sky, horizon, glow, sun and ambient colours, the exposure,
## the wind and the hour), from MOODS, none of them winter.
##
## Flags: --mood=ID (MOOD), --hour=H (0..24, the mood's own by default),
## --day (the hour runs, a day in about eight minutes), --plain-look (round
## one's procedural sky, flat sea and vertex colours; also under the
## Compatibility renderer). T steps to the next quarter of the day, L to the
## next mood.

const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const SkyBelow = preload("res://scripts/sky_below.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const EndlessSea = preload("res://scripts/endless/endless_sea.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Presets = preload("res://scripts/scene_look_presets.gd")
const EndlessClouds = preload("res://scripts/endless/endless_clouds.gd")
const LandStream = preload("res://scripts/endless/land_stream.gd")
const EndlessPost = preload("res://scripts/endless/endless_post.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")

## The moods L steps through (no winter: the season stays off it), and the
## one it opens on.
const MOODS := ["alpine_morning","golden_meadow","ocean_light","meadow_morning","after_the_rain","desert_afternoon","rosewater_dusk","rose_dusk","moonlit_stillness"]
const MOOD := "alpine_morning"
## The hour it opens on with no --mood or --hour: the mood's own, as the
## aqueduct isle opens on it. (Round one's 7.6, a low sun raking every
## blade's edge, read the carpet's tufts as coarse dark-sided clumps from
## the plane: docs/design/endless-flight/grass-tune-handoff.md.)
const HOUR := 8.6

## The haze: from FOG_BEGIN m it thickens to all sky by FOG_END m (inside
## the land's reach, LandStream ROOT_REACH), along FOG_CURVE.
const FOG_BEGIN := 120.0
const FOG_END := 7600.0
const FOG_CURVE := 0.75
## The sun's glow in the haze looking toward it.
const SUN_SCATTER := 0.18
## The haze's colour is the sky's own at the horizon the eye faces
## (`horizon`), so the far land goes into the sky with no line; this share
## of it is the sky's blurred light round each pixel (Godot's aerial
## perspective), which turns the middle distance bluer.
const AERIAL := 0.35
## The sun's shadows reach this far (m), in four splits.
const SHADOW_REACH := 900.0
## The wind over the land and sea: its strength (the isles' 0..2) and the
## air's speed (m/s) that rolls the grass's waves and the sea's paws.
const WIND := 0.75
const AIR_SPEED := 4.5
## The sea's colour by depth (sky_ocean `tint_*`): turquoise over the
## shallows, clear teal, deep blue, then the open sea's dark blue, by the
## depths in TINT_DEPTHS (m of water looked through).
const TINT_SHALLOW := Color(0.36,0.88,0.80)
const TINT_MID := Color(0.10,0.58,0.66)
const TINT_DEEP := Color(0.05,0.32,0.48)
const TINT_ABYSS := Color(0.04,0.20,0.36)
const TINT_DEPTHS := Vector3(2.5,9.0,26.0)
## The sea draws first of the see-through things, so the clouds' sheet
## (EndlessClouds RENDER_PRIORITY) lays the cloud over it.
const SEA_PRIORITY := -8
## The share of the land's haze the cloud takes (shaders/
## endless_cloud_composite.gdshader `haze`.w).
const CLOUD_HAZE := 0.6

var plain := false
var lighting: Node3D
var celestial: RefCounted
var environment: Environment
var sun: DirectionalLight3D
var sea: MeshInstance3D
## The sea's material and its feeds (scripts/endless/endless_sea.gd), or
## null under --water=old.
var water: EndlessSea
## The plane now, for the sea's wake (set each frame before `step`).
var plane_at := Vector3(0.0,1.0e4,0.0)
var _land_seed := 0
var ground: ShaderMaterial
var _time := 0.0
var _gust := 0.0
var _wind_angle := 0.0
var _wind := WIND
var mood := MOOD
## The clouds (scripts/endless/endless_clouds.gd), or null (--no-clouds, no
## RenderingDevice).
var clouds: Node3D
## The light pass (scripts/endless/endless_post.gd), or null (the default; --post=1 puts it in).
var post: CompositorEffect
## The mood's key and fill scales on the sun and the sky's fill
## (EndlessPost MOODS); --light=0 leaves the isles' light as it was.
var _key := 1.0
var _fill := 1.0
var _light_on := true
## --key=X and --fill=X scale the mood's own (to try a value).
var _key_arg := 1.0
var _fill_arg := 1.0
## The wind's heading over the ground now (unit xz).
var wind_direction := Vector2.RIGHT

## The season and weather shader globals a title world, isle or study may
## have left set (the isle publishes the real date's autumn, its snow, wet
## and haze); shader globals outlive a scene change. Endless flight never
## publishes them, so it puts each back to its project.godot value on start:
## a green land, dry, no frost, the plants and sky in no season.
const SEASON_GLOBALS := ["zs_season","zs_sky_season","zs_autumn","zs_snow","zs_ice","zs_ground_wet","zs_foliage_wet","zs_storm_grade","zs_storm_thin","zs_haze","zs_surface_post",
		"zs_palette_grass","zs_palette_foliage","zs_palette_rock","zs_palette_earth","zs_palette_water",
		"zs_look_ao","zs_look_rim","zs_look_shore","zs_look_bounce","zs_look_fill","zs_night_style"]

static func reset_season_globals() -> void:
	# The plant materials the isle shares through static caches (SkyIslets,
	# KitFlora's rings) carry whatever look the isle gave them: made fresh.
	preload("res://scripts/sky_islets.gd")._plant_materials.clear()
	preload("res://scripts/kit_isle/kit_flora.gd")._ring_materials.clear()
	for key in SEASON_GLOBALS:
		var path := "shader_globals/%s" % key
		if ProjectSettings.has_setting(path):
			RenderingServer.global_shader_parameter_set(key,(ProjectSettings.get_setting(path) as Dictionary).get("value"))

## Whether the full look runs (not --plain-look, not the Compatibility
## renderer).
static func wanted() -> bool:
	if "--plain-look" in LaunchArgs.user_args(): return false
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

## Frame rate (docs/design/endless-flight/frame-rate-handoff.md). No
## ambient occlusion: the land's surfaces take their sky fill as emission,
## which it never darkens, so in stills at every spot it changed no pixel
## past the clouds' own frame-to-frame noise, and it cost 2.3 to 3.2 ms a
## frame on the M5 Pro; --ssao=1 brings it back. Trades the eye can see,
## off elsewhere and on by default on a Mac (the user's call for the M5
## Pro; --mac-trades=0 leaves them off there too): --shadow-size=N (the
## sun's shadow map, 8192 a side; 4096 saves 0.5 to 0.8 ms, shadow edges a
## little softer), --msaa=N (0, 2, 4: the 3D's MSAA, 4), and the clouds'
## half-res march (EndlessClouds.setup, --cloud-full-res). On a discrete GPU
## off the Mac (LandStream.high_end) SMAA over the MSAA, 0 to 0.4 ms
## (docs/design/endless-flight/aa-view-handoff.md). --screen-aa=smaa|fxaa|off,
## --taa=1 (2 to 5 ms, and the grass ghosts). The flags win.
const SSAO := false
const MAC_SHADOW := 4096
static func mac_trades() -> bool:
	return OS.get_name() == "macOS" and not "--mac-trades=0" in LaunchArgs.user_args()
func _frame_trades() -> void:
	environment.ssao_enabled = SSAO
	if mac_trades():
		RenderingServer.directional_shadow_atlas_set_size(MAC_SHADOW,true)
		(Engine.get_main_loop() as SceneTree).root.msaa_3d = Viewport.MSAA_2X
	if LandStream.high_end():
		(Engine.get_main_loop() as SceneTree).root.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--ssao="): environment.ssao_enabled = a.get_slice("=",1) != "0"
		elif a.begins_with("--shadow-size="):
			RenderingServer.directional_shadow_atlas_set_size(clampi(int(a.get_slice("=",1)),1024,16384),true)
		elif a.begins_with("--msaa="):
			var n := int(a.get_slice("=",1))
			var root := (Engine.get_main_loop() as SceneTree).root
			root.msaa_3d = Viewport.MSAA_8X if n >= 8 else (Viewport.MSAA_4X if n >= 4 else (Viewport.MSAA_2X if n >= 2 else Viewport.MSAA_DISABLED))
		elif a.begins_with("--screen-aa="):
			var kind := a.get_slice("=",1)
			(Engine.get_main_loop() as SceneTree).root.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if kind == "smaa" else (Viewport.SCREEN_SPACE_AA_FXAA if kind == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED)
		elif a.begins_with("--taa="): (Engine.get_main_loop() as SceneTree).root.use_taa = a.get_slice("=",1) != "0"

func setup(land_seed: int) -> void:
	name = "Look"
	_land_seed = land_seed
	# The world's mood and hour (its paint), then the flags over them.
	var world: RefCounted = WorldProfile.current()
	var world_mood := str(world.paint.get("mood",MOOD))
	if world_mood in MOODS: mood = world_mood
	var hour := -1.0
	var day := false
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--hour="): hour = clampf(a.get_slice("=",1).to_float(),0.0,24.0)
		elif a == "--day": day = true
		elif a.begins_with("--key="): _key_arg = a.get_slice("=",1).to_float()
		elif a.begins_with("--fill="): _fill_arg = a.get_slice("=",1).to_float()
		elif a.begins_with("--mood=") and a.get_slice("=",1) in MOODS: mood = a.get_slice("=",1)
	# The world's mood at its hour (wilderness: MOOD at HOUR; -1 the mood's
	# own); another mood at its own hour.
	if hour < 0.0 and mood == world_mood: hour = float(world.paint.get("hour",HOUR))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	lighting = LandscapeLighting.new()
	lighting.name = "Lighting"
	add_child(lighting)
	lighting.setup(source)
	environment = lighting.environment
	sun = lighting.lights[0]
	sun.name = "Sun"
	# The isle's one orthogonal map fits a diorama; over open land, four
	# splits out to SHADOW_REACH, the nearest tight on the plane.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = SHADOW_REACH
	sun.directional_shadow_split_1 = 0.03
	sun.directional_shadow_split_2 = 0.12
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	_frame_trades()
	celestial = Celestial.new()
	celestial.cloud = 0.0
	celestial.setup(lighting.lights)
	celestial.look.changed.connect(_exposure)
	show_mood(mood,false)
	celestial.cycling = day
	if hour >= 0.0: celestial.set_phase(hour/24.0)
	_exposure()
	# The sky's own cloud deck off; the cloud volume comes later as a pass.
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(0.0,0.0,20.0,12.0))
	# The haze.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Depth fog's density scales its curve: 1 runs it to all sky.
	environment.fog_density = 1.0
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END*LandStream.view()
	environment.fog_depth_curve = FOG_CURVE
	environment.fog_aerial_perspective = AERIAL
	environment.fog_sky_affect = 0.0
	environment.fog_sun_scatter = SUN_SCATTER
	environment.fog_light_energy = 1.0
	_wind_angle = float(absi(hash(land_seed))%6283)/1000.0
	ground = ShaderMaterial.new()
	ground.shader = preload("res://shaders/endless_ground.gdshader")
	ground.set_shader_parameter("old_rock","--old-rock" in LaunchArgs.user_args())
	ground.set_shader_parameter("rock_pass1","--rock-pass1" in LaunchArgs.user_args())
	ground.set_shader_parameter("rock_flat","--rock-flat" in LaunchArgs.user_args())
	ground.set_shader_parameter("rock_erosion_tex",load("res://assets/textures/endless_rock_erosion.png"))
	world.apply_ground(ground)
	# --rock-knob=name=value (repeatable): any rock_* float uniform, to try a
	# value without editing the shader (rock-carve-handoff.md).
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--rock-knob=") and arg.get_slice("=",1).begins_with("rock_"):
			ground.set_shader_parameter(arg.get_slice("=",1),float(arg.get_slice("=",2)))
	ground.set_shader_parameter("sea_y",Field.SEA_Y)
	ground.set_shader_parameter("beach",Field.BEACH)
	ground.set_shader_parameter("snow_line",Field.new(land_seed).snow_line())
	_build_sea()
	_river_water(land_seed)
	if EndlessClouds.wanted():
		clouds = EndlessClouds.new()
		add_child(clouds)
		clouds.setup(land_seed,celestial,Vector4(FOG_BEGIN,FOG_END*LandStream.view(),FOG_CURVE,CLOUD_HAZE),SUN_SCATTER*0.5)
		if sea != null and sea.material_override is ShaderMaterial and (sea.material_override as ShaderMaterial).shader == preload("res://shaders/endless_sea.gdshader"):
			clouds.sea_material = sea.material_override
	_light_on = not "--light=0" in LaunchArgs.user_args()
	if EndlessPost.wanted():
		post = EndlessPost.new()
		post.setup(self,Vector3(FOG_BEGIN,FOG_END*LandStream.view(),FOG_CURVE))
		if clouds != null: post.cloud_shape = clouds.effect.resolved_b
	_publish(0.0)
	_haze(Vector3.FORWARD)
	# The ringed planet is the isles' option, off by default (look_pass.gd).
	if lighting.sky_objects != null: lighting.sky_objects.planet.visible = false

## Mood `id` (a preset in MOODS): its colours, exposure, night light and
## wind, and its hour unless `keep_hour`.
func show_mood(id: String, keep_hour := true) -> void:
	if not Presets.PRESETS.has(id): return
	mood = id
	var p: Dictionary = Presets.recipe(id)
	celestial.look.restore(Presets.look_document(id))
	var c: Dictionary = Presets.controls(id)._celestial
	celestial.night_fill = c.night_fill
	celestial.night_look = c.night_look
	celestial.aurora_strength = c.aurora_strength
	_wind = clampf(float(p.wind),0.3,1.2)
	if not keep_hour: celestial.set_phase(float(p.phase))
	celestial.update_rig()
	var t := EndlessPost.tuning(id)
	_key = float(t.key)*_key_arg
	_fill = float(t.fill)*_fill_arg
	if post != null: post.set_mood(id)

## The next mood in MOODS, keeping the hour.
func next_mood() -> void:
	show_mood(MOODS[(MOODS.find(mood)+1)%MOODS.size()])

## The mood's title.
func mood_title() -> String:
	return str(Presets.PRESETS[mood].title)

## The scene look's exposure, as the isle sets it (studies/kit_isle.gd).
func _exposure() -> void:
	celestial.update_rig()
	var exposure := 1.15/1.08*float(celestial.look.settings.exposure)
	environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)

func _build_sea() -> void:
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = SkyBelow._sheet()
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.extra_cull_margin = 16384.0
	sea.position.y = Field.SEA_Y
	add_child(sea)
	if EndlessSea.wanted():
		water = EndlessSea.new(_land_seed)
		water.set_wind(_wind_angle)
		if EndlessSea.body_wanted(): sea.mesh = EndlessSea.sheet()
		water.material.render_priority = SEA_PRIORITY
		sea.material_override = water.material
		return
	_build_old_sea()

## The rivers' water, painted by the ground shader (rivers-handoff.md):
## the sea's chop maps and its colours, so a river reads as the same water.
## Off with the land's rivers (--no-rivers).
func _river_water(land_seed: int) -> void:
	var field := Field.new(land_seed)
	var on := field.rivers > 0.0
	ground.set_shader_parameter("river_on",1.0 if on else 0.0)
	if not on: return
	# The mouths (river-mouths-handoff.md): --river-mouth=0 as before.
	var mouth := minf(field.river_mouth,1.0)
	ground.set_shader_parameter("river_mouth_blend",mouth)
	ground.set_shader_parameter("river_mouth_sink",Vector2((Field.RIVER_BED+Field.RIVER_MOUTH_DEEP)*mouth,Field.RIVER_MOUTH_SINK))
	ground.set_shader_parameter("river_mouth_rise",Field.RIVER_MOUTH_RISE)
	ground.set_shader_parameter("river_mouth_deep",Vector2(Field.RIVER_BED,Field.RIVER_MOUTH_DEEP*mouth))
	if water != null:
		ground.set_shader_parameter("river_detail_a",water.material.get_shader_parameter("detail_a"))
		ground.set_shader_parameter("river_detail_b",water.material.get_shader_parameter("detail_b"))
		for k: String in ["tint_shallow","tint_mid","tint_deep"]:
			ground.set_shader_parameter("river_"+k,water.material.get_shader_parameter(k))
		# The sea's colour by depth and its calm body light, for the mouths.
		var td: Variant = water.material.get_shader_parameter("tint_depths")
		if td is Vector4: ground.set_shader_parameter("river_sea_tint_depths",td)
		var bf: Variant = water.material.get_shader_parameter("bed_fade")
		if bf is float: ground.set_shader_parameter("river_sea_bed_fade",bf)
		# The body's light on calm water (half way from trough to crest; the
		# shader's default body_value (0.6, 1.2) unless it was set).
		var body: Variant = water.material.get_shader_parameter("sea_body")
		var bv: Variant = water.material.get_shader_parameter("body_value")
		var mean := ((bv as Vector2).x+(bv as Vector2).y)*0.5 if bv is Vector2 else 0.9
		ground.set_shader_parameter("river_sea_body",mean if body is int and body > 0 else 1.0)
	else:
		ground.set_shader_parameter("river_detail_a",EndlessSea._detail(land_seed,0.022,5))
		ground.set_shader_parameter("river_detail_b",EndlessSea._detail(land_seed+7,0.035,4))
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--river-knob="):
			ground.set_shader_parameter(arg.get_slice("=",1),str_to_var(arg.get_slice("=",2)))

## The earlier sea (--water=old): the lower world's ocean shader.
func _build_old_sea() -> void:
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/sky_ocean.gdshader")
	# The open sky mirrored, not the lower world's overcast.
	water.set_shader_parameter("below_sky",0.0)
	water.set_shader_parameter("tint_shallow",TINT_SHALLOW)
	water.set_shader_parameter("tint_mid",TINT_MID)
	water.set_shader_parameter("tint_deep",TINT_DEEP)
	water.set_shader_parameter("tint_abyss",TINT_ABYSS)
	water.set_shader_parameter("tint_depths",TINT_DEPTHS)
	water.set_shader_parameter("bed_fade",6.0)
	water.set_shader_parameter("glint_share",1.0)
	water.render_priority = SEA_PRIORITY
	# The clouds' shadows on the water (none drawn without the clouds).
	water.set_shader_parameter("cloud_shade",1.0)
	sea.material_override = water

## One frame: the hour, the wind and the clocks the shaders read, the sea
## under the eye, then the clouds round `view` (the camera that draws).
func step(delta: float, eye: Vector3, facing := Vector3.FORWARD, view: Camera3D = null) -> void:
	celestial.advance(delta,false)
	if _light_on:
		sun.light_energy *= _key
		RenderingServer.global_shader_parameter_set("zs_hemi_energy",float(celestial.state.zs_hemi_energy)*_fill)
	_publish(delta)
	_haze(facing)
	if post != null: post.step(view,self,facing)
	ground.set_shader_parameter("night_grade",celestial.night_grade)
	RenderingServer.global_shader_parameter_set("zs_camera_position",eye)
	sea.position = Vector3(snappedf(eye.x,64.0),Field.SEA_Y,snappedf(eye.z,64.0))
	if water != null: water.step(delta,eye,plane_at,facing,_time,view)
	if clouds != null: clouds.step(delta,view,wind_direction,_time)

func _publish(delta: float) -> void:
	_time += delta
	# The wind wanders a little round its heading, its strength breathing.
	var angle := _wind_angle+0.35*sin(_time*0.013)
	var strength := _wind*(0.85+0.15*sin(_time*0.21)*sin(_time*0.077))
	_gust += delta*AIR_SPEED*(0.5+0.5*strength/WIND)
	wind_direction = Vector2(cos(angle),sin(angle))
	RenderingServer.global_shader_parameter_set("zs_motion_time",_time)
	RenderingServer.global_shader_parameter_set("zs_flow_time",_time)
	RenderingServer.global_shader_parameter_set("zs_wind_direction",Vector2(cos(angle),sin(angle)))
	RenderingServer.global_shader_parameter_set("zs_wind_strength",strength)
	RenderingServer.global_shader_parameter_set("zs_gust_distance",_gust)
	RenderingServer.global_shader_parameter_set("zs_gust_speed",AIR_SPEED)

## The haze's colour: the sky's at the horizon toward `facing` (the
## dome's zsSkyBase, shaders/reference_sky_common.gdshaderinc, at y 0 and
## taken from display to scene light as the dome takes it).
func _haze(facing: Vector3) -> void:
	var c := horizon(facing)
	var top := maxf(maxf(c.r,c.g),maxf(c.b,1e-4))
	environment.fog_light_color = Color(c.r/top,c.g/top,c.b/top).linear_to_srgb()
	environment.fog_light_energy = top

## The sky's colour (scene linear) at the horizon toward `facing`.
func horizon(facing: Vector3) -> Color:
	var st: Dictionary = celestial.state
	var down: Vector3 = st.zs_sky_down
	var up: Vector3 = st.zs_sky_up
	var glow: Vector3 = st.zs_sky_glow
	var sun_dir: Vector3 = st.zs_sun_direction
	var flat := Vector2(facing.x,facing.z).normalized()
	var to_sun := flat.dot(Vector2(sun_dir.x,sun_dir.z).normalized())*0.5+0.5
	# smoothstep(-0.4, 0.7, 0)
	var col := down.lerp(up,0.3005)
	col += glow*lerpf(1.0,to_sun*to_sun*1.6+0.08,float(st.zs_dusk_direction))
	col *= 0.98/maxf(maxf(maxf(col.x,col.y),col.z),0.98)
	return _scene_linear(col,environment.tonemap_exposure)

## shaders/reference_display.gdshaderinc scene_linear_for_display: the
## display colour the dome means, as the scene light ACES maps back to it.
static func _scene_linear(display: Vector3, exposure: float) -> Color:
	var d := Vector3.ZERO
	for i in 3:
		var v := display[i]
		d[i] = v/12.92 if v <= 0.04045 else pow((v+0.055)/1.055,2.4)
	var input := Basis(Vector3(0.59719,0.07600,0.02840),Vector3(0.35458,0.90834,0.13383),Vector3(0.04823,0.01566,0.83777))
	var output := Basis(Vector3(1.60475,-0.10208,-0.00327),Vector3(-0.53108,1.10813,-0.07276),Vector3(-0.07367,-0.00605,1.07602))
	var w := 16.0*1.8
	var white_scale := (w*(w+0.0245786)-0.000090537)/(w*(0.983729*w+0.432951)+0.238081)
	var y := output.inverse()*d*white_scale
	var x := Vector3.ZERO
	for i in 3:
		var a := y[i]*0.983729-1.0
		var b := y[i]*0.432951-0.0245786
		var c := y[i]*0.238081+0.000090537
		x[i] = (-b-sqrt(maxf(b*b-4.0*a*c,0.0)))/(2.0*a)
	var lin := input.inverse()*x/(1.8*exposure)
	return Color(maxf(lin.x,0.0),maxf(lin.y,0.0),maxf(lin.z,0.0))

## The next quarter of the day (dawn, noon, dusk, midnight), eased to.
func next_hour() -> void:
	celestial.next_hour()

## The hour now (0..24).
func hour() -> float:
	return fposmod(float(celestial.phase),1.0)*24.0

func _exit_tree() -> void:
	if post != null: post.free_buffers()
	if water != null: water.finish()
