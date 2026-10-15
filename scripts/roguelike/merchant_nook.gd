extends RefCounted
## [merchant] The stall's nook (docs/design/roguelike/run-trim-round1.md):
## the merchant off the beaten path. On a layer with a stall, the plan lays a
## short side spur off a free rim of a place on the way up (one on the
## main line first, else a side place, else a free face of the landing;
## never the greed isle, and clear of the exit chain's rim): one crossing of the layer's own kinds,
## sized from the motor as every edge is, out to a broad slab where the
## stall stands. You see it from the place's rim and platform out to it: a
## bit of jumping, never the greed branch's hard line (no hard piers, the
## gentlest meanness, the step drums kept on the piers).
##
##   city      the staggered piers (step drums aside, the slow safe line),
##             else a run of column tops (the broken causeway's slumped
##             climb and gone spans are left to the route)
##   sky       a run of floating stones
##
## Data only: `lay` adds one edge of branch "nook" to `plan.edges` (built
## with the rest: its stones and the slab are the edge's, so the city's
## crossings and the sky's floating stones draw it) and `plan.nook` = {at
## (the slab's top middle), face (back toward the rim, flat), side, edge,
## isle}. Merchant `lay` stands the stall there. A layer where no spur
## stands clear keeps round 1's spot (a cover or perch of a route isle).
## `--merchant=start` still sets it beside the spawn.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const CityWays = preload("res://scripts/roguelike/city_ways.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")

## The slab: its side as a share of LayerPlan `landing_size` (his running
## half second), at least SLAB_LEAST m (the stall is 5.2 x 4.8 m and wants
## room to walk round its front).
const SLAB := 2.6
const SLAB_LEAST := 8.5
## The kinds tried, in order, per world.
const CITY_KINDS := ["piers","stones"]
const SKY_KINDS := ["stones"]
## Its rim: at least this run-up (m: the piers' and stones' want), tried at
## most RIMS of them, TRIES a rim (each a little turned off its facing,
## degrees at most TURN).
const RUN_UP := 1.5
const RIMS := 12
const TRIES := 3
const TURN := 20.0
## How mean the spur is: this share of the layer's (LayerPlan `mean`).
const MEAN_SHARE := 0.4
## Clear of a gulf's piers, of a cannon or keg, of a ride's tube (m).
const PIER_CLEAR := 16.0
const CANNON_CLEAR := 4.0
const TUBE_CLEAR := 6.0
## Kept this far (m, flat) off the exit chain's rim and the gate.
const EXIT_CLEAR := 24.0

## Whether `layer` has a stall (data only): odd regions (seed parity with no
## region), `--merchant=always|start` every layer, `--no-merchant` none.
static func wanted(layer: Dictionary) -> bool:
	if not RunFeatures.on(&"merchant"): return false
	var mode := RunFeatures.value("merchant")
	if mode == "always" or mode == "start": return true
	var region := LayerWorlds.region_of(layer)
	return region % 2 == 1 if region > 0 else int(layer.get("seed",0)) % 2 == 1

## The nook laid into `plan` (an edge and `plan.nook`): true when one stood.
static func lay(plan: Dictionary, rng: RandomNumberGenerator) -> bool:
	plan.nook = {}
	if not wanted(plan) or RunFeatures.value("merchant") == "start": return false
	var city := LayerWorlds.city(plan.knobs)
	var kinds: Array = CITY_KINDS if city and CityWays.on(plan.knobs) else SKY_KINDS
	var used := {}
	for e: Dictionary in plan.edges:
		used[LayerPlan._key(int(e.from[0]),str(e.from[1]))] = true
		used[LayerPlan._key(int(e.to[0]),str(e.to[1]))] = true
	var avoid: Array = []
	if not (plan.exit as Dictionary).is_empty(): avoid.append(plan.exit.at)
	for i: int in plan.get("chain",[]): avoid.append(plan.edges[i].a)
	# The rims: free, with run-up, of the places on the main line first (the
	# way he walks), then the route's side places, then the landing's (seen
	# from the start); never the greed isle's.
	var line := main_isles(plan)
	var first: Array = []
	var then: Array = []
	var last: Array = []
	for i in range((plan.isles as Array).size()):
		var isle: Dictionary = plan.isles[i]
		var role := str(isle.get("role",""))
		if role != "route" and role != "base": continue
		for s: Dictionary in isle.sockets:
			if s.kind != "rim" or used.has(LayerPlan._key(i,s.name)) or float(s.run_up) < RUN_UP or not LayerPlan.can_out(s,plan.knobs): continue
			var far := true
			for p: Vector3 in avoid:
				if Vector2((s.at as Vector3).x-p.x,(s.at as Vector3).z-p.z).length() < EXIT_CLEAR: far = false
			if not (plan.ram as Dictionary).is_empty() and int(plan.ram.isle) == i and (plan.ram.at as Vector3).distance_to(s.at) < LayerPlan.RAM_CLEAR: far = false
			if far: (last if role == "base" else (first if line.has(i) else then)).append([i,s])
	LayerPlan._shuffle(first,rng)
	LayerPlan._shuffle(then,rng)
	LayerPlan._shuffle(last,rng)
	var rims: Array = first+then+last
	var meanness := LayerPlan.mean(plan.knobs)*MEAN_SHARE
	var side := maxf(LayerPlan.landing_size()*SLAB,SLAB_LEAST)
	for r: Array in rims.slice(0,RIMS+(last.size() if first.size()+then.size() >= RIMS else 0)):
		var i: int = r[0]
		var rim: Dictionary = r[1]
		for t in range(TRIES):
			var face: Vector3 = rim.face
			var d := Vector3(face.x,0.0,face.z).normalized().rotated(Vector3.UP,deg_to_rad(rng.randf_range(-TURN,TURN)*float(t > 0)))
			var a: Vector3 = (rim.at as Vector3)+face*float(rim.lip)
			for kind: String in kinds:
				var edge := _edge(plan,i,rim,a,d,kind,side,meanness,rng)
				if edge.is_empty() or not _clear(plan,edge,i): continue
				plan.nook = {"at":edge.slab_at,"face":-d,"side":side,"edge":(plan.edges as Array).size(),"isle":i,"rim":str(rim.name),"kind":kind,"main":line.has(i),"base":i == 0}
				edge.erase("slab_at")
				plan.edges.append(edge)
				return true
	return false

