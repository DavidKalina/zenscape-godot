class_name SuspensionBridge extends Node3D
## A hand-built rope-and-plank crossing between two floating islands.
##
## The deck is real physics: a chain of plank bodies linked by locked-linear
## 6DOF joints, so a creature can stand on it and it sways when the wind
## pushes. The ropes are not. Four tubes rebuilt each physics tick from the
## plank poses read as a handrail and an under-deck cable, which costs a few
## hundred triangles instead of another forty constrained bodies.
##
## The chain is laid along a parabola (close enough to a catenary at these
## sags) so the joints open at rest and the deck settles in a second and a half
## instead of whipping down from a straight line.
##
## Per-plank jitter lives on the visual child, never on the body: the
## collision box and the joint frames stay square to the span, so a crooked
## plank is a crooked plank and not a joint fighting its own limits.

const THICKNESS := 0.06
## Locked-linear 6DOF joints are compliant under load, so a deck always hangs
## deeper than it was laid out. Subtracting the measured 4.6% of span lets `sag`
## mean where the deck ends up rather than where it starts: exact at the default
## 0.08, and within two points of the request from 0.04 to 0.12. The error grows
## as the layout flattens, because a flatter deck pulls its joints harder.
const COMPLIANCE_SAG := 0.046
## Joint travel. The deck hinges freely enough to sag and sway but cannot fold
## back on itself, twist into a corkscrew, or snake sideways.
## The handrails are paint, not bodies, so the lateral stiffness real rope
## would give the deck is modelled as a spring pulling each plank back to the
## line it was laid on. Without it the chain keeps whatever sideways set a gust
## hands it: the joints articulate freely in yaw and gravity barely objects.
## At 16 per metre a 7 m/s² gust bows the middle about 0.4 m and it swings back
## at roughly 0.6 Hz.
const RAIL_STIFFNESS := 16.0
const BEND_LIMIT := 0.38
const TWIST_LIMIT := 0.09
const YAW_LIMIT := 0.09

var planks: Array[RigidBody3D] = []
var anchors: Array[StaticBody3D] = []
var plank_spacing := 0.4
var plank_width := 1.0
var rail_height := 1.0
var sag := 0.08
var damping := 0.8
var plank_mass := 3.0

var _forward := Vector3.FORWARD
var _lateral := Vector3.RIGHT
var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _span := 0.0
var _wind := Vector3.ZERO
var _rest := PackedVector3Array()
var _ropes: MeshInstance3D = null
var _rope_mesh: ImmediateMesh = null

func setup(a: Transform3D, b: Transform3D, options: Dictionary = {}) -> void:
	plank_spacing = maxf(0.15, float(options.get("plank_spacing", plank_spacing)))
	plank_width = maxf(0.3, float(options.get("plank_width", plank_width)))
	rail_height = maxf(0.2, float(options.get("rail_height", rail_height)))
	sag = clampf(float(options.get("sag", sag)), 0.0, 0.3)
	damping = maxf(0.0, float(options.get("damping", damping)))
	plank_mass = clampf(float(options.get("plank_mass", plank_mass)), 0.5, 20.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 7))

	# Anchors arrive in the parent's space; everything is built in ours.
	var to_local := transform.affine_inverse()
	_a = to_local * a.origin
	_b = to_local * b.origin
	_span = _a.distance_to(_b)
	var flat := Vector3(_b.x - _a.x, 0.0, _b.z - _a.z)
	_forward = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	_lateral = _forward.cross(Vector3.UP)

	var count: int = maxi(3, int(floor(_span / plank_spacing)) - 1)
	_build_anchor(_a, 1.0)
	_build_anchor(_b, -1.0)
	var woods := _wood_materials(rng)
	for i in range(count):
		planks.append(_build_plank(float(i + 1) / float(count + 1), woods[rng.randi_range(0, woods.size() - 1)], rng))
		_rest.append(planks[i].position)
	_join(anchors[0], planks[0], (_a + planks[0].position) * 0.5)
	for i in range(count - 1):
		_join(planks[i], planks[i + 1], (planks[i].position + planks[i + 1].position) * 0.5)
	_join(planks[count - 1], anchors[1], (planks[count - 1].position + _b) * 0.5)

	_rope_mesh = ImmediateMesh.new()
	_ropes = MeshInstance3D.new()
	_ropes.name = "Ropes"
	_ropes.mesh = _rope_mesh
	_ropes.material_override = _rope_material()
	# The ropes reach a rail height above a deck that can swing anywhere.
	_ropes.custom_aabb = AABB(Vector3(minf(_a.x, _b.x), minf(_a.y, _b.y) - _span, minf(_a.z, _b.z)) - Vector3.ONE * plank_width, Vector3(absf(_b.x - _a.x), absf(_b.y - _a.y) + _span + rail_height, absf(_b.z - _a.z)) + Vector3.ONE * plank_width * 2.0)
	add_child(_ropes)
	_rebuild_ropes()

## How many planks the span came out to. Derived, not authored.
func plank_count() -> int:
	return planks.size()

