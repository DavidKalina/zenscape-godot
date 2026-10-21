extends "res://scripts/mountain_spire.gd"
## A mountain island's massif, raised out of a sky islet's ground (scripts/
## sky_islet.gd, a recipe's `massif`; scripts/landform_mountains.gd lays the
## recipe): the landmark of the lower world's archipelago, an island 55 to
## 100 m across whose summits stand far over every other island. It is the
## floating mountain's peak (scripts/mountain_spire.gd) grown into a range,
## and draws as that peak does, in the basalt ring's look: green lower
## slopes, a band of conifers to a ragged treeline, scree, then dark faceted
## basalt with its lava beds stepping the cliffs, and a snow cap on each
## summit (`_snow_faces`): down its ridges, gentler faces, gullies and the
## corrie, ragged at its foot, the steepest faces left rock.
##
## Its shape, all in the islet's frame:
##   two summits on a ridge across the island (the main and a lower second,
##     sometimes a third, a shoulder off the ridge), each a stepped cone
##     (PROFILE: cliff bands and ledges; a tall one broadened at its head,
##     BROAD) whose reach round it runs to the
##     shore, pushed out along aretes that radiate from it and pulled in
##     along the gullies between;
##   a col between the two, a flat-floored notch cut down to COL of the
##     height, wide enough to fly through (COL_HALF, COL_WALL);
##   a corrie on one flank of the main summit, a bowl under a sheer
##     headwall, its floor running out as a glen down to the shore;
##   a hut on the col, its pad levelled as the peak's ledge is.
## The heights are a coarse faceted solid as the peak's (`coarse`, `tris`):
## points every COARSE m over the island, and along its crests (the ridge,
## the aretes, the glen's floor) so they stay sharp; triangulated and read
## onto the islet's grid (MountainSpire `_read_lift`), so its big planes
## read on the grid as flat facets.
##
## Faces it draws itself (`drawn`, as the peak's): basalt and snow over the
## treeline or steeper than ROCK_SLOPE, scree in fans under the cliffs and in
## the corrie, the hut's pad; the islet's own top draws the rest, the green
## lower slopes, the col's alpine turf and the glen. Lone faces of one among
## the other are folded in (`_tidy`), so no green speckle shows on the rock
## and no dark pit in the grass. It plants the conifers itself (`_dress`); the
## islet's own planting keeps off its faces (`bare`).

## Its height over its foot: the islet's radius times STATURE, held within the
## recipe's `height` (the landform's SUMMIT).
const STATURE_SHARE := Vector2(1.3,1.6)
const TALLEST := Vector2(36.0,85.0)
## The summits: how far each stands out from the middle along the ridge
## (share of the radius), the second's height (share of the main's), the
## odds of a third (a shoulder off the ridge) and its height and offset.
const SPREAD := Vector2(0.24,0.32)
const SECOND := Vector2(0.76,0.9)
const THIRD_ODDS := 0.6
const THIRD := Vector2(0.52,0.66)
const THIRD_OUT := Vector2(0.28,0.38)
## The hut stands at least this far (m) past its pad's ease below the col,
## where its ground varies by no more than HUT_SPREAD m over its pad.
const HUT_BELOW := 1.2
const HUT_SPREAD := 9.0
## The hut window's halo: its size (m) and strength, as the floating
## mountain's hut's star (scripts/cluster_mountain.gd STAR_HALO).
const HUT_HALO := Vector2(3.6,1.0)
## The two summits stand at least this far apart (share of the radius).
const APART := 0.42
## A summit's profile out to its reach: [share of the reach out, share of
## its height], summit to foot. A cliff band where the share drops fast,
## a ledge where it lingers; the lower third a long green apron.
const PROFILE := [[0.0,1.0],[0.06,0.9],[0.14,0.74],[0.2,0.64],[0.27,0.52],[0.36,0.4],[0.45,0.27],[0.55,0.17],
	[0.66,0.1],[0.78,0.05],[0.9,0.015],[1.0,0.0]]
