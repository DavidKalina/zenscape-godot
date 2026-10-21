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
const ClimbRope = preload("res://scripts/rope/climb_rope.gd")
const Pad = preload("res://scripts/pad.gd")
const BagBrood = preload("res://scripts/brood/bag_brood.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

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
	["loot_07","urn",6.0,Vector3(95.0,25.6,9.0),120.0,"east terrace (rope; post_02)"],
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

## The host's own tables, if it answers them (the heist level's
## `greed_root`, `greed_loot`, `greed_posts`, `greed_burrows`), else the
## crag's (ROOT, LOOT, POSTS, BURROWS).
static func _table(host: Node, ask: String, crag: Variant) -> Variant:
	return host.call(ask) if host.has_method(ask) else crag
## The grass round each piece's spot (the units' KitFlora carpet), this
## far (m), shrunk to nothing after the units stand, so the small pieces
## aren't lost in it.
const BARE := 1.3
## Kept this far (m, across) off the plane's takeoff line on its crown.
const LINE_CLEAR := 12.0

## The whole greed run on a host (the crag reach with --greed-run, the
## heist level): the bag and its loot, the rope and its posts, the burrows
## and brood (if the host has any), the greed meter (the host's `greed`),
## the run's keep, clock, escape and end (the host's `run`) and the hands
## hint. Each piece asks the host's own tables first (`_table`).
static func build_all(host: Node3D) -> void:
	build(host)
	build_rope(host)
	if not (_table(host,"greed_burrows",BURROWS) as Array).is_empty(): build_brood(host)
	var meter: Node = load("res://scripts/greed/greed_meter.gd").new()
	host.add_child(meter)
	meter.setup(host)
	host.set("greed",meter)
	var run: Node = load("res://scripts/greed/greed_run.gd").new()
	host.add_child(run)
	run.setup(host)
	host.set("run",run)
	host.call("_build_hands_hint")

## Stands the loot on the host (filling its `loot`, under a "Loot" node),
## gives it a carry host for the plane's rope (no treasures, the bare
## hook: the host's `bag_on`), and puts the bag on him (the host's `bag`).
static func build(host: Node3D) -> void:
	var carry: Node3D = CarryHost.new()
	host.add_child(carry)
	host.set("carry",carry)
	carry.setup(host,_table(host,"greed_root",ROOT),[])
	carry.deal()
	var holder := Node3D.new()
	holder.name = "Loot"
	host.add_child(holder)
	var space := host.get_world_3d().direct_space_state
	var loot: Array = host.get("loot")
	var home: Vector4 = host.call("place_strip") if host.has_method("place_strip") else host.call("plane_home")
	var run_dir := Vector2(-sin(home.w),-cos(home.w))
	var root: String = _table(host,"greed_root",ROOT)
	for row: Array in _table(host,"greed_loot",LOOT):
		var called := "%s/%s" % [root,str(row[0])]
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

# --- The climbing rope (scripts/rope/climb_rope.gd) -------------------------------------

## The anchor posts the rope ties to over the faces down to the rope's
## loot: [id, foot (world; its height only aims the settle's ray), what
## it's over]. Each stands ~1.2 m in from a clean lip (flat to the edge, a
## sheer face, the terrace's turf 9-10 m under the rope: found by the rope's
## own fix, swept in scratch/greed_postsweep.gd); tie it standing inland of
## it, facing out. Named `greed_run/<id>` for the world view.
const POSTS := [
	["post_01",Vector3(17.97,30.2,25.91),"main crown over terrace 1 (loot_08)"],
	["post_02",Vector3(89.0,34.0,8.21),"east crown over the east terrace (loot_07)"],
]
## A post's radius and how high it stands (the rope study's).
const POST_R := 0.16
const POST_H := 1.0
const POST_COLOUR := Color(0.32,0.25,0.18)

## His rope and hook, the posts it ties to, and every untagged top a solid
## hold to throw at (the host's `rope`, `holds`, `pieces`,
## `rope_ground_hold`).
static func build_rope(host: Node3D) -> void:
	var holds: Dictionary = host.get("holds")
	var pieces: Dictionary = host.get("pieces")
	var space := host.get_world_3d().direct_space_state
	var holder := Node3D.new()
	holder.name = "RopePosts"
	host.add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = POST_COLOUR
	mat.roughness = 0.9
	var root: String = _table(host,"greed_root",ROOT)
	for row: Array in _table(host,"greed_posts",POSTS):
		var id := str(row[0])
		var called := "%s/%s" % [root,id]
		if LayoutOverrides.deleted(called): continue
		var at: Vector3 = row[1]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*RAY.x,at-Vector3.UP*RAY.y,1|(1 << 11)))
		if not hit.is_empty(): at = hit.position
		else: push_warning("greed run: %s found no ground under %s" % [called,at])
		var coded := Transform3D(Basis(),at+Vector3.UP*POST_H*0.5)
		var post := StaticBody3D.new()
		post.name = id
		post.transform = LayoutOverrides.xform(called,coded)
		var shape := CylinderShape3D.new()
		shape.radius = POST_R
		shape.height = POST_H
		var col := CollisionShape3D.new()
		col.shape = shape
		post.add_child(col)
		var mesh := CylinderMesh.new()
		mesh.top_radius = POST_R*0.85
		mesh.bottom_radius = POST_R
		mesh.height = POST_H
		mesh.radial_segments = 10
		var drawn := MeshInstance3D.new()
		drawn.mesh = mesh
		drawn.material_override = mat
		post.add_child(drawn)
		holder.add_child(post)
		LayoutOverrides.track(called,post,"piece",coded)
		pieces[id] = post
		holds[id] = "anchor"
	host.set("rope_ground_hold","solid")
	var rope: Node3D = ClimbRope.new()
	host.add_child(rope)
	rope.setup(host)
	host.set("rope",rope)

