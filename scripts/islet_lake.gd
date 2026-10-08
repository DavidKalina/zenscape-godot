extends RefCounted
## A lake on a sky islet (scripts/sky_islet.gd, a recipe's `lake`): a wide
## bowl taking most of the islet, its own water level, the lake motif's
## lead (scripts/cluster_motifs.gd "lake"). The islet keeps it in `lake`
## and its level in `water_level`; its own `wet`, `top_arrays`,
## `water_arrays` and planting ask here when it has one.
##
## The bowl follows the islet's outline: the water lies where the land is
## more than a bank's width in from the shore (BANK, wandering round it,
## so the lake has coves and the bank wide meadows and narrow necks), so
## its shore is as lobed as the islet's. In from the waterline:
##   the bank eases down to just over the water over BEACH m, a pale beach;
##   a shallow shelf (SHELF wide, SHELF_DEPTH under the water) the reeds
##     stand in and the lilies float over, turquoise under the depth tint;
##   then the bowl drops away to DEPTH, the deep water slate blue;
##   and maybe a small isle (ISLE) rising out of the deep, a tree on it.
## Everywhere else the land stands at least LAND_OVER over the water, so
## the only way out is the spill: a channel (SkyIslet CHANNEL) cut from
## the nearest water to a lip on the rim, where the lake pours off as a
## fall (`spill`, laid by the cluster solver toward open sky, or at once if
## the recipe gives `toward`).
##
## Water is read from the ground itself (under the level is wet); a coarse
## field of distance to the water (FIELD m a cell) answers "near the
## water" fast for the spot finder and the planting.
##
## The recipe's lake: {bank: Vector2 (m), shelf: Vector2 (m), depth:
## Vector2 (m), level: Vector2 (m over Genesis RIM_HEIGHT), isle: odds,
## toward: Vector2 (spill now, that way)}; each optional. A big lake (the
## lower world's, scripts/landform_lake.gd) may also give: copses:
## Vector2i, stands of trees round it (COPSE) from copse_pool (else the
## recipe's tree_pool); beach: how far up from the waterline the bank
## eases (m, BEACH); isle_radius:
## Vector2 (m); channel: the spill channel's half width (m) and fall: its
## fall's (m), for a wide curtain; reeds: a multiplier on the reeds and
## bank grass; tea: true to steep the water by what grows round it
## (`steep`), or the most it may steep (0 to 1).

const Genesis = preload("res://scripts/genesis_canvas.gd")
const IslandShore = preload("res://scripts/island_shore.gd")
const LakeTea = preload("res://scripts/lake_tea.gd")
const Emergence = preload("res://scripts/emergence.gd")

## The bank's width in from the shore (m, wandering over BANK_WAVE 1/m),
## and the beach: how far up from the waterline the bank eases (m), how
## high over the water it leaves the land at least (m).
const BANK := Vector2(2.6,4.8)
const BANK_WAVE := 0.09
const BEACH := 2.0
const BEACH_TOP := 0.28
const LAND_OVER := 0.1
## The waterline: the ground there stands this much over the water (m).
const EDGE := 0.03
## The shelf: its width (m), its depth under the water (m), and the drop
## from its outer edge to the deep (m).
const SHELF := Vector2(1.2,2.8)
const SHELF_DEPTH := 0.22
const DROP := 2.4
## The deep bowl's depth under the water (m), and its bed's swell (m).
const DEPTH := Vector2(2.6,3.6)
const BED_SWELL := 0.14
## The water's level over Genesis RIM_HEIGHT (m).
const LEVEL := Vector2(-0.1,0.08)
## The isle: the odds of one, its radius (m), its top over the water (m),
## and how far in from the waterline its middle must be (m, past its radius).
const ISLE := 0.5
const ISLE_RADIUS := Vector2(1.5,2.3)
const ISLE_TOP := 0.55
const ISLE_IN := 2.5
## The field of distance to the water: its cell (m).
const FIELD := 0.5
## Reeds: clumps along the shallows, reeds a clump and its spread (m);
## bank grass along the waterline.
const REED_CLUMPS := Vector2i(6,11)
const REED_CLUMP := Vector2i(4,9)
const REED_SPREAD := 0.45
const BANK_GRASS := Vector2i(10,18)
## Copses (a recipe's `copses`): stands of one species round the lake, each
## COPSE trees, spread COPSE_SPREAD m, its middle this far from the water
## (m), the trees kept COPSE_APART m apart (times their record scale).
const COPSE := Vector2i(3,7)
const COPSE_SPREAD := 2.2
const COPSE_WATER := Vector2(1.5,9.0)
const COPSE_APART := 1.6
## The fetch (open water upwind) is read this far at most (m).
const FETCH := 9.0
## The bed's colours: the beach sand, the shelf's weed-dark sand (WEED of
## the way to WEEDY) darkening to silt in the deep.
const SILT := Color(0.11,0.12,0.09)
const WEEDY := Color(0.24,0.27,0.16)
const WEED := 0.4
## The fall off the spill: its half width (m).
const FALL_HALF := 0.72

