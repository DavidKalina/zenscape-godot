extends RefCounted
## The sky dragon asleep on its roost (docs/design/dragon-roost/round2.md):
## the flying dragon's own body and dress (scripts/sky_dragon.gd, look c) at
## its own size (sky_dragon.gd SIZE, 1.5, so the same dragon can wake and
## fly) posed lying on its mountain (scripts/kit_isle/motif_dragon_roost.gd),
## with --dragon-roost. It never flies; the dragon hands its frame here
## (`advance`) instead.
##
## The line is the mountain's (Roost `coil`, laid once in `_lay`): the
## spine's rest length (its rest z, head tip to tail tip): the trunk and
## hind legs on the ledge's nest, the tail round its rim, the neck rising
## from the chest round the front of the summit tower on the shelf the rock
## has for it, the head resting on that shelf under the peak. Each point is
## first rested on the rock (the highest the ground reaches under a disc of
## its girth), eased so the line never climbs or falls steeper than SLOPE;
## then settled (`_settle`): the hide skinned on the CPU, each stretch of
## the line brought down (or up) until its lowest hide point lies on the
## ground, a little sunk into the nest's worn floor, never through rock.
##
## The bones follow it as a chain (`_lay_chain`): from the chest and hips (the
## dragon's frame set at the chest), each bone turned so its child's joint
## lands on the line a bone's length on, rolled to the line's up. The wings
## fold close along the flanks (arm back, forearm forward, the fingers back
## along the side, shortened to FOLD of their length: they are single
## 30-odd-metre bones that can't bend with the trunk), the hind legs fold
## at its sides, the jaw is shut and the eyes are lids (the eye surface worn
## as hide, no glow, no night halo).
##
## Asleep: it breathes slowly (BREATH s a breath): the chest swells and
## settles, the neck lifts a little with it, and on each out-breath a faint
## warm haze puffs from the nostrils. Now and then (TWITCH) the tail's tip
## twitches. At night the membranes glow faintly (the dragon's own night
## glow; the folded panels' trailing edges show as rose lines).
const Roost = preload("res://scripts/kit_isle/motif_dragon_roost.gd")

## The coil's line is the mountain's (Roost `coil`: its spine by rest z,
## head tip to tail tip, every COIL_DZ, the chest at CHEST_Z).
const HEAD_TIP := Roost.HEAD_TIP
const CHEST_Z := Roost.CHEST_Z
const DZ := Roost.COIL_DZ
## The line's steepest rise or fall, the gap kept off the rock (m).
const SLOPE := 0.75
const GAP := 0.2
## The folded wing's fingers, this share of their length.
const FOLD := 0.36
## A breath (s), the chest's swell (share), the neck's lift (rad).
const BREATH := 6.5
const SWELL := 0.045
const NECK_LIFT := 0.035
## The tail tip's twitch: seconds between (range), its size (rad).
const TWITCH := Vector2(6.0,14.0)
const TWITCH_SIZE := 0.35

## The dragon's size: the flying dragon's, the one its rock is laid out for.
var size: float = Roost.DRAGON_SIZE
var dragon: Node3D
var skeleton: Skeleton3D
## Where the isle stands from its own frame (world = own + offset).
var offset := Roost.AT
## The line (skeleton space), its ups, by rest z from HEAD_TIP.
var _line := PackedVector3Array()
var _ups := PackedVector3Array()
## And in the world (for checks and captures).
var line_world := PackedVector3Array()
var _bone := {}
var _rest_g := {}
var _rest_local_at := {}
var _t := 0.0
var _twitch_next := 4.0
var _twitch := 0.0
var _twitch_v := 0.0
var _rng := RandomNumberGenerator.new()
var _haze: CPUParticles3D
## The deepest any point of the line sits under the girth it needs (m;
## 0 or more is clear), before settling.
var worst_clear := INF
var _line_ups := PackedVector3Array()
## After settling (`_settle`): the largest gap left between the hide's
## underside and the ground under any stretch of the line (m) and where
## (its point); the same from the chest to the tail's tip (the trunk, legs
## and tail); the deepest the hide sinks into the ground (m, the nest's
## floor allows SINK_NEST), and the folded wings' deepest into it (m).
var worst_gap := 0.0
var worst_gap_at := -1
var body_gap := 0.0
var body_gap_at := -1
var worst_sink := 0.0
var wing_sink := 0.0
## The gap under each stretch of the line after settling (m; INF over a drop).
var gaps_along := PackedFloat32Array()
## The hide's points, skinned on the CPU for settling: rest positions,
## their four bones (skeleton indices), weights, whether a wing's.
var _skin_v := PackedVector3Array()
var _skin_b := PackedInt32Array()
var _skin_w := PackedFloat32Array()
var _skin_wing := PackedByteArray()
var _skin_bind := {}

