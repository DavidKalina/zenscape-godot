extends Node3D
## Remote charges belong to the shared editor, so every native landscape can
## place, bury, save and detonate them. One salvo is one ordinary undo step.
const Blast = preload("res://scripts/terrain_blast.gd")
const InternalBlast = preload("res://scripts/internal_blast.gd")
const Collapse = preload("res://scripts/mountain_collapse.gd")
const MAX_BODIES := 100
const SOLIDS := ["tree","layered_tree","redwood","broadleaf","snag","bigfoot_tree","rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4"]
var editor: NativeChunkEditor
var effects = preload("res://scripts/explosion_effects.gd").new()
var collisions := NativePlayCollisions.new()
var bodies: Array[RigidBody3D] = []
var requested := false
var firing := false
var _staging := false
var _blast_generation := 0
var target_id := -1
var rng := RandomNumberGenerator.new()
var remote := PanelContainer.new()
var charge_list := OptionButton.new()
var detonate_button := Button.new()
var restore_button := Button.new()
var cover := CheckButton.new()
var radius_slider := HSlider.new()
var radius_label := Label.new()
var _revision := -1
var _syncing := false
var _elapsed := 0.0
var collapse_count := 0
var _resident_before: Variant = null
## Last detonation stage costs, in microseconds; instrumentation only.
var last_stage_usec := {}
var phase := "idle"

func setup(target: NativeChunkEditor) -> void:
	editor = target
	add_child(effects)
	add_child(collisions)
	editor.play_geometry_changed.connect(_geometry_changed)
	editor.formation_started.connect(clear_effects)
	editor.setting_changed.connect(func(_property: String,_value: float) -> void: _sync_settings())
	editor.tool_changed.connect(func(_tool: String) -> void: _sync_settings())
	editor.selection_changed.connect(func(id: int) -> void:
		var item := editor.data.object_by_id(id)
		if not item.is_empty() and item.asset == "explosive":
			target_id = id
			_sync_list())
	_build_remote()

func charges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in editor.data.objects:
		if item.asset == "explosive": result.append(item)
	return result

func _build_remote() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	layer.add_child(remote)
	remote.name = "ExplosiveRemote"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202a27ed")
	style.set_corner_radius_all(12)
	for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(edge,14)
	remote.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	remote.add_child(column)
	var title := Label.new()
	title.text = "EXPLOSIVE REMOTE"
	title.add_theme_font_size_override("font_size",14)
	column.add_child(title)
	charge_list.custom_minimum_size.x = 235
	charge_list.item_selected.connect(func(index: int) -> void:
		# Remote targeting is independent of the visible object's editor card.
		# Clear that selection so a later refresh cannot retarget this control.
		editor.select_object(-1)
		target_id = charge_list.get_item_id(index)
		_sync_settings())
	column.add_child(charge_list)
	column.add_child(radius_label)
	radius_slider.min_value = 1.0
	radius_slider.max_value = 6.0
	radius_slider.step = 0.1
	radius_slider.value_changed.connect(_radius_changed)
	column.add_child(radius_slider)
	cover.text = "Hide under leaves"
	cover.toggled.connect(_cover_changed)
	column.add_child(cover)
	detonate_button.name = "DetonateRemote"
	detonate_button.text = "Detonate all  ·  X"
	detonate_button.pressed.connect(request_detonation)
	detonate_button.focus_mode = Control.FOCUS_NONE
	column.add_child(detonate_button)
	restore_button.name = "RestoreBeforeBlast"
	restore_button.text = "Undo last blast"
	restore_button.pressed.connect(func() -> void:
		if can_restore(): editor.undo())
	restore_button.focus_mode = Control.FOCUS_NONE
	column.add_child(restore_button)
	_sync_list()

