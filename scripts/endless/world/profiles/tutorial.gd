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
## first asked at WATER or later and outside `dry_r` m of where the plane was
## when WATER came (so no square the near land already stood on changes
## under it); `keep_off` holds trees off the hall's ground.
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
## The share of the meadow's pond squares that hold a straight reach instead.
const REACH_SHARE := 0.12
## A reach: half its length, its half width (m).
const REACH_HALF := 110.0
const REACH_R := 13.0

var offset := Vector2(OFFSET,0.0)
## The lesson's stage now (read on workers and the main thread; set by
## tutorial_land.gd).
var stage := GRASS
## No ponds within dry_r m of dry_at (world XZ): the land stood when WATER came.
var dry_at := Vector2(INF,INF)
var dry_r := 0.0
## Trees kept off these: [centre XZ, radius] (the hall's ground).
var keep_off: Array = []

func _init() -> void:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--lesson-stage="): stage = clampi(a.get_slice("=",1).to_int(),0,5)
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
	if c.distance_to(dry_at) < dry_r+Ponds.CELL*0.71: return false
	var h := float(hash([seed,ci,cj,4401]) & 0xffff)/65536.0
	if h > REACH_SHARE: return null
	return _reach(seed,ci,cj,impl)

## A straight reach across square (ci, cj): a long pond, its level just under
## the lowest ground along it.
func _reach(seed: int, ci: int, cj: int, impl: Object) -> PackedFloat32Array:
	var a := float(hash([seed,ci,cj,4402]) & 0xffff)/65536.0*PI
	var c := Vector2((ci+0.5)*Ponds.CELL,(cj+0.5)*Ponds.CELL)
	var d := Vector2(cos(a),sin(a))
	var low := INF
	for t: float in [-1.0,-0.5,0.0,0.5,1.0]:
		for s: float in [-1.0,1.0]:
			var q := c+d*REACH_HALF*t+Vector2(-d.y,d.x)*s*(REACH_R+6.0)
			low = minf(low,float((impl.sample(q.x,q.y) as Vector2).x))
	var p := PackedFloat32Array()
	p.resize(14)
	p[0] = c.x
	p[1] = c.y
	p[2] = REACH_R
	p[3] = low-Ponds.BRIM
	p[4] = 2.2
	p[11] = REACH_HALF+REACH_R
	p[12] = REACH_HALF
	p[13] = a
	return p
