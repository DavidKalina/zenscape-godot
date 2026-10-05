extends SceneTree
## The wonders round the plate laid out together (scripts/sky_homes.gd): the
## mountain range, the pillar forest, the tepui, the towering cumulus and
## the forested isle in sight of the plate each stand within sight of it,
## in their own directions, turned to it where that matters, their rock
## (cloud, for the tower) at least GAP from every other's and from every
## fixed island, out of the islands' jet streams and thermals, and out of
## each other's keep-outs; and the kinds scattered through the far cells
## never land on another kind, nor islands on any of them. Footprints are
## read from each one's real shape (its grid over the sea, its pillars'
## bounds, its cloud's lobes, its rim), not its keep. Headless: shapes and
## spots only, nothing drawn.
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPillars = preload("res://scripts/sky_pillars.gd")
const SkyPillar = preload("res://scripts/sky_pillar.gd")
const SkyTepuis = preload("res://scripts/sky_tepuis.gd")
const SkyTepui = preload("res://scripts/sky_tepui.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyTower = preload("res://scripts/sky_tower.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyForestIsle = preload("res://scripts/sky_forest_isle.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")

## Rock to rock between two wonders, and from a wonder to a fixed island's
## edge (m).
const GAP := 150.0
## From a wonder's rock to the islands' jet streams and thermals (m, plate
## plane: none passes over or through it at all).
const AIR := 60.0
## Within sight of the plate: each middle this far off (m).
const SIGHT := Vector2(450.0,1300.0)
## No two in the same direction from the plate (radians).
const APART := deg_to_rad(45.0)
## The scattered cells looked at round the origin, each grid.
const WINDOW := 6

var failures := 0
## Each home wonder: {name, middle, turn, keep, outline (global plate-plane
## points), extra (points of its air and water that must stay clear too),
## reach}.
var homes := []

func _initialize() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	_off_in_play()
	SkyHomes.stone = true
	SkyHomes.isles = true
	_gather()
	_in_sight()
	_facing()
	_apart()
	_clear_of_islands()
	_scattered()
	print("PASS: sky layout" if failures == 0 else "FAIL: sky layout")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Off in play (SkyHomes `stone`, `isles`): only the cumulus stands, and no
## range, pillar forest, tepui or isle turns up or keeps anything out.
func _off_in_play() -> void:
	check(not SkyHomes.stone and not SkyHomes.isles,"The stone wonders and the forested isles start off")
	check(SkyHomes.spots() == [[SkyHomes.TOWER,SkyHomes.TOWER_KEEP]],"Only the towering cumulus stands in sight of the plate")
	var none := true
	for x in range(-WINDOW,WINDOW+1):
		for z in range(-WINDOW,WINDOW+1):
			var cell := Vector2i(x,z)
			if SkyPeaks.spot(cell) != null or SkyForestIsles.spot(cell) != null: none = false
	check(none,"No range or isle turns up in any cell")
	check(not SkyPeaks.blocks(SkyPeaks.HOME) and not SkyPeaks.blocks(SkyPillars.HOME) and not SkyPeaks.blocks(SkyTepuis.HOME) and not SkyForestIsles.blocks(SkyForestIsles.HOME),"Nothing is kept clear for them")
	var peaks: Node3D = SkyPeaks.new()
	var isles: Node3D = SkyForestIsles.new()
	var cells := SkyCells.new([Vector3.ZERO])
	peaks.reset(cells)
	isles.reset(cells)
	peaks.advance(1.0,Vector3.ZERO)
	isles.advance(1.0,Vector3.ZERO)
	peaks.flush()
	isles.flush()
	check(peaks.range_count() == 0 and peaks.kinds[0].forest_count() == 0 and peaks.tepuis.tepui_count() == 0 and isles.isle_count() == 0,"Reset and run, none is made")
	peaks.free()
	isles.free()

# --- The home wonders' footprints ---------------------------------------------------

func _gather() -> void:
	var peak: RefCounted = SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO))
	var gorge := []
	for p: Vector3 in peak.gorge_line(SkyPeaks.JET_Y,32): gorge.append(Vector2(p.x,p.z))
	_add("range",SkyPeaks.HOME,SkyPeaks.HOME_TURN,SkyPeaks.KEEP,_grid_outline(peak,SkyPeak.SEA),gorge)
	var forest: RefCounted = SkyPillar.make(SkyPillars.seed_of(Vector2i.ZERO))
	var rings := []
	for q: Dictionary in forest.pillars:
		for y in [SkyPillar.SEA,float(q.top)]: rings.append_array(_circle(forest.axis(q,y),float(q.bound),16))
	var thread := []
	for p: Vector3 in forest.thread_line(SkyPillar.THREAD_Y,24): thread.append(Vector2(p.x,p.z))
	_add("pillars",SkyPillars.HOME,SkyPillars.HOME_TURN,SkyPillars.KEEP,rings,thread)
	var tepui: RefCounted = SkyTepui.make(SkyTepuis.SEED)
	var feet := []
	for f: Dictionary in tepui.falls:
		var foot := SkyTepui.fall_point(f,float(f.drop))
		feet.append(Vector2(foot.x,foot.z))
	_add("tepui",SkyTepuis.HOME,SkyTepuis.HOME_TURN,SkyTepuis.KEEP,_grid_outline(tepui,SkyTepui.SEA),feet)
	var tower: RefCounted = SkyTower.make(SkyTowers.seed_of(Vector2i.ZERO))
	var lobes := []
	for l: Vector4 in tower.lobes: lobes.append_array(_circle(Vector2(l.x,l.z),l.w+SkyTowers.EDGE,24))
	_add("tower",SkyTowers.HOME,0.0,SkyTowers.KEEP,lobes,[])
	var isle: RefCounted = SkyForestIsle.make(SkyForestIsles.seed_of(Vector2i.ZERO))
	var rim := []
	for k in range(144): rim.append(isle.rim_point(TAU*k/144.0))
	# The broken-off chunk and every other piece: the edge of its whole
	# footprint, on a grid.
	var e: Vector2 = isle.ext*1.5
	for x in range(int(-e.x),int(e.x),6):
		for z in range(int(-e.y),int(e.y),6):
			var p := Vector2(x,z)
			if isle.share(p) > 1.0: continue
			for n: Vector2 in [Vector2(6,0),Vector2(-6,0),Vector2(0,6),Vector2(0,-6)]:
				if isle.share(p+n) > 1.0:
					rim.append(p)
					break
	_add("isle",SkyForestIsles.HOME,SkyForestIsles.HOME_TURN,SkyForestIsles.KEEP,rim,[])
	for h: Dictionary in homes: print("     %s at (%.0f, %.0f): %.0f m off the plate, bearing %.0f deg, reach %.0f m, nearest rock %.0f m from the plate" % [h.name,h.middle.x,h.middle.z,Vector2(h.middle.x,h.middle.z).length(),rad_to_deg(atan2(h.middle.z,h.middle.x)),h.reach,_nearest(h.outline,Vector2.ZERO)])

