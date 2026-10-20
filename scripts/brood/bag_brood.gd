extends "res://scripts/brood/brood_host.gd"
## The stone brood after the loot bag (docs/design/bag-brood/spec-bag-brood.md),
## for the bag study (studies/bag_study.gd): the room has walls, not a rim,
## so they wake out of burrows in its floor, and what they want is the bag
## (scripts/carry/loot_bag.gd), not a hand-carried treasure.
##
## The wake: the first piece into the bag wakes BAG_STUDY_COUNT guys out of
## the burrows (`burrows`: nodes whose origin is the mouth's floor), dealt
## round them nearest the bag first, each burrow's guys BURROW_STAGGER s
## apart (StoneGuy.rise_at). Once a deal; `clear` puts them away.
##
## Then they come for him while he has the bag on (worn or dragged): up to
## GRAB_SLOTS cling round him, slowing him (the bag's `set_slow`) and
## shoving him about; a jump shakes them off, dazed. The bag set down,
## they gather round it.
##
## The rip: worn with any clinging, every RIP_EVERY s or so a clinger pulls a
## piece out (the bag's `rip_out`) and drops off; it hops out of the mouth
## onto the ground beside him, a stray. RIP_CREW of the nearest free guys go
## for a stray (more for a heavy one: one per BAG_KG_EACH kg), take it up
## and haul it to the nearest burrow (slower the heavier), where it's taken
## down (`buried`, by the burrow's name). He bowls into the crew (under
## BAG_KEEP of it left they let it down) or takes it back with E, as any
## piece on the ground.
##
## The idle bag: set down with something in it and left (him BAG_LEFT off)
## BAG_IDLE s, it calls a crew of one per BAG_KG_EACH kg; once enough are by
## it they lift it (the bag's `haul_hold`) and haul it whole to the nearest
## burrow, the lead walking for it with the bag on his head, the rest round
## him under it, more joining on the way; pace by crew over kg. Bowled under
## BAG_KEEP of the crew they let it down; F by it takes it from them (the
## bag frees itself). At the burrow it's buried.
##
## The burial: a bag or piece taken down into a burrow is buried there (the
## bag's `bury`: hidden, out of reach), and GUARDS of its crew (GUARDS_BAG
## for the bag) settle on the mouth. He comes near and they cling to him (a
## jump shakes them); while any cling the spade won't dig (the study's
## `dig_blocked`) and a dig under way stops. The burrow is a dig spot
## (scripts/brood/burrow_digs.gd); dug, `dig_out` brings its whole pile up:
## the bag hops out, the ripped pieces land round the mouth, and the guards
## stand down.

## The burrows: Node3D, each at its mouth's floor.
var burrows: Array = []
## The bag (the study's `bag`).
var bag: Node3D = null
## Pieces ripped out, on the ground or hauled: {p, pop (s into its hop out of
## the mouth; -1 landed), from, to, rest, crew (lead first), hole, last,
## best, since}.
var strays: Array = []
## Pieces taken down into each burrow: its name -> [pieces].
var buried: Dictionary = {}
var rips := 0
var rip_hauls := 0
var rip_hits := 0
var rip_lets := 0
var takebacks := 0
var _rip_t := -1.0
## The rip's pace (1 as tuned; a host slows it, e.g. the bridge study on a
## loaded deck).
var rip_pace := 1.0
## The bag's haul: {crew (lead first), need, hole, last, best, since}; {} none.
var lift := {}
var bag_hauls := 0
var bag_hits := 0
var bag_lets := 0
var bag_takes := 0
var bag_homes := 0
var _idle_t := 0.0
var _lift_rest := 0.0
## The burrow the bag is buried in ("" none); the guards (guy -> its
## burrow); the burrow whose guards are after him now; pieces hopping out
## of a dug burrow: {node, from, to, t, yaw}.
var bag_in := ""
var guard_of := {}
var _guard_hole: Node3D = null
var _pops: Array = []
var burials := 0
var digs_out := 0
var dig_cuts := 0
## Going home: guy -> the burrow he's walking to (or going down into); the
## time with nothing to take; how many went down; the bag's last kg (a rise
## is a piece bagged).
var homing := {}
var calm_t := 0.0
var gone_home := 0
var rewakes := 0
var _last_kg := 0.0
## A host that wakes them itself (the greed run, studies/crag_reach_greed.gd)
## holds the bag's wake: they stay down till it calls `wake_burrows`. And
## on a wide isle only the `wake_holes` burrows nearest the bag deal the
## wake (0: all of them).
var wake_held := false
var wake_holes := 0

func setup_bag(host: Node3D, holes: Array) -> void:
	setup(host)
	burrows = holes
	bag = host.get("bag")
	count = K.BAG_STUDY_COUNT
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--brood-count="): count = maxi(int(a.get_slice("=",1)),1)