## The bag or the rope in hand (H / pad up): their keys clash (E, F, the
## throw), so one has them at a time. Refused while either is busy (the
## rope thrown, climbing or aimed; the bag aimed, lifted or stowing). Left
## fixed or hooked, the rope stays where it is, and Jump by it still takes
## hold. Returns the slot now.
static func switch(host: Node3D) -> String:
	var rope: Node3D = host.get("rope")
	var bag: Node3D = host.get("bag")
	var now := str(host.get("hands"))
	if rope != null and (not str(rope.state) in ["coiled","caught","seated"] or rope.climber or rope.hauling or rope.lowering or rope.swing_hold):
		host.call("_say","Busy with the rope")
		return now
	if bag != null and (str(bag.act) != "" or not (bag.stowing as Dictionary).is_empty()):
		return now
	var to := "rope" if now == "bag" else "bag"
	host.set("hands",to)
	host.call("_say","The rope in hand" if to == "rope" else "The bag in hand")
	return to

## The two-slot hint: which is in hand, and the key to switch.
static func hands_text(hands: String) -> String:
	var key := Pad.pick("H","UP")
	if hands == "rope":
		return "[ROPE] bag  ·  %s switch\nhold LMB/T aim the hook · E tug / tie at a post · F reel · Space by it: hold, over the edge: rappel" % key
	return "[BAG] rope  ·  %s switch\nE bag loot · F off / on / hitch at the plane · hold LMB/T throw it" % key

## The bag's keys, for the foot hint.
static func hint(place := "the crag") -> String:
	return "Greed run: H (pad up) switches the bag / the rope in hand · bag: E by loot bags it · F off / on / drag · F by the plane's rope hook: hitch the bag (its load is the plane's), F again: its load into the plane's keep and the bag back on · Space at the plane boards; fly clear of %s to end the run" % place

# --- The stone brood (scripts/brood/bag_brood.gd) ---------------------------------------

