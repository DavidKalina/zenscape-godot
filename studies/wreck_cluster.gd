extends "res://studies/kit_isle.gd"
## The wreck cluster (docs/design/wreck-cluster/round1.md): a run's start.
## The plane lies broken on a small cluster of four land masses in open sky
## (studies/wreck_cluster_art.gd): its six parts (scripts/plane_arc/
## wreck_arc.gd on scripts/plane_arc/plane_arc.gd) are dealt at random to a
## pool of candidate spots across the cluster, found on foot, carried back
## and fitted; with all six fitted it flies. A kit isle (studies/
## kit_isle.gd: the pilot, the look, the plane and its hand landing, the
## grass and life), with the rune knight on the causeway by default.
##
##   N            re-deal: the plane back on its spot, broken, every part
##                off it and dealt to fresh spots (a new seed; the pause
##                menu has it too)
##   R            back to the start (beside the plane)
##   Z            (dev key) the stand-in wind blast at the knight; Q (RB)
##                timed as his wind reaches you parries it
##   F4           (dev key) the world view: move the part spots
##                (wreck_cluster/part_spot_NN), pieces and islands; N after
##                a move deals onto the moved spots
##   Esc          pause (Resume, Back to the plane, New deal, ...)
##   ./run-wreck-cluster.command [--seed=N]
##   godot --path . res://studies/wreck_cluster.tscn -- --no-title [--seed=N]
## --seed=N repeats a deal (the first; N re-deals from a fresh seed, printed
## and shown). --no-rune-knight leaves the knight out. --plane-fixed starts
## it repaired, --parts-carried carrying all six, --part-at=<id> by one.
## The kit isles' flags hold (--no-flora, --no-life, --no-sky, --fly, ...).
## Nothing here is saved to the player's progress: the ledger is kept in
## memory while this scene runs (unless --ledger=<path> names a file), and
## the parts never touch it.
const Art = preload("res://studies/wreck_cluster_art.gd")
const WreckSky = preload("res://studies/wreck_cluster_sky.gd")
const WreckArc = preload("res://scripts/plane_arc/wreck_arc.gd")
const PartSpots = preload("res://scripts/plane_arc/part_spots.gd")
const PART_IDS := PartSpots.IDS
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldIslands = preload("res://scripts/world_islands.gd")
const TurfLips = preload("res://scripts/kit_isle/turf_lips.gd")
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const RuneKnight = preload("res://scripts/enemies/rune_knight.gd")
const WindBlastStandin = preload("res://scripts/enemies/wind_blast_standin.gd")
const WindParry = preload("res://scripts/wind_parry.gd")
const PauseHost = preload("res://scripts/kit_isle/pause_host.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DevKeys = preload("res://scripts/kit_isle/dev_keys.gd")

## The re-deal's key (free on foot and in the plane: scripts/pad.gd,
## scripts/kit_isle/dev_keys.gd).
const DEAL_KEY := KEY_N
## How many parts one mass holds at most in a deal (four masses, six parts).
const PER_MASS := 2
## A spot's settle: the ray down from this far over its point, this far
## under it; the part's middle PartSpots.HOVER over what it rests on, clear
## of stone round it by CLEAR (raised by RAISE steps up to RAISE_MOST).
const SETTLE_OVER := 3.0
const SETTLE_UNDER := 8.0
const CLEAR := 0.3
const RAISE := 0.25
const RAISE_MOST := 2.0
const SOLID_MASK := 1|(1 << 11)

var lands := {}
var foot_host: Node3D = null
var spot_root: Node3D = null
## The spot nodes, in the order of Art.spots() (null where deleted).
var spot_nodes: Array = []
## The deal now: its seed and id -> spot index.
var deal_seed := 0
var dealt := {}
var deals := 0
var rune_knight: Node3D = null
var wind_blast: Node = null
var wind_parry: Node3D = null
var pause: Node = null
var _rng := RandomNumberGenerator.new()
var _ledger_was := []

func _ready() -> void:
	_keep_ledger_in_memory()
	_no_lode = true
	_rng.randomize()
	deal_seed = _rng.randi()%100000
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--seed="): deal_seed = int(arg.get_slice("=",1))
	pause = PauseHost.new()
	pause.name = "Pause"
	add_child(pause)
	pause.setup(self)
	_add_deal_row()
	super._ready()

func _exit_tree() -> void:
	WorldIslands.begin()
	if not _ledger_was.is_empty():
		var book := Ledger.shared()
		book.path = _ledger_was[0]
		book.load_saved()
		_ledger_was = []
	super._exit_tree()

## The ledger in memory for this scene (no --ledger=): nothing it marks
## reaches user://progress.json; put back as it was on the way out.
func _keep_ledger_in_memory() -> void:
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--ledger="): return
	var book := Ledger.shared()
	_ledger_was = [book.path]
	book.path = ""
	book.records = {}
	book.plane = Ledger._no_plane()

## The pause's New deal row, under Back to the plane.
func _add_deal_row() -> void:
	var menu: Node = pause.menu
	var row: Control = menu.add_row("New deal (parts re-dealt)",func() -> void:
		pause.resume()
		new_deal(),"N")
	var at: int = menu._sheet.get_children().find(menu.plane_row)+1
	menu._sheet.move_child(row,at)
	menu.rows.erase(row)
	menu.rows.insert(menu.rows.find(menu.plane_row)+1,row)
	menu._items.erase(row)
	menu._items.insert(menu._items.find(menu.plane_row)+1,row)
	menu._layout()

# --- The isle's hooks ---------------------------------------------------------------

func _load_pack() -> void:
	var at := Art.PLANE_AT
	start = Vector3(at.x+1.0,Art.TOP,at.y-2.6)
	start_face = Vector2(0.0,1.0)
	lost = Art.TOP-45.0
	_last_stood = start
	stations = []

func isle_name() -> String:
	return "wreck cluster"

func isle_card() -> Dictionary:
	return {"name":"The Wreck","epithet":"Where the plane came down"}

func isle_top() -> float:
	return Art.TOP

func isle_summit() -> Vector3:
	return Vector3(Art.TOWER_AT.x,Art.plateau_top()+Art.TOWER_HEIGHT,Art.TOWER_AT.y)

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Art.TOP)

