extends Node
## One owner for quiet environmental activities. Uses real safe routes and
## scenery bounds; physical interruptions always take precedence.
const TREES := ["tree","layered_tree","broadleaf","redwood","bigfoot_tree"]
const TREE_HUG = preload("res://scripts/bigfoot_tree_hug.gd")
const TREE_TOUCH = preload("res://scripts/bigfoot_tree_touch.gd")
var _touch_start := Vector3.ZERO
const FIRE = preload("res://scripts/bigfoot_fire.gd")
## Fire sits just below lightning: it cancels everything else, but a strike
## still gets its own frame first. Inert until the scene owns a `_fire_field`.
var fire: Node
var _hug_variant := {}
var _hug_start := {}
var _hug_elbows := {}
var _hug_count := 0
var _peek_side := 1.0
var _peek_target := Vector3.ZERO
var _arrive_left := 0.0
var scene: Node
var active := ""
var phase := ""
var target := {}
var history: Array[String] = []
var autonomous := true
var arrival_pending := false
var arrival_elapsed := 0.0
var _arrival_facing := Basis.IDENTITY
var _watched_tree: PlaySpringTree
var _tree_response_after := 0.0
var _clock := 0.0
var _elapsed := 0.0
var _next := 14.0
var _choice := 0
var _route := PackedVector3Array()
var _waypoint := 0
var _look := Vector3.ZERO
var _duration := 6.0
var _cooldowns := {}
var _strike := Vector3.ZERO
var _pending_strike := false
var _last_meteor := -1
var _wet := false
var _dry_pending := false
var _facing := 0.0
var _sparks := MeshInstance3D.new()
var _spark_mesh := ImmediateMesh.new()

func setup(world: Node) -> void:
	scene = world
	scene._lightning.struck.connect(_on_strike)
	scene.creature.action_finished.connect(_finished)
	_sparks.mesh = _spark_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("bcefff")
	material.emission_enabled = true
	material.emission = Color("70cfff")
	material.emission_energy_multiplier = 3.0
	_sparks.material_override = material
	add_child(_sparks)
	_sparks.hide()
	fire = FIRE.new()
	add_child(fire)
	fire.setup(scene,self)

func _on_strike(point: Vector3) -> void:
	if not scene.resident_enabled: return
	# Store the nearest flash while paused; the simulation consumes it once.
	if not _pending_strike or point.distance_to(scene.creature.position)<_strike.distance_to(scene.creature.position):
		_strike = point
	_pending_strike = true

func busy() -> bool: return not active.is_empty()

## Only deliberate player releases invite this response; ordinary wind does not.
func notice_tree_release(tree: PlaySpringTree, strength: float) -> bool:
	if not is_instance_valid(tree) or not is_finite(strength) or strength<0.04: return false
	if scene._paused or not scene.resident_enabled or _clock<_tree_response_after: return false
	if scene.has_method("resident_activity_owned") and scene.resident_activity_owned(): return false
	if busy() or _routine_busy() or not scene.creature.can_roam(): return false
	if scene.creature.global_position.distance_to(tree.global_position)>8.0: return false
	arrival_pending = false
	_watched_tree = tree
	_tree_response_after = _clock+9.0
	var look := tree.center(minf(tree.tree_height*0.6,3.0))
	_begin("tree_startle" if strength>=0.55 else "tree_curious",look,4.2)
	return true

## Placement offers a short, interruptible introduction before normal choices.
## Landing keeps its authored motion; surveying begins only on solid ground.
func welcome_arrival() -> void:
	cancel()
	scene.routine.cancel("arriving in a place")
	scene.brain.reset_behavior()
	arrival_pending = true
	arrival_elapsed = 0.0
	_arrival_facing = scene.creature.basis

