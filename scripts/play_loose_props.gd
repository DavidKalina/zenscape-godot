extends Node3D
## One gesture contract across loose stones, logs and selected boulders.
const BODY = preload("res://scripts/play_loose_body.gd")
var scene: Node
var bodies: Array[RigidBody3D] = []
var grabbed: RigidBody3D
var hovered: RigidBody3D
var _grab_pose := Transform3D.IDENTITY
var _grab_parked := false
var _plane := Plane()
var _origin := Vector3.ZERO
var _target := Vector3.ZERO
var _samples: Array[Dictionary] = []
var _clock := 0.0
var _previous := {}
var _investigated := {}
var _evade_to: Variant = null
var _evade_time := 0.0
var _evade_cooldown := 0.0
var _glare_pending := false
var hits := {"stone":0,"log":0,"boulder":0}
var dodges := 0
var investigations := 0

func setup(playground: Node) -> void:
	scene = playground
	var source := preload("res://assets/zen_reference/geometry.scn").instantiate()
	for entry in [["stone",Vector2(-0.2,5.8)],["stone",Vector2(0.6,6.2)],["stone",Vector2(1.5,6.0)],["log",Vector2(5.2,4.6)],["boulder",Vector2(-2.6,0.9)],["boulder",Vector2(-1.8,-2.8)]]:
		var body := BODY.new()
		var original: GeometryInstance3D = source.get_node("logs" if entry[0] == "log" else ("mesh-5" if entry[0] == "stone" else "mesh-4"))
		var mesh: Mesh = original.multimesh.mesh if original is MultiMeshInstance3D else original.mesh
		var material: Material = original.material_override if original.material_override != null else mesh.surface_get_material(0)
		body.setup(entry[0],mesh,material)
		add_child(body)
		var point: Vector2 = entry[1]
		body.position = Vector3(point.x,scene._chunk_editor.data.ground_height(point)+body.radius+0.08,point.y)
		body.home = body.transform
		body.sleeping = true
		body.water_probe = scene.water_play.surface_at
		body.splashed.connect(scene.water_play.splash)
		body.released.connect(func() -> void:
			_previous[body] = body.global_position
			_investigated.erase(body))
		bodies.append(body)
		_previous[body] = body.position
	source.free()

func busy() -> bool: return _evade_to != null

func pick(mouse: Vector2) -> RigidBody3D:
	if scene._over_controls(mouse) or not get_viewport().get_visible_rect().has_point(mouse): return null
	var origin: Vector3 = scene.camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+scene.camera.project_ray_normal(mouse)*200.0,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is RigidBody3D and hit.collider in bodies else null

func hover(mouse: Vector2) -> void:
	var next: RigidBody3D = null if scene._paused or scene.gust_tool or scene._carrying or scene._tree_drag else pick(mouse)
	if next == hovered: return
	if hovered != null: hovered.set_highlight(false)
	hovered = next
	if hovered != null: hovered.set_highlight(true)

func begin_grab(body: RigidBody3D, mouse: Vector2) -> void:
	if body not in bodies or scene._paused or scene.gust_tool or scene._carrying: return
	cancel()
	grabbed = body
	_grab_pose = body.global_transform
	_grab_parked = body.parked
	var lift: float = {"stone":1.15,"log":0.45,"boulder":0.18}[body.kind]
	_plane = Plane(Vector3.UP,body.global_position.y+lift)
	var at: Variant = _plane.intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
	_origin = at if at != null else body.global_position
	_target = body.global_position+Vector3.UP*lift
	_samples = [{"point":body.global_position,"time":_clock}]
	_investigated.erase(body)
	body.grab()
	scene._show_reaction("?","A little heft to this one." if body.kind == "boulder" else "Swing your cursor and release to throw. Hold still to drop.")

func move_grab(mouse: Vector2) -> void:
	if grabbed == null or scene._paused or scene._over_controls(mouse): return
	var point: Variant = _plane.intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
	if point == null: return
	var offset: Vector3 = (point-_origin).limit_length(13.0)
	_target = _grab_pose.origin+offset
	_target.y = _plane.d
	var ground: Variant = scene._probe_ground(_target)
	if ground != null: _target.y = maxf(_target.y,ground.y+grabbed.radius+0.1)

func release() -> void:
	if grabbed == null: return
	var velocity := Vector3.ZERO
	if _samples.size()>1:
		var first: Dictionary = _samples[0]
		velocity = (grabbed.global_position-first.point)/maxf(_clock-first.time,0.016)
		if velocity.length()>1.0: velocity.y += 0.9 if grabbed.kind == "stone" else 0.2
	grabbed.release(velocity*1.12)
	_previous[grabbed] = grabbed.global_position
	grabbed = null
	_samples.clear()

func cancel() -> void:
	if grabbed == null: return
	grabbed.parked = _grab_parked
	grabbed.restore(_grab_pose)
	_previous[grabbed] = grabbed.global_position
	grabbed = null
	_samples.clear()

func reset() -> void:
	cancel()
	_evade_to = null
	_evade_time = 0.0
	_glare_pending = false
	_investigated.clear()
	for body in bodies:
		body.parked = body.kind == "boulder"
		body.restore(body.home)
		body.sleeping = true
		_previous[body] = body.position