func clear() -> void:
	for st: Dictionary in strays: for g: RefCounted in st.crew: g.release()
	strays.clear()
	_rip_t = -1.0
	if not lift.is_empty():
		for g: RefCounted in lift.crew: g.release()
		lift = {}
		bag.haul_free()
	_idle_t = 0.0
	guard_of.clear()
	_guard_hole = null
	homing.clear()
	calm_t = 0.0
	super.clear()
	if bag != null: bag.set_slow(1.0)

## Where the bag is now: on him (worn, dragged) or where it lies.
func bag_at() -> Vector3:
	if bag == null or bool(bag.buried): return Vector3.INF
	if _on_him():
		var m: Variant = _motor()
		return m.feet if m != null else Vector3.INF
	return (bag.loose as Node3D).global_position

## The bag on him (worn or by its neck)?
func _on_him() -> bool:
	return bag != null and (bag.state == "worn" or bag.state == "drag")

func _tick(delta: float) -> void:
	if study == null or bag == null or not bool(study.get("walk_ready")): return
	if not woken and not wake_held and (float(bag.kg) > 0.0 or not (bag.stowing as Dictionary).is_empty()): wake_burrows()
	# A piece bagged again wakes as many as went home.
	if woken and float(bag.kg) > _last_kg+0.01 and guys.size() < count:
		rewakes += 1
		print("brood: a piece bagged; %d come up again" % (count-guys.size()))
		wake_burrows(count-guys.size())
	_last_kg = float(bag.kg)
	if guys.is_empty(): return
	var dt := minf(delta,1.0/30.0)
	var space := get_world_3d().direct_space_state
	var m: Variant = _motor()
	var on_him: bool = _on_him() and float(bag.kg) > 0.0 and goal_override == Vector3.INF and m != null
	var goal := goal_override
	if goal == Vector3.INF: goal = bag_at()
	# The bag buried: the rest trail him, off a way, while the guards keep it.
	var trail: bool = goal == Vector3.INF and goal_override == Vector3.INF and bool(bag.buried) and m != null
	if trail: goal = m.feet
	var guarded := _guard_watch(m)
	if not on_him and guarded == null: _shake_all(Vector3.ZERO)
	elif m != null and not bool(m.grounded) and float(m.velocity.y) > K.SHAKE_UP*K.s(): _shake_all(Vector3(m.velocity.x,0.0,m.velocity.z)*0.3)
	# A shaken guard stays down longer: long enough to dig.
	for g: RefCounted in guard_of: if g.daze >= K.DAZE-0.001 and g.daze < K.GUARD_DAZE: g.daze = K.GUARD_DAZE
	var used := {}
	for g: RefCounted in guys: if g.state == "cling": used[g.slot] = true
	_grace_t = maxf(_grace_t-dt,0.0)
	_prune_strays()
	_lift_watch(m,dt)
	_home_watch(m,dt)
	var busy := _busy()
	var sent := _send_to_strays(busy)
	_send_to_bag(busy,sent)
	_separate()
	for i: int in guys.size():
		var g: RefCounted = guys[i]
		if g.state == "lost": continue
		if homing.has(g):
			_home_step(g,space,dt)
			continue
		if guard_of.has(g):
			_guard_step(g,i,m,guarded,used,space,dt)
			continue
		if busy.has(g):
			var job: Dictionary = busy[g]
			if g == job.crew[0]: g.step(space,(job.hole as Node3D).global_position,dt)
			continue
		if sent.has(g):
			g.step(space,sent[g],dt)
			continue
		var to := goal
		if on_him and to != Vector3.INF:
			if g.state == "walk" and g.daze <= 0.0 and _grace_t <= 0.0 and bool(m.grounded) and used.size() < K.GRAB_SLOTS and _in_grab(g,m.feet):
				g.slot = _free_slot(used)
				used[g.slot] = true
				g.cling_at(m.feet,Vector3.BACK)
			elif used.size() >= K.GRAB_SLOTS or g.daze > 0.0:
				to = goal+_ring(i)*K.CROWD_RING*K.s()
		elif to != Vector3.INF and goal_override == Vector3.INF:
			to = goal+_ring(i)*(K.TRAIL_RING if trail else K.CROWD_RING)*K.s()
		g.step(space,to,dt)
	_cling_step(m,dt)
	_strays_step(m,space,dt)
	_lift_step(m,space,dt)
	_pops_step(dt)
	_put_away()
	var dig: Variant = study.get("dig")
	if clinging > 0 and dig != null and dig.motion != null:
		dig.end_dig()
		dig_cuts += 1
		print("brood: grabbed mid-dig, the dig stops")

## The guys on a job (a stray's crew, the bag's): guy -> its job (crew, hole).
func _busy() -> Dictionary:
	var busy := {}
	for st: Dictionary in strays: for g: RefCounted in st.crew: busy[g] = st
	if not lift.is_empty(): for g: RefCounted in lift.crew: busy[g] = lift
	for g: RefCounted in guard_of: busy[g] = {"guard":guard_of[g]}
	for g: RefCounted in homing: busy[g] = {"home":homing[g]}
	return busy