func _sync_list() -> void:
	charge_list.clear()
	var planted := charges()
	charge_list.add_item("All charges (%d)" % planted.size(),0)
	var selected := 0
	for item in planted:
		var point := editor.data.object_position(item)
		var buried: bool = editor.data.ground_height(Vector2(point.x,point.z)) > point.y + 0.2 * item.scale
		var in_tunnel := false
		for tunnel in editor.data.tunnels:
			if not tunnel.sealed and preload("res://scripts/native_tunnels.gd").inside(tunnel,point): in_tunnel = true
		charge_list.add_item("Charge %d · %s" % [item.id,"in tunnel" if in_tunnel else "buried" if buried else "leaves" if item.leaf_cover else "exposed"],item.id)
		if item.id == target_id: selected = charge_list.item_count-1
	charge_list.select(selected)
	if selected == 0: target_id = 0
	_revision = editor.data.objects_revision
	_sync_settings()

func _sync_settings() -> void:
	_syncing = true
	var item := editor.data.object_by_id(target_id)
	var single: bool = not item.is_empty() and item.asset == "explosive"
	radius_slider.set_value_no_signal(item.blast_radius if single else editor.blast_radius)
	cover.set_pressed_no_signal(item.leaf_cover if single else editor.explosive_leaf_cover)
	radius_label.text = "%s radius · %.1f m" % ["Charge" if single else "New charge",radius_slider.value]
	detonate_button.text = "Detonate charge  ·  X" if single else "Detonate all  ·  X"
	var show_settings: bool = single or editor.active and editor.mode == "explosive"
	radius_label.visible = show_settings
	radius_slider.visible = show_settings
	cover.visible = show_settings
	remote.reset_size()
	_syncing = false

func _radius_changed(value: float) -> void:
	if _syncing: return
	if target_id > 0:
		editor.finish_stroke()
		editor.data.begin_stroke()
		editor.data.update_object(target_id,{"blast_radius":value})
		editor.data.end_stroke()
	else: editor.set_setting("blast_radius",value)
	_sync_settings()

func _cover_changed(value: bool) -> void:
	if _syncing: return
	if target_id > 0:
		editor.finish_stroke()
		editor.data.begin_stroke()
		editor.data.update_object(target_id,{"leaf_cover":value})
		editor.data.end_stroke()
		editor.refresh()
	else: editor.explosive_leaf_cover = value

func _blocked() -> bool:
	if editor.forming or editor.scene._paused: return true
	var menu: Variant = editor.scene.get("_menu")
	return menu != null and menu.visible

func _process(_delta: float) -> void:
	if editor == null: return
	if _revision != editor.data.objects_revision: _sync_list()
	remote.visible = not _blocked() and (charge_list.item_count > 1 or editor.mode == "explosive" and editor.active or can_restore())
	detonate_button.disabled = charge_list.item_count <= 1
	restore_button.disabled = not can_restore()
	var screen := get_viewport().get_visible_rect().size
	remote.position = Vector2(20,screen.y-remote.size.y-84)

func contains(point: Vector2) -> bool:
	return remote.visible and remote.get_global_rect().has_point(point)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
		if _blocked() or get_viewport().gui_get_focus_owner() is LineEdit: return
		request_detonation()
		get_viewport().set_input_as_handled()

func request_detonation() -> void:
	if not _blocked(): requested = true

func can_restore() -> bool:
	return not editor.data._undo.is_empty() and editor.data._undo.back().get("explosion",false)

func _geometry_changed() -> void:
	if not firing: clear_effects()
	_sync_list()

func clear_effects() -> void:
	_blast_generation += 1
	if _resident_before is Vector3 and editor != null:
		editor.scene.creature.reset_at(_resident_before)
	_resident_before = null
	requested = false
	collapse_count = 0
	for body in bodies:
		body.collision_layer = 0
		body.collision_mask = 0
		body.queue_free()
	bodies.clear()
	for child in collisions.get_children():
		if child is CollisionObject3D: child.collision_layer = 0
		child.queue_free()
	effects.clear()

