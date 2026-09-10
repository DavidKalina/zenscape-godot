class_name SuspensionBridge extends Node3D
## A rickety rope crossing, built to span a real chasm.
##
## The physics is a coarse rope: two dozen to four dozen slab bodies, a couple
## of metres each, chained by locked-linear 6DOF joints and anchored at both
## ends. A hundred metres of plank-per-body deck would be two hundred and fifty
## bodies in one constraint island, and every joint in series adds its own
## solver slop, so the deck would hang far deeper than it was laid and creep
## while it did it. Coarse segments carry the same load through a fifth of the
## links.
##
## The planks are paint. Two MultiMeshes are re-placed along the rope every
## tick — whole planks in one, the halves of the cracked ones in the other —
## and the ropes are tubes in an ImmediateMesh. Nothing visual is simulated,
## which is why a missing plank leaves a hole you can see through but not fall
## through: the collision slab runs the length of the rope.
##
## Sag is the settled sag, not the laid one. Locked-linear joints stretch under
## the deck's own weight, so `setup` lays the chain shallower by a measured
## fraction of the span and lets it fall to the number that was asked for.
##
## A creature standing here later wants friction 0.9 and a mass well under the
## segment's own: the slabs are `DECK_DENSITY` kilograms per metre, so a two
## metre segment weighs about as much as a large dog and a Bigfoot leaning on
## one will move it. Wake the rope with `apply_wind` or a contact; it never
## sleeps.

## Rope slab: heavy enough that a creature does not flick it aside, light
## enough that a hundred metres of it does not out-pull the solver.
const DECK_DENSITY := 7.0
const DECK_THICKNESS := 0.13
const PLANK_THICKNESS := 0.09
## Joint travel. Long segments need little bend and no twist at all.
const BEND_LIMIT := 0.30
const TWIST_LIMIT := 0.05
const YAW_LIMIT := 0.05
## Locked-linear joints stretch under load. On the coarse rope that stretch is
## small and steady — about a percent and a half of the span across 22 m and
## 100 m decks — so `setup` lays the curve that much shallower and lets it fall
## to the sag that was asked for.
const COMPLIANCE_SAG := 0.015
## The handrails are paint, so the lateral stiffness real rope would give the
## deck is a spring pulling each segment back to the line it was laid on.
## Without it a gust leaves the rope permanently bowed: the joints articulate
## freely in yaw and gravity barely objects. A long rope is a slacker rope, so
## the pull falls off with the span, referenced to an eight metre footbridge.
const RAIL_STIFFNESS := 16.0
const RAIL_REFERENCE := 8.0
## Rope thicknesses, chosen to still register from a hundred and forty metres.
const RAIL_RADIUS := 0.055
const CABLE_RADIUS := 0.05
const STAY_RADIUS := 0.035
## Weathered boards, light to dark. One MultiMesh a tone: `set_instance_color`
## is a no-op in this engine build — it reads straight back black — and six
## batches is cheaper than a custom shader to work around it.
const WOOD_TONES := [Color(0.55, 0.44, 0.30), Color(0.47, 0.36, 0.24), Color(0.38, 0.28, 0.19), Color(0.50, 0.41, 0.29), Color(0.32, 0.24, 0.17), Color(0.58, 0.48, 0.35)]

var segments: Array[RigidBody3D] = []
var anchors: Array[StaticBody3D] = []
var planks: Array[Dictionary] = []
var segment_length := 1.6
var segment_mass := 0.0
var plank_spacing := 0.45
var plank_width := 1.15
var rail_height := 1.05
var sag := 0.135
var damping := 0.8

var _forward := Vector3.FORWARD
var _lateral := Vector3.RIGHT
var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _span := 0.0
var _wind := Vector3.ZERO
var _pull := 0.0
var _rest := PackedVector3Array()
var _lane := PackedVector3Array()
var _up := PackedVector3Array()
var _stays := PackedFloat32Array()
var _frays: Array[Dictionary] = []
var _lashings: Array[PackedVector3Array] = []
var _layers: Array[MultiMeshInstance3D] = []
var _cursor := PackedInt32Array()
var _ropes: MultiMeshInstance3D = null
var _strands := 0
## Visual rebuild cadence, in physics ticks: 1 every tick, 2 every other, 0 to
## stop painting at all. Tests run at 0; a bridge far off screen could too.
## `setup` steps it up every sixty plank slots, to three at most: a full
## repaint costs about six microseconds a slot, and a rope this slow loses
## nothing at thirty or even twenty repaints a second.
var repaint_stride := 1
var _repaint_at := 0
var _rebuild_usec := 0
var _rebuild_ticks := 0