func _add(name: String, middle: Vector3, turn: float, keep: float, local: Array, extra: Array) -> void:
	var at := Vector2(middle.x,middle.z)
	var outline := PackedVector2Array()
	var reach := 0.0
	for p: Vector2 in local:
		outline.append(at+_turned(p,turn))
		reach = maxf(reach,p.length())
	var air := PackedVector2Array()
	for p: Vector2 in extra: air.append(at+_turned(p,turn))
	homes.append({"name":name,"middle":middle,"turn":turn,"keep":keep,"outline":outline,"extra":air,"reach":reach})

## A local plate-plane point turned about y as the nodes are (Node3D
## rotation.y).
static func _turned(p: Vector2, turn: float) -> Vector2:
	var v := Vector3(p.x,0.0,p.y).rotated(Vector3.UP,turn)
	return Vector2(v.x,v.z)

static func _circle(c: Vector2, r: float, n: int) -> Array:
	var out := []
	for k in range(n): out.append(c+Vector2.from_angle(TAU*k/n)*r)
	return out

## The edge of a heightfield's rock over the sea: grid points over it with
## a neighbour under it (or at the grid's edge).
static func _grid_outline(shape: RefCounted, sea: float) -> Array:
	var out := []
	var nx: int = shape.nx
	var nz: int = shape.nz
	var s := 2
	for j in range(0,nz,s):
		for i in range(0,nx,s):
			if shape.heights[j*nx+i] <= sea: continue
			var edge := false
			for n: Vector2i in [Vector2i(s,0),Vector2i(-s,0),Vector2i(0,s),Vector2i(0,-s)]:
				var a := i+n.x
				var b := j+n.y
				if a < 0 or b < 0 or a >= nx or b >= nz or shape.heights[b*nx+a] <= sea:
					edge = true
					break
			if edge: out.append(shape.point(i,j))
	return out