func _advance_arrival(dt: float) -> bool:
	var actor: CreatureActor = scene.creature
	if actor.state == CreatureActor.State.LANDING: return true
	if not actor.can_roam():
		arrival_pending = false
		return false
	arrival_elapsed += dt
	# A quiet beat lets the landing finish before his attention moves outward.
	if arrival_elapsed > 0.8:
		var sweep := sin(clampf((arrival_elapsed-0.8)/3.2,0.0,1.0)*TAU)*0.42
		var direction := _arrival_facing*Vector3(sin(sweep),0.08,cos(sweep))
		actor.track_gaze(actor.position+Vector3.UP*1.9+direction*5.0)
	if arrival_elapsed < 4.0: return true
	arrival_pending = false
	# Existing contact selection owns bounds, reachability and the approach.
	if request("tree_touch"): return true
	_next = _clock+8.0
	scene.brain.reset_behavior()
	return false

func advance(delta: float) -> bool:
	if delta<=0.0 or scene._paused: return busy()
	var dt := minf(delta,0.05)
	_clock += dt
	var actor: CreatureActor = scene.creature
	var owned: bool = scene.has_method("resident_activity_owned") and scene.resident_activity_owned()
	if _pending_strike:
		_pending_strike = false
		var distance := actor.global_position.distance_to(_strike)
		if not owned and distance<12.0 and (actor.can_roam() or actor.state == CreatureActor.State.ACTION):
			cancel()
			if scene.routine != null: scene.routine.cancel("lightning")
			if actor.can_roam():
				_begin("shock" if distance<1.8 else "startle",_strike+Vector3.UP*4.0,3.8 if distance<1.8 else 2.8)
	if fire != null:
		# Fire outranks every quiet activity below it. While it owns the actor
		# this controller is silent; while it merely walks him to the ash it
		# reports "not observing" so the brain keeps driving the journey.
		var burning: bool = fire.advance(dt,owned)
		if burning or fire.busy():
			if busy() or arrival_pending: cancel()
			return burning
	if owned or (not actor.can_roam() and actor.state != CreatureActor.State.ACTION):
		if arrival_pending and not owned and actor.state == CreatureActor.State.LANDING:
			return true
		cancel()
		return false
	if arrival_pending: return _advance_arrival(dt)
	if busy():
		if active in ["tree_curious","tree_startle"]:
			if not is_instance_valid(_watched_tree) or _watched_tree.held:
				cancel()
				return false
			_look = _watched_tree.center(minf(_watched_tree.tree_height*0.6,3.0))
		_elapsed += dt
		if _elapsed>35.0 or (not target.is_empty() and not _target_valid()):
			cancel()
			return false
		if phase == "approach":
			if _waypoint>=_route.size():
				actor.stop_walking()
				phase = "turn"
			elif not scene.navigation.motion_safe(actor.position,_route[_waypoint],actor.walking_speed(0.65)*dt):
				cancel()
			elif actor.walk_step(_route[_waypoint],0.65,dt): _waypoint += 1
		elif phase == "turn":
			actor.track_gaze(Vector3(_look.x,actor.global_position.y+2.15,_look.z) if active == "tree_hug" else _look)
			if actor.turn_step(_facing,dt):
				if active in ["tree_hug","tree_touch"]:
					phase = "plant"
					_arrive_left = 0.35
				else: _perform()
		elif phase == "plant":
			# Level the head before reaching; an inherited downward gaze drives
			# the forehead into bark before the peek has even begun.
			actor.track_gaze(Vector3(_look.x,actor.global_position.y+2.15,_look.z))
			_arrive_left -= dt
			if _arrive_left<=0.0: _perform()
		elif phase == "perform": _pose(dt)
		return busy()
	if not autonomous or not actor.can_roam() or _routine_busy(): return false
	var rain: float = scene._precipitation.state.x
	var snow: float = scene._precipitation.state.y
	if rain>0.2: _wet = true
	if _wet and rain<0.04:
		_wet = false
		_dry_pending = true
	var celestial = scene._celestial
	var meteor: Dictionary = celestial.meteor
	if not meteor.is_empty() and meteor.head.y>0.05 and int(meteor.window)!=_last_meteor and _ready_for("meteor"):
		# Only catch a streak already in his forward field of view.
		if actor.global_basis.z.dot(meteor.head)>0.35:
			_last_meteor = int(meteor.window)
			_begin("meteor",actor.position+meteor.head*80.0,2.4)
			return busy()
	if _clock<_next or not scene.brain.ready_for_activity(dt): return false
	if _dry_pending and _ready_for("dry"):
		_dry_pending = false
		_begin("dry",actor.position+actor.basis.z*3.0,3.8)
	elif maxf(rain,snow)>0.18 and _ready_for("rain"):
		_begin("rain" if rain>=snow else "snow",actor.position+actor.basis.z*3.0+Vector3.UP*4.0,6.5)
	elif float(celestial.state.get("zs_bow",0.0))*celestial._rainbow_growth>0.12 and _ready_for("rainbow"):
		_begin("rainbow",actor.position+celestial.rainbow_direction()*80.0,8.0)
	else:
		var kind: String = ["tree_hug","horizon","tree_touch","horizon"][_choice%4]
		_choice += 1
		if not request(kind): _next = _clock+5.0
	return busy()

