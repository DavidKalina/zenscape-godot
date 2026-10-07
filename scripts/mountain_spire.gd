extends RefCounted
## A floating mountain's peak, raised out of a sky islet's ground (scripts/
## sky_islet.gd, a recipe's `spire`): the lead islet of the mountain motif
## (scripts/cluster_mountain.gd). The islet's ground tops out a few metres
## up; this stands a real peak on it, 30 to 60 m tall, in the look of the
## basalt ring (scripts/sky_peak.gd): dark faceted basalt, its lava beds
## stepping the cliffs, a snow cap over a ragged line, scree at its foot,
## spruces on its lower slopes and a meadow ring round it to the rim.
##
## It is part of the islet's own heightfield, so everything that reads the
## islet reads it too: the glide's solid (`body`), perching and the walker
## (`islet_at`, scripts/wanderer_eye.gd), `find_spot` and the planting. Its
## shape is a coarse faceted solid, a few dozen big planes: rings of points
## round the summit on SPOKES spokes, alternate rings turned half a spoke so
## the planes are triangles, the rings' heights from a PROFILE with cliff
## bands (rings close, far apart in height) and ledges (rings apart, close
## in height), spokes standing as aretes or sunk as gullies; triangulated,
## then read onto the islet's grid. The grid samples planes exactly, so the
## big facets still read on the fine grid, and are drawn flat (`arrays`).
##
## A trail winds up round it from the meadow to a hut's ledge carved a little
## over half way up (HUT): never steeper than GRADE along, a level bench
## BENCH m wide cut into the rock, stone steps laid on it (cluster_mountain
## `prepare`), lanterns along it. The trail is planned down from the hut, at
## each step at the height the grade gives, where the mountain's face stands
## at that height, round and round till it reaches the foot, so the turns lie
## one over the next with the face between.
##
## Under the islet the rock hangs deeper, an upside-down echo of the peak
## (KEEL), so from far off it reads as a floating mountain: a peak over the
## cloud and a long keel of rock under it.
##
## Faces of the islet the peak draws itself (`drawn`): rock (steep or high),
## scree, and the trail's bench and the hut's ledge; the islet's own top
## leaves them out (SkyIslet `top_arrays`) and draws the meadow and the
## spruces' gentler ground round them.

