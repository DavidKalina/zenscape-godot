extends RefCounted
## The generator's headless bodies, planned (docs/design/roguelike/layer-
## round9-bodies.md): for each inhaler head the generator lays (scripts/
## roguelike/layer_enemies.gd), the cliffs its body (scripts/enemies/
## headless_body.gd) may come up, on its own isle or a nearby one, from
## which the body can get to the head by its own moves. Laid as data on the
## plan's head ({cliffs: [[name, lip, out (x, z), hang]]}); the stage's
## spawner (scripts/enemies/body_spawner.gd) brings a body up one of them
## when the walker comes near, fitting it to the built face first.
##
## Read off the isles' occupancy (LayerPlan `occ_at`: per CELL m column,
## each isle's lowest and highest solid there), each isle's column a place
## to stand on its top (an isle hung over another is a place of its own,
## and a roof over the one under it):
##   - a cliff is a column whose top has open sky (or ground more than the
##     body's hang under it) out past it on one side and its neighbours
##     along the rim, its isle's stone FACE_DEPTH of the hang deep under its
##     top, and flat ground (WALK) in behind it to haul onto; clear of the
##     edges' paths, the rides' tubes, the piers and the cannons.
##   - the body's moves, column to column (`_can`): a walk (the tops within
##     WALK); a climb up a wall to `climb_max`; down off an edge onto a
##     lower top within `drop_max`, `leap_max` across, no lower than
##     `drop_under` under the head's ground; a jump across open
##     sky to a top `jump_gap` across at most, `jump_rise` over or
##     `jump_sink` under (the body's knobs: its `default_knobs`).
##   - a cliff is kept if the head's ground can be got to from it (flooded
##     back from the head's spot and its round, `_reach`).
## Cliffs nearest the head first (its own isle's before another's),
## CLIFF_APART apart, CLIFFS_MOST of them, within CLIFF_FAR of the head
## (flat), on isles within NEAR of its isle.
## The occupancy can't see under an arch or between columns, so the floor
## it reads is the top of what stands there: the spawn's `fit` and the
## body's own rays in play have the last word.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerHazards = preload("res://scripts/roguelike/layer_hazards.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")

const CELL := 2.0
## Isles within this of the head's isle (m, rect to rect) are in its reach.
const NEAR := 40.0
## Tops within this of each other are walked (m, a cell apart).
const WALK := 1.2
## The stone under a lip, at least this share of the body's hang deep.
const FACE_DEPTH := 0.75
## Cliffs kept: at most CLIFFS_MOST, CLIFF_APART apart, within CLIFF_FAR
## of the head (m, flat).
const CLIFFS_MOST := 10
const CLIFF_APART := 10.0
const CLIFF_FAR := 90.0
## The head's ground: the columns within HEAD_CELLS of its spot and of its
## round's points whose tops are within HEAD_LEVEL of the spot's.
const HEAD_CELLS := 2
const HEAD_LEVEL := 2.5
const DIRS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

## The generator's spawn rules over BodySpawner RULES (round 10, layer-
## round10-far-bodies.md): now and then a body comes up a far cliff in
## the walker's view, to watch it climb across a gulf. `--knob=spawn_<rule>=`
## over these.
const SPAWN := {"far_share":0.3}
## Underground, by the danger (0 the first region, 1 the fourth): a bare
## head's body comes back after this long (s, BodySpawner `wait`), and this
## share of its comings are far ones.
const DANGER_WAIT := Vector2(6.0,1.0)
const DANGER_FAR := Vector2(0.2,0.45)

static var _build := {}
static var _build_lock := Mutex.new()

## The generator's bodies' own knobs (over the study's): headless, they
## drop no more than 3 walker heads under their head's ground unless lost
## (HeadlessBody `_drop_ok`), so they don't strand themselves on the spurs
## and ledges down the isles' cliffs.
## Whole, its hunt is on (whole-body-chase-round1.md): `--body-chase=0`
## turns it off (not a plan knob: those are layer_plan.gd's). Any body knob
## by `--body-knob=<knob>=<value>`, as the studies take it (e.g.
## `--body-knob=leap_grab=1`).
static func knobs(n: Dictionary) -> Dictionary:
	var out := {"drop_under":float(n.unit)*3.0,"chase":1.0}
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--body-chase="): out.chase = float(arg.get_slice("=",1))
		elif arg.begins_with("--body-knob="):
			var pair := arg.trim_prefix("--body-knob=")
			out[pair.get_slice("=",0)] = float(pair.get_slice("=",1))
	return out

