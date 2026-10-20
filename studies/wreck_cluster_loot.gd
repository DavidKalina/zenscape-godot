extends RefCounted
## The loot bag in the home base (docs/design/bag-hitch/spec-bag-hitch.md),
## opt-in with --loot-bag (run-bag-hitch.command passes it with --home): the
## wanderer's bag (scripts/carry/loot_bag.gd) on his back, and loose loot to
## fill it lying on the home isle and on the stretch's islet_b, the next
## islet east. The loot is the bag study's kinds (studies/bag_study.gd
## `loot_model`); each piece is named `bag_hitch/<id>` for the world view
## (F4), settled onto the turf under its spot. Off the strip's clear band
## (Home.STRIP_Z +- STRIP_HALF and its ease) and islet_b's run, so the
## landing turf stays clear.
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LootBag = preload("res://scripts/carry/loot_bag.gd")
const BagStudy = preload("res://studies/bag_study.gd")
const Home = preload("res://studies/wreck_cluster_home.gd")
const Stretch = preload("res://studies/wreck_cluster_stretch.gd")

const ROOT := "bag_hitch"
## The loot: [id, kind, kg, spot (x, z, world), yaw deg]. 29 kg on the home
## isle (more than the bag's cap with the egg, so one trip can't take it
## all worn), 13 kg on islet_b.
const LOOT := [
	# North of the strip, between it and the bluff, by the plane's tail.
	["loot_01","chalice",1.5,Vector2(-918.0,27.0),20.0],
	["loot_02","idol",3.0,Vector2(-905.0,29.0),160.0],
	["loot_03","coins",2.0,Vector2(-896.0,26.5),0.0],
	["loot_07","gem",0.5,Vector2(-891.0,36.0),0.0],
	# South of it, west of the drop field: the egg is a drag.
	["loot_04","bar",4.0,Vector2(-920.0,3.0),35.0],
	["loot_05","urn",6.0,Vector2(-905.0,1.0),200.0],
	["loot_06","egg",12.0,Vector2(-914.0,-6.0),90.0],
	# Islet_b, on its rims off the run (z 10..22).
	["loot_08","idol",3.0,Vector2(-560.0,27.0),220.0],
	["loot_09","bar",4.0,Vector2(-530.0,6.0),70.0],
	["loot_10","urn",6.0,Vector2(-585.0,26.0),130.0],
]
## The grass kept off each spot (KitFlora's `wear`), this far round it (m).
const BARE := 1.2
## The settle's ray: down from this far over the land's top to this far under.
const RAY := Vector2(30.0,40.0)

## The ground under each spot is bare of grass (0..1 at world (x, z)), so
## the small pieces aren't lost in the carpet.
static func wear(p: Vector2) -> float:
	var near := INF
	for row: Array in LOOT: near = minf(near,p.distance_to(row[3]))
	return 1.0-smoothstep(BARE*0.5,BARE,near)

## Stands the loot on the host (filling its `loot`, under a "Loot" node)
## and puts the bag on him (the host's `bag`).
static func build(host: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Loot"
	host.add_child(holder)
	var space := host.get_world_3d().direct_space_state
	var loot: Array = host.get("loot")
	for row: Array in LOOT:
		var called := "%s/%s" % [ROOT,str(row[0])]
		if LayoutOverrides.deleted(called): continue
		var at: Vector2 = row[3]
		var foot := Vector3(at.x,Home.TOP,at.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,Home.TOP+RAY.x,at.y),Vector3(at.x,Home.TOP-RAY.y,at.y),1|(1 << 11)))
		if not hit.is_empty(): foot = hit.position
		var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(row[4]))),foot)
		var spot := Node3D.new()
		spot.name = str(row[0])
		spot.transform = LayoutOverrides.xform(called,coded)
		holder.add_child(spot)
		LayoutOverrides.track(called,spot,"token",coded)
		var made := BagStudy.loot_model(str(row[1]))
		var node: Node3D = made.node
		spot.add_child(node)
		var tag := Label3D.new()
		tag.name = "Kg"
		tag.text = BagStudy._kg_text(float(row[2]))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 28
		tag.pixel_size = 0.006
		tag.outline_size = 6
		tag.position = Vector3(0.0,float(made.height)+0.25,0.0)
		spot.add_child(tag)
		loot.append({"id":str(row[0]),"kind":str(row[1]),"kg":float(row[2]),"spot":spot,"node":node,"measures":made})
	var bag := LootBag.new()
	host.add_child(bag)
	bag.setup(host)
	host.set("bag",bag)

## The bag's keys, for the foot hint.
static func hint() -> String:
	return "Bag: E by loot bags it · F off / on / drag · hold LMB or T aim a throw · V shove it"
