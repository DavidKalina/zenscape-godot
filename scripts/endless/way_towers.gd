extends Node3D
## The way towers (docs/design/endless-flight/spec-wilderness-demo.md, trunk 3,
## the pull): lone belfries, the door ruin's own, the only thing on the land
## taller than a hill that isn't one. Neither the ruin nor the coast shows from
## the start meadow. The first tower does, down the length of the bay, and from
## its foot the next two show, one on the way to the ruin, one on the way to
## the isles.
##
## Each stands from REACH m, built on a worker. Handles `way/<place>`: a move in
## the layout file wins, and a find on the handle follows. Trees keep off
## (`tree_keepouts`). Its stone is the flight's solid through LandArches `loose`.
## Only the wilderness has them: they go while the plane is anywhere else.
## Each stands as a temple-kit ruin (temple_site.gd: the temple on the isle,
## the colonnade at the bay, the shrine to the south) instead of the old
## belfry, unless `--temple=0`. The aqueduct across the north downs
## (aqueduct_site.gd) streams from here too, its kit builds taking turns
## with the ruins'.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const TempleSite = preload("res://scripts/endless/temple_site.gd")
const AqueductSite = preload("res://scripts/endless/aqueduct_site.gd")
const TempleKit = preload("res://scripts/temple_kit.gd")
const StreetSite = preload("res://scripts/endless/street_site.gd")
const AgoraSite = preload("res://scripts/endless/agora_site.gd")
const TholosSite = preload("res://scripts/endless/tholos_site.gd")
const TheatreSite = preload("res://scripts/endless/theatre_site.gd")
const ArenaSite = preload("res://scripts/endless/arena_site.gd")
const BathsSite = preload("res://scripts/endless/baths_site.gd")
const SanctuarySite = preload("res://scripts/endless/sanctuary_site.gd")
const CitadelSite = preload("res://scripts/endless/citadel_site.gd")
const TombsSite = preload("res://scripts/endless/tombs_site.gd")
const ViaductSite = preload("res://scripts/endless/viaduct_site.gd")
const DomeSite = preload("res://scripts/endless/dome_site.gd")
const BridgeSite = preload("res://scripts/endless/bridge_site.gd")

const SITES := [
	{"name":"way/bay","at":Vector2(130.0,1540.0),"yaw":PI},
	{"name":"way/south","at":Vector2(-600.0,2480.0),"yaw":0.6},
	{"name":"way/isle","at":Vector2(990.0,2700.0),"yaw":-0.9},
]
const WEATHERED := 0.55
## Stands within REACH m of the eye, gone past FREE.
const REACH := 3200.0
const FREE := 3600.0
## The tower's solid: [half width, top], stage on stage, as the buttresses step in.
const STAGES := [[13.5,24.0],[12.5,45.0],[11.5,66.0],[9.5,106.0],[7.0,120.0]]
const FOOT := 6.0
## The trees' keep-out, half a side (m).
const CLEAR := 38.0

var game: Node3D
## handle -> {name, coded, xf, seed, state ("away", "building", "up"), task, made, node, record}.
var sites := {}
## The aqueduct (aqueduct_site.gd), or null with `--aqueduct=0`.
var aqueduct: Node3D
## The colonnaded street (street_site.gd), or null with `--street=0`.
var street: Node3D
## The agora (agora_site.gd), or null with `--agora=0`.
var agora: Node3D
## The round temple on the ridge (tholos_site.gd), or null with `--tholos=0`.
var tholos: Node3D
## The theatre (theatre_site.gd), or null with `--theatre=0`.
var theatre: Node3D
## The amphitheatre (arena_site.gd), or null with `--colosseum-ruin=0`.
var arena: Node3D
## The bath house (baths_site.gd), or null with `--baths=0`.
var baths: Node3D
## The hillside sanctuary (sanctuary_site.gd), or null with `--sanctuary=0`.
var sanctuary: Node3D
## The citadel on the cape (citadel_site.gd) and the road of tombs to it (tombs_site.gd), or null with `--citadel=0`.
var citadel: Node3D
## The two-tier viaduct on the north-west plain (viaduct_site.gd), or null with `--viaduct=0`.
var viaduct: Node3D
var tombs: Node3D
## The great dome (dome_site.gd), or null with `--dome=0`.
var dome: Node3D
## The great bridge over the gorge (bridge_site.gd), or null with `--bridge=0`.
var bridge: Node3D