## Dresses `owner` (a SkyDragon, its model built) for sleep and lays its coil.
func setup(owner: Node3D) -> void:
	dragon = owner
	skeleton = dragon.skeleton
	_rng.seed = 31
	for i in range(skeleton.get_bone_count()):
		var b := skeleton.get_bone_name(i)
		_bone[b] = i
		_rest_g[b] = skeleton.get_bone_global_rest(i)
		_rest_local_at[b] = skeleton.get_bone_rest(i).origin
	_close_eyes(dragon.model)
	(dragon.get("_eye_points") as Array).clear()
	_lay()
	_build_haze()
	advance(0.0)
	_settle()
	print("dragon roost: lying at (%.0f, %.0f, %.0f) at size %.2f; %d line points, %d hide points skinned; the largest gap under its underside: %.2f m along the trunk and tail (line point %d), %.2f m anywhere (line point %d, the neck and head included); the deepest any of it sinks into the ground %.2f m, its folded wings %.2f m" % [dragon.global_position.x,dragon.global_position.y,dragon.global_position.z,size,_line.size(),_skin_v.size(),body_gap,body_gap_at,worst_gap,worst_gap_at,worst_sink,wing_sink])

## Eyes shut: the eye surface worn as the hide (lids), so no glow.
func _close_eyes(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "dragon_eye": mi.set_surface_override_material(i,dragon.call("_material","dragon_hide"))
	for c in n.get_children(): _close_eyes(c)

# --- The coil ----------------------------------------------------------------------------

## Where a body of girth `g` centred over `p` (own frame x, z) rests on the
## rock: the least height its centre can have.
static func _rest_on_rock(p: Vector2, g: float) -> float:
	var best := Roost.ground(p.x,p.y)+g
	for ring: float in [0.45,0.8,1.0]:
		var count := 8 if ring < 0.9 else 12
		for k in range(count):
			var a := TAU*float(k)/float(count)+ring
			var q := p+Vector2(cos(a),sin(a))*g*ring
			best = maxf(best,Roost.ground(q.x,q.y)+g*sqrt(maxf(1.0-ring*ring,0.0)))
	return best

## Lays the line (see the head): the mountain's (Roost `coil`: the head and
## neck round the tower on their shelf, the trunk and tail on the ledge),
## each point rested on the rock (the least height a body of its girth can
## have there, or the line's own if higher), eased; then the dragon's frame
## at the chest and the line into its skeleton's.
func _lay() -> void:
	var coil := Roost.coil()
	var laid: PackedVector3Array = coil.at
	var girth: PackedFloat32Array = coil.girth
	var count := laid.size()
	var need := PackedFloat32Array()
	need.resize(count)
	for i in range(count):
		var flat := Vector2(laid[i].x,laid[i].z)
		need[i] = maxf(_rest_on_rock(flat,girth[i])+GAP,laid[i].y)
	# Eased: never steeper than SLOPE (the highest of the cones down from
	# each need), so it only ever lifts off the rock.
	var ys := PackedFloat32Array()
	ys.resize(count)
	var step := DZ*size*SLOPE
	for i in range(count):
		var y := -INF
		var reach := int(ceil(40.0/step))
		for j in range(maxi(i-reach,0),mini(i+reach+1,count)): y = maxf(y,need[j]-step*absf(float(i-j)))
		ys[i] = y
	var points := PackedVector3Array()
	var ups: PackedVector3Array = coil.up
	worst_clear = INF
	for i in range(count):
		points.append(Vector3(laid[i].x,ys[i],laid[i].z))
		worst_clear = minf(worst_clear,ys[i]-_rest_on_rock(Vector2(laid[i].x,laid[i].z),girth[i]))
	line_world = PackedVector3Array()
	for p in points: line_world.append(p+offset)
	_line_ups = ups
	_frame_line()

## The dragon's frame and its skeleton's line from `line_world`.
func _frame_line() -> void:
	var chest_i := int(round((CHEST_Z-HEAD_TIP)/DZ))
	var ups := _line_ups
	var count := line_world.size()
	# The dragon's frame: its chest's joint on the line, facing along it
	# toward the head, its up the line's there.
	var at := line_world[chest_i]
	var ahead := (line_world[chest_i-1]-line_world[chest_i+1]).normalized()
	var up := ups[chest_i]
	var back := -ahead
	var side := up.cross(back).normalized()
	up = back.cross(side).normalized()
	var basis := Basis(side,up,back)
	var chest_rest: Vector3 = (_rest_g["chest"] as Transform3D).origin
	dragon.global_transform = Transform3D(basis,at-basis*(chest_rest*size))
	var sk_inv := skeleton.global_transform.affine_inverse()
	_line = PackedVector3Array()
	_ups = PackedVector3Array()
	for i in range(count):
		_line.append(sk_inv*line_world[i])
		_ups.append((sk_inv.basis*ups[i]).normalized())

## The point on the line `length` (skeleton m) on from `from`, walking from
## index `i` by `way` (-1 toward the head, +1 toward the tail): [point,
## index, up].
func _along(from: Vector3, i: int, way: int, length: float) -> Array:
	var k := i
	while k+way >= 0 and k+way < _line.size():
		var a := _line[k]
		var b := _line[k+way]
		if from.distance_to(b) >= length:
			# Between a and b: where the distance reaches `length`.
			var lo := 0.0
			var hi := 1.0
			for _n in range(12):
				var mid := (lo+hi)*0.5
				if from.distance_to(a.lerp(b,mid)) < length: lo = mid
				else: hi = mid
			return [a.lerp(b,hi),k+way,_ups[k].lerp(_ups[k+way],hi).normalized()]
		k += way
	var end := _line[k]
	var dir := (end-from).normalized() if end.distance_to(from) > 0.01 else (_line[k]-_line[k-way]).normalized()
	return [from+dir*length,k,_ups[k]]

## A frame from a direction and an up (orthonormal; columns along, up, across).
static func _frame(along: Vector3, up: Vector3) -> Basis:
	var a := along.normalized()
	var u := (up-a*a.dot(up)).normalized()
	return Basis(a,u,a.cross(u))

## The bone `b` turned (globally, skeleton space) so its rest direction
## `rest_dir` lies along `dir` and its rest up (the model's up) along `up`;
## its parent's posed global `parent_g`. Answers its posed global basis.
func _aim(b: String, parent_g: Basis, rest_dir: Vector3, dir: Vector3, up: Vector3, rest_up := Vector3.UP) -> Basis:
	var rest: Basis = (_rest_g[b] as Transform3D).basis
	var turn := _frame(dir,up)*_frame(rest_dir,rest_up).transposed()
	var g := turn*rest
	skeleton.set_bone_pose_rotation(_bone[b],(parent_g.inverse()*g).get_rotation_quaternion())
	return g

## A bone's rest direction to its child (or its own axis, a leaf).
func _rest_dir(b: String, child: String) -> Vector3:
	if child != "" and _rest_g.has(child): return ((_rest_g[child] as Transform3D).origin-(_rest_g[b] as Transform3D).origin).normalized()
	return (_rest_g[b] as Transform3D).basis.y.normalized()

# --- Settling --------------------------------------------------------------------------

## The line lowered (or raised) until the hide lies on the ground: the
## body, legs and tail resting their weight on it, a little sunk into the
## nest's worn floor (SINK_NEST), touching the rock elsewhere (SINK_ROCK),
## never through it. Each pass skins the hide on the CPU and gives each of
## its points to the nearest point of the line; each point of the line
## goes to the height at which the hide point of its that bears on the
## ground most just touches it (the highest of the ground under each, less
## its drop under the line), so its lowest point rests and none is in the
## ground (the ground is a heightfield: under it is rock). Its neighbours'
## highest of those (SETTLE_SPAN either way), so the line stays smooth.
## Over a drop (nothing of its hide within OVER of the ground) a point of
## the head or neck follows its neighbours: the snout may hang off its
## shelf. The trunk and tail always come down onto what is under them.
const SINK_NEST := 0.15
const SINK_ROCK := 0.03
const OVER := 4.0
const SETTLE_PASSES := 14
const SETTLE_LAST := 5
const SETTLE_EASE := 0.6
const SETTLE_SPAN := 2
const GAP_SPAN := 4

func _settle() -> void:
	var chest_i := int(round((CHEST_Z-HEAD_TIP)/DZ))
	_gather_skin()
	if _skin_v.is_empty(): return
	for pass_n in range(SETTLE_PASSES+1):
		var low := _clearances()
		var rest: PackedFloat32Array = low[0]
		var gap: PackedFloat32Array = low[1]
		var n := rest.size()
		if pass_n == SETTLE_PASSES:
			worst_gap = 0.0
			worst_sink = 0.0
			worst_gap_at = -1
			body_gap = 0.0
			body_gap_at = -1
			# The gap under each stretch of the body (GAP_SPAN points either
			# way, about a bone's length): its lowest hide point's clearance.
			gaps_along = PackedFloat32Array()
			gaps_along.resize(n)
			for i in range(n):
				var m := INF
				for j in range(maxi(i-GAP_SPAN,0),mini(i+GAP_SPAN+1,n)): m = minf(m,gap[j])
				gaps_along[i] = m
				if gap[i] != INF: worst_sink = maxf(worst_sink,-gap[i])
				if m == INF: continue
				if m > worst_gap:
					worst_gap = m
					worst_gap_at = i
				if i >= chest_i and m > body_gap:
					body_gap = m
					body_gap_at = i
			wing_sink = float(low[2])
			break
		var to := PackedFloat32Array()
		to.resize(n)
		for i in range(n):
			var m := -INF
			for j in range(maxi(i-SETTLE_SPAN,0),mini(i+SETTLE_SPAN+1,n)): m = maxf(m,rest[j])
			to[i] = m
		# Points with nothing bearing near them follow their neighbours.
		for i in range(n):
			if to[i] != -INF: continue
			var a := i-1
			while a >= 0 and to[a] == -INF: a -= 1
			var b := i+1
			while b < n and to[b] == -INF: b += 1
			var da := line_world[a].y-to[a] if a >= 0 else 0.0
			var db := line_world[b].y-to[b] if b < n else da
			if a < 0: da = db
			to[i] = line_world[i].y-lerpf(da,db,float(i-a)/float(maxi(b-a,1)) if a >= 0 and b < n else 0.0)
		# Eased toward it (the pose shifts as the line moves), the last
		# passes only ever raising (so nothing is left in the ground).
		var raise_only := pass_n >= SETTLE_PASSES-SETTLE_LAST
		for i in range(n):
			if raise_only: line_world[i].y = maxf(line_world[i].y,to[i])
			else: line_world[i].y = lerpf(line_world[i].y,to[i],SETTLE_EASE)
		_frame_line()
		advance(0.0)

## The hide's points with their bones and weights.
func _gather_skin() -> void:
	for mi: MeshInstance3D in dragon.model.find_children("*","MeshInstance3D",true,false):
		if mi.skin == null or mi.mesh == null: continue
		var skin := mi.skin
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.mesh.surface_get_material(s)
			var key := mat.resource_name if mat != null else ""
			if key in ["dragon_eye","dragon_tooth","dragon_tongue","dragon_mouth"]: continue
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if bones.size() < verts.size()*4: continue
			for i in range(verts.size()):
				_skin_v.append(verts[i])
				var wing := false
				var top_w := -1.0
				for k in range(4):
					var bi := bones[i*4+k]
					var bone := skin.get_bind_bone(bi)
					if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bi))
					_skin_b.append(bone)
					_skin_w.append(weights[i*4+k])
					if not _skin_bind.has(bone): _skin_bind[bone] = skin.get_bind_pose(bi)
					if weights[i*4+k] > top_w:
						top_w = weights[i*4+k]
						wing = skeleton.get_bone_name(bone).begins_with("wing")
				_skin_wing.append(1 if wing else 0)

