extends "res://scripts/kit_isle/break_pieces.gd"
## Any kit piece broken by its kind (spec: docs/design/kit-breaks/
## spec-kit-breaks.md): a breakable for the hub's `others` (scripts/
## kit_isle/breakables.gd) holding the pieces of a place, each cut by its
## break kind (scripts/kit_isle/break_kinds.gd) on the first hit strong
## enough to break it. Until then nothing about a piece changes: `adopt`
## only notes where it stands.
##
## A hit (`hit`, or the Olmec's bulk through `met`) on a piece: it is built
## again in its kind's parts (what stands, the falling parts), the whole
## swapped for what stands, the parts let go as bodies (the base's fall,
## cap, rubble and `changed`), out from where it was hit.
const Kinds = preload("res://scripts/kit_isle/break_kinds.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")

## The pieces: [{node, kind, tough, box (its frame), xf, seed, rebuild, alive}].
var targets: Array = []
## Pieces broken, and the cut of the last (ms).
var broken := 0

## Every piece under `root` with a kind (Kinds `kind_of`) noted as a
## target. Returns how
## many were added. A piece with meta "breakable" false is left out.
func adopt(root: Node) -> int:
	var n := 0
	for node: Node in root.find_children("*","Node3D",true,false):
		if not node.has_meta("kit_piece") and not node.has_meta("break_kind"): continue
		if node.has_meta("breakable") and not bool(node.get_meta("breakable")): continue
		var kind := Kinds.kind_of(node)
		if kind == "" or not Kinds.has(kind): continue
		if add(node as Node3D,kind) >= 0: n += 1
	return n

## `node` a target of `kind`; `rebuild` builds it again (honouring RuinKit
## Build.keep_only): by default its "kit_piece" recipe. Its index, or -1.
func add(node: Node3D, kind: String, rebuild := Callable(), seed_value := -1) -> int:
	var box := _box_of(node)
	if box.size == Vector3.ZERO: return -1
	var recipe: Array = node.get_meta("kit_piece",[]) as Array
	if not rebuild.is_valid() and recipe.size() == 3:
		rebuild = func() -> Node3D: return RuinKit.piece(str(recipe[0]),int(recipe[1]),float(recipe[2]))
	if seed_value < 0: seed_value = int(recipe[1]) if recipe.size() == 3 else hash(node.name)
	targets.append({"node":node,"kind":kind,"tough":Kinds.toughness(node,kind),"box":box,"seed":seed_value,
		"rebuild":rebuild,"alive":true})
	_refresh_rids()
	return targets.size()-1

