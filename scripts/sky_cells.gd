extends RefCounted
## Where islands turn up when the glide wanders off from the copies
## (scripts/sky_islands.gd), so a place always comes into view.
##
## The sky is laid out in square cells. A hash of each cell says whether it
## holds an island and where, jittered in the cell, at a height in the band.
## Spots too near the fixed slots (the plate's first home and the copies'
## OFFSETS), or too near a neighbour that outranks them, are left empty, so
## no two islands ever stand closer than SPACING; and so are spots on a
## mountain range risen through the sea (scripts/sky_peaks.gd `blocks`) or in
## a towering cumulus (scripts/sky_towers.gd `blocks`). Spawning realises the
## best spot, so the same place gives the same island when flown back to.
##
## The cells live in home coordinates: where things stood when the copies
## were built. The swaps shift the world (SkyIslands `arrive`), and `origin`
## keeps the sum of those shifts, so a global point is its home plus origin.
##
## Two things realise a spot (`advance`):
##   wandering: further than WANDER_FAR from every island for WANDER_TIME,
##     a spot ahead along the heading, about IDEAL out;
##   falling: down in the parted cloud sea with nothing in reach, the spot
##     nearest to a point just ahead.

const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const CELL := 450.0
## The share of cells holding an island, and how far from a cell's middle
## its spot may sit, as a share of the cell.
const HOLDS := 0.9
const JITTER := 0.15
const SPACING := 350.0
const BAND := Vector2(-50.0,25.0)
const SEED := 7
## Wandering: this far (plate plane) from every island for this long.
const WANDER_FAR := 500.0
const WANDER_TIME := 20.0
## A wandering spot lies within CONE radians of the heading, NEAR to FAR
## metres out, best at IDEAL.
const CONE := 0.9
const NEAR := 280.0
const FAR := 600.0
const IDEAL := 350.0
## The glide's sink per metre flown, and the height a spot may stand over
## that line before it counts as out of reach (its thermal makes up the rest).
const SINK_RATIO := 0.125
const CLIMB := 40.0
## Falling: with the sea parted this far and the eye under LOW, a spot
## within RANGE of a point AHEAD metres on, unless an island is in REACH.
const PARTED := 0.7
const LOW := -55.0
const AHEAD := 100.0
const RANGE := 320.0
const REACH := 300.0

## The fixed slots' home positions, the plate's first home first.
var reserved: Array[Vector3] = []
## The swaps' shifts added up: global = home + origin.
var origin := Vector3.ZERO
## Seconds spent far from every island.
var wandered := 0.0

func _init(fixed: Array = []) -> void:
	for s: Vector3 in fixed: reserved.append(s)

## A hash of a cell, 0 to 1, one per salt.
static func noise(cell: Vector2i, salt: int) -> float:
	var h := cell.x*73856093^cell.y*19349663^salt*83492791^SEED*2654435761
	h = (h^(h >> 13))*1274126177
	h = (h^(h >> 16))*668265263
	h ^= h >> 15
	return float(h & 0xFFFFFF)/float(0x1000000)

## The cell's spot before spacing (home), or null if it holds none.
static func raw(cell: Vector2i) -> Variant:
	if noise(cell,0) >= HOLDS: return null
	var middle := (Vector2(cell)+Vector2.ONE*0.5)*CELL
	var off := Vector2(noise(cell,1)-0.5,noise(cell,2)-0.5)*2.0*JITTER*CELL
	return Vector3(middle.x+off.x,lerpf(BAND.x,BAND.y,noise(cell,3)),middle.y+off.y)

## The cell's island (home), or null: its raw spot, if no fixed slot and no
## outranking neighbour stands within SPACING. Neighbours further than one
## cell off can't come that close.
func spot(cell: Vector2i) -> Variant:
	var here: Variant = raw(cell)
	if here == null: return null
	if (SkyPeaks.blocks(here) or SkyTowers.blocks(here)): return null
	for s in reserved:
		if _flat(s,here) < SPACING: return null
	var rank := noise(cell,4)
	for dx in range(-1,2):
		for dz in range(-1,2):
			if dx == 0 and dz == 0: continue
			var other := cell+Vector2i(dx,dz)
			var there: Variant = raw(other)
			if there != null and noise(other,4) > rank and _flat(there,here) < SPACING: return null
	return here