## Where the hide's points are now (world).
func _skinned() -> PackedVector3Array:
	var pose := {}
	for bone: int in _skin_bind: pose[bone] = skeleton.get_bone_global_pose(bone)*(_skin_bind[bone] as Transform3D)
	var to_world := skeleton.global_transform
	var out := PackedVector3Array()
	out.resize(_skin_v.size())
	for i in range(_skin_v.size()):
		var p := Vector3.ZERO
		for k in range(4):
			var w := _skin_w[i*4+k]
			if w <= 0.0: continue
			p += (pose[_skin_b[i*4+k]] as Transform3D)*_skin_v[i]*w
		out[i] = to_world*p
	return out

## The ground's height under `p` (world).
func _ground_at(p: Vector3) -> float:
	return Roost.ground(p.x-offset.x,p.z-offset.z)+offset.y

## For each point of the line: the height it would rest at (its hide's
## points given to it each just touching the ground, the highest of
## those; -INF with none bearing), its least clearance now (INF with none
## bearing); and the wings' deepest into the ground. [rest, gap, wing sink].
func _clearances() -> Array:
	var chest_i := int(round((CHEST_Z-HEAD_TIP)/DZ))
	var pts := _skinned()
	var n := line_world.size()
	var rest := PackedFloat32Array()
	rest.resize(n)
	rest.fill(-INF)
	var gap := PackedFloat32Array()
	gap.resize(n)
	gap.fill(INF)
	var want := PackedFloat32Array()
	want.resize(n)
	for i in range(n):
		var p := line_world[i]
		var worn := Roost.nest_wear(Vector2(p.x-offset.x,p.z-offset.z))
		want[i] = lerpf(SINK_ROCK,-SINK_NEST,clampf(worn*2.0-0.5,0.0,1.0))
	var wing_low := 0.0
	for v in range(pts.size()):
		var p := pts[v]
		var floor_y := _ground_at(p)
		var c := p.y-floor_y
		var i := _nearest(p)
		# The folded wings don't bear: they lie on the flanks (their
		# deepest into the ground is reported).
		if _skin_wing[v] == 1:
			wing_low = maxf(wing_low,-c)
			continue
		# The head and neck may reach out over a drop (the snout off its
		# shelf); the trunk and tail lie on what is under them, down a
		# crag's face too.
		if c > OVER and i < chest_i: continue
		rest[i] = maxf(rest[i],line_world[i].y-c+want[i])
		gap[i] = minf(gap[i],c-want[i])
	return [rest,gap,wing_low]

