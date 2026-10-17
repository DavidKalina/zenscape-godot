extends Node3D
## The rune knight coming apart (body lane task 5): his stone pieces thrown
## loose off the real model (scripts/enemies/rune_knight_look.gd), each on
## its own flight, the stand-in's `_come_apart` and `_step_blocks`
## (scripts/enemies/rune_knight_body_standin.gd) on skinned pieces.
##
##   const Breakup = preload("res://scripts/enemies/rune_knight_breakup.gd")
##   var b := Breakup.new()
##   host.add_child(b)                # anywhere in the world; not under him
##   b.start(look, tall, thrown)      # thrown: shatter; else crumble
##   b.at_rest() -> Vector2i          # (pieces at rest, pieces that flew)
##
## crumble: from where he knelt, the pieces drift out a little and slump
## into a heap where he was (each comes to rest on stone, turf, or a piece
## already resting under it; a piece landing over the heap's cone slips
## off outward). shatter: thrown apart off the ground, spinning, the runes
## and the eye going dark, dust off the impact.
##
## Each piece is skinned rigidly to one bone, its vertices in the model's
## space at rest, so its pose is skeleton x bone pose x the skin's bind
## pose. start() freezes that pose: the skin is dropped and the mesh hung
## under a pivot at its own centre (so it spins about itself), reparented
## here; its material overrides go with it. The model (and its skeleton
## and sockets) is hidden.
const BodyDust = preload("res://scripts/enemies/body_dust.gd")

## The stand-in's numbers (shares of tall where it says so).
## (crumble drifts less than the stand-in: 43 pieces, not ~30 blocks.)
const CRUMBLE_OUT := 0.55
const CRUMBLE_UP := 0.4
const SHATTER_OUT := 2.6
const SHATTER_UP := 2.4
const BLOCK_FALL := 20.0
const BLOCK_BOUNCE := 0.25
const BLOCK_REST := 0.35
const HEAP_TALL := 0.5
const HEAP_SLOPE := 0.8
const HEAP_SLIP := 3.0
## Stacked pieces nest: a piece rests this share of the two half heights
## above the one under it (round stone, turned, doesn't sit box on box).
const NEST := 0.7
## Rays see the world's stone and turf (layer 1) and the aqueduct (12).
const MASK := 1 | (1 << 11)
## A crumbling piece drifting over a drop deeper than this (m) below his
## base stops drifting, so the heap stays on the deck.
const LEDGE := 0.4
## A piece still not at rest after this long is left where it is (s).
const GIVE_UP := 8.0

var tall := 1.9
var thrown := false
var heap_at := Vector3.ZERO
## [pivot, velocity, spin (axis * rad/s), half height, half width, at rest]
var flying: Array = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()

## Throw `look`'s pieces loose. `seed_value` keeps a run repeatable.
func start(look: Node3D, tall_: float, thrown_: bool, seed_value := 11) -> void:
	tall = tall_
	thrown = thrown_
	_rng.seed = seed_value
	top_level = true
	global_transform = Transform3D.IDENTITY
	heap_at = look.global_position
	var mid := heap_at+Vector3.UP*tall*(0.4 if thrown else 0.25)
	var model: Node3D = look.model
	for key in look.pieces:
		var mi := look.pieces[key] as MeshInstance3D
		if mi == null or not is_instance_valid(mi): continue
		var w := _posed(mi)
		var aabb := mi.mesh.get_aabb()
		var c := aabb.get_center()
		var pivot := Node3D.new()
		pivot.name = String(mi.name)
		add_child(pivot)
		pivot.global_transform = Transform3D(w.basis,w*c)
		mi.get_parent().remove_child(mi)
		mi.skin = null
		mi.skeleton = NodePath()
		pivot.add_child(mi)
		mi.transform = Transform3D(Basis(),-c)
		var size := aabb.size*w.basis.get_scale()
		var out := pivot.global_position-mid
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(_rng.randf_range(-1,1),0,_rng.randf_range(-1,1)).normalized()
		var v: Vector3
		var spin := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized()
		if thrown:
			v = out*SHATTER_OUT*tall*_rng.randf_range(0.5,1.3)+Vector3.UP*SHATTER_UP*tall*_rng.randf_range(0.4,1.1)
			spin *= _rng.randf_range(6.0,14.0)
		else:
			v = out*CRUMBLE_OUT*tall*_rng.randf_range(0.2,1.0)+Vector3.UP*CRUMBLE_UP*tall*_rng.randf_range(0.0,0.6)
			spin *= _rng.randf_range(2.5,6.0)
		flying.append([pivot,v,spin,minf(size.y,minf(size.x,size.z))*0.5,Vector2(size.x,size.z).length()*0.5,false])
	model.visible = false
	if thrown:
		for k in look.runes: look.rune_energy(k,0.0)
		look.eye_glow(0.0)
		BodyDust.plume(self,heap_at+Vector3.UP*0.1*tall,0.6*tall)
		BodyDust.puff(self,heap_at+Vector3.UP*0.3*tall,0.4*tall,Vector3.UP*2.0)
	else:
		look.eye_glow(0.0)
		BodyDust.puff(self,heap_at+Vector3.UP*0.2*tall,0.45*tall)

