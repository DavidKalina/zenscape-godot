extends Node
## The tilt, after the
## dragon's (scripts/dragon_gale.gd): when the Olmec
## hauls himself over a rim or lands a leap, the stone under him tips toward
## his weight, and while he stands out near its rim it stays leaned that
## way; the walker on it is carried as it tips and lurches toward the low
## side, so he feels him coming and a hit near the edge is what kills.
##
## What tips is the stone under the Olmec's feet: the largest node over the
## collider there (a kit piece, a pillar, a column top, a terrace's piece)
## no wider than TIP_MOST m (flat, its meshes' box). A whole place merged
## into one hillside is too big to tip: it only groans and shakes. The node
## is posed each frame from its rest about a pivot at its middle (at the
## haul's height): its own colliders tip with it (the walker's ground rays
## read them), and the walker standing on it is carried
## (PilotMotor.carry), as the dragon's gale does.
##
## The tip is a 2D spring (rad about x and z): a kick on a haul or a landing
## (DIP m down at the rim, so a small stone tips more than a big one, held
## in TIP_LEAST..TIP_MOST_DEG), its goal the lean toward each Olmec on it (LEAN
## m down at the rim, by how far out he stands), back to rest when he's
## gone. Fair: it reads (the stone visibly goes over, a groan, dust off the
## rim, the camera's quake) and the lurch is slower than his run
## (LURCH m/s at the kick's peak, along the fall line only), so running
## upslope always wins.

const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")

## The largest stone that tips (m, flat across).
const TIP_MOST := 80.0
## The smallest worth tipping (m): a block, not an isle.
const TIP_LEAST := 6.0
## The rim's dip at a kick (m, x the weight's power), and the tip's bounds.
const DIP := 2.2
const TIP_LEAST_DEG := 2.0
const TIP_MOST_DEG := 9.0
## The lean while he stands out on it (m down at the rim at most).
const LEAN := 0.9
const LEAN_MOST_DEG := 4.0
## The spring: its rate (rad/s), damping; the kick's share of a full swing.
const W := 3.4
const ZETA := 0.32
## The lurch on the walker (m/s at a full kick tip), and how long a kick
## counts as fresh for it (s).
const LURCH := 3.1
const LURCH_FOR := 1.1
## Settled this near rest (rad, rad/s), the node set back exactly.
const REST := 0.0006

class Tip:
	var node: Node3D
	var rest: Transform3D
	var pivot := Vector3.ZERO
	var r := 10.0
	var size := 10.0
	var tip := Vector2.ZERO
	var v := Vector2.ZERO
	var goal := Vector2.ZERO
	var peak := 0.0
	var kicked := -INF
	var before: Transform3D
	## What rides it (a place's live bits: its fires, its hub), and their rests.
	var riders: Array = []
	var rider_rest: Array = []
	## The steep mode's (`steep`): held at `hold` (rad, x and z) on its own
	## spring, its riders carry the walker too, no lurch (his motor's own
	## surf takes him down it).
	var held := false
	var hold := Vector2.ZERO

var field: Node = null
var study: Node3D = null
## Nodes never tipped (the stage and what holds it, the field).
var never: Array = []
## The nodes that ride a tipping node (`riders.call(node, box)`: Array of
## Node3D), e.g. the place's live host when the whole place tips.
var riders := Callable()
var tips: Array = []
## Counted, for checks: kicks, those that tipped a stone, the walker
## carried frames and lurched frames, the most tip (deg), the last node.
var kicks := 0
var tipped := 0
var carried := 0
var lurched := 0
var most_deg := 0.0
var last_node := ""
var last_size := 0.0
var _size_cache := {}
var _clock := 0.0

