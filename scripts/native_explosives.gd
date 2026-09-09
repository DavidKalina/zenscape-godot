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
## Charges the fire has cooked off. The field never detonates anything itself;
## it names the charge and this queue sends it through the ordinary path.
var fire_queue: Array[int] = []

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

## `FireField.explosive_triggered` lands here. One charge per physics frame, so
## a chain of cook-offs reads as a chain rather than a single flash.
func ignite_charge(id: int) -> void:
	if id not in fire_queue: fire_queue.append(id)

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
		if not _blocked(): detonate()
	elif not fire_queue.is_empty() and not _blocked():
		var cooked: int = fire_queue.pop_front()
		if not editor.data.object_by_id(cooked).is_empty():
			var aimed := target_id
			target_id = cooked
			detonate()
			if editor.data.object_by_id(aimed).is_empty(): aimed = 0
			target_id = aimed
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

func detonate() -> void:
	var salvo: Array[Dictionary] = []
	for item in charges():
		if target_id <= 0 or item.id == target_id: salvo.append(item.duplicate(true))
	if salvo.is_empty(): return
	editor.finish_stroke()
	if editor.scene.has_method("flush_world_play"): editor.scene.flush_world_play()
	clear_effects()
	firing = true
	# Legacy scenery becomes ordinary records before taking visible mesh copies.
	editor.data.begin_stroke()
	if preload("res://scripts/world_reference_props.gd").migrate(editor): editor.refresh()
	editor.reactions.finish_all()
	var affected := {}
	var origins: Array[Vector3] = []
	var resident := editor.scene.get("creature") as CreatureActor
	var resident_enabled: bool = resident != null and editor.scene.get("resident_enabled") == true
	var resident_kick := Vector3.ZERO
	for charge in salvo:
		var local := editor.data.object_position(charge)
		var origin := editor.terrain.to_global(local)
		origins.append(origin)
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
	var collapses: Array[Dictionary] = []
	for charge in salvo:
		var point := editor.data.object_position(charge)
		var initial_heights := editor.data.heights.duplicate()
		var collapse := InternalBlast.rupture(editor.data,point,charge.blast_radius,surface_colors)
		if collapse.is_empty() and not InternalBlast.confined(editor.data,point,charge.blast_radius):
			Blast.carve_native(editor.data,point,charge.blast_radius)
			collapse = Collapse.collapse(editor.data,initial_heights,point,charge.blast_radius,surface_colors)
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
	# The live instance transforms still describe the unbroken mountainside.
	var parts := _capture_parts(affected)
	for id in affected: editor.data.remove_object(id)
	editor.data.end_stroke()
	editor.data._undo.back()["explosion"] = true
	editor.refresh()
	var world_play: Variant = editor.scene.get("world_play")
	if world_play != null:
		# The resident and thrown props share these colliders. Refresh them now,
		# before debris can encounter the pre-blast ground on the next tick.
		world_play.ensure_collision()
	else:
		collisions.rebuild(editor.data)
		collisions.global_transform = editor.terrain.global_transform
	if resident_kick.length() > 0.1:
		var before := resident.global_position
		if resident.receive_blast(resident_kick): _resident_before = before
	for collapse in collapses:
		_launch_collapse(collapse)
		if collapse.get("internal",false):
			# Surface breakouts make the buried blast visible around the cap.
			for i in range(mini(8,collapse.chunks.size())):
				effects.emit_rockfall(editor.terrain.to_global(collapse.chunks[i].center),1.2)
	var launch_order := affected.keys()
	# Preserve the big readable silhouettes when a dense flower patch exceeds
	# the debris budget; small plants still disappear into the dust.
	launch_order.sort_custom(func(a: int,b: int) -> bool: return int(affected[a].item.asset in SOLIDS) > int(affected[b].item.asset in SOLIDS))
	for id in launch_order:
		if not parts.has(id) or bodies.size() >= MAX_BODIES: continue
		_launch_parts(parts[id],affected[id].kick)
	for i in range(salvo.size()):
		var charge := salvo[i]
		effects.emit_blast(origins[i],charge.blast_radius)
		_eject_dirt(origins[i],charge.blast_radius)
	_elapsed = 0.0
	firing = false
	collapse_count = collapses.size()
	_sync_list()
	# A blast leaves fire behind. Wet ground, snow or rain still smother it, so
	# the field decides whether anything actually catches.
	#
	# `carve_native` zeroes cover inside the blast radius, so the crater has no
	# fuel of its own and only the ring outside it can catch. The design's
	# radius * 1.2 at full strength lands that ring below the ignition
	# threshold; 1.6 at 1.5 puts a cell-wide band of grass over it.
	var field: Variant = editor.scene.get("_fire_field")
	if field != null:
		for i in range(salvo.size()):
			field.ignite(editor.terrain.to_local(origins[i]),salvo[i].blast_radius*1.6,1.5)
	editor._set_status(("Mountain collapse · " if collapse_count > 0 else "Detonated %d charge(s) · " % salvo.size())+"Undo last blast restores the landscape.")

func _launch_collapse(collapse: Dictionary) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("palette_role",3)
	material.set_shader_parameter("wet_ground",true)
	for chunk: Dictionary in collapse.chunks:
		# Reserve some of the common budget for trees, scenery and blast dirt.
		if bodies.size() >= 48: return
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
	body.collision_layer = 4
	body.collision_mask = 1
	body.continuous_cd = true
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
	body.apply_central_impulse(kick.limit_length(45))
	body.apply_torque_impulse(Vector3(rng.randf_range(-2,2),rng.randf_range(-2,2),rng.randf_range(-2,2)))
	bodies.append(body)

func _eject_dirt(origin: Vector3, radius: float) -> void:
	for i in range(12):
		if bodies.size() >= MAX_BODIES: return
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * rng.randf_range(0.1,0.3)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("98734f")
		var point := origin+Vector3(rng.randf_range(-0.5,0.5),0.25,rng.randf_range(-0.5,0.5))
		_launch_parts([{"mesh":mesh,"material":material,"transform":Transform3D(Basis.IDENTITY,point)}],Blast.impulse(origin,point,radius)*rng.randf_range(0.5,1.0))