## Where a skinned piece is now: the skeleton's pose of its bone times the
## skin's bind pose for it (vertices are in model space at rest).
func _posed(mi: MeshInstance3D) -> Transform3D:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skel == null or mi.skin == null: return mi.global_transform
	var bone_name := String(mi.name).get_slice("-",0)
	var bi := skel.find_bone(bone_name)
	var skin := mi.skin
	for i in range(skin.get_bind_count()):
		var b := skin.get_bind_bone(i)
		if b == -1: b = skel.find_bone(skin.get_bind_name(i))
		if b == bi:
			return skel.global_transform*skel.get_bone_global_pose(bi)*skin.get_bind_pose(i)
	return mi.global_transform

func at_rest() -> Vector2i:
	var n := 0
	for f: Array in flying:
		if f[5]: n += 1
	return Vector2i(n,flying.size())

func _physics_process(delta: float) -> void:
	if flying.is_empty(): return
	_t += delta
	if _t > GIVE_UP:
		for f: Array in flying: f[5] = true
		return
	var space := get_world_3d().direct_space_state
	for f: Array in flying:
		if f[5]: continue
		var m: Node3D = f[0]
		var v: Vector3 = f[1]
		v += Vector3.DOWN*BLOCK_FALL*delta
		var at := m.global_position
		var to := at+v*delta
		var half: float = f[3]
		if not thrown and (to.x != at.x or to.z != at.z):
			# A crumble stays where he knelt: a piece about to drift off an
			# edge (no floor under it near his base) stops drifting.
			var edge := PhysicsRayQueryParameters3D.create(Vector3(to.x,at.y+half,to.z),Vector3(to.x,heap_at.y-LEDGE,to.z),MASK)
			if space.intersect_ray(edge).is_empty():
				v = Vector3(0.0,v.y,0.0)
				to = Vector3(at.x,to.y,at.z)
		var floor_y := -INF
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*half,to+Vector3.DOWN*half,MASK)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and (hit.normal as Vector3).y >= 0.5:
			floor_y = (hit.position as Vector3).y+half
		elif not hit.is_empty():
			# A wall: it glances off.
			var nrm: Vector3 = hit.normal
			if v.dot(nrm) < 0.0: v -= nrm*v.dot(nrm)*1.4
			to = at+v*delta
		var out := Vector2(to.x-heap_at.x,to.z-heap_at.z)
		var cone := heap_at.y+maxf(HEAP_TALL*tall-HEAP_SLOPE*out.length(),0.0)
		for o: Array in flying:
			if not o[5] or o == f: continue
			var on: Node3D = o[0]
			var off := on.global_position-to
			if Vector2(off.x,off.z).length() < (float(f[4])+float(o[4]))*0.6:
				var top := on.global_position.y+(float(o[3])+half)*NEST
				if top-half <= cone:
					floor_y = maxf(floor_y,top)
				elif to.y-half < on.global_position.y+float(o[3]):
					# Over the heap's cone: it slips off outward.
					var away := out.normalized() if out.length() > 0.01 else Vector2(1.0,0.0).rotated(_rng.randf()*TAU)
					v += Vector3(away.x,0.0,away.y)*HEAP_SLIP*tall*delta
		var spin: Vector3 = f[2]
		if to.y <= floor_y and v.y < 0.0:
			to.y = floor_y
			v = Vector3(v.x*0.5,-v.y*BLOCK_BOUNCE,v.z*0.5)
			spin *= 0.5
			if v.length() < BLOCK_REST*tall:
				f[5] = true
				v = Vector3.ZERO
		if spin.length() > 0.01:
			m.global_basis = Basis(spin.normalized(),spin.length()*delta)*m.global_basis
		m.global_position = to
		f[1] = v
		f[2] = spin