## The clingers moved with him, his paces held back, the shove.
func _cling_step(m: Variant, dt: float) -> void:
	var n := 0
	if m != null:
		var tall := WorldScale.wanderer_tall
		var f2: Vector2 = m.forward(float(m.facing))
		var fwd := Vector3(f2.x,0.0,f2.y)
		for g: RefCounted in guys:
			if g.state != "cling": continue
			n += 1
			var sl: Array = SLOTS[clampi(int(g.slot),0,SLOTS.size()-1)]
			var out := fwd.rotated(Vector3.UP,float(sl[0]))
			g.cling_at(m.feet+Vector3.UP*tall*float(sl[1])+out*(0.2*K.s()+float(g.tall)*0.26),out)
		if n > 0:
			_shove_t -= dt
			if _shove_t <= 0.0 and bool(m.grounded):
				_shove_t = K.SHOVE_EVERY*_rng.randf_range(0.5,1.5)
				m.velocity += fwd.rotated(Vector3.UP,_rng.randf_range(PI*0.4,PI*1.6))*K.SHOVE*K.s()
	clinging = n
	bag.set_slow(maxf(1.0-K.SLOW_EACH*float(n),K.SLOW_MOST))
	# The rip: a slow leak while they hang on; shaken off, the wait starts over.
	if n > 0 and m != null and bag.state == "worn" and (bag.stowing as Dictionary).is_empty() and str(bag.act) == "" and not (bag.items as Array).is_empty():
		if _rip_t < 0.0: _rip_t = _rip_wait()
		_rip_t -= dt*rip_pace*(1.0+K.RIP_MORE*float(n-1))
		if _rip_t <= 0.0:
			_rip(m)
			_rip_t = _rip_wait()
	elif n == 0: _rip_t = -1.0

func _rip_wait() -> float:
	return K.RIP_EVERY*_rng.randf_range(1.0-K.RIP_JITTER,1.0+K.RIP_JITTER)

## A clinger pulls a piece out and drops off; it hops out of the mouth onto
## the ground beside him.
func _rip(m: Variant) -> void:
	var on: Array = guys.filter(func(g: RefCounted) -> bool: return g.state == "cling")
	if on.is_empty(): return
	var g: RefCounted = on[_rng.randi() % on.size()]
	var p: Dictionary = bag.rip_out()
	if p.is_empty(): return
	var out := Vector3(g.face_n.x,0.0,g.face_n.z)
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	var to: Vector3 = m.feet+out*K.RIP_OUT*K.s()
	var hit := _ray(get_world_3d().direct_space_state,to+Vector3.UP*0.8*K.s(),to+Vector3.DOWN*2.0*K.s())
	if not hit.is_empty(): to = hit.position
	g.shake(out*1.4*K.s()+Vector3.UP*1.2*K.s())
	g.daze = 0.0
	strays.append({"p":p,"pop":0.0,"from":bag.mouth(),"to":to,"rest":0.0,"crew":[],"hole":null,"last":Vector3.ZERO,"best":0.0,"since":0.0,"yaw":_rng.randf()*TAU})
	rips += 1
	print("brood: ripped %s (%.1f kg) out of the bag; %.1f kg left" % [p.id,float(p.kg),float(bag.kg)])

# --- The strays (ripped-out pieces) ------------------------------------------------------

## Back in the bag (he took it, E): no longer theirs.
func _prune_strays() -> void:
	for st: Dictionary in strays.duplicate():
		var p: Dictionary = st.p
		if (bag.items as Array).has(p) or bag.stowing == p:
			if not (st.crew as Array).is_empty(): takebacks += 1
			for g: RefCounted in st.crew: g.release()
			strays.erase(st)
			print("brood: he took %s back" % p.id)

## The crew's worth (by kg) of the nearest free guys (walking or on the way, not dazed, not
## clinging, not hauling) to each stray lying free: guy -> where it lies.
func _send_to_strays(busy: Dictionary) -> Dictionary:
	var sent := {}
	for st: Dictionary in strays:
		if float(st.pop) >= 0.0 or not (st.crew as Array).is_empty() or float(st.rest) > 0.0: continue
		var at: Vector3 = (st.p.node as Node3D).global_position
		var near: Array = []
		for g: RefCounted in guys:
			if busy.has(g) or sent.has(g) or g.daze > 0.0: continue
			if not (g.state == "walk" or g.state == "climb" or g.state == "mantle" or g.state == "fall"): continue
			near.append([(g.feet as Vector3).distance_to(at),g])
		near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for k: int in mini(_stray_need(st.p),near.size()): sent[near[k][1]] = at
	return sent

