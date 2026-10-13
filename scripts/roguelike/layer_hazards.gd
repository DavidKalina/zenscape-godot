extends Node3D
## The sprawl layer's hazards (docs/design/roguelike/layer-round6-hazards.md):
## the crossing yard's gust arrows (studies/crossings/gust_arrows.gd, reused
## as they are) on perches at sections of a generated layer, and the Broken
## Viaduct (studies/crossings/crossing_viaduct.gd, as it is, its own arrows,
## routes and updrafts with it) as a link of the exit chain in some layers.
##
## Planned as data (`lay`, from LayerSprawl `core` once the exit chain is
## laid, before the spawn's view, the roost and the next region, so they see
## the viaduct's new gate), built on the stage (`dress`, a child of
## scripts/roguelike/layer_stage.gd, which steps it after the pilot's motor).
##
## The perches, each a horn on a dark column (the yard's `_perch`), not
## reachable (as the yard's deck and low perches: no route out to them):
## - "edge": off to one side of a neighbourhood edge (stones, a bridge, the
##   climb to the upper tier, the voussoirs), firing on a stretch of it
##   (WINDOW m of its path);
## - "chain": the same on a section of the exit chain;
## - "ground": just off an unused rim of an isle, a little over its turf,
##   firing on an open stretch of turf (a clear spot, GROUND_ZONE round)
##   inland of it: a knock throws him inland.
## A placement is "soft" where the knock (away from the perch) lands on a
## lower isle; at most VOID_MOST of a layer's are not. All a layer's
## launchers are one GustArrows, so they take turns (TURN_GAP, the cooldown):
## the timing window. The isles' ruins are the cover.
##
## Knobs (LayerPlan KNOBS): `arrows` (how many; -1 rolled ARROWS, 0 none),
## `viaduct` (-1 rolled VIADUCT_CHANCE, 0 never, 1 forced: a draw that can't
## take it is drawn again).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const Crossing = preload("res://studies/crossings/crossing.gd")
const Viaduct = preload("res://studies/crossings/crossing_viaduct.gd")
const GustArrows = preload("res://studies/crossings/gust_arrows.gd")
const HornStandIn = preload("res://studies/crossings/horn_stand_in.gd")
const HornPerch = preload("res://studies/crossings/horn_perch.gd")
const RuinKitHorn = preload("res://scripts/ruin_kit_horn.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const Slam = preload("res://scripts/slam.gd")
const CrossingYard = preload("res://studies/crossing_yard.gd")

## How many perches a layer rolls, and the most whose knock is over the void.
const ARROWS := Vector2i(3,5)
const VOID_MOST := 1
const VOID_MOST_MANY := 2
## Edge perches: aside of the path (m), over the window's highest point (m),
## the stretch they fire on (m of path), how near it his feet count (m flat,
## and under / over its points).
const ASIDE := Vector2(13.0,17.0)
const UP := Vector2(2.0,4.0)
const WINDOW := 24.0
const ZONE_R := 3.5
const ZONE_UNDER := 2.5
const ZONE_OVER := 5.0
## Stone under an air perch's top (m), the yard's low perches'.
const BLOCK := Viaduct.LOW_BLOCK
## Ground perches: out past the rim's lip (m), over the higher of the rim and
## the turf it covers (m), their column's stone (m); the spot this far from
## the rim (m flat), its turf within this of the rim's height; the zone round
## the spot (m flat, m up or down).
const GROUND_OUT := [5.5,7.5]
const GROUND_UP := 2.5
const GROUND_BLOCK := 3.5
const GROUND_FROM := Vector2(8.0,30.0)
const GROUND_LEVEL := 5.0
const GROUND_ZONE := 8.0
const GROUND_DY := 3.0
const SPOT_ROOM := 2.0
## A soft knock: a lower isle within these (m out from the path, away from
## the perch; m under the path).
const SOFT_OUT := [0.0,3.0,6.0,9.0,12.0,15.0]
const SOFT_UNDER := Vector2(1.0,45.0)
## Perches keep this far apart (m) and this clear of an edge's path (m flat,
## unless this far over or under it), a ride's tube, a pier or a cannon.
const APART := 30.0
const PATH_CLEAR := 5.0
const PATH_DY := 8.0
const TUBE_CLEAR := 6.0
const PIER_CLEAR := 16.0
const CANNON_CLEAR := 6.0
## The horn over a perch's top (m), for clearance and sight.
const HORN_TALL := 3.0

## The viaduct: how often a layer rolls it; the hop from the threshold to its
## start rim (m, a running hop's, the routes' STEP_GAP); the turns tried off
## the chain's way (degrees) for its chord.
const VIADUCT_CHANCE := 0.45
const HOP := Viaduct.STEP_GAP
const VIADUCT_YAWS := [0.0,12.0,-12.0,24.0,-24.0,36.0,-36.0]

# --- Planning -----------------------------------------------------------------------

## The viaduct's numbers laid out once (its own frame): {entry, exit, chord,
## lumps ([middle, radius, under, over]), updrafts}.
static var _via := {}
static var _via_lock := Mutex.new()

## The hazards laid into `plan` (`plan.viaduct`, `plan.arrows`): false only
## where the viaduct is forced and won't fit (the draw is laid again).
static func lay(plan: Dictionary, attempt: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.seed),attempt,"hazards"])
	var knobs: Dictionary = plan.knobs
	var want_v := int(knobs.get("viaduct",-1))
	var roll := rng.randf()
	plan.viaduct = {}
	if want_v > 0 or (want_v < 0 and roll < VIADUCT_CHANCE):
		if not _viaduct(plan,rng) and want_v > 0: return false
	_arrows(plan,rng)
	return true

