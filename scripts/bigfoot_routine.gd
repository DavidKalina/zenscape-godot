extends Node
## Daily activities own their approaches and authored performances; CreatureBrain
## supplies curiosity and wandering between activities.
var habits = preload("res://scripts/bigfoot_habits.gd").new()
var crossing_wish = preload("res://scripts/bigfoot_crossing_wish.gd").new()
var _tended := false
var _tending := false
var scene: Node
var active := ""
var target := {}
var _phase := ""
var _clock := 0.0
var _next_action := 8.0
var _choice := 0
var _elapsed := 0.0
var _approach_path := PackedVector3Array()
var _approach_index := 0
var _approach_hops := {}
var _hop_pending := false
var _held: Node3D
var _catch_payload := {}
var _released := false
var _taking_stone := false
var _rest_normal := Vector3.UP
var _rest_yaw := 0.0
var _rest_upright := Basis.IDENTITY
var _rest_tilt := Basis.IDENTITY
var _tree_rest := Transform3D.IDENTITY
var _tree_parts: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _sleep_marks: Array[Label3D] = []
var _cooldowns := {}
var history: Array[String] = []
var last_cancel := ""
const ORDER := ["stone","tree","sit","fish","sleep"]

func setup(owner_scene: Node) -> void:
	scene = owner_scene
	habits.setup(scene)
	add_child(crossing_wish)
	crossing_wish.setup(self)
	scene.creature.action_finished.connect(_action_finished)
	scene.creature.state_changed.connect(func(state: CreatureActor.State) -> void:
		if state == CreatureActor.State.STUMBLING and not active.is_empty(): cancel("ground tremor"))
	for i in range(3):
		var label := Label3D.new()
		label.text = "Z"
		label.font_size = 38+i*8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visible = false
		add_child(label)
		_sleep_marks.append(label)

## Returns true while an authored action owns the actor.
func advance(delta: float) -> bool:
	var dt := minf(delta,0.05)
	_clock += dt
	_advance_projectiles(dt)
	if not active.is_empty():
		_elapsed += dt
		if _phase == "approach":
			if _approach_hops.has(_approach_index):
				var actor: CreatureActor = scene.creature
				var from: Vector3 = _approach_path[_approach_index-1]
				var to: Vector3 = _approach_path[_approach_index]
				if not preload("res://scripts/stepping_route.gd").hop_safe(scene.navigation,from,to):
					cancel("stepping stone changed")
					return false
				if _hop_pending:
					if actor.state in [CreatureActor.State.HOPPING,CreatureActor.State.LANDING]: return true
					if not actor.can_roam() or actor.position.distance_to(to)>0.05:
						cancel("hop interrupted")
						return false
					_hop_pending = false
					_approach_index += 1
				else:
					_hop_pending = actor.begin_hop(to)
					return _hop_pending
			while _approach_index < _approach_path.size() and scene.creature.position.distance_squared_to(_approach_path[_approach_index])<0.000001:
				_approach_index += 1
			if _approach_hops.has(_approach_index): return true
			if not _target_exists() or _elapsed > 30.0:
				cancel("target changed or approach timeout")
			elif _approach_index >= _approach_path.size():
				_start_performance()
			else:
				var destination := _approach_path[_approach_index]
				if not scene.navigation.motion_safe(scene.creature.position,destination,scene.creature.walking_speed(0.85)*dt):
					scene.navigation.reject_segment(_approach_path[maxi(0,_approach_index-1)],destination)
					_approach_path = scene.navigation.path(scene.creature.position,_approach_path[-1])
					_approach_hops.clear()
					_approach_index = 0
					if _approach_path.is_empty(): cancel("no safe approach after terrain edge rejection")
				elif scene.creature.walk_step(destination,0.85,dt): _approach_index += 1
			return not active.is_empty()

		if _phase == "inspect_home":
			if _elapsed >= 2.0:
				if not _rest_stance(scene.creature.position): cancel("home ground changed")
				else:
					habits.claim(scene.creature.position)
					_start_performance(true)
			return not active.is_empty()

		if _phase == "perform":
			_effects(dt)
			return true
	if crossing_wish.advance(dt): return true
	if _clock < _next_action or not scene.creature.can_roam(): return false
	if not scene.brain.ready_for_activity(dt): return false
	var kind: String = ORDER[_choice%ORDER.size()]
	_choice += 1
	if kind == "sleep" and _choice%10 == 0: kind = "hibernate"
	if not request(kind): _next_action = _clock+3.0
	return not active.is_empty()

