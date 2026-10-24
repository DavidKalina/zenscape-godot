extends Node3D
## Endless flight, round 1 (docs/design/endless-flight/round-1-handoff.md):
## the game's plane over endless streamed land. It starts in the air, in
## the plane the aqueduct isle flies (scripts/sky_plane.gd at the game's
## speed, the hand landing scripts/manual_landing.gd, the figure scripts/
## plane_figure.gd and its ground scale, the chase camera scripts/
## glide_camera.gd), flown by the same keys, mouse and pad. Under it the
## land streams in chunks round the camera (scripts/endless/land_stream.gd
## over scripts/endless/land_field.gd): rolling hills, a few mountains,
## coast and sea, and broad flat meadows to put it down on. Land on the
## turf as on the isle; stopped, Space (Boost) rolls it off again, and F
## (pad Y) gets out: the pilot hops down beside it and walks the land
## (scripts/endless/endless_walker.gd: the game's motor, figure and walker
## camera; docs/design/endless-flight/get-out-handoff.md), the plane parked
## where it stopped. Back by it, F or Space (pad Y or A) climbs in, stopped
## on its wheels to take off again.
##
## Keys: WASD or the left stick bank and pitch (W nose down), the mouse
## steers, Space boost, Shift brake, Q E held knife edge (twice quick a
## barrel roll, or click), F flaps in the air (pad Y), stopped F gets out,
## hold right mouse to look round, F1 the numbers, R back up into the air
## over where it is (on foot too), Esc lets the mouse go.
## On foot: WASD or the stick walk (the mouse or right stick turn the view),
## Space jumps (held higher, again on landing the pump), Shift (C, LT)
## crouches: at a run the slide, on a slope the surf, with Space the long
## jump (again on each landing, chained); Space in the air with room under
## him opens the sail, again folds it. He wades the shallows; deeper water
## stops him (come down in it, he swims). By the plane F or Space boards.
##
##   ./run-endless-flight.command [--seed=7]
##   godot --path . res://studies/endless_flight.tscn -- --no-title [--seed=7] [--at=x,z] [--heading=deg] [--alt=m] [--on-foot]
##
## The world: this script is the engine's (the plane and flight, on foot,
## streaming, the look, the dressing machinery, the HUD and harness hooks);
## what makes the world this world is its profile
## (scripts/endless/world/world_profile.gd, profiles/<id>.gd): --world=ID
## (wilderness; test_dry is a test profile). The profile sets the defaults;
## every flag below still wins (docs/design/endless-flight/world-profiles-handoff.md).
##
## Flags: --on-foot starts parked at --at (on the land there) with the pilot
## out beside the plane. --seed=N the land (1), --at=x,z where it starts (0,0), the land's shape
## (land_field.gd): --mountains=X, --peaks=X, --valleys=X, --no-valleys,
## --old-land (round one's land and ceiling), --ceiling=m over the sea (215),
## --heading=deg clockwise from -z (0; `sun` toward the sun), --alt=m over
## the ground (45), --numbers opens with F1's numbers shown, --uncapped
## turns vsync and the frame cap off (the fps is then the frame's cost).
## The look (scripts/endless/endless_look.gd): --mood=ID one of its
## moods (alpine_morning), --hour=H the sun's hour (the mood's), --day the
## hour runs, --plain-look round one's plain sky and colours; T steps to the
## next quarter of the day, L to the next mood. The clouds (scripts/endless/
## endless_clouds.gd): --no-clouds, --cloud-cover=X (1), --cloud-field=old (the
## earlier near-grid of mushrooms), --cloud-half-res (the earlier march); C turns them off
## and on. The grass carpet (scripts/endless/endless_grass.gd): --no-grass,
## --grass=X (its density, 1), --grass-range=M (how far the tufts reach,
## 230), --grass-lod=x,y,z,w (its rings, 16,30,150,230), --no-flowers,
## --grass-fine=X (the near ring's fine tuft at X of the isle's density,
## 1.2; 0: the isle's own tuft), --grass-patches=X (how much of the ground's
## patches the tufts carry, 1), --grass-set= / --far-set= / --ground-set=
## name=value (a shader setting, for tuning by hand), --flower-drifts=X
## (how many flower drifts, 1; 0 or --no-drifts: round 4's), --grass-regions=X
## (how strongly the grass's colour regions show, 1; 0 or --no-regions:
## one palette), --grass-lead=X (how far its rings lead out ahead along the
## view, 0.45), --no-grass-lead, --grass-flat-up=M (the height its rings are
## measured along the ground to, 20), --grass-ring=3d (the old 3D rings),
## --grass-silver=X (the silvery undersides the gusts flip into view, 0.8;
## 0 or --no-grass-silver: off), --grass-cover=old (bare slopes and hills as
## before the bare-patches round), --grass-slope=a,b; G
## turns it off and on. The grass reacting (scripts/endless/grass_react.gd):
## --no-grass-react, --no-prop-wash, --no-grass-gusts, --no-grass-part,
## --prop-wash=X, --grass-gusts=X, --gust-every=S, --grass-bend=X. The arches (scripts/endless/land_arches.gd):
## --arches=X (how many, 1; 0 or --no-arches none), --rock-arches=X /
## --ruin-arches=X (each family's share, 1; 0 none). The spruce forests
## (scripts/endless/land_trees.gd): --no-trees, --forest=X (their share, 1),
## --forest-meadows=X (how far onto the meadows, as groves, 1; 0 none).
## The birds (scripts/endless/endless_birds.gd): --birds=0 off, --birds=X,
## --bird-range=X, --bird-size=X, --bird-ride=S, --ambient-birds=X.
## Other planes (scripts/endless/endless_traffic.gd): --traffic=0 off,
## --traffic=N how many (3), --trails=0 no smoke trails.
## The plane's speed (SkyPlane FLIGHT_SPEED, use_flight_speed): --plane-speed=X
## (times the toy's 14 m/s cruise, 2.1; 1.15 the isles'), --plane-turn=X; the
## view widens with speed RUSH_FOV times the chase's own (--cam-speed-fov=X
## sets it), and past cruise the eye can buffet a little (--rush=X, 0 off by default).

