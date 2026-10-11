extends SceneTree
## The sea's summits (scripts/sky_world.gd `_summits`, stood with the
## skyline by scripts/sky_ring.gd): a handful of the land's peaks out in
## the open sea of the regions, sunk so only their tips stand over the
## cloud. A handful across the whole world (4 to 8 tips), lone mostly, a
## small cluster at most; the same seed lays the same, another another;
## their rock over the sea (read from their real shapes, made as the game
## makes them) clear of the islands, islets, cumulus, jet streams, passes,
## notches, kept gorges, the plate's open air, the range in sight of it, the
## band and the ridges; no island and no cumulus gives way to them; their
## tops 20 to 80 m over the sea, under the glide's ceiling (never a wall),
## read by the glide as stone; and they stand with the skyline: built on
## workers, coarse, no shadow, out of the plate's water's mirror, fading in
## with the ranges. Shown in the build view: tests/test_sky_overview.gd.
## Headless: shapes, nodes and numbers only, nothing drawn.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
## The seeds whose layouts are counted (tests/test_sky_world.gd SEEDS).
const SEEDS := [7,1,99,12345,31337,424242,5,2024]
## The tips across the whole world, at least and at most.
const TIPS := Vector2i(4,8)
## The sea's line wanders this far up and down (SkyPeaks SEA_FRAY x): a tip
## stands this much over the sea, give or take it.
const FRAY := 18.0
## Rock over the sea to an island's spot and an islet's (m, plate plane:
## their own reach, and air between).
const ISLAND_AIR := 90.0
const ISLET_AIR := 30.0

var failures := 0

