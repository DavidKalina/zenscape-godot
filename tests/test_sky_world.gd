extends SceneTree
## suite: slow
## The bounded sky world (scripts/sky_world.gd): one seed, the bounds, the
## whole-world layout (the band round the edge, its foothills and far row,
## the dividing ridges and the regions they cut), and the edge wind.
##
## For several seeds, from the layout alone: the same seed lays the same
## world and another seed another; the old worlds' hash is unchanged under
## the legacy seed; NOTCHES notches spread round the band, MASSIFS massifs
## and GORGES kept gorges in it; the band's footprints clear of the bounds
## (the notches read on the real shapes); the band within BAND_WORLD, far row
## within WORLD; the ridges laid keeping every rule, REGIONS regions with
## the plate's one of them and a pass through every wall across the world, the ridges clear of
## the plate, the fixed islands and the cumulus in sight of the plate; each
## region's cumulus in a region of its own; the plate, the fixed islands and
## the wonders in sight of the plate inside the bounds; nothing scattered
## (islands, islets, cumulus) outside them (SCATTER, clear of the band's
## rock) or on a ridge.
##
## For SHAPED seeds, from the ranges' real shapes (scripts/sky_peak.gd) (the
## band's on BAND_SHAPED): the band stands over the glide's ceiling (CEILING) all the way round, its
## saddles included, but for the notches (open at glide height across their
## middles) and the kept gorges (slots no wider than SLOT); its rock stands
## GAP clear of the bounds. The regions, read off the real rock at glide
## height inside the band (SkyWorld `basins`): as many as laid out, each
## laid-out region's heart in its own; every one reached from every other
## through passes open over PASS_TOP at least PASS_HALF each side of the
## way, every pass laid out so open; the plate's region open round it; every
## region holding islands and islets, the cumulus each in a region of its
## own. The ridges' rock stands clear of the plate and the fixed islands,
## and their tops are varied: walls over the glide's ceiling, low stretches
## under it to hop.
##
## The edge: no wind inside, a smooth one past the band rising over the
## glide's cruise, blowing home; a glide out through every notch, let be,
## is turned home, and one held outward in a dive is held by the wind, never
## stopped dead by a wall. A world saved before the ring keeps its far
## islands: the ranges leave them room and the edge wind starts past them.
## The seed is saved, and a save without one reads as the legacy seed.
##
## The skyline: every range laid out stands far off as coarse faces, steps
## aside for the full range near and comes back when it is let go; a kept
## gorge's jet runs in; and the band's haze leaves it in sight across the
## world while the bounds keep the islands' haze.
## Headless: shapes, spots and the glide's own stepping; nothing drawn.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SEEDS := [7,1,99,12345,31337,424242,5,2024]
## The seeds whose ranges are made for real: the band and the ridges read
## on all of them (BAND_SHAPED).
const SHAPED := [7,12345,99,31337]
const BAND_SHAPED := [7,12345,99,31337]
## How many regions the ridges cut the middle into (at least, at most).
const REGIONS := Vector2i(3,5)
## The real rock's grid (m) for the regions.
const REAL_GRID := 25.0
## The band stands within BAND_WORLD (m) of the middle along x and z, the
## far row within WORLD.
const BAND_WORLD := 4400.0
const WORLD := 5300.0
## Rock to the bounds (m).
const GAP := 150.0
## The glide's ceiling: no climbing over it (SkyGlide CEILING, faded out by
## CEILING_FADE).
const CEILING := SkyGlide.CEILING+SkyGlide.CEILING_FADE
## The widest opening through the band outside the notches (m): a kept
## gorge's slot at the ceiling, its range stretched along its crest (so its
## gorge wider) as laid out.
const SLOT := 600.0
## The notches stay at least this far apart round the ring (radians).
const NOTCH_APART := deg_to_rad(60.0)
const DT := 1.0/30.0

var failures := 0

func _initialize() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	_defaults()
	for s: int in SEEDS:
		SkyWorld.seed = s
		_laid_out(s)
	_deterministic()
	_inside()
	for s: int in SHAPED:
		SkyWorld.seed = s
		_shaped(s)
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	_edge()
	_glide_home()
	_saved()
	_skyline()
	_haze()
	print("PASS: sky world" if failures == 0 else "FAIL: sky world")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## In play the ranges and the ring stand; the other wonders don't.
func _defaults() -> void:
	check(SkyHomes.peaks and not SkyHomes.stone and not SkyHomes.isles and SkyWorld.ring and SkyWorld.ring_on(),"The ranges and the ring stand by default; the other stone wonders and the isles don't")
	check(SkyWorld.seed == SkyWorld.LEGACY_SEED,"A world starts on the legacy seed")
	check(SkyWorld.SLOTS.slice(1) == SkyIslands.OFFSETS,"The layout reads the fixed islands where they stand (SkyIslands OFFSETS)")
	# The hash every kind used before, by hand, under the legacy seed.
	var same := true
	for cell: Vector2i in [Vector2i(0,0),Vector2i(3,-7),Vector2i(-12,40)]:
		for salt in [0,4,1000,3000,5010]:
			var h: int = cell.x*73856093^cell.y*19349663^salt*83492791^7*2654435761
			h = (h^(h >> 13))*1274126177
			h = (h^(h >> 16))*668265263
			h ^= h >> 15
			if not is_equal_approx(float(h & 0xFFFFFF)/float(0x1000000),SkyCells.noise(cell,salt)) or SkyCells.noise(cell,salt) != SkyPeaks.noise(cell,salt): same = false
	check(same,"Under the legacy seed every cell hashes as it did, so an old world's sky is unchanged")
	check(SkyWorld.salted(23) == 23,"The clouds' own seed is unchanged under the legacy seed")

# --- The layout ----------------------------------------------------------------------

static func angle_of(p: Vector3) -> float:
	return fposmod(atan2(p.z,p.x),TAU)

