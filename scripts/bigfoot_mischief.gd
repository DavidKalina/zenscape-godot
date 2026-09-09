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
var _log_faces := PackedVector3Array()
var _log_grip_sign := 1.0
var _log_grasp_pose := Transform3D.IDENTITY
var _carry_route := PackedVector3Array()
var _carry_index := 0
var _carry_distance := 0.0
var _forceful := false
var _toss_pose := Transform3D.IDENTITY


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
	var log_source := preload("res://assets/models/zenscape-bigfoot-log.glb").instantiate()
	var log_player: AnimationPlayer = log_source.find_child("AnimationPlayer",true,false)
	for clip in ["LogLift","LogCarry","LogToss","LogSlam"]:
		if not library.has_animation(clip): library.add_animation(clip,log_player.get_animation(clip).duplicate())
	library.get_animation("LogCarry").loop_mode = Animation.LOOP_LINEAR
	log_source.free()
	var stone_source := preload("res://assets/models/zenscape-bigfoot-stone.glb").instantiate()
	var stone_player: AnimationPlayer = stone_source.find_child("AnimationPlayer",true,false)
	library.add_animation("StoneHeave",stone_player.get_animation("StoneHeave").duplicate())
	stone_source.free()

func furious() -> bool:
	return is_instance_valid(scene.temper) and scene.temper.enraged

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
	elif scene.has_method("mischief_candidates"): candidates.assign(scene.mischief_candidates(kind))
	elif kind == "tree": candidates.append(scene.spring_tree)
	else:
		for body in scene.loose_props.bodies:
			if body.kind == kind: candidates.append(body)
	candidates.sort_custom(func(a: Node3D,b: Node3D): return scene.creature.global_position.distance_squared_to(a.global_position)<scene.creature.global_position.distance_squared_to(b.global_position))
	for item in candidates:
		if kind == "tree":
			if item.held or item.bend.length()>0.08: continue
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
		if kind == "tree": scene.spring_tree = item
		scene.brain.reset_behavior()
		scene.brain.enabled = false
		scene.creature.notice(item.global_position)
		scene._show_reaction("!!" if furious() else "?","He needs to let off some steam." if furious() else "He has an idea of his own.")
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
		if autonomous and _cooldown<=0.0 and _available() and (furious() or (scene._attention_time<=0.0 and scene.brain.ready_for_activity(delta))):
			var kind: String = ["stone","log","tree"][_choice%3]
			_choice += 1
			_cooldown = 1.2 if furious() else 5.0 # Bound failed route searches as well as successful play.
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
			phase = "turn"
			scene.creature.stop_walking()
			return
		if not scene.navigation.motion_safe(scene.creature.global_position,_route[_waypoint],scene.creature.walking_speed(0.85)*minf(delta,0.05)):
			cancel("approach obstructed")
			return
		if scene.creature.walk_step(_route[_waypoint],0.85,delta): _waypoint += 1
		return
	if phase == "turn":
		if not scene.creature.can_roam() or target.global_position.distance_to(_target_start)>0.25:
			cancel("interrupted turn")
		elif scene.creature.turn_step(_facing,delta): _start()
		return
	if active == "log" and phase == "carry":
		_carry_log(delta)
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
	elif active == "log": _perform_log(t)
	else: _perform_throw(t)

func _start() -> void:
	_forceful = furious()
	scene.creature.stop_walking()
	_direction = scene.creature.global_basis.z
	if active == "log":
		_log_grip_sign = 1.0 if target.global_basis.x.dot(scene.creature.global_basis.x)>=0.0 else -1.0
		_log_faces = target.visual.transform*target.visual.mesh.get_faces()
	phase = "perform"
	_elapsed = 0.0
	if not scene.creature.perform_action("LogLift" if active == "log" else "TreeShake" if active == "tree" else "StoneHeave",4.6 if active != "log" else 5.0):
		cancel("animation unavailable")

func _stone_hand(point: Vector3, weight: float) -> void:
	var actor: CreatureActor = scene.creature
	var right := actor.global_basis.x
	var palm_basis := Basis(right,Vector3.UP.cross(right),Vector3.UP)
	actor.reach_hand(point-Vector3.UP*target.radius*0.75,weight,"R",actor.to_global(Vector3(-0.95,1.85,0.1)),palm_basis)

