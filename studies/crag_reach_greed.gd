extends RefCounted
## The greed run on the crag reach (docs/design/greed-run/spec-greed-run.md),
## opt-in with --greed-run (run-greed-run.command): the wanderer's loot bag
## (scripts/carry/loot_bag.gd) on his back, the plane's bare rope hook to
## hitch it to (scripts/carry/carry_host.gd, no treasures of its own), and
## loose loot over the crag to fill it. A few light pieces lie near the
## plane; better and heavier ones across the bridge, down the pillar, over
## the aqueduct, on the knolls and down the terraces' faces (the rope's
## way there and back). Each piece is named `greed_run/<id>` for the world
## view (F4), settled onto the ground under its spot; none within LINE_CLEAR
## m of the parked plane's takeoff line (landing turf, AGENTS.md).
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LootBag = preload("res://scripts/carry/loot_bag.gd")
const CarryHost = preload("res://scripts/carry/carry_host.gd")
const BagStudy = preload("res://studies/bag_study.gd")
const Glint = preload("res://scripts/kit_isle/kit_cache_glint.gd")

const GLINT_TINT := Color(1.0,0.9,0.62)
const ROOT := "greed_run"
## The loot: [id, kind, kg, spot (world x, the turf's height near there,
## z), yaw deg, where]. The height only aims the settle's ray (from RAY.x m
## over it down to RAY.y m under), so a terrace under a crown's lip settles
## on the terrace, not the crown. Values: scripts/home/vault_host.gd VALUES.
const LOOT := [
	# Near the plane, on the main crown: light and easy.
	["loot_01","coins",2.0,Vector3(10.0,30.4,10.0),0.0,"main crown"],
	["loot_02","chalice",1.5,Vector3(14.0,30.4,-9.0),30.0,"main crown"],
	["loot_03","idol",3.0,Vector3(-22.0,30.4,-17.0),160.0,"main crown"],
	["loot_04","chalice",1.5,Vector3(-22.0,35.2,24.0),200.0,"main knoll"],
	# Across the rope bridge, on the east mass.
	["loot_05","bar",4.0,Vector3(84.0,35.0,-3.0),35.0,"east crown"],
	["loot_06","gem",0.5,Vector3(94.0,41.7,-20.0),0.0,"east knoll"],
	["loot_07","urn",6.0,Vector3(100.0,25.3,6.0),120.0,"east terrace (rope)"],
	# Down the main mass's faces: the rope's way.
	["loot_08","bar",4.0,Vector3(30.0,22.7,24.0),70.0,"main terrace 1 (rope)"],
	["loot_09","gem",0.5,Vector3(-33.0,16.0,-8.0),0.0,"main terrace 2, under the aqueduct (rope)"],
	["loot_10","idol",3.0,Vector3(8.0,7.0,38.0),220.0,"main terrace 3, deep (rope)"],
	# Down the pillar onto the north mass: the egg is a drag.
	["loot_11","egg",12.0,Vector3(6.0,17.2,-86.0),90.0,"north crown"],
	# Over the aqueduct, up onto the west mass.
	["loot_12","urn",6.0,Vector3(-100.0,42.4,-34.0),300.0,"west crown (climb)"],
]
const RAY := Vector2(3.0,12.0)
## The grass round each piece's spot (the units' KitFlora carpet), this
## far (m), shrunk to nothing after the units stand, so the small pieces
## aren't lost in it.
const BARE := 1.3
## Kept this far (m, across) off the plane's takeoff line on its crown.
const LINE_CLEAR := 12.0

## Stands the loot on the host (filling its `loot`, under a "Loot" node),
## gives it a carry host for the plane's rope (no treasures, the bare
## hook: the host's `bag_on`), and puts the bag on him (the host's `bag`).
static func build(host: Node3D) -> void:
	var carry: Node3D = CarryHost.new()
	host.add_child(carry)
	host.set("carry",carry)
	carry.setup(host,ROOT,[])
	carry.deal()
	var holder := Node3D.new()
	holder.name = "Loot"
	host.add_child(holder)
	var space := host.get_world_3d().direct_space_state
	var loot: Array = host.get("loot")
	var home: Vector4 = host.call("plane_home")
	var run_dir := Vector2(-sin(home.w),-cos(home.w))
	for row: Array in LOOT:
		var called := "%s/%s" % [ROOT,str(row[0])]
		if LayoutOverrides.deleted(called): continue
		var at: Vector3 = row[3]
		var rel := Vector2(at.x-home.x,at.z-home.z)
		if absf(rel.dot(Vector2(-run_dir.y,run_dir.x))) < LINE_CLEAR and absf(at.y-home.y) < 6.0:
			push_warning("greed run: %s on the plane's line" % called)
		var foot := at
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*RAY.x,at-Vector3.UP*RAY.y,1|(1 << 11)))
		if not hit.is_empty(): foot = hit.position
		else: push_warning("greed run: %s found no ground under %s" % [called,at])
		var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(row[4]))),foot)
		var spot := Node3D.new()
		spot.name = str(row[0])
		spot.transform = LayoutOverrides.xform(called,coded)
		holder.add_child(spot)
		LayoutOverrides.track(called,spot,"token",coded)
		var made := BagStudy.loot_model(str(row[1]))
		var node: Node3D = made.node
		spot.add_child(node)
		var g: Sprite3D = Glint.new()
		g.name = "Glint"
		g.set_instance_shader_parameter("tint",GLINT_TINT)
		g.rng.seed = hash(str(row[0]))
		g.wait = g.rng.randf_range(0.3,Glint.EVERY.y)
		g.transform = Transform3D(Basis(Vector3.RIGHT,-PI*0.5),Vector3(0.0,float(made.height)*0.9,0.0))
		node.add_child(g)
		var tag := Label3D.new()
		tag.name = "Kg"
		tag.text = BagStudy._kg_text(float(row[2]))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 28
		tag.pixel_size = 0.006
		tag.outline_size = 6
		tag.position = Vector3(0.0,float(made.height)+0.25,0.0)
		spot.add_child(tag)
		loot.append({"id":str(row[0]),"kind":str(row[1]),"kg":float(row[2]),"spot":spot,"node":node,"measures":made,"body":null,"still":0.0,"lost":false,"banked":false})
	_bare(host,holder)
	var bag := LootBag.new()
	host.add_child(bag)
	bag.setup(host)
	host.set("bag",bag)

## Every grass instance (a multimesh under a "Flora" node) within BARE m
## of a piece, shrunk to nothing. Returns how many.
static func _bare(host: Node3D, holder: Node3D) -> int:
	var spots: Array[Vector3] = []
	for c: Node in holder.get_children(): spots.append((c as Node3D).global_position)
	var art: Node = host.get("art")
	if art == null: return 0
	var cleared := 0
	for n: Node in art.find_children("*","MultiMeshInstance3D",true,false):
		if not str(n.get_path()).contains("Flora"): continue
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null: continue
		var box := (mmi.global_transform*mm.get_aabb()).grow(BARE)
		var near: Array[Vector3] = []
		for p: Vector3 in spots:
			if box.has_point(p): near.append(p)
		if near.is_empty(): continue
		var xf := mmi.global_transform
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var at := xf*t.origin
			for p: Vector3 in near:
				if Vector2(at.x-p.x,at.z-p.z).length() < BARE and absf(at.y-p.y) < 2.0:
					mm.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),t.origin))
					cleared += 1
					break
	return cleared

## The bag's keys, for the foot hint.
static func hint() -> String:
	return "Greed run: E by loot bags it · F off / on / drag · F by the plane's rope hook: hitch the bag on / off · Space at the plane boards"
