extends RefCounted
## An island's outline on the plate's own triangulation: which of the plate's
## faces are land. The plate keeps its square grid of points and faces; a
## small island is a small part of it, a large one most of it
## (NativeTerrainData `outline`, saved and undone with the land).
##
## The shape is the forested isles' share field (scripts/sky_forest_isle.gd
## `main_share`), plate-sized: 0 at the middle and growing outward, from a
## seeded ellipse with lobes round it, bays bitten in, its points pushed about
## by a slow warp so no edge runs true. The land is every face whose middle's
## share is under the level that leaves the seed's share of the square
## (AREA); then it is cleaned up so it reads as one island:
##   features narrower than OPEN twice over are opened away (a morphological
##   opening on the faces' middles), so no spit or neck is a triangle wide;
##   the plate's middle (MIDDLE) is always land: the player and the landing
##   spot arrive there;
##   a band of sky along the plate's rim (RIM) is never land, a seeded
##   width that wanders along the rim, and the shore leans in before it
##   (RIM_SOFT), so no shore runs along the square;
##   only the piece holding the middle stays, and lakes of sky enclosed by
##   land are filled;
##   a face hanging on by one side goes, a notch open on one side is filled,
##   and two pieces of land touching at a single point are joined there.
## Deterministic for a seed: the same seed is the same island.

const Plate = preload("res://scripts/plate.gd")
## The share of the square that is land, from the smallest island to the
## largest.
const AREA := Vector2(0.32,0.5)
## Metres round the plate's middle that are always land.
const MIDDLE := 3.0
## The band along the plate's rim that is never land: its width (m) from
## narrowest to widest, wandering along the rim over a wavelength (m). The
## plate's rim stands HALF from its middle.
const RIM := Vector2(0.9,3.2)
const RIM_WAVE := 7.0
const HALF := Plate.HALF
## The lean away from the band: share added over the last RIM_SOFT metres
## before it, up to RIM_PUSH, measured to a square rounded by ROUND (a
## superellipse's power) so a large island is not squared off either.
const RIM_SOFT := 3.0
const RIM_PUSH := 6.0
const ROUND := 3.0
## The opening's reach (m): land narrower than twice this is cut away.
const OPEN := 1.0
## The ellipse: its long half against its short (a range), the middle's drift
## off the plate's middle (m).
const ASPECT := Vector2(1.0,1.5)
const DRIFT := 1.6
## Lobes round the rim: [count round, share out].
const LOBES := [[2,0.14],[3,0.13],[4,0.08],[5,0.05],[7,0.035]]
## Bays bitten in: how many, how deep (share), how wide (radians).
const BAYS := Vector2i(1,3)
const BAY_DEEP := Vector2(0.24,0.42)
const BAY_WIDE := Vector2(0.16,0.34)
## The warp (m, over a wavelength of m).
const WARP := 2.0
const WARP_WAVE := 10.0

## How large the island for `seed_value` is, 0 (smallest) to 1 (largest).
static func size_for(seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"island size"])
	return rng.randf()

## The share of the square that is land at `size` (0..1).
static func area_for(size: float) -> float:
	return lerpf(AREA.x,AREA.y,clampf(size,0.0,1.0))

## The outline for `seed_value` on the triangulation (`points`, and `ids`
## three a face, as NativeTerrainData holds them): a byte a face, 1 where
## the face is off the island. `size` 0..1 (AREA); left out, the seed's own
## (`size_for`).
static func mask(points: PackedVector2Array, ids: PackedInt32Array, seed_value: int, size := -1.0) -> PackedByteArray:
	if size < 0.0: size = size_for(seed_value)
	var field := _Field.new(seed_value)
	var faces := ids.size()/3
	var middles := PackedVector2Array()
	var areas := PackedFloat32Array()
	var shares := PackedFloat32Array()
	middles.resize(faces)
	areas.resize(faces)
	shares.resize(faces)
	var total := 0.0
	for f in range(faces):
		var a := points[ids[f*3]]
		var b := points[ids[f*3+1]]
		var c := points[ids[f*3+2]]
		middles[f] = (a+b+c)/3.0
		areas[f] = absf((b-a).cross(c-a))*0.5
		shares[f] = field.share(middles[f])
		total += areas[f]
	var rim := _Rim.new(seed_value)
	var near_rim := rim.faces(points,ids)
	for f in range(faces): shares[f] = INF if near_rim[f] == 1 else shares[f]+rim.push(middles[f])
	# The level: faces taken lowest share first until the island's area.
	var order := range(faces)
	order.sort_custom(func(x: int, y: int) -> bool: return shares[x] < shares[y] or (shares[x] == shares[y] and x < y))
	var land := PackedByteArray()
	land.resize(faces)
	var goal := area_for(size)*total
	var taken := 0.0
	for f: int in order:
		if taken >= goal or near_rim[f] == 1: break
		land[f] = 1
		taken += areas[f]
	var topology := _Topology.new(points,ids,middles)
	for f in range(faces):
		if middles[f].length() <= MIDDLE: land[f] = 1
	land = topology.open(land,OPEN)
	for f in range(faces):
		if middles[f].length() <= MIDDLE: land[f] = 1
	land = topology.tidy(land,near_rim)
	var result := PackedByteArray()
	result.resize(faces)
	for f in range(faces): result[f] = 0 if land[f] == 1 else 1
	return result