## How far a summit reaches (share of its room to the shore), how far its
## aretes push out (share) and how wide they are (radians), and how far
## the gullies between pull in.
const REACH_SHARE := Vector2(0.92,1.05)
const ARETES := Vector2i(4,6)
const ARETE_OUT := 0.26
const ARETE_WIDTH := 0.2
const GULLY_IN := 0.1
## The lift fades to the islet's own ground over this many metres in from
## the shore, so the shore stays the islands' own.
const SHORE_EASE := 3.0
## The col: its floor's height (share of the main summit's), its flat
## floor's half width along the ridge (m, share of the radius, held within
## COL_HALF_M) and how steeply its walls rise (rise over run, at least; more
## where a summit stands close, so the walls never cut a summit down).
const COL := Vector2(0.4,0.48)
const COL_HALF := 0.16
const COL_HALF_M := Vector2(4.0,10.0)
const COL_WALL := 1.4
## The corrie: how far out on the main summit's flank (share of its reach),
## its floor's height (share of the height), its size (share of the
## radius) and its flat floor (share of its size), the height its headwall
## reaches at its rim (share of the height; steeper where the summit stands
## close, so it never cuts the summit down); the glen falls from its floor
## to the shore.
const CORRIE_OUT := Vector2(0.3,0.38)
const CORRIE_FLOOR := Vector2(0.2,0.26)
const CORRIE_SIZE := Vector2(0.3,0.36)
const CORRIE_FLAT := 0.48
const CORRIE_WALL := 0.75
## The coarse solid's spacing (m, share of the radius held within COARSE_M),
## how far its points are jittered (share of the spacing) and their height
## (share of their lift).
const COARSE := 0.09
const COARSE_M := Vector2(3.0,5.0)
const COARSE_JITTER := 0.32
const LIFT_JITTER := 0.035
const CREST_WEAVE := 0.12
## The bands: the treeline and the rock above it (shares of the height,
## ragged by BAND_RAG of the height), and the snow line (share).
const TREELINE := Vector2(0.22,0.28)
const ROCKLINE := 0.08
const BAND_RAG := 0.05
const SNOWLINE := Vector2(0.54,0.62)
## Faces steeper than this are rock wherever they are; scree lies between
## SCREE_SLOPE and it under the rock line, in fans.
const ROCK_SLOPE := 1.35
const SCREE_SLOPE := 0.6
const SCREE_FANS := 0.05
## The conifers: how many a square metre of forest band, at least and most,
## the steepest they stand on, their size, spacing (m, times their size),
## the odds of a juniper or (low down) a birch.
const CONIFERS := 0.045
const CONIFER_COUNT := Vector2i(30,160)
const CONIFER_SLOPE := 1.5
const CONIFER_SIZE := Vector2(0.9,1.4)
const CONIFER_APART := 2.0
const CONIFER_JUNIPER := 0.2
const CONIFER_BIRCH := 0.18
## Boulders on the scree.
const STONES_ON_SCREE := Vector2i(10,22)
const STONE_SIZE := Vector2(0.5,1.5)
## A summit standing more than BROAD.x times as high as its mean reach
## reads its profile at x to the power p, p rising to BROAD.z at BROAD.y
## times, so a small island's summit stands as a broad head over its
## cliffs, not a needle.
const BROAD := Vector3(0.7,1.5,1.9)
## The snow, cap by cap (`_snow_faces`): each summit's line CAP of the way
## the islet's snow line stands up the main one, on its own height; ragged
## by CAP_RAG of the height over waves 1/CAP_RAG_WAVE m; down into hollows
## by up to HOLLOW_SNOW of the height (full at HOLLOW_FULL m a metre,
## read over HOLLOW_M) and on crests by CREST_SNOW; the corrie's bowl
## snowed to CORRIE_SNOW of the height over its floor. Snow holds on faces
## up to HOLD.x steep at its line, HOLD.y toward the summit, HOLD_HOLLOW
## more in a hollow, and on ledges gentler than LEDGE_SNOW a little under
## the line; never under the treeline's SNOW_FLOOR m over it. A snowy
## face's lie for the shader's flutes is leaned up by CAP_LIE.
const CAP := 0.9
const CAP_RAG := 0.07
const CAP_RAG_WAVE := Vector2(0.06,0.22)
const HOLLOW_SNOW := 0.16
const HOLLOW_FULL := 0.25
const HOLLOW_M := 4.0
const CREST_SNOW := 0.05
const CORRIE_SNOW := 0.12
const HOLD := Vector2(1.2,3.6)
const HOLD_HOLLOW := 0.7
const LEDGE_SNOW := 0.75
const SNOW_FLOOR := 4.0
const CAP_LIE := 1.8

## The summits, Vector3(x, z, lift over the foot), main first; the ridge's
## way (main to second), the col (x, z, its floor's lift) and the way
## across it; the corrie (x, z, size), its floor's lift and the glen's way.
var summits: Array[Vector3] = []
var axis := Vector2.RIGHT
var col := Vector3.ZERO
var col_half := 6.0
## The col's half width asked by the recipe (`massif.col_half`, m; 0: its
## own, from the radius and the summits' spacing). Opt-in: a flown pass
## sized by WorldScale.opening (studies/home_hub.gd).
var col_want := 0.0
## The col's walls' steepness toward the main summit (x) and the second (y).
var col_walls := Vector2(COL_WALL,COL_WALL)
var across := Vector2.UP
var corrie := Vector3.ZERO
var corrie_floor := 0.0
var corrie_wall := 1.0
var glen := Vector2.UP
var glen_length := 10.0
## The treeline (islet frame y) and each summit's room to the shore by
## angle (ROOM_ANGLES of them) and its arete angles.
var treeline := 0.0
## The lowest any snow lies (islet frame y), and each summit's profile
## power (BROAD).
var snow_floor := 0.0
var _broad := PackedFloat32Array()
var _rooms: Array = []
var _aretes: Array = []
var _raggy: FastNoiseLite
const ROOM_ANGLES := 64

## Raises the massif on `islet` (after its ground and keel are laid, before
## its planting), as MountainSpire `raise` does a peak; returns it.
static func raise_massif(islet: RefCounted) -> RefCounted:
	var massif: RefCounted = new()
	massif._raise_massif(islet)
	return massif

func _raise_massif(islet: RefCounted) -> void:
	seed = int(islet.seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,"massif"])
	var spec: Dictionary = islet.recipe.get("massif",{}) if islet.recipe.get("massif") is Dictionary else {}
	var radius: float = islet.radius
	tall = spec.get("height",TALLEST)
	var share: Vector2 = spec.get("stature",STATURE_SHARE)
	height = clampf(radius*rng.randf_range(share.x,share.y),tall.x,tall.y)
	foot = radius
	snowy = bool(spec.get("snow",true))
	with_trail = bool(spec.get("hut",true))
	col_want = float(spec.get("col_half",0.0))
	_raggy = _noise(83,0.05)
	_lay_out(islet,rng)
	_shape_massif(islet,rng)
	_read_lift(islet)
	var heights: PackedFloat32Array = islet.heights
	for i in range(heights.size()): heights[i] += lift[i]
	islet.heights = heights
	summit = Vector3(centre.x,islet.ground_at(centre),centre.y)
	snowline = ground+height*rng.randf_range(SNOWLINE.x,SNOWLINE.y)
	treeline = ground+height*rng.randf_range(TREELINE.x,TREELINE.y)
	# Snow lingering on ledges under the line (MountainSpire `arrays`)
	# never reaches down to the trees.
	snowline = maxf(snowline,treeline+SNOW_LINGER+SNOW_RAG*2.0+1.0)
	snow_floor = treeline+SNOW_FLOOR
	if with_trail: _place_hut(islet)
	_carve(islet)
	_deepen(islet)
	_mark(islet)
	_dress(islet,rng)