static func viaduct_numbers() -> Dictionary:
	_via_lock.lock()
	if _via.is_empty():
		var v: Node3D = Viaduct.new()
		v.lay_out()
		_via = _numbers(v)
		v.free()
	var out := _via
	_via_lock.unlock()
	return out

static func _numbers(v: Node3D) -> Dictionary:
	var lumps: Array = []
	var low := -float(Viaduct.ROOTS)
	# [middle, radius, under (down to the stone's foot), over]
	var add := func(p: Vector3, r: float, over: float, bottom: float) -> void: lumps.append([p,r,p.y-bottom,over])
	var line := func(a: Vector3, b: Vector3, r: float) -> void:
		var n := maxi(int(ceil(a.distance_to(b)/3.0)),1)
		for i in range(n+1):
			var p := a.lerp(b,float(i)/n)
			lumps.append([p,r,p.y-low,4.0])
	add.call(Vector3(0.0,0.0,Viaduct.RIM.y*0.5),8.5,4.0,low)
	line.call(Vector3.ZERO,v.lip,4.5)
	line.call(v.far_start,v.turn_mid,4.5)
	add.call(v.turn_mid,7.0,4.0,low)
	for top: Vector3 in v.pier_tops:
		add.call(Crossing.at(top,Viaduct.TURN_B,0.0,Viaduct.SAFE_ASIDE*0.5),5.5,4.0,low)
	add.call(v.slot_foot,Viaduct.SLOT_PLINTH+1.0,Viaduct.SLOT_HEIGHT+4.0,low)
	var c_deg := Viaduct.TURN_B+90.0
	line.call(v.slab_top,v.lip_end,2.5)
	line.call(v.far_near,Crossing.at(v.far_near,c_deg,Viaduct.FAR_RIM.x),Viaduct.FAR_RIM.y*0.5+2.0)
	for key: String in v.routes:
		var r: Dictionary = v.routes[key]
		for st: Dictionary in r.stones: add.call(st.at,2.5,3.0,(st.at as Vector3).y-2.0)
		add.call(r.top,2.5,HORN_TALL,low)
	add.call(v.deck_archer_at()-Vector3.UP*Viaduct.ARCHER_CLEAR,2.5,HORN_TALL,low)
	for i in range(Viaduct.LOW_PERCHES.size()):
		var t: Vector3 = v.low_perch_at(i)
		add.call(t,2.5,HORN_TALL,t.y-Viaduct.LOW_BLOCK)
	var e: Dictionary = v.entry()
	var x: Dictionary = v.exit()
	var chord: Vector3 = (x.at as Vector3)-(e.at as Vector3)
	return {"entry":e,"exit":x,"chord":Vector3(chord.x,0.0,chord.z),"lumps":lumps,"updrafts":v.updrafts(),"rise":chord.y}

