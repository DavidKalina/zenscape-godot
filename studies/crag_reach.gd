extends "res://studies/kit_isle.gd"
## The crag reach (docs/design/isle-look/spec-crag-reach.md): big land
## masses in the islet unit's crag style (scripts/kit_isle/islet_crag.gd),
## at different heights, with smaller crag islets between and round them
## and small ones far off for depth. He starts on foot on the main mass,
## whose crown is level landing turf (spec `flat`); the plane is parked on
## it (kit_isle.gd `park_home`).
## A mass is one big unit (spec `mass` 1, its size past an islet's) with
## terraces: smaller units set against its flank, their crowns lower, so
## the mass steps down in tiers; a knoll rises over its crown at the edge.
## Every unit is named `crag_reach/<mass>_<part>`, `crag_reach/islet_<n>`
## or `crag_reach/speck_<n>` (scripts/layout_overrides.gd, layouts/
## crag_reach.json): moved and tuned in the world view (F4), it keeps its
## name.
##   godot --path . res://studies/crag_reach.tscn -- --no-title
##     [--no-specks]        without the far small islets
##     [--no-debris]        without any unit's debris

const Layout = preload("res://scripts/layout_overrides.gd")
const UnitNode = preload("res://scripts/kit_isle/islet_unit_node.gd")
const SkyScript = preload("res://studies/islet_yard_sky.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")