func cell_of(home: Vector3) -> Vector2i:
	return Vector2i(floori(home.x/CELL),floori(home.z/CELL))

## Every island spot (home) within `radius` of a home point, fixed slots
## included.
func spots_near(home: Vector3, radius: float) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for s in reserved:
		if _flat(s,home) <= radius: found.append(s)
	var lo := cell_of(home-Vector3(radius,0.0,radius))
	var hi := cell_of(home+Vector3(radius,0.0,radius))
	for x in range(lo.x,hi.x+1):
		for z in range(lo.y,hi.y+1):
			var s: Variant = spot(Vector2i(x,z))
			if s != null and _flat(s,home) <= radius: found.append(s)
	return found

## Each frame of the glide: the eye (global), its heading (the scene's yaw),
## the islands standing now (global, the plate included) and how far the
## cloud sea has parted. Returns {home, kind} for a spot to realise, kind
## "wander" or "fall", or null.
func advance(delta: float, eye: Vector3, heading: float, live: Array, parted: float) -> Variant:
	var nearest := INF
	for s: Vector3 in live: nearest = minf(nearest,_flat(s,eye))
	wandered = wandered+delta if nearest > WANDER_FAR else 0.0
	var taken: Array[Vector3] = []
	for s: Vector3 in live: taken.append(s-origin)
	var home := eye-origin
	var way := Vector2(-sin(heading),-cos(heading))
	if parted >= PARTED and eye.y < LOW and nearest > REACH:
		var found: Variant = fall_pick(home,way,taken)
		if found != null:
			wandered = 0.0
			return {"home":found,"kind":"fall"}
	if wandered >= WANDER_TIME:
		var found: Variant = wander_pick(home,way,taken)
		if found != null:
			wandered = 0.0
			return {"home":found,"kind":"wander"}
	return null

## The spot ahead of a wandering eye (home), out of those not `taken`.
func wander_pick(home: Vector3, way: Vector2, taken: Array) -> Variant:
	var best: Variant = null
	var best_score := INF
	for s in spots_near(home,FAR):
		if _taken(s,taken): continue
		var to := Vector2(s.x-home.x,s.z-home.z)
		var d := to.length()
		if d < NEAR: continue
		var off := absf(way.angle_to(to))
		if off > CONE: continue
		var over := maxf(0.0,s.y-(home.y-d*SINK_RATIO+CLIMB))
		var score := absf(d-IDEAL)+off*150.0+over*4.0
		if score < best_score:
			best = s
			best_score = score
	return best

## The spot nearest a point just ahead of a falling eye (home).
func fall_pick(home: Vector3, way: Vector2, taken: Array) -> Variant:
	var target := home+Vector3(way.x,0.0,way.y)*AHEAD
	var best: Variant = null
	var best_d := RANGE
	for s in spots_near(target,RANGE):
		if _taken(s,taken): continue
		var d := _flat(s,target)
		if d <= best_d:
			best = s
			best_d = d
	return best

## The copies to free to bring `copies` (global) down to `cap`: the
## farthest from the eye first, never one in `keep`.
static func trim(eye: Vector3, copies: Array, cap: int, keep: Array) -> Array[int]:
	var order := []
	for i in range(copies.size()):
		if i not in keep: order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _flat(copies[a],eye) > _flat(copies[b],eye))
	var freed: Array[int] = []
	var over := copies.size()-cap
	for i in order:
		if freed.size() >= over: break
		freed.append(i)
	return freed

static func _taken(s: Vector3, taken: Array) -> bool:
	for t: Vector3 in taken:
		if _flat(s,t) < 1.0: return true
	return false

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
