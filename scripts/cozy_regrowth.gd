extends Node
## Cozy prototype: reverse the source growth channels, regenerate in place,
## then replay them forward. One native world; the camera and Bigfoot stay put.
## In scenery mode there is no Bigfoot to carry: regrow folds and replays the
## land directly.
const Generator = preload("res://scripts/cozy_world_generator.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const Presets = preload("res://scripts/native_landscape_presets.gd")
## The best-scoring seeds per landform family (tools/probe_world_beauty.gd),
## plus a few weathers. Step through them with [ and ] to check look changes.
const SHOWCASE := [184,105,147,193,303,79,328,301,176,33,102,353,58,177,198,134,45,309,248,250,278,364]
const DEGROW_SECONDS := 3.4
const GROW_SECONDS := 5.0
## The plain's day (creation mode only). Its world clock turns at a gentle
## PLAIN_DAY_LENGTH real seconds per 24 hours (the default day is 480 s), so
## dawn and dusk come round within a session and the deer can find the dawn.
## Night hides the land, so the plain eases through it (celestial phases
## PLAIN_NIGHT.x -> PLAIN_NIGHT.y) in a few seconds, like pressing N. Both ends
## sit just outside life's DAWN and DUSK windows (scripts/life_moments.gd).
## The day length doubles as the marker: a saved plain keeps its clock, and a
## plain whose day length is anything else was saved before the plain turned.
const PLAIN_DAY_LENGTH := 1200.0
const PLAIN_NIGHT := Vector2(0.8,0.2)
var scene: Node3D
var primary: Node3D
var initialized := false
var busy := false
var holding := false
var pressed := false
var press_at := Vector2.ZERO
var last_mouse := Vector2.ZERO
var origin_feet := Vector3.ZERO
var old_paused := false
var armed := true
var edge_time := 0.0
var pending_drop := false
var phase := "ready"
var generation := 0
## The seed the current landscape grew from; -1 for saved or preset places.
var world_seed := -1
var showcase_index := -1
var generated_world := {}
var previous_look := {}
var next_look := {}
var previous_hour := 0.0
var next_hour := 0.0
var previous_distance := 40.0
var next_distance := 40.0
var slots: Array = []
var active := 0
var regrow_button: Button
var cover := CanvasLayer.new()
var badge := Label.new()
var carry_view := SubViewport.new()
var carry_actor := CreatureActor.new()
var carry_image := TextureRect.new()
var carry_offset := Vector2.ZERO
var marker := MeshInstance3D.new()
var marker_mat := StandardMaterial3D.new()
var landing: Variant = null
var pool_revision := -1
var pool_depth := 0.0
## True while the current world is a Genesis plain (scripts/genesis_canvas.gd).
var plain := false

## Launch into the Genesis plain unless asked for the old start: --generated
## (or --seed N) opens the saved place or the valley as before, --resume opens
## the last saved place.
static func launch_choice() -> String:
	var args := OS.get_cmdline_user_args()
	if "--resume" in args: return "resume"
	if "--generated" in args or "--seed" in args: return "generated"
	return "plain"

func setup(owner_scene: Node3D) -> void:
	primary = owner_scene
	scene = primary
	busy = true
	process_priority = 100
	DirAccess.make_dir_recursive_absolute(scene.library_path)
	var choice := launch_choice()
	var saved := _read_saved()
	if choice == "plain" and not saved.is_empty():
		# The plain replaces the saved place on the next save; keep one copy.
		DirAccess.copy_absolute(primary.places_path,primary.places_path.get_basename()+"-previous.json")
	scene._paused = true
	if choice == "plain":
		scene.restore_cave_state({})
		var plain_seed := _plain_seed()
		generated_world = Genesis.world(plain_seed)
		await Genesis.form(scene._chunk_editor,generated_world,false)
		scene._chunk_editor.data._undo.clear()
		scene._chunk_editor.data._redo.clear()
		Genesis.apply_mood(scene,generated_world)
		world_seed = plain_seed
		plain = true
		_sync_plain_day(true)
		slots = [{}]
		active = 0
		saved = {}
	elif saved.is_empty():
		scene.restore_cave_state({})
		await scene._chunk_editor.form_landscape("valley","",true)
		scene._refresh_habitat()
		scene.invite_bigfoot(Vector3(0,0,5))
		slots = [{}]
	else:
		# Retain earlier prototype places on disk, but only load the chosen one.
		slots = saved.slots
		active = int(saved.active)
		scene._chunk_editor.data.load_document(slots[active].document)
		await scene._chunk_editor.refresh(get_tree())
		NativeGardenStore.restore(scene,slots[active].state)
		scene._refresh_habitat()
		plain = scene._chunk_editor.data.blank and scene._chunk_editor.data._recipe_settings.is_empty()
		_sync_plain_day(false)
	scene.position = Vector3.ZERO
	if saved.get("layout","")!="regrowth": scene._frame_diorama()
	scene._chunk_editor.save_path = scene.library_path.path_join("Current.json")
	scene.set_building(false)
	_set_growth(1.0)
	scene._paused = false
	scene.resident_enabled = not _scenery()
	_build_overlay()
	initialized = true
	busy = false
	_update_badge()
	scene._notice.text = "Regrow for a new landscape, or press Build to shape this one." if _scenery() else "Regrow this landscape, or carry Bigfoot to an edge to discover a new place."
	if plain: scene._notice.text = "Drag across the plain to raise land. Shift or right drag lowers it."
	if world_seed >= 0: scene._chunk_editor.land_seed = world_seed
	var args := OS.get_cmdline_user_args()
	var at := args.find("--seed")
	if at >= 0 and at+1 < args.size() and args[at+1].is_valid_int(): regrow.call_deferred(int(args[at+1]))

## Regrow the next or previous showcase seed.
func step_showcase(direction: int) -> void:
	if busy: return
	showcase_index = posmod(showcase_index+direction,SHOWCASE.size())
	regrow(SHOWCASE[showcase_index])

## A random seed whose landform family differs from the current one. The
## family is the first genome draw, so this stays cheap and the seed alone
## reproduces the world.
func _fresh_seed() -> int:
	var current: String = scene._chunk_editor.data._recipe_settings.get("composition",scene._chunk_editor.data._recipe_settings.get("family",""))
	for attempt in range(32):
		var candidate := randi() % 1000000
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		if preload("res://scripts/inland_genome.gd").sample(rng.randi_range(0,999999)).composition != current: return candidate
	return randi() % 1000000

func _plain_seed() -> int:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--plain-seed")
	if at >= 0 and at+1 < args.size() and args[at+1].is_valid_int(): return int(args[at+1])
	return randi() % 1000000

func _scenery() -> bool:
	return bool(scene.get("scenery_mode"))

## Turn the plain's day (PLAIN_DAY_LENGTH) when a plain opens in creation mode,
## and put other worlds back on the default day; their moods hold the hour.
## `fresh` is a new plain; a loaded one keeps the clock it was saved with,
## unless it was saved before the plain turned.
func _sync_plain_day(fresh: bool) -> void:
	var clock: WorldClock = scene.get("world_clock")
	if clock == null: return
	var marked := is_equal_approx(clock.day_length,PLAIN_DAY_LENGTH)
	if not (plain and bool(scene.get("creation_mode"))):
		if marked: clock.day_length = WorldClock.DEFAULT_DAY_LENGTH
		return
	if marked and not fresh: return
	clock.day_length = PLAIN_DAY_LENGTH
	clock.running = true

## The plain eases through the night to the edge of dawn. Keyed on the clock's
## day length rather than `plain`, since an undo past a regrow restores the
## old world's clock without telling this node.
func _pass_plain_night() -> void:
	var clock: WorldClock = scene.get("world_clock")
	if clock == null or not clock.running or clock.target_hour >= 0.0 or not is_equal_approx(clock.day_length,PLAIN_DAY_LENGTH): return
	# The margin keeps a skip that lands a hair short of dawn from firing again.
	if clock.phase > PLAIN_NIGHT.x or clock.phase < PLAIN_NIGHT.y-0.01:
		clock.skip_to(WorldClock.hour_for_phase(PLAIN_NIGHT.y))

func _build_overlay() -> void:
	cover.layer = 60
	add_child(cover)
	cover.add_child(badge)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(18,18)
	badge.add_theme_font_override("font",preload("res://assets/fonts/Nunito.ttf"))
	badge.add_theme_font_size_override("font_size",15)
	badge.add_theme_color_override("font_color",Color("fff1d5"))
	badge.add_theme_color_override("font_shadow_color",Color("182628"))
	badge.add_theme_constant_override("shadow_offset_y",2)
	regrow_button = scene._button(scene._toolbar,"Regrow landscape",regrow)
	preload("res://scripts/tactile_editor_style.gd").button(regrow_button)
	regrow_button.tooltip_text = "Fold this landscape away and discover a different landscape. Undo restores the old terrain."
	carry_view.size = Vector2i(320,400)
	carry_view.transparent_bg = true
	carry_view.own_world_3d = true
	carry_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(carry_view)
	var rig := Node3D.new()
	carry_view.add_child(rig)
	rig.add_child(carry_actor)
	carry_actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	carry_actor.set_process(false)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	for mesh: MeshInstance3D in carry_actor.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = material
	var eye := Camera3D.new()
	rig.add_child(eye)
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = 3.5
	eye.position = Vector3(0,1.55,8)
	eye.look_at(Vector3(0,1.55,0))
	for source: DirectionalLight3D in scene._lights:
		var light := DirectionalLight3D.new()
		light.transform = source.transform
		light.light_color = source.light_color
		light.light_energy = source.light_energy
		rig.add_child(light)
	cover.add_child(carry_image)
	carry_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carry_image.texture = carry_view.get_texture()
	carry_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carry_image.hide()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.59
	marker.mesh = ring
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Color("b3e699")
	marker.material_override = marker_mat
	add_child(marker)
	marker.hide()

func _label(world: Node3D) -> String:
	var recipe: Dictionary = world._chunk_editor.data._recipe_settings
	if plain and recipe.is_empty(): return "Open plain"+(" · "+Genesis.palette_title(generated_world) if generated_world.has("palette") else "")
	if recipe.get("kind")=="inland":
		return preload("res://scripts/biome_blend.gd").title(recipe)+" · "+recipe.composition.replace("-"," ").capitalize()+(" · seed %d" % world_seed if world_seed>=0 else "")
	var family: String = world._chunk_editor.data._recipe_settings.get("family","")
	return Presets.PRESETS[family].title if Presets.PRESETS.has(family) else "Your clearing"

## The badge adds a second line with living weather: the season and the sky.
func _badge_text() -> String:
	var living: RefCounted = scene.get("living_weather")
	return _label(scene)+("\n"+living.label() if living != null else "")

func _update_badge() -> void:
	badge.text = _badge_text()

func blocks(point: Vector2) -> bool:
	return busy or badge.get_global_rect().has_point(point)

func handle(event: InputEvent) -> bool:
	if not initialized: return true
	if _scenery(): return busy
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and holding:
		cancel_carry()
		return true
	if event is InputEventMouseMotion:
		last_mouse = event.position
		if pressed and not holding and event.position.distance_to(press_at)>=5:
			begin_carry()
			return true
		if holding or busy: return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		last_mouse = event.position
		if not event.pressed and (pressed or holding):
			pressed = false
			if holding: drop_at(event.position)
			else: scene.creature.notice(scene.camera.global_position)
			return true
		if event.pressed and not busy and scene._resident_play.pick(event.position):
			pressed = true
			press_at = event.position
			return true
	return holding or busy

func begin_carry() -> void:
	if busy or holding: return
	origin_feet = scene.creature._safe_position
	old_paused = scene._paused
	scene._chunk_editor.finish_stroke()
	scene.world_play.cancel()
	scene.routine.cancel("carried through the landscape")
	scene.environment_life.cancel()
	if scene.foliage_tread != null: scene.foliage_tread.clear()
	scene._resident_play.cancel()
	holding = true
	scene._paused = true
	scene.resident_enabled = false
	scene.creature.hide()
	carry_actor.reset_at(Vector3.ZERO)
	carry_actor.pick_up()
	carry_actor.rotation.y = scene.creature.rotation.y-scene.yaw
	var feet: Vector2 = scene.camera.unproject_position(origin_feet)
	var head: Vector2 = scene.camera.unproject_position(origin_feet+Vector3.UP*3)
	var height := clampf(feet.distance_to(head)*1.25,90,250)
	carry_image.size = Vector2(height*0.8,height)
	carry_offset = Vector2(height*0.4,height*0.16)
	carry_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	carry_image.show()
	armed = true
	edge_time = 0.0
	pending_drop = false
	scene._notice.text = "Hold near an edge to grow a new landscape. Release to set him down."

func _process(delta: float) -> void:
	if not initialized: return
	regrow_button.disabled = busy or scene._chunk_editor.forming
	if holding:
		carry_actor.advance(minf(delta,0.05))
		carry_image.position = (last_mouse-carry_offset).clamp(Vector2.ZERO,scene.get_viewport().get_visible_rect().size-carry_image.size)
	if busy: return
	_pass_plain_night()
	if badge.text!=_badge_text(): _update_badge()
	if not holding: return
	_update_landing(last_mouse)
	var size: Vector2 = scene.get_viewport().get_visible_rect().size
	var x := last_mouse.x/size.x
	var inside := Rect2(Vector2.ZERO,size).has_point(last_mouse)
	var edge := inside and (x<0.08 or x>0.92)
	if not edge:
		edge_time = 0
		if inside and x>0.18 and x<0.82: armed = true
	elif armed:
		edge_time += minf(delta,0.05)
		if edge_time>=0.45:
			armed = false
			regrow()

## Fold this world away and lay down a fresh Genesis plain in its place.
func new_plain(requested_seed := -1) -> void:
	await regrow(requested_seed,true)

func regrow(requested_seed := -1, to_plain := false) -> void:
	if busy or not initialized or scene._chunk_editor.forming: return
	var before_state := NativeGardenStore.capture(scene)
	if holding:
		before_state.scene._paused = old_paused
		before_state.diorama.resident = true
		before_state.diorama.position = [origin_feet.x,origin_feet.y,origin_feet.z]
	previous_look = scene._celestial.look.document()
	previous_hour = scene._celestial.phase
	previous_distance = scene.distance
	next_look = {}
	if _scenery():
		old_paused = scene._paused
		scene._chunk_editor.finish_stroke()
		scene.world_play.cancel()
		scene._paused = true
	elif not holding:
		last_mouse = scene.camera.unproject_position(scene.creature.global_position+Vector3.UP*2.0)
		begin_carry()
		pending_drop = true
	busy = true
	armed = false
	marker.hide()
	if scene.has_method("suspend_creation"): scene.suspend_creation()
	else: scene.set_building(false)
	scene._growth.reset_feedback()
	phase = "reversing"
	scene._notice.text = "Letting this landscape settle back to earth…"
	await _animate_growth(false,DEGROW_SECONDS)
	phase = "regenerating"
	if to_plain:
		var plain_seed := randi() % 1000000 if requested_seed<0 else requested_seed
		generated_world = Genesis.world(plain_seed)
		world_seed = plain_seed
		scene._notice.text = "Laying down a quiet plain…"
		await Genesis.form(scene._chunk_editor,generated_world,true)
	else:
		var chosen := _fresh_seed() if requested_seed<0 else requested_seed
		generated_world = await Generator.sample_async(chosen,{},get_tree())
		world_seed = chosen
		scene._notice.text = "Shaping a new wilderness…"
		await scene._chunk_editor.form_inland(generated_world.terrain,true,false)
	plain = to_plain
	scene._chunk_editor.land_seed = world_seed
	# form_inland captures its snapshot while the old world is folded down.
	# Undo must instead restore the complete, playable scene before the reveal.
	if not scene._chunk_editor.data._undo.is_empty():
		scene._chunk_editor.data._undo.back()["favorite_scene"] = before_state
	# Publication, atmosphere, framing and navigation each get a fresh frame.
	await get_tree().process_frame
	Generator.apply_mood(scene,generated_world)
	_sync_plain_day(true)
	next_look = scene._celestial.look.document()
	next_hour = scene._celestial.phase
	_set_growth(0.0)
	await get_tree().process_frame
	next_distance = await _fit_distance(get_tree())
	_set_growth(0.0)
	# Navigation is prepared before Bigfoot can be released onto the new ground.
	# Scenery mode has nobody to walk it; the habitat rebuilds lazily if he returns.
	await get_tree().process_frame
	if not _scenery():
		var nav_workers: int = scene.navigation.thread_workers
		# Two snapshots leave room for rendering; four copies cost a frame by
		# themselves on dense forests. Poll and merge within the native 2 ms budget.
		scene.navigation.thread_workers = 2
		scene._refresh_habitat(true)
		while scene.navigation.rebuilding:
			await get_tree().process_frame
			scene._refresh_habitat(true)
		scene.navigation.thread_workers = nav_workers
		await get_tree().process_frame
	scene._growth.reset_feedback()
	phase = "growing"
	scene._notice.text = "A new little wilderness, growing…" if _scenery() else "A new little wilderness, growing around him…"
	await _animate_growth(true,GROW_SECONDS)
	generation += 1
	phase = "ready"
	busy = false
	_update_badge()
	if scene.has_method("resume_creation"): scene.resume_creation()
	if _scenery():
		scene._paused = old_paused
		scene._notice.text = "Drag across the plain to raise land. Shift or right drag lowers it." if plain else ""
		return
	# The original pickup ground no longer exists after regeneration.
	var safe: Variant = scene.navigation.nearest_safe(origin_feet)
	if safe!=null: origin_feet = safe
	if pending_drop:
		pending_drop = false
		drop_at(last_mouse)
	else:
		scene._notice.text = "Set him down wherever feels like home."

func _fit_distance(frame_tree: SceneTree = null) -> float:
	# Fit the fully grown plant meshes too: redwoods can tower above the land.
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	var points := PackedVector3Array()
	var nodes: Array = [scene._chunk_editor.terrain,scene._chunk_editor._skirt]
	nodes.append_array(scene._chunk_editor.content.get_children())
	nodes.append_array(scene._chunk_editor.landmarks.find_children("*","MeshInstance3D",true,false))
	for node in nodes:
		if node is MultiMeshInstance3D and node.multimesh!=null:
			var box: AABB = node.multimesh.mesh.get_aabb()
			for i in range(node.multimesh.instance_count):
				var pose: Transform3D = node.global_transform*node.multimesh.get_instance_transform(i)
				for corner in range(8): points.append(pose*box.get_endpoint(corner))
				if i%64==63: await budget.checkpoint()
		elif node is MeshInstance3D and node.mesh!=null:
			var box: AABB = node.mesh.get_aabb()
			for corner in range(8): points.append(node.to_global(box.get_endpoint(corner)))
	scene._update_camera()
	var size: Vector2 = scene.get_viewport().get_visible_rect().size
	var vertical: float = tan(deg_to_rad(scene.camera.fov)*0.5)
	var horizontal := vertical*size.x/maxf(size.y,1.0)
	var distance := 30.0
	for endpoint in points:
		var point: Vector3 = endpoint-scene.target
		var depth: float = point.dot(scene.camera.basis.z)
		distance = maxf(distance,depth+absf(point.dot(scene.camera.basis.x))*1.16/horizontal)
		distance = maxf(distance,depth+absf(point.dot(scene.camera.basis.y))*1.16/vertical)
		await budget.checkpoint()
	return distance

func _animate_growth(forward: bool, duration: float) -> void:
	var elapsed := 0.0
	while elapsed<duration:
		await get_tree().process_frame
		var step := minf(get_process_delta_time(),0.05)
		elapsed = minf(duration,elapsed+step)
		var progress := elapsed/duration
		var before: float = scene._growth.terrain
		_set_growth(progress if forward else 1.0-progress)
		scene._growth.formation_feedback(absf(scene._growth.terrain-before),step,scene._tremor)
	_set_growth(1.0 if forward else 0.0)

func _set_growth(progress: float) -> void:
	# Same terrain delays, water fronts and plant overshoot as Electron. The
	# compact overlapping timeline replaces its journal-driven target pacing.
	if phase in ["regenerating","growing"] and not next_look.is_empty():
		var blend := smoothstep(0.0,0.85,progress)
		var look: SceneLook = scene._celestial.look
		for key in look.colors:
			var a: Array = previous_look.colors[key]
			var b: Array = next_look.colors[key]
			look.colors[key] = Color(a[0],a[1],a[2]).lerp(Color(b[0],b[1],b[2]),blend)
		for key in look.settings: look.settings[key] = lerpf(previous_look.settings[key],next_look.settings[key],blend)
		look.publish()
		scene._celestial.set_phase(fposmod(lerp_angle(previous_hour*TAU,next_hour*TAU,blend)/TAU,1.0))
		scene.distance = lerpf(previous_distance,next_distance,blend)
	scene._growth.replaying = false
	scene._growth.terrain = smoothstep(0.0,0.48,progress)
	scene._growth.water = smoothstep(0.46,0.76,progress)
	scene._growth.foliage = smoothstep(0.62,1.0,progress)
	scene._growth.publish()
	scene._chunk_editor.sync_visibility()
	# Native placed rocks/deadwood need the same arrival gate as source props.
	for material: ShaderMaterial in scene._chunk_editor.content._materials.values():
		material.set_shader_parameter("cozy_prop_growth",true)
	scene._chunk_editor.landmarks.visible = scene._growth.foliage>0.01
	var content: GardenView = scene._chunk_editor.content
	if pool_revision!=content.revision:
		pool_revision = content.revision
		pool_depth = 0.0
		if content._water.mesh!=null:
			var uv: PackedVector2Array = content._water.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			for value in uv: pool_depth = maxf(pool_depth,value.x)
	var fill := smoothstep(0.2,0.85,scene._growth.water)
	content._water.position.y = -pool_depth*(1.0-fill)
	content._water_material.set_shader_parameter("level_drop",pool_depth*(1.0-fill))
	content._water.visible = scene._growth.terrain>=0.995 and fill>0.001


func _update_landing(mouse: Vector2) -> void:
	landing = null
	marker.hide()
	if not holding or busy: return
	var terrain: MeshInstance3D = scene._chunk_editor.terrain
	var ray := terrain.to_local(scene.camera.project_ray_origin(mouse))
	var vector: Vector3 = terrain.global_basis.inverse()*scene.camera.project_ray_normal(mouse)
	var hit: Variant = scene._chunk_editor.data.ray_hit(ray,vector.normalized())
	if hit==null: return
	landing = scene.navigation.nearest_safe(terrain.to_global(hit))
	if landing!=null:
		marker.position = landing+Vector3.UP*0.08
		marker.show()

func drop_at(mouse: Vector2) -> void:
	if not holding: return
	if busy:
		pending_drop = true
		return
	# The carry portrait has no world position. Project its release onto the
	# original bank's plane so a missing triangle remains a deliberate drop.
	if scene._chunk_editor.pointer_in_world(mouse) and not scene._chunk_editor.data.void_faces.is_empty():
		var hit: Variant = Plane(Vector3.UP,origin_feet.y).intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
		if hit is Vector3:
			var p := Vector2(hit.x,hit.z)
			var data: NativeTerrainData = scene._chunk_editor.data
			if data.is_void(p):
				var support: Variant = scene.navigation._ground(hit)
				if support == null and not scene.navigation.rebuilding and scene.nearest_safe_bank(hit) != null:
					_end_hold()
					scene.creature.reset_at(hit+Vector3.UP*0.9)
					if scene.try_void_fall(true): return
				elif support != null and scene.navigation.is_safe(support):
					_end_hold()
					scene.creature.reset_at(support)
					return
	_update_landing(mouse)
	if landing==null: landing = scene.navigation.nearest_safe(origin_feet)
	if landing==null: cancel_carry(); return
	var point: Vector3 = landing
	_end_hold()
	scene.creature.reset_at(point)
	scene.creature.pick_up()
	scene.creature.position = point+Vector3.UP*0.9
	scene.creature.release_at(point)
	scene.environment_life.welcome_arrival()
	scene._notice.text = "A little place to linger."

func cancel_carry() -> void:
	if not holding: return
	if busy:
		pending_drop = true
		return
	_end_hold()
	var safe: Variant = scene.navigation.nearest_safe(origin_feet)
	if safe!=null: scene.creature.reset_at(safe)
	scene._notice.text = "Back on solid ground."

func _end_hold() -> void:
	holding = false
	pressed = false
	carry_image.hide()
	marker.hide()
	carry_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	scene.resident_enabled = true
	scene.creature.show()
	scene._paused = old_paused
	scene.brain.reset_behavior()

func save_places() -> bool:
	if busy or holding or not initialized: return false
	scene._chunk_editor.finish_stroke()
	scene.flush_world_play()
	var state := NativeGardenStore.capture(scene)
	state.scene._paused = false
	state.diorama.resident = not _scenery()
	slots[active] = {"label":_label(scene),"document":scene._chunk_editor.data.to_document(),"state":state}
	var temporary: String = primary.places_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"version":1,"layout":"regrowth","active":active,"slots":slots},"",true,true))
	file.flush()
	var result := file.get_error()
	file.close()
	return result==OK and DirAccess.rename_absolute(temporary,primary.places_path)==OK