func _ready_for(kind: String) -> bool:
	return _clock>=float(_cooldowns.get(kind,0.0))

## Cave visits and needs-driven surface actions can own him without setting
## the legacy routine's active verb. Emergencies above still take precedence.
func _routine_busy() -> bool:
	if not scene.routine.active.is_empty(): return true
	var living: Variant = scene.routine.get("living")
	var cave: Variant = scene.routine.get("cave")
	return (living != null and not living.current.is_empty()) or (cave != null and not cave.phase.is_empty())

## Also used by the repeatable visual study; never teleports to a contact.
func request(kind: String) -> bool:
	if busy() or scene._paused or not scene.creature.can_roam() or _routine_busy(): return false
	if scene.has_method("resident_activity_owned") and scene.resident_activity_owned(): return false
	if kind not in ["tree_hug","tree_touch","horizon"]: return false
	if kind == "horizon": return _viewpoint()
	var candidates: Array = scene.habitat.interests.filter(func(item: Dictionary) -> bool:
		return item.get("kind","") in TREES and item.has("bounds") and _ready_for(str(item.id)))
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return scene.creature.position.distance_squared_to(a.position)<scene.creature.position.distance_squared_to(b.position))
	for item: Dictionary in candidates.slice(0,8):
		var box: AABB = item.bounds
		var radius := maxf(box.size.x,box.size.z)*0.5
		# Never stretch arms around a trunk wider than their span.
		# Contact height follows the exposed trunk, including young trees.
		if radius>0.65 or box.end.y<item.position.y+1.15: continue
		var center := Vector3(box.get_center().x,item.position.y,box.get_center().z)
		if scene.creature.position.distance_to(center)>10.0: continue
		var toward: Vector3 = center-scene.creature.position
		var yaw := atan2(toward.x,toward.z)
		for i in range(8):
			var angle := yaw+float(i)*TAU/8.0
			var point: Variant = scene.navigation._ground(center-Basis(Vector3.UP,angle).z*(radius+0.64))
			if point == null or absf(point.y-center.y)>0.3 or not scene.navigation.is_safe(point): continue
			var route: PackedVector3Array = scene.navigation.path(scene.creature.position,point)
			if route.is_empty(): continue
			target = item.duplicate()
			target.center = center
			target.radius = radius
			target.contact_height = clampf(box.end.y-center.y-0.22,1.0,1.75)
			_travel(kind,route,center+Vector3.UP*1.9,7.5 if kind == "tree_hug" else TREE_TOUCH.DURATION)
			return true
	return false