func flora_seed() -> int:
	return 421

func sky_script() -> Script:
	return WreckSky

func capture_look() -> Vector3:
	return Vector3(0.0,Art.TOP+2.0,0.0)

## The plane parked on the strip's west end, facing east down it.
func plane_home() -> Vector4:
	var y := Art.TOP
	var top := _turf_top(get_world_3d().direct_space_state,Art.PLANE_AT.x,Art.PLANE_AT.y)
	if top != Vector3.INF: y = top.y
	return Vector4(Art.PLANE_AT.x,y,Art.PLANE_AT.y,Art.PLANE_HEADING)

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	LayoutOverrides.begin("wreck_cluster")
	WorldIslands.begin()
	for spec: Array in Art.lands():
		var land := Art.build_land(spec)
		art.add_child(land)
		lands[str(spec[0])] = land
		add_turf(land)
		WorldIslands.add("island/"+str(spec[0]),land,float(spec[6]))
		if not "--no-turf-lips" in LaunchArgs.user_args(): TurfLips.dress(land,hash(land.name))
	if not LayoutOverrides.islands().is_empty(): isle_ready.connect(_place_saved_islands,CONNECT_ONE_SHOT)
	for p: Array in Art.pieces(): _place_piece(str(p[0]),RuinKit.piece(str(p[1]),int(p[2]),float(p[3])),p[4],float(p[5]))
	_place_piece("tower",Art.tower(),Art.tower_foot(),0.0)
	_build_foot_pieces()
	_build_spots()
	if DevKeys.enabled():
		var editor: Node = preload("res://scripts/layout_edit.gd").new()
		editor.name = "LayoutEdit"
		add_child(editor)
		editor.setup(self,foot_host)
	print("wreck cluster: %d triangles, built in %d ms" % [triangles(art),Time.get_ticks_msec()-began])

## A kit piece stood at `foot` turned `yaw` degrees, named for the world
## view (`wreck_cluster/<name>`; the layout file's move wins).
func _place_piece(called: String, piece: Node3D, foot: Vector3, yaw: float) -> void:
	var name := "wreck_cluster/"+called
	if LayoutOverrides.deleted(name):
		piece.free()
		return
	var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(yaw)),foot)
	piece.transform = LayoutOverrides.xform(name,coded)
	art.add_child(piece)
	LayoutOverrides.track(name,piece,"piece",coded)

## The swing ropes' frames, the air ring and its perch (scripts/
## interactables/foot_pieces.gd, named under wreck_cluster/).
func _build_foot_pieces() -> void:
	foot_host = FootPieces.new()
	add_child(foot_host)
	foot_host.attach(self)
	foot_host.name_under("wreck_cluster")
	var k := 0
	for f: Array in Art.rope_frames():
		foot_host.call_next(str(f[0]))
		foot_host.rope_frame(f[1],f[2],3.0,Art.frame_height(),Art.SwingRope.LENGTH,431+k)
		k += 1
	foot_host.call_next("air_ring")
	foot_host.air_ring(Art.RING_AT,433)
	foot_host.call_next("perch")
	foot_host.stones(434,[Art.PERCH],"Perch")
	LayoutOverrides.build_added(foot_host)

