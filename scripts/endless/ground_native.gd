class_name GroundNative
extends RefCounted
## The flight's ground queries' broad phase in C++ (ZenScapeGround,
## native/terrain_kernels/ground_bind.h): the arches, the rocks (with the
## Peak's towers), the Peak's stair and the ice tunnel publish where they stand as world XZ
## rectangles, and `mask` hands back, from one native lookup, which of them
## may answer at a point. The study's `plane_ground`, `_blocked`, `_solid` and
## `_sight` ask only those; the rest answer "nothing here" as they would
## have (the rectangles hold everything each owner's own quick reject lets
## through), so the answers are the owners' own, bit for bit.
##
## Owners say what changed: the arches and rocks `touch` the cell or grid
## square (only its squares are re-marked, so a commit costs little), the
## towers and the stair `bump` their part; the next `mask` republishes it. The loose arches `bump_loose` (the ships move them each
## frame): they are kept apart from the hash, so a move costs little. Main thread only. Off (every bit set: ask them all, as
## before) with --ground-native=0, --gdscript-kernels, no library or a stale
## one. Spec: docs/design/endless-flight/spec-ground-native.md.

const CLASS := &"ZenScapeGround"
const VERSION := 2
## The hash's square (m).
const CELL := 8.0
## The most pad (m) the published rectangles are grown for, where an owner's
## reach grows with it (the towers, the stair); a query grown more asks all.
const MOST_PAD := 16.0
## A metre over, for the stair's frame round-off.
const SLACK := 1.0

const ARCHES := 1
const ROCKS := 2
const STAIR := 4
const ICE := 8
const ALL := 0xffff

## `bump`'s parts: everything, the Peak's towers, the Peak's stair.
const PART_ALL := 1
const PART_TOWERS := 2
const PART_STAIR := 4
## The towers' id in the rocks' layer (a grid square's is its packed key).
const TOWERS_ID := 1 << 62

## The parts to republish at the next `mask`.
static var parts := PART_ALL
## The arches' cells and the rocks' grid squares touched since the last `mask`.
static var touched_arches := {}
static var touched_rocks := {}

## Bumped when the loose arches move or come and go (cheap: only they republish).
static var moved := 0

## An owner's stand changed: the next `mask` republishes `part` (all of it
## by default).
static func bump(part := PART_ALL) -> void:
	parts |= part

## LandArches' cell `key` committed an arch or was freed.
static func touch_arch(key: Vector2i) -> void:
	touched_arches[key] = true

## LandRocks' grid square `key` was filled or emptied.
static func touch_rock(key: Vector2i) -> void:
	touched_rocks[key] = true

static func _id(k: Vector2i) -> int:
	return (k.x << 32) | (k.y & 0xffffffff)

## The loose arches (LandArches `loose`: cracked walls, way towers, the
## ships' hulls and plates) moved, came or went.
static func bump_loose() -> void:
	moved += 1

var on := false
var _g: Object
var _moved_seen := -1
var _loose_n := -1
var arches: Node3D
var rocks: Node3D
var towers: Node3D
var stair: Node3D
var ice: Node3D
## Bits always set (an owner whose stand can't be bounded right now).
var _force := 0
var _force_rocks := 0
var _force_stair := 0

static func wanted() -> bool:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--ground-native=0" or arg == "--gdscript-kernels": return false
	return true

func setup(p_arches: Node3D, p_rocks: Node3D, p_towers: Node3D, p_stair: Node3D, p_ice: Node3D = null) -> void:
	arches = p_arches
	rocks = p_rocks
	towers = p_towers
	stair = p_stair
	ice = p_ice
	on = false
	if not wanted() or not preload("res://scripts/endless/land_field.gd").native_available() or not ClassDB.class_exists(CLASS): return
	_g = ClassDB.instantiate(CLASS)
	if int(_g.version()) != VERSION:
		_g = null
		return
	_g.setup(CELL)
	parts |= PART_ALL
	_moved_seen = -1
	on = true

## The bits of the owners that may answer at `p` with stone grown by `pad`.
func mask(p: Vector3, pad: float) -> int:
	if not on or pad > MOST_PAD: return ALL
	if parts != 0 or not touched_arches.is_empty() or not touched_rocks.is_empty(): _publish()
	if _moved_seen != moved or (arches != null and (arches.loose as Array).size() != _loose_n): _publish_loose()
	return int(_g.near(p.x,p.z)) | _force

## The loose arches, as movers (out of the hash: they republish as they move).
func _publish_loose() -> void:
	_moved_seen = moved
	var out := PackedFloat32Array()
	if arches != null:
		_loose_n = (arches.loose as Array).size()
		for r: Dictionary in arches.loose: out.append_array(_reach_rect(r))
	_g.movers(0,out)