## Metres inside the outline at each point: the distance to the nearest shore
## edge for a point on the island, 0 on the shore (an edge with land on one
## side only, which takes in the plate's own rim where the land reaches it),
## -1 for a point with no land round it. `outline` as `mask` returns it.
static func shore_distance(points: PackedVector2Array, ids: PackedInt32Array, outline: PackedByteArray) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(points.size())
	result.fill(-1.0)
	var edges := {}
	for f in range(ids.size()/3):
		if outline[f] != 0: continue
		for j in range(3):
			var a := ids[f*3+j]
			var b := ids[f*3+(j+1)%3]
			var key := Vector2i(mini(a,b),maxi(a,b))
			edges[key] = int(edges.get(key,0))+1
			result[a] = INF
	# The shore's edges, bucketed by every cell their bounds cover.
	const CELL := 2.0
	var buckets := {}
	var shore := PackedInt32Array()
	for key: Vector2i in edges:
		if edges[key] != 1: continue
		result[key.x] = 0.0
		result[key.y] = 0.0
		var e := shore.size()
		shore.append_array([key.x,key.y])
		var low := points[key.x].min(points[key.y])
		var high := points[key.x].max(points[key.y])
		for z in range(floori(low.y/CELL),floori(high.y/CELL)+1):
			for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
				var cell := Vector2i(x,z)
				if not buckets.has(cell): buckets[cell] = PackedInt32Array()
				buckets[cell].append(e)
	if shore.is_empty(): return result
	var span := 0
	for cell: Vector2i in buckets: span = maxi(span,maxi(absi(cell.x),absi(cell.y)))
	for i in range(points.size()):
		if result[i] != INF: continue
		var p := points[i]
		var home := Vector2i(floori(p.x/CELL),floori(p.y/CELL))
		var best := INF
		# Rings of cells outward until the nearest edge found lies within the
		# rings searched.
		for ring in range(0,span*2+3):
			if best <= (ring-1)*CELL: break
			for z in range(home.y-ring,home.y+ring+1):
				for x in range(home.x-ring,home.x+ring+1):
					if maxi(absi(x-home.x),absi(z-home.y)) != ring: continue
					var bucket: Variant = buckets.get(Vector2i(x,z))
					if bucket == null: continue
					for e: int in bucket:
						var a := points[shore[e]]
						var b := points[shore[e+1]]
						best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
		result[i] = best
	return result

## The shore's edges: three ids an edge, its two ends in the order the land
## face it bounds runs, and that face's third corner (the land side).
static func shore_edges(ids: PackedInt32Array, outline: PackedByteArray) -> PackedInt32Array:
	var count := {}
	for f in range(ids.size()/3):
		if outline[f] != 0: continue
		for j in range(3):
			var key := Vector2i(mini(ids[f*3+j],ids[f*3+(j+1)%3]),maxi(ids[f*3+j],ids[f*3+(j+1)%3]))
			count[key] = int(count.get(key,0))+1
	var result := PackedInt32Array()
	for f in range(ids.size()/3):
		if outline[f] != 0: continue
		for j in range(3):
			var a := ids[f*3+j]
			var b := ids[f*3+(j+1)%3]
			if count[Vector2i(mini(a,b),maxi(a,b))] == 1: result.append_array([a,b,ids[f*3+(j+2)%3]])
	return result