func setup(g: Node3D) -> void:
	game = g
	# The kit's models, all loaded here on the main thread while the scene sets
	# up (about 1.4 s rendered), so no build's worker ever loads one
	# (TempleKit.warm) and no flight frame pays for a load.
	while not TempleKit.warm(): pass
	if AqueductSite.wanted():
		aqueduct = AqueductSite.new()
		aqueduct.name = "Aqueduct"
		add_child(aqueduct)
		aqueduct.setup(g)
	if StreetSite.wanted():
		street = StreetSite.new()
		street.name = "Street"
		add_child(street)
		street.setup(g)
	if AgoraSite.wanted():
		agora = AgoraSite.new()
		agora.name = "Agora"
		add_child(agora)
		agora.setup(g)
	if TholosSite.wanted():
		tholos = TholosSite.new()
		tholos.name = "Tholos"
		add_child(tholos)
		tholos.setup(g)
	if TheatreSite.wanted():
		theatre = TheatreSite.new()
		theatre.name = "Theatre"
		add_child(theatre)
		theatre.setup(g)
	if ArenaSite.wanted():
		arena = ArenaSite.new()
		arena.name = "Arena"
		add_child(arena)
		arena.setup(g)
	if BathsSite.wanted():
		baths = BathsSite.new()
		baths.name = "Baths"
		add_child(baths)
		baths.setup(g)
	if SanctuarySite.wanted():
		sanctuary = SanctuarySite.new()
		sanctuary.name = "Sanctuary"
		add_child(sanctuary)
		sanctuary.setup(g)
	if CitadelSite.wanted():
		citadel = CitadelSite.new()
		citadel.name = "Citadel"
		add_child(citadel)
		citadel.setup(g)
		tombs = TombsSite.new()
		tombs.name = "Tombs"
		add_child(tombs)
		tombs.setup(g)
	if ViaductSite.wanted():
		viaduct = ViaductSite.new()
		viaduct.name = "Viaduct"
		add_child(viaduct)
		viaduct.setup(g)
	if DomeSite.wanted():
		dome = DomeSite.new()
		dome.name = "Dome"
		add_child(dome)
		dome.setup(g)
	if BridgeSite.wanted():
		bridge = BridgeSite.new()
		bridge.name = "Bridge"
		add_child(bridge)
		bridge.setup(g)
	for site: Dictionary in SITES:
		var at: Vector2 = site.at
		var temple: bool = TempleSite.has(str(site.name)) and TempleSite.wanted()
		var coded := Transform3D(Basis(Vector3.UP,float(site.yaw)),Vector3(at.x,float(game.field.height(at.x,at.y)),at.y))
		if temple: coded = TempleSite.xform(game.field,str(site.name))
		sites[site.name] = {"name":site.name,"coded":coded,"xf":LayoutOverrides.xform(str(site.name),coded),
			"seed":absi(hash(str(site.name)))%100000,"state":"away","task":-1,"temple":temple}

## Where a tower's foot stands (world), or Vector3.INF for no such tower.
func at(handle: String) -> Vector3:
	if not sites.has(handle): return Vector3.INF
	return (sites[handle].xf as Transform3D).origin

