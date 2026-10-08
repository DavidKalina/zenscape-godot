extends RefCounted
## Rolling downs laid over an island (scripts/sky_islet.gd, a recipe's
## `downs`): the hills landform (scripts/landform_hills.gd), 30 to 90 m
## across, seen first from a plane flying low over it. Static; the islet
## calls `shape` once its outline and its kind's ground are laid (before
## the erosion), `plant` from its planting, and `tone` for each grass face
## of its top.
##
## The ground (`shape`), as heights over the rim:
##   the downs: a few long swells (RIDGES), each a capsule round a short
##     spine with a soft bell for a profile, joined by a smooth maximum so
##     they meet in saddles rather than heaping up; warped by a low noise so
##     no spine runs straight, and rolled by noise at three scales;
##   the coast: a low noise round the land (COAST) marks stretches of cliff
##     and stretches of beach. Along a beach the downs ease down to the shore
##     over a long run; along a cliff the land keeps its height, at least a
##     cliff's (CLIFF), to the islet's own short rim ease, so it breaks off
##     in a rock face (the palette's rock past its rock slope);
##   the glen and its cove: most islands have a glen winding down from the
##     hills to a cove, the shore point most bayed in among the beaches, its
##     floor falling gently to a beach at its mouth;
##   tors: a few knuckles of rock on the high shoulders, steep enough to
##     read as rock, boulders round them.
## What grows (`plant`): a lone tree or a small copse on a crest, flower
## drifts in the hollows (the ground washed in their colour under them, so
## a drift still reads from the air past the flowers' range), ferns and
## bank grass down the glen, boulders round the tors.
## The colour (`tone`), all of the downs' ground: the large-scale shading
## over the palette's greens: broad lighter and darker sweeps, slopes
## facing one way warmer and those facing away lusher (ASPECT),
## crests lighter and a little sun bleached, hollows richer and darker,
## bracken-russet patches on the steeper slopes, and the drifts' wash; the
## palette's rock on the sea cliffs and the tors (not on an inland bank,
## which stays a darker green), sand and shingle on the beaches and the
## cove.
## Its plan lives on the islet as meta "downs" (`plan`).

const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Emergence = preload("res://scripts/emergence.gd")

