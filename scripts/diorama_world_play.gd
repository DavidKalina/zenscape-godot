extends Node3D
## Bridges the main world's authored objects to the shared physical play systems.
## Untouched objects stay batched. Promotion keeps their record identity for saving.
const TREES := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","snag"]
const PROPS := ["rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4"]
var owner_scene: Node3D
var creature: CreatureActor
var brain: Node
var navigation: CreatureNavigation
var camera: Camera3D
var _chunk_editor: NativeChunkEditor
var loose_props = preload("res://scripts/world_loose_props.gd").new()
var water_play = preload("res://scripts/world_water_play.gd").new()
var mischief = preload("res://scripts/bigfoot_mischief.gd").new()
var exchange = preload("res://scripts/bigfoot_object_exchange.gd").new()
var temper = preload("res://scripts/bigfoot_temper.gd").new()
var play_collisions := NativePlayCollisions.new()
var spring_tree: PlaySpringTree
var _tree_drag := false
var _tree_plane := Plane()
var _tree_origin := Vector3.ZERO
var _attention_time := 0.0
var _offended_time := 0.0
var _refresh_phase := 0
var _world_dirty := true
var _parts := {}
var _records := {}
var _active := {}
var _triangles := {}
var _collision_dirty := true
var _flushing := false
var _pick_distance := INF
var _hover_clock := 0.0
var _wake_clock := 0.0
var _hint := Label.new()
var _paused: bool:
	get: return owner_scene == null or owner_scene._paused or owner_scene._chunk_editor.active or owner_scene._chunk_editor.forming or owner_scene._menu.visible
var _carrying: bool:
	get: return owner_scene._resident_play.carrying
var gust_tool: bool:
	get: return owner_scene._resident_play.gust
var _habitat_blocked: bool:
	get: return not owner_scene.resident_enabled or owner_scene._habitat_blocked or owner_scene._habitat_changed or navigation.rebuilding

func setup(target: Node3D) -> void:
	owner_scene = target
	add_child(preload("res://scripts/tree_motion_tuner.gd").new())
	creature = target.creature
	brain = target.brain
	navigation = target.navigation
	navigation.dynamic_clearance = dynamic_clearance
	camera = target.camera
	_chunk_editor = target._chunk_editor
	_chunk_editor.content.object_fire_changed.connect(_update_object_fire)
	_chunk_editor.content.instances_published.connect(_instances_published)
	_chunk_editor.landmarks.instances_published.connect(_instances_published)
	for node in [loose_props,water_play,mischief,exchange,temper,play_collisions]: add_child(node)
	loose_props.setup(self)
	water_play.setup(self)
	mischief.setup(self)
	exchange.setup(self)
	temper.setup(self)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	overlay.add_child(_hint)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_color",Color("fff0d9"))
	_hint.add_theme_color_override("font_shadow_color",Color("25202a"))
	_hint.add_theme_constant_override("shadow_offset_x",1)
	_hint.add_theme_constant_override("shadow_offset_y",2)
	_hint.hide()
	_chunk_editor.formation_started.connect(invalidate)
	_chunk_editor.play_geometry_changed.connect(invalidate)
	creature.state_changed.connect(func(state: CreatureActor.State) -> void:
		if state in [CreatureActor.State.STUMBLING,CreatureActor.State.WIND,CreatureActor.State.SWIMMING]:
			temper.provoke(0.42)
			mischief.cancel()
			exchange.cancel("actor interrupted"))

func _over_controls(mouse: Vector2) -> bool:
	for tuner in get_tree().get_nodes_in_group("tree_motion_tuner"):
		if tuner.contains(mouse): return true
	return not _chunk_editor.pointer_in_world(mouse)

func _probe_ground(point: Vector3) -> Variant:
	return owner_scene._resident_wind.ground(point)

func _ground_at(mouse: Vector2) -> Variant:
	var point: Variant = _chunk_editor.pick(mouse)
	return _chunk_editor.terrain.to_global(point) if point != null else null

func valid_landing(point: Vector3) -> bool:
	return navigation.is_safe(point) and play_collisions.can_stand(point)

func prop_out_of_bounds(point: Vector3) -> bool:
	return point.y < -40.0 or _chunk_editor.data.ground_height(Vector2(point.x,point.z)) == null

