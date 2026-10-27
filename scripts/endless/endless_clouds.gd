extends Node3D
## The endless flight's clouds (docs/design/endless-flight/clouds-round-handoff.md):
## the isles' raymarched cloud volume (scripts/cloud_volume.gd's passes, on
## the camera's compositor, resolved over frames and laid into the scene by
## a sheet in the see-through pass) over a field of cumulus that never runs
## out, marched by shaders/endless_cloud_march.glsl.
##
##   the field   cells hashed from the land's seed, in the wind's drifting
##               frame (so flying any way keeps meeting new cloud, and the
##               cloud drifts): broad cumulus (some low enough to fly into,
##               most standing over the flight's ceiling as a roof, the odd
##               tower) and small puffs low in the band. `clouds_in` has
##               the same field on the CPU.
##   meadows     a ground map (meadow, height) worked out on a worker round
##               the eye: over the meadows the low cloud is lifted
##               MEADOW_CLEAR m clear of the turf and thinned, so they stay
##               landable; no cloud's base goes under the ground.
##   light       the mood's sun and sky (scripts/shared/celestial.gd globals) in
##               the cumulus palette, the land's haze over far cloud
##               (shaders/endless_cloud_composite.gdshader).
##   shade       the cloud's shadow on the land and the sea: the shade map
##               over SHADE_SIDE m round the eye, published as the isles' do
##               (zs_cloud_shadow*, shaders/cloud_volume_shadow.gdshaderinc,
##               read by shaders/endless_ground.gdshader and the sea's
##               `cloud_shade`).
##
## Flags: --no-clouds leaves them out; --cloud-cover=X scales how much sky
## they take (1; 0.5 sparse, 1.6 heavy); --cloud-haze=X the share of the
## land's haze laid on them (EndlessLook CLOUD_HAZE); --cloud-steps=N the
## march's steps (QUALITY); every pixel is marched (--cloud-half-res: one
## in four, as before); --cloud-grain=old the earlier grain; --cloud-blend=m,u
## the resolve's blends; --cloud-field=old the earlier field (a near-grid of
## four-bubble mushrooms with flat bases; docs/design/endless-flight/
## cloud-shape-handoff.md). --cloud-stack=old lets two clouds of one layer
## stand one over the other again (the map's one span per layer drew them as
## a mushroom on a stem; docs/design/endless-flight/cloud-water-fix-handoff.md);
## --cloud-puffs=old the small puffs as smooth bells again.
## C turns them off and on.
##
## The valley fog (docs/design/endless-flight/valley-fog-handoff.md): a low
## layer in the same march, lying along the valleys between the ridges, from
## a fog map baked off the land's shape (`fog_image`: the ground, the
## nearest valley's floor, how much fog the valley holds there) round the
## eye on a worker. --no-valley-fog leaves it out; --valley-fog=X scales its
## density (1); --valley-fog-depth=M how deep it lies over a floor
## (FOG_DEPTH); --valley-fog-steps=N its march's steps (FOG_STEPS).

