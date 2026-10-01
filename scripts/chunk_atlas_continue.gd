extends RefCounted
## Continue: a new atlas chunk completes the land its stored neighbours leave
## at the seam (docs/chunk-atlas/CONTINUE.md). A range that is still climbing
## at the border rounds over a crest just inside the new chunk and comes down
## its far flank; a ridge that crosses the border runs on along its heading; a
## slope that already falls to the border eases on down to the low ground.
##
## It is a sheared mirror of the neighbour across the seam, read off a regular
## raster of the neighbour's stored heights:
## - a ridge crossing at heading k (along-seam metres per metre across) is
##   sampled at t - 2k·u, which carries it straight on instead of folding it
##   back into a chevron;
## - a range running along the seam is mirrored about a crest placed c metres
##   past the border (c grows with how steeply the border still climbs), with
##   a parabolic cap from the border to 2c;
## - a range that falls to the border decays to the neighbour's low ground at
##   the border's slope.
## The two readings blend by how much of the band's slope runs across the seam
## (its structure tensor). Each continued relief then fades over a reach set by
## the world's mountain country and the range's height, and is varied by world
## noise past the seam so it is a continuation, not a copy. The atlas pin keeps
## the seam itself exact afterwards.

const Atlas = preload("res://scripts/chunk_atlas.gd")

## The neighbour is read off a regular raster this fine (57 x 57 over 28 m).
const GRID_STEP := 0.5
const GRID_N := 57
## Along each seam the reading is taken every ALONG_STEP metres.
const ALONG_STEP := 1.0
const ALONG_N := 29
## How deep into the neighbour its slope and heading are read.
const READ_DEPTH := 8.0
## The low ground is this quantile of the neighbour's heights within LOW_DEPTH.
const LOW_QUANTILE := 0.2
const LOW_DEPTH := 12.0
## A side whose band stands less than this above or below its low ground has
## nothing to continue.
const RELIEF_MIN := 0.6
## Ridge shear, clamped; past twice this the ridge runs along the seam and the
## shear is let go.
const SHEAR_MAX := 1.2
## A border still climbing at slope m puts the crest c = CAP_PER_SLOPE·m past
## it, up to CAP_MAX.
const CAP_PER_SLOPE := 1.5
const CAP_MAX := 3.0
## Reach of a continued range, metres: low country to high country.
const REACH := Vector2(14.0,34.0)
## Past the seam, the copy is warped along the seam by up to WARP metres and
## its relief scaled by 1 ± VARY, both easing in over VARY_IN metres.
const WARP := 1.4
const VARY := 0.28
const VARY_IN := 6.0
## A crossing ridge may climb this far above where it meets the border
## (scaled down where the border is lower than 2 m above the low ground).
const CROSS_CLIMB := 0.8
## Hollows mirrored over are kept shallow.
const HOLLOW_MAX := 2.0
## Seam frames: `n` points from this chunk into the neighbour, `t` runs along
## the seam. A neighbour point at depth d' and along t is n·(d'-HALF)+t·tan in
## the neighbour's own frame.
const FRAMES := {"e":[Vector2(1,0),Vector2(0,1)],"w":[Vector2(-1,0),Vector2(0,1)],"n":[Vector2(0,-1),Vector2(1,0)],"s":[Vector2(0,1),Vector2(1,0)]}

static func enabled() -> bool:
	return not "--no-continue" in OS.get_cmdline_user_args() and not "--no-continue" in OS.get_cmdline_args()

