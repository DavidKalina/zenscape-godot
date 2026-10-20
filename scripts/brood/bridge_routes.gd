extends RefCounted
## Floors and rope bridges as routes for the stone brood
## (docs/design/bridge-snap/spec-bridge-snap.md, task 5). Opt-in: a study
## builds one, tells it its floors (flat rects) and its live rope bridges,
## and sets it as StoneGuy.route (scripts/brood/stone_guy.gd); without one
## the brood walk straight at their goal as before.
##
## The zones are the floors and the bridges' decks. Floors that share an
## edge are joined along it; a bridge joins the floors under its two ends. A
## walking guy whose goal is in another zone heads for the next crossing on
## the shortest way there (Dijkstra over the zones): to the shared edge, or
## to a spot LINE_UP m back from a bridge's end on its line, then up its
## funnel onto the deck. On a deck he walks its middle line (LOOK m ahead), to the
## goal if it's on that deck, else OUT m past the end he leaves by; `keep`
## holds him off its open sides. A snapped bridge (its BridgeLoad `broken`)
## is no route.

const Footbridge = preload("res://scripts/footbridge.gd")

## Ahead along a deck's middle line (m) a guy on it walks for.
const LOOK := 1.6
## Back from a bridge's end on the cliff (m): where they line up.
const LINE_UP := 2.0
## The funnel in front of a bridge's end: within LINE_UP+0.8 back and
## FUNNEL m off its line, a guy walks for the line FUNNEL_AHEAD m ahead of
## him, so a crowd jostled off the line still files on.
const FUNNEL := 1.6
const FUNNEL_AHEAD := 1.4
## Past a deck's end (m) a guy leaving it walks for.
const OUT := 2.2
## Into the next floor past a shared edge (m), and kept in from the edge's
## ends (m).
const EDGE_IN := 1.0
const EDGE_KEEP := 0.9
## A guy is on a deck within its half width plus ON_SLACK of the middle
## line; a goal is within GOAL_SLACK (the crowd ring round him on it).
const ON_SLACK := 0.3
const GOAL_SLACK := 2.6
## Held this far (m) inside the deck's edge.
const KEEP_IN := 0.22

## The brood's node: guys' feet are in its frame.
var frame: Node3D
## {name, rect (Rect2 in x, z), y (its top)}.
var floors: Array = []
## {name, holder (Node3D), live (the rope bridge), a, b (ends, holder's
## frame), span, load (BridgeLoad or null)}.
var decks: Array = []
## Crossings, both ways: {from, to, kind ("edge", "onto", "off"), p0, p1
## (an edge's ends, world), n (into `to`), deck, end (0 at a, 1 at b)}.
var _links: Array = []
var _built := false
## Steps sent somewhere other than the goal (drivers).
var routed := 0

func add_floor(called: String, rect: Rect2, y := 0.0) -> void:
	floors.append({"name":called,"rect":rect,"y":y})
	_built = false

func add_deck(called: String, holder: Node3D, live: Node3D, a: Vector3, b: Vector3, span: float, load: Node = null) -> void:
	decks.append({"name":called,"holder":holder,"live":live,"a":a,"b":b,"span":span,"load":load})
	_built = false

# --- Called by StoneGuy ------------------------------------------------------------------

## The spot (the brood's frame) a walking guy heads for to get to `goal`.
func way(g: RefCounted, goal: Vector3) -> Vector3:
	if goal == Vector3.INF or frame == null: return goal
	if not _built: _build()
	var p: Vector3 = frame.global_transform*g.feet
	var q: Vector3 = frame.global_transform*goal
	var zp := _zone_of(p,false)
	if zp < 0: return goal
	var zq := _zone_of(q,true)
	if zq < 0: return goal
	var to := Vector3.INF
	if zp == zq:
		if zp < floors.size(): return goal
		var d: Dictionary = decks[zp-floors.size()]
		to = _along(d,p,_t_of(d,q).x)
	else:
		var link := _first_link(zp,p,zq,q)
		if link.is_empty(): return goal
		to = _toward(link,p)
	routed += 1
	return frame.global_transform.affine_inverse()*to

## Holds a guy on a deck off its open sides (his feet pulled in across).
func keep(g: RefCounted) -> void:
	if frame == null: return
	var p: Vector3 = frame.global_transform*g.feet
	for d: Dictionary in decks:
		if _broken(d): continue
		var tl := _t_of(d,p)
		if tl.x <= 0.0 or tl.x >= 1.0: continue
		var half := Footbridge.WIDTH*0.5
		if absf(tl.y) > half+ON_SLACK or not _level(d,p,tl.x): continue
		var most := half-KEEP_IN
		if absf(tl.y) <= most: return
		p -= _across(d)*(tl.y-clampf(tl.y,-most,most))
		g.feet = frame.global_transform.affine_inverse()*p
		return

