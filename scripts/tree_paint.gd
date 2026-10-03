extends "res://scripts/flower_paint.gd"
## Trees painted from the hand, as flowers are (scripts/flower_paint.gd;
## docs/scenic/handful.md "Tree seed"). With a tree seed in hand (oak, pine,
## willow, or birch and the rest from the command palette), a press on the
## land paints that kind of tree: no veil and no wind. The user, 2026-10-02:
## "I'd like to be able to set trees down just like flowers. I don't want to
## have to use the pollen." The veil stays for a bent tree's own spores.
##
## - **A tap** sets one tree where it is pressed, if the ground there takes a
##   tree and there is room (`_plant`).
## - **A drag** paints a stand: the flower brush's coat (`PASS` a pass,
##   `PER_SECOND` held) over a jittered lattice SPACING m apart, each spot
##   coming up once the coat passes its own draw (`_judge`), so one pass
##   leaves an open stand, and going over it, or lingering, fills it toward
##   every spot (a close wood, STAND_FULL). The brush is TREE_RADIUS m at the
##   middle pip.
## - **Shift** thins: the same coat takes the trees and dead wood under it,
##   the hand's or the world's, each at its own share; one pass thins a wood,
##   going over it clears it. The cells turn hand work, as a plucked tree's,
##   so emergence does not sow them straight back.
##
## The kind is the seed's, always: an oak is painted as oaks. The land still
## decides where one can stand, as emergence's arrivals do (`suits`): not on
## water or within its shore, not on rock steeper than the habitat's rock
## slope, not near the snow or above the treeline, and not nearer than GAP to
## another tree or ROOM to a stone or a shrub. Each tree is an ordinary
## record of its kind, sized, tinted and given its stand's autumn as an
## emerged one is, marked hand work, and grows in with emergence's rise
## within SPROUT_TREE s of being painted.
##
## Preloaded, not a class_name.

const NativeEmergence = preload("res://scripts/emergence.gd")

## The brush's radius (m) at the middle pip; the stand's lattice; the least
## gap to another tree and to anything else; the coat at which every lattice
## spot stands; seconds a dab's trees are born over.
const TREE_RADIUS := 3.0
const SPACING := 2.3
const GAP := 1.7
const ROOM := 0.6
const STAND_FULL := 7.0
## How far a spot is jittered within its lattice cell, either way of the
## middle (share of SPACING): little enough that neighbours keep GAP.
const JITTER := 0.2
const SPROUT_TREE := 0.6
## What a thinning takes: the trees and the dead wood.
const TAKEN := NativeEmergence.TREES+NativeEmergence.DEAD_KINDS

## What FlowerPaint reads off its sowing: the land and a salt.
class Ground extends RefCounted:
	var data: NativeTerrainData
	var salt := 0
	func _survey(_bounds: Rect2) -> void: pass

var emergence: RefCounted
var kind := ""
## True where live water stands on `p` (a Callable of a Vector2), or invalid.
var wet := Callable()
## What a tree must keep its distance from, by 1 m cell: Vector3(x, z, 1 for
## a tree, 0 for anything else).
var _room := {}

## A stroke of `tree_kind` trees on `terrain`, whose emergence (`life`) gives
## the habitat, the rules and the looks, at `size` times the brush, thinning
## when `thinning`.
func _init(life: RefCounted, terrain: NativeTerrainData, tree_kind: String, size: float, thinning: bool, stroke_serial: int, wet_at := Callable()) -> void:
	var ground := Ground.new()
	ground.data = terrain
	ground.salt = Variety.mix([int(life.salt),811])
	emergence = life
	kind = tree_kind
	wet = wet_at
	super(ground,size,thinning,stroke_serial)
	radius = TREE_RADIUS*size
	if not thin: _survey_room()

## True for a kind a tree seed paints.
static func paints_kind(asset: String) -> bool:
	return asset in NativeEmergence.TREES

# --- The ground --------------------------------------------------------------------

func _survey_room() -> void:
	_room.clear()
	for item: Dictionary in data.objects:
		var asset := str(item.asset)
		# Flowers and grass give way to a tree painted over them.
		if is_flower(asset) or asset == "waterfall": continue
		_keep_room(Vector2(float(item.x),float(item.z)),asset in NativeEmergence.TREES)

func _keep_room(p: Vector2, tree: bool) -> void:
	_room.get_or_add(Vector2i(p.floor()),[]).append(Vector3(p.x,p.y,1.0 if tree else 0.0))

## Whether a tree at `p` stands clear of the trees (GAP) and of everything
## else (ROOM).
func _clear(p: Vector2) -> bool:
	var base := Vector2i(p.floor())
	var reach := ceili(GAP)
	for dz in range(-reach,reach+1):
		for dx in range(-reach,reach+1):
			for other: Vector3 in _room.get(base+Vector2i(dx,dz),[]):
				var gap := GAP if other.z > 0.5 else ROOM
				if p.distance_squared_to(Vector2(other.x,other.y)) < gap*gap: return false
	return true

