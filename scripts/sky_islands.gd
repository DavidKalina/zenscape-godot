extends Node3D
## The old game's sky round the plate (scripts/sky_glide.gd flies it): the
## currents, the clouds and the cumulus, the islets and the clusters, the
## pierced isles, the airship, the traffic and the tokens, so there is
## somewhere to fly. Only the plate is land: the fresh chunks that once
## stood round it to be claimed, and the world shift that made one the
## plate, are gone (round 7 of docs/design/consolidation-audit.md). The
## fixed slots they stood at (OFFSETS) still lay out the currents, the
## traffic's laps and the clouds.
##
## One seed for every placement in the sky (scripts/sky_world.gd), saved with
## the world. With --peak-ring (kept but unwired: the game dropped it) the
## world is bounded: islands, islets and clouds only within the bounds round
## the plate's first home, and round them a ring of mountain ranges with a few
## notches through it, past which an edge wind turns the glide home (`air`).
## Without it the sky is open, endless.
##
## Between them stand the islets (scripts/sky_islets.gd), small scenery; with
## --wonders a few big forested isles (scripts/sky_forest_isles.gd) to glide
## in under the trees of, and with --peaks or --peak-ring now and then a
## mountain range of the land far below risen up through the cloud sea
## (scripts/sky_peaks.gd), giant stone with a gorge through it. All are solids
## to the glide (`body`); no island stands on a range or an isle.
##
## Through it all, in short lines, the collectible tokens (scripts/
## sky_collectibles.gd): on the clusters' bridges, under the plate's and
## islets' rock, out on good flying lines and under the trees; what the
## pilot has collected is kept with the world (`save_state`).
##
## With --moments, the flight study's greybox moments set pieces too
## (scripts/sky_moments.gd), laid by the world's layout between the
## islands, their free collectibles and challenge records kept with the
## world as the tokens are.
##
## A world saved while claiming was in keeps what it saved of it (`origin`,
## the plate's seed, the islands built and left): the sky still lays out
## round the plate's home, and the rest is written back as it was read
## (`_claims_kept`), so no save loses an island's land.