func request(kind: String, chosen: Dictionary = {}, invited := false) -> bool:
	if kind in ["stone","tree"] and scene.has_method("resident_activity_owned"): return false
	if not active.is_empty() or not scene.creature.can_roam(): return false
	if kind in ["sit","sleep","hibernate"]:
		if chosen.has("rest_point"):
			var point: Vector3 = chosen.rest_point
			if not _rest_stance(point): return false
			var route: PackedVector3Array = chosen.get("stepping",{}).get("points",PackedVector3Array())
			if route.is_empty(): route = scene.navigation.path(scene.creature.position,point)
			if route.is_empty(): return false
			_approach_hops = chosen.get("stepping",{}).get("hops",{}).duplicate()
			active = kind
			target = {}
			scene.brain.reset_behavior()
			_approach_path = route
			_approach_index = 0
			_phase = "approach"
			_elapsed = 0.0
			return true
		var spots: Array = [scene.creature.position]
		for point in scene.navigation._nodes:
			if point.distance_to(scene.creature.position)<8.0: spots.append(point)
		spots = habits.rest_candidates(spots,scene.creature.position)
		var favorite: Variant = habits.preferred()
		if favorite != null:
			# Keep an established sheltered home. An outdoor resting spot can
			# give way to player-created shelter, but only along a safe route.
			var upgrade := false
			if not habits.sheltered_home:
				for candidate: Vector3 in spots:
					if habits.can_claim(candidate) and _rest_stance(candidate) and not scene.navigation.path(scene.creature.position,candidate).is_empty():
						upgrade = true
						break
			if not upgrade: spots.push_front(favorite)
		for point: Vector3 in spots:
			if not habits.allows(point) or not _rest_stance(point): continue
			var path: PackedVector3Array = scene.navigation.path(scene.creature.position,point)
			if path.is_empty(): continue
			active = kind
			target = {}
			scene.brain.reset_behavior()
			_approach_path = path
			_approach_index = 0
			_phase = "approach"
			_elapsed = 0.0
			return true
		return false

	var candidates := _targets(kind) if chosen.is_empty() else [chosen]
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return scene.creature.position.distance_squared_to(a.position)<scene.creature.position.distance_squared_to(b.position))
	for item: Dictionary in candidates:
		# A player invitation may send him across the chunk; autonomous choices
		# stay local and respect the ordinary repeat cooldown.
		if not invited and _clock < float(_cooldowns.get(item.id,0.0)): continue
		if not invited and scene.creature.position.distance_to(item.position) > 11.0: continue
		if not _plan_approach(item,kind): continue
		scene.brain.reset_behavior()
		scene.creature.notice(item.position)
		active = kind
		if kind == "fish": scene.fish.reserve_target(item.id)
		target = item
		_phase = "approach"
		_elapsed = 0.0
		return true
	return false