const Field = preload("res://scripts/endless/land_field.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const LandStream = preload("res://scripts/endless/land_stream.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Pad = preload("res://scripts/pad.gd")
const EndlessLook = preload("res://scripts/endless/endless_look.gd")
const EndlessGrass = preload("res://scripts/endless/endless_grass.gd")
const GrassReact = preload("res://scripts/endless/grass_react.gd")
const EndlessEddies = preload("res://scripts/endless/endless_eddies.gd")
const EndlessMotes = preload("res://scripts/endless/endless_motes.gd")
const LandArches = preload("res://scripts/endless/land_arches.gd")
const LandTrees = preload("res://scripts/endless/land_trees.gd")
## The birds (scripts/endless/endless_birds.gd; --birds=0 off).
const EndlessBirds = preload("res://scripts/endless/endless_birds.gd")
## Fish leaping in the ponds (scripts/endless/endless_fish.gd; --fish=0 off).
const EndlessFish = preload("res://scripts/endless/endless_fish.gd")
## Other planes and their trails (--traffic=0 off).
const EndlessTraffic = preload("res://scripts/endless/endless_traffic.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const EndlessWalker = preload("res://scripts/endless/endless_walker.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")

const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const DOUBLE_TAP := 0.3
const LOOK_LINGER := 2.5
## The sky and the haze: the fog thickens from FOG_BEGIN m to FOG_END m,
## inside the land's far edge (LandStream ROOT_REACH root chunks out).
const HORIZON := Color("cfdde6")
const FOG_BEGIN := 900.0
const FOG_END := 7000.0
const FOG_DENSITY := 0.00028
const SEA_COLOUR := Color("2f6f8f")
const SEA_SIZE := 40000.0
## The plane's start over the ground (m), and the eye's clearance over it.
const START_ALT := 45.0
const EYE_CLEAR := 0.6
## Speed's feel: the chase's speed widening times RUSH_FOV (GlideCamera
## FOV_FAST; at cruise about +6 degrees, at boost +12), and the wind's
## buffet on the eye, RUSH_SHAKE radians at most, coming in from
## RUSH_FROM of the cruise to Boost's speed, shaken at RUSH_HZ.
const RUSH_FOV := 1.8
const RUSH_SHAKE := 0.0045
const RUSH_FROM := 0.9
const RUSH_HZ := Vector3(7.3,11.9,17.1)

## True once the land under the start stands and it flies (the harness
## waits on it: tools/harness/drive.gd `open`).
var walk_ready := false
var seed := 1
## The world profile in play (--world=; scripts/endless/world/world_profile.gd).
var world: RefCounted
var land: Node3D
var field: RefCounted
var camera: Camera3D
var plane: RefCounted
var plane_figure: Node3D
var chase: RefCounted
var hand_landing := ManualLanding.new()
var ground_scale := PlaneGroundScale.new()
var flaps := false
var sea: MeshInstance3D
## The look (sky, light, haze, ground, sea), or null under --plain-look.
var look: Node3D
## The grass carpet round the eye (off at the start under --no-grass), or
## null under --plain-look.
var grass: Node3D
## The grass reacting to the wash, the walker and the gusts (scripts/endless/
## grass_react.gd), or null under --no-grass-react or --plain-look.
var react: Node
## The gusts as sweeping breeze ribbons (scripts/endless/endless_eddies.gd), or null under --gusts=rings.
var eddies: Node3D
## The pollen and the grass the wash kicks up (scripts/endless/endless_motes.gd).
var motes: Node3D
## The arches over the land (scripts/endless/land_arches.gd).
var arches: Node3D
## The spruce forests (scripts/endless/land_trees.gd; off under --no-trees).
var trees: Node3D
## The birds flushed from the trees and the far flocks.
var birds: Node3D
var fish: Node3D
## Other planes in the sky, or null under --traffic=0.
var traffic: Node
var flown := 0.0
var _start := Vector2.ZERO
var _heading := 0.0
var _face_sun := false
var _numbers := false
var _alt := START_ALT
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := -100000
var _hud: Label
## The plane's ceiling over the sea (Field CEILING_OVER; --ceiling=).
var _ceiling_over := Field.CEILING_OVER
var _hint: Label
## On foot (scripts/endless/endless_walker.gd), the plane parked: see the
## "On foot" part below.
var walker: Node3D
var on_foot := false
var _exit_asked := false
var _on_foot_start := false
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.INF
var _parked_at := Vector3.ZERO
var _boarding := -1.0
## The buffet's strength (--rush=X; off by default, it read as jitter)
## and its clock.
var _rush := 0.0
var _rush_t := 0.0

## The 3D at a Native draw (the player's render resolution, and the default
## on a discrete GPU): 75%, upscaled by FSR (scripts/render_resolution.gd
## native_scale). About 2.5 ms back at 1440p on an RTX 4070 SUPER, a little
## softer (docs/design/endless-flight/cloud-weather-slices-handoff.md).
## --render-scale=1 draws at the window's own; F2 still cycles SCALES.
const NATIVE_3D := 0.75

func _ready() -> void:
	var rr := preload("res://scripts/render_resolution.gd")
	rr.native_scale = NATIVE_3D
	rr.apply(get_tree().root,rr.load_cap())
	EndlessLook.reset_season_globals()
	# The world: its shader globals over the reset, its start under the flags.
	world = WorldProfile.current()
	world.apply_globals()
	_start = world.spawn.get("at",_start)
	_alt = float(world.spawn.get("alt",_alt))
	var spawn_heading := float(world.spawn.get("heading",0.0))
	if spawn_heading != 0.0: _heading = -deg_to_rad(spawn_heading)
	Pad.ensure()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--seed="): seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--at="):
			var p := arg.get_slice("=",1).split(",")
			if p.size() >= 2: _start = Vector2(float(p[0]),float(p[1]))
		elif arg == "--heading=sun": _face_sun = true
		elif arg.begins_with("--heading="): _heading = -deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--alt="): _alt = float(arg.get_slice("=",1))
		elif arg == "--numbers": _numbers = true
		elif arg == "--on-foot": _on_foot_start = true
		elif arg.begins_with("--rush="): _rush = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--ceiling="): _ceiling_over = float(arg.get_slice("=",1))
		elif arg == "--old-land": _ceiling_over = SkyPlane.CEILING-Field.SEA_Y
		elif arg == "--uncapped":
			# No vsync and no cap, so the numbers' fps is the frame's cost.
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
	field = Field.new(seed,world)
	if EndlessLook.wanted():
		look = EndlessLook.new()
		add_child(look)
		look.setup(seed)
		sea = look.sea
		_build_camera()
		if _face_sun:
			var s: Vector3 = look.celestial.state.zs_sun_direction
			_heading = atan2(-s.x,-s.z)
	else:
		_build_light()
		_build_sea()
	land = LandStream.new()
	land.name = "Land"
	add_child(land)
	land.setup(seed,look.ground if look != null else null)
	LayoutOverrides.begin("endless_flight")
	arches = LandArches.new()
	arches.name = "Arches"
	add_child(arches)
	arches.setup(seed,look.ground if look != null else null)
	trees = LandTrees.new()
	trees.name = "Trees"
	add_child(trees)
	trees.setup(seed)
	if EndlessFish.wanted() and field.ponds > 0.0:
		fish = EndlessFish.new()
		fish.name = "Fish"
		add_child(fish)
		fish.setup(seed,field)
	birds = EndlessBirds.new()
	birds.name = "Birds"
	add_child(birds)
	birds.setup(seed,field,trees)
	if EndlessTraffic.wanted() > 0:
		traffic = EndlessTraffic.new()
		add_child(traffic)
		traffic.setup(seed,field,look,EndlessTraffic.wanted())
	if look != null:
		grass = EndlessGrass.new()
		grass.setup(seed,look.ground)
		add_child(grass)
		grass.set_enabled(EndlessGrass.wanted())
		if GrassReact.wanted():
			react = GrassReact.new()
			add_child(react)
			react.setup(seed)
			var gust_mode := EndlessEddies.mode()
			react.rings_on = gust_mode != "eddies"
			if gust_mode != "rings":
				eddies = EndlessEddies.new()
				add_child(eddies)
				eddies.setup(seed,Callable(field,"height"),react)
			if EndlessMotes.wanted():
				motes = EndlessMotes.new()
				add_child(motes)
				motes.setup(seed,Callable(field,"height"))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	_build_ui()
	_hud.visible = _numbers
	# The land round the start first, so it starts over ground that stands.
	var eye := Vector3(_start.x,_start_height(),_start.y)
	camera.global_position = eye
	var took: float = land.prime(eye)
	arches.prime(eye)
	trees.prime(eye)
	_launch(Vector3(_start.x,_start_height(),_start.y),_heading)
	walker = EndlessWalker.new()
	walker.name = "Walker"
	add_child(walker)
	walker.setup(camera,field,Callable(self,"water_at"),react)
	if _on_foot_start: await _start_on_foot()
	if grass != null and grass.enabled: grass.prime(camera.global_position,-camera.global_basis.z)
	walk_ready = true
	print("endless flight: seed %d, the land stood in %.2f s (%d chunks)%s" % [seed,took,int(land.counts().standing),"" if world.id == WorldProfile.DEFAULT else ", world "+str(world.id)])
	if get_tree().current_scene == self and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _start_height() -> float:
	return maxf(field.height(_start.x,_start.y),Field.SEA_Y)+_alt

# --- The world ------------------------------------------------------------------------

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5d8fc4")
	sky.sky_horizon_color = HORIZON
	sky.ground_bottom_color = Color("6f8a99")
	sky.ground_horizon_color = HORIZON
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = HORIZON
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.6
	# The Compatibility renderer has no depth fog: its exponential fog's
	# density, thin enough to read the far land.
	environment.fog_density = FOG_DENSITY
	environment.fog_aerial_perspective = 0.5
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	_build_camera()

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.near = 0.1
	# With the look, the haze is all sky by its end: nothing past it shows,
	# and the aerial perspective reads the sharp sky there (Godot picks the
	# radiance's blur by depth over the far plane).
	camera.far = EndlessLook.FOG_END*LandStream.view()*1.04 if look != null else FOG_END*2.2
	add_child(camera)
	camera.current = true

## The sea: one wide sheet at sea level that follows the eye.
func _build_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SEA_SIZE,SEA_SIZE)
	var m := StandardMaterial3D.new()
	m.albedo_color = SEA_COLOUR
	m.roughness = 0.12
	m.metallic_specular = 0.7
	mesh.material = m
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = mesh
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position.y = Field.SEA_Y
	add_child(sea)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16,12)
	_hud.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_hud.add_theme_constant_override("outline_size",4)
	_hud.visible = false
	layer.add_child(_hud)
	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -40.0
	_hint.offset_left = 16.0
	_hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_hint.add_theme_constant_override("outline_size",4)
	_hint.text = "A D bank  ·  W S pitch  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  Q E knife edge (twice: roll)  ·  F flaps (stopped: get out)  ·  land on the meadows  ·  R up again  ·  C clouds  ·  G grass  ·  F1 numbers  ·  F2 3D scale"
	layer.add_child(_hint)