## The downs: how many swells, a spine's half length and the bell's width
## (shares of the radius), a swell's height (share of the recipe's `rise`),
## the smooth maximum's softness (share of the rise), and the warp (share
## of the radius, at 1/m over the radius).
const RIDGES := Vector2i(2,4)
const SPINE := Vector2(0.15,0.55)
const WIDTH := Vector2(0.55,0.9)
const SWELL := Vector2(0.55,1.0)
const SOFT := 0.35
const WARP := Vector2(0.18,1.3)
## The roll: a low wave (share of the rise, waves over the radius), a
## middle swell and a ripple (m, 1/m).
const ROLL := Vector2(0.16,1.6)
const MIDDLE := Vector2(0.3,0.06)
const RIPPLE := Vector2(0.05,0.2)
## The coast: the noise's waves over the radius; along a beach the downs
## ease to the shore over BEACH of the radius (at least BEACH_LEAST m); a
## cliff stands at least CLIFF.x m plus CLIFF.y of the rise. Sand reaches
## SAND m in from a beach's shore (more in the cove), on ground lower than
## SAND_RISE m over the rim.
const COAST := 1.0
const BEACH := 0.4
const BEACH_LEAST := 6.0
const CLIFF := Vector2(1.6,0.3)
const SAND := 2.6
const SAND_RISE := 0.7
## The glen: its odds, half width (share of the radius), how far in it
## reaches (share of the most inland), its floor at the head (share of the
## rise), the cove's reach (share of the radius) where cliffs give way.
const GLEN_ODDS := 0.75
const GLEN_WIDTH := Vector2(0.24,0.34)
const GLEN_REACH := Vector2(0.55,0.85)
const GLEN_HEAD := 0.35
const COVE := 0.45
## Tors: radius (m), height (m), how high on the land they stand (share of
## the highest), boulders round each.
const TOR_RADIUS := Vector2(1.6,3.4)
const TOR_HEIGHT := Vector2(1.3,2.8)
const TOR_HIGH := 0.45
const TOR_STONES := Vector2i(2,5)
## Trees on a crest: the species, a lone tree's height (m), a copse's
## trees' heights and spread (m).
const TREE_POOL := {"tree":1.0,"broadleaf":0.75,"birch":0.6,"juniper":0.35}
const LONE := Vector2(7.0,10.0)
const COPSE := Vector2(5.5,8.5)
const COPSE_SPREAD := Vector2(3.0,5.5)
## Each species' drawn height at record scale 1 (m), as Woodland HEIGHT.
const HEIGHT := {"tree":4.4,"birch":3.4,"juniper":1.6,"broadleaf":3.0}
## Flower drifts: flowers a drift, its spread (m), the least gap between
## drifts (m), and the wash under it (its strength at the heart).
const DRIFT := Vector2i(30,70)
const DRIFT_SPREAD := Vector2(1.6,3.2)
const DRIFT_GAP := 7.0
const WASH := 0.4
## The hollows: heights are measured against their mean over HOLLOW m;
## HOLLOW_FULL m under it is a full hollow, as far over it a full crest.
const HOLLOW := 6.0
const HOLLOW_FULL := 0.7
## The colour: broad sweeps' waves (1/m), bracken's patches (1/m), and
## how strongly each leans the green.
const SWEEP := 0.03
const BRACKEN := 0.09
const CREST_LIGHT := 0.4
const CREST_DRY := 0.3
const HOLLOW_DARK := 0.45
const BRACKEN_LEAN := 0.22
## The aspect: slopes facing ASPECT_WAY (the drier side, the same on every
## island) lean this much to the dry tone, those facing away to the lush.
const ASPECT := 0.28
const ASPECT_WAY := Vector2(-0.6,0.8)
## Rock shows on faces steeper than the palette's rock slope this close to
## the shore (m): the sea cliffs.
const CLIFF_BAND := 4.0

# --- The ground -------------------------------------------------------------------

