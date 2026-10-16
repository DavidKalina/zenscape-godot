extends SceneTree
## Bakes what the layer generator (scripts/roguelike/layer_plan.gd) reads of
## the isles it places without building them: each isle built once headless and read through the
## physics space (scripts/roguelike/isle_probe.gd): its occupancy (per 2 m
## cell its lowest and highest solid) and, for the motifs that are not
## families yet and the aqueduct isle, its rims and clear spots. Written to
## data/layer/pieces.json. Run again when an isle's art changes:
##   godot --headless --path . --script tools/bake_layer_pieces.gd -- --no-sky --no-life --no-flora --no-lode --no-chain --no-dragon-roost
## (The flags keep the aqueduct isle bare: its rims are its land's.)
## `--only=<id>[,<id>...]` bakes just those motifs (of MOTIFS) into the
## file as it stands, the rest kept as baked: e.g. `--only=dragon_roost`
## (the roost's occupancy).
const Probe = preload("res://scripts/roguelike/isle_probe.gd")
const OUT := "res://data/layer/pieces.json"
## The motifs read: [id, whether its rims and spots are baked (else only
## its occupancy: a family answers its own sockets)].
const MOTIFS := [["sundered_gorge",true],["stair_clouds",true],["bell_spires",true],["colonnade_spine",false],["dragon_roost",false]]
const CELL := 2.0
const WALK_CELL := 1.0
## Rims at least this far apart (m), at most this many; spots with this
## much room at least, this far apart.
const RIM_APART := 9.0
const RIM_MOST := 14
const SPOT_LEAST := 2.5
const SPOT_APART := 12.0
const SPOT_MOST := 6
## The aqueduct isle's rims are on its near island only (where it starts).
const BASE_LAND := "NearIsland"

var out := {}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",",false)
	for spec: Array in MOTIFS:
		if only.is_empty() or only.has(spec[0]): await _motif(spec[0],spec[1])
	if only.is_empty() or only.has("aqueduct_isle"): await _base()
	var text := JSON.stringify(out,"",false)
	if not only.is_empty():
		# The others kept as they were baked: a new entry appended to the
		# file's text, one baked before replaced in the whole.
		var was := FileAccess.get_file_as_string(OUT).strip_edges()
		var had: Variant = JSON.parse_string(was)
		if had is Dictionary:
			var fresh := true
			for id: String in out.keys(): fresh = fresh and not (had as Dictionary).has(id)
			if fresh: text = was.trim_suffix("}")+","+text.trim_prefix("{")
			else:
				(had as Dictionary).merge(out,true)
				text = JSON.stringify(had,"",false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var f := FileAccess.open(OUT,FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("bake: wrote %s" % OUT)
	quit(0)

func _motif(id: String, sockets: bool) -> void:
	var m: RefCounted = load("res://scripts/kit_isle/motif_%s.gd" % id).new()
	m.warm()
	var node := Node3D.new()
	node.name = id
	m.build(node)
	root.add_child(node)
	var turf := {}
	var outlines: Array = []
	for land: Array in m.lands:
		var n: Node3D = land[0]
		for body: StaticBody3D in (KitLand.turf_bodies(n) if bool(land[2]) else [n.get_node("Body")]): turf[body.get_rid()] = true
		outlines.append(land[1] if land[1] != null else n.get_meta("outline"))
	await physics_frame
	await physics_frame
	var entry := _read(root.get_world_3d().direct_space_state,turf,outlines,sockets)
	out[id] = entry
	print("bake: %s %d rims, %d spots, grid %dx%d" % [id,(entry.get("rims",[]) as Array).size(),(entry.get("spots",[]) as Array).size(),int(entry.occupancy.cols),int(entry.occupancy.rows)])
	node.free()
	await physics_frame

func _base() -> void:
	var study: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	await physics_frame
	var all := {}
	var near := {}
	var art: Node3D = study.art
	var near_land: Node = art.get_node(BASE_LAND)
	for body: StaticBody3D in study._turf:
		all[body.get_rid()] = true
		if near_land.is_ancestor_of(body): near[body.get_rid()] = true
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var entry := _read(space,all,study._outlines,false)
	# Rims and spots on the near island only.
	var rect := _rect(study._outlines)
	var grid := Probe.walked_grid(space,near,rect,WALK_CELL,_top(entry.occupancy)+5.0)
	entry.rims = _plain(Probe.rims(space,near,grid,RIM_APART,RIM_MOST))
	entry.spots = _spots(Probe.spots(grid,Probe.rooms(grid),SPOT_LEAST,SPOT_APART,SPOT_MOST))
	entry.start = [study.start.x,study.start.y,study.start.z]
	out["aqueduct_isle"] = entry
	print("bake: aqueduct isle %d rims, %d spots" % [(entry.rims as Array).size(),(entry.spots as Array).size()])
	study.free()

func _read(space: PhysicsDirectSpaceState3D, turf: Dictionary, outlines: Array, sockets: bool) -> Dictionary:
	var rect := _rect(outlines).grow(12.0)
	var occ := Probe.occupancy(space,rect,CELL,Vector2(-120.0,200.0))
	var entry := {"occupancy":_plain_occ(occ)}
	if not sockets: return entry
	var grid := Probe.walked_grid(space,turf,_rect(outlines),WALK_CELL,_top(occ)+5.0)
	entry.rims = _plain(Probe.rims(space,turf,grid,RIM_APART,RIM_MOST))
	entry.spots = _spots(Probe.spots(grid,Probe.rooms(grid),SPOT_LEAST,SPOT_APART,SPOT_MOST))
	return entry

static func _rect(outlines: Array) -> Rect2:
	var box := Rect2()
	var first := true
	for outline: PackedVector2Array in outlines:
		for p in outline:
			if first:
				box = Rect2(p,Vector2.ZERO)
				first = false
			else: box = box.expand(p)
	return box.grow(2.0)

static func _top(occ: Dictionary) -> float:
	var h := -INF
	for v: Variant in occ.hi: if v != null: h = maxf(h,float(v))
	return h

## The grid as plain JSON: its origin [x, z], each cell's lo and hi to the
## centimetre, null where nothing stands.
static func _plain_occ(occ: Dictionary) -> Dictionary:
	var lo: Array = []
	var hi: Array = []
	for v: float in occ.lo: lo.append(snappedf(v,0.01) if is_finite(v) else null)
	for v: float in occ.hi: hi.append(snappedf(v,0.01) if is_finite(v) else null)
	var o: Vector2 = occ.origin
	return {"origin":[snappedf(o.x,0.01),snappedf(o.y,0.01)],"cell":occ.cell,"cols":occ.cols,"rows":occ.rows,"lo":lo,"hi":hi}

static func _plain(rims: Array) -> Array:
	var out_rims: Array = []
	for s: Dictionary in rims:
		var at: Vector3 = s.at
		var face: Vector3 = s.face
		out_rims.append({"name":s.name,"at":[snappedf(at.x,0.01),snappedf(at.y,0.01),snappedf(at.z,0.01)],"face":[snappedf(face.x,0.0001),snappedf(face.z,0.0001)],
			"run_up":s.run_up,"lip":s.lip})
	return out_rims

static func _spots(found: Array) -> Array:
	var out_spots: Array = []
	for s: Array in found:
		var p: Vector3 = s[0]
		out_spots.append({"at":[snappedf(p.x,0.01),snappedf(p.y,0.01),snappedf(p.z,0.01)],"room":snappedf(float(s[1]),0.1)})
	return out_spots
