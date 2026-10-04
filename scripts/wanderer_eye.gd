extends Node
## A first test for a human who roams the chunk: a small figure stands on the
## land and the camera can step into its eyes. V with the pointer on the land
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
## In the air the camera chases the glider from behind (scripts/glide_camera.gd)
## and the figure is drawn gliding under its cloth wing
## (scripts/glider_figure.gd). A click (or E, or the pad's X) flaps for
## lift of its own. C swaps to the old view from its eyes; the
## right mouse button (or the right stick) looks round it. The glide can dip
## under an island's slab. Near the
## ground a mark shows where it would touch down, and touching down slowly
## anywhere on the island lands, the camera swooping down into its eyes.

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
const PLATE_REACH := 13.5
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
const HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Shift to run  ·  Space to jump, hold to glide  ·  V or Esc to step out"
const PERCH_HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Walk off the edge or hold Space to glide  ·  V or Esc to step out"
const FLY_HINT := "Mouse or A D to turn  ·  W S to pitch  ·  Click or E to flap  ·  Space to rise  ·  Shift to dive  ·  Right mouse to look round  ·  C for the camera  ·  V or Esc to step out"
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const GlideAir = preload("res://scripts/glide_air.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const GliderFigure = preload("res://scripts/glider_figure.gd")
const GlideVapour = preload("res://scripts/glide_vapour.gd")
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
## What the copies were last built from, so a glide opened again from the
## same island keeps the sky as it was.
var _built_key := []
## Tree and rock crowns in the plate plane: (x, z, radius, top), terrain-local.
var _crowns := PackedVector4Array()
## Footprint profile of a mesh: [y0, band height, radius per band...].
static var _profiles := {}

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
	steps = WandererSteps.new()
	add_child(steps)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	_hint = Label.new()
	_hint.text = HINT
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
		islands = SkyIslands.new()
		islands.setup(scene)
		add_child(islands)
		# A mountain's rock is ridden only where it is no steeper than the
		# glide can ride (SkyGlide `stone`).
		glide.stone = Callable(islands.peaks,"solid")
		sky = SkyFlight.new()
		add_child(sky)
		sky.setup(scene)
		air = GlideAir.new()
		add_child(air)
		islands.skip.append(air)
		glider = GliderFigure.new()
		glider.visible = false
		add_child(glider)
		islands.skip.append(glider)

# --- The figure -------------------------------------------------------------------

## A plain little person: a capsule body, a head and a pale face side so its
## heading reads from the orbit.
func _build_figure() -> void:
	figure = Node3D.new()
	figure.name = "Wanderer"
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("c8643b")
	cloth.roughness = 0.85
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("e8c39e")
	skin.roughness = 0.7
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.14
	capsule.height = FIGURE_HEIGHT*0.78
	capsule.radial_segments = 12
	capsule.rings = 4
	body.mesh = capsule
	body.material_override = cloth
	body.position.y = capsule.height*0.5
	figure.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.material_override = skin
	head.position.y = FIGURE_HEIGHT-0.1
	figure.add_child(head)
	# A nose, so which way it faces reads from above.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04,0.04,0.06)
	nose.mesh = box
	nose.material_override = skin
	nose.position = Vector3(0.0,FIGURE_HEIGHT-0.1,-0.11)
	figure.add_child(nose)
	editor.terrain.add_child(figure)
	if islands != null: islands.skip.append(figure)

func _world_restored(state: Dictionary) -> void:
	if state.is_empty(): forget()

## The figure is gone, stepped out of first if the eye is in it; V sets a
## new one down.
func forget() -> void:
	if active: leave()
	if has_figure(): figure.queue_free()
	figure = null
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
	var key := [editor.data.objects_revision,batches.size()]
	for batch in batches: key.append(batch.get_instance_id())
	if not force and key == _obstacle_key: return
	_obstacle_key = key
	_obstacles = PackedVector3Array()
	_crowns = PackedVector4Array()
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
	return absf(p.x) <= PLATE_REACH and absf(p.y) <= PLATE_REACH and not _blocked(p)

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
		_end_flight()
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
	if glide_enabled and (absf(walked.x) > PLATE_REACH or absf(walked.z) > PLATE_REACH):
		_launch(move.length())
		return
	if _advance_jump(delta):
		_launch(move.length(),false)
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
func _launch(pace: float, drop := true) -> void:
	var from := _eye_global()
	var perched := not perch.is_empty()
	if perched:
		from = _perch_eye_global()
		_unperch()
	flying = true
	_fly_look = Vector2.ZERO
	_skim_time = 0.0
	_hop = 0.0
	_hop_rise = 0.0
	_hop_held = -1.0
	# The sky stays as it was unless the island has changed since.
	var key := [editor.data.objects_revision,hash(editor.data.heights)]
	if not islands.built() or key != _built_key:
		islands.build()
		_built_key = key
	if not perched: _far_before = camera.far
	camera.far = FLY_FAR
	islands.show_air(true)
	glide.launch(from,_yaw,pace,drop)
	glide.pitch = clampf(_polar-PI*0.5,-0.6,0.3)
	_flap_asked = false
	_flaps_heard = 0
	# The camera pulls back out of the eyes to chase.
	chase.reset(glide,from,camera.fov)
	vapour.reset()
	glider.visible = not chase.first_person
	glider.reset(glide)
	_swoop = 0.0
	if not perched:
		air.start()
		sky.start(glide.position)
	_hint.text = FLY_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	steps.step(_surface(),1.0)

func _end_flight() -> void:
	_unperch()
	flying = false
	scene.camera_roll = 0.0
	glider.visible = false
	camera.far = _far_before
	islands.show_air(false)
	sky.stop()
	air.stop()
	_hint.text = HINT

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
	return input

func _advance_flight(delta: float) -> void:
	if not perch.is_empty():
		_advance_perch(delta)
		return
	var input := _fly_input()
	_read_obstacles(false)
	glide.step(delta,input,_fly_ground,_fly_air)
	sky.advance(delta,glide.position,islands.clouds.inside(glide.position,scene._motion_time))
	# Wandered off or fallen into the sea, an island turns up.
	islands.advance(delta,glide.position,glide.heading,sky.flight.w)
	vapour.step(delta,glide,_fly_ground)
	air.advance(delta,glide.velocity,glide.hang,float(input.dive),vapour.near)
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
		if on_plate: _land()
		else: _perch(islet)

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
	_hint.text = PERCH_HINT
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
	sky.advance(delta,eye,islands.clouds.inside(eye,scene._motion_time))
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
	var at := Vector2(_feet.x,_feet.z)
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
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and flying and chase.free_held:
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
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and flying and perch.is_empty(): _flap_asked = true
		return true
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		return true
	if event is InputEventKey:
		if event.ctrl_pressed or event.meta_pressed: return false
		if event.pressed and not event.echo and event.keycode in [KEY_V,KEY_ESCAPE]:
			leave()
		elif event.pressed and not event.echo and event.keycode == KEY_E and flying and perch.is_empty():
			_flap_asked = true
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