func _viewpoint() -> bool:
	var origin: Vector3 = scene.creature.position
	var candidates: Array[Vector3] = []
	for point: Vector3 in scene.navigation._nodes:
		var edge := maxf(absf(point.x),absf(point.z))
		if edge<10.0 or edge>12.5 or origin.distance_to(point)>10.0 or origin.distance_to(point)<1.5: continue
		candidates.append(point)
	candidates.sort_custom(func(a: Vector3,b: Vector3) -> bool:
		return a.y*2.0-origin.distance_to(a)*0.2>b.y*2.0-origin.distance_to(b)*0.2)
	for point in candidates.slice(0,8):
		var route: PackedVector3Array = scene.navigation.path(origin,point)
		if route.is_empty(): continue
		var outward := Vector3(point.x,0,point.z).normalized()
		_travel("horizon",route,point+outward*60.0+Vector3.UP*5.0,10.0)
		return true
	return false

func _travel(kind: String, route: PackedVector3Array, look: Vector3, duration: float) -> void:
	scene.brain.reset_behavior()
	active = kind
	phase = "approach"
	_route = route
	_waypoint = 0
	_elapsed = 0.0
	_look = look
	_duration = duration
	var offset := look-route[-1]
	_facing = atan2(offset.x,offset.z)
	scene.creature.notice(look)

func _begin(kind: String, look: Vector3, duration: float) -> void:
	scene.brain.reset_behavior()
	scene.creature.stop_walking()
	active = kind
	_look = look
	_duration = duration
	_elapsed = 0.0
	var offset: Vector3 = look-scene.creature.position
	_facing = atan2(offset.x,offset.z)
	phase = "turn"
	if kind in ["shock","startle","meteor","tree_startle"]: _perform()

func _perform() -> void:
	phase = "perform"
	_elapsed = 0.0
	var clip := "Idle"
	if active == "tree_touch": _touch_start = scene.creature.hand_position("R")
	if active == "tree_hug":
		_hug_count += 1
		_hug_variant = TREE_HUG.make_variant(_hug_count*4707+str(target.get("id","")).hash())
		_duration = TREE_HUG.duration(_hug_variant)
		clip = "TreeHugBase"
		var camera := scene.get_viewport().get_camera_3d()
		_peek_target = camera.global_position if camera != null else scene.creature.to_global(Vector3(2,2.5,8))
		_peek_side = 1.0 if scene.creature.to_local(_peek_target).x>=0.0 else -1.0
		scene.creature.prepare_tree_hug_base()
		for side in ["R","L"]:
			_hug_start[side] = scene.creature.hand_position(side)
			var skeleton: Skeleton3D = scene.creature.skeleton
			_hug_elbows[side] = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Forearm_"+side)).origin)
	if not scene.creature.perform_action(clip,_duration):
		cancel()
		return
	scene.creature.environment_pose = active
	scene.brain.reaction.emit("!" if active in ["shock","startle"] else "",active.replace("_"," "))

func _target_valid() -> bool:
	if scene.has_method("resident_activity_owned") and str(target.id).begins_with("object:"):
		var physical: Node3D = scene.world_play._active.get(int(str(target.id).trim_prefix("object:")))
		if is_instance_valid(physical) and physical is PlaySpringTree:
			if physical.held or physical.bend.length()>0.04 or physical.global_position.distance_to(target.position)>0.08: return false
	for item: Dictionary in scene.habitat.interests:
		if item.id == target.id:
			return item.position.distance_to(target.position)<0.05 and item.get("bounds",AABB()).is_equal_approx(target.bounds)
	return false