## The masses: name, the top unit's middle (x, height off TOP, z), its
## spec; then its parts, each [part, offset from the top's middle (x, dy,
## z), spec]. Specs fill from MASS_BASE / PART_BASE.
const MASSES := [
	["main",Vector3(0.0,0.0,0.0),{"seed":41,"size":36.0,"shape":0.62,"flat":0.95,"landmark":0,"growth":0.72,"weather":0.5,"lopsided":0.6},[
		["terrace_1",Vector3(30.0,-9.0,24.0),{"seed":42,"size":15.0,"shape":0.3,"flat":0.4}],
		["terrace_2",Vector3(-33.0,-15.0,-8.0),{"seed":43,"size":13.0,"shape":0.5,"flat":0.3}],
		["terrace_3",Vector3(8.0,-24.0,38.0),{"seed":44,"size":11.0,"shape":0.75}],
		["knoll",Vector3(-22.0,3.5,24.0),{"seed":45,"size":9.0,"shape":0.25,"landmark":1}],
	]],
	["east",Vector3(80.0,4.0,-12.0),{"seed":51,"size":25.0,"shape":0.5,"flat":0.5,"landmark":0},[
		["terrace_1",Vector3(20.0,-10.0,18.0),{"seed":52,"size":12.0,"shape":0.65}],
		["terrace_2",Vector3(-6.0,-17.0,-24.0),{"seed":53,"size":10.0,"shape":0.4}],
		["knoll",Vector3(14.0,5.0,-8.0),{"seed":54,"size":8.0,"shape":0.9,"landmark":0}],
	]],
	["north",Vector3(4.0,-14.0,-80.0),{"seed":61,"size":28.0,"shape":0.7,"flat":0.6,"landmark":0},[
		["terrace_1",Vector3(-24.0,-8.0,-14.0),{"seed":62,"size":13.0,"shape":0.3}],
		["terrace_2",Vector3(22.0,-20.0,-18.0),{"seed":63,"size":11.0,"shape":0.6}],
	]],
	["west",Vector3(-100.0,11.0,-34.0),{"seed":71,"size":20.0,"shape":0.55,"flat":0.5,"landmark":0},[
		["terrace_1",Vector3(14.0,-11.0,14.0),{"seed":72,"size":10.0,"shape":0.7,"flat":0.7}],
		["spire",Vector3(-12.0,4.0,-10.0),{"seed":73,"size":8.0,"shape":0.92,"landmark":0}],
	]],
]
const MASS_BASE := {"mass":1,"lean":0.2,"drip":0.5,"lopsided":0.5,"growth":0.7,"weather":0.55,"debris":0.35}
const PART_BASE := {"lean":0.25,"drip":0.5,"lopsided":0.5,"growth":0.7,"weather":0.55,"landmark":-1,"debris":0.3}
## The rope bridges between masses: name, from, to, seed. Each end sits on
## its mass's crown rim on the line between the two crowns' middles
## (`_rim_end`), RIM_BACK m in from where the level turf stops, on a stone
## anchor (RuinKit `bridge_anchor`, the broken ring's). The live rope bridge
## (scripts/rope_bridge.gd via Footbridge `live`) sags, bounces and sways
## under him; studies/kit_isle.gd's DeckGround stands him on its planks.
const BRIDGES := [
	["bridge_east","main","east",181],
]
const RIM_BACK := 1.2
## The fallen pillars: name, from (the high mass), to (the low), seed. A
## colossus column (RuinKit's hall drums, scripts/ruin_kit_hall.gd) lies
## from the high crown's rim, its broken top end at the turf there, down
## across the gap, its foot end sunk PILLAR_IN m into the low crown, so its
## top is one long slope from turf to turf. Crouched on it at a run he
## boot-surfs it down (pilot_motor.gd move "slide", steeper than
## SLIDE_FROM); an invisible walk box (PILLAR_DECK m either side of its
## crest) lies along its top so the crest stands as a flat beam, not a
## round ridge he rolls off.
const PILLARS := [
	["pillar_north","main","north",191],
]
const PILLAR_IN := 3.0
const PILLAR_DECK := 0.55
## How far the top end's crest stands over the high crown's turf (a step).
const PILLAR_PROUD := 0.2
## The aqueducts: name, from (a unit), to (a unit), seed. A level run of
## RuinKit aqueduct spans (scripts/ruin_kit_aqueduct.gd), its channel
## floor AQ_LIFT m over the higher rim's turf, from the `from` crown's rim
## (`_rim_end`) on across the gap onto the `to` crown, a pier every SPAN.
## A pier over the void stands on a small crag rock of its own
## (`crag_reach/<name>_rock_<n>`), its top AQ_ROCK_DROP m (give or take
## AQ_ROCK_JITTER) under the deck's foot, so the piers stride across on
## stepping stones. Dry: the water's long gone. He walks the channel.
const AQUEDUCTS := [
	["aqueduct_west","main","west_terrace_1",201],
]
const AQ_LIFT := 0.08
const AQ_ROCK_DROP := 2.0
const AQ_ROCK_JITTER := 3.0
const AQ_ROCK_SIZE := Vector2(3.6,5.0)
## A rim end's turf: within RIM_RISE m of the crown middle's height.
const RIM_RISE := 3.0
## The islets between and round the masses: how many, their distance (m)
## from the main's middle, height off TOP, size; they keep clear of the
## masses.
const ISLETS := 14
const ISLET_AT := Vector2(40.0,190.0)
const ISLET_LIFT := Vector2(-60.0,50.0)
const ISLET_SIZE := Vector2(2.0,7.0)
## The far small islets (no grass past GRASS_NEAR, no debris past 400 m).
const SPECKS := 18
const SPECK_AT := Vector2(230.0,900.0)
const SPECK_LIFT := Vector2(-120.0,170.0)
const SPECK_SIZE := Vector2(3.0,8.0)
const GRASS_NEAR := 260.0

var units: Array = []
var specks := true
var debris := true
## Each mass's top unit and its world middle and radius (x, z, r).
var mass_tops := {}
## Every mass's unit by its short name (`main`, `west_terrace_1`).
var named := {}

func _ready() -> void:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == "--no-specks": specks = false
		elif a == "--no-debris": debris = false
	_no_lode = true
	super._ready()

func _load_pack() -> void:
	stations = []
	start = Vector3(0.0,TOP+1.5,0.0)
	start_face = Vector2(1.0,0.0)
	lost = TOP-160.0
	_last_stood = start

func isle_name() -> String:
	return "crag reach"

func sky_script() -> Script:
	return SkyScript

func capture_look() -> Vector3:
	return Vector3(0.0,TOP-10.0,-20.0)

