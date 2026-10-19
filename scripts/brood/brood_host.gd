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
## The mob and the haul: a loose treasure (or one set down off its spot)
## draws them; HAUL_CREW of them at it lift it over their heads and haul
## it home: the crew's lead walks and climbs for its spot at HAUL_PACE, the
## treasure on his head, the rest round him under it (StoneGuy.haul_at).
## He takes it back by lifting it from them (carry's E) or by running into
## the haulers (each knocked off is dazed; under HAUL_KEEP left they let it
## down, and leave it HAUL_REST). Home (HOME_NEAR of its spot) it's set on
## its spot (carry's `_home`) and they settle: they stand where they are
## till it's lifted again.
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
var _grace_t := 0.0
var knocked := 0
var shaken := 0
## The haul ({} none): {t, crew (the lead first), moved}; the time left
## before they lift a let-down one again; hauls begun, knocked off, let
## down and brought home so far (for drivers).
var haul: Dictionary = {}
## A treasure they gave up hauling (stuck short of home): they settle round
## it till he lifts it again ({} none).
var given_up: Dictionary = {}
var give_ups := 0
var _rest_t := 0.0
var hauls := 0
var haul_hits := 0
var let_downs := 0
var homes := 0
## How many wake (WAKE_COUNT, or `--brood-count=N`).
var count := K.WAKE_COUNT
## The bag's riders (clingers on the plane's bag): how many on now, leaps
## and sheds so far (drivers), the hardest bag hit since last frame.
var riding := 0
var leaps := 0
var sheds := 0
var _bag: Node3D = null
var _bag_hit := 0.0
var _bag_woken := false
var _air_t := 0.0
## What shook them off so far (drivers): frames each cause was on with
## riders aboard, and sheds by the hit.
var shake_why := {"bank":0,"skim":0,"side":0,"gap":0,"hit":0}
## The host's own frame (ms, smoothed; the guys' steps, the haul, the
## clingers) and the rays cast in the last frame (for drivers).
var step_ms := 0.0

func setup(host: Node3D) -> void:
	study = host
	name = "Brood"
	process_priority = 90
	_rng.randomize()
	_one = LaunchArgs.user_args().has("--brood-one")
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--brood-count="): count = maxi(int(a.get_slice("=",1)),1)

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
	haul = {}
	given_up = {}
	_rest_t = 0.0
	_grace_t = 0.0
	clinging = 0
	riding = 0
	_bag_hit = 0.0
	_bag_woken = false
	_knock_t = 0.0
	var carry: Variant = study.get("carry") if study != null else null
	if carry != null:
		carry.set_slow(1.0)
		if carry.has_method("set_riders_kg"): carry.set_riders_kg(0.0)

func _motor() -> Variant:
	return study.get("motor") if study != null else null

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_tick(delta)
	step_ms = lerpf(step_ms,float(Time.get_ticks_usec()-t0)/1000.0,0.1)