func _laid_out(s: int) -> void:
	var l := SkyWorld.layout()
	var notches: Array = l.notches
	var counts := {}
	var gorges := 0
	for r: Dictionary in l.ranges:
		counts[r.kind] = counts.get(r.kind,0)+1
		if r.gorge and SkyWorld.in_band(r.kind): gorges += 1
	var closest := INF
	for i in range(notches.size()):
		for j in range(i+1,notches.size()): closest = minf(closest,absf(angle_difference(float(notches[i].angle),float(notches[j].angle))))
	check(notches.size() == SkyWorld.NOTCHES and closest >= NOTCH_APART,"Seed %d: %d notches, %.0f deg apart at the closest; ranges %s" % [s,notches.size(),rad_to_deg(closest),counts])
	check(counts.get("massif",0) >= SkyWorld.MASSIFS.x and counts.get("massif",0) <= SkyWorld.MASSIFS.y and gorges >= SkyWorld.GORGES.x and gorges <= SkyWorld.GORGES.y,"Seed %d: %d massifs in the band, %d of its ranges keep their gorge" % [s,counts.get("massif",0),gorges])
	check(counts.get("ridge",0) >= 6 and counts.get("foot",0) >= 2 and counts.get("far",0) >= 1,"Seed %d: ridges, foothills and a far row stand (%d, %d, %d)" % [s,counts.get("ridge",0),counts.get("foot",0),counts.get("far",0)])
	# Footprints: the band's out past the bounds and within the world.
	# (The notches are read on the real shapes.)
	var nearest := INF
	var band_far := 0.0
	var far := 0.0
	for r: Dictionary in l.ranges:
		for p: Vector2 in SkyWorld.box_outline(r):
			if not SkyWorld.in_band(r.kind): continue
			nearest = minf(nearest,p.length())
			far = maxf(far,maxf(absf(p.x),absf(p.y)))
			if r.kind != "far": band_far = maxf(band_far,maxf(absf(p.x),absf(p.y)))
	check(nearest >= SkyWorld.BAND_IN,"Seed %d: the band's footprints %.0f m out at the nearest (its own bound %.0f m)" % [s,nearest,SkyWorld.BAND_IN])
	check(band_far <= BAND_WORLD and far <= WORLD,"Seed %d: the band within %.0f m (%.0f m), its far row within %.0f m (%.0f m)" % [s,BAND_WORLD,band_far,WORLD,far])
	_ridges_laid(s)

## The ridges as laid out: every rule kept, the regions and their passes,
## clear of the plate, the fixed islands and the cumulus in sight of it, a
## region's cumulus each its own region's.
func _ridges_laid(s: int) -> void:
	var l := SkyWorld.layout()
	var regions: Array = l.regions
	var homes := regions.filter(func(g: Dictionary) -> bool: return g.home)
	# Every wall across the world has a pass.
	var walls := {}
	for p: Dictionary in l.passes: walls[int(p.get("chord",-1))] = true
	check(bool(l.kept_rules),"Seed %d: the ridges are laid keeping every rule (try %d)" % [s,int(l.tries)])
	check(regions.size() >= REGIONS.x and regions.size() <= REGIONS.y and homes.size() == 1,"Seed %d: the ridges cut the middle into %d regions, the plate's one of them (room for islands %s km^2)" % [s,regions.size(),str(regions.map(func(g: Dictionary) -> String: return ("home " if g.home else "")+str(g.area)))])
	var narrow: Array = l.passes.filter(func(p: Dictionary) -> bool: return float(p.open) < SkyWorld.PASS_OPEN.x-1.0)
	check(walls.size() == SkyWorld.CHORDS and not walls.has(-1) and narrow.is_empty(),"Seed %d: a pass through each of the %d walls across the world, the one through the range in sight of the plate among them, every one at least %.0f m open (%s m)" % [s,SkyWorld.CHORDS,SkyWorld.PASS_OPEN.x,str(l.passes.map(func(p: Dictionary) -> int: return roundi(p.open)))])
	var near_plate := INF
	var near_slot := INF
	var near_tower := INF
	for r: Dictionary in l.ranges:
		if r.kind != "ridge": continue
		near_plate = minf(near_plate,SkyWorld.box_distance(r,Vector2.ZERO))
		near_tower = minf(near_tower,SkyWorld.box_distance(r,Vector2(SkyHomes.TOWER.x,SkyHomes.TOWER.z)))
		for sl: Vector3 in SkyWorld.SLOTS.slice(1): near_slot = minf(near_slot,SkyWorld.box_distance(r,Vector2(sl.x,sl.z)))
	check(near_plate >= SkyWorld.PLATE_ROOM and near_slot >= SkyWorld.ISLAND_ROOM and near_tower >= SkyHomes.TOWER_KEEP,"Seed %d: the ridges stand %.0f m from the plate, %.0f m from a fixed island, %.0f m from the cumulus in sight of the plate" % [s,near_plate,near_slot,near_tower])
	# The plan's regions: each cumulus in a region of its own, not the plate's.
	var band: Array = l.ranges.filter(func(r: Dictionary) -> bool: return SkyWorld.in_band(r.kind))
	var ridges: Array = l.ranges.filter(func(r: Dictionary) -> bool: return not SkyWorld.in_band(r.kind))
	var n := SkyWorld.grid_size()
	var b := SkyWorld.basins(SkyWorld.plan_open(ridges,SkyWorld._band_open(band)),n,SkyWorld.GRID,SkyWorld.CORE,SkyWorld.PASS_HALF)
	var plate_label: int = b.labels[SkyWorld._grid_index(Vector2.ZERO,n)]
	var held := []
	for t: Vector3 in l.towers:
		var k: int = b.labels[SkyWorld._grid_index(Vector2(t.x,t.z),n)]
		if k < 0 or k == plate_label or k in held: held.append(-9)
		else: held.append(k)
	check(not -9 in held and int(b.count) == regions.size(),"Seed %d: %d of the %d regions past the plate's have a cumulus of their own" % [s,l.towers.size(),regions.size()-1])