## The point of the line nearest `p` (every other one, then refined).
func _nearest(p: Vector3) -> int:
	var n := line_world.size()
	var best := 0
	var bd := INF
	for i in range(0,n,2):
		var d := p.distance_squared_to(line_world[i])
		if d < bd:
			bd = d
			best = i
	for i in [best-1,best+1]:
		if i >= 0 and i < n and p.distance_squared_to(line_world[i]) < bd:
			bd = p.distance_squared_to(line_world[i])
			best = i
	return best

# --- Each frame --------------------------------------------------------------------------

func advance(delta: float) -> void:
	_t += delta
	var breath := 0.5-0.5*cos(TAU*_t/BREATH)
	var g := {}
	g["root"] = (_rest_g["root"] as Transform3D).basis
	skeleton.set_bone_pose_rotation(_bone["root"],skeleton.get_bone_rest(_bone["root"]).basis.get_rotation_quaternion())
	var chest_i := int(round((CHEST_Z-HEAD_TIP)/DZ))
	var start := _line[chest_i]
	# The chest and the neck toward the head; the hips and the tail away.
	_lay_chain(["chest","spine.2","neck.0","neck.1","neck.2","neck.3","head"],"root",start,chest_i,-1,10.7,g,breath)
	_lay_chain(["hips","tail.0","tail.1","tail.2","tail.3","tail.4","tail.5","tail.6","tail.7"],"root",start,chest_i,1,5.9,g,0.0)
	_fold_wings(g)
	_fold_legs(g)
	# The jaw shut.
	for b in ["jaw","jaw.tip"]: skeleton.set_bone_pose_rotation(_bone[b],skeleton.get_bone_rest(_bone[b]).basis.get_rotation_quaternion())
	# Breathing: the chest swells across (not along, so the neck keeps its
	# place on the line).
	var s := 1.0+SWELL*breath
	skeleton.set_bone_pose_scale(_bone["chest"],Vector3(s,1.0,s))
	_breathe_out(delta)