## Lays the downs over `islet`'s land: replaces its heights (`inland` its
## most inland ground, m), and keeps the plan as meta "downs".
static func shape(islet: RefCounted, rng: RandomNumberGenerator, inland: float) -> void:
	var spec: Dictionary = islet.recipe.downs
	var r: float = islet.radius
	var seed_value: int = islet.seed
	var rise := float(spec.get("rise",r*0.2))
	var points: PackedVector2Array = islet.points
	var shore: PackedFloat32Array = islet.shore_distance
	var rim: float = islet.RIM_HEIGHT
	# The swells.
	var ridges: Array = []
	var count: Vector2i = spec.get("ridges",RIDGES)
	for k in range(rng.randi_range(count.x,count.y)):
		var middle: Vector2 = islet._inland_point(rng,inland*(0.45 if k == 0 else 0.25))
		var way := Vector2.from_angle(rng.randf()*TAU)*r*rng.randf_range(SPINE.x,SPINE.y)
		ridges.append({"a":middle-way,"b":middle+way,"width":r*rng.randf_range(WIDTH.x,WIDTH.y),
			"height":rise*(1.0 if k == 0 else rng.randf_range(SWELL.x,SWELL.y))})
	var warp := _noise(seed_value+101,WARP.y/r,2)
	var roll := _noise(seed_value+103,ROLL.y/r,2)
	var middle_noise := _noise(seed_value+107,MIDDLE.y,2)
	var ripple := _noise(seed_value+109,RIPPLE.y,2)
	var coast := _noise(seed_value+113,COAST/r,1)
	var cliffs := float(spec.get("cliffs",0.4))
	# The cove: the shore point most bayed in, among the gentler shore.
	var plan := {"rise":rise,"ridges":ridges,"tors":[],"glen":PackedVector2Array(),"cove":Vector2.INF,"drifts":[]}
	var edges: PackedInt32Array = islet.shore_edges
	if rng.randf() < float(spec.get("glen",GLEN_ODDS)) and edges.size() > 0:
		var best := INF
		var cove := Vector2.ZERO
		for k in range(0,edges.size(),3):
			var p := points[edges[k]]
			var score := p.length()/r+_cliffy(coast,p,cliffs)*0.8+rng.randf()*0.25
			if score < best:
				best = score
				cove = p
		plan.cove = cove
		var head: Vector2 = islet._inland_point(rng,inland*rng.randf_range(GLEN_REACH.x,GLEN_REACH.y))
		var path := PackedVector2Array()
		var across := (head-cove).orthogonal().normalized()
		var bends := rng.randf_range(1.0,2.2)
		var sway := cove.distance_to(head)*rng.randf_range(0.08,0.16)
		var phase := rng.randf()*TAU
		for i in range(25):
			var t := i/24.0
			path.append(cove.lerp(head,t)+across*sin(t*PI*bends+phase)*sway*sin(t*PI))
		plan.glen = path
		plan.glen_width = r*rng.randf_range(GLEN_WIDTH.x,GLEN_WIDTH.y)
	var lip := _noise(seed_value+43,islet.LIP_WAVE,5)
	var ease := minf(islet.RIM_EASE,r*islet.RIM_EASE_SHARE)
	var cliff := CLIFF.x+CLIFF.y*rise
	var heights: PackedFloat32Array = islet.heights
	var cliffiness := PackedFloat32Array()
	cliffiness.resize(points.size())
	for i in range(points.size()):
		var d := shore[i]
		if d < 0.0: continue
		var p := points[i]
		var q := p+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.x+311.0,p.y-173.0))*r*WARP.x
		var h := 0.0
		for ridge: Dictionary in ridges:
			var s := _segment_distance(q,ridge.a,ridge.b)/float(ridge.width)
			h = _smooth_max(h,float(ridge.height)*exp(-s*s*2.2),rise*SOFT)
		h += roll.get_noise_2d(p.x,p.y)*rise*ROLL.x+middle_noise.get_noise_2d(p.x,p.y)*MIDDLE.x+ripple.get_noise_2d(p.x,p.y)*RIPPLE.x
		h = maxf(h,0.15)
		var c := _cliffy(coast,p,cliffs)
		if plan.cove != Vector2.INF: c *= smoothstep(r*COVE*0.5,r*COVE,p.distance_to(plan.cove))
		cliffiness[i] = c
		var run := maxf(r*BEACH,BEACH_LEAST)
		var beach := smoothstep(0.0,run,d)
		h = lerpf(h*beach,_smooth_max(h,cliff*(1.0-smoothstep(run*0.4,run,d)),1.0),c)
		# The glen: the ground pulled down to its floor, falling to the cove.
		if not (plan.glen as PackedVector2Array).is_empty():
			var at := _path_distance(p,plan.glen)
			var s: float = at.x/float(plan.glen_width)
			if s < 1.0:
				var floor_h := lerpf(0.12,rise*GLEN_HEAD,at.y)
				var valley := floor_h+rise*0.5*s*s
				h = minf(h,lerpf(valley,h,smoothstep(0.3,1.0,s)))
		heights[i] = lerpf(islet._rim_at(p,lip),rim+0.06+h,smoothstep(0.0,ease,d))
	plan.cliffiness = cliffiness
	# The tors: on the high shoulders, clear of the glen.
	var highest := 0.0
	for i in range(points.size()):
		if shore[i] >= 0.0: highest = maxf(highest,heights[i]-rim)
	var tors: Array = []
	var tor_count: Vector2i = spec.get("tors",Vector2i(1,3))
	var rough := _noise(seed_value+127,0.6,2)
	rough.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for k in range(rng.randi_range(tor_count.x,tor_count.y)):
		for attempt in range(30):
			var i := rng.randi_range(0,points.size()-1)
			if shore[i] < 4.0 or heights[i]-rim < highest*TOR_HIGH: continue
			var p := points[i]
			if not (plan.glen as PackedVector2Array).is_empty() and _path_distance(p,plan.glen).x < float(plan.glen_width)*1.3: continue
			var clear := true
			for t: Vector4 in tors: clear = clear and p.distance_to(Vector2(t.x,t.y)) > t.z+8.0
			if not clear: continue
			tors.append(Vector4(p.x,p.y,rng.randf_range(TOR_RADIUS.x,TOR_RADIUS.y),rng.randf_range(TOR_HEIGHT.x,TOR_HEIGHT.y)))
			break
	for i in range(points.size()):
		if shore[i] < 0.0: continue
		for t: Vector4 in tors:
			var s := points[i].distance_to(Vector2(t.x,t.y))/t.z
			# A knuckle: steep sides, a rough rounded top.
			if s < 1.0: heights[i] += t.w*smoothstep(1.0,0.45,s)*(0.75+0.5*(rough.get_noise_2d(points[i].x,points[i].y)*0.5+0.5))
	plan.tors = tors
	islet.set_meta("downs",plan)