func setup(a: Transform3D, b: Transform3D, options: Dictionary = {}) -> void:
	segment_length = maxf(0.8, float(options.get("segment_length", segment_length)))
	plank_spacing = maxf(0.15, float(options.get("plank_spacing", plank_spacing)))
	plank_width = maxf(0.3, float(options.get("plank_width", plank_width)))
	rail_height = maxf(0.2, float(options.get("rail_height", rail_height)))
	sag = clampf(float(options.get("sag", sag)), 0.02, 0.35)
	damping = maxf(0.0, float(options.get("damping", damping)))
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
	_pull = RAIL_STIFFNESS * RAIL_REFERENCE / maxf(RAIL_REFERENCE, _span)

	# Between twelve and forty-eight slabs, whatever the span: too few and the
	# curve is a polygon, too many and the chain goes soft again.
	var count: int = clampi(int(round(_span / segment_length)), 12, 48)
	segment_length = _span / float(count)
	segment_mass = maxf(1.0, float(options.get("segment_mass", DECK_DENSITY * segment_length)))
	_build_anchor(_a, 1.0, rng)
	_build_anchor(_b, -1.0, rng)
	for i in range(count):
		var body := _build_segment((float(i) + 0.5) / float(count))
		segments.append(body)
		_rest.append(body.position)
	_join(anchors[0], segments[0], _layout(0.5 / float(count)).lerp(_a, 0.5))
	for i in range(count - 1):
		_join(segments[i], segments[i + 1], _layout(float(i + 1) / float(count)))
	_join(segments[count - 1], anchors[1], _layout(1.0 - 0.5 / float(count)).lerp(_b, 0.5))

	_plan_deck(rng)
	# Measured at about six microseconds a plank slot, ropes included, so past
	# sixty slots a full repaint every tick would cost more than the frame can
	# spare. A rope this slow loses nothing at thirty.
	repaint_stride = int(options.get("repaint_stride", clampi(1 + planks.size() / 60, 1, 3)))
	_refresh_lane()
	_build_visuals()
	_rebuild_visuals()

## Plank slots along the deck, missing ones included: the count the span and
## the spacing asked for, not the count still nailed down.
func plank_count() -> int:
	return planks.size()

## A gentle lateral shove held until it is changed. Strength is metres per
## second squared; three is a stiff breeze on a hundred metre rope.
func apply_wind(direction: Vector3, strength: float) -> void:
	_wind = direction.normalized() * strength if direction.length() > 0.001 else Vector3.ZERO
	for body in segments: body.sleeping = false

## A world-space point on the walking surface, t from the first anchor to the
## second. The anchor mouths cap the rope so t=0 and t=1 land on solid ground.
func deck_point(t: float) -> Vector3:
	if _lane.is_empty(): return global_transform * _a.lerp(_b, clampf(t, 0.0, 1.0))
	var slide := clampf(t, 0.0, 1.0) * float(_lane.size() - 1)
	var first := clampi(int(slide), 0, _lane.size() - 2)
	var here := _lane[first].lerp(_lane[first + 1], slide - float(first))
	return global_transform * (here + Vector3.UP * DECK_THICKNESS * 0.5)

## Deepest drop below the straight line between the anchors, in metres.
func sag_depth() -> float:
	var deepest := 0.0
	for body in segments:
		var along: float = clampf((body.position - _a).dot(_b - _a) / maxf(0.001, _span * _span), 0.0, 1.0)
		deepest = maxf(deepest, _a.lerp(_b, along).y - body.position.y)
	return deepest

## Fastest rope segment, in metres per second: zero once the deck has settled.
func deck_motion() -> float:
	var fastest := 0.0
	for body in segments: fastest = maxf(fastest, body.linear_velocity.length())
	return fastest

## Drops a weight onto the deck at t, for tests and for dislodging things. The
## caller owns the body: free it to watch the deck come back up.
func drop_weight(t: float, weight := 5.0, height := 3.0) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.mass = weight
	ball.collision_layer = 1
	ball.collision_mask = 3
	var shape := SphereShape3D.new()
	shape.radius = 0.26
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ball.add_child(collision)
	add_child(ball)
	ball.global_position = deck_point(t) + Vector3(0.0, height, 0.0)
	return ball

