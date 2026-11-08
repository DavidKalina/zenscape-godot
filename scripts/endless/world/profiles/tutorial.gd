extends "res://scripts/endless/world/profiles/regions.gd"
## The tutorial (--world=tutorial; docs/ship/spec-ship.md, Round 2): the
## land that teaches. Two whole lands on the doors world's map
## (scripts/endless/world/door_map.gd): wilderness at home (x = 0, its own
## coordinates, so its start, shops and sites are where they always are)
## and the tutorial meadow (profiles/tutorial_meadow.gd) OFFSET m east, where
## the flight starts. The ruin hall the lesson's last stage stands
## (scripts/endless/tutorial/tutorial_hall.gd) carries the plane across.
##
## The lesson's stage (scripts/endless/tutorial/tutorial_land.gd sets
## `stage`; --lesson-stage=N gives the first) gates the meadow's land as it
## is built: tree blocks committed below TREES stand bare; ponds and the
## straight river reaches (a long pond, land_ponds.gd) come only in squares
## at WATER or later, in no square that meets `dry` (the land and tree blocks
## left standing round the plane when WATER came, so nothing changes under
## it), and `ahead` stamps a straight reach in the first clear square ahead
## of the plane then; `keep_off` holds trees off the hall's ground. At PARRY
## `stamp_lake` puts a wide reach (`lakes`) ahead for the pirate ship: the
## meadow's ponds and reaches (26 m across) are narrower than she is.
##
## No `side_of`: the doors (region_doors.gd) don't build from the start here.

const DoorMap = preload("res://scripts/endless/world/door_map.gd")
const Ponds = preload("res://scripts/endless/land_ponds.gd")

## From wilderness's home to the meadow's (m, along x), as the doors world.
const OFFSET := 50000.0
## The stages (scripts/endless/tutorial/lesson.gd `Stage`).
const GRASS := 0
const TREES := 1
const WATER := 2
const PARRY := 3
## The share of the meadow's pond squares that hold a straight reach instead.
const REACH_SHARE := 0.12
## A reach: half its length, its half width (m).
const REACH_HALF := 110.0
const REACH_R := 13.0

var offset := Vector2(OFFSET,0.0)
## The lesson's stage now (read on workers and the main thread; set by
## tutorial_land.gd).
var stage := GRASS
## No ponds in a square that meets these (world XZ): the land stood when WATER
## came. Set once, before the land past them is built again.
var dry: Array[Rect2] = []
## How far off the nose the reach stamped ahead may lie (rad).
const AHEAD_TURN := deg_to_rad(15.0)
## The reach stamped ahead at WATER (`stamp_ahead`): square -> [centre XZ,
## angle, half length].
var ahead := {}
## Trees kept off these: [centre XZ, radius] (the hall's ground).
var keep_off: Array = []
## The lake stamped for the ship at PARRY (`stamp_lake`): square -> [centre
## XZ, angle, half length, half width, depth]. Kept for the run (its land
## stands built with it).
var lakes := {}
## The lake: tiers of [half length, half width, the most off the nose (rad),
## nearest and farthest (m)], tried in turn; LAKE_AT m ahead is wanted; its
## depth (m).
const LAKE_TIERS := [[80.0,30.0,deg_to_rad(30.0),300.0,650.0],[60.0,28.0,deg_to_rad(40.0),280.0,750.0],[60.0,28.0,deg_to_rad(65.0),250.0,900.0]]
const LAKE_AT := 470.0
const LAKE_DEPTH := 3.0

func _init() -> void:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--lesson-stage="): stage = clampi(a.get_slice("=",1).to_int(),0,6)
	super()
	id = "tutorial"
	title = "Tutorial"
	Ponds.gate = Callable(self,"pond_gate")

func _region_list() -> Array:
	return [{"id":"wilderness","share":1.0,"start":false},{"id":"tutorial_meadow","share":1.0,"start":true}]

func _make_map(_size: float, band: float, _layout_seed: int, shares: PackedFloat32Array) -> RefCounted:
	var m: RefCounted = DoorMap.new(OFFSET,band,mini(shares.size(),2))
	offset = Vector2(m.size,0.0)
	return m