## A chain along the line, each joint carried from the last bone's posed
## end (so it stays joined), aimed at the line a bone's length on. The
## neck lifts a little with the breath; the tail's tip twitches.
func _lay_chain(names: Array, parent: String, start: Vector3, i: int, way: int, leaf_len: float, g: Dictionary, breath: float) -> void:
	var at := start
	var k := i
	var parent_g: Basis = g[parent]
	for n in range(names.size()):
		var b: String = names[n]
		var child: String = names[n+1] if n+1 < names.size() else ""
		var span: Vector3 = ((_rest_g[child] as Transform3D).origin-(_rest_g[b] as Transform3D).origin) if child != "" else (_rest_g[b] as Transform3D).basis.y.normalized()*leaf_len
		var hit := _along(at,k,way,span.length())
		var dir: Vector3 = (hit[0] as Vector3)-at
		var up: Vector3 = hit[2]
		if b.begins_with("neck") or b == "head":
			# Up a little with each breath in, more toward the head.
			var side := dir.cross(up).normalized()
			dir = Basis(side,NECK_LIFT*breath*(1.0 if b != "head" else -2.0)).orthonormalized()*dir
		if b in ["tail.5","tail.6","tail.7"]:
			dir = Basis(up.normalized(),_twitch*(0.4 if b == "tail.5" else 1.0))*dir
		parent_g = _aim(b,parent_g,span.normalized(),dir,up)
		g[b] = parent_g
		at = at+parent_g*((_rest_g[b] as Transform3D).basis.inverse()*span)
		k = hit[1]

