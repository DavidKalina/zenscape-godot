extends SceneTree
## The moments set pieces in the sky world (--moments: scripts/sky_world.gd
## `_moments`, scripts/sky_moments_plan.gd, scripts/sky_moments.gd),
## headless, for a few seeds:
## - Off by default: without --moments the layout, its key and what blocks
##   the scattered kinds are as before; with it everything else laid is the
##   same and the islands stand where they did.
## - Laid by seed: the same seed lays the same set pieces, another seed
##   others; 10 to 15 of them, every one of the five layouts at least twice,
##   turned and mirrored.
## - Clear: no footprint within reach of an island (the fixed ones and every
##   cell's), a ridge, a summit's crest, a cumulus, a pierced isle or another
##   set piece; all inside the bounds; the stone over the glide's floor (and
##   the cloud sea's top) and under its ceiling.
## - Turned and mirrored true: the line's room to the stone is the study's.
## - Stood: one body on the ruins' layer with a shape a solid, one mesh; the
##   plane bumps off it.
## - Taken: a free collectible on the path is taken and kept through a save;
##   the hoop starts the challenge flown toward the entry only; its
##   collectibles complete it; leaving the area ends it, never a penalty;
##   the hoop stands again once off it.
##   godot --headless --path . --script tests/test_sky_moments.gd
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCache = preload("res://scripts/sky_cache.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyPierced = preload("res://scripts/sky_pierced.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const SkyMoments = preload("res://scripts/sky_moments.gd")
const Course = preload("res://scripts/flight_course.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const SEEDS := [7,99,12345]
## An island's rock reaches about this far from its spot (m: the 48 m plate
## and its hanging rock, irregular), and the plane wants this much air past it.
const ISLAND_REACH := 40.0
const AIR := 40.0
var failures := 0

func _initialize() -> void:
	# Laid out in the bounded world, with the ring and its ranges: those are
	# kept but unwired, so this runs under --peak-ring.
	preload("res://scripts/sky_homes.gd").use_flags(PackedStringArray(["--peak-ring"]))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("sky moments test timed out"); quit(2))
	SkyCache.enabled = false
	_off_by_default()
	for s in SEEDS: _laid(s)
	_true_to_the_study()
	await _stood_and_taken()
	print("sky moments: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _layout(s: int, on: bool) -> Dictionary:
	SkyWorld.moments = on
	SkyWorld.seed = s
	return SkyWorld.layout()

# --- Off by default ---------------------------------------------------------------------

func _off_by_default() -> void:
	var args := OS.get_cmdline_user_args()
	check(not "--moments" in args,"The test runs without --moments")
	SkyWorld.read_flags()
	check(not SkyWorld.moments,"Without --moments the set pieces are off")
	var off := _layout(7,false).duplicate()
	var key_off := SkyWorld._key_now()
	check(not off.has("moments") and SkyWorld.moment_spots().is_empty(),"Without --moments the layout lays none")
	check(not key_off.contains("moments"),"... and its key (and cached layout) is as before")
	var cells := SkyCells.new(SkyWorld.SLOTS)
	var islands_off := _islands(cells)
	var on := _layout(7,true)
	check(SkyWorld._key_now() != key_off,"With --moments the layout's key is its own")
	var same := true
	for part in ["ranges","regions","passes","towers","summits","islands","notches"]:
		if var_to_str(off.get(part)) != var_to_str(on.get(part)): same = false
	check(same,"With --moments everything else laid is the same")
	check(_islands(cells) == islands_off,"... and the islands stand where they did (%d)" % islands_off.size())
	SkyWorld.moments = false

## Every island spot within the bounds (home), sorted.
func _islands(cells: SkyCells) -> Array:
	var out := []
	var reach := ceili(SkyWorld.SCATTER/SkyCells.CELL)+1
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s != null: out.append(s)
	out.sort()
	return out

# --- Laid by seed -----------------------------------------------------------------------

func _laid(s: int) -> void:
	var first: Array = _layout(s,true).moments.duplicate(true)
	SkyWorld.seed = s+1
	SkyWorld.layout()
	var again: Array = _layout(s,true).moments
	check(var_to_str(first) == var_to_str(again),"Seed %d lays the same set pieces again" % s)
	check(first.size() >= 10 and first.size() <= 15,"Seed %d: %d set pieces (10 to 15)" % [s,first.size()])
	var each := {}
	var mirrored := 0
	var turns := {}
	for m: Dictionary in first:
		each[m.layout] = int(each.get(m.layout,0))+1
		if m.mirror: mirrored += 1
		turns[snappedf(float(m.turn),0.1)] = true
	check(each.size() == Plan.count() and each.values().min() >= 2,"Seed %d: every layout stands twice or more %s" % [s,each])
	check(mirrored > 0 and mirrored < first.size() and turns.size() >= 4,"Seed %d: turned (%d ways) and mirrored (%d of them)" % [s,turns.size(),mirrored])
	var other: Array = _layout(s+1000,true).moments
	check(var_to_str(other) != var_to_str(first),"Seed %d and seed %d lay different ones" % [s,s+1000])
	_layout(s,true)
	_clear(s,first)

func _clear(s: int, laid: Array) -> void:
	var cells := SkyCells.new(SkyWorld.SLOTS)
	var spots := _islands(cells)
	spots.append_array(SkyWorld.SLOTS)
	var layout := SkyWorld.layout()
	var worst := {"island":INF,"ridge":INF,"summit":INF,"tower":INF,"apart":INF,"pierced":INF}
	var inside := true
	var heights := true
	for m: Dictionary in laid:
		var box := _home_box(m)
		var corners := [Vector2(box.position.x,box.position.z),Vector2(box.end.x,box.position.z),Vector2(box.end.x,box.end.z),Vector2(box.position.x,box.end.z)]
		for p: Vector3 in spots: worst.island = minf(worst.island,SkyWorld.box_distance(m,Vector2(p.x,p.z)))
		for r: Dictionary in layout.ranges:
			if not SkyWorld.in_band(r.kind):
				for c: Vector2 in SkyWorld.box_outline(m): worst.ridge = minf(worst.ridge,SkyWorld.box_distance(r,c))
		for summit: Dictionary in layout.summits:
			for q: Vector3 in summit.crest: worst.summit = minf(worst.summit,SkyWorld.box_distance(m,Vector2(q.x,q.z))-SkyWorld.SUMMIT_KEEP)
		var towers: Array = [SkyHomes.TOWER]
		towers.append_array(layout.towers)
		for t: Vector3 in towers: worst.tower = minf(worst.tower,SkyWorld.box_distance(m,Vector2(t.x,t.z))-SkyTowers.KEEP)
		for o: Dictionary in laid:
			if o != m: worst.apart = minf(worst.apart,SkyWorld.box_gap(m,o))
		for c: Vector2 in SkyWorld.box_outline(m):
			if not SkyWorld.inside(Vector3(c.x,0.0,c.y)): inside = false
		if box.position.y < SkyGlide.FLOOR or box.position.y < SkyFlight.SEA_Y+40.0 or box.end.y > SkyGlide.CEILING: heights = false
	# The pierced isles, laid after (SkyPierced `spot_of`, round the cells).
	var pierced := SkyPierced.new()
	pierced.cells = cells
	var isles := 0
	for x in range(-2,3):
		for z in range(-2,3):
			var sp: Variant = pierced.spot_of(Vector2i(x,z))
			if sp == null: continue
			isles += 1
			for m: Dictionary in laid: worst.pierced = minf(worst.pierced,SkyWorld.box_distance(m,Vector2(sp.at.x,sp.at.z))-SkyPierced.KEEP)
	pierced.free()
	print("     %d pierced isles" % isles)
	check(worst.island >= ISLAND_REACH+AIR,"Seed %d: every set piece %.0f m (>= %.0f) off every island's spot" % [s,worst.island,ISLAND_REACH+AIR])
	check(worst.ridge > SkyWorld.RIDGE_GAP,"Seed %d: clear of the ridges (%.0f m)" % [s,worst.ridge])
	check(worst.summit > 0.0,"Seed %d: clear of the summits' rock (%.0f m past)" % [s,worst.summit])
	check(worst.tower > 0.0,"Seed %d: clear of the cumulus (%.0f m past)" % [s,worst.tower])
	check(worst.pierced > 0.0,"Seed %d: clear of the pierced isles (%.0f m past)" % [s,worst.pierced])
	check(worst.apart > 300.0,"Seed %d: clear of each other (%.0f m)" % [s,worst.apart])
	check(inside,"Seed %d: all inside the bounds" % s)
	check(heights,"Seed %d: the stone over the glide's floor and the cloud sea, under the ceiling" % s)
	# Nothing scattered stands on one.
	var blocked := true
	for m: Dictionary in laid:
		if not SkyPeaks.blocks(m.box_at): blocked = false
	check(blocked,"Seed %d: nothing scattered stands on them (SkyPeaks blocks)" % s)

## A placement's stone, line and collectibles' box (home).
func _home_box(m: Dictionary) -> AABB:
	var f := Plan.footprint(int(m.layout))
	var box := AABB(Plan.place(m,f.lo),Vector3.ZERO)
	for x: float in [f.lo.x,f.hi.x]:
		for y: float in [f.lo.y,f.hi.y]:
			for z: float in [f.lo.z,f.hi.z]: box = box.expand(Plan.place(m,Vector3(x,y,z)))
	return box

# --- True to the study --------------------------------------------------------------------

## Turned and mirrored, the room from the line to the stone is the study's.
func _true_to_the_study() -> void:
	for i in range(Plan.count()):
		var local := Plan.local_solids(i)
		for mirror: bool in [false,true]:
			var p := {"at":Vector3(500.0,20.0,-300.0),"turn":1.1,"mirror":mirror,"layout":i}
			var placed := []
			for q: Dictionary in local:
				var c: Dictionary = q.duplicate()
				c.middle = Plan.place(p,q.middle)
				if q.kind == "box": c.basis = Plan.solid_basis(q.basis,p.turn,mirror)
				placed.append(c)
			var same := true
			for t: Vector3 in Plan.line(i):
				var a := INF
				var b := INF
				for q: Dictionary in local: a = minf(a,Course.distance(q,t))
				for q: Dictionary in placed: b = minf(b,Course.distance(q,Plan.place(p,t)))
				if absf(a-b) > 0.001: same = false
			check(same,"%s %s: the line's room to the stone is the study's" % [Plan.footprint(i).id,"mirrored" if mirror else "turned"])

# --- Stood and taken -----------------------------------------------------------------------

func _stood_and_taken() -> void:
	SkyWorld.seed = 7
	SkyWorld.moments = true
	var cells := SkyCells.new(SkyWorld.SLOTS)
	var moments := SkyMoments.new()
	root.add_child(moments)
	moments.reset(cells)
	check(moments.placements.size() == SkyWorld.moment_spots().size() and moments.beacons.size() == moments.placements.size(),"Every set piece's hoop and beacon stands from the start (%d)" % moments.beacons.size())
	# A hall (it has every role) stood.
	var p: Dictionary = {}
	for q: Dictionary in moments.placements:
		if q.id == "moments_hall" and p.is_empty(): p = q
	moments.make_now(p.key)
	# Each layout's size and cost, for the record.
	var seen := {}
	for q: Dictionary in moments.placements:
		if seen.has(q.layout): continue
		seen[q.layout] = true
		moments.make_now(q.key)
		var st: Dictionary = moments.stats[q.key]
		print("     %-16s %3d solids, %5d verts, made in %.1f ms, stood in %.2f ms" % [q.id,int(st.solids),int(st.verts),st.make_usec/1000.0,st.stand_usec/1000.0])
	var s: Dictionary = moments.stations[p.key]
	var body: StaticBody3D = (s.node as Node).get_node("Stone")
	var solids := Plan.local_solids(int(p.layout))
	check(body.collision_layer == RuinBump.LAYER and body.get_child_count() == solids.size(),"Its stone is one body on the ruins' layer, a shape a solid (%d)" % solids.size())
	var mesh: Mesh = ((s.node as Node).get_node("Greybox") as MeshInstance3D).mesh
	check(mesh.get_surface_count() >= 2,"... and one mesh (%d surfaces, %d verts)" % [mesh.get_surface_count(),int(moments.stats[p.key].verts)])
	print("     made in %.1f ms on a worker, stood in %.2f ms" % [moments.stats[p.key].make_usec/1000.0,moments.stats[p.key].stand_usec/1000.0])
	# The plane bumps off it.
	await physics_frame
	await physics_frame
	var plane := SkyPlane.new()
	var q0: Dictionary = solids[0]
	plane.launch(Plan.place(p,q0.middle),Plan.heading(p),SkyPlane.CRUISE_SPEED,false)
	var was: Vector3 = plane.position+Vector3.UP*30.0
	var bumped := RuinBump.bump(root.get_world_3d().direct_space_state,plane,was)
	check(bumped,"The plane in its stone is bumped out (ruin bump)")
	# A free collectible on the path is taken, and kept through a save.
	var free: Dictionary = {}
	var starter: Dictionary = {}
	var chal: Array = []
	for m: Dictionary in Plan.moments(int(p.layout)):
		if m.role == "free" and free.is_empty(): free = m
		if m.role == "starter": starter = m
		if m.role == "challenge": chal.append(m)
	var id := "%s:%d" % [p.key,int(free.index)]
	_fly(moments,p,[free.at+Vector3(0,0,3),free.at+Vector3(0,0,-3)])
	check(moments.collected.has(id),"A free collectible on the path is taken")
	check(not (s.nodes as Dictionary).has(int(free.index)),"... and goes")
	check(moments.hud.last_pop.contains("free 1/3"),"... the HUD pops \"%s\"" % moments.hud.last_pop)
	var saved: Dictionary = moments.save_state()
	var again := SkyMoments.new()
	root.add_child(again)
	again.load_state(saved)
	again.reset(cells)
	again.make_now(p.key)
	check(again.collected.has(id) and not (again.stations[p.key].nodes as Dictionary).has(int(free.index)),"Taken stays taken through a save")
	var other := saved.duplicate(true)
	other.seed = 8
	again.load_state(other)
	check(again.collected.is_empty(),"A save for another seed is left out")
	again.queue_free()
	# The hoop: flown the wrong way, nothing; toward the entry, the challenge.
	var hoop: Vector3 = starter.at
	_fly(moments,p,[hoop+Vector3(0,0,-4),hoop+Vector3(0,0,4)])
	check(moments.challenge.is_empty(),"Flown through the hoop away from the entry, no challenge")
	_fly(moments,p,[hoop+Vector3(0,0,10),hoop+Vector3(0,0,-2)])
	check(not moments.challenge.is_empty(),"Flown through toward the entry, the challenge is on")
	check(moments.hud.last_status == "challenge 0/%d" % chal.size(),"... the HUD reads \"%s\"" % moments.hud.last_status)
	var shown := true
	for m: Dictionary in chal:
		if not (s.nodes[int(m.index)] as Node3D).visible: shown = false
	check(shown,"... and its collectibles come out")
	# Its collectibles taken in turn: complete.
	var path: Array = [hoop+Vector3(0,0,-2)]
	for m: Dictionary in chal:
		path.append(m.at+Vector3(0,0,1))
		path.append(m.at+Vector3(0,0,-1))
		_fly(moments,p,path)
		path = [m.at+Vector3(0,0,-1)]
	check(moments.challenge.is_empty() and int(moments.record[p.key].done) == 1 and int(moments.record[p.key].best) == chal.size(),"Taking them all completes it (%s)" % moments.record[p.key])
	check(moments.hud.last_pop.contains("complete") and moments.hud.last_status == "","... the HUD pops \"%s\"" % moments.hud.last_pop)
	# Off the hoop, it stands again; taken, then out of the area: ended.
	_fly(moments,p,[hoop+Vector3(0,0,30)])
	check(moments.armed[p.key],"The hoop stands again once the plane is off it")
	_fly(moments,p,[hoop+Vector3(0,0,10),hoop+Vector3(0,0,-2)])
	check(not moments.armed[p.key] and not (moments.beacons[p.key].ring as Node3D).visible,"... it is down while its challenge is on")
	var started: int = moments.record[p.key].tries
	_fly(moments,p,[hoop+Vector3(0,0,-2),hoop+Vector3(0,80,-2)])
	check(moments.challenge.is_empty() and moments.hud.last_pop.contains("left the area") and started == 2,"Leaving its area ends a try (never a penalty): \"%s\"" % moments.hud.last_pop)
	check(moments.collected.has(id) and int(moments.record[p.key].done) == 1,"... and nothing taken is lost")
	# The list and the hop.
	var target := moments.hop(0)
	var first: Dictionary = moments.placements[0]
	check(Plan.unplace(first,target.position).distance_to(Vector3(0,0,SkyMoments.HOP_OUT)) < 0.01 and is_equal_approx(float(target.heading),Plan.heading(first)),"A hop puts the plane on a set piece's way in, flying its line")
	check(moments.list(Vector3.ZERO).size() == moments.placements.size(),"Every set piece is listed")
	moments.queue_free()
	SkyWorld.moments = false
	await process_frame

## Flies the plane along `path` (the placement's own metres).
func _fly(moments: Node3D, p: Dictionary, path: Array) -> void:
	for local: Vector3 in path:
		moments.touch_plane(Plan.place(p,local))