func _pose(delta := 0.0) -> void:
	var actor: CreatureActor = scene.creature
	# Match the animation time the actor will render on this simulation tick.
	var t := actor._age+minf(delta,0.05)*actor.action_tempo
	var weight := smoothstep(0.0,0.9,t)*(1.0-smoothstep(_duration-1.2,_duration,t))
	actor.clear_hand_targets()
	if active == "meteor" and not scene._celestial.meteor.is_empty():
		_look = actor.position+scene._celestial.meteor.head*80.0
	if active == "rainbow":
		if float(scene._celestial.state.get("zs_bow",0.0))<0.04:
			cancel()
			return
		_look = actor.position+scene._celestial.rainbow_direction()*80.0
	var gaze := _look
	if active == "horizon": gaze += actor.basis.x*sin(t*0.45)*22.0
	if active != "tree_hug": actor.track_gaze(gaze)
	if active == "tree_hug":
		_pose_tree_hug(actor,t)
	elif active == "tree_touch":
		var motion: Dictionary = TREE_TOUCH.sample(t)
		actor.environment_motion = motion
		var radius: float = target.radius
		var center: Vector3 = target.center+Vector3.UP*(float(target.get("contact_height",1.75))-0.1)
		var contact := center-actor.basis.x*radius*0.94+actor.basis.z*radius*0.34
		var point := _touch_start.lerp(contact,float(motion.reach))
		point -= actor.basis.x*float(motion.arc)*0.18
		# Peel down and outward, then return to the resting palm before releasing IK.
		var release: float = motion.release
		point = point.lerp(_touch_start,release)
		point -= Vector3.UP*sin(release*PI)*0.12
		var elbow := center-actor.basis.x*(radius+0.48)-actor.basis.z*0.32
		actor.reach_hand(point,float(motion.weight),"R",elbow)
		actor.track_gaze(_look.lerp(actor.position+actor.basis.x*3.0+actor.basis.z*3.0+Vector3.UP*2.1,float(motion.glance_away)))
	elif active in ["horizon","rainbow"]:
		actor.reach_hand(actor.to_global(Vector3(-0.32,2.65,0.4)),weight*0.95,"R",actor.to_global(Vector3(-1.0,2.1,0.2)),Basis(-actor.basis.z,actor.basis.x,-actor.basis.y))
	elif active in ["rain","snow"]:
		actor.reach_hand(actor.to_global(Vector3(-0.55,1.65,0.85)),weight,"R",null,Basis(-actor.basis.x,actor.basis.z,actor.basis.y))
		if active == "rain": actor.reach_hand(actor.to_global(Vector3(0.2,2.88,0.13)),weight,"L",null,Basis(actor.basis.z,-actor.basis.x,-actor.basis.y))
	elif active in ["startle","shock"]:
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			var jitter := sin(t*65.0)*0.09 if active == "shock" else 0.0
			actor.reach_hand(actor.to_global(Vector3(sign*(0.48+jitter),2.48+jitter,0.25)),smoothstep(0.0,0.12,t)*(1.0-smoothstep(_duration-1.3,_duration,t)),side)
		if active == "shock": _electric_arcs(t,weight)
	elif active == "dry":
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			actor.reach_hand(actor.to_global(Vector3(sign*0.85,1.05+sin(t*18.0)*0.15,0.2)),weight,side)

