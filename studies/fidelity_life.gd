extends "res://studies/fidelity.gd"
## Bigfoot inhabits the full imported Fidelity world.
var habitat = preload("res://scripts/fidelity_habitat.gd").new()
var navigation = preload("res://scripts/creature_navigation.gd").new()
var brain = preload("res://scripts/creature_brain.gd").new()
var creature: CreatureActor
var resident_enabled := true
var routine: Node
var fish: Node
var spawn_options: Array = []
var _nav_view := MeshInstance3D.new()
var _life_status := Label.new()
var _habitat_changed := false
var _habitat_blocked := false
var _reaction := Label3D.new()
var _reaction_time := 0.0

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
	creature.setup("res://assets/models/zenscape-bigfoot-woodland.glb")
	_tremor.shaken.connect(creature.queue_tremor)
	creature.set_process(false)
	creature._ground_probe = navigation._ground
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
	fish = preload("res://scripts/fidelity_fish.gd").new()
	add_child(fish)
	fish.setup(self)
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
	if creature == null: return
	if not resident_enabled:
		creature.visible = false
		return
	if (_habitat_changed or navigation.rebuilding) and not _paused and not _chunk_editor.forming: _refresh_habitat(true)
	creature.visible = not _habitat_blocked and _growth.terrain >= 0.995
	var stopped := _paused or not creature.visible
	if not stopped:
		if not _habitat_changed and not navigation.rebuilding and not _chunk_editor.forming:
			if routine == null or not routine.advance(delta): brain.advance(delta)
		elif routine != null:
			routine._advance_projectiles(minf(delta,0.05))
		if fish != null: fish.advance(delta)
		creature.advance(delta)
		_reaction_time = maxf(0.0,_reaction_time-delta)
		_reaction.visible = _reaction_time > 0.0
	if creature.state == CreatureActor.State.STUMBLING and not stopped:
		_life_status.text = "Bigfoot · finding his balance · P pause"
		return
	_life_status.text = "Bigfoot · %s · P pause" % ["needs a clearing" if _habitat_blocked else ("paused" if stopped else (routine.active if routine != null and not routine.active.is_empty() else CreatureBrain.Phase.keys()[brain.phase].to_lower()))]

func _geometry_changed() -> void:
	_habitat_changed = true
	if creature != null: creature.stop_walking()
	if routine != null: routine.world_changed()

func _refresh_habitat(budgeted := false) -> void:
	if _habitat_changed or not budgeted:
		_habitat_changed = false
		habitat.setup($Reference,_chunk_editor.data)
		navigation.begin_rebuild(habitat,habitat.clear_at,0.35,0.3)
	if budgeted:
		if not navigation.advance_rebuild(2000): return
	else:
		while not navigation.advance_rebuild(1000000): pass
	var safe: Variant = navigation.nearest_safe(creature.global_position)
	_habitat_blocked = safe == null
	if routine != null: routine.habits.preferred()
	if _habitat_blocked: return
	if not navigation.is_safe(creature.global_position): creature.reset_at(safe)
	brain.world_changed()
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
	routine.cancel("garden opened")
	_refresh_habitat()
	routine.habits.restore(state)
