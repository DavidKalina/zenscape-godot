extends Node
## Interruptible world play: navigation owns the approach, authored clips and
## hand targets own the grasp, and the existing prop solver owns every throw.
signal completed(kind: String)
var scene: Node
var autonomous := true
var active := ""
var phase := ""
var target: Node3D
var held: RigidBody3D
var history: Array[String] = []
var last_cancel := ""
var tree_protected := false
var _tree_contacts := {}
var _route := PackedVector3Array()
var _waypoint := 0
var _target_start := Vector3.ZERO
var _facing := 0.0
var _elapsed := 0.0
var _cooldown := 9.0
var _choice := 0
var _released := false
var _owns_tree := false
var _grip_start := Vector3.ZERO
var _direction := Vector3.FORWARD

func setup(playground: Node) -> void:
	scene = playground
	# Reuse the authored performances on the same skeleton, preserving this
	# playground's existing actor, breath, carrying and recovery assets.
	var source := preload("res://assets/models/zenscape-bigfoot-routine.glb").instantiate()
	var player: AnimationPlayer = source.find_child("AnimationPlayer",true,false)
	var library: AnimationLibrary = scene.creature.player.get_animation_library("")
	for clip in ["StoneThrow","TreeShake"]:
		if not library.has_animation(clip): library.add_animation(clip,player.get_animation(clip).duplicate())
	source.free()

func busy() -> bool: return not active.is_empty()

func invite() -> bool:
	for i in range(3):
		var kind: String = ["stone","log","tree"][_choice%3]
		_choice += 1
		if request(kind): return true
	return false

func _available() -> bool:
	return not scene._paused and not scene._carrying and not scene._tree_drag and scene.loose_props.grabbed == null and not scene.loose_props.busy() and not scene._world_dirty and scene._refresh_phase == 0 and not scene._habitat_blocked

func request(kind: String, chosen: Node3D = null) -> bool:
	if kind not in ["stone","log","tree"] or busy() or not _available() or not scene.creature.can_roam(): return false
	var candidates: Array[Node3D] = []
	if chosen != null: candidates.append(chosen)
	elif kind == "tree": candidates.append(scene.spring_tree)
	else:
		for body in scene.loose_props.bodies:
			if body.kind == kind: candidates.append(body)
	candidates.sort_custom(func(a: Node3D,b: Node3D): return scene.creature.global_position.distance_squared_to(a.global_position)<scene.creature.global_position.distance_squared_to(b.global_position))
	for item in candidates:
		if kind == "tree":
			if item != scene.spring_tree or item.held or item.bend.length()>0.08: continue
		elif item not in scene.loose_props.bodies or item.kind != kind or item.held or item.linear_velocity.length()>0.4: continue
		if scene.water_play.surface_at(item.global_position) != null: continue
		if not _plan(item,kind): continue
		last_cancel = ""
		active = kind
		target = item
		_target_start = item.global_position
		phase = "approach"
		_elapsed = 0.0
		_released = false
		scene.brain.reset_behavior()
		scene.brain.enabled = false
		scene.creature.notice(item.global_position)
		scene._show_reaction("?","He has an idea of his own.")
		return true
	return false

func _plan(item: Node3D, kind: String) -> bool:
	var offset: Vector3 = scene.creature.global_position-item.global_position
	var angle := atan2(offset.x,offset.z)
	# Log end-on approaches keep feet outside the entire capsule. Reject any
	# stance beyond arm reach instead of snapping the prop across the clearing.
	for i in range(24):
		var radial := Vector3(sin(angle+i*TAU/24.0),0,cos(angle+i*TAU/24.0))
		var radius := 1.25 if kind == "tree" else 0.95
		var ground: Variant = scene._probe_ground(item.global_position+radial*radius)
		if ground == null or not scene.valid_landing(ground): continue
		if kind != "tree" and absf(ground.y-(item.global_position.y-item.radius))>0.4: continue
		var path: PackedVector3Array = scene.navigation.path(scene.creature.global_position,ground)
		if path.is_empty(): continue
		_route = path
		_waypoint = 0
		_facing = atan2(-radial.x,-radial.z)
		return true
	return false

func advance(delta: float) -> void:
	if scene._paused: return
	_cooldown = maxf(0.0,_cooldown-delta)
	if tree_protected and not _owns_tree and scene.spring_tree.bend.length()<0.05 and scene.spring_tree.velocity.length()<0.1: tree_protected = false
	if not busy():
		if autonomous and _cooldown<=0.0 and _available() and scene._attention_time<=0.0 and scene.brain.ready_for_activity(delta):
			var kind: String = ["stone","log","tree"][_choice%3]
			_choice += 1
			_cooldown = 5.0 # Bound failed route searches as well as successful play.
			request(kind)
		return
	if not _available() or not is_instance_valid(target):
		cancel("player or world interruption")
		return
	_elapsed += delta
	if phase == "approach":
		if not scene.creature.can_roam() or target.global_position.distance_to(_target_start)>0.25 or (target is RigidBody3D and target.held) or _elapsed>30.0:
			cancel("target moved or approach interrupted")
			return
		while _waypoint<_route.size() and scene.creature.global_position.distance_to(_route[_waypoint])<0.025: _waypoint += 1
		if _waypoint>=_route.size():
			_start()
			return
		if not scene.navigation.motion_safe(scene.creature.global_position,_route[_waypoint],0.85*delta):
			cancel("approach obstructed")
			return
		if scene.creature.walk_step(_route[_waypoint],0.85,delta): _waypoint += 1
		return
	if scene.creature.state != CreatureActor.State.ACTION:
		if _released and scene.creature.can_roam(): _finish()
		else: cancel("actor interrupted")
		return
	if not _released and held == null and target.global_position.distance_to(_target_start)>0.25:
		cancel("target moved before grasp")
		return
	var t: float = scene.creature._age
	if active == "tree": _perform_tree(t)
	else: _perform_throw(t)