func advance(delta: float) -> void:
	for body in bodies: body.set_paused(scene._paused)
	if scene._paused: return
	_clock += delta
	_evade_cooldown = maxf(0.0,_evade_cooldown-delta)
	if grabbed != null:
		var response: float = {"stone":24.0,"log":12.0,"boulder":4.0}[grabbed.kind]
		grabbed.global_position = grabbed.global_position.lerp(_target,1.0-exp(-response*delta))
		_samples.append({"point":grabbed.global_position,"time":_clock})
		while _samples.size()>2 and _samples[0].time<_clock-0.12: _samples.pop_front()
	if _evade_to != null:
		_evade_time -= delta
		if not scene.creature.can_roam() or _evade_time<=0.0 or not scene.navigation.motion_safe(scene.creature.global_position,_evade_to,2.8*delta):
			_evade_to = null
		elif scene.creature.walk_step(_evade_to,2.8,delta):
			_evade_to = null
			scene.creature.stop_walking()
			scene._attention_time = 1.0
	if _glare_pending and scene.creature.state == CreatureActor.State.ALERT:
		_glare_pending = false
		scene._offended_time = 2.0
		scene._attention_time = 2.0
		scene._show_reaction("…","He has some thoughts about your throwing arm.")
	for body in bodies:
		var before: Vector3 = _previous.get(body,body.global_position)
		if not body.held:
			if body.global_position.y < -12.0 or Vector2(body.position.x,body.position.z).length()>22.0:
				body.parked = body.kind == "boulder"
				body.restore(body.home)
				_previous[body] = body.global_position
				continue
			if body.kind == "boulder" and body.linear_velocity.length()>1.1: _anticipate(body)
			_contact(body,before)
			if body.launched and body.age_since_release>1.4 and body.linear_velocity.length()<0.3 and not _investigated.has(body) and scene.creature.can_roam() and not busy() and grabbed == null and not scene._tree_drag and scene._attention_time<=0.0:
				# An unreachable release must not trigger an expensive route search every tick.
				_investigated[body] = true
				if scene.brain.investigate(body.global_position,false,"loose:%d" % body.get_instance_id()):
					investigations += 1
					scene._show_reaction("?","Now where did that come from?")
		_previous[body] = body.global_position

func _anticipate(body: RigidBody3D) -> void:
	if _evade_cooldown>0.0 or busy() or not scene.creature.can_roam() or scene._carrying: return
	var velocity: Vector3 = body.linear_velocity
	velocity.y = 0.0
	var relative: Vector3 = scene.creature.global_position-body.global_position
	relative.y = 0.0
	var time := relative.dot(velocity)/maxf(velocity.length_squared(),0.01)
	if time<0.15 or time>1.6 or (relative-velocity*time).length()>body.radius+0.85: return
	var side := Vector3(-velocity.z,0,velocity.x).normalized()
	for sign in [1.0,-1.0]:
		var point: Variant = scene._probe_ground(scene.creature.global_position+side*sign*2.4)
		if point == null or not scene.valid_landing(point) or not scene.navigation.segment_safe(scene.creature.global_position,point): continue
		_evade_to = point
		_evade_time = 1.4
		_evade_cooldown = 2.5
		dodges += 1
		scene.brain.enabled = false
		scene.creature.notice(body.global_position)
		scene._show_reaction("!","Suddenly, somewhere else looks much nicer.")
		return

func _contact(body: RigidBody3D, before: Vector3) -> void:
	if body.hit_cooldown>0.0 or body.linear_velocity.length()<1.0: return
	if scene.creature.state in [CreatureActor.State.HELD,CreatureActor.State.LANDING,CreatureActor.State.RECOVERING,CreatureActor.State.SWIMMING,CreatureActor.State.SHAKING]: return
	var points: Array[Vector3] = [Vector3.ZERO]
	if body.kind == "log": points.append_array([body.global_basis.x*0.8,-body.global_basis.x*0.8])
	var touched := false
	for offset in points:
		var a := before+offset
		var b: Vector3 = body.global_position+offset
		var segment := b-a
		for height in [0.45,1.15,1.85]:
			var target: Vector3 = scene.creature.global_position+Vector3.UP*height
			var near := a+segment*clampf((target-a).dot(segment)/maxf(segment.length_squared(),0.00001),0.0,1.0)
			if near.distance_to(target)<body.radius+0.48: touched = true
	if not touched: return
	body.hit_cooldown = 1.3
	hits[body.kind] += 1
	_glare_pending = true
	scene._attention_time = 3.0
	if body.kind == "stone":
		scene.creature.queue_tremor(0.48)
		scene._show_reaction("!","Bonk. A strongly worded look is on its way.")
	else:
		scene.creature.receive_impulse((body.linear_velocity*body.mass*1.8+Vector3.UP*65.0).limit_length(230.0))
		scene._show_reaction("!","That was not a stepping stone." if body.kind == "boulder" else "A log has rearranged his afternoon.")
	body.linear_velocity *= -0.25 if body.kind == "stone" else 0.45