func _deterministic() -> void:
	SkyWorld.seed = 99
	var a := str(SkyWorld.layout())
	SkyWorld.seed = 7
	var b := str(SkyWorld.layout())
	SkyWorld.seed = 99
	var c := str(SkyWorld.layout())
	check(a == c and a != b,"A seed always lays the same world, another seed another")
	SkyWorld.seed = SkyWorld.LEGACY_SEED

## The plate, the fixed islands and the wonders in sight of the plate stand
## inside the bounds; nothing scattered stands outside them or on a ridge.
func _inside() -> void:
	var ok := true
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	for s: Vector3 in slots:
		if not SkyWorld.inside(s,SkyIslands.HALF*1.5): ok = false
	for w: Array in SkyHomes.spots():
		if not SkyWorld.inside(w[0]): ok = false
	check(ok,"The plate, the fixed islands and the wonders in sight of the plate stand inside the bounds")
	for s: int in [7,99]:
		SkyWorld.seed = s
		var inner: Array = SkyWorld.layout().ranges.filter(func(r: Dictionary) -> bool: return r.kind == "ridge")
		var cells := SkyCells.new(slots)
		var islets: Node3D = SkyIslets.new()
		islets.cells = cells
		var counts := {"island":0,"islet":0,"tower":0}
		var out := ""
		var on := ""
		var reach := 6000.0
		var spots := []
		for x in range(int(-reach/SkyCells.CELL),int(reach/SkyCells.CELL)+1):
			for z in range(int(-reach/SkyCells.CELL),int(reach/SkyCells.CELL)+1):
				var found: Variant = cells.spot(Vector2i(x,z))
				if found == null: continue
				counts.island += 1
				spots.append(["island",found])
		for x in range(int(-reach/SkyIslets.CELL),int(reach/SkyIslets.CELL)+1):
			for z in range(int(-reach/SkyIslets.CELL),int(reach/SkyIslets.CELL)+1):
				var found: Variant = islets.spot(Vector2i(x,z))
				if found == null: continue
				counts.islet += 1
				spots.append(["islet",found])
		for x in range(-4,5):
			for z in range(-4,5):
				var found: Variant = SkyTowers.spot(Vector2i(x,z))
				if found == null: continue
				counts.tower += 1
				spots.append(["tower",found])
		for sp: Array in spots:
			var p: Vector3 = sp[1]
			if Vector2(p.x,p.z).length() > SkyWorld.SCATTER or not SkyWorld.clear_of_band(Vector2(p.x,p.z),SkyWorld.layout().ranges): out += " %s %s;" % sp
			for r: Dictionary in inner:
				var room := SkyTowers.KEEP if sp[0] == "tower" else SkyPeaks.INNER_CLEAR
				if SkyWorld.box_distance(r,Vector2(p.x,p.z)) < room: on += " %s %s;" % sp
		islets.free()
		check(out == "" and on == "" and counts.island > 15 and counts.islet > 25 and counts.tower >= 1,"Seed %d: nothing scattered stands outside the bounds or on a ridge (%s)%s%s" % [s,counts,out,on])
	SkyWorld.seed = SkyWorld.LEGACY_SEED
	# Wandering: inside, an island turns up ahead; heading out at the edge,
	# none turns up past it.
	var found: Variant = null
	for h in range(8):
		var grid := SkyCells.new(slots)
		for i in range(int((SkyCells.WANDER_TIME+1.0)/DT)):
			found = grid.advance(DT,Vector3(900.0,0.0,900.0),TAU*h/8.0,[Vector3.ZERO],0.0)
			if found != null: break
		if found != null: break
	var edge := SkyCells.new(slots)
	var beyond: Variant = null
	for i in range(int((SkyCells.WANDER_TIME*2.0)/DT)):
		var past: Variant = edge.advance(DT,Vector3(SkyWorld.SCATTER-150.0,0.0,0.0),-PI*0.5,[Vector3.ZERO],0.0)
		if past != null and not SkyWorld.inside(past.home): beyond = past
	check(found != null and SkyWorld.inside(found.home) and beyond == null,"Wandering inside, an island turns up ahead; heading out at the edge, none turns up past it")

# --- The real ranges -------------------------------------------------------------------

## Every range laid out, made: [{shape, at, turn, scale, kind, gorge}];
## and the range in sight of the plate as "home".
func _made() -> Array:
	var out := []
	for r: Dictionary in SkyWorld.layout().ranges:
		out.append({"shape":SkyPeak.make(int(r.seed),float(r.stature),bool(r.gorge)),"at":r.at,"turn":float(r.turn),"scale":r.scale,"kind":r.kind,"gorge":r.gorge,"index":r.index})
	out.append({"shape":SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO),SkyPeaks.stature_of(Vector2i.ZERO)),"at":SkyPeaks.HOME,"turn":SkyPeaks.HOME_TURN,"scale":Vector3.ONE,"kind":"home","gorge":true,"index":-1})
	return out

## The highest rock of `made` (those `take` says yes to) at a home point,
## lifted as placed, or -INF.
static func rock(made: Array, p: Vector2, take := Callable()) -> float:
	var top := -INF
	for m: Dictionary in made:
		if take.is_valid() and not take.call(m): continue
		var at: Vector3 = m.at
		var s: Vector3 = m.scale
		var d := Vector2(p.x-at.x,p.y-at.z)
		if d.length() > SkyPeak.HALF.length()*maxf(s.x,s.z): continue
		var local := Vector3(d.x,0.0,d.y).rotated(Vector3.UP,-float(m.turn))
		var h: Variant = m.shape.height_at(Vector2(local.x/s.x,local.z/s.z))
		if h != null: top = maxf(top,SkyPeak.SEA+(float(h)-SkyPeak.SEA)*s.y)
	return top