func _start() -> void:
	scene.creature.stop_walking()
	scene.creature.global_rotation.y = _facing
	_direction = scene.creature.global_basis.z
	phase = "perform"
	_elapsed = 0.0
	if not scene.creature.perform_action("TreeShake" if active == "tree" else "StoneThrow",4.6):
		cancel("animation unavailable")

func _perform_throw(t: float) -> void:
	if _released: return
	if t<1.05:
		var weight := smoothstep(0.25,0.9,t)
		scene.creature.reach_hand(target.global_position,weight)
		if active == "log":
			scene.creature.reach_hand(target.global_position+target.global_basis.x*0.55,weight,"L")
		return
	if held == null:
		if target.held or target.linear_velocity.length()>0.5:
			cancel("prop no longer available")
			return
		held = target
		_grip_start = held.global_position
		held.grab()
		# Moving the existing body preserves identity, buoyancy and collision.
		if active == "log": held.global_basis = scene.creature.global_basis
	if active == "stone":
		# Blend the last inches into the authored palm to avoid a grasp pop.
		held.global_position = _grip_start.lerp(scene.creature.hand_position(),smoothstep(1.05,1.3,t))
		scene.creature.clear_hand_targets()
	else:
		# Two hands lift a heavy log, draw it back, then shove it outward.
		var local := Vector3(0,1.35,0.85)
		if t>1.9: local = local.lerp(Vector3(0,1.85,0.45),smoothstep(1.9,2.55,t))
		if t>2.55: local = Vector3(0,1.85,0.45).lerp(Vector3(0,1.65,1.35),smoothstep(2.55,2.95,t))
		var grip: Vector3 = scene.creature.global_position+scene.creature.global_basis*local
		held.global_position = _grip_start.lerp(grip,smoothstep(1.05,1.85,t))
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			scene.creature.reach_hand(held.global_position+held.global_basis.x*sign*0.55,1.0,side)
	if t>=2.95:
		# Clear the thrower's collision envelope before enabling flight. This is
		# a launch clearance check, not a scripted trajectory after release.
		var launch: Vector3 = held.global_position
		var ahead: float = (launch-scene.creature.global_position).dot(_direction)
		if ahead<1.05: launch += _direction*(1.05-ahead)
		held.global_position = launch
		held.release(_direction*(6.8 if active == "stone" else 4.5)+Vector3.UP*(3.0 if active == "stone" else 2.5))
		held.hit_cooldown = 0.8
		held = null
		_released = true
		scene.creature.clear_hand_targets()
		scene._show_reaction("!","He can throw things too." if active == "stone" else "A little redecorating.")

func _perform_tree(t: float) -> void:
	if _released: return
	var tree: PlaySpringTree = target
	if t>=0.65 and not _owns_tree:
		if tree.held:
			cancel("tree already held")
			return
		tree.begin_grab()
		_owns_tree = true
		tree_protected = true
		_tree_contacts.clear()
	if _owns_tree:
		# Draw the trunk toward his chest, then let the same spring recoil.
		tree.drag_to(-_direction*2.8*smoothstep(0.7,2.5,t))
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			scene.creature.reach_hand(tree.center(2.1)+scene.creature.global_basis.x*sign*0.16, smoothstep(0.4,0.9,t),side)
	if t>=2.95:
		tree.release()
		_owns_tree = false
		_released = true
		scene.creature.clear_hand_targets()
		scene._show_reaction("!","He has been paying attention.")

func tree_sweep(previous: Vector2, delta: float) -> void:
	# Player and resident releases can both bat loose objects with the crown.
	if scene.spring_tree.held:
		_tree_contacts.clear()
		return
	for body in scene.loose_props.bodies:
		if body.held or _tree_contacts.has(body): continue
		var speed: Vector3 = scene.spring_tree.sweep_contact(previous,body.global_position,delta,false)
		if speed.length()<1.4: continue
		_tree_contacts[body] = true
		body.release((body.linear_velocity+speed*0.55+Vector3.UP*1.0).limit_length(8.0))

func cancel(reason := "player interruption") -> void:
	if not busy(): return
	last_cancel = reason
	if held != null:
		held.release(Vector3.ZERO)
		held.hit_cooldown = 0.8
		held = null
	if _owns_tree:
		scene.spring_tree.cancel()
		_owns_tree = false
		tree_protected = false
	scene.creature.cancel_action()
	scene.creature.clear_hand_targets()
	scene.creature.stop_walking()
	active = ""
	phase = ""
	target = null
	_cooldown = 10.0
	scene.brain.reset_behavior()

func _finish() -> void:
	var kind := active
	active = ""
	phase = ""
	target = null
	_cooldown = 12.0
	scene.brain.reset_behavior()
	history.append(kind)
	completed.emit(kind)

func reset() -> void:
	cancel("reset")
	tree_protected = false
	_tree_contacts.clear()
	_cooldown = 9.0
	_choice = 0