func _physics_process(delta: float) -> void:
	if editor == null: return
	if requested:
		requested = false
		if not _blocked() and not firing: detonate(true)
	if not _blocked(): _elapsed += delta
	for i in range(bodies.size()-1,-1,-1):
		var body := bodies[i]
		if body.position.y < -50 or _elapsed > 18:
			body.collision_layer = 0
			body.collision_mask = 0
			body.queue_free()
			bodies.remove_at(i)
		else:
			var waiting: bool = _elapsed < float(body.get_meta("release_at",0.0))
			body.freeze = _blocked() or waiting
			if not _staging and body.collision_layer == 0:
				body.collision_layer = 4
				body.collision_mask = 1
			if not body.freeze and body.has_meta("blast_impulse"):
				var impulse: Array = body.get_meta("blast_impulse")
				body.apply_central_impulse(impulse[0])
				body.apply_torque_impulse(impulse[1])
				body.remove_meta("blast_impulse")
			if not body.freeze and body.has_meta("collapse_velocity"):
				body.linear_velocity = body.get_meta("collapse_velocity")
				body.angular_velocity = Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))
				body.remove_meta("collapse_velocity")
				effects.emit_rockfall(body.global_position,0.8)

func detonate(live := false) -> void:
	if firing or editor.forming: return
	var frame_tree: SceneTree = get_tree() if live else null
	phase = "preparation"
	last_stage_usec.clear()
	var stage_start := Time.get_ticks_usec()
	var salvo: Array[Dictionary] = []
	for item in charges():
		if target_id <= 0 or item.id == target_id: salvo.append(item.duplicate(true))
	if salvo.is_empty(): return
	editor.finish_stroke()
	if editor.scene.has_method("flush_world_play"): editor.scene.flush_world_play()
	clear_effects()
	firing = true
	_staging = live
	_elapsed = 0.0
	var generation := _blast_generation
	var target_data := editor.data
	editor.forming = true
	# Legacy scenery becomes ordinary records before taking visible mesh copies.
	editor.data.begin_stroke()
	if preload("res://scripts/world_reference_props.gd").migrate(editor): editor.refresh()
	editor.reactions.finish_all()
	last_stage_usec["preparation"] = Time.get_ticks_usec()-stage_start
	phase = "affected"
	stage_start = Time.get_ticks_usec()
	var affected := {}
	var origins: Array[Vector3] = []
	var resident := editor.scene.get("creature") as CreatureActor
	var resident_enabled: bool = resident != null and editor.scene.get("resident_enabled") == true
	var resident_kick := Vector3.ZERO
	for charge in salvo:
		var local := editor.data.object_position(charge)
		var origin := editor.terrain.to_global(local)
		origins.append(origin)
		if live: effects.emit_blast(origin,charge.blast_radius)
		if resident_enabled:
			resident_kick += Blast.impulse(origin,resident.global_position+Vector3.UP*0.9,charge.blast_radius)*0.8
		for item in editor.data.objects:
			if item.asset == "explosive" or item.asset == "waterfall": continue
			var world := editor.terrain.to_global(editor.data.object_position(item))
			var kick := Blast.impulse(origin,world,charge.blast_radius)
			if kick.length_squared() > 0.01:
				affected[item.id] = {"item":item.duplicate(true),"kick":kick + affected.get(item.id,{}).get("kick",Vector3.ZERO)}
	# Reuse the visible terrain colors instead of rebuilding a temporary crater mesh.
	var surface_colors: PackedColorArray = editor.data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	last_stage_usec["affected_and_colors"] = Time.get_ticks_usec()-stage_start
	phase = "worker"
	stage_start = Time.get_ticks_usec()
	var preparation = preload("res://scripts/native_blast_preparation.gd")
	var detached: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_queries(editor.data,true)
	var job = preload("res://scripts/background_work.gd").new()
	var prepared: Dictionary = await job.run(preparation.build.bind(detached,salvo.duplicate(true),surface_colors.duplicate()),frame_tree)
	if _aborted(generation,target_data): return
	var collapses: Array[Dictionary] = prepared.collapses
	editor.data.heights = prepared.heights
	editor.data.grass = prepared.grass
	editor.data.meadow = prepared.meadow
	editor.data.blades = prepared.blades
	editor.data.tint = prepared.tint
	for charge in salvo: editor.data.remove_object(charge.id)
	last_stage_usec["carve_and_collapse"] = Time.get_ticks_usec()-stage_start
	phase = "capture"
	stage_start = Time.get_ticks_usec()
	var publication_budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	# Scenery farther downhill joins the slide if its supporting ground moved,
	# even when it was outside the direct explosion's impulse radius.
	for collapse in collapses:
		for item in editor.data.objects:
			if item.asset in ["explosive","waterfall"] or affected.has(item.id): continue
			var point := Vector2(item.x,item.z)
			if absf(Collapse.displacement(editor.data,collapse,point)) < 0.18: continue
			var downhill := Collapse._gradient(editor.data,collapse.before,point)
			var kick := Vector3(-downhill.x,0.2,-downhill.y).normalized()*5.0
			if collapse.get("internal",false):
				var world := Vector3(point.x,float(editor.data.sample(point,collapse.before)),point.y)
				kick = ((world-collapse.origin).normalized()+Vector3.UP*0.25).normalized()*collapse.radius*2.5
			affected[item.id] = {"item":item.duplicate(true),"kick":kick}
	for collapse in collapses:
		if not collapse.get("internal",false) or not resident_enabled: continue
		var feet: Vector3 = editor.terrain.to_local(resident.global_position)
		if Collapse.displacement(editor.data,collapse,Vector2(feet.x,feet.z))<0.18: continue
		var surface: Variant = editor.data.sample(Vector2(feet.x,feet.z),collapse.before)
		if surface == null or absf(feet.y-surface)>2.0: continue
		var kick: Vector3 = ((feet-collapse.origin).normalized()+Vector3.UP*0.25).normalized()*collapse.radius*2.5
		if kick.length()>resident_kick.length(): resident_kick = editor.terrain.global_basis*kick
	# The live instance transforms still describe the unbroken mountainside.
	var parts := _capture_parts(affected)
	last_stage_usec["capture"] = Time.get_ticks_usec()-stage_start
	await publication_budget.checkpoint()
	if _aborted(generation,target_data): return
	phase = "launch"
	stage_start = Time.get_ticks_usec()
	_publish_chunk_resources(collapses)
	await publication_budget.checkpoint()
	if _aborted(generation,target_data): return
	for collapse in collapses:
		await _launch_collapse(collapse,frame_tree,generation)
		if _aborted(generation,target_data): return
	var launch_order := affected.keys()
	# Preserve the big readable silhouettes when a dense flower patch exceeds
	# the debris budget; small plants still disappear into the dust.
	launch_order.sort_custom(func(a: int,b: int) -> bool: return int(affected[a].item.asset in SOLIDS) > int(affected[b].item.asset in SOLIDS))
	var launch_budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	for id in launch_order:
		if not parts.has(id) or bodies.size() >= MAX_BODIES: continue
		var began := Time.get_ticks_usec()
		_launch_parts(parts[id],affected[id].kick)
		bodies.back().set_meta("visual_source","landmarks" if affected[id].item.asset in NativeGardenLandmarks.KINDS else "content")
		last_stage_usec["props_cpu"] = last_stage_usec.get("props_cpu",0)+Time.get_ticks_usec()-began
		if frame_tree != null: await launch_budget.checkpoint()
		if _aborted(generation,target_data): return
	for i in range(salvo.size()):
		var charge := salvo[i]
		if not live: effects.emit_blast(origins[i],charge.blast_radius)
		_eject_dirt(origins[i],charge.blast_radius)
	last_stage_usec["launch"] = Time.get_ticks_usec()-stage_start
	phase = "refresh"
	stage_start = Time.get_ticks_usec()
	for id in affected: editor.data.remove_object(id)
	editor.data.end_stroke()
	editor.data._undo.back()["explosion"] = true
	# A rejected stage has not published its matching visuals/maps. Keep all
	# bodies staged until a complete refresh succeeds or this blast is aborted.
	while not await editor.refresh(frame_tree,_publish_staged.bind(generation,target_data)):
		if _aborted(generation,target_data): return
		if frame_tree != null: await frame_tree.process_frame
		if _aborted(generation,target_data): return
	if _aborted(generation,target_data): return
	last_stage_usec["refresh"] = Time.get_ticks_usec()-stage_start
	await publication_budget.checkpoint()
	if _aborted(generation,target_data): return
	phase = "collision"
	stage_start = Time.get_ticks_usec()
	var world_play: Variant = editor.scene.get("world_play")
	if world_play != null:
		# The resident and thrown props share these colliders. Refresh them now,
		# before debris can encounter the pre-blast ground on the next tick.
		world_play.ensure_collision()
	else:
		collisions.rebuild(editor.data)
		collisions.global_transform = editor.terrain.global_transform
	last_stage_usec["collision"] = Time.get_ticks_usec()-stage_start
	await publication_budget.checkpoint()
	if _aborted(generation,target_data): return
	if resident_kick.length() > 0.1:
		var before := resident.global_position
		if resident.receive_blast(resident_kick): _resident_before = before
	for collapse in collapses:
		if collapse.get("internal",false):
			# Surface breakouts make the buried blast visible around the cap.
			for i in range(mini(8,collapse.chunks.size())):
				effects.emit_rockfall(editor.terrain.to_global(collapse.chunks[i].center),1.2)
	# Dirt has no former visual source; reveal it at transaction completion.
	for body in bodies: body.visible = true
	phase = "finish"
	stage_start = Time.get_ticks_usec()
	_elapsed = 0.0
	firing = false
	_staging = false
	editor.forming = false
	phase = "idle"
	collapse_count = collapses.size()
	_sync_list()
	editor._set_status(("Mountain collapse · " if collapse_count > 0 else "Detonated %d charge(s) · " % salvo.size())+"Undo last blast restores the landscape.")
	last_stage_usec["finish"] = Time.get_ticks_usec()-stage_start