## The steep mode (the Olmec field's tilt set piece, docs/design/olmec-boss/
## spec-olmec-boss.md "The tilt"): a whole field, past TIP_MOST, tipped on
## purpose about `pivot` toward `way` to `deg` and held there (far past
## TIP_MOST_DEG: too steep to walk up) on a slower, heavier spring, till
## `steep_release` eases it back. Only `steep` makes one: every other use of
## this tilt is as before.
const STEEP_W := 1.25
const STEEP_ZETA := 0.62
## Its spring once let go (rad/s, damping): its own, so a release can be
## made to snap (STEEP_ZETA under 1 overshoots).
var steep_w := STEEP_W
var steep_zeta := STEEP_ZETA
var steep_tip: Tip = null

func _init() -> void:
	name = "OlmecTilt"

## His weight come down at `at` (`power`): the stone under it kicked over.
func weigh(body: Node3D, at: Vector3, power: float) -> Tip:
	kicks += 1
	var t := tip_at(at,body)
	if field != null:
		field.sound(&"isle_groan",at)
		Dust.rocks(field,at,Vector3.DOWN,6,0.4)
	if t == null: return null
	var flat := Vector2(at.x-t.pivot.x,at.z-t.pivot.z)
	if flat.length() < 0.5: return t
	var dir := flat.normalized()
	var deg := clampf(rad_to_deg(DIP*power/maxf(t.r,1.0)),TIP_LEAST_DEG,TIP_MOST_DEG)
	# The kick's speed for a peak of `deg` (an underdamped spring peaks at
	# about v/W less its damping).
	var kick := deg_to_rad(deg)*W/0.62
	t.v += dir*kick
	t.peak = maxf(t.peak,deg_to_rad(deg))
	t.kicked = _clock
	tipped += 1
	last_node = str(t.node.name)
	last_size = t.size
	return t

## The steep mode: `node` (a whole field) tipped about `pivot` toward
## `way` (x, z: that side goes down) to `deg`, held; `riders` (Node3D) are
## posed with it and carry the walker as it does. Again while one is on:
## its goal set anew.
func steep(node: Node3D, pivot: Vector3, way: Vector2, deg: float, ride: Array = []) -> Tip:
	if steep_tip != null and steep_tip.node == node and is_instance_valid(node):
		steep_tip.hold = way.normalized()*deg_to_rad(deg)
		steep_tip.held = true
		return steep_tip
	var t := Tip.new()
	t.node = node
	t.rest = node.global_transform
	t.before = t.rest
	t.pivot = pivot
	var box := _flat_box(node)
	t.size = maxf(box.size.x,box.size.z)
	t.r = t.size*0.5
	for r: Variant in ride:
		if r == null or not is_instance_valid(r) or r == node or node.is_ancestor_of(r): continue
		t.riders.append(r)
		t.rider_rest.append((r as Node3D).global_transform)
	t.held = true
	t.hold = way.normalized()*deg_to_rad(deg)
	t.kicked = _clock
	steep_tip = t
	tips.append(t)
	kicks += 1
	tipped += 1
	last_node = str(node.name)
	last_size = t.size
	return t

## The steep tip let go: it eases (or snaps) back to rest on its spring.
func steep_release() -> void:
	if steep_tip != null: steep_tip.held = false

## The steep tip now (deg), 0 with none.
func steep_deg() -> float:
	return rad_to_deg(steep_tip.tip.length()) if steep_tip != null else 0.0

## The steep tip's turn now (identity with none): a rest point times it is
## where that point stands tipped.
func steep_turn() -> Transform3D:
	if steep_tip == null or steep_tip.tip.length() < 1e-6: return Transform3D.IDENTITY
	return _turn(steep_tip)

## A rider added to the steep tip as it stands (its rest read back through
## the tip now), e.g. the rubble of a piece broken meanwhile.
func steep_ride(r: Node3D) -> void:
	if steep_tip == null or r == null or steep_tip.riders.has(r): return
	steep_tip.riders.append(r)
	steep_tip.rider_rest.append(steep_turn().affine_inverse()*r.global_transform)