# --- Zones -------------------------------------------------------------------------------

## The zone at `p`: a deck (index floors.size()+i) first, then a floor; for
## a goal, a wider deck and else the nearest floor. -1 none.
func _zone_of(p: Vector3, goal: bool) -> int:
	for i: int in decks.size():
		var d: Dictionary = decks[i]
		if _broken(d): continue
		var tl := _t_of(d,p)
		if tl.x <= 0.0 or tl.x >= 1.0: continue
		if absf(tl.y) > Footbridge.WIDTH*0.5+(GOAL_SLACK if goal else ON_SLACK): continue
		if not _level(d,p,tl.x): continue
		return floors.size()+i
	var best := -1
	var near := 4.0 if goal else 0.0
	for i: int in floors.size():
		var f: Dictionary = floors[i]
		if p.y < float(f.y)-1.5 or p.y > float(f.y)+3.0: continue
		var r: Rect2 = f.rect
		var flat := Vector2(p.x,p.z)
		var off := flat.distance_to(Vector2(clampf(flat.x,r.position.x,r.end.x),clampf(flat.y,r.position.y,r.end.y)))
		if off <= near:
			near = off
			best = i
			if off == 0.0: break
	return best

func _broken(d: Dictionary) -> bool:
	var load: Node = d.load
	return load != null and is_instance_valid(load) and bool(load.get("broken"))

## On the deck's level at `t` (not far under it, falling, or over it).
func _level(d: Dictionary, p: Vector3, t: float) -> bool:
	var c := _centre(d,t)
	return p.y > c.y-3.0 and p.y < c.y+2.5

## (t along the deck, signed m across from its middle line) of `p`.
func _t_of(d: Dictionary, p: Vector3) -> Vector2:
	var holder: Node3D = d.holder
	var local := holder.global_transform.affine_inverse()*p
	var a: Vector3 = d.a
	var ab: Vector3 = d.b-a
	ab.y = 0.0
	var rel := local-a
	rel.y = 0.0
	var t := rel.dot(ab)/maxf(ab.length_squared(),0.01)
	var c := holder.global_transform.affine_inverse()*_centre(d,t)
	var side := ab.normalized().cross(Vector3.UP)
	var across := (local-c)
	across.y = 0.0
	return Vector2(t,across.dot(side))

## The across way (world) `_t_of` measures along.
func _across(d: Dictionary) -> Vector3:
	var ab: Vector3 = d.b-d.a
	ab.y = 0.0
	return (d.holder as Node3D).global_basis*(ab.normalized().cross(Vector3.UP))

## The deck's middle line at `t` (world): the resting curve dropped and
## swayed by the sim; past its ends, on along its line level with them.
func _centre(d: Dictionary, t: float) -> Vector3:
	var a: Vector3 = d.a
	var b: Vector3 = d.b
	var p := a.lerp(b,t)
	if t > 0.0 and t < 1.0:
		p += Vector3.UP*Footbridge.lift(float(d.span),t)
		var live: Node3D = d.live
		var sim: Variant = live.get("sim")
		if sim != null:
			var off: Vector2 = sim.offset(t,0.0)
			p += Vector3.UP*off.x+(live.get("across") as Vector3)*off.y
	return (d.holder as Node3D).global_transform*p

## Where a guy on deck `d` at `p` walks for to get to `t_to` along it.
func _along(d: Dictionary, p: Vector3, t_to: float) -> Vector3:
	var span := float(d.span)
	var t := _t_of(d,p).x
	var step := LOOK/span
	var tw := t_to if absf(t_to-t)*span < LOOK else t+signf(t_to-t)*step
	return _centre(d,tw)

# --- The crossings -----------------------------------------------------------------------

func _end(d: Dictionary, e: int) -> Vector3:
	return (d.holder as Node3D).global_transform*(d.a if e == 0 else d.b)

## Onto the deck from end `e` (world, flat).
func _in(d: Dictionary, e: int) -> Vector3:
	var w := _end(d,1-e)-_end(d,e)
	w.y = 0.0
	return w.normalized()

func _build() -> void:
	_built = true
	_links.clear()
	var nf := floors.size()
	for i: int in nf:
		for j: int in nf:
			if i == j: continue
			var e := _shared_edge(floors[i].rect,floors[j].rect)
			if e.is_empty(): continue
			var y := float(floors[i].y)
			_links.append({"from":i,"to":j,"kind":"edge","p0":Vector3(e[0].x,y,e[0].y),"p1":Vector3(e[1].x,y,e[1].y),"n":Vector3(e[2].x,0.0,e[2].y)})
	for k: int in decks.size():
		var d: Dictionary = decks[k]
		for e: int in 2:
			var back := _end(d,e)-_in(d,e)*1.0
			var f := -1
			for i: int in nf:
				var r: Rect2 = floors[i].rect
				if r.grow(0.05).has_point(Vector2(back.x,back.z)): f = i
			if f < 0: continue
			_links.append({"from":f,"to":nf+k,"kind":"onto","deck":k,"end":e})
			_links.append({"from":nf+k,"to":f,"kind":"off","deck":k,"end":e})