func _rest_stance(point: Vector3) -> bool:
	if not scene.navigation.is_safe(point): return false
	# Fit a small ground plane. A smooth bank is a useful resting place even
	# when it is not horizontal; reject steps and hollows the pose cannot fit.
	var heights: Array[float] = []
	for offset in [Vector3(0.6,0,0),Vector3(-0.6,0,0),Vector3(0,0,0.6),Vector3(0,0,-0.6)]:
		var ground: Variant = scene.navigation._ground(point+offset)
		if ground == null: return false
		heights.append(ground.y-point.y)
	var dx := (heights[0]-heights[1])/1.2
	var dz := (heights[2]-heights[3])/1.2
	if Vector2(dx,dz).length()>0.65: return false
	if absf(heights[0]+heights[1])*0.5>0.12 or absf(heights[2]+heights[3])*0.5>0.12: return false
	_rest_normal = Vector3(-dx,1,-dz).normalized()
	_rest_yaw = atan2(dx,dz) if Vector2(dx,dz).length()>0.05 else scene.creature.rotation.y
	# Face uphill so the extended toes stay on the bank. Resting must not
	# dangle the feet into water just because the standing center is dry.
	var facing := Basis(Vector3.UP,_rest_yaw)
	for side in [-1.0,1.0]:
		var foot: Vector3 = point+facing*Vector3(side*0.4,0,0.75)
		var ground: Variant = scene.navigation._ground(foot)
		if ground == null: return false
		if absf(ground.y-point.y-dx*(foot.x-point.x)-dz*(foot.z-point.z))>0.15: return false
		for water in scene.habitat.waters:
			var level: Variant = water.height_at(foot.x,foot.z)
			if level != null and ground.y<level+0.08: return false
	return true

func _plan_approach(item: Dictionary, kind: String, require_route := true) -> bool:
	# Match the authored contact instead of stopping at a generic viewing radius.
	var contact := Vector3(0,0,1.55) if kind == "tree" else Vector3(-0.457,0,1.35) if kind == "fish" else Vector3(-0.457,0,0.864)
	contact *= scene.creature.body_scale
	var toward: Vector3 = item.position-scene.creature.position
	var initial := atan2(toward.x,toward.z)-atan2(contact.x,contact.z)
	for i in range(32):
		var yaw := float(posmod(roundi(initial*32.0/TAU)+i,32))*TAU/32.0
		var foot: Vector3 = item.position-Basis(Vector3.UP,yaw)*contact
		var ground: Variant = scene.navigation._ground(foot)
		if ground == null or not scene.navigation.is_safe(ground): continue
		if kind in ["stone","fish"] and absf(ground.y-float(item.position.y))>(0.65 if kind == "fish" else 0.5): continue
		var path: PackedVector3Array = scene.navigation.path(scene.creature.position,ground) if require_route else PackedVector3Array([ground])
		if path.is_empty(): continue
		_approach_path = path
		_approach_index = 0
		item.facing = yaw
		return true
	return false

func _targets(kind: String) -> Array:
	var result: Array = []
	if kind == "stone":
		for item: Dictionary in scene._chunk_editor.data.objects:
			if item.asset == "rock" and float(item.scale) <= 0.5:
				if item.has("pose"):
					var size := NativeObjectPose.decode_basis(item.pose).get_scale()
					if maxf(size.x,maxf(size.y,size.z))>0.5: continue
				result.append({"id":"object:%d" % item.id,"record":item.duplicate(true),"position":scene._chunk_editor.data.object_position(item)})
	elif kind == "tree":
		for item: Dictionary in scene.habitat.interests:
			if str(item.id).begins_with("mesh-8:") or str(item.id).begins_with("mesh-11:"):
				result.append(item)
	elif kind == "fish" and scene.fish != null:
		result = scene.fish.available_targets()
	return result

func _target_exists() -> bool:
	if target.is_empty(): return true
	for item: Dictionary in _targets(active):
		if item.id == target.id and item.position.distance_to(target.position)<0.15: return true
	return false