## The viaduct past the exit chain's threshold: its start rim a hop on, its
## chord along the chain's way (a turn or two tried), clear of the layer;
## its far rim holds the gate now. False where it won't fit.
static func _viaduct(plan: Dictionary, rng: RandomNumberGenerator) -> bool:
	var chain: Array = plan.get("chain",[])
	if chain.is_empty(): return false
	var last: Dictionary = plan.edges[chain[chain.size()-1]]
	var threshold := {}
	for st: Dictionary in last.stones:
		if str(st.name).ends_with("_threshold"): threshold = st
	if threshold.is_empty(): return false
	var d: Vector3 = last.dir
	d = Vector3(d.x,0.0,d.z).normalized()
	var side: float = (threshold.size as Vector3).x
	var edge_at: Vector3 = (threshold.at as Vector3)+d*side*0.5
	var nums := viaduct_numbers()
	var chord: Vector3 = nums.chord
	var yaws := VIADUCT_YAWS.duplicate()
	if rng.randf() < 0.5: yaws.reverse()
	for jitter: float in yaws:
		var want := d.rotated(Vector3.UP,deg_to_rad(jitter))
		var theta := atan2(want.x,want.z)-atan2(chord.x,chord.z)
		var b := Basis(Vector3.UP,theta)
		var ax := b*Vector3.RIGHT
		var az := b*Vector3.BACK
		var half := Viaduct.RIM.x*0.5/maxf(maxf(absf(d.dot(ax)),absf(d.dot(az))),0.5)
		var pad := edge_at+d*(HOP+half)
		var origin := pad-b*Vector3(0.0,0.0,Viaduct.RIM.y*0.5)
		var xf := Transform3D(b,origin)
		var path: Array = []
		for l: Array in nums.lumps: path.append([xf*(l[0] as Vector3),l[1],l[2],l[3]])
		if not _lumps_clear(plan,path,chain[chain.size()-1]): continue
		var x: Dictionary = nums.exit
		var gate := xf*(x.at as Vector3)
		var f2: Vector2 = x.face
		var face := (b*Vector3(f2.x,0.0,f2.y)).normalized()
		var flat_path: Array = []
		for l: Array in path: flat_path.append([l[0],float(l[2]),float(l[3])])
		var edge := {"kind":"viaduct","branch":"exit","from":[-1,"threshold"],"to":[-1,"gate"],"a":edge_at,"b":gate,"dir":d,
			"stones":[],"bridges":[],"parts":["the Broken Viaduct"],"trap":{},"path":flat_path,"cannon":{},
			"from_rim":{"kind":"rim","name":"threshold","at":edge_at,"face":d,"run_up":side,"lip":0.0,"room":0.0},
			"to_rim":{"kind":"rim","name":"gate","at":gate,"face":-face,"run_up":4.0,"lip":0.0,"room":0.0}}
		plan.chain.append((plan.edges as Array).size())
		plan.edges.append(edge)
		plan.exit = {"isle":-1,"rim":"gate","at":gate,"face":face,"from":plan.exit.get("from",[])}
		plan.viaduct = {"xform":xf,"edge":(plan.edges as Array).size()-1,"turn":jitter,"rise":float(nums.rise)}
		return true
	return false

## Whether lumps ([middle, radius, under, over], world) stand clear of every
## isle, every edge's path but `skip`'s, the rides' tubes, the gulfs' piers
## and the cannons.
static func _lumps_clear(plan: Dictionary, lumps: Array, skip := -1) -> bool:
	for l: Array in lumps:
		var p: Vector3 = l[0]
		var r: float = l[1]
		var lo := p.y-float(l[2])
		var hi := p.y+float(l[3])
		for isle: Dictionary in plan.isles:
			if not LayerPlan._rect(isle).grow(r+2.0).has_point(Vector2(p.x,p.z)): continue
			var k := -r
			while k <= r:
				var j := -r
				while j <= r:
					if k*k+j*j <= r*r+1.0:
						var o := LayerPlan.occ_at(isle,p.x+k,p.z+j)
						if o.x < INF and o.x < hi+LayerPlan.CLEAR*0.5 and lo-LayerPlan.CLEAR*0.5 < o.y: return false
					j += 2.0
				k += 2.0
		for i in range((plan.edges as Array).size()):
			if i == skip: continue
			for s: Array in plan.edges[i].path:
				var q: Vector3 = s[0]
				if absf(q.x-p.x) > r+PATH_CLEAR or absf(q.z-p.z) > r+PATH_CLEAR: continue
				if Vector2(q.x-p.x,q.z-p.z).length() < r+PATH_CLEAR*0.5 and q.y-float(s[1]) < hi+2.0 and q.y+float(s[2]) > lo-2.0: return false
		for t: Array in plan.tubes:
			var tp: Vector3 = t[0]
			if tp.distance_to(Vector3(p.x,clampf(tp.y,lo,hi),p.z)) < float(t[1])+r+TUBE_CLEAR*0.5: return false
		for kp: Array in _keep(plan):
			var c: Vector3 = kp[0]
			if Vector2(c.x-p.x,c.z-p.z).length() < float(kp[1])+r and c.y > lo-8.0 and c.y < hi+8.0: return false
	return true

