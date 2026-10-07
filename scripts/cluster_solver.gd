extends RefCounted
## Lays out a sky cluster from a motif (scripts/cluster_motifs.gd) and a
## seed: which members are there, their islets (scripts/sky_islet.gd
## `author`), where each stands, what stands on each, the bridges, the
## stepping stones and the dock, all as a plan of plain data and islet
## shapes. Safe on a worker; the same motif and seed always give the same
## plan. `validate` checks a plan for what must never happen.
##
## Laying out, in order:
##   1. the members: each role's count and chance drawn, each member's
##      size, height, rock look and keel; its islet shaped;
##   2. where they stand: the anchor at the middle, each other member by
##      its relation to the one it names, along the ways the motif's
##      layout tries (scatter, ring, chain, terrace), at a gap rim to rim in
##      its range, and kept MIN_GAP clear of every member laid before
##      (their rims compared all round, not as circles). Stones lay a run
##      of small islets from the one to the other, each STONE_GAP from the
##      last and never more than STONE_RISE up or down, so the pilot can
##      run and jump the whole way and back. Bridges keep their span within
##      a rope footbridge's and their grade gentle. An outer member goes
##      out on the side facing open sky;
##   3. the bridges' decks and their lantern posts;
##   4. what stands on each member, found by asking its land (SkyIslet
##      `find_spot`), then claimed (levelled, cleared) and set: the cabin,
##      the field, the lamps, the windmill, the lighthouse, the lookout, the
##      dock (off the rim facing the most open sky), the fisher, the lantern
##      bearer. A feature that finds no room is left out.
##
## The plan: {motif, seed, label, night, members: [{name, role, seed,
## shape, offset (its middle from the anchor's), features}], bridges:
## [{from, to, a, b (deck ends in the from member's frame), span}],
## routes: [[member names, stone by stone]], problems: [what could not be
## laid]}.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const Motifs = preload("res://scripts/cluster_motifs.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cabin = preload("res://scripts/cabin.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Stack = preload("res://scripts/cluster_stack.gd")

## Rim to rim (m): any two members at least MIN_GAP; stepping stones
## STONE_GAP apart (a running jump is about 2.5 to 3 m; checked against
## STONE_MAX), each at most STONE_RISE up or down from the last (a jump
## lifts PilotMotor JUMPS[1]).
const MIN_GAP := 1.5
const STONE_GAP := Vector2(1.1,1.7)
const STONE_MAX := 2.2
const STONE_RISE := 0.85
const STONE_RADIUS := Vector2(2.0,2.7)
## A footbridge's deck starts this far in from each rim; its grade at most
## Footbridge MAX_GRADE.
const BRIDGE_INSET := 1.3
## The dock: its length and width (m), and how far clear of every other
## member its end and the air beyond it stay.
const DOCK_LENGTH := Vector2(5.5,7.5)
const DOCK_WIDTH := 1.5
const DOCK_CLEAR := 6.0
## Rim samples a member's outline is compared by, and the ways tried for
## each member.
const RIM_SAMPLES := 32
const TRIES := 32
## Footprints (m): a cabin, a windmill, a lighthouse, a lamp.
const CABIN := 2.3
const MILL := 1.9
const LIGHT := 2.1
const LAMP := 0.45

static func solve(motif_name: String, seed_value: int) -> Dictionary:
	# A plan that could not lay all it must is laid again from the next
	# draw, a few times at most: still the same plan for the same seed.
	var plan := {}
	for attempt in range(ATTEMPTS):
		plan = _solve(motif_name,seed_value,attempt)
		if (plan.problems as Array).is_empty(): break
	return plan

## Draws a plan is laid from before it is given up on.
const ATTEMPTS := 4

static func _solve(motif_name: String, seed_value: int, attempt: int) -> Dictionary:
	var motif: Dictionary = Motifs.motif(motif_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([motif_name,seed_value,attempt])
	var plan := {"motif":motif_name,"seed":seed_value,"label":motif.get("label",motif_name),"night":motif.get("night",{}),
		"members":[],"bridges":[],"routes":[],"problems":[]}
	var members: Array = []
	var ring_base := rng.randf()*TAU
	# 1. The members.
	for role: Dictionary in motif.roles:
		if rng.randf() > float(role.get("chance",1.0)): continue
		var count: Vector2i = role.get("count",Vector2i(1,1))
		var n := rng.randi_range(count.x,count.y)
		for i in range(n):
			var m := _member(motif,role,i,n,seed_value,rng)
			members.append(m)
	# 2. Where they stand.
	var placed: Array = []
	for m: Dictionary in members:
		var role: Dictionary = m.role_data
		if role.get("anchor",false):
			m.offset = Vector3.ZERO
			placed.append(m)
			continue
		if role.has("offset") and not (role.get("relation",{}) as Dictionary).get("type","") == "stones":
			m.offset = role.offset
			if _clear(m,m.offset,placed,MIN_GAP): placed.append(m)
			else: plan.problems.append("fixed member %s overlaps" % m.name)
			continue
		var rel: Dictionary = role.get("relation",{"type":"near","to":members[0].role})
		var parent := _parent(rel,m,placed)
		if parent.is_empty():
			plan.problems.append("no member for %s to relate to" % m.name)
			continue
		var ok := false
		if rel.type == "stones": ok = _lay_stones(m,parent,rel,placed,plan,rng)
		elif rel.type == "stack": ok = Stack.place(m,placed,plan,rng)
		else:
			for angle in _ways(motif,rel,m,parent,placed,rng,ring_base):
				var gap: Vector2 = rel.get("gap",Vector2(6.0,12.0))
				var g := rng.randf_range(gap.x,gap.y)
				var at := _beyond(parent,m,angle,g)
				if rel.type == "bridge" and not _bridgeable(parent,m,at,placed): continue
				if not _clear(m,at,placed,MIN_GAP): continue
				m.offset = at
				ok = true
				break
		if ok:
			placed.append(m)
			if rel.type == "bridge": m.bridge_to = parent.name
		elif float(role.get("chance",1.0)) >= 1.0 and m.index < int((role.get("count",Vector2i(1,1)) as Vector2i).x):
			plan.problems.append("could not place %s" % m.name)
	# Fixed bridges (the showcase's members set by hand).
	for m: Dictionary in placed:
		var rel: Dictionary = m.role_data.get("relation",{})
		if m.role_data.has("offset") and rel.get("type","") == "bridge":
			var parent := _parent(rel,m,placed)
			if not parent.is_empty(): m.bridge_to = parent.name
	var by_name := {}
	for m: Dictionary in placed: by_name[m.name] = m
	var centre := Vector3.ZERO
	for m: Dictionary in placed: centre += m.offset
	centre /= maxf(placed.size(),1)
	# 3. Bridges.
	for m: Dictionary in placed:
		if not m.has("bridge_to"): continue
		_bridge(by_name[m.bridge_to],m,plan)
	# 4. What stands on them.
	for m: Dictionary in placed:
		for f: Dictionary in m.role_data.get("features",[]):
			if rng.randf() > float(f.get("chance",1.0)): continue
			_feature(m,f,placed,centre,rng,plan)
	for m: Dictionary in placed:
		plan.members.append({"name":m.name,"role":m.role,"seed":m.seed,"shape":m.shape,"offset":m.offset,"features":m.features})
	return plan

# --- 1. Members -------------------------------------------------------------------

static func _member(motif: Dictionary, role: Dictionary, index: int, count: int, seed_value: int, rng: RandomNumberGenerator) -> Dictionary:
	var name: String = role.name if count == 1 else "%s%d" % [role.name,index]
	var radius_range: Vector2 = role.radius
	var height: Vector2 = role.get("height",Vector2.ZERO)
	var spec: Dictionary = (role.get("spec",{}) as Dictionary).duplicate(true)
	spec.kind = role.kind
	spec.radius = rng.randf_range(radius_range.x,radius_range.y)
	var rock: Dictionary = motif.get("rock",{})
	var palettes: Array = rock.get("palettes",["basalt"])
	var tone: Vector2 = rock.get("tone",Vector2.ONE)
	spec.rock = {"palette":palettes[rng.randi()%palettes.size()],"tone":rng.randf_range(tone.x,tone.y)}
	var keel: Vector2 = motif.get("keel",Vector2.ONE)
	# Small islets hang less deep, so a run of them reads as rocks, not teeth.
	spec.keel = lerpf(1.0,rng.randf_range(keel.x,keel.y),clampf((float(spec.radius)-2.0)/7.0,0.25,1.0))
	if rng.randf() < float(role.get("pond",0.0)) and not spec.has("pond"):
		spec.pond = {"toward":Vector2.from_angle(rng.randf()*TAU)}
	var member_seed: int = int(role.get("seed",hash([seed_value,name]) & 0xffffff))
	var shape: RefCounted = SkyIslet.author(member_seed,spec)
	var y := rng.randf_range(height.x,height.y)
	if role.has("offset"): y = (role.offset as Vector3).y
	return {"name":name,"role":role.name,"role_data":role,"index":index,"seed":member_seed,"shape":shape,"y":y,
		"rim":_rim(shape),"features":[],"offset":Vector3.ZERO}

## The rim's points, RIM_SAMPLES round (islet frame).
static func _rim(shape: RefCounted) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(RIM_SAMPLES): out.append(shape.rim_point(TAU*k/RIM_SAMPLES))
	return out

# --- 2. Layout --------------------------------------------------------------------

static func _parent(rel: Dictionary, m: Dictionary, placed: Array) -> Dictionary:
	var to: String = rel.get("to","")
	if to == "prev":
		for k in range(placed.size()-1,-1,-1):
			if placed[k].role == m.role: return placed[k]
		return placed[0] if not placed.is_empty() else {}
	for p: Dictionary in placed:
		if p.role == to or p.name == to: return p
	return placed[0] if not placed.is_empty() else {}

## The ways (angles, plate x z) to try laying `m` from `parent`, by the
## motif's layout.
static func _ways(motif: Dictionary, rel: Dictionary, m: Dictionary, parent: Dictionary, placed: Array, rng: RandomNumberGenerator, ring_base: float) -> Array:
	var ways: Array = []
	var layout: String = motif.get("layout","scatter")
	if rel.type == "outer":
		var centre := Vector2.ZERO
		for p: Dictionary in placed: centre += Vector2(p.offset.x,p.offset.z)
		centre /= maxf(placed.size(),1)
		var out := Vector2(parent.offset.x,parent.offset.z)-centre
		var a := out.angle() if out.length() > 0.5 else rng.randf()*TAU
		for k in range(TRIES): ways.append(a+(k/2)*0.12*(1.0 if k%2 == 0 else -1.0))
		return ways
	if layout == "ring":
		var count := int((m.role_data.get("count",Vector2i(1,1)) as Vector2i).y)
		var a := ring_base+TAU*float(m.index)/maxf(count,1)
		for k in range(TRIES): ways.append(a+(k/2)*0.15*(1.0 if k%2 == 0 else -1.0))
		return ways
	if layout == "chain" and parent.has("from_angle"):
		for k in range(TRIES): ways.append(float(parent.from_angle)+rng.randf_range(-1.1,1.1)*(1.0+k*0.05))
		return ways
	for k in range(TRIES): ways.append(rng.randf()*TAU)
	return ways

## Where `m` stands laid `gap` m rim to rim from `parent` along `angle`.
static func _beyond(parent: Dictionary, m: Dictionary, angle: float, gap: float) -> Vector3:
	var way := Vector2.from_angle(angle)
	var d: float = parent.shape.rim_radius(angle)+gap+m.shape.rim_radius(angle+PI)
	m.from_angle = angle
	return Vector3(parent.offset.x+way.x*d,m.y,parent.offset.z+way.y*d)

## True when `m` at `at` keeps `gap` clear of every placed member's rim
## (`except` excepted, kept `except_gap` clear).
static func _clear(m: Dictionary, at: Vector3, placed: Array, gap: float, except := {}, except_gap := 0.0) -> bool:
	for p: Dictionary in placed:
		var need := except_gap if p == except else gap
		if rim_gap(m.rim,at,p.rim,p.offset) < need: return false
	return true

## The narrowest gap (m, plate plane) between two rims standing at `a_at`
## and `b_at`; negative where one reaches into the other's middle.
static func rim_gap(a: PackedVector2Array, a_at: Vector3, b: PackedVector2Array, b_at: Vector3) -> float:
	var off := Vector2(b_at.x-a_at.x,b_at.z-a_at.z)
	var reach_a := 0.0
	var reach_b := 0.0
	for p in a: reach_a = maxf(reach_a,p.length())
	for p in b: reach_b = maxf(reach_b,p.length())
	if off.length() > reach_a+reach_b+4.0: return off.length()-reach_a-reach_b
	# Inside: a rim point of one inside the other's polygon.
	for p in a:
		if Geometry2D.is_point_in_polygon(p-off,b): return -1.0
	for p in b:
		if Geometry2D.is_point_in_polygon(p+off,a): return -1.0
	var best := INF
	for i in range(a.size()):
		var a0 := a[i]
		var a1 := a[(i+1)%a.size()]
		for j in range(b.size()):
			var q := b[j]+off
			best = minf(best,q.distance_to(Geometry2D.get_closest_point_to_segment(q,a0,a1)))
	for j in range(b.size()):
		var b0 := b[j]+off
		var b1 := b[(j+1)%b.size()]+off
		for i in range(a.size()):
			best = minf(best,a[i].distance_to(Geometry2D.get_closest_point_to_segment(a[i],b0,b1)))
	return best

## A rope bridge from `parent` to `m` at `at` would span within a
## footbridge's reach, at a gentle grade, over nothing else.
static func _bridgeable(parent: Dictionary, m: Dictionary, at: Vector3, placed: Array) -> bool:
	var ends := _bridge_ends(parent,m,at)
	var span := Vector2(ends[1].x-ends[0].x,ends[1].z-ends[0].z).length()
	if span > Footbridge.MAX_SPAN-1.0 or span < 3.0: return false
	if absf(ends[1].y-ends[0].y) > span*Footbridge.MAX_GRADE*0.85: return false
	for p: Dictionary in placed:
		if p == parent: continue
		for k in range(1,10):
			var q: Vector3 = parent.offset+(ends[0] as Vector3).lerp(ends[1],k/10.0)
			if p.shape.inside(Vector2(q.x-p.offset.x,q.z-p.offset.z)): return false
	return true

## A bridge's two deck ends, in the parent's frame, from `parent` to `m`
## standing at `at`: each BRIDGE_INSET in from its rim on the line between
## their middles, on the ground there.
static func _bridge_ends(parent: Dictionary, m: Dictionary, at: Vector3) -> Array:
	var off: Vector3 = at-(parent.offset as Vector3)
	var way := Vector2(off.x,off.z).normalized()
	var a2: Vector2 = way*(parent.shape.rim_radius(way.angle())-BRIDGE_INSET)
	var b_local: Vector2 = -way*(m.shape.rim_radius((-way).angle())-BRIDGE_INSET)
	var b2 := b_local+Vector2(off.x,off.z)
	return [Vector3(a2.x,parent.shape.ground_at(a2)+0.05,a2.y),Vector3(b2.x,m.shape.ground_at(b_local)+off.y+0.05,b2.y)]

## A run of stepping stones from `parent` to `m`: each stone a small islet
## STONE_GAP on from the last, `m` STONE_GAP past the last stone; the
## heights stepping evenly, at most STONE_RISE a step. Stones join the
## plan's members and its routes.
static func _lay_stones(m: Dictionary, parent: Dictionary, rel: Dictionary, placed: Array, plan: Dictionary, rng: RandomNumberGenerator) -> bool:
	var counts: Vector2i = rel.get("stones",Vector2i(2,3))
	var n := rng.randi_range(counts.x,counts.y)
	var y_from: float = parent.offset.y
	var limit := STONE_RISE*(n+1)
	m.y = clampf(m.y,y_from-limit,y_from+limit)
	var stones: Array = []
	var radii: Array = rel.get("stone_radius",[])
	for k in range(n):
		var r: float = float(radii[k]) if k < radii.size() else rng.randf_range(STONE_RADIUS.x,STONE_RADIUS.y)
		var spec := {"kind":"hills","radius":r,"dome":0.15,"mounds":[],"trees":Vector2i(0,0),"undergrowth":0.5,
			"rock":m.shape.recipe.get("rock",{}),"keel":float(m.shape.recipe.get("keel",1.0))}
		var stone_seed: int = hash([plan.seed,m.name,"stone",k]) & 0xffffff
		if m.role_data.has("seed"): stone_seed = 40031+k*977
		var shape: RefCounted = SkyIslet.author(stone_seed,spec)
		stones.append({"name":"%s_stone%d" % [m.name,k],"role":"stone","role_data":{},"index":k,"seed":stone_seed,"shape":shape,
			"y":lerpf(y_from,m.y,float(k+1)/(n+1)),"rim":_rim(shape),"features":[],"offset":Vector3.ZERO})
	var ways: Array = []
	if rel.has("angle"):
		for k in range(9): ways.append((rel.angle as Vector2).angle()+(k/2)*0.08*(1.0 if k%2 == 0 else -1.0))
	else:
		for k in range(TRIES): ways.append(rng.randf()*TAU)
	var swings: Array = rel.get("swings",[])
	for base: float in ways:
		var prev := parent
		var ok := true
		var chain := stones+[m]
		var laid: Array = []
		for k in range(chain.size()):
			var s: Dictionary = chain[k]
			var swing: float = float(swings[k]) if k < swings.size() else (rng.randf_range(-0.3,0.3) if k < n else 0.0)
			var at := _beyond(prev,s,base+swing,rng.randf_range(STONE_GAP.x,STONE_GAP.y))
			if not _clear(s,at,placed+laid,MIN_GAP,prev,STONE_GAP.x*0.8) or rim_gap(prev.rim,prev.offset,s.rim,at) > STONE_MAX-0.15:
				ok = false
				break
			s.offset = at
			laid.append(s)
			prev = s
		if not ok: continue
		for s: Dictionary in stones: placed.append(s)
		var route: Array = [parent.name]
		for s: Dictionary in stones: route.append(s.name)
		route.append(m.name)
		plan.routes.append(route)
		return true
	return false

# --- 3. Bridges ---------------------------------------------------------------------

static func _bridge(parent: Dictionary, m: Dictionary, plan: Dictionary) -> void:
	var ends := _bridge_ends(parent,m,m.offset)
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	parent.shape.decks.append({"a":a,"b":b,"width":Footbridge.WIDTH,"bow":Footbridge.bow(span)})
	parent.shape.reach = maxf(parent.shape.reach,Vector2(b.x,b.z).length()+1.0)
	# Clear the bridge's heads of what grows, and a lantern post by each.
	var off: Vector3 = (m.offset as Vector3)-(parent.offset as Vector3)
	var b_local := Vector2(b.x-off.x,b.z-off.z)
	parent.shape.claim(Vector2(a.x,a.z),1.1,0.0)
	m.shape.claim(b_local,1.1,0.0)
	var way := Vector2(b.x-a.x,b.z-a.z).normalized()
	var across := Vector2(-way.y,way.x)
	for end: Array in [[parent,Vector2(a.x,a.z)-way*0.4+across*0.8,way],[m,b_local+way*0.4+across*0.8,-way]]:
		var who: Dictionary = end[0]
		var at: Vector2 = end[1]
		if who.shape.on_land(at) and not who.shape.wet(at):
			who.features.append({"type":"post","at":at,"angle":atan2(-(end[2] as Vector2).x,-(end[2] as Vector2).y)+PI})
	plan.bridges.append({"from":parent.name,"to":m.name,"a":a,"b":b,"span":span})

# --- 4. Features --------------------------------------------------------------------

static func _feature(m: Dictionary, f: Dictionary, placed: Array, centre: Vector3, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var outward := Vector2(m.offset.x-centre.x,m.offset.z-centre.z)
	outward = outward.normalized() if outward.length() > 0.5 else Vector2.from_angle(rng.randf()*TAU)
	var prefer: Dictionary = f.get("prefer",{}) if f.get("prefer",{}) is Dictionary else {}
	match str(f.type):
		"cabin":
			var at: Variant = shape.find_spot(CABIN,0.5,0.9,[],prefer if not prefer.is_empty() else {"middle":0.6})
			if at == null: _missing(m,f,plan); return
			var p: Vector2 = at
			shape.claim(p,CABIN)
			# The door faces in toward the land's middle (the model's door is +Z).
			var inward := -p if p.length() > 1.0 else Vector2.from_angle(rng.randf()*TAU)
			var angle := atan2(inward.x,inward.y)+rng.randf_range(-0.4,0.4)
			shape.add_record("cabin",p,angle,1.0)
			m.features.append({"type":"cabin","at":p,"angle":angle})
		"field":
			var half := Vector2(rng.randf_range(3.2,4.4),rng.randf_range(2.8,4.0))
			var at: Variant = shape.find_spot(0.0,0.6,1.2,[],prefer,half)
			if at == null: _missing(m,f,plan); return
			var p: Vector2 = at
			shape.claim(p,0.0,0.0,half)
			var rect := Rect2(p-half,half*2.0)
			shape.soil.append(rect)
			var z := rect.position.y+0.3
			while z < rect.end.y-0.2:
				var x := rect.position.x+0.3
				while x < rect.end.x-0.2:
					shape.add_record("wheat",Vector2(x+rng.randf_range(-0.05,0.05),z+rng.randf_range(-0.04,0.04)),rng.randf()*TAU,
						rng.randf_range(0.82,0.95),MeadowTypes.tint("wheat",rng.randf()))
					x += 0.24
				z += 0.42
			m.features.append({"type":"field","rect":rect})
		"lamps":
			var count: Vector2i = f.get("count",Vector2i(2,2))
			var cabin := _find(m,"cabin")
			var near: Vector2 = cabin.at if not cabin.is_empty() else Vector2.ZERO
			for k in range(rng.randi_range(count.x,count.y)):
				var at: Variant = shape.find_spot(LAMP,0.4,0.5,[],{"near":near+Vector2.from_angle(rng.randf()*TAU)*4.0,"near_weight":1.0})
				if at == null: continue
				shape.claim(at,LAMP)
				shape.add_record("stone_lamp",at,rng.randf()*TAU,1.0)
				m.features.append({"type":"lamp","at":at})
		"bearer":
			var cabin := _find(m,"cabin")
			if cabin.is_empty(): return
			var pose := Transform3D(Basis(Vector3.UP,float(cabin.angle)),Vector3(cabin.at.x,0.0,cabin.at.y))
			var door: Vector3 = pose*((Cabin.info().door as Vector3)+Vector3(0.9,0.0,1.1))
			var at := Vector2(door.x,door.z)
			if not shape.on_land(at) or shape.wet(at) or shape.inland(at) < 0.3: return
			m.features.append({"type":"bearer","at":at,"angle":float(cabin.angle)+0.4})
		"windmill":
			var at: Variant = shape.find_spot(MILL,0.3,1.8,[],{"high":1.0,"middle":0.4})
			if at == null: _missing(m,f,plan); return
			shape.claim(at,MILL)
			m.features.append({"type":"windmill","at":at,"angle":atan2(-outward.x,-outward.y)})
		"lighthouse":
			var at: Variant = shape.find_spot(LIGHT,0.3,1.8,[],{"toward":outward,"toward_weight":2.0,"middle":0.2})
			if at == null: _missing(m,f,plan); return
			shape.claim(at,LIGHT)
			var inward := -(at as Vector2)
			m.features.append({"type":"lighthouse","at":at,"angle":atan2(-inward.x,-inward.y) if inward.length() > 0.5 else 0.0})
		"lookout":
			var at: Variant = shape.find_spot(0.9,0.6,0.7,[],{"high":3.0})
			if at == null: return
			shape.claim(at,0.9)
			shape.add_record("stone_lamp",at+Vector2(0.5,0.3),0.2,1.0)
			m.features.append({"type":"lamp","at":at+Vector2(0.5,0.3)})
		"dock":
			_dock(m,f,placed,outward,rng,plan)
		"fisher":
			var dock := _find(m,"dock")
			if dock.is_empty(): return
			var a: Vector3 = dock.a
			var b: Vector3 = dock.b
			var way := Vector2(b.x-a.x,b.z-a.z).normalized()
			var at := Vector2(b.x,b.z)-way*0.45+Vector2(-way.y,way.x)*0.25
			m.features.append({"type":"fisher","at":at,"angle":atan2(-way.x,-way.y),"deck_y":a.y})
		"garden", "hives":
			Stack.feature(m,f,rng,plan)

static func _missing(m: Dictionary, f: Dictionary, plan: Dictionary) -> void:
	if float(f.get("chance",1.0)) >= 1.0: plan.problems.append("no room for the %s on %s" % [f.type,m.name])

static func _find(m: Dictionary, type: String) -> Dictionary:
	for f: Dictionary in m.features:
		if f.type == type: return f
	return {}

## The dock: off the rim where the sky is most open (its end and the air
## DOCK_CLEAR beyond it farthest from every other member), its head on the
## land, the deck reaching DOCK_LENGTH out into the air.
static func _dock(m: Dictionary, f: Dictionary, placed: Array, outward: Vector2, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var length := rng.randf_range(DOCK_LENGTH.x,DOCK_LENGTH.y)
	var best: Variant = null
	var best_score := -INF
	var lean: Vector2 = f.get("prefer",outward) if f.get("prefer",null) is Vector2 else outward
	for k in range(36):
		var angle := TAU*k/36.0
		var way := Vector2.from_angle(angle)
		var start: Vector2 = way*(shape.rim_radius(angle)-1.2)
		if not shape.on_land(start) or shape.wet(start): continue
		var end := start+way*length
		var clear := INF
		for t in [0.5,1.0,1.6,2.4]:
			var q: Vector2 = start+way*length*float(t)+Vector2(m.offset.x,m.offset.z)
			if shape.on_land(start+way*length*float(t)): clear = minf(clear,-1.0)
			for p: Dictionary in placed:
				if p == m: continue
				clear = minf(clear,_distance_to_rim(p,q))
		if clear < DOCK_CLEAR: continue
		var score := minf(clear,30.0)+way.dot(lean.normalized())*8.0
		if score > best_score:
			best_score = score
			best = [start,end]
	if best == null: _missing(m,f,plan); return
	var start: Vector2 = best[0]
	var end: Vector2 = best[1]
	shape.claim(start,1.2)
	var y: float = shape.ground_at(start)+0.12
	var a := Vector3(start.x,y,start.y)
	var b := Vector3(end.x,y,end.y)
	shape.decks.append({"a":a,"b":b,"width":DOCK_WIDTH,"bow":0.0})
	shape.reach = maxf(shape.reach,end.length()+1.0)
	m.features.append({"type":"dock","a":a,"b":b})

## How far plate point `q` (cluster frame) lies from member `p`'s rim,
## 0 inside it.
static func _distance_to_rim(p: Dictionary, q: Vector2) -> float:
	var local := q-Vector2(p.offset.x,p.offset.z)
	var rim: PackedVector2Array = p.rim
	if Geometry2D.is_point_in_polygon(local,rim): return 0.0
	var best := INF
	for i in range(rim.size()):
		best = minf(best,local.distance_to(Geometry2D.get_closest_point_to_segment(local,rim[i],rim[(i+1)%rim.size()])))
	return best

# --- Validation -----------------------------------------------------------------------

## What is wrong with a plan, as sentences; empty when nothing is: members
## overlapping, stepping stones too far apart or too high to jump, a bridge
## too long or steep or with an end off the land, a record off the rim,
## anything built off the land, in water or on uneven ground (floating),
## a dock running into another member, and whatever could not be laid.
static func validate(plan: Dictionary) -> Array:
	var problems: Array = (plan.problems as Array).duplicate()
	var members: Array = plan.members
	var by_name := {}
	var rims := {}
	for m: Dictionary in members:
		by_name[m.name] = m
		rims[m.name] = _rim(m.shape)
	for i in range(members.size()):
		for j in range(i+1,members.size()):
			var a: Dictionary = members[i]
			var b: Dictionary = members[j]
			if rim_gap(rims[a.name],a.offset,rims[b.name],b.offset) < 0.5 and not Stack.stacked(a,b): problems.append("overlap: %s and %s" % [a.name,b.name])
	for route: Array in plan.routes:
		for k in range(route.size()-1):
			var a: Dictionary = by_name[route[k]]
			var b: Dictionary = by_name[route[k+1]]
			var gap := rim_gap(rims[a.name],a.offset,rims[b.name],b.offset)
			if gap > STONE_MAX: problems.append("unjumpable: %s to %s is %.2f m" % [a.name,b.name,gap])
			if absf(b.offset.y-a.offset.y) > float(PilotMotor.JUMPS[1]): problems.append("unjumpable: %s to %s rises %.2f m" % [a.name,b.name,absf(b.offset.y-a.offset.y)])
	for br: Dictionary in plan.bridges:
		var from: Dictionary = by_name[br.from]
		var to: Dictionary = by_name[br.to]
		var a: Vector3 = br.a
		var b: Vector3 = br.b
		if float(br.span) > Footbridge.MAX_SPAN: problems.append("bridge %s-%s too long (%.1f m)" % [br.from,br.to,br.span])
		if absf(b.y-a.y) > float(br.span)*Footbridge.MAX_GRADE: problems.append("bridge %s-%s too steep" % [br.from,br.to])
		var off: Vector3 = (to.offset as Vector3)-(from.offset as Vector3)
		if not from.shape.on_land(Vector2(a.x,a.z)): problems.append("bridge %s-%s: near end off the land" % [br.from,br.to])
		if not to.shape.on_land(Vector2(b.x-off.x,b.z-off.z)): problems.append("bridge %s-%s: far end off the land" % [br.from,br.to])
		if absf(b.y-(to.shape.ground_at(Vector2(b.x-off.x,b.z-off.z))+off.y)) > 0.35: problems.append("bridge %s-%s: far end floats" % [br.from,br.to])
	for m: Dictionary in members:
		var shape: RefCounted = m.shape
		for o: Dictionary in shape.objects:
			var p := Vector2(o.x,o.z)
			if not shape.on_land(p): problems.append("off the rim: %s on %s" % [o.asset,m.name])
			elif o.asset in ["cabin","stone_lamp","wheat"] and shape.wet(p): problems.append("in water: %s on %s" % [o.asset,m.name])
		for f: Dictionary in m.features:
			match str(f.type):
				"cabin": _footing(shape,f.at,CABIN,"cabin",m.name,problems)
				"windmill": _footing(shape,f.at,MILL,"windmill",m.name,problems)
				"lighthouse": _footing(shape,f.at,LIGHT,"lighthouse",m.name,problems)
				"lamp": _footing(shape,f.at,LAMP,"lamp",m.name,problems)
				"bearer", "post":
					if not shape.on_land(f.at) or shape.wet(f.at): problems.append("off the land or in water: %s on %s" % [f.type,m.name])
				"field":
					var rect: Rect2 = f.rect
					for c: Vector2 in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y),rect.get_center()]:
						if not shape.on_land(c) or shape.wet(c): problems.append("field off the land or in water on %s" % m.name)
				"dock":
					var a: Vector3 = f.a
					var b: Vector3 = f.b
					if not shape.on_land(Vector2(a.x,a.z)): problems.append("dock head off the land on %s" % m.name)
					for p: Dictionary in members:
						if p == m: continue
						var q := Vector2(b.x+m.offset.x,b.z+m.offset.z)
						if _distance_to_rim({"offset":p.offset,"rim":rims[p.name]},q) < 2.0: problems.append("dock on %s runs into %s" % [m.name,p.name])
				"fisher":
					if shape.deck_y(f.at) == -INF: problems.append("fisher off the dock on %s" % m.name)
	problems.append_array(Stack.validate(plan))
	return problems

## A footprint's ground: on the land, dry, in from the rim and level
## (floating or sunk past 0.3 m otherwise).
static func _footing(shape: RefCounted, at: Vector2, radius: float, what: String, member: String, problems: Array) -> void:
	var low := INF
	var high := -INF
	for k in range(9):
		var q := at if k == 8 else at+Vector2.from_angle(TAU*k/8.0)*radius*0.85
		if not shape.on_land(q):
			problems.append("off the rim: %s on %s" % [what,member])
			return
		if shape.wet(q):
			problems.append("in water: %s on %s" % [what,member])
			return
		var h: float = shape.ground_at(q)
		low = minf(low,h)
		high = maxf(high,h)
	if high-low > 0.3: problems.append("floating: %s on %s (ground varies %.2f m)" % [what,member,high-low])
