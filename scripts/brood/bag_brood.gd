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
## for a stray, take it up and haul it to the nearest burrow, where it's
## taken down (`buried`, by the burrow's name; the dig is the next step).
## He bowls into the crew (under RIP_CREW left they let it down) or takes
## it back with E, as any piece on the ground.

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
	super.clear()
	if bag != null: bag.set_slow(1.0)

## Where the bag is now: on him (worn, dragged) or where it lies.
func bag_at() -> Vector3:
	if bag == null: return Vector3.INF
	if _on_him():
		var m: Variant = _motor()
		return m.feet if m != null else Vector3.INF
	return (bag.loose as Node3D).global_position

## The bag on him (worn or by its neck)?
func _on_him() -> bool:
	return bag != null and (bag.state == "worn" or bag.state == "drag")

func _tick(delta: float) -> void:
	if study == null or bag == null or not bool(study.get("walk_ready")): return
	if not woken and (float(bag.kg) > 0.0 or not (bag.stowing as Dictionary).is_empty()): wake_burrows()
	if guys.is_empty(): return
	var dt := minf(delta,1.0/30.0)
	var space := get_world_3d().direct_space_state
	var m: Variant = _motor()
	var on_him: bool = _on_him() and float(bag.kg) > 0.0 and goal_override == Vector3.INF and m != null
	var goal := goal_override
	if goal == Vector3.INF: goal = bag_at()
	if not on_him: _shake_all(Vector3.ZERO)
	elif not bool(m.grounded) and float(m.velocity.y) > K.SHAKE_UP*K.s(): _shake_all(Vector3(m.velocity.x,0.0,m.velocity.z)*0.3)
	var used := {}
	for g: RefCounted in guys: if g.state == "cling": used[g.slot] = true
	_grace_t = maxf(_grace_t-dt,0.0)
	_prune_strays()
	var busy := {}
	for st: Dictionary in strays: for g: RefCounted in st.crew: busy[g] = st
	var sent := _send_to_strays(busy)
	_separate()
	for i: int in guys.size():
		var g: RefCounted = guys[i]
		if g.state == "lost": continue
		if busy.has(g):
			var st: Dictionary = busy[g]
			if g == st.crew[0]: g.step(space,(st.hole as Node3D).global_position,dt)
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
			to = goal+_ring(i)*K.CROWD_RING*K.s()
		g.step(space,to,dt)
	_cling_step(m,dt)
	_strays_step(m,space,dt)

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
		_rip_t -= dt*(1.0+K.RIP_MORE*float(n-1))
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

## The RIP_CREW nearest free guys (walking or on the way, not dazed, not
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
		for k: int in mini(K.RIP_CREW,near.size()): sent[near[k][1]] = at
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

## RIP_CREW free guys at a stray take it up, toward the nearest burrow.
func _take_up(st: Dictionary) -> void:
	var p: Dictionary = st.p
	var at: Vector3 = (p.node as Node3D).global_position
	var reach := float(p.measures.radius)+K.HAUL_REACH*K.s()
	var busy := {}
	for o: Dictionary in strays: for g: RefCounted in o.crew: busy[g] = true
	var near: Array = []
	for g: RefCounted in guys:
		if busy.has(g) or g.state != "walk" or g.daze > 0.0: continue
		var d := Vector2(g.feet.x-at.x,g.feet.z-at.z).length()
		if d < reach and absf(float(g.feet.y)-at.y) < float(g.tall)*1.5: near.append([d,g])
	if near.size() < K.RIP_CREW: return
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var crew: Array = []
	for k: int in K.RIP_CREW: crew.append(near[k][1])
	var hole: Node3D = null
	for b: Node3D in burrows:
		if not is_instance_valid(b): continue
		if hole == null or b.global_position.distance_to(at) < hole.global_position.distance_to(at): hole = b
	if hole == null: return
	var lead: RefCounted = crew[0]
	lead.hauling = true
	lead.pace = K.RIP_PACE
	st.crew = crew
	st.hole = hole
	st.last = lead.feet
	st.best = hole.global_position.distance_to(at)
	st.since = 0.0
	rip_hauls += 1
	print("brood: %d took up %s, off to %s (%.1f m)" % [crew.size(),p.id,hole.name,float(st.best)])

## A stray's haul: on the lead's head, the crew round him; his runs into
## them knock them off (under RIP_CREW left, let down); at the burrow,
## taken down.
func _rip_haul(st: Dictionary, m: Variant, space: PhysicsDirectSpaceState3D, dt: float) -> void:
	var p: Dictionary = st.p
	var crew: Array = st.crew
	if m != null:
		var v: Vector3 = m.velocity
		var fast := Vector2(v.x,v.z).length() > K.RIP_HIT_SPEED*K.s() or v.y < -2.0*K.s()
		if fast:
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
				rip_hits += 1
				print("brood: knocked a hauler off %s (%d left)" % [p.id,crew.size()])
	if crew.size() < K.RIP_CREW or (crew[0] as RefCounted).state == "lost":
		_rip_down(st)
		return
	var lead: RefCounted = crew[0]
	if not lead.hauling:
		lead.release()
		lead.hauling = true
		lead.pace = K.RIP_PACE
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
		print("brood: %s taken down into %s (%d there)" % [p.id,hole.name,(buried[hole.name] as Array).size()])

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

## Wakes `count` guys out of the burrows, dealt round them nearest the bag
## first; each burrow's guys come up one after another.
func wake_burrows() -> void:
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
	for i: int in count:
		var hole: Node3D = holes[i % holes.size()]
		var turn := i/holes.size()
		var g: RefCounted = spawn(hole.global_position)
		var wait := float(turn)*K.BURROW_STAGGER+_rng.randf()*K.WAKE_JITTER+float(i % holes.size())*K.WAKE_STAGGER
		g.rise_at(hole.global_position,wait,K.WAKE_HOLD*_rng.randf_range(0.5,1.5))
	print("brood: woke %d out of %d burrows (nearest %.1f m)" % [count,holes.size(),(holes[0] as Node3D).global_position.distance_to(from)])