# --- The layout ---------------------------------------------------------------------

## The summits along a ridge through the island's most inland ground, the
## col between them, the corrie on the main summit's flank.
func _lay_out(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var points: PackedVector2Array = islet.points
	var distance: PackedFloat32Array = islet.shore_distance
	var radius: float = islet.radius
	var middle := Vector2.ZERO
	var best := -INF
	for i in range(points.size()):
		var score := distance[i]-points[i].length()*0.25
		if score > best:
			best = score
			middle = points[i]
	# The ridge: of a few ways tried, the one whose summits stand furthest in.
	var spread := radius*rng.randf_range(SPREAD.x,SPREAD.y)
	var lean := rng.randf_range(0.42,0.58)
	var turn := rng.randf()*TAU
	var best_in := -INF
	for k in range(8):
		var way := Vector2.from_angle(turn+PI*k/8.0)
		var a := middle-way*spread*lean*2.0
		var b := middle+way*spread*(1.0-lean)*2.0
		var inner := minf(islet.inland(a),islet.inland(b))
		if inner > best_in+0.5:
			best_in = inner
			axis = way
	var main := middle-axis*spread*lean*2.0
	var second := middle+axis*spread*(1.0-lean)*2.0
	# Held in from the shore: pulled toward the middle till they are, but
	# never closer together than APART of the radius.
	for k in range(12):
		if islet.inland(main) >= radius*0.3 or main.distance_to(middle) < radius*APART*lean: break
		main = main.lerp(middle,0.15)
	for k in range(12):
		if islet.inland(second) >= radius*0.3 or second.distance_to(middle) < radius*APART*(1.0-lean): break
		second = second.lerp(middle,0.15)
	centre = main
	ground = islet.ground_at(main)
	summits = [Vector3(main.x,main.y,height),Vector3(second.x,second.y,height*rng.randf_range(SECOND.x,SECOND.y))]
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	across = axis.orthogonal()*side
	if rng.randf() < THIRD_ODDS:
		var at := main.lerp(second,rng.randf_range(0.0,0.3))-across*radius*rng.randf_range(THIRD_OUT.x,THIRD_OUT.y)
		if islet.inland(at) > radius*0.3: summits.append(Vector3(at.x,at.y,height*rng.randf_range(THIRD.x,THIRD.y)))
	for s: Vector3 in summits:
		var rooms := PackedFloat32Array()
		for k in range(ROOM_ANGLES): rooms.append(_room_from(islet,Vector2(s.x,s.y),TAU*k/ROOM_ANGLES))
		_rooms.append(rooms)
		var aretes := PackedFloat32Array()
		var count := rng.randi_range(ARETES.x,ARETES.y)
		var base := rng.randf()*TAU
		for k in range(count): aretes.append(base+TAU*(k+rng.randf_range(-0.2,0.2))/count)
		_aretes.append(aretes)
	for k in range(_rooms.size()):
		var reach := rng.randf_range(REACH_SHARE.x,REACH_SHARE.y)
		var rooms: PackedFloat32Array = _rooms[k]
		for a in range(rooms.size()): rooms[a] *= reach
		_rooms[k] = rooms
	# The col: the lowest of the ridge between the two, cut to its floor.
	var lowest := INF
	var at_col := main.lerp(second,0.5)
	for k in range(1,40):
		var p := main.lerp(second,k/40.0)
		var h := maxf(_cone(0,p),_cone(1,p))
		if h < lowest:
			lowest = h
			at_col = p
	col = Vector3(at_col.x,at_col.y,minf(lowest,height*rng.randf_range(COL.x,COL.y)))
	col_half = clampf(minf(radius*COL_HALF,main.distance_to(second)*0.2),COL_HALF_M.x,COL_HALF_M.y)
	if col_want > 0.0: col_half = col_want
	for k in range(2):
		var run := absf((Vector2(summits[k].x,summits[k].y)-at_col).dot(axis))-col_half
		col_walls[k] = maxf(COL_WALL,(summits[k].z*1.08-col.z)/maxf(run,1.0))
	# The summits broadened (BROAD) once the col is found on their plain
	# cones, so a broad head never fills the pass.
	_broad.clear()
	for k in range(summits.size()):
		var mean := 0.0
		for room: float in (_rooms[k] as PackedFloat32Array): mean += room
		mean /= ROOM_ANGLES
		_broad.append(lerpf(1.0,BROAD.z,clampf((summits[k].z/maxf(mean,1.0)-BROAD.x)/(BROAD.y-BROAD.x),0.0,1.0)))
	# The corrie under the main summit, opening down the far flank from
	# the shoulder; its glen out to the shore.
	glen = (-across).rotated(rng.randf_range(-0.35,0.35)) if summits.size() < 3 else across.rotated(rng.randf_range(-0.35,0.35))
	var room := _room_from(islet,main,glen.angle())
	var c := main+glen*room*rng.randf_range(CORRIE_OUT.x,CORRIE_OUT.y)
	# Its flat floor ends short of the summit, so the headwall stands under it.
	corrie = Vector3(c.x,c.y,minf(radius*rng.randf_range(CORRIE_SIZE.x,CORRIE_SIZE.y),main.distance_to(c)/(CORRIE_FLAT+0.3)))
	corrie_floor = height*rng.randf_range(CORRIE_FLOOR.x,CORRIE_FLOOR.y)
	glen_length = _room_from(islet,c,glen.angle())+2.0
	var flat := corrie.z*CORRIE_FLAT
	corrie_wall = (height*CORRIE_WALL-corrie_floor)/pow(corrie.z-flat,1.6)
	corrie_wall = maxf(corrie_wall,(height*1.08-corrie_floor)/pow(maxf(main.distance_to(c)-flat,1.0),1.6))

## How far from `from` along `angle` the land keeps 1 m in from the shore.
func _room_from(islet: RefCounted, from: Vector2, angle: float) -> float:
	var way := Vector2.from_angle(angle)
	var r := 0.0
	while r < float(islet.reach)*2.0:
		if islet.inland(from+way*(r+1.0)) < 1.0: break
		r += 1.0
	return maxf(r,4.0)

# --- The solid ----------------------------------------------------------------------

## Summit `k`'s stepped cone at `p` (lift over the foot, m).
func _cone(k: int, p: Vector2) -> float:
	var s: Vector3 = summits[k]
	var d := p-Vector2(s.x,s.y)
	var r := d.length()
	if r < 0.001: return s.z
	var angle := d.angle()
	var rooms: PackedFloat32Array = _rooms[k]
	var t := posmod(angle,TAU)/TAU*ROOM_ANGLES
	var i := floori(t)
	var room := lerpf(rooms[i%ROOM_ANGLES],rooms[(i+1)%ROOM_ANGLES],t-i)
	var push := 0.0
	var pull := 0.0
	for a in (_aretes[k] as PackedFloat32Array):
		var off := absf(wrapf(angle-a,-PI,PI))
		push = maxf(push,exp(-pow(off/ARETE_WIDTH,2.0)))
	var reach := room*(1.0+ARETE_OUT*push-GULLY_IN*(1.0-push))
	var x := r/maxf(reach,1.0)
	if x >= 1.0: return 0.0
	return s.z*_profile(pow(x,_broad[k]) if k < _broad.size() else x)

static func _profile(x: float) -> float:
	for k in range(1,PROFILE.size()):
		var a: Array = PROFILE[k-1]
		var b: Array = PROFILE[k]
		if x <= float(b[0]): return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
	return 0.0

## The massif's lift at `p` (m over the islet's own ground): the summits'
## cones, cut by the col and the corrie and its glen, eased out at the shore.
func _field(islet: RefCounted, p: Vector2) -> float:
	var h := 0.0
	for k in range(summits.size()): h = maxf(h,_cone(k,p))
	# The col: a flat floor along the ridge, its walls rising either way.
	var along := (p-Vector2(col.x,col.y)).dot(axis)
	h = minf(h,col.z+maxf(absf(along)-col_half,0.0)*(col_walls.x if along < 0.0 else col_walls.y))
	# The corrie and its glen: a bowl, its floor falling away down the glen.
	var c := Vector2(corrie.x,corrie.y)
	var t := clampf((p-c).dot(glen)/glen_length,0.0,1.0)
	var d := p.distance_to(c+glen*t*glen_length)
	var flat := corrie.z*CORRIE_FLAT
	var floor_lift := corrie_floor*pow(1.0-t,1.3)
	h = minf(h,floor_lift+pow(maxf(d-flat,0.0),1.6)*corrie_wall*lerpf(1.0,0.55,t))
	return maxf(h,0.0)*smoothstep(0.0,SHORE_EASE,float(islet.inland(p)))

## The coarse points: the crests first (the ridge, the aretes, the glen's
## floor and the col), then a jittered lattice over the island, kept apart;
## their lifts, triangulated, bucketed for `lift_at`.
func _shape_massif(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var radius: float = islet.radius
	var spacing := clampf(radius*COARSE,COARSE_M.x,COARSE_M.y)
	var keep := spacing*0.45
	var cells := {}
	coarse = PackedVector2Array()
	coarse_lift = PackedFloat32Array()
	var add := func(p: Vector2, jitter: float) -> void:
		var key := Vector2i(floori(p.x/keep),floori(p.y/keep))
		for dx in range(-1,2):
			for dz in range(-1,2):
				var other: Variant = cells.get(key+Vector2i(dx,dz))
				if other != null and (other as Vector2).distance_to(p) < keep: return
		cells[key] = p
		coarse.append(p)
		var up := _field(islet,p)
		coarse_lift.append(maxf(up*(1.0+rng.randf_range(-jitter,jitter)),0.0))
	for s: Vector3 in summits: add.call(Vector2(s.x,s.y),0.0)
	add.call(Vector2(col.x,col.y),0.0)
	var main := Vector2(summits[0].x,summits[0].y)
	var second := Vector2(summits[1].x,summits[1].y)
	# The ridge and its ends, out past each summit. Crest points stand a
	# little either side of their line by turns (CREST_WEAVE), never in a
	# row, so the triangulation lays no slivers along it.
	var span := main.distance_to(second)
	var steps := ceili(span/(spacing*0.6))
	for k in range(-steps,steps*2+1):
		add.call(main.lerp(second,float(k)/steps)+across*_weave(k,spacing),0.0)
	# The col's floor edges, so its walls stand where they should.
	for sign in [-1.0,1.0]:
		for k in range(-3,4):
			add.call(Vector2(col.x,col.y)+axis*col_half*sign+across*k*spacing*0.7,0.0)
	# The aretes, down from each summit.
	for k in range(summits.size()):
		var s := Vector2(summits[k].x,summits[k].y)
		for a in (_aretes[k] as PackedFloat32Array):
			var r := spacing*0.8
			var n := 0
			while r < float(islet.reach):
				var p := s+Vector2.from_angle(a)*r+Vector2.from_angle(a+PI*0.5)*_weave(n,spacing)
				if not islet.on_land(p): break
				add.call(p,0.0)
				r += spacing*0.8
				n += 1
	# The glen's floor.
	var c := Vector2(corrie.x,corrie.y)
	var r := 0.0
	var n := 0
	while r < glen_length:
		add.call(c+glen*r+glen.orthogonal()*_weave(n,spacing),0.0)
		r += spacing*0.8
		n += 1
	# The lattice, over the whole grid, so the solid covers all the land.
	var half: float = islet.half
	var row := 0
	var z := -half
	while z <= half:
		var x := -half+(spacing*0.5 if row%2 == 1 else 0.0)
		while x <= half:
			var p := Vector2(x,z)+Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))*spacing*COARSE_JITTER
			add.call(p,LIFT_JITTER)
			x += spacing
		z += spacing*0.866
		row += 1
	tris = Geometry2D.triangulate_delaunay(coarse)
	_buckets.clear()
	for t in range(0,tris.size(),3):
		var box := Rect2(coarse[tris[t]],Vector2.ZERO).expand(coarse[tris[t+1]]).expand(coarse[tris[t+2]])
		for bx in range(floori(box.position.x/BUCKET),floori(box.end.x/BUCKET)+1):
			for bz in range(floori(box.position.y/BUCKET),floori(box.end.y/BUCKET)+1):
				var key := Vector2i(bx,bz)
				if not _buckets.has(key): _buckets[key] = []
				(_buckets[key] as Array).append(t)