func _aborted(generation: int, target_data: NativeTerrainData) -> bool:
	if generation == _blast_generation and editor.data == target_data: return false
	# Jobs are joined before this check. Close the original stroke, but never
	# apply old terrain, meshes or physics bodies to a cleared/replaced world.
	target_data.end_stroke()
	firing = false
	_staging = false
	phase = "idle"
	editor.forming = false
	return true

## Upload together and feed retained CPU vertices to the original hull cleaner.
## No freshly uploaded mesh is read back. At most 48 chunks publish here.
func _publish_chunk_resources(collapses: Array[Dictionary]) -> void:
	var began := Time.get_ticks_usec()
	var chunks: Array[Dictionary] = []
	for collapse in collapses:
		for chunk: Dictionary in collapse.chunks:
			if chunks.size() >= 48: break
			if not chunk.has("arrays"): continue
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,chunk.arrays,[],{},0)
			chunk.mesh = mesh
			chunks.append(chunk)
	var uploaded := Time.get_ticks_usec()
	var max_hull_usec := 0
	for chunk in chunks:
		var hull_began := Time.get_ticks_usec()
		chunk.shape = preload("res://scripts/native_chunk_hull.gd").build(chunk.arrays[Mesh.ARRAY_VERTEX])
		chunk.erase("arrays")
		max_hull_usec = maxi(max_hull_usec,Time.get_ticks_usec()-hull_began)
	last_stage_usec.chunk_upload = uploaded-began
	last_stage_usec.chunk_hulls = Time.get_ticks_usec()-uploaded
	last_stage_usec.chunk_hull_max = max_hull_usec
	last_stage_usec.chunk_resources = Time.get_ticks_usec()-began