## Shapes the lake into `islet`'s ground (after the erosion): the bank,
## the shelf, the bowl, the isle, the land over the water all round, and
## its field; spilled at once if the recipe says which way.
static func cut(islet: RefCounted, rng: RandomNumberGenerator, inland: float) -> void:
	var spec: Dictionary = islet.recipe.get("lake",{})
	var bank: Vector2 = spec.get("bank",BANK)
	var shelf_range: Vector2 = spec.get("shelf",SHELF)
	var depth_range: Vector2 = spec.get("depth",DEPTH)
	var level_range: Vector2 = spec.get("level",LEVEL)
	var level: float = Genesis.RIM_HEIGHT+rng.randf_range(level_range.x,level_range.y)
	var shelf := rng.randf_range(shelf_range.x,shelf_range.y)
	var depth := rng.randf_range(depth_range.x,depth_range.y)
	var beach := float(spec.get("beach",BEACH))
	islet.water_level = level
	var wander := FastNoiseLite.new()
	wander.seed = islet.seed+71
	wander.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wander.frequency = BANK_WAVE
	var swell := FastNoiseLite.new()
	swell.seed = islet.seed+73
	swell.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	swell.frequency = 0.22
	# The bank never leaves less than a share of the islet as water.
	var widest := minf(bank.y,inland*0.45)
	var narrowest := minf(bank.x,widest)
	var points: PackedVector2Array = islet.points
	var into := PackedFloat32Array()
	into.resize(points.size())
	var deepest := -INF
	var deep_at := Vector2.ZERO
	for i in range(points.size()):
		var d: float = islet.shore_distance[i]
		if d < 0.0:
			into[i] = -INF
			continue
		var p := points[i]
		var b := lerpf(narrowest,widest,wander.get_noise_2d(p.x,p.y)*0.5+0.5)
		var t := d-b
		into[i] = t
		if t > deepest:
			deepest = t
			deep_at = p
	# The isle, out in the deep.
	var isle := Vector3.ZERO
	var spec_isle := float(spec.get("isle",ISLE))
	if rng.randf() < spec_isle:
		var isle_radius: Vector2 = spec.get("isle_radius",ISLE_RADIUS)
		var r := rng.randf_range(isle_radius.x,isle_radius.y)
		var choices := []
		for i in range(points.size()):
			if into[i] > r+ISLE_IN+shelf: choices.append(points[i])
		if not choices.is_empty():
			var at: Vector2 = choices[rng.randi_range(0,choices.size()-1)]
			isle = Vector3(at.x,at.y,r)
	for i in range(points.size()):
		var t := into[i]
		if t == -INF: continue
		var p := points[i]
		var h: float = islet.heights[i]
		if t <= 0.0:
			# The bank: over the water all round, easing down to it.
			var land := maxf(h,level+LAND_OVER)
			var shore_top := maxf(h,level+BEACH_TOP)
			h = land if t < -beach else lerpf(level+EDGE,shore_top,smoothstep(0.0,1.0,-t/beach))
		else:
			var bed := level-lerpf(0.05,SHELF_DEPTH,smoothstep(0.0,0.6,t))-0.06*clampf(t/shelf,0.0,1.0)
			var deep := level-depth+swell.get_noise_2d(p.x,p.y)*BED_SWELL
			h = lerpf(bed,deep,smoothstep(shelf,shelf+DROP,t))
		if isle.z > 0.0:
			var r := p.distance_to(Vector2(isle.x,isle.y))/isle.z
			if r < 1.6:
				var mound := level-0.5+(ISLE_TOP+0.5)*pow(maxf(1.0-r*r/2.56,0.0),1.4)*1.0
				h = maxf(h,mound)
		islet.heights[i] = h
	var area := 0.0
	for f in islet.land:
		var a: Vector2 = points[islet.ids[f*3]]
		var mean: float = (islet.heights[islet.ids[f*3]]+islet.heights[islet.ids[f*3+1]]+islet.heights[islet.ids[f*3+2]])/3.0
		if mean < level: area += absf((points[islet.ids[f*3+1]]-a).cross(points[islet.ids[f*3+2]]-a))*0.5
	islet.lake = {"level":level,"shelf":shelf,"depth":depth,"isle":isle,"deep":deep_at,"area":area,"spilled":false,
		"channel":float(spec.get("channel",_channel(islet))),"fall":float(spec.get("fall",FALL_HALF)),"swim":bool(spec.get("swim",false))}
	# Until it spills the pond's circle stands at the deepest water: the
	# islet's water (`water`) and channel read it.
	islet.pond = Vector3(deep_at.x,deep_at.y,sqrt(maxf(area,1.0)/PI))
	islet.lip = islet.rim_point(deep_at.angle())
	islet.lip_out = islet.lip.normalized()
	build_field(islet)
	if spec.has("toward"): spill(islet,spec.toward)