func _initialize() -> void:
	# The ring and its ranges are kept but unwired: this runs under --peak-ring.
	preload("res://scripts/sky_homes.gd").use_flags(PackedStringArray(["--peak-ring"]))
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	_counts()
	_same_by_seed()
	_rock()
	print("PASS: sky summits" if failures == 0 else "FAIL: sky summits (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## A handful across the whole world: 4 to 8 tips, at most one cluster (2 or
## 3 tips), every other a lone tip, never more ranges than SUMMITS allows.
func _counts() -> void:
	var line := ""
	var ok := true
	for s: int in SEEDS:
		SkyWorld.seed = s
		var laid: Array = SkyWorld.layout().summits
		var tips := 0
		var clusters := 0
		var lone := true
		for summit: Dictionary in laid:
			tips += summit.tips.size()
			if summit.tips.size() > 1: clusters += 1
			if summit.tips.size() > SkyWorld.CLUSTER.y: lone = false
		line += " %d: %d (%d)," % [s,tips,laid.size()]
		if tips < TIPS.x or tips > TIPS.y or clusters > 1 or not lone or laid.size() > SkyWorld.SUMMITS.y: ok = false
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	print("     the summits' layout took %.0f ms of the layout's worker" % SkyWorld.summit_ms)
	check(ok,"A handful of tips across the world, lone but for one small cluster at most (seed: tips (ranges)%s)" % line)

## The same seed lays the same summits, another seed others.
func _same_by_seed() -> void:
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	var a := str(SkyWorld.layout().summits)
	SkyWorld.seed = 99
	var b := str(SkyWorld.layout().summits)
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	var c := str(SkyWorld.layout().summits)
	check(a == c and a != b and a != "[]","A seed always lays the same summits, another seed others")

## Every summit made as the game makes it (SkyRing, on workers), and its
## rock over the sea read from its solid.
func _rock() -> void:
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	var laid: Array = SkyWorld.layout().summits
	var cells := SkyCells.new([Vector3.ZERO])
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	var began := Time.get_ticks_msec()
	peaks.reset(cells)
	peaks.flush()
	var ring: Node3D = peaks.ring
	print("     the skyline and its %d summits made in %.1f s (workers)" % [laid.size(),(Time.get_ticks_msec()-began)/1000.0])
	check(ring.summit_count() == laid.size() and laid.size() > 0,"Every summit laid stands with the skyline (%d of %d)" % [ring.summit_count(),laid.size()])
	# Coarse, no shadow, out of the mirror, shown with the skyline, fading in
	# with it.
	var faces := 0
	var bytes := 0
	var plain := true
	for i in ring.summits:
		var node: Node3D = ring.summits[i].node
		var body := node.get_node("Body") as MeshInstance3D
		faces += body.mesh.surface_get_array_len(0)/3
		bytes += body.mesh.surface_get_array_len(0)*(12+12+16+8+8)
		bytes += (ring.summits[i].solid.heights as PackedFloat32Array).size()*4
		if body.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not body.has_meta("skip_reflection") or not node.visible: plain = false
		if body.mesh.surface_get_material(0) != peaks._ground(): plain = false
	print("     the summits: %d faces, %.2f MB of vertices and solids" % [faces,bytes/1048576.0])
	check(plain and faces > 0 and faces < 4000*laid.size(),"Each stands coarse in the ranges' own material, casts no shadow, stays out of the plate's water's mirror and shows with the skyline (%d faces)" % faces)
	ring.whole = false
	ring._show()
	var hidden := true
	for i in ring.summits:
		if (ring.summits[i].node as Node3D).visible: hidden = false
	ring.flush()
	check(hidden,"Until the skyline is whole, no summit shows: they come into the world with the ranges")
	# The rock over the sea, home (the peaks stand at the origin here).
	var rock := []
	var top := -INF
	var low := INF
	var tips := 0
	for i in ring.summits:
		var summit: Dictionary = ring.summits[i]
		var node: Node3D = summit.node
		var solid: Dictionary = summit.solid
		var heights: PackedFloat32Array = solid.heights
		var points := []
		var high := -INF
		for j in range(int(solid.h)):
			for k in range(int(solid.w)):
				var h := heights[j*int(solid.w)+k]
				if h < float(solid.sea): continue
				var local := Vector3(-SkyPeak.HALF.x+(k+int(solid.i0))*SkyPeak.STEP,h,-SkyPeak.HALF.y+(j+int(solid.j0))*SkyPeak.STEP)
				var p := node.transform*local
				points.append(p)
				high = maxf(high,p.y)
		rock.append({"index":i,"points":points,"laid":laid[i]})
		top = maxf(top,high)
		low = minf(low,high)
		tips += int(summit.over)
	check(top <= SkyPeak.SEA+SkyWorld.CLUSTER_SHOW.y+1.0 and low >= SkyPeak.SEA+SkyWorld.SUMMIT_SHOW.x-1.0,"Only their tops stand over the sea: %.0f to %.0f m over it" % [low-SkyPeak.SEA,top-SkyPeak.SEA])
	check(top < SkyGlide.CEILING-SkyGlide.CEILING_FADE,"The highest tip stands at %.0f m, under the glide's ceiling (%.0f m): never a wall" % [top,SkyGlide.CEILING])
	check(tips >= TIPS.x and tips <= TIPS.y,"Their real summits over the sea: %d tips" % tips)
	_clear(rock)
	_kept(rock)
	_stone(peaks,rock)
	peaks.free()

## Their rock over the sea clear of everything the world holds.
func _clear(rock: Array) -> void:
	var layout: Dictionary = SkyWorld.layout()
	var islands := _islands()
	var islets: Node3D = SkyIslets.new()
	islets.cells = SkyCells.new(_slots())
	var towers := [SkyHomes.TOWER]
	towers.append_array(layout.towers)
	var mouths := []
	for r: Dictionary in layout.ranges:
		if not r.gorge: continue
		var x := SkyPeak.gorge_at(int(r.seed),float(r.stature))
		var sc: Vector3 = r.scale
		mouths.append(r.at+Vector3(x*sc.x,0.0,0.0).rotated(Vector3.UP,float(r.turn)))
	var notches := []
	for n: Dictionary in layout.notches: notches.append(n.at)
	var air: Array = SkyWorld._air()
	var found := {}
	var near := {}
	for r: Dictionary in rock:
		var tip: Vector3 = r.laid.tips[0]
		var crest: Array = r.laid.crest
		var islet_spots := []
		for x in range(floori((tip.x-900.0)/SkyIslets.CELL),floori((tip.x+900.0)/SkyIslets.CELL)+1):
			for z in range(floori((tip.z-900.0)/SkyIslets.CELL),floori((tip.z+900.0)/SkyIslets.CELL)+1):
				var s: Variant = islets.spot(Vector2i(x,z))
				if s != null: islet_spots.append(s)
		for p: Vector3 in r.points:
			var flat := Vector2(p.x,p.z)
			var worst := {
				"the bounds":SkyWorld.SCATTER-flat.length(),
				"the plate's open air":flat.length()-SkyWorld.PLATE_OPEN,
				"the range in sight of the plate":flat.distance_to(Vector2(SkyHomes.RANGE.x,SkyHomes.RANGE.z))-SkyHomes.RANGE_KEEP,
			}
			if not SkyWorld.clear_of_band(flat,layout.ranges): worst["the band"] = -1.0
			for q: Dictionary in layout.ranges:
				if q.kind == "ridge": worst["the ridges"] = minf(worst.get("the ridges",INF),SkyWorld.box_distance(q,flat))
			for q: Vector3 in islands: worst["the islands"] = minf(worst.get("the islands",INF),_flat(q,p)-ISLAND_AIR)
			for q: Vector3 in islet_spots: worst["the islets"] = minf(worst.get("the islets",INF),_flat(q,p)-ISLET_AIR)
			for q: Vector3 in towers: worst["the cumulus"] = minf(worst.get("the cumulus",INF),_flat(q,p)-SkyHomes.TOWER_KEEP)
			for q: Vector2 in air: worst["the jet streams"] = minf(worst.get("the jet streams",INF),q.distance_to(flat)-SkyWorld.AIR_ROOM)
			for q: Dictionary in layout.passes: worst["the passes"] = minf(worst.get("the passes",INF),_flat(q.at,p)-SkyWorld.PASS_OPEN.y)
			for q: Vector3 in notches: worst["the notches"] = minf(worst.get("the notches",INF),_flat(q,p)-SkyWorld.MOUTH_GAP)
			for q: Vector3 in mouths: worst["the kept gorges"] = minf(worst.get("the kept gorges",INF),_flat(q,p)-SkyWorld.MOUTH_GAP)
			var kept := INF
			for q: Vector3 in crest: kept = minf(kept,_flat(q,p))
			worst["its keep"] = SkyWorld.SUMMIT_KEEP-kept
			for key in worst:
				near[key] = minf(near.get(key,INF),float(worst[key]))
				if float(worst[key]) < 0.0: found[key] = int(found.get(key,0))+1
	islets.free()
	var nearest := ""
	for key in near: nearest += " %s %.0f m," % [key,near[key]]
	check(found.is_empty(),"Every summit's rock over the sea stands clear of the bounds, the plate's open air, the range in sight of it, the band, the ridges, the islands, the islets, the cumulus, the jet streams, the passes, the notches and the kept gorges, and within its keep (rock points in the way: %s; the least room:%s)" % [str(found),nearest])

## No island and no cumulus gives way to them: the same stand with the
## summits laid and without.
func _kept(rock: Array) -> void:
	var with := _islands()
	var cumulus := _towers()
	var laid: Array = SkyWorld._layout.summits
	SkyWorld._layout.summits = []
	var without := _islands()
	var cumulus_without := _towers()
	SkyWorld._layout.summits = laid
	check(with == without and with.size() > 15,"No island gives way to a summit (%d islands)" % with.size())
	check(cumulus == cumulus_without and not cumulus.is_empty(),"No cumulus gives way to a summit (%d)" % cumulus.size())
	var taken := true
	for r: Dictionary in rock:
		for q: Vector3 in r.laid.crest:
			if not SkyPeaks.blocks(q): taken = false
	check(taken,"Nothing scattered stands on a summit's crest (SkyPeaks blocks)")

## The glide meets them as stone: over a tip, the solid stands at its top;
## off its rock, none.
func _stone(peaks: Node3D, rock: Array) -> void:
	var ok := true
	var line := ""
	for r: Dictionary in rock:
		var high: Vector3 = r.points[0]
		for p: Vector3 in r.points:
			if p.y > high.y: high = p
		var b: Variant = peaks.body(Vector3(high.x,0.0,high.z))
		# Half the summits' spacing off: off every summit's rock.
		var off: Variant = peaks.ring.summit_body(Vector3(high.x+SkyWorld.SUMMIT_APART*0.5,0.0,high.z))
		if b == null or absf((b as Vector2).x-high.y) > 2.0 or not peaks.solid(Vector3(high.x,high.y-1.0,high.z)) or off != null: ok = false
		line += " %.0f m (%s)," % [high.y,str(b)]
	check(ok,"The glide reads each tip as stone, its solid at its top:%s" % line)

func _slots() -> Array:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	return slots

## Every island's spot within the bounds, as the glide finds them.
func _islands() -> Array:
	var cells := SkyCells.new(_slots())
	var out := []
	var reach := SkyWorld.SCATTER+SkyCells.CELL
	for x in range(int(-reach/SkyCells.CELL)-1,int(reach/SkyCells.CELL)+2):
		for z in range(int(-reach/SkyCells.CELL)-1,int(reach/SkyCells.CELL)+2):
			var found: Variant = cells.spot(Vector2i(x,z))
			if found != null: out.append(found)
	out.append_array(_slots())
	return out

func _towers() -> Array:
	var out := []
	for x in range(-4,5):
		for z in range(-4,5):
			var found: Variant = SkyTowers.spot(Vector2i(x,z))
			if found != null: out.append(found)
	return out

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