func _strays_step(m: Variant, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	for st: Dictionary in strays.duplicate():
		var node: Node3D = st.p.node
		if float(st.pop) >= 0.0:
			st.pop = float(st.pop)+dt
			var k := clampf(float(st.pop)/K.RIP_POP,0.0,1.0)
			var at: Vector3 = (st.from as Vector3).lerp(st.to,k)+Vector3.UP*0.5*K.s()*sin(PI*k)
			node.global_transform = Transform3D(Basis(Vector3.UP,float(st.yaw)+k*4.0),at)
			if k >= 1.0: st.pop = -1.0
			continue
		st.rest = maxf(float(st.rest)-dt,0.0)
		if (st.crew as Array).is_empty():
			if float(st.rest) <= 0.0: _take_up(st)
		else: _rip_haul(st,m,space,dt)

## Its crew (by kg) of free guys at a stray take it up, toward the nearest burrow.
func _take_up(st: Dictionary) -> void:
	var p: Dictionary = st.p
	var at: Vector3 = (p.node as Node3D).global_position
	var reach := float(p.measures.radius)+K.HAUL_REACH*K.s()
	var busy := _busy()
	var near: Array = []
	for g: RefCounted in guys:
		if busy.has(g) or g.state != "walk" or g.daze > 0.0: continue
		var d := Vector2(g.feet.x-at.x,g.feet.z-at.z).length()
		if d < reach and absf(float(g.feet.y)-at.y) < float(g.tall)*1.5: near.append([d,g])
	var need := _stray_need(p)
	if near.size() < need: return
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var crew: Array = []
	for k: int in need: crew.append(near[k][1])
	var hole: Node3D = null
	for b: Node3D in burrows:
		if not is_instance_valid(b): continue
		if hole == null or b.global_position.distance_to(at) < hole.global_position.distance_to(at): hole = b
	if hole == null: return
	var lead: RefCounted = crew[0]
	lead.hauling = true
	lead.pace = _stray_pace(p)
	st.crew = crew
	st.hole = hole
	st.last = lead.feet
	st.best = hole.global_position.distance_to(at)
	st.since = 0.0
	rip_hauls += 1
	print("brood: %d took up %s (%.1f kg, pace %.2f), off to %s (%.1f m)" % [crew.size(),p.id,float(p.kg),float(lead.pace),hole.name,float(st.best)])

## A ripped piece's crew by its kg (as the bag's), the fewest that keep it
## up, and its pace.
func _stray_need(p: Dictionary) -> int:
	return clampi(ceili(float(p.kg)/K.BAG_KG_EACH),K.RIP_CREW,K.BAG_CREW_MOST)

func _stray_keep(p: Dictionary) -> int:
	return maxi(ceili(float(_stray_need(p))*K.BAG_KEEP),K.RIP_CREW)

func _stray_pace(p: Dictionary) -> float:
	return lerpf(K.RIP_PACE,K.RIP_PACE_HEAVY,clampf(float(p.kg)/K.RIP_HEAVY,0.0,1.0))

## A stray's haul: on the lead's head, the crew round him; his runs into
## them knock them off (under its keep left, let down); at the burrow,
## taken down.
func _rip_haul(st: Dictionary, m: Variant, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	var p: Dictionary = st.p
	var crew: Array = st.crew
	rip_hits += _bowl(crew,m,p.id)
	if crew.size() < _stray_keep(p) or (crew[0] as RefCounted).state == "lost":
		_rip_down(st)
		return
	var lead: RefCounted = crew[0]
	if not lead.hauling:
		lead.release()
		lead.hauling = true
		lead.pace = _stray_pace(p)
	var lx: Transform3D = (lead.node as Node3D).global_transform
	var b := lx.basis.orthonormalized()
	var tall: float = lead.tall
	var moved := ((lead.feet as Vector3)-(st.last as Vector3)).length()
	st.last = lead.feet
	(p.node as Node3D).global_transform = Transform3D(b,lx.origin+b.y*tall*0.62)
	var r := float(p.measures.radius)*0.8+float(lead.radius)*0.6
	for k: int in range(1,crew.size()):
		var a := TAU*float(k)/float(crew.size())
		var at := lx.origin+b.x*cos(a)*r+b.z*sin(a)*r
		if lead.state == "walk":
			var hit := _ray(space,at+Vector3.UP*tall,at+Vector3.DOWN*tall*1.5)
			if not hit.is_empty() and (hit.normal as Vector3).y >= K.FLOOR: at.y = float(hit.position.y)+tall*0.5
		(crew[k] as RefCounted).haul_at(at,b,moved,dt)
	var hole: Node3D = st.hole
	var h := hole.global_position
	var left := (h-(lead.feet as Vector3)).length()
	st.since = float(st.since)+dt
	if left < float(st.best)-K.HAUL_GAIN*K.s():
		st.best = left
		st.since = 0.0
	elif float(st.since) > K.HAUL_STUCK:
		print("brood: stuck %.1f m short of %s with %s" % [left,hole.name,p.id])
		_rip_down(st)
		return
	if Vector2(lead.feet.x-h.x,lead.feet.z-h.z).length() < K.HOME_NEAR*K.s() and absf(float(lead.feet.y)-h.y) < float(tall)*1.5:
		(p.node as Node3D).visible = false
		p["buried"] = true
		if not buried.has(hole.name): buried[hole.name] = []
		(buried[hole.name] as Array).append(p)
		for g: RefCounted in crew: g.release()
		strays.erase(st)
		_settle_guards(hole,crew,K.GUARDS)
		burials += 1
		print("brood: %s taken down into %s (%d there)" % [p.id,hole.name,(buried[hole.name] as Array).size()])

## His runs into a crew (faster than RIP_HIT_SPEED, or coming down on them)
## knock them off, dazed, out of `crew`; how many.
func _bowl(crew: Array, m: Variant, what: String) -> int:
	if m == null: return 0
	var v: Vector3 = m.velocity
	if not (Vector2(v.x,v.z).length() > K.RIP_HIT_SPEED*K.s() or v.y < -2.0*K.s()): return 0
	var n := 0
	for g: RefCounted in crew.duplicate():
		var at: Vector3 = (g.node as Node3D).global_position
		var d := Vector2(at.x-m.feet.x,at.z-m.feet.z).length()
		if d > K.HAUL_HIT*K.s()+float(g.radius) or absf(at.y-float(m.feet.y)) > WorldScale.wanderer_tall: continue
		var out := Vector3(at.x-m.feet.x,0.0,at.z-m.feet.z).normalized()
		if v.y > -2.0*K.s() and Vector3(v.x,0.0,v.z).normalized().dot(out) < 0.3: continue
		crew.erase(g)
		g.hauling = false
		g.pace = 1.0
		g.mid = at
		g.shake(out*2.4*K.s()+Vector3(v.x,0.0,v.z)*0.4+Vector3.UP*1.6*K.s())
		n += 1
		print("brood: knocked a hauler off %s (%d left)" % [what,crew.size()])
	return n

## Let down where it is, on the ground; none lifts it for RIP_REST s.
func _rip_down(st: Dictionary) -> void:
	var node: Node3D = st.p.node
	var at := node.global_position
	var hit := _ray(get_world_3d().direct_space_state,at+Vector3.UP*0.3,at+Vector3.DOWN*(K.DROP_MOST*K.s()))
	if not hit.is_empty(): node.global_transform = Transform3D(Basis(Vector3.UP,float(st.yaw)),hit.position)
	for g: RefCounted in st.crew: g.release()
	st.crew = []
	st.rest = K.RIP_REST
	rip_lets += 1
	print("brood: they let %s down" % st.p.id)

# --- The idle bag, hauled whole --------------------------------------------------------

## Its radius (m, world) and the full crew it calls.
func _bag_r() -> float:
	return (bag._ball as SphereShape3D).radius/0.95

func _bag_need() -> int:
	return clampi(ceili(float(bag.kg)/K.BAG_KG_EACH),K.BAG_CREW_LEAST,K.BAG_CREW_MOST)

## The fewest that lift it or keep it up.
func _bag_keep() -> int:
	return ceili(float(_bag_need())*K.BAG_KEEP)

## The full crew's pace by kg, times the crew they have over the full one.
func _bag_pace(n: int) -> float:
	var full := lerpf(K.BAG_PACE.x,K.BAG_PACE.y,clampf(float(bag.kg)/float(bag.CAP),0.0,1.0))
	return maxf(full*float(n)/float(_bag_need()),K.BAG_PACE_LEAST)

func _nearest_hole(at: Vector3) -> Node3D:
	var hole: Node3D = null
	for b: Node3D in burrows:
		if not is_instance_valid(b): continue
		if hole == null or b.global_position.distance_to(at) < hole.global_position.distance_to(at): hole = b
	return hole

## Lying on a burrow's mouth (set there): theirs already, left be.
func _bag_home() -> bool:
	var at: Vector3 = (bag.loose as Node3D).global_position
	var h := _nearest_hole(at)
	return h != null and Vector2(at.x-h.global_position.x,at.z-h.global_position.z).length() < K.HOME_NEAR*K.s() and absf(at.y-h.global_position.y) < 1.0*K.s()

## The idle clock (lying full and left), and the haul's end when he takes
## it (F, V: the bag frees itself) or it leaves the ground.
func _lift_watch(m: Variant, dt: float) -> void:
	_lift_rest = maxf(_lift_rest-dt,0.0)
	if not lift.is_empty():
		if bag.state != "ground" or not bool(bag.hauled):
			for g: RefCounted in lift.crew: g.release()
			lift = {}
			bag.haul_free()
			_idle_t = 0.0
			bag_takes += 1
			print("brood: he took the bag back from them")
		return
	var left: bool = m != null and not bool(bag.buried) and bag.state == "ground" and str(bag.act) == "" and float(bag.kg) > 0.0 and _lift_rest <= 0.0
	if left:
		var at: Vector3 = (bag.loose as Node3D).global_position
		var off := Vector2(at.x-m.feet.x,at.z-m.feet.z).length()-_bag_r()
		left = off > K.BAG_LEFT*K.s() and not _bag_home()
	_idle_t = _idle_t+dt if left else 0.0

## Idle long enough: the full crew's worth of the nearest free guys go to
## it (into `sent`); once BAG_KEEP of it are within reach, they lift it.
func _send_to_bag(busy: Dictionary, sent: Dictionary) -> void:
	if not lift.is_empty() or _idle_t < K.BAG_IDLE: return
	var at: Vector3 = (bag.loose as Node3D).global_position
	var reach := _bag_r()+K.HAUL_REACH*K.s()
	var near: Array = []
	var by: Array = []
	for g: RefCounted in guys:
		if busy.has(g) or sent.has(g) or g.daze > 0.0: continue
		if not (g.state == "walk" or g.state == "climb" or g.state == "mantle" or g.state == "fall"): continue
		var d := Vector2(g.feet.x-at.x,g.feet.z-at.z).length()
		near.append([d,g])
		if g.state == "walk" and d < reach and absf(float(g.feet.y)-(at.y-_bag_r())) < float(g.tall)*1.5: by.append([d,g])
	var need := _bag_need()
	if by.size() >= _bag_keep():
		by.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var crew: Array = []
		for k: int in mini(need,by.size()): crew.append(by[k][1])
		_lift_up(crew)
		return
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k: int in mini(need,near.size()): sent[near[k][1]] = at

func _lift_up(crew: Array) -> void:
	var at: Vector3 = (bag.loose as Node3D).global_position
	var hole := _nearest_hole(at)
	if hole == null: return
	bag.haul_hold()
	var lead: RefCounted = crew[0]
	lead.hauling = true
	lead.pace = _bag_pace(crew.size())
	lift = {"crew":crew,"hole":hole,"last":lead.feet,"best":hole.global_position.distance_to(at),"since":0.0}
	bag_hauls += 1
	print("brood: %d of %d lifted the bag (%.1f kg), off to %s (%.1f m)" % [crew.size(),_bag_need(),float(bag.kg),hole.name,float(lift.best)])

## The bag's haul: on the lead's head, the crew round him under it; free
## guys by it join; bowled under BAG_KEEP it's let down; at the burrow, set
## on the mouth.
func _lift_step(m: Variant, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	if lift.is_empty(): return
	var crew: Array = lift.crew
	bag_hits += _bowl(crew,m,"the bag")
	if crew.size() < _bag_keep() or (crew[0] as RefCounted).state == "lost":
		_lift_down()
		return
	var lead: RefCounted = crew[0]
	# More by it join, up to the full crew.
	if crew.size() < _bag_need():
		var busy := _busy()
		var reach := _bag_r()+K.HAUL_REACH*K.s()
		for g: RefCounted in guys:
			if crew.size() >= _bag_need(): break
			if busy.has(g) or g.state != "walk" or g.daze > 0.0: continue
			if Vector2(g.feet.x-lead.feet.x,g.feet.z-lead.feet.z).length() < reach and absf(float(g.feet.y)-float(lead.feet.y)) < float(g.tall)*1.5:
				crew.append(g)
				print("brood: one more on the bag (%d of %d)" % [crew.size(),_bag_need()])
	if not lead.hauling:
		lead.release()
		lead.hauling = true
	lead.pace = _bag_pace(crew.size())
	var lx: Transform3D = (lead.node as Node3D).global_transform
	var b := lx.basis.orthonormalized()
	var tall: float = lead.tall
	var r := _bag_r()
	var moved := ((lead.feet as Vector3)-(lift.last as Vector3)).length()
	lift.last = lead.feet
	bag.haul_place(lx.origin+b.y*(tall*0.5+r*0.8),atan2(b.z.x,b.z.z))
	var ring := r*0.85+float(lead.radius)*0.7
	for k: int in range(1,crew.size()):
		var a := TAU*float(k)/float(crew.size())
		var at := lx.origin+b.x*cos(a)*ring+b.z*sin(a)*ring
		if lead.state == "walk":
			var hit := _ray(space,at+Vector3.UP*tall,at+Vector3.DOWN*tall*1.5)
			if not hit.is_empty() and (hit.normal as Vector3).y >= K.FLOOR: at.y = float(hit.position.y)+tall*0.5
		(crew[k] as RefCounted).haul_at(at,b,moved,dt)
	var hole: Node3D = lift.hole
	var h := hole.global_position
	var left := (h-(lead.feet as Vector3)).length()
	lift.since = float(lift.since)+dt
	if left < float(lift.best)-K.HAUL_GAIN*K.s():
		lift.best = left
		lift.since = 0.0
	elif float(lift.since) > K.HAUL_STUCK:
		print("brood: stuck %.1f m short of %s with the bag" % [left,hole.name])
		_lift_down()
		return
	if Vector2(lead.feet.x-h.x,lead.feet.z-h.z).length() < K.HOME_NEAR*K.s() and absf(float(lead.feet.y)-h.y) < float(tall)*1.5:
		bag.haul_place(h+Vector3.UP*r,float(bag._rest_yaw))
		bag.bury()
		bag_in = str(hole.name)
		for g: RefCounted in crew: g.release()
		lift = {}
		_settle_guards(hole,crew,K.GUARDS_BAG)
		_idle_t = 0.0
		bag_homes += 1
		burials += 1
		print("brood: buried the bag (%.1f kg) in %s" % [float(bag.kg),hole.name])

## Let down where it is; none lifts it for BAG_REST s.
func _lift_down() -> void:
	for g: RefCounted in lift.crew: g.release()
	lift = {}
	bag.haul_free()
	_idle_t = 0.0
	_lift_rest = K.BAG_REST
	bag_lets += 1
	print("brood: they let the bag down")

## Wakes `count` guys out of the burrows, dealt round them nearest the bag
## first; each burrow's guys come up one after another.
func wake_burrows(n := -1) -> void:
	if n < 0: n = count
	woken = true
	var holes: Array = []
	for b: Node3D in burrows:
		if is_instance_valid(b) and b.is_inside_tree(): holes.append(b)
	if holes.is_empty():
		print("brood: no burrows")
		return
	var from := bag_at()
	if from == Vector3.INF: from = (holes[0] as Node3D).global_position
	holes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	if wake_holes > 0 and holes.size() > wake_holes: holes.resize(wake_holes)
	for i: int in n:
		var hole: Node3D = holes[i % holes.size()]
		var turn := i/holes.size()
		var g: RefCounted = spawn(hole.global_position)
		var wait := float(turn)*K.BURROW_STAGGER+_rng.randf()*K.WAKE_JITTER+float(i % holes.size())*K.WAKE_STAGGER
		g.rise_at(hole.global_position,wait,K.WAKE_HOLD*_rng.randf_range(0.5,1.5))
	print("brood: woke %d out of %d burrows (nearest %.1f m)" % [n,holes.size(),(holes[0] as Node3D).global_position.distance_to(from)])

# --- The burial: guards, and the dig ----------------------------------------------------

## Up to `n` guards on `hole`, from `crew` (who brought it).
func _settle_guards(hole: Node3D, crew: Array, n: int) -> void:
	var have := 0
	for g: RefCounted in guard_of: if guard_of[g] == hole: have += 1
	for g: RefCounted in crew:
		if have >= n: break
		if guard_of.has(g) or g.state == "lost": continue
		guard_of[g] = hole
		have += 1
	print("brood: %d guarding %s" % [have,hole.name])

## The guarded burrow he's at (within GUARD_NEAR of its mouth, held till
## he's GUARD_LEAVE off), or null.
func _guard_watch(m: Variant) -> Node3D:
	if m == null or guard_of.is_empty():
		_guard_hole = null
		return null
	var feet: Vector3 = m.feet
	if _guard_hole != null:
		var h := _guard_hole.global_position
		if not guard_of.values().has(_guard_hole) or Vector2(h.x-feet.x,h.z-feet.z).length() > K.GUARD_LEAVE*K.s():
			_guard_hole = null
	if _guard_hole == null:
		for hole: Variant in guard_of.values():
			var h: Vector3 = (hole as Node3D).global_position
			if Vector2(h.x-feet.x,h.z-feet.z).length() < K.GUARD_NEAR*K.s() and absf(h.y-feet.y) < 2.0*K.s():
				_guard_hole = hole
				print("brood: he's at %s; its guards come for him" % _guard_hole.name)
				break
	return _guard_hole

## A guard: round its burrow's mouth, or at him while he's at it.
func _guard_step(g: RefCounted, i: int, m: Variant, guarded: Node3D, used: Dictionary, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	var hole: Node3D = guard_of[g]
	var to := hole.global_position+_ring(i)*K.GUARD_RING*K.s()
	if hole == guarded:
		to = m.feet
		if g.state == "walk" and g.daze <= 0.0 and _grace_t <= 0.0 and bool(m.grounded) and used.size() < K.GRAB_SLOTS and _in_grab(g,m.feet):
			g.slot = _free_slot(used)
			used[g.slot] = true
			g.cling_at(m.feet,Vector3.BACK)
	g.step(space,to,dt)

func _hole_named(called: String) -> Node3D:
	for b: Variant in burrows:
		if is_instance_valid(b) and str((b as Node3D).name) == called: return b
	return null

## Something buried in burrow `called` (the bag, or pieces)?
func has_pile(called: String) -> bool:
	return bag_in == called or not (buried.get(called,[]) as Array).is_empty()

## Burrow `called` dug open (the dig's second bite at `at`): the bag hops
## out toward him, the pieces land round the mouth, the guards stand down.
func dig_out(called: String, at: Vector3) -> void:
	var hole := _hole_named(called)
	if hole == null: return
	var h := hole.global_position
	var m: Variant = _motor()
	var toward := Vector3.BACK
	if m != null:
		var off: Vector3 = (m.feet as Vector3)-h
		off.y = 0.0
		if off.length() > 0.05: toward = off.normalized()
	var what: Array = []
	if bag_in == called:
		bag.unbury(h+Vector3.UP*(_bag_r()+0.3*K.s()),(toward*0.5+Vector3.UP)*K.PILE_HOP*K.s())
		bag_in = ""
		what.append("the bag")
	var pieces: Array = buried.get(called,[])
	var space := get_world_3d().direct_space_state
	for k: int in pieces.size():
		var p: Dictionary = pieces[k]
		p["buried"] = false
		var node: Node3D = p.node
		node.visible = true
		var a := atan2(toward.x,toward.z)+PI*0.5+PI*float(k+1)/float(pieces.size()+1)
		var to := h+Vector3(sin(a),0.0,cos(a))*K.PILE_OUT*K.s()
		var hit := _ray(space,to+Vector3.UP*0.8*K.s(),to+Vector3.DOWN*2.0*K.s())
		if not hit.is_empty(): to = hit.position
		_pops.append({"node":node,"from":h,"to":to,"t":0.0,"yaw":_rng.randf()*TAU})
		what.append(str(p.id))
	buried.erase(called)
	for g: RefCounted in guard_of.keys():
		if guard_of[g] == hole: guard_of.erase(g)
	if _guard_hole == hole: _guard_hole = null
	digs_out += 1
	print("brood: dug out %s: %s" % [called,", ".join(what)])

## The dug pieces hopping out of the mouth onto the floor round it.
func _pops_step(dt: float) -> void:
	for pp: Dictionary in _pops.duplicate():
		pp.t = float(pp.t)+dt
		var k := clampf(float(pp.t)/K.PILE_POP,0.0,1.0)
		var at: Vector3 = (pp.from as Vector3).lerp(pp.to,k)+Vector3.UP*0.7*K.s()*sin(PI*k)
		(pp.node as Node3D).global_transform = Transform3D(Basis(Vector3.UP,float(pp.yaw)+k*5.0),at)
		if k >= 1.0: _pops.erase(pp)

# --- Going home ----------------------------------------------------------------------

## Anything for them to take: loot on him, the bag lying loose with loot in
## it (or being hauled), a ripped piece about.
func _something_to_take() -> bool:
	if not strays.is_empty() or not lift.is_empty(): return true
	if float(bag.kg) <= 0.0 or bool(bag.buried): return false
	return true

## The calm clock (nothing to take, none on him); past HOME_AFTER the free
## ones head home, past GUARD_HOME_AFTER the guards too (not while he's at
## their burrow). Something to take again: the ones still walking home turn
## back.
func _home_watch(m: Variant, dt: float) -> void:
	var calm := not _something_to_take() and clinging == 0 and m != null
	calm_t = calm_t+dt if calm else 0.0
	if not calm:
		for g: RefCounted in homing.keys():
			if g.state != "sink" and g.state != "home": homing.erase(g)
		return
	if calm_t < K.HOME_AFTER: return
	var guards := calm_t >= K.GUARD_HOME_AFTER
	for g: RefCounted in guys:
		if homing.has(g) or g.state == "lost" or g.state == "wake": continue
		if g.state != "walk" and g.state != "climb" and g.state != "mantle" and g.state != "fall": continue
		var hole: Node3D = null
		if guard_of.has(g):
			if not guards or guard_of[g] == _guard_hole: continue
			hole = guard_of[g]
			guard_of.erase(g)
		else: hole = _nearest_hole(g.feet)
		if hole == null: continue
		homing[g] = hole
		if homing.size() == 1: print("brood: nothing to take for %.0f s; they head home" % calm_t)

## A guy going home: walk to the mouth, then down into it.
func _home_step(g: RefCounted, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	var h: Vector3 = (homing[g] as Node3D).global_position
	if g.state == "walk" and Vector2(g.feet.x-h.x,g.feet.z-h.z).length() < K.HOME_DOWN*K.s() and absf(float(g.feet.y)-h.y) < float(g.tall)*1.5:
		g.sink_at(h)
	g.step(space,h,dt)

## The ones gone down: off the board.
func _put_away() -> void:
	for g: RefCounted in homing.keys():
		if g.state != "home": continue
		homing.erase(g)
		guys.erase(g)
		(g.node as Node3D).queue_free()
		gone_home += 1
		if guys.is_empty(): print("brood: all home (%d went down)" % gone_home)