# --- The plane ------------------------------------------------------------------------

## Flying from `at` on `heading`, at cruise, the chase camera behind it.
func _launch(at: Vector3, heading: float) -> void:
	plane = SkyPlane.new()
	plane.use_flight_speed()
	plane.floor_y = Field.SEA_Y-15.0
	plane.water = Field.SEA_Y
	# The ranges' tallest peaks stand into the cloud roof: the ceiling
	# rises over the isles' (Field CEILING_OVER, --ceiling=m over the sea).
	plane.ceiling_y = Field.SEA_Y+_ceiling_over
	# The land is a heightfield: it rides up what is no cliff, and a
	# cliff's face turns it aside (SkyGlide `stone`).
	plane.stone = func(_p: Vector3) -> bool: return true
	plane.launch(at,heading,plane.cruise(),false)
	hand_landing.begin(plane)
	if plane_figure == null:
		plane_figure = PlaneFigure.new()
		plane_figure.name = "Plane"
		add_child(plane_figure)
	plane_figure.show_pilot(true)
	plane_figure.reset(plane)
	ground_scale.reset(false)
	ground_scale.apply(plane_figure)
	plane_figure._mark.visible = false
	flaps = false
	chase = GlideCamera.new()
	chase.framed = true
	chase.sight = _sight
	chase.reset(plane,at+(-plane.forward()*GlideCamera.BACK.x+Vector3.UP*GlideCamera.UP.x)*ground_scale.size(),camera.fov)
	chase.linger = LOOK_LINGER
	if not _has_arg("--cam-speed-fov="): chase.speed_fov = RUSH_FOV
	_size_chase()
	_frame(0.0)