func _perform_throw(t: float) -> void:
	var actor: CreatureActor = scene.creature
	var chest: Vector3 = actor.to_global(Vector3(-0.55,1.8,0.65))
	var cocked: Vector3 = actor.to_global(Vector3(-0.65,2.55,-0.15))
	var release: Vector3 = actor.to_global(Vector3(-0.55,2.3,1.25))
	if _released:
		var follow: Vector3 = actor.to_global(Vector3(-0.25,1.7,1.1))
		_stone_hand(release.lerp(follow,smoothstep(2.95,3.35,t)),1.0-smoothstep(3.2,4.15,t))
		return
	if held == null:
		_stone_hand(target.global_position,smoothstep(0.25,0.95,t))
		if t<1.05: return
		if target.held or target.linear_velocity.length()>0.5:
			cancel("prop no longer available")
			return
		held = target
		_grip_start = held.global_position
		held.grab()
	var point := _grip_start.lerp(chest,smoothstep(1.05,1.85,t))
	if t>1.85: point = chest.lerp(cocked,smoothstep(1.85,2.55,t))
	if t>2.55: point = cocked.lerp(release,smoothstep(2.55,2.95,t))
	held.global_position = point
	_stone_hand(point,1.0)
	if t>=2.95:
		_release_prop(_direction*6.8+Vector3.UP*3.0)
		scene._show_reaction("!","He can throw things too.")

func _release_prop(velocity: Vector3) -> void:
	held.release(velocity*(2.8 if furious() else 1.0),2.0 if furious() else 1.0)
	held.hit_cooldown = 0.8
	held = null
	_released = true

func _log_hands(pose: Transform3D, right_weight := 1.0, left_weight := 1.0) -> void:
	var actor: CreatureActor = scene.creature
	var axis := pose.basis.x*_log_grip_sign
	# Approach the near surface instead of putting palm centers on the log's
	# centerline. Under the shoulder, that near surface becomes the underside.
	var toward_body: Vector3 = -actor.global_basis.z+Vector3.DOWN*0.5
	var outward := (toward_body-axis*toward_body.dot(axis)).normalized()
	var normal := -outward
	var palm_basis := Basis(axis,normal.cross(axis).normalized(),normal).orthonormalized()
	for side in ["R","L"]:
		var sign := -1.0 if side == "R" else 1.0
		var center := pose.origin+axis*sign*0.55
		var point := _log_surface(pose,center,outward)
		var receive := smoothstep(3.3,3.8,actor._age)*(1.0-smoothstep(4.15,4.65,actor._age)) if phase=="perform" else 0.0
		var elbow: Vector3 = actor.to_global(Vector3(sign*0.9,1.2+0.7*receive,0.35+0.25*receive))
		actor.reach_hand(point,right_weight if side == "R" else left_weight,side,elbow,palm_basis)

func _log_surface(pose: Transform3D, center: Vector3, outward: Vector3) -> Vector3:
	# The visible trunk is slimmer than its capsule (which includes branches).
	# Cache its triangles once, then fit each palm to the actual near surface.
	var inverse := pose.affine_inverse()
	var start: Vector3 = inverse*(center+outward*0.8)
	var end: Vector3 = inverse*(center-outward*0.5)
	var nearest: Variant = null
	var distance := INF
	for i in range(0,_log_faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,end,_log_faces[i],_log_faces[i+1],_log_faces[i+2])
		if hit != null and start.distance_squared_to(hit)<distance:
			nearest = hit
			distance = start.distance_squared_to(hit)
	return pose*nearest+outward*0.015 if nearest != null else center+outward*0.3

func _shoulder_pose() -> Transform3D:
	var actor: CreatureActor = scene.creature
	var shoulder := actor.skeleton.find_bone("UpperArm_R")
	var anchor: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(shoulder).origin)
	var basis: Basis = actor.global_basis*Basis(Vector3.UP,PI*0.5)*Basis(Vector3.FORWARD,-0.12)
	if _log_grip_sign<0.0: basis *= Basis(Vector3.UP,PI)
	return Transform3D(basis,anchor+actor.global_basis*Vector3(-0.02,0.34,-0.22))