func _tick(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	if _one and guys.is_empty(): _spawn_one()
	var carry: Variant = study.get("carry")
	var holding: bool = carry != null and not (carry.held as Dictionary).is_empty()
	if not woken and holding: wake(carry.held)
	if holding:
		wanted = carry.held
		given_up = {}
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
	_rest_t = maxf(_rest_t-dt,0.0)
	_grace_t = maxf(_grace_t-dt,0.0)
	var crew: Array = haul.get("crew",[])
	_separate()
	for i: int in guys.size():
		var g: RefCounted = guys[i]
		if g.state == "lost": continue
		if crew.has(g):
			if g == crew[0]: g.step(space,_home_of(haul.t),dt)
			continue
		var to := goal
		if on_him and to != Vector3.INF:
			if g.state == "walk" and g.daze <= 0.0 and _grace_t <= 0.0 and bool(m.grounded) and used.size() < K.GRAB_SLOTS and _in_grab(g,m.feet):
				g.slot = _free_slot(used)
				used[g.slot] = true
				g.cling_at(m.feet,Vector3.BACK)
			elif used.size() >= K.GRAB_SLOTS or g.daze > 0.0:
				to = goal+_ring(i)*K.CROWD_RING*K.s()
		elif to != Vector3.INF and not _one and goal_override == Vector3.INF:
			# Round a loose one close (to take it up); round a haul wider,
			# an escort, so the crew under it shows.
			to = goal+_ring(i)*(K.ESCORT_RING if not haul.is_empty() else 0.5)*K.s()
		g.step(space,to,dt)
	_hold_on(carry,m,dt)
	_ride_step(carry,space,dt)
	if not haul.is_empty(): _haul_step(carry,m,space,dt)
	elif goal_override == Vector3.INF and not _one and _rest_t <= 0.0: _mob(carry)

## The crowd step: each walking guy's lean away from walking neighbours
## nearer than SEP (a grid of SEP cells, so it's near-linear in their
## count); `sep` is read by his next walk step.
func _separate() -> void:
	var cell := K.SEP*K.s()
	var grid := {}
	for g: RefCounted in guys:
		g.sep = Vector3.ZERO
		if g.state != "walk" or g.hauling: continue
		var c := Vector2i(floori(g.feet.x/cell),floori(g.feet.z/cell))
		if grid.has(c): (grid[c] as Array).append(g)
		else: grid[c] = [g]
	for c: Vector2i in grid:
		var here: Array = grid[c]
		for g: RefCounted in here:
			var push := Vector3.ZERO
			for dx: int in [-1,0,1]:
				for dz: int in [-1,0,1]:
					var other: Array = grid.get(c+Vector2i(dx,dz),[])
					for o: RefCounted in other:
						if o == g: continue
						var d := Vector3(g.feet.x-o.feet.x,0.0,g.feet.z-o.feet.z)
						var l := d.length()
						if l >= cell or absf(float(g.feet.y)-float(o.feet.y)) > float(g.tall): continue
						if l < 0.001: d = Vector3(cos(float(g.get_instance_id() % 628)*0.01),0.0,sin(float(g.get_instance_id() % 628)*0.01))
						else: d /= l
						push += d*(1.0-l/cell)
			g.sep = push*K.SEP_PUSH

# --- The mob and the haul ---------------------------------------------------------------

## Where `t` rests at home: its spot.
func _home_of(t: Dictionary) -> Vector3:
	return (t.spot as Node3D).global_position

func _at_home(t: Dictionary) -> bool:
	var at: Vector3 = (t.node as Node3D).global_position
	var home := _home_of(t)
	return t.body == null and Vector2(at.x-home.x,at.z-home.z).length() < K.HOME_NEAR*K.s()

## Whether they can take `t` up: resting where he left it (off its spot,
## not in his hands, not lost, not rolling).
func _takeable(carry: Variant, t: Dictionary) -> bool:
	if t.is_empty() or bool(t.lost) or bool(t.get("banked",false)) or carry == null or t == given_up: return false
	if _in_bag(t): return false
	if not (carry.held as Dictionary).is_empty() and carry.held == t: return false
	if t.body != null and not (t.body as RigidBody3D).freeze: return false
	return not _at_home(t)

## The wanted treasure resting off its spot: HAUL_CREW (by its weight) at
## it, walking and not dazed, take it up; the nearest leads.
func _mob(carry: Variant) -> void:
	var t := wanted
	if not _takeable(carry,t): return
	var at: Vector3 = (t.node as Node3D).global_position
	var reach := float(t.measures.radius)+K.HAUL_REACH*K.s()
	var near: Array = []
	for g: RefCounted in guys:
		if g.state != "walk" or g.daze > 0.0: continue
		var d := Vector2(g.feet.x-at.x,g.feet.z-at.z).length()
		if d < reach and absf(float(g.feet.y)-at.y) < float(g.tall)*1.5: near.append([d,g])
	var need := int(K.HAUL_CREW.get(str(t.weight),3))
	if near.size() < need: return
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var crew: Array = []
	for k: int in need: crew.append(near[k][1])
	carry._unloose(t)
	var lead: RefCounted = crew[0]
	lead.hauling = true
	lead.pace = float(K.HAUL_PACE.get(str(t.weight),0.4))
	haul = {"t":t,"crew":crew,"last":lead.feet,"best":(_home_of(t)-at).length(),"since":0.0}
	hauls += 1
	print("brood: %d took up %s, hauling it home (%.1f m)" % [need,t.id,(_home_of(t)-at).length()])

## The haul's frame: the treasure on the lead's head, the crew round him
## under it; his runs into them knock them off; under HAUL_KEEP it's let
## down; lifted by him, the haul's over; home, it's set and they settle.
func _haul_step(carry: Variant, m: Variant, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	var t: Dictionary = haul.t
	var crew: Array = haul.crew
	if carry == null or bool(t.lost) or (not (carry.held as Dictionary).is_empty() and carry.held == t):
		# Lifted from them (or gone): the haul's over.
		_end_haul()
		return
	# His runs into the haulers.
	if m != null and not bool(study.get("flying")):
		var v: Vector3 = m.velocity
		var fast := Vector2(v.x,v.z).length() > K.HAUL_HIT_SPEED*K.s() or v.y < -2.0*K.s()
		if fast:
			for g: RefCounted in crew.duplicate():
				var at: Vector3 = (g.node as Node3D).global_position
				var d := Vector2(at.x-m.feet.x,at.z-m.feet.z).length()
				if d > K.HAUL_HIT*K.s()+float(g.radius) or absf(at.y-float(m.feet.y)) > WorldScale.wanderer_tall: continue
				var out := Vector3(at.x-m.feet.x,0.0,at.z-m.feet.z).normalized()
				# Into him, not walking off past him.
				if v.y > -2.0*K.s() and Vector3(v.x,0.0,v.z).normalized().dot(out) < 0.3: continue
				crew.erase(g)
				g.hauling = false
				g.pace = 1.0
				g.mid = at
				g.shake(out*2.4*K.s()+Vector3(v.x,0.0,v.z)*0.4+Vector3.UP*1.6*K.s())
				haul_hits += 1
				print("brood: knocked a hauler off %s (%d left)" % [t.id,crew.size()])
	if crew.size() < K.HAUL_KEEP or (crew[0] as RefCounted).state == "lost":
		_let_down(t)
		return
	var lead: RefCounted = crew[0]
	if not lead.hauling:
		# A new lead (the last one knocked off): onto his feet under it.
		lead.release()
		lead.hauling = true
		lead.pace = float(K.HAUL_PACE.get(str(t.weight),0.4))
	var lx: Transform3D = (lead.node as Node3D).global_transform
	var b := lx.basis.orthonormalized()
	var tall: float = lead.tall
	var moved := ((lead.feet as Vector3)-(haul.last as Vector3)).length()
	haul.last = lead.feet
	# The treasure on his head (its foot), held level.
	(t.node as Node3D).global_position = lx.origin+b.y*tall*0.62
	# The rest round him, under its rim.
	var r := float(t.measures.radius)*0.8+float(lead.radius)*0.6
	for k: int in range(1,crew.size()):
		var a := TAU*float(k)/float(crew.size())
		var at := lx.origin+b.x*cos(a)*r+b.z*sin(a)*r
		if lead.state == "walk":
			var hit := _ray(space,at+Vector3.UP*tall,at+Vector3.DOWN*tall*1.5)
			if not hit.is_empty() and (hit.normal as Vector3).y >= K.FLOOR: at.y = float(hit.position.y)+tall*0.5
		(crew[k] as RefCounted).haul_at(at,b,moved,dt)
	# Getting nearer home? Else, stuck a while, they give it up.
	var left := (_home_of(t)-(t.node as Node3D).global_position).length()
	haul.since = float(haul.since)+dt
	if left < float(haul.best)-K.HAUL_GAIN*K.s():
		haul.best = left
		haul.since = 0.0
	elif float(haul.since) > K.HAUL_STUCK:
		print("brood: stuck %.1f m short of %s's home; they give it up" % [left,t.id])
		give_ups += 1
		given_up = t
		_let_down(t)
		return
	if _at_home(t):
		carry._home(t)
		homes += 1
		print("brood: %s hauled home; they settle" % t.id)
		_end_haul()

## The treasure set down on the ground under it, the crew off it, left
## HAUL_REST.
func _let_down(t: Dictionary) -> void:
	var node: Node3D = t.node
	var at := node.global_position
	var hit := _ray(get_world_3d().direct_space_state,at+Vector3.UP*0.3,at+Vector3.DOWN*(K.DROP_MOST*K.s()))
	if not hit.is_empty(): node.global_position = hit.position
	let_downs += 1
	_rest_t = K.HAUL_REST
	print("brood: they let %s down" % t.id)
	_end_haul()

func _end_haul() -> void:
	for g: RefCounted in haul.get("crew",[]): g.release()
	haul = {}

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

# --- Clingers on the plane's bag ---------------------------------------------------------

func _in_bag(t: Dictionary) -> bool:
	return int(t.get("slot",-1)) >= 0

## Ride spot `k` on the bag for a guy `tall` high: his middle on the
## belly's side, and the way out of it.
func _ride_spot(bag: Node3D, pf: Node3D, k: int, tall: float) -> Array:
	var b: Transform3D = bag.basket_xform(pf)
	var r := float(bag.radius)
	var a := float(k)*TAU/float(K.RIDE_SLOTS)+0.4
	var out := Vector3(cos(a),0.0,sin(a))
	var at := b*(out*(r*0.95+tall*0.22)+Vector3.UP*(r*0.85-tall*0.2))
	return [at,(b.basis*out).normalized()]

## In the plane with treasure in the bag: the near ones leap onto it and
## ride; in the air a hard bank, a skim, a cliff or gap beside, or a hit
## shakes them off one by one. Their kg rides in the bag's load.
func _ride_step(carry: Variant, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	if carry == null: return
	var bag: Node3D = carry.get("sling")
	var pf: Node3D = study.get("plane_figure")
	if bag == null or pf == null:
		riding = 0
		return
	if bag != _bag:
		_bag = bag
		bag.hit.connect(func(speed: float, _at: Vector3, _n: Vector3, _v: Vector3) -> void: _bag_hit = maxf(_bag_hit,speed))
	var in_plane := bool(study.get("flying"))
	var loaded := float(bag.load_kg) > 0.0
	var belly: Vector3 = bag.belly()
	# Treasure in the bag wakes the rim round the plane too (the brood
	# can't cross to its strip from the treasure's land).
	if loaded and woken and not _bag_woken and not _one:
		_bag_woken = true
		_wake_from(belly,K.BAG_WAKE,"the bag")
	var used := {}
	var on: Array = []
	for g: RefCounted in guys:
		if g.state == "ride" or g.state == "leap":
			used[g.slot] = true
			on.append(g)
	# Out of the plane (or the bag emptied): they let go and drop off.
	if not in_plane or not loaded:
		for g: RefCounted in on: g.shake(Vector3(bag.vel)*0.5+Vector3.UP*1.0*K.s())
		on.clear()
	# Leaps: the near ones, his slots allowing.
	if in_plane and loaded and on.size() < K.RIDE_SLOTS:
		for g: RefCounted in guys:
			if on.size() >= K.RIDE_SLOTS: break
			if g.state != "walk" or g.daze > 0.0 or g.hauling: continue
			var d := Vector2(g.feet.x-belly.x,g.feet.z-belly.z).length()-float(bag.radius)
			if d > K.LEAP_REACH*K.s() or absf(float(g.feet.y)-belly.y) > K.LEAP_RISE*float(g.tall): continue
			var k := 0
			while used.has(k): k += 1
			used[k] = true
			g.leap()
			g.slot = k
			on.append(g)
			leaps += 1
	# The shake: chances a second, summed; a hit sheds outright.
	var rate := 0.0
	var shed_now := 0
	var hl: Variant = study.get("hand_landing")
	var airborne: bool = in_plane and not bool(bag.grounded) and (hl == null or bool(hl.flying()))
	_air_t = _air_t+dt if airborne else 0.0
	if airborne and not on.is_empty():
		var plane: Variant = study.get("plane")
		if plane != null:
			var bank := absf(float(plane.bank))
			if bank > K.BANK_SHAKE:
				rate += K.BANK_RATE*clampf((bank-K.BANK_SHAKE)/(K.BANK_TOP-K.BANK_SHAKE),0.0,1.5)
				shake_why.bank += 1
		var r := float(bag.radius)
		if _air_t > K.SKIM_AFTER and not _ray(space,belly,belly-Vector3.UP*(r+K.SKIM_DOWN)).is_empty():
			rate += K.SKIM_RATE
			shake_why.skim += 1
		var x: Vector3 = (bag.basket_xform(pf) as Transform3D).basis.x
		var lh := not _ray(space,belly,belly-x*(r+K.SKIM_SIDE)).is_empty()
		var rh := not _ray(space,belly,belly+x*(r+K.SKIM_SIDE)).is_empty()
		if lh and rh:
			rate += K.GAP_RATE
			shake_why.gap += 1
		elif lh or rh:
			rate += K.SIDE_RATE
			shake_why.side += 1
		if _bag_hit > 0.0:
			shed_now = maxi(1,ceili(_bag_hit*K.HIT_SHED))
			shake_why.hit += shed_now
	_bag_hit = 0.0
	var n := 0
	for g: RefCounted in on:
		var spot := _ride_spot(bag,pf,int(g.slot),float(g.tall))
		var off: bool = g.state == "ride" and (shed_now > 0 or _rng.randf() < rate*dt)
		if off:
			shed_now -= 1
			sheds += 1
			var out: Vector3 = spot[1]
			g.shake(Vector3(bag.vel)*0.8+out*2.5*K.s()+Vector3.UP*1.5*K.s(),K.TUMBLE*(1.0 if _rng.randf() < 0.5 else -1.0))
			continue
		if g.state == "leap": g.leap_step(spot[0],spot[1],dt)
		else: g.ride_at(spot[0],spot[1],dt)
		n += 1
	riding = n
	if carry.has_method("set_riders_kg"): carry.set_riders_kg(float(n)*K.RIDER_KG)

## Every clinger thrown off, out of him and along `push`.
func _shake_all(push: Vector3) -> void:
	var any := false
	for g: RefCounted in guys:
		if g.state != "cling": continue
		any = true
		g.shake(push+(g.face_n as Vector3)*1.6*K.s()+Vector3.UP*1.2*K.s())
	if any:
		shaken += 1
		_grace_t = K.GRAB_GRACE
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
		if _in_bag(wanted):
			var bag: Node3D = carry.get("sling")
			return bag.belly() if bag != null else Vector3.INF
		if _at_home(wanted) or wanted == given_up: return Vector3.INF
		return (wanted.node as Node3D).global_position
	return Vector3.INF

## Wakes the brood for treasure `t`: WAKE_COUNT guys on the rim spots
## nearest it, nearest first, each his turn.
func wake(t: Dictionary) -> void:
	woken = true
	wanted = t
	_wake_from((t.node as Node3D).global_position,count,str(t.id))

## Wakes `n` guys on the rim spots nearest `from`, nearest first, each his
## turn (`what` for the log).
func _wake_from(from: Vector3, n: int, what: String) -> void:
	var spots := rim_spots(from)
	if spots.is_empty():
		print("brood: no rim round %s" % [from])
		return
	for i: int in n:
		var sp: Dictionary = spots[i % spots.size()]
		var at: Vector3 = sp.face
		var fn: Vector3 = sp.n
		var later := 0.0
		if i >= spots.size():
			# More guys than spots: along the face beside the spot, where
			# there's face under a lip there; else the spot itself, later.
			var beside := _beside(sp,0.6*K.s()*float(1+i/spots.size())*(1.0 if i % 2 == 0 else -1.0))
			if beside.is_empty(): later = K.WAKE_RISE*float(i/spots.size())
			else:
				at = beside.face
				fn = beside.n
		var g: RefCounted = spawn(at)
		var wait := float(i)*K.WAKE_STAGGER+_rng.randf()*K.WAKE_JITTER+later
		var hold := K.WAKE_HOLD*_rng.randf_range(0.5,1.5)
		g.wake_at(at,fn,float(sp.lip.y),wait,hold)
	print("brood: woke %d for %s from %d rim spots (first %.1f m, last used %.1f m)" % [n,what,spots.size(),float(spots[0].dist),float(spots[mini(n,spots.size())-1].dist)])

## A wake spot `by` m along the face beside rim spot `sp` ({face, n}, or
## {}): a face there under the lip's height, and ground on top over it.
func _beside(sp: Dictionary, by: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var fn: Vector3 = sp.n
	var flat := Vector3(fn.x,0.0,fn.z).normalized()
	var at: Vector3 = (sp.face as Vector3)+Vector3.UP.cross(fn).normalized()*by
	var hit := _ray(space,at+flat*1.0*K.s(),at-flat*1.0*K.s())
	if hit.is_empty(): return {}
	var n: Vector3 = hit.normal
	if n.y >= K.FLOOR or n.y <= -0.7: return {}
	var lip_y := float(sp.lip.y)
	var over := (hit.position as Vector3)-flat*0.4*K.s()
	var top := _ray(space,Vector3(over.x,lip_y+K.tall(),over.z),Vector3(over.x,lip_y-K.tall()*0.6,over.z))
	if top.is_empty() or (top.normal as Vector3).y < K.FLOOR: return {}
	if not _can_top(space,hit.position,n,lip_y): return {}
	return {"face":hit.position,"n":n}

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
			if not _can_top(space,hit.position,n,lip.y): break
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

## Whether a guy on the face at `at` (`n` out of it) under a lip at
## `lip_y` finds a floor to mantle onto over it (his mantle's probes).
func _can_top(space: PhysicsDirectSpaceState3D, at: Vector3, n: Vector3, lip_y: float) -> bool:
	var into := Vector3(-n.x,0.0,-n.z).normalized()
	var tall := K.tall()
	for reach: float in [K.RADIUS+0.3,K.RADIUS+0.7,K.RADIUS+1.2]:
		var over := Vector3(at.x,lip_y,at.z)+into*reach*K.s()+Vector3.UP*tall*1.4
		var hit := _ray(space,over,over+Vector3.DOWN*tall*3.3)
		if not hit.is_empty() and (hit.normal as Vector3).y >= K.FLOOR: return true
	return false

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