func _start_performance(inspected := false) -> void:
	scene.creature.stop_walking()
	if not inspected and active in ["sit","sleep","hibernate"] and habits.can_claim(scene.creature.position):
		_phase = "inspect_home"
		_elapsed = 0.0
		scene.creature.notice(scene.creature.position+Vector3(0,1.5,1))
		scene.brain.reaction.emit("?","A sheltered place to rest")
		return
	scene.brain.reset_behavior()
	_phase = "perform"
	_elapsed = 0.0
	_released = false
	_tended = false
	_tending = active in ["sit","sleep","hibernate"] and habits.can_tend(scene.creature.position)
	if not target.is_empty():
		var offset: Vector3 = target.position-scene.creature.position
		scene.creature.rotation.y = float(target.get("facing",atan2(offset.x,offset.z)))
	if active in ["sit","sleep","hibernate"]:
		_rest_upright = Basis(Vector3.UP,_rest_yaw)
		scene.creature.basis = _rest_upright
		_rest_tilt = Basis(Quaternion(Vector3.UP,_rest_normal))*_rest_upright
	var clip := "SitDown" if active in ["sit","sleep","hibernate"] else "StoneThrow" if active == "stone" else "TreeShake" if active == "tree" else "FishCatch"
	if not scene.creature.perform_action(clip): cancel("actor refused performance")

func _effects(dt: float) -> void:
	var t: float = scene.creature._age
	if active in ["sit","sleep","hibernate"]:
		var weight := smoothstep(0.0,1.4,t) if scene.creature.action_clip == "SitDown" else 1.0-smoothstep(0.0,1.5,t) if scene.creature.action_clip == "StandUp" else 1.0
		scene.creature.basis = _rest_upright.slerp(_rest_tilt,weight)
	if _tending and scene.creature.action_clip == "SitDown":
		# Both hands draw leaves inward as he settles. Commit at contact, once.
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			var hand: Vector3 = scene.creature.position+_rest_tilt*Vector3(sign*lerpf(0.8,0.45,smoothstep(0.5,1.25,t)),0.14,0.45)
			scene.creature.reach_hand(hand,smoothstep(0.25,0.65,t)*(1.0-smoothstep(1.15,1.4,t)),side)
		if t>=1.1 and not _tended:
			habits.tend(scene.creature.position,_rest_normal,_rest_yaw)
			_tended = true
			if habits.stage == 1 and habits.sheltered_home: scene.brain.reaction.emit("Home","Making a leaf bed")
	if active in ["stone","fish"] and not _released:
		var reach := smoothstep(0.45,0.95,t)*(1.0-smoothstep(1.10,1.65,t))
		var point: Vector3 = target.position
		if active == "stone": point.y += 0.24*float(target.record.scale)
		scene.creature.reach_hand(point,reach)
	if scene.creature.action_clip == "Sleep":
		for i in range(_sleep_marks.size()):
			var phase := fmod(t+float(i)*0.7,2.1)/2.1
			_sleep_marks[i].visible = true
			_sleep_marks[i].global_position = scene.creature.position+Vector3(0.2+phase*0.5,1.6+phase*1.3,0)
			_sleep_marks[i].modulate.a = sin(phase*PI)
	if active == "stone":
		if t >= 1.5:
			var outward := Vector3(scene.creature.position.x,0,scene.creature.position.z).normalized()
			scene.creature.rotation.y = lerp_angle(scene.creature.rotation.y,atan2(outward.x,outward.z),1.0-exp(-5.0*dt))
		if t >= 1.05 and _held == null and not _released: _grasp_stone()
		if _held != null:
			_held.global_position = scene.creature.hand_position()
			if t >= 2.95: _throw_stone()
	elif active == "tree":
		if t >= 0.8 and t < 3.4: _shake_tree(t)
		elif t >= 3.4:
			_restore_tree()
			scene.creature.clear_hand_targets()
	elif active == "fish":
		if t >= 1.05 and _held == null and not _released:
			_catch_payload = scene.fish.catch_for_carry(target.id) if scene.fish.has_method("catch_for_carry") else {}
			_held = _catch_payload.get("node") as Node3D
			if _held == null and t>1.3:
				cancel("fish unavailable at grasp")
				return
		if _held != null:
			_held.global_position = scene.creature.hand_position()