## The foot: its radius as a share of the islet's (drawn), and the meadow
## kept between it and the rim (m). The peak's height over its foot's
## radius (drawn), held within HEIGHT (m).
const FOOT_SHARE := Vector2(0.6,0.7)
const MEADOW := 3.0
const STATURE := Vector2(2.5,3.0)
const HEIGHT := Vector2(30.0,58.0)
## How far the summit stands off the islet's middle (share of its radius).
const OFF := 0.16
## Spokes round the summit, and how far each turns from even (share of a
## spoke's angle); each spoke's reach (share of the foot), and how much the
## aretes stand out and the gullies sink (share of the height, most at mid
## height).
const SPOKES := Vector2i(7,9)
const SPOKE_TURN := 0.22
const SPOKE_REACH := Vector2(0.86,1.12)
const ARETE := 0.07
const GULLY := 0.06
## Profiles: [share of the foot's radius out, share of the height], summit
## to foot. Each has cliff bands and ledges; one is drawn per peak and each
## point jittered (PROFILE_JITTER: share of radius, share of height).
const PROFILES := [
	[[0.0,1.0],[0.09,0.9],[0.2,0.74],[0.27,0.6],[0.37,0.565],[0.47,0.42],[0.54,0.3],[0.64,0.265],[0.75,0.16],[0.87,0.075],[1.0,0.02],[1.14,0.0]],
	[[0.0,1.0],[0.11,0.86],[0.18,0.72],[0.3,0.68],[0.4,0.5],[0.46,0.39],[0.57,0.355],[0.68,0.22],[0.8,0.12],[0.9,0.06],[1.0,0.02],[1.14,0.0]],
	[[0.0,1.0],[0.08,0.92],[0.16,0.8],[0.22,0.66],[0.33,0.62],[0.43,0.48],[0.5,0.36],[0.62,0.31],[0.72,0.19],[0.85,0.08],[1.0,0.02],[1.14,0.0]],
]
const PROFILE_JITTER := Vector2(0.025,0.025)
## A second summit: the odds, how far out (share of the foot) and how high
## (share of the height).
const TWIN_ODDS := 0.55
const TWIN := Vector2(0.11,0.93)
## The snow: its line (share of the height over the foot), wandering by
## SNOW_RAG m; snow holds on faces gentler than SNOW_SLOPE, and lingers on
## ledges (gentler than LEDGE_SLOPE) SNOW_LINGER m under the line. Its need
## for the seasons' shader (sky_season zs_sky_peak_margin): SNOW_NEED m at
## the line, SNOW_NEED_RISE m more a metre over it, so summer bares the
## lower cap and the summit keeps its snow.
const SNOW_SHARE := Vector2(0.7,0.78)
const SNOW_RAG := 1.6
const SNOW_SLOPE := 3.6
const LEDGE_SLOPE := 1.3
const SNOW_LINGER := 7.0
const SNOW_NEED := 25.0
const SNOW_NEED_RISE := 8.0
## The hut's ledge: its height (share of the peak's, the highest its
## ledge keeps HUT_CLEAR m off the summit), its radius and the ease round
## it (m), how far it is carved in from the face (m).
const HUT := Vector2(0.5,0.6)
const HUT_CLEAR := 7.0
const PAD := 3.2
const PAD_EASE := 1.6
const PAD_IN := 1.0
## The trail: its grade (rise over run), its sample spacing (m), the bench's
## half width and its ease (m), the most turns, and where it ends at the
## foot (m of peak under it).
const GRADE := 0.3
const TRAIL_STEP := 0.5
const BENCH := 1.15
const BENCH_EASE := 0.8
const TURNS := 2.8
const FOOT_LIFT := 0.35
## The keel: the peak's echo under the islet (share of its height), turned
## (radians) so it is not a mirror.
const KEEL := 0.62
const KEEL_TURN := 0.9
## Faces drawn as the peak's: any steeper than DRAW_SLOPE or higher than
## ROCK_SHARE of the peak, once the peak lifts them at least DRAW_LIFT m.
const DRAW_LIFT := 0.25
const DRAW_SLOPE := 0.9
const ROCK_SHARE := 0.4
## Scree: faces at the foot under LIFT m of peak, in fans where SCREE_NOISE
## is over its threshold, and boulders lying in them.
const SCREE_LIFT := 3.2
const SCREE_NOISE := 0.15
const BOULDERS := Vector2i(8,14)
const BOULDER_SIZE := Vector2(0.35,1.05)
const BOULDER_KINDS := ["boulder_1","boulder_2","boulder_3","boulder_4","rock"]
## Spruces on the lower slopes: how many, how high up they climb (share of
## the height), the steepest they stand on, their size and spacing (m).
const SPRUCES := Vector2i(16,26)
const SPRUCE_BAND := Vector2(0.4,0.42)
const SPRUCE_SLOPE := 1.6
const SPRUCE_SIZE := Vector2(0.7,1.15)
const SPRUCE_APART := 2.1
const JUNIPER_ODDS := 0.25
## The rock's colours (linear): the basalt ring's (SkyPeak BASALT), the
## path's slate, the beds' height (m) and the cooling toward the top.
const BASALT := [Color(0.052,0.058,0.073),Color(0.092,0.098,0.115),Color(0.142,0.146,0.160)]
const PATH := Color(0.27,0.262,0.245)
const BED := 3.4
const BED_TONES := [1.0,0.82,1.14,0.9,1.26,0.74]
const COOL := 0.25
const COOL_HUE := Vector3(0.9,0.97,1.16)
const SNOW_NEVER := 1.0e5
const SNOW_JITTER := 0.03

## The summit's spot on the islet (its frame), its foot's radius, the
## peak's height over the ground at its foot, and that ground's height.
var centre := Vector2.ZERO
var foot := 10.0
var height := 40.0
var ground := 0.5
var summit := Vector3.ZERO
## The snow line (islet frame y).
var snowline := 0.0
## The coarse solid: points (x, z) and their lift, triangles, and a bucket
## grid over them (BUCKET m cells) for reading the lift anywhere.
var coarse := PackedVector2Array()
var coarse_lift := PackedFloat32Array()
var tris := PackedInt32Array()
var _buckets := {}
const BUCKET := 3.0
## Each islet point's lift by the peak (m) before the trail was cut, and
## what was cut there: 0 nothing, 1 the trail's bench, 2 the hut's ledge.
var lift := PackedFloat32Array()
var cut := PackedByteArray()
## Each islet face drawn as the peak's: 0 not, 1 rock, 2 path, 3 scree.
var drawn := PackedByteArray()
## The trail (islet frame, y its tread), foot to hut, TRAIL_STEP apart.
var trail := PackedVector3Array()
## The hut's ledge: its middle and the way out from the peak.
var hut := Vector2.ZERO
var hut_y := 0.0
var hut_out := Vector2.RIGHT
var seed := 0
var stature := STATURE