## The share field: 0 at the island's middle, rising outward; the rim is
## wherever the area's level falls.
class _Field:
	var aspect := 1.0
	var heading := 0.0
	var drift := Vector2.ZERO
	var lobes := PackedVector3Array()
	var bays := PackedVector3Array()
	var warp := FastNoiseLite.new()

	func _init(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value,"island outline"])
		aspect = rng.randf_range(ASPECT.x,ASPECT.y)
		heading = rng.randf()*TAU
		drift = Vector2.from_angle(rng.randf()*TAU)*rng.randf()*DRIFT
		for l: Array in LOBES: lobes.append(Vector3(float(l[0]),float(l[1])*rng.randf_range(0.6,1.3),rng.randf()*TAU))
		for i in range(rng.randi_range(BAYS.x,BAYS.y)):
			bays.append(Vector3(rng.randf()*TAU,rng.randf_range(BAY_DEEP.x,BAY_DEEP.y),rng.randf_range(BAY_WIDE.x,BAY_WIDE.y)))
		warp.seed = rng.randi()
		warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp.frequency = 1.0/WARP_WAVE
		warp.fractal_type = FastNoiseLite.FRACTAL_FBM
		warp.fractal_octaves = 2

	func share(p: Vector2) -> float:
		var w := p-drift+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.x+911.0,p.y-337.0))*WARP
		var q := w.rotated(-heading)
		q.x /= aspect
		var t := q.angle()
		var out := 1.0
		for l in lobes: out += l.y*sin(l.x*t+l.z)
		for b in bays: out -= b.y*exp(-pow(angle_difference(t,b.x)/b.z,2.0))
		return q.length()/maxf(out,0.2)

## The band along the plate's rim that is never land (RIM), and the push
## that leans the shore away from it before it gets there (RIM_SOFT), so a
## large island's lobes are drawn in short of the band rather than cut off
## along it.
class _Rim:
	var wander := FastNoiseLite.new()

	func _init(seed_value: int) -> void:
		wander.seed = hash([seed_value,"island rim"])
		wander.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		wander.frequency = 1.0/RIM_WAVE

	## The band's width (m) where it passes `p`.
	func width(p: Vector2) -> float:
		return lerpf(RIM.x,RIM.y,clampf(wander.get_noise_2d(p.x,p.y)*0.75+0.5,0.0,1.0))

	## Metres from `p` to the plate's rim.
	static func reach(p: Vector2) -> float:
		return HALF-maxf(absf(p.x),absf(p.y))

	## Share added at `p`: none until RIM_SOFT outside the band, rising to
	## RIM_PUSH at its edge, the rim taken round the plate's corners (ROUND).
	func push(p: Vector2) -> float:
		var rounded := HALF-pow(pow(absf(p.x),ROUND)+pow(absf(p.y),ROUND),1.0/ROUND)
		var u := clampf((width(p)+RIM_SOFT-rounded)/RIM_SOFT,0.0,1.0)
		return RIM_PUSH*u*u

	## The faces with a corner in the band: a byte a face, 1 there.
	func faces(points: PackedVector2Array, ids: PackedInt32Array) -> PackedByteArray:
		var inside := PackedByteArray()
		inside.resize(points.size())
		for i in range(points.size()): inside[i] = 1 if reach(points[i]) < width(points[i]) else 0
		var result := PackedByteArray()
		result.resize(ids.size()/3)
		for f in range(result.size()):
			result[f] = 1 if inside[ids[f*3]] == 1 or inside[ids[f*3+1]] == 1 or inside[ids[f*3+2]] == 1 else 0
		return result