func _perform_log(t: float) -> void:
	if phase == "toss":
		# Drive the shouldered log forward along its length, keeping its heading.
		var forward := Transform3D(_toss_pose.basis,_toss_pose.origin+scene.creature.global_basis*Vector3(0,0.2,1.05))
		var pose := _toss_pose.interpolate_with(forward,smoothstep(0.15,0.78,t))
		if _forceful:
			var loaded := Transform3D(_toss_pose.basis,_toss_pose.origin+scene.creature.global_basis*Vector3(0,-0.08,-0.22))
			pose = _toss_pose.interpolate_with(loaded,smoothstep(0.0,0.3,t))
			if t>0.3: pose = loaded.interpolate_with(forward,smoothstep(0.34,0.78,t))
		if not _released:
			held.global_transform = pose
			_log_hands(pose,1.0,0.0)
			if t>=0.78:
				_release_prop(scene.creature.global_basis.z*(6.0 if _forceful else 4.5)+Vector3.UP*(3.0 if _forceful else 2.5))
				scene._show_reaction("!","That should go over there.")
		else:
			_log_hands(forward,1.0-smoothstep(0.9,1.65,t),0.0)
		return
	if held == null:
		_log_hands(target.global_transform,smoothstep(0.25,1.0,t),smoothstep(0.4,1.1,t))
		if t<1.15: return
		if target.held or target.linear_velocity.length()>0.5:
			cancel("log moved before grasp")
			return
		held = target
		_log_grasp_pose = held.global_transform
		held.grab()
	var cradle: Transform3D = scene.creature.global_transform*Transform3D(Basis(Vector3.UP,PI if _log_grip_sign<0.0 else 0.0),Vector3(0,1.25,0.9))
	var pose := _log_grasp_pose.interpolate_with(cradle,smoothstep(1.3,2.35,t))
	# Lift in front first; only swing the long axis across his head once clear.
	# A direct cradle-to-shoulder blend sweeps the trunk through his face.
	var overhead := cradle
	overhead.origin = scene.creature.to_global(Vector3(0,3.65,0.9))
	var above_shoulder := _shoulder_pose()
	above_shoulder.origin.y = overhead.origin.y
	if t>2.35: pose = cradle.interpolate_with(overhead,smoothstep(2.35,3.05,t))
	if t>3.05: pose = overhead.interpolate_with(above_shoulder,smoothstep(3.05,3.6,t))
	if t>3.6: pose = above_shoulder.interpolate_with(_shoulder_pose(),smoothstep(3.6,4.55,t))
	held.global_transform = pose
	_log_hands(pose,1.0,1.0-smoothstep(3.05,3.55,t))
	if t>=4.7:
		scene.creature.cancel_action()
		_plan_carry()
		phase = "carry"
		_elapsed = 0.0
		_carry_distance = 0.0
		scene._show_reaction("…","He has somewhere to put this.")

func _plan_carry() -> void:
	_carry_route.clear()
	_carry_index = 0
	var actor: CreatureActor = scene.creature
	# Stay close and favor the direction he's already facing. Never walk a
	# loaded actor across unchecked water, steep edges or a newly moved prop.
	for angle in [0.0,0.5,-0.5,1.0,-1.0]:
		var direction := Basis(Vector3.UP,angle)*actor.global_basis.z
		var ground: Variant = scene._probe_ground(actor.global_position+direction*2.2)
		if ground == null or not scene.valid_landing(ground): continue
		if not scene.navigation.segment_safe(actor.global_position,ground): continue
		_carry_route = PackedVector3Array([ground])
		return

func _carry_log(delta: float) -> void:
	if not scene.creature.can_roam():
		cancel("carry interrupted")
		return
	var finished := _carry_route.is_empty() or _elapsed>5.0
	if not finished:
		var next: Vector3 = _carry_route[_carry_index]
		if not scene.navigation.motion_safe(scene.creature.global_position,next,scene.creature.walking_speed(0.65)*minf(delta,0.05)): finished = true
		else:
			var before: Vector3 = scene.creature.global_position
			finished = scene.creature.walk_step(next,0.65,delta,"LogCarry")
			_carry_distance += before.distance_to(scene.creature.global_position)
	held.global_transform = _shoulder_pose()
	_log_hands(held.global_transform,1.0,0.0)
	if finished:
		_toss_pose = held.global_transform
		scene.creature.stop_walking()
		phase = "toss"
		if not scene.creature.perform_action("LogSlam" if _forceful else "LogToss",1.85): cancel("toss interrupted")

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
	if _owns_tree:
		# Draw the trunk toward his chest, then let the same spring recoil.
		tree.drag_to(-_direction*(5.0 if _forceful else 2.8)*smoothstep(0.7,2.5,t))
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			scene.creature.reach_hand(tree.center(2.1)+scene.creature.global_basis.x*sign*0.16, smoothstep(0.4,0.9,t),side)
	if t>=2.95:
		tree.release()
		_owns_tree = false
		_released = true
		scene.creature.clear_hand_targets()
		scene._show_reaction("!","He has been paying attention.")

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
	_cooldown = 1.0 if furious() else 12.0
	scene.brain.reset_behavior()
	history.append(kind)
	completed.emit(kind)

func reset() -> void:
	cancel("reset")
	tree_protected = false
	_cooldown = 9.0
	_choice = 0