## Raises the peak on `islet` (after its ground and keel are laid, before
## its planting): its heights, keel and recipe (the spruces and boulders as
## records, the trail and ledge kept clear) are changed; returns the peak.
static func raise(islet: RefCounted) -> RefCounted:
	var spire: RefCounted = new()
	spire._raise(islet)
	return spire

func _raise(islet: RefCounted) -> void:
	seed = int(islet.seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,"spire"])
	var spec: Dictionary = islet.recipe.get("spire",{}) if islet.recipe.get("spire") is Dictionary else {}
	var radius: float = islet.radius
	# The summit: the most inland ground near the middle, a little off it.
	var points: PackedVector2Array = islet.points
	var distance: PackedFloat32Array = islet.shore_distance
	var best := -INF
	for i in range(points.size()):
		var score := distance[i]-points[i].length()*0.25
		if score > best:
			best = score
			centre = points[i]
	var nudge := centre+Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.0,OFF)
	if islet.inland(nudge) > islet.inland(centre)*0.85: centre = nudge
	var share: Vector2 = spec.get("foot",FOOT_SHARE)
	foot = radius*rng.randf_range(share.x,share.y)
	stature = spec.get("stature",STATURE)
	ground = islet.ground_at(centre)
	_shape_coarse(islet,rng)
	_read_lift(islet)
	var heights: PackedFloat32Array = islet.heights
	for i in range(heights.size()): heights[i] += lift[i]
	islet.heights = heights
	summit = Vector3(centre.x,islet.ground_at(centre),centre.y)
	snowline = ground+height*rng.randf_range(SNOW_SHARE.x,SNOW_SHARE.y)
	_plan_trail(islet,rng)
	_carve(islet)
	_deepen(islet)
	_mark(islet)
	_dress(islet,rng)

# --- The solid --------------------------------------------------------------------

