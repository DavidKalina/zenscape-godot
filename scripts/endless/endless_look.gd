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
## Flags: --mood=ID (MOOD), --hour=H (0..24, the mood's own by default;
## the time stands still there), --plain-look (round one's procedural sky,
## flat sea and vertex colours; also under the Compatibility renderer).
## The day cycle (scripts/endless/day_cycle.gd, day-cycle-handoff.md) runs
## by default from the opening hour: --day=0 stops it (--day or --day=1
## runs it from --hour=H too), --day-length=S (seconds a cycle, 1200),
## --day-at=dawn|noon|dusk|blue (where it starts), --night=1 (the full night
## under the horizon instead of the blue hour). T sweeps to the next stop
## (dawn, noon, dusk, blue hour), ] and [ speed time up and back, L steps
## to the next mood.

const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://scripts/shared/celestial.gd")
const SkyBelow = preload("res://scripts/sky_below.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const EndlessSea = preload("res://scripts/endless/endless_sea.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Presets = preload("res://scripts/scene_look_presets.gd")
const EndlessClouds = preload("res://scripts/endless/endless_clouds.gd")
const LandStream = preload("res://scripts/endless/land_stream.gd")
const EndlessPost = preload("res://scripts/endless/endless_post.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const DayCycle = preload("res://scripts/endless/day_cycle.gd")
const LandHorizon = preload("res://scripts/endless/land_horizon.gd")
const WindField = preload("res://scripts/endless/wind_field.gd")
const WindMap = preload("res://scripts/endless/wind_map.gd")

## The moods L steps through (no winter: the season stays off it), and the
## one it opens on.
const MOODS := ["alpine_morning","golden_meadow","ocean_light","meadow_morning","after_the_rain","desert_afternoon","amber_hour","rosewater_dusk","rose_dusk","moonlit_stillness"]
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
## The haze thins on high ground (shaders/endless_height_haze.gdshaderinc):
## from HAZE_RISE m over the sea, over the next HAZE_SPAN m, down to this
## share of the haze less. --haze-height=X scales it (0: the distance-only
## haze as before, drawn by the ground itself); --haze-height-bias=M counts
## ground M m higher in it, to try it on low hills.
const HAZE_RISE := 350.0
const HAZE_SPAN := 300.0
const HAZE_CUT := 0.6
## The sun's glow in the haze looking toward it.
const SUN_SCATTER := 0.18
## The haze's colour is the sky's own at the horizon the eye faces
## (`horizon`), so the far land goes into the sky with no line; this share
## of it is the sky's blurred light round each pixel (Godot's aerial
## perspective), which turns the middle distance bluer.
const AERIAL := 0.35
## At a low sun (zs_haze_sun, celestial.gd haze_sun) the haze takes this
## share of the sky behind each pixel instead, so it turns with the view's
## bearing to the sun (warm into it, blue away) and the far land meets the
## dome's own horizon in every direction; and the sun's scatter in it grows
## to this.
const AERIAL_SUN := 0.6
const SUN_SCATTER_SUN := 0.45
## shaders/reference_sky_common.gdshaderinc ZS_HAZE_GATHER, _COOL, _BLUE.
const HAZE_GATHER := 0.4
const HAZE_COOL := 0.55
const HAZE_BLUE := 0.6
## The sun's shadows reach this far (m), in four splits.
const SHADOW_REACH := 900.0
## The wind over the land and sea: its strength (the isles' 0..2) and the
## air's speed (m/s) that rolls the grass's waves and the sea's paws.
const WIND := 0.75
const AIR_SPEED := 4.5
## The breeze plants lean in with no field (zs_breeze's project.godot value).
const BREEZE := 0.53
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
## The sky over the Peak's collar keeps its own hour (set_collar_sky): its
## golden hour, the sun this high on the day's ring (DayCycle ring_height),
## setting; --collar-hour=H gives another, --collar-sky=0 keeps the land's.
const COLLAR_SUN := 0.3
## Round the collar the lift is whole out to its radius plus COLLAR_NEAR,
## and gone COLLAR_FADE further out (m, level from its centre).
const COLLAR_NEAR := 1000.0
const COLLAR_FADE := 1500.0
## The sun's bearing at the opening hour, degrees clockwise from the way in to
## the Peak (turn_ring_to). Ahead and to the left, so the towers' near faces
## stand in shade, and the day walks it on over the crown rather than behind
## the eye (bearing from the way: left at the opening, ahead at noon, right
## by evening).
const PEAK_SUN := -80.0

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
## Copies of `ground` (the rocks' bare one) that take its haze each frame too.
var ground_copies: Array[ShaderMaterial] = []
var _time := 0.0
var _gust := 0.0
## The grass's swells' clock: the air's travel at the world's pace under the eye.
var _sheen := 0.0
var _sheen_pace := 1.0
var _wind_angle := 0.0
var _wind := WIND
var mood := MOOD
## The day cycle: owns the sun's phase while it moves.
var cycle: DayCycle
## The hour is the clock's (T took it): a region's paint keeps off it.
var _hour_taken := false
## A world of regions paints the mood and hour by the eye (blend_moods)
## until --mood=, --hour=, --day, L or T takes them over.
var world_paint := true
## The collar's sky: {centre (xz), radius, lo, hi (world y)}, empty with no
## Peak or --collar-sky=0.
var _collar_sky := {}
## The collar's own phase (0..1).
var _collar_phase := 0.0
## How far the sky has gone from the land's hour to the collar's (0..1).
var collar_lift := 0.0
## The land's phase this frame, and the lifted one celestial was given
## (-1: none), so the next frame puts the land's back.
var _land_phase := 0.0
var _sky_phase := -1.0
## The clouds (scripts/endless/endless_clouds.gd), or null (--no-clouds, no
## RenderingDevice).
var clouds: Node3D
## The land's shadows past the sun's map (--terrain-shadows=1, LandHorizon).
var land_shade: LandHorizon
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
## The wind by place and hour (scripts/endless/wind_field.gd: `wind.wind_at(x,
## z)`), or null: a world whose paint has no "wind": "field" (the doors world
## takes its home's, the wilderness's), or --wind=off, blows the mood's one
## wind everywhere as before; so does the land past the field's bake (the
## doors' amberlands half).
var wind: WindField
## The wind's clock (s): from the day's time at the start, then real seconds.
var _wind_clock := 0.0
## The eye last frame (the wind's strength there is the view's).
var _eye := Vector3.ZERO
## The field's strength at the eye, eased, and the breeze plants lean in there.
var _wind_here := -1.0
var _breeze_here := -1.0
## The baked exposure's texture once handed to the shaders (zs_wind_exposure).
var _wind_texture: ImageTexture
## The field's map (--wind-map), or null.
var wind_map: CanvasLayer

## The season and weather shader globals a title world, isle or study may
## have left set (the isle publishes the real date's autumn, its snow, wet
## and haze); shader globals outlive a scene change. Endless flight never
## publishes them, so it puts each back to its project.godot value on start:
## a green land, dry, no frost, the plants and sky in no season.
const SEASON_GLOBALS := ["zs_season","zs_sky_season","zs_autumn","zs_snow","zs_ice","zs_ground_wet","zs_foliage_wet","zs_storm_grade","zs_storm_thin","zs_haze","zs_surface_post",
		"zs_palette_grass","zs_palette_foliage","zs_palette_rock","zs_palette_earth","zs_palette_water",
		"zs_look_ao","zs_look_rim","zs_look_shore","zs_look_bounce","zs_look_fill","zs_night_style",
		# (The wind field off and the breeze a light day's till a world's field blows.)
		"zs_wind_field","zs_breeze"]

static func reset_season_globals() -> void:
	# The plant materials the isle shares through static caches (SkyIslets,
	# KitFlora's rings) carry whatever look the isle gave them: made fresh.
	preload("res://scripts/sky_islets.gd")._plant_materials.clear()
	preload("res://scripts/shared/kit_flora.gd")._ring_materials.clear()
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
## little softer), and the clouds' half-res march (EndlessClouds.setup, --cloud-full-res). On a discrete GPU
## off the Mac (LandStream.high_end) SMAA over the MSAA, 0 to 0.4 ms
## (docs/design/endless-flight/aa-view-handoff.md). --screen-aa=smaa|fxaa|off,
## --taa=1 (2 to 5 ms, and the grass ghosts). MSAA 2x everywhere (MSAA_3D;
## 4x cost 1.2 to 1.7 ms more on the Mac and about 1.5 at 1440p on an RTX
## 4070 SUPER, the grass edges a little rougher at 2x): --msaa=N (0, 2, 4,
## 8). The flags win.
const SSAO := false
const MSAA_3D := Viewport.MSAA_2X
const MAC_SHADOW := 4096
static func mac_trades() -> bool:
	return OS.get_name() == "macOS" and not "--mac-trades=0" in LaunchArgs.user_args()
func _frame_trades() -> void:
	environment.ssao_enabled = SSAO
	(Engine.get_main_loop() as SceneTree).root.msaa_3d = MSAA_3D
	if mac_trades():
		RenderingServer.directional_shadow_atlas_set_size(MAC_SHADOW,true)
	# Set either way: the root window keeps the last flight's (F3's restart).
	(Engine.get_main_loop() as SceneTree).root.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if LandStream.high_end() else Viewport.SCREEN_SPACE_AA_DISABLED
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
	# The day cycle: on unless --hour= stills it or --day=0 stops it.
	var day := -1
	var day_length := DayCycle.LENGTH
	var day_at := ""
	var full_night := false
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--hour="): hour = clampf(a.get_slice("=",1).to_float(),0.0,24.0)
		elif a == "--day": day = 1
		elif a.begins_with("--day="): day = 0 if a.get_slice("=",1) == "0" else 1
		elif a.begins_with("--day-length="): day_length = maxf(a.get_slice("=",1).to_float(),1.0)
		elif a.begins_with("--day-at="): day_at = a.get_slice("=",1)
		elif a.begins_with("--night="): full_night = a.get_slice("=",1) != "0"
		elif a.begins_with("--key="): _key_arg = a.get_slice("=",1).to_float()
		elif a.begins_with("--fill="): _fill_arg = a.get_slice("=",1).to_float()
		elif a.begins_with("--mood=") and a.get_slice("=",1) in MOODS: mood = a.get_slice("=",1)
	var still := hour >= 0.0
	if hour >= 0.0 or day == 1 or mood != world_mood or day_at != "": world_paint = false
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
	# The cycle owns the phase (celestial's own 480 s loop stays off).
	celestial.cycling = false
	if not full_night: celestial.night_floor = DayCycle.FLOOR
	if hour >= 0.0: celestial.set_phase(hour/24.0)
	cycle = DayCycle.new(day_length)
	# A one-profile world whose paint says `still` holds its hour (the
	# amberlands' low sun) unless --day runs the clock.
	var world_still := bool(world.paint.get("still",false)) and bool(world.uniform)
	cycle.running = day == 1 or (day == -1 and not still and not world_still)
	cycle.set_phase(celestial.phase)
	if day_at != "":
		if cycle.go_to(day_at): celestial.set_phase(cycle.phase())
		elif day_at.is_valid_float():
			celestial.set_phase(clampf(day_at.to_float(),0.0,24.0)/24.0)
			cycle.set_phase(celestial.phase)
	_exposure()
	# The sky's own cloud deck off; the cloud volume comes later as a pass.
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(0.0,0.0,20.0,12.0))
	# The haze; under the horizon the dome on screen keeps the horizon's
	# colour, so from high up the far land's haze meets sky of its colour
	# (shaders/reference_sky.gdshader ground_horizon).
	if environment.sky != null and environment.sky.sky_material is ShaderMaterial:
		(environment.sky.sky_material as ShaderMaterial).set_shader_parameter("ground_horizon",1.0)
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
	# The grass's paint skipped where it can't show (--land-skip=0 off, =show
	# tints what it skips).
	for a in LaunchArgs.user_args():
		if a.begins_with("--land-skip="): ground.set_shader_parameter("grass_skip",2 if a.get_slice("=",1) == "show" else clampi(int(a.get_slice("=",1)),0,1))
	ground.set_shader_parameter("rock_erosion_tex",load("res://assets/textures/endless_rock_erosion.png"))
	# --rock-look=old: the rock before the rich and shape rounds
	# (rock-polish-handoff.md); the land still bakes its shape unless --rock-shape=0.
	if "--rock-look=old" in LaunchArgs.user_args():
		ground.set_shader_parameter("rock_rich",0.0)
		ground.set_shader_parameter("rock_shape",0.0)
	world.apply_ground(ground)
	# --rock-knob=name=value (repeatable): any rock_* float uniform, to try a
	# value without editing the shader (rock-carve-handoff.md).
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--rock-knob=") and arg.get_slice("=",1).begins_with("rock_"):
			ground.set_shader_parameter(arg.get_slice("=",1),float(arg.get_slice("=",2)))
	ground.set_shader_parameter("sea_y",Field.SEA_Y)
	var haze_cut := HAZE_CUT
	var haze_bias := 0.0
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--haze-height="): haze_cut = HAZE_CUT*a.get_slice("=",1).to_float()
		elif a.begins_with("--haze-height-bias="): haze_bias = a.get_slice("=",1).to_float()
	ground.set_shader_parameter("haze_height",Vector4(HAZE_RISE,HAZE_SPAN,haze_cut,haze_bias))
	ground.set_shader_parameter("beach",Field.BEACH)
	var land := Field.new(land_seed)
	ground.set_shader_parameter("snow_line",land.snow_line())
	if str(world.paint.get("wind","")) == "field" and WindField.wanted_mode(LaunchArgs.user_args()) != "off":
		wind = WindField.new()
		_wind_clock = cycle.t
		wind.setup(land_seed,land,LaunchArgs.user_args())
		if "--wind-map" in LaunchArgs.user_args():
			wind_map = WindMap.new()
			add_child(wind_map)
			wind_map.setup(wind)
	_build_sea()
	_river_water(land_seed)
	if EndlessClouds.wanted():
		clouds = EndlessClouds.new()
		add_child(clouds)
		clouds.setup(land_seed,celestial,Vector4(FOG_BEGIN,FOG_END*LandStream.view(),FOG_CURVE,CLOUD_HAZE),SUN_SCATTER*0.5)
		if sea != null and sea.material_override is ShaderMaterial and (sea.material_override as ShaderMaterial).shader == preload("res://shaders/endless_sea.gdshader"):
			clouds.sea_material = sea.material_override
	_light_on = not "--light=0" in LaunchArgs.user_args()
	if LandHorizon.wanted():
		land_shade = LandHorizon.new()
		add_child(land_shade)
		land_shade.setup(land_seed)
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
	world_paint = false
	show_mood(MOODS[(MOODS.find(mood)+1)%MOODS.size()])

## A world of regions: the moods meeting under the eye, [[id, hour, weight],
## ...] (the regions profile's moods_at_eye), blended as one: the sky's and
## light's colours and settings, the night light, the wind, the key and
## fill, the post's grade and the hour (its own preset's where a region's is
## -1), so the sky eases over a border band as the eye crosses it. Off once
## --mood=, --hour=, --day, L or T takes the look over.
func blend_moods(list: Array) -> void:
	if not world_paint or list.is_empty() or celestial == null: return
	var total := 0.0
	for e: Array in list: total += float(e[2])
	if total <= 0.0: return
	var colors := {}
	var settings := {}
	var night := Vector3.ZERO
	var wind := 0.0
	var tune := {}
	var hour_at := 0.0
	var heaviest := -1.0
	var so_far := 0.0
	for e: Array in list:
		var id := str(e[0])
		if not Presets.PRESETS.has(id): id = MOOD
		var w := float(e[2])/total
		if w > heaviest:
			heaviest = w
			mood = id
		var doc: Dictionary = Presets.look_document(id)
		# The colours mix one mood at a time into the running mix, by hue,
		# saturation and lightness (OkHSL): a straight RGB mix of the alpine
		# blue and the desert's violet and orange greys and darkens half way.
		so_far += w
		var into := w/so_far if so_far > 0.0 else 1.0
		for k: String in doc.colors:
			var c: Array = doc.colors[k]
			var col := Color(float(c[0]),float(c[1]),float(c[2]))
			var acc: Variant = colors.get(k)
			colors[k] = col if acc == null else mix_hue(acc as Color,col,into)
		for k: String in doc.settings: settings[k] = float(settings.get(k,0.0))+float(doc.settings[k])*w
		var c: Dictionary = Presets.controls(id)._celestial
		night += Vector3(float(c.night_fill),float(c.night_look),float(c.aurora_strength))*w
		wind += clampf(float(Presets.recipe(id).wind),0.3,1.2)*w
		var t := EndlessPost.tuning(id)
		for k: String in t:
			var v: Variant = t[k]
			if v is Vector3: tune[k] = (tune.get(k,Vector3.ZERO) as Vector3)+v*w
			elif v is float or v is int: tune[k] = float(tune.get(k,0.0))+float(v)*w
			elif not tune.has(k): tune[k] = v
		var h := float(e[1])
		if h < 0.0: h = float(Presets.recipe(id).phase)*24.0
		hour_at += h*w
	celestial.night_fill = night.x
	celestial.night_look = night.y
	celestial.aurora_strength = night.z
	_wind = wind
	_key = float(tune.key)*_key_arg
	_fill = float(tune.fill)*_fill_arg
	if post != null: post.set_tuning(tune)
	if not cycle.running and not _hour_taken: celestial.set_phase(hour_at/24.0)
	var encoded := {}
	for k: String in colors:
		var c: Color = colors[k]
		encoded[k] = [c.r,c.g,c.b]
	celestial.look.restore({"version":1,"palette":"Custom","colors":encoded,"settings":settings})
	celestial.update_rig()

## Colour a toward b by t, by hue (the short way round, unless that passes
## the greens), saturation and
## lightness in OkHSL: the middle is as bright and as clean as the ends. A
## grey end takes the other's hue. Colours past 1 (light, not paint) mix
## straight.
static func mix_hue(a: Color, b: Color, t: float) -> Color:
	if t <= 0.0: return a
	if t >= 1.0: return b
	if maxf(maxf(a.r,a.g),a.b) > 1.0 or maxf(maxf(b.r,b.g),b.b) > 1.0: return a.lerp(b,t)
	var sa := a.ok_hsl_s
	var sb := b.ok_hsl_s
	var ha := a.ok_hsl_h
	var hb := b.ok_hsl_h
	# Below a little saturation the hue means nothing: borrow the other's,
	# easing in, so a grey never snaps.
	var ga := smoothstep(0.0,0.06,sa)
	var gb := smoothstep(0.0,0.06,sb)
	var dh := wrapf(hb-ha,-0.5,0.5)
	var ha2 := ha+dh*(1.0-ga)*gb
	var hb2 := ha+dh-dh*(1.0-gb)*ga
	ha = ha2
	dh = hb2-ha2
	# Never through the greens (the short way from the alpine glow's cyan to
	# the desert's orange would pass a green neither sky has): the other way
	# round, by violet and rose, as a sky turns at dusk. A green end (the
	# grass, the foliage) turns the short way.
	var green_end := absf(wrapf(ha-HUE_GREEN,-0.5,0.5)) < 0.12 or absf(wrapf(ha+dh-HUE_GREEN,-0.5,0.5)) < 0.12
	if not green_end and _turns_through(ha,dh,HUE_GREEN): dh -= signf(dh)
	# A wide turn (past HUE_WIDE) pales on its way, so the hues it passes
	# (violet, rose) show as a light haze, not a sky of their own.
	var s := lerpf(sa,sb,t)
	if absf(dh) > HUE_WIDE: s *= 1.0-HUE_PALE*4.0*t*(1.0-t)*clampf((absf(dh)-HUE_WIDE)/0.15,0.0,1.0)
	return Color.from_ok_hsl(wrapf(ha+dh*t,0.0,1.0),s,lerpf(a.ok_hsl_l,b.ok_hsl_l,t))

## The green (OkHSL hue, of a full turn) mix_hue never turns through.
const HUE_GREEN := 0.42
## A turn of hue past this pales by up to HUE_PALE at its middle.
const HUE_WIDE := 0.2
const HUE_PALE := 0.55

## Whether hue h turned by dh passes hue g.
static func _turns_through(h: float, dh: float, g: float) -> bool:
	var to := wrapf(g-h,0.0,1.0)
	return to <= dh if dh >= 0.0 else to >= 1.0+dh

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
		water.set_wind(_wind_angle,_wind)
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
	_river_live(land_seed)
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--river-knob="):
			ground.set_shader_parameter(arg.get_slice("=",1),str_to_var(arg.get_slice("=",2)))

## Rivers as moving water (unless --river-live=0, river-live-handoff.md): the
## ground shader's live path, which reads the channel frame the land's
## chunks carry in CUSTOM2 (LandStream river_live_wanted). A noise height
## map and its normals for the riffles, foam and the bed; and, with the
## sea's FFT cascades running (not --sea-fft=0, and a rendering device), their
## slopes for the ripples, else the sea's noise maps. Off, nothing is set.
func _river_live(land_seed: int) -> void:
	if not LandStream.river_live_wanted(): return
	ground.set_shader_parameter("river_live",1.0)
	var noise := FastNoiseLite.new()
	noise.seed = land_seed+41
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	for normals in [false,true]:
		var tex := NoiseTexture2D.new()
		tex.width = 512
		tex.height = 512
		tex.seamless = true
		tex.as_normal_map = normals
		tex.bump_strength = 8.0
		tex.normalize = true
		tex.generate_mipmaps = true
		tex.noise = noise
		ground.set_shader_parameter("river_live_normal" if normals else "river_live_height",tex)
	if water != null and water.fft != null:
		ground.set_shader_parameter("river_fft",1)
		ground.set_shader_parameter("river_fft_maps",water.fft.texture)
		ground.set_shader_parameter("river_fft_sizes",water.fft.knobs.sizes)

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
	# Last frame's collar sky off again, unless the phase was set since.
	if _sky_phase >= 0.0 and is_equal_approx(float(celestial.phase),_sky_phase): celestial.phase = _land_phase
	_sky_phase = -1.0
	if cycle.moving():
		cycle.advance(delta)
		celestial.phase = cycle.phase()
	else: cycle.follow(celestial.phase)
	_land_phase = float(celestial.phase)
	_collar_hour(eye)
	celestial.advance(delta,false)
	if _light_on:
		sun.light_energy *= _key
		RenderingServer.global_shader_parameter_set("zs_hemi_energy",float(celestial.state.zs_hemi_energy)*_fill)
	_sheen_pace = WorldProfile.current().sheen_pace_at(eye.x,eye.z)
	_eye = eye
	_publish(delta)
	_haze(facing)
	if post != null: post.step(view,self,facing)
	ground.set_shader_parameter("night_grade",celestial.night_grade)
	RenderingServer.global_shader_parameter_set("zs_camera_position",eye)
	sea.position = Vector3(snappedf(eye.x,64.0),Field.SEA_Y,snappedf(eye.z,64.0))
	if water != null: water.step(delta,eye,plane_at,facing,_time,view)
	if clouds != null: clouds.step(delta,view,wind_direction,_time)
	if land_shade != null:
		# The key light the clouds' shade takes: the sun, the moon by night.
		var s: Vector3 = Vector3(celestial.state.get("zs_sun_direction",Vector3.UP)).normalized()
		var m: Vector3 = Vector3(celestial.state.get("zs_moon_direction",Vector3.DOWN)).normalized()
		land_shade.step(eye,s.lerp(m,smoothstep(0.05,-0.1,s.y)).normalized(),delta)

func _publish(delta: float) -> void:
	_time += delta
	# The wind wanders a little round its heading, its strength breathing.
	var angle := _wind_angle+0.35*sin(_time*0.013)
	var strength := _wind*(0.85+0.15*sin(_time*0.21)*sin(_time*0.077))
	if wind != null:
		# The field's: the hour, the day's temper, the place under the eye.
		_wind_clock += delta
		wind.step(0.0,_wind_clock,float(celestial.phase)*24.0,cycle.day,cycle.t/cycle.length,delta)
		# Past the bake (the doors' far half: the amberlands) the mood's one
		# wind as before.
		var reach := wind.reach(_eye.x,_eye.z)
		angle = lerp_angle(angle,wind.heading,reach)
		var at_eye := wind.wind_at(_eye.x,_eye.z)
		var here := lerpf(strength,at_eye,reach)
		var ease := 1.0-exp(-delta*1.5)
		_wind_here = here if _wind_here < 0.0 else lerpf(_wind_here,here,ease)
		strength = _wind_here
		# The breeze the near plants lean in (the near tufts, flowers, spruce):
		# the field's at the eye; a light day's (zs_breeze's own) past its land.
		var breeze := lerpf(BREEZE,WindField.breeze_of(at_eye),reach)
		_breeze_here = breeze if _breeze_here < 0.0 else lerpf(_breeze_here,breeze,ease)
		RenderingServer.global_shader_parameter_set("zs_breeze",_breeze_here)
		_publish_field()
		if wind_map != null: wind_map.step(delta,_eye)
	var travel := delta*AIR_SPEED*(0.5+0.5*minf(strength,2.0)/WIND)
	_gust += travel
	_sheen += travel*_sheen_pace
	wind_direction = Vector2(cos(angle),sin(angle))
	RenderingServer.global_shader_parameter_set("zs_motion_time",_time)
	RenderingServer.global_shader_parameter_set("zs_flow_time",_time)
	RenderingServer.global_shader_parameter_set("zs_wind_direction",Vector2(cos(angle),sin(angle)))
	RenderingServer.global_shader_parameter_set("zs_wind_strength",strength)
	RenderingServer.global_shader_parameter_set("zs_gust_distance",_gust)
	RenderingServer.global_shader_parameter_set("zs_sheen_distance",_sheen)
	RenderingServer.global_shader_parameter_set("zs_gust_speed",AIR_SPEED)

## The wind field to the shaders (shaders/wind_field.gdshaderinc): its factor
## now, how far its bake has come in, a fixed strength, its patches, and the
## baked exposure as a texture once it lands.
func _publish_field() -> void:
	if wind.baked and _wind_texture == null:
		_wind_texture = wind.texture()
		if _wind_texture != null:
			RenderingServer.global_shader_parameter_set("zs_wind_exposure",_wind_texture)
			RenderingServer.global_shader_parameter_set("zs_wind_rect",wind.rect())
	if _wind_texture == null and wind.n >= 2: RenderingServer.global_shader_parameter_set("zs_wind_rect",wind.rect())
	var fixed := wind.fixed if wind.mode == "fixed" else -1.0
	RenderingServer.global_shader_parameter_set("zs_wind_field",Vector4(WindField.PEAK*wind.now,wind.come_in() if _wind_texture != null else 0.0,fixed,1.0))
	for i in 5:
		RenderingServer.global_shader_parameter_set("zs_wind_patch_%d" % i,wind.blobs[i] if i < wind.blobs.size() else Vector4(0.0,0.0,1.0,0.0))

## The Peak's collar keeps its own sky: the land's hour below the band
## (`lo`..`hi`, m over the sea, as EndlessClouds.set_collar), the collar's
## above it (`hour`, or its golden hour with -1), blended by the eye's
## height through the band, near the collar only.
func set_collar_sky(centre: Vector3, radius: float, lo: float, hi: float, hour := -1.0) -> void:
	var h := hour
	for a: String in LaunchArgs.user_args():
		if a == "--collar-sky=0": return
		if a.begins_with("--collar-hour="): h = clampf(a.get_slice("=",1).to_float(),0.0,24.0)
	_collar_phase = h/24.0 if h >= 0.0 else DayCycle.ring_phase(COLLAR_SUN,false)
	_collar_sky = {"centre":Vector2(centre.x,centre.z),"radius":radius,"lo":lo+Field.SEA_Y,"hi":hi+Field.SEA_Y}

## The Peak's side light: the day's ring turned about the vertical (the room's
## yaw, sun, moon, rim, stars and sky together) so that at the world's opening
## hour the sun stands `PEAK_SUN` degrees clockwise of `way` (the way in, flat,
## world x and z). The hour, the sun's height and the day's length stay the
## land's: only where the compass stands moves. --peak-sun=DEG another bearing,
## --peak-sun=off leaves the ring as it was.
func turn_ring_to(way: Vector2) -> void:
	var off := PEAK_SUN
	for a: String in LaunchArgs.user_args():
		if a == "--peak-sun=off": return
		if a.begins_with("--peak-sun="): off = a.get_slice("=",1).to_float()
	var hour := float(WorldProfile.current().paint.get("hour",HOUR))
	if hour < 0.0: hour = HOUR
	var at: Vector3 = celestial.floored(celestial.ring_at(hour/24.0))
	var want := atan2(way.x,-way.y)+deg_to_rad(off)
	celestial.room_yaw = wrapf(atan2(at.x,-at.z)-want,-PI,PI)
	celestial.update_rig()

## The phase the sky shows at `eye`: the land's, turned the short way round
## toward the collar's by the lift.
func _collar_hour(eye: Vector3) -> void:
	collar_lift = 0.0
	if _collar_sky.is_empty(): return
	var d := Vector2(eye.x,eye.z).distance_to(_collar_sky.centre)-float(_collar_sky.radius)-COLLAR_NEAR
	collar_lift = smoothstep(float(_collar_sky.lo),float(_collar_sky.hi),eye.y)*(1.0-smoothstep(0.0,COLLAR_FADE,d))
	if collar_lift <= 0.0: return
	var turn := wrapf(_collar_phase-_land_phase,-0.5,0.5)
	_sky_phase = fposmod(_land_phase+turn*collar_lift,1.0)
	celestial.phase = _sky_phase
	_sky_phase = float(celestial.phase)

## The land's phase (0..1): the clock's, whatever the collar's sky shows.
func land_phase() -> float:
	if _sky_phase >= 0.0 and is_equal_approx(float(celestial.phase),_sky_phase): return _land_phase
	return float(celestial.phase)

## The haze's colour: the sky's at the horizon toward `facing` (the
## dome's zsSkyBase, shaders/reference_sky_common.gdshaderinc, at y 0 and
## taken from display to scene light as the dome takes it).
func _haze(facing: Vector3) -> void:
	var c := horizon(facing)
	var top := maxf(maxf(c.r,c.g),maxf(c.b,1e-4))
	environment.fog_light_color = Color(c.r/top,c.g/top,c.b/top).linear_to_srgb()
	environment.fog_light_energy = top
	var k := float(celestial.state.get("zs_haze_sun",0.0))
	environment.fog_aerial_perspective = lerpf(AERIAL,AERIAL_SUN,k)
	environment.fog_sun_scatter = lerpf(SUN_SCATTER,SUN_SCATTER_SUN,k)
	_haze_ground(c,k)

## The haze the ground lays itself (so its height term can thin it): the
## engine's own numbers, colour and sun, for shaders/endless_height_haze.gdshaderinc.
func _haze_ground(c: Color, k: float) -> void:
	if ground == null: return
	var lc := sun.light_color.srgb_to_linear()*sun.light_energy
	for g: ShaderMaterial in [ground]+ground_copies:
		g.set_shader_parameter("haze_depth",Vector4(environment.fog_depth_begin,environment.fog_depth_end,environment.fog_depth_curve,environment.fog_density))
		g.set_shader_parameter("haze_light",Vector3(c.r,c.g,c.b))
		g.set_shader_parameter("haze_mix",Vector2(environment.fog_aerial_perspective,environment.fog_sun_scatter))
		g.set_shader_parameter("haze_sun",Vector3(lc.r,lc.g,lc.b))

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
	var k := float(st.get("zs_haze_sun",0.0))
	var dusk := float(st.zs_dusk_direction)
	var was := col+glow*lerpf(1.0,to_sun*to_sun*1.6+0.08,dusk)
	col += glow*lerpf(1.0,to_sun*to_sun*1.6+0.08,lerpf(dusk,1.0,k*HAZE_GATHER))
	if k > 0.001:
		var luma := Vector3(0.2126,0.7152,0.0722)
		var zen := Vector3.ONE.lerp(up/maxf(up.dot(luma),1e-4),HAZE_BLUE)
		zen /= zen.dot(luma)
		col = col.lerp(zen*was.dot(luma),(1.0-to_sun)*(1.0-to_sun)*k*HAZE_COOL)
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

## The next stop of the day (dawn, noon, dusk, the blue hour), swept to
## through the hours between.
func next_hour() -> void:
	_hour_taken = true
	cycle.follow(land_phase())
	cycle.next_stop()

## Time faster or slower (DayCycle SPEEDS: 1, 8, 30, 120 times).
func faster() -> void: cycle.faster()
func slower() -> void: cycle.slower()

## The clock for the HUD: the part of the day, and how fast it runs if not
## at its own pace, or that it stands still.
func time_note() -> String:
	var s := cycle.part()
	if not cycle.running: s += ", still"
	elif cycle.speed() > 1.0: s += ", x%d" % int(cycle.speed())
	return s

## The hour now (0..24).
func hour() -> float:
	return fposmod(land_phase(),1.0)*24.0

func _exit_tree() -> void:
	if post != null: post.free_buffers()
	if water != null: water.finish()
	if wind != null:
		wind.finish_bake()
		# The next scene's shaders blow no field till it publishes its own.
		RenderingServer.global_shader_parameter_set("zs_wind_field",Vector4(0.0,0.0,-1.0,0.0))
		RenderingServer.global_shader_parameter_set("zs_breeze",BREEZE)