## A record's square of reach round its foot, a hair over (LandArches
## `stretches` skips it past `reach` on either axis, whatever the pad).
static func _reach_rect(r: Dictionary) -> PackedFloat32Array:
	var o: Vector3 = r.pos
	var e := float(r.reach)+0.01
	return PackedFloat32Array([o.x-e,o.z-e,o.x+e,o.z+e])

func _publish() -> void:
	var whole := parts & PART_ALL != 0
	if whole:
		touched_arches.clear()
		touched_rocks.clear()
		_g.publish(0,PackedFloat32Array())
		_g.publish(1,PackedFloat32Array())
		if arches != null:
			for key: Vector2i in arches._cells: _put_arches(key)
		if rocks != null:
			for k: Vector2i in rocks._grid: _put_rock(k)
		_g.publish(3,_ice_rects())
	if whole or parts & PART_TOWERS: _g.put(1,TOWERS_ID,_tower_rects())
	if whole or parts & PART_STAIR: _g.publish(2,_stair_rects())
	parts = 0
	for key: Vector2i in touched_arches: _put_arches(key)
	touched_arches.clear()
	for k: Vector2i in touched_rocks: _put_rock(k)
	touched_rocks.clear()
	_force = _force_rocks | _force_stair

## Arch cell `key`'s records' squares of reach (`_reach_rect`), or none.
func _put_arches(key: Vector2i) -> void:
	var out := PackedFloat32Array()
	if arches != null:
		for r: Dictionary in arches._cells.get(key,[]): out.append_array(_reach_rect(r))
	_g.put(0,_id(key),out)

## A rocks' grid square (LandRocks `_near` reads only the square holding
## the point), shrunk a hair inside so it never marks the next; none once empty.
func _put_rock(k: Vector2i) -> void:
	if rocks == null or not rocks._grid.has(k):
		_g.drop(1,_id(k))
		return
	var g: float = rocks.GRID
	_g.put(1,_id(k),PackedFloat32Array([k.x*g+0.01,k.y*g+0.01,(k.x+1)*g-0.01,(k.y+1)*g-0.01]))

## Each of the Peak's towers' disc of reach grown by MOST_PAD (rocks.extra).
func _tower_rects() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	_force_rocks = 0
	if rocks == null or rocks.extra == null: return out
	if rocks.extra != towers or towers == null:
		_force_rocks = ROCKS
		return out
	if float(towers._pad) > MOST_PAD: _force_rocks = ROCKS
	for s: Dictionary in towers._solids:
		var c: Vector2 = s.mid
		var e := float(s.reach)+MOST_PAD+SLACK
		out.append_array([c.x-e,c.y-e,c.x+e,c.y+e])
	return out

## Each built flight's footprint grown by MOST_PAD, as a world box round its
## corners (PeakStair `ground`'s test, in the flight's frame). A frame that
## tilts (a moved flight) can't be boxed in XZ: the stair is always asked.
func _stair_rects() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	_force_stair = 0
	if stair == null: return out
	var scale: float = stair.SCALE
	var pk := MOST_PAD/scale
	for f: Dictionary in stair.flights:
		if not bool(f.built): continue
		var xf: Transform3D = f.xf
		if absf(xf.basis.y.normalized().dot(Vector3.UP)) < 0.9999:
			_force_stair = STAIR
			continue
		var half := float(f.half)+pk
		var front := float(f.front)+pk
		var back := float(f.front)-float(f.run)-pk
		var lo := Vector2(INF,INF)
		var hi := Vector2(-INF,-INF)
		for c: Vector2 in [Vector2(-half,back),Vector2(half,back),Vector2(-half,front),Vector2(half,front)]:
			var w := xf*Vector3(c.x,0.0,c.y)
			lo = Vector2(minf(lo.x,w.x),minf(lo.y,w.z))
			hi = Vector2(maxf(hi.x,w.x),maxf(hi.y,w.z))
		out.append_array([lo.x-SLACK,lo.y-SLACK,hi.x+SLACK,hi.y+SLACK])
	return out

## The ice tunnel's box (LandIceTunnel `_at` answers nothing outside
## PeakTunnel `box`, already grown by its REACH, whatever the pad) and each
## window's square round its shaft (`window_at`: within WINDOW_R of it, less
## the grow). Its `ground` and `land_y` sample the field before those tests,
## so skipping them off these saves a field.height a query. The tube stands
## once (LandField `ice_tunnel`), so this is published with the rest.
func _ice_rects() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if ice == null or ice.tun == null: return out
	var b: Rect2 = ice.tun.box
	out.append_array([b.position.x-0.01,b.position.y-0.01,b.end.x+0.01,b.end.y+0.01])
	var r: float = ice.tun.WINDOW_R+0.01
	for w: Dictionary in ice.tun.windows:
		var c: Vector2 = w.at
		out.append_array([c.x-r,c.y-r,c.x+r,c.y+r])
	return out