## The coarse points round the summit and their triangles.
func _shape_coarse(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var profile: Array = PROFILES[rng.randi()%PROFILES.size()]
	var spokes := rng.randi_range(SPOKES.x,SPOKES.y)
	var angles := PackedFloat32Array()
	var base := rng.randf()*TAU
	for k in range(spokes): angles.append(base+TAU*(k+rng.randf_range(-SPOKE_TURN,SPOKE_TURN))/spokes)
	# Each spoke's reach, held short of the meadow, and its lie: arete or gully.
	var reach := PackedFloat32Array()
	var lie := PackedFloat32Array()
	var last: Array = profile[profile.size()-1]
	var mean := 0.0
	for k in range(spokes):
		var room := _room(islet,angles[k])
		reach.append(minf(rng.randf_range(SPOKE_REACH.x,SPOKE_REACH.y),room/(foot*float(last[0]))))
		lie.append(ARETE if (k%2 == 0) != (rng.randf() < 0.25) else -GULLY*rng.randf_range(0.4,1.0))
		mean += reach[k]*foot/spokes
	# Its height by its foot's mean reach, so a narrow islet's peak is a
	# ridge no steeper than a round one's.
	height = clampf(mean*rng.randf_range(stature.x,stature.y),HEIGHT.x,HEIGHT.y)
	coarse = PackedVector2Array([centre])
	coarse_lift = PackedFloat32Array([height])
	for r in range(1,profile.size()):
		var s: float = profile[r][0]
		var f: float = profile[r][1]
		var outer := r == profile.size()-1
		for k in range(spokes):
			# Alternate rings stand half a spoke round, between two spokes.
			var half := r%2 == 1
			var k2 := (k+1)%spokes
			var a := angles[k]
			var reach_here := reach[k]
			var lie_here := lie[k]
			if half:
				var next := angles[k2] if k2 > k else angles[k2]+TAU
				a = (a+next)*0.5
				reach_here = (reach[k]+reach[k2])*0.5
				lie_here = (lie[k]+lie[k2])*0.25
			var out := s*(1.0+(0.0 if outer else rng.randf_range(-PROFILE_JITTER.x,PROFILE_JITTER.x)))*reach_here*foot
			var up := 0.0
			if not outer:
				up = height*(f+rng.randf_range(-PROFILE_JITTER.y,PROFILE_JITTER.y)*f+lie_here*sin(PI*clampf(s,0.0,1.0)))
				up = maxf(up,0.0)
			coarse.append(centre+Vector2.from_angle(a)*out)
			coarse_lift.append(up)
	# A second summit a little way down one spoke.
	if rng.randf() < TWIN_ODDS:
		var k := rng.randi()%spokes
		coarse.append(centre+Vector2.from_angle(angles[k])*TWIN.x*foot*reach[k])
		coarse_lift.append(height*TWIN.y)
	tris = Geometry2D.triangulate_delaunay(coarse)
	_buckets.clear()
	for t in range(0,tris.size(),3):
		var box := Rect2(coarse[tris[t]],Vector2.ZERO).expand(coarse[tris[t+1]]).expand(coarse[tris[t+2]])
		for bx in range(floori(box.position.x/BUCKET),floori(box.end.x/BUCKET)+1):
			for bz in range(floori(box.position.y/BUCKET),floori(box.end.y/BUCKET)+1):
				var key := Vector2i(bx,bz)
				if not _buckets.has(key): _buckets[key] = []
				(_buckets[key] as Array).append(t)

## How far from the summit along `angle` the land keeps MEADOW m in from the
## shore (m).
func _room(islet: RefCounted, angle: float) -> float:
	var way := Vector2.from_angle(angle)
	var r := 0.0
	while r < float(islet.reach):
		if islet.inland(centre+way*(r+0.5)) < MEADOW: break
		r += 0.5
	return maxf(r,3.0)

## The peak's lift at `p` (islet frame), 0 off it.
func lift_at(p: Vector2) -> float:
	var key := Vector2i(floori(p.x/BUCKET),floori(p.y/BUCKET))
	var list: Variant = _buckets.get(key)
	if list == null: return 0.0
	for t: int in list:
		var w := _barycentric(p,coarse[tris[t]],coarse[tris[t+1]],coarse[tris[t+2]])
		if w.x >= -0.0001 and w.y >= -0.0001 and w.z >= -0.0001:
			return w.x*coarse_lift[tris[t]]+w.y*coarse_lift[tris[t+1]]+w.z*coarse_lift[tris[t+2]]
	return 0.0

## The lift on every islet point inside the coarse solid, read triangle by
## triangle over the grid points under it.
func _read_lift(islet: RefCounted) -> void:
	var points: PackedVector2Array = islet.points
	var distance: PackedFloat32Array = islet.shore_distance
	lift.resize(points.size())
	lift.fill(0.0)
	var cells: int = islet.cells
	var half: float = islet.half
	var step := half*2.0/cells
	var side := cells+1
	for t in range(0,tris.size(),3):
		var a := coarse[tris[t]]
		var b := coarse[tris[t+1]]
		var c := coarse[tris[t+2]]
		var box := Rect2(a,Vector2.ZERO).expand(b).expand(c)
		var i0 := clampi(floori((box.position.x+half)/step)-1,0,cells)
		var i1 := clampi(ceili((box.end.x+half)/step)+1,0,cells)
		var j0 := clampi(floori((box.position.y+half)/step)-1,0,cells)
		var j1 := clampi(ceili((box.end.y+half)/step)+1,0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var n := j*side+i
				if distance[n] < 0.0: continue
				var w := _barycentric(points[n],a,b,c)
				if w.x >= -0.0001 and w.y >= -0.0001 and w.z >= -0.0001:
					lift[n] = w.x*coarse_lift[tris[t]]+w.y*coarse_lift[tris[t+1]]+w.z*coarse_lift[tris[t+2]]

static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b-a
	var v1 := c-a
	var v2 := p-a
	var d := v0.x*v1.y-v1.x*v0.y
	if absf(d) < 1e-9: return Vector3(-1.0,-1.0,-1.0)
	var v := (v2.x*v1.y-v1.x*v2.y)/d
	var w := (v0.x*v2.y-v2.x*v0.y)/d
	return Vector3(1.0-v-w,v,w)

# --- The trail and the hut's ledge --------------------------------------------------

## Where the face along `angle` from the summit first comes down to `y`: the
## distance out (m), scanning out from the summit and narrowing in.
func _out_at(islet: RefCounted, angle: float, y: float) -> float:
	var way := Vector2.from_angle(angle)
	var r := 0.0
	var limit := foot*1.3
	while r < limit:
		if islet.ground_at(centre+way*(r+0.3)) < y: break
		r += 0.3
	var lo := r
	var hi := r+0.3
	for k in range(8):
		var mid := (lo+hi)*0.5
		if islet.ground_at(centre+way*mid) < y: hi = mid
		else: lo = mid
	return (lo+hi)*0.5

## The hut's ledge, then the trail down from it round the peak to the foot
## (kept foot to hut).
func _plan_trail(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var hut_angle := rng.randf()*TAU
	hut_y = ground+height*rng.randf_range(HUT.x,HUT.y)
	var face := _out_at(islet,hut_angle,hut_y)
	# Lower till the ledge stands clear of the summit's spire.
	while face-PAD_IN < HUT_CLEAR and hut_y > ground+height*0.2:
		hut_y -= 0.5
		face = _out_at(islet,hut_angle,hut_y)
	hut_out = Vector2.from_angle(hut_angle)
	hut = centre+hut_out*maxf(face-PAD_IN,1.0)
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	var angle := hut_angle
	var y := hut_y
	var down: Array[Vector3] = []
	var swept := 0.0
	var steps := 0
	while steps < 4000:
		steps += 1
		var r := _out_at(islet,angle,y)
		var p := centre+Vector2.from_angle(angle)*r
		down.append(Vector3(p.x,y,p.y))
		if lift_at(p) < FOOT_LIFT or swept > TAU*TURNS: break
		# On round: the next point TRAIL_STEP on, lower by the grade over
		# the way it went (level while still on the ledge).
		var a := angle-turn*TRAIL_STEP/maxf(r,2.0)
		var on_ledge := p.distance_to(hut) < PAD
		var next_y := y-(0.0 if on_ledge else GRADE*TRAIL_STEP)
		for k in range(2):
			var q := centre+Vector2.from_angle(a)*_out_at(islet,a,next_y)
			if not on_ledge: next_y = y-GRADE*maxf(q.distance_to(p),0.05)
		swept += absf(a-angle)
		angle = a
		y = next_y
	down.reverse()
	trail = PackedVector3Array(down)

## Cuts the ledge and then the trail's bench into the heights: level across,
## eased into the face either side.
func _carve(islet: RefCounted) -> void:
	var points: PackedVector2Array = islet.points
	var distance: PackedFloat32Array = islet.shore_distance
	var heights: PackedFloat32Array = islet.heights
	cut.resize(points.size())
	cut.fill(0)
	var cells: int = islet.cells
	var half: float = islet.half
	var step := half*2.0/cells
	var side := cells+1
	var near := func(box: Rect2) -> PackedInt32Array:
		var out := PackedInt32Array()
		var i0 := clampi(floori((box.position.x+half)/step)-1,0,cells)
		var i1 := clampi(ceili((box.end.x+half)/step)+1,0,cells)
		var j0 := clampi(floori((box.position.y+half)/step)-1,0,cells)
		var j1 := clampi(ceili((box.end.y+half)/step)+1,0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				if distance[j*side+i] >= 0.0: out.append(j*side+i)
		return out
	# The ledge.
	var reach := PAD+PAD_EASE
	for n: int in near.call(Rect2(hut-Vector2.ONE*reach,Vector2.ONE*reach*2.0)):
		var d := points[n].distance_to(hut)
		var t := 1.0-smoothstep(PAD,reach,d)
		if t <= 0.0: continue
		heights[n] = lerpf(heights[n],hut_y,t)
		if d < PAD: cut[n] = 2
	# The bench: each point takes the tread of the nearest of the trail.
	var best := {}
	var wide := BENCH+BENCH_EASE
	for k in range(trail.size()-1):
		var a := Vector2(trail[k].x,trail[k].z)
		var b := Vector2(trail[k+1].x,trail[k+1].z)
		var box := Rect2(a,Vector2.ZERO).expand(b).grow(wide)
		for n: int in near.call(box):
			var p := points[n]
			var ab := b-a
			var u := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
			var d := p.distance_to(a+ab*u)
			if d > wide: continue
			if not best.has(n) or d < float(best[n][0]): best[n] = [d,lerpf(trail[k].y,trail[k+1].y,u)]
	for n: int in best:
		if cut[n] == 2: continue
		var d: float = best[n][0]
		var t := 1.0-smoothstep(BENCH,wide,d)
		heights[n] = lerpf(heights[n],float(best[n][1]),t)
		if d < BENCH: cut[n] = 1
	islet.heights = heights

## The keel hangs deeper under the peak: its echo, turned.
func _deepen(islet: RefCounted) -> void:
	var keel: PackedFloat32Array = islet.keel
	var points: PackedVector2Array = islet.points
	var distance: PackedFloat32Array = islet.shore_distance
	for i in range(points.size()):
		if distance[i] < 0.0: continue
		var p := centre+(points[i]-centre).rotated(KEEL_TURN)
		keel[i] += lift_at(p)*KEEL
	islet.keel = keel

## Which faces the peak draws: rock, path or scree.
func _mark(islet: RefCounted) -> void:
	var ids: PackedInt32Array = islet.ids
	var land: PackedInt32Array = islet.land
	drawn.resize(int(ids.size()/3.0))
	drawn.fill(0)
	var scree := _noise(31,0.16)
	for f in land:
		var a := ids[f*3]
		var b := ids[f*3+1]
		var c := ids[f*3+2]
		var up := (lift[a]+lift[b]+lift[c])/3.0
		if cut[a] > 0 and cut[b] > 0 and cut[c] > 0:
			drawn[f] = 2
			continue
		if up < DRAW_LIFT: continue
		var slope: float = islet._slope(f)
		var mid: Vector2 = (islet.points[a]+islet.points[b]+islet.points[c])/3.0
		if slope > DRAW_SLOPE or up > height*ROCK_SHARE: drawn[f] = 1
		elif up < SCREE_LIFT and scree.get_noise_2d(mid.x,mid.y) > SCREE_NOISE: drawn[f] = 3

func _noise(salt: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed+salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	return n

## The spruces on the lower slopes and the boulders at the foot, as the
## recipe's records; the trail, the ledge and each of them kept clear of
## the islet's own planting.
func _dress(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var recipe: Dictionary = islet.recipe
	var objects: Array = recipe.get("objects",[])
	var clear: Array = recipe.get("clear",[])
	for k in range(0,trail.size(),3): clear.append(Vector3(trail[k].x,trail[k].z,BENCH+0.4))
	clear.append(Vector3(hut.x,hut.y,PAD+0.6))
	var taken: Array[Vector3] = []
	for c: Vector3 in clear: taken.append(c)
	var script: Script = islet.get_script()
	var tints := {}
	var want := rng.randi_range(SPRUCES.x,SPRUCES.y)
	var placed := 0
	for attempt in range(want*14):
		if placed >= want: break
		var p := centre+Vector2.from_angle(rng.randf()*TAU)*foot*sqrt(rng.randf_range(0.04,1.3))
		var up := lift_at(p)
		if up < 0.6 or up > height*rng.randf_range(SPRUCE_BAND.x,SPRUCE_BAND.y): continue
		if not islet.on_land(p) or islet.inland(p) < 1.0: continue
		if _steep(islet,p) > SPRUCE_SLOPE: continue
		var tree := "juniper" if rng.randf() < JUNIPER_ODDS else "tree"
		var size := rng.randf_range(SPRUCE_SIZE.x,SPRUCE_SIZE.y)*lerpf(1.0,0.75,up/(height*SPRUCE_BAND.y))
		var room := SPRUCE_APART*size
		if _taken(p,taken,room*0.5): continue
		if not tints.has(tree): tints[tree] = script._tree_tint(tree,rng)
		objects.append({"asset":tree,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size,"tint":tints[tree],"inset":0.8})
		taken.append(Vector3(p.x,p.y,room*0.5))
		clear.append(Vector3(p.x,p.y,0.6))
		placed += 1
	var stones := rng.randi_range(BOULDERS.x,BOULDERS.y)
	placed = 0
	var scree := _noise(31,0.16)
	for attempt in range(stones*16):
		if placed >= stones: break
		var p := centre+Vector2.from_angle(rng.randf()*TAU)*foot*rng.randf_range(0.7,1.15)
		var up := lift_at(p)
		if up > SCREE_LIFT or up < 0.05 or scree.get_noise_2d(p.x,p.y) < SCREE_NOISE-0.1: continue
		if not islet.on_land(p) or islet.inland(p) < 1.0: continue
		var size := rng.randf_range(BOULDER_SIZE.x,BOULDER_SIZE.y)
		if _taken(p,taken,size*0.7): continue
		objects.append({"asset":BOULDER_KINDS[rng.randi()%BOULDER_KINDS.size()],"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size,"inset":0.8})
		taken.append(Vector3(p.x,p.y,size*0.7))
		clear.append(Vector3(p.x,p.y,size*0.6))
		placed += 1
	recipe.objects = objects
	recipe.clear = clear

## The slope (rise over run) of the ground at `p`.
func _steep(islet: RefCounted, p: Vector2) -> float:
	var e := 0.5
	var gx: float = islet.ground_at(p+Vector2(e,0.0))-islet.ground_at(p-Vector2(e,0.0))
	var gz: float = islet.ground_at(p+Vector2(0.0,e))-islet.ground_at(p-Vector2(0.0,e))
	return Vector2(gx,gz).length()/(2.0*e)

static func _taken(p: Vector2, taken: Array, room: float) -> bool:
	for t: Vector3 in taken:
		if p.distance_to(Vector2(t.x,t.y)) < t.z+room: return true
	return false

# --- Its mesh -----------------------------------------------------------------------

## The peak's faces (`drawn`) as surface arrays for the basalt ring's ground
## material (scripts/sky_peaks.gd `_ground`): flat faces in the basalt's
## tones, its beds on the cliffs, the path's slate, the scree; each face's
## snow need in UV.x and its shade in UV2.x, its height in UV2.y, as
## SkyPeak `body_arrays` lays them. Safe on a worker; laid `shift` off, as
## the islet's top is.
func arrays(islet: RefCounted, shift := Vector3.ZERO) -> Array:
	var ids: PackedInt32Array = islet.ids
	var land: PackedInt32Array = islet.land
	var patch := _noise(67,0.08)
	var rag := _noise(73,0.12)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	for f in land:
		var kind := drawn[f] if f < drawn.size() else 0
		if kind == 0: continue
		var a: Vector3 = islet._vertex(ids[f*3])
		var b: Vector3 = islet._vertex(ids[f*3+1])
		var c: Vector3 = islet._vertex(ids[f*3+2])
		var n := (c-a).cross(b-a).normalized()
		if n.y < 0.0: n = -n
		var mid := (a+b+c)/3.0
		var slope := sqrt(maxf(0.0,1.0-n.y*n.y))/maxf(n.y,0.001)
		var jitter := 1.0+rng.randf_range(-0.03,0.03)
		var tone: Color
		var need := SNOW_NEVER
		var shade := 16.0
		if kind == 2:
			tone = PATH*(1.0+0.08*patch.get_noise_2d(mid.x*3.0,mid.z*3.0))*jitter
		elif kind == 3:
			tone = (BASALT[2] as Color).lerp(PATH,0.45)*(1.0+0.1*patch.get_noise_2d(mid.x*2.0,mid.z*2.0))*jitter
		else:
			tone = _rock(mid,slope,patch)*jitter
			var line := snowline+rag.get_noise_2d(mid.x,mid.z)*SNOW_RAG*2.0
			var snowy := (mid.y > line and slope < SNOW_SLOPE) or (mid.y > line-SNOW_LINGER and slope < LEDGE_SLOPE)
			if snowy:
				need = -(SNOW_NEED+maxf(mid.y-line,0.0)*SNOW_NEED_RISE)
				shade = _snow_pack(clampf(1.0-n.y,0.0,1.0)*0.6,rng.randf_range(-SNOW_JITTER,SNOW_JITTER))
		for q: Vector3 in [a,b,c]:
			vertices.append(q+shift)
			normals.append(n)
			colours.append(tone)
			uv.append(Vector2(need,1.0))
			uv2.append(Vector2(shade,q.y))
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertices
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colours
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_TEX_UV2] = uv2
	return out

## A rock face's colour: the basalt ring's (SkyPeak `_tone`), weathered slate
## where it lies back, basalt where it stands, blue-black on the sheerest;
## its beds (lava flows) showing on the cliffs, cooler toward the top.
func _rock(at: Vector3, slope: float, patch: FastNoiseLite) -> Color:
	var steep := smoothstep(0.45,1.5,slope)
	var stone: Color = (BASALT[2] as Color).lerp(BASALT[1],steep)
	stone = stone.lerp(BASALT[0],smoothstep(1.5,2.9,slope)*0.6)
	stone *= 1.0+0.12*patch.get_noise_2d(at.x,at.z)
	var grey := (stone.r+stone.g+stone.b)/3.0
	stone = stone.lerp(Color(grey*COOL_HUE.x,grey*COOL_HUE.y,grey*COOL_HUE.z),COOL*clampf((at.y-ground)/height,0.0,1.0))
	var bed := floori((at.y+patch.get_noise_2d(at.x*2.3+71.0,at.z*2.3-13.0)*0.8)/BED)
	var pick := absi(hash([seed,bed,"bed"]))%BED_TONES.size()
	var show := smoothstep(0.75,1.9,slope)
	return stone*lerpf(1.0,float(BED_TONES[pick]),show)

## A snowy face's shade for the shader (as SkyPeak `_snow_pack`).
static func _snow_pack(blue: float, nudge: float) -> float:
	var step := roundf((clampf(nudge/SNOW_JITTER,-1.0,1.0)*0.5+0.5)*32.0)
	return step+clampf(blue,0.0,1.0)*0.999

# --- Checks -------------------------------------------------------------------------

## What is wrong with the peak on `islet`, as sentences (`label` names it):
## too low; a trail missing, too steep, off its bench, crossing itself or
## not reaching the ledge or the foot; a ledge not level.
func problems(islet: RefCounted, label: String) -> Array:
	var out: Array = []
	var top := summit.y-float(islet.ground_at(centre+(hut_out*foot*1.2)))
	if height < HEIGHT.x-0.01: out.append("peak too low on %s (%.1f m)" % [label,height])
	if trail.size() < 8:
		out.append("no trail on %s" % label)
		return out
	var steepest := 0.0
	var off := 0.0
	for k in range(trail.size()):
		var p := Vector2(trail[k].x,trail[k].z)
		if not islet.on_land(p) or islet.wet(p):
			out.append("trail off the land on %s" % label)
			break
		off = maxf(off,absf(float(islet.ground_at(p))-trail[k].y))
		if k > 0:
			var run := p.distance_to(Vector2(trail[k-1].x,trail[k-1].z))
			steepest = maxf(steepest,absf(trail[k].y-trail[k-1].y)/maxf(run,0.05))
	if steepest > GRADE*1.5: out.append("trail too steep on %s (%.2f)" % [label,steepest])
	if off > 0.3: out.append("trail off its bench on %s (%.2f m)" % [label,off])
	# The turns lie apart, the bench's width and more.
	var along := PackedFloat32Array([0.0])
	for k in range(1,trail.size()): along.append(along[k-1]+Vector2(trail[k].x-trail[k-1].x,trail[k].z-trail[k-1].z).length())
	var closest := INF
	for i in range(0,trail.size(),2):
		for j in range(i+1,trail.size(),2):
			if along[j]-along[i] < 12.0: continue
			closest = minf(closest,Vector2(trail[i].x-trail[j].x,trail[i].z-trail[j].z).length())
	if closest < BENCH*2.0+0.3: out.append("trail crosses itself on %s (%.2f m)" % [label,closest])
	var last := Vector2(trail[trail.size()-1].x,trail[trail.size()-1].z)
	if last.distance_to(hut) > PAD+0.6: out.append("trail misses the ledge on %s" % label)
	var first := Vector2(trail[0].x,trail[0].z)
	if lift_at(first) > 1.2: out.append("trail ends up the face on %s (%.1f m)" % [label,lift_at(first)])
	var low := INF
	var high := -INF
	for k in range(9):
		var q := hut if k == 8 else hut+Vector2.from_angle(TAU*k/8.0)*PAD*0.8
		low = minf(low,float(islet.ground_at(q)))
		high = maxf(high,float(islet.ground_at(q)))
	if high-low > 0.3: out.append("hut ledge not level on %s (%.2f m)" % [label,high-low])
	if top < HEIGHT.x*0.8: out.append("peak stands low over its meadow on %s (%.1f m)" % [label,top])
	return out
