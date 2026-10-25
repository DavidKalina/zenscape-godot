extends Node3D
## A breakable's shared fall (spec: docs/design/kit-breaks/spec-kit-breaks.md):
## what any break does once it has cut its stone along real joints
## (scripts/breaks/masonry_cuts.gd, RuinKit `Build.keep_only`). Lifted
## out of the colonnade's breaks (scripts/kit_isle/colonnade_breaks.gd,
## which extends this), so every kit piece comes down the same way:
##
##   each piece a Jolt RigidBody3D a second or two (MAX_BODIES live at most
##   across the hub, scripts/breaks/breakables.gd `live_count`; past that
##   a piece skips the physics and is laid as rubble where it would lie);
##   a hard stop puffs dust, thuds, shakes; a column bursts into its drums;
##   still, it freezes where it is: static rubble he and the walker stand
##   on; a break's pieces all at rest are merged into one mesh with what
##   stands of it, and `changed(box)` tells every body to read its ground
##   afresh.
##
## A breakable answers the hub (`others`) with `standing_rids`,
## `rubble_rids`, and `hit(at, radius, strength, source)` (how many things
## it broke). The Olmec's own calls (`met`, `wave`, `veer`, `ahead`,
## `smash`) are a subclass's, each optional.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const Dust = preload("res://scripts/breaks/body_dust.gd")

## Live pieces at most (scripts/native_explosives.gd's MAX_BODIES, at this
## scale), across the hub: past it a piece lands as rubble at once.
const MAX_BODIES := 24
## A piece this still (m/s, rad/s) this long (s) is rubble.
const STILL_V := 0.35
const STILL_W := 0.6
const STILL_FOR := 0.25
## Live this long (s) and slow, it is frozen where it is; falling on past
## LIVE_MOST (off the isle), it is gone.
const SETTLE_MOST := 3.5
const LIVE_MOST := 8.0
## A drum's radius, the capital's (laid past the cap), stone's weight.
const DRUM_R := 0.55
const CAPITAL := Vector2(0.66,0.62)
const STONE_KG := 2300.0
## The pause on impact: the game this slow this many frames.
const HITSTOP_FRAMES := 3
const HITSTOP_SCALE := 0.15
## A column bursting into its drums where it hits (a stop this hard, m/s,
## after this long, s), the drums keeping this share of its way.
const BURST_V := 1.6
const BURST_AFTER := 0.3
const BURST_KEEP := 0.65
## The ground's shake: a landing's, a slab's.
const QUAKE_PIER := 0.35
const QUAKE_LAND := 0.45
const QUAKE_SLAB := 0.9
const QUAKE_FADE := 1.4
## Placeholder sounds (studies/enemy_yard.gd `_synth`: seconds, tone, tone at
## the end, noise share, low-pass, attack, tremolo) and their reach (m).
const VOICES := {
	"ruin_crack":[0.35,0.0,0.0,1.0,0.55,0.001,0.0],
	"ruin_fall":[1.6,38.0,24.0,0.8,0.07,0.04,6.0],
	"ruin_thud":[0.45,60.0,38.0,0.55,0.16,0.002,0.0],
	"ruin_boom":[1.2,42.0,26.0,0.7,0.06,0.003,0.0],
}
const REACH := {"ruin_crack":36.0,"ruin_fall":50.0,"ruin_thud":20.0,"ruin_boom":70.0}
## His shove (`shove`): rubble this near his bulk (m) is let loose again,
## a live piece till he has gone on (NEAR_HOLD s) and it rests; a piece in
## his bulk goes at least his way and speed and out to his side (PUSH_OUT
## m/s, all of it at his middle), rolling over the ground; a piece born
## of a break feels him only past PUSH_AFTER s (not shoved out of the
## blow that broke it).
const LOOSE_REACH := 1.2
const NEAR_HOLD := 0.6
const PUSH_OUT := 2.4
const PUSH_ROLL := 0.8
const PUSH_AFTER := 0.3