## The edge rect `a` shares with `b` (touching sides, overlapping by more
## than 2 EDGE_KEEP): [end, end, way from a into b] (x, z), or [].
static func _shared_edge(a: Rect2, b: Rect2) -> Array:
	var eps := 0.05
	var sides := [
		[absf(a.end.x-b.position.x) < eps,Vector2(1,0)],
		[absf(a.position.x-b.end.x) < eps,Vector2(-1,0)],
		[absf(a.end.y-b.position.y) < eps,Vector2(0,1)],
		[absf(a.position.y-b.end.y) < eps,Vector2(0,-1)],
	]
	for s: Array in sides:
		if not bool(s[0]): continue
		var n: Vector2 = s[1]
		if n.x != 0.0:
			var lo := maxf(a.position.y,b.position.y)
			var hi := minf(a.end.y,b.end.y)
			if hi-lo < EDGE_KEEP*2.0: continue
			var x := a.end.x if n.x > 0.0 else a.position.x
			return [Vector2(x,lo),Vector2(x,hi),n]
		var lo2 := maxf(a.position.x,b.position.x)
		var hi2 := minf(a.end.x,b.end.x)
		if hi2-lo2 < EDGE_KEEP*2.0: continue
		var z := a.end.y if n.y > 0.0 else a.position.y
		return [Vector2(lo2,z),Vector2(hi2,z),n]
	return []

## Where a crossing is taken from `from` (world).
func _cross_at(link: Dictionary, from: Vector3) -> Vector3:
	if link.kind == "edge":
		var p0: Vector3 = link.p0
		var p1: Vector3 = link.p1
		var w := (p1-p0).normalized()
		var u := clampf((from-p0).dot(w),EDGE_KEEP,(p1-p0).length()-EDGE_KEEP)
		return p0+w*u
	return _end(decks[link.deck],link.end)

## The first crossing on the shortest way from zone `zp` (at `p`) to `zq`
## (at `q`): Dijkstra over the zones, each reached at a crossing's spot.
func _first_link(zp: int, p: Vector3, zq: int, q: Vector3) -> Dictionary:
	var cost := {zp:0.0}
	var at := {zp:p}
	var first := {zp:{}}
	var open := [zp]
	var done := {}
	while not open.is_empty():
		var z: int = open[0]
		for o: int in open: if float(cost[o]) < float(cost[z]): z = o
		open.erase(z)
		if done.has(z): continue
		done[z] = true
		if z == zq: return first[z]
		for link: Dictionary in _links:
			if int(link.from) != z or done.has(int(link.to)): continue
			if link.kind != "edge" and _broken(decks[link.deck]): continue
			var lp := _cross_at(link,at[z])
			var c := float(cost[z])+(at[z] as Vector3).distance_to(lp)
			var to: int = link.to
			if to == zq: c += lp.distance_to(q)
			if not cost.has(to) or c < float(cost[to]):
				cost[to] = c
				at[to] = lp
				first[to] = first[z] if not (first[z] as Dictionary).is_empty() else link
				open.append(to)
	return {}

## The spot to walk for to take `link` from `p`.
func _toward(link: Dictionary, p: Vector3) -> Vector3:
	match str(link.kind):
		"edge":
			return _cross_at(link,p)+(link.n as Vector3)*EDGE_IN
		"onto":
			var d: Dictionary = decks[link.deck]
			var e: int = link.end
			var end := _end(d,e)
			var u := _in(d,e)
			var rel := p-end
			rel.y = 0.0
			var along := rel.dot(u)
			var across := absf(rel.dot(u.cross(Vector3.UP)))
			if along < -LINE_UP-0.8 or across > FUNNEL: return end-u*LINE_UP
			# In the funnel: for the line a little ahead, onto the deck.
			var ahead := along+FUNNEL_AHEAD
			if ahead <= 0.0: return end+u*ahead
			var t := minf(ahead,LOOK)/float(d.span)
			return _centre(d,t if e == 0 else 1.0-t)
		"off":
			var d: Dictionary = decks[link.deck]
			var t_out := -OUT/float(d.span) if int(link.end) == 0 else 1.0+OUT/float(d.span)
			return _along(d,p,t_out)
	return p