## The start: the meadow's own, on its side.
func _place_start() -> void:
	start_region = 1
	spawn = (regions[1].spawn as Dictionary).duplicate(true)
	spawn.at = (spawn.at as Vector2)+offset

## Wilderness keeps its coast (LandField `_blend_of`).
func is_doors() -> bool:
	return true

## The side world XZ (x, z) is on: 0 wilderness, 1 the meadow.
func side(x: float, z: float) -> int:
	return int(map.dominant(x,z))

## No sea on the meadow's side: it has no coast (its ponds are the ground's
## own water); the sheet under its flat field only showed through far off.
func sea_at(x: float, z: float) -> bool:
	return side(x,z) == 0

func layer_at(layer: StringName, x: float, z: float) -> bool:
	if layer == &"trees" and side(x,z) == 1:
		if stage < TREES: return false
		for k: Array in keep_off:
			if Vector2(x,z).distance_to(k[0] as Vector2) < float(k[1]): return false
	return super(layer,x,z)

## LandPonds' gate (land_ponds.gd `gate`), on any thread: null rolls the
## square as ever, false holds it dry for now (not kept), an array is its pond.
func pond_gate(seed: int, ci: int, cj: int, impl: Object) -> Variant:
	var c := Vector2((ci+0.5)*Ponds.CELL,(cj+0.5)*Ponds.CELL)
	if side(c.x,c.y) != 1: return null
	if stage < WATER: return false
	var key := Vector2i(ci,cj)
	if lakes.has(key):
		var k: Array = lakes[key]
		return _reach_at(k[0] as Vector2,float(k[1]),float(k[2]),impl,float(k[3]),float(k[4]))
	if ahead.has(key):
		var a: Array = ahead[key]
		return _reach_at(a[0] as Vector2,float(a[1]),float(a[2]),impl)
	if _dry(ci,cj): return false
	var h := float(hash([seed,ci,cj,4401]) & 0xffff)/65536.0
	if h > REACH_SHARE: return null
	return _reach(seed,ci,cj,impl)

func _dry(ci: int, cj: int) -> bool:
	var sq := Rect2(ci*Ponds.CELL,cj*Ponds.CELL,Ponds.CELL,Ponds.CELL)
	for r: Rect2 in dry:
		if r.intersects(sq): return true
	return false

## At WATER, a straight reach stamped in the first square ahead of `at`
## along `dir` (world XZ), between `from` and `most` m out, laid from `at`
## toward it; it clears `dry` and lies wholly inside its own square (as
## every pond does), and stands in place of whatever that square would
## roll. Returns its centre, or INF.
func stamp_ahead(at: Vector2, dir: Vector2, from: float, most: float) -> Vector2:
	ahead = {}
	var d := from
	while d <= most:
		var q := at+dir*d
		d += 20.0
		if side(q.x,q.y) != 1: continue
		var key := Vector2i(floori(q.x/Ponds.CELL),floori(q.y/Ponds.CELL))
		var lo := Vector2(key)*Ponds.CELL
		for half: float in [REACH_HALF,70.0,40.0]:
			var box := half+REACH_R+Ponds.REACH
			if box*2.0 >= Ponds.CELL: continue
			var c := Vector2(clampf(q.x,lo.x+box,lo.x+Ponds.CELL-box),clampf(q.y,lo.y+box,lo.y+Ponds.CELL-box))
			var r := Rect2(c-Vector2(box,box),Vector2(box,box)*2.0)
			var clear := true
			for k: Rect2 in dry:
				if k.intersects(r): clear = false
			if not clear: continue
			# Near the line of flight (the clamp into its square may push it
			# off): at most AHEAD_TURN off the nose, laid along the way there,
			# its near end ahead of the plane.
			var to := c-at
			if absf(dir.angle_to(to)) > AHEAD_TURN: continue
			if to.length()-half < from*0.5: continue
			var ang := to.angle()
			ahead = {key: [c,ang,half]}
			return c
	return Vector2(INF,INF)