## How far crest point `k` stands off its line (m), by turns either side.
static func _weave(k: int, spacing: float) -> float:
	return spacing*CREST_WEAVE*(1.0 if k%2 == 0 else -1.0)

# --- The hut ------------------------------------------------------------------------

## The hut under the col, on its flank away from the corrie: of spots tried
## down that flank, the flattest whose levelled pad (MountainSpire `_carve`)
## keeps clear of the col's floor and the summits; its door looking out
## down the flank. None if no spot is flat enough (HUT_SPREAD).
func _place_hut(islet: RefCounted) -> void:
	var way := across if across.dot(glen) < 0.0 else -across
	var c := Vector2(col.x,col.y)
	var clear := PAD+PAD_EASE
	var best := INF
	trail = PackedVector3Array()
	for k in range(HUT_TRIES*3):
		var at := c+way.rotated(lerpf(-0.6,0.6,(k%7)/6.0))*(clear+HUT_BELOW+float(k/7)*2.0)
		if islet.inland(at) < clear+1.0: continue
		var near := false
		for s: Vector3 in summits:
			if at.distance_to(Vector2(s.x,s.y)) < clear+4.0: near = true
		if near or absf((at-c).dot(axis)) < col_half and at.distance_to(c) < clear+col_half*0.5: continue
		var low := INF
		var high := -INF
		for j in range(9):
			var q := at if j == 8 else at+Vector2.from_angle(TAU*j/8.0)*PAD
			low = minf(low,float(islet.ground_at(q)))
			high = maxf(high,float(islet.ground_at(q)))
		if high-low < best:
			best = high-low
			hut = at
	if best > HUT_SPREAD:
		with_trail = false
		return
	hut_out = (hut-c).normalized()
	hut_y = float(islet.ground_at(hut))