## Its stone's bounds in its own frame (every mesh under it).
func _box_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse() if node.is_inside_tree() else Transform3D.IDENTITY
	for m: Node in node.find_children("*","MeshInstance3D",true,false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var xf := inv*mi.global_transform if node.is_inside_tree() else _local_of(node,mi)
		var b := xf*mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

func _local_of(node: Node3D, under: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var up: Node = under
	while up != node and up is Node3D:
		xf = (up as Node3D).transform*xf
		up = up.get_parent()
	return xf

## The bodies of what stands and breaks to him (his rays look through them,
## he walks into them): pieces he is strong enough for that aren't ground.
func _standing_bodies() -> Array[RID]:
	var out: Array[RID] = []
	var olmec := float(hub.strength_of(&"olmec")) if hub != null else 1.0
	for t: Dictionary in targets:
		if not t.alive or float(t.tough) > olmec or str(t.kind) in ["slab","stair"]: continue
		var node: Node3D = t.node
		if not is_instance_valid(node): continue
		for b: Node in node.find_children("*","CollisionObject3D",true,false): out.append((b as CollisionObject3D).get_rid())
	return out

## The world point of target `t` nearest `at`.
func _nearest(t: Dictionary, at: Vector3) -> Vector3:
	var xf: Transform3D = (t.node as Node3D).global_transform
	var box: AABB = t.box
	var lp := xf.affine_inverse()*at
	return xf*Vector3(clampf(lp.x,box.position.x,box.end.x),clampf(lp.y,box.position.y,box.end.y),clampf(lp.z,box.position.z,box.end.z))

# --- The hub's calls --------------------------------------------------------------------------

func hit(at: Vector3, radius: float, strength: float, _source: StringName) -> int:
	var n := 0
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if not t.alive or not is_instance_valid(t.node) or strength < float(t.tough): continue
		var q := _nearest(t,at)
		if q.distance_to(at) > radius: continue
		var out := Vector3(q.x-at.x,0.0,q.z-at.z)
		var centre: Vector3 = (t.node as Node3D).global_transform*(t.box as AABB).get_center()
		if out.length() < 0.05: out = Vector3(centre.x-at.x,0.0,centre.z-at.z)
		_break(i,q,out.normalized() if out.length() > 0.05 else Vector3.FORWARD,Vector3.ZERO,null)
		n += 1
	if n > 0: _pause()
	return n

## His bulk this frame: a piece he's strong enough for that it touches
## breaks where it meets him, over the way he goes.
func met(body: Node3D) -> void:
	var olmec := float(hub.strength_of(&"olmec")) if hub != null else 1.0
	var hh: float = body.hh
	var hw := hh*HeadlessBody.BULK_W
	var hl := hh*HeadlessBody.BULK_L
	var low: float = body.position.y+0.3
	var high: float = body.position.y+float(body._bulk_top())
	var inv := Basis(Vector3.UP,float(body.facing)).inverse()
	var fwd: Vector3 = body._forward3()
	var any := false
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if not t.alive or not is_instance_valid(t.node) or olmec < float(t.tough): continue
		var mid := Vector3(body.position.x,(low+high)*0.5,body.position.z)
		var q := _nearest(t,mid)
		if q.y < low or q.y > high: continue
		var rel := inv*(q-body.position)
		if absf(rel.x) > hw or absf(rel.z) > hl: continue
		_break(i,q,fwd,body.vel,body)
		any = true
	if any: _pause()

func wave(_body: Node3D, _w: Dictionary) -> void:
	pass

func veer(_body: Node3D, heading: float) -> float:
	return heading

func ahead(_body: Node3D) -> bool:
	return false

func smash(_body: Node3D) -> void:
	pass

# --- A break --------------------------------------------------------------------------------

## Target `i` cut by its kind where `at` (world) met it, its parts going
## over along `dir` (flat), with `push` (his way) on them; `his` a body its
## parts pass through, or null.
func _break(i: int, at: Vector3, dir: Vector3, push: Vector3, his: Variant) -> void:
	var t: Dictionary = targets[i]
	t.alive = false
	var node: Node3D = t.node
	var xf := node.global_transform
	var inv := xf.affine_inverse()
	var cut_t := {"node":node,"box":t.box,"at":inv*at,"dir":inv.basis*dir,"seed":t.seed,"rebuild":t.rebuild}
	var began := Time.get_ticks_usec()
	var cut := Kinds.cut(str(t.kind),cut_t)
	cut_ms = (Time.get_ticks_usec()-began)/1000.0
	build_ms += cut_ms
	if cut.is_empty():
		t.alive = true
		return
	broken += 1
	var parent := node.get_parent()
	var stands: Node3D = cut.get("stands")
	if stands != null:
		parent.add_child(stands)
		stands.global_transform = xf
	parent.remove_child(node)
	node.queue_free()
	var group := _new_group(at)
	group.stump = stands
	var foot := xf*Vector3((t.box as AABB).get_center().x,(t.box as AABB).position.y,(t.box as AABB).get_center().z)
	var fall: Array = cut.get("parts",[])
	for part: Dictionary in fall:
		var pat: Vector3 = xf*(part.at as Vector3)
		var out := Vector3(pat.x-at.x,0.0,pat.z-at.z)
		var away := (out.normalized()*0.5+dir*0.5).normalized() if out.length() > 0.05 else dir
		var axis := Vector3.UP.cross(away).normalized()
		var high := clampf((pat.y-foot.y)/maxf((t.box as AABB).size.y,0.5),0.0,1.0)
		var ang := axis*_rng.randf_range(0.5,1.0)*(0.6+high)+Vector3.UP*_rng.randf_range(-0.3,0.3)
		var lin := away*_rng.randf_range(0.6,1.4)*(0.5+high)+push*0.3
		var rb := _body_of([{"mesh":part.mesh,"shape":part.shape,"local":Transform3D.IDENTITY,"kg":float(part.kg)}],Transform3D(xf.basis,pat))
		rb.angular_damp = 0.9
		if his is PhysicsBody3D: rb.add_collision_exception_with(his)
		for other: Variant in group.pieces:
			if is_instance_valid(other): rb.add_collision_exception_with(other as RigidBody3D)
		# The top goes a beat after the bottom: it falls on what fell.
		_go_piece(rb,group,str(part.kind),lin,ang,0.08*high,away,high)
	if group.pieces.is_empty(): _settled(group)
	Dust.plume(self,at,4.0)
	Dust.rocks(self,at,dir,12,0.3)
	_sound(&"ruin_crack",at)
	_sound(&"ruin_fall",foot)
	_shake(QUAKE_PIER*1.2)
	_refresh_rids()
