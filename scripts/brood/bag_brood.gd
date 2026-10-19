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

## The burrows: Node3D, each at its mouth's floor.
var burrows: Array = []
## The bag (the study's `bag`).
var bag: Node3D = null

func setup_bag(host: Node3D, holes: Array) -> void:
	setup(host)
	burrows = holes
	bag = host.get("bag")
	count = K.BAG_STUDY_COUNT
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--brood-count="): count = maxi(int(a.get_slice("=",1)),1)

func clear() -> void:
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
	_separate()
	for i: int in guys.size():
		var g: RefCounted = guys[i]
		if g.state == "lost": continue
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