# --- Its faces ----------------------------------------------------------------------

## True on a face the massif draws (rock, scree, snow, the hut's pad):
## the islet plants nothing there (SkyIslet `_ground_ok`).
func bare(f: int) -> bool:
	return f < drawn.size() and drawn[f] != 0

## Which faces the massif draws: rock over the ragged rock line or steeper
## than ROCK_SLOPE, scree in fans under it, the hut's pad; then tidied.
func _mark(islet: RefCounted) -> void:
	var ids: PackedInt32Array = islet.ids
	var land: PackedInt32Array = islet.land
	var points: PackedVector2Array = islet.points
	drawn.resize(int(ids.size()/3.0))
	drawn.fill(0)
	var fans := _noise(31,SCREE_FANS)
	for f in land:
		var a := ids[f*3]
		var b := ids[f*3+1]
		var c := ids[f*3+2]
		if cut[a] == 2 and cut[b] == 2 and cut[c] == 2:
			drawn[f] = 2
			continue
		var up := (lift[a]+lift[b]+lift[c])/3.0
		if up < DRAW_LIFT: continue
		var mid: Vector2 = (points[a]+points[b]+points[c])/3.0
		var y: float = (islet.heights[a]+islet.heights[b]+islet.heights[c])/3.0
		var slope: float = islet._slope(f)
		var rag := _raggy.get_noise_2d(mid.x,mid.y)*height*BAND_RAG
		var rockline := treeline+height*ROCKLINE+rag
		if y > rockline or slope > ROCK_SLOPE: drawn[f] = 1
		elif slope > SCREE_SLOPE and y > treeline+rag-height*0.08 and fans.get_noise_2d(mid.x,mid.y) > -0.15: drawn[f] = 3
		elif mid.distance_to(Vector2(corrie.x,corrie.y)) < corrie.z and slope > SCREE_SLOPE*0.6: drawn[f] = 3
	_tidy(islet)

