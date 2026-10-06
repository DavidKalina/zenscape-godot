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
var _tree_contacts := {}

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
		body.released.connect(func() -> void: _previous[body] = body.global_position)
		bodies.append(body)
		_previous[body] = body.position
	source.free()

func pick(mouse: Vector2) -> RigidBody3D:
	if scene._over_controls(mouse) or not get_viewport().get_visible_rect().has_point(mouse): return null
	var origin: Vector3 = scene.camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+scene.camera.project_ray_normal(mouse)*200.0,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is RigidBody3D and hit.collider in bodies else null

func hover(mouse: Vector2) -> void:
	var next: RigidBody3D = null if scene._paused or scene.gust_tool or scene._tree_drag else pick(mouse)
	if next == hovered: return
	if hovered != null: hovered.set_highlight(false)
	hovered = next
	if hovered != null: hovered.set_highlight(true)

func begin_grab(body: RigidBody3D, mouse: Vector2) -> void:
	if body not in bodies or scene._paused or scene.gust_tool: return
	cancel()
	grabbed = body
	_grab_pose = body.global_transform
	_grab_parked = body.parked
	var lift: float = {"stone":1.15,"log":0.45,"boulder":0.18}[body.kind]
	_plane = Plane(Vector3.UP,body.global_position.y+lift)
	var at: Variant = _plane.intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
	_origin = at if at != null else body.global_position
	# Center the lifted prop on the cursor ray, including off-center pickups.
	_target = _origin
	_samples = [{"point":body.global_position,"time":_clock}]
	body.grab()
	scene._show_reaction("?","A little heft to this one." if body.kind == "boulder" else "Swing your cursor and release to throw. Hold still to drop.")

func move_grab(mouse: Vector2) -> void:
	if grabbed == null or scene._paused or scene._over_controls(mouse): return
	var point: Variant = _plane.intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
	if point == null: return
	var offset: Vector3 = (point-_origin).limit_length(13.0)
	_target = _origin+offset
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
	_tree_contacts.clear()
	for body in bodies:
		body.parked = body.kind == "boulder"
		body.restore(body.home)
		body.sleeping = true
		_previous[body] = body.position

func advance(delta: float) -> void:
	for body in bodies: body.set_paused(scene._paused)
	if scene._paused: return
	_clock += delta
	if grabbed != null:
		var response: float = {"stone":24.0,"log":12.0,"boulder":4.0}[grabbed.kind]
		grabbed.global_position = grabbed.global_position.lerp(_target,1.0-exp(-response*delta))
		_samples.append({"point":grabbed.global_position,"time":_clock})
		while _samples.size()>2 and _samples[0].time<_clock-0.12: _samples.pop_front()
	for body in bodies:
		if not body.held:
			if scene.prop_out_of_bounds(body.global_position) if scene.has_method("prop_out_of_bounds") else (body.global_position.y < -12.0 or Vector2(body.position.x,body.position.z).length()>22.0):
				body.parked = body.kind == "boulder"
				body.restore(body.home)
				_previous[body] = body.global_position
				continue
		_previous[body] = body.global_position

func tree_sweep(previous: Vector2, delta: float) -> void:
	# A released tree bats loose objects with its crown.
	if scene.spring_tree.held:
		_tree_contacts.clear()
		return
	for body in bodies:
		if body.held or _tree_contacts.has(body): continue
		var speed: Vector3 = scene.spring_tree.sweep_contact(previous,body.global_position,delta,false)
		if speed.length()<1.4: continue
		_tree_contacts[body] = true
		body.release((body.linear_velocity+speed*0.55+Vector3.UP*1.0).limit_length(8.0))
