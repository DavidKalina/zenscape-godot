extends Node3D
## A city kit floor that breaks under the Olmec's weight (docs/design/
## roguelike/city-kit-round1.md): the epic stair's fault landing and the
## causeway's bay (scripts/city_kit.gd `_fault`, `_bay` build it as their
## unit: this script on it, its "Body" and its pre-cut pieces "P0".."Pn").
## A piece of the breakables hub (scripts/kit_isle/breakables.gd): it joins
## the group BREAKABLE and answers the hub's calls.
##
## A floor is ground to him and the walker until it goes (never in
## `standing_rids`, unlike a pier: he would fall through it). It goes when
##   he stands on it (his feet over its top) `weight` s (at a third of it,
##   the tell: a crack and a trickle of dust), or
##   his landing's shockwave starts on it.
## Then its pieces go as Jolt bodies (a little smaller than they stood, so
## none wedges in its old place), the near ones first, tipping out from
## under him, and fall to what is below: the fault's chamber floor, the road
## under the bay (the motif's), or the void (freed). Settled, they are
## slabs he wades (out of his rays, as round 2's) and the walker climbs, and every
## body's routes round them are read afresh (the hub's `changed`).
## Breaks last the session.
const Dust = preload("res://scripts/enemies/body_dust.gd")
const BREAKABLE := &"breakable"

## Each falling piece's box this much smaller across than it stood (m).
const SHRINK := 0.4
## A piece this still (m/s, rad/s) this long (s) is rubble; slow past
## SETTLE_MOST s it is frozen where it is; still falling past LIVE_MOST s
## (off the isle) it is freed.
const STILL_V := 0.35
const STILL_W := 0.6
const STILL_FOR := 0.25
const SETTLE_MOST := 3.5
const LIVE_MOST := 8.0
## The break's weight: the hit-stop (frames at a time scale), the quake.
const HITSTOP := Vector2(4,0.15)
const QUAKE := 0.9

## Set by the kit: "fault" or "bay", the pieces' count, its slab's box
## (unit-local), the seconds his weight takes, each piece's kg.
var kind := "fault"
var count := 0
var box := AABB()
var weight := 0.6
var kg := 1000.0
## Standing still, or down.
var alive := true
var on := 0.0
var told := false
## Where it broke (world) and the hub that broke it.
var broke_at := Vector3.INF
var settled := false
## Live pieces: {rb, t, still, v, wait, lin, ang, landed}.
var live: Array = []
var _rubble: Array[RID] = []
var _hub: Node = null
var _rng := RandomNumberGenerator.new()
var _material := PhysicsMaterial.new()

func _ready() -> void:
	add_to_group(BREAKABLE)
	_rng.seed = hash(name)+count
	_material.friction = 0.9
	_material.bounce = 0.05

# --- The hub's calls -----------------------------------------------------------------

## The live pieces, and the settled slabs: wadeable to him as the
## destruction round's slabs are (round 2: never a heap he plans round or
## climbs; his feet sink into a lying slab), so they are left out of his
## rays. The walker climbs them.
func standing_rids() -> Array[RID]:
	var out: Array[RID] = []
	for p: Dictionary in live: out.append((p.rb as RigidBody3D).get_rid())
	out.append_array(_rubble)
	return out

func rubble_rids() -> Array[RID]:
	return _rubble

## His weight: his feet over its top a beat, and it goes.
func met(hub: Node, body: Node3D) -> void:
	if not alive: return
	var dt := get_physics_process_delta_time()
	var local := global_transform.affine_inverse()*body.position
	var over := local.x > box.position.x-0.5 and local.x < box.end.x+0.5 and local.z > box.position.z-0.5 and local.z < box.end.z+0.5
	if over and absf(local.y-box.end.y) < 1.2:
		on += dt
		if not told and on > weight*0.35:
			told = true
			hub.sound(&"ruin_crack",body.position)
			Dust.puff(self,global_position+Vector3.DOWN*0.6,2.2)
			hub.shake(0.25)
		if on >= weight: break_now(hub,body.position,body._forward3())
	else:
		on = maxf(0.0,on-dt*0.5)

## His landing's shockwave started on it: it goes at once.
func wave(hub: Node, _body: Node3D, w: Dictionary) -> void:
	if not alive: return
	var key := "floor_%d" % get_instance_id()
	if w.has(key): return
	w[key] = true
	var local := global_transform.affine_inverse()*(w.at as Vector3)
	if local.x > box.position.x-1.0 and local.x < box.end.x+1.0 and local.z > box.position.z-1.0 and local.z < box.end.z+1.0 and absf(local.y-box.end.y) < 1.5:
		break_now(hub,w.at,Vector3.ZERO)

