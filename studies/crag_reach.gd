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
##     [--olmec]            the whole Olmec (the headless body, its inhaler
##                          head on) hunting you from the start: he comes up
##                          a cliff face of the crown you stand on, out of
##                          your view, hauls over the lip and hunts you
##                          (relentless; he leaps gaps, and with the body's
##                          `leap_catch` on, a leap that meets a face is
##                          caught and climbed, and he throws himself at a
##                          face across a gap too wide to land over)
##     [--olmec-after=N]    the same, N s after you start (a late threat)
##     [--body-knob=<knob>=<value>] over his knobs (repeatable)
##     [--greed-run]        the greed run (studies/crag_reach_greed.gd):
##                          the loot bag on his back, loot over the crag,
##                          the plane's rope hook to hitch it to
##   With the Olmec out: Tab / R3 lock on, X the gust shot (its charge
##   refills on foot), R you back at the start and him gone, up a cliff
##   again (at once with --olmec, N s on with --olmec-after); fallen off the
##   world, he comes up another cliff OLMEC_AGAIN s later.

const Layout = preload("res://scripts/layout_overrides.gd")
const UnitNode = preload("res://scripts/kit_isle/islet_unit_node.gd")
const SkyScript = preload("res://studies/islet_yard_sky.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const BreakKinds = preload("res://scripts/kit_isle/break_kinds.gd")

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
## The ruins seated on the masses' crowns and terraces: name, the unit
## (its short name in `named`), the offset (world x, z) from its middle,
## the piece, its turn (deg), seed, weathered, and for the built-up ones
## their size. A piece is a RuinKit id (scripts/ruin_kit.gd ALL_PIECES), or
## "hall" (a colossus hall of `bays` bays, scripts/ruin_kit_hall.gd `hall`,
## its nave along the turn, centred on the spot) or "colonnade" (`count`
## hall columns in a row `step` m apart along the turn, the odd one snapped
## or fallen). Each stands on the ground under it (its rubble on the turf,
## none over the drop), sunk RUIN_SINK m. Nothing within RUIN_CLEAR m of
## the parked plane's takeoff line (landing turf, AGENTS.md), nor RUIN_SPAN
## m of a span's end at its height.
const RUINS := [
	["ruin_east_hall","east",Vector2(-2.0,0.0),"hall",0.0,211,0.75,{"bays":2}],
	["ruin_east_turret","east_terrace_1",Vector2(1.0,1.0),"turret",200.0,212,0.5,{}],
	["ruin_north_colonnade","north",Vector2(-4.0,-9.0),"colonnade",8.0,221,0.55,{"count":5,"step":7.0}],
	["ruin_north_chest","north_terrace_1",Vector2(0.0,0.0),"tomb_chest",35.0,222,0.6,{}],
	["ruin_west_tower","west",Vector2(-2.0,2.0),"tower_shell",40.0,231,0.6,{}],
	["ruin_west_wall","west_terrace_1",Vector2(-5.0,5.0),"lancet_wall",120.0,232,0.55,{}],
	["ruin_main_gable","main_terrace_1",Vector2(0.0,0.0),"rose_gable",210.0,241,0.5,{}],
	["ruin_main_arch","main_terrace_2",Vector2(0.0,0.0),"arch",80.0,242,0.6,{}],
	["ruin_main_circle","main_knoll",Vector2(0.0,0.0),"stone_circle",0.0,243,0.5,{}],
	["ruin_main_pier","main",Vector2(16.0,-17.0),"pier",15.0,244,0.55,{}],
	["ruin_main_fallen","main",Vector2(18.0,22.0),"fallen_pier",60.0,245,0.5,{}],
]
const RUIN_SINK := 0.15
const RUIN_CLEAR := 12.0
const RUIN_SPAN := 7.0
const RUIN_VOID := 4.0
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
## Debris (spec item 4): the masses keep theirs (MASS_BASE / PART_BASE),
## gathered under them; the strays between them are cut: the islets', the
## aqueduct's stepping rocks' and the near specks' amounts are low. Then
## every fragment within SPAN_CLEAR m (sideways) of a route's line, from
## SPAN_BELOW m under it to SPAN_ABOVE over, is left out (`_clear_spans`),
## so nothing hangs in a bridge's, pillar's or channel's way.
const ISLET_DEBRIS := 0.12
const ROCK_DEBRIS := 0.08
const SPECK_DEBRIS := 0.1
const SPAN_CLEAR := 5.0
const SPAN_BELOW := 14.0
const SPAN_ABOVE := 6.0

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
		elif a == "--olmec": olmec_after = 0.0
		elif a.begins_with("--olmec-after="): olmec_after = maxf(float(a.get_slice("=",1)),0.0)
		elif a == "--greed-run": greed_on = true
		elif a.begins_with("--body-knob="):
			var kv: String = a.trim_prefix("--body-knob=")
			_body_knobs[kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	bag_on = greed_on
	_no_lode = true
	_olmec_due = olmec_after
	# The greed run builds him (and the breaks) always; greed fires him.
	kit_breaks_on = olmec_after >= 0.0 or greed_on
	olmec_armed = olmec_after >= 0.0
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
	_ruins()
	_islets()
	if specks: _specks()
	var cleared := _clear_spans()
	var tris := 0
	var frags := 0
	var by := {"mass":0,"rock":0,"islet":0,"speck":0}
	for u: Node3D in units:
		var st: Dictionary = u.unit.get_meta("stats")
		tris += int(st.get("triangles",0))
		var f := int(st.get("debris",0))
		frags += f
		var nm := String(u.name).to_snake_case()
		var group := "islet" if nm.begins_with("islet_") else "speck" if nm.begins_with("speck_") else "rock" if nm.contains("_rock_") else "mass"
		by[group] += f
	print("crag reach: %d units, %d triangles, %d debris fragments (masses %d, aqueduct rocks %d, islets %d, specks %d; %d of them cleared off the routes), built in %d ms" % [units.size(),tris,frags-cleared,by.mass,by.rock,by.islet,by.speck,cleared,Time.get_ticks_msec()-began])

## The tables the bridges, pillars and ruins are built from, and the root
## of their layout names: a place built on this one (studies/heist_level.gd)
## answers its own.
func place_root() -> String:
	return "crag_reach"

func bridge_list() -> Array:
	return BRIDGES

func pillar_list() -> Array:
	return PILLARS

func ruin_list() -> Array:
	return RUINS

## Leaves out every debris fragment in a route's way (SPAN_CLEAR): its
## instance shrunk to nothing. Returns how many. Fixed loops: units x
## multimeshes x instances x spans.
func _clear_spans() -> int:
	var cleared := 0
	for u: Node3D in units:
		for mmi: Node in u.find_children("Shape*","MultiMeshInstance3D",true,false):
			if mmi.get_parent().name != "Debris": continue
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			var xf: Transform3D = (mmi as MultiMeshInstance3D).global_transform
			for i in mm.instance_count:
				var p: Vector3 = xf*mm.get_instance_transform(i).origin
				for span: Array in spans:
					var a: Vector3 = span[0]
					var b: Vector3 = span[1]
					var ab := Vector2(b.x-a.x,b.z-a.z)
					var t := clampf(Vector2(p.x-a.x,p.z-a.z).dot(ab)/maxf(ab.length_squared(),0.001),0.0,1.0)
					var on := a.lerp(b,t)
					if Vector2(p.x-on.x,p.z-on.z).length() < SPAN_CLEAR and p.y > on.y-SPAN_BELOW and p.y < on.y+SPAN_ABOVE:
						mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),mm.get_instance_transform(i).origin))
						cleared += 1
						break
	return cleared

## The rope bridges (BRIDGES), each named `crag_reach/<name>`: its node
## moved in the world view moves the whole span with its anchors.
var bridges: Array = []
## Every span's ends [a, b] (bridges and pillars), kept clear of islets.
var spans: Array = []

func _bridges() -> void:
	var space := get_world_3d().direct_space_state
	for br: Array in bridge_list():
		var name_: String = place_root()+"/"+str(br[0])
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
	for pl: Array in pillar_list():
		var name_: String = place_root()+"/"+str(pl[0])
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
				"landmark":-1,"debris":ROCK_DEBRIS}
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
			var span_seed: int = seed_value+i
			var span_worn := clampf(0.5+rng.randf_range(-0.15,0.2),0.0,1.0)
			var piers := 3 if i == 0 else 2
			if kit_breaks_on: ground = _held(ground)
			var span := Aqueduct.span(span_seed,span_worn,piers,false,ground)
			span.transform = at
			if kit_breaks_on:
				span.name = "Span%d" % i
				var g: Callable = ground
				span.set_meta("crag_break",["arch",func() -> Node3D: return Aqueduct.span(span_seed,span_worn,piers,false,g)])
			root.add_child(span)
		if not kit_breaks_on: RuinKit.merge(root)
		art.add_child(root)
		root.transform = Layout.xform(name_,frame)
		Layout.track(name_,root,"piece",frame)
		var end := frame*Vector3(Aqueduct.SPAN*count,Aqueduct.DECK,0.0)
		aqueducts.append([name_,Vector3(a.x,deck,a.z),end])
		spans.append([Vector3(a.x,deck,a.z),end])
		print("crag reach: %s %s -> %s, %d spans, deck %.1f (rims %.1f, %.1f)" % [name_,a,end,count,deck,a.y,b.y])

## The ruins (RUINS), each named `crag_reach/<name>`, kind "piece".
var ruins: Array = []

func _ruins() -> void:
	var space := get_world_3d().direct_space_state
	# The plane's spot and run, found now on bare turf, kept clear.
	var home := plane_home()
	var run_dir := Vector2(-sin(home.w),-cos(home.w))
	var home2 := Vector2(home.x,home.z)
	for r: Array in ruin_list():
		var name_: String = place_root()+"/"+str(r[0])
		var unit: Node3D = named.get(r[1])
		if Layout.deleted(name_) or unit == null: continue
		var off: Vector2 = r[2]
		var at2 := Vector2(unit.position.x,unit.position.z)+off
		var rel := at2-home2
		if absf(rel.dot(Vector2(-run_dir.y,run_dir.x))) < RUIN_CLEAR and absf(unit.position.y-home.y) < 6.0:
			push_warning("crag reach: %s on the plane's line, left out" % name_)
			continue
		var near_span := false
		for sp: Array in spans:
			for e: Vector3 in sp:
				if Vector2(e.x,e.z).distance_to(at2) < RUIN_SPAN and absf(e.y-unit.position.y) < 4.0: near_span = true
		if near_span:
			push_warning("crag reach: %s at a span's end, left out" % name_)
			continue
		var top := _turf_top(space,at2.x,at2.y)
		var y := top.y if top != Vector3.INF else _ground_under(space,at2.x,at2.y,unit.position.y)
		var turn := Basis(Vector3.UP,deg_to_rad(float(r[4])))
		var id: String = r[3]
		var seed_value: int = r[5]
		var worn: float = r[6]
		var opts: Dictionary = r[7]
		var coded := Transform3D(turn,Vector3(at2.x,y,at2.y))
		var node: Node3D = null
		match id:
			"hall":
				var bays := int(opts.get("bays",2))
				var length := Hall.BAY*bays
				var frame := Transform3D(turn,coded.origin-turn.x*length*0.5)
				node = Hall.hall(seed_value,worn,bays,_held(_ground_of(space,frame,-RUIN_VOID)),not kit_breaks_on)
				node.transform = coded.affine_inverse()*frame
				if kit_breaks_on:
					for bay: Node in node.get_children():
						if bay.has_meta("rebuild"): bay.set_meta("crag_break",["wall",bay.get_meta("rebuild")])
				var holder := Node3D.new()
				holder.add_child(node)
				node = holder
			"colonnade":
				node = Node3D.new()
				var count := int(opts.get("count",5))
				var step := float(opts.get("step",7.0))
				for i in count:
					var x := (float(i)-(count-1)*0.5)*step
					var w := coded*Vector3(x,0.0,0.0)
					var t := _turf_top(space,w.x,w.z)
					if t == Vector3.INF: continue
					var frame := Transform3D(turn,Vector3(w.x,t.y,w.z))
					# Every other column standing whole, the rest snapped.
					var col_seed: int = seed_value+i
					var col_worn := worn*(0.3 if i%2 == 0 else 1.3)
					var col_ground := _held(_ground_of(space,frame,-RUIN_VOID))
					var col := Hall.column(col_seed,col_worn,col_ground)
					col.transform = coded.affine_inverse()*frame
					if kit_breaks_on:
						col.name = "Column%d" % i
						col.set_meta("crag_break",["pier",func() -> Node3D: return Hall.column(col_seed,col_worn,col_ground)])
					node.add_child(col)
				if not kit_breaks_on: RuinKit.merge(node)
			_:
				# Down to the lowest turf under its middle and round it.
				var low := y
				for d: Vector2 in [Vector2(2.5,0.0),Vector2(-2.5,0.0),Vector2(0.0,2.5),Vector2(0.0,-2.5)]:
					var t := _turf_top(space,at2.x+d.x,at2.y+d.y)
					if t != Vector3.INF and absf(t.y-y) < 2.0: low = minf(low,t.y)
				coded.origin.y = low-RUIN_SINK
				var seat := _held(_ground_of(space,coded))
				RuinKit.Build.seat(seat)
				node = RuinKit.piece(id,seed_value,worn)
				RuinKit.Build.seat(Callable())
				var kind: String = BreakKinds.KIND_OF.get(id,"")
				if kit_breaks_on and node != null and kind != "":
					node.set_meta("crag_break",[kind,func() -> Node3D:
						RuinKit.Build.seat(seat)
						var again := RuinKit.piece(id,seed_value,worn)
						RuinKit.Build.seat(Callable())
						return again])
		if node == null: continue
		node.name = str(r[0]).to_pascal_case()
		art.add_child(node)
		node.transform = Layout.xform(name_,coded)
		Layout.track(name_,node,"piece",coded)
		ruins.append([name_,node])
	print("crag reach: %d ruins" % ruins.size())

## `ground` (a Callable(x, z) -> y) with what it answered kept: a piece
## built again for a break (kit_breaks.gd, on a worker) asks the ground
## too, and live rays would meet the piece itself, or its rubble, by then
## (and can't be cast off the main thread). Once the piece is built
## (`_built`) it answers from what it kept, the nearest point asked.
var _built := false
var held_misses := 0
const HELD_CELL := 0.5
## How far (cells) past what was asked a miss still finds the nearest kept.
const HELD_RING := 3
## Each `_held`'s grid maker, run once the pieces are built (`_freeze_held`).
var _held_freezers: Array[Callable] = []
func _held(ground: Callable) -> Callable:
	if not kit_breaks_on or not ground.is_valid(): return ground
	var seen := {}
	# What it answered by HELD_CELL m cell too, for the nearest point asked;
	# once built, laid out as a grid (each cell the nearest asked one's
	# answer, HELD_RING cells round them) so a miss is one look, cheap on
	# the cuts' workers (an ivy strand asks thousands of new points).
	var cells := {}
	var grid := {"lo":Vector2i.ZERO,"w":0,"h":0,"y":PackedFloat32Array()}
	_held_freezers.append(func() -> void: _held_grid(cells,grid))
	return func(x: float, z: float) -> float:
		var key := Vector2(x,z)
		if seen.has(key): return float(seen[key])
		var cell := Vector2i(roundi(x/HELD_CELL),roundi(z/HELD_CELL))
		if not _built:
			var y := float(ground.call(x,z))
			seen[key] = y
			cells[cell] = y
			return y
		held_misses += 1
		var g := cell-(grid.lo as Vector2i)
		if g.x < 0 or g.y < 0 or g.x >= int(grid.w) or g.y >= int(grid.h): return 0.0
		var y: float = (grid.y as PackedFloat32Array)[g.y*int(grid.w)+g.x]
		return 0.0 if is_nan(y) else y

## `cells` (cell -> y) laid out in `grid`: each cell within HELD_RING of an
## asked one holds the nearest asked one's y (the ring search it replaces),
## the rest NAN.
func _held_grid(cells: Dictionary, grid: Dictionary) -> void:
	if cells.is_empty(): return
	var lo := Vector2i(1 << 30,1 << 30)
	var hi := -lo
	for c: Vector2i in cells.keys():
		lo = Vector2i(mini(lo.x,c.x),mini(lo.y,c.y))
		hi = Vector2i(maxi(hi.x,c.x),maxi(hi.y,c.y))
	lo -= Vector2i.ONE*HELD_RING
	hi += Vector2i.ONE*HELD_RING
	var w := hi.x-lo.x+1
	var h := hi.y-lo.y+1
	var ys := PackedFloat32Array()
	ys.resize(w*h)
	ys.fill(NAN)
	var best := PackedFloat32Array()
	best.resize(w*h)
	best.fill(INF)
	for c: Vector2i in cells.keys():
		var y := float(cells[c])
		for dx in range(-HELD_RING,HELD_RING+1):
			for dz in range(-HELD_RING,HELD_RING+1):
				var k := (c.y+dz-lo.y)*w+(c.x+dx-lo.x)
				var d := float(dx*dx+dz*dz)
				if d < best[k]:
					best[k] = d
					ys[k] = y
	grid.lo = lo
	grid.w = w
	grid.h = h
	grid.y = ys

func _freeze_held() -> void:
	for f: Callable in _held_freezers: f.call()

## The ground under a piece standing at `xf` (world): a Callable(x, z) ->
## y in its frame, `none` over the drop (-INF: none there; the halls'
## columns want a floor everywhere, RUIN_VOID m down).
func _ground_of(space: PhysicsDirectSpaceState3D, xf: Transform3D, none := -INF) -> Callable:
	return func(x: float, z: float) -> float:
		var w := xf*Vector3(x,0.0,z)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(w.x,xf.origin.y+25.0,w.z),Vector3(w.x,xf.origin.y-25.0,w.z))
		var hit := space.intersect_ray(ray)
		if hit.is_empty(): return none
		return (hit.position as Vector3).y-xf.origin.y

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
			"landmark":-1,"debris":ISLET_DEBRIS}
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
			"landmark":(-1 if d < 400.0 else 0),"grass":(1.0 if d < GRASS_NEAR else 0.0),"debris":(SPECK_DEBRIS if d < 400.0 else 0.0)}
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

## No kit life (its undergrowth and flowers are another palette). With
## --greed-run, the bag, its loot and the plane's rope hook.
func _add_life() -> void:
	if not greed_on: return
	Greed.build(self)
	Greed.build_rope(self)
	Greed.build_brood(self)
	greed = GreedMeter.new()
	add_child(greed)
	greed.setup(self)
	run = GreedRun.new()
	add_child(run)
	run.setup(self)
	_build_hands_hint()

# --- The greed run (--greed-run, studies/crag_reach_greed.gd) -------------------------

const Greed = preload("res://studies/crag_reach_greed.gd")
const GreedMeter = preload("res://scripts/greed/greed_meter.gd")
const GreedRun = preload("res://scripts/greed/greed_run.gd")
## The run's keep, clock, escape, death and end screen
## (scripts/greed/greed_run.gd).
var run: Node = null

## The bag off the plane's hook (scripts/carry/loot_bag.gd `unhitch`): its
## load into the plane's keep.
func bag_unhitching(b: Node3D) -> void:
	if run != null: run.bank(b)
var greed_on := false
## The isle's anger (scripts/greed/greed_meter.gd): value bagged, its
## thresholds (--greed-brood=N, --greed-olmec=N) and its cue.
var greed: Node = null
## The burrows on the crag's turf and the stone brood out of them
## (scripts/brood/bag_brood.gd), woken by greed (`greed_woke`).
var burrows: Array = []
var brood: Node3D = null
## No spade on the crag (the brood's `dig` ask): what they bury stays down.
var dig = null

## The greed meter's marks: "brood", "olmec".
func greed_woke(what: String) -> void:
	if what == "brood": Greed.wake(self)
	elif what == "olmec" and enemies != null and not olmec_armed:
		# The --olmec entrance, now: up a cliff out of view on the next
		# foot tick (after a landing if he's flying), and back OLMEC_AGAIN
		# s after he's gone, as with --olmec.
		olmec_armed = true
		_olmec_due = 0.0
## Read by the carry (scripts/carry/carry_host.gd) and the bag
## (scripts/carry/loot_bag.gd), as studies/wreck_cluster.gd's: the plane's
## rope ends in a bare hook (`bag_on`), the bag, the loose loot.
var bag_on := false
var carry: Node3D = null
var bag: Node3D = null
var loot: Array = []
## His climbing rope (scripts/rope/climb_rope.gd) and what it reads of
## the host: the anchor posts (`holds` id -> "anchor", `pieces` id ->
## node) and the hold every untagged top gives (`rope_ground_hold`).
var rope: Node3D = null
var holds: Dictionary = {}
var pieces: Dictionary = {}
var rope_ground_hold = null
## The bag or the rope in hand ("bag", "rope"; H / pad up): only the one
## in hand hears E, F and the throw (the bag's `bag_keys`, the rope's
## `rope_keys`).
var hands := "bag"
var bag_keys: bool:
	get: return hands == "bag"
var rope_keys: bool:
	get: return hands == "rope"
var _hands_label: Label = null

func _build_hands_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hands_label = Label.new()
	_hands_label.name = "HandsHint"
	_hands_label.add_theme_font_size_override("font_size",18)
	_hands_label.add_theme_color_override("font_color",Color("fbf6ea"))
	_hands_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	_hands_label.add_theme_constant_override("shadow_offset_y",1)
	# Top left: the bag's own lines hold the top right.
	_hands_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hands_label.offset_left = 16.0
	_hands_label.offset_right = 640.0
	_hands_label.offset_top = 12.0
	layer.add_child(_hands_label)
	_hands_label.text = Greed.hands_text(hands)

func _unhandled_input(event: InputEvent) -> void:
	if greed_on and not flying and event.is_action_pressed(&"walk_tool",false,true) and not _tuning():
		Greed.switch(self)
		if _hands_label != null: _hands_label.text = Greed.hands_text(hands)
		get_viewport().set_input_as_handled()
		return
	# The rope in hand, F is its reel (polled), not the walk back's word.
	if greed_on and not flying and hands == "rope" and event.is_action_pressed(&"walk_reel",false,true): return
	super._unhandled_input(event)

func _foot_text() -> String:
	return super._foot_text()+("\n"+Greed.hint() if greed_on else "")

## Dragging, the bag holds him to its rope; aiming a throw, the stick moves
## the reticle, not him (as studies/wreck_cluster.gd).
func _want(delta: float) -> Vector2:
	var want := super._want(delta)
	# Aiming the hook, tugging it or pulling it up, he stands (the rope
	# study's).
	if rope != null and rope.state in ["aim","tug","pull_up"]:
		rope.aim_steer(want,delta)
		return Vector2.ZERO
	if bag == null or bag.act != "aim": return want
	bag.aim_steer(want,delta)
	return Vector2.ZERO

func _sync_figure() -> void:
	if bag != null: bag.leash(get_process_delta_time())
	super._sync_figure()

# --- The Olmec hunt (--olmec, --olmec-after=N) ------------------------------------------

const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const OlmecTarget = preload("res://scripts/lock_on/olmec_target.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
## How far down the face (m, at most) he starts under the lip, so his
## climb is heard and its dust seen before he hauls over.
const OLMEC_BELOW := 4.0
## The cliffs looked at round the crown he stands on (ways out from its
## middle), and how near him (m, flat) a cliff may be.
const OLMEC_WAYS := 32
const OLMEC_NEAR := 14.0
const OLMEC_FAR := 45.0
## Fallen off the world (a gap too wide), he comes up another cliff this
## many s on.
const OLMEC_AGAIN := 6.0
## His knobs here: the whole body's hunt (as studies/olmec_field.gd's
## whole Olmec), relentless, and the wall catch (headless_body.gd
## `leap_catch`).
const OLMEC_KNOBS := {"chase":1.0,"relentless":1.0,"periscope":0.0,"leap_catch":1.0,"down_to":1.0,"skirt_hold":1.0,"climb_clear":1.0}

## Seconds after the start (and after R) the Olmec comes; -1 never (no flag).
var olmec_after := -1.0
## The ruins, the aqueduct's spans and the colonnade's columns break under
## him (on with --olmec / --olmec-after): each piece built as its own node
## with how to build it again (meta "crag_break" [kind, Callable]), handed
## to the breakables hub (scripts/kit_isle/breakables.gd) through
## CragBreaks (kit_breaks.gd, with his landings' waves).
var kit_breaks_on := false
var breakables: Node3D = null
var kit_breaks: Node3D = null
var enemies: Node = null
var _body_knobs := {}
var _olmec_due := -1.0
## Whether the Olmec comes at all: on with --olmec / --olmec-after; with
## --greed-run only once greed reaches his mark (`greed_woke("olmec")`).
var olmec_armed := false
var _gone_t := -1.0
var _voices := {}
var _spawner: Node = null
## Counted, for drivers: spawns, the last cliff (lip, out, below).
var olmec_spawns := 0
var olmec_cliff := {}

## Hides the figure while the head holds him, and steps the enemies
## (studies/whole_body_chase.gd's).
class Slot extends Node:
	var field: Node
	func before(delta: float) -> void: field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _build_room() -> void:
	super._build_room()
	if olmec_after < 0.0 and not greed_on: return
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	var slot := Slot.new()
	slot.field = enemies
	add_child(slot)
	foot_pieces = slot
	_spawner = BodySpawner.new()
	add_child(_spawner)
	_spawner.setup(self,enemies)
	_wire_breaks()

const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const BreakPieces = preload("res://scripts/kit_isle/break_pieces.gd")
## His landing's shockwave (the hunt's leaps, drops and pounces): the
## pieces within LAND_REACH head heights of where he came down (times the
## wave's power's root) take a hit of his strength.
const LAND_REACH := 1.1

## The kit breaks, his landings' too: a wave's first front hits what is
## round where he landed.
class CragBreaks extends "res://scripts/kit_isle/kit_breaks.gd":
	var landings := 0
	func wave(body: Node3D, w: Dictionary) -> void:
		if w.has("kit"): return
		w["kit"] = true
		landings += 1
		var power := float(w.get("power",1.0))
		var reach: float = float(body.hh)*LAND_REACH*sqrt(maxf(power,0.0))
		var at: Vector3 = w.at
		hit(at+Vector3.UP*float(body.hh)*0.5,reach,float(hub.strength_of(&"olmec"))*minf(power,1.0),&"olmec")

func _wire_breaks() -> void:
	if not kit_breaks_on: return
	_built = true
	_freeze_held()
	breakables = Breakables.new()
	breakables.field = enemies
	breakables.sound_hook = _voice
	add_child(breakables)
	kit_breaks = CragBreaks.new()
	kit_breaks.name = "KitBreaks"
	kit_breaks.hub = breakables
	kit_breaks.field = enemies
	kit_breaks.lost_y = lost
	add_child(kit_breaks)
	var n := 0
	var by := {}
	# The ruins the islets and terraces stand on their turf (islet_crag.gd
	# `_landmark`, built by id and seed): broken as the reach's own are.
	for node: Node in art.find_children("Landmark","Node3D",true,false):
		if not node.has_meta("landmark_spec") or node.has_meta("crag_break"): continue
		var lm: Array = node.get_meta("landmark_spec")
		var lm_kind: String = BreakKinds.KIND_OF.get(str(lm[0]),"")
		if lm_kind == "": continue
		node.set_meta("crag_break",[lm_kind,func() -> Node3D: return RuinKit.piece(str(lm[0]),int(lm[1]),float(lm[2]))])
	for node: Node in art.find_children("*","Node3D",true,false):
		if not node.has_meta("crag_break"): continue
		var spec: Array = node.get_meta("crag_break")
		var idx: int = kit_breaks.add(node as Node3D,str(spec[0]),spec[1] as Callable,hash(String(node.get_path())))
		if idx >= 0:
			n += 1
			by[spec[0]] = int(by.get(spec[0],0))+1
	breakables.others.append(kit_breaks)
	# The breaks' voices made now, not at the first break (a frame's ~25 ms).
	for key: String in BreakPieces.VOICES.keys():
		if not _voices.has(key): _voices[key] = EnemyYard._synth(BreakPieces.VOICES[key])
	# Every cut made ahead on workers from now (kit_breaks.gd `prepare_all`):
	# a break only swaps it in, so neither his approach nor a hit (his
	# landings' too) makes a cut on the main thread.
	kit_breaks.prepare_all()
	print("crag reach: %d breakable piece(s) %s" % [n,by])

func olmec() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("crumble"): return e
	return null

func olmec_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## The unit whose turf is under `p` (or the nearest mass top).
func _crown_under(p: Vector3) -> Node3D:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.0,p-Vector3.UP*30.0,TURF_LAYER))
	if not hit.is_empty():
		var n: Node = hit.collider
		while n != null:
			if n in units: return n
			n = n.get_parent()
	var best: Node3D = null
	var best_d := INF
	for u: Node3D in mass_tops.values():
		var d := Vector2(u.position.x-p.x,u.position.z-p.z).length()
		if d < best_d:
			best_d = d
			best = u
	return best

## A cliff of the crown he stands on for the Olmec to come up, out of his
## view: each way out from its middle, the rim (`_rim_end`) fitted to the
## real face (BodySpawner `fit`); out of the camera's look first, the
## camera's line to where he hangs blocked next, then OLMEC_NEAR..OLMEC_FAR
## m off him. {lip, out, below, crown, seen, far} or {}.
func olmec_cliff_pick() -> Dictionary:
	var crown := _crown_under(motor.feet)
	if crown == null: return {}
	var space := get_world_3d().direct_space_state
	var mid := crown.position
	var top := _turf_top(space,mid.x,mid.z)
	mid.y = top.y if top != Vector3.INF else motor.feet.y
	var reach := float(crown.spec.size)*3.0
	var feet: Vector3 = motor.feet
	var best := {}
	var best_score := INF
	for k in OLMEC_WAYS:
		var a := TAU*float(k)/OLMEC_WAYS
		var way := Vector2(cos(a),sin(a))
		var rim := _rim_end(space,mid,mid+Vector3(way.x,0.0,way.y)*reach)
		if rim == Vector3.INF: continue
		var fitted: Array = _spawner.fit(rim,way)
		if fitted.is_empty(): continue
		var lip: Vector3 = fitted[0]
		var out: Vector2 = fitted[1]
		if _lip_failed(lip): continue
		var d := Vector2(lip.x-feet.x,lip.z-feet.z).length()
		var seen: bool = _spawner.in_view(lip)
		var score := 0.0
		if seen: score += 1000.0
		if not _spawner.hidden(lip,out): score += 300.0
		if d < OLMEC_NEAR: score += 2000.0
		# The crown's own rim, not a knoll's or a terrace's over it.
		score += absf(lip.y-mid.y)*40.0
		# A face with a shelf or a bulge on it, he'd haul out onto that.
		var below: float = _spawner.face_below(lip,out,OLMEC_BELOW)
		var clean := _face_clean(space,lip,out,below)
		if not clean: score += 600.0
		score += absf(d-clampf(d,OLMEC_NEAR,OLMEC_FAR))*5.0+d*0.1
		if score < best_score:
			best_score = score
			best = {"lip":lip,"out":out,"crown":String(crown.name),"seen":seen,"far":d,"below":below,"clean":clean,"score":score}
	return best

## Whether his climb up the face under `lip` (`out` its way) from `below`
## m under his hang finds no top short of the lip, as his climb looks for
## one (headless_body.gd `_climb`): every OLMEC_FACE_STEP m of the way up,
## the face at his chest, a ray down past it from his reach to a step over
## his feet. (A crag's stacked collision inside its face reads as a
## shelf there: he'd haul out onto it, under the rim.)
const OLMEC_FACE_STEP := 0.5
func _face_clean(space: PhysicsDirectSpaceState3D, lip: Vector3, out: Vector2, below: float) -> bool:
	var f3 := Vector3(out.x,0.0,out.y).normalized()
	var k: Dictionary = BodySpawner.HeadlessBody.build_of(_spawner._body_k(),float(enemies.numbers().unit))
	var reach := float(k.neck)+float(k.arm)*0.75
	var chest := float(k.chest)
	var step := float(_spawner._body_k().step)
	var mask := WalkerOnly.strip(ground.mask)
	var face := lip
	var y := lip.y-float(k.hang)-below
	while y < lip.y-step:
		var c := Vector3(lip.x,y+chest,lip.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c+f3*6.0,c-f3*4.0,mask))
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7: face = hit.position
		var past := Vector3(face.x,0.0,face.z)-f3*0.8
		var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(past.x,y+reach,past.z),Vector3(past.x,y+step,past.z),mask))
		if not top.is_empty() and (top.normal as Vector3).y > 0.6 and (top.position as Vector3).y < lip.y-0.5: return false
		y += OLMEC_FACE_STEP
	return true

## The whole Olmec up a cliff of his crown (`olmec_cliff_pick`), clinging
## under the lip, climbing; whole and on the hunt once over it.
func spawn_olmec() -> Node3D:
	if enemies == null: return null
	_olmec_clear()
	var c := olmec_cliff_pick()
	if c.is_empty():
		push_warning("crag reach: no cliff fits the Olmec (%s)" % _spawner.fit_why)
		return null
	var lip: Vector3 = c.lip
	var out: Vector2 = c.out
	var knobs: Dictionary = OLMEC_KNOBS.duplicate()
	knobs.merge(_body_knobs,true)
	# The body first, so the head reads its neck where it is this frame.
	var b: Node3D = enemies.add(OlmecTarget,lip,-out,knobs)
	var h: Node3D = enemies.add(InhalerHead,lip,-out,{})
	b.make_whole(h)
	if breakables != null: b.breaker = breakables
	b.cling(lip,out,float(c.below))
	b.body.force_update_transform()
	# He knows you're here: over the lip, straight on the hunt.
	b.hunting = true
	b.seen_at = motor.feet
	enemies.sound(&"body_rumble",b.position)
	olmec_spawns += 1
	olmec_cliff = c
	_gone_t = -1.0
	_say("Stone grinds on stone below the rim...",4.0)
	print("crag reach: the Olmec up %s's face at %s (out %s), %.1f m down, %.1f m off you, %s" % [c.crown,lip,out,lip.y-b.position.y,float(c.far),"in view" if c.seen else "out of view"])
	return b

## With --greed-run: an Olmec under him, far off and not closing (a fall
## off an unclean face, a ledge he paces) is cleared, and comes again up
## another cliff OLMEC_AGAIN s on (the gone path). His moves are untouched.
const OLMEC_STUCK_BELOW := 4.0
const OLMEC_STUCK_FAR := 20.0
const OLMEC_STUCK_GAIN := 3.0
const OLMEC_STUCK_T := 8.0
var _stuck_t := 0.0
var _stuck_best := INF
func _olmec_stuck(b: Node3D, delta: float) -> bool:
	var at: Vector3 = b.global_position
	var d: float = at.distance_to(motor.feet)
	if at.y > motor.feet.y-OLMEC_STUCK_BELOW or d < OLMEC_STUCK_FAR or bool(b.crumbled) or d < _stuck_best-OLMEC_STUCK_GAIN:
		_stuck_t = 0.0
		_stuck_best = d
		return false
	_stuck_t += delta
	if _stuck_t < OLMEC_STUCK_T: return false
	print("crag reach: the Olmec stuck %.1f m under him, %.1f m off, at %s; again up another cliff" % [motor.feet.y-at.y,d,at])
	_stuck_t = 0.0
	_stuck_best = INF
	if not olmec_cliff.is_empty(): _failed_lips.append(olmec_cliff.lip)
	_olmec_clear()
	return true

## Lips he got stuck under (`_olmec_stuck`), not picked again; only the
## greed run fills it.
var _failed_lips: Array = []
func _lip_failed(lip: Vector3) -> bool:
	for l: Vector3 in _failed_lips:
		if l.distance_to(lip) < 6.0: return true
	return false

func _olmec_clear() -> void:
	if enemies == null: return
	if foot_lock != null and foot_lock.locked(): foot_lock.release()
	enemies.clear()
	if figure != null: figure.visible = true

func respawn() -> void:
	super.respawn()
	if rope != null: rope.reset()
	if enemies == null: return
	_olmec_clear()
	_olmec_due = olmec_after

func tick(delta: float) -> void:
	# Jump by a hooked rope takes hold of it (before the motor would jump).
	if rope != null and not flying: rope.pre_step((script_jump if scripted else Input.is_action_pressed(&"walk_jump")) and not _tuning())
	super.tick(delta)
	if greed != null:
		greed.step(delta)
		if _hands_label != null: _hands_label.text = Greed.hands_text(hands)+"\n"+greed.text()+("\n"+run.text() if run != null else "")
	if enemies == null or flying or not olmec_armed: return
	if _olmec_due >= 0.0:
		_olmec_due -= delta
		if _olmec_due < 0.0: spawn_olmec()
		return
	var b := olmec()
	if b == null:
		if _gone_t < 0.0: _gone_t = 0.0
		_gone_t += delta
		if _gone_t > OLMEC_AGAIN: spawn_olmec()
		return
	if greed_on and _olmec_stuck(b,delta): return
	# The gust shot's charge refills on foot while he hunts (olmec_field's).
	if updraft != null: updraft.charge = 1.0
	if bool(b.crumbled):
		if foot_lock != null and foot_lock.target == b: foot_lock.release("down")
	elif camera != null:
		var q := maxf(float(b.quake),float(breakables.quake) if breakables != null else 0.0)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
		if q > 0.001:
			var t := Time.get_ticks_msec()/1000.0
			camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

## Flying, the hunt goes on (he makes for where you left the ground).
func _process(delta: float) -> void:
	super._process(delta)
	if run != null: run.step(delta)
	if flying and enemies != null and delta > 0.0:
		for e in enemies.enemies:
			if is_instance_valid(e) and not e.gone: e.step(delta)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key,BreakPieces.VOICES.get(key)))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,BreakPieces.REACH.get(key,14.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