## The place a plain launch set aside before the plain replaced it.
func previous_path() -> String:
	return primary.places_path.get_basename()+"-previous.json"

func has_previous() -> bool:
	return FileAccess.file_exists(previous_path())

## Swap this place with the one set aside: this place is saved and set aside in
## turn, so choosing it again swaps back. Undo history starts over.
func resume_previous() -> bool:
	if busy or holding or not initialized or scene._chunk_editor.forming: return false
	var previous := _read_saved(previous_path())
	if previous.is_empty():
		scene._notice.text = "There is no earlier place to return to."
		return false
	if not save_places() or DirAccess.copy_absolute(primary.places_path,previous_path()) != OK:
		scene._notice.text = "Could not set this place aside. It is still open."
		return false
	busy = true
	if scene.has_method("suspend_creation"): scene.suspend_creation()
	else: scene.set_building(false)
	slots = previous.slots
	active = int(previous.active)
	scene._chunk_editor.data.load_document(slots[active].document)
	scene._chunk_editor.data._undo.clear()
	scene._chunk_editor.data._redo.clear()
	await scene._chunk_editor.refresh(get_tree())
	NativeGardenStore.restore(scene,slots[active].state)
	scene._refresh_habitat()
	plain = scene._chunk_editor.data.blank and scene._chunk_editor.data._recipe_settings.is_empty()
	_sync_plain_day(false)
	generated_world = {}
	world_seed = -1
	_set_growth(1.0)
	busy = false
	_update_badge()
	if scene.has_method("resume_creation"): scene.resume_creation()
	save_places()
	scene._notice.text = "Back to "+_label(scene)
	return true

func _read_saved(path := "") -> Dictionary:
	var source: String = primary.places_path if path.is_empty() else path
	if not FileAccess.file_exists(source): return {}
	var file := FileAccess.open(source,FileAccess.READ)
	if file==null or file.get_length()>40000000: return {}
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary or saved.get("version")!=1 or not saved.get("slots") is Array: return {}
	if saved.slots.size() not in [1,2,3] or not GardenData._integer(saved.get("active")) or int(saved.active)<0 or int(saved.active)>=saved.slots.size(): return {}
	for slot in saved.slots:
		if not slot is Dictionary or not slot.get("document") is Dictionary or not NativeGardenStore.valid(primary,slot.get("state")): return {}
		var data := NativeTerrainData.new()
		data.setup(primary._chunk_editor.data.source_mesh)
		if not data.load_document(slot.document): return {}
	return saved
