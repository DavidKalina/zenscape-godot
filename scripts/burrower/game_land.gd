extends "res://scripts/burrower/burrower_ground.gd"
## Endless flight's land as the burrower sees it (burrower_ground.gd): the
## land field's height and colour, the sea's and rivers' water
## (studies/endless_flight.gd `water_at`). No lists and no rim: it feels
## ahead with `open` (steep ground, and the game's rocks, sea stacks, arches,
## ruins, halls and tunnels; not trees, it runs through a forest), and `room` is
## 0 where it can't run (so a start, a resurfacing or a push-up there is
## passed over) and ROOM elsewhere. Trees are asked of the game's own stand
## near the head (`trees_near`, `canopy_top`, `stand_ahead`): it has no nodes
## for them, so `trees` stays empty.

const Field = preload("res://scripts/endless/land_field.gd")
const TreePlan = preload("res://scripts/endless/tree_plan.gd")
const WakeSheet = preload("res://scripts/burrower/wake_sheet.gd")

## The game (studies/endless_flight.gd): its `field` and `water_at`.
var game: Node3D
## The wake, laid on the game's water.
var sheet: WakeSheet

## Ground it runs up: the normal's up at least RUN_UP (~28 deg); water
## counts at any bed. Things are felt for PROBE_UP m over the ground or water.
const RUN_UP := 0.88
## Steeper than WALL_UP's up (~40 deg) is a wall: it sounds there.
const WALL_UP := 0.76
const PROBE_UP := 1.5
const ROOM := 1000.0
## A stand worth running for: a plan cell with at least STAND_N trees, within
## acos(STAND_COS) of the way it looks.
const STAND_N := 12
const STAND_COS := 0.6
## His goals when roaming (`roam_goal`): how far on, the ways tried (rad off his
## own, straight first, so a tie goes on), the strip counted either side (m).
const ROAM_ON := 110.0
const ROAM_FAN := [0.0,0.4,-0.4,0.8,-0.8,1.2,-1.2]
const ROAM_STRIP := 30.0
## As burrower.gd's WET_DEEP.
const WET_DEEP := 0.15

func _init() -> void:
	name = "BurrowerGround"
	probes = true

func setup(the_game: Node3D) -> void:
	game = the_game
	sheet = WakeSheet.new()
	add_child(sheet)
	sheet.setup(self)
	pond_material = sheet.wake_material()

func wake_point(at: Vector2, now: float, k: float) -> void:
	sheet.point(at,now,k)

func wake_tick(now: float, at: Vector2, way: Vector2, wet: float) -> void:
	sheet.tick(now,at,way,wet)

func wake_busy() -> bool:
	return sheet.busy()

## On the sea's water, not a river's or a lake's.
func on_sea(at: Vector2) -> bool:
	return is_nan(game.field.river_y(at.x,at.y))

## The track to the sea's own wake (the sea drawn by EndlessSea only).
func sea_track(points: Array[Vector4], head: Vector2) -> void:
	var look: Variant = game.look
	if look == null or look.water == null or not look.water.has_method("other_track"): return
	look.water.other_track(points,head)

func height(x: float, z: float) -> float:
	return game.field.height(x,z)

func colour(x: float, z: float, y: float, nm: Vector3) -> Color:
	# The ground's own meadow share, so dry ground reads dry (not a green rug).
	var meadow: float = clampf(float(game.field.sample(x,z).y),0.0,1.0)
	return game.field.colour(x,z,y,nm.y,meadow)

## The sea's swell or a river's or lake's level (Field.SEA_Y and under on
## dry land, which is far over it). Land well over the sea skips the swell:
## `water_at` marches the sea's waves, and a run asks several times a frame.
func water_y(x: float, z: float) -> float:
	if float(game.field.height(x,z)) > Field.SEA_Y+SWELL_ROOM:
		var river: float = game.field.river_y(x,z)
		return Field.SEA_Y if is_nan(river) else maxf(Field.SEA_Y,river)
	return game.water_at(Vector3(x,Field.SEA_Y,z))

