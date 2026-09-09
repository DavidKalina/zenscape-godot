extends Node3D
## Remote charges belong to the shared editor, so every native landscape can
## place, bury, save and detonate them. One salvo is one ordinary undo step.
const Blast = preload("res://scripts/terrain_blast.gd")
const InternalBlast = preload("res://scripts/internal_blast.gd")
const Collapse = preload("res://scripts/mountain_collapse.gd")
const MAX_BODIES := 100
## Debris slower or smaller than this passes harmlessly; anything above it
## knocks the resident down and unseats authored props it strikes.
const STRIKE_SPEED := 4.0
const STRIKE_RADIUS := 0.25
const SOLIDS := ["tree","layered_tree","redwood","broadleaf","snag","bigfoot_tree","rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4"]
var editor: NativeChunkEditor
var effects = preload("res://scripts/explosion_effects.gd").new()
var collisions := NativePlayCollisions.new()
var bodies: Array[RigidBody3D] = []
var requested := false
var firing := false
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
## Bumped by clear_effects so a detonation resolving across frames can tell
## its world was replaced or reset underneath it and stop before launching.
var _salvo_serial := 0

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
	if not _blocked() and not firing: requested = true

func can_restore() -> bool:
	return not editor.data._undo.is_empty() and editor.data._undo.back().get("explosion",false)

func _geometry_changed() -> void:
	if not firing: clear_effects()
	_sync_list()

func clear_effects() -> void:
	if _resident_before is Vector3 and editor != null:
		editor.scene.creature.reset_at(_resident_before)
	_resident_before = null
	requested = false
	collapse_count = 0
	_salvo_serial += 1
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
	if requested and not firing:
		requested = false
		if not _blocked(): detonate(get_tree())
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
			if not body.freeze and body.has_meta("collapse_velocity"):
				body.linear_velocity = body.get_meta("collapse_velocity")
				body.angular_velocity = Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))
				body.remove_meta("collapse_velocity")
				effects.emit_rockfall(body.global_position,0.8)
	if not _blocked():
		_strike_resident()
		_splash_debris()