## Raise the land of `slot` (formed as `plain`, its heights before carry-in)
## so it continues every stored orthogonal neighbour. Writes `data.heights`;
## the caller pins the seam afterwards. Returns what it continued, per side:
## {"e": {"relief": m, "reach": m, "across": 0..1}}.
static func apply(atlas, slot: Vector2i, data: NativeTerrainData, plain: PackedFloat32Array) -> Dictionary:
	var readings := {}
	for side in Atlas.SIDES:
		var next: Vector2i = slot+Atlas.SIDES[side]
		if next == atlas.live and slot != atlas.live or not atlas.slots.has(next): continue
		var document: Dictionary = atlas.slots[next].document
		var heights: Variant = document.get("heights")
		if not heights is Array or heights.size() != data.points.size(): continue
		var reading := read_side(side,raster(data.points,PackedFloat32Array(heights)),atlas.seed_value,slot)
		if not reading.is_empty(): readings[side] = reading
	if readings.is_empty(): return {}
	var vary := FastNoiseLite.new()
	vary.seed = atlas.seed_value+211
	vary.frequency = 0.07
	vary.fractal_octaves = 2
	var origin := Atlas.world_origin(slot)
	var heights := data.heights
	for i in range(data.points.size()):
		var p := data.points[i]
		var rise := 0.0
		var hollow := 0.0
		for side in readings:
			var relief := relief_at(readings[side],p,origin,vary)
			rise = maxf(rise,relief)
			hollow = minf(hollow,relief)
		heights[i] = clampf(plain[i]+rise+maxf(hollow,-HOLLOW_MAX),NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	data.heights = heights
	var summary := {}
	for side in readings:
		summary[side] = {"relief":readings[side].relief,"reach":readings[side].reach_mean,"across":readings[side].across_mean}
	return summary

## A document's heights resampled onto the GRID_N² raster by inverse distance
## over the points within a metre (the jittered reference mesh is 0.64 m).
static func raster(points: PackedVector2Array, heights: PackedFloat32Array) -> PackedFloat32Array:
	var buckets := {}
	for id in range(points.size()):
		var key := Vector2i(floori(points[id].x+Atlas.HALF),floori(points[id].y+Atlas.HALF))
		if not buckets.has(key): buckets[key] = PackedInt32Array()
		buckets[key].append(id)
	var grid := PackedFloat32Array()
	grid.resize(GRID_N*GRID_N)
	for gz in range(GRID_N):
		for gx in range(GRID_N):
			var at := Vector2(gx*GRID_STEP-Atlas.HALF,gz*GRID_STEP-Atlas.HALF)
			var key := Vector2i(floori(at.x+Atlas.HALF),floori(at.y+Atlas.HALF))
			var total := 0.0
			var weight := 0.0
			var exact := INF
			for dz in range(-1,2):
				for dx in range(-1,2):
					for id in buckets.get(key+Vector2i(dx,dz),PackedInt32Array()):
						var distance := at.distance_squared_to(points[id])
						if distance < 1e-8: exact = heights[id]
						if distance > 1.0: continue
						var w := 1.0/distance
						total += heights[id]*w
						weight += w
			grid[gz*GRID_N+gx] = exact if exact != INF else (total/weight if weight > 0.0 else 0.0)
	return grid

## Bilinear height of the raster at a chunk-local point, clamped to the chunk.
static func height_at(grid: PackedFloat32Array, at: Vector2) -> float:
	var g := ((at+Vector2.ONE*Atlas.HALF)/GRID_STEP).clamp(Vector2.ZERO,Vector2.ONE*(GRID_N-1))
	var x := mini(floori(g.x),GRID_N-2)
	var z := mini(floori(g.y),GRID_N-2)
	var fx := g.x-x
	var fz := g.y-z
	var top := lerpf(grid[z*GRID_N+x],grid[z*GRID_N+x+1],fx)
	var bottom := lerpf(grid[(z+1)*GRID_N+x],grid[(z+1)*GRID_N+x+1],fx)
	return lerpf(top,bottom,fz)

## The neighbour across `side`, at depth d into it from the seam and along t.
static func neighbour_height(reading: Dictionary, depth: float, along: float) -> float:
	return height_at(reading.grid,reading.n*(clampf(depth,0.0,Atlas.SIZE)-Atlas.HALF)+reading.tan*clampf(along,-Atlas.HALF,Atlas.HALF))

## Everything continuation needs from one neighbour: its low ground, and per
## along-seam sample the border height, its slope toward this chunk, the
## ridge heading k, the crest offset c, and how much of the slope runs across
## the seam (1: a range along the seam, 0: ridges crossing it).
static func read_side(side: String, grid: PackedFloat32Array, seed_value: int, slot: Vector2i) -> Dictionary:
	var reading := {"grid":grid,"n":FRAMES[side][0],"tan":FRAMES[side][1]}
	var band := PackedFloat32Array()
	for d in range(0,int(LOW_DEPTH/GRID_STEP)+1):
		for a in range(GRID_N):
			band.append(neighbour_height(reading,d*GRID_STEP,a*GRID_STEP-Atlas.HALF))
	var sorted := band.duplicate()
	sorted.sort()
	var low: float = sorted[int(LOW_QUANTILE*(sorted.size()-1))]
	var relief := 0.0
	for h in band: relief = maxf(relief,absf(h-low))
	if relief < RELIEF_MIN: return {}
	reading.low = low
	reading.relief = relief
	var slope := PackedFloat32Array()
	var shear := PackedFloat32Array()
	var across := PackedFloat32Array()
	for j in range(ALONG_N):
		var t := j*ALONG_STEP-Atlas.HALF
		# Rise toward this chunk over the last 1.5 m of the neighbour.
		slope.append((neighbour_height(reading,0.0,t)-neighbour_height(reading,1.5,t))/1.5)
		# Structure tensor of the band's gradient in (u, t), u running into
		# this chunk (so u = -depth).
		var juu := 0.0
		var jut := 0.0
		var jtt := 0.0
		var depth := GRID_STEP
		while depth <= READ_DEPTH:
			for k in range(-8,9):
				var along := t+k*0.5
				var w := exp(-pow(k*0.5/2.5,2.0))
				var gu := -(neighbour_height(reading,depth+0.25,along)-neighbour_height(reading,depth-0.25,along))/0.5
				var gt := (neighbour_height(reading,depth,along+0.25)-neighbour_height(reading,depth,along-0.25))/0.5
				juu += w*gu*gu
				jut += w*gu*gt
				jtt += w*gt*gt
			depth += GRID_STEP
		var energy := juu+jtt
		if energy < 1e-6:
			shear.append(0.0)
			across.append(1.0)
			continue
		var theta := 0.5*atan2(2.0*jut,juu-jtt)
		var coherence := sqrt(pow(juu-jtt,2.0)+4.0*jut*jut)/energy
		# The gradient runs along theta; the ridge runs across it.
		var k_raw := -cos(theta)/sin(theta) if absf(sin(theta)) > 1e-4 else INF
		var k_value := 0.0 if absf(k_raw) == INF else k_raw*coherence*(1.0-smoothstep(SHEAR_MAX,2.0*SHEAR_MAX,absf(k_raw)))
		shear.append(clampf(k_value,-SHEAR_MAX,SHEAR_MAX))
		across.append(smoothstep(0.55,0.85,juu/energy))
	# Past its crest a range along the seam only comes down: per along sample,
	# the running minimum of the neighbour's heights going in from the border,
	# so a hill deeper inside the neighbour is not mirrored over as a twin.
	var falls := []
	for j in range(ALONG_N):
		var t := j*ALONG_STEP-Atlas.HALF
		var fall := PackedFloat32Array()
		var lowest := INF
		for d in range(GRID_N):
			lowest = minf(lowest,neighbour_height(reading,d*GRID_STEP,t))
			fall.append(lowest)
		falls.append(fall)
	reading.falls = falls
	reading.slope = smooth(slope,1.5)
	reading.shear = smooth(shear,1.5)
	reading.across = smooth(across,1.5)
	# Reach: the world's mountain country (value noise about seven chunks
	# across, as macro.js) and the range's own height.
	var country := FastNoiseLite.new()
	country.seed = seed_value+5
	country.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	country.frequency = 1.0/(7.0*Atlas.SIZE)
	var origin := Atlas.world_origin(slot)
	var mountainous := clampf(0.5+0.5*country.get_noise_2d(origin.x,origin.y)*2.3,0.0,1.0)
	var weight := clampf(0.55*mountainous+0.45*relief/8.0,0.0,1.0)
	reading.reach_base = lerpf(REACH.x,REACH.y,weight)
	reading.reach_mean = reading.reach_base
	var across_total := 0.0
	for value in reading.across: across_total += value
	reading.across_mean = across_total/ALONG_N
	return reading

## Gaussian smoothing along the seam.
static func smooth(values: PackedFloat32Array, sigma: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for j in range(values.size()):
		var total := 0.0
		var weight := 0.0
		for k in range(maxi(0,j-4),mini(values.size(),j+5)):
			var w := exp(-pow((k-j)*ALONG_STEP/sigma,2.0))
			total += values[k]*w
			weight += w
		out[j] = total/weight
	return out

static func along_value(values: PackedFloat32Array, t: float) -> float:
	var g := clampf((t+Atlas.HALF)/ALONG_STEP,0.0,ALONG_N-1.0)
	var j := mini(floori(g),ALONG_N-2)
	return lerpf(values[j],values[j+1],g-j)

## The descending envelope (read_side `falls`) at depth d, along t.
static func fall_at(reading: Dictionary, depth: float, t: float) -> float:
	var g := clampf((t+Atlas.HALF)/ALONG_STEP,0.0,ALONG_N-1.0)
	var j := mini(floori(g),ALONG_N-2)
	var e := clampf(depth/GRID_STEP,0.0,GRID_N-1.0)
	var i := mini(floori(e),GRID_N-2)
	var near: PackedFloat32Array = reading.falls[j]
	var far: PackedFloat32Array = reading.falls[j+1]
	return lerpf(lerpf(near[i],near[i+1],e-i),lerpf(far[i],far[i+1],e-i),g-j)

## Relief this side adds at chunk-local point p, above or below the plain.
static func relief_at(reading: Dictionary, p: Vector2, origin: Vector2, vary: FastNoiseLite) -> float:
	var u: float = Atlas.HALF-p.dot(reading.n)
	var t: float = p.dot(reading.tan)
	var world := p+origin
	var ease_in := smoothstep(0.0,VARY_IN,u)
	t += WARP*ease_in*vary.get_noise_2d(world.x+311.0,world.y-97.0)
	var low: float = reading.low
	var k := along_value(reading.shear,t)
	var across := along_value(reading.across,t)
	# Crossing ridges: the sheared mirror about the seam, no higher than the
	# ridge stands where it meets the border (plus CROSS_CLIMB), so a hill deep
	# inside the neighbour is not copied over and a ridge rising away from the
	# seam runs on level instead of climbing twice.
	var met := neighbour_height(reading,0.0,t-k*u)
	var crossing := minf(neighbour_height(reading,u,t-2.0*k*u),met+CROSS_CLIMB*clampf((met-low)/2.0,0.0,1.0))
	# Along the seam: climb over a crest c past the border, or fall away.
	var along_seam: float
	var m := along_value(reading.slope,t)
	if m > 0.0:
		var c := minf(CAP_PER_SLOPE*m,CAP_MAX)
		if u < 2.0*c:
			along_seam = neighbour_height(reading,0.0,t)+m*u-m*u*u/(2.0*c)
		else:
			along_seam = fall_at(reading,u-2.0*c,t)
	else:
		var edge := neighbour_height(reading,0.0,t)
		var drop := maxf(edge-low,1e-3)
		along_seam = low+(edge-low)*exp(-u*absf(m)/drop)
	var height := lerpf(crossing,along_seam,across)
	# Fade over the reach, ragged along the seam.
	var reach: float = reading.reach_base*(1.0+0.22*vary.get_noise_2d(t*2.0+origin.x,-41.0+origin.y))
	var fade := 1.0-smoothstep(0.4*reach,reach,u)
	var scale := 1.0+VARY*ease_in*vary.get_noise_2d(world.x,world.y)
	return (height-low)*fade*scale
