extends RefCounted
## The forgiving knife slots (RuinKitGothic `openings` with `forgive`: the
## nave's buttress slots, the rose gate's slots). The strict ones (the
## belfry's slits, the nave's east slits and wall lights) are left to the
## flight's contact as ever.
##
## In or at the mouth of a forgiving slot, rolled far enough onto a wingtip
## that its body fits (half the slot's width less ROLLED), the plane's reach
## is fitted to its true side shape (WorldScale `reach_fitted`: the keel's
## reach one way, the roof's the other; the study's `solid_pad` and
## `solid_shift` for the frame), and a jamb met within LOOK s (its face at
## the mouth or its side down the slot) is glanced off: the plane is slid
## across toward the slot's middle to where its fitted body clears the
## jamb, a share each frame so it lands clear by the time it gets there, and
## the touch is a scrape (FlightContact `glance`), never a crash. A plane
## more than CATCH m past the slot's side, or with its wings too level to
## fit, meets the stone as anywhere else.
##
## Run before the plane's move (studies/endless_flight.gd `tick`, after the
## trees' knock).

const Gothic = preload("res://scripts/ruin_kit_gothic.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## How far before a slot's mouth (and past its end) it catches, along it (m).
const LEAD := 6.0
## How far past a slot's side the middle may be and still be caught (m): the
## keel's reach and a little; past that the plane has met the wall itself.
const CATCH := 1.2
## The least room a side (m) the fitted body must leave in the slot for it
## to be caught: wings too level for that and the slot is a wall.
const ROLLED := 0.05
## How far ahead (s) a jamb is looked for, and the slide's step (m).
const LOOK := 0.12
const STEP := 0.04
## The most steps ahead looked at (a frame each).
const LOOKS := 16

## This frame's slot ({} out of one): {name, inv (world to the slot's frame),
## across (world, its x), half (its clear box's half size), head}.
var zone := {}
## Forgiving slots by record name: {id (the node's instance id), list}.
var _slots := {}

## One frame, before the move. Returns {} or FlightContact `glance`'s
## {"scrape": ...} for the frame's events.
func before(delta: float, game: Node3D) -> Dictionary:
	zone = {}
	var plane = game.plane
	if game.arches == null or not bool(plane.weighted) or not bool(game.hand_landing.flying()): return {}
	var p: Vector3 = plane.position
	var v: Vector3 = plane.velocity
	var ahead := p+v*delta
	var slot := _slot_at(game,ahead)
	if slot.is_empty(): return {}
	var up := Basis.from_euler(Vector3(float(plane.pitch),float(plane.heading),-(float(plane.bank)+float(plane.spin))))*Vector3.UP
	var fit := WorldScale.reach_fitted(up)
	var level := Vector3(up.x,0.0,up.z)
	var keel := Vector3.ZERO if fit.y == 0.0 or level.length() < 0.001 else -level.normalized()*fit.y
	var across: Vector3 = slot.across
	var half: Vector3 = slot.half
	if half.x-fit.x-absf(keel.dot(across)) < ROLLED: return {}
	zone = slot
	game.solid_pad = fit.x
	game.solid_shift = keel
	# The first time within LOOK the fitted body meets stone.
	var arches = game.arches
	var hit_t := -1.0
	var dt := maxf(delta,1.0/120.0)
	for i in range(1,LOOKS+1):
		var t := dt*i
		if t > maxf(LOOK,dt)+0.0001: break
		if bool(arches.inside(p+v*t+keel,fit.x)):
			hit_t = t
			break
	if hit_t < 0.0: return {}
	# Across toward the middle, to where it clears there.
	var meet := p+v*hit_t+keel
	var side := ((slot.inv as Transform3D)*meet).x
	var dir := -across if side > 0.0 else across
	var need := -1.0
	var k := STEP
	var most := absf(side)+fit.x+0.3
	while k <= most:
		if not bool(arches.inside(meet+dir*k,fit.x)):
			need = k
			break
		k += STEP
	if need < 0.0: return {}
	# A share of it now, all of it by the time it gets there; never left
	# in the stone this frame.
	var share := need*clampf(dt/hit_t,0.0,1.0)
	while share < need and bool(arches.inside(ahead+keel+dir*share,fit.x)): share = minf(need,share+STEP)
	if bool(arches.inside(p+keel+dir*share,fit.x)) and bool(arches.inside(ahead+keel+dir*share,fit.x)): return {}
	plane.position = p+dir*share
	return game.contact.glance(game,dir,meet-dir*fit.x)

## The forgiving slot the plane's middle `p` is in or at the mouth of, or {}.
func _slot_at(game: Node3D, p: Vector3) -> Dictionary:
	for r: Dictionary in game.arches.sets_near(p):
		for s: Dictionary in _list(r):
			var l: Vector3 = (s.inv as Transform3D)*p
			var h: Vector3 = s.half
			if absf(l.x) > h.x+CATCH or absf(l.z) > h.z+LEAD: continue
			if l.y < -h.y-0.5 or l.y > h.y+float(s.head)+0.5: continue
			return s
	return {}

## The forgiving slots of set piece record `r`, in the world.
func _list(r: Dictionary) -> Array:
	var node: Node3D = r.node
	var name := String(r.name)
	var had: Variant = _slots.get(name)
	if had != null and int((had as Dictionary).id) == node.get_instance_id(): return (had as Dictionary).list
	var spec: Dictionary = r.spec
	var list: Array = []
	for o: Dictionary in Gothic.openings(String(spec.kind),int(spec.seed),float(spec.weathered)):
		if not bool(o.get("knife",false)) or not bool(o.get("forgive",false)): continue
		var f: Transform3D = node.global_transform*(o.frame as Transform3D)
		list.append({"name":String(o.name),"inv":f.affine_inverse(),"across":f.basis.x.normalized(),"half":(o.size as Vector3)*0.5,"head":float(o.head)})
	if _slots.size() > 64: _slots.clear()
	_slots[name] = {"id":node.get_instance_id(),"list":list}
	return list