## Folds lone faces into their neighbours, twice over: a green face with
## two drawn neighbours takes theirs, a drawn face among green ones (not
## steep, not snowy) turns green, a lone scree face in rock turns rock.
func _tidy(islet: RefCounted) -> void:
	var cells: int = islet.cells
	var outline: PackedByteArray = islet.outline
	for pass_index in range(2):
		var next := drawn.duplicate()
		for f in (islet.land as PackedInt32Array):
			if drawn[f] == 2: continue
			var cell := f/2
			var ci := cell%cells
			var cj := cell/cells
			var near: Array[int] = []
			if f%2 == 0:
				near = [f+1,((cj-1)*cells+ci)*2+1 if cj > 0 else -1,(cj*cells+ci-1)*2+1 if ci > 0 else -1]
			else:
				near = [f-1,(cj*cells+ci+1)*2 if ci < cells-1 else -1,((cj+1)*cells+ci)*2 if cj < cells-1 else -1]
			var rock := 0
			var scree := 0
			var green := 0
			for g in near:
				if g < 0 or outline[g] != 0: continue
				match drawn[g]:
					0: green += 1
					1: rock += 1
					3: scree += 1
			if drawn[f] == 0 and rock+scree >= 2: next[f] = 1 if rock >= scree else 3
			elif drawn[f] != 0 and green >= 2 and float(islet._slope(f)) < ROCK_SLOPE*1.3 and _face_y(islet,f) < snowline: next[f] = 0
			elif drawn[f] == 3 and rock >= 2: next[f] = 1
		drawn = next

func _face_y(islet: RefCounted, f: int) -> float:
	var ids: PackedInt32Array = islet.ids
	return (islet.heights[ids[f*3]]+islet.heights[ids[f*3+1]]+islet.heights[ids[f*3+2]])/3.0

# --- What grows ---------------------------------------------------------------------