## A null tree keeps the synchronous path used by tests and offline tools. The
## live remote passes the scene tree: the flash and rumble land on the request
## frame, then the terrain refresh spreads across the following frames under
## the flash instead of stalling the frame the charge goes off.
func detonate(frame_tree: SceneTree = null) -> void:
	var salvo: Array[Dictionary] = []
	for item in charges():
		if target_id <= 0 or item.id == target_id: salvo.append(item.duplicate(true))
	if salvo.is_empty(): return
	editor.finish_stroke()
	clear_effects()
	var serial := _salvo_serial
	firing = true
	var origins: Array[Vector3] = []
	for charge in salvo: origins.append(editor.terrain.to_global(editor.data.object_position(charge)))
	# The blast is visible and audible before any of the heavy work.
	for i in range(salvo.size()): effects.emit_blast(origins[i],salvo[i].blast_radius)
	# Thrown props return to records and legacy scenery becomes ordinary records
	# before taking visible mesh copies. Both refreshes spread across frames
	# under the flash; a world needing neither pays nothing here.
	if editor.scene.has_method("flush_world_play_budgeted"): await editor.scene.flush_world_play_budgeted(frame_tree)
	elif editor.scene.has_method("flush_world_play"): editor.scene.flush_world_play()
	if serial != _salvo_serial:
		firing = false
		return
	editor.data.begin_stroke()
	if preload("res://scripts/world_reference_props.gd").migrate(editor):
		await editor.refresh(frame_tree)
		if serial != _salvo_serial:
			firing = false
			return
	editor.reactions.finish_all()
	var affected := {}
	var resident := editor.scene.get("creature") as CreatureActor
	var resident_enabled: bool = resident != null and editor.scene.get("resident_enabled") == true
	var resident_kick := Vector3.ZERO
	for i in range(salvo.size()):
		var charge := salvo[i]
		var origin := origins[i]
		if resident_enabled:
			resident_kick += Blast.impulse(origin,resident.global_position+Vector3.UP*0.9,charge.blast_radius)*0.8
		for item in editor.data.objects:
			if item.asset == "explosive" or item.asset == "waterfall": continue
			var world := editor.terrain.to_global(editor.data.object_position(item))
			var kick := Blast.impulse(origin,world,charge.blast_radius)
			if kick.length_squared() > 0.01:
				affected[item.id] = {"item":item.duplicate(true),"kick":kick + affected.get(item.id,{}).get("kick",Vector3.ZERO)}
	# Reuse the visible terrain colors instead of rebuilding a temporary crater mesh.
	var visible := editor.terrain.mesh as ArrayMesh
	var color_source: ArrayMesh = visible if visible != null and editor.data.tunnels.is_empty() else editor.data.build_mesh()
	var surface_colors: PackedColorArray = color_source.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var collapses: Array[Dictionary] = []
	for charge in salvo:
		var point := editor.data.object_position(charge)
		var initial_heights := editor.data.heights.duplicate()
		var collapse := InternalBlast.rupture(editor.data,point,charge.blast_radius,surface_colors)
		if collapse.is_empty() and not InternalBlast.confined(editor.data,point,charge.blast_radius):
			Blast.carve_native(editor.data,point,charge.blast_radius)
			collapse = await Collapse.collapse(editor.data,initial_heights,point,charge.blast_radius,surface_colors,frame_tree)
			if serial != _salvo_serial:
				firing = false
				return
		if not collapse.is_empty(): collapses.append(collapse)
		editor.data.remove_object(charge.id)
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
	if frame_tree != null: await frame_tree.process_frame
	if serial != _salvo_serial:
		firing = false
		return
	# The live instance transforms still describe the unbroken mountainside.
	var parts := _capture_parts(affected)
	for id in affected: editor.data.remove_object(id)
	editor.data.end_stroke()
	editor.data._undo.back()["explosion"] = true
	# Physics first: the crater collision is cheap, so debris can fly on the
	# blast frame. The visual refresh then spreads out under the flash.
	var world_play: Variant = editor.scene.get("world_play")
	if world_play != null:
		world_play.ensure_collision(true)
	else:
		collisions.rebuild(editor.data)
		collisions.global_transform = editor.terrain.global_transform
	# The collision rebuild already built the crater mesh; show it now rather
	# than when the visual refresh reaches it.
	editor.terrain.mesh = editor.data.play_mesh()
	if frame_tree != null: await frame_tree.process_frame
	if serial != _salvo_serial:
		firing = false
		return
	if resident_kick.length() > 0.1:
		var before := resident.global_position
		if resident.receive_blast(resident_kick): _resident_before = before
	for collapse in collapses:
		await _launch_collapse(collapse,frame_tree,serial)
		if serial != _salvo_serial:
			firing = false
			return
		if collapse.get("internal",false):
			# Surface breakouts make the buried blast visible around the cap.
			for i in range(mini(8,collapse.chunks.size())):
				effects.emit_rockfall(editor.terrain.to_global(collapse.chunks[i].center),1.2)
	var launch_order := affected.keys()
	# Preserve the big readable silhouettes when a dense flower patch exceeds
	# the debris budget; small plants still disappear into the dust.
	launch_order.sort_custom(func(a: int,b: int) -> bool: return int(affected[a].item.asset in SOLIDS) > int(affected[b].item.asset in SOLIDS))
	var launched := 0
	for id in launch_order:
		if not parts.has(id) or bodies.size() >= MAX_BODIES: continue
		_hide_sources(parts[id])
		_launch_parts(parts[id],affected[id].kick)
		launched += 1
		# Convex hulls and material copies for a dense grove spread over frames.
		if frame_tree != null and launched % 24 == 0:
			await frame_tree.process_frame
			if serial != _salvo_serial:
				firing = false
				return
	for i in range(salvo.size()): _eject_dirt(origins[i],salvo[i].blast_radius)
	_elapsed = 0.0
	collapse_count = collapses.size()
	await editor.refresh(frame_tree)
	if serial != _salvo_serial:
		firing = false
		return
	if world_play != null: world_play.ensure_collision()
	firing = false
	_sync_list()
	editor._set_status(("Mountain collapse · " if collapse_count > 0 else "Detonated %d charge(s) · " % salvo.size())+"Undo last blast restores the landscape.")

func _launch_collapse(collapse: Dictionary, frame_tree: SceneTree = null, serial := -1) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("palette_role",3)
	material.set_shader_parameter("wet_ground",true)
	var launched := 0
	for chunk: Dictionary in collapse.chunks:
		# Reserve some of the common budget for trees, scenery and blast dirt.
		if bodies.size() >= 48: return
		if frame_tree != null and launched > 0 and launched % 16 == 0:
			await frame_tree.process_frame
			if serial != _salvo_serial: return
		launched += 1
		var transform: Transform3D = editor.terrain.global_transform*Transform3D(Basis.IDENTITY,chunk.center)
		_launch_parts([{"mesh":chunk.mesh,"material":material,"transform":transform}],Vector3.ZERO)
		var body: RigidBody3D = bodies.back()
		body.set_meta("mountain_chunk",true)
		body.set_meta("internal_blast",collapse.get("internal",false))
		body.set_meta("release_at",chunk.delay)
		body.set_meta("collapse_velocity",editor.terrain.global_basis*chunk.velocity)
		body.freeze = true
		var collider := body.get_child(body.get_child_count()-1) as CollisionShape3D
		collider.shape = chunk.mesh.create_convex_shape(true,false)
		collider.global_transform = transform
		var physics := PhysicsMaterial.new()
		physics.friction = 0.7
		physics.bounce = 0.12
		body.physics_material_override = physics

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
			result[item.id].append({"mesh":batch.multimesh.mesh,"transform":batch.global_transform*batch.multimesh.get_instance_transform(i),"material":_material(material,tint),"batch":batch,"index":i})
	for id in affected:
		var item: Dictionary = affected[id].item
		if item.asset not in NativeGardenLandmarks.KINDS: continue
		var node := editor.landmarks.get_node_or_null("%s_%d" % [item.asset,id])
		if node == null: continue
		result[id] = []
		for visual: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			result[id].append({"mesh":visual.mesh,"transform":visual.global_transform,"material":_material(visual.get_active_material(0),Color.WHITE),"node":node})
	return result

