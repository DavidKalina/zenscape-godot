extends "res://studies/kit_isle.gd"
## The islet yard (docs/design/isle-look/islet-unit-handoff.md): the islet
## unit (scripts/kit_isle/islet_unit.gd) on its own in the game's sky, to
## judge its look. One hero unit in the middle (he starts on its turf), a
## ring of siblings round it, each drawn from the family's knobs with its
## own seed (IsletUnit.sibling), at heights and distances that layer.
## Each unit is named `islet_yard/<hero|sib_n>` (scripts/layout_overrides.gd,
## layouts/islet_yard.json): moved and tuned there, it keeps its name.
##   godot --path . res://studies/islet_yard.tscn -- --no-title
##     [--family=<seed>]   the siblings' seeds start here (1)
##     [--ring=<n>]        siblings (8)
##     [--hero=k=v,k=v]    the hero's knobs (size=9,shape=0.4,...)
##     [--base=k=v,...]    the family's middle the siblings vary round
##     [--solo]            the hero alone
##     [--hide=Turf,Rock]  leave those parts of every unit hidden (looking at one)

const Layout = preload("res://scripts/layout_overrides.gd")
const UnitNode = preload("res://scripts/kit_isle/islet_unit_node.gd")
const SkyScript = preload("res://studies/islet_yard_sky.gd")

const HERO := {"seed":29,"size":9.0,"shape":0.45,"lean":0.3,"drip":0.55,"lopsided":0.5,"growth":0.7,"weather":0.6}
const BASE := {"size":6.0,"shape":0.5,"lean":0.3,"drip":0.5,"lopsided":0.5,"growth":0.6,"weather":0.55}
## The ring: distance (m) round the hero, height off its top.
const RING := Vector2(34.0,62.0)
const LIFT := Vector2(-22.0,14.0)

var family := 1
var ring_count := 8
var hero_spec := HERO.duplicate()
var base_spec := BASE.duplicate()
var solo := false
var units: Array = []

func _ready() -> void:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--family="): family = a.get_slice("=",1).to_int()
		elif a.begins_with("--ring="): ring_count = clampi(a.get_slice("=",1).to_int(),0,16)
		elif a.begins_with("--hero="): hero_spec.merge(_kv(a.substr(7)),true)
		elif a.begins_with("--base="): base_spec.merge(_kv(a.substr(7)),true)
		elif a == "--solo": solo = true
	# No lodestone: nothing to find here.
	_no_lode = true
	super._ready()

static func _kv(text: String) -> Dictionary:
	var out := {}
	for pair: String in text.split(",",false):
		if "=" in pair: out[pair.get_slice("=",0)] = pair.get_slice("=",1).to_float()
	return out

func _load_pack() -> void:
	stations = []
	start = Vector3(0.0,TOP+0.4,0.0)
	start_face = Vector2(0.0,-1.0)
	lost = TOP-80.0
	_last_stood = start

func isle_name() -> String:
	return "islet yard"

func sky_script() -> Script:
	return SkyScript

func capture_look() -> Vector3:
	return Vector3(0.0,TOP-6.0,0.0)

func isle_circle() -> Vector3:
	return Vector3(0.0,0.0,RING.y+10.0)

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	Layout.begin("islet_yard")
	var began := Time.get_ticks_msec()
	_stand("islet_yard/hero",Transform3D(Basis(),Vector3(0.0,TOP,0.0)),hero_spec)
	if not solo:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["islet_yard",family])
		for i in ring_count:
			var a := TAU*(i+rng.randf_range(-0.25,0.25))/maxf(ring_count,1)
			var d := rng.randf_range(RING.x,RING.y)
			var at := Vector3(cos(a)*d,TOP+rng.randf_range(LIFT.x,LIFT.y),sin(a)*d)
			var turn := Basis(Vector3.UP,rng.randf()*TAU)
			_stand("islet_yard/sib_%d" % (i+1),Transform3D(turn,at),IsletUnit.sibling(family*100+i+1,base_spec))
	var tris := 0
	for u: Node3D in units: tris += int((u.unit.get_meta("stats") as Dictionary).get("triangles",0))
	print("islet yard: %d units, %d triangles, built in %d ms" % [units.size(),tris,Time.get_ticks_msec()-began])
	for u: Node3D in units: print("  %s %s %s" % [u.name,str(u.spec),str(u.unit.get_meta("stats"))])
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if not a.begins_with("--hide="): continue
		for part: String in a.substr(7).split(",",false):
			for u: Node3D in units:
				var n := u.unit.get_node_or_null(part) as Node3D
				if n != null: n.visible = false

func _stand(name_: String, coded: Transform3D, spec: Dictionary) -> void:
	if Layout.deleted(name_): return
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

## The units grow their own tufts; no KitFlora carpet here.
func _grow() -> void:
	flora_ready = true

## No plane parked in the yard.
func park_home() -> void:
	pass

## No kit life (its undergrowth and flowers are another palette).
func _add_life() -> void:
	pass