## How much of a cliff the coast near `p` is, 0 to 1, more of it with more
## `cliffs` (0 to 1).
static func _cliffy(coast: FastNoiseLite, p: Vector2, cliffs: float) -> float:
	return smoothstep(-0.25,0.35,coast.get_noise_2d(p.x,p.y)+(cliffs-0.5)*1.1)

static func _noise(seed_value: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n

## A polynomial smooth maximum of `a` and `b`, softened over `k`.
static func _smooth_max(a: float, b: float, k: float) -> float:
	var t := clampf(0.5+0.5*(b-a)/k,0.0,1.0)
	return lerpf(a,b,t)+k*t*(1.0-t)

static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
	return p.distance_to(a+ab*t)

## The distance from `p` to a polyline, and how far along it (0 to 1) the
## nearest point lies.
static func _path_distance(p: Vector2, path: PackedVector2Array) -> Vector2:
	var best := INF
	var along := 0.0
	for k in range(path.size()-1):
		var a := path[k]
		var ab := path[k+1]-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
		var d := p.distance_to(a+ab*t)
		if d < best:
			best = d
			along = (k+t)/float(path.size()-1)
	return Vector2(best,along)

# --- What grows --------------------------------------------------------------------

## Plants the downs onto `islet` (after its stones, before its tufts and
## undergrowth), clear of `taken`, which it adds its trunks and boulders to.
static func plant(islet: RefCounted, rng: RandomNumberGenerator, taken: Array[Vector3]) -> void:
	var plan: Dictionary = islet.get_meta("downs",{})
	if plan.is_empty(): return
	var spec: Dictionary = islet.recipe.downs
	var points: PackedVector2Array = islet.points
	var shore: PackedFloat32Array = islet.shore_distance
	var heights: PackedFloat32Array = islet.heights
	var rim: float = islet.RIM_HEIGHT
	plan.hollow = _hollows(islet)
	var hollow: PackedFloat32Array = plan.hollow
	# Boulders round the tors.
	for t: Vector4 in plan.tors:
		for n in range(rng.randi_range(TOR_STONES.x,TOR_STONES.y)):
			var p := Vector2(t.x,t.y)+Vector2.from_angle(rng.randf()*TAU)*t.z*rng.randf_range(0.7,1.5)
			if not islet.on_land(p) or islet.inland(p) < 0.6 or islet._near(p,taken,0.3): continue
			var size := rng.randf_range(0.5,1.4)
			islet.add_record(islet.BOULDERS[rng.randi() % islet.BOULDERS.size()],p,rng.randf()*TAU,size)
			taken.append(Vector3(p.x,p.y,size*0.6))
		taken.append(Vector3(t.x,t.y,t.z*0.8))
	# A lone tree or a copse on a crest: the highest, most rounded ground.
	var crests := []
	for i in range(points.size()):
		if shore[i] < 3.0: continue
		crests.append([heights[i]-rim-hollow[i]*2.0,i])
	crests.sort()
	crests.reverse()
	var copse := int(spec.get("copse",0))
	if not crests.is_empty():
		var pick: int = crests[rng.randi_range(0,mini(crests.size()-1,maxi(crests.size()/12,1)))][1]
		var crest := points[pick]
		var pool: Dictionary = spec.get("tree_pool",TREE_POOL)
		var tree := _weighted(pool,rng.randf())
		var tint: String = islet._tree_tint(tree,rng)
		var trees := maxi(copse,1)
		var spread := rng.randf_range(COPSE_SPREAD.x,COPSE_SPREAD.y)
		var stood := 0
		for n in range(trees*4):
			if stood >= trees: break
			var p := crest if n == 0 else crest+Vector2(rng.randfn(0.0,spread),rng.randfn(0.0,spread))
			var height := rng.randf_range(LONE.x,LONE.y) if trees == 1 else rng.randf_range(COPSE.x,COPSE.y)
			# A copse's odd tree is a companion.
			var kind := tree if n == 0 or rng.randf() < 0.75 else _weighted(pool,rng.randf())
			var size := height/float(HEIGHT.get(kind,4.0))
			var room := height*0.22
			if not islet._ground_ok(p,1.0,islet.TREE_STEEP,true) or islet._near(p,taken,room): continue
			islet.add_record(kind,p,rng.randf()*TAU,size,tint if kind == tree else islet._tree_tint(kind,rng))
			taken.append(Vector3(p.x,p.y,room))
			stood += 1
			if not kind in islet.species: islet.species.append(kind)
		plan.crest = crest
	# Flower drifts in the hollows.
	var kinds: Array = spec.get("flowers",["buttercup","oxeye_daisy"])
	var hollows := []
	for i in range(points.size()):
		if shore[i] < 2.0 or hollow[i] < HOLLOW_FULL*0.25 or islet.wet(points[i]): continue
		hollows.append([hollow[i]+rng.randf()*0.3,i])
	hollows.sort()
	hollows.reverse()
	var drifts: Array = []
	var want := int(spec.get("drifts",4))
	for entry: Array in hollows:
		if drifts.size() >= want: break
		var middle := points[int(entry[1])]
		var apart := true
		for d: Dictionary in drifts: apart = apart and middle.distance_to(d.at) > DRIFT_GAP
		if not apart: continue
		var flower: String = kinds[drifts.size() % kinds.size()]
		var variant := rng.randf()
		var tint := MeadowTypes.tint(flower,variant)
		var spread := rng.randf_range(DRIFT_SPREAD.x,DRIFT_SPREAD.y)
		var placed := 0
		var count := rng.randi_range(DRIFT.x,DRIFT.y)
		for n in range(count*3):
			if placed >= count: break
			var p := middle+Vector2(rng.randfn(0.0,spread),rng.randfn(0.0,spread))
			if not islet._ground_ok(p,0.4,islet.TREE_STEEP,true) or islet._near(p,taken,0.0): continue
			islet.add_record(flower,p,rng.randf()*TAU,rng.randf_range(0.8,1.15),tint)
			placed += 1
		if placed == 0: continue
		if not flower in islet.flowers: islet.flowers.append(flower)
		drifts.append({"at":middle,"reach":spread*2.3,"wash":Color(MeadowTypes.wash_of(flower,variant)).srgb_to_linear()})
	plan.drifts = drifts
	# Down the glen: bank grass and ferns along its floor, reeds at its mouth.
	var glen: PackedVector2Array = plan.glen
	if not glen.is_empty():
		for n in range(rng.randi_range(14,26)):
			var t := rng.randf()
			var k := mini(int(t*(glen.size()-1)),glen.size()-2)
			var p := glen[k].lerp(glen[k+1],t*(glen.size()-1)-k)+Vector2(rng.randfn(0.0,1.0),rng.randfn(0.0,1.0))*float(plan.glen_width)*0.25
			if not islet._ground_ok(p,0.5,islet.TREE_STEEP,true) or islet._near(p,taken,0.2): continue
			var asset := "fern" if t > 0.35 and rng.randf() < 0.5 else ("reeds" if t < 0.2 else "bank_grass")
			islet.add_record(asset,p,rng.randf()*TAU,rng.randf_range(0.6,1.0))

## Each land point's hollowness (m): the mean of the land's heights within
## HOLLOW m (a box on the grid) less its own; under 0 on a crest.
static func _hollows(islet: RefCounted) -> PackedFloat32Array:
	var points: PackedVector2Array = islet.points
	var shore: PackedFloat32Array = islet.shore_distance
	var heights: PackedFloat32Array = islet.heights
	var side: int = islet.cells+1
	var k := maxi(roundi(HOLLOW/float(islet.step)),1)
	var sum := PackedFloat32Array()
	var weight := PackedFloat32Array()
	sum.resize(points.size())
	weight.resize(points.size())
	for i in range(points.size()):
		if shore[i] >= 0.0:
			sum[i] = heights[i]
			weight[i] = 1.0
	# A running box along the rows, then along the columns.
	for pass_x in [true,false]:
		var s2 := PackedFloat32Array()
		var w2 := PackedFloat32Array()
		s2.resize(points.size())
		w2.resize(points.size())
		var along := 1 if pass_x else side
		var across := side if pass_x else 1
		for line in range(side):
			var first: int = line*across
			var a := 0.0
			var b := 0.0
			for o in range(mini(k,side-1)+1):
				a += sum[first+o*along]
				b += weight[first+o*along]
			for m in range(side):
				var at: int = first+m*along
				s2[at] = a
				w2[at] = b
				if m+k+1 < side:
					a += sum[first+(m+k+1)*along]
					b += weight[first+(m+k+1)*along]
				if m-k >= 0:
					a -= sum[first+(m-k)*along]
					b -= weight[first+(m-k)*along]
		sum = s2
		weight = w2
	var out := PackedFloat32Array()
	out.resize(points.size())
	for i in range(points.size()):
		if shore[i] >= 0.0 and weight[i] > 0.0: out[i] = sum[i]/weight[i]-heights[i]
	return out

static func _weighted(pool: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in pool: total += float(pool[k])
	roll *= total
	for k in pool:
		roll -= float(pool[k])
		if roll <= 0.0: return k
	return pool.keys()[0]

# --- The colour --------------------------------------------------------------------

## The ground colour (linear) of land face `f` of `islet`, its middle `at`
## and its slope `slope`, from `palette` (SkyIslet `top_arrays`'): the
## downs' shading over the greens, the beaches' sand, the cliffs' and tors'
## rock. The islet's shimmer goes over it.
static func tone(islet: RefCounted, f: int, at: Vector2, slope: float, palette: Dictionary) -> Color:
	var plan: Dictionary = islet.get_meta("downs",{})
	var grass: Array = palette.grass
	if plan.is_empty() or grass.size() < 3: return grass[0]
	if not plan.has("noise"):
		plan.noise = [_noise(int(islet.seed)+131,SWEEP,3),_noise(int(islet.seed)+137,BRACKEN,2),_noise(int(islet.seed)+139,0.45,1)]
	var sweep: FastNoiseLite = plan.noise[0]
	var bracken: FastNoiseLite = plan.noise[1]
	var fine: FastNoiseLite = plan.noise[2]
	var ids: PackedInt32Array = islet.ids
	var heights: PackedFloat32Array = islet.heights
	var shore: PackedFloat32Array = islet.shore_distance
	var a := ids[f*3]
	var b := ids[f*3+1]
	var c := ids[f*3+2]
	var h := (heights[a]+heights[b]+heights[c])/3.0-float(islet.RIM_HEIGHT)
	var edge := (shore[a]+shore[b]+shore[c])/3.0
	var rise := maxf(float(plan.rise),1.0)
	var hollow := 0.0
	if plan.has("hollow"):
		var hl: PackedFloat32Array = plan.hollow
		hollow = (hl[a]+hl[b]+hl[c])/3.0
	var cliffy := 0.0
	if plan.has("cliffiness"):
		var cl: PackedFloat32Array = plan.cliffiness
		cliffy = (cl[a]+cl[b]+cl[c])/3.0
	var sand: Color = palette.sand
	var gravel: Color = palette.gravel
	var rock: Array = palette.rock
	# The tors' rock, and the cliffs' along the shore.
	var rocky: Color = rock[0 if fine.get_noise_2d(at.x,at.y) > 0.0 else rock.size()-1]
	for t: Vector4 in plan.tors:
		if at.distance_to(Vector2(t.x,t.y)) < t.z*0.75 and slope > 0.35: return rocky
	var rock_slope: float = palette.rock_slope
	if slope > rock_slope and edge < CLIFF_BAND: return rocky
	if slope > rock_slope*0.75 and edge < 0.6: return gravel.lerp(rocky,0.5)
	# The beaches, wider in the cove.
	var cove: Vector2 = plan.cove
	var in_cove := 0.0 if cove == Vector2.INF else 1.0-smoothstep(float(islet.radius)*0.15,float(islet.radius)*COVE,at.distance_to(cove))
	var sand_reach := clampf(float(islet.radius)*0.08,1.2,SAND)*(1.0-smoothstep(0.15,0.5,cliffy))*(1.0+in_cove*1.6)*(0.75+0.5*(fine.get_noise_2d(at.x,at.y)*0.5+0.5))
	if edge < sand_reach and h < SAND_RISE*(1.0+in_cove) and slope < 0.45:
		return gravel.lerp(sand,0.35) if fine.get_noise_2d(at.x*2.0,at.y*2.0) > 0.3 else sand
	# The greens: broad sweeps from dark to light.
	var n := sweep.get_noise_2d(at.x,at.y)*0.5+0.5
	var tone: Color = (grass[2] as Color).lerp(grass[0],smoothstep(0.15,0.5,n)).lerp(grass[1],smoothstep(0.6,0.9,n)*0.5)
	# Crests lighter and a little bleached, the higher the more; hollows rich.
	var crest := clampf(-hollow/HOLLOW_FULL,0.0,1.0)
	var high := clampf(h/rise,0.0,1.0)
	var dry := (grass[1] as Color).lerp(sand,0.5)
	tone = tone.lerp(grass[1],crest*CREST_LIGHT).lerp(dry,crest*high*CREST_DRY)
	var deep := clampf(hollow/HOLLOW_FULL,0.0,1.0)
	tone = tone.lerp((grass[2] as Color)*0.82,deep*HOLLOW_DARK)
	# Bracken on the steeper slopes, in patches.
	var earth: Color = palette.get("earth",Color("6a503e").srgb_to_linear())
	var russet := earth.lerp(sand,0.35).lerp(Color(0.36,0.17,0.05),0.2)
	var patch := smoothstep(0.2,0.5,bracken.get_noise_2d(at.x,at.y))*smoothstep(0.3,0.6,slope)
	tone = tone.lerp(russet,patch*BRACKEN_LEAN)
	# One side of the hills drier, the other lusher; a steep inland bank
	# darker.
	var normal: Vector3 = islet._face_normal(f)
	var facing := Vector2(normal.x,normal.z).dot(ASPECT_WAY)/maxf(Vector2(normal.x,normal.z).length(),0.001)*clampf(slope*2.5,0.0,1.0)
	tone = tone.lerp(dry,maxf(facing,0.0)*ASPECT) if facing > 0.0 else tone.lerp((grass[2] as Color)*0.9,-facing*ASPECT)
	if slope > rock_slope: tone = tone.lerp((grass[2] as Color)*0.85,0.25)
	# The drifts' wash.
	for d: Dictionary in plan.drifts:
		var w := 1.0-smoothstep(float(d.reach)*0.35,float(d.reach),at.distance_to(d.at))
		if w > 0.0: tone = tone.lerp(d.wash,w*WASH*(0.7+0.3*fine.get_noise_2d(at.x*3.0,at.y*3.0)))
	return tone