## The lake spills off the rim the way `toward` leans: the lip, the shore
## point that way nearest the water, the channel cut from the nearest
## water to it a little under the level, and what grew in it cleared.
static func spill(islet: RefCounted, toward: Vector2) -> void:
	var level: float = islet.water_level
	var points: PackedVector2Array = islet.points
	var edges: PackedInt32Array = islet.shore_edges
	var way := toward.normalized()
	var best := INF
	var pick := -1
	for k in range(0,edges.size(),3):
		var i := edges[k]
		var p := points[i]
		var score := 12.0*(1.0-p.normalized().dot(way))+distance(islet,p)*0.8
		if score < best:
			best = score
			pick = i
	if pick < 0: return
	var lip := points[pick]
	# The mouth: the nearest water to the lip, a little out into it.
	var mouth := lip
	var near := INF
	var field: Dictionary = islet.lake.field
	var n: int = field.n
	for j in range(n):
		for i in range(n):
			if field.dist[j*n+i] > 0.0: continue
			var q := Vector2(field.origin+i*FIELD,field.origin+j*FIELD)
			if _raw(islet,q) > level-SHELF_DEPTH*0.8: continue
			var d := q.distance_to(lip)
			if d < near:
				near = d
				mouth = q
	islet.lip = lip
	var outward: Dictionary = IslandShore._outward(points,edges)
	islet.lip_out = outward.get(pick,lip.normalized())
	islet.pond = Vector3(mouth.x,mouth.y,islet.pond.z)
	var channel := _channel(islet)
	for i in range(points.size()):
		if islet.shore_distance[i] < 0.0: continue
		var cd: float = islet._channel_distance(points[i])
		var cut := 1.0-smoothstep(channel*0.8,channel*1.45,cd)
		if cut <= 0.0: continue
		islet.heights[i] = minf(islet.heights[i],lerpf(islet.heights[i],level-0.14,cut))
	islet.objects = islet.objects.filter(func(o: Dictionary) -> bool:
		return islet._channel_distance(Vector2(o.x,o.z)) > channel+0.6)
	islet.lake.spilled = true
	build_field(islet)

## The field of distance to the water (m, 0 over it), FIELD a cell over the
## islet's reach.
static func build_field(islet: RefCounted) -> void:
	var level: float = islet.water_level
	var origin: float = -(float(islet.reach)+1.0)
	var n := ceili((float(islet.reach)+1.0)*2.0/FIELD)+1
	var dist := PackedFloat32Array()
	dist.resize(n*n)
	for j in range(n):
		for i in range(n):
			var q := Vector2(origin+i*FIELD,origin+j*FIELD)
			dist[j*n+i] = 0.0 if _land_height(islet,q) < level-0.005 else INF
	# A two-pass chamfer: near enough a distance for a spot finder.
	var diag := FIELD*sqrt(2.0)
	for j in range(n):
		for i in range(n):
			var k := j*n+i
			var v := dist[k]
			if i > 0: v = minf(v,dist[k-1]+FIELD)
			if j > 0:
				v = minf(v,dist[k-n]+FIELD)
				if i > 0: v = minf(v,dist[k-n-1]+diag)
				if i < n-1: v = minf(v,dist[k-n+1]+diag)
			dist[k] = v
	for j in range(n-1,-1,-1):
		for i in range(n-1,-1,-1):
			var k := j*n+i
			var v := dist[k]
			if i < n-1: v = minf(v,dist[k+1]+FIELD)
			if j < n-1:
				v = minf(v,dist[k+n]+FIELD)
				if i < n-1: v = minf(v,dist[k+n+1]+diag)
				if i > 0: v = minf(v,dist[k+n-1]+diag)
			dist[k] = v
	islet.lake.field = {"origin":origin,"n":n,"dist":dist}

