extends RefCounted
## The lake motif's features (scripts/cluster_motifs.gd "lake"), laid by
## the cluster solver (scripts/cluster_solver.gd `_feature`) on a member
## whose islet has a lake (scripts/islet_lake.gd), after the members are
## placed and their bridges laid:
##   spill: the lake pours off the rim where the sky beyond is most open
##     (clear of every other member, of the bridges' heads, leaning out of
##     the cluster), the channel cut there (IsletLake `spill`);
##   jetty: a plank jetty (the dock's, so the dock's lantern and the
##     fisher on its end come with it) from the bank out over the shallows
##     to deep water, open water beyond its end, and a lantern post at its
##     head;
##   boat: a rowing boat moored alongside the jetty's end, afloat;
##   floats: lilies in patches on the shallows, and lanterns floating out
##     on the open water, lit at night.
## `validate` checks what the solver's own validator can't: the lake spills,
## the boat and lanterns float, the jetty ends over water, and the lake is
## most of its islet.

const IsletLake = preload("res://scripts/islet_lake.gd")

## The spill keeps this clear of every other member (m) along its way, and
## its lip this far from a bridge's head.
const SPILL_CLEAR := 6.0
const SPILL_BRIDGE := 4.0
## The jetty: its length (m), its width (the dock's), its head this far in
## from the water at least and at most (m), the depth its end wants (m),
## the open water beyond it (m), and the deck's height over the water (m).
const JETTY := Vector2(4.0,6.5)
const JETTY_WIDTH := 1.5
const JETTY_HEAD := Vector2(0.7,1.8)
const JETTY_DEPTH := 0.45
const JETTY_OPEN := 2.5
const JETTY_OVER := 0.28
## The boat: half its length and beam (m), the least water under it (m).
const BOAT := Vector2(1.45,0.6)
const BOAT_DEPTH := 0.18
## Lanterns afloat (count), the water they want under them (m) and how far
## apart (m); lily patches (count), pads a patch, their spread (m).
const LANTERNS := Vector2i(4,7)
const LANTERN_DEPTH := 0.35
const LANTERN_APART := 2.4
const LILY_PATCHES := Vector2i(2,4)
const LILIES := Vector2i(4,10)
const LILY_SPREAD := 0.8
const BLOOMS := 0.3
## The lake takes at least this share of its islet's land.
const LAKE_SHARE := 0.35

