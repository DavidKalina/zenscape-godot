extends Node
## A first test for a human who roams the chunk: a small figure stands on the
## land and the camera can step into its eyes. V with the pointer on the land
## sets the figure down there (or picks it up and moves it) and looks out
## through it; V with the pointer off the land steps into it where it stands.
## In its eyes the mouse is captured: move to look, WASD or the arrows walk,
## Shift runs. V or Esc steps back out, and the camera glides back to where it
## was; the figure stays where you walked it.
##
## Like photo mode (scripts/photo_mode.gd) this runs before the scene each
## frame (process_priority) and writes the pose into the scene's own orbit
## (target, yaw, polar, distance), so the fog, reflections and look pass read
## the same camera they always do. The figure is not saved with the place.

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
const Disturbance = preload("res://scripts/disturbance.gd")
const HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Shift to run  ·  V or Esc to step out"

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
	_hint.offset_left = -400.0
	_hint.offset_right = 400.0
	_layer.add_child(_hint)
	# A faint dot where the eye looks.
	_dot = Control.new()
	_dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void:
		_dot.draw_circle(_dot.size*0.5,2.5,Color(1,1,1,0.55),true,-1.0,true))
	_layer.add_child(_dot)

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

## Terrain height under a local point, or the point's own height off the map.
func _ground(local: Vector3) -> float:
	var h: Variant = editor.data.ground_height(Vector2(local.x,local.z))
	return float(h) if h != null else local.y

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

## Live water depth at a plate point, 0 without live water.
func _depth(point: Vector2) -> float:
	if _depths.is_empty(): return 0.0
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
	_pace = Vector2.ZERO
	_yaw = figure.rotation.y+_turn()
	_polar = PI*0.5
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(_feet)))
	_eye_y = _feet.y+EYE_HEIGHT
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
	active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = false
	figure.visible = true
	_sync_figure()
	if not bool(_before.looking): scene.select_brush(scene.brush)
	scene._auto_orbit = bool(_before.auto)
	# Re-express the eye as an orbit around a point ahead of it, then glide home.
	var reach := 6.0
	var eye := _eye_global()
	scene.target = eye-_offset(scene.yaw,scene.polar)*reach
	scene.distance = reach
	_returning = RETURN
	left.emit()

static func _offset(yaw: float, polar: float) -> Vector3:
	return Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))

func _eye_global() -> Vector3:
	return editor.terrain.to_global(Vector3(_feet.x,_eye_y,_feet.z))

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
	_feet = _clamped(_walk(_feet,Vector2(move.x,move.z)*delta))
	_notice_step(Vector2(_feet.x-was.x,_feet.z-was.z).length(),delta)
	_eye_y = lerpf(_eye_y,_feet.y+EYE_HEIGHT,_ease(EASE_HEIGHT,delta))
	# Never below the ground right under the eye.
	_eye_y = maxf(_eye_y,_feet.y+EYE_HEIGHT*0.6)
	var reach := 6.0
	scene.yaw = _yaw
	scene.polar = _polar
	scene.target = _eye_global()-_offset(_yaw,_polar)*reach
	scene.distance = reach
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = lerpf(camera.fov,FOV,_ease(EASE_FOV,delta))
	# The figure keeps the eye's heading and place for when you step out.
	_sync_figure()
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-4.0)/1.5,0.0,1.0)

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
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x*LOOK
			_polar = clampf(_polar-event.relative.y*LOOK,POLAR.x,POLAR.y)
		return true
	if event is InputEventMouseButton:
		# A click takes the mouse back if the window let it go.
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return true
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		return true
	if event is InputEventKey:
		if event.ctrl_pressed or event.meta_pressed: return false
		if event.pressed and not event.echo and event.keycode in [KEY_V,KEY_ESCAPE]:
			leave()
		# Walking keys are read each frame; every plain key stays here.
		return true
	return false

func _notification(what: int) -> void:
	# Stepping out of the window lets the mouse go.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