const Effect = preload("res://scripts/endless/endless_cloud_effect.gd")
const CumulusNoise = preload("res://scripts/cumulus_noise.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const StormTowers = preload("res://scripts/endless/storm_towers.gd")

const OFF_FLAG := "--no-clouds"
## Drawn after the sea (EndlessLook SEA_PRIORITY) and before anything else
## see-through.
const RENDER_PRIORITY := -6
## How far out cloud is marched (m) and the slab's top (m over the sea).
const REACH := 7800.0
const TOP := 1250.0
## The slab's top with a storm's towers in it (TOP + STORM_GROW_TOP and
## their billows).
const STORM_TOP := 2800.0
## A cloud the storm pushes (StormFront.push_at; the march's SP_*, shaders/
## storm_cloud.glslinc, keep equal): wider and taller, its top higher, the
## share of broad cells turned to towers, more domes, a deeper belly, the
## most its reach spans (cells), the base it sinks to.
const STORM_GROW := Vector2(1.9,1.8)
const STORM_GROW_TOP := 1450.0
const STORM_TOWERS := 0.75
const STORM_DOMES := 3.0
const STORM_BELLY := 1.3
const STORM_EXT := 1.9
const STORM_BASE := Vector2(60.0,110.0)
## Behind the core, where the deck lets go, a pushed cell's base at least
## this (the march's SP_TRAIL_BASE).
const STORM_TRAIL_BASE := Vector2(230.0,300.0)
## A small puff (never pushed) thins away over this much of the push (the
## march's SP_SMALL_GO).
const STORM_SMALL_GO := Vector2(0.03,0.3)
## A cell only the storm stands up grows in from a wisp over this much of
## its push past its own hash (the march's SP_ADMIT).
const STORM_ADMIT := 0.12
## The weather map's square round the eye: the reach and this much past it.
const WEATHER_PAST := 250.0
## The shade on the land: its square's side (m).
const SHADE_SIDE := 6000.0
## The wind carries the field at this speed (m/s).
const WIND_SPEED := 3.2
## Cloud life (shaders/endless_cloud_march.glsl `cell_life`): each cloud's
## cycle runs about LIFE_PERIOD s (0.6 to 1.5 times by the cloud), growing
## over the first 30 % and thinning away over the last 32 %; the low layer
## drifts at LOW_WIND times the wind and the high layer at HIGH_WIND.
const LIFE_PERIOD := 110.0
const LIFE_COVER := 1.6
const LOW_WIND := 0.8
const HIGH_WIND := 2.0
## The low cloud over a meadow stands at least this far over the turf (m).
const MEADOW_CLEAR := 70.0
## The small puffs' cover, the broad cumulus' share that hang low, and the
## share that tower (mirrored in the march: knobs).
const SMALL_COVER := 0.34
const LOW_SHARE := 0.3
const TOWER_SHARE := 0.12
## The march: steps, light taps, the march's scale (1: every pixel;
## --cloud-half-res 2, half the render each axis), fine octaves near the eye.
const QUALITY := [110,5,1,1]
## The weather map and the shade redrawn every this many frames.
const WEATHER_EVERY := 2
const SHADE_EVERY := 2
## The weather map drawn this many slices of rows a frame, into a second map
## that takes over when whole (scripts/cloud_volume_effect.gd
## weather_slices): about 1/WEATHER_SLICES of a whole draw a frame, the map
## at most two cycles old (0.27 s at 60 fps; the high layer drifts under
## 2 m of its 15 m texels in that). --cloud-weather-slices=N, 0 the whole map
## every WEATHER_EVERY frames as before.
const WEATHER_SLICES := 8
## The ground map: texels a side, its side (m), redrawn when the eye is
## this far from its middle (m).
const GROUND_TEXELS := 160
const GROUND_SIDE := 20000.0
const GROUND_MOVE := 1800.0
## The valley fog's map: texels a side, its side (m), redrawn when the eye is
## this far from its middle (m); the fog is drawn out to FOG_REACH m (faded
## over the last FOG_FADE), well inside the map wherever the eye is.
const FOG_TEXELS := 384
const FOG_SIDE := 12000.0
const FOG_MOVE := 1400.0
const FOG_REACH := 4400.0
const FOG_FADE := 1100.0
## How deep the fog lies over a valley's floor at most (m, before the
## patches thin it), its march's steps, and how fast its patches drift on
## the wind (a share of the clouds').
const FOG_DEPTH := 40.0
const FOG_STEPS := 32
const FOG_DRIFT := 0.3
const MARCHED_BLEND := 0.5
const UPSAMPLED_BLEND := 0.08
## Less grain: the new jitter, the resolve's 3x3 filter and sigma clip
## (shaders/endless_cloud_resolve.glsl) and a longer history. --cloud-grain=old
## runs the earlier look; --cloud-blend=m,u sets the two blends by hand.
const GRAIN_MARCHED_BLEND := 0.2
const GRAIN_UPSAMPLED_BLEND := 0.06

# The field, as the march has it (shaders/endless_cloud_march.glsl).
const BIG := 620.0
const BIG_R := Vector2(0.16,0.40)
const LOW_BASE := Vector2(26.0,60.0)
const MID_BASE := Vector2(128.0,190.0)
const TOWER_BASE := Vector2(115.0,160.0)
const LOW_TALL := Vector2(0.8,1.4)
const MID_TALL := Vector2(0.7,1.3)
const TOWER_TALL := Vector2(1.2,1.9)
const TOWER_WIDE := 1.35
const BIG_COVER := 0.72
const SMALL := 230.0
const SMALL_R := Vector2(0.13,0.30)
const SMALL_BASE := Vector2(22.0,115.0)
const SMALL_TALL := Vector2(0.8,1.5)
const REGION := 5200.0
const PROFILE := 0.42
const MAIN_R := 0.74
const CURL := 0.3
const REGION_SCALE := Vector2(0.3,1.45)

# The organic field (the march's `recipe`, `bubble_span`): clouds gather in
# fields under a cluster gate, jitter well past their cells, and come in
# kinds with 2 to 9 wobbly bubbles, rounded bellies and their own heights.
const JIT := 0.62
const EXT_MAX := 0.85
const CLUSTER := 2600.0
const CLUSTER_GATE := Vector2(0.36,0.66)
const BIG_COVER2 := 1.0
const SMALL_COVER2 := 0.27
const FAIR_SHARE := 0.28
const TOWER_SHARE2 := 0.08
const ROW_SHARE := 0.14
const WISP_SHARE := 0.08
const BIG_R2 := Vector2(0.09,0.44)
const SMALL_R2 := Vector2(0.10,0.32)
const SIZE_SKEW := 1.5
const WOB := 0.2
const LIFT := 0.3
const DOME := 1.6
## The march's YIELD_LEVEL (`clash`).
const YIELD_LEVEL := 0.5

var effect := Effect.new()
var material := ShaderMaterial.new()
var sheet := MeshInstance3D.new()
var camera: Camera3D
var celestial: RefCounted
var land_seed := 0
var salt := 0
var cover := 1.0
## The march's quality this run (QUALITY; --cloud-full-res marches every
## pixel, --cloud-steps=N sets the steps).
var quality: Array = QUALITY.duplicate()
## The grain treatment (--cloud-grain=old turns it off) and the blends.
var grain := true
var marched_blend := GRAIN_MARCHED_BLEND
var upsampled_blend := GRAIN_UPSAMPLED_BLEND
var enabled := true
## The organic field (false: --cloud-field=old).
var organic := true
## Two clouds of one layer, one over the other, never both placed (the
## march's `yields`; false: --cloud-stack=old, the mushrooms and stems).
var stack_yield := true
## Thin low cloud (the small puffs) takes its lobes from finer noise, so a
## puff reads as a small cumulus, not a smooth bell (--cloud-puffs=old: off).
var puff_lobes := true
## The sea's material (EndlessLook sets it): it reads the shade map with the
## square drawn this frame (`shade_square`), not the land's (--sea-shade=old).
var sea_material: ShaderMaterial
## The storm front (scripts/endless/storm_front.gd), set by the study when
## --storm asks for one, or null: it pushes the field's own clouds
## (shaders/storm_cloud.glslinc; `_recipe` here).
var storm: RefCounted
## The storm's cumulonimbus (scripts/endless/storm_towers.gd), made with the
## first frame that has a storm; null without one or with --storm-towers=0.
var towers: RefCounted
var _towers_made := false
var _towers_tick := 0
## The march's cost view (--cloud-cost-view=N, 0 off): the march shows what a
## pixel cost as grey instead of the cloud (shaders/endless_cloud_march.glsl
## cost_view).
var cost_view := 0.0
var sea_shade_sync := true
## The field's drift so far (m): a cloud stands at its field point plus this.
var drift := Vector2.ZERO
var motion_time := 0.0
## Cloud life (--cloud-life=0 off, =X scales the cycle's length; --cloud-shear=
## X scales how far the layers' winds differ, 0 one wind; --cloud-clock=S starts
## the clouds S seconds into their life, for stills).
var life := true
var life_scale := 1.0
var shear := 1.0
var clock_start := 0.0
var _clock_pending := false
var drift_lo := Vector2.ZERO
var drift_hi := Vector2.ZERO
var weather_corner := Vector2.ZERO
var weather_side := 0.0
## The draw distance (LandStream.view()): the march reaches REACH times it.
var _view: float = preload("res://scripts/endless/land_stream.gd").view()
var shade_at := Vector4.ZERO
## The ground map: its texture, its square (corner, side), its worker.
var ground := ImageTexture.new()
var ground_at := Vector4.ZERO
var _ground_task := -1
var _ground_image: Image
var _ground_next := Vector4.ZERO
## The ground map the march reads, kept for the CPU field (`_cloud_floor`).
var _ground_cpu: Image
## The valley fog: on, its density, depth and steps (the flags), its map.
var fog_on := true
## The fog's look (floor share, density scale, top thinning): the soft one
## by default, --fog=old the first pass's (valley-fog-handoff.md).
var fog_look := Vector4(0.8,0.35,0.6,0.0)
var fog_gain := 0.75
var fog_density := 1.0
## 0..1: the valley fog thinned toward none (a tunnel's dark inside sets it,
## scripts/endless/land_tunnels.gd); 0 leaves it as it is.
var fog_hush := 0.0
var fog_depth := FOG_DEPTH
var fog_steps := FOG_STEPS
var fog := ImageTexture.new()
var fog_at := Vector4.ZERO
var fog_top := -1e3
var _fog_task := -1
var _fog_image: Image
var _fog_next := Vector4.ZERO
var _fog_next_top := -1e3
var _frame := 0
var _prev_view := Projection.IDENTITY
var _prev_lens := Vector2.ONE
var _has_prev := false
var _shade_drawn := Vector4.ZERO
var _shade_published := false

## Whether the clouds run: not --no-clouds, and a RenderingDevice to march
## on (none headless or under the Compatibility renderer).
static func wanted() -> bool:
	return not OFF_FLAG in LaunchArgs.user_args() and RenderingServer.get_rendering_device() != null

func _init() -> void:
	name = "Clouds"
	material.shader = preload("res://shaders/endless_cloud_composite.gdshader")
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
	sheet.custom_aabb = AABB(Vector3.ONE*-1e6,Vector3.ONE*2e6)
	sheet.visible = false
	add_child(sheet)

func setup(seed_value: int, sky: RefCounted, haze: Vector4, sun_scatter: float) -> void:
	land_seed = seed_value
	salt = (absi(hash(seed_value*7919+13))%100000)
	celestial = sky
	# On a Mac the half-res march is the default (endless_look.gd mac_trades).
	if OS.get_name() == "macOS" and not "--mac-trades=0" in LaunchArgs.user_args(): quality[2] = 2
	# So on a discrete GPU drawing at the window's own resolution: 2.6 to
	# 3.4 ms back at 1440p, and the march still 720 lines high, its edges a
	# touch softer (docs/design/endless-flight/aa-view-handoff.md).
	if preload("res://scripts/endless/land_stream.gd").high_end(): quality[2] = 2
	effect.weather_slices = WEATHER_SLICES
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--cloud-weather-slices="): effect.weather_slices = clampi(int(a.get_slice("=",1)),0,64)
		if a.begins_with("--cloud-cover="): cover = clampf(a.get_slice("=",1).to_float(),0.0,3.0)
		elif a == "--cloud-full-res": quality[2] = 1
		elif a == "--cloud-half-res": quality[2] = 2
		elif a == "--cloud-field=old": organic = false
		elif a == "--cloud-stack=old": stack_yield = false
		elif a == "--cloud-puffs=old": puff_lobes = false
		elif a.begins_with("--cloud-life="):
			life_scale = maxf(a.get_slice("=",1).to_float(),0.0)
			if life_scale <= 0.0: life = false
		elif a.begins_with("--cloud-shear="): shear = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--cloud-clock="):
			clock_start = a.get_slice("=",1).to_float()
			_clock_pending = clock_start != 0.0
		elif a == "--sea-shade=old": sea_shade_sync = false
		elif a.begins_with("--cloud-cost-view="):
			cost_view = a.get_slice("=",1).to_float()
			effect.cost_view = cost_view > 0.0
		elif a.begins_with("--cloud-steps="): quality[0] = clampi(int(a.get_slice("=",1)),16,160)
		elif a == "--no-valley-fog": fog_on = false
		elif a == "--fog=old":
			fog_look = Vector4(0.12,1.0,0.0,0.0)
			fog_gain = 1.0
		elif a.begins_with("--fog-gain="): fog_gain = a.get_slice("=",1).to_float()
		elif a.begins_with("--fog-look="):
			var fl := a.get_slice("=",1).split(",")
			if fl.size() >= 3: fog_look = Vector4(fl[0].to_float(),fl[1].to_float(),fl[2].to_float(),0.0)
		elif a.begins_with("--valley-fog="):
			fog_density = maxf(a.get_slice("=",1).to_float(),0.0)
			if fog_density <= 0.0: fog_on = false
		elif a.begins_with("--valley-fog-depth="): fog_depth = clampf(a.get_slice("=",1).to_float(),2.0,150.0)
		elif a.begins_with("--valley-fog-steps="): fog_steps = clampi(int(a.get_slice("=",1)),4,96)
		elif a == "--cloud-grain=old":
			grain = false
			marched_blend = MARCHED_BLEND
			upsampled_blend = UPSAMPLED_BLEND
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--cloud-blend="):
			var bl := a.get_slice("=",1).split(",")
			if bl.size() >= 2:
				marched_blend = clampf(bl[0].to_float(),0.02,1.0)
				upsampled_blend = clampf(bl[1].to_float(),0.01,1.0)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--cloud-haze="): haze.w = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
	material.set_shader_parameter("haze",haze)
	material.set_shader_parameter("fog_gain",fog_gain)
	material.set_shader_parameter("sea_y",Field.SEA_Y)
	material.set_shader_parameter("sun_scatter",sun_scatter)
	CumulusNoise.request()

func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_before_draw):
		RenderingServer.frame_pre_draw.connect(_before_draw)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw):
		RenderingServer.frame_pre_draw.disconnect(_before_draw)
	_detach()
	_publish_shade(false)
	if _ground_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ground_task)
		_ground_task = -1
	if _fog_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_fog_task)
		_fog_task = -1