## The gulfs' piers and the cannons and kegs: [point, clear].
static func _keep(plan: Dictionary) -> Array:
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
	return keep

## The perches: candidates of each kind (edge, chain, ground), then picked
## round the kinds, soft first, at most VOID_MOST over the void, APART.
static func _arrows(plan: Dictionary, rng: RandomNumberGenerator) -> void:
	plan.arrows = []
	var n := int(plan.knobs.get("arrows",-1))
	if n < 0: n = rng.randi_range(ARROWS.x,ARROWS.y)
	if n == 0: return
	var by := {"edge":[],"chain":[],"ground":[]}
	for i in range((plan.edges as Array).size()):
		var e: Dictionary = plan.edges[i]
		if not ["stones","bridge","climb","trap","hard"].has(str(e.kind)): continue
		var kind := "chain" if e.branch == "exit" else "edge"
		var along: Array = [0.3,0.6,0.85] if e.kind == "climb" else [0.35,0.65]
		for t: float in along:
			for s: float in ([1.0,-1.0] if rng.randf() < 0.5 else [-1.0,1.0]):
				var c := _edge_perch(plan,i,t,s,rng)
				if not c.is_empty(): (by[kind] as Array).append(c)
	by.ground = _ground_perches(plan,rng)
	for k: String in by:
		var list: Array = by[k]
		LayerPlan._shuffle(list,rng)
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return bool(a.soft) and not bool(b.soft))
	var order: Array = ["ground","chain","edge","edge","ground","chain","edge"]
	var void_most := VOID_MOST_MANY if n >= 5 else VOID_MOST
	var voids := 0
	var used_edges := {}
	var k := 0
	var misses := 0
	while (plan.arrows as Array).size() < n and misses < order.size():
		var want: String = order[k%order.size()]
		k += 1
		var took := false
		for c: Dictionary in by[want]:
			if not bool(c.soft) and voids >= void_most: continue
			if c.has("edge") and used_edges.has(int(c.edge)): continue
			var near := false
			for p: Dictionary in plan.arrows:
				if (p.top as Vector3).distance_to(c.top) < APART or (p.mid as Vector3).distance_to(c.mid) < APART: near = true
			if near: continue
			plan.arrows.append(c)
			if c.has("edge"): used_edges[int(c.edge)] = true
			if not bool(c.soft): voids += 1
			(by[want] as Array).erase(c)
			took = true
			break
		misses = 0 if took else misses+1