func _grasp_stone() -> void:
	if not _target_exists():
		cancel()
		return
	var record: Dictionary = target.record
	# Garden data remains authoritative; taking the record is undoable.
	var data = scene._chunk_editor.data
	_taking_stone = true
	data.begin_stroke()
	data.remove_object(int(record.id))
	data.end_stroke()
	_held = MeshInstance3D.new()
	_held.mesh = scene._chunk_editor.content._meshes.rock
	_held.material_override = scene._chunk_editor.content._materials.rock.duplicate()
	if record.has("tint"): _held.material_override.set_shader_parameter("base_color",NativeObjectPose.decode_tint(record.tint))
	_held.basis = NativeObjectPose.decode_basis(record.pose) if record.has("pose") else Basis(Vector3.UP,float(record.angle)).scaled(Vector3.ONE*float(record.scale))
	add_child(_held)
	scene._chunk_editor.refresh()
	_taking_stone = false

func _throw_stone() -> void:
	var direction := Vector3(scene.creature.position.x,0,scene.creature.position.z).normalized()
	if direction.length_squared()<0.1: direction = scene.creature.basis.z
	# Deliberately enough energy to clear the edge of this 28-meter diorama.
	_projectiles.append({"node":_held,"velocity":direction*11.0+Vector3.UP*5.5,"age":0.0,"source_id":int(target.record.id),"settled":false})
	_held = null
	_released = true

func _advance_projectiles(dt: float) -> void:
	for i in range(_projectiles.size()-1,-1,-1):
		var p: Dictionary = _projectiles[i]
		if p.settled: continue
		var before: Vector3 = p.node.global_position
		p.velocity += Vector3.DOWN*9.8*dt
		p.node.global_position += p.velocity*dt
		var floor_height: Variant = scene.habitat.ground_height(Vector2(p.node.global_position.x,p.node.global_position.z))
		var radius: float = p.node.scale.x*0.42
		if floor_height != null and before.y-radius >= floor_height and p.node.global_position.y-radius <= floor_height and p.velocity.y < 0.0:
			p.node.global_position.y = floor_height+radius
			p.velocity = Vector3(p.velocity.x*0.65,-p.velocity.y*0.35,p.velocity.z*0.65)
			if p.velocity.length()<0.6:
				p.settled = true
		p.age += dt
		var outside := absf(p.node.global_position.x)>14.0 or absf(p.node.global_position.z)>14.0
		if (outside and p.age > 6.0) or p.node.global_position.y < -20.0:
			p.node.queue_free()
			_projectiles.remove_at(i)

func _shake_tree(t: float) -> void:
	if _tree_parts.is_empty():
		var parts := str(target.id).split(":")
		var index := int(parts[1])
		var names := ["mesh-8","mesh-9"] if parts[0] == "mesh-8" else ["mesh-11","broadleaf-canopies"]
		for name in names:
			var node: MultiMeshInstance3D = scene.get_node("Reference/"+name)
			if index < node.multimesh.instance_count:
				_tree_parts.append({"node":node,"index":index,"rest":node.multimesh.get_instance_transform(index),"last":node.multimesh.get_instance_transform(index)})
	var amount := sin((t-0.8)*TAU*2.8)*0.035*smoothstep(0.8,1.0,t)*(1.0-smoothstep(3.1,3.4,t))
	for part in _tree_parts:
		var pose: Transform3D = part.rest
		pose.basis = Basis(Vector3.FORWARD,amount)*pose.basis
		part.node.multimesh.set_instance_transform(part.index,pose)
		part.last = pose
	if not _tree_parts.is_empty():
		var trunk: Dictionary = _tree_parts[0]
		var box: AABB = trunk.node.transform*trunk.rest*trunk.node.multimesh.mesh.get_aabb()
		var radius := maxf(0.08,minf(box.size.x,box.size.z)*0.5)
		var sway := Vector3(-sin(amount)*1.55,0,0)
		for side in ["R","L"]:
			var sign := -1.0 if side == "R" else 1.0
			var point: Vector3 = target.position+Vector3.UP*1.55+sway+scene.creature.basis.x*sign*radius*0.7-scene.creature.basis.z*radius*0.7
			scene.creature.reach_hand(point,smoothstep(0.8,1.0,t)*(1.0-smoothstep(3.1,3.4,t)),side)