## The flying copy replaces its authored source in the same frame, so nothing
## is ever missing or doubled while the visual refresh catches up.
func _hide_sources(parts: Array) -> void:
	for part in parts:
		if part.has("batch") and is_instance_valid(part.batch):
			part.batch.multimesh.set_instance_transform(part.index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		elif part.has("node") and is_instance_valid(part.node): part.node.hide()

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
	body.collision_layer = 4
	# Terrain and props, plus the resident's tumble proxy on layer 2.
	body.collision_mask = 1|2
	body.continuous_cd = true
	# Rock-like density so a slab shoves Bigfoot and a pebble does not. Kicks
	# below are scaled by mass, so launch speeds are unchanged.
	body.mass = clampf(bounds.get_volume()*400.0,0.5,400.0)
	body.set_meta("radius",bounds.size.length()*0.5)
	# Only pieces big enough to strike pay for contact reporting.
	if float(body.get_meta("radius")) >= STRIKE_RADIUS:
		body.contact_monitor = true
		body.max_contacts_reported = 4
		body.body_entered.connect(_debris_contact.bind(body))
	body.linear_damp = 0.15
	body.angular_damp = 0.2
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
	body.apply_central_impulse(kick.limit_length(45)*body.mass)
	body.apply_torque_impulse(Vector3(rng.randf_range(-2,2),rng.randf_range(-2,2),rng.randf_range(-2,2))*body.mass)
	bodies.append(body)

## Debris that reaches a pond splashes it once, then wallows instead of
## skating across the surface as if it were ground.
func _splash_debris() -> void:
	var world_play: Variant = editor.scene.get("world_play")
	if world_play == null: return
	var water: Node = world_play.water_play
	for body in bodies:
		if body.freeze or body.has_meta("wet"): continue
		var surface: Variant = water.surface_at(body.global_position)
		if surface == null or body.global_position.y-float(body.get_meta("radius",0.1)) > surface.y: continue
		body.set_meta("wet",true)
		water.splash(surface,clampf(body.mass/60.0,0.3,1.0))
		body.linear_velocity *= 0.35
		body.linear_damp = 2.5
		body.angular_damp = 2.0

func _strikes(body: RigidBody3D) -> bool:
	return not body.freeze and body.linear_velocity.length() >= STRIKE_SPEED and float(body.get_meta("radius",0.0)) >= STRIKE_RADIUS

## Flying debris knocks a standing resident into the same physical tumble a
## blast does. Once airborne, the solver handles further hits directly.
func _strike_resident() -> void:
	var resident := editor.scene.get("creature") as CreatureActor
	if resident == null or editor.scene.get("resident_enabled") != true: return
	if resident.blast_airborne or resident.is_held() or (resident.wind_body != null and resident.wind_body.active): return
	var feet := resident.global_position
	for body in bodies:
		if not _strikes(body): continue
		var point := body.global_position
		var axis := feet+Vector3.UP*clampf(point.y-feet.y,0.0,2.3)
		if point.distance_to(axis) > float(body.get_meta("radius"))+0.55: continue
		var kick := body.linear_velocity*clampf(body.mass/32.0,0.25,1.0)
		if kick.length() < 5.0: kick = kick.normalized()*5.0
		kick += Vector3.UP*2.0
		var before := resident.global_position
		if resident.receive_blast(kick):
			if not _resident_before is Vector3: _resident_before = before
			body.linear_velocity *= 0.55
		return

## A static authored prop struck by fast debris joins the solver and takes the
## hit, so rockfall clears whatever stands in its path.
func _debris_contact(other: Node, body: RigidBody3D) -> void:
	# The prop registry is rebuilt by the refresh still in flight while firing.
	if firing or not other is StaticBody3D or not other.name.begins_with("Prop_") or not _strikes(body): return
	var world_play: Variant = editor.scene.get("world_play")
	if world_play == null: return
	var target: Node3D = world_play.promote(int(other.name.trim_prefix("Prop_")))
	if not target is RigidBody3D: return
	target.release(body.linear_velocity*clampf(body.mass/target.mass,0.2,1.0)+Vector3.UP*1.0,1.0)
	body.linear_velocity *= 0.6

func _eject_dirt(origin: Vector3, radius: float) -> void:
	for i in range(12):
		if bodies.size() >= MAX_BODIES: return
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * rng.randf_range(0.1,0.3)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("98734f")
		var point := origin+Vector3(rng.randf_range(-0.5,0.5),0.25,rng.randf_range(-0.5,0.5))
		_launch_parts([{"mesh":mesh,"material":material,"transform":Transform3D(Basis.IDENTITY,point)}],Blast.impulse(origin,point,radius)*rng.randf_range(0.5,1.0))