## A straight reach across square (ci, cj): a long pond, its level just under
## the lowest ground along it.
func _reach(seed: int, ci: int, cj: int, impl: Object) -> PackedFloat32Array:
	var a := float(hash([seed,ci,cj,4402]) & 0xffff)/65536.0*PI
	return _reach_at(Vector2((ci+0.5)*Ponds.CELL,(cj+0.5)*Ponds.CELL),a,REACH_HALF,impl)

## A reach centred at `c`, along angle `a`, `half` m each way, `r` m half
## wide, `depth` m deep in the middle.
func _reach_at(c: Vector2, a: float, half: float, impl: Object, r := REACH_R, depth := 2.2) -> PackedFloat32Array:
	var d := Vector2(cos(a),sin(a))
	var low := INF
	for t: float in [-1.0,-0.5,0.0,0.5,1.0]:
		for s: float in ([-1.0,1.0] if r <= REACH_R else [-1.0,-0.5,0.0,0.5,1.0]):
			var q := c+d*half*t+Vector2(-d.y,d.x)*s*(r+6.0)
			low = minf(low,float((impl.sample(q.x,q.y) as Vector2).x))
	var p := PackedFloat32Array()
	p.resize(14)
	p[0] = c.x
	p[1] = c.y
	p[2] = r
	p[3] = low-Ponds.BRIM
	p[4] = depth
	p[11] = half+r
	p[12] = half
	p[13] = a
	return p

## At PARRY, a wide reach for the pirate ship (pirate_ship.gd, 130 m long and
## 29 m across) laid across the flight ahead of `at` along `dir` (world XZ),
## about LAKE_AT m out, broadside to the plane coming. Like every pond it
## lies wholly in its own square (CELL m) with its reads' REACH, so its middle
## can only lie near a square's: the squares round the point wanted are
## tried, tier by tier (LAKE_TIERS), clear of `kept` (the land standing near
## the plane, which must not change). It stands in place of that square's
## pond; `Ponds.forget` drops what was kept of the square. Returns {centre,
## angle (of its length), half, r, square and rect (its reads' box; Rect2
## world XZ)}, or {}. Its level is the field's (`river_y`) once stamped.
func stamp_lake(at: Vector2, dir: Vector2, kept: Array[Rect2]) -> Dictionary:
	var want := at+dir*LAKE_AT
	var home := Vector2i(floori(want.x/Ponds.CELL),floori(want.y/Ponds.CELL))
	for tier: Array in LAKE_TIERS:
		var half := float(tier[0])
		var r := float(tier[1])
		var box := half+r+Ponds.REACH
		var best := {}
		var best_d := INF
		for dj in range(-2,3):
			for di in range(-2,3):
				var key := home+Vector2i(di,dj)
				var lo := Vector2(key)*Ponds.CELL
				var c := Vector2(clampf(want.x,lo.x+box,lo.x+Ponds.CELL-box),clampf(want.y,lo.y+box,lo.y+Ponds.CELL-box))
				if side(c.x,c.y) != 1: continue
				var to := c-at
				if to.length() < float(tier[3]) or to.length() > float(tier[4]): continue
				if absf(dir.angle_to(to)) > float(tier[2]): continue
				var rect := Rect2(c-Vector2(box,box),Vector2(box,box)*2.0)
				var clear := true
				for k: Rect2 in kept:
					if k.intersects(Rect2(lo,Vector2(Ponds.CELL,Ponds.CELL))): clear = false
				if not clear: continue
				var dd := c.distance_to(want)
				if dd < best_d:
					best_d = dd
					best = {"key":key,"centre":c,"rect":rect}
		if best.is_empty(): continue
		var c: Vector2 = best.centre
		# Its length across the way to it: her broadside to the plane coming.
		var ang := (c-at).angle()+PI*0.5
		var key: Vector2i = best.key
		lakes[key] = [c,ang,half,r,LAKE_DEPTH]
		Ponds.forget(key)
		return {"centre":c,"angle":ang,"half":half,"r":r,"square":Rect2(Vector2(key)*Ponds.CELL,Vector2(Ponds.CELL,Ponds.CELL)),"rect":best.rect}
	return {}