func _restore_tree() -> void:
	for part in _tree_parts:
		if is_instance_valid(part.node) and part.node.multimesh.get_instance_transform(part.index).is_equal_approx(part.last): part.node.multimesh.set_instance_transform(part.index,part.rest)
	_tree_parts.clear()

func _action_finished(clip: String, cancelled: bool) -> void:
	if active.is_empty(): return
	if cancelled:
		last_cancel = "actor interrupted "+clip
		_finish()
		return
	if clip == "SitDown":
		scene.creature.clear_hand_targets()
		scene.creature.perform_action("Sleep" if active in ["sleep","hibernate"] else "Sit",60.0 if active == "hibernate" else 18.0 if active == "sleep" else 8.0 if scene.creature.personality_active else 4.0)
	elif clip in ["Sit","Sleep"]:
		for label in _sleep_marks: label.visible = false
		scene.creature.perform_action("StandUp")
	else:
		if active == "fish" and not _catch_payload.is_empty():
			scene.fish.reserve_target(target.id,false)
			if (_catch_payload.get("release",Callable()) as Callable).is_valid(): _catch_payload.release.call()
			_held = null
			_catch_payload = {}
		if active in ["sit","sleep","hibernate"]:
			habits.rested(scene.creature.position)
			crossing_wish.rested(scene.creature.position)
		history.append(active)
		_finish()

func cancel(reason := "world edit or explicit cancellation") -> void:
	last_cancel = reason
	if scene.creature.state == CreatureActor.State.ACTION: scene.creature.cancel_action()
	_finish()

func _finish() -> void:
	if scene.creature.state == CreatureActor.State.HOPPING or (_hop_pending and scene.creature.state == CreatureActor.State.STUMBLING):
		var safe: Variant = scene.navigation.nearest_safe(scene.creature._safe_position)
		if safe != null: scene.creature.reset_at(safe)
	_hop_pending = false
	_approach_hops.clear()
	if crossing_wish.travelling or crossing_wish._planning or not crossing_wish._planned.is_empty(): crossing_wish.interrupted()
	if active in ["sit","sleep","hibernate"] and _phase == "perform": scene.creature.basis = _rest_upright
	if active == "fish" and not target.is_empty(): scene.fish.reserve_target(target.id,false)
	scene.creature.clear_hand_targets()
	_restore_tree()
	for label in _sleep_marks: label.visible = false
	if _held != null:
		if active == "fish":
			if not _catch_payload.is_empty() and (_catch_payload.get("release",Callable()) as Callable).is_valid(): _catch_payload.release.call()
			else: scene.fish.release_fish(target.id)
		else:
			# An interrupted grasp drops the same held prop; it is never duplicated.
			_projectiles.append({"node":_held,"velocity":Vector3.ZERO,"age":0.0,"source_id":int(target.record.id),"settled":false})
		_held = null
	_catch_payload = {}
	if not target.is_empty(): _cooldowns[target.id] = _clock+50.0
	active = ""
	target = {}
	_phase = ""
	_approach_path.clear()
	if scene.creature.state == CreatureActor.State.WALKING: scene.creature.stop_walking()
	_next_action = _clock+9.0

func world_changed() -> void:
	if habits.writing: return
	habits.world_changed()
	# Undo may restore a taken record: remove its transient representation first.
	for record: Dictionary in scene._chunk_editor.data.objects:
		for i in range(_projectiles.size()-1,-1,-1):
			if int(record.id) == int(_projectiles[i].source_id):
				_projectiles[i].node.queue_free()
				_projectiles.remove_at(i)
		if active == "stone" and _held != null and int(record.id) == int(target.record.id):
			_held.queue_free()
			_held = null
			cancel()
			return
	# Self-triggered removal after grasp does not cancel the throw.
	if _taking_stone: return
	if not active.is_empty(): cancel()

func _exit_tree() -> void:
	_restore_tree()