## Not steep (or water) and clear of what stands on the land.
func open(at: Vector2) -> bool:
	var key := Vector3i(floori(at.x/MEMO_CELL),floori(at.y/MEMO_CELL),0)
	if _memo.has(key): return _memo[key]
	var got := _open(at)
	_keep(key,got)
	return got

## The creature asks these several times a frame and each costs a few height
## reads and four `inside`s; 2 m is finer than it steers. Kept a short while (the
## land stands and goes).
const MEMO_CELL := 2.0
## Land this far over the sea has no swell to ask about (`water_y`).
const SWELL_ROOM := 8.0
const MEMO_MOST := 400
var _memo := {}

func _keep(key: Vector3i, got: bool) -> void:
	if _memo.size() >= MEMO_MOST: _memo.clear()
	_memo[key] = got

func _open(at: Vector2) -> bool:
	var h := height(at.x,at.y)
	var w := water_y(at.x,at.y)
	if h >= w and normal(at.x,at.y).y < RUN_UP: return false
	return not blocked(at,maxf(h,w))

## Too steep to run on through, or something standing (not over water).
func wall(at: Vector2) -> bool:
	var key := Vector3i(floori(at.x/MEMO_CELL),floori(at.y/MEMO_CELL),1)
	if _memo.has(key): return _memo[key]
	var got := _wall(at)
	_keep(key,got)
	return got

func _wall(at: Vector2) -> bool:
	var h := height(at.x,at.y)
	var w := water_y(at.x,at.y)
	if h >= w and normal(at.x,at.y).y < WALL_UP: return true
	return blocked(at,maxf(h,w))

## Something standing there, at any slope (a wall, less the steep ground).
func stands(at: Vector2) -> bool:
	return blocked(at,maxf(height(at.x,at.y),water_y(at.x,at.y)))

## Something standing at (x, z) a little over `y` (the ground or water
## there): a rock or sea stack, an arch's leg, a hall, a tunnel's mouth (as
## the game's `_blocked`, less trees: a run goes through a forest).
func blocked(at: Vector2, y: float) -> bool:
	var p := Vector3(at.x,y+PROBE_UP,at.y)
	return game.arches.inside(p) or game.rocks.inside(p) or game.halls.inside(p) or game.tunnels.inside(p)

## Under a tree's crown at (x, z).
func wooded(at: Vector2, y: float) -> bool:
	return game.trees.inside(Vector3(at.x,y+PROBE_UP,at.y))

## How many standing trees lie in the strip `half` m to each side of the
## line from `at` along `fwd` (unit) for `length` m (the wake gate's forest
## test, when it counts them: the trees the game has stood, near the plane).
func trees_along(at: Vector2, fwd: Vector2, length: float, half: float) -> int:
	var end := at+fwd*length
	var lo := TreePlan.cell_of(minf(at.x,end.x)-half,minf(at.y,end.y)-half)
	var hi := TreePlan.cell_of(maxf(at.x,end.x)+half,maxf(at.y,end.y)+half)
	var n := 0
	for cz in range(lo.y,hi.y+1):
		for cx in range(lo.x,hi.x+1):
			var t: PackedFloat32Array = game.trees.cell_trees(Vector2i(cx,cz))
			for q in range(0,t.size(),8):
				if t[q+5] <= 0.0: continue
				var rel := Vector2(t[q]-at.x,t[q+1]-at.y)
				var along := rel.dot(fwd)
				if along < 0.0 or along > length: continue
				if absf(rel.dot(fwd.orthogonal())) <= half+t[q+6]: n += 1
	return n

## The stood cells' arrays over the square `r` m round `at`.
func _cells_round(at: Vector2, r: float) -> Array:
	var lo := TreePlan.cell_of(at.x-r,at.y-r)
	var hi := TreePlan.cell_of(at.x+r,at.y+r)
	var out := []
	for cz in range(lo.y,hi.y+1):
		for cx in range(lo.x,hi.x+1):
			var t: PackedFloat32Array = game.trees.cell_trees(Vector2i(cx,cz))
			if not t.is_empty(): out.append(t)
	return out