## TreePlan's keep-outs, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	var temple := TempleSite.wanted()
	for site: Dictionary in SITES:
		var p: Vector2 = site.at
		if temple and TempleSite.has(str(site.name)):
			var k: Array = TempleSite.keepout(str(site.name))
			var q: Vector2 = k[0]
			if q.x > x0-500.0 and q.x < x1+500.0 and q.y > z0-500.0 and q.y < z1+500.0: out.append(k)
			continue
		if p.x < x0-500.0 or p.x > x1+500.0 or p.y < z0-500.0 or p.y > z1+500.0: continue
		out.append([p,1.0,0.0,CLEAR,CLEAR])
	out.append_array(AqueductSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(StreetSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(AgoraSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(TholosSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(TheatreSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(ArenaSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(BathsSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(SanctuarySite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(CitadelSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(ViaductSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(TombsSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(DomeSite.tree_keepouts(x0,z0,x1,z1))
	out.append_array(BridgeSite.tree_keepouts(x0,z0,x1,z1))
	return out

## One frame: the towers streamed round the eye.
func step(eye: Vector3) -> void:
	var here := game.finds == null or str(game.finds.world) == "wilderness"
	# One kit ruin builds at a time: its loads and MultiMeshes on two workers at
	# once broke RIDs (headless).
	var kit_busy := false
	for handle: String in sites:
		if sites[handle].temple and str(sites[handle].state) == "building": kit_busy = true
	if aqueduct != null and aqueduct.step(eye,kit_busy,here): kit_busy = true
	if street != null and street.step(eye,kit_busy,here): kit_busy = true
	if agora != null and agora.step(eye,kit_busy,here): kit_busy = true
	if tholos != null and tholos.step(eye,kit_busy,here): kit_busy = true
	if theatre != null and theatre.step(eye,kit_busy,here): kit_busy = true
	if arena != null and arena.step(eye,kit_busy,here): kit_busy = true
	if baths != null and baths.step(eye,kit_busy,here): kit_busy = true
	if sanctuary != null and sanctuary.step(eye,kit_busy,here): kit_busy = true
	if citadel != null and citadel.step(eye,kit_busy,here): kit_busy = true
	if viaduct != null and viaduct.step(eye,kit_busy,here): kit_busy = true
	if tombs != null and tombs.step(eye,kit_busy,here): kit_busy = true
	if dome != null and dome.step(eye,kit_busy,here): kit_busy = true
	if bridge != null and bridge.step(eye,kit_busy,here): kit_busy = true
	for handle: String in sites:
		var site: Dictionary = sites[handle]
		var d: float = (site.xf as Transform3D).origin.distance_to(eye) if here else INF
		match str(site.state):
			"away":
				if d < REACH and not (site.temple and kit_busy):
					_begin(site)
					if site.temple: kit_busy = true
			"building":
				if WorkerThreadPool.is_task_completed(int(site.task)): _commit(site)
			"up":
				if d > FREE: _free(site)

func _begin(site: Dictionary) -> void:
	site.state = "building"
	if not site.temple: RuinKit.Build.materials()
	site.task = WorkerThreadPool.add_task(_make.bind(site),false,"Way tower")

## On a worker: the piece, off the tree.
func _make(site: Dictionary) -> void:
	if site.temple:
		site.made = TempleSite.build(str(site.name))
		return
	site.made = RuinKit.piece("belfry_tower",int(site.seed),WEATHERED)

## On the main thread: the piece in the tree, its boxes for its hulls.
func _commit(site: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	var xf: Transform3D = site.xf
	var root := Node3D.new()
	root.name = str(site.name).replace("/","_")
	root.transform = xf
	add_child(root)
	site.node = root
	LayoutOverrides.track(str(site.name),root,"piece",site.coded)
	if site.temple:
		_commit_temple(site,root)
		return
	var piece: Node3D = site.made
	site.erase("made")
	for old in piece.find_children("*","StaticBody3D",true,false):
		old.get_parent().remove_child(old)
		old.free()
	game.arches._sunlit(piece,false,false,xf.origin)
	root.add_child(piece)
	var boxes: Array = []
	var low := -FOOT
	for stage: Array in STAGES:
		var half := float(stage[0])
		boxes.append(AABB(Vector3(-half,low,-half),Vector3(half*2.0,float(stage[1])-low,half*2.0)))
		low = float(stage[1])
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	var yaw := xf.basis.get_euler().y
	site.record = {"name":str(site.name),"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":float(STAGES[0][0])+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
	game.arches.loose.append(site.record)
	GroundNative.bump_loose()
	site.state = "up"

## The temple's commit: its kit pieces, their boxes for the flight and the body.
func _commit_temple(site: Dictionary, root: Node3D) -> void:
	var made: Dictionary = site.made
	site.erase("made")
	TempleKit.fill(made.node as Node3D,made.sets as Array)
	root.add_child(made.node as Node3D)
	var boxes: Array = made.boxes
	root.add_child(_body(boxes))
	var xf: Transform3D = site.xf
	var yaw := xf.basis.get_euler().y
	site.record = {"name":str(site.name),"kind":"way","node":root,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":float(made.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
	game.arches.loose.append(site.record)
	GroundNative.bump_loose()
	site.state = "up"

func _body(boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	return body

func _free(site: Dictionary) -> void:
	game.arches.loose.erase(site.record)
	GroundNative.bump_loose()
	site.erase("record")
	if site.has("node") and is_instance_valid(site.node): (site.node as Node).queue_free()
	LayoutOverrides.entries.erase(site.name)
	site.state = "away"

func _exit_tree() -> void:
	for handle: String in sites:
		var site: Dictionary = sites[handle]
		if int(site.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(site.task))
		site.task = -1
		if site.has("made"):
			if site.temple: ((site.made as Dictionary).node as Node).free()
			else: (site.made as Node).free()