## The wings folded close along the flanks (a resting bat's, a bird's):
## in the chest's posed frame, the arm back and a little up from the
## shoulder, the forearm forward along the side above the belly, the hand
## and fingers back along the flank, level or a little up, close together,
## the membranes' faces turned out, so the folded panels lie flat on the
## flanks over the belly line and never hang under the body. The fingers
## shortened (FOLD): they are single straight bones and can't follow the
## trunk's curve (see round2.md for what the rig would need).
const WING_FOLD := {
	"wing_arm":Vector3(0.26,0.0,0.97),"wing_fore":Vector3(0.2,0.02,-0.98),"wing_hand":Vector3(0.16,0.03,0.99),
	"wing_f1":Vector3(0.12,0.05,0.99),"wing_f1b":Vector3(0.1,0.03,0.99),"wing_f2":Vector3(0.14,0.04,0.99),
	"wing_f3":Vector3(0.15,0.03,0.99),"wing_f4":Vector3(0.16,0.02,0.99)}
const WING_CHILD := {"wing_arm":"wing_fore","wing_fore":"wing_hand","wing_hand":"wing_f1","wing_f1":"wing_f1b"}
const WING_PARENT := {"wing_arm":"chest","wing_fore":"wing_arm","wing_hand":"wing_fore","wing_f1":"wing_hand","wing_f1b":"wing_f1",
	"wing_f2":"wing_hand","wing_f3":"wing_hand","wing_f4":"wing_hand"}

func _fold_wings(g: Dictionary) -> void:
	var chest_turn: Basis = (g["chest"] as Basis)*(_rest_g["chest"] as Transform3D).basis.inverse()
	for s in [-1.0,1.0]:
		var n := "L" if s < 0.0 else "R"
		for key: String in ["wing_arm","wing_fore","wing_hand","wing_f1","wing_f1b","wing_f2","wing_f3","wing_f4"]:
			var b := key+"."+n
			if not _bone.has(b): continue
			var v: Vector3 = WING_FOLD[key]
			var dir := chest_turn*Vector3(v.x*s,v.y,v.z)
			var up := chest_turn*Vector3(s,0.0,0.0)
			var child: String = (WING_CHILD[key]+"."+n) if WING_CHILD.has(key) else ""
			var parent: String = WING_PARENT[key]
			var pb: String = parent if parent == "chest" else parent+"."+n
			g[b] = _aim(b,g[pb],_rest_dir(b,child),dir,up,Vector3.UP)
			if key.begins_with("wing_f") and key != "wing_f1b":
				skeleton.set_bone_pose_scale(_bone[b],Vector3(1.0,FOLD,1.0))