## The hub (scripts/breaks/breakables.gd) this answers to, or null (then
## its own pause, `field` and `sound_hook`).
var hub: Node = null
## Live pieces: {rb, t, still, group, v, kind, wait, lin, ang, burst}.
var live: Array = []
## The scene's enemies (scripts/enemies/enemy_field.gd), told of new rubble
## (when there is no hub).
var field: Node = null
## (name, at): the scene's sound.
var sound_hook := Callable()
## Under this (world y) a piece is gone.
var lost_y := -INF
## The ground's shake now (the hub, and the study's camera, read it).
var quake := 0.0
## A flat piece laid past the cap rests this high over the ground (m).
var flat_rest := 0.3
var _rids: Array[RID] = []
var _rubble: Array[RID] = []
## Each piece's break and kind: {rb: [group, kind]} (`shove` lets rubble
## loose again).
var _group_of := {}
var _near_box := BoxShape3D.new()
var _near_q := PhysicsShapeQueryParameters3D.new()
## The slabs come to rest (a wall's, the gable's): ankle-deep to him, he
## wades them as if they were not there (never a heap to climb or plan
## round); the walker climbs them.
var _wade: Array[RID] = []
var _rng := RandomNumberGenerator.new()
var _seed := 0
var _hitstop := 0
var _material := PhysicsMaterial.new()
## Counted, for checks and the HUD.
var peak_live := 0
var landed_direct := 0
var settled_groups := 0
var loosened := 0
var shoved := 0
var bursts := 0
## The longest a break took to build at hit time (ms), and the pre-cuts (ms).
var build_ms := 0.0
var cut_ms := 0.0

func _init() -> void:
	_material.friction = 0.9
	_material.bounce = 0.05

## What still stands, and the pieces still flying (left out of the body's
## rays: he walks through the one, and the other is gone in a moment).
func standing_rids() -> Array[RID]:
	return _rids

## The rubble come to rest: ground to him (his feet and his routes read it),
## but his bulk and legs wade through it, never shoved back off it.
func rubble_rids() -> Array[RID]:
	return _rubble

## Override: the bodies of what still stands.
func _standing_bodies() -> Array[RID]:
	return []

func _refresh_rids() -> void:
	_rids.clear()
	_rids.append_array(_standing_bodies())
	for p: Dictionary in live: _rids.append((p.rb as RigidBody3D).get_rid())
	_rids.append_array(_wade)

## Override: a hit at `at` (world) reaching `radius` m, of `strength` (the
## breaker's: 1 the Olmec's), from `source` (the hub's breaker name).
## Returns how many things it broke.
func hit(_at: Vector3, _radius: float, _strength: float, _source: StringName) -> int:
	return 0

func _pause(frames := HITSTOP_FRAMES, scale := HITSTOP_SCALE) -> void:
	if hub != null:
		hub.pause(frames,scale)
		return
	if _hitstop <= 0 or scale < Engine.time_scale: Engine.time_scale = scale
	_hitstop = maxi(_hitstop,frames)

func _shake(k: float) -> void:
	quake = maxf(quake,k)

func _sound(sound_name: StringName, at: Vector3) -> void:
	if sound_hook.is_valid(): sound_hook.call(sound_name,at)
	elif hub != null: hub.sound(sound_name,at)

## Live pieces across the hub (or here, with none): against MAX_BODIES.
func _count() -> int:
	return int(hub.live_count()) if hub != null else live.size()

# --- A break --------------------------------------------------------------------------------

func _new_group(at: Vector3) -> Dictionary:
	return {"pieces":[],"left":0,"box":AABB(at,Vector3.ZERO),"stump":null}

# --- The pieces -----------------------------------------------------------------------------

## A built piece's "Mesh", let go of the piece.
func _mesh_of(piece: Node3D) -> MeshInstance3D:
	var mesh := piece.get_node("Mesh") as MeshInstance3D
	piece.remove_child(mesh)
	piece.free()
	return mesh

## A rigid body at `xf` of `subs` ([{mesh, shape, local, kg}]): their
## meshes and shapes its own, at their `local`.
func _body_of(subs: Array, xf: Transform3D) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "Piece"
	rb.collision_layer = 1
	rb.collision_mask = 1
	var kg := 0.0
	for s: Dictionary in subs:
		var holder := CollisionShape3D.new()
		holder.shape = s.shape
		holder.transform = s.local
		rb.add_child(holder)
		var mesh: MeshInstance3D = s.mesh
		if mesh.get_parent() != null: mesh.get_parent().remove_child(mesh)
		mesh.transform = s.local
		rb.add_child(mesh)
		kg += float(s.kg)
	rb.mass = maxf(kg,50.0)
	rb.physics_material_override = _material
	add_child(rb)
	rb.global_transform = xf
	return rb