func isle_circle() -> Vector3:
	return Vector3(0.0,-20.0,700.0)

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	Layout.begin("crag_reach")
	var began := Time.get_ticks_msec()
	for m: Array in MASSES:
		var mname: String = m[0]
		var mid: Vector3 = m[1]
		var top_at := Vector3(mid.x,TOP+mid.y,mid.z)
		var spec: Dictionary = MASS_BASE.merged(m[2],true)
		var n := _stand("crag_reach/%s" % mname,Transform3D(Basis(),top_at),spec)
		if n != null:
			mass_tops[mname] = n
			named[mname] = n
		for part: Array in m[3]:
			var off: Vector3 = part[1]
			var ps: Dictionary = PART_BASE.merged(part[2],true)
			var turn := Basis(Vector3.UP,float(int(ps.seed)%7)*0.9)
			named["%s_%s" % [mname,part[0]]] = _stand("crag_reach/%s_%s" % [mname,part[0]],Transform3D(turn,top_at+off),ps)
	_bridges()
	_pillars()
	_aqueducts()
	_islets()
	if specks: _specks()
	var tris := 0
	var frags := 0
	for u: Node3D in units:
		var st: Dictionary = u.unit.get_meta("stats")
		tris += int(st.get("triangles",0))
		frags += int(st.get("debris",0))
	print("crag reach: %d units, %d triangles, %d debris fragments, built in %d ms" % [units.size(),tris,frags,Time.get_ticks_msec()-began])

## The rope bridges (BRIDGES), each named `crag_reach/<name>`: its node
## moved in the world view moves the whole span with its anchors.
var bridges: Array = []
## Every span's ends [a, b] (bridges and pillars), kept clear of islets.
var spans: Array = []

func _bridges() -> void:
	var space := get_world_3d().direct_space_state
	for br: Array in BRIDGES:
		var name_: String = "crag_reach/"+str(br[0])
		if Layout.deleted(name_) or not mass_tops.has(br[1]) or not mass_tops.has(br[2]): continue
		var from: Node3D = mass_tops[br[1]]
		var to: Node3D = mass_tops[br[2]]
		var a := _rim_end(space,from.position,to.position)
		var b := _rim_end(space,to.position,from.position)
		if a == Vector3.INF or b == Vector3.INF:
			push_warning("crag reach: no rim for %s" % name_)
			continue
		var seed_value: int = br[3]
		var holder := Node3D.new()
		holder.name = str(br[0]).to_pascal_case()
		art.add_child(holder)
		var live: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,seed_value),a,b,seed_value)
		live.name = "Rope"
		holder.add_child(live)
		for end: Array in [[a,b],[b,a]]:
			var anchor := RuinKit.bridge_anchor(seed_value*3+int(end[0] == b),0.45,Footbridge.WIDTH,
				{"post_x":Footbridge.WIDTH*0.5+0.33,"post_z":0.0,"sill":Vector3(0.75,0.11,0.55),"sill_at":Vector3(0.0,-0.11,0.15),
				"plinth":Vector3(1.15,1.4,0.375),"plinth_z":0.2})
			var way: Vector3 = (end[1] as Vector3)-(end[0] as Vector3)
			way.y = 0.0
			anchor.transform = Transform3D(Basis.looking_at(way.normalized(),Vector3.UP),end[0])
			holder.add_child(anchor)
		holder.transform = Layout.xform(name_,Transform3D.IDENTITY)
		Layout.track(name_,holder,"piece",Transform3D.IDENTITY)
		bridges.append(live)
		spans.append([a,b])
		print("crag reach: %s %s -> %s, span %.1f m, rise %.1f m" % [name_,a,b,Vector2(b.x-a.x,b.z-a.z).length(),b.y-a.y])

## The fallen pillars (PILLARS), each named `crag_reach/<name>`; the crest
## line's ends (top, foot) in `pillars` [name, a, b] for the drive.
var pillars: Array = []

func _pillars() -> void:
	var space := get_world_3d().direct_space_state
	for pl: Array in PILLARS:
		var name_: String = "crag_reach/"+str(pl[0])
		if Layout.deleted(name_) or not mass_tops.has(pl[1]) or not mass_tops.has(pl[2]): continue
		var hi: Vector3 = (mass_tops[pl[1]] as Node3D).position
		var lo: Vector3 = (mass_tops[pl[2]] as Node3D).position
		var a := _rim_end(space,hi,lo)
		var b := _rim_end(space,lo,hi)
		if a == Vector3.INF or b == Vector3.INF:
			push_warning("crag reach: no rim for %s" % name_)
			continue
		# The foot sunk PILLAR_IN m further into the low crown.
		var inward := Vector2(lo.x-b.x,lo.z-b.z).normalized()*PILLAR_IN
		var sunk := _turf_top(space,b.x+inward.x,b.z+inward.y)
		if sunk != Vector3.INF: b = sunk
		a.y += PILLAR_PROUD
		var seed_value: int = pl[3]
		var column := fallen_column(seed_value,a,b)
		column.name = str(pl[0]).to_pascal_case()
		art.add_child(column)
		column.transform = Layout.xform(name_,column.transform)
		Layout.track(name_,column,"piece",column.transform)
		pillars.append([name_,a,b])
		spans.append([a,b])
		print("crag reach: %s %s -> %s, length %.1f m, slope %.1f deg" % [name_,a,b,a.distance_to(b),rad_to_deg(asin((a.y-b.y)/a.distance_to(b)))])

## The aqueducts (AQUEDUCTS), each named `crag_reach/<name>`: a holder at
## the run's frame (moved in F4, the whole run moves; its rocks are their
## own units). `aqueducts` holds [name, a, b] (the channel's walk line,
## world) for the drive.
var aqueducts: Array = []

func _aqueducts() -> void:
	var space := get_world_3d().direct_space_state
	for aq: Array in AQUEDUCTS:
		var name_: String = "crag_reach/"+str(aq[0])
		if Layout.deleted(name_) or named.get(aq[1]) == null or named.get(aq[2]) == null: continue
		var from: Vector3 = (named[aq[1]] as Node3D).position
		var to: Vector3 = (named[aq[2]] as Node3D).position
		var a := _rim_end(space,from,to)
		var b := _rim_end(space,to,from)
		if a == Vector3.INF or b == Vector3.INF:
			push_warning("crag reach: no rim for %s" % name_)
			continue
		var seed_value: int = aq[3]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value,"aqueduct"])
		# Level: the channel floor just over the higher end's turf; the run
		# starts at `a` and runs on past `b` to a whole number of spans.
		var deck := maxf(a.y,b.y)+AQ_LIFT
		var way := Vector3(b.x-a.x,0.0,b.z-a.z)
		var count := int(ceil(way.length()/Aqueduct.SPAN))
		way = way.normalized()
		var frame := Transform3D(Basis(way,Vector3.UP,way.cross(Vector3.UP)),Vector3(a.x,deck-Aqueduct.DECK,a.z))
		# A rock under each pier over the void.
		var base := deck-Aqueduct.DECK
		for i in range(count+1):
			var p := frame*Vector3(Aqueduct.SPAN*i,0.0,0.0)
			if _ground_under(space,p.x,p.z,deck) > base-AQ_ROCK_DROP-AQ_ROCK_JITTER: continue
			var size := rng.randf_range(AQ_ROCK_SIZE.x,AQ_ROCK_SIZE.y)
			var spec := {"seed":seed_value*10+i,"size":size,"shape":rng.randf_range(0.2,0.8),"flat":0.6,"lean":rng.randf()*0.4,
				"drip":rng.randf_range(0.4,0.9),"lopsided":rng.randf()*0.5,"growth":rng.randf_range(0.55,0.8),"weather":0.6,
				"landmark":-1,"debris":0.2}
			var at := Vector3(p.x,base-AQ_ROCK_DROP-rng.randf_range(0.0,AQ_ROCK_JITTER),p.z)
			_stand("%s_rock_%d" % [name_,i],Transform3D(Basis(Vector3.UP,rng.randf()*TAU),at),spec)
		# The spans, each on the ground under it (the crowns, the rocks).
		var root := Node3D.new()
		root.name = str(aq[0]).to_pascal_case()
		for i in range(count):
			var at := Transform3D(Basis.IDENTITY,Vector3(Aqueduct.SPAN*(i+0.5),0.0,0.0))
			var world := frame*at
			var ground := func(x: float, z: float) -> float:
				var w := world*Vector3(x,0.0,z)
				return _ground_under(space,w.x,w.z,deck)-base
			var span := Aqueduct.span(seed_value+i,clampf(0.5+rng.randf_range(-0.15,0.2),0.0,1.0),3 if i == 0 else 2,false,ground)
			span.transform = at
			root.add_child(span)
		RuinKit.merge(root)
		art.add_child(root)
		root.transform = Layout.xform(name_,frame)
		Layout.track(name_,root,"piece",frame)
		var end := frame*Vector3(Aqueduct.SPAN*count,Aqueduct.DECK,0.0)
		aqueducts.append([name_,Vector3(a.x,deck,a.z),end])
		spans.append([Vector3(a.x,deck,a.z),end])
		print("crag reach: %s %s -> %s, %d spans, deck %.1f (rims %.1f, %.1f)" % [name_,a,end,count,deck,a.y,b.y])

## The ground (any body) under (x, z) from over `over`: its height, or far
## under the deck (a pier left hanging) where there is none.
func _ground_under(space: PhysicsDirectSpaceState3D, x: float, z: float, over: float) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x,over+20.0,z),Vector3(x,over-60.0,z))
	var hit := space.intersect_ray(ray)
	if hit.is_empty(): return over-Aqueduct.DECK-AQ_ROCK_DROP-AQ_ROCK_JITTER-6.0
	return (hit.position as Vector3).y

## A colossus column fallen with its crest along `a` -> `b` (world): hall
## drums (plain, a niche band, a roundel band) laid end to end along its
## axis, a little out of line as they came to rest, its top end at `a`
## snapped off, its foot running on past `b` into the ground; a walk box
## along its crest. The node's frame: X along it, Y square up off it, the
## origin on its axis under `a`.
static func fallen_column(seed_value: int, a: Vector3, b: Vector3) -> Node3D:
	var along := (b-a).normalized()
	var up := (Vector3.UP-along*along.y).normalized()
	var r := Hall.COLUMN_R
	var length := a.distance_to(b)+r*2.5
	var b_ := RuinKit.Build.new(seed_value,0.55,"FallenColumn")
	b_.settle = Hall.SETTLE
	b_.lean = true
	b_.cull = true
	# Drums along +X: the shaft's own drum stretch (a man's height and a
	# half), the niche and roundel bands once each a third and two thirds in.
	var lie := Basis(Vector3.BACK,-PI*0.5)
	var x := 0.0
	var k := 0
	while x < length-0.3:
		var kind := "plain"
		var h := 1.5
		if k == 4: kind = "niche"
		elif k == 9: kind = "roundel"
		if kind == "niche": h = Hall.NICHE_BAND
		elif kind == "roundel": h = Hall.ROUNDEL_BAND
		h = minf(h,length-x)
		var extra: Array = []
		# The top end snapped off: the first drum broken at its near face.
		if k == 0: extra = RuinKit._break(b_,h,r,0.35,0.0)
		var spin := Basis(Vector3.UP,b_.rng.randf()*TAU)
		var off := Vector3(0.0,b_.rng.randf_range(-0.03,0.03),b_.rng.randf_range(-0.05,0.05))
		if k == 0:
			# Turned end for end so its break faces up the slope (-X).
			Hall._drum(b_,Transform3D(Basis(Vector3.BACK,PI*0.5)*spin,Vector3(x+h,0.0,0.0)+off),kind,h,extra)
		else:
			Hall._drum(b_,Transform3D(lie*spin,Vector3(x,0.0,0.0)+off),kind,h,extra)
		x += h+0.02
		k += 1
	var deck := a.distance_to(b)+r
	RuinKit._walk_hull(b_,Transform3D.IDENTITY,[Plane(Vector3.LEFT,0.0),Plane(Vector3.RIGHT,deck),Plane(Vector3.UP,r+0.02),
		Plane(Vector3.DOWN,-(r-0.6)),Plane(Vector3.BACK,PILLAR_DECK),Plane(Vector3.FORWARD,PILLAR_DECK)])
	var node := b_.finish()
	node.transform = Transform3D(Basis(along,up,along.cross(up)),a-up*(r+0.02))
	return node

## Where a bridge from the crown at `mid` toward `other` ends: walking out
## from the middle, the last level turf near the crown's height before it
## stops (the rim), RIM_BACK m back in. INF when none.
func _rim_end(space: PhysicsDirectSpaceState3D, mid: Vector3, other: Vector3) -> Vector3:
	var way := Vector2(other.x-mid.x,other.z-mid.z)
	var far := way.length()
	way /= far
	var last := Vector3.INF
	var d := 2.0
	while d < far:
		var p := Vector2(mid.x,mid.z)+way*d
		var top := _turf_top(space,p.x,p.y)
		if top == Vector3.INF or absf(top.y-mid.y) > RIM_RISE:
			if last != Vector3.INF: break
		else:
			last = top
		d += 0.25
	if last == Vector3.INF: return last
	var back := Vector2(last.x,last.z)-way*RIM_BACK
	var top := _turf_top(space,back.x,back.y)
	return top if top != Vector3.INF else last

## The masses' footprints (x, z, reach) to keep islets clear of.
func _clear_of(p: Vector3, r: float) -> bool:
	for u: Node3D in units:
		var q: Vector3 = u.position
		var reach := float(u.spec.size)*1.25+r+6.0
		if Vector2(p.x-q.x,p.z-q.z).length() < reach and absf(p.y-q.y) < float(u.spec.size)*2.5+r: return false
	# Clear of the spans too: nothing in a bridge's way or hung under it.
	for span: Array in spans:
		var a: Vector3 = span[0]
		var b: Vector3 = span[1]
		var near := Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),Vector2(a.x,a.z),Vector2(b.x,b.z))
		if near.distance_to(Vector2(p.x,p.z)) < r*1.25+8.0 and p.y > minf(a.y,b.y)-30.0 and p.y < maxf(a.y,b.y)+10.0: return false
	return true

## Smaller crag islets between and round the masses, at many heights.
func _islets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crag_reach_islets")
	var placed := 0
	var tries := 0
	while placed < ISLETS and tries < 400:
		tries += 1
		var a := rng.randf()*TAU
		var d := rng.randf_range(ISLET_AT.x,ISLET_AT.y)
		var size := lerpf(ISLET_SIZE.x,ISLET_SIZE.y,pow(rng.randf(),1.5))
		var at := Vector3(cos(a)*d+20.0,TOP+rng.randf_range(ISLET_LIFT.x,ISLET_LIFT.y),sin(a)*d-30.0)
		if not _clear_of(at,size): continue
		placed += 1
		var spec := {"seed":300+placed,"size":size,"shape":rng.randf(),"lean":rng.randf(),"drip":rng.randf(),
			"lopsided":rng.randf(),"growth":rng.randf_range(0.5,0.85),"weather":rng.randf_range(0.4,0.8),
			"landmark":-1,"debris":0.25}
		var n := _stand("crag_reach/islet_%d" % placed,Transform3D(Basis(Vector3.UP,rng.randf()*TAU),at),spec)
		if n != null and size < 4.0: n.set_drift(rng.randf_range(0.15,0.4),int(spec.seed))

## Small islets far off, for depth.
func _specks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crag_reach_specks")
	for i in SPECKS:
		var a := TAU*(i+rng.randf_range(-0.4,0.4))/SPECKS
		var d := SPECK_AT.x*pow(SPECK_AT.y/SPECK_AT.x,rng.randf())
		var at := Vector3(cos(a)*d,TOP+rng.randf_range(SPECK_LIFT.x,SPECK_LIFT.y),sin(a)*d)
		var size := lerpf(SPECK_SIZE.x,SPECK_SIZE.y,rng.randf())*lerpf(1.0,2.0,clampf(d/SPECK_AT.y,0.0,1.0))
		var spec := {"seed":600+i,"size":size,"shape":rng.randf(),"lean":rng.randf(),"drip":rng.randf(),
			"lopsided":rng.randf(),"growth":rng.randf_range(0.45,0.85),"weather":rng.randf_range(0.3,0.9),
			"landmark":(-1 if d < 400.0 else 0),"grass":(1.0 if d < GRASS_NEAR else 0.0),"debris":(0.25 if d < 400.0 else 0.0)}
		_stand("crag_reach/speck_%d" % (i+1),Transform3D(Basis(Vector3.UP,rng.randf()*TAU),at),spec)

func _stand(name_: String, coded: Transform3D, spec: Dictionary) -> Node3D:
	if Layout.deleted(name_): return null
	if not debris: spec = spec.merged({"debris":0.0},true)
	var n: Node3D = UnitNode.new()
	n.name = name_.get_slice("/",1).to_pascal_case()
	art.add_child(n)
	n.setup(Layout.xform(name_,coded),spec)
	Layout.track(name_,n,"piece",coded)
	for b: StaticBody3D in n.turf_bodies():
		b.collision_layer |= TURF_LAYER
		_turf_rids.append(b.get_rid())
		_turf.append(b)
	_outlines.append(n.world_outline())
	units.append(n)
	return n

## The units grow their own grass (KitFlora, each over its own crown).
func _grow() -> void:
	flora_ready = true

## No kit life (its undergrowth and flowers are another palette).
func _add_life() -> void:
	pass