const Plate = preload("res://scripts/plate.gd")
const HALF := Plate.HALF
## The fixed slots round the plate, in metres, where islands once stood to
## be claimed: the currents, the traffic's laps and the clouds are still laid
## out round them (and SkyWorld SLOTS keeps them equal).
const OFFSETS := [Vector3(380.0,-20.0,-160.0),Vector3(-260.0,25.0,-520.0),Vector3(-640.0,-35.0,120.0),Vector3(180.0,-50.0,700.0),Vector3(820.0,15.0,420.0)]
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const LandformPreview = preload("res://scripts/landform_preview.gd")
const SkyAirship = preload("res://scripts/sky_airship.gd")
const SkyCollectibles = preload("res://scripts/sky_collectibles.gd")
const SkyMoments = preload("res://scripts/sky_moments.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const CloudWakes = preload("res://scripts/cloud_wakes.gd")
const CloudHost = preload("res://scripts/cloud_host.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyPierced = preload("res://scripts/sky_pierced.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
## The world's seed, bounds, ring and edge (scripts/sky_world.gd).
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
## Height lookups snap to this grid. The terrain data memoises every point
## it is asked about, and a glide asks about a great many.
const SNAP := 0.1

var scene: Node3D
var editor: NativeChunkEditor
## Where the sky's kinds are laid out (scripts/sky_cells.gd).
var cells: SkyCells
## The sky's own parts, and what flies with the glide (the plane, its air,
## added by the wanderer): those not under this node are drawn only in the
## glide, and lend the pipelines' stand-ins their meshes (`standins`).
var skip: Array[Node] = []
## The jet streams and thermals between the islands (scripts/sky_currents.gd).
var currents: Node3D
## The other planes touring the jets (scripts/sky_traffic.gd), or null.
var traffic: Node
## The clouds between them (scripts/sky_clouds.gd).
var clouds: Node3D
## The small islets scattered between them (scripts/sky_islets.gd).
var islets: Node3D
## The mountain ranges risen through the cloud sea (scripts/sky_peaks.gd).
var peaks: Node3D
## The towering cumulus risen out of the cloud sea (scripts/sky_towers.gd).
var towers: Node3D
## The planes' tunnels through the clouds and the tufts they tear off
## (scripts/cloud_wakes.gd), every flier's: the eye's plane (`wake`) and
## the traffic's.
var wakes: Node3D
## The forested isles (scripts/sky_forest_isles.gd).
var isles: Node3D
## The clusters of islets that read as places (scripts/sky_clusters.gd).
var clusters: Node3D
## The pierced isles, big masses with holes to fly through (scripts/
## sky_pierced.gd).
var pierced: Node3D
## Now and then an airship towing a lone islet away (scripts/sky_airship.gd).
var airship: Node3D
## The collectible tokens (scripts/sky_collectibles.gd), or null with
## --no-collectibles.
var collectibles: Node3D
## The moments set pieces (scripts/sky_moments.gd), or null without
## --moments.
var moments: Node3D
## The plate's own home is -origin: a world saved while claiming was in
## may have moved it; never changed now.
var origin := Vector3.ZERO
## What such a world saved of its claims (the plate's seed, the islands
## built and left), written back as it was read.
var _claims_kept := {}
## True once the sky is laid out round the plate (`build`).
var _built := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "SkyIslands"
	# The wonders (SkyHomes): none stand unless asked for. --peak-ring stands
	# the ranges and the ring round the world with them
	# (scripts/sky_world.gd), --peaks the ranges alone, --wonders every other
	# one.
	var args := preload("res://scripts/launch_args.gd").user_args()
	if "--wonders" in args:
		SkyHomes.stone = true
		SkyHomes.isles = true
	SkyWorld.read_flags()
	currents = SkyCurrents.new()
	add_child(currents)
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	currents.build(slots)
	if SkyTraffic.enabled():
		traffic = SkyTraffic.new()
		add_child(traffic)
		skip.append(traffic)
		traffic.ground = ground
		traffic.cloud_near = cloud_near
		traffic.cloud_depth = func(point: Vector3) -> float: return in_cloud(point,scene._motion_time)
		traffic.build(currents,slots)
	# The clouds are laid out with the islands (`build`), once the world's
	# seed and its mountains are known: never here, where it would wait on
	# the layout on the main thread.
	clouds = SkyClouds.new()
	add_child(clouds)
	islets = SkyIslets.new()
	islets.palette_source = editor.data._palette
	islets.flora_source = editor.content
	add_child(islets)
	skip.append(islets)
	peaks = SkyPeaks.new()
	peaks.palette_source = editor.data._palette
	peaks.tree_parts = Callable(SkyIslets,"_tree_parts")
	add_child(peaks)
	skip.append(peaks)
	towers = SkyTowers.new()
	add_child(towers)
	skip.append(towers)
	wakes = CloudWakes.new()
	add_child(wakes)
	skip.append(wakes)
	isles = SkyForestIsles.new()
	isles.palette_source = editor.data._palette
	isles.tree_parts = Callable(SkyIslets,"_tree_parts")
	isles.islets = islets
	add_child(isles)
	skip.append(isles)
	pierced = SkyPierced.new()
	pierced.islets = islets
	add_child(pierced)
	skip.append(pierced)
	clusters = SkyClusters.new()
	clusters.islets = islets
	clusters.scene = scene
	add_child(clusters)
	skip.append(clusters)
	airship = SkyAirship.new()
	airship.islets = islets
	airship.scene = scene
	add_child(airship)
	skip.append(airship)
	if SkyCollectibles.enabled():
		collectibles = SkyCollectibles.new()
		collectibles.islands = self
		collectibles.islets = islets
		collectibles.clusters = clusters
		collectibles.scene = scene
		add_child(collectibles)
		skip.append(collectibles)
		# Review: every kind laid near the home, on clusters stood there.
		if collectibles.near_home and clusters.with_near.is_empty(): clusters.with_near = SkyCollectibles.NEAR_MOTIFS.duplicate()
	if SkyMoments.enabled():
		moments = SkyMoments.new()
		moments.scene = scene
		add_child(moments)
		skip.append(moments)
	# --landform=<name>: the lower world's landforms stood near the home.
	LandformPreview.attach(self)
	show_air(false)

## Lays the sky out round the plate, replacing any earlier one.
func build() -> void:
	clear()
	_keep()
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	clouds.build(slots)
	clouds.reset()
	cells = SkyCells.new(slots)
	cells.origin = origin
	currents.position = origin
	clouds.move(origin)
	_islet_materials()
	islets.side_source = editor._skirt_mesh.surface_get_material(0) if editor._skirt_mesh != null else null
	islets.reset(cells)
	peaks.ground_source = islets.ground_source
	peaks.canopy_tint = SkyIslets._canopy_tint
	peaks.reset(cells,currents)
	towers.reset(cells,currents)
	isles.ground_source = islets.ground_source
	isles.side_source = editor._skirt_mesh.surface_get_material(0) if editor._skirt_mesh != null else null
	isles.canopy_tint = SkyIslets._canopy_tint
	isles.reset(cells)
	pierced.reset(cells)
	clusters.reset(cells)
	if collectibles != null: collectibles.reset(cells)
	if moments != null: moments.reset(cells)
	_built = true

func clear() -> void:
	_built = false
	if currents != null: currents.drop_added()
	if collectibles != null: collectibles.clear()
	if moments != null: moments.clear()
	if clusters != null: clusters.clear()
	if pierced != null: pierced.clear()
	if airship != null: airship.clear()
	if islets != null: islets.clear()
	if peaks != null: peaks.clear()
	if towers != null: towers.clear()
	if wakes != null: wakes.clear()
	if isles != null: isles.clear()

## The main thread's microseconds each part of the last `advance` took,
## for the record (tools/profile_sky_glide.gd).
var spent := {}

## Each frame of the glide: what stands round the eye is made or let go,
## and the clouds follow.
func advance(delta: float, eye: Vector3, _heading: float, _parted: float) -> void:
	var t := Time.get_ticks_usec()
	islets.advance(delta,eye)
	clusters.advance(delta,eye)
	pierced.advance(delta,eye)
	spent.islets = Time.get_ticks_usec()-t
	if collectibles != null:
		t = Time.get_ticks_usec()
		collectibles.advance(delta,eye)
		spent.collectibles = Time.get_ticks_usec()-t
	if moments != null:
		t = Time.get_ticks_usec()
		moments.advance(delta,eye)
		spent.moments = Time.get_ticks_usec()-t
	t = Time.get_ticks_usec()
	peaks.advance(delta,eye)
	spent.peaks = Time.get_ticks_usec()-t
	t = Time.get_ticks_usec()
	towers.advance(delta,eye)
	isles.advance(delta,eye)
	spent.towers = Time.get_ticks_usec()-t
	clouds.screen(towers.screens(eye),towers.fade(eye)*0.9)
	var keep: Array = peaks.keep_spots(eye)+isles.keep_spots(eye)+pierced.keep_spots(eye)
	if moments != null: keep.append_array(moments.keep_spots(eye))
	keep.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(b.x-eye.x,b.y-eye.z).length())
	clouds.keep_off(keep)
	clouds.follow(eye)
	_tear(delta)

## The plate's own terrain and still-water materials for the islets, so
## their grass and ponds are drawn as the plate's are.
func _islet_materials() -> void:
	islets.ground_source = editor.terrain.get_active_material(0)
	var water: Material = null
	var view: Node = editor.get("flow_view")
	if view != null and view.get("still") != null: water = (view.still as MeshInstance3D).material_override
	if water == null and editor.content != null: water = editor.content.get("_water_material")
	islets.water_source = water

## Whether the sky is laid out round the plate (`build`).
func built() -> bool:
	return _built

## What the world's save keeps of the sky: its seed and the tokens
## collected, and what a world from before kept of its claims, as it was.
func save_state() -> Dictionary:
	var state := _claims_kept.duplicate()
	if origin != Vector3.ZERO: state.origin = [origin.x,origin.y,origin.z]
	state.seed = SkyWorld.seed
	if collectibles != null: state.collectibles = collectibles.save_state()
	elif _collected_kept is Dictionary: state.collectibles = _collected_kept
	if moments != null: state.moments = moments.save_state()
	elif _moments_kept is Dictionary: state.moments = _moments_kept
	return state

## The tokens a world saved, kept as they were with --no-collectibles so a
## save never drops them.
var _collected_kept: Variant = null
## The same for the moments set pieces without --moments.
var _moments_kept: Variant = null

## Takes a world's saved sky (`save_state`), or none for a new world. The
## sky is laid out again at the next glide.
func load_state(state: Dictionary) -> void:
	clear()
	if airship != null: airship.forget_session()
	origin = Vector3.ZERO
	var at: Variant = state.get("origin")
	if at is Array and at.size() == 3: origin = Vector3(float(at[0]),float(at[1]),float(at[2]))
	_claims_kept = {}
	for key: String in ["plate_seed","built"]:
		if state.has(key): _claims_kept[key] = state[key]
	# The world's seed: a world saved before it had one keeps the sky it had
	# (SkyWorld LEGACY_SEED); --sky-seed=N tries another. Never changed
	# under a worker working out the layout.
	SkyWorld.settle()
	SkyWorld.seed = int(state.get("seed",SkyWorld.LEGACY_SEED))
	if SkyWorld.seed_flag() >= 0: SkyWorld.seed = SkyWorld.seed_flag()
	_collected_kept = state.get("collectibles")
	if collectibles != null: collectibles.load_state(state.get("collectibles",{}) if state.get("collectibles") is Dictionary else {})
	_moments_kept = state.get("moments")
	if moments != null: moments.load_state(state.get("moments",{}) if state.get("moments") is Dictionary else {})
	_keep()
	# The world's layout worked out on a worker from here, as the world
	# starts (SkyWorld `prepare`); the build view stands its ranges once it
	# is (`_process`). A skyline made for another world's seed is let go.
	SkyWorld.prepare()
	if peaks != null and peaks.ring.line_count() > 0: peaks.ring.warm(peaks)

## Sets the mountain ring's skyline (scripts/sky_ring.gd) to be worked out
## on workers, if it isn't yet (it is from the world's start: `_process`);
## nothing waits on it.
func warm_ring() -> void:
	if peaks == null: return
	_keep()
	peaks.ring.warm(peaks)

## Whether the glide's sky is out (`show_air`).
var _air := false

## The build view: the mountains stand round the plate as they do round the
## glide (SkyPeaks `overview`), on their skylines, warmed on workers as the
## world starts; the rest of the glide's sky stays away.
func _process(_delta: float) -> void:
	if _air or peaks == null or not SkyWorld.ring_on(): return
	if peaks.ground_source == null:
		# The plate's own ground material, once it has one.
		var ground: Material = editor.terrain.get_active_material(0) if editor != null and editor.terrain != null else null
		if ground == null: return
		peaks.ground_source = ground
		peaks.canopy_tint = SkyIslets._canopy_tint
		peaks._material = null
	peaks.overview(origin)
	# The ranges within reach of the plate made ahead and kept fresh (a new
	# layout, a claim, a new palette), so a glide starts among them whole.
	_ahead_since += _delta
	if _ahead_since >= 1.0 and SkyWorld.ready():
		_ahead_since = 0.0
		peaks.premake(-origin)

var _ahead_since := 1.0

# --- Made ahead, as a world starts ----------------------------------------------------
# Under the loading screen (scripts/sky_reveal.gd) the sky the world will
# show is made before it is seen: the layout, every range's skyline (the
# build view's mountains), the ranges within reach of the plate in full
# and the islands, islets and cumulus round it (the glide's first sight),
# all hidden till they are wanted.

## Where the glide starts from: over the plate (global).
const AHEAD_EYE := Vector3(0.0,50.0,0.0)

## A frame's making ahead: everything above set going, and what workers
## have finished stood up (hidden: islets, cumulus and isles show only in
## the glide, the islands only once one has been flown).
func make_ahead(delta: float) -> void:
	if not SkyWorld.ring_on() or peaks == null: return
	SkyWorld.prepare()
	_note_ahead()
	if peaks.ground_source == null or not SkyWorld.ready(): return
	peaks.premake(-origin)
	if not _built: build()
	islets.advance(delta,AHEAD_EYE)
	towers.advance(delta,AHEAD_EYE)
	isles.advance(delta,AHEAD_EYE)

## True once the sky the world will show is made (`make_ahead`): with the
## ring off, at once (nothing is laid out ahead then).
func sky_ready() -> bool:
	return sky_waiting() == ""

## What the sky still waits on ("" if nothing): the layout, the skylines,
## the ranges near, the islets and cumulus.
func sky_waiting() -> String:
	if not SkyWorld.ring_on() or peaks == null: return ""
	if not SkyWorld.ready(): return "layout"
	if not peaks.ring.whole: return "skylines"
	if not peaks.premade_whole(-origin): return "ranges"
	if not _built: return "islets"
	if not (islets._making.is_empty() and towers._making.is_empty() and isles._making.is_empty() and islets._wanted.is_empty()): return "islets"
	return ""

## When each part of it was made (msec, from the first ask), for the
## record (scripts/sky_reveal.gd).
var ahead_times := {}

func _note_ahead() -> void:
	var now := Time.get_ticks_msec()
	if not ahead_times.has("asked"): ahead_times.asked = now
	var parts := {"layout":SkyWorld.ready(),"skylines":SkyWorld.ready() and peaks.ring.whole,"ranges":SkyWorld.ready() and peaks.premade_whole(-origin),"islets":_built and islets._making.is_empty() and islets._wanted.is_empty() and towers._making.is_empty()}
	for part: String in parts:
		if parts[part] and not ahead_times.has(part): ahead_times[part] = now-int(ahead_times.asked)

## How much of it is made, 0 to 1, by rough share of the time each takes:
## the layout, the skylines, the ranges near in full, the rest.
func sky_progress() -> float:
	if not SkyWorld.ring_on() or peaks == null: return 1.0
	var done := 0.1 if SkyWorld.ready() else 0.0
	if SkyWorld.ready():
		done += 0.55*peaks.ring.progress()
		done += 0.2*peaks.premade_progress(-origin)
		if _built: done += 0.15
	return clampf(done,0.0,1.0)

## Stand-ins for everything the sky will draw, each mesh and material once
## (scripts/pipeline_warmup.gd: drawn tiny before the camera for a few
## frames, so their pipelines are built under the loading screen): the
## skylines, solid and fading; a range made in full, the cloud at its foot
## and its spruces; whatever stands under the sky now (islands, islets,
## cumulus, clouds), hidden or not; and the plane the glide flies,
## all its parts.
func standins() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var seen := {}
	_standins_of(self,out,seen)
	# And what flies with the glide, drawn only in it (`skip`, set by the
	# wanderer: the plane with its prop's blur and vapour, the
	# streaks of air).
	for node in skip:
		if is_instance_valid(node) and not is_ancestor_of(node): _standins_of(node,out,seen)
	if peaks != null and not peaks.premade.is_empty():
		var made: Dictionary = peaks.premade.values()[0]
		var holder := Node3D.new()
		for mesh: ArrayMesh in [made.body,made.far]:
			mesh.surface_set_material(0,peaks._ground())
			var body := MeshInstance3D.new()
			body.mesh = mesh
			holder.add_child(body)
		if not made.shape.wraps.is_empty(): holder.add_child(peaks._wrap(made.shape))
		if peaks.tree_parts.is_valid(): peaks._plant(holder,made.shape)
		_standins_of(holder,out,seen)
		holder.free()
	# Fading (the skylines' reveal and swaps, the far faces' visibility
	# fade): the same meshes through the transparent pass.
	for node in out.duplicate():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
			var faded := node.duplicate() as MeshInstance3D
			faded.transparency = 0.5
			out.append(faded)
			break
	return out

func _standins_of(node: Node, out: Array[GeometryInstance3D], seen: Dictionary) -> void:
	for child in node.get_children():
		_standins_of(child,out,seen)
		var g := child as GeometryInstance3D
		if g == null: continue
		var drawn: Resource = (g as MeshInstance3D).mesh if g is MeshInstance3D else ((g as MultiMeshInstance3D).multimesh if g is MultiMeshInstance3D else null)
		if drawn == null: continue
		var key := [drawn.get_rid(),g.material_override.get_rid() if g.material_override != null else RID()]
		if seen.has(key): continue
		seen[key] = true
		var copy: GeometryInstance3D
		if g is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = (g as MeshInstance3D).mesh
			for k in range(mini(m.get_surface_override_material_count(),(g as MeshInstance3D).get_surface_override_material_count())):
				m.set_surface_override_material(k,(g as MeshInstance3D).get_surface_override_material(k))
			copy = m
		else:
			var mm := MultiMeshInstance3D.new()
			mm.multimesh = (g as MultiMeshInstance3D).multimesh
			copy = mm
		copy.material_override = g.material_override
		copy.material_overlay = g.material_overlay
		copy.cast_shadow = g.cast_shadow
		copy.layers = g.layers
		copy.extra_cull_margin = 16384.0
		out.append(copy)

## Tells the ring which island it must keep clear of and hold inside its
## edge (SkyWorld `keep`): the plate's own.
func _keep() -> void:
	var homes: Array[Vector3] = [-origin]
	SkyWorld.keep(homes)

## The currents and clouds show only while gliding; the build view stays
## as it was, but for the mountains: they stand round the plate in both
## (`_process`). Back from a glide, the ranges made in full near it are let
## go, so the build view stands on their skylines.
func show_air(on: bool) -> void:
	_air = on
	currents.visible = on
	if traffic != null: traffic.show(on)
	clouds.visible = on
	islets.visible = on
	if airship != null: airship.visible = on
	if collectibles != null: collectibles.visible = on
	if moments != null: moments.visible = on
	peaks.visible = on or SkyWorld.ring_on()
	if not on: peaks.let_go()
	towers.visible = on
	wakes.visible = on
	if not on: wakes.clear()
	isles.visible = on

## How deep a global point is in cloud, for the vapour: a drifting one's
## heap or a tower's, 0 to 1 (CloudHost `veil_of`). The islands are the
## old game's cloud host (scripts/cloud_host.gd): the look pass hands
## their towers and wakes to the cloud volume, the traffic flies through
## their clouds.
func in_cloud(point: Vector3, time: float) -> float:
	return CloudHost.veil_of(clouds,towers,point,time)

## How deep a global point is in the body of a cloud, drifting or a
## tower, 0 to 1: what a plane tears through and the mist round the eye.
func cloud_body(point: Vector3) -> float:
	return CloudHost.body_of(clouds,towers,point,scene._motion_time)

## The eye's plane this frame, through the clouds (CloudWakes `trace`).
func wake(position: Vector3, velocity: Vector3, delta: float) -> void:
	wakes.trace("eye",position,velocity,cloud_body(position),scene._motion_time,delta)

## The traffic through the clouds, the tufts flown on, and every tunnel
## handed to the clouds that show it (CloudHost `tear_into`).
func _tear(delta: float) -> void:
	var time: float = scene._motion_time
	if traffic != null:
		for i in range(traffic.planes.size()):
			var flight: RefCounted = traffic.planes[i].flight
			wakes.trace(i,flight.position,flight.velocity,cloud_body(flight.position),time,delta)
	CloudHost.tear_into(towers,clouds,wakes,time,delta)

## The middle of the drifting cloud nearest a global point within `reach`
## metres, global, or null (for the other planes, scripts/sky_traffic.gd).
func cloud_near(point: Vector3, reach: float) -> Variant:
	return CloudHost.nearest_of(clouds,point,reach,scene._motion_time)

## The air at a global point (SkyCurrents `air_at`), and past the mountain
## ring the edge wind blowing home (SkyWorld `edge_air`).
func air(point: Vector3) -> Dictionary:
	var here: Dictionary = currents.air_at(point)
	var edge := SkyWorld.edge_air(point-origin)
	if edge.is_empty(): return here
	here.wind = (here.get("wind",Vector3.ZERO) as Vector3)+(edge.wind as Vector3)
	here.along = (here.get("along",Vector3.ZERO) as Vector3)+(edge.along as Vector3)
	return here

## The height of whatever stands under a global point (the plate, an islet,
## the airship, an isle, a range), or null over open air.
func ground(point: Vector3) -> Variant:
	var plate: Variant = _height(point)
	if plate != null: return plate
	var islet: Variant = islets.body(point)
	if islet != null: return (islet as Vector2).x
	var ship: Variant = airship.body(point) if airship != null else null
	if ship != null: return (ship as Vector2).x
	var isle: Variant = isles.ground(point)
	if isle != null: return isle
	return peaks.ground(point)

## What holds a global point, as a solid: Vector2(its ground's height
## there, the underside there: under the plate the hanging rock of an
## island with an outline (NativeTerrainData `underside`), or the square
## slab's flat base, SLAB_BASE), in global metres, or null over open air.
func body(point: Vector3) -> Variant:
	var plate: Variant = _body(point)
	if plate != null: return plate
	var islet: Variant = islets.body(point)
	if islet != null: return islet
	var ship: Variant = airship.body(point) if airship != null else null
	if ship != null: return ship
	var isle: Variant = isles.body(point)
	if isle != null: return isle
	return peaks.body(point)

## True where the solid at a global point is one the glide only rides where
## it is gentle and is turned aside by at its sides (SkyGlide `stone`): a
## range's rock, or a forested isle's trunks and crowns.
func stone(point: Vector3) -> bool:
	return isles.stone(point) or peaks.solid(point)

func _body(point: Vector3, land: NativeTerrainData = null) -> Variant:
	var top: Variant = _height(point,land)
	if top == null: return null
	var local := editor.terrain.to_local(point)
	# The rock under an island with an outline (NativeTerrainData `underside`),
	# at the spot `_height` reads, or the slab's flat base.
	var at := Vector2(snappedf(local.x,SNAP),snappedf(local.z,SNAP))
	var base := (land if land != null else editor.data).underside(at)
	var under := editor.terrain.to_global(Vector3(local.x,base,local.z)).y
	return Vector2(float(top),under)

## The plate's height under a global point, in global metres, or null off it;
## or, given the flat chunk's `land`, a chunk's at the plate's spot.
func _height(point: Vector3, land: NativeTerrainData = null) -> Variant:
	var local := editor.terrain.to_local(point)
	if absf(local.x) > HALF or absf(local.z) > HALF: return null
	var at := Vector2(snappedf(local.x,SNAP),snappedf(local.z,SNAP))
	var h: Variant = (land if land != null else editor.data).ground_height(at)
	if h == null: return null
	return editor.terrain.to_global(Vector3(at.x,float(h),at.y)).y