## `rb` set going (`lin`, `ang`) once `wait` s have gone (held where it
## stands till then); past MAX_BODIES, laid as rubble at once.
func _go_piece(rb: RigidBody3D, group: Dictionary, kind: String, lin: Vector3, ang: Vector3, wait: float, dir: Vector3, up: float) -> void:
	group.pieces.append(rb)
	group.box = (group.box as AABB).expand(rb.global_position)
	_group_of[rb] = [group,kind]
	if _count() >= MAX_BODIES:
		_lay(rb,dir,up,kind)
		landed_direct += 1
		return
	if wait > 0.0:
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
	else:
		rb.linear_velocity = lin
		rb.angular_velocity = ang
	group.left += 1
	live.append({"rb":rb,"t":0.0,"still":0.0,"group":group,"v":lin,"kind":kind,"wait":wait,"lin":lin,"ang":ang,"burst":[]})
	peak_live = maxi(peak_live,live.size())

## Past the cap: laid where it would lie, a little along `dir` from where it
## stood, on its side (a column, a drum, the capital) or flat (a lintel's
## half, a slab, a chunk), and frozen there.
func _lay(rb: RigidBody3D, dir: Vector3, up: float, kind: String) -> void:
	var from := rb.global_position+dir*(0.6+2.4*up)
	var skip: Array[RID] = [rb.get_rid()]
	skip.append_array(_rids)
	var q := PhysicsRayQueryParameters3D.create(from+Vector3.UP*2.0,from+Vector3.DOWN*30.0,1,skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground: float = (hit.position as Vector3).y if not hit.is_empty() else from.y-2.0
	var lie := Basis(Vector3.UP,_rng.randf_range(-PI,PI))
	var rest := flat_rest
	var axis := Vector3.UP.cross(dir).normalized()
	if kind in ["drum","column"]:
		lie = Basis(axis,PI*0.5)*Basis(Vector3.UP,_rng.randf_range(-PI,PI))
		rest = DRUM_R*0.92
	elif kind == "capital":
		lie = Basis(axis,_rng.randf_range(1.2,1.6))
		rest = CAPITAL.x*0.85
	elif kind in ["slab","chunk"]:
		lie = Basis(axis,PI*0.5)*rb.global_transform.basis
		rest = 0.6
	else:
		lie = Basis(Vector3.UP,atan2(dir.x,dir.z)+_rng.randf_range(-0.6,0.6)+PI*0.5)
	rb.global_transform = Transform3D(lie,Vector3(from.x,ground+rest,from.z))
	_freeze(rb)

func _freeze(rb: RigidBody3D) -> void:
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	rb.freeze = true
	_rubble.append(rb.get_rid())

## A column come down hard: burst into its drums and capital, each going on
## with the column's way at its own place (BURST_KEEP of it), a little apart.
func _burst(p: Dictionary) -> Array:
	var rb: RigidBody3D = p.rb
	var subs: Array = p.burst
	var out: Array = []
	if _count()+subs.size()-1 > MAX_BODIES: return out
	bursts += 1
	var xf := rb.global_transform
	var v := rb.linear_velocity
	var w := rb.angular_velocity
	var com := rb.global_position
	var group: Dictionary = p.group
	for s: Dictionary in subs:
		var mesh: MeshInstance3D = s.mesh
		var sx := xf*(s.local as Transform3D)
		rb.remove_child(mesh)
		var piece := _body_of([{"mesh":mesh,"shape":s.shape,"local":Transform3D.IDENTITY,"kg":float(s.kg)}],sx)
		var at := sx.origin
		var lin := (v+w.cross(at-com))*BURST_KEEP+Vector3(_rng.randf_range(-0.6,0.6),_rng.randf_range(0.2,0.9),_rng.randf_range(-0.6,0.6))
		var ang := w*BURST_KEEP+Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0))
		piece.linear_velocity = lin
		piece.angular_velocity = ang
		group.pieces.append(piece)
		_group_of[piece] = [group,String(s.get("kind","drum"))]
		out.append({"rb":piece,"t":0.0,"still":0.0,"group":group,"v":lin,"kind":String(s.get("kind","drum")),"wait":0.0,"lin":lin,"ang":ang,"burst":[],"soft":String(s.get("kind","drum")) in ["slab","column","chunk"]})
	group.pieces.erase(rb)
	_group_of.erase(rb)
	rb.queue_free()
	return out