## The faces' neighbours, across an edge and within a reach, for the cleanup.
class _Topology:
	var points: PackedVector2Array
	var ids: PackedInt32Array
	var middles: PackedVector2Array
	## Per face, the faces across its three edges (-1 off the plate).
	var across := PackedInt32Array()
	## Per point, the faces round it.
	var star: Array[PackedInt32Array] = []
	var _buckets := {}

	func _init(at: PackedVector2Array, faces: PackedInt32Array, centres: PackedVector2Array) -> void:
		points = at
		ids = faces
		middles = centres
		var count := faces.size()/3
		across.resize(count*3)
		across.fill(-1)
		star.resize(at.size())
		var edges := {}
		for f in range(count):
			for j in range(3):
				var a := faces[f*3+j]
				var b := faces[f*3+(j+1)%3]
				star[a].append(f)
				var key := Vector2i(mini(a,b),maxi(a,b))
				if edges.has(key):
					var other: int = edges[key]
					across[f*3+j] = other/3
					across[other] = f
				else: edges[key] = f*3+j
			var cell := Vector2i(floori(centres[f].x),floori(centres[f].y))
			if not _buckets.has(cell): _buckets[cell] = PackedInt32Array()
			_buckets[cell].append(f)

	## The faces whose middles lie within `reach` of face `f`'s.
	func near(f: int, reach: float) -> PackedInt32Array:
		var p := middles[f]
		var result := PackedInt32Array()
		for z in range(floori(p.y-reach),floori(p.y+reach)+1):
			for x in range(floori(p.x-reach),floori(p.x+reach)+1):
				for g: int in _buckets.get(Vector2i(x,z),PackedInt32Array()):
					if middles[g].distance_to(p) <= reach: result.append(g)
		return result

	## A morphological opening: land stays only within `reach` of a face
	## whose whole reach is land.
	func open(land: PackedByteArray, reach: float) -> PackedByteArray:
		var count := land.size()
		var core := PackedByteArray()
		core.resize(count)
		var rounds: Array[PackedInt32Array] = []
		rounds.resize(count)
		for f in range(count):
			if land[f] == 0: continue
			rounds[f] = near(f,reach)
			var whole := true
			for g in rounds[f]:
				if land[g] == 0:
					whole = false
					break
			core[f] = 1 if whole else 0
		var result := PackedByteArray()
		result.resize(count)
		for f in range(count):
			if core[f] == 0: continue
			for g in rounds[f]: result[g] = 1
		return result

	## One piece holding the middle, no enclosed sky, no face on one side, no
	## one-sided notch and no two pieces meeting at a point, and never land on
	## a face `kept_off` holds. Repeats until nothing changes.
	func tidy(land: PackedByteArray, kept_off: PackedByteArray) -> PackedByteArray:
		var count := land.size()
		var middle := 0
		for f in range(count):
			if middles[f].length() < middles[middle].length(): middle = f
		for _pass in range(32):
			var changed := false
			land[middle] = 1
			# The piece holding the middle.
			var kept := _flood(land,middle,1)
			for f in range(count):
				if land[f] == 1 and kept[f] == 0:
					land[f] = 0
					changed = true
			# Sky enclosed by land: every piece of sky not reaching the plate's rim.
			var open_sky := PackedByteArray()
			open_sky.resize(count)
			for f in range(count):
				if land[f] == 1 or open_sky[f] == 1: continue
				var rim := false
				for j in range(3): rim = rim or across[f*3+j] < 0
				if not rim: continue
				var reached := _flood(land,f,0)
				for g in range(count):
					if reached[g] == 1: open_sky[g] = 1
			for f in range(count):
				if land[f] == 0 and open_sky[f] == 0 and kept_off[f] == 0:
					land[f] = 1
					changed = true
			# Faces holding on by one side go; notches open on one side fill.
			for f in range(count):
				var sides := 0
				for j in range(3):
					var g := across[f*3+j]
					if g >= 0 and land[g] == 1: sides += 1
				if land[f] == 1 and sides <= 1 and f != middle:
					land[f] = 0
					changed = true
				elif land[f] == 0 and sides == 3 and kept_off[f] == 0:
					land[f] = 1
					changed = true
			# Two pieces of land meeting at one point: fill round it, or where
			# the rim's band is in the way, clear round it.
			for i in range(points.size()):
				if _fans(land,i) > 1:
					var blocked := false
					for f in star[i]: blocked = blocked or (land[f] == 0 and kept_off[f] == 1)
					for f in star[i]:
						if blocked and f != middle and land[f] == 1:
							land[f] = 0
							changed = true
						elif not blocked and land[f] == 0:
							land[f] = 1
							changed = true
			if not changed: break
		return land

	## Faces joined to `start` across edges, all of `value`.
	func _flood(land: PackedByteArray, start: int, value: int) -> PackedByteArray:
		var seen := PackedByteArray()
		seen.resize(land.size())
		var stack := PackedInt32Array([start])
		seen[start] = 1
		while not stack.is_empty():
			var f: int = stack[stack.size()-1]
			stack.resize(stack.size()-1)
			for j in range(3):
				var g := across[f*3+j]
				if g < 0 or seen[g] == 1 or land[g] != value: continue
				seen[g] = 1
				stack.append(g)
		return seen

	## How many separate runs of land faces stand round point `i` (joined
	## across the edges that meet at it).
	func _fans(land: PackedByteArray, i: int) -> int:
		var round := star[i]
		var seen := {}
		var runs := 0
		for f in round:
			if land[f] == 0 or seen.has(f): continue
			runs += 1
			var stack := [f]
			seen[f] = true
			while not stack.is_empty():
				var g: int = stack.pop_back()
				for j in range(3):
					var h := across[g*3+j]
					if h < 0 or seen.has(h) or land[h] == 0 or not h in round: continue
					# Only across an edge that has `i` at one end.
					if ids[g*3+j] != i and ids[g*3+(j+1)%3] != i: continue
					seen[h] = true
					stack.append(h)
		return runs