## The isles of the main line (the base's way to the exit chain's rim, as
## way_lights.gd `main_line` walks it), but the base: {index: true}.
static func main_isles(plan: Dictionary) -> Dictionary:
	var out := {}
	var edges: Array = plan.edges
	var chain: Array = plan.get("chain",[])
	var target := int(edges[chain[0]].from[0]) if not chain.is_empty() else int((plan.exit as Dictionary).get("isle",-1))
	var guard := 0
	while target > 0 and guard < 64:
		guard += 1
		out[target] = true
		var found := -1
		for e: Dictionary in edges:
			if str(e.branch) == "route" and int(e.to[0]) == target:
				found = int(e.from[0])
				break
		target = found
	return out

## The spur of `kind` off lip `a` along `d`, its slab at the end: the edge
## (with `slab_at`), or {}.
static func _edge(plan: Dictionary, i: int, rim: Dictionary, a: Vector3, d: Vector3, kind: String, side: float, meanness: float, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary
	var chain := "nook_%d_%d" % [roundi(a.x),roundi(a.z)]
	if kind == "stones":
		out = {"stones":[],"bridges":[],"trap":{},"parts":[],"path":[],"mean":meanness}
		out.b = LayerPlan._lay_stones(out,a,d,rng.randi_range(3,5),false,rng,chain)
	else:
		out = CityWays.shape(kind,a,d,rng,meanness)
		if out.is_empty(): return {}
	var q: Vector3 = out.b
	# The slab: its near edge's middle the spur's far lip.
	var top := q+d*side*0.5
	(out.stones as Array).append({"name":"%s_nook" % chain,"at":top,"size":Vector3(side,1.0,side),"yaw":atan2(-d.z,d.x),
		"kind":"block","chain":chain,"landing":true,"nook":true})
	(out.parts as Array).append("nook %.1f m" % side)
	(out.path as Array).append_array(LayerPlan._line(q,q+d*side,LayerPlan.UNDER))
	var e := {"kind":kind,"branch":"nook","from":[i,str(rim.name)],"to":[-1,"nook"],"a":a,"b":q,"dir":d,
		"stones":out.stones,"bridges":out.bridges,"parts":out.parts,"trap":{},"path":out.path,"cannon":{},"mean":meanness,
		"from_rim":rim,"to_rim":{"kind":"rim","name":"nook","at":q,"face":-d,"run_up":side*0.5,"lip":0.0,"room":side*0.5},"slab_at":top}
	for k: String in ["spans","chute","flank"]:
		if out.has(k): e[k] = out[k]
	return e

## Whether the spur stands clear: of every isle (its own rim's near its lip),
## of every edge, of the rides' tubes, the gulfs' piers and the cannons.
static func _clear(plan: Dictionary, edge: Dictionary, from: int) -> bool:
	if not LayerPlan._corridor_clear(edge,plan.isles,from,-1): return false
	if LayerPlan._crosses(edge,plan.edges): return false
	var walked: Array = edge.path+edge.get("flank",[])
	for t: Array in plan.tubes:
		var tp: Vector3 = t[0]
		for s: Array in walked:
			if (s[0] as Vector3).distance_to(tp) < float(t[1])+TUBE_CLEAR: return false
	var keep: Array = []
	for gi: int in plan.gulfs:
		var g: Dictionary = plan.edges[gi]
		keep.append([g.from_rim.at,PIER_CLEAR])
		keep.append([g.to_rim.at,PIER_CLEAR])
	for e: Dictionary in plan.edges:
		var c: Dictionary = e.get("cannon",{})
		if c.is_empty(): continue
		keep.append([c.at,CANNON_CLEAR])
		for kat: Vector3 in c.kegs: keep.append([kat,CANNON_CLEAR])
	if not (plan.cannon as Dictionary).is_empty():
		keep.append([plan.cannon.at,CANNON_CLEAR])
		for kat: Vector3 in plan.cannon.kegs: keep.append([kat,CANNON_CLEAR])
	for kp: Array in keep:
		for s: Array in walked:
			var p: Vector3 = s[0]
			if Vector2(p.x-(kp[0] as Vector3).x,p.z-(kp[0] as Vector3).z).length() < float(kp[1]) and absf(p.y-(kp[0] as Vector3).y) < 8.0: return false
	return true