## Mean microseconds spent re-placing planks and ropes, since the last read.
func rebuild_cost_usec() -> float:
	var mean := float(_rebuild_usec) / maxf(1.0, float(_rebuild_ticks))
	_rebuild_usec = 0
	_rebuild_ticks = 0
	return mean

func _physics_process(_delta: float) -> void:
	if segments.is_empty(): return
	for i in range(segments.size()):
		var body := segments[i]
		var drift: float = (body.position - _rest[i]).dot(_lateral)
		var push := _wind - _lateral * drift * _pull
		if push.length_squared() < 1e-6: continue
		body.sleeping = false
		body.apply_central_force(push * body.mass)
	var started := Time.get_ticks_usec()
	_refresh_lane()
	if repaint_stride > 0 and _repaint_at % repaint_stride == 0:
		_rebuild_visuals()
		_rebuild_usec += Time.get_ticks_usec() - started
		_rebuild_ticks += 1
	_repaint_at += 1

# ----------------------------------------------------------------- the rope

## The resting curve: a parabola between the anchors, laid shallower than the
## sag that was asked for because the joints will stretch to the rest.
func _layout(u: float) -> Vector3:
	var point := _a.lerp(_b, u)
	point.y -= maxf(0.01, sag - COMPLIANCE_SAG) * _span * (1.0 - pow(u * 2.0 - 1.0, 2.0))
	return point

## Span frame at a point on the curve: x along the walk, z across it.
func _frame(u: float) -> Basis:
	var step := 0.5 / maxf(1.0, float(segments.size()))
	var tangent := (_layout(minf(1.0, u + step)) - _layout(maxf(0.0, u - step))).normalized()
	if tangent.length() < 0.5: tangent = _forward
	return Basis(tangent, _lateral.cross(tangent), _lateral)

