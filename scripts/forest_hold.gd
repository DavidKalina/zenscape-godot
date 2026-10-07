extends RefCounted
## The forest hold motif's own features (scripts/cluster_motifs.gd
## "forest"): laid by the solver (scripts/cluster_solver.gd `_feature`
## hands them here), checked by its validator (`check`), and stood up by
## the dresser (scripts/cluster_dresser.gd `prepare` and `furnish` hand
## them here). Its islets are planted as woodland (scripts/woodland.gd),
## which leaves its glades and the hold tree on the islet as meta.
##
## Features:
##   hut: the cabin, set in the hold's glade across from the hold tree, its
##     door to the glade's middle (laid as a "cabin", so its window, porch
##     lantern, lamps and lantern bearer come as any cabin's);
##   treehouse: a platform in the hold tree's boughs (scripts/
##     forest_builds.gd), roofed, railed, a ladder down to the glade,
##     lanterns round its eaves;
##   trail: a way cleared through the wood from each bridge's head and the
##     stepping stones' landing to the hut's door, or the middle;
##   canopy: lanterns in the trees: strings from the hold tree's platform
##     out to the glade's edge and round it, strings zigzagging over the
##     trails, and single lanterns hung from boughs out toward the open
##     sky, so the wood shows from far at night as warm points scattered
##     through the trees.
## And with the motif's night "bridge_lanterns", lanterns hang from the
## rope bridges' hand ropes.
##
## Nothing hangs lower than HEADROOM over the ground under it, so the
## pilot walks under every string.

