extends Node3D
## The stone brood on a kit isle (docs/design/brood/spec-brood.md): the
## stone guys (scripts/brood/stone_guy.gd), stepped together each frame,
## each toward the goal the host picks for him. The study adds it
## (studies/wreck_cluster.gd) and calls `clear()` on its re-deal.
##
## The wake: lifting a treasure (the carry host's `held`, scripts/carry/
## carry_host.gd) wakes WAKE_COUNT guys under the isle's rim nearest it
## (`rim_spots`: rays marched out from the treasure to where the ground ends
## over a void, then a ray in at the face under that lip); they come up over
## it staggered (StoneGuy.wake_at) and come for whoever holds it, or for
## the treasure where it rests once he lets it go. Once a deal; the re-deal
## (`clear`) puts them away and lets the next lift wake them again.
##
## `--brood-one` stands one stone guy a little way off the wanderer when he
## can walk, and he comes for the wanderer wherever he goes (over walls, up
## faces, around edges he won't go over).

const K = preload("res://scripts/brood/brood_knobs.gd")
const StoneGuy = preload("res://scripts/brood/stone_guy.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

var study: Node3D = null
var guys: Array = []
## A driver's goal for every guy (INF: the host picks).
var goal_override := Vector3.INF
var _one := false
var _rng := RandomNumberGenerator.new()
## Woken this deal, and the treasure that woke them ({} none).
var woken := false
var wanted: Dictionary = {}

func setup(host: Node3D) -> void:
	study = host
	name = "Brood"
	process_priority = 90
	_rng.randomize()
	_one = LaunchArgs.user_args().has("--brood-one")

## One guy standing at `feet`.
func spawn(feet: Vector3) -> RefCounted:
	var g: RefCounted = StoneGuy.new(feet,1.0 if _rng.randf() < 0.5 else -1.0)
	add_child(g.node)
	guys.append(g)
	return g

## Every guy put away.
func clear() -> void:
	for g: RefCounted in guys: (g.node as Node3D).queue_free()
	guys.clear()
	woken = false
	wanted = {}

func _motor() -> Variant:
	return study.get("motor") if study != null else null

func _process(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	if _one and guys.is_empty(): _spawn_one()
	var carry: Variant = study.get("carry")
	if not woken and carry != null and not (carry.held as Dictionary).is_empty(): wake(carry.held)
	if guys.is_empty(): return
	var dt := minf(delta,1.0/30.0)
	var space := get_world_3d().direct_space_state
	var goal := goal_override
	if goal == Vector3.INF: goal = _goal(carry)
	for g: RefCounted in guys:
		if g.state == "lost": continue
		g.step(space,goal,dt)

## Where they head: whoever holds a treasure (on foot), else the treasure
## that woke them where it rests (unless it's lost), else nowhere (INF).
func _goal(carry: Variant) -> Vector3:
	var m: Variant = _motor()
	if carry != null and not (carry.held as Dictionary).is_empty():
		if m != null and not bool(study.get("flying")): return m.feet
		return Vector3.INF
	if _one:
		if m != null and not bool(study.get("flying")): return m.feet
		return Vector3.INF
	if not wanted.is_empty() and not bool(wanted.lost):
		return (wanted.node as Node3D).global_position
	return Vector3.INF

## Wakes the brood for treasure `t`: WAKE_COUNT guys on the rim spots
## nearest it, nearest first, each his turn.
func wake(t: Dictionary) -> void:
	woken = true
	wanted = t
	var from: Vector3 = (t.node as Node3D).global_position
	var spots := rim_spots(from)
	if spots.is_empty():
		print("brood: no rim round %s" % [from])
		return
	var n := K.WAKE_COUNT
	for i: int in n:
		var sp: Dictionary = spots[i % spots.size()]
		var at: Vector3 = sp.face
		var fn: Vector3 = sp.n
		if i >= spots.size():
			# More guys than spots: along the face beside the spot.
			var across := Vector3.UP.cross(fn).normalized()
			at += across*(0.6*K.s()*float(1+i/spots.size())*(1.0 if i % 2 == 0 else -1.0))
		var g: RefCounted = spawn(at)
		var wait := float(i)*K.WAKE_STAGGER+_rng.randf()*K.WAKE_JITTER
		var hold := K.WAKE_HOLD*_rng.randf_range(0.5,1.5)
		g.wake_at(at,fn,float(sp.lip.y),wait,hold)
	print("brood: woke %d for %s from %d rim spots (first %.1f m, last used %.1f m)" % [n,t.id,spots.size(),float(spots[0].dist),float(spots[mini(n,spots.size())-1].dist)])

## The isle's rim round `from`: in RIM_RAYS ways, rays down marched out
## from it to where the ground ends over a void (nothing within RIM_VOID
## under the last ground), the lip found closer by halving, and a ray in at
## the face under it. [{lip, face, n, dist}], nearest first past
## WAKE_NEAR, then the nearer ones.
func rim_spots(from: Vector3) -> Array:
	var space := get_world_3d().direct_space_state
	var s := K.s()
	var tall := K.tall()
	var out: Array = []
	for i: int in K.RIM_RAYS:
		var a := TAU*float(i)/float(K.RIM_RAYS)
		var d := Vector3(cos(a),0.0,sin(a))
		var last := from
		var gy := from.y
		var lip := Vector3.INF
		var r := K.RIM_STEP
		while r <= K.RIM_MOST:
			var q := from+d*r
			var hit := _down(space,Vector3(q.x,gy,q.z))
			if hit.is_empty():
				# Ground ends between `last` and here: halve to the lip.
				var lo := r-K.RIM_STEP
				var hi := r
				for k: int in 5:
					var m := (lo+hi)*0.5
					var p := from+d*m
					var h2 := _down(space,Vector3(p.x,gy,p.z))
					if h2.is_empty(): hi = m
					else:
						lo = m
						last = h2.position
				lip = last
				break
			last = hit.position
			gy = last.y
			r += K.RIM_STEP
		if lip == Vector3.INF: continue
		# The face under the lip: a ray in from out over the void.
		for under: float in [0.6,1.0,1.5]:
			var y := lip.y-under*tall
			var o := Vector3(lip.x,y,lip.z)+d*1.5*s
			var hit := _ray(space,o,o-d*3.0*s)
			if hit.is_empty(): continue
			var n: Vector3 = hit.normal
			if n.y >= K.FLOOR or n.y <= -0.7: break
			out.append({"lip":lip,"face":hit.position,"n":n,"dist":Vector2(lip.x-from.x,lip.z-from.z).length()})
			break
	# Nearest first, but those closer than WAKE_NEAR (he gets a breath to
	# run) after all the rest.
	var near := K.WAKE_NEAR*s
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var xn := float(x.dist) < near
		var yn := float(y.dist) < near
		if xn != yn: return yn
		return float(x.dist) < float(y.dist))
	return out

## The top ground under `at` (from well over it down past a void's depth),
## or {}: nothing within RIM_VOID under `at`'s height.
func _down(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	return _ray(space,at+Vector3.UP*30.0,at+Vector3.DOWN*K.RIM_VOID)

func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a,b,K.SOLID_MASK)
	return space.intersect_ray(q)

## `--brood-one`: one guy on the ground some 8 m off him, the first spot
## round him that has ground.
func _spawn_one() -> void:
	var m: Variant = _motor()
	if m == null: return
	var feet: Vector3 = m.feet
	var space := get_world_3d().direct_space_state
	for i: int in 12:
		var a := TAU*float(i)/12.0
		var p := feet+Vector3(cos(a),0.0,sin(a))*8.0*K.s()
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*4.0,p+Vector3.DOWN*6.0,K.SOLID_MASK)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y < K.FLOOR: continue
		spawn(hit.position)
		print("brood: one stone guy at %s" % [hit.position])
		return
	_one = false