## A range's rock over the sea, sampled (home, plate plane), lifted as
## placed: [points, its top].
static func outline(m: Dictionary) -> Array:
	var shape: RefCounted = m.shape
	var s: Vector3 = m.scale
	var at: Vector3 = m.at
	var pts := PackedVector2Array()
	var top := -INF
	var nx: int = shape.nx
	var nz: int = shape.nz
	for j in range(0,nz,4):
		for i in range(0,nx,4):
			var h: float = shape.heights[j*nx+i]
			if h <= SkyPeak.SEA: continue
			top = maxf(top,SkyPeak.SEA+(h-SkyPeak.SEA)*s.y)
			# Only its edge: a neighbour under the sea, or the grid's end.
			var edge := false
			for n: Vector2i in [Vector2i(4,0),Vector2i(-4,0),Vector2i(0,4),Vector2i(0,-4)]:
				var a := i+n.x
				var b := j+n.y
				if a < 0 or b < 0 or a >= nx or b >= nz or shape.heights[b*nx+a] <= SkyPeak.SEA: edge = true
			if not edge: continue
			var p: Vector2 = shape.point(i,j)
			var g := Vector3(p.x*s.x,0.0,p.y*s.z).rotated(Vector3.UP,float(m.turn))
			pts.append(Vector2(at.x+g.x,at.z+g.z))
	return [pts,top]