## It goes: its body out of the world, its pieces live, the nearest to
## `at` first, each tipping out from under it (`push` his way, flat).
func break_now(hub: Node, at: Vector3, push: Vector3) -> void:
	if not alive: return
	alive = false
	_hub = hub
	broke_at = global_position
	var body := get_node("Body") as StaticBody3D
	var shapes := {}
	for c: Node in body.get_children():
		var cs := c as CollisionShape3D
		var k := String(cs.name).get_slice("_",0)
		if not shapes.has(k): shapes[k] = []
		(shapes[k] as Array).append([cs.shape,cs.transform])
	remove_child(body)
	body.queue_free()
	var flat := Vector3(push.x,0.0,push.z)
	for i in range(count):
		var holder := get_node_or_null("P%d" % i) as Node3D
		if holder == null: continue
		var xf := holder.global_transform
		var mesh := holder.get_node("Mesh") as MeshInstance3D
		holder.remove_child(mesh)
		var rb := RigidBody3D.new()
		rb.name = "Piece%d" % i
		var hinv := holder.transform.affine_inverse()
		for s: Array in shapes.get("P%d" % i,[]):
			var cs := CollisionShape3D.new()
			cs.shape = s[0]
			if s[0] is BoxShape3D:
				var bx := BoxShape3D.new()
				bx.size = ((s[0] as BoxShape3D).size-Vector3(SHRINK,0.04,SHRINK)).max(Vector3.ONE*0.2)
				cs.shape = bx
			cs.transform = hinv*(s[1] as Transform3D)
			rb.add_child(cs)
		mesh.transform = Transform3D.IDENTITY
		rb.add_child(mesh)
		rb.mass = maxf(kg,200.0)
		rb.physics_material_override = _material
		holder.queue_free()
		add_child(rb)
		rb.global_transform = xf
		var out := Vector3(xf.origin.x-at.x,0.0,xf.origin.z-at.z)
		var away := out.normalized() if out.length() > 0.1 else Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()
		var lin := Vector3.DOWN*1.2+away*_rng.randf_range(0.1,0.4)+flat*0.1
		var axis := Vector3.UP.cross(away).normalized()
		var ang := axis*_rng.randf_range(0.6,1.4)+Vector3(_rng.randf_range(-0.2,0.2),_rng.randf_range(-0.3,0.3),_rng.randf_range(-0.2,0.2))
		var wait := clampf(out.length()*0.04,0.0,0.25)
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
		live.append({"rb":rb,"t":0.0,"still":0.0,"v":lin,"wait":wait,"lin":lin,"ang":ang,"landed":false})
	hub.sound(&"ruin_fall",global_position)
	hub.sound(&"ruin_crack",global_position)
	Dust.plume(self,global_position+Vector3.DOWN*0.5,3.6)
	hub.shake(QUAKE)
	hub.pause(int(HITSTOP.x),HITSTOP.y)
	# Its old ground read afresh now (the floor is gone), and again settled.
	hub.changed(AABB(global_position-Vector3(8.0,8.0,8.0),Vector3(16.0,16.0,16.0)))

func _physics_process(delta: float) -> void:
	if live.is_empty(): return
	var done: Array = []
	for p: Dictionary in live:
		var rb: RigidBody3D = p.rb
		if float(p.wait) > 0.0:
			p.wait = float(p.wait)-delta
			if float(p.wait) <= 0.0:
				rb.freeze = false
				rb.linear_velocity = p.lin
				rb.angular_velocity = p.ang
			continue
		p.t = float(p.t)+delta
		var v := rb.linear_velocity
		var lost_v := ((p.v as Vector3)-v).length()
		if lost_v > 1.8 and float(p.t) > 0.08:
			var at := rb.global_position
			if not p.landed:
				p.landed = true
				Dust.plume(self,at,2.6+0.35*minf(lost_v,7.0))
				if _hub != null:
					_hub.shake(QUAKE*clampf(lost_v/5.0,0.4,1.0))
					_hub.sound(&"ruin_boom",at)
			else:
				Dust.puff(self,at,1.6)
		p.v = v
		if v.length() < STILL_V and rb.angular_velocity.length() < STILL_W: p.still = float(p.still)+delta
		else: p.still = 0.0
		if float(p.still) >= STILL_FOR or (float(p.t) > SETTLE_MOST and v.length() < 2.0):
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
			rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			rb.freeze = true
			_rubble.append(rb.get_rid())
			done.append(p)
		elif float(p.t) > LIVE_MOST:
			rb.queue_free()
			done.append(p)
	for p: Dictionary in done: live.erase(p)
	if live.is_empty() and not settled:
		settled = true
		var b := AABB(global_position,Vector3.ZERO)
		for c: Node in get_children():
			if c is RigidBody3D and is_instance_valid(c): b = b.expand((c as Node3D).global_position)
		if _hub != null: _hub.changed(b.grow(3.0))