static func feature(m: Dictionary, f: Dictionary, placed: Array, centre: Vector3, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	if shape.lake.is_empty():
		_missing(m,f,plan)
		return
	match str(f.type):
		"spill": _spill(m,placed,centre)
		"jetty": _jetty(m,f,centre,rng,plan)
		"boat": _boat(m,f,rng,plan)
		"floats": _floats(m,rng)

static func _missing(m: Dictionary, f: Dictionary, plan: Dictionary) -> void:
	if float(f.get("chance",1.0)) >= 1.0: plan.problems.append("no room for the %s on %s" % [f.type,m.name])

## The spill: the rim's way most open to the sky, leaning out of the
## cluster.
static func _spill(m: Dictionary, placed: Array, centre: Vector3) -> void:
	var shape: RefCounted = m.shape
	var outward := Vector2(m.offset.x-centre.x,m.offset.z-centre.z)
	outward = outward.normalized() if outward.length() > 0.5 else Vector2.RIGHT
	var best := Vector2.RIGHT
	var best_score := -INF
	for k in range(48):
		var way := Vector2.from_angle(TAU*k/48.0)
		var lip: Vector2 = shape.rim_point(way.angle())
		var clear := 30.0
		for t: float in [1.0,4.0,9.0,15.0]:
			var q: Vector2 = lip+way*t+Vector2(m.offset.x,m.offset.z)
			for p: Dictionary in placed:
				if p == m: continue
				clear = minf(clear,rim_distance(p,q))
		var by_bridge := false
		for deck: Dictionary in shape.decks:
			if Vector2(deck.a.x,deck.a.z).distance_to(lip) < SPILL_BRIDGE: by_bridge = true
		var score := minf(clear,SPILL_CLEAR*2.0)*2.0+way.dot(outward)*6.0-(40.0 if by_bridge else 0.0)
		if score > best_score:
			best_score = score
			best = way
	IsletLake.spill(shape,best)

## The jetty: from a head on the bank out over the shallows to deep, open
## water.
static func _jetty(m: Dictionary, f: Dictionary, centre: Vector3, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var level: float = shape.water_level
	var field: Dictionary = shape.lake.field
	var n: int = field.n
	var toward := Vector2(centre.x-m.offset.x,centre.z-m.offset.z)
	toward = toward.normalized() if toward.length() > 0.5 else Vector2.ZERO
	var best: Variant = null
	var best_score := -INF
	for j in range(0,n,2):
		for i in range(0,n,2):
			var d: float = field.dist[j*n+i]
			if d < JETTY_HEAD.x or d > JETTY_HEAD.y: continue
			var head := Vector2(float(field.origin)+i*IsletLake.FIELD,float(field.origin)+j*IsletLake.FIELD)
			if not shape.on_land(head) or shape.inland(head) < 0.8 or shape._blocked_by(head,1.0,[]): continue
			if shape._channel_distance(head) < 4.0 or head.distance_to(shape.lip) < 5.0: continue
			for k in range(16):
				var way := Vector2.from_angle(TAU*k/16.0+float(i+j)*0.07)
				var length := rng.randf_range(JETTY.x,JETTY.y)
				var ok := true
				for t: float in [0.45,0.65,0.85,1.0]:
					var q: Vector2 = head+way*length*t
					if not shape.wet(q) or shape._channel_distance(q) < 2.0: ok = false; break
				if not ok: continue
				var end: Vector2 = head+way*length
				var deep: float = IsletLake.depth_at(shape,end)
				if deep < JETTY_DEPTH: continue
				var open := 0.0
				while open < 8.0 and shape.wet(end+way*(open+0.5)): open += 0.5
				if open < JETTY_OPEN: continue
				# Clear of the water's other side and the isle sideways too.
				var across := Vector2(-way.y,way.x)
				if not (shape.wet(end+across*1.6) and shape.wet(end-across*1.6)): continue
				var score := minf(deep,1.2)+minf(open,6.0)*0.3+way.dot(toward)*0.4+rng.randf()*0.3
				if score > best_score:
					best_score = score
					best = [head,end]
	if best == null:
		_missing(m,f,plan)
		return
	var head: Vector2 = best[0]
	var end: Vector2 = best[1]
	var way := (end-head).normalized()
	var y := maxf(float(shape.ground_at(head))+0.12,level+JETTY_OVER)
	var a := Vector3(head.x,y,head.y)
	var b := Vector3(end.x,y,end.y)
	shape.decks.append({"a":a,"b":b,"width":JETTY_WIDTH,"bow":0.0})
	shape.reach = maxf(shape.reach,end.length()+1.0)
	shape.claims.append(Vector4(head.x,head.y,1.2,0.0))
	# Nothing grows through the planks.
	shape.objects = shape.objects.filter(func(o: Dictionary) -> bool:
		var p := Vector2(o.x,o.z)
		var t := clampf((p-head).dot(way)/head.distance_to(end),0.0,1.0)
		return p.distance_to(head.lerp(end,t)) > JETTY_WIDTH*0.5+0.35)
	m.features.append({"type":"dock","a":a,"b":b,"jetty":true})
	# A lantern post by its head, on the bank.
	var across := Vector2(-way.y,way.x)
	for side: float in [1.0,-1.0]:
		var at := head-way*0.5+across*side*1.05
		if shape.on_land(at) and not shape.wet(at) and not IsletLake.near(shape,at,0.15):
			m.features.append({"type":"post","at":at,"angle":atan2(-way.x,-way.y)+PI})
			break

static func _find(m: Dictionary, test: Callable) -> Dictionary:
	for f: Dictionary in m.features:
		if test.call(f): return f
	return {}

## The boat, moored alongside the jetty's end, afloat; or, with no jetty,
## out on the water near the bank.
static func _boat(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var jetty := _find(m,func(g: Dictionary) -> bool: return g.type == "dock" and g.get("jetty",false))
	var tries: Array = []
	if not jetty.is_empty():
		var a := Vector2(jetty.a.x,jetty.a.z)
		var b := Vector2(jetty.b.x,jetty.b.z)
		var way := (b-a).normalized()
		var across := Vector2(-way.y,way.x)
		var first := 1.0 if rng.randf() < 0.5 else -1.0
		for back: float in [1.7,2.6,1.2]:
			for side: float in [first,-first]:
				tries.append([b-way*back+across*side*(JETTY_WIDTH*0.5+BOAT.y+0.25),way*(1.0 if rng.randf() < 0.6 else -1.0)])
	for k in range(40):
		var p := Vector2(rng.randf_range(-shape.reach,shape.reach),rng.randf_range(-shape.reach,shape.reach))
		tries.append([p,Vector2.from_angle(rng.randf()*TAU)])
	for t: Array in tries:
		var at: Vector2 = t[0]
		var way: Vector2 = t[1]
		if not _afloat(shape,at,way): continue
		if not jetty.is_empty() and _to_deck(jetty,at) < JETTY_WIDTH*0.5+0.3: continue
		m.features.append({"type":"boat","at":at,"angle":atan2(-way.x,-way.y),"paint":rng.randi() % 4})
		return
	_missing(m,f,plan)

## True where a boat lying along `way` at `at` floats clear of the bed and
## the channel.
static func _afloat(shape: RefCounted, at: Vector2, way: Vector2) -> bool:
	var across := Vector2(-way.y,way.x)
	for c: Vector2 in [at,at+way*BOAT.x,at-way*BOAT.x,at+across*BOAT.y,at-across*BOAT.y]:
		if IsletLake.depth_at(shape,c) < BOAT_DEPTH: return false
		if shape._channel_distance(c) < 2.5: return false
	return true

static func _to_deck(deck: Dictionary, p: Vector2) -> float:
	var a := Vector2(deck.a.x,deck.a.z)
	var b := Vector2(deck.b.x,deck.b.z)
	var t := clampf((p-a).dot(b-a)/maxf(a.distance_squared_to(b),0.0001),0.0,1.0)
	return p.distance_to(a.lerp(b,t))

## Lilies on the shallows, lanterns out on the open water.
static func _floats(m: Dictionary, rng: RandomNumberGenerator) -> void:
	var shape: RefCounted = m.shape
	var reach: float = shape.reach
	var keep: Array = []
	for g: Dictionary in m.features:
		if g.type == "boat": keep.append(Vector3(g.at.x,g.at.y,BOAT.x+0.6))
	var jetty := _find(m,func(g: Dictionary) -> bool: return g.type == "dock" and g.get("jetty",false))
	var isle: Vector3 = shape.lake.isle
	var clear := func(p: Vector2, room: float) -> bool:
		if not jetty.is_empty() and _to_deck(jetty,p) < JETTY_WIDTH*0.5+room: return false
		if shape._channel_distance(p) < 2.0+room: return false
		for k: Vector3 in keep:
			if p.distance_to(Vector2(k.x,k.y)) < k.z+room: return false
		return true
	var lanterns: Array = []
	var want := rng.randi_range(LANTERNS.x,LANTERNS.y)
	for attempt in range(want*30):
		if lanterns.size() >= want: break
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		if IsletLake.depth_at(shape,p) < LANTERN_DEPTH or IsletLake.distance(shape,p) > 0.0: continue
		if not clear.call(p,0.8): continue
		if isle.z > 0.0 and p.distance_to(Vector2(isle.x,isle.y)) < isle.z*1.4: continue
		var apart := true
		for q: Vector2 in lanterns:
			if p.distance_to(q) < LANTERN_APART: apart = false
		if apart: lanterns.append(p)
	var lilies: Array = []
	for patch in range(rng.randi_range(LILY_PATCHES.x,LILY_PATCHES.y)):
		for attempt in range(30):
			var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
			var d: float = IsletLake.depth_at(shape,p)
			if d < 0.15 or d > 0.6 or not clear.call(p,1.0): continue
			for k in range(rng.randi_range(LILIES.x,LILIES.y)):
				var q := p+Vector2(rng.randfn(0.0,LILY_SPREAD),rng.randfn(0.0,LILY_SPREAD))
				var dq: float = IsletLake.depth_at(shape,q)
				if dq < 0.08 or dq > 0.9 or not clear.call(q,0.4): continue
				var near := false
				for l: Array in lilies:
					if q.distance_to(Vector2(l[0],l[1])) < 0.45: near = true
				if near: continue
				lilies.append([q.x,q.y,rng.randf()*TAU,rng.randf_range(0.7,1.25),rng.randf() < BLOOMS,rng.randf() < 0.35])
			break
	m.features.append({"type":"floats","lanterns":lanterns,"lilies":lilies})

## How far plate point `q` (cluster frame) lies from member `p`'s rim, 0
## inside it.
static func rim_distance(p: Dictionary, q: Vector2) -> float:
	var local := q-Vector2(p.offset.x,p.offset.z)
	var rim: PackedVector2Array = p.rim
	if Geometry2D.is_point_in_polygon(local,rim): return 0.0
	var best := INF
	for i in range(rim.size()):
		best = minf(best,local.distance_to(Geometry2D.get_closest_point_to_segment(local,rim[i],rim[(i+1)%rim.size()])))
	return best

## What is wrong with a plan's lakes, as sentences.
static func validate(plan: Dictionary) -> Array:
	var problems: Array = []
	for m: Dictionary in plan.members:
		var shape: RefCounted = m.shape
		if shape.lake.is_empty(): continue
		if not shape.lake.get("spilled",false): problems.append("lake on %s never spills" % m.name)
		elif not shape.wet(shape.lip-(shape.lip_out as Vector2)*0.4): problems.append("lake on %s: dry spill" % m.name)
		var share: float = float(shape.lake.area)/maxf(shape.land_area(),1.0)
		if share < LAKE_SHARE: problems.append("lake on %s too small (%.0f%%)" % [m.name,share*100.0])
		for f: Dictionary in m.features:
			match str(f.type):
				"dock":
					if f.get("jetty",false) and not shape.wet(Vector2(f.b.x,f.b.z)): problems.append("jetty on %s ends on land" % m.name)
				"boat":
					if not _afloat(shape,f.at,Vector2(-sin(float(f.angle)),-cos(float(f.angle)))): problems.append("boat aground on %s" % m.name)
				"floats":
					for p: Vector2 in f.lanterns:
						if not shape.wet(p): problems.append("lantern aground on %s" % m.name)
					for l: Array in f.lilies:
						if not shape.wet(Vector2(l[0],l[1])): problems.append("lily aground on %s" % m.name)
	return problems