## The burrows on the crag's turf: [id, mouth (world; its height only aims
## the settle's ray), where]. Off the plane's takeoff line (LINE_CLEAR), a
## few on each crown the loot lies on, so a wake comes up near the bag
## wherever he is. Named `greed_run/<id>` for the world view.
const BURROWS := [
	["burrow_01",Vector3(22.0,30.4,2.0),"main crown, east of the plane"],
	["burrow_02",Vector3(-30.0,30.4,-4.0),"main crown, west"],
	["burrow_03",Vector3(9.0,30.4,-24.0),"main crown, north"],
	["burrow_04",Vector3(78.0,35.0,-12.0),"east crown"],
	["burrow_05",Vector3(30.0,22.7,18.0),"main terrace 1"],
	["burrow_06",Vector3(0.0,17.2,-78.0),"north crown"],
	["burrow_07",Vector3(-94.0,42.4,-26.0),"west crown"],
]
## Only the burrows this near the bag (by count) deal a wake.
const WAKE_HOLES := 3

## The burrows (the bag study's mound and mouth) and the brood out of them,
## held down till the greed meter wakes them (`wake`). The host's `brood`,
## `burrows`.
static func build_brood(host: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Burrows"
	host.add_child(holder)
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.36,0.3,0.24)
	earth.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03,0.025,0.02)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := WorldScale.wanderer
	var space := host.get_world_3d().direct_space_state
	var home: Vector4 = host.call("place_strip") if host.has_method("place_strip") else host.call("plane_home")
	var run_dir := Vector2(-sin(home.w),-cos(home.w))
	var holes: Array = host.get("burrows")
	var root: String = _table(host,"greed_root",ROOT)
	for row: Array in _table(host,"greed_burrows",BURROWS):
		var called := "%s/%s" % [root,str(row[0])]
		if LayoutOverrides.deleted(called): continue
		var at: Vector3 = row[1]
		var rel := Vector2(at.x-home.x,at.z-home.z)
		if absf(rel.dot(Vector2(-run_dir.y,run_dir.x))) < LINE_CLEAR and absf(at.y-home.y) < 6.0 and rel.dot(run_dir) > -10.0:
			push_warning("greed run: %s on the plane's line" % called)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*RAY.x,at-Vector3.UP*RAY.y,1|(1 << 11)))
		if not hit.is_empty(): at = hit.position
		else: push_warning("greed run: %s found no ground under %s" % [called,at])
		var coded := Transform3D(Basis.IDENTITY,at)
		var hole := Node3D.new()
		hole.name = str(row[0])
		hole.transform = LayoutOverrides.xform(called,coded)
		holder.add_child(hole)
		LayoutOverrides.track(called,hole,"token",coded)
		var mound := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.bottom_radius = BagStudy.BURROW_FOOT*s
		c.top_radius = BagStudy.BURROW_TOP*s
		c.height = BagStudy.BURROW_HIGH*s
		c.radial_segments = 18
		c.rings = 1
		mound.name = "Mound"
		mound.mesh = c
		# Sunk a little, so a tilted turf doesn't show its foot's underside.
		mound.position.y = BagStudy.BURROW_HIGH*s*0.5-0.05*s
		mound.material_override = earth
		hole.add_child(mound)
		var mouth := MeshInstance3D.new()
		var d := CylinderMesh.new()
		d.bottom_radius = BagStudy.BURROW_HOLE*s
		d.top_radius = BagStudy.BURROW_HOLE*s
		d.height = 0.01
		d.radial_segments = 18
		mouth.name = "Mouth"
		mouth.mesh = d
		mouth.position.y = BagStudy.BURROW_HIGH*s-0.05*s+0.006
		mouth.material_override = dark
		hole.add_child(mouth)
		holes.append(hole)
	_bare(host,holder)
	if LaunchArgs.user_args().has("--no-brood"): return
	var brood: Node3D = BagBrood.new()
	host.add_child(brood)
	brood.setup_bag(host,holes)
	brood.wake_held = true
	brood.wake_holes = WAKE_HOLES
	host.set("brood",brood)

## The greed meter's brood mark: they come up out of the burrows nearest
## the bag.
static func wake(host: Node3D) -> void:
	var brood: Node3D = host.get("brood")
	if brood == null or bool(brood.woken): return
	brood.wake_held = false
	brood.wake_burrows()