# --- The part spots -----------------------------------------------------------------

## The candidate spots, each a node the world view moves
## (`wreck_cluster/part_spot_NN`, kind "token": the node's own transform);
## a marker and its name shown only while the world view is open.
func _build_spots() -> void:
	spot_root = Node3D.new()
	spot_root.name = "PartSpots"
	add_child(spot_root)
	var list := Art.spots()
	for i in range(list.size()):
		var row: Array = list[i]
		var name := Art.spot_name(i)
		if LayoutOverrides.deleted(name):
			spot_nodes.append(null)
			continue
		var node := Node3D.new()
		node.name = "PartSpot_%02d" % (i+1)
		node.set_meta("mass",str(row[0]))
		node.set_meta("asks",str(row[1]))
		var coded := Transform3D(Basis.IDENTITY,row[2])
		node.transform = LayoutOverrides.xform(name,coded)
		spot_root.add_child(node)
		var marker := MeshInstance3D.new()
		marker.name = "Marker"
		var disc := CylinderMesh.new()
		disc.top_radius = 0.45
		disc.bottom_radius = 0.45
		disc.height = 0.08
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0,0.55,0.15)
		disc.material = mat
		marker.mesh = disc
		marker.position = Vector3.UP*0.06
		marker.visible = false
		node.add_child(marker)
		var label := Label3D.new()
		label.name = "Label"
		label.text = "part_spot_%02d\n%s" % [i+1,row[1]]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 40
		label.pixel_size = 0.01
		label.position = Vector3.UP*1.4
		label.visible = false
		node.add_child(label)
		LayoutOverrides.track(name,node,"token",coded)
		spot_nodes.append(node)

## Spot `i` settled onto what's under it: the part's middle (world), or INF
## where nothing walkable is under it or no room clears it.
func settle_spot(i: int) -> Vector3:
	var node: Node3D = spot_nodes[i]
	if node == null or not is_instance_valid(node): return Vector3.INF
	var p := node.global_position
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*SETTLE_OVER,p+Vector3.DOWN*SETTLE_UNDER,SOLID_MASK)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6: return Vector3.INF
	var ball := SphereShape3D.new()
	ball.radius = CLEAR
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = SOLID_MASK
	var at: Vector3 = (hit.position as Vector3)+Vector3.UP*PartSpots.HOVER
	var up := 0.0
	while up <= RAISE_MOST:
		q.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*up)
		if space.intersect_shape(q,1).is_empty(): return at+Vector3.UP*up
		up += RAISE
	return Vector3.INF