## Whether the ground at `p` takes a tree: emergence's arrivals' rules.
func suits(p: Vector2) -> bool:
	var h: Variant = data.ground_height(p)
	if h == null: return false
	if wet.is_valid() and wet.call(p): return false
	if emergence._blend == null: return true
	if emergence._wet(p) or emergence._shore(p): return false
	var habitat: String = emergence._blend.pick(p)
	return emergence._slope(p) <= emergence._rock_slope(habitat) and float(h) <= minf(emergence._snowline()-1.8,emergence._treeline(habitat))

# --- Painting ----------------------------------------------------------------------

## The press: one tree where it is pressed (thinning: the flower brush's tap).
func press(p: Vector2) -> Dictionary:
	if thin: return super(p)
	_press = p
	_last = p
	_held = 0.0
	_decided = false
	_grow_bounds(p,ROOM)
	var made := []
	if suits(p) and _clear(p):
		var item: Variant = _plant(p,[sowing.salt,serial,83])
		if item != null: made.append(item)
	else: refused += 1
	return {"records":made,"removed":[]}

## Brings the trees in `area` up to its coat.
func _grow(area: Rect2) -> Array:
	var made := []
	var first := Vector2i((area.position/SPACING).floor())
	var last := Vector2i((area.end/SPACING).ceil())
	for gz in range(first.y,last.y):
		for gx in range(first.x,last.x):
			var cell := Vector2i(gx,gz)
			var spot: Variant = _spots.get(cell)
			if spot == null:
				var middle := (Vector2(cell)+Vector2.ONE*0.5)*SPACING
				if coat(middle)*1.2 < FlowerSowing.THIN: continue
				spot = _judge(cell)
				_spots[cell] = spot
			if (spot as Array).is_empty(): continue
			var p: Vector2 = spot[0]
			if smoothstep(FlowerSowing.THIN,STAND_FULL,coat(p)) <= float(spot[1]): continue
			_spots[cell] = []
			if not _clear(p): continue
			var item: Variant = _plant(p,[sowing.salt,83,gx,gz])
			if item != null: made.append(item)
	return made

## Lattice spot `cell`, judged once a stroke: [where, the presence it needs]
## or [] where the ground refuses a tree.
func _judge(cell: Vector2i) -> Array:
	var key := [sowing.salt,83,cell.x,cell.y]
	var p := (Vector2(cell)+Vector2.ONE*0.5+Vector2(Variety.unit(key+[1])-0.5,Variety.unit(key+[2])-0.5)*2.0*JITTER)*SPACING
	if not suits(p):
		refused += 1
		return []
	return [p,Variety.unit([sowing.salt,serial,cell.x,cell.y,3])]

## One tree of the kind at `p`, as an emerged one is made but the hand's.
## The record, or null when the land would not take it.
func _plant(p: Vector2, key: Array) -> Variant:
	var span: Vector2 = NativeEmergence.TREE_SIZE
	var size := lerpf(span.x,span.y,Variety.unit(key+[6]))*float(NativeEmergence.KIND_SIZE.get(kind,1.0))
	var live: bool = emergence._blend != null
	var tint: String = emergence._tree_tint(kind,p,key) if live else ""
	var id := data.place(kind,p,Variety.unit(key+[7])*TAU,size,{},tint)
	if id < 0: return null
	var item: Dictionary = data.objects.back()
	item["source"] = "hand"
	item["born"] = Emergence.time+SPROUT_TREE*Variety.unit(key+[8])
	if live: item["autumn"] = emergence._stand_autumn(p)
	_keep_room(p,true)
	placed.append(id)
	kinds[kind] = int(kinds.get(kind,0))+1
	return item

# --- Thinning ----------------------------------------------------------------------

## The trees and dead wood on the plate when a thinning starts (FlowerPaint
## `_thin` takes them by the coat).
func _survey_flowers() -> void:
	_flowers.clear()
	for item: Dictionary in data.objects:
		if not str(item.asset) in TAKEN: continue
		var p := Vector2(float(item.x),float(item.z))
		_flowers.get_or_add(Vector2i((p/0.5).floor()),[]).append([int(item.id),p])

# --- The end -----------------------------------------------------------------------

## No wash under trees. The summary FlowerPaint's `finish` gives.
func finish() -> Dictionary:
	return {"placed":placed.duplicate(),"kinds":kinds.duplicate(),"removed":removed.duplicate(),"bounds":bounds,"washed":0,"refused":refused,"dabs":dabs}