func _build_segment(u: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Rope%d" % segments.size()
	body.transform = Transform3D(_frame(u), _layout(u))
	body.mass = segment_mass
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
	# A wide flat slab: the deck a creature stands on, gaps in the planks or not.
	shape.size = Vector3(segment_length * 0.98, DECK_THICKNESS, plank_width)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

## Linear axes locked, the rope free to hinge across the span only.
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

## Poses of the rope, anchors capping both ends, resampled each tick. Planks,
## ropes and `deck_point` all read this and nothing else.
func _refresh_lane() -> void:
	if _lane.size() != segments.size() + 2:
		_lane.resize(segments.size() + 2)
		_up.resize(segments.size() + 2)
	_lane[0] = _a
	_lane[_lane.size() - 1] = _b
	for i in range(segments.size()):
		_lane[i + 1] = segments[i].position
		_up[i + 1] = segments[i].basis.y
	_up[0] = _up[1]
	_up[_up.size() - 1] = _up[_up.size() - 2]

## Position and orientation on the deck at t, in our own space.
func _deck_pose(t: float) -> Transform3D:
	var slide := clampf(t, 0.0, 1.0) * float(_lane.size() - 1)
	var first := clampi(int(slide), 0, _lane.size() - 2)
	var blend := slide - float(first)
	# Lerped up vectors rather than a quaternion slerp: the joints allow five
	# hundredths of a radian of twist, so nothing here is worth a slerp, and
	# this runs two hundred and some times a tick.
	var along := (_lane[first + 1] - _lane[first]).normalized()
	if along.length_squared() < 0.5: along = _forward
	var side := along.cross(_up[first].lerp(_up[first + 1], blend))
	if side.length_squared() < 0.0001: side = _lateral
	side = side.normalized()
	return Transform3D(Basis(along, side.cross(along), side), _lane[first].lerp(_lane[first + 1], blend))

# ---------------------------------------------------------------- the planks

## Every plank slot decided once, from the seed: which are gone, which sit
## crooked, which have snapped in half, and what each is cut from.
func _plan_deck(rng: RandomNumberGenerator) -> void:
	var slots: int = maxi(4, int(floor(_span / plank_spacing)) - 1)
	var cracked := {}
	for i in range(3): cracked[rng.randi_range(2, slots - 3)] = true
	for i in range(slots):
		var plank := {
			"t": float(i + 1) / float(slots + 1),
			"gone": rng.randf() < 0.12,
			"crack": false,
			"yaw": 0.0,
			"slide": 0.0,
			"lift": 0.0,
			"width": rng.randf_range(0.76, 1.08),
			"length": rng.randf_range(0.58, 0.86),
			"tone": rng.randi_range(0, WOOD_TONES.size() - 1),
		}
		if rng.randf() < 0.2:
			# One in five was never laid straight, or has been kicked askew.
			plank.yaw = rng.randf_range(-0.34, 0.34)
			plank.slide = rng.randf_range(-0.4, 0.4) * plank_spacing
			plank.lift = rng.randf_range(-0.015, 0.03)
		else:
			plank.yaw = rng.randf_range(-0.05, 0.05)
			plank.slide = rng.randf_range(-0.06, 0.06) * plank_spacing
		if cracked.has(i) and not plank.gone:
			plank.crack = true
			plank.gone = false
		# The whole local frame — crookedness and cut size together — folds into
		# one basis here, so the tick loop is a single multiply per plank.
		var size := Vector3(plank_spacing * float(plank.length), PLANK_THICKNESS, plank_width * float(plank.width))
		var turn := Basis.from_euler(Vector3(0.0, float(plank.yaw), 0.0))
		plank.frame = turn.scaled(size)
		if plank.crack:
			# One board, split and sagging into the gap it made.
			var halves: Array[Basis] = []
			var offsets: Array[Vector3] = []
			for side: float in [-1.0, 1.0]:
				var tilt := turn.rotated(turn.x, side * 0.13)
				halves.append(tilt.scaled(Vector3(size.x, size.y, size.z * 0.47)))
				offsets.append(tilt.z * side * size.z * 0.25)
			plank.halves = halves
			plank.offsets = offsets
		planks.append(plank)
	# Stays are tied where the rope-layer felt like it, not on a grid.
	var walk := plank_spacing * 1.5
	while walk < _span - plank_spacing:
		_stays.append(walk / _span)
		walk += plank_spacing * rng.randf_range(3.0, 6.0)
	for i in range(4):
		_frays.append({"t": rng.randf_range(0.12, 0.88), "side": -1.0 if rng.randf() < 0.5 else 1.0, "drop": rng.randf_range(0.8, 1.9), "kink": rng.randf_range(-0.5, 0.5)})

func _build_visuals() -> void:
	var tally := PackedInt32Array()
	tally.resize(WOOD_TONES.size())
	for plank: Dictionary in planks:
		if plank.gone: continue
		tally[int(plank.tone)] += 2 if plank.crack else 1
	_cursor.resize(WOOD_TONES.size())
	for tone in range(WOOD_TONES.size()): _layers.append(_plank_layer(tally[tone], WOOD_TONES[tone]))
	_ropes = _strand_layer(_stays.size() * 6 + _lane.size() * 2 + _frays.size() * 2 + 24)
	_lash_mesh()

func _plank_layer(count: int, tone: Color) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = _wood_material(tone)
	instance.custom_aabb = _reach()
	add_child(instance)
	return instance

## The box the deck can swing through, so nothing is culled mid-sway.
func _reach() -> AABB:
	var low := Vector3(minf(_a.x, _b.x), minf(_a.y, _b.y) - _span * 0.4, minf(_a.z, _b.z)) - Vector3.ONE * (plank_width + 2.0)
	var size := Vector3(absf(_b.x - _a.x), absf(_b.y - _a.y) + _span * 0.4 + rail_height, absf(_b.z - _a.z)) + Vector3.ONE * (plank_width + 2.0) * 2.0
	return AABB(low, size)

func _rebuild_visuals() -> void:
	for tone in range(_cursor.size()): _cursor[tone] = 0
	for plank: Dictionary in planks:
		if plank.gone: continue
		var tone: int = plank.tone
		var batch := _layers[tone].multimesh
		var pose := _deck_pose(float(plank.t) + float(plank.slide) / _span)
		pose.origin += pose.basis.y * (DECK_THICKNESS * 0.5 + PLANK_THICKNESS * 0.5 + float(plank.lift))
		if plank.crack:
			var halves: Array[Basis] = plank.halves
			var offsets: Array[Vector3] = plank.offsets
			for half in range(2):
				batch.set_instance_transform(_cursor[tone], Transform3D(pose.basis * halves[half], pose.origin + pose.basis * offsets[half]))
				_cursor[tone] += 1
		else:
			batch.set_instance_transform(_cursor[tone], Transform3D(pose.basis * plank.frame, pose.origin))
			_cursor[tone] += 1
	_rebuild_ropes()

# ------------------------------------------------------------------ the ropes

func _rebuild_ropes() -> void:
	if _ropes == null: return
	_strands = 0
	# Both sides come off one pose per sample: the deck is read a hundred times
	# a tick as it is, and reading it twice for a mirror image is waste.
	var rails := [PackedVector3Array([_anchor_rail(0, -1.0)]), PackedVector3Array([_anchor_rail(0, 1.0)])]
	for i in range(_stays.size()):
		var at: float = _stays[i]
		var pose := _deck_pose(at)
		var next: float = _stays[i + 1] if i + 1 < _stays.size() else 1.0
		var between := _deck_pose((at + next) * 0.5)
		for s in range(2):
			var side := -1.0 if s == 0 else 1.0
			var edge := pose.origin + pose.basis.z * side * plank_width * 0.46
			var top := edge + pose.basis.y * rail_height
			rails[s].append(top)
			_strand(edge, top, STAY_RADIUS)
			# Rope tied at the stays hangs slack in between; that slack is most
			# of what tells a rope bridge from a boardwalk.
			rails[s].append(between.origin + between.basis.z * side * plank_width * 0.46 + between.basis.y * rail_height - Vector3.UP * rail_height * 0.17)
	var cables := [PackedVector3Array([_anchor_cable(0, -1.0)]), PackedVector3Array([_anchor_cable(0, 1.0)])]
	for i in range(_lane.size()):
		var pose := _deck_pose(float(i) / float(_lane.size() - 1))
		var under := pose.basis.y * (DECK_THICKNESS * 0.5 + 0.09)
		for s in range(2):
			cables[s].append(pose.origin + pose.basis.z * (-1.0 if s == 0 else 1.0) * plank_width * 0.44 - under)
	for s in range(2):
		var side := -1.0 if s == 0 else 1.0
		rails[s].append(_anchor_rail(1, side))
		cables[s].append(_anchor_cable(1, side))
		_run(_smoothed(rails[s]), RAIL_RADIUS)
		_run(_smoothed(cables[s]), CABLE_RADIUS)
	for fray: Dictionary in _frays:
		# Frayed ends, left where a rope was cut or gave way.
		var top := _cable_point(float(fray.t), float(fray.side))
		var tail := top - Vector3.UP * float(fray.drop) + _lateral * float(fray.kink) * float(fray.side)
		var knee := top.lerp(tail, 0.55) + _lateral * 0.12 * float(fray.side)
		_strand(top, knee, CABLE_RADIUS * 0.7)
		_strand(knee, tail, CABLE_RADIUS * 0.7)
	# Whatever this rope did not need this tick is folded away to nothing.
	var batch := _ropes.multimesh
	for i in range(_strands, batch.instance_count): batch.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))