static func _between(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var best := INF
	for p in a:
		for q in b: best = minf(best,p.distance_squared_to(q))
	return sqrt(best)

func _shaped(s: int) -> void:
	var began := Time.get_ticks_msec()
	var made := _made()
	print("     seed %d: %d ranges made in %.1f s" % [s,made.size(),(Time.get_ticks_msec()-began)/1000.0])
	if s in BAND_SHAPED: _band_real(s,made)
	var outlines := {}
	for m: Dictionary in made:
		if m.kind == "ridge": outlines[m] = outline(m)
	_ridges_real(s,made,outlines)

## The band's real rock: over the ceiling but for the notches and kept
## gorges, clear of the bounds, its massifs over its runs over its
## foothills.
func _band_real(s: int, made: Array) -> void:
	var band := func(m: Dictionary) -> bool: return m.kind != "home" and SkyWorld.in_band(m.kind)
	# Round the band, every fifth of a degree: how high it stands on the way
	# out through it.
	var steps := 1800
	var tops: Array[float] = []
	var nearest := INF
	for k in range(steps):
		var angle := TAU*k/steps
		var c := SkyWorld.crest(angle)
		var way := Vector2(cos(angle),sin(angle))
		var top := -INF
		var r := SkyWorld.BAND_IN-200.0
		while r <= c+1700.0:
			var h := rock(made,way*r,band)
			if h > SkyPeak.SEA: nearest = minf(nearest,r)
			top = maxf(top,h)
			r += 8.0
		tops.append(top)
	# Each notch at the ceiling: from the crest's end before it (the last
	# range of one stretch) to its start after (the first of the next), as
	# laid out; [middle angle, half width].
	var zones := []
	var widths: Array[int] = []
	for n: Dictionary in SkyWorld.layout().notches:
		var a: float = n.angle
		var before := INF
		var after := INF
		for q: Dictionary in SkyWorld.layout().ranges:
			if q.kind != "run" and q.kind != "massif": continue
			if int(q.order) == int(q.of)-1:
				var d := angle_difference(angle_of(q.p_hi),a)
				if d > 0.0: before = minf(before,d)
			if int(q.order) == 0:
				var d := angle_difference(a,angle_of(q.p_lo))
				if d > 0.0: after = minf(after,d)
		zones.append([a+(after-before)*0.5,(after+before)*0.5])
		widths.append(roundi((after+before)*SkyWorld.crest(a)))
	print("     seed %d: the notches %s m wide at the ceiling, crest to crest" % [s,str(widths)])
	# Openings under the ceiling outside the notches: only through the kept
	# gorges, none wider than SLOT.
	var gorge_spans := []
	for m: Dictionary in made:
		if m.kind == "run" and m.gorge:
			var a := angle_of(m.at)
			gorge_spans.append([a,(SkyPeak.HALF.x*float(m.scale.x))/Vector2(m.at.x,m.at.z).length()])
	var widest := 0.0
	var stray := 0
	var slots := 0
	var run := 0.0
	var low := INF
	for i in range(steps+1):
		var k := i%steps
		var angle := TAU*k/steps
		var notch := _in_spans(angle,zones)
		if not notch: low = minf(low,tops[k]) if not _in_spans(angle,gorge_spans) else low
		if tops[k] <= CEILING and not notch:
			run += SkyWorld.crest(angle)*TAU/steps
			if not _in_spans(angle,gorge_spans):
				stray += 1
				if stray < 40: print("       open at %.1f deg, top %.0f m" % [rad_to_deg(angle),tops[k]])
		elif run > 0.0:
			widest = maxf(widest,run)
			slots += 1
			run = 0.0
	check(stray == 0 and widest <= SLOT,"Seed %d: the band stands over the glide's ceiling (%.0f m) all the way round but for the notches and %d slots through its kept gorges (the widest %.0f m; %d fifths of a degree open elsewhere); its lowest saddle %.0f m" % [s,CEILING,slots,widest,stray,low])
	# The notches: open at glide height across their middle.
	var shut := 0
	var looked := 0
	for n: Dictionary in SkyWorld.layout().notches:
		var half := float(n.arc)*0.4/SkyWorld.crest(float(n.angle))
		for k in range(steps):
			var angle := TAU*k/steps
			if absf(angle_difference(angle,float(n.angle))) > half: continue
			looked += 1
			if tops[k] > SkyGlide.FLOOR: shut += 1
	check(shut == 0 and looked > 0,"Seed %d: every notch is open at glide height across its middle (%d of %d looked at shut)" % [s,shut,looked])
	check(nearest >= SkyWorld.BAND_IN,"Seed %d: the band's rock stands %.0f m out at the nearest (its own bound %.0f m)" % [s,nearest,SkyWorld.BAND_IN])
	# The band's tops by kind: massifs over the runs, foothills under them.
	var by_kind := {}
	var outlines := {}
	for m: Dictionary in made:
		var o := outline(m)
		outlines[m] = o
		var t: Array = by_kind.get(m.kind,[])
		t.append(roundi(float(o[1])))
		by_kind[m.kind] = t
	print("     seed %d: tops by kind %s" % [s,by_kind])
	var mean := func(a: Array) -> float: return float(a.reduce(func(x, y): return x+y,0))/maxf(a.size(),1)
	check(mean.call(by_kind.get("massif",[])) > mean.call(by_kind.get("run",[]))+80.0 and mean.call(by_kind.get("foot",[])) < mean.call(by_kind.get("run",[]))-80.0,"Seed %d: the massifs stand over the runs, the foothills under them" % s)

## The ridges' real rock: the regions read off it at glide height, the
## passes through, the islands in each, the ridges clear of the plate and
## the fixed islands, their tops varied.
func _ridges_real(s: int, made: Array, outlines: Dictionary) -> void:
	var l := SkyWorld.layout()
	var began := Time.get_ticks_msec()
	# Open air over PASS_TOP inside the band's crest line, every range's
	# rock read as made.
	var half := 3650.0
	var n := int(half*2.0/REAL_GRID)+1
	var open := PackedByteArray()
	open.resize(n*n)
	for c in range(n*n):
		var p := Vector2(-half+(c%n)*REAL_GRID,-half+(c/n)*REAL_GRID)
		if p.length() >= SkyWorld.crest(atan2(p.y,p.x)):
			open[c] = 0
			continue
		open[c] = 1 if rock(made,p) <= SkyWorld.PASS_TOP else 0
	var b := SkyWorld.basins(open,n,REAL_GRID,SkyWorld.CORE,SkyWorld.PASS_HALF)
	var at := func(p: Vector2) -> int: return clampi(roundi((p.y+half)/REAL_GRID),0,n-1)*n+clampi(roundi((p.x+half)/REAL_GRID),0,n-1)
	var labels: PackedInt32Array = b.labels
	var dist: PackedFloat32Array = b.dist
	print("     seed %d: the regions read off the real rock in %.1f s" % [s,(Time.get_ticks_msec()-began)/1000.0])
	# Each laid-out region's heart in a region of its own.
	var hearts := []
	for g: Dictionary in l.regions: hearts.append(labels[at.call(Vector2(g.at.x,g.at.z))])
	var distinct: bool = hearts.filter(func(k: int) -> bool: return k >= 0 and hearts.count(k) == 1).size() == hearts.size()
	check(int(b.count) == l.regions.size() and distinct,"Seed %d: on the real rock the ridges cut the middle into %d regions (%d laid out), each laid-out region's heart in its own" % [s,b.count,l.regions.size()])
	check(bool(b.connected),"Seed %d: on the real rock every region reaches every other through a pass open over %.0f m, %.0f m wide or more" % [s,SkyWorld.PASS_TOP,SkyWorld.PASS_HALF*2.0])
	var widths := []
	var shut := 0
	for p: Dictionary in l.passes:
		# Its widest opening along the gap laid out.
		var d := 0.0
		for t in range(-10,11):
			var q: Vector3 = p.at+p.along*float(p.open)*0.5*t/10.0
			d = maxf(d,dist[at.call(Vector2(q.x,q.z))])
		widths.append(roundi(d*2.0))
		if d < SkyWorld.PASS_HALF: shut += 1
	check(shut == 0,"Seed %d: every pass laid out is open over %.0f m on the real rock, at least %.0f m across (%s m)" % [s,SkyWorld.PASS_TOP,SkyWorld.PASS_HALF*2.0,str(widths)])
	var plate: int = at.call(Vector2.ZERO)
	var home_label := labels[plate]
	var home_heart := -1
	for k in range(l.regions.size()):
		if l.regions[k].home: home_heart = hearts[k]
	check(home_label >= 0 and home_label == home_heart and dist[plate] >= SkyWorld.PLATE_OPEN*0.9,"Seed %d: the plate stands in its own region, %.0f m from any rock at glide height" % [s,dist[plate]])
	# The range in sight of the plate: nothing over glide height between.
	var hidden := 0
	var not_home := func(m: Dictionary) -> bool: return m.kind != "home"
	for t in range(1,30):
		var p := Vector2(SkyPeaks.HOME.x,SkyPeaks.HOME.z)*t/30.0*0.6
		if rock(made,p,not_home) > 40.0: hidden += 1
	check(hidden == 0,"Seed %d: the range in sight of the plate stays in sight: no ridge between at glide height" % s)
	# Islands, islets and the cumulus in each region.
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var cells := SkyCells.new(slots)
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var islands := []
	islands.resize(int(b.count))
	islands.fill(0)
	var islet_count := islands.duplicate()
	var towers := islands.duplicate()
	var lost := 0
	var reach := SkyWorld.SCATTER+100.0
	var spots := slots.duplicate()
	for x in range(int(-reach/SkyCells.CELL)-1,int(reach/SkyCells.CELL)+1):
		for z in range(int(-reach/SkyCells.CELL)-1,int(reach/SkyCells.CELL)+1):
			var found: Variant = cells.spot(Vector2i(x,z))
			if found != null: spots.append(found)
	for sp: Vector3 in spots:
		var k := labels[at.call(Vector2(sp.x,sp.z))]
		if k < 0: lost += 1
		else: islands[k] += 1
	for x in range(int(-reach/SkyIslets.CELL)-1,int(reach/SkyIslets.CELL)+1):
		for z in range(int(-reach/SkyIslets.CELL)-1,int(reach/SkyIslets.CELL)+1):
			var found: Variant = islets.spot(Vector2i(x,z))
			if found == null: continue
			var k := labels[at.call(Vector2(found.x,found.z))]
			if k >= 0: islet_count[k] += 1
	islets.free()
	for x in range(-2,3):
		for z in range(-2,3):
			var found: Variant = SkyTowers.spot(Vector2i(x,z))
			if found == null: continue
			var k := labels[at.call(Vector2(found.x,found.z))]
			if k >= 0: towers[k] += 1
	var groups := []
	for k in range(islands.size()): groups.append(islands[k]+islet_count[k])
	check(islands.min() >= 1 and groups.min() >= 4 and lost == 0,"Seed %d: every region holds a group: islands %s and islets %s (cumulus %s); none on rock" % [s,str(islands),str(islet_count),str(towers)])
	check(towers.max() <= 1 and towers.count(1) >= 2,"Seed %d: the cumulus stand each in a region of its own, in %d of the %d regions" % [s,towers.count(1),b.count])
	# The ridges' rock: clear of the plate and the fixed islands; tops
	# varied, walls and low stretches.
	var to_plate := INF
	var to_island := INF
	var tops: Array[float] = []
	var walls := 0
	var lows := 0
	for m: Dictionary in made:
		if m.kind != "ridge": continue
		var o: Array = outlines[m]
		tops.append(float(o[1]))
		if float(o[1]) > CEILING: walls += 1
		if float(o[1]) < SkyGlide.CEILING: lows += 1
		for p: Vector2 in o[0]:
			to_plate = minf(to_plate,p.length())
			for sl: Vector3 in SkyWorld.SLOTS.slice(1): to_island = minf(to_island,p.distance_to(Vector2(sl.x,sl.z))-SkyIslands.HALF*1.5)
	check(to_plate >= SkyWorld.PLATE_ROOM*0.8 and to_island >= 150.0,"Seed %d: the ridges' rock stands %.0f m from the plate and %.0f m from a fixed island's edge" % [s,to_plate,to_island])
	tops.sort()
	check(walls >= 3 and lows >= 1,"Seed %d: the ridges' tops are varied, %d walls over the glide's ceiling and %d low stretches under it to hop (%s m)" % [s,walls,lows,str(tops.map(func(v: float) -> int: return roundi(v)))])

static func _in_spans(angle: float, spans: Array) -> bool:
	for sp: Array in spans:
		if absf(angle_difference(angle,float(sp[0]))) <= float(sp[1]): return true
	return false

# --- The edge --------------------------------------------------------------------------

func _edge() -> void:
	var calm := true
	var home_way := true
	var strong := true
	var smooth := 0.0
	for k in range(360):
		var angle := TAU*k/360.0
		var way := Vector3(cos(angle),0.0,sin(angle))
		var c := SkyWorld.crest(angle)
		for r in [0.0,1000.0,SkyWorld.SCATTER,c,c+SkyWorld.OUTSIDE-1.0]:
			if not SkyWorld.edge_air(way*r).is_empty(): calm = false
		var past: Dictionary = SkyWorld.edge_air(way*(c+SkyWorld.OUTSIDE+SkyWorld.RAMP+10.0))
		if past.is_empty() or (past.wind as Vector3).dot(-way) < SkyWorld.EDGE_WIND*0.99: strong = false
		var r := c+SkyWorld.OUTSIDE
		while r < c+SkyWorld.OUTSIDE+SkyWorld.RAMP+3000.0:
			var a: Dictionary = SkyWorld.edge_air(way*r)
			var b: Dictionary = SkyWorld.edge_air(way*(r+10.0))
			var wa: Vector3 = a.get("wind",Vector3.ZERO)
			var wb: Vector3 = b.get("wind",Vector3.ZERO)
			smooth = maxf(smooth,(wb-wa).length())
			if not wb.is_zero_approx() and wb.normalized().dot(-way) < 0.999: home_way = false
			r += 50.0
	check(calm,"No edge wind anywhere inside the band")
	check(strong and home_way,"Past the band's outer flank the wind blows home, harder than the glide cruises (%.0f m/s over %.0f)" % [SkyWorld.EDGE_WIND,SkyGlide.CRUISE])
	check(smooth < 0.25,"It rises smoothly, no wall (at most %.2f m/s more over 10 m)" % smooth)

## A glide out through every notch: let be, it is turned home; held outward
## in a dive, the wind holds it, rising smoothly, never a wall.
func _glide_home() -> void:
	var air := func(p: Vector3) -> Dictionary: return SkyWorld.edge_air(p)
	var none := func(_p: Vector3) -> Variant: return null
	var bound := 0.0
	var home := true
	var held_bound := 0.0
	var held_slow := 0.0
	for n: Dictionary in SkyWorld.layout().notches:
		var way := Vector3(cos(float(n.angle)),0.0,sin(float(n.angle)))
		var c := SkyWorld.crest(float(n.angle))
		# Let be: a few minutes after flying out through the notch.
		var glide := SkyGlide.new()
		glide.launch(way*(c-200.0)+Vector3.UP*40.0,atan2(-way.x,-way.z),SkyGlide.CRUISE,false)
		var out := 0.0
		for i in range(int(240.0/DT)):
			glide.step(DT,{},none,air)
			out = maxf(out,Vector2(glide.position.x,glide.position.z).length()-c)
		bound = maxf(bound,out)
		var flat := Vector2(glide.position.x,glide.position.z)
		var moving := Vector2(glide.velocity.x,glide.velocity.z)
		if flat.length()-c > SkyWorld.OUTSIDE+SkyWorld.RAMP and moving.dot(flat) > 0.0: home = false
		# Held outward, nose down: held all the same.
		var held := SkyGlide.new()
		held.launch(way*(c-200.0)+Vector3.UP*40.0,atan2(-way.x,-way.z),SkyGlide.CRUISE,false)
		var held_out := 0.0
		var late := 0.0
		for i in range(int(360.0/DT)):
			held.heading = atan2(-way.x,-way.z)
			held.step(DT,{"dive":1.0},none,air)
			held_out = maxf(held_out,Vector2(held.position.x,held.position.z).length()-c)
			late = Vector2(held.velocity.x,held.velocity.z).dot(Vector2(way.x,way.z))
		held_bound = maxf(held_bound,held_out)
		held_slow = maxf(held_slow,late)
	check(home and bound < SkyWorld.OUTSIDE+SkyWorld.RAMP+600.0,"Flown out through a notch and let be, the glide is turned home (at most %.0f m past the crest line)" % bound)
	check(held_slow < 2.0 and held_bound < SkyWorld.OUTSIDE+SkyWorld.RAMP+1500.0,"Held outward in a dive, the edge wind holds it all the same (at most %.0f m past the crest line, making %.1f m/s outward by the end), never a wall" % [held_bound,held_slow])

# --- Saved worlds ----------------------------------------------------------------------

func _saved() -> void:
	var islands: Node3D = SkyIslands.new()
	islands.load_state({})
	check(SkyWorld.seed == SkyWorld.LEGACY_SEED and int(islands.save_state().get("seed",-1)) == SkyWorld.LEGACY_SEED,"A new world takes the legacy seed and saves it")
	islands.load_state({"origin":[0.0,0.0,0.0],"plate_seed":-1,"built":[],"seed":99})
	check(SkyWorld.seed == 99 and int(islands.save_state().seed) == 99,"A world's seed is read back from its save")
	islands.load_state({"origin":[0.0,0.0,0.0],"plate_seed":-1,"built":[]})
	check(SkyWorld.seed == SkyWorld.LEGACY_SEED,"A save from before the seed reads as the legacy seed")
	# A world saved before the ring, with islands out where the band stands.
	var before: int = SkyWorld.layout().ranges.size()
	var r: Dictionary = SkyWorld.layout().ranges[2]
	var far: Vector3 = r.at+Vector3(0.0,-10.0,0.0)
	islands.load_state({"origin":[-far.x,10.0,-far.z],"plate_seed":-1,"built":[{"home":[far.x+400.0,0.0,far.z],"label":"Far","document":{}}]})
	var after: Array = SkyWorld.layout().ranges
	var clear := true
	for q: Dictionary in after:
		for h: Vector3 in [far,far+Vector3(400.0,0.0,0.0)]:
			if SkyWorld.box_distance(q,Vector2(h.x,h.z)) < 200.0: clear = false
	var calm := SkyWorld.edge_air(far).is_empty() and SkyWorld.edge_air(far+Vector3(400.0,0.0,0.0)).is_empty()
	check(after.size() < before and clear and calm,"Islands saved out where the band stands keep their place: %d of %d ranges leave them room, and no edge wind blows there" % [after.size(),before])
	islands.load_state({})
	check(SkyWorld.layout().ranges.size() == before and SkyWorld.kept.is_empty(),"Islands inside the bounds change nothing")
	islands.free()

# --- The skyline -----------------------------------------------------------------------

func _skyline() -> void:
	var cells := SkyCells.new([Vector3.ZERO])
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build([Vector3.ZERO])
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	var began := Time.get_ticks_msec()
	peaks.ring.warm(peaks)
	peaks.reset(cells,currents)
	peaks.flush()
	# Every range laid out, and the one in sight of the plate (its skyline
	# finer: SkyRing HOME_STRIDE), which the build view stands on too.
	var count: int = SkyWorld.layout().ranges.size()+1
	print("     the skyline's %d ranges made in %.1f s (workers)" % [count,(Time.get_ticks_msec()-began)/1000.0])
	var faces := 0
	var bytes := 0
	for key in peaks.ring.lines:
		var mesh := peaks.ring.lines[key].node.get_node("Body").mesh as ArrayMesh
		faces += mesh.surface_get_array_len(0)/3
		# Position, normal, colour, two UVs a vertex.
		bytes += mesh.surface_get_array_len(0)*(12+12+16+8+8)
	print("     the skyline: %d faces, %.1f MB of vertices" % [faces,bytes/1048576.0])
	# The most ranges standing in full at once, anywhere inside the band: the
	# laid ones within their reach of the eye (SkyPeaks `build_reach`), the
	# one in sight of the plate within BUILD.
	var worst := 0
	var worst_at := Vector2.ZERO
	for x in range(-3400,3401,100):
		for z in range(-3400,3401,100):
			var p := Vector2(x,z)
			if p.length() > SkyWorld.crest(p.angle()): continue
			var near := 1 if p.distance_to(Vector2(SkyPeaks.HOME.x,SkyPeaks.HOME.z)) <= SkyPeaks.BUILD else 0
			for q: Dictionary in SkyWorld.layout().ranges:
				if p.distance_to(Vector2(q.at.x,q.at.z)) <= SkyPeaks.build_reach(Vector2i(SkyPeaks.RING_ROW,int(q.index))).x: near += 1
			if near > worst:
				worst = near
				worst_at = p
	# Their faces there, from each skyline's (every STRIDE-th point): near
	# (LOD_NEAR) every `detail_of`-th, further LOD_STRIDE times coarser.
	var drawn := 0.0
	var every := 0.0
	for q: Dictionary in SkyWorld.layout().ranges:
		var c := Vector2i(SkyPeaks.RING_ROW,int(q.index))
		var d := worst_at.distance_to(Vector2(q.at.x,q.at.z))
		if d > SkyPeaks.build_reach(c).x: continue
		var line_mesh := peaks.ring.lines[peaks._key(c)].node.get_node("Body").mesh as ArrayMesh
		var stride: int = preload("res://scripts/sky_ring.gd").STRIDE_LOW if SkyPeaks.coarse_of(c) else preload("res://scripts/sky_ring.gd").STRIDE
		var full := line_mesh.surface_get_array_len(0)/3.0*stride*stride
		var step := SkyPeaks.detail_of(c)*(1 if d <= SkyPeaks.LOD_NEAR else SkyPeaks.LOD_STRIDE)
		drawn += full/(step*step)
		every += full/(1 if d <= SkyPeaks.LOD_NEAR else SkyPeaks.LOD_STRIDE*SkyPeaks.LOD_STRIDE)
	print("     at the worst spot (%.0f, %.0f) %d ranges stand in full at once: about %.0fk faces drawn (%.0fk were every ridge drawn at the band's detail)" % [worst_at.x,worst_at.y,worst,drawn/1000.0,every/1000.0])
	check(peaks.ring.line_count() == count and peaks.ring.lines.has(peaks._key(Vector2i.ZERO)),"Every range laid out, and the one in sight of the plate, stands far off as a skyline (%d, %d faces in all)" % [count,faces])
	# Near a band range keeping its gorge: made in full, its skyline aside.
	var r: Dictionary = {}
	for q: Dictionary in SkyWorld.layout().ranges:
		if q.kind == "run" and q.gorge: r = q
	var cell := Vector2i(SkyPeaks.RING_ROW,int(r.index))
	var key: String = peaks._key(cell)
	var eye: Vector3 = r.at*0.85
	peaks.advance(1.0,eye)
	peaks.flush()
	check(peaks.built.has(key) and not peaks.ring.showing(key),"Flown near, the range is made in full and its skyline steps aside")
	var shown := 0
	for k in peaks.ring.lines:
		if peaks.ring.showing(k): shown += 1
	check(shown == count-_ring_built(peaks),"Every range not made in full still shows as skyline (%d)" % shown)
	check(peaks.body(r.at+Vector3(0.0,500.0,0.0)) != null or _solid_somewhere(peaks,r),"The range made in full is a solid to the glide")
	check((peaks.built[key].node as Node3D).scale.is_equal_approx(r.scale),"It stands scaled as laid out")
	# Its jet runs in through its gorge; a range without one has none.
	var inward := true
	var jets := 0
	for c: Dictionary in currents.currents:
		if str(c.get("key","")) != "peak:"+key: continue
		jets += 1
		var pts: PackedVector3Array = c.points
		if Vector2(pts[0].x,pts[0].z).length() <= Vector2(pts[pts.size()-1].x,pts[pts.size()-1].z).length(): inward = false
	var gorgeless := 0
	for k in peaks.built:
		if SkyPeaks.is_ring(peaks.built[k].cell) and not SkyPeaks.gorge_of(peaks.built[k].cell):
			for c: Dictionary in currents.currents:
				if str(c.get("key","")) == "peak:"+k: gorgeless += 1
	check(jets == 1 and inward and gorgeless == 0,"A kept gorge's jet runs in through it, toward the world's middle; the whole ranges have none")
	# Flown back to the middle: let go, and the skyline back.
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	check(not peaks.built.has(key) and peaks.ring.showing(key),"Flown away, it is let go and its skyline comes back")
	# A new glide keeps the skyline made.
	peaks.reset(cells,currents)
	check(peaks.ring.line_count() == count and peaks.ring._making.is_empty(),"A new glide keeps the skyline as it was, nothing made again")
	peaks.queue_free()
	currents.queue_free()

func _ring_built(peaks: Node3D) -> int:
	var n := 0
	for key in peaks.built:
		if peaks.ring.lines.has(key): n += 1
	return n

func _solid_somewhere(peaks: Node3D, r: Dictionary) -> bool:
	for dx in range(-600,601,40):
		for dz in range(-600,601,40):
			if peaks.body(r.at+Vector3(dx,0.0,dz)) != null: return true
	return false

# --- The haze --------------------------------------------------------------------------

func _haze() -> void:
	var middle := Vector3.ZERO
	# From the plate, the band stands in sight; on the far side of the world
	# from its edge, it is all but gone.
	var near_seen := 1.0-SkyHaze.fog_ring(SkyWorld.RADIUS,60.0)
	var island_seen := 1.0-SkyHaze.fog(SkyWorld.RADIUS,60.0)
	var across := 1.0-SkyHaze.fog_ring(SkyWorld.RADIUS*2.2,60.0)
	check(near_seen > 0.3 and island_seen < 0.01,"From the plate the band stands in sight (%.0f%% seen at %.0f m, where an island would be gone)" % [near_seen*100.0,SkyWorld.RADIUS])
	check(across < 0.05,"From one edge, the far side of the band is all but gone (%.1f%% seen)" % (across*100.0))
	check(SkyWorld.VIEW_FAR > SkyWorld.HAZE_WHOLE,"The glide's view reaches past where the band's haze is whole (%.0f m)" % SkyWorld.VIEW_FAR)
	# Nothing scattered takes the band's curve: the bounds stand inside it.
	# Nothing scattered takes the band's curve, all the way out to the
	# bounds; the band's rock does, every way round.
	var cells := SkyCells.new([Vector3.ZERO])
	var ringed := 0
	var looked := 0
	for x in range(-7,7):
		for z in range(-7,7):
			var at: Variant = cells.spot(Vector2i(x,z))
			if at == null: continue
			looked += 1
			if SkyHaze.ring_share(at,middle) > 0.0: ringed += 1
	var bare := 0
	for r: Dictionary in SkyWorld.layout().ranges:
		if r.kind != "run" and r.kind != "massif": continue
		if SkyHaze.ring_share(r.at,middle) < 1.0: bare += 1
	check(looked > 20 and ringed == 0 and bare == 0,"The islands' haze keeps to the bounds (%d islands, %d on the band's curve, out to %.0f m); the band's rock takes its own (%d of its ranges' middles not)" % [looked,ringed,SkyWorld.SCATTER,bare])
	var spot := SkyHaze.ring_spot(Vector3(100.0,0.0,-50.0))
	check(spot == Vector4(100.0,-50.0,SkyWorld.HAZE_FROM,SkyWorld.HAZE_TO),"The shader is told where the world's middle is now")