## The tip for the stone under `at` (made once), or null.
func tip_at(at: Vector3, body: Node3D = null) -> Tip:
	var node := _node_under(at,body)
	if node == null: return null
	for t: Tip in tips:
		if t.node == node: return t
	var box := _flat_box(node)
	var t := Tip.new()
	t.node = node
	t.rest = node.global_transform
	t.before = t.rest
	t.pivot = Vector3(box.get_center().x,at.y,box.get_center().z)
	t.size = maxf(box.size.x,box.size.z)
	t.r = maxf(Vector2(at.x-t.pivot.x,at.z-t.pivot.z).length(),t.size*0.35)
	if riders.is_valid():
		for r: Node3D in riders.call(node,box):
			if r == null or not is_instance_valid(r) or r == node or node.is_ancestor_of(r): continue
			t.riders.append(r)
			t.rider_rest.append(r.global_transform)
	tips.append(t)
	return t

## The largest node over the collider under `at` that may tip.
func _node_under(at: Vector3, body: Node3D) -> Node3D:
	if study == null: return null
	var q := PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.5,at-Vector3.UP*3.0,WalkerOnly.strip(study.ground.mask))
	if body != null and body.get("body") is CollisionObject3D: q.exclude = [(body.get("body") as CollisionObject3D).get_rid()]
	var hit := study.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider is Node3D): return null
	var n: Node3D = hit.collider
	if field != null and (field == n or field.is_ancestor_of(n)): return null
	var best: Node3D = null
	while n != null:
		if _barred(n): break
		var box := _flat_box(n)
		var wide := maxf(box.size.x,box.size.z)
		if wide > TIP_MOST: break
		if wide >= TIP_LEAST: best = n
		var up := n.get_parent() as Node3D
		n = up
	return best

func _barred(n: Node) -> bool:
	if n == study or n == get_tree().current_scene: return true
	for b: Node in never:
		if b != null and is_instance_valid(b) and (b == n or n.is_ancestor_of(b)): return true
	return false

## `n`'s meshes' box (world), cached.
func _flat_box(n: Node3D) -> AABB:
	var key := n.get_instance_id()
	if _size_cache.has(key): return _size_cache[key]
	var box := AABB()
	var got := false
	var list: Array = n.find_children("*","GeometryInstance3D",true,false)
	if n is GeometryInstance3D: list.append(n)
	for g: Node in list:
		var gi := g as GeometryInstance3D
		if gi is MultiMeshInstance3D: continue
		if not gi.is_visible_in_tree(): continue
		var bb: AABB = gi.global_transform*gi.get_aabb()
		box = bb if not got else box.merge(bb)
		got = true
	if not got: box = AABB(n.global_position,Vector3.ZERO)
	_size_cache[key] = box
	return box