## Each frame, after the sea has followed the eye: the camera that draws,
## the wind (a unit direction) the field drifts on, the clock.
func step(delta: float, view: Camera3D, wind: Vector2, time: float) -> void:
	if view != null and view.is_inside_tree():
		var drawing := view.get_viewport().get_camera_3d()
		if drawing != null: view = drawing
	if view != camera:
		_detach()
		camera = view
		if enabled: _attach()
	drift += wind*WIND_SPEED*delta
	if _clock_pending:
		# Stills: the field as it stands clock_start s into its drift.
		_clock_pending = false
		drift += wind*WIND_SPEED*clock_start
		drift_lo += wind*WIND_SPEED*lerpf(1.0,LOW_WIND,shear)*clock_start
		drift_hi += wind*WIND_SPEED*lerpf(1.0,HIGH_WIND,shear)*clock_start
	drift_lo += wind*WIND_SPEED*lerpf(1.0,LOW_WIND,shear)*delta
	drift_hi += wind*WIND_SPEED*lerpf(1.0,HIGH_WIND,shear)*delta
	motion_time = time
	if camera != null:
		_ground(camera.global_position)
		if fog_on: _fog(camera.global_position)
	sheet.visible = enabled and camera != null and ground_at.w > 0.5

## On or off (C): off, nothing is marched and the land takes no shade.
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
	if sea_material != null: sea_material.set_shader_parameter("shade_square",Vector4.ZERO)

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

# --- The ground map -------------------------------------------------------------------

## The ground map round `eye`: made at once the first time, then on a
## worker whenever the eye strays GROUND_MOVE m from its middle.
func _ground(eye: Vector3) -> void:
	if _ground_task >= 0 and WorkerThreadPool.is_task_completed(_ground_task):
		WorkerThreadPool.wait_for_task_completion(_ground_task)
		_ground_task = -1
		_take_ground()
	var middle := Vector2(ground_at.x,ground_at.y)+Vector2.ONE*ground_at.z*0.5
	var want := ground_at.w < 0.5 or Vector2(eye.x,eye.z).distance_to(middle) > GROUND_MOVE
	if not want or _ground_task >= 0: return
	var texel := GROUND_SIDE/GROUND_TEXELS
	var corner := ((Vector2(eye.x,eye.z)-Vector2.ONE*GROUND_SIDE*0.5)/texel).floor()*texel
	_ground_next = Vector4(corner.x,corner.y,GROUND_SIDE,1.0)
	if ground_at.w < 0.5:
		_ground_image = ground_image(land_seed,corner)
		_take_ground()
	else:
		_ground_task = WorkerThreadPool.add_task(func() -> void: _ground_image = ground_image(land_seed,corner),false,"Cloud ground map")

func _take_ground() -> void:
	if _ground_image == null: return
	_ground_cpu = _ground_image
	if ground.get_image() != null and ground.get_size() == Vector2(_ground_image.get_size()): ground.update(_ground_image)
	else: ground.set_image(_ground_image)
	ground_at = _ground_next

## The valley fog's map round `eye`, as the ground map is kept.
func _fog(eye: Vector3) -> void:
	if _fog_task >= 0 and WorkerThreadPool.is_task_completed(_fog_task):
		WorkerThreadPool.wait_for_task_completion(_fog_task)
		_fog_task = -1
		_take_fog()
	var middle := Vector2(fog_at.x,fog_at.y)+Vector2.ONE*fog_at.z*0.5
	var want := fog_at.w < 0.5 or Vector2(eye.x,eye.z).distance_to(middle) > FOG_MOVE
	if not want or _fog_task >= 0: return
	var texel := FOG_SIDE/FOG_TEXELS
	var corner := ((Vector2(eye.x,eye.z)-Vector2.ONE*FOG_SIDE*0.5)/texel).floor()*texel
	_fog_next = Vector4(corner.x,corner.y,FOG_SIDE,1.0)
	if fog_at.w < 0.5:
		_fog_image = fog_image(land_seed,corner)
		_take_fog()
	else:
		_fog_task = WorkerThreadPool.add_task(func() -> void: _fog_image = fog_image(land_seed,corner),false,"Valley fog map")

func _take_fog() -> void:
	if _fog_image == null: return
	if fog.get_image() != null and fog.get_size() == Vector2(_fog_image.get_size()): fog.update(_fog_image)
	else: fog.set_image(_fog_image)
	fog_at = _fog_next
	# The highest floor the fog lies on in this map (the march's slab top).
	var top := -1e3
	var n := _fog_image.get_width()
	for j in range(0,n,2):
		for i in range(0,n,2):
			var c := _fog_image.get_pixel(i,j)
			if c.b > 0.01: top = maxf(top,c.g)
	fog_top = top