func _pose_tree_hug(actor: CreatureActor, t: float) -> void:
	var motion: Dictionary = TREE_HUG.sample(t,_hug_variant)
	var peek: float = motion.peek
	var look: float = motion.peek_look
	var local_target := actor.to_local(_peek_target)
	var head: Vector3 = motion.head
	head.y = clampf(atan2(local_target.x-_peek_side*0.3*peek,local_target.z),-0.65,0.65)*look
	head.z = _peek_side*(0.13*peek-0.045*look)
	motion.head = head
	motion.spine.z -= _peek_side*0.19*peek
	var normalized_time := t/_duration
	var backoff := smoothstep(0.03,0.22,normalized_time)*(1.0-smoothstep(0.75,1.0,normalized_time))
	motion.body_offset = Vector3(_peek_side*0.09*peek,0,-0.09*backoff)
	motion.tree_center = target.center
	motion.tree_radius = target.radius
	motion.tree_top = target.get("bounds",AABB(Vector3.ZERO,Vector3(0,5,0))).end.y
	actor.environment_motion = motion
	var radius: float = target.radius
	for side in ["R","L"]:
		var hand: Dictionary = motion.hands[side]
		var sign := -1.0 if side == "R" else 1.0
		var center: Vector3 = target.center+Vector3.UP*(float(target.get("contact_height",1.75))+(-0.1 if side == "R" else 0.07))
		var radial: Vector3 = actor.basis.x*sign*0.94+actor.basis.z*0.34
		var contact := center+radial*radius
		var start: Vector3 = _hug_start.get(side,actor.hand_position(side))
		# The long forearm rises close to the body; only a little extra room is
		# needed around the trunk. Keep release separate: peel, then drop.
		var release: float = hand.release
		var point := start.lerp(contact,float(hand.approach))
		point += (actor.basis.x*sign*0.08+Vector3.UP*0.035)*float(hand.arc)
		if release>0.0:
			# Space the vertical controls evenly: the time curve already eases
			# the descent. Bunching both controls at the ends doubles that ease
			# and turns the middle into a sudden drop.
			var peel := contact.lerp(start,1.0/3.0)+radial*0.07
			var fall := contact.lerp(start,2.0/3.0)+actor.basis.z*0.06
			var u := 1.0-release
			point = contact*u*u*u+peel*3.0*u*u*release+fall*3.0*u*release*release+start*release*release*release
		var contact_elbow := center+actor.basis.x*sign*(radius+0.48)-actor.basis.z*0.32
		var elbow: Vector3 = _hug_elbows.get(side,contact_elbow)
		var elbow_weight := smoothstep(0.20,0.95,float(hand.approach))*(1.0-smoothstep(0.12,1.0,release))
		elbow = elbow.lerp(contact_elbow,elbow_weight)
		var fingers := (actor.basis.x*-sign*0.34+actor.basis.z*0.94).normalized()
		var normal := -radial.normalized()
		var palm := Basis(fingers.cross(normal).normalized(),fingers,normal)
		# The actor blends this surface basis against its freshly solved natural
		# wrist. Rest belongs to the forearm, never to a fixed world orientation.
		var wrist_weight := smoothstep(0.4,0.95,float(hand.approach))*(1.0-smoothstep(0.06,0.75,release))
		actor.reach_hand(point,float(hand.weight),side,elbow,palm,wrist_weight)

func _electric_arcs(t: float, weight: float) -> void:
	_spark_mesh.clear_surfaces()
	_sparks.visible = weight>0.05
	if not _sparks.visible: return
	_sparks.global_transform = scene.creature.global_transform
	_spark_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for side in [-1.0,1.0]:
		for i in range(8):
			var y := 0.6+float(i)*0.24
			var a := Vector3(side*(0.56+sin(t*53+i*2.7)*0.12),y,0.36)
			var b := Vector3(side*(0.56+sin(t*53+(i+1)*2.7)*0.12),y+0.24,0.36)
			_spark_mesh.surface_add_vertex(a)
			_spark_mesh.surface_add_vertex(b)
	_spark_mesh.surface_end()

func _finished(_clip: String, cancelled: bool) -> void:
	if not busy() or phase != "perform": return
	if not cancelled:
		history.append(active)
		if history.size()>32: history.pop_front()
	_clear()

func cancel() -> void:
	arrival_pending = false
	var performing := busy() and phase == "perform"
	_clear()
	if performing and scene.creature.state == CreatureActor.State.ACTION: scene.creature.cancel_action()

func _clear() -> void:
	_watched_tree = null
	if not active.is_empty():
		_cooldowns[active] = _clock+45.0
		if active == "snow": _cooldowns.rain = _clock+45.0
		if not target.is_empty(): _cooldowns[str(target.id)] = _clock+80.0
		scene.creature.clear_hand_targets()
		scene.creature.environment_pose = ""
		scene.creature.environment_motion = {}
		scene.creature.stop_walking()
	active = ""
	phase = ""
	target = {}
	_route.clear()
	_hug_start.clear()
	_hug_elbows.clear()
	_sparks.hide()
	_next = _clock+12.0

func world_changed() -> void:
	cancel()
	_pending_strike = false
	if fire != null: fire.world_changed()
