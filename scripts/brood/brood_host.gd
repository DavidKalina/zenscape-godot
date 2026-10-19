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
## Grab and shove: reaching whoever holds it, up to GRAB_SLOTS cling on
## (slots round his legs and back, moved with him each frame), the rest
## crowd round him. Clingers slow him (carry's `set_slow`) and shove him
## about; KNOCK_COUNT on him a moment knock the treasure loose (carry's
## `drop("knock")`) and they're thrown off. A jump shakes them all off;
## shaken, a guy is dazed a moment. No damage.
##
## `--brood-one` stands one stone guy a little way off the wanderer when he
## can walk, and he comes for the wanderer wherever he goes (over walls, up
## faces, around edges he won't go over).

const K = preload("res://scripts/brood/brood_knobs.gd")
const StoneGuy = preload("res://scripts/brood/stone_guy.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The clinging slots round him: [the way out of him, turned from his
## facing (rad); the height on him (of his height)]. Legs and back first;
## the front, where the treasure is, last and low.
const SLOTS := [[PI*0.5,0.28],[-PI*0.5,0.28],[PI,0.32],[PI*0.72,0.58],[-PI*0.72,0.58],[PI*0.3,0.14],[-PI*0.3,0.14],[PI,0.72]]

var study: Node3D = null
var guys: Array = []
## A driver's goal for every guy (INF: the host picks).
var goal_override := Vector3.INF
var _one := false
var _rng := RandomNumberGenerator.new()
## Woken this deal, and the treasure that woke them ({} none).
var woken := false
var wanted: Dictionary = {}
## The clingers now, the time KNOCK_COUNT have hung on, the next shove's
## wait; knocks and shakes so far (for drivers).
var clinging := 0
var _knock_t := 0.0
var _shove_t := 0.0
var knocked := 0
var shaken := 0

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
	clinging = 0
	_knock_t = 0.0
	var carry: Variant = study.get("carry") if study != null else null
	if carry != null: carry.set_slow(1.0)

func _motor() -> Variant:
	return study.get("motor") if study != null else null

func _process(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	if _one and guys.is_empty(): _spawn_one()
	var carry: Variant = study.get("carry")
	var holding: bool = carry != null and not (carry.held as Dictionary).is_empty()
	if not woken and holding: wake(carry.held)
	if holding: wanted = carry.held
	if guys.is_empty(): return
	var dt := minf(delta,1.0/30.0)
	var space := get_world_3d().direct_space_state
	var goal := goal_override
	if goal == Vector3.INF: goal = _goal(carry)
	var m: Variant = _motor()
	var on_him: bool = holding and goal_override == Vector3.INF and m != null and not bool(study.get("flying"))
	if not on_him: _shake_all(Vector3.ZERO)
	elif not bool(m.grounded) and float(m.velocity.y) > K.SHAKE_UP*K.s(): _shake_all(Vector3(m.velocity.x,0.0,m.velocity.z)*0.3)
	var used := {}
	for g: RefCounted in guys: if g.state == "cling": used[g.slot] = true
	for i: int in guys.size():
		var g: RefCounted = guys[i]
		if g.state == "lost": continue
		var to := goal
		if on_him and to != Vector3.INF:
			if g.state == "walk" and g.daze <= 0.0 and bool(m.grounded) and used.size() < K.GRAB_SLOTS and _in_grab(g,m.feet):
				g.slot = _free_slot(used)
				used[g.slot] = true
				g.cling_at(m.feet,Vector3.BACK)
			elif used.size() >= K.GRAB_SLOTS or g.daze > 0.0:
				to = goal+_ring(i)*K.CROWD_RING*K.s()
		elif to != Vector3.INF and not _one and goal_override == Vector3.INF:
			to = goal+_ring(i)*0.5*K.s()
		g.step(space,to,dt)
	_hold_on(carry,m,dt)

## Within his grab of the holder's feet `at`.
func _in_grab(g: RefCounted, at: Vector3) -> bool:
	var d := Vector2(g.feet.x-at.x,g.feet.z-at.z).length()
	return d < K.GRAB_REACH*K.s() and absf(float(g.feet.y)-at.y) < K.GRAB_RISE*float(g.tall)

func _free_slot(used: Dictionary) -> int:
	for k: int in SLOTS.size(): if not used.has(k): return k
	return 0

## Guy `i`'s way round a goal (spread evenly by the golden angle).
func _ring(i: int) -> Vector3:
	var a := float(i)*2.39996
	return Vector3(cos(a),0.0,sin(a))

## The clingers moved with him, his paces held back, the shove, the knock.
func _hold_on(carry: Variant, m: Variant, dt: float) -> void:
	var n := 0
	var tall := WorldScale.wanderer_tall
	var f2: Vector2 = m.forward(float(m.facing)) if m != null else Vector2.ZERO
	var fwd := Vector3(f2.x,0.0,f2.y)
	for g: RefCounted in guys:
		if g.state != "cling": continue
		n += 1
		var sl: Array = SLOTS[clampi(int(g.slot),0,SLOTS.size()-1)]
		var out := fwd.rotated(Vector3.UP,float(sl[0]))
		var at: Vector3 = m.feet+Vector3.UP*tall*float(sl[1])+out*(0.2*K.s()+float(g.tall)*0.26)
		g.cling_at(at,out)
	clinging = n
	if carry == null: return
	carry.set_slow(maxf(1.0-K.SLOW_EACH*float(n),K.SLOW_MOST))
	if n == 0:
		_knock_t = 0.0
		return
	# The shove: a lurch sideways or back, now and then.
	_shove_t -= dt
	if _shove_t <= 0.0 and bool(m.grounded):
		_shove_t = K.SHOVE_EVERY*_rng.randf_range(0.5,1.5)
		var way := fwd.rotated(Vector3.UP,_rng.randf_range(PI*0.4,PI*1.6))
		m.velocity += way*K.SHOVE*K.s()
	if n >= K.KNOCK_COUNT: _knock_t += dt
	else: _knock_t = 0.0
	if _knock_t >= K.KNOCK_HOLD:
		_knock_t = 0.0
		knocked += 1
		carry.drop("knock")
		print("brood: %d clinging knocked it loose" % n)
		_shake_all(Vector3.UP*2.0*K.s())

## Every clinger thrown off, out of him and along `push`.
func _shake_all(push: Vector3) -> void:
	var any := false
	for g: RefCounted in guys:
		if g.state != "cling": continue
		any = true
		g.shake(push+(g.face_n as Vector3)*1.6*K.s()+Vector3.UP*1.2*K.s())
	if any:
		shaken += 1
		clinging = 0
		var carry: Variant = study.get("carry")
		if carry != null: carry.set_slow(1.0)

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