const Builds = preload("res://scripts/showcase_builds.gd")
const ForestBuilds = preload("res://scripts/forest_builds.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Woodland = preload("res://scripts/woodland.gd")

## Footprints (m): the hut (a cabin's), and how far its middle keeps off
## the hold tree.
const CABIN := 2.3
const HOLD_TREE_KEEP := 3.8
## The platform: its height up the hold tree (share of the tree's, and m
## at most), its inner and outer radius (m, inner a share of the tree's
## record scale), and lanterns round its eaves.
const DECK_SHARE := 0.3
const DECK_MOST := 5.2
const DECK_INNER := 0.62
const DECK_OUTER := 1.75
const EAVE_LANTERNS := 3
## A trail's half width (m) cleared of what grows, and its bend (m).
const TRAIL_HALF := 0.85
const TRAIL_BEND := 1.4
## Strings: their span (m), sag (share of span), lanterns a metre, and the
## least room under them over the ground (m).
const SPAN := Vector2(2.6,10.5)
const SAG := 0.09
const STRING_LANTERNS := 0.75
const HEADROOM := 2.3
## Bough lanterns (count a square metre of land, and at most), hung from
## this share of a tree's height.
const BOUGHS := 0.012
const BOUGHS_MOST := 14
const BOUGH_AT := Vector2(0.38,0.5)
## The lights: a string lantern's scale, halos (m across near, strength),
## real lights' (reach m, energy) and how far they show (m).
const SMALL := 0.75
const HALO_STRING := Vector2(0.75,0.75)
const HALO_BOUGH := Vector2(1.0,0.8)
const HALO_EAVE := Vector2(1.3,0.9)
const GLOW := Color("ffa955")
const LIGHT_COLOR := Color("ffb36b")
const LIGHT := Vector2(5.5,1.0)
const FADE := 50.0
## Lanterns on a rope bridge: where along it, as shares of its span.
const BRIDGE_AT := [0.22,0.5,0.78]

const TREES := ["tree","birch","redwood","juniper","broadleaf","willow","layered_tree"]
const CLEARED := ["tree","birch","redwood","juniper","broadleaf","willow","layered_tree","fern","shrub","mushroom","log","stump","snag",
	"boulder_1","boulder_2","boulder_3","boulder_4","rock"]

# --- Laying (the solver) ---------------------------------------------------------------

## Lays feature `f` on member `m` (the solver's member), as the solver's
## own features are laid; a must-have that finds no room is a problem.
static func feature(m: Dictionary, f: Dictionary, placed: Array, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	match str(f.type):
		"hut": _hut(m,f,rng,plan)
		"treehouse": _treehouse(m,f,rng,plan)
		"trail": _trail(m,placed,rng,plan)
		"canopy": _canopy(m,f,rng)

static func _missing(m: Dictionary, f: Dictionary, plan: Dictionary) -> void:
	if float(f.get("chance",1.0)) >= 1.0: plan.problems.append("no room for the %s on %s" % [f.type,m.name])

static func _find(m: Dictionary, type: String) -> Dictionary:
	for f: Dictionary in m.features:
		if f.type == type: return f
	return {}

static func _hut(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var glades: Array = shape.get_meta("glades",[])
	var tree: Variant = shape.get_meta("hold_tree") if shape.has_meta("hold_tree") else null
	var avoid: Array = []
	var prefer := {"middle":0.6}
	if tree != null: avoid.append(Vector3(tree.x,tree.y,HOLD_TREE_KEEP))
	if not glades.is_empty():
		var g: Vector3 = glades[0]
		var middle := Vector2(g.x,g.y)
		var away := (middle-Vector2(tree.x,tree.y)).normalized() if tree != null else Vector2.ZERO
		prefer = {"near":middle+away*g.z*0.3,"near_weight":1.5}
	var at: Variant = shape.find_spot(CABIN,0.5,0.9,avoid,prefer)
	if at == null:
		_missing(m,f,plan)
		return
	var p: Vector2 = at
	shape.claim(p,CABIN)
	var look := -p
	if not glades.is_empty(): look = Vector2(glades[0].x,glades[0].y)-p
	if look.length() < 1.0 and tree != null: look = Vector2(tree.x,tree.y)-p
	if look.length() < 0.5: look = Vector2.from_angle(rng.randf()*TAU)
	var angle := atan2(look.x,look.y)+rng.randf_range(-0.25,0.25)
	shape.add_record("cabin",p,angle,1.0)
	m.features.append({"type":"cabin","at":p,"angle":angle})

static func _treehouse(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var tree: Variant = shape.get_meta("hold_tree") if shape.has_meta("hold_tree") else null
	if tree == null or not _standing(shape,Vector2(tree.x,tree.y)):
		_missing(m,f,plan)
		return
	var at := Vector2(tree.x,tree.y)
	var scale := float(tree.z)
	var height := minf(scale*float(Woodland.HEIGHT.redwood)*DECK_SHARE,DECK_MOST)
	var inner := DECK_INNER*scale
	var outer := DECK_OUTER+inner*0.4
	# The ladder down toward the glade's middle (or the hut), else inland.
	var glades: Array = shape.get_meta("glades",[])
	var toward := -at
	if not glades.is_empty(): toward = Vector2(glades[0].x,glades[0].y)-at
	var best: Variant = null
	for k in range(12):
		var a := toward.angle()+(k/2)*0.35*(1.0 if k % 2 == 0 else -1.0)
		var way := Vector2.from_angle(a)
		var foot := at+way*(ForestBuilds.ladder_foot(outer).z)
		if not shape.on_land(foot) or shape.wet(foot) or shape.inland(foot) < 0.8: continue
		if absf(shape.ground_at(foot)-shape.ground_at(at)) > 0.6: continue
		best = way
		break
	if best == null:
		_missing(m,f,plan)
		return
	var way: Vector2 = best
	var foot := at+way*ForestBuilds.ladder_foot(outer).z
	# Clear the ladder's foot and the way up of what grows (but the tree).
	shape.objects = shape.objects.filter(func(o: Dictionary) -> bool:
		var q := Vector2(o.x,o.z)
		if q.distance_to(at) < 0.05: return true
		return not (o.asset in CLEARED and _segment_distance(q,at+way*outer*0.6,foot) < 0.9))
	m.features.append({"type":"treehouse","at":at,"ground":shape.ground_at(at),"height":height,"inner":inner,"outer":outer,
		"angle":atan2(way.x,way.y),"foot":foot})

## True while a tree record still stands at `p`.
static func _standing(shape: RefCounted, p: Vector2) -> bool:
	for o: Dictionary in shape.objects:
		if o.asset in TREES and Vector2(o.x,o.z).distance_to(p) < 0.05: return true
	return false

## The trail's heads on `m`: each bridge's end on it, and where the
## stepping stones land.
static func _heads(m: Dictionary, placed: Array, plan: Dictionary) -> Array:
	var heads: Array = []
	var by_name := {}
	for p: Dictionary in placed: by_name[p.name] = p
	for br: Dictionary in plan.bridges:
		if br.from == m.name: heads.append(Vector2((br.a as Vector3).x,(br.a as Vector3).z))
		elif br.to == m.name and by_name.has(br.from):
			var off: Vector3 = (m.offset as Vector3)-(by_name[br.from].offset as Vector3)
			heads.append(Vector2((br.b as Vector3).x-off.x,(br.b as Vector3).z-off.z))
	for route: Array in plan.routes:
		for k in range(route.size()):
			if route[k] != m.name: continue
			for n: int in [k-1,k+1]:
				if n < 0 or n >= route.size() or not by_name.has(route[n]): continue
				var off: Vector3 = (by_name[route[n]].offset as Vector3)-(m.offset as Vector3)
				var way := Vector2(off.x,off.z).normalized()
				heads.append(way*maxf(m.shape.rim_radius(way.angle())-1.0,0.5))
	return heads

static func _trail(m: Dictionary, placed: Array, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var heads := _heads(m,placed,plan)
	if heads.is_empty(): return
	# The heart: the hut's door, the glade's middle, or the middle.
	var heart := Vector2.ZERO
	var glades: Array = shape.get_meta("glades",[])
	if not glades.is_empty(): heart = Vector2(glades[0].x,glades[0].y)
	var hut := _find(m,"cabin")
	if not hut.is_empty():
		heart = (hut.at as Vector2)+Vector2(sin(float(hut.angle)),cos(float(hut.angle)))*2.4
		if not shape.on_land(heart): heart = hut.at
	var tree: Variant = shape.get_meta("hold_tree") if shape.has_meta("hold_tree") else null
	var lines: Array = []
	for head: Vector2 in heads:
		var way := heart-head
		var mid := head.lerp(heart,0.5)+Vector2(-way.y,way.x).normalized()*rng.randf_range(-TRAIL_BEND,TRAIL_BEND)
		if not shape.on_land(mid): mid = head.lerp(heart,0.5)
		# Round the hold tree's trunk, not through it.
		if tree != null:
			var trunk := Vector2(tree.x,tree.y)
			for k in range(6):
				if minf(_segment_distance(trunk,head,mid),_segment_distance(trunk,mid,heart)) > TRAIL_HALF+1.0: break
				var off := mid-trunk
				mid += (off.normalized() if off.length() > 0.1 else Vector2(-way.y,way.x).normalized())*0.8
		lines.append(PackedVector2Array([head,mid,heart]))
	shape.objects = shape.objects.filter(func(o: Dictionary) -> bool:
		if not o.asset in CLEARED: return true
		var q := Vector2(o.x,o.z)
		if tree != null and q.distance_to(Vector2(tree.x,tree.y)) < 0.05: return true
		for line: PackedVector2Array in lines:
			for k in range(line.size()-1):
				if _segment_distance(q,line[k],line[k+1]) < TRAIL_HALF+(0.4 if o.asset in TREES else 0.0): return false
		return true)
	m.features.append({"type":"trail","lines":lines})

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))

## The trees standing on `shape`: [at, top (m over the ground), reach, asset].
static func _trees(shape: RefCounted) -> Array:
	var out: Array = []
	for o: Dictionary in shape.objects:
		if not o.asset in TREES: continue
		var h := float(o.scale)*float(Woodland.HEIGHT.get(o.asset,4.0))
		out.append([Vector2(o.x,o.z),h,h*float(Woodland.REACH.get(o.asset,0.2)),str(o.asset)])
	return out

static func _canopy(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var shape: RefCounted = m.shape
	var trees := _trees(shape)
	var strings: Array = []
	var hangs: Array = []
	var glades: Array = shape.get_meta("glades",[])
	var house := _find(m,"treehouse")
	# Round the glade: its edge trees in turn, strung each to the next, and
	# from the platform out to a few of them.
	if not glades.is_empty():
		var g: Vector3 = glades[0]
		var middle := Vector2(g.x,g.y)
		var edge: Array = []
		for t: Array in trees:
			var d: float = (t[0] as Vector2).distance_to(middle)
			if d > g.z-1.0 and d < g.z+3.5 and float(t[1]) > 3.4 and t[3] != "juniper":
				if not house.is_empty() and (t[0] as Vector2).distance_to(house.at) < 0.05: continue
				edge.append(t)
		edge.sort_custom(func(a: Array, b: Array) -> bool: return ((a[0] as Vector2)-middle).angle() < ((b[0] as Vector2)-middle).angle())
		# Every other edge tree, so the ring's strings run 3 to 8 m.
		var ring: Array = []
		for t: Array in edge:
			if ring.is_empty() or (t[0] as Vector2).distance_to(ring.back()[0]) > 2.8: ring.append(t)
		for k in range(ring.size()):
			_try_string(shape,ring[k],ring[(k+1) % ring.size()],middle,rng,strings)
		if not house.is_empty():
			var deck := Vector3((house.at as Vector2).x,float(house.ground)+float(house.height)+ForestBuilds.ROOF_LOW-0.1,(house.at as Vector2).y)
			var picks := ring.duplicate()
			picks.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).distance_to(house.at) > (b[0] as Vector2).distance_to(house.at))
			var made := 0
			for t: Array in picks:
				if made >= 3: break
				var way := ((t[0] as Vector2)-(house.at as Vector2)).normalized()
				var from := deck+Vector3(way.x,0.0,way.y)*(float(house.outer)+0.35)
				if _string_to(shape,from,t,house.at,rng,strings): made += 1
	# Over the trails: zigzag between the trees each side.
	var trail := _find(m,"trail")
	if not trail.is_empty():
		for line: PackedVector2Array in trail.lines:
			var side: Array = []
			for t: Array in trees:
				if float(t[1]) < 3.4 or t[3] == "juniper": continue
				var best := INF
				var at_t := 0.0
				for k in range(line.size()-1):
					var d := _segment_distance(t[0],line[k],line[k+1])
					if d < best:
						best = d
						at_t = k+((t[0] as Vector2)-line[k]).dot(line[k+1]-line[k])/maxf((line[k+1]-line[k]).length_squared(),0.001)
				if best < 3.2: side.append([at_t,t])
			side.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			var last: Variant = null
			for s: Array in side:
				if last == null:
					last = s[1]
					continue
				var span: float = ((s[1][0] as Vector2)-(last[0] as Vector2)).length()
				if span < 3.0: continue
				if _try_string(shape,last,s[1],line[line.size()-1],rng,strings): last = s[1]
				elif span > SPAN.y: last = s[1]
	# Bough lanterns: trees toward the open sky (and the glade), one each.
	var want := mini(roundi(shape.land_area()*BOUGHS*rng.randf_range(0.8,1.2)),BOUGHS_MOST)
	var pool: Array = []
	for t: Array in trees:
		if float(t[1]) < 4.2 or t[3] == "juniper": continue
		pool.append([rng.randf()+shape.share(t[0])*0.8,t])
	pool.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var used: Array[Vector2] = []
	for entry: Array in pool:
		if hangs.size() >= want: break
		var t: Array = entry[1]
		var at: Vector2 = t[0]
		var near := false
		for u in used:
			if u.distance_to(at) < 3.0: near = true
		if near: continue
		var out := at.normalized() if at.length() > 0.5 else Vector2.RIGHT
		out = out.rotated(rng.randf_range(-0.7,0.7))
		var h: float = float(t[1])*rng.randf_range(BOUGH_AT.x,BOUGH_AT.y)
		var reach: float = float(t[2])*(1.0-h/float(t[1]))*1.05+0.25
		var p := at+out*reach
		var ground: float = shape.ground_at(p) if shape.on_land(p) else shape.ground_at(at)
		var hook := Vector3(p.x,shape.ground_at(at)+h,p.y)
		if hook.y-ForestBuilds.HOOK-ground < HEADROOM: continue
		hangs.append([Vector3(at.x+out.x*0.15,hook.y+0.35,at.y+out.y*0.15),hook])
		used.append(at)
	m.features.append({"type":"canopy","strings":strings,"hangs":hangs})

## A string between trees `a` and `b` (as `_trees` gives them), each end
## tied where the crown's reach meets the way to the other, at a height
## that leaves HEADROOM under its sag; true if laid.
static func _try_string(shape: RefCounted, a: Array, b: Array, middle: Vector2, rng: RandomNumberGenerator, strings: Array) -> bool:
	var pa: Vector2 = a[0]
	var pb: Vector2 = b[0]
	var span := pa.distance_to(pb)
	if span < SPAN.x or span > SPAN.y: return false
	var way := (pb-pa)/span
	var h := minf(minf(float(a[1]),float(b[1]))*0.55,rng.randf_range(3.1,3.9))
	var ends: Array = []
	for t: Array in [[a,way],[b,-way]]:
		var tree: Array = t[0]
		var at: Vector2 = tree[0]
		var reach: float = float(tree[2])*(1.0-h/float(tree[1]))*0.6
		var p: Vector2 = at+(t[1] as Vector2)*reach
		ends.append(Vector3(p.x,shape.ground_at(at)+h,p.y))
	return _lay(shape,ends[0],ends[1],strings)

## A string from a point `from` to tree `b`.
static func _string_to(shape: RefCounted, from: Vector3, b: Array, _origin: Vector2, rng: RandomNumberGenerator, strings: Array) -> bool:
	var pb: Vector2 = b[0]
	var flat := Vector2(from.x,from.z)
	var span := flat.distance_to(pb)
	if span < SPAN.x or span > SPAN.y+2.0: return false
	var h := minf(float(b[1])*0.55,rng.randf_range(3.3,4.0))
	var way := (flat-pb)/span
	var reach: float = float(b[2])*(1.0-h/float(b[1]))*0.6
	var p := pb+way*reach
	return _lay(shape,from,Vector3(p.x,shape.ground_at(pb)+h,p.y),strings)

## Lays a string from `a` to `b` if the room under it all along is
## HEADROOM and its ends stand over the land.
static func _lay(shape: RefCounted, a: Vector3, b: Vector3, strings: Array) -> bool:
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	var sag := span*SAG
	var count := maxi(2,roundi(span*STRING_LANTERNS))
	if not _clear_under(shape,a,b,sag): return false
	strings.append({"a":a,"b":b,"sag":sag,"count":count})
	return true

static func _clear_under(shape: RefCounted, a: Vector3, b: Vector3, sag: float) -> bool:
	for k in range(9):
		var t := k/8.0
		var p := ForestBuilds.along(a,b,sag,t)
		var q := Vector2(p.x,p.z)
		if not shape.on_land(q):
			if k == 0 or k == 8: return false
			continue
		var low := p.y-ForestBuilds.CORD-ForestBuilds.HOOK*SMALL
		if low-shape.ground_at(q) < HEADROOM: return false
	return true

# --- Checking (the validator) ----------------------------------------------------------

## What is wrong with forest feature `f` on member `member`'s `shape`,
## appended to `problems`: a treehouse whose tree is gone or whose ladder
## stands off the land or in water; a lantern string or bough lantern over
## no land, or hung lower than HEADROOM.
static func check(shape: RefCounted, f: Dictionary, member: String, problems: Array) -> void:
	match str(f.type):
		"treehouse":
			if not _standing(shape,f.at): problems.append("treehouse without its tree on %s" % member)
			var foot: Vector2 = f.foot
			if not shape.on_land(foot) or shape.wet(foot): problems.append("off the land or in water: treehouse ladder on %s" % member)
		"canopy":
			for s: Dictionary in f.strings:
				if not _clear_under(shape,s.a,s.b,float(s.sag)): problems.append("low or off the land: lantern string on %s" % member)
			for h: Array in f.hangs:
				var hook: Vector3 = h[1]
				var q := Vector2(hook.x,hook.z)
				var ground: float = shape.ground_at(q)
				if hook.y-ForestBuilds.HOOK-ground < HEADROOM-0.05: problems.append("low: bough lantern on %s" % member)

# --- Standing up (the dresser) ---------------------------------------------------------

## The meshes and placings of `member`'s forest features and its bridges'
## lanterns, safe on a worker: {mesh (ropes, cords, the platform), lanterns
## (Transform3D each), beads (glow cores), halos ([at, size, strength]),
## lights ([at])}; empty when it has none.
static func prepare(member: Dictionary, plan: Dictionary) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var out := {"lanterns":[],"beads":[],"halos":[],"lights":[]}
	var any := false
	for f: Dictionary in member.features:
		match str(f.type):
			"treehouse":
				any = true
				var pose := Transform3D(Basis(Vector3.UP,float(f.angle)),Vector3((f.at as Vector2).x,float(f.ground),(f.at as Vector2).y))
				var part := SurfaceTool.new()
				part.begin(Mesh.PRIMITIVE_TRIANGLES)
				ForestBuilds.platform(part,float(f.height),float(f.inner),float(f.outer),int(member.seed) % 991)
				# Copied over by hand: a committed mesh read back asks the
				# renderer for its faces, which a worker must never wait on.
				var arrays := part.commit_to_arrays()
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				for k in range(points.size()):
					st.set_color(colours[k])
					st.add_vertex(pose*points[k])
				for hook: Vector3 in ForestBuilds.eave_hooks(float(f.height),float(f.outer),EAVE_LANTERNS):
					_hang(out,pose*hook,1.0,HALO_EAVE)
				out.lights.append(pose*Vector3(0.0,float(f.height)+1.2,float(f.outer)))
			"canopy":
				for s: Dictionary in f.strings:
					any = true
					for hook: Vector3 in ForestBuilds.string(st,s.a,s.b,float(s.sag),int(s.count)): _hang(out,hook,SMALL,HALO_STRING)
				for h: Array in f.hangs:
					any = true
					ForestBuilds.cord(st,h[0],h[1])
					_hang(out,h[1],1.0,HALO_BOUGH)
				var glades: Array = member.shape.get_meta("glades",[])
				if not glades.is_empty() and not f.strings.is_empty():
					var g: Vector3 = glades[0]
					out.lights.append(Vector3(g.x,member.shape.ground_at(Vector2(g.x,g.y))+3.0,g.y))
	if (plan.get("night",{}) as Dictionary).get("bridge_lanterns",false):
		for br: Dictionary in plan.bridges:
			if br.from != member.name or not Footbridge.roped(float(br.span)): continue
			any = true
			var a: Vector3 = br.a
			var b: Vector3 = br.b
			var span := float(br.span)
			var across := Vector3(b.x-a.x,0.0,b.z-a.z).normalized().cross(Vector3.UP)
			for k in range(BRIDGE_AT.size()):
				var t: float = BRIDGE_AT[k]
				var side := 1.0 if k % 2 == 0 else -1.0
				var rope: Vector3 = a.lerp(b,t)+Vector3.UP*(Footbridge.HAND_ROPE+Footbridge.lift(span,t)*0.55)+across*side*(Footbridge.WIDTH*0.5+0.04)
				var hook := rope+across*side*0.1+Vector3.DOWN*ForestBuilds.CORD
				ForestBuilds.cord(st,rope,hook)
				_hang(out,hook,SMALL,HALO_STRING)
	if not any: return {}
	st.generate_normals()
	out.mesh = st.commit()
	return out

## A lantern hung by its hook at `hook`, `scale` its size.
static func _hang(out: Dictionary, hook: Vector3, scale: float, halo: Vector2) -> void:
	var foot := hook+Vector3.DOWN*ForestBuilds.HOOK*scale
	out.lanterns.append(Transform3D(Basis.from_scale(Vector3.ONE*scale),foot))
	out.beads.append(foot+Vector3.UP*0.12*scale)
	out.halos.append([foot+Vector3.UP*0.14*scale,halo])

## Stands `made` (from `prepare`) under the member's `node`, drawn with the
## dresser's shared materials `mats` (its lanterns, glow and halos lit with
## every cluster's); its lights go into `live.lights`.
static func furnish(node: Node3D, made: Dictionary, mats: Dictionary, live: Dictionary) -> void:
	if made.is_empty(): return
	var mesh := MeshInstance3D.new()
	mesh.name = "ForestHold"
	mesh.mesh = made.mesh
	mesh.material_override = mats.solid
	node.add_child(mesh)
	var lanterns: Array = made.lanterns
	if lanterns.is_empty(): return
	node.add_child(_batch("Lanterns",mats.lantern,mats.solid,lanterns.size(),func(k: int, multi: MultiMesh) -> void:
		multi.set_instance_transform(k,lanterns[k])))
	var beads: Array = made.beads
	var bead := ForestBuilds.bead(0.055)
	var cores := _batch("LanternGlow",bead,mats.glow,beads.size(),func(k: int, multi: MultiMesh) -> void:
		multi.set_instance_transform(k,Transform3D(Basis.IDENTITY,beads[k])))
	cores.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(cores)
	var halos: Array = made.halos
	var glow := _batch("ForestHalos",mats.quad,mats.halo,halos.size(),func(k: int, multi: MultiMesh) -> void:
		var size: Vector2 = halos[k][1]
		multi.set_instance_transform(k,Transform3D(Basis.from_scale(Vector3.ONE*size.x),halos[k][0]))
		multi.set_instance_color(k,Color(GLOW,size.y)),true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.custom_aabb = AABB(Vector3(-60.0,-20.0,-60.0),Vector3(120.0,60.0,120.0))
	node.add_child(glow)
	for at: Vector3 in made.lights:
		var light := OmniLight3D.new()
		light.light_color = LIGHT_COLOR
		light.omni_range = LIGHT.x
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = FADE
		light.distance_fade_length = FADE*0.25
		light.position = at
		light.visible = false
		node.add_child(light)
		live.lights.append([light,LIGHT.y])

static func _batch(label: String, mesh: Mesh, material: Material, count: int, fill: Callable, colours := false) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colours
	multi.mesh = mesh
	multi.instance_count = count
	for k in range(count): fill.call(k,multi)
	batch.multimesh = multi
	batch.material_override = material
	return batch