func _launch_collapse(collapse: Dictionary, frame_tree: SceneTree = null, generation := -1) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("palette_role",3)
	material.set_shader_parameter("wet_ground",true)
	var launch_budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	for chunk: Dictionary in collapse.chunks:
		# Reserve some of the common budget for trees, scenery and blast dirt.
		if bodies.size() >= 48 or generation != -1 and generation != _blast_generation: return
		var began := Time.get_ticks_usec()
		var transform: Transform3D = editor.terrain.global_transform*Transform3D(Basis.IDENTITY,chunk.center)
		_launch_parts([{"mesh":chunk.mesh,"material":material,"transform":transform}],Vector3.ZERO)
		var body: RigidBody3D = bodies.back()
		body.set_meta("mountain_chunk",true)
		body.set_meta("visual_source","terrain")
		body.set_meta("internal_blast",collapse.get("internal",false))
		body.set_meta("release_at",chunk.delay)
		body.set_meta("collapse_velocity",editor.terrain.global_basis*chunk.velocity)
		body.freeze = true
		var collider := body.get_child(body.get_child_count()-1) as CollisionShape3D
		collider.shape = chunk.shape if chunk.has("shape") else chunk.mesh.create_convex_shape(true,false)
		collider.global_transform = transform
		var physics := PhysicsMaterial.new()
		physics.friction = 0.7
		physics.bounce = 0.12
		body.physics_material_override = physics
		last_stage_usec["chunks_cpu"] = last_stage_usec.get("chunks_cpu",0)+Time.get_ticks_usec()-began
		if frame_tree != null: await launch_budget.checkpoint()