# --- The pieces, live -----------------------------------------------------------------------

func _process(delta: float) -> void:
	quake = maxf(0.0,quake-delta*QUAKE_FADE)
	if _hitstop > 0:
		_hitstop -= 1
		if _hitstop == 0: Engine.time_scale = 1.0

func _physics_process(delta: float) -> void:
	if live.is_empty(): return
	var done: Array = []
	var born: Array = []
	for p: Dictionary in live:
		var rb: RigidBody3D = p.rb
		if float(p.wait) > 0.0:
			p.wait -= delta
			if float(p.wait) <= 0.0:
				rb.freeze = false
				rb.linear_velocity = p.lin
				rb.angular_velocity = p.ang
				p.v = p.lin
			continue
		p.t += delta
		var v := rb.linear_velocity
		# A hard stop (it hit the ground or another stone): a puff, a thud.
		var lost_v: float = ((p.v as Vector3)-v).length()
		var heavy: bool = p.kind in ["slab","column","chunk"]
		if lost_v > (1.8 if heavy else 2.5) and float(p.t) > 0.08:
			var hard := minf(lost_v,7.0)
			var low := _ground_under(rb)
			var first: bool = not p.get("landed",false)
			# A knock in the air (stone on stone, well off the ground) only
			# puffs, for a piece that asks (`soft_air`): the plume is the ground's.
			if p.get("soft_air",false) and rb.global_position.y-low.y > 2.5:
				Dust.puff(self,rb.global_position,0.8+0.15*hard)
				p.v = v
				continue
			p["landed"] = true
			# A burst's parts (and a slab's later knocks) only puff: the
			# landing that burst them made the plume.
			if (p.kind == "slab" and not first) or p.get("soft",false):
				Dust.puff(self,rb.global_position,1.2+0.2*hard)
				if lost_v > 3.5 and first: _sound(&"ruin_thud",rb.global_position)
			elif p.kind == "slab":
				Dust.plume(self,low,2.6+0.35*hard)
				Dust.rocks(self,low+Vector3.UP*0.6,Vector3(v.x,0.0,v.z).normalized() if Vector2(v.x,v.z).length() > 0.1 else Vector3.UP,8,0.3)
				_shake(QUAKE_SLAB*clampf(hard/5.0,0.4,1.0))
				_sound(&"ruin_boom",rb.global_position)
			elif heavy:
				Dust.plume(self,low,2.2+0.4*hard)
				_shake(QUAKE_LAND*clampf(hard/5.0,0.4,1.0))
				_sound(&"ruin_thud",rb.global_position)
			else:
				Dust.puff(self,rb.global_position,0.9+0.25*hard)
				if lost_v > 3.5: _sound(&"ruin_thud",rb.global_position)
			# A column bursts into its drums where it hits.
			if p.kind == "column" and not (p.burst as Array).is_empty() and float(p.t) > BURST_AFTER:
				var pieces := _burst(p)
				if not pieces.is_empty():
					born.append_array(pieces)
					p.group.left += pieces.size()
					done.append(p)
					continue
		p.v = v
		if v.length() < STILL_V and rb.angular_velocity.length() < STILL_W: p.still += delta
		else: p.still = 0.0
		var near := float(p.get("near",0.0))
		if near > 0.0:
			# By him still: loose, not rubble yet.
			p.near = near-delta
			p.t = minf(float(p.t),SETTLE_MOST)
		elif float(p.still) >= STILL_FOR or (float(p.t) > SETTLE_MOST and v.length() < 2.0):
			_freeze(rb)
			if p.kind in ["slab","chunk"]: _wade.append(rb.get_rid())
			done.append(p)
		elif rb.global_position.y < lost_y or float(p.t) > LIVE_MOST:
			(p.group.pieces as Array).erase(rb)
			_group_of.erase(rb)
			rb.queue_free()
			done.append(p)
	for p: Dictionary in done:
		live.erase(p)
		p.group.left -= 1
	live.append_array(born)
	peak_live = maxi(peak_live,live.size())
	for p: Dictionary in done:
		if int(p.group.left) <= 0: _settled(p.group)
	if not done.is_empty() or not born.is_empty(): _refresh_rids()