## A deal from `seed_value`: id -> spot index, at most PER_MASS a mass,
## avoiding the spots in `avoid` while enough others settle.
func deal(seed_value: int, avoid: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var good: Array = []
	for i in range(spot_nodes.size()):
		if settle_spot(i) != Vector3.INF: good.append(i)
	var fresh := good.filter(func(i: int) -> bool: return not i in avoid)
	var pool: Array = fresh if fresh.size() >= PART_IDS.size() else good
	for k in range(pool.size()-1,0,-1):
		var j := rng.randi_range(0,k)
		var t: int = pool[k]
		pool[k] = pool[j]
		pool[j] = t
	var picks: Array = []
	var per := {}
	for i: int in pool:
		var mass := str((spot_nodes[i] as Node3D).get_meta("mass"))
		if int(per.get(mass,0)) >= PER_MASS: continue
		per[mass] = int(per.get(mass,0))+1
		picks.append(i)
		if picks.size() == PART_IDS.size(): break
	for i: int in pool:
		if picks.size() >= PART_IDS.size(): break
		if not i in picks: picks.append(i)
	var out := {}
	for k in range(mini(picks.size(),PART_IDS.size())): out[PART_IDS[k]] = picks[k]
	return out

## The dealt parts' points (id -> world middle).
func dealt_points() -> Dictionary:
	var out := {}
	for id: String in dealt: out[id] = settle_spot(int(dealt[id]))
	return out

## The deal laid on the plane's arc, and said.
func _lay_deal(all_carried := false) -> void:
	plane_arc.lay_out(dealt_points(),all_carried)
	var names := PackedStringArray()
	for id: String in PART_IDS:
		if dealt.has(id): names.append("%s %s" % [id,Art.spot_name(int(dealt[id])).get_file()])
	print("wreck cluster: deal %d (seed %d): %s" % [deals,deal_seed,", ".join(names)])

## N: a fresh deal. The plane back on its spot, broken, every part taken off
## it and dealt to fresh spots from a new seed; he stands at the start; the
## knight reforms on his causeway.
func new_deal(seed_value := -1) -> void:
	if not walk_ready: return
	if flying: leave_plane(start)
	park_home()
	if off_edge: _end_fall()
	respawn()
	var avoid: Array = dealt.values()
	deal_seed = seed_value if seed_value >= 0 else _rng.randi()%100000
	deals += 1
	dealt = deal(deal_seed,avoid)
	_lay_deal()
	_make_knight()
	_show_toast("New deal  ·  seed %d" % deal_seed)
	if _switch_hint != null: _switch_hint.text = _foot_text()

# --- Life: the arc and the knight ---------------------------------------------------------

func _add_life() -> void:
	super._add_life()
	if _moments == null:
		_moments = MomentsHud.new()
		add_child(_moments)
	plane_arc = WreckArc.new()
	add_child(plane_arc)
	plane_arc.setup(self)
	dealt = deal(deal_seed)
	_lay_deal(LaunchArgs.user_args().has("--parts-carried"))
	plane_arc.start_by_flag()
	if not LaunchArgs.user_args().has("--no-rune-knight"):
		_make_knight()
		wind_blast = WindBlastStandin.new()
		add_child(wind_blast)
		wind_blast.setup(self)
		wind_parry = WindParry.new()
		add_child(wind_parry)
		wind_parry.setup(self)
		plane_air = _knight_air

## The rune knight on his causeway (scripts/enemies/rune_knight.gd), made
## afresh (a re-deal reforms him).
func _make_knight() -> void:
	if LaunchArgs.user_args().has("--no-rune-knight"): return
	if rune_knight != null and is_instance_valid(rune_knight):
		if rune_knight.core_rune != null and is_instance_valid(rune_knight.core_rune): rune_knight.core_rune.queue_free()
		rune_knight.queue_free()
	rune_knight = RuneKnight.new()
	add_child(rune_knight)
	rune_knight.setup(self,Art.knight_line())

## His crescents buffet the plane.
func _knight_air(p: Vector3) -> Dictionary:
	if plane == null or rune_knight == null or not is_instance_valid(rune_knight): return {}
	return rune_knight.plane_air(p,plane.forward())

func knight_rune_taken() -> void:
	if _moments != null: _moments.pop("The knight's core rune: the causeway is quiet",2.8)

# --- Each frame, keys, the hint ---------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_show_markers()

## The spots' markers only while the world view is open.
var _markers_shown := false
func _show_markers() -> void:
	var editor := get_node_or_null("LayoutEdit")
	var on: bool = editor != null and bool(editor.get("editing"))
	if on == _markers_shown: return
	_markers_shown = on
	for node: Variant in spot_nodes:
		if node == null or not is_instance_valid(node): continue
		for c: Node in (node as Node).get_children(): (c as Node3D).visible = on

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == DEAL_KEY:
		new_deal()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _foot_text() -> String:
	return super._foot_text()+"\nN  re-deal the parts (seed %d)" % deal_seed

## The pause's Back to the plane (scripts/kit_isle/pause_host.gd).
func back_to_plane() -> void:
	if flying or not walk_ready: return
	_return_to_plane()

# --- The world view ------------------------------------------------------------------

## Where the world view looks for what stands on the islands.
func world_roots() -> Array:
	var out: Array = [art]
	for n: String in ["FootPieces","PlaneArc","PartSpots","Life"]:
		var node := get_node_or_null(n)
		if node != null: out.append(node)
	return out

## The layout file's island moves put back once the cluster stands, then the
## deal laid again on the spots where they now stand.
func _place_saved_islands() -> void:
	var saved := LayoutOverrides.islands()
	var done := WorldIslands.place_saved(saved,world_roots(),self)
	if done.is_empty(): return
	for n: Node3D in LayoutOverrides.reapply(): WorldIslands.reanchor(n)
	for name: String in done:
		var i: Dictionary = WorldIslands.islands[name]
		var xf: Transform3D = i.xf
		if Geometry2D.is_point_in_polygon(Vector2(start.x,start.z),i.coded):
			start = xf*start
			_last_stood = start
	park_home()
	respawn()
	if plane_arc != null: _lay_deal()
	print("wreck cluster: islands moved from the layout file: %s" % ", ".join(done))

## An island moved in the world view: the parked plane carried if it stood on it.
func island_moved(_name: String, d := Transform3D.IDENTITY, was := PackedVector2Array()) -> void:
	if parked and not was.is_empty() and Geometry2D.is_point_in_polygon(Vector2(parked_at.x,parked_at.z),was):
		_park(d*parked_at,wrapf(parked_heading+d.basis.get_euler().y,-PI,PI))