func _run(points: PackedVector3Array, radius: float) -> void:
	for i in range(points.size() - 1): _strand(points[i], points[i + 1], radius)

## One length of rope, as a squat four-sided cylinder in the shared batch. A
## hundred metres of handrail is a few hundred of these, which is a few hundred
## calls a tick — an ImmediateMesh of the same rope was eight thousand
## vertices, and three and a half milliseconds.
func _strand(from: Vector3, to: Vector3, radius: float) -> void:
	var batch := _ropes.multimesh
	if _strands >= batch.instance_count: return
	var along := to - from
	var length := along.length()
	if length < 0.0001: return
	along /= length
	var side := along.cross(Vector3.UP)
	if side.length_squared() < 0.0001: side = _lateral
	side = side.normalized() * radius
	batch.set_instance_transform(_strands, Transform3D(Basis(side, along * length, side.cross(along).normalized() * radius), (from + to) * 0.5))
	_strands += 1

func _strand_layer(count: int) -> MultiMeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 0
	mesh.cap_top = false
	mesh.cap_bottom = false
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = _rope_material()
	instance.custom_aabb = _reach()
	add_child(instance)
	return instance

## The lashings never move: the anchors are static, so they are placed once.
func _lash_mesh() -> void:
	var loops := _strand_layer(_lashings.size() * 6)
	var keep := _ropes
	_ropes = loops
	_strands = 0
	for loop in _lashings: _run(loop, STAY_RADIUS * 0.9)
	_ropes = keep