static func _nearest(points: PackedVector2Array, to: Vector2) -> float:
	var best := INF
	for p in points: best = minf(best,p.distance_to(to))
	return best

static func _between(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var best := INF
	for p in a:
		for q in b: best = minf(best,p.distance_squared_to(q))
	return sqrt(best)

# --- Checks -------------------------------------------------------------------------

## Each middle within sight of the plate, its nearest rock well off it, and
## no two in the same direction.
func _in_sight() -> void:
	var worst := ""
	for h: Dictionary in homes:
		var off := Vector2(h.middle.x,h.middle.z).length()
		var near := _nearest(h.outline,Vector2.ZERO)
		if off < SIGHT.x or off > SIGHT.y or near < GAP+SkyIslands.HALF*1.5: worst += " %s %.0f m off (rock %.0f m);" % [h.name,off,near]
	check(worst == "","Every one stands within sight of the plate (%.0f-%.0f m), its rock clear of it%s" % [SIGHT.x,SIGHT.y,worst])
	var closest := INF
	for i in range(homes.size()):
		for j in range(i+1,homes.size()):
			var a: Vector3 = homes[i].middle
			var b: Vector3 = homes[j].middle
			closest = minf(closest,absf(angle_difference(atan2(a.z,a.x),atan2(b.z,b.x))))
	check(closest >= APART,"Each stands in its own direction from the plate (%.0f deg apart at the closest)" % rad_to_deg(closest))

## Turned to the plate: the range's long face and gorge mouth, the pillars'
## thread side, the isle's long side, and the tepui's fall three-quarter on.
func _facing() -> void:
	for h: Dictionary in homes:
		if h.name == "tower": continue
		var front := Vector3(0.0,0.0,1.0).rotated(Vector3.UP,h.turn)
		var to_plate := -Vector3(h.middle.x,0.0,h.middle.z).normalized()
		var off := front.angle_to(to_plate)
		if h.name == "tepui": check(off > 0.1 and off < 0.35,"The tepui's great fall pours toward the plate, three-quarter on (%.2f rad off)" % off)
		else: check(off < 0.05,"The %s's side is turned square to the plate (%.3f rad off)" % [h.name,off])

## Rock to rock, GAP at least between every two; each one's air and falls
## (the gorge's jet, the thread, the falls' feet) clear of the others' rock;
## and no one's rock inside another's keep-out.
func _apart() -> void:
	for i in range(homes.size()):
		for j in range(i+1,homes.size()):
			var a: Dictionary = homes[i]
			var b: Dictionary = homes[j]
			var rock := _between(a.outline,b.outline)
			var air := INF
			if not (a.extra as PackedVector2Array).is_empty(): air = minf(air,_between(a.extra,b.outline))
			if not (b.extra as PackedVector2Array).is_empty(): air = minf(air,_between(b.extra,a.outline))
			var middle := Vector2(a.middle.x-b.middle.x,a.middle.z-b.middle.z).length()
			var kept := middle-maxf(a.keep+b.reach,b.keep+a.reach)
			check(rock >= GAP and air >= GAP and kept > 0.0,"%s and %s: %.0f m rock to rock, %.0f m from air and falls to rock, %.0f m to spare past the keep-outs" % [a.name,b.name,rock,air,kept])

## Clear of every fixed island (and the plate) and of the islands' jet
## streams and thermals; no fixed island inside a keep-out.
func _clear_of_islands() -> void:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var air := PackedVector2Array()
	for c: Dictionary in currents.currents:
		for p: Vector3 in c.points: air.append(Vector2(p.x,p.z))
	currents.free()
	for h: Dictionary in homes:
		var rock := INF
		var kept := INF
		for s: Vector3 in slots:
			if s != Vector3.ZERO: rock = minf(rock,_nearest(h.outline,Vector2(s.x,s.z))-SkyIslands.HALF*1.5)
			kept = minf(kept,Vector2(s.x-h.middle.x,s.z-h.middle.z).length()-h.keep)
		var stream := _between(h.outline,air)
		var flows := _between(h.extra,air) if not (h.extra as PackedVector2Array).is_empty() else INF
		check(rock >= GAP and kept > 0.0 and stream >= AIR and flows >= AIR,"The %s: %.0f m from its rock to a fixed island, %.0f m to spare past its keep, %.0f m to the islands' currents (its own air %.0f m)" % [h.name,rock,kept,stream,flows])

# --- The far cells ------------------------------------------------------------------

## Every kind's scattered spots within WINDOW cells of the origin, on every
## grid: none stands within another kind's keep-out (its own keep taken in);
## no island and no islet stands on any of them.
func _scattered() -> void:
	var spots := []
	for x in range(-WINDOW,WINDOW+1):
		for z in range(-WINDOW,WINDOW+1):
			var c := Vector2i(x,z)
			var r: Variant = SkyPeaks.spot(c)
			if r != null: spots.append({"kind":"range","at":Vector3(r.x,0.0,r.z),"keep":SkyPeaks.KEEP*SkyPeaks.spread_of(c),"cell":c})
			var p: Variant = SkyPillars.spot(c)
			if p != null: spots.append({"kind":"pillars","at":Vector3(p.x,0.0,p.z),"keep":SkyPillars.KEEP,"cell":c})
			var t: Variant = SkyTowers.spot(c)
			if t != null: spots.append({"kind":"tower","at":t,"keep":SkyTowers.KEEP,"cell":c})
			var i: Variant = SkyForestIsles.spot(c)
			if i != null: spots.append({"kind":"isle","at":Vector3(i.x,0.0,i.z),"keep":SkyForestIsles.KEEP,"cell":c})
	for s: Vector4 in SkyTepuis.spots(): spots.append({"kind":"tepui","at":Vector3(s.x,0.0,s.z),"keep":SkyTepuis.KEEP,"cell":Vector2i.ZERO})
	var counts := {}
	var bad := ""
	var tightest := INF
	for a in range(spots.size()):
		counts[spots[a].kind] = counts.get(spots[a].kind,0)+1
		for b in range(a+1,spots.size()):
			var u: Dictionary = spots[a]
			var v: Dictionary = spots[b]
			if u.kind == v.kind: continue
			var spare: float = Vector2(u.at.x-v.at.x,u.at.z-v.at.z).length()-float(u.keep)-float(v.keep)
			tightest = minf(tightest,spare)
			if spare < 0.0: bad += " %s %s on %s %s (%.0f m);" % [u.kind,u.cell,v.kind,v.cell,spare]
	check(bad == "" and counts.get("range",0) > 4 and counts.get("tower",0) > 4 and counts.get("isle",0) > 4,
		"No kind scattered through the far cells lands on another (%s; %.0f m to spare at the tightest)%s" % [counts,tightest,bad])
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var cells := SkyCells.new(slots)
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var on := 0
	var looked := 0
	for x in range(-WINDOW*4,WINDOW*4+1):
		for z in range(-WINDOW*4,WINDOW*4+1):
			for found: Variant in [cells.spot(Vector2i(x,z)),islets.spot(Vector2i(x,z))]:
				if found == null: continue
				looked += 1
				for s: Dictionary in spots:
					if Vector2(found.x-s.at.x,found.z-s.at.z).length() < float(s.keep): on += 1
	islets.free()
	check(on == 0 and looked > 200,"No island or islet turns up on any of them (%d looked at)" % looked)