## The valley fog's map over the square at `corner` (FOG_TEXELS a side):
## per texel the ground (world y), the nearest valley's floor (world y), how
## much fog the valley holds there (0..1: its middle and up its sides, more
## through the ranges and where the floor widens into a pocket), and how
## much of a range stands round it (0..1, deepening the fog).
static func fog_image(seed_value: int, corner: Vector2) -> Image:
	var field := Field.new(seed_value)
	var n := FOG_TEXELS
	var texel := FOG_SIDE/n
	var floor_half := WorldScale.opening(Field.TOY_VALLEY)*0.5
	var data := PackedFloat32Array()
	data.resize(n*n*4)
	for j in n:
		for i in n:
			var s: Vector2 = field.sample(corner.x+(i+0.5)*texel,corner.y+(j+0.5)*texel)
			var k := (j*n+i)*4
			data[k] = s.x
			var amount := 0.0
			var fl := s.x
			if field.last_valley < INF and field.last_floor < INF:
				var d: float = field.last_valley
				var half: float = field.last_half
				var side: float = field.last_side
				fl = field.last_floor
				var near := 1.0-smoothstep(half+side*0.3,half+side*1.05,d)
				var ranged := smoothstep(0.0,0.45,field.last_mountain)
				var pocket := clampf((half/floor_half-0.75)/0.95,0.0,1.0)
				amount = near*smoothstep(0.2,0.8,field.last_inland)*lerpf(0.3,1.0,ranged)*lerpf(0.7,1.15,pocket)
				data[k+3] = ranged
			data[k+1] = fl
			data[k+2] = clampf(amount,0.0,1.0)
	return Image.create_from_data(n,n,false,Image.FORMAT_RGBAF,data.to_byte_array())

## The ground map over the square at `corner`: per texel the most meadow
## and the highest ground round it (its texel and the eight about it).
static func ground_image(seed_value: int, corner: Vector2) -> Image:
	var field := Field.new(seed_value)
	var n := GROUND_TEXELS
	var texel := GROUND_SIDE/n
	# A map this coarse takes the land's carve at its own texel (land_field.gd).
	field.detail = texel
	var meadow := PackedFloat32Array()
	var height := PackedFloat32Array()
	meadow.resize(n*n)
	height.resize(n*n)
	for j in n:
		for i in n:
			var s: Vector2 = field.sample(corner.x+(i+0.5)*texel,corner.y+(j+0.5)*texel)
			meadow[j*n+i] = s.y
			height[j*n+i] = s.x
	var image := Image.create_empty(n,n,false,Image.FORMAT_RGF)
	for j in n:
		for i in n:
			var m := 0.0
			var h := -1e4
			for dj in range(-1,2):
				for di in range(-1,2):
					var k := clampi(j+dj,0,n-1)*n+clampi(i+di,0,n-1)
					m = maxf(m,meadow[k])
					h = maxf(h,height[k])
			image.set_pixel(i,j,Color(m,h,0.0))
	return image

# --- The field on the CPU --------------------------------------------------------------

## The ground map at world `xz` as the march reads it (bilinear):
## (meadow, height).
func _ground_sample(xz: Vector2) -> Vector2:
	if _ground_cpu == null or ground_at.w < 0.5: return Vector2(0.0,Field.SEA_Y)
	var uv := (xz-Vector2(ground_at.x,ground_at.y))/ground_at.z
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0: return Vector2(0.0,Field.SEA_Y)
	var n := _ground_cpu.get_width()
	var g := uv*n-Vector2(0.5,0.5)
	var i := Vector2i(floori(g.x),floori(g.y))
	var t := g-Vector2(i)
	var a := _ground_cpu.get_pixel(clampi(i.x,0,n-1),clampi(i.y,0,n-1))
	var b := _ground_cpu.get_pixel(clampi(i.x+1,0,n-1),clampi(i.y,0,n-1))
	var c := _ground_cpu.get_pixel(clampi(i.x,0,n-1),clampi(i.y+1,0,n-1))
	var d := _ground_cpu.get_pixel(clampi(i.x+1,0,n-1),clampi(i.y+1,0,n-1))
	var top := Vector2(a.r,a.g).lerp(Vector2(b.r,b.g),t.x)
	var bottom := Vector2(c.r,c.g).lerp(Vector2(d.r,d.g),t.x)
	return top.lerp(bottom,t.y)

## How high a cloud over world `w` reaching `reach` keeps its lowest point
## (over the sea) and the most meadow under it (the march's `cloud_floor`).
func _cloud_floor(w: Vector2, reach: float, low: bool) -> Vector2:
	var need := -1e4
	var meadow := 0.0
	for i in 7:
		var a := float(i)*1.0472
		var xz := w+(Vector2.ZERO if i == 0 else Vector2(cos(a),sin(a))*reach*0.55)
		var g := _ground_sample(xz)
		var m := clampf(g.x,0.0,1.0)
		var fl := maxf(g.y,Field.SEA_Y)+4.0
		need = maxf(need,maxf(fl,lerpf(fl,g.y+MEADOW_CLEAR,m)) if low else fl)
		meadow = maxf(meadow,m)
	return Vector2(need-Field.SEA_Y,meadow)