func _cable_point(t: float, side: float) -> Vector3:
	var pose := _deck_pose(t)
	return pose.origin + pose.basis.z * side * plank_width * 0.44 - pose.basis.y * (DECK_THICKNESS * 0.5 + 0.09)

func _anchor_rail(index: int, side: float) -> Vector3:
	# The rail ties to the cross-bar, and stops there.
	var at := _a if index == 0 else _b
	return at + _lateral * side * (plank_width * 0.5 + 0.16) + Vector3.UP * (rail_height + 0.52)

func _anchor_cable(index: int, side: float) -> Vector3:
	var at := _a if index == 0 else _b
	return at + _lateral * side * (plank_width * 0.5 + 0.05) - Vector3.UP * 0.16

## Two passes of a [1 2 1] blur over the interior of a rope path. The ends are
## tied off and never move.
func _smoothed(points: PackedVector3Array) -> PackedVector3Array:
	for pass_index in range(2):
		var eased := points.duplicate()
		for i in range(1, points.size() - 1):
			eased[i] = (points[i - 1] + points[i] * 2.0 + points[i + 1]) * 0.25
		points = eased
	return points

# ---------------------------------------------------------------- the anchors

## Two leaning stakes, a cross-bar lashed across them, rock wedged round the
## feet: the crossing reads as something people tied, not something installed.
func _build_anchor(at: Vector3, facing: float, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "Anchor%d" % anchors.size()
	body.transform = Transform3D(Basis(_forward * facing, Vector3.UP, _lateral * facing), at)
	var bar := rail_height + 0.52
	var reach := plank_width * 0.5 + 0.16
	for side: float in [-1.0, 1.0]:
		var lean := 0.17 * side
		var stake := Transform3D(Basis.from_euler(Vector3(lean, 0.0, 0.0)), Vector3(0.0, bar * 0.5 - 0.35, side * reach - sin(lean) * bar * 0.5))
		_add_block(body, stake, Vector3(0.26, bar + 0.7, 0.28), _post_material())
		for wedge in range(2):
			var pose := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, 3.1), rng.randf_range(-0.2, 0.2))), Vector3(rng.randf_range(-0.35, 0.35), -0.16, side * (reach + rng.randf_range(-0.3, 0.3))))
			_add_block(body, pose, Vector3(0.44, 0.34, 0.5) * rng.randf_range(0.7, 1.25), _rock_material())
	_add_block(body, Transform3D(Basis(), Vector3(0.0, bar, 0.0)), Vector3(0.24, 0.22, (reach + 0.28) * 2.0), _post_material())
	# A sill the deck can be stepped onto rather than stepped over.
	_add_block(body, Transform3D(Basis(), Vector3(-0.3, -0.06, 0.0)), Vector3(0.6, 0.14, plank_width + 0.3), _post_material())
	add_child(body)
	anchors.append(body)
	_lash(at, facing, reach, bar)

## Rope turns over the cross-bar at each stake, and a tie running down to the
## deck mouth. Static geometry, so it is built into the rope mesh once — but
## the mesh is rebuilt every tick anyway, so it lives with the rest.
func _lash(at: Vector3, facing: float, reach: float, bar: float) -> void:
	for side: float in [-1.0, 1.0]:
		for turn in range(3):
			var centre := at + _lateral * side * facing * (reach + float(turn) * 0.09 - 0.09) + Vector3.UP * bar
			var loop := PackedVector3Array()
			for step in range(7):
				var angle := float(step) / 6.0 * TAU
				loop.append(centre + _forward * facing * cos(angle) * 0.2 + Vector3.UP * sin(angle) * 0.19)
			_lashings.append(loop)

func _add_block(body: StaticBody3D, pose: Transform3D, size: Vector3, skin: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = skin
	visual.transform = pose
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = pose
	body.add_child(collision)

# --------------------------------------------------------------- the palette

func _wood_material(tone: Color) -> Material:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = tone
	wood.roughness = 1.0
	wood.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return wood

func _post_material() -> Material:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.29, 0.21, 0.15)
	wood.roughness = 1.0
	wood.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return wood

func _rock_material() -> Material:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.42, 0.41, 0.39)
	rock.roughness = 1.0
	rock.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return rock

func _rope_material() -> Material:
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.68, 0.57, 0.39)
	hemp.roughness = 1.0
	hemp.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return hemp