func _show_reaction(symbol: String, message: String) -> void:
	if owner_scene.resident_enabled:
		owner_scene._reaction.text = symbol
		owner_scene._reaction_time = 2.0
	owner_scene._notice.text = message

func owns_resident() -> bool:
	return exchange.busy() or mischief.busy() or loose_props.busy() or _carrying

func cancel() -> void:
	if owner_scene == null: return
	exchange.cancel()
	mischief.cancel()
	loose_props.cancel()
	if _tree_drag and is_instance_valid(spring_tree): spring_tree.cancel()
	_tree_drag = false
	_hint.hide()

func invalidate() -> void:
	if _flushing: return
	owner_scene.habitat.walkways.disabled.clear()
	cancel()
	for id in _active:
		for part in _parts.get(id,[]):
			if part.has("batch") and is_instance_valid(part.batch) and part.batch in _chunk_editor.content._batches:
				var key: String = part.batch.get_meta("part")
				var sources: Array = _chunk_editor.content._sources.get(key,[])
				if part.index<sources.size() and sources[part.index].item != null and int(sources[part.index].item.id)==id:
					part.batch.multimesh.set_instance_transform(part.index,_chunk_editor.content._instance_transform(sources[part.index]))
			elif part.has("node") and is_instance_valid(part.node): part.node.show()
		var node: Node3D = _active[id]
		if node is RigidBody3D: node.collision_layer = 0
		node.queue_free()
	_active.clear()
	loose_props.bodies.clear()
	loose_props._previous.clear()
	loose_props._investigated.clear()
	loose_props._tree_contacts.clear()
	loose_props._evade_to = null
	spring_tree = null
	mischief.tree_protected = false
	_parts.clear()
	_world_dirty = true
	_collision_dirty = true
	temper.reset()

func _material(source: Material, tint: Color) -> Material:
	if source == null: return null
	var result := source.duplicate() as Material
	if result is ShaderMaterial:
		var base: Variant = result.get_shader_parameter("base_color")
		result.set_shader_parameter("base_color",(base if base is Color else Color.WHITE)*tint)
	elif result is StandardMaterial3D:
		result.albedo_color *= tint
	return result

func _instances_published() -> void:
	# Cover/tint refreshes replace batches even when placements do not change.
	# Keep physical props alive and hide their newly published authored copies.
	rebuild_registry(false)
	for id in _active: _hide_authored(id)

func _hide_authored(id: int) -> void:
	for part in _parts.get(id,[]):
		if part.has("batch"):
			part.batch.multimesh.set_instance_transform(part.index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
		else: part.node.hide()

func rebuild_registry(refresh_water := true) -> void:
	_parts.clear()
	_records.clear()
	for record in _chunk_editor.data.objects: _records[int(record.id)] = record
	for batch in _chunk_editor.content._batches:
		var sources: Array = _chunk_editor.content._sources.get(batch.get_meta("part"),[])
		for i in range(sources.size()):
			var item: Variant = sources[i].get("item")
			if item == null or (item.asset not in TREES and item.asset not in PROPS): continue
			var id := int(item.id)
			if not _parts.has(id): _parts[id] = []
			var mesh: Mesh = batch.multimesh.mesh
			var material: Material = batch.material_override if batch.material_override != null else mesh.surface_get_material(0)
			var tint: Color = sources[i].get("color",Color.WHITE)
			_parts[id].append({"batch":batch,"index":i,"mesh":mesh,"transform":batch.global_transform*_chunk_editor.content._instance_transform(sources[i]),"source_material":material,"tint":tint})
	for item in _chunk_editor.data.objects:
		if item.asset != "bigfoot_tree": continue
		var node := _chunk_editor.landmarks.get_node_or_null("%s_%d" % [item.asset,item.id])
		if node == null: continue
		_parts[int(item.id)] = []
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			_parts[int(item.id)].append({"node":mesh,"mesh":mesh.mesh,"transform":mesh.global_transform,"source_material":mesh.get_active_material(0),"tint":Color.WHITE})
	if refresh_water:
		water_play.ponds.clear()
		for pond in _chunk_editor.data.ponds:
			water_play.ponds.append({"level":float(pond.level),"vertices":_chunk_editor.data.pond_surface(pond)})
		water_play.refresh()
	_world_dirty = false

func ensure_collision() -> void:
	if not _collision_dirty: return
	play_collisions.rebuild(_chunk_editor.data)
	play_collisions.global_transform = _chunk_editor.terrain.global_transform
	for id in _active:
		if _active[id] is RigidBody3D: _disable_source_collision(id)
	_collision_dirty = false

func _disable_source_collision(id: int) -> void:
	var node := play_collisions.get_node_or_null("Prop_%d" % id)
	if node != null: node.collision_layer = 0

func pick_object(mouse: Vector2, include_trees := true) -> int:
	if _over_controls(mouse): return -1
	if _world_dirty: rebuild_registry()
	var origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	var ground: Variant = _ground_at(mouse)
	var nearest: float = origin.distance_to(ground)+0.05 if ground != null else INF
	var result := -1
	for id in _parts:
		if _active.has(id): continue
		var item: Dictionary = _records.get(id,{})
		if not include_trees and item.asset in TREES: continue
		for part in _parts[id]:
			var inverse: Transform3D = part.transform.affine_inverse()
			var local_origin: Vector3 = inverse*origin
			var local_ray: Vector3 = (inverse.basis*ray).normalized()
			if part.mesh.get_aabb().intersects_ray(local_origin,local_ray) == null: continue
			if not _triangles.has(part.mesh): _triangles[part.mesh] = part.mesh.generate_triangle_mesh()
			var triangles: TriangleMesh = _triangles[part.mesh]
			if triangles == null: continue
			var hit := triangles.intersect_ray(local_origin,local_ray)
			if hit.is_empty(): continue
			var distance := origin.distance_to(part.transform*hit.position)
			if distance < nearest:
				nearest = distance
				result = id
	_pick_distance = nearest
	return result

func promote(id: int) -> Node3D:
	if _active.has(id): return _active[id]
	if _world_dirty: rebuild_registry()
	if not _parts.has(id): return null
	ensure_collision()
	var item: Dictionary = _records.get(id,{})
	var parts: Array = _parts[id]
	for part in parts:
		part.material = _material(part.source_material,part.tint)
		FireMaterial.apply(part.material,_chunk_editor.content.object_fire(id))
	var basis := NativeObjectPose.decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP,float(item.angle)).scaled(Vector3.ONE*float(item.scale))
	var pose: Transform3D = _chunk_editor.terrain.global_transform*Transform3D(basis,_chunk_editor.data.object_position(item))
	var node: Node3D
	if item.asset in TREES:
		node = preload("res://scripts/world_spring_tree.gd").new()
		add_child(node)
		node.configure(parts,pose.origin)
	else:
		node = preload("res://scripts/world_loose_body.gd").new()
		loose_props.add_child(node)
		var kind := "log" if item.asset in ["log","stump"] else "boulder" if item.asset.begins_with("boulder") else "stone"
		node.configure(parts,pose,kind)
		loose_props.register(node)
		_disable_source_collision(id)
	node.object_id = id
	_active[id] = node
	if item.asset == "log":
		owner_scene.habitat.walkways.disabled[id] = true
		# Small carryable logs never supplied footing. Invalidating their world
		# here would reject the very interaction that just promoted the prop.
		if owner_scene.habitat.walkways.surfaces.any(func(surface: Dictionary) -> bool: return int(surface.id)==id):
			owner_scene._geometry_changed()
	var fire_materials: Array[Material] = []
	for part in parts: fire_materials.append(part.material)
	node.set_meta("fire_materials",fire_materials)
	_hide_authored(id)
	return node

func mischief_candidates(kind: String) -> Array:
	if _habitat_blocked or owner_scene.routine.living.enabled or not owner_scene.routine.active.is_empty() or not owner_scene.routine.living.current.is_empty() or not owner_scene.routine.cave.phase.is_empty(): return []
	if _world_dirty: rebuild_registry()
	var ids: Array = _parts.keys()
	ids.sort_custom(func(a: int,b: int) -> bool:
		return _chunk_editor.data.object_position(_records[a]).distance_squared_to(creature.global_position)<_chunk_editor.data.object_position(_records[b]).distance_squared_to(creature.global_position))
	var result := []
	for id in ids:
		var item: Dictionary = _records.get(id,{})
		if (kind == "tree" and item.asset not in TREES) or (kind == "log" and item.asset != "log") or (kind == "stone" and item.asset != "rock"): continue
		var point := _chunk_editor.data.object_position(item)
		if point.distance_to(creature.global_position)>10.0: break
		# His hand choreography fits human-scale props; the player can grab any size.
		if float(item.scale)>1.5: continue
		var candidate := promote(id)
		if candidate != null: result.append(candidate)
		if result.size()>=3: break
	return result

func handle(event: InputEvent) -> bool:
	if _paused: return false
	if event is InputEventMouseButton and event.pressed and loose_props.grabbed != null and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		loose_props.adjust_height(0.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.18,event.position)
		return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (_tree_drag or loose_props.grabbed != null):
		cancel()
		return true
	if event is InputEventMouseMotion:
		if loose_props.grabbed != null:
			loose_props.move_grab(event.position)
			return true
		if _tree_drag:
			var point: Variant = _tree_plane.intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
			if point != null and not _over_controls(event.position): spring_tree.drag_to(point-_tree_origin)
			return true
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	if not event.pressed:
		if loose_props.grabbed != null:
			if _over_controls(event.position): loose_props.cancel()
			else: loose_props.release()
			return true
		if _tree_drag:
			if _over_controls(event.position): spring_tree.cancel()
			else: release_player_tree()
			_tree_drag = false
			return true
		return false
	if gust_tool or _carrying or _over_controls(event.position): return false
	var picked_id := pick_object(event.position)
	var body: RigidBody3D = loose_props.pick(event.position)
	if body != null and picked_id > 0 and camera.project_ray_origin(event.position).distance_to(body.global_position)-body.reach > _pick_distance: body = null
	if body == null and picked_id > 0 and _records.get(picked_id,{}).asset in PROPS: body = promote(picked_id) as RigidBody3D
	if body != null:
		loose_props.begin_grab(body,event.position)
		return true
	var tree: PlaySpringTree
	for id in _active:
		if _active[id] is PlaySpringTree and _active[id].pick(camera,event.position): tree = _active[id]
	if tree == null:
		if picked_id > 0: tree = promote(picked_id) as PlaySpringTree
	if tree == null: return false
	exchange.cancel()
	mischief.cancel()
	spring_tree = tree
	_tree_drag = true
	tree.begin_grab()
	_tree_plane = Plane(Vector3.UP,tree.center(tree.tree_height*0.6).y)
	var at: Variant = _tree_plane.intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
	_tree_origin = at if at != null else tree.global_position
	return true

func release_player_tree() -> void:
	if not is_instance_valid(spring_tree): return
	var strength := spring_tree.tension
	spring_tree.release()
	if not _habitat_blocked and owner_scene.environment_life != null:
		owner_scene.environment_life.notice_tree_release(spring_tree,strength)

func advance(delta: float) -> void:
	if owner_scene == null: return
	if _paused:
		loose_props.cancel()
		if _tree_drag and is_instance_valid(spring_tree): spring_tree.cancel()
		_tree_drag = false
		_hint.hide()
		for body in loose_props.bodies: body.set_paused(true)
		return
	if _world_dirty:
		if preload("res://scripts/world_reference_props.gd").migrate(_chunk_editor): _chunk_editor.refresh()
		rebuild_registry()
	_attention_time = maxf(0.0,_attention_time-delta)
	_offended_time = maxf(0.0,_offended_time-delta)
	_wake_clock -= delta
	if _wake_clock<=0.0:
		_wake_clock = 0.1
		wake_near_projectiles()
	loose_props.advance(delta)
	water_play.advance(delta)
	if not _habitat_blocked:
		temper.advance(delta)
		exchange.advance(delta)
		if not exchange.busy() and (owner_scene.environment_life == null or not owner_scene.environment_life.busy()): mischief.advance(delta)
	else:
		exchange.cancel("habitat changed")
		mischief.cancel()
		temper.reset()
	for id in _active:
		var tree: Node3D = _active[id]
		if not tree is PlaySpringTree: continue
		var before: Vector2 = tree.bend
		tree.advance(delta)
		if not _habitat_blocked and not _carrying and not (mischief.tree_protected and tree == spring_tree):
			var impulse: Vector3 = tree.sweep_contact(before,creature.global_position+Vector3.UP*1.5,delta)
			if impulse.length()>0.0: creature.receive_impulse((impulse*12.0+Vector3.UP*55).limit_length(240.0))
		var selected := spring_tree
		spring_tree = tree
		loose_props.tree_sweep(before,delta)
		spring_tree = selected
	brain.enabled = not owns_resident() and _attention_time <= 0.0 and creature.state not in [CreatureActor.State.SWIMMING,CreatureActor.State.SHAKING]
	_hover_clock -= delta
	if _hover_clock <= 0.0:
		_hover_clock = 0.16
		var mouse := get_viewport().get_mouse_position()
		_hint.visible = not gust_tool and not _carrying and (not owner_scene._resident_play.hovered or loose_props.grabbed != null) and not _over_controls(mouse) and (loose_props.grabbed != null or _tree_drag or pick_object(mouse)>0)
		_hint.text = "Hold near Bigfoot to offer · Scroll height · Release to throw" if exchange.accepts(loose_props.grabbed) else "Swing and release to throw · Esc to return" if loose_props.grabbed != null else "Pull and release to fling · Esc to cancel" if _tree_drag else "Drag a tree to bend · Drag a rock or log to throw"
		_hint.position = mouse+Vector2(18,22)

func flush() -> void:
	if owner_scene == null or _active.is_empty(): return
	_store_active_poses()
	_chunk_editor.refresh()

## The blast remote flushes under its flash, so the refresh spreads across
## frames instead of stalling the frame the charge goes off.
func flush_budgeted(frame_tree: SceneTree) -> void:
	if owner_scene == null or _active.is_empty(): return
	_store_active_poses()
	await _chunk_editor.refresh(frame_tree)

func _store_active_poses() -> void:
	cancel()
	_flushing = true
	for id in _active:
		var body: Node3D = _active[id]
		if not body is RigidBody3D: continue
		var pose: Transform3D = _chunk_editor.terrain.global_transform.affine_inverse()*body.global_transform*body.record_in_body
		var ground: Variant = _chunk_editor.data.ground_height(Vector2(pose.origin.x,pose.origin.z))
		if ground == null: continue
		var stored := NativeObjectPose.make(pose.basis,clampf(pose.origin.y-ground,-5.0,10.0))
		_chunk_editor.data.update_object(id,{"x":pose.origin.x,"z":pose.origin.z,"pose":stored})
	_flushing = false
	invalidate()

func dynamic_clearance(feet: Vector3) -> bool:
	# A grabbed/thrown log no longer supports its saved position. Its next
	# committed placement can qualify again after the normal habitat rebuild.
	var deck: Dictionary = owner_scene.habitat.walkways.at(Vector2(feet.x,feet.z))
	if not deck.is_empty() and _active.has(int(deck.id)): return false
	for body in loose_props.bodies:
		if body.held or body.parked: continue
		var box: AABB = body.visual.global_transform*body.visual.mesh.get_aabb()
		if feet.y>box.end.y or feet.y+2.8<box.position.y: continue
		if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(0.5).has_point(Vector2(feet.x,feet.z)): return false
	return true

func wake_near_projectiles() -> void:
	# Nearby static props join the solver before a thrown prop reaches them.
	# This allows chain reactions without simulating a whole forest at startup.
	var moving := []
	for body in loose_props.bodies:
		if not body.held and body.linear_velocity.length()>0.8: moving.append(body)
	if moving.is_empty(): return
	var count := 0
	for id in _records:
		if _active.has(id) or _records[id].asset not in PROPS: continue
		var point := _chunk_editor.data.object_position(_records[id])
		for projectile in moving:
			var nearest := Geometry3D.get_closest_point_to_segment(point,projectile.global_position,projectile.global_position+projectile.linear_velocity*0.3)
			if nearest.distance_to(point)>projectile.reach+2.0: continue
			var body := promote(id) as RigidBody3D
			if body != null:
				body.parked = false
				body.set_paused(false)
				body.sleeping = false
			count += 1
			break
		if count>=4: break

func prepare() -> void:
	if owner_scene == null or _chunk_editor.forming: return
	if _world_dirty:
		if preload("res://scripts/world_reference_props.gd").migrate(_chunk_editor): _chunk_editor.refresh()
		rebuild_registry()
	ensure_collision()

func _update_object_fire(id: int, value: Vector2) -> void:
	var node: Node3D = _active.get(id)
	if not is_instance_valid(node): return
	for material: Material in node.get_meta("fire_materials",[]): FireMaterial.apply(material,value)