## The conifers over the green lower slopes up to the treeline, smaller as
## they climb; boulders on the scree; the hut. As the recipe's records, each
## kept clear of the islet's own planting.
func _dress(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var recipe: Dictionary = islet.recipe
	var spec: Dictionary = recipe.get("massif",{}) if recipe.get("massif") is Dictionary else {}
	var objects: Array = recipe.get("objects",[])
	var clear: Array = recipe.get("clear",[])
	var taken: Array[Vector3] = []
	if with_trail:
		clear.append(Vector3(hut.x,hut.y,PAD+0.6))
		taken.append(Vector3(hut.x,hut.y,PAD+0.6))
	var script: Script = islet.get_script()
	var tints := {}
	var reach: float = islet.reach
	# The forest band's area, from the faces under the treeline.
	var band := 0.0
	var ids: PackedInt32Array = islet.ids
	var points: PackedVector2Array = islet.points
	for f in (islet.land as PackedInt32Array):
		if drawn[f] != 0 or _face_y(islet,f) > treeline: continue
		var a := points[ids[f*3]]
		band += absf((points[ids[f*3+1]]-a).cross(points[ids[f*3+2]]-a))*0.5
	var bounds: Vector2i = spec.get("conifers",CONIFER_COUNT)
	var want := clampi(roundi(band*CONIFERS*rng.randf_range(0.8,1.2)),bounds.x,bounds.y)
	var placed := 0
	for attempt in range(want*16):
		if placed >= want: break
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		var hit: Array = islet._locate(p)
		var f: int = hit[0]
		if f < 0 or drawn[f] != 0: continue
		if islet.inland(p) < 1.5 or islet.wet(p): continue
		var y: float = islet.ground_at(p)
		var climb := clampf((y-ground)/maxf(treeline-ground,1.0),0.0,1.2)
		if climb > 1.0+_raggy.get_noise_2d(p.x*2.0,p.y*2.0)*0.15: continue
		if float(islet._slope(f)) > CONIFER_SLOPE: continue
		# Thin out low down, toward the shore's meadow.
		if climb < 0.12 and rng.randf() < 0.6: continue
		var tree := "tree"
		var roll := rng.randf()
		if roll < CONIFER_JUNIPER: tree = "juniper"
		elif roll < CONIFER_JUNIPER+CONIFER_BIRCH and climb < 0.45: tree = "birch"
		var size := rng.randf_range(CONIFER_SIZE.x,CONIFER_SIZE.y)*lerpf(1.1,0.65,clampf(climb,0.0,1.0))
		var room := CONIFER_APART*size
		if _taken(p,taken,room*0.5): continue
		if not tints.has(tree): tints[tree] = script._tree_tint(tree,rng)
		objects.append({"asset":tree,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size,"tint":tints[tree],"inset":1.0})
		taken.append(Vector3(p.x,p.y,room*0.5))
		clear.append(Vector3(p.x,p.y,0.6))
		placed += 1
	# Boulders lying on the scree.
	var stones := rng.randi_range(STONES_ON_SCREE.x,STONES_ON_SCREE.y)
	placed = 0
	for attempt in range(stones*30):
		if placed >= stones: break
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		var hit: Array = islet._locate(p)
		var f: int = hit[0]
		if f < 0 or drawn[f] != 3 or islet.inland(p) < 1.0: continue
		var size := rng.randf_range(STONE_SIZE.x,STONE_SIZE.y)
		if _taken(p,taken,size*0.7): continue
		objects.append({"asset":BOULDER_KINDS[rng.randi()%BOULDER_KINDS.size()],"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size,"inset":0.8})
		taken.append(Vector3(p.x,p.y,size*0.7))
		placed += 1
	if with_trail:
		objects.append({"asset":"cabin","x":hut.x,"z":hut.y,"angle":atan2(hut_out.x,hut_out.y),"scale":1.0,"inset":0.4})
	recipe.objects = objects
	recipe.clear = clear

# --- The snow -----------------------------------------------------------------------

## Which drawn faces are snowed, and each one's own snow line (islet frame
## y): {face: line}. Each summit carries its own cap (CAP of its height, as
## the islet's draw puts the main one's), the line ragged over two scales
## (CAP_RAG), brought down into the hollows (gullies, the corrie: HOLLOW_SNOW)
## and a little on the crests (CREST_SNOW); snow holds on faces up to HOLD
## steep at its line and steeper toward the summit or in a hollow, and on
## ledges (LEDGE_SNOW) a little under it; never under `snow_floor`. Lone
## flakes on the rock are let go and lone rock in a snowfield filled, so it
## reads as caps and tongues, never speckle.
func _snow_faces(islet: RefCounted) -> Dictionary:
	var ids: PackedInt32Array = islet.ids
	var points: PackedVector2Array = islet.points
	var heights: PackedFloat32Array = islet.heights
	var hollows := _hollows(islet)
	var share := (snowline-ground)/maxf(height,1.0)*CAP
	var coarse_rag := _noise(73,CAP_RAG_WAVE.x)
	var fine_rag := _noise(79,CAP_RAG_WAVE.y)
	var corrie_at := Vector2(corrie.x,corrie.y)
	var lines := {}
	var steep := {}
	for f in (islet.land as PackedInt32Array):
		var kind := drawn[f] if f < drawn.size() else 0
		if kind != 1 and kind != 3: continue
		var a := ids[f*3]
		var b := ids[f*3+1]
		var c := ids[f*3+2]
		var mid: Vector2 = (points[a]+points[b]+points[c])/3.0
		var y := (heights[a]+heights[b]+heights[c])/3.0
		if y < snow_floor: continue
		var owner := 0
		var best := -INF
		for k in range(summits.size()):
			var up := _cone(k,mid)
			if up > best:
				best = up
				owner = k
		var rag := (coarse_rag.get_noise_2d(mid.x,mid.y)*0.65+fine_rag.get_noise_2d(mid.x,mid.y)*0.35)*height*CAP_RAG
		var line := ground+summits[owner].z*share+rag
		var hollow := clampf((hollows[a]+hollows[b]+hollows[c])/3.0/HOLLOW_FULL,-1.0,1.0)
		line -= maxf(hollow,0.0)*height*HOLLOW_SNOW+maxf(-hollow,0.0)*height*CREST_SNOW
		# The corrie's bowl holds its snow down toward its floor.
		if mid.distance_to(corrie_at) < corrie.z*1.15: line = minf(line,ground+corrie_floor+height*CORRIE_SNOW+rag*0.5)
		line = maxf(line,snow_floor)
		var slope: float = islet._slope(f)
		var hold := lerpf(HOLD.x,HOLD.y,clampf((y-line)/(height*0.3),0.0,1.0))+maxf(hollow,0.0)*HOLD_HOLLOW
		if (y > line and slope < hold) or (y > line-SNOW_LINGER*0.5 and slope < LEDGE_SNOW):
			lines[f] = line
		elif y > line: steep[f] = line
	# Tidied twice over, as `_tidy` does the rock: a flake with no snowy
	# neighbour goes (not on the summits' heads), a gap in the snow with two
	# snowy neighbours and not too steep fills.
	var cells: int = islet.cells
	for pass_index in range(2):
		var next := lines.duplicate()
		for f in (islet.land as PackedInt32Array):
			var white := lines.has(f)
			if not white and not steep.has(f): continue
			var cell := f/2
			var ci := cell%cells
			var cj := cell/cells
			var near: Array[int] = []
			if f%2 == 0:
				near = [f+1,((cj-1)*cells+ci)*2+1 if cj > 0 else -1,(cj*cells+ci-1)*2+1 if ci > 0 else -1]
			else:
				near = [f-1,(cj*cells+ci+1)*2 if ci < cells-1 else -1,((cj+1)*cells+ci)*2 if cj < cells-1 else -1]
			var snowy := 0
			for g in near:
				if g >= 0 and lines.has(g): snowy += 1
			if white and snowy == 0 and _face_y(islet,f) < float(lines[f])+height*0.12: next.erase(f)
			elif not white and snowy >= 2 and float(islet._slope(f)) < HOLD.y+HOLD_HOLLOW: next[f] = steep[f]
		lines = next
	return lines

## How hollow the ground lies at each grid point (m a metre, over
## HOLLOW_M): the mean of the points HOLLOW_M off each way less its own,
## over 0 in a gully or a bowl, under it on a crest.
func _hollows(islet: RefCounted) -> PackedFloat32Array:
	var heights: PackedFloat32Array = islet.heights
	var side: int = int(islet.cells)+1
	var r := maxi(roundi(HOLLOW_M/float(islet.step)),1)
	var run := r*float(islet.step)
	var out := PackedFloat32Array()
	out.resize(heights.size())
	for k in range(heights.size()):
		var i := k%side
		var j := k/side
		if i < r or j < r or i >= side-r or j >= side-r: continue
		var around := heights[k-r]+heights[k+r]+heights[k-r*side]+heights[k+r*side]
		out[k] = (around*0.25-heights[k])/run
	return out

## The massif's faces (`drawn`) as surface arrays for the peak material, as
## MountainSpire `arrays` lays them, but snowed by its own caps
## (`_snow_faces`) and its snow's lie leaned up the further (CAP_LIE), so
## the shader's flutes break only the steepest snowfields.
func arrays(islet: RefCounted, shift := Vector3.ZERO) -> Array:
	var ids: PackedInt32Array = islet.ids
	var land: PackedInt32Array = islet.land
	var patch := _noise(67,0.08)
	var snow := _snow_faces(islet) if snowy else {}
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
		var lie := n
		if kind == 2:
			tone = PATH*(1.0+0.08*patch.get_noise_2d(mid.x*3.0,mid.z*3.0))*jitter
		elif kind == 3:
			tone = (BASALT[2] as Color).lerp(PATH,0.45)*(1.0+0.1*patch.get_noise_2d(mid.x*2.0,mid.z*2.0))*jitter
		else:
			tone = _rock(mid,slope,patch)*jitter
		var nudge := rng.randf_range(-SNOW_JITTER,SNOW_JITTER)
		if snow.has(f):
			var line: float = snow[f]
			need = -(SNOW_NEED+maxf(mid.y-line,0.0)*SNOW_NEED_RISE)
			shade = _snow_pack(clampf(1.0-n.y,0.0,1.0)*0.6,nudge)
			lie = (n+Vector3.UP*CAP_LIE).normalized()
		for q: Vector3 in [a,b,c]:
			vertices.append(q+shift)
			normals.append(lie)
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

# --- Checks -------------------------------------------------------------------------

## The lowest the crest runs between the main and second summits (islet
## frame y), sampled along the ridge: the pass's floor.
func pass_floor(islet: RefCounted) -> float:
	var main := Vector2(summits[0].x,summits[0].y)
	var second := Vector2(summits[1].x,summits[1].y)
	var low := INF
	for k in range(1,60):
		var p := main.lerp(second,k/60.0)
		var top := -INF
		for j in range(-3,4): top = maxf(top,float(islet.ground_at(p+across*j*0.5)))
		low = minf(low,top)
	return low

## The summits' tops (islet frame y), main first.
func summit_tops(islet: RefCounted) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for s: Vector3 in summits:
		var top := -INF
		for k in range(9):
			var p := Vector2(s.x,s.y)+(Vector2.ZERO if k == 8 else Vector2.from_angle(TAU*k/8.0)*1.0)
			top = maxf(top,float(islet.ground_at(p)))
		out.append(top)
	return out

## What is wrong with the massif on `islet`, as sentences (`label` names it):
## too low or too high; no pass between its summits deep enough to fly
## through; a hut's pad not level.
func problems(islet: RefCounted, label: String) -> Array:
	var out: Array = []
	var tops := summit_tops(islet)
	# The grid reads a sharp summit a little low.
	if tops[0]-ground < tall.x*0.85: out.append("massif too low on %s (%.1f m)" % [label,tops[0]-ground])
	if tops[0] > tall.y+2.0: out.append("massif over its ceiling on %s (%.1f m)" % [label,tops[0]])
	var floor_y := pass_floor(islet)
	if minf(tops[0],tops[1])-floor_y < maxf(height*0.15,8.0): out.append("no pass on %s (%.1f m under the lower summit)" % [label,minf(tops[0],tops[1])-floor_y])
	if with_trail:
		var low := INF
		var high := -INF
		# Read inside the pad by a grid face, where it is wholly level.
		var inner := maxf(PAD-float(islet.step)*1.2,0.8)
		for k in range(9):
			var q := hut if k == 8 else hut+Vector2.from_angle(TAU*k/8.0)*inner
			low = minf(low,float(islet.ground_at(q)))
			high = maxf(high,float(islet.ground_at(q)))
		if high-low > 0.3: out.append("hut pad not level on %s (%.2f m)" % [label,high-low])
	return out

# --- Standing it --------------------------------------------------------------------

## Stands the massif's faces (`arrays`, made on a worker) under its islet's
## `node` (a child of the islets, SkyIslets `stand`), laid `shift` back as
## the islet's top is, in the floating mountain's peak material (scripts/
## cluster_mountain.gd `_peak`: the basalt ring's, its snow by the seasons);
## and the hut's window, a warm pane and a halo seen from far over the
## water, lit with the clusters' night (scripts/cluster_dresser.gd: its
## shared glow and halo, `set_night`). Loaded here, not preloaded: they
## preload the islets, which preload this.
static func stand(node: Node3D, arrays: Array, shape: RefCounted, shift: Vector3) -> void:
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): return
	var mountain: Script = load("res://scripts/cluster_mountain.gd")
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,mountain._peak(node.get_parent()))
	var faces := MeshInstance3D.new()
	faces.name = "Massif"
	faces.mesh = mesh
	faces.position = shift
	faces.set_meta("skip_reflection",true)
	node.add_child(faces)
	var massif: RefCounted = shape.spire
	if not massif.with_trail: return
	var dresser: Script = load("res://scripts/cluster_dresser.gd")
	var cabin: Script = load("res://scripts/cabin.gd")
	var m: Dictionary = dresser._mats()
	var out: Vector2 = massif.hut_out
	var at: Vector2 = massif.hut
	var pose := Transform3D(Basis(Vector3.UP,atan2(out.x,out.y)),Vector3(at.x,shape.ground_at(at),at.y))
	var pane: AABB = cabin.info().pane
	var glow := MeshInstance3D.new()
	glow.name = "HutWindow"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	glow.mesh = cube
	glow.material_override = m.glow
	glow.transform = pose*Transform3D(Basis.from_scale(pane.size+Vector3(0.006,0.0,0.0)),pane.get_center()+Vector3(0.003,0.0,0.0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glow)
	var halo := MultiMeshInstance3D.new()
	halo.name = "HutHalo"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = m.quad
	multi.instance_count = 1
	multi.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*HUT_HALO.x),pose*(pane.get_center()+Vector3(0.6,0.3,0.0))))
	multi.set_instance_color(0,Color(dresser.HALO_WARM,HUT_HALO.y))
	halo.multimesh = multi
	halo.material_override = m.halo
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(halo)