func _capture_parts(affected: Dictionary) -> Dictionary:
	var result := {}
	for batch in editor.content._batches:
		var sources: Array = editor.content._sources.get(batch.get_meta("part"),[])
		for i in range(sources.size()):
			var item: Variant = sources[i].get("item")
			if item == null or not affected.has(item.id): continue
			if not result.has(item.id): result[item.id] = []
			var material: Material = batch.material_override if batch.material_override != null else batch.multimesh.mesh.surface_get_material(0)
			var tint: Color = batch.multimesh.get_instance_color(i) if batch.multimesh.use_colors else Color.WHITE
			result[item.id].append({"mesh":batch.multimesh.mesh,"transform":batch.global_transform*batch.multimesh.get_instance_transform(i),"material":_material(material,tint)})
	for id in affected:
		var item: Dictionary = affected[id].item
		if item.asset not in NativeGardenLandmarks.KINDS: continue
		var node := editor.landmarks.get_node_or_null("%s_%d" % [item.asset,id])
		if node == null: continue
		result[id] = []
		for visual: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			result[id].append({"mesh":visual.mesh,"transform":visual.global_transform,"material":_material(visual.get_active_material(0),Color.WHITE)})
	return result

func _material(source: Material, tint: Color) -> Material:
	if source == null: return null
	var material := source.duplicate() as Material
	if material is ShaderMaterial:
		var base: Variant = material.get_shader_parameter("base_color")
		material.set_shader_parameter("base_color",(base if base is Color else Color.WHITE)*tint)
		for flag in ["terrain_growth","plant_growth","sway_enabled","conifer_sway"]: material.set_shader_parameter(flag,false)
	elif material is StandardMaterial3D: material.albedo_color *= tint
	return material

func _launch_parts(parts: Array, kick: Vector3) -> void:
	if parts.is_empty(): return
	var bounds: AABB = parts[0].transform * parts[0].mesh.get_aabb()
	for part in parts: bounds = bounds.merge(part.transform * part.mesh.get_aabb())
	var body := RigidBody3D.new()
	body.collision_layer = 0 if _staging else 4
	body.collision_mask = 0 if _staging else 1
	body.continuous_cd = true
	body.linear_damp = 0.15
	body.angular_damp = 0.2
	body.freeze = _staging
	body.visible = not _staging
	add_child(body)
	body.global_position = bounds.get_center()
	for part in parts:
		var visual := MeshInstance3D.new()
		visual.mesh = part.mesh
		visual.material_override = part.material
		body.add_child(visual)
		visual.global_transform = part.transform
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size.max(Vector3.ONE*0.08)
	collider.shape = shape
	body.add_child(collider)
	var torque := Vector3(rng.randf_range(-2,2),rng.randf_range(-2,2),rng.randf_range(-2,2))
	if _staging:
		body.set_meta("blast_impulse",[kick.limit_length(45),torque])
	else:
		body.apply_central_impulse(kick.limit_length(45))
		body.apply_torque_impulse(torque)
	bodies.append(body)

func _publish_staged(kind: String, generation: int, target_data: NativeTerrainData) -> void:
	if generation != _blast_generation or editor.data != target_data: return
	for body in bodies:
		if body.get_meta("visual_source","") == kind: body.visible = true

func _eject_dirt(origin: Vector3, radius: float) -> void:
	for i in range(12):
		if bodies.size() >= MAX_BODIES: return
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * rng.randf_range(0.1,0.3)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("98734f")
		var point := origin+Vector3(rng.randf_range(-0.5,0.5),0.25,rng.randf_range(-0.5,0.5))
		_launch_parts([{"mesh":mesh,"material":material,"transform":Transform3D(Basis.IDENTITY,point)}],Blast.impulse(origin,point,radius)*rng.randf_range(0.5,1.0))