func _size_chase() -> void:
	chase.size = ground_scale.size()
	chase.lift = ground_scale.lift()
	var span := WorldScale.TOY_SPAN*ground_scale.size()
	chase.near = span*GlideCamera.NEAR_SPANS
	chase.extent = span*0.5
	chase.cruise = plane.cruise()
	var view := get_viewport().get_visible_rect().size
	if view.y > 0.0: chase.aspect = view.x/view.y

## The land's height under a point, for the flight (SkyGlide `step`).
## The arches stand on it (LandArches `ground`): a leg raises it, a span
## over it is a solid the plane slides under.
func plane_ground(p: Vector3) -> Variant:
	return trees.ground(p,arches.ground(p,field.height(p.x,p.z)))

## In the way of the rolling plane: an arch's leg or pier, a tree.
func _blocked(p: Vector3) -> bool:
	return arches.inside(p) or trees.inside(p)

## The turf under the wheels at a world XZ point; NAN over the sea and a
## river's water (the land field's `last_river`, from the same sample).
func floor_at(p: Vector2) -> float:
	var h: float = field.height(p.x,p.y)
	if h < Field.SEA_Y+0.2 or _on_river(): return NAN
	return h

## Whether the field's last sample was on a river's water (not the sea's
## mouth, which the sea takes).
func _on_river() -> bool:
	return field.last_river < 0.0 and field.river_drawn() > Field.SEA_Y+0.05

## The water under a point: the sea's swell, or a river's level over it.
func water_at(p: Vector3) -> float:
	var level := Field.SEA_Y+sea_height(p)
	var river: float = field.river_y(p.x,p.z)
	return level if is_nan(river) else maxf(level,river)

## Inside the land or the sea, for the camera to keep out of.
func _solid(p: Vector3) -> bool:
	var h: float = field.height(p.x,p.z)
	if _on_river(): h = maxf(h,field.river_drawn())
	return p.y < maxf(h,Field.SEA_Y+sea_height(p))+EYE_CLEAR*0.5 or arches.inside(p)

## The sea's swell over its rest level at `p` (EndlessSea `height_at`; 0 on
## the flat sea), looked up only near the water.
func sea_height(p: Vector3) -> float:
	if look == null or look.water == null or p.y > Field.SEA_Y+12.0: return 0.0
	# Up a river's mouth the sea lies still, as the sea shader draws it.
	return look.water.height_at(p.x,p.z)*(1.0-field.sea_calm(p.x,p.z))

## The share of the way from `from` to `to` clear of the land (GlideCamera
## `sight`), marched over the field.
func _sight(from: Vector3, to: Vector3) -> float:
	const STEPS := 10
	for i in range(1,STEPS+1):
		var t := float(i)/STEPS
		var p := from.lerp(to,t)
		if p.y < field.height(p.x,p.z) or arches.inside(p): return float(i-1)/STEPS
	return 1.0

func _process(delta: float) -> void:
	if not walk_ready: return
	tick(minf(delta,1.0/20.0))

## One frame: the plane flown, drawn and followed, the land streamed round
## the eye, the sea under it.
func tick(delta: float) -> void:
	flown += delta
	if on_foot:
		_foot_tick(delta)
		return
	var input := _fly_input(delta)
	# The plane skims the swell as drawn, not the sea's rest level, and a
	# river's water as it skims the sea.
	plane.water = water_at(plane.position)
	input["flaps"] = 1.0 if flaps else 0.0
	input["exit"] = _exit_asked
	_exit_asked = false
	# Rolling, the arches' legs and piers stand in the way (LandArches `inside`).
	var wheels := hand_landing.step(delta,input,Callable(self,"plane_ground"),Callable(self,"floor_at"),Callable(),Callable(self,"_blocked"))
	plane.engine = hand_landing.engine*float(plane.sputter)
	var ground := Callable(self,"plane_ground")
	plane_figure.update(delta,plane,0.0,ground,hand_landing.would_grease(Callable(self,"floor_at")))
	_hop_out(wheels,delta)
	if on_foot: return
	ground_scale.step(delta,hand_landing.on_ground(),hand_landing.dipping(),plane)
	ground_scale.apply(plane_figure)
	plane_figure._mark.visible = false
	_size_chase()
	chase.cine = Vector3(-1.25,0.0,0.3) if hand_landing.on_ground() else Vector3.ZERO
	_frame(delta)
	land.lead_with(plane.velocity)
	land.step(camera.global_position)
	arches.step(camera.global_position)
	trees.step(camera.global_position,plane.position)
	birds.step(delta,camera.global_position,plane)
	if fish != null: fish.step(delta,camera.global_position,plane.position,plane.velocity,false)
	if traffic != null: traffic.step(delta,camera.global_position,-camera.global_basis.z,plane.position,Vector3(-sin(plane.heading),0.0,-cos(plane.heading)),float(plane.speed))
	if grass != null:
		var view := get_viewport().get_camera_3d()
		var eye: Camera3D = view if view != null else camera
		grass.lead_with(plane.velocity)
		grass.step(eye.global_position,-eye.global_basis.z)
	if look != null: look.plane_at = plane.position
	if look != null: look.step(delta,camera.global_position,-camera.global_basis.z,camera)
	if react != null: _react(delta)
	else: sea.position = Vector3(snappedf(camera.global_position.x,64.0),Field.SEA_Y,snappedf(camera.global_position.z,64.0))
	_show_hud()

## The grass reacting: the plane's wash (by its height and thrust) and the
## look's breeze for the gusts (GrassReact `step`).
func _react(delta: float) -> void:
	var p: Vector3 = plane.position
	var h: float = field.height(p.x,p.z)
	var over := p.y-h if h > Field.SEA_Y+0.2 and not _on_river() else NAN
	var thrust := 0.0
	if hand_landing.on_ground(): thrust = hand_landing.engine*(0.3+0.7*maxf(hand_landing.throttle,0.0))
	else: thrust = float(plane.engine)*clampf(0.6+0.4*float(plane.throttle),0.35,1.0)
	var facing := -camera.global_basis.z
	if eddies != null:
		eddies.step(delta,camera.global_position,Vector2(facing.x,facing.z),look.wind_direction,1.0,Callable(self,"_grass_at"))
	react.step(delta,camera.global_position,
		{"position": p, "forward": plane.forward(), "over": over, "thrust": thrust, "size": ground_scale.size()},
		{"way": look.wind_direction, "travel": look._gust, "facing": Vector2(facing.x,facing.z)},
		Callable(self,"_grass_at"))
	if motes != null:
		motes.step(delta,camera.global_position,look.wind_direction,look._gust,react.wash_spot,
			eddies.ribbons.ribbons if eddies != null else [],Callable(self,"_grass_at"))

## The land's height where grass grows (open turf over the beach), else NAN.
func _grass_at(x: float, z: float) -> float:
	var h: float = field.height(x,z)
	return h if h > Field.SEA_Y+3.0 and field.last_river > Field.RIVER_CLEAR else NAN

func _frame(delta: float) -> void:
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*delta)
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	chase.step(delta,plane,0.0,_solid)
	camera.global_position = chase.eye
	var way: Vector3 = chase.look-chase.eye
	if way.length() < 0.01: way = plane.forward()
	camera.look_at(camera.global_position+way,Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD,chase.roll)
	_buffet(delta)
	camera.fov = chase.fov

## The wind's buffet past cruise: a small shake of the eye's aim, three
## sines out of step, growing to RUSH_SHAKE at Boost's speed. None on the
## wheels.
func _buffet(delta: float) -> void:
	if _rush <= 0.0 or hand_landing.on_ground(): return
	_rush_t += delta
	var v: float = plane.velocity.length()
	var k := smoothstep(plane.cruise()*RUSH_FROM,plane.boost_speed(),v)*RUSH_SHAKE*_rush
	if k <= 0.0: return
	var t := _rush_t*TAU
	var yaw := sin(t*RUSH_HZ.x)*0.6+sin(t*RUSH_HZ.z+1.7)*0.4
	var nod := sin(t*RUSH_HZ.y+0.9)*0.6+sin(t*RUSH_HZ.x*1.31+2.3)*0.4
	camera.rotate_object_local(Vector3.UP,yaw*k)
	camera.rotate_object_local(Vector3.RIGHT,nod*k*0.7)

static func _has_arg(prefix: String) -> bool:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with(prefix): return true
	return false

## The plane's input, as the isle reads it (studies/kit_isle.gd `_fly_input`).
func _fly_input(_delta: float) -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),"roll":_roll_asked}
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	return input

func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

## Back up into the air over where it is, on the heading it had.
func respawn() -> void:
	var at: Vector3 = plane.position
	_start = Vector2(at.x,at.z)
	_launch(Vector3(at.x,_start_height(),at.z),float(plane.heading))

func _unhandled_input(event: InputEvent) -> void:
	if not walk_ready: return
	if on_foot:
		_foot_event(event)
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif Pad.pressed(event,&"fly_land"): _land_key()
	elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F: _land_key()
			KEY_F1: _hud.visible = not _hud.visible
			KEY_F2: _next_scale()
			KEY_R: respawn()
			KEY_T:
				if look != null: look.next_hour()
			KEY_L:
				if look != null: look.next_mood()
			KEY_C:
				if look != null and look.clouds != null: look.clouds.set_enabled(not look.clouds.enabled)
			KEY_G:
				if grass != null: grass.set_enabled(not grass.enabled)
			KEY_Q: _lean_tapped(-1.0)
			KEY_E: _lean_tapped(1.0)
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	var rr := preload("res://scripts/render_resolution.gd")
	rr.native_scale = 1.0
	rr.apply(get_tree().root,rr.load_cap())

## F2: the 3D's resolution through SCALES (the window's own, then upscaled
## by FSR), to judge sharpness against the frame rate; shown on the hint
## line and the numbers.
const SCALES := [1.0,0.85,0.75,0.67]
func _next_scale() -> void:
	var rr := preload("res://scripts/render_resolution.gd")
	var now := get_viewport().scaling_3d_scale
	var i := 0
	for k in SCALES.size():
		if absf(SCALES[k]-now) < 0.01: i = k
	rr.scale_override = SCALES[(i+1)%SCALES.size()]
	rr.apply(get_tree().root,rr.load_cap())
	_hint.text = _hint.text.get_slice("  ·  3D at",0)+"  ·  3D at %d%%" % roundi(rr.scale_override*100.0)

func _cloud_note() -> String:
	if look.clouds == null: return "  ·  no clouds"
	if not look.clouds.enabled: return "  ·  clouds off (C)"
	return "  ·  in cloud" if look.clouds.in_cloud(camera.global_position) else ""

## The numbers (F1) are written HUD_EVERY ms apart: walking the land's and
## the grass's counts and laying the label out every frame cost about 4 ms.
const HUD_EVERY := 250
var _hud_at := -HUD_EVERY

func _show_hud() -> void:
	if not _hud.visible or Time.get_ticks_msec()-_hud_at < HUD_EVERY: return
	_hud_at = Time.get_ticks_msec()
	var p: Vector3 = plane.position
	var c: Dictionary = land.counts()
	var s: Dictionary = land.stats
	# The GPU's own time, where the driver reports it (not on Metal).
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_hud.text = "seed %d  ·  %s  ·  %.1f m/s  ·  %.0f m over the ground  ·  flaps %s\nat %.0f, %.0f  ·  %d fps (%.1f ms)%s%s%s\nland: %d drawn, %d standing, %d wanted, %d building, %d queued, %d colliders\nbuilt %d (%.1f ms each on a worker), slowest commit %.2f ms%s" % [
		seed,ManualLanding.NAMES[hand_landing.phase],float(plane.speed),p.y-maxf(field.height(p.x,p.z),Field.SEA_Y),"down" if flaps else "up",
		p.x,p.z,Engine.get_frames_per_second(),1000.0/maxf(Engine.get_frames_per_second(),1.0),
		("  ·  gpu %.2f ms" % gpu) if gpu > 0.0 else "",
		"  ·  3D at %d%%" % roundi(get_viewport().scaling_3d_scale*100.0),
		("  ·  %s, %05.2f h%s" % [look.mood_title(),look.hour(),_cloud_note()]) if look != null else "",
		int(c.drawn),int(c.standing),int(c.wanted),int(c.in_flight),int(c.queued),int(c.colliders),
		int(s.built),float(s.build_ms)/maxf(float(s.built),1.0),float(s.slowest_commit_ms),_grass_note()+_react_note()+_arch_note()+trees.note()+birds.note()+(fish.note() if fish != null else "")+(traffic.note() if traffic != null else "")]

func _react_note() -> String:
	if react == null: return ""
	return "\ngrass react: %d stamps, wash %.2f, %d gusts" % [int(react.stats.stamps),float(react.stats.wash),int(react.stats.gusts)]

func _arch_note() -> String:
	if arches.density <= 0.0: return "\nno arches"
	var a: Dictionary = arches.stats
	return "\narches: %d standing in %d cells  ·  slowest build %.0f ms on a worker, slowest commit %.2f ms" % [int(a.arches),int(a.cells),float(a.slowest_build_ms),float(a.slowest_commit_ms)]

func _grass_note() -> String:
	if grass == null: return ""
	if not grass.enabled: return "\ngrass off (G)"
	var g: Dictionary = grass.counts()
	var gs: Dictionary = grass.stats
	return "\ngrass: %d cells, %d building, %d queued, %dk plants  ·  %.0f ms a cell on a worker, slowest stand %.2f ms" % [
		int(g.cells),int(g.building),int(g.queued),int(g.instances)/1000,float(gs.grow_ms)/maxf(float(gs.grown),1.0),float(gs.slowest_stand_ms)]

# --- On foot ------------------------------------------------------------------------
# Stopped, F (pad Y) gets out: the engine spins down and the pilot hops down
# beside the plane (ManualLanding EXIT, `hop`), which stays parked where it
# stopped; he walks the land (scripts/endless/endless_walker.gd). Back by
# it, F or Space (pad Y or A) climbs in: the hop run backwards, then the
# hand landing has it stopped on its wheels, as a parked plane boarded on
# the isles (studies/kit_isle.gd `board_parked`, without its takeoff run).

## As the isles': Space or F within BOARD_REACH m (times the plane's
## ground size's root) of its middle boards; he keeps PARKED_ROOM m off its
## middle (a column PARKED_TALL m up only he sees); the hop out lands
## HOP_SIDE m to its left and HOP_AHEAD m ahead (studies/kit_isle.gd).
const BOARD_REACH := 1.9
const PARKED_ROOM := 0.75
const PARKED_TALL := 6.0
const HOP_SIDE := 1.4
const HOP_AHEAD := 0.3
const FOOT_HINT := "WASD walk  ·  mouse looks  ·  Space jump (again landing: higher)  ·  Shift slide, surf, with Space long jump  ·  Space in the air: sail  ·  by the plane F or Space climbs in  ·  R back in the air  ·  F1 numbers"
var _plane_hint := ""

## F (pad Y) in the plane: in the air the flaps go down or up; on the
## wheels it asks to get out (only stopped does it: ManualLanding `step`).
func _land_key() -> void:
	if hand_landing.flying(): flaps = not flaps
	else: _exit_asked = true

## The hop out as the hand landing runs it, and out at its end.
func _hop_out(wheels: Dictionary, delta: float) -> void:
	if hand_landing.phase == ManualLanding.EXIT:
		if _hop_to == Vector3.INF:
			_hop_from = ground_scale.point(plane_figure,plane.position+Vector3.UP*0.1)
			_hop_to = _hop_spot()
			plane_figure.show_pilot(false)
			var way := Vector2(_hop_to.x-_hop_from.x,_hop_to.z-_hop_from.z)
			if way.length() > 0.01: walker.motor.facing = walker.motor.facing_of(way.normalized())
		walker.hop(_hop_from,_hop_to,hand_landing.hop,delta)
	if wheels.has("out"): _get_out()

## Where the hop out lands: HOP_SIDE m to the plane's left and HOP_AHEAD m
## ahead on open turf; else to its right; else beside it on the land.
func _hop_spot() -> Vector3:
	var heading := float(plane.heading)
	var at: Vector3 = plane.position
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var right := Vector3(cos(heading),0.0,-sin(heading))
	var hop: Vector2 = ground_scale.hop_offset(HOP_SIDE,HOP_AHEAD)
	# Clear of the column he keeps off (else he lands on its top).
	hop.x = maxf(hop.x,_column_radius()+walker.ground.RADIUS*walker.size+0.15)
	for side: float in [-1.0,1.0]:
		var p := at+right*hop.x*side+forward*hop.y
		var h := floor_at(Vector2(p.x,p.z))
		if is_nan(h): continue
		var spot := Vector3(p.x,h,p.z)
		if trees.inside(spot+Vector3.UP*0.5) or arches.inside(spot+Vector3.UP*0.5): continue
		return spot
	var p := at-right*hop.x
	return Vector3(p.x,field.height(p.x,p.z),p.z)

## Out: the plane parked where it stands, the pilot on foot at `_hop_to`
## facing it.
func _get_out() -> void:
	on_foot = true
	flaps = false
	plane.engine = 0.0
	var under: float = field.height(plane.position.x,plane.position.z)
	_parked_at = Vector3(plane.position.x,under,plane.position.z)
	plane_figure.show_pilot(false)
	walker.set_column(_parked_at,_column_radius(),PARKED_TALL)
	var spot := _hop_to if _hop_to != Vector3.INF else _hop_spot()
	var to := Vector2(_parked_at.x-spot.x,_parked_at.z-spot.z)
	walker.place(spot,to.normalized() if to.length() > 0.01 else Vector2(0.0,-1.0))
	_hop_to = Vector3.INF
	if _plane_hint == "": _plane_hint = _hint.text
	_hint.text = FOOT_HINT

func _column_radius() -> float:
	return PARKED_ROOM*sqrt(ground_scale.ground_size())

## True on foot within reach of the parked plane.
func by_plane() -> bool:
	if not on_foot or _boarding >= 0.0: return false
	var feet: Vector3 = walker.motor.feet
	return Vector2(feet.x-_parked_at.x,feet.z-_parked_at.z).length() <= BOARD_REACH*sqrt(ground_scale.ground_size()) and absf(feet.y-_parked_at.y) < 1.5

## Climbing in: the hop run backwards (PlaneLanding BOARD_TIME), then in.
func board() -> void:
	if not by_plane(): return
	_boarding = 0.0
	_hop_from = walker.motor.feet
	_hop_to = ground_scale.point(plane_figure,plane.position+Vector3.UP*0.1)
	walker.clear_column()

## In the plane, stopped on its wheels, the chase camera from where the
## walker's camera stood.
func _into_plane() -> void:
	_leave_foot()
	plane_figure.show_pilot(true)
	hand_landing.begin(plane,true)
	ground_scale.reset(true)
	ground_scale.apply(plane_figure)
	chase = GlideCamera.new()
	chase.framed = true
	chase.sight = _sight
	chase.reset(plane,camera.global_position,camera.fov)
	chase.linger = LOOK_LINGER
	_size_chase()
	_frame(0.0)

func _leave_foot() -> void:
	on_foot = false
	_boarding = -1.0
	_hop_to = Vector3.INF
	walker.hide_figure()
	walker.clear_column()
	if _plane_hint != "": _hint.text = _plane_hint

## One frame on foot: the walker (or his hop in), then the land, trees,
## arches, grass, look and grass reacting round the eye as in the plane.
func _foot_tick(delta: float) -> void:
	if _boarding >= 0.0:
		_boarding += delta
		var k := 1.0-clampf(_boarding/PlaneLanding.BOARD_TIME,0.0,1.0)
		walker.hop(_hop_to,_hop_from,k,delta)
		if _boarding >= PlaneLanding.BOARD_TIME:
			_into_plane()
			return
	else:
		walker.tick(delta)
	var eye := camera.global_position
	land.step(eye)
	arches.step(eye)
	trees.step(eye,walker.motor.feet)
	birds.step(delta,eye,plane)
	if fish != null: fish.step(delta,eye,walker.motor.feet,walker.motor.velocity,true)
	if traffic != null: traffic.step(delta,eye,-camera.global_basis.z,eye,-camera.global_basis.z,0.0)
	if grass != null:
		var view := get_viewport().get_camera_3d()
		var at: Camera3D = view if view != null else camera
		grass.lead_with(walker.motor.velocity)
		grass.step(at.global_position,-at.global_basis.z)
	if look != null: look.plane_at = plane.position
	if look != null: look.step(delta,eye,-camera.global_basis.z,camera)
	if react != null: _react(delta)
	else: sea.position = Vector3(snappedf(eye.x,64.0),Field.SEA_Y,snappedf(eye.z,64.0))
	_show_hud()

## On foot: the mouse turns the view, F or Space by the plane boards it, R
## back into the air over where he stands; the look's keys as in the plane
## (C is crouch here, not the clouds).
func _foot_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: walker.look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var key := (event as InputEventKey).keycode if event is InputEventKey and event.pressed and not event.echo else KEY_NONE
	if (key == KEY_F or key == KEY_SPACE or Pad.pressed(event,&"fly_land") or Pad.pressed(event,&"walk_jump")) and by_plane():
		board()
		Input.action_release(&"walk_jump")
		return
	match key:
		KEY_F1: _hud.visible = not _hud.visible
		KEY_F2: _next_scale()
		KEY_R: _fly_from_foot()
		KEY_T:
			if look != null: look.next_hour()
		KEY_L:
			if look != null: look.next_mood()
		KEY_G:
			if grass != null: grass.set_enabled(not grass.enabled)
		KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## R on foot: back up into the air in the plane, over where he stands, on
## the way the view looks.
func _fly_from_foot() -> void:
	var feet: Vector3 = walker.motor.feet
	var heading: float = walker.yaw()
	_leave_foot()
	_start = Vector2(feet.x,feet.z)
	_launch(Vector3(feet.x,_start_height(),feet.z),heading)

## --on-foot: the plane parked on the land at the start, the pilot out
## beside it, once the colliders under it stand.
func _start_on_foot() -> void:
	_start = _dry_spot(_start)
	var height := func(p: Vector2) -> float: return field.height(p.x,p.y)
	var r := PlaneStrip.rest(height,_start,_heading)
	plane.park(Vector3(_start.x,r.x,_start.y),_heading,r.y,r.z)
	hand_landing.begin(plane,true)
	plane_figure.reset(plane)
	ground_scale.reset(true)
	ground_scale.apply(plane_figure)
	plane_figure.update(0.0,plane,0.0,Callable(self,"plane_ground"),false)
	var eye := Vector3(_start.x,r.w+2.0,_start.y)
	for i in range(3):
		land.step(eye)
		trees.step(eye,eye)
		await get_tree().physics_frame
	_get_out()

## The nearest open, level, dry turf to `near` (x, z) within 300 m, rings
## out from it: the turf under it and 3 m round within 0.4 m, no water, no
## tree or arch; failing all, `near`.
func _dry_spot(near: Vector2) -> Vector2:
	var r := 0.0
	while r <= 300.0:
		var count := 1 if r == 0.0 else 16
		for i in range(count):
			var a := TAU*float(i)/float(count)+r*0.37
			var p := near+Vector2(cos(a),sin(a))*r
			var h := floor_at(p)
			if is_nan(h) or h < Field.SEA_Y+1.0: continue
			var ok := true
			for d: Vector2 in [Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3),Vector2(6,0),Vector2(-6,0)]:
				var q := floor_at(p+d)
				if is_nan(q) or absf(q-h) > 0.4 or walker.water_depth(p+d) > 0.0: ok = false
			var up := Vector3(p.x,h+1.0,p.y)
			if ok and not trees.inside(up) and not arches.inside(up): return p
		r += 4.0
	return near