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
	["east",Vector3(96.0,7.0,-14.0),{"seed":51,"size":25.0,"shape":0.5,"flat":0.5,"landmark":0},[
		["terrace_1",Vector3(20.0,-10.0,18.0),{"seed":52,"size":12.0,"shape":0.65}],
		["terrace_2",Vector3(-6.0,-17.0,-24.0),{"seed":53,"size":10.0,"shape":0.4}],
		["knoll",Vector3(14.0,5.0,-8.0),{"seed":54,"size":8.0,"shape":0.9,"landmark":0}],
	]],
	["north",Vector3(4.0,-14.0,-80.0),{"seed":61,"size":28.0,"shape":0.7,"flat":0.6,"landmark":0},[
		["terrace_1",Vector3(-24.0,-8.0,-14.0),{"seed":62,"size":13.0,"shape":0.3}],
		["terrace_2",Vector3(22.0,-20.0,-18.0),{"seed":63,"size":11.0,"shape":0.6}],
	]],
	["west",Vector3(-100.0,22.0,-34.0),{"seed":71,"size":20.0,"shape":0.55,"flat":0.5,"landmark":0},[
		["terrace_1",Vector3(14.0,-11.0,14.0),{"seed":72,"size":10.0,"shape":0.7}],
		["spire",Vector3(-12.0,4.0,-10.0),{"seed":73,"size":8.0,"shape":0.92,"landmark":0}],
	]],
]
const MASS_BASE := {"mass":1,"lean":0.2,"drip":0.5,"lopsided":0.5,"growth":0.7,"weather":0.55,"debris":0.35}
const PART_BASE := {"lean":0.25,"drip":0.5,"lopsided":0.5,"growth":0.7,"weather":0.55,"landmark":-1,"debris":0.3}
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
		if n != null: mass_tops[mname] = n
		for part: Array in m[3]:
			var off: Vector3 = part[1]
			var ps: Dictionary = PART_BASE.merged(part[2],true)
			var turn := Basis(Vector3.UP,float(int(ps.seed)%7)*0.9)
			_stand("crag_reach/%s_%s" % [mname,part[0]],Transform3D(turn,top_at+off),ps)
	_islets()
	if specks: _specks()
	var tris := 0
	var frags := 0
	for u: Node3D in units:
		var st: Dictionary = u.unit.get_meta("stats")
		tris += int(st.get("triangles",0))
		frags += int(st.get("debris",0))
	print("crag reach: %d units, %d triangles, %d debris fragments, built in %d ms" % [units.size(),tris,frags,Time.get_ticks_msec()-began])

## The masses' footprints (x, z, reach) to keep islets clear of.
func _clear_of(p: Vector3, r: float) -> bool:
	for u: Node3D in units:
		var q: Vector3 = u.position
		var reach := float(u.spec.size)*1.25+r+6.0
		if Vector2(p.x-q.x,p.z-q.z).length() < reach and absf(p.y-q.y) < float(u.spec.size)*2.5+r: return false
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
