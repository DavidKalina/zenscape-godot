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
##   sea            shaders/sky_ocean.gdshader (the plane-height sea) on
##                  SkyBelow's ringed sheet, following the eye.
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
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Presets = preload("res://scripts/scene_look_presets.gd")
const EndlessClouds = preload("res://scripts/endless/endless_clouds.gd")

## The moods L steps through (no winter: the season stays off it), and the
## one it opens on.
const MOODS := ["alpine_morning","golden_meadow","ocean_light","meadow_morning","after_the_rain","desert_afternoon","rosewater_dusk","rose_dusk","moonlit_stillness"]
const MOOD := "alpine_morning"
## The hour it opens on with no --mood or --hour: early morning, the sun
## low enough to model the hills (the mood's own is mid-morning).
const HOUR := 7.6

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
var ground: ShaderMaterial
var _time := 0.0
var _gust := 0.0
var _wind_angle := 0.0
var _wind := WIND
var mood := MOOD
## The clouds (scripts/endless/endless_clouds.gd), or null (--no-clouds, no
## RenderingDevice).
var clouds: Node3D
## The wind's heading over the ground now (unit xz).
var wind_direction := Vector2.RIGHT

## Whether the full look runs (not --plain-look, not the Compatibility
## renderer).
static func wanted() -> bool:
	if "--plain-look" in LaunchArgs.user_args(): return false
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

func setup(land_seed: int) -> void:
	name = "Look"
	var hour := -1.0
	var day := false
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--hour="): hour = clampf(a.get_slice("=",1).to_float(),0.0,24.0)
		elif a == "--day": day = true
		elif a.begins_with("--mood=") and a.get_slice("=",1) in MOODS: mood = a.get_slice("=",1)
	# The opening mood at HOUR; another at its own hour.
	if hour < 0.0 and mood == MOOD: hour = HOUR
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
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = FOG_CURVE
	environment.fog_aerial_perspective = AERIAL
	environment.fog_sky_affect = 0.0
	environment.fog_sun_scatter = SUN_SCATTER
	environment.fog_light_energy = 1.0
	_wind_angle = float(absi(hash(land_seed))%6283)/1000.0
	ground = ShaderMaterial.new()
	ground.shader = preload("res://shaders/endless_ground.gdshader")
	ground.set_shader_parameter("sea_y",Field.SEA_Y)
	ground.set_shader_parameter("beach",Field.BEACH)
	ground.set_shader_parameter("snow_line",Field.SNOW)
	_build_sea()
	if EndlessClouds.wanted():
		clouds = EndlessClouds.new()
		add_child(clouds)
		clouds.setup(land_seed,celestial,Vector4(FOG_BEGIN,FOG_END,FOG_CURVE,CLOUD_HAZE),SUN_SCATTER*0.5)
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
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = SkyBelow._sheet()
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.extra_cull_margin = 16384.0
	sea.position.y = Field.SEA_Y
	add_child(sea)

## One frame: the hour, the wind and the clocks the shaders read, the sea
## under the eye, then the clouds round `view` (the camera that draws).
func step(delta: float, eye: Vector3, facing := Vector3.FORWARD, view: Camera3D = null) -> void:
	celestial.advance(delta,false)
	_publish(delta)
	_haze(facing)
	ground.set_shader_parameter("night_grade",celestial.night_grade)
	RenderingServer.global_shader_parameter_set("zs_camera_position",eye)
	sea.position = Vector3(snappedf(eye.x,64.0),Field.SEA_Y,snappedf(eye.z,64.0))
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