func trees_near(at: Vector2, r: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var r2 := r*r
	for t: PackedFloat32Array in _cells_round(at,r):
		for q in range(0,t.size(),8):
			if t[q+3] <= 0.0: continue
			var ox := t[q]-at.x
			var oz := t[q+1]-at.y
			if ox*ox+oz*oz > r2: continue
			out.append(t[q])
			out.append(t[q+1])
			out.append(t[q+2])
			out.append(t[q+3])
	return out

func canopy_top(at: Vector2, r: float) -> float:
	var top := -INF
	var r2 := r*r
	for t: PackedFloat32Array in _cells_round(at,r):
		for q in range(0,t.size(),8):
			if t[q+3] <= 0.0: continue
			var ox := t[q]-at.x
			var oz := t[q+1]-at.y
			if ox*ox+oz*oz <= r2: top = maxf(top,t[q+2]+t[q+3])
	return top

func stand_ahead(at: Vector2, fwd: Vector2, most: float) -> Vector2:
	var best := Vector2(NAN,NAN)
	var score := 0.0
	var lo := TreePlan.cell_of(at.x-most,at.y-most)
	var hi := TreePlan.cell_of(at.x+most,at.y+most)
	for cz in range(lo.y,hi.y+1):
		for cx in range(lo.x,hi.x+1):
			var t: PackedFloat32Array = game.trees.cell_trees(Vector2i(cx,cz))
			var n := t.size()/8
			if n < STAND_N: continue
			var mid := (Vector2(cx,cz)+Vector2(0.5,0.5))*TreePlan.CELL
			var to := mid-at
			var d := to.length()
			if d > most or to.dot(fwd) < d*STAND_COS: continue
			var s := float(n)*(1.0-0.5*d/most)
			if s > score and open(mid):
				score = s
				best = mid
	return best

func room(at: Vector2) -> float:
	return ROOM if open(at) else 0.0

## Water over the bed here.
func wet(at: Vector2) -> bool:
	return height(at.x,at.y) < water_y(at.x,at.y)-WET_DEEP

## Water all the way `length` m from `at` along `way` (unit).
func wet_along(at: Vector2, way: Vector2, length: float) -> bool:
	for i in range(1,5):
		if not wet(at+way*length*i/4.0): return false
	return true

## The middles of the stood plan cells with STAND_N trees or more within `r` m of
## `at`, thickest first (only cells that have loaded: there's no planning here).
func stands_round(at: Vector2, r: float) -> Array:
	var lo := TreePlan.cell_of(at.x-r,at.y-r)
	var hi := TreePlan.cell_of(at.x+r,at.y+r)
	var found: Array = []
	for cz in range(lo.y,hi.y+1):
		for cx in range(lo.x,hi.x+1):
			var n: int = game.trees.cell_trees(Vector2i(cx,cz)).size()/8
			if n >= STAND_N: found.append([n,(Vector2(cx,cz)+Vector2(0.5,0.5))*TreePlan.CELL])
	found.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	return found.map(func(f: Array) -> Vector2: return f[1])

## Where he roams next from `at` going `fwd`, ROAM_ON m on: on water, on along the
## water; else the way with the most trees; nothing better, straight on.
func roam_goal(at: Vector2, fwd: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var on_water := wet(at)
	var best := at+fwd*ROAM_ON
	var most := 0
	for a: float in ROAM_FAN:
		var way := fwd.rotated(a+rng.randf_range(-0.12,0.12))
		var end := at+way*ROAM_ON
		if not open(end): continue
		var n := (2 if wet(end) and wet(at+way*ROAM_ON*0.5) else 0) if on_water else trees_along(at,way,ROAM_ON,ROAM_STRIP)
		if n > most:
			most = n
			best = end
	return best