## The ground under a piece (or its middle, none in reach).
func _ground_under(rb: RigidBody3D) -> Vector3:
	var at := rb.global_position
	var skip: Array[RID] = [rb.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(at,at+Vector3.DOWN*8.0,1,skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3)+Vector3.UP*0.3 if not hit.is_empty() else at

## A break's pieces all at rest: drawn as one mesh with what stands of it,
## and its ground read afresh by every body.
func _settled(group: Dictionary) -> void:
	if group.get("merged",false): return
	group.merged = true
	settled_groups += 1
	var root := Node3D.new()
	root.name = "Rubble"
	add_child(root)
	group.root = root
	# Each mesh's way back to its piece (`_unmerge`, his shove).
	var back: Array = []
	group.back = back
	var box: AABB = group.box
	var holders: Array = []
	var take := func(owner_node: Node3D) -> void:
		for m: Node in owner_node.get_children():
			if not m is MeshInstance3D: continue
			var mesh := m as MeshInstance3D
			back.append({"owner":owner_node,"mesh":mesh.mesh,"node":mesh if not _stone(mesh.mesh) else null,
				"xf":mesh.transform,"name":mesh.name,"material":mesh.material_override,"shadow":mesh.cast_shadow})
			var holder := Node3D.new()
			holder.transform = root.global_transform.affine_inverse()*owner_node.global_transform*mesh.transform
			owner_node.remove_child(mesh)
			mesh.transform = Transform3D.IDENTITY
			root.add_child(holder)
			# A mesh not built as RuinKit stone (a registered kind's own)
			# stays itself in the rubble; the stone merges into one.
			if not _stone(mesh.mesh):
				mesh.name = "Own"
				holder.add_child(mesh)
				continue
			mesh.name = "Mesh"
			holder.add_child(mesh)
			holders.append(holder)
	for piece: Variant in group.pieces:
		if not is_instance_valid(piece): continue
		var rb := piece as RigidBody3D
		box = box.expand(rb.global_position)
		take.call(rb)
	# What stands of it: its stone and growth go in; it keeps its own body.
	var stump: Node3D = group.stump
	if stump != null and is_instance_valid(stump): take.call(stump)
	RuinKit.merge(root)
	for h: Node3D in holders: h.free()
	box = box.grow(2.5)
	_changed(box)

## A settled break's merged mesh undone: each piece and its stump given
## its own meshes back, so a piece of it can move again (his shove);
## settling again merges it anew.
func _unmerge(group: Dictionary) -> void:
	group.merged = false
	settled_groups -= 1
	for b: Dictionary in group.get("back",[]):
		var owner_node: Node3D = b.owner
		if not is_instance_valid(owner_node): continue
		var mesh: MeshInstance3D = b.node
		if mesh != null and is_instance_valid(mesh): mesh.get_parent().remove_child(mesh)
		else:
			mesh = MeshInstance3D.new()
			mesh.mesh = b.mesh
			mesh.material_override = b.material
			mesh.cast_shadow = b.shadow
		mesh.name = b.name
		mesh.transform = b.xf
		owner_node.add_child(mesh)
	group.back = []
	var root: Node3D = group.get("root")
	if root != null and is_instance_valid(root): root.queue_free()
	group.root = null

# --- His shove ------------------------------------------------------------------------------

## The Olmec's bulk this frame (`xf`, a box `size` big, turned with him;
## his velocity `vel`): the rubble by it let loose again, and every loose
## piece in it shoved along his way and out to his side, so he plows
## through what he broke rather than wading through it.
func shove(xf: Transform3D, size: Vector3, vel: Vector3) -> void:
	if _group_of.is_empty(): return
	var any := false
	if not _rubble.is_empty():
		_near_box.size = size+Vector3(LOOSE_REACH,0.0,LOOSE_REACH)*2.0
		_near_q.shape = _near_box
		_near_q.transform = xf
		_near_q.collision_mask = 1
		for h: Dictionary in get_world_3d().direct_space_state.intersect_shape(_near_q,32):
			var rb := h.collider as RigidBody3D
			if rb == null or not _group_of.has(rb) or not rb.get_rid() in _rubble: continue
			if _count() >= MAX_BODIES: break
			_loosen(rb)
			any = true
	if any: _refresh_rids()
	if live.is_empty(): return
	var inv := xf.affine_inverse()
	var half := size*0.5
	var his := Vector3(vel.x,0.0,vel.z)
	for p: Dictionary in live:
		var rb: RigidBody3D = p.rb
		if float(p.wait) > 0.0 or float(p.t) < PUSH_AFTER or not is_instance_valid(rb): continue
		var c := rb.global_position
		var rel := inv*c
		var r: float = p.get("r",-1.0)
		if r < 0.0:
			r = _reach_of(rb)
			p.r = r
		var lx := half.x+LOOSE_REACH
		var lz := half.z+LOOSE_REACH
		if absf(rel.x) < lx and absf(rel.z) < lz and rel.y > -half.y-r and rel.y < half.y+r: p.near = NEAR_HOLD
		if absf(rel.x) > half.x+r or absf(rel.z) > half.z+r or absf(rel.y) > half.y+r: continue
		# Out to his nearer side (ahead of him, the side it is on), the
		# deeper in the harder; along his way at his speed.
		var side := Vector3(signf(rel.x) if absf(rel.x) > 0.05 else 1.0,0.0,0.0)
		var depth := 1.0-clampf(absf(rel.x)/(half.x+r),0.0,1.0)
		var out := xf.basis*side
		out.y = 0.0
		out = out.normalized()
		var want := his+out*PUSH_OUT*(0.35+0.65*depth)
		var v := rb.linear_velocity
		var along := want.normalized()
		var s := v.dot(along)
		if s < want.length(): v += along*(want.length()-s)
		rb.linear_velocity = v
		# Over the ground it rolls the way it goes.
		var roll := Vector3.UP.cross(along)*want.length()*PUSH_ROLL/maxf(r,0.3)
		rb.angular_velocity = rb.angular_velocity.lerp(roll,0.25)
		rb.sleeping = false
		shoved += 1

## Rubble `rb` let loose: a live piece again (its break unmerged first).
func _loosen(rb: RigidBody3D) -> void:
	var of: Array = _group_of[rb]
	var group: Dictionary = of[0]
	if group.get("merged",false): _unmerge(group)
	_rubble.erase(rb.get_rid())
	_wade.erase(rb.get_rid())
	rb.freeze = false
	rb.sleeping = false
	group.left += 1
	loosened += 1
	live.append({"rb":rb,"t":PUSH_AFTER,"still":0.0,"group":group,"v":Vector3.ZERO,"kind":str(of[1]),"wait":0.0,
		"lin":Vector3.ZERO,"ang":Vector3.ZERO,"burst":[],"soft":true,"landed":true,"near":NEAR_HOLD})

## Half `rb`'s breadth (m): its shapes' bounds, the longest way.
static func _reach_of(rb: RigidBody3D) -> float:
	var r := 0.3
	for c: Node in rb.get_children():
		var holder := c as CollisionShape3D
		if holder == null or holder.shape == null: continue
		var b := holder.transform*holder.shape.get_debug_mesh().get_aabb()
		r = maxf(r,b.size.length()*0.5)
	return r

## Whether `mesh` merges as RuinKit stone (RuinKit.merge): one surface of
## unindexed triangles with vertex colours.
static func _stone(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() != 1: return false
	if mesh.has_meta("arrays"): return true
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_INDEX] == null

## Rubble at rest in `box`: every body's routes read it afresh.
func _changed(box: AABB) -> void:
	if hub != null:
		hub.changed(box)
		return
	if field != null:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed"): e.world_changed(box)

## The draws the breaks add now (meshes under this, each surface).
func draws() -> int:
	var n := 0
	for m: Node in find_children("*","MeshInstance3D",true,false):
		var mi := m as MeshInstance3D
		if mi.visible and mi.mesh != null: n += mi.mesh.get_surface_count()
	return n