# --- Reading it -------------------------------------------------------------------

## The ground's own height at `p` (no decks), the rim's off the land.
static func _raw(islet: RefCounted, p: Vector2) -> float:
	return islet._sample(islet.heights,p,Genesis.RIM_HEIGHT)

## The ground's own height at `p` on the land, INF off it: one lookup for
## both (`_raw`, `on_land`).
static func _land_height(islet: RefCounted, p: Vector2) -> float:
	var hit: Array = islet._locate(p)
	var f: int = hit[0]
	if f < 0: return INF
	var w: Vector3 = hit[1]
	var ids: PackedInt32Array = islet.ids
	var heights: PackedFloat32Array = islet.heights
	return w.x*heights[ids[f*3]]+w.y*heights[ids[f*3+1]]+w.z*heights[ids[f*3+2]]

## How far `p` is from the water (m, 0 over it), from the field.
static func distance(islet: RefCounted, p: Vector2) -> float:
	var field: Dictionary = islet.lake.get("field",{})
	if field.is_empty(): return INF
	var n: int = field.n
	var i := clampi(roundi((p.x-float(field.origin))/FIELD),0,n-1)
	var j := clampi(roundi((p.y-float(field.origin))/FIELD),0,n-1)
	return float(field.dist[j*n+i])

## True over the water (the ground under its level), the channel too.
static func wet(islet: RefCounted, p: Vector2) -> bool:
	if distance(islet,p) > 1.0: return false
	return islet.on_land(p) and _raw(islet,p) < float(islet.water_level)-0.005

## True within `room` m of the water.
static func near(islet: RefCounted, p: Vector2, room: float) -> bool:
	return distance(islet,p) < room+FIELD*0.5 or wet(islet,p)

## The water's depth at `p` (m, 0 dry).
static func depth_at(islet: RefCounted, p: Vector2) -> float:
	if not islet.on_land(p): return 0.0
	return maxf(float(islet.water_level)-_raw(islet,p),0.0)

## The bed's colour under the water and on the beach: sand at the
## waterline, darkening through the shelf to silt in the deep.
static func bed_tone(islet: RefCounted, sand: Color, gravel: Color, y: float, at: Vector2) -> Color:
	var under := float(islet.water_level)-y
	if under < 0.0: return sand.lerp(gravel,0.25+0.25*sin(at.x*1.7+at.y*2.3))
	var t := clampf(under/float(islet.lake.get("depth",1.6)),0.0,1.0)
	return sand.lerp(WEEDY,WEED*smoothstep(0.0,0.1,under)).lerp(SILT,smoothstep(0.08,0.8,t))

# --- What grows -------------------------------------------------------------------