## A gentle lateral shove held until it is changed. Direction need not be
## normalised to a horizontal; strength is metres per second squared.
func apply_wind(direction: Vector3, strength: float) -> void:
	_wind = direction.normalized() * strength if direction.length() > 0.001 else Vector3.ZERO
	for plank in planks: plank.sleeping = false

## A world-space point on the walking surface, t from the first anchor to the
## second. The anchor mouths cap the chain so t=0 and t=1 land on solid ground.
func deck_point(t: float) -> Vector3:
	if planks.is_empty(): return global_transform * _a.lerp(_b, clampf(t, 0.0, 1.0))
	var lane := PackedVector3Array([_a])
	for plank in planks: lane.append(plank.position + plank.basis.y * THICKNESS * 0.5)
	lane.append(_b)
	var slide := clampf(t, 0.0, 1.0) * float(lane.size() - 1)
	var first := clampi(int(slide), 0, lane.size() - 2)
	return global_transform * lane[first].lerp(lane[first + 1], slide - float(first))

## Deepest drop below the straight line between the anchors, in metres. The
## cheapest read on whether the deck is hanging right or hanging broken.
func sag_depth() -> float:
	var deepest := 0.0
	for plank in planks:
		var along: float = clampf((plank.position - _a).dot(_b - _a) / maxf(0.001, _span * _span), 0.0, 1.0)
		deepest = maxf(deepest, _a.lerp(_b, along).y - plank.position.y)
	return deepest

## Fastest plank, in metres per second: zero once the deck has settled.
func deck_motion() -> float:
	var fastest := 0.0
	for plank in planks: fastest = maxf(fastest, plank.linear_velocity.length())
	return fastest

func _physics_process(_delta: float) -> void:
	if planks.is_empty(): return
	for i in range(planks.size()):
		var plank := planks[i]
		var drift: float = (plank.position - _rest[i]).dot(_lateral)
		var push := _wind - _lateral * drift * RAIL_STIFFNESS
		if push.length_squared() < 1e-6: continue
		plank.sleeping = false
		plank.apply_central_force(push * plank.mass)
	_rebuild_ropes()

# ----------------------------------------------------------------- the layout

## The resting curve of the deck: a parabola hanging between the anchors.
func _layout(u: float) -> Vector3:
	var point := _a.lerp(_b, u)
	point.y -= maxf(0.012, sag - COMPLIANCE_SAG) * _span * (1.0 - pow(u * 2.0 - 1.0, 2.0))
	return point

## Span frame at a point on the curve: x along the walk, z across it.
func _frame(u: float) -> Basis:
	var tangent := (_layout(minf(1.0, u + 0.02)) - _layout(maxf(0.0, u - 0.02))).normalized()
	if tangent.length() < 0.5: tangent = _forward
	return Basis(tangent, _lateral.cross(tangent), _lateral)

func _build_plank(u: float, wood: Material, rng: RandomNumberGenerator) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Plank%d" % planks.size()
	body.transform = Transform3D(_frame(u), _layout(u))
	body.mass = plank_mass
	body.can_sleep = false  # A bridge nobody is on must still answer the wind.
	body.collision_layer = 1
	body.collision_mask = 3
	body.linear_damp = damping
	body.angular_damp = damping * 1.6
	var surface := PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.0
	body.physics_material_override = surface
	var shape := BoxShape3D.new()
	# Slightly shy of the mesh, so neighbours never grind edge on edge.
	shape.size = Vector3(plank_spacing * 0.8, THICKNESS, plank_width * 0.96)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(plank_spacing * 0.86, THICKNESS, plank_width)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = wood
	# Hand-laid: every plank sits a little crooked, and none is cut square.
	visual.rotation = Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.02, 0.02))
	visual.scale = Vector3(rng.randf_range(0.92, 1.05), rng.randf_range(0.85, 1.2), rng.randf_range(0.96, 1.02))
	visual.position = Vector3(rng.randf_range(-0.01, 0.01), 0.0, rng.randf_range(-0.03, 0.03))
	body.add_child(visual)
	add_child(body)
	return body

