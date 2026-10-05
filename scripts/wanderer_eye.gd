extends Node
## A first test for a human who roams the chunk: an unseen figure stands on
## the land and the camera can step into its eyes. V with the pointer on the land
## sets the figure down there (or picks it up and moves it) and looks out
## through it; V with the pointer off the land steps into it where it stands.
## In its eyes the mouse is captured: move to look, WASD or the arrows walk,
## Shift runs. V or Esc steps back out, and the camera glides back to where it
## was; the figure stays where you walked it. Walking, the eye bobs with each
## footfall and sways a little from foot to foot, and each footfall sounds
## (scripts/wanderer_steps.gd): earth, a bridge's planks or a wade.
##
## Like photo mode (scripts/photo_mode.gd) this runs before the scene each
## frame (process_priority) and writes the pose into the scene's own orbit
## (target, yaw, polar, distance), so the fog, reflections and look pass read
## the same camera they always do. The figure is not saved with the place.
##
## Walked off the plate's edge, the figure glides (scripts/sky_glide.gd): out
## over the cloud sea towards fresh flat chunks set in the sky
## (scripts/sky_islands.gd), with the air streaking past and the wind's sound
## (scripts/glide_air.gd). Touching down on land skims along it, and a
## slow skim lands, back to walking. Space jumps; held past the top of the
## jump it opens the glide anywhere: a flutter off flat ground, a real glide
## off a ridge. Over the island the wind lifts it where it blows up a slope
## (ridge lift) and as a gust front passes, and tree crowns lift it over
## them like the ground. A prototype: `--no-glide` keeps the old plate clamp.
##
## It flies a little prop plane (scripts/sky_plane.gd, drawn by
## scripts/plane_figure.gd): always under power, Space or the pad's right
## trigger (or A) boosts, Shift or the left trigger brakes, left and right
## roll it into its turns, and Q and E (or a click, or the pad's shoulders)
## throw a barrel roll. The mouse (or the right stick) pans the camera round
## it rather than steering, and the pan holds PLANE_LINGER seconds before
## swinging back behind, for the view. In the air the camera chases it from
## behind (scripts/glide_camera.gd); C swaps to the view from its eyes. It
## can dip under an island's slab. Near the ground a mark shows where it
## would touch down.
##
## F lands it (scripts/plane_landing.gd): the nearest island within
## LANDING_REACH is claimed if it is not the plate yet, a strip picked on
## its land (scripts/plane_strip.gd: the longest, flattest clear run, into
## the wind), and the plane lines up, glides down, flares, touches with a
## bounce and a puff, rolls to a stop, and the pilot hops out; the camera
## swoops into the eyes beside it. Before the touch, Boost, a roll or F
## again flies on; after, F hops out at once. A slow touch anywhere on the
## land without F rolls it to a stop where it came down. The plane stays
## parked where it stopped, on its wheels and tail skid, out of the way of
## the editor's tools (not a record on the land; the walker steps round
## it). Walked up to, Space takes off from it: the pilot hops in, it turns
## to its longest clear run, rolls, lifts and flies. Flying any other way
## (off the edge, a held jump) brings it along: the parked one goes in a
## puff, so there is only ever the one plane, and it is always yours.
##
## With `--glider` it glides under the old cloth wing instead
## (scripts/glider_figure.gd): a click (or E, or the pad's X) flaps for lift
## of its own, the right mouse button (or the right stick) looks round it,
## F comes in to land at the island's middle, and touching down slowly
## anywhere on the island lands, the camera swooping down into its eyes.

const Plate = preload("res://scripts/plate.gd")
## The figure's height and the eye's height above the ground, in metres. The
## diorama is toy-scaled: trees stand about 3 to 5 m and photo mode's ground
## eye sits at 0.85 m.
const FIGURE_HEIGHT := 0.95
const EYE_HEIGHT := 0.85
## Walking and running speed, in metres a second, and how fast the pace eases.
const WALK := 1.6
const RUN := 4.0
const EASE_PACE := 0.12
## The eye rides over bumps rather than snapping to every step.
const EASE_HEIGHT := 0.08
## Radians of look per pixel of captured mouse movement.
const LOOK := 0.0025
## The eye's vertical field of view, in degrees: wider than the orbit's 45 so
## the land round the figure fills the view as it would for someone standing
## there. It eases in on stepping in and back on stepping out.
const FOV := 70.0
const EASE_FOV := 0.2
## The polar range of the look: near straight down to well above the horizon.
const POLAR := Vector2(0.25,2.8)
## The walk stays on the plate.
const PLATE_REACH := Plate.HALF-0.5
## How far inside the shore a walker is put back on an outlined island (m).
const SHORE_INSET := 0.1
## Seconds the glide back to the orbit takes.
const RETURN := 0.7
## The figure's own radius in the plate plane, with room for the eye's near
## plane, so trunks and rocks never fill the view.
const RADIUS := 0.28
## What stops the figure: trees, rocks and the other solid props. Only their
## geometry between STEP and HEAD above their ground counts, so a crown that
## sweeps low (a spruce) keeps the eye out of it, a broadleaf's high crown
## does not, and anything lower than STEP is stepped over.
const SOLID := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","snag","birch","willow","juniper","joshua","cactus",
	"rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4"]
const STEP := 0.2
const HEAD := FIGURE_HEIGHT+0.2
## Bands each part's mesh is cut into for its footprint (`_profile`).
const BANDS := 24
## Push-out passes a step takes; each can move off one more obstacle.
const PASSES := 3
## Water: the figure wades in, slowing, and will not step where live water
## stands deeper than WADE metres; a soft wall it slides along.
const WADE := 0.4
const WADE_SLOW := 0.55
## How far round `place` looks for a free spot, and the ring spacing.
const FREE_REACH := 4.0
const FREE_STEP := 0.2
## Creatures notice the figure (scripts/disturbance.gd, scripts/life_notice.gd):
## a disturbance each STRIDE metres walked, as strong as the pace (a run is
## 1), one every STILL_PING seconds while it stands in its eyes, at
## STILL_STRENGTH, and one when it is set down, at PLACE_STRENGTH.
const STRIDE := 0.7
const STILL_PING := 2.0
const STILL_STRENGTH := 0.15
const PLACE_STRENGTH := 0.6
## Footfalls: metres a step at a walk and at a full run. The eye dips BOB m at
## each footfall (more at a run) and sways SWAY of that from side to side, a
## sway a stride of two steps; the bob eases in and out with the pace.
const STEP_WALK := 0.7
const STEP_RUN := 1.25
const BOB_WALK := 0.032
const BOB_RUN := 0.06
const SWAY := 0.6
const EASE_BOB := 0.15
## Where the first footfall comes on setting off, as a share of a step.
const FIRST_STEP := 0.55
## Ground cover at least GRASSY sounds as grass; bare ground within SHORE m of
## water to wade sounds as sand.
const GRASSY := 0.4
const SHORE := 0.7
const WandererSteps = preload("res://scripts/wanderer_steps.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const Shape = preload("res://scripts/native_formation_shape.gd")
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Disturbance = preload("res://scripts/disturbance.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Shift to run  ·  Space to jump, hold to fly  ·  V or Esc to step out"
const PERCH_HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Walk off the edge or hold Space to fly  ·  V or Esc to step out"
const GLIDER_HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Shift to run  ·  Space to jump, hold to glide  ·  V or Esc to step out"
const GLIDER_PERCH_HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Walk off the edge or hold Space to glide  ·  V or Esc to step out"
## Beside the parked plane, coming in to land, and rolling out.
const BOARD_HINT := "Space to take off  ·  WASD or arrows to walk  ·  Mouse to look  ·  V or Esc to step out"
const LANDING_HINT := "Coming in to land  ·  Space, Q E or F to fly on"
const ROLLING_HINT := "F to hop out"
const NO_LANDING_HINT := "No island near enough to land on"
const PLANE_HINT := "A D to bank and turn  ·  W S to pitch  ·  Mouse to look round  ·  Space to boost  ·  Shift to brake  ·  Q E or click to barrel roll  ·  F to land  ·  C for the camera  ·  V or Esc to step out"
## The plane's camera pan holds this many seconds after the mouse or the
## right stick last turned it, then swings back behind.
const PLANE_LINGER := 2.5
## Walked within BOARD_REACH m of the parked plane, Space takes off; the
## walker keeps PARKED_ROOM m from its middle.
const BOARD_REACH := 1.9
const PARKED_ROOM := 0.75
## Hopping out, the walker lands this far to the plane's left (m) and a
## little ahead, and hops this high (m).
const HOP_SIDE := 1.4
const HOP_AHEAD := 0.3
const HOP_HEIGHT := 0.55
## Anything standing taller than this over its ground (m) is in the wings'
## way on a strip.
const WING_LOW := 0.28
const FLY_HINT := "Mouse or A D to turn  ·  W S to pitch  ·  Click or E to flap  ·  Space to rise  ·  Shift to dive  ·  F to land  ·  Right mouse to look round  ·  C for the camera  ·  V or Esc to step out"
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
## The world's ring (scripts/sky_world.gd): with it, the view reaches across
## the whole world (VIEW_FAR), so the ring stands as a skyline.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const GlideAir = preload("res://scripts/glide_air.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const GliderFigure = preload("res://scripts/glider_figure.gd")
const IslandFrame = preload("res://scripts/island_frame.gd")
const GlideVapour = preload("res://scripts/glide_vapour.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
## The chase view's field of view at a cruise; the camera widens it with
## speed (GlideCamera `fov`).
const CHASE_FOV := GlideCamera.FOV
## Seconds the camera takes to swoop from the chase into the eyes on landing.
const SWOOP := 0.9
## The right stick's free look, radians a second at full tilt.
const STICK_LOOK := 2.4
## A skim this slow for this long, not diving, lands.
const LAND_SPEED := 10.0
## The islands stand hundreds of metres apart; the view reaches FLY_FAR m
## while gliding.
const FLY_FAR := 3000.0
## The jump: metres a second up, the fall's pull, and how long Space must be
## held from the jump before the glide opens.
const JUMP := 3.3
const GRAVITY := 9.8
const OPEN_AFTER := 0.2
## Ridge lift: where the wind blows up a slope, the air rises by RIDGE_GAIN
## times the wind's speed times the slope (sampled RIDGE_STEP m either way
## along the wind), up to RIDGE_MAX m/s, fading out by RIDGE_REACH m over the
## ground. Gust fronts lift by GUST_LIFT and push by GUST_PUSH m/s per unit of
## their lean (studies/gust_fronts.gd `lean_at`).
const RIDGE_GAIN := 2.2
const RIDGE_STEP := 1.5
const RIDGE_MAX := 6.5
const RIDGE_REACH := 14.0
const GUST_LIFT := 9.0
const GUST_PUSH := 5.0
const LAND_TIME := 0.3
## F lands on the nearest island this near (m, in the plate plane).
const LANDING_REACH := 160.0

signal entered
signal left

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
## True while the camera looks through the figure.
var active := false
## The figure, parented to the terrain so it turns with the world.
var figure: Node3D
## Terrain-local position of the figure's feet.
var _feet := Vector3.ZERO
var _eye_y := 0.0
var _yaw := 0.0
var _polar := PI*0.5
var _pace := Vector2.ZERO
var _before := {}
var _returning := 0.0
## The orbit camera's field of view before stepping in.
var _fov_before := 45.0
var _hint_time := 0.0
var _layer: CanvasLayer
var _hint: Label
var _dot: Control
## Obstacles in the plate plane: [Vector3(x, z, radius)], figure radius
## included, and what they were read from (`_obstacle_key`).
var _obstacles := PackedVector3Array()
var _obstacle_key := []
## Live water depths, read once a frame while walking.
var _depths := PackedFloat32Array()
## Metres walked and seconds stood since the last disturbance.
var _stride := 0.0
var _still := 0.0
## Steps walked (the fraction is the way through the current one), the bob's
## depth now, and the eye's offset from it (terrain-local).
var _steps := 0.0
var _bob := 0.0
var _bob_offset := Vector3.ZERO
var steps: Node
## The glide (scripts/sky_glide.gd), the islands it flies between and the air
## round it; `flying` while it glides.
var glide := SkyGlide.new()
var islands: Node3D
var air: Node3D
## The sky's answer to the glide: the cloud sea and the vapour (scripts/sky_flight.gd).
var sky: Node
var flying := false
var glide_enabled := "--no-glide" not in OS.get_cmdline_user_args()
## Flying the little plane (the default), or the old glider (`--glider`).
var plane := flies_plane(OS.get_cmdline_user_args())
## The plane's landing or takeoff under way (scripts/plane_landing.gd), and
## which; F pressed and waiting for its island to be claimed.
var landing: RefCounted = null
var _taking_off := false
var _landing_wait := false
## The plane parked on the plate (a PlaneFigure under the terrain), where
## its flight position stands (plate XZ) and its heading (plate yaw).
var parked: Node3D = null
var _parked_at := Vector2.ZERO
var _parked_heading := 0.0
## Where the hop out lands (plate frame) and where it leaves from.
var _hop_to := Vector3.INF
var _hop_from := Vector3.ZERO
var _board_asked := false
var _near_plane := false
## Mouse look gathered for the glide's next step, and seconds of skim so far.
var _fly_look := Vector2.ZERO
var _skim_time := 0.0
## The chase camera, the figure drawn gliding, and how close it passes to
## rock, for the vapour off its wingtips.
var chase := GlideCamera.new()
var glider: Node3D
var vapour := GlideVapour.new()
## The landing's swoop into the eyes: seconds left, and the chase pose it
## leaves from.
var _swoop := 0.0
var _swoop_from := {}
## A flap asked for since the last glide step (click, E or the pad's X),
## the pad's X last frame, and the glide's flaps when last heard.
var _flap_asked := false
var _pad_flap_was := false
var _flaps_heard := 0
## The plane's barrel roll asked for since the last step (-1 left, 1 right),
## and the pad's shoulders last frame.
var _roll_asked := 0.0
var _pad_roll_was := Vector2.ZERO
var _far_before := 500.0
## The jump: how high the feet are off the ground, how fast they rise, and
## how long Space has been held since the jump (-1 once let go).
var _hop := 0.0
var _hop_rise := 0.0
var _hop_held := -1.0
var _jump_was := false
## Perched on an islet (scripts/sky_islets.gd): its record, empty when not;
## the feet in its frame and the eye's height over them.
var perch := {}
var _perch_feet := Vector3.ZERO
var _perch_eye := EYE_HEIGHT
## Tree and rock crowns in the plate plane: (x, z, radius, top), terrain-local.
var _crowns := PackedVector4Array()
## Each island's land middle for F's landing (`_land_middle`), by land.
var _middles := {}
## Footprint profile of a mesh: [y0, band height, radius per band...].
static var _profiles := {}

## Whether a run with these command line arguments flies the plane: yes,
## unless `--glider` asks for the old glider.
static func flies_plane(args: PackedStringArray) -> bool:
	return "--glider" not in args

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	name = "WandererEye"
	# Before the scene's own _process (and with photo mode), so the scene
	# reads this frame's pose.
	process_priority = -10
	set_process(false)
	# A new world (`reset_flat`: the flip, a new plain, a regrow) has no
	# figure on it until the next V.
	editor.data.state_restored.connect(_world_restored)
	# The parked plane settles again on land shaped under it.
	editor.data.history_captured.connect(func(_state: Dictionary) -> void: _seat_parked.call_deferred())
	steps = WandererSteps.new()
	add_child(steps)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	_hint = Label.new()
	_hint.text = _walk_hint()
	_hint.add_theme_font_size_override("font_size",15)
	_hint.add_theme_color_override("font_color",Color("fbf6ea"))
	_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
	_hint.add_theme_constant_override("shadow_offset_y",1)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -56.0
	_hint.offset_bottom = -30.0
	_hint.offset_left = -640.0
	_hint.offset_right = 640.0
	_layer.add_child(_hint)
	# A faint dot where the eye looks.
	_dot = Control.new()
	_dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void:
		_dot.draw_circle(_dot.size*0.5,2.5,Color(1,1,1,0.55),true,-1.0,true))
	_layer.add_child(_dot)
	if glide_enabled:
		if plane:
			glide = SkyPlane.new()
			chase.linger = PLANE_LINGER
		islands = SkyIslands.new()
		islands.setup(scene)
		add_child(islands)
		# A mountain's rock is ridden only where it is no steeper than the
		# glide can ride, and an isle's trees turn it aside (SkyGlide
		# `stone`).
		glide.stone = Callable(islands,"stone")
		# A world loaded before the islands were made left its sky here.
		var places: Variant = scene.get("places")
		if places is Node: islands.load_state(places.sky_state)
		sky = SkyFlight.new()
		add_child(sky)
		sky.setup(scene)
		air = GlideAir.new()
		add_child(air)
		islands.skip.append(air)
		if plane: glider = PlaneFigure.new()
		else: glider = GliderFigure.new()
		glider.visible = false
		add_child(glider)
		islands.skip.append(glider)
		# The mountains stand round the plate in the build view too
		# (SkyIslands `_process`): the view reaches them.
		if SkyWorld.ring_on(): camera.far = maxf(camera.far,SkyWorld.VIEW_FAR)

# --- The figure -------------------------------------------------------------------

## Where the walker stands and faces, kept as a bare node: it is never drawn
## (the parked plane shows where you came down), only remembered for the
## next V and moved through the hop in and out of the plane.
func _build_figure() -> void:
	figure = Node3D.new()
	figure.name = "Wanderer"
	editor.terrain.add_child(figure)
	if islands != null: islands.skip.append(figure)

func _world_restored(state: Dictionary) -> void:
	# A claimed island's plain is formed under the glide, not a new world.
	if state.is_empty() and not (islands != null and islands.claiming): forget()
	elif has_parked(): _seat_parked.call_deferred()

## The figure is gone, stepped out of first if the eye is in it; V sets a
## new one down.
func forget() -> void:
	if active: leave()
	if has_figure(): figure.queue_free()
	figure = null
	_unpark(false)
	_feet = Vector3.ZERO
	_obstacle_key = []
	_obstacles = PackedVector3Array()
	_depths = PackedFloat32Array()

func has_figure() -> bool:
	return figure != null and is_instance_valid(figure)

## What a local point stands on: a footbridge's deck where there is one
## (scripts/footbridge.gd `deck_at`), else the terrain, or the point's own
## height off the map.
func _ground(local: Vector3) -> float:
	var at := Vector2(local.x,local.z)
	var h: Variant = editor.data.ground_height(at)
	var deck := _deck(at)
	if not deck.is_empty(): return maxf(float(deck.y),float(h) if h != null else -INF)
	return float(h) if h != null else local.y

## The footbridge deck under a plate point, or {}.
func _deck(point: Vector2) -> Dictionary:
	return Footbridge.deck_at(Footbridge.decks(editor.data),point)

func _clamped(local: Vector3) -> Vector3:
	local.x = clampf(local.x,-PLATE_REACH,PLATE_REACH)
	local.z = clampf(local.z,-PLATE_REACH,PLATE_REACH)
	# On an outlined island, the nearest land (a bridge's deck is footing too).
	if not _on_land(Vector2(local.x,local.z)):
		var land := editor.data.nearest_land(Vector2(local.x,local.z),SHORE_INSET)
		if land != Vector2.INF:
			local.x = land.x
			local.z = land.y
	local.y = _ground(local)
	return local

## Set the figure down at a terrain-local point, facing the way the camera
## looks: on the nearest free, shallow spot to it.
func place(local: Vector3) -> void:
	if not has_figure(): _build_figure()
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(local)))
	_yaw = scene.yaw
	_sync_figure()
	_disturb(PLACE_STRENGTH)

## The terrain's own turn; the world turn (scripts/world_turn.gd) turns the
## camera, so this is normally 0.
func _turn() -> float:
	return editor.terrain.global_basis.get_euler().y

## The scene's yaw points from the look target to the camera; the figure
## faces the other way, down its local -Z, in the terrain's frame.
func _sync_figure() -> void:
	if not has_figure(): return
	figure.position = _feet
	figure.rotation = Vector3(0.0,_yaw-_turn(),0.0)

# --- Obstacles and water ------------------------------------------------------------

## Re-reads the solid props' footprints when the objects or their batches
## have changed (or always, with `force`). Each drawn part of a solid object
## becomes a circle round its origin, as wide as its mesh is between STEP
## and HEAD over the object's ground.
func _read_obstacles(force: bool) -> void:
	var content: Node = editor.content
	if content == null: return
	var batches: Array = content._batches
	var key := [editor.data.objects_revision,batches.size(),_parked_at if has_parked() else null]
	for batch in batches: key.append(batch.get_instance_id())
	if not force and key == _obstacle_key: return
	_obstacle_key = key
	_obstacles = PackedVector3Array()
	_crowns = PackedVector4Array()
	# The parked plane: the walker steps round it.
	if has_parked(): _obstacles.append(Vector3(_parked_at.x,_parked_at.y,PARKED_ROOM+RADIUS))
	var to_plate: Transform3D = editor.terrain.global_transform.affine_inverse()
	for batch: MultiMeshInstance3D in batches:
		if not is_instance_valid(batch) or batch.multimesh == null or batch.multimesh.mesh == null: continue
		var sources: Array = content._sources.get(batch.get_meta("part"),[])
		for source: Dictionary in sources:
			var item: Variant = source.get("item")
			if item == null or not str(item.asset) in SOLID: continue
			var placed: Variant = content._instance_transform(source)
			if placed == null: continue
			_add_obstacle(batch.multimesh.mesh,to_plate*batch.global_transform*(placed as Transform3D),item)
	# The encounter tree is a landmark of its own, not a batch.
	var landmarks: Node = editor.get("landmarks")
	if landmarks == null: return
	for item: Dictionary in editor.data.objects:
		if item.asset != "bigfoot_tree": continue
		var node := landmarks.get_node_or_null("%s_%d" % [item.asset,item.id])
		if node == null: continue
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh != null: _add_obstacle(mesh.mesh,to_plate*mesh.global_transform,item)

func _add_obstacle(mesh: Mesh, placed: Transform3D, item: Dictionary) -> void:
	var profile := _profile(mesh)
	if profile.size() < 3: return
	var ground := _ground(Vector3(float(item.x),placed.origin.y,float(item.z)))
	var lift: float = placed.basis.y.y
	var scale := placed.basis.get_scale()
	var wide := maxf(scale.x,scale.z)
	var reach := 0.0
	for band in range(profile.size()-2):
		var low := placed.origin.y+lift*(profile[0]+profile[1]*band)
		var high := low+lift*profile[1]
		if high < ground+STEP or low > ground+HEAD: continue
		reach = maxf(reach,profile[band+2]*wide)
	if reach > 0.0: _obstacles.append(Vector3(placed.origin.x,placed.origin.z,reach+RADIUS))
	# The whole crown, for the glide to lift over.
	var crown := 0.0
	for band in range(profile.size()-2): crown = maxf(crown,profile[band+2]*wide)
	var top := placed.origin.y+lift*(profile[0]+profile[1]*(profile.size()-2))
	if crown > 0.0 and top > ground+STEP: _crowns.append(Vector4(placed.origin.x,placed.origin.z,crown,top))

## A mesh's footprint by height: [lowest y, band height, then the widest
## any vertex in each band stands from the mesh's vertical axis]. Built once.
static func _profile(mesh: Mesh) -> PackedFloat32Array:
	if _profiles.has(mesh): return _profiles[mesh]
	var box := mesh.get_aabb()
	var profile := PackedFloat32Array([box.position.y,maxf(box.size.y,0.001)/BANDS])
	profile.resize(BANDS+2)
	for s in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			var band := clampi(int((v.y-profile[0])/profile[1]),0,BANDS-1)
			profile[band+2] = maxf(profile[band+2],Vector2(v.x,v.z).length())
	_profiles[mesh] = profile
	return profile

func _read_depths() -> void:
	var flow: RefCounted = editor.get("flow")
	_depths = flow.depths() if flow != null and flow.ready else PackedFloat32Array()

## Live water depth at a plate point, 0 without live water or on a bridge.
func _depth(point: Vector2) -> float:
	if _depths.is_empty() or not _deck(point).is_empty(): return 0.0
	var at: int = editor.flow.cell_at(point)
	return _depths[at] if at >= 0 and at < _depths.size() else 0.0

func _wet(point: Vector2) -> bool:
	return _depth(point) > WADE

## `point` pushed out of every obstacle it stands in, PASSES times over.
func _pushed_out(point: Vector2) -> Vector2:
	for i in range(PASSES):
		var moved := false
		for o in _obstacles:
			var away := point-Vector2(o.x,o.y)
			var gap := away.length()
			if gap >= o.z: continue
			point = Vector2(o.x,o.y)+(away/gap if gap > 0.0001 else Vector2.RIGHT)*o.z
			moved = true
		if not moved: break
	return point

func _blocked(point: Vector2) -> bool:
	for o in _obstacles:
		if point.distance_squared_to(Vector2(o.x,o.y)) < o.z*o.z-0.0001: return true
	return _wet(point)

## One step of the walk: into the obstacles, then pushed back out along
## their normals, which keeps the part of the step along them, so the figure
## slides round a trunk. Walked square into one it is turned a little aside,
## so it never stops dead. Deep water is a wall: the step keeps whichever of
## its two plate axes stays shallow.
func _walk(feet: Vector3, step: Vector2) -> Vector3:
	if step.length_squared() < 1e-10: return feet
	var from := Vector2(feet.x,feet.z)
	var to := from+step
	for o in _obstacles:
		var centre := Vector2(o.x,o.y)
		var away := to-centre
		if away.length() >= o.z: continue
		var normal := (from-centre).normalized() if from.distance_to(centre) > 0.0001 else -step.normalized()
		# Square on: lean the step round the trunk on the side it is already on.
		if step.normalized().dot(-normal) > 0.97:
			var side := signf(normal.cross(step)) if absf(normal.cross(step)) > 1e-6 else 1.0
			to += Vector2(-normal.y,normal.x)*side*step.length()*0.6
	to = _pushed_out(to)
	# A bridge with hand rails keeps the walker on it; one without lets them
	# step off its side, where the water allows.
	var deck := _deck(from)
	if not deck.is_empty() and deck.deck.rails and _deck(to).is_empty(): to = Footbridge.keep_on(deck.deck,to,RADIUS*0.5)
	if _wet(to) and not _wet(from):
		var across := Vector2(to.x,from.y)
		var along := Vector2(from.x,to.y)
		if not _wet(across) and not _blocked(_pushed_out(across)): to = _pushed_out(across)
		elif not _wet(along) and not _blocked(_pushed_out(along)): to = _pushed_out(along)
		else: to = from
	return Vector3(to.x,feet.y,to.y)

## The free, shallow spot nearest `local` (on the plate), or `local` itself
## if nothing is free within FREE_REACH.
func _free_spot(local: Vector3) -> Vector3:
	var at := Vector2(local.x,local.z)
	if not _blocked(at) and _pushed_out(at) == at: return local
	# The push-out first: the nearest way out of the one it stands in.
	var out := _pushed_out(at)
	if _free(out): return Vector3(out.x,local.y,out.y)
	var ring := FREE_STEP
	while ring <= FREE_REACH:
		var best := Vector2.INF
		var count := maxi(8,int(TAU*ring/FREE_STEP))
		for i in range(count):
			var angle := TAU*i/count
			var p := at+Vector2(cos(angle),sin(angle))*ring
			if _free(p) and (best == Vector2.INF or p.distance_squared_to(at) < best.distance_squared_to(at)): best = p
		if best != Vector2.INF: return Vector3(best.x,local.y,best.y)
		ring += FREE_STEP
	return local

func _free(p: Vector2) -> bool:
	return absf(p.x) <= PLATE_REACH and absf(p.y) <= PLATE_REACH and _on_land(p) and not _blocked(p)

## Whether the island holds plate point `p` as ground to stand on: its land
## (the whole square if it has no outline), or a footbridge deck.
func _on_land(p: Vector2) -> bool:
	return editor.data.has_land(p) or not _deck(p).is_empty()

## Whether a walk to plate point `p` has gone off the island: past the
## square's reach, or past the shore of an outlined one.
func _off_plate(p: Vector2) -> bool:
	return absf(p.x) > PLATE_REACH or absf(p.y) > PLATE_REACH or not _on_land(p)

# --- Stepping in and out ------------------------------------------------------------

func can_enter() -> bool:
	if active or scene == null or not scene.get("shell_ready") or not scene._has_world: return false
	if scene._menu.visible or scene.crafting or editor.forming: return false
	var photo: Node = scene.get("photo")
	if photo != null and photo.active: return false
	var watch: Node = scene.get("watch")
	if watch != null and watch.active: return false
	var places: Node = scene.get("places")
	return places == null or not places.busy

## V from the world: set the figure down under the pointer (if the land is
## there) and look through it.
func summon(pointer: Vector2) -> void:
	if not can_enter(): return
	var hit: Variant = editor.pick(pointer)
	if hit != null: place(hit)
	elif not has_figure(): place(editor.terrain.to_local(scene.target))
	enter()

func enter() -> void:
	if not can_enter() or not has_figure(): return
	_before = {"looking":scene.looking,"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance,"auto":scene._auto_orbit}
	if _returning <= 0.0: _fov_before = camera.fov
	if not scene.looking:
		scene._set_looking_state(true)
		editor.set_active(false)
		scene._sync_creation_ui()
	active = true
	_returning = 0.0
	_swoop = 0.0
	_pace = Vector2.ZERO
	# The mountain ring's skyline is worked out from here, so it stands
	# whole by the time the glide opens (scripts/sky_ring.gd).
	if islands != null: islands.warm_ring()
	_yaw = figure.rotation.y+_turn()
	_polar = PI*0.5
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(_feet)))
	_eye_y = _feet.y+EYE_HEIGHT
	_steps = FIRST_STEP
	_bob = 0.0
	_bob_offset = Vector3.ZERO
	scene._orbiting = false
	scene._panning = false
	scene._auto_orbit = false
	figure.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_layer.visible = true
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	set_process(true)
	entered.emit()

func leave() -> void:
	if not active: return
	var eye := _eye_global()
	if flying:
		var at := glide.position
		# From the chase the orbit takes over where the camera is.
		eye = camera.global_position
		# On the ground, mid landing or takeoff, the plane stays parked
		# where it stands and the walker steps out beside it.
		var grounded: bool = landing != null and landing.on_ground()
		if grounded: _park_here()
		_end_flight()
		if grounded: _read_obstacles(true)
		_feet = _clamped(_free_spot(_clamped(editor.terrain.to_local(at))))
		_eye_y = _feet.y+EYE_HEIGHT
	active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = false
	figure.visible = true
	_sync_figure()
	if not bool(_before.looking): scene.select_brush(scene.brush)
	scene._auto_orbit = bool(_before.auto)
	# Re-express the eye as an orbit around a point ahead of it, then glide home.
	var reach := 6.0
	scene.target = eye-_offset(scene.yaw,scene.polar)*reach
	scene.distance = reach
	_returning = RETURN
	left.emit()

static func _offset(yaw: float, polar: float) -> Vector3:
	return Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))

func _eye_global() -> Vector3:
	return editor.terrain.to_global(Vector3(_feet.x,_eye_y,_feet.z)+_bob_offset)

# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if active: _advance_eye(delta)
	elif _returning > 0.0: _advance_return(delta)
	else: set_process(false)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)

func _advance_eye(delta: float) -> void:
	if not has_figure() or scene._menu.visible:
		leave()
		return
	if flying:
		_advance_flight(delta)
		return
	var want := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if want.length() > 1.0: want = want.normalized()
	want *= RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	_pace = _pace.lerp(want,_ease(EASE_PACE,delta))
	# Walk in the terrain's frame: the scene's yaw is in world space, and the
	# world may be turned under the camera.
	var heading := _yaw-_turn()
	var forward := -Vector3(sin(heading),0.0,cos(heading))
	var right := forward.cross(Vector3.UP)
	_read_obstacles(false)
	_read_depths()
	var move := right*_pace.x-forward*_pace.y
	# Wading slows the walk as the water deepens.
	move *= 1.0-WADE_SLOW*clampf(_depth(Vector2(_feet.x,_feet.z))/WADE,0.0,1.0)
	var was := _feet
	var walked := _walk(_feet,Vector2(move.x,move.z)*delta)
	if glide_enabled and _off_plate(Vector2(walked.x,walked.z)):
		_launch(move.length())
		return
	if _advance_jump(delta):
		_launch(move.length(),false)
		return
	if _board_asked:
		_board_asked = false
		_board()
		return
	_feet = _clamped(walked)
	var moved := Vector2(_feet.x-was.x,_feet.z-was.z).length()
	_notice_step(moved,delta)
	_footfall(moved,delta,right)
	_eye_y = lerpf(_eye_y,_feet.y+EYE_HEIGHT,_ease(EASE_HEIGHT,delta))
	# Never below the ground right under the eye.
	_eye_y = maxf(_eye_y,_feet.y+EYE_HEIGHT*0.6)
	# The jump rides on top, unsmoothed.
	_eye_y = maxf(_eye_y,_feet.y+EYE_HEIGHT+_hop) if _hop > 0.0 else _eye_y
	var reach := 6.0
	scene.yaw = _yaw
	scene.polar = _polar
	scene.target = _eye_global()-_offset(_yaw,_polar)*reach
	scene.distance = reach
	_swoop_in(delta)
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = lerpf(camera.fov,FOV,_ease(EASE_FOV,delta))
	# The figure keeps the eye's heading and place for when you step out.
	_sync_figure()
	_hint_time += delta
	_hint_plane()
	_hint.modulate.a = clampf(1.0-(_hint_time-4.0)/1.5,0.0,1.0)

## Just landed from the chase: the camera swoops from where it was down
## into the eyes.
func _swoop_in(delta: float) -> void:
	if _swoop <= 0.0: return
	_swoop = maxf(0.0,_swoop-delta)
	var k := smoothstep(0.0,1.0,1.0-_swoop/SWOOP)
	scene.target = (_swoop_from.target as Vector3).lerp(scene.target,k)
	scene.yaw = lerp_angle(float(_swoop_from.yaw),scene.yaw,k)
	scene.polar = lerpf(float(_swoop_from.polar),scene.polar,k)
	scene.distance = lerpf(float(_swoop_from.distance),scene.distance,k)

# --- The glide --------------------------------------------------------------------

## Off the edge: the plate is copied out into the sky and the glide takes the eye.
## Off an islet the sky is already out, and the glide leaves from its top.
func _launch(pace: float, drop := true, start := Vector3.INF, towards := 0.0) -> void:
	var from := _eye_global()
	var perched := not perch.is_empty()
	if perched:
		from = _perch_eye_global()
		_unperch()
	# There is only the one plane: flying from anywhere but it brings it along.
	if start == Vector3.INF: _unpark(true)
	flying = true
	_fly_look = Vector2.ZERO
	_skim_time = 0.0
	_hop = 0.0
	_hop_rise = 0.0
	_hop_held = -1.0
	# The sky stays as it was between glides.
	if not islands.built(): islands.build()
	if not perched: _far_before = camera.far
	camera.far = SkyWorld.VIEW_FAR if SkyWorld.ring_on() else FLY_FAR
	islands.show_air(true)
	if start != Vector3.INF:
		glide.launch(start,towards,pace,drop)
	else:
		glide.launch(from,_yaw,pace,drop)
		glide.pitch = clampf(_polar-PI*0.5,-0.6,0.3)
	_flap_asked = false
	_flaps_heard = 0
	_roll_asked = 0.0
	# The camera pulls back out of the eyes to chase.
	chase.reset(glide,from,camera.fov)
	vapour.reset()
	glider.visible = not chase.first_person
	glider.reset(glide)
	_swoop = 0.0
	if not perched:
		air.start()
		sky.start(glide.position)
	_hint.text = PLANE_HINT if plane else FLY_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	steps.step(_surface(),1.0)

func _end_flight() -> void:
	_unperch()
	flying = false
	landing = null
	_taking_off = false
	_landing_wait = false
	chase.cine = Vector3.ZERO
	scene.camera_roll = 0.0
	glider.visible = false
	if glider.has_method("show_pilot"): glider.show_pilot(true)
	camera.far = _far_before
	islands.show_air(false)
	sky.stop()
	air.stop()
	_hint.text = _walk_hint()

## The glide's input this frame: keys, the first gamepad and the mouse.
func _fly_input() -> Dictionary:
	var key := func(a: Key, b: Key) -> float: return float(Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b))
	var stick := Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
	if stick.length() < 0.15: stick = Vector2.ZERO
	var input := {
		"turn":clampf(key.call(KEY_D,KEY_RIGHT)-key.call(KEY_A,KEY_LEFT)+stick.x,-1.0,1.0),
		"pitch":clampf(key.call(KEY_S,KEY_DOWN)-key.call(KEY_W,KEY_UP)+stick.y,-1.0,1.0),
		"rise":maxf(float(Input.is_physical_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0,JOY_BUTTON_A)),Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT)),
		"dive":maxf(float(Input.is_physical_key_pressed(KEY_SHIFT)),Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT)),
		"look":_fly_look,
	}
	_fly_look = Vector2.ZERO
	var pad_flap := Input.is_joy_button_pressed(0,JOY_BUTTON_X)
	input["flap"] = _flap_asked or (pad_flap and not _pad_flap_was)
	_pad_flap_was = pad_flap
	_flap_asked = false
	# The right stick looks round the glider.
	var right := Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
	var stick_held := right.length() > 0.2
	if stick_held: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*get_process_delta_time())
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or stick_held
	if plane: _plane_input(input)
	return input

## The plane's own input over the glide's: Space or the pad's right trigger
## (or A) boosts and Shift or its left trigger brakes, in place of Rise and
## the dive; Q, E, a click or the pad's shoulders ask for a barrel roll.
func _plane_input(input: Dictionary) -> void:
	input["boost"] = maxf(float(Input.is_physical_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0,JOY_BUTTON_A)),Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT))
	input["brake"] = maxf(float(Input.is_physical_key_pressed(KEY_SHIFT)),Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT))
	input["rise"] = 0.0
	input["dive"] = 0.0
	input["flap"] = false
	var pad := Vector2(float(Input.is_joy_button_pressed(0,JOY_BUTTON_LEFT_SHOULDER)),float(Input.is_joy_button_pressed(0,JOY_BUTTON_RIGHT_SHOULDER)))
	if pad.x > _pad_roll_was.x: _roll_asked = -1.0
	if pad.y > _pad_roll_was.y: _roll_asked = 1.0
	_pad_roll_was = pad
	input["roll"] = _roll_asked
	_roll_asked = 0.0

func _advance_flight(delta: float) -> void:
	if not perch.is_empty():
		_advance_perch(delta)
		return
	if landing != null:
		_advance_sequence(delta)
		return
	var input := _fly_input()
	_read_obstacles(false)
	if glide.approach: glide.approach_target = _landing_spot()
	if _landing_wait: _wait_to_land(delta,input)
	glide.step(delta,input,_fly_ground,_fly_air)
	# Into another island's footprint, it becomes the plate.
	if not islands.claiming:
		var under: int = islands.copy_under(glide.position)
		if under >= 0: _claim(under)
	sky.advance(delta,glide.position,islands.in_cloud(glide.position,scene._motion_time))
	# Wandered off or fallen into the sea, an island turns up.
	islands.advance(delta,glide.position,glide.heading,sky.flight.w)
	vapour.step(delta,glide,_fly_ground)
	air.advance(delta,glide.velocity,glide.hang,float(input.dive),vapour.near,islands.towers.fade(glide.position))
	if plane: air.engine(glide.speed,(glide as SkyPlane).throttle)
	if glide.flaps != _flaps_heard:
		_flaps_heard = glide.flaps
		air.flap()
	chase.step(delta,glide,float(input.dive),_solid)
	_write_chase()
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = chase.fov
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)
	# Touching down slowly anywhere on the plate lands; on an islet's ground
	# (not its crowns or spire) it perches.
	var on_plate: bool = islands._height(glide.position) != null
	var islet: Dictionary = {} if on_plate else islands.islets.islet_at(glide.position)
	var on_islet := not islet.is_empty() and _islet_ground_near(islet,glide.position)
	var landable: bool = glide.speed < LAND_SPEED and float(input.dive) < 0.5 and (on_plate or on_islet)
	glider.update(delta,glide,float(input.dive),_fly_ground,landable,vapour.near,vapour.side)
	_skim_time = _skim_time+delta if glide.skimming and landable else 0.0
	if _skim_time >= LAND_TIME:
		if on_plate and plane: _roll_out()
		elif on_plate: _land()
		else: _perch(islet)

## Where F comes in to land: the middle of the nearest island's land within
## LANDING_REACH, or INF. An island's land need not sit in the middle of its
## plate, nor hold its own middle (scripts/island_frame.gd `middle`).
func _landing_spot() -> Vector3:
	var best := Vector3.INF
	var nearest := LANDING_REACH
	var middles: Array[Vector3] = [editor.terrain.global_position+_land_middle(editor.data)]
	for i in range(islands.offsets.size()): middles.append(editor.terrain.global_position+islands.offsets[i]+Vector3.DOWN*islands.sunk(i)+_land_middle(islands.lands[i]))
	for m in middles:
		var d := Vector2(m.x-glide.position.x,m.z-glide.position.z).length()
		if d < nearest:
			nearest = d
			best = m
	return best

## The offset of `land`'s middle from its plate's, level; none for a land
## still baking. Kept per land and outline: a ring search is not per frame.
func _land_middle(land: NativeTerrainData) -> Vector3:
	if land == null: return Vector3.ZERO
	var kept: Array = _middles.get(land.get_instance_id(),[])
	var bounds := land.land_rect()
	if kept.is_empty() or kept[0] != bounds:
		var at := IslandFrame.middle(land)
		kept = [bounds,Vector3(at.x,0.0,at.y)]
		if _middles.size() > 32: _middles.clear()
		_middles[land.get_instance_id()] = kept
	return kept[1]

## Claims an island (SkyIslands `claim`); once the plate is its land, the
## world has shifted, and everything that flies shifts with it.
func _claim(index: int) -> void:
	var shift: Vector3 = await islands.claim(index)
	if not flying or shift == Vector3.ZERO: return
	glide.position += shift
	sky.move(shift)
	glider.shift(shift)
	chase.eye += shift
	chase.look += shift

## The chase camera's pose, written into the scene's orbit.
func _write_chase() -> void:
	var out := chase.eye-chase.look
	var reach := maxf(out.length(),0.01)
	var dir := out/reach
	scene.target = chase.look
	scene.distance = reach
	scene.yaw = atan2(dir.x,dir.z)
	scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
	scene.camera_roll = chase.roll

## True inside an island's rock or ground, for the camera to keep out of.
func _solid(point: Vector3) -> bool:
	var body: Variant = _fly_ground(point)
	if body == null: return false
	var b := body as Vector2
	return point.y < b.x+0.3 and point.y > b.y-0.3

## Space (or the pad's A) jumps from the ground; held past OPEN_AFTER it
## opens the glide. Returns true when it should open.
func _advance_jump(delta: float) -> bool:
	var down := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0,JOY_BUTTON_A)
	var pressed := down and not _jump_was
	_jump_was = down
	# By the parked plane, Space climbs in rather than jumping.
	if pressed and _hop <= 0.0 and perch.is_empty() and by_plane():
		_board_asked = true
		return false
	if pressed and _hop <= 0.0:
		_hop_rise = JUMP
		_hop = 0.001
		_hop_held = 0.0
		steps.step(_surface(),0.3)
	if _hop <= 0.0: return false
	if _hop_held >= 0.0: _hop_held = _hop_held+delta if down else -1.0
	if glide_enabled and _hop_held >= OPEN_AFTER: return true
	_hop_rise -= GRAVITY*delta
	_hop += _hop_rise*delta
	if _hop <= 0.0:
		_hop = 0.0
		_hop_rise = 0.0
		_hop_held = -1.0
		steps.step(_surface(),0.5)
	return false

## What the glide stands on: the islands as solids, Vector2(top, underside)
## (SkyIslands `body`), and over the plate the crowns of its trees and rocks.
func _fly_ground(point: Vector3) -> Variant:
	var body: Variant = islands.body(point)
	if body == null or islands._height(point) == null: return body
	var local := editor.terrain.to_local(point)
	var at := Vector2(local.x,local.z)
	var top: float = (body as Vector2).x
	for c in _crowns:
		if at.distance_squared_to(Vector2(c.x,c.y)) < c.z*c.z:
			top = maxf(top,editor.terrain.to_global(Vector3(c.x,c.w,c.y)).y)
	return Vector2(top,(body as Vector2).y)

## The air the glide flies in: the sky's currents, and over the island the
## breeze rising up its slopes and the gust fronts rolling across it.
func _fly_air(point: Vector3) -> Dictionary:
	var air: Dictionary = islands.air(point)
	var atmosphere: Node = scene.get("_atmosphere")
	if atmosphere == null: return air
	var angle: float = atmosphere._air_angle
	var way := Vector2(cos(angle),sin(angle))
	var breeze: float = 1.6+1.9*float(atmosphere._air_strength)
	var extra := Vector3.ZERO
	var h: Variant = islands._height(point)
	if h != null and point.y > float(h)-1.0:
		var ahead: Variant = islands._height(point+Vector3(way.x,0.0,way.y)*RIDGE_STEP)
		var behind: Variant = islands._height(point-Vector3(way.x,0.0,way.y)*RIDGE_STEP)
		if ahead != null and behind != null:
			var slope := (float(ahead)-float(behind))/(2.0*RIDGE_STEP)
			var near := 1.0-smoothstep(RIDGE_REACH*0.3,RIDGE_REACH,point.y-float(h))
			extra.y += clampf(slope*breeze*RIDGE_GAIN,0.0,RIDGE_MAX)*near
	var lean: float = atmosphere.fronts.lean_at(Vector2(point.x,point.z),way)
	if lean > 0.0: extra += Vector3(way.x*GUST_PUSH,GUST_LIFT,way.y*GUST_PUSH)*lean
	air.wind = (air.get("wind",Vector3.ZERO) as Vector3)+extra
	air["island"] = extra
	return air

# --- Perched on an islet ------------------------------------------------------------

## True when a point over an islet is down near its ground, not riding over
## a crown or the spire.
func _islet_ground_near(islet: Dictionary, point: Vector3) -> bool:
	var local: Vector3 = point-islands.islets.place(islet)
	return local.y-float(islet.shape.ground_at(Vector2(local.x,local.z))) < SkyGlide.SKIM+0.5

## Touched down on an islet: the glide stops and the eye walks its top,
## still out in the sky. It is pinned so it is never let go while stood on.
func _perch(islet: Dictionary) -> void:
	_swoop = 0.0 if chase.first_person else SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	perch = islet
	islands.islets.pinned = islet.node
	var local: Vector3 = glide.position-islands.islets.place(islet)
	var at := _perch_free(islet.shape,Vector2(local.x,local.z))
	_perch_feet = Vector3(at.x,islet.shape.ground_at(at),at.y)
	_perch_eye = maxf(local.y-_perch_feet.y,EYE_HEIGHT*0.6)
	_yaw = glide.heading
	_polar = PI*0.5
	glider.visible = false
	scene.camera_roll = 0.0
	# It lands at a run that eases off.
	_pace = Vector2(0.0,-1.0)*RUN
	_steps = FIRST_STEP
	_bob = 0.0
	_bob_offset = Vector3.ZERO
	steps.step("grass",1.0)
	_hint.text = PERCH_HINT if plane else GLIDER_PERCH_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

func _unperch() -> void:
	if perch.is_empty(): return
	perch = {}
	if islands != null: islands.islets.pinned = null

## The nearest point to `at` (islet frame) a walker can stand on: inside,
## clear of trunks, the spire and the water.
func _perch_free(shape: RefCounted, at: Vector2) -> Vector2:
	if shape.share(at) > 0.92: at *= 0.92/shape.share(at)
	if not SkyIslets.blocked(shape,at): return at
	for ring in range(1,12):
		for k in range(12):
			var p := at+Vector2.from_angle(TAU*k/12.0)*ring*0.3
			if shape.share(p) <= 0.92 and not SkyIslets.blocked(shape,p): return p
	return at

func _perch_eye_global() -> Vector3:
	return islands.islets.place(perch)+_perch_feet+Vector3.UP*_perch_eye+_bob_offset

## Walking an islet's top as the plate's: the same keys and pace, round
## trunks and the pond; off the rim the glide opens, as off the plate's
## edge, and Space held opens it from a jump.
func _advance_perch(delta: float) -> void:
	var node: Node3D = perch.node
	if not is_instance_valid(node):
		_launch(1.0)
		return
	var shape: RefCounted = perch.shape
	var want := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if want.length() > 1.0: want = want.normalized()
	want *= RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	_pace = _pace.lerp(want,_ease(EASE_PACE,delta))
	# Islets are never turned, so the eye's yaw is the islet's frame's too.
	var forward := -Vector3(sin(_yaw),0.0,cos(_yaw))
	var right := forward.cross(Vector3.UP)
	var move := right*_pace.x-forward*_pace.y
	var was := Vector2(_perch_feet.x,_perch_feet.z)
	var step := Vector2(move.x,move.z)*delta
	var next := was+step
	if not shape.inside(next):
		_launch(move.length())
		return
	if _advance_jump(delta):
		_launch(move.length(),false)
		return
	# Round what blocks the way: slide along one axis or stand.
	if SkyIslets.blocked(shape,next):
		next = was+Vector2(step.x,0.0)
		if SkyIslets.blocked(shape,next) or not shape.inside(next): next = was+Vector2(0.0,step.y)
		if SkyIslets.blocked(shape,next) or not shape.inside(next): next = was
	_perch_feet = Vector3(next.x,shape.ground_at(next),next.y)
	var moved := next.distance_to(was)
	_footfall(moved,delta,right)
	_perch_eye = lerpf(_perch_eye,EYE_HEIGHT,_ease(EASE_HEIGHT,delta))
	_perch_eye = maxf(_perch_eye,EYE_HEIGHT+_hop) if _hop > 0.0 else _perch_eye
	var eye := _perch_eye_global()
	var reach := 6.0
	scene.yaw = _yaw
	scene.polar = _polar
	scene.target = eye-_offset(_yaw,_polar)*reach
	scene.distance = reach
	_swoop_in(delta)
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = lerpf(camera.fov,FOV,_ease(EASE_FOV,delta))
	# The sky goes on round it: the islets bob, the clouds drift, the wind
	# quietens.
	sky.advance(delta,eye,islands.in_cloud(eye,scene._motion_time))
	islands.advance(delta,eye,_yaw,sky.flight.w)
	air.advance(delta,Vector3.ZERO,0.0,0.0)
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)

## Down on the plate: back to walking where the glide touched.
func _land() -> void:
	var at := glide.position
	_swoop = 0.0 if chase.first_person else SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	_end_flight()
	_yaw = glide.heading
	_polar = PI*0.5
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(editor.terrain.to_local(at))))
	_eye_y = maxf(editor.terrain.to_local(at).y,_feet.y+EYE_HEIGHT*0.6)
	# It lands at a run that eases off.
	_pace = Vector2(0.0,-1.0)*RUN
	_steps = FIRST_STEP
	steps.step(_surface(),1.0)
	_disturb(PLACE_STRENGTH)
	_sync_figure()

## A stride walked, or a while stood: the life round it hears.
func _notice_step(moved: float, delta: float) -> void:
	_stride += moved
	_still = 0.0 if moved > 0.001 else _still+delta
	if _stride >= STRIDE:
		_stride = 0.0
		_disturb(clampf(_pace.length()/RUN,STILL_STRENGTH,1.0))
	elif _still >= STILL_PING:
		_still = 0.0
		_disturb(STILL_STRENGTH)

## The walk's rhythm: `moved` metres this frame count off steps, longer at a
## run; each whole one sounds a footfall. The eye sits lowest at a footfall
## and highest between, swaying toward each foot in turn along `right`.
func _footfall(moved: float, delta: float, right: Vector3) -> void:
	var speed := moved/maxf(delta,0.0001)
	var effort := clampf((speed-WALK)/(RUN-WALK),0.0,1.0)
	var before := _steps
	_steps += moved/lerpf(STEP_WALK,STEP_RUN,effort)
	if floorf(_steps) > floorf(before): steps.step(_surface(),effort)
	var depth := lerpf(BOB_WALK,BOB_RUN,effort)*clampf(speed/WALK,0.0,1.0)
	_bob = lerpf(_bob,depth,_ease(EASE_BOB,delta))
	var phase := _steps-floorf(_steps)
	_bob_offset = Vector3.UP*(-_bob*(0.5+0.5*cos(TAU*phase)))+right*(_bob*SWAY*sin(PI*_steps))

## What the feet are on (scripts/wanderer_steps.gd SURFACES), read as the
## terrain shades its faces (NativeTerrainData `rebuild_mesh`): a bridge's
## planks; water to wade; snow over the snowline; stone where the land is
## steeper than its rock slope or near the snowline; sand on an arid world's
## bare ground and on a bare shore; grass where cover grows (GRASSY); else
## bare earth, as a worn path is.
func _surface() -> String:
	if not perch.is_empty(): return "grass"
	return _surface_at(Vector2(_feet.x,_feet.z))

## What stands at plate point `at`, as `_surface`.
func _surface_at(at: Vector2) -> String:
	if not _deck(at).is_empty(): return "wood"
	if _depth(at) >= Footbridge.WET: return "water"
	var data: NativeTerrainData = editor.data
	var h: Variant = data.ground_height(at)
	if h == null: return "earth"
	var settings: Dictionary = data._recipe_settings
	var snowline: float = BiomeBlend.snowline(settings,data._palette.snowline)
	var drawn: Dictionary = Shape.BIOMES.get(settings.get("biome",""),{})
	var rock_slope: float = float(drawn.get("rock_slope",data._palette.rock_slope))
	var slope: float = Presets._slope(data,at)
	if float(h) > snowline and slope < 2.4: return "snow"
	if slope > rock_slope or float(h) > snowline-1.8: return "stone"
	var cover := data.ground_coverage(at)
	if cover >= GRASSY: return "grass"
	if settings.get("biome","") == "arid": return "sand"
	for d: Vector2 in [Vector2(SHORE,0.0),Vector2(-SHORE,0.0),Vector2(0.0,SHORE),Vector2(0.0,-SHORE)]:
		if _depth(at+d) >= Footbridge.WET: return "sand"
	return "earth"

func _disturb(strength: float) -> void:
	Disturbance.raise(editor.terrain.to_global(_feet),RADIUS,strength,"figure")

func _advance_return(delta: float) -> void:
	_returning = maxf(0.0,_returning-delta)
	var k := _ease(0.18,delta) if _returning > 0.0 else 1.0
	camera.fov = lerpf(camera.fov,_fov_before,k)
	if scene._orbiting or scene._panning:
		camera.fov = _fov_before
		_returning = 0.0
		return
	scene.target = scene.target.lerp(_before.target,k)
	scene.yaw = lerp_angle(scene.yaw,_before.yaw,k)
	scene.polar = lerpf(scene.polar,_before.polar,k)
	scene.distance = lerpf(scene.distance,_before.distance,k)


# --- The plane: landing, parked, taking off ---------------------------------------

func _walk_hint() -> String:
	if not plane: return GLIDER_HINT
	return BOARD_HINT if _near_plane else HINT

## Walking: the hint offers the takeoff by the parked plane.
func _hint_plane() -> void:
	var near := by_plane()
	if near == _near_plane: return
	_near_plane = near
	_hint.text = _walk_hint()
	if near:
		_hint_time = 0.0
		_hint.modulate.a = 1.0

func has_parked() -> bool:
	return parked != null and is_instance_valid(parked)

## True with the walker within BOARD_REACH of the parked plane, walking.
func by_plane() -> bool:
	if not plane or not has_parked() or flying or not perch.is_empty(): return false
	return Vector2(_feet.x,_feet.z).distance_to(_parked_at) <= BOARD_REACH

## F in the plane: lands; mid line-up, flies on; rolling out, hops out now.
func _land_key() -> void:
	if landing != null:
		if _taking_off: return
		if landing.can_cancel(): _fly_on()
		else: landing.skip()
		return
	if _landing_wait:
		_landing_wait = false
		_hint.text = PLANE_HINT
		return
	_landing_wait = true
	_hint.text = LANDING_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## Called off before the touch: back to flying from where it is.
func _fly_on() -> void:
	if landing == null or not landing.cancel(): return
	landing = null
	chase.cine = Vector3.ZERO
	_hint.text = PLANE_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## F pressed: the plane heads for the island to land on while it is
## claimed; once it is the plate, the strip is picked and the landing
## begins. Boost or a roll calls it off.
func _wait_to_land(delta: float, input: Dictionary) -> void:
	if float(input.get("boost",0.0)) > 0.0 or float(input.get("roll",0.0)) != 0.0:
		_landing_wait = false
		_hint.text = PLANE_HINT
		return
	# Turning towards it meanwhile, unless steered.
	glide.approach_target = _landing_spot()
	if glide.approach_target != Vector3.INF and is_zero_approx(float(input.get("turn",0.0))): glide.heading += glide._aim(delta)
	if islands.claiming: return
	var target := _landing_target()
	if target == -2:
		_landing_wait = false
		_hint.text = NO_LANDING_HINT
		_hint.modulate.a = 1.0
		_hint_time = 0.0
		return
	if target >= 0:
		# Claimed first, so the strip is read off the real land.
		if islands._rise[target] == Vector3.ZERO and islands.lands[target] != null: _claim(target)
		return
	# Under the island or below its land, it climbs out first, so the way
	# in never has to pass through its rock.
	var under: Variant = _fly_ground(glide.position)
	var middle: Variant = _fly_ground(glide.approach_target) if glide.approach_target != Vector3.INF else null
	var floor_y := maxf((under as Vector2).x if under != null else -INF,(middle as Vector2).x if middle != null else -INF)
	if glide.under_rock or glide.position.y < floor_y+2.0:
		if is_zero_approx(float(input.get("pitch",0.0))): input["pitch"] = 0.8
		return
	_begin_landing()

## Which island F lands on: -1 the plate, a copy's index, or -2 none
## within LANDING_REACH.
func _landing_target() -> int:
	var best := -2
	var nearest := LANDING_REACH
	var m := editor.terrain.global_position+_land_middle(editor.data)
	var d := Vector2(m.x-glide.position.x,m.z-glide.position.z).length()
	if d < nearest:
		nearest = d
		best = -1
	for i in range(islands.offsets.size()):
		m = editor.terrain.global_position+islands.offsets[i]+Vector3.DOWN*islands.sunk(i)+_land_middle(islands.lands[i])
		d = Vector2(m.x-glide.position.x,m.z-glide.position.z).length()
		if d < nearest:
			nearest = d
			best = i
	return best

## The plate's land as a strip survey (PlaneStrip `survey`): its heights,
## water and decks, and everything standing taller than the wings.
func _strip_map() -> Dictionary:
	_read_obstacles(true)
	_read_depths()
	var data: NativeTerrainData = editor.data
	var height := func(p: Vector2) -> Variant: return data.ground_height(p) if data.has_land(p) else null
	var wet := func(p: Vector2) -> bool: return _depth(p) > Footbridge.WET or not _deck(p).is_empty()
	return PlaneStrip.survey(data.land_rect(),height,wet,_strip_blockers())

## What stands taller than the wings on the plate: every placed thing's
## footprint above WING_LOW (trees, rocks, cabins, lamps, fences), and the
## walker's own obstacles but the parked plane.
func _strip_blockers() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(1 if has_parked() else 0,_obstacles.size()): out.append(_obstacles[i])
	var content: Node = editor.content
	if content == null: return out
	var to_plate: Transform3D = editor.terrain.global_transform.affine_inverse()
	for batch: MultiMeshInstance3D in content._batches:
		if not is_instance_valid(batch) or batch.multimesh == null or batch.multimesh.mesh == null: continue
		var profile := _profile(batch.multimesh.mesh)
		if profile.size() < 3: continue
		for source: Dictionary in content._sources.get(batch.get_meta("part"),[]):
			var item: Variant = source.get("item")
			if item == null: continue
			var placed: Variant = content._instance_transform(source)
			if placed == null: continue
			var at: Transform3D = to_plate*batch.global_transform*(placed as Transform3D)
			var ground := _ground(Vector3(float(item.x),at.origin.y,float(item.z)))
			var lift: float = at.basis.y.y
			var wide := maxf(at.basis.get_scale().x,at.basis.get_scale().z)
			var reach := 0.0
			for band in range(profile.size()-2):
				var high := at.origin.y+lift*(profile[0]+profile[1]*(band+1))
				if high > ground+WING_LOW: reach = maxf(reach,profile[band+2]*wide)
			if reach > 0.0: out.append(Vector3(at.origin.x,at.origin.z,reach))
	return out

## The wind's way over the plate (plate XZ), or none.
func _wind_way() -> Vector2:
	var atmosphere: Node = scene.get("_atmosphere")
	if atmosphere == null: return Vector2.ZERO
	var angle: float = atmosphere._air_angle
	var way := editor.terrain.global_basis.inverse()*Vector3(cos(angle),0.0,sin(angle))
	return Vector2(way.x,way.z)

## The ground's height under a global point's XZ, or NAN off the land.
func _floor_global(p: Vector2) -> float:
	var local := editor.terrain.to_local(Vector3(p.x,0.0,p.y))
	if not _on_land(Vector2(local.x,local.z)): return NAN
	return editor.terrain.to_global(Vector3(local.x,_ground(local),local.z)).y

## A strip in the plate's frame (PlaneStrip) made global.
func _strip_global(strip: Dictionary) -> Dictionary:
	var out := strip.duplicate()
	for key in ["touch","end"]:
		var at: Vector2 = strip[key]
		out[key] = editor.terrain.to_global(Vector3(at.x,_ground(Vector3(at.x,0.0,at.y)),at.y))
	var dir: Vector2 = strip.dir
	out.dir = (editor.terrain.global_basis*Vector3(dir.x,0.0,dir.y)).normalized()
	return out

## Picks the strip on the plate and starts the landing.
func _begin_landing() -> void:
	_landing_wait = false
	var map := _strip_map()
	var local := editor.terrain.to_local(glide.position)
	var way := editor.terrain.global_basis.inverse()*glide.forward()
	var strips := []
	for strip in PlaneStrip.candidates(map,_wind_way(),Vector2(local.x,local.z),Vector2(way.x,way.z)): strips.append(_strip_global(strip))
	var seq := PlaneLanding.new()
	var chosen: Dictionary = seq.choose(glide,strips,_fly_ground)
	seq.land(glide,chosen,_fly_ground,_floor_global)
	_start_sequence(seq,false)
	_hint.text = LANDING_HINT

func _start_sequence(seq: RefCounted, takeoff: bool) -> void:
	landing = seq
	_taking_off = takeoff
	_hop_to = Vector3.INF
	glide.approach = false

## A slow touch on the land without F: it rolls to a stop straight ahead,
## as far as the land is clear.
func _roll_out() -> void:
	var map := _strip_map()
	var local := editor.terrain.to_local(glide.position)
	var way3 := editor.terrain.global_basis.inverse()*glide.forward()
	var way := Vector2(way3.x,way3.z).normalized() if Vector2(way3.x,way3.z).length() > 0.01 else Vector2(0.0,-1.0)
	var at := Vector2(local.x,local.z)
	var ahead := PlaneStrip.clear_ahead(map,at,way,PlaneLanding.ROLL_LEN)
	var strip := _strip_global({"touch":at,"end":at+way*maxf(ahead,0.3),"dir":way,"length":maxf(ahead,0.3),"hop":true})
	var seq := PlaneLanding.new()
	seq.land(glide,strip,_fly_ground,_floor_global,true)
	_start_sequence(seq,false)
	_touchdown()
	_hint.text = ROLLING_HINT

## One frame of the landing or takeoff: the sequence flies the plane and
## the sky, the sound and the camera follow it.
func _advance_sequence(delta: float) -> void:
	var input := _fly_input()
	var seq := landing
	if seq.can_cancel() and (float(input.get("boost",0.0)) > 0.0 or float(input.get("roll",0.0)) != 0.0):
		# Flying on from the next frame; a roll asked for still rolls.
		_fly_on()
		_roll_asked = float(input.get("roll",0.0))
		return
	seq.step(delta)
	glide.engine = seq.engine
	if seq.touched: _touchdown()
	if not _taking_off and seq.phase == PlaneLanding.HOP_OUT and _hop_to == Vector3.INF: _begin_hop_out()
	if seq.phase in [PlaneLanding.HOP_OUT,PlaneLanding.BOARD]: _hop_figure(seq.hop)
	elif has_figure(): figure.visible = false
	if not _taking_off and seq.phase == PlaneLanding.TOUCHDOWN: _hint.text = ROLLING_HINT
	sky.advance(delta,glide.position,islands.in_cloud(glide.position,scene._motion_time))
	islands.advance(delta,glide.position,glide.heading,sky.flight.w)
	vapour.step(delta,glide,_fly_ground)
	air.advance(delta,glide.velocity,0.0,0.0,vapour.near,islands.towers.fade(glide.position))
	air.engine(glide.speed,seq.throttle,seq.engine)
	chase.cine = _framing(seq)
	chase.step(delta,glide,0.0,_solid)
	_write_chase()
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = chase.fov
	if not has_parked() or _taking_off: glider.update(delta,glide,0.0,_fly_ground,false,vapour.near,vapour.side)
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)
	if not seq.done(): return
	landing = null
	if _taking_off:
		_taking_off = false
		chase.cine = Vector3.ZERO
		glider.show_pilot(true)
		_hint.text = PLANE_HINT
		_hint.modulate.a = 1.0
		_hint_time = 0.0
	else:
		_land_beside_plane()

## How the camera frames each part: a little wider lining up, wider and to
## the left on final, round low to the left side for the touch and the hop
## out (the pilot climbs out on the left), and from there for the takeoff.
func _framing(seq: RefCounted) -> Vector3:
	match seq.phase:
		PlaneLanding.LINE_UP: return Vector3(0.0,0.0,0.25)
		PlaneLanding.DESCENT: return Vector3(-0.8,0.02,0.45)
		PlaneLanding.FLARE,PlaneLanding.TOUCHDOWN,PlaneLanding.ROLLOUT: return Vector3(-1.25,0.0,0.3)
		PlaneLanding.BEAT,PlaneLanding.HOP_OUT: return Vector3(-1.35,-0.04,0.3)
		PlaneLanding.BOARD,PlaneLanding.TAXI: return Vector3(-1.2,-0.04,0.3)
		PlaneLanding.ROLL: return Vector3(-0.9,0.0,0.3)
	return Vector3.ZERO

## The wheels touch: a puff of grass or dust, a thump, a blip of throttle,
## and the life round it startles.
func _touchdown() -> void:
	var local := editor.terrain.to_local(glide.position)
	var surface := _surface_at(Vector2(local.x,local.z))
	var ground := _floor_global(Vector2(glide.position.x,glide.position.z))
	var at := Vector3(glide.position.x,ground if not is_nan(ground) else glide.position.y-0.6,glide.position.z)
	_puff(at,surface)
	steps.step(surface,1.0)
	air.blip()
	Disturbance.raise(at,RADIUS*4.0,0.8,"figure")

## A soft puff at a global point: grass-green and pale on grass, warm dust
## on earth and sand, snow on snow, spray on water; a few soft balls that
## swell, drift up and fade.
func _puff(at: Vector3, surface: String) -> void:
	var tints := {"grass":Color("d6dcb4"),"snow":Color("f4f6f8"),"water":Color("e8f2f4"),"stone":Color("cfc8bc"),"wood":Color("d8c4a4")}
	var tint: Color = tints.get(surface,Color("d8c39c"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x*13.0+at.z*7.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	for i in range(7):
		var ball := MeshInstance3D.new()
		ball.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(tint,0.38)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ball.material_override = material
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ball.name = "PlanePuff"
		add_child(ball)
		var side := Vector3(rng.randf_range(-1.0,1.0),0.0,rng.randf_range(-1.0,1.0))
		ball.global_position = at+side*0.25+Vector3.UP*0.1
		ball.scale = Vector3.ONE*0.18
		var tween := ball.create_tween().set_parallel(true)
		tween.tween_property(ball,"scale",Vector3.ONE*rng.randf_range(0.55,0.9),1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ball,"global_position",ball.global_position+side*0.7+Vector3.UP*rng.randf_range(0.25,0.55),1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(material,"albedo_color:a",0.0,1.1).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(ball.queue_free)

## Stopped: the plane is parked where it stands, and the walker's hop out
## is worked out: to the plane's left, a little ahead, on free ground.
func _begin_hop_out() -> void:
	_park_here()
	glider.visible = false
	_read_obstacles(true)
	_read_depths()
	var local := editor.terrain.to_local(glide.position)
	var heading := _parked_heading
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var right := Vector3(cos(heading),0.0,-sin(heading))
	var spot := Vector3(local.x,0.0,local.z)-right*HOP_SIDE+forward*HOP_AHEAD
	_hop_to = _clamped(_free_spot(_clamped(spot)))
	_hop_from = Vector3(local.x,local.y+0.1,local.z)

## The walker mid-hop: `k` 0 in the cockpit, 1 on the ground beside it.
func _hop_figure(k: float) -> void:
	if not has_figure() or _hop_to == Vector3.INF: return
	figure.visible = k > 0.02 and k < 0.999
	var at := _hop_from.lerp(_hop_to,smoothstep(0.0,1.0,k))
	at.y += HOP_HEIGHT*sin(PI*k)
	figure.position = at
	var way := _hop_to-_hop_from
	figure.rotation = Vector3(0.0,atan2(-way.x,-way.z),0.0)

## Down beside the parked plane: walking, facing it, the camera swooping
## from the chase into the eyes.
func _land_beside_plane() -> void:
	if not has_parked(): _park_here()
	if _hop_to == Vector3.INF: _begin_hop_out()
	_swoop = 0.0 if chase.first_person else SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	_end_flight()
	_feet = _hop_to
	var to := Vector2(_parked_at.x-_feet.x,_parked_at.y-_feet.z)
	_yaw = atan2(-to.x,-to.y)+_turn()
	_polar = PI*0.5-0.18
	_eye_y = _feet.y+EYE_HEIGHT
	_pace = Vector2.ZERO
	_steps = FIRST_STEP
	_bob = 0.0
	_bob_offset = Vector3.ZERO
	figure.visible = false
	steps.step(_surface(),0.6)
	_disturb(PLACE_STRENGTH)
	_sync_figure()
	_near_plane = by_plane()
	_hint.text = _walk_hint()
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## Parks the plane where the flight stands now.
func _park_here() -> void:
	var local := editor.terrain.to_local(glide.position)
	_park(Vector2(local.x,local.z),glide.heading-_turn())

## Stands the plane parked at plate point `at`, facing `heading` (plate yaw).
func _park(at: Vector2, heading: float) -> void:
	if not has_parked():
		parked = PlaneFigure.new()
		parked.name = "ParkedPlane"
		editor.terrain.add_child(parked)
		if islands != null: islands.skip.append(parked)
	_parked_at = at
	_parked_heading = heading
	_seat_parked()
	_obstacle_key = []

## Sits the parked plane on its wheels and skid on the ground under it.
func _seat_parked() -> void:
	if not has_parked(): return
	var r := PlaneStrip.rest(func(p: Vector2) -> float: return _ground(Vector3(p.x,0.0,p.y)),_parked_at,_parked_heading)
	parked.park(PlaneFigure.pose(Vector3(_parked_at.x,r.x,_parked_at.y),_parked_heading,r.y,r.z))

## The parked plane goes: with `puff`, in a puff where it stood.
func _unpark(puff: bool) -> void:
	if not has_parked():
		parked = null
		return
	if puff and is_inside_tree(): _puff(parked.global_position,"grass")
	if islands != null: islands.skip.erase(parked)
	parked.queue_free()
	parked = null
	_obstacle_key = []

## Space by the parked plane: the pilot hops in, and it turns to its
## longest clear run, rolls, lifts and flies.
func _board() -> void:
	if not has_parked(): return
	var map := _strip_map()
	var heading := _parked_heading
	var run := PlaneStrip.takeoff(map,_parked_at,Vector2(-sin(heading),-cos(heading)),_wind_way())
	var r := PlaneStrip.rest(func(p: Vector2) -> float: return _ground(Vector3(p.x,0.0,p.y)),_parked_at,heading)
	var start := editor.terrain.to_global(Vector3(_parked_at.x,r.x,_parked_at.y))
	_hop_to = _feet
	_hop_from = Vector3(_parked_at.x,r.x+0.1,_parked_at.y)
	_unpark(false)
	_launch(0.0,false,start,heading+_turn())
	glide.pitch = r.y
	glide.bank = r.z
	glider.reset(glide)
	glider.show_pilot(false)
	var dir: Vector2 = run.dir
	var global_run := {"dir":(editor.terrain.global_basis*Vector3(dir.x,0.0,dir.y)).normalized(),"length":run.length,"edge":run.edge}
	var seq := PlaneLanding.new()
	seq.take_off(glide,global_run,_floor_global)
	# Hopping in from where the walker stood.
	var hop_to := _hop_to
	_start_sequence(seq,true)
	_hop_to = hop_to
	_hint.text = PLANE_HINT

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle(event): get_viewport().set_input_as_handled()

## The eye's input. Returns true when the event was used. V from the world
## is taken here too, so the hand scheme's key filter never sees it.
func handle(event: InputEvent) -> bool:
	if not active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V \
				and not (event.ctrl_pressed or event.meta_pressed or event.alt_pressed) and can_enter():
			summon(scene.get_viewport().get_mouse_position())
			return true
		return false
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not perch.is_empty():
			_yaw -= event.relative.x*LOOK
			_polar = clampf(_polar-event.relative.y*LOOK,POLAR.x,POLAR.y)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and flying and (chase.free_held or plane):
			chase.turn(Vector2(-event.relative.x,-event.relative.y)*LOOK)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and flying:
			_fly_look += Vector2(event.relative.x,-event.relative.y)*LOOK
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x*LOOK
			_polar = clampf(_polar-event.relative.y*LOOK,POLAR.x,POLAR.y)
		return true
	if event is InputEventMouseButton:
		# A click takes the mouse back if the window let it go.
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.button_index == MOUSE_BUTTON_RIGHT and flying: chase.free_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and flying and perch.is_empty() and plane:
			# A click rolls the way it is turning, or right flying straight.
			_roll_asked = -1.0 if glide.bank < -0.05 else 1.0
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and flying and perch.is_empty(): _flap_asked = true
		return true
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		return true
	if event is InputEventKey:
		if event.ctrl_pressed or event.meta_pressed: return false
		if event.pressed and not event.echo and event.keycode in [KEY_V,KEY_ESCAPE]:
			leave()
		elif event.pressed and not event.echo and event.keycode in [KEY_Q,KEY_E] and flying and perch.is_empty() and plane:
			_roll_asked = -1.0 if event.keycode == KEY_Q else 1.0
		elif event.pressed and not event.echo and event.keycode == KEY_E and flying and perch.is_empty():
			_flap_asked = true
		elif event.pressed and not event.echo and event.keycode == KEY_F and flying and perch.is_empty() and plane:
			_land_key()
		elif event.pressed and not event.echo and event.keycode == KEY_F and flying and perch.is_empty():
			glide.approach = not glide.approach
		elif event.pressed and not event.echo and event.keycode == KEY_C and flying and perch.is_empty():
			chase.first_person = not chase.first_person
			glider.visible = not chase.first_person
		# Walking keys are read each frame; every plain key stays here.
		return true
	return false

func _notification(what: int) -> void:
	# Stepping out of the window lets the mouse go.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