## Reeds in clumps in the shallows and along the waterline, bank grass at
## the water's edge, and a tree on the isle; never in the spill's way.
static func plant(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var level: float = islet.water_level
	var reach: float = islet.reach
	var more := float((islet.recipe.get("lake",{}) as Dictionary).get("reeds",1.0))
	var clumps := roundi(rng.randi_range(REED_CLUMPS.x,REED_CLUMPS.y)*more)
	var made := 0
	for attempt in range(clumps*12):
		if made >= clumps: break
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		var under := depth_at(islet,p)
		if under <= 0.02 or under > SHELF_DEPTH+0.05: continue
		if _in_spill(islet,p,2.5): continue
		made += 1
		for k in range(rng.randi_range(REED_CLUMP.x,REED_CLUMP.y)):
			var q := p+Vector2(rng.randfn(0.0,REED_SPREAD),rng.randfn(0.0,REED_SPREAD))
			var d := depth_at(islet,q)
			if d > SHELF_DEPTH+0.08 or not islet.on_land(q) or _in_spill(islet,q,2.0): continue
			if d <= 0.0 and distance(islet,q) > 0.8: continue
			islet._add("reeds",q,rng.randf()*TAU,rng.randf_range(0.75,1.15))
	for n in range(roundi(rng.randi_range(BANK_GRASS.x,BANK_GRASS.y)*more)):
		for attempt in range(10):
			var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
			if not islet.on_land(p) or depth_at(islet,p) > 0.0 or distance(islet,p) > 0.9 or _in_spill(islet,p,1.5): continue
			if _raw(islet,p) > level+0.4: continue
			islet._add("bank_grass",p,rng.randf()*TAU,rng.randf_range(0.6,1.0))
			break
	var isle: Vector3 = islet.lake.isle
	if isle.z > 0.0:
		var top := Vector2(isle.x,isle.y)
		var tree: String = ["willow","birch","juniper"][rng.randi() % 3]
		islet._add(tree,top+Vector2.from_angle(rng.randf()*TAU)*0.2,rng.randf()*TAU,rng.randf_range(0.7,0.95))
		if not tree in islet.species: islet.species.append(tree)
		# A bigger isle (a big lake's) holds a small stand round it.
		for k in range(floori(maxf(isle.z-ISLE_RADIUS.y,0.0)/1.2)):
			var q := top+Vector2.from_angle(rng.randf()*TAU)*isle.z*rng.randf_range(0.25,0.55)
			if depth_at(islet,q) > 0.0: continue
			islet._add(tree,q,rng.randf()*TAU,rng.randf_range(0.6,0.85))
		for k in range(roundi(rng.randi_range(4,8)*maxf(isle.z/ISLE_RADIUS.y,1.0))):
			var q := top+Vector2.from_angle(rng.randf()*TAU)*isle.z*rng.randf_range(0.55,0.95)
			var d := depth_at(islet,q)
			if d > 0.2: continue
			islet._add("reeds" if d > 0.0 else "bank_grass",q,rng.randf()*TAU,rng.randf_range(0.6,0.95))
	_copses(islet,rng)
	var tea: Variant = (islet.recipe.get("lake",{}) as Dictionary).get("tea",false)
	if tea is float: islet.lake.tea = minf(steep(islet),tea)
	elif tea: islet.lake.tea = steep(islet)

## A recipe's copses: each a stand of one species and tint on the bank,
## its middle a little way from the water, clear of what already stands.
static func _copses(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var spec: Dictionary = islet.recipe.get("lake",{})
	var count: Vector2i = spec.get("copses",Vector2i.ZERO)
	if count.y <= 0: return
	var pool: Dictionary = spec.get("copse_pool",islet.recipe.get("tree_pool",{"birch":1.0}))
	var taken: Array[Vector3] = []
	for item: Dictionary in islet.objects:
		if Emergence.KIND_SIZE.has(item.asset) or str(item.asset) == "tree" or str(item.asset) in islet.BOULDERS:
			taken.append(Vector3(float(item.x),float(item.z),COPSE_APART*0.5*float(item.scale)))
	var reach: float = islet.reach
	for c in range(rng.randi_range(count.x,count.y)):
		var middle := Vector2.INF
		for attempt in range(30):
			var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
			var off := distance(islet,p)
			if off < COPSE_WATER.x or off > COPSE_WATER.y: continue
			if not islet._ground_ok(p,1.2,islet.TREE_STEEP,true) or _in_spill(islet,p,3.0): continue
			middle = p
			break
		if middle == Vector2.INF: continue
		var tree: String = islet._weighted(pool,rng.randf())
		var tint: String = islet._tree_tint(tree,rng)
		for k in range(rng.randi_range(COPSE.x,COPSE.y)):
			var q := middle+Vector2(rng.randfn(0.0,COPSE_SPREAD),rng.randfn(0.0,COPSE_SPREAD))
			var size := rng.randf_range(Emergence.TREE_SIZE.x,Emergence.TREE_SIZE.y)*float(Emergence.KIND_SIZE.get(tree,1.0))
			if not islet._ground_ok(q,1.0,islet.TREE_STEEP,true) or _in_spill(islet,q,2.0) or islet._near(q,taken,COPSE_APART*0.5*size): continue
			islet._add(tree,q,rng.randf()*TAU,size,tint)
			taken.append(Vector3(q.x,q.y,COPSE_APART*0.5*size))
			if not tree in islet.species: islet.species.append(tree)

## How steeped the lake is (0 clear to 1 a dark tarn) by what grows round
## it, as the plate's lakes are (scripts/lake_tea.gd `target`): each thing
## within its SHORE_REACH of the water weighs its STEEP, over the lake's
## size.
static func steep(islet: RefCounted) -> float:
	var total := 0.0
	for item: Dictionary in islet.objects:
		var weight: float = LakeTea.STEEP.get(str(item.asset),0.0)
		if weight > 0.0 and near(islet,Vector2(float(item.x),float(item.z)),LakeTea.SHORE_REACH): total += weight
	return clampf(total/(1.0+sqrt(maxf(float(islet.lake.area),0.0))/LakeTea.AREA_SPAN),0.0,1.0)

## The water's depth at `p` for a walker (m): the lake's where its recipe
## lets the pilot wade and swim it (`swim`), else none.
static func swim_depth(islet: RefCounted, p: Vector2) -> float:
	if not islet.lake.get("swim",false): return 0.0
	return depth_at(islet,p)

## Near the spill's channel (once it has spilled: until then what grows in
## its way is cleared as it is cut).
static func _in_spill(islet: RefCounted, p: Vector2, room: float) -> bool:
	if not islet.lake.get("spilled",false): return false
	return islet._channel_distance(p) < _channel(islet)+room*0.5

## The spill channel's half width (m): the lake's own, else the islet's.
static func _channel(islet: RefCounted) -> float:
	return float(islet.lake.get("channel",islet.get_script().CHANNEL))

## The fall's half width off the lip (m).
static func fall_half(islet: RefCounted) -> float:
	return float(islet.lake.get("fall",FALL_HALF))

# --- The water's sheet ------------------------------------------------------------------

## The lake's surface arrays for the plate's still-water material, as the
## islet's pond's (SkyIslet `water_arrays`): a sheet FIELD m a cell over
## every cell with water at a corner, at the level, reaching just under the
## banks; each vertex its depth (UV2.x), a run to the bank (UV.x) and the
## fetch, the open water upwind in eight directions (CUSTOM0, CUSTOM1).
static func water_arrays(islet: RefCounted, color: Color, shift: Vector3) -> Array:
	var level: float = islet.water_level
	var origin: float = -(float(islet.reach)+1.0)
	var n := ceili((float(islet.reach)+1.0)*2.0/FIELD)+1
	var deep := PackedFloat32Array()
	deep.resize(n*n)
	var wet := PackedByteArray()
	wet.resize(n*n)
	for j in range(n):
		for i in range(n):
			var h := _land_height(islet,Vector2(origin+i*FIELD,origin+j*FIELD))
			deep[j*n+i] = level-h if h < INF else -1.0
			wet[j*n+i] = 1 if deep[j*n+i] > 0.0 else 0
	# The fetch, eight ways (+x, +x+z, +z, -x+z, then the opposites): each
	# cell's run of open water that way, FETCH at most, swept from the far
	# side so each reads its neighbour's.
	var dirs: Array[Vector2i] = [Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]
	var runs: Array[PackedFloat32Array] = []
	for d: Vector2i in dirs:
		var run := PackedFloat32Array()
		run.resize(n*n)
		var step := FIELD*Vector2(d).length()
		var js := range(n-1,-1,-1) if d.y > 0 else range(n)
		var is_ := range(n-1,-1,-1) if d.x > 0 else range(n)
		for j: int in js:
			var nj := j+d.y
			if nj < 0 or nj >= n: continue
			for i: int in is_:
				var ni := i+d.x
				if ni < 0 or ni >= n: continue
				var next := nj*n+ni
				if wet[next] == 1: run[j*n+i] = minf(step+run[next],FETCH)
		runs.append(run)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	# Up-facing in Godot's winding (as SkyIslet `_tri`).
	var corners: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]
	for j in range(n-1):
		for i in range(n-1):
			var k := j*n+i
			if wet[k] == 0 and wet[k+1] == 0 and wet[k+n] == 0 and wet[k+n+1] == 0: continue
			for c: Vector2i in corners:
				var ci := i+c.x
				var cj := j+c.y
				var at := cj*n+ci
				var under := maxf(deep[at],0.0)
				vertices.append(Vector3(origin+ci*FIELD,level,origin+cj*FIELD)+shift)
				normals.append(Vector3.UP)
				colors.append(color)
				uv.append(Vector2(under*2.5,0.0))
				uv2.append(Vector2(under,0.0))
				fetch_a.append_array([runs[0][at],runs[1][at],runs[2][at],runs[3][at]])
				fetch_b.append_array([runs[4][at],runs[5][at],runs[6][at],runs[7][at]])
	if vertices.is_empty(): return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays
