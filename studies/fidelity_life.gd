extends "res://studies/fidelity.gd"
## Bigfoot inhabits the full imported Fidelity world.
var habitat = preload("res://scripts/fidelity_habitat.gd").new()
var navigation = preload("res://scripts/creature_navigation.gd").new()
var brain = preload("res://scripts/creature_brain.gd").new()
var creature: CreatureActor
var resident_enabled := true
var routine: Node
var cave_sites: Node3D
var lair: Node3D
var _cave_skirt_original: Transform3D
var _cave_original_ready := false
var _cave_underside_layers := 1
var environment_life: Node
var fish: Node
var dead_wood: Node
var spawn_options: Array = []
var _nav_view := MeshInstance3D.new()
var _life_status := Label.new()
var _habitat_changed := false
var _habitat_blocked := false
var _reaction := Label3D.new()
var _reaction_time := 0.0
var foliage_tread: Node

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Bigfoot in Fidelity"
	_bigfoot.automatic_enabled = false
	habitat.setup($Reference,_chunk_editor.data)
	_chunk_editor.play_geometry_changed.connect(_geometry_changed)
	_chunk_editor.formation_started.connect(_geometry_changed)
	navigation.rebuild(habitat,habitat.clear_at,0.35,0.3)
	var spawn: Variant = navigation.nearest_safe(Vector3(3,0,3))
	if spawn == null:
		push_error("Fidelity has no safe Bigfoot habitat")
		return
	creature = CreatureActor.new()
	creature.name = "RoamingBigfoot"
	add_child(creature)
	creature.position = spawn
	creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	creature.footstep.connect(_ambient_audio.nature.footstep)
	_tremor.shaken.connect(creature.queue_tremor)
	creature.set_process(false)
	creature._ground_probe = navigation._ground
	foliage_tread = preload("res://scripts/foliage_tread.gd").new()
	add_child(foliage_tread)
	for pair in [["mesh-8",4.26],["mesh-9",4.26],["mesh-11",1.82],["broadleaf-canopies",1.82]]:
		var tree_part := $Reference.get_node_or_null(NodePath(pair[0])) as GeometryInstance3D
		if tree_part == null: continue
		var tree_mesh: Mesh = tree_part.multimesh.mesh if tree_part is MultiMeshInstance3D else tree_part.mesh
		var original: Material = tree_part.material_override if tree_part.material_override != null else tree_mesh.surface_get_material(0)
		if original is ShaderMaterial:
			var material := original.duplicate() as ShaderMaterial
			material.set_shader_parameter("tree_tread",true)
			material.set_shader_parameter("tree_tread_height",pair[1])
			tree_part.material_override = material
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	for mesh: MeshInstance3D in creature.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	add_child(brain)
	brain.rest_min = 4.0
	brain.rest_max = 8.0
	brain.inspection_duration = 4.5
	brain.scenery_chance = 0.35
	brain.react_immediately = false
	brain.setup(creature,navigation,func() -> Array: return habitat.interests)
	brain.planning_allowed = func() -> bool: return not _paused and resident_enabled and not _habitat_changed
	creature.add_child(_reaction)
	_reaction.position.y = 3.3
	_reaction.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_reaction.font_size = 64
	brain.reaction.connect(func(symbol: String, _text: String) -> void:
		_reaction.text = symbol
		_reaction_time = 2.0)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20,20)
	overlay.add_child(panel)
	panel.add_child(_life_status)
	for entry in [["Find Bigfoot",_focus_bigfoot],["Find his resting spot",_focus_resting_spot],["Show / hide walkable ground",_toggle_navigation]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		panel.add_child(button)
	add_child(_nav_view)
	_nav_view.visible = false
	routine = preload("res://scripts/bigfoot_routine.gd").new()
	add_child(routine)
	routine.setup(self)
	cave_sites = preload("res://scripts/bigfoot_cave_site.gd").new()
	add_child(cave_sites)
	cave_sites.rebuild(_chunk_editor.data)
	environment_life = preload("res://scripts/bigfoot_environment.gd").new()
	add_child(environment_life)
	environment_life.setup(self)
	fish = preload("res://scripts/fidelity_fish.gd").new()
	add_child(fish)
	fish.setup(self)
	dead_wood = preload("res://scripts/dead_wood.gd").new()
	add_child(dead_wood)
	dead_wood.setup(self)
	_choose_inhabited_shore()
	_seed_loose_stones()
	_focus_bigfoot()

func _choose_inhabited_shore() -> void:
	var best := creature.position
	var best_score := -1
	for candidate: Dictionary in fish.available_targets():
		if not routine._plan_approach(candidate,"fish",false): continue
		var nearest: Variant = navigation.nearest_safe(candidate.position)
		if nearest == null: continue
		var spot: Vector3 = nearest
		creature.reset_at(spot)
		var score := 0
		for tree: Dictionary in routine._targets("tree"):
			if tree.position.distance_to(spot)<9.0 and routine._plan_approach(tree,"tree"): score += 1
		for point in navigation._nodes:
			if point.distance_to(spot)<5.0 and not navigation.path(spot,point).is_empty(): score += 1
		spawn_options.append({"point":spot,"score":score})
		if score > best_score:
			best = spot
			best_score = score
	creature.reset_at(best)

func _seed_loose_stones() -> void:
	# Put loose stones within arm's reach beside the paths, not on the tiny
	# shoreline passages whose clearance Bigfoot needs for the other activities.
	var protected: Array[Vector3] = []
	for point in navigation._nodes:
		if point.distance_to(creature.position)<6.0 and not navigation.path(creature.position,point).is_empty(): protected.append(point)
	var points: Array[Vector3] = []
	for stance in protected.duplicate():
		for turn in range(24):
			var point: Vector3 = stance+Basis(Vector3.UP,float(turn)*TAU/24.0)*Vector3(-0.457,0,0.864)
			var ground: Variant = navigation._ground(point)
			if ground == null or absf(ground.y-stance.y)>0.4: continue
			var room := true
			for other in protected:
				if Vector2(ground.x-other.x,ground.z-other.z).length()<0.9: room = false
			for other in points:
				if ground.distance_to(other)<1.0: room = false
			if not room: continue
			if _chunk_editor.data.place("rock",Vector2(ground.x,ground.z),0.0,0.28)>=0: points.append(ground)
			if points.size()>=3: break
		if points.size()>=3: break
	_chunk_editor.refresh()

func _process(delta: float) -> void:
	super._process(delta)
	if lair != null: lair.drips.advance(delta,_paused)
	if creature == null: return
	if not resident_enabled:
		if foliage_tread != null: foliage_tread.tick(null,delta)
		creature.visible = false
		return
	if (_habitat_changed or navigation.rebuilding) and not _paused and not _chunk_editor.forming: _refresh_habitat(true)
	var present := not _habitat_blocked and _growth.terrain >= 0.995
	creature.visible = present and (not routine.cave.concealed or lair != null)
	if foliage_tread != null:
		var on_ground: bool = present and not routine.cave.concealed and creature.state in [CreatureActor.State.IDLE,CreatureActor.State.ALERT,CreatureActor.State.WALKING,CreatureActor.State.ACTION]
		foliage_tread.tick(creature.global_position if on_ground else null,delta,_paused)
	var stopped := _paused or not present
	if not stopped:
		try_void_fall()
		if creature.state != CreatureActor.State.FALLING and not _habitat_changed and not navigation.rebuilding and not _chunk_editor.forming:
			var observing: bool = environment_life != null and environment_life.advance(delta)
			if not observing and not (has_method("resident_activity_owned") and call("resident_activity_owned")):
				if routine == null or not routine.advance(delta): brain.advance(delta)
			elif routine != null:
				# Environmental reactions and player interactions take ownership
				# before the routine ticks; release its journey but keep props moving.
				if not routine.living.current.is_empty(): routine.cancel("resident activity interrupted routine")
				routine.living.advance_needs(delta)
				routine._advance_projectiles(minf(delta,0.05))
		elif routine != null:
			routine._advance_projectiles(minf(delta,0.05))
		if fish != null: fish.advance(delta)
		if dead_wood != null: dead_wood.advance(delta)
		creature.wet_coat.rain = 0.0 if routine.cave.sheltered() else _precipitation.state.x
		var deck: Dictionary = habitat.walkways.at(Vector2(creature.position.x,creature.position.z))
		creature.balancing = not deck.is_empty() and creature.position.y>=float(deck.height)
		creature.advance(delta)
		_reaction_time = maxf(0.0,_reaction_time-delta)
		_reaction.visible = _reaction_time > 0.0
	creature.visible = present and (not routine.cave.concealed or lair != null)
	if creature.state == CreatureActor.State.STUMBLING and not stopped:
		_life_status.text = "Bigfoot · finding his balance · P pause"
		return
	_life_status.text = "Bigfoot · %s · P pause" % ["needs a clearing" if _habitat_blocked else ("paused" if stopped else ("in his cave" if routine != null and routine.cave.sheltered() else ("cave · "+routine.cave.phase if routine != null and not routine.cave.phase.is_empty() else (routine.active if routine != null and not routine.active.is_empty() else CreatureBrain.Phase.keys()[brain.phase].to_lower()))))]

## Only an actual missing terrain face triggers a void fall. A qualifying log
## can still supply support there, and a held resident falls only on release.
func try_void_fall(released := false) -> bool:
	if creature == null or _chunk_editor.data.void_faces.is_empty(): return false
	if creature.state == CreatureActor.State.FALLING: return true
	if creature.is_held() and not released: return false
	if routine != null and routine.cave.concealed: return false
	var p := Vector2(creature.global_position.x,creature.global_position.z)
	var data: NativeTerrainData = _chunk_editor.data
	if not data.is_void(p): return false
	var deck: Variant = habitat.navigation_height(p)
	if deck != null and creature.global_position.y>=float(deck)-0.12: return false
	if navigation.rebuilding: return false
	var safe: Variant = nearest_safe_bank(creature.global_position)
	if safe == null: return false
	creature.begin_void_fall(safe,nearest_safe_bank)
	if environment_life != null: environment_life.cancel()
	if routine != null: routine.cancel("fell into the chasm")
	brain.reset_behavior()
	return true

func nearest_safe_bank(point: Vector3) -> Variant:
	var best: Variant = null
	var distance := INF
	for candidate: Vector3 in navigation._nodes:
		var score := candidate.distance_squared_to(point)
		if score>=distance: continue
		var h: Variant = habitat.ground_height(Vector2(candidate.x,candidate.z))
		if h == null or absf(h-candidate.y)>0.02 or not navigation.is_safe(candidate): continue
		best = candidate
		distance = score
	return best

func _geometry_changed() -> void:
	_habitat_changed = true
	if creature != null: creature.stop_walking()
	if environment_life != null: environment_life.world_changed()
	if routine != null: routine.world_changed()

func _refresh_habitat(budgeted := false) -> void:
	if _habitat_changed or not budgeted:
		if foliage_tread != null: foliage_tread.clear()
		_habitat_changed = false
		if cave_sites != null: cave_sites.rebuild(_chunk_editor.data)
		habitat.setup($Reference,_chunk_editor.data)
		navigation.begin_rebuild(habitat,habitat.clear_at,0.35,0.3,budgeted)
	if budgeted:
		if not navigation.advance_rebuild(2000): return
	else:
		while not navigation.advance_rebuild(1000000): pass
	var safe: Variant = navigation.nearest_safe(creature.global_position)
	_habitat_blocked = safe == null
	if routine != null: routine.habits.preferred()
	if _habitat_blocked: return
	if creature.is_held():
		var fallback: Variant = navigation.nearest_safe(creature._safe_position)
		creature._safe_position = fallback if fallback != null else safe
	elif creature.state == CreatureActor.State.FALLING or try_void_fall(): pass
	elif not creature.blast_airborne and not navigation.is_safe(creature.global_position): creature.reset_at(safe)
	brain.world_changed()
	# New trees, new places for the wind to drop wood. Branches already lying on
	# the ground keep the spot they fell on.
	if dead_wood != null: dead_wood.rebuild_sites()
	var shown := _nav_view.visible
	_nav_view.mesh = null
	_nav_view.visible = false
	if shown: _toggle_navigation()

func _summon_bigfoot(_fog := false) -> void:
	if creature != null: _focus_bigfoot()

func _focus_resting_spot() -> void:
	if routine == null or routine.habits.home == null: return
	_auto_orbit = false
	target = routine.habits.home+Vector3.UP*0.5
	distance = 7.0
	yaw = 0.4
	polar = 0.85
	_update_camera()

func _focus_bigfoot() -> void:
	frame_creature(10.0,creature.rotation.y-0.65)

func frame_creature(view_distance: float, preferred_yaw: float) -> void:
	target = creature.global_position+Vector3.UP*1.3
	distance = view_distance
	var foliage_boxes: Array[AABB] = []
	for name in ["mesh-9","broadleaf-canopies","mesh-13"]:
		var node: MultiMeshInstance3D = get_node("Reference/"+name)
		for i in range(node.multimesh.instance_count):
			foliage_boxes.append(node.transform*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb())
	var best := INF
	for elevation in [1.05,0.8,0.55]:
		for i in range(16):
			var angle: float = preferred_yaw+float(i)*TAU/16.0
			var view := target+Vector3(sin(elevation)*sin(angle),cos(elevation),sin(elevation)*cos(angle))*distance
			var score := 0.0
			for sample_index in range(1,25):
				var sample_point := target.lerp(view,float(sample_index)/24.0)
				var ground: Variant = habitat.ground_height(Vector2(sample_point.x,sample_point.z))
				if ground != null and ground>sample_point.y-0.2: score += 10.0
			for box: AABB in habitat.solids:
				if box.intersects_segment(target,view) != null: score += 1.0
			for box in foliage_boxes:
				if box.intersects_segment(target,view) != null: score += 25.0
			score += absf(angle_difference(preferred_yaw,angle))*0.1+(1.05-elevation)
			if score < best:
				best = score
				yaw = angle
				polar = elevation
	_update_camera()

func _toggle_navigation() -> void:
	if _nav_view.mesh == null:
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for p in navigation._nodes:
			mesh.surface_add_vertex(p+Vector3(-0.12,0.08,0))
			mesh.surface_add_vertex(p+Vector3(0.12,0.08,0))
			mesh.surface_add_vertex(p+Vector3(0,0.08,-0.12))
			mesh.surface_add_vertex(p+Vector3(0,0.08,0.12))
		mesh.surface_end()
		_nav_view.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.3,1.0,0.5)
		_nav_view.material_override = material
	_nav_view.visible = not _nav_view.visible

func capture_life_state() -> Dictionary:
	return routine.habits.capture()

func restore_life_state(state: Dictionary) -> void:
	routine.crossing_wish.reset()
	if environment_life != null: environment_life.world_changed()
	routine.cancel("garden opened")
	_refresh_habitat()
	routine.habits.restore(state)

func capture_cave_state() -> Dictionary:
	return lair.document() if is_instance_valid(lair) else {}

func restore_cave_state(state: Dictionary) -> void:
	if not preload("res://scripts/cave_genome.gd").valid_state(state): return
	if state.is_empty() and lair==null: return
	if routine != null: routine.cancel("cave system changed")
	var skirt: MeshInstance3D = get_node("Reference/skirt")
	var old_underside := get_node("Reference").find_child("mesh-3",true,false)
	if not _cave_original_ready:
		_cave_skirt_original = skirt.transform
		if old_underside != null: _cave_underside_layers = old_underside.layers
		_cave_original_ready = true
	if is_instance_valid(lair):
		remove_child(lair)
		lair.queue_free()
		lair = null
	routine.cave.rest_anchor = null
	skirt.transform = _cave_skirt_original
	if old_underside != null: old_underside.layers = _cave_underside_layers
	if state.is_empty(): return
	if old_underside != null: old_underside.layers = 0
	var top: float = (skirt.transform*skirt.mesh.get_aabb()).end.y
	skirt.scale.y *= 0.61
	skirt.position.y = top-(top-skirt.position.y)*0.61
	lair = preload("res://scripts/bigfoot_lair_room.gd").new()
	lair.genome = state.genome.duplicate(true)
	lair.position = Vector3(0,-11,0)
	# The lower story's outer walls continue this chunk's own earth.
	lair.earth_material = skirt.mesh.surface_get_material(0) as ShaderMaterial
	lair.strata = lair.strata_from(skirt.mesh)
	add_child(lair)
	lair.restore_stash(state.stash)
	lair.restore_living(state.get("living",{"bed_stage":0,"play_stage":0}))
	routine.cave.rest_anchor = lair.bed

func capture_living_state() -> Dictionary:
	return routine.living.capture()

func remap_living_interest(old_id: String, new_id: String) -> void:
	if routine != null: routine.living.mind.remap_observation(old_id,new_id)

func restore_living_state(state: Dictionary) -> void:
	routine.living.restore(state)

func capture_fish_state() -> Dictionary:
	return fish.capture_state() if fish != null else {"version":1,"stored_ids":[]}

func restore_fish_state(state: Dictionary) -> void:
	if fish != null: fish.restore_state(state)

func capture_wood_state() -> Dictionary:
	return dead_wood.capture_state() if dead_wood != null else {"version":1,"branches":[]}

func restore_wood_state(state: Dictionary) -> void:
	if dead_wood != null: dead_wood.restore_state(state)