## The spawn rules for a plan's knobs: SPAWN, then its `spawn_<rule>`s.
static func spawn_rules(plan_knobs: Dictionary) -> Dictionary:
	var out := SPAWN.duplicate()
	# Danger by height (scripts/roguelike/layer_worlds.gd `danger`): higher
	# up a body comes back sooner once its head is bare, and more often in
	# view across a gulf (the climb gets watched).
	var d := LayerPlan.LayerWorlds.danger(plan_knobs)
	if LayerPlan.LayerWorlds.world_of(plan_knobs) == "under":
		out.wait = lerpf(DANGER_WAIT.x,DANGER_WAIT.y,d)
		out.far_share = lerpf(DANGER_FAR.x,DANGER_FAR.y,d)
	for key: String in plan_knobs:
		if key.begins_with("spawn_"): out[key.trim_prefix("spawn_")] = float(plan_knobs[key])
	return out

## The body's moves and build (m), from its knobs at the walker's numbers
## (LayerEnemies `numbers`) and the generator's (`knobs`).
static func body(n: Dictionary) -> Dictionary:
	_build_lock.lock()
	if _build.is_empty():
		var probe: Node3D = HeadlessBody.new()
		var k: Dictionary = probe.default_knobs(n)
		probe.free()
		k.merge(knobs(n),true)
		var b := HeadlessBody.build_of(k,float(n.unit))
		b.climb_max = float(k.climb_max)
		b.drop_max = float(k.drop_max)
		b.leap_max = float(k.leap_max)
		b.drop_under = float(k.drop_under)
		b.jump_gap = float(k.jump_gap)*float(b.hh)
		b.jump_rise = float(k.jump_rise)*float(b.hh)
		b.jump_sink = float(k.jump_sink)*float(b.hh)
		_build = b
	var out := _build
	_build_lock.unlock()
	return out

## The cliffs for the head `head` ({isle, at, route}) in `plan`: [[name,
## lip, out, hang]], nearest the head first; [] where none reaches it.
static func cliffs(plan: Dictionary, head: Dictionary, n: Dictionary) -> Array:
	var b := body(n)
	var g := _grid(plan,int(head.isle))
	var reach := _reach(g,head,b)
	if reach.is_empty(): return []
	var bare := plan.duplicate()
	bare.isles = []
	var hang: float = b.hang
	var found: Array = []
	for u: Vector3i in reach:
		for d: Vector2i in DIRS:
			var lip := _lip(g,u,d,b)
			if lip == Vector3.INF: continue
			var flat := Vector2(lip.x-(head.at as Vector3).x,lip.z-(head.at as Vector3).z).length()
			if flat > CLIFF_FAR: continue
			# Clear of the edges, tubes, piers and cannons where it hangs.
			var hung := lip+Vector3(d.x,0.0,d.y)*(float(b.length)*0.5+0.5)-Vector3.UP*hang*0.5
			if not LayerHazards._lumps_clear(bare,[[hung,float(b.width)*0.5,hang*0.5,hang*0.5+float(b.neck)]]): continue
			var isle: Dictionary = plan.isles[u.z]
			found.append([flat+(0.0 if u.z == int(head.isle) else CLIFF_FAR),
				["%d %s %s" % [u.z,str(isle.id).replace("_"," "),_way(d)],lip,Vector2(d.x,d.y),hang]])
	found.sort_custom(func(a: Array, z: Array) -> bool: return float(a[0]) < float(z[0]))
	var out: Array = []
	for f: Array in found:
		var lip: Vector3 = f[1][1]
		var near := false
		for o: Array in out:
			if Vector2(lip.x-(o[1] as Vector3).x,lip.z-(o[1] as Vector3).z).length() < CLIFF_APART: near = true
		if near: continue
		out.append(f[1])
		if out.size() >= CLIFFS_MOST: break
	return out

static func _way(d: Vector2i) -> String:
	return {Vector2i(1,0):"east",Vector2i(-1,0):"west",Vector2i(0,1):"south",Vector2i(0,-1):"north"}[d]

## The columns round isle `i` and those NEAR it, each isle's its own place:
## {tops: {Vector3i (column x, z, isle): Vector3 (x, top, z)}, lo:
## {Vector3i: its lowest solid}, at: {Vector2i (column): [Vector3i]}}.
static func _grid(plan: Dictionary, i: int) -> Dictionary:
	var home := LayerPlan._rect(plan.isles[i]).grow(NEAR)
	var tops := {}
	var lo := {}
	var at := {}
	for k in range((plan.isles as Array).size()):
		var isle: Dictionary = plan.isles[k]
		var r := LayerPlan._rect(isle)
		if not r.intersects(home): continue
		for cx in range(floori(r.position.x/CELL),ceili(r.end.x/CELL)+1):
			for cz in range(floori(r.position.y/CELL),ceili(r.end.y/CELL)+1):
				var x := (cx+0.5)*CELL
				var z := (cz+0.5)*CELL
				var o := LayerPlan.occ_at(isle,x,z)
				if o.x == INF: continue
				var u := Vector3i(cx,cz,k)
				tops[u] = Vector3(x,o.y,z)
				lo[u] = o.x
				var c := Vector2i(cx,cz)
				if not at.has(c): at[c] = []
				(at[c] as Array).append(u)
	return {"tops":tops,"lo":lo,"at":at}