## Posts and a threshold beam where the deck meets land. `facing` points the
## pair into the span so the splay leans outward from the crossing.
func _build_anchor(at: Vector3, facing: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Anchor%d" % anchors.size()
	body.transform = Transform3D(Basis(_forward * facing, Vector3.UP, _lateral * facing), at)
	var height := rail_height + 0.95
	var lift := (rail_height + 0.35 - 0.6) * 0.5
	for side in [-1.0, 1.0]:
		var post := Transform3D(Basis.from_euler(Vector3(side * 0.1, 0.0, 0.0)), Vector3(0.0, lift, side * (plank_width * 0.5 + 0.13)))
		_add_block(body, post, Vector3(0.15, height, 0.16), _post_material())
	# A sill the deck can be stepped onto rather than stepped over. It sits all
	# but flush with the ground so it reads as a threshold, not a loading dock.
	_add_block(body, Transform3D(Basis(), Vector3(-0.19, -0.05, 0.0)), Vector3(0.38, 0.12, plank_width + 0.2), _post_material())
	add_child(body)
	anchors.append(body)

func _add_block(body: StaticBody3D, pose: Transform3D, size: Vector3, wood: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = wood
	visual.transform = pose
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = pose
	body.add_child(collision)

## Linear axes locked, the deck free to hinge across the span only.
func _join(first: PhysicsBody3D, second: PhysicsBody3D, at: Vector3) -> void:
	var joint := Generic6DOFJoint3D.new()
	var along: float = clampf((at - _a).dot(_b - _a) / maxf(0.001, _span * _span), 0.0, 1.0)
	joint.transform = Transform3D(_frame(along), at)
	add_child(joint)
	joint.node_a = joint.get_path_to(first)
	joint.node_b = joint.get_path_to(second)
	var axes: Array[Callable] = [joint.set_param_x, joint.set_param_y, joint.set_param_z]
	var travel := [TWIST_LIMIT, YAW_LIMIT, BEND_LIMIT]
	for i in range(3):
		axes[i].call(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		axes[i].call(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
		axes[i].call(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -travel[i])
		axes[i].call(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, travel[i])

# ------------------------------------------------------------------ the ropes

func _rebuild_ropes() -> void:
	if _rope_mesh == null: return
	_rope_mesh.clear_surfaces()
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var rail := PackedVector3Array([_anchor_rail(0, side)])
		var cable := PackedVector3Array([_anchor_cable(0, side)])
		for i in range(planks.size()):
			rail.append(_rail_point(i, side))
			cable.append(_cable_point(i, side))
			# A stay every other plank carries the deck off the handrail.
			if i % 2 == 1: _tube(PackedVector3Array([_edge_point(i, side), _rail_point(i, side)]), 0.015)
		rail.append(_anchor_rail(1, side))
		cable.append(_anchor_cable(1, side))
		# Rope pulled taut between the posts does not copy every crooked plank,
		# so the rail is smoothed while the stays keep their honest lengths.
		_tube(_smoothed(rail), 0.028)
		_tube(_smoothed(cable), 0.023)
	_rope_mesh.surface_end()

func _edge_point(index: int, side: float) -> Vector3:
	var plank := planks[index]
	return plank.position + plank.basis.z * side * plank_width * 0.46

func _rail_point(index: int, side: float) -> Vector3:
	return _edge_point(index, side) + planks[index].basis.y * rail_height

func _cable_point(index: int, side: float) -> Vector3:
	return _edge_point(index, side) - planks[index].basis.y * (THICKNESS * 0.5 + 0.07)

func _anchor_rail(index: int, side: float) -> Vector3:
	var at := _a if index == 0 else _b
	return at + _lateral * side * (plank_width * 0.5 + 0.13) + Vector3.UP * (rail_height + 0.14)

func _anchor_cable(index: int, side: float) -> Vector3:
	var at := _a if index == 0 else _b
	return at + _lateral * side * (plank_width * 0.5 + 0.1) - Vector3.UP * 0.12

## Two passes of a [1 2 1] blur over the interior of a rope path. The ends are
## tied to the posts and never move.
func _smoothed(points: PackedVector3Array) -> PackedVector3Array:
	for pass_index in range(2):
		var eased := points.duplicate()
		for i in range(1, points.size() - 1):
			eased[i] = (points[i - 1] + points[i] * 2.0 + points[i + 1]) * 0.25
		points = eased
	return points

## A four-sided prism down a polyline: thick enough to read as rope at two
## metres, cheap enough to rebuild sixty times a second.
func _tube(points: PackedVector3Array, radius: float) -> void:
	if points.size() < 2: return
	var rings: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var ahead: Vector3 = points[mini(i + 1, points.size() - 1)]
		var behind: Vector3 = points[maxi(i - 1, 0)]
		var tangent := (ahead - behind).normalized()
		if tangent.length() < 0.5: tangent = _forward
		var side := tangent.cross(Vector3.UP)
		if side.length() < 0.01: side = _lateral
		side = side.normalized() * radius
		var lift := side.cross(tangent).normalized() * radius
		rings.append(PackedVector3Array([points[i] + side, points[i] + lift, points[i] - side, points[i] - lift]))
	for i in range(rings.size() - 1):
		for corner in range(4):
			var next := (corner + 1) % 4
			_quad(rings[i][corner], rings[i][next], rings[i + 1][next], rings[i + 1][corner])

func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var normal := (p1 - p0).cross(p3 - p0).normalized()
	for point in [p0, p1, p2, p0, p2, p3]:
		_rope_mesh.surface_set_normal(normal)
		_rope_mesh.surface_add_vertex(point)

# --------------------------------------------------------------- the palette

func _wood_materials(rng: RandomNumberGenerator) -> Array[Material]:
	var woods: Array[Material] = []
	for i in range(4):
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.40, 0.29, 0.19).lerp(Color(0.55, 0.43, 0.29), rng.randf())
		wood.roughness = 1.0
		wood.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		woods.append(wood)
	return woods

func _post_material() -> Material:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.31, 0.23, 0.16)
	wood.roughness = 1.0
	wood.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return wood

func _rope_material() -> Material:
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.70, 0.59, 0.40)
	hemp.roughness = 1.0
	hemp.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return hemp