## The hind legs folded out at the hips' sides: the thigh forward and out,
## the shank back, the foot back and flat.
const LEG_FOLD := {"hind_upper":Vector3(0.5,-0.05,-0.86),"hind_lower":Vector3(0.25,-0.05,0.97),"hind_foot":Vector3(0.3,-0.08,0.95)}
const LEG_CHILD := {"hind_upper":"hind_lower","hind_lower":"hind_foot"}

func _fold_legs(g: Dictionary) -> void:
	var hips_turn: Basis = (g["hips"] as Basis)*(_rest_g["hips"] as Transform3D).basis.inverse()
	for s in [-1.0,1.0]:
		var n := "L" if s < 0.0 else "R"
		var parent := "hips"
		for key: String in ["hind_upper","hind_lower","hind_foot"]:
			var b := key+"."+n
			if not _bone.has(b): continue
			var v: Vector3 = LEG_FOLD[key]
			var child: String = (LEG_CHILD[key]+"."+n) if LEG_CHILD.has(key) else ""
			g[b] = _aim(b,g[parent],_rest_dir(b,child),hips_turn*Vector3(v.x*s,v.y,v.z),hips_turn*Vector3.UP)
			parent = b

# --- The breath's haze and the tail's twitch ------------------------------------------------

## The nostrils (rest, model m): either side of the snout's top.
const NOSTRILS := [Vector3(-0.8,6.3,-34.6),Vector3(0.8,6.3,-34.6)]

func _build_haze() -> void:
	_haze = CPUParticles3D.new()
	_haze.name = "BreathHaze"
	_haze.emitting = false
	_haze.amount = 18
	_haze.lifetime = 3.2
	_haze.one_shot = false
	_haze.local_coords = false
	_haze.explosiveness = 0.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*1.6*float(dragon.size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_texture()
	m.disable_receive_shadows = true
	quad.material = m
	_haze.mesh = quad
	_haze.direction = Vector3(0.0,0.3,-1.0)
	_haze.spread = 22.0
	_haze.initial_velocity_min = 1.2
	_haze.initial_velocity_max = 2.2
	_haze.gravity = Vector3(0.0,0.35,0.0)
	_haze.damping_min = 0.3
	_haze.damping_max = 0.6
	_haze.scale_amount_min = 0.8
	_haze.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0.0,0.5))
	grow.add_point(Vector2(1.0,2.6))
	_haze.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0,Color(1.0,0.86,0.7,0.0))
	fade.set_color(1,Color(1.0,0.9,0.8,0.0))
	fade.add_point(0.2,Color(1.0,0.82,0.66,0.24))
	fade.add_point(0.6,Color(0.95,0.88,0.82,0.14))
	_haze.color_ramp = fade
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dragon.add_child(_haze)

static func _puff_texture() -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	tex.width = 64
	tex.height = 64
	var gr := Gradient.new()
	gr.set_color(0,Color(1,1,1,1))
	gr.set_color(1,Color(1,1,1,0))
	tex.gradient = gr
	return tex

## Whether it is breathing out now (the breath falling).
func breathing_out() -> bool:
	return sin(TAU*_t/BREATH) < -0.15

## The haze puffs from the nostrils while it breathes out (the breath
## falling), the emitter at the snout facing out of it. The tail's twitch:
## a kick now and then, on a spring.
func _breathe_out(delta: float) -> void:
	var head: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(_bone["head"])
	var head_rest: Transform3D = _rest_g["head"]
	var mid := ((NOSTRILS[0] as Vector3)+(NOSTRILS[1] as Vector3))*0.5
	var at := head*(head_rest.affine_inverse()*mid)
	var tip := head*(head_rest.affine_inverse()*(mid+Vector3(0.0,0.0,-3.0)))
	_haze.global_position = at
	_haze.direction = (tip-at).normalized()+Vector3.DOWN*0.15
	_haze.emitting = breathing_out()
	_twitch_next -= delta
	if _twitch_next <= 0.0:
		_twitch_next = _rng.randf_range(TWITCH.x,TWITCH.y)
		_twitch_v += _rng.randf_range(0.7,1.0)*TWITCH_SIZE*8.0*(1.0 if _rng.randf() < 0.5 else -1.0)
	_twitch_v += (-_twitch*22.0-_twitch_v*3.2)*delta
	_twitch += _twitch_v*delta