## pcg3d (shaders/endless_cloud_march.glsl), in 32-bit unsigned arithmetic.
static func _mul(a: int, b: int) -> int:
	return (a*(b & 0xFFFF)+(((a*(b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

## (Three uint32s, kept in 64-bit ints: a Vector3i would wrap them signed.)
static func pcg3d(x: int, y: int, z: int) -> PackedInt64Array:
	var m := 0xFFFFFFFF
	x = (_mul(x & m,1664525)+1013904223) & m
	y = (_mul(y & m,1664525)+1013904223) & m
	z = (_mul(z & m,1664525)+1013904223) & m
	x = (x+_mul(y,z)) & m
	y = (y+_mul(z,x)) & m
	z = (z+_mul(x,y)) & m
	x ^= x >> 16
	y ^= y >> 16
	z ^= z >> 16
	x = (x+_mul(y,z)) & m
	y = (y+_mul(z,x)) & m
	z = (z+_mul(x,y)) & m
	return PackedInt64Array([x,y,z])

static func hash3(cx: int, cy: int, s: int) -> Vector3:
	var h := pcg3d(cx,cy,s)
	return Vector3(float(h[0] >> 8),float(h[1] >> 8),float(h[2] >> 8))/16777216.0

func _region(f: Vector2) -> float:
	var g := f/REGION
	var i := Vector2i(floori(g.x),floori(g.y))
	var u := g-Vector2(i)
	u = u*u*(Vector2(3.0,3.0)-2.0*u)
	var s := salt+7
	var a := hash3(i.x,i.y,s).x
	var b := hash3(i.x+1,i.y,s).x
	var c := hash3(i.x,i.y+1,s).x
	var d := hash3(i.x+1,i.y+1,s).x
	return lerpf(REGION_SCALE.x,REGION_SCALE.y,lerpf(lerpf(a,b,u.x),lerpf(c,d,u.x),u.y))

## The clouds whose middles lie within `reach` m of world `at` (xz), as
## they stand now (drifted), before the meadows lift them: each
## {at: world xz, radius, base, top (world y), low, kind}.
func clouds_in(at: Vector2, reach: float) -> Array:
	if organic: return _clouds_in_organic(at,reach)
	var out := []
	var f := at-drift
	for big in [true,false]:
		var cell: float = BIG if big else SMALL
		var s: int = salt+(101 if big else 211)
		var lo := Vector2i(floori((f.x-reach)/cell),floori((f.y-reach)/cell))
		var hi := Vector2i(floori((f.x+reach)/cell),floori((f.y+reach)/cell))
		for cy in range(lo.y,hi.y+1):
			for cx in range(lo.x,hi.x+1):
				var h := hash3(cx,cy,s)
				var k := hash3(cx,cy,s+1)
				var middle := (Vector2(cx,cy)+Vector2(0.2,0.2)+0.6*Vector2(h.x,h.y))*cell
				if middle.distance_to(f) > reach: continue
				var here := _region(middle)*cover*(BIG_COVER if big else SMALL_COVER)
				if h.z >= here: continue
				var rr: Vector2 = BIG_R if big else SMALL_R
				var r := cell*lerpf(rr.x,rr.y,k.x)
				var base: float
				var tall: float
				var kind := "puff"
				if big:
					var t2 := fposmod(k.z*7.31,1.0)
					if k.y < LOW_SHARE:
						kind = "low"
						base = lerpf(LOW_BASE.x,LOW_BASE.y,k.z)
						tall = lerpf(LOW_TALL.x,LOW_TALL.y,t2)
					elif k.y < LOW_SHARE+TOWER_SHARE:
						kind = "tower"
						base = lerpf(TOWER_BASE.x,TOWER_BASE.y,k.z)
						tall = lerpf(TOWER_TALL.x,TOWER_TALL.y,t2)
						r *= TOWER_WIDE
					else:
						kind = "mid"
						base = lerpf(MID_BASE.x,MID_BASE.y,k.z)
						tall = lerpf(MID_TALL.x,MID_TALL.y,t2)
				else:
					base = lerpf(SMALL_BASE.x,SMALL_BASE.y,k.y)
					tall = lerpf(SMALL_TALL.x,SMALL_TALL.y,k.z)
				var H := minf(r*tall,TOP-base)
				# Its bubbles (the march's cluster): [middle xz, radius, height].
				var b1 := hash3(cx,cy,s+2)
				var b2 := hash3(cx,cy,s+3)
				var spin := b1.x*6.2832
				var bubbles := [[middle+drift,r*MAIN_R,H]]
				for i in range(1,4):
					var sh: float = [b1.y,b1.z,b2.x][i-1]
					var a: float = spin+i*2.0944+float([b2.y,b2.z,b1.y][i-1])*1.2
					var br := r*lerpf(0.36,0.58,fposmod(sh*3.7,1.0))
					if kind == "tower": br *= 1.25
					bubbles.append([middle+drift+Vector2(cos(a),sin(a))*r*lerpf(0.32,0.58,sh),br,H*lerpf(0.4,0.85,fposmod(sh*5.3,1.0))])
				out.append({"at":middle+drift,"radius":r,"base":Field.SEA_Y+base,"top":Field.SEA_Y+base+H,"low":kind == "low" or kind == "puff","kind":kind,"bubbles":bubbles})
	return out

static func _vnoise(g: Vector2, s: int) -> float:
	var i := Vector2i(floori(g.x),floori(g.y))
	var u := g-Vector2(i)
	u = u*u*(Vector2(3.0,3.0)-2.0*u)
	var a := hash3(i.x,i.y,s).x
	var b := hash3(i.x+1,i.y,s).x
	var c := hash3(i.x,i.y+1,s).x
	var d := hash3(i.x+1,i.y+1,s).x
	return lerpf(lerpf(a,b,u.x),lerpf(c,d,u.x),u.y)

## Cell (cx, cy)'s life now and its cycle (the march's `cell_life`): x 0..1.
func _cell_life(cx: int, cy: int, big: bool) -> Vector2:
	if not _lifed(): return Vector2(1.0,0.0)
	var h := hash3(cx,cy,salt+(101 if big else 211)+31)
	var period := LIFE_PERIOD*life_scale*lerpf(0.6,1.5,h.x)*(1.0 if big else 0.6)
	var ph := (motion_time+clock_start)/period+h.y
	var f := floorf(ph)
	var u := ph-f
	return Vector2(smoothstep(0.0,0.4,u)*(1.0-smoothstep(0.55,1.0,u)),maxf(f,0.0))

func _lifed() -> bool:
	return life and organic

## The drift of the layer a cloud is in (the weather pass's `g_drift`).
func _layer_drift(low: bool) -> Vector2:
	if not _lifed(): return drift
	return drift_lo if low else drift_hi

func _cluster_gate(f: Vector2) -> float:
	var n := 0.65*_vnoise(f/CLUSTER,salt+17)+0.35*_vnoise(f/(CLUSTER*0.43),salt+19)
	return smoothstep(CLUSTER_GATE.x,CLUSTER_GATE.y,n)

## The organic field's cloud of cell (cx, cy), in the field frame (the
## march's `recipe`), or an empty dictionary.
func _recipe(cx: int, cy: int, big: bool, lift := true) -> Dictionary:
	var cell: float = BIG if big else SMALL
	var lf := _cell_life(cx,cy,big)
	var lifed := _lifed()
	var s0: int = salt+(101 if big else 211)+int(lf.y)*977
	var h := hash3(cx,cy,s0)
	var middle := (Vector2(cx,cy)+Vector2(0.5,0.5)+JIT*(Vector2(h.x,h.y)*2.0-Vector2.ONE))*cell
	# The storm's push at the cloud's place now (the low layer's drift, as
	# the march): a pushed broad cloud lives on whole and always stands.
	# Its kind reads the place alone (place_at): it never changes as the
	# storm builds.
	var st: float = storm.push_at(middle+_layer_drift(true)) if storm != null and big else 0.0
	var kp: float = storm.place_at(middle+_layer_drift(true)) if storm != null and big else 0.0
	lf.x = lerpf(lf.x,1.0,st)
	# A small puff where the storm pushes thins away (the march's SP_SMALL_GO).
	if not big and storm != null:
		lf.x *= 1.0-smoothstep(STORM_SMALL_GO.x,STORM_SMALL_GO.y,storm.push_at(middle+_layer_drift(true)))
		if lf.x < 0.01: return {}
	if lifed and lf.x < 0.01: return {}
	var gate := _cluster_gate(middle)
	if not big: gate = lerpf(0.02,1.0,gate*gate)
	var field_here := _region(middle)*cover*(BIG_COVER2 if big else SMALL_COVER2)*gate*(LIFE_COVER if lifed else 1.0)
	var here := lerpf(field_here,1.0,st)
	if h.z >= here: return {}
	# A cell only the storm stands up comes in from a wisp as it builds.
	if h.z >= field_here: lf.x *= smoothstep(0.0,STORM_ADMIT,here-h.z)
	if lf.x < 0.01: return {}
	var s := hash3(cx,cy,s0+1)
	var m := hash3(cx,cy,s0+2)
	var rr: Vector2 = BIG_R2 if big else SMALL_R2
	var r := cell*lerpf(rr.x,rr.y,pow(s.x,SIZE_SKEW))
	var spin := m.x*6.2832
	var t2 := fposmod(s.z*7.31,1.0)
	var t3 := fposmod(s.z*3.17+m.y,1.0)
	var k := {"cell":Vector2i(cx,cy),"salt":s0,"life":lf.x,"middle":middle,"axis":Vector2(cos(spin),sin(spin)),"profile":PROFILE,"low":false,"storm":st}
	var towers := kp > 0.0 and fposmod(s.y*13.7+s.x,1.0) < kp*STORM_TOWERS
	var mids := kp > 0.25 and not towers
	# [kind, n range, L, W, main_r, br, hs, tall, belly, qb]
	var p: Array
	if not big:
		k.kind = "puff"; k.low = true; k.b0 = lerpf(SMALL_BASE.x,SMALL_BASE.y,s.y)
		p = [Vector2(2,5),0.45,0.35,0.65,Vector2(0.4,0.62),Vector2(0.7,1.1),Vector2(0.6,1.25),Vector2(0.35,0.55),Vector2(0.5,0.85)]
	elif s.y < FAIR_SHARE and not towers and not mids:
		k.kind = "fair"; k.low = true; k.b0 = lerpf(LOW_BASE.x,LOW_BASE.y,s.z)
		p = [Vector2(3,6),0.55,0.38,0.62,Vector2(0.35,0.6),Vector2(0.7,1.1),Vector2(0.55,1.0),Vector2(0.3,0.5),Vector2(0.45,0.8)]
	elif towers or (s.y < FAIR_SHARE+TOWER_SHARE2 and not mids):
		k.kind = "tower"; k.b0 = lerpf(TOWER_BASE.x,TOWER_BASE.y,s.z)
		p = [Vector2(5,9),0.5,0.45,0.6,Vector2(0.4,0.6),Vector2(0.6,1.0),Vector2(1.0,1.5),Vector2(0.25,0.4),Vector2(0.45,0.7)]
		k.profile = 0.4
		r *= 1.2
	elif s.y < FAIR_SHARE+TOWER_SHARE2+ROW_SHARE and not mids:
		k.kind = "row"; k.low = t3 < 0.4
		k.b0 = lerpf(LOW_BASE.x,LOW_BASE.y+30.0,s.z) if k.low else lerpf(MID_BASE.x,MID_BASE.y,s.z)
		p = [Vector2(6,9),1.15,0.18,0.5,Vector2(0.36,0.55),Vector2(0.8,1.15),Vector2(0.55,0.95),Vector2(0.32,0.5),Vector2(0.5,0.8)]
	elif s.y < FAIR_SHARE+TOWER_SHARE2+ROW_SHARE+WISP_SHARE and not mids:
		k.kind = "wisp"; k.b0 = lerpf(180.0,320.0,s.z)
		p = [Vector2(2,4),1.0,0.4,0.6,Vector2(0.5,0.8),Vector2(0.9,1.1),Vector2(0.08,0.16),Vector2(0.45,0.5),Vector2(0.6,0.7)]
		r *= 1.3
	else:
		k.kind = "mid"; k.b0 = lerpf(MID_BASE.x,MID_BASE.y,s.z)
		p = [Vector2(4,8),0.6,0.45,0.6,Vector2(0.35,0.62),Vector2(0.7,1.15),Vector2(0.6,1.2),Vector2(0.35,0.55),Vector2(0.5,0.85)]
	var nr: Vector2 = p[0]
	k.L = float(p[1])*lerpf(0.8,1.45,m.y)
	k.W = float(p[2])
	k.main_r = float(p[3])
	k.br = p[4]
	k.hs = p[5]
	k.n = int(nr.x)+mini(int(m.z*(nr.y-nr.x+1.0)),int(nr.y-nr.x))
	k.ext = Vector2(k.L,k.W).length()+maxf(k.br.y,k.main_r)*(1.0+WOB)
	# Pushed: wider, taller, more domes, a deeper belly, a lower base.
	r *= lerpf(1.0,STORM_GROW.x,st)
	k.n = mini(int(k.n)+int(st*STORM_DOMES+0.5),9)
	k.b0 = lerpf(float(k.b0),minf(float(k.b0),lerpf(STORM_BASE.x,STORM_BASE.y,s.z)),st)
	# Past the core, where the deck lets go, it rides up to the deck's back
	# (the march's SP_TRAIL_BASE).
	if st > 0.0:
		var d_s: float = storm.edge_distance(middle+_layer_drift(true))
		var back: float = storm.ramp(-storm.CORE_DEPTH+storm.ENV_OUT.x,-storm.CORE_DEPTH+storm.ENV_OUT.y,d_s)
		k.b0 = lerpf(float(k.b0),maxf(float(k.b0),lerpf(STORM_TRAIL_BASE.x,STORM_TRAIL_BASE.y,s.z)),smoothstep(0.0,0.3,st)*back)
	r = minf(r,lerpf(EXT_MAX,STORM_EXT,st)*cell/k.ext)
	k.r = r
	var tall: Vector2 = p[6]
	k.tall = lerpf(tall.x,tall.y,t2)*DOME*lerpf(1.0,STORM_GROW.y,st)
	var bl: Vector2 = p[7]
	var qb: Vector2 = p[8]
	k.belly = lerpf(bl.x,bl.y,fposmod(m.y*5.13+s.x,1.0))*lerpf(1.0,STORM_BELLY,st)
	k.qb = lerpf(qb.x,qb.y,fposmod(m.z*3.71+h.x,1.0))
	k.big = big
	if lift: _recipe_lift(k)
	return k

## The cloud as its life has it now (the march's `apply_life`).
func _apply_life(k: Dictionary) -> void:
	if not _lifed() and float(k.storm) <= 0.0: return
	var lr := lerpf(0.7,1.0,float(k.life))
	k.r = float(k.r)*lr
	k.tall = float(k.tall)*float(k.life)
	k.H = float(k.H)*lr*float(k.life)

## Cloud `k` lifted whole over the ground (the march's `recipe_lift`).
func _recipe_lift(k: Dictionary) -> void:
	var c: Vector2i = k.cell
	var h := hash3(c.x,c.y,int(k.salt))
	var s := hash3(c.x,c.y,int(k.salt)+1)
	var fl := _cloud_floor(Vector2(k.middle)+_layer_drift(bool(k.low)),float(k.r)*float(k.ext),bool(k.low))
	if fl.x > float(k.b0): k.b0 = fl.x+30.0*fposmod(s.y*13.7+h.x,1.0)
	if k.low: k.tall = float(k.tall)*lerpf(1.0,0.6,fl.y)
	k.H = minf(float(k.r)*float(k.main_r)*float(k.tall),TOP+STORM_GROW_TOP*float(k.storm)-float(k.b0))

## Whether cloud `k` (a puff or a wisp) stands one over another of its
## layer whose footprint overlaps its own, and is the lesser of the two (the
## march's `yields`; the other broad clouds never yield).
func _yields(k: Dictionary) -> bool:
	var reach := float(k.r)*float(k.ext)
	var big: bool = k.big
	var c: Vector2i = k.cell
	for other_big: bool in [true,false]:
		if big and not other_big: continue
		var cell: float = BIG if other_big else SMALL
		var s0: int = salt+(101 if other_big else 211)
		var mid0: Vector2 = k.middle
		var g := Vector2i(floori(mid0.x/cell),floori(mid0.y/cell))
		var most := reach+(STORM_EXT if other_big and storm != null else EXT_MAX)*cell
		for y in range(-2,3):
			for x in range(-2,3):
				var n := g+Vector2i(x,y)
				if other_big == big and n == c: continue
				var h := hash3(n.x,n.y,s0)
				var mid := (Vector2(n)+Vector2(0.5,0.5)+JIT*(Vector2(h.x,h.y)*2.0-Vector2.ONE))*cell
				if mid.distance_to(mid0) >= most: continue
				var o := _recipe(n.x,n.y,other_big,false)
				if o.is_empty() or bool(o.low) != bool(k.low): continue
				if Vector2(o.middle).distance_to(mid0) >= reach+float(o.r)*float(o.ext): continue
				if k.kind != "wisp" and o.kind != "wisp":
					_recipe_lift(o)
					if not _clash(k,o): continue
				var me: bool
				var order := c.x < n.x or (c.x == n.x and c.y < n.y)
				if big != other_big: me = true
				elif (k.kind == "wisp") != (o.kind == "wisp"): me = k.kind == "wisp"
				elif k.kind == "wisp": me = order
				else: me = float(k.H) < float(o.H) or (float(k.H) == float(o.H) and order)
				if me: return true
	return false

static func _clash(a: Dictionary, b: Dictionary) -> bool:
	if a.kind == "wisp" or b.kind == "wisp": return true
	var a_low := float(a.b0) <= float(b.b0)
	var lo: Dictionary = a if a_low else b
	var hi: Dictionary = b if a_low else a
	return float(hi.b0) > float(lo.b0)+YIELD_LEVEL*float(lo.H)

## Bubble `i` of cloud `k` over field point `f` (the march's `bubble_span`):
## (top, bottom) over the sea where it covers f, else (-1e4, distance past
## its rim).
static func _bubble_span(k: Dictionary, i: int, f: Vector2) -> Vector2:
	var c: Vector2i = k.cell
	var q := hash3(c.x,c.y,int(k.salt)+10+i)
	var off := Vector2.ZERO
	var br: float = k.main_r
	var hs := 1.0
	var lift := 0.0
	var L: float = k.L
	if i > 0:
		var along := (2.0*(float(i-1)+q.x)/float(maxi(int(k.n)-1,1))-1.0)*L if k.kind == "row" else (q.x*2.0-1.0)*L
		off = Vector2(along,(q.y*2.0-1.0)*float(k.W))
		br = lerpf(k.br.x,k.br.y,q.z)
		hs = lerpf(k.hs.x,k.hs.y,fposmod(q.z*5.3,1.0))*(1.0-0.25*minf(off.length()/maxf(L,0.05),1.0))
		lift = LIFT*fposmod(q.z*9.17,1.0)
	else:
		lift = LIFT*0.3*fposmod(q.z*9.17,1.0)
	var ax: Vector2 = k.axis
	var r: float = k.r
	var at: Vector2 = k.middle+(ax*off.x+Vector2(-ax.y,ax.x)*off.y)*r
	var d := f-at
	var bd := d.length()
	var a := atan2(d.y,d.x+1e-6)
	var rw := br*r*(1.0+WOB*(0.6*sin(3.0*a+fposmod(q.x*7.7,1.0)*6.2832)+0.4*sin(5.0*a+fposmod(q.y*5.9,1.0)*6.2832)))
	var u := bd/rw
	if u >= 1.0: return Vector2(-1e4,bd-br*r*(1.0+WOB))
	var bh: float = minf(br*r*float(k.tall)*hs,float(k.H)*1.2)
	var down: float = bh*float(k.belly)*lerpf(0.75,1.3,fposmod(q.y*3.31+q.x,1.0))
	var qb: float = float(k.qb)*lerpf(0.8,1.25,fposmod(q.x*4.13+q.z,1.0))
	var rim: float = k.b0+k.H*lift+down
	var v := 1.0-u*u
	return Vector2(rim+maxf(bh-down,bh*0.3)*pow(v,k.profile),rim-down*pow(v,qb))

func _clouds_in_organic(at: Vector2, reach: float) -> Array:
	var out := []
	for layer_low in ([true,false] if _lifed() else [true]):
		_clouds_in_layer(at,reach,layer_low,out)
	return out

func _clouds_in_layer(at: Vector2, reach: float, layer_low: bool, out: Array) -> void:
	var dr := _layer_drift(layer_low)
	var f := at-dr
	for big in [true,false]:
		var cell: float = BIG if big else SMALL
		var lo := Vector2i(floori((f.x-reach)/cell)-1,floori((f.y-reach)/cell)-1)
		var hi := Vector2i(floori((f.x+reach)/cell)+1,floori((f.y+reach)/cell)+1)
		for cy in range(lo.y,hi.y+1):
			for cx in range(lo.x,hi.x+1):
				var k := _recipe(cx,cy,big)
				if k.is_empty() or Vector2(k.middle).distance_to(f) > reach: continue
				if _lifed() and bool(k.low) != layer_low: continue
				if stack_yield and (not big or k.kind == "wisp") and _yields(k): continue
				_apply_life(k)
				var w: Vector2 = k.middle
				k["drift"] = dr
				k["at"] = w+dr
				k["radius"] = float(k.r)*float(k.ext)
				k["base"] = Field.SEA_Y+float(k.b0)
				k["top"] = Field.SEA_Y+float(k.b0)+float(k.H)*(1.2+LIFT)
				out.append(k)

## How far world point `p` is into a cloud's smooth body (m, up or down
## to its crown or its base; no billows, before the meadows lift the low
## ones), or a negative number outside every cloud.
func cloud_depth(p: Vector3) -> float:
	var best: float = towers.depth(p) if towers != null else -1e9
	if storm != null: best = maxf(best,envelope_depth(p))
	var xz := Vector2(p.x,p.z)
	if organic:
		for c: Dictionary in clouds_in(xz,BIG*(2.6 if storm != null else 1.6)):
			var top := -1e9
			var bottom := 1e9
			for i in int(c.n):
				var b := _bubble_span(c,i,xz-Vector2(c.get("drift",drift)))
				if b.x < -1e3: continue
				top = maxf(top,b.x)
				bottom = minf(bottom,b.y)
			if top > -1e3: best = maxf(best,minf(Field.SEA_Y+top-p.y,p.y-Field.SEA_Y-bottom))
		return best
	for c: Dictionary in clouds_in(xz,BIG*0.6):
		var top := -1e9
		var bottom := 1e9
		for b: Array in c.bubbles:
			var u: float = xz.distance_to(b[0])/float(b[1])
			if u >= 1.0: continue
			top = maxf(top,float(c.base)+float(b[2])*pow(1.0-u*u,PROFILE))
			bottom = minf(bottom,float(c.base)+float(b[2])*CURL*u*u*u*u)
		best = maxf(best,minf(top-p.y,p.y-bottom))
	return best

## How far world point `p` is into the storm's own cloud: its towers and
## its envelope's deck (cheap enough for every frame; `cloud_depth` adds the
## field's cells).
func storm_depth(p: Vector3) -> float:
	var best: float = towers.depth(p) if towers != null else -1e9
	return maxf(best,envelope_depth(p))

## How far world point `p` is into the storm's envelope deck (StormFront
## ENV_*; the march's storm_env_cloud), its smooth base (no lumps, no
## scud), or a negative number outside it.
func envelope_depth(p: Vector3) -> float:
	if storm == null or not storm.envelope or storm.env_scale.z <= 0.0: return -1e9
	var xz := Vector2(p.x,p.z)
	var e: float = storm.envelope_at(xz)
	# The deck stands from a fifth of the envelope (its density rides
	# smoothstep(0, 0.35, e) in the march).
	if e < 0.2: return -1e9
	var g := _ground_sample(xz)
	var m := clampf(g.x,0.0,1.0)
	var fl := maxf(g.y,Field.SEA_Y)+float(storm.ENV_GROUND)
	fl = maxf(fl,lerpf(fl,g.y+MEADOW_CLEAR,m))
	var base: float = storm.deck_base(e,fl,Field.SEA_Y)
	return minf(p.y-base,base+float(storm.ENV_THICK)-p.y)

## Whether world point `p` is inside a cloud's body (`cloud_depth` > 0).
func in_cloud(p: Vector3) -> bool:
	return cloud_depth(p) > 0.0

# --- Each frame, just before drawing --------------------------------------------------

func _before_draw() -> void:
	if camera == null or not is_instance_valid(camera) or not sheet.visible: return
	var window := camera.get_window()
	var viewport := camera.get_viewport()
	var physical := Vector2(window.size) if window != null else Vector2(1280,720)
	var scale := viewport.scaling_3d_scale if viewport != null else 1.0
	effect.resize(Vector2i((physical*scale).round()),int(quality[2]))
	_fill()

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
	var sun := Vector3.UP
	var moon := Vector3.DOWN
	var night := 0.0
	if celestial != null and celestial.get("state") is Dictionary:
		sun = celestial.state.get("zs_sun_direction",Vector3.UP)
		moon = celestial.state.get("zs_moon_direction",Vector3.DOWN)
		night = float(celestial.state.get("zs_night",0.0))*float(celestial.state.get("zs_celestial_clear",1.0))
	var key := sun.normalized().lerp(moon.normalized(),smoothstep(0.05,-0.1,sun.normalized().y)).normalized()
	_put4(p,16,Vector4(tan_x,tan_y,camera.near,camera.far))
	_put4(p,20,Vector4(eye.x,eye.y,eye.z,motion_time))
	_put4(p,24,Vector4(sun.x,sun.y,sun.z,0.0))
	_put4(p,28,Vector4(key.x,key.y,key.z,0.0))
	_put4(p,32,Vector4(Field.SEA_Y,Field.SEA_Y+(STORM_TOP if storm != null else TOP),REACH*_view,1.0))
	var lifed := life and organic
	var low_at := drift_lo if lifed else drift
	_put4(p,36,Vector4(low_at.x,low_at.y,float(salt),cover))
	_put4(p,72,Vector4(1.0 if lifed else 0.0,LIFE_PERIOD*life_scale,drift_hi.x,drift_hi.y))
	_put4(p,76,Vector4(motion_time+clock_start,0.0,0.0,0.0))
	_put4(p,40,ground_at)
	var noise: Texture = CumulusNoise.request()
	var shade_texel := SHADE_SIDE/Effect.SHADOW_TEXELS
	var shade_corner := ((Vector2(eye.x,eye.z)-Vector2.ONE*SHADE_SIDE*0.5)/shade_texel).floor()*shade_texel
	_put4(p,48,Vector4(_frame,0.0,0.0,night))
	_put4(p,52,Vector4(SMALL_COVER,LOW_SHARE,TOWER_SHARE,MEADOW_CLEAR))
	var fog_live := fog_on and fog_at.w > 0.5 and fog_top > -1e2 and fog_hush < 1.0
	_put4(p,56,fog_at if fog_live else Vector4.ZERO)
	_put4(p,60,Vector4(fog_density*(1.0-fog_hush),fog_depth,fog_steps,fog_top+fog_depth*1.6+16.0))
	_put4(p,64,Vector4(drift.x*FOG_DRIFT,drift.y*FOG_DRIFT,FOG_REACH,FOG_FADE))
	_put4(p,68,fog_look)
	# The storm's push (spare[3], spare[4]; shaders/storm_cloud.glslinc).
	if storm != null:
		var e: Vector2 = storm.edge()
		var h: Vector2 = storm.heading()
		_put4(p,80,Vector4(e.x,e.y,h.x,h.y))
		_put4(p,84,Vector4(storm.length,storm.CORE_DEPTH,storm.intensity,1.0))
		_put4(p,88,Vector4(storm.churn,0.0,0.0,cost_view))
		# Its envelope (spare[18]: on, the murk's, scud's, deck's scales).
		var es: Vector3 = storm.env_scale
		_put4(p,140,Vector4(1.0 if storm.envelope else 0.0,es.x,es.y,es.z))
		# Its towers (spare[5].y, spare[6..17]).
		if not _towers_made:
			_towers_made = true
			towers = StormTowers.from_args(storm,LaunchArgs.user_args())
		if towers != null:
			var now := Time.get_ticks_usec()
			towers.advance(0.0 if _towers_tick == 0 else minf((now-_towers_tick)*1e-6,0.25))
			_towers_tick = now
			towers.put(p)
		material.set_shader_parameter("storm_intensity",storm.intensity)
	var weather_due := _frame%WEATHER_EVERY == 0 or weather_side == 0.0
	var shade_due := _frame%SHADE_EVERY == 0
	# Sliced, the square round the eye is asked for every frame; the effect
	# takes it when a cycle begins.
	if weather_due or effect.weather_slices > 1:
		weather_side = (REACH*_view+WEATHER_PAST)*2.0
		var texel := weather_side/Effect.WEATHER_TEXELS
		weather_corner = ((Vector2(eye.x,eye.z)-Vector2.ONE*weather_side*0.5)/texel).floor()*texel
	var shade_square := Vector4(shade_corner.x,shade_corner.y,SHADE_SIDE,1.0)
	if shade_due: _put4(p,44,shade_square)
	else: _put4(p,44,Vector4(_shade_drawn.x,_shade_drawn.y,SHADE_SIDE,1.0) if _shade_drawn != Vector4.ZERO else shade_square)
	_put4(p,164,Vector4(weather_corner.x,weather_corner.y,weather_side,Effect.WEATHER_TEXELS))
	_put4(p,168,Vector4(quality[0],quality[1],quality[2],quality[3]))
	_put4(p,172,Vector4(1.0 if grain else 0.0,1.0 if organic else 0.0,1.0 if stack_yield else 0.0,1.0 if puff_lobes else 0.0))
	_put4(p,176,Vector4(0.0,Effect.SHADOW_TEXELS,1.0 if weather_due else 0.0,1.0 if shade_due else 0.0))
	# The sea draws after this frame's passes: the square they leave in the map.
	if sea_material != null:
		var now := shade_square if shade_due or _shade_drawn == Vector4.ZERO else _shade_drawn
		sea_material.set_shader_parameter("shade_square",now if sea_shade_sync else Vector4.ZERO)
	# The land reads the shade map the frame after it is drawn.
	if _shade_drawn != Vector4.ZERO: _publish_shade(true,key,_shade_drawn)
	if shade_due: _shade_drawn = shade_square
	_frame = (_frame+1)%4096
	effect.set_inputs(ground,fog if fog_live else null,noise,towers.textures() if towers != null else [])
	var r := effect.resolve_params
	_put_transform(r,0,xf)
	_put_projection(r,16,_prev_view)
	_put4(r,32,Vector4(tan_x,tan_y,upsampled_blend,1.0 if _has_prev else 0.0))
	_put4(r,36,Vector4(_prev_lens.x,_prev_lens.y,1.0 if grain else 0.0,0.0))
	_put4(r,40,Vector4(eye.x,eye.y,eye.z,p[48]))
	_put4(r,44,Vector4(camera.near,camera.far,marched_blend,quality[2]))
	if not _has_prev: effect.history_ok = false
	_prev_view = Projection(xf.affine_inverse())
	_prev_lens = Vector2(tan_x,tan_y)
	_has_prev = true
	sheet.global_position = eye

## The shade on the land (shaders/cloud_volume_shadow.gdshaderinc): the map,
## its square, the light and the height it looks up from (the sea's).
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
	RenderingServer.global_shader_parameter_set("zs_cloud_shadow_light",Vector4(light.x,light.y,light.z,Field.SEA_Y))

static func _put4(p: PackedFloat32Array, at: int, v: Vector4) -> void:
	p[at] = v.x
	p[at+1] = v.y
	p[at+2] = v.z
	p[at+3] = v.w

static func _put_transform(p: PackedFloat32Array, at: int, xf: Transform3D) -> void:
	_put_projection(p,at,Projection(xf))

static func _put_projection(p: PackedFloat32Array, at: int, m: Projection) -> void:
	_put4(p,at,m.x)
	_put4(p,at+4,m.y)
	_put4(p,at+8,m.z)
	_put4(p,at+12,m.w)