## A frame: each Olmec's lean on the stone under him, the springs, the
## stones posed, the walker carried and lurched.
func step(delta: float, bodies: Array) -> void:
	_clock += delta
	for t: Tip in tips: t.goal = t.hold if t.held else Vector2.ZERO
	for b: Node3D in bodies:
		if not is_instance_valid(b) or not bool(b.grounded) or str(b.state) in ["climb","mantle","hang","grab_leap","leap","fall"]: continue
		var t := _tip_holding(b)
		if t == null: continue
		var flat := Vector2(b.position.x-t.pivot.x,b.position.z-t.pivot.z)
		var out := clampf(flat.length()/maxf(t.r,1.0),0.0,1.0)
		if out < 0.2: continue
		var deg := minf(rad_to_deg(LEAN*out/maxf(t.r,1.0)),LEAN_MOST_DEG)
		t.goal += flat.normalized()*deg_to_rad(deg)
	var m: PilotMotor = study.motor if study != null else null
	var under: Object = _walker_under(m)
	var keep: Array = []
	for t: Tip in tips:
		if not is_instance_valid(t.node):
			continue
		var h := 1.0/240.0
		var left := delta
		var w := W
		var zeta := ZETA
		if t == steep_tip:
			w = STEEP_W if t.held else steep_w
			zeta = STEEP_ZETA if t.held else steep_zeta
		while left > 0.0:
			var dt := minf(h,left)
			t.v += (w*w*(t.goal-t.tip)-2.0*zeta*w*t.v)*dt
			t.tip += t.v*dt
			left -= dt
		most_deg = maxf(most_deg,rad_to_deg(t.tip.length()))
		t.before = t.node.global_transform
		var settled := t.tip.length() < REST and t.v.length() < REST*4.0 and t.goal == Vector2.ZERO
		var turn := Transform3D.IDENTITY if settled else _turn(t)
		t.node.global_transform = turn*t.rest
		for k in range(t.riders.size()):
			if is_instance_valid(t.riders[k]): (t.riders[k] as Node3D).global_transform = turn*(t.rider_rest[k] as Transform3D)
		var moved: Transform3D = t.node.global_transform*t.before.affine_inverse()
		# The walker on it: carried as it tips, and lurched toward the low
		# side while a kick is fresh.
		if m != null and under != null and under is Node and (under == t.node or t.node.is_ancestor_of(under) or (t.held or t == steep_tip) and _on_rider(t,under)):
			if m.grounded and m.rider == null and not m.seized():
				m.carry(moved,0.0)
				carried += 1
				var fresh := clampf(1.0-(_clock-t.kicked)/LURCH_FOR,0.0,1.0)
				if fresh > 0.0 and t.peak > 0.0:
					var fall := t.tip
					var k := clampf(fall.length()/t.peak,0.0,1.0)*fresh
					if k > 0.05:
						var step_v := fall.normalized()*LURCH*k*delta
						var dest: Vector3 = study.ground.slide(m.feet,step_v)
						m.carry(Transform3D(Basis.IDENTITY,Vector3(dest.x-m.feet.x,0.0,dest.z-m.feet.z)),0.0)
						lurched += 1
		if settled:
			t.peak = 0.0
			t.v = Vector2.ZERO
			t.tip = Vector2.ZERO
			if t == steep_tip and not t.held:
				# Let go and come to rest: done (its riders exactly back).
				for k in range(t.riders.size()):
					if is_instance_valid(t.riders[k]): (t.riders[k] as Node3D).global_transform = t.rider_rest[k]
				steep_tip = null
				continue
			if _clock-t.kicked > 3.0 and not t.held: continue
		keep.append(t)
	tips = keep

## Whether `under` is one of `t`'s riders or under one.
func _on_rider(t: Tip, under: Object) -> bool:
	for r: Variant in t.riders:
		if is_instance_valid(r) and (r == under or (r as Node).is_ancestor_of(under as Node)): return true
	return false

## The stone's pose at its tip: turned about its pivot, the rim along the
## tip's way going down.
func _turn(t: Tip) -> Transform3D:
	var a := t.tip.length()
	if a < 1e-6: return Transform3D.IDENTITY
	var d := t.tip/a
	# About the flat axis square to the tip's way, so that way goes down.
	var axis := Vector3(d.y,0.0,-d.x).normalized()
	return Transform3D(Basis(axis,a),t.pivot)*Transform3D(Basis.IDENTITY,-t.pivot)

## The tip of the stone `b` stands on, made if it may tip (null none).
func _tip_holding(b: Node3D) -> Tip:
	return tip_at(b.position,b)

## What the walker stands on (a collider), or null.
func _walker_under(m: PilotMotor) -> Object:
	if m == null or not m.grounded: return null
	var q := PhysicsRayQueryParameters3D.create(m.feet+Vector3.UP*0.3,m.feet-Vector3.UP*0.5,study.ground.mask)
	var hit := study.get_world_3d().direct_space_state.intersect_ray(q)
	return null if hit.is_empty() else hit.collider

## Every stone back at rest (a reset).
func settle_all() -> void:
	for t: Tip in tips:
		if is_instance_valid(t.node): t.node.global_transform = t.rest
		for k in range(t.riders.size()):
			if is_instance_valid(t.riders[k]): (t.riders[k] as Node3D).global_transform = t.rider_rest[k]
	tips.clear()
	steep_tip = null