## The places from which the body gets to the head's ground, flooded back
## from it: {Vector3i: true}.
static func _reach(g: Dictionary, head: Dictionary, b: Dictionary) -> Dictionary:
	var tops: Dictionary = g.tops
	var at: Vector3 = head.at
	var reached := {}
	var front: Array = []
	for p: Vector3 in [at]+(head.get("route",[]) as Array):
		var spot := Vector2i(floori(p.x/CELL),floori(p.z/CELL))
		for dx in range(-HEAD_CELLS,HEAD_CELLS+1):
			for dz in range(-HEAD_CELLS,HEAD_CELLS+1):
				for u: Vector3i in g.at.get(spot+Vector2i(dx,dz),[]):
					if reached.has(u) or absf((tops[u] as Vector3).y-at.y) > HEAD_LEVEL or not _stands(g,u,b): continue
					reached[u] = true
					front.append(u)
	var most := int(ceil(float(b.leap_max)/CELL))+1
	while not front.is_empty():
		var v: Vector3i = front.pop_back()
		var vc := Vector2i(v.x,v.y)
		for d: Vector2i in DIRS:
			for k in range(1,most+1):
				for u: Vector3i in g.at.get(vc-d*k,[]):
					if reached.has(u): continue
					if _can(g,u,v,d,k,b,at.y):
						reached[u] = true
						front.append(u)
	return reached

## Whether the body has room to stand on place `u` (no other isle's stone
## lower than its neck over the top).
static func _stands(g: Dictionary, u: Vector3i, b: Dictionary) -> bool:
	var top: float = (g.tops[u] as Vector3).y
	for w: Vector3i in g.at.get(Vector2i(u.x,u.y),[]):
		if w != u and float(g.lo[w]) > top and float(g.lo[w]) < top+float(b.neck): return false
	return true

## Whether the body stood on place `u` gets onto place `v` (`k` columns on
## along `d`) by one move (a drop no lower than `drop_under` under the
## head's ground `head_y`, as the body won't).
static func _can(g: Dictionary, u: Vector3i, v: Vector3i, d: Vector2i, k: int, b: Dictionary, head_y: float) -> bool:
	var tops: Dictionary = g.tops
	var hu: float = (tops[u] as Vector3).y
	var hv: float = (tops[v] as Vector3).y
	var dh := hv-hu
	if not _stands(g,u,b): return false
	if k == 1:
		if absf(dh) <= WALK: return true
		if dh > 0.0: return dh <= float(b.climb_max)
		return -dh <= float(b.drop_max) and hv >= head_y-float(b.drop_under)
	# Across: what lies between is open sky, or deep enough under him that
	# he doesn't come down on it first (or high enough over that he passes
	# under it).
	var jump := (k-1)*CELL <= float(b.jump_gap) and dh <= float(b.jump_rise) and dh >= -float(b.jump_sink)
	var drop := k*CELL <= float(b.leap_max) and dh < -WALK and -dh <= float(b.drop_max) and hv >= head_y-float(b.drop_under)
	if not (jump or drop): return false
	var under := float(b.jump_sink) if jump else float(b.drop_max)
	var over := hu+float(b.neck)+float(b.jump_rise)
	var uc := Vector2i(u.x,u.y)
	for j in range(1,k):
		for w: Vector3i in g.at.get(uc+d*j,[]):
			if (tops[w] as Vector3).y > hu-under and float(g.lo[w]) < over: return false
	return true

## A lip on place `u` facing out along `d`: open sky out past it (and its
## neighbours along the rim) down past the body's hang under its top (or
## stone high enough over to hang under), its isle's stone under it
## FACE_DEPTH of the hang deep, flat ground in behind it on the same isle;
## the lip (on the column's edge, at its top) or INF.
static func _lip(g: Dictionary, u: Vector3i, d: Vector2i, b: Dictionary) -> Vector3:
	var top: Vector3 = g.tops[u]
	var hang: float = b.hang
	if top.y-float(g.lo[u]) < hang*FACE_DEPTH: return Vector3.INF
	var c := Vector2i(u.x,u.y)
	var side := Vector2i(d.y,d.x)
	for w: Vector2i in [c+d,c+d+side,c+d-side,c+d*2]:
		for o: Vector3i in g.at.get(w,[]):
			if (g.tops[o] as Vector3).y > top.y-hang-1.0 and float(g.lo[o]) < top.y+float(b.neck): return Vector3.INF
	# A rim, not a post: flat ground in behind and along it either side.
	for w: Vector3i in [Vector3i(u.x-d.x,u.y-d.y,u.z),Vector3i(u.x+side.x,u.y+side.y,u.z),Vector3i(u.x-side.x,u.y-side.y,u.z)]:
		if not g.tops.has(w) or absf((g.tops[w] as Vector3).y-top.y) > WALK: return Vector3.INF
	return Vector3(top.x+d.x*CELL*0.5,top.y,top.z+d.y*CELL*0.5)