## A perch off edge `i` at `t` of its path, on side `s` (+1 its right):
## {kind, top, mid (the window's middle), zone ({points}), soft, edge}, or {}.
static func _edge_perch(plan: Dictionary, i: int, t: float, s: float, rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = plan.edges[i]
	var path: Array = e.path
	if path.size() < 4: return {}
	var lengths := PackedFloat32Array([0.0])
	for j in range(1,path.size()): lengths.append(lengths[j-1]+(path[j][0] as Vector3).distance_to(path[j-1][0]))
	var total := lengths[lengths.size()-1]
	var centre := total*t
	var points := PackedVector3Array()
	var last := -INF
	var hi := -INF
	var j0 := -1
	var j1 := -1
	for j in range(path.size()):
		if absf(lengths[j]-centre) > WINDOW*0.5: continue
		if j0 < 0: j0 = j
		j1 = j
		var p: Vector3 = path[j][0]
		hi = maxf(hi,p.y)
		if lengths[j]-last >= 2.0:
			points.append(p)
			last = lengths[j]
	if points.size() < 3: return {}
	var a: Vector3 = path[j0][0]
	var b: Vector3 = path[j1][0]
	var way := Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
	if way == Vector3.ZERO: return {}
	var right := way.cross(Vector3.UP).normalized()
	var mid := a.lerp(b,0.5)
	var top := Vector3(mid.x,hi,mid.z)+right*s*rng.randf_range(ASIDE.x,ASIDE.y)+Vector3.UP*rng.randf_range(UP.x,UP.y)
	if not _perch_clear(plan,top,BLOCK): return {}
	if not _sees(plan,top,mid): return {}
	return {"kind":"chain" if e.branch == "exit" else ("climb" if e.kind == "climb" else "edge"),"top":top,"mid":mid,"zone":{"points":points},
		"soft":_soft(plan,points,-right*s),"edge":i,"block":BLOCK,"on":str(e.kind)}

## Ground perches: per isle with a clear spot, an unused rim near it a
## little over the spot's turf; the perch out past its lip.
static func _ground_perches(plan: Dictionary, rng: RandomNumberGenerator) -> Array:
	var used := {}
	for e: Dictionary in plan.edges:
		used[LayerPlan._key(int(e.from[0]),str(e.from[1]))] = true
		used[LayerPlan._key(int(e.to[0]),str(e.to[1]))] = true
	var out: Array = []
	for i in range((plan.isles as Array).size()):
		var isle: Dictionary = plan.isles[i]
		var spots: Array = (isle.sockets as Array).filter(func(x: Dictionary) -> bool: return (x.kind == "perch" or x.kind == "arena") and float(x.room) >= SPOT_ROOM)
		var rims: Array = (isle.sockets as Array).filter(func(x: Dictionary) -> bool: return x.kind == "rim" and not used.has(LayerPlan._key(i,x.name)))
		LayerPlan._shuffle(spots,rng)
		var found := false
		for spot: Dictionary in spots:
			var at: Vector3 = spot.at
			if not (plan.ram as Dictionary).is_empty() and (plan.ram.at as Vector3).distance_to(at) < LayerPlan.RAM_CLEAR+GROUND_ZONE: continue
			if not (plan.prize as Dictionary).is_empty() and (plan.prize.at as Vector3).distance_to(at) < GROUND_ZONE: continue
			for rim: Dictionary in rims:
				var r_at: Vector3 = rim.at
				var flat := Vector2(r_at.x-at.x,r_at.z-at.z).length()
				if flat < GROUND_FROM.x or flat > GROUND_FROM.y or absf(r_at.y-at.y) > GROUND_LEVEL: continue
				var face: Vector3 = rim.face
				# The rim faces away from the spot: the perch out there fires
				# back in over the turf.
				if Vector2(face.x,face.z).dot(Vector2(r_at.x-at.x,r_at.z-at.z)) <= 0.0: continue
				for go: float in GROUND_OUT:
					var top := r_at+face*(float(rim.lip)+go)
					top.y = maxf(r_at.y,at.y)+GROUND_UP
					if not _perch_clear(plan,top,GROUND_BLOCK): continue
					if not _sees(plan,top,at): continue
					var zone := PackedVector3Array([at])
					out.append({"kind":"ground","top":top,"mid":at,"zone":{"disc":at,"r":GROUND_ZONE,"dy":GROUND_DY,"points":zone},"soft":true,"isle":i,
						"block":GROUND_BLOCK,"on":"%s (%s)" % [isle.id,spot.name]})
					found = true
					break
				if found: break
			if found: break
	return out

## Whether a perch's column (`block` m of stone under `top`) and its horn
## stand clear of the isles, the edges' paths, the tubes, piers, cannons.
static func _perch_clear(plan: Dictionary, top: Vector3, block: float) -> bool:
	var r := Viaduct.PERCH_TOP*0.5+1.0
	return _lumps_clear(plan,[[top,r,block,HORN_TALL]])

## Whether the horn's mouth on `top` sees his middle at `at`.
static func _sees(plan: Dictionary, top: Vector3, at: Vector3) -> bool:
	return load("res://scripts/roguelike/layer_sprawl.gd").sight_clear(plan,top+Vector3.UP*HornStandIn.MOUTH_UP,at+Vector3.UP*1.0,false)

## Whether a knock from `points` along `away` (flat) comes down on a lower
## isle (or the path's own isle under it).
static func _soft(plan: Dictionary, points: PackedVector3Array, away: Vector3) -> bool:
	var hits := 0
	for p: Vector3 in points:
		var caught := false
		for out: float in SOFT_OUT:
			var q := p+away*out
			for isle: Dictionary in plan.isles:
				var o := LayerPlan.occ_at(isle,q.x,q.z)
				if o.x < INF and o.y < p.y-SOFT_UNDER.x and o.y > p.y-SOFT_UNDER.y:
					caught = true
					break
			if caught: break
		if caught: hits += 1
	return hits*2 >= points.size()

## A line for the card.
static func card(plan: Dictionary) -> String:
	var parts := PackedStringArray()
	var arrows: Array = plan.get("arrows",[])
	if not arrows.is_empty():
		var kinds := {}
		var voids := 0
		for a: Dictionary in arrows:
			kinds[a.kind] = int(kinds.get(a.kind,0))+1
			if not bool(a.soft): voids += 1
		var words := PackedStringArray()
		for k: String in kinds: words.append("%d %s" % [kinds[k],k])
		parts.append("Gust arrows: %s (%d over the void)" % [", ".join(words),voids])
	if not (plan.get("viaduct",{}) as Dictionary).is_empty(): parts.append("The Broken Viaduct past the threshold (%.0f m up)" % float(plan.viaduct.rise))
	return "  ·  ".join(parts)

# --- On the stage -------------------------------------------------------------------

var study: Node3D
var arrows: GustArrows
var viaduct: Node3D
var stones: Node3D
var currents: Node3D
var _air_was: Callable
var _beds: Array = []

## Built on `stage` from its plan, or null (nothing to build).
static func dress(stage: Node3D, plan: Dictionary) -> Node3D:
	if (plan.get("arrows",[]) as Array).is_empty() and (plan.get("viaduct",{}) as Dictionary).is_empty(): return null
	var node := new()
	node.name = "Hazards"
	stage.add_child(node)
	node.build(stage.study,plan)
	return node

func build(scene: Node3D, plan: Dictionary) -> void:
	study = scene
	var paint := Callable(scene,"_material")
	var kit: Node3D = Crossing.new()
	kit.name = "Perches"
	add_child(kit)
	kit.build(paint)
	var list: Array = plan.get("arrows",[])
	if not list.is_empty():
		arrows = GustArrows.new()
		add_child(arrows)
		for i in range(list.size()):
			var a: Dictionary = list[i]
			var top: Vector3 = a.top
			var mid: Vector3 = a.mid
			var toward := rad_to_deg(atan2(mid.x-top.x,-(mid.z-top.z)))
			var deg := toward+180.0
			# The viaduct's own perch (crossing_viaduct.gd `_perch`): a ruin-kit
			# pillar under the stone wind horn.
			var bottom := top.y-float(a.block)
			var pillar: Node3D = kit.piece(Aqueduct.pillar(Viaduct.SEED+40+i,Viaduct.WEATHERED,top.y-bottom,Vector2(Viaduct.PERCH_TOP,Viaduct.PERCH_TOP)),Transform3D(Basis(Vector3.UP,Crossing.yaw_of(deg)),Vector3(top.x,bottom,top.z)))
			pillar.name = "Perch%d_%s" % [i,a.kind]
			var horn := HornPerch.new()
			horn.setup(Viaduct.SEED+60+i,Viaduct.WEATHERED)
			horn.rotation.y = Crossing.yaw_of(deg+180.0)
			var l := arrows.add_launcher(top,_zone(a.zone),horn,Viaduct.PERCH_TOP*0.5,{})
			l.cap_rise = RuinKitHorn.TOP_HEIGHT
			l.name = "Perch%d_%sLauncher" % [i,a.kind]
	var v: Dictionary = plan.get("viaduct",{})
	if not v.is_empty(): _build_viaduct(v,paint)

## A zone's test on his feet (world).
static func _zone(z: Dictionary) -> Callable:
	if z.has("disc"):
		var at: Vector3 = z.disc
		var r: float = z.r
		var dy: float = z.dy
		return func(f: Vector3) -> bool: return absf(f.y-at.y) < dy and Vector2(f.x-at.x,f.z-at.z).length() < r
	var points: PackedVector3Array = z.points
	return func(f: Vector3) -> bool:
		for p: Vector3 in points:
			if f.y > p.y-ZONE_UNDER and f.y < p.y+ZONE_OVER and Vector2(f.x-p.x,f.z-p.z).length() < ZONE_R: return true
		return false

## The viaduct as the yard builds it, at its place: its stones (foot pieces,
## stepped here), its updrafts on the sail's air.
func _build_viaduct(v: Dictionary, paint: Callable) -> void:
	viaduct = Viaduct.new()
	viaduct.name = "BrokenViaduct"
	viaduct.lay_out()
	viaduct.transform = v.xform
	add_child(viaduct)
	viaduct.build(paint)
	var xf: Transform3D = v.xform
	stones = FootPieces.new()
	stones.name = "ViaductStones"
	stones.study = study
	stones.motor = study.motor
	add_child(stones)
	var k := 0
	var turn := xf.basis.get_euler().y
	for st: Dictionary in viaduct.foot_stones():
		var p := xf*(st.at as Vector3)
		if st.kind == "sink": stones.sink_slab(p,st.size,float(st.yaw)+turn,900+k)
		else: stones.bob_slab(p,st.size,float(st.yaw)+turn,900+k)
		k += 1
	var rids: Array[RID] = []
	for slab: Node3D in stones.slabs: rids.append(slab.rid())
	viaduct.stones_made(rids)
	currents = SkyCurrents.new()
	currents.name = "ViaductUpdrafts"
	add_child(currents)
	for d: Dictionary in viaduct.updrafts():
		currents.add_thermal(xf*(d.base as Vector3),"crossing",xf.origin.y+float(d.top),float(d.radius))
	var look: ShaderMaterial = currents.wisp_material()
	look.set_shader_parameter("opacity",CrossingYard.UPDRAFT_OPACITY)
	look.set_shader_parameter("width_scale",CrossingYard.UPDRAFT_WIDTH)
	look.set_shader_parameter("glow",CrossingYard.UPDRAFT_GLOW)
	var motor: Object = study.motor
	_air_was = motor.air
	var was := _air_was
	var air := currents
	motor.air = func(p: Vector3) -> Dictionary:
		var here: Dictionary = was.call(p) if was.is_valid() else {}
		if not is_instance_valid(air): return here
		var lift: Dictionary = air.air_at(p)
		return {"wind":(here.get("wind",Vector3.ZERO) as Vector3)+(lift.wind as Vector3),"thermal":maxf(float(here.get("thermal",0.0)),float(lift.thermal))}

func _exit_tree() -> void:
	if viaduct != null and study != null and _air_was.is_valid(): study.motor.air = _air_was

func set_on(value: bool) -> void:
	if arrows != null: arrows.set_on(value)
	if viaduct != null: viaduct.set_hazards(value)

# --- The slot (LayerStage forwards) -------------------------------------------------

func before(delta: float) -> void:
	if stones != null: stones.before(delta)

## After the pilot's motor: the viaduct's stones, then every launcher's turn
## and hit, and their sound.
func after(delta: float, events: Dictionary) -> void:
	if stones != null: stones.after(delta,events)
	var space := get_world_3d().direct_space_state
	var motor: Object = study.motor
	var words: Array = []
	if arrows != null: words.append(arrows.step(delta,motor,space))
	if viaduct != null: words.append(viaduct.step_hazards(delta,motor,space))
	if words.has("silenced") and study.has_method("_show_toast"): study._show_toast("Slammed the horn: silenced for %.0f s" % GustArrows.DISABLE_TIME)
	var audio: Variant = study.get("audio")
	if audio == null or audio.beasts == null: return
	var voices: Array = []
	if arrows != null: voices.append_array(arrows.voices())
	if viaduct != null: voices.append_array(viaduct.hazard_voices())
	while _beds.size() < voices.size(): _beds.append({})
	for i in range(voices.size()): audio.beasts._air_blast(voices[i],_beds[i])
