extends RefCounted
## A whole forest planted on an islet (scripts/sky_islet.gd, its recipe's
## `forest`): the forest landform's wood (scripts/landform_forest.gd), made
## to be skimmed over in the plane, so from above it reads as a rolling,
## textured canopy of stands, not a carpet of one tree. Static; called from
## the islet's `_plant` on a worker, after its stones and before its tufts
## (the recipe turns the islet's own trees, drifts and undergrowth off),
## keeping clear of the records it already holds (`taken`).
##
## In order:
##   the clearing: one open meadow (`clearing` m round) on the flattest
##     ground away from the stream, its ground levelled (SkyIslet `claim`)
##     so the plane can set down in it, flowers in its light; and a few
##     smaller glades (`glades`, `glade` m) you can see into from above;
##     kept on the islet as meta "glades" (Vector3 x, z, radius, the
##     clearing first) and "clearing";
##   the stands: the land split into irregular stands about STAND m across
##     (a cellular noise), each its own dominant species and a companion
##     from its zone's pool, one crown tint a species a stand (the
##     forest's own deep greens, FOREST_COLOURS), so the canopy is a
##     patchwork of darker and lighter greens; the zones, spruce the mass
##     and birch the accent (a leafy crown reads as broccoli from the air):
##       high: the upper ground (over `line` of the land's height range,
##         the line wandering with the stands), darker spruce, the odd
##         redwood;
##       low: mostly mixed stands, spruce with a little birch, and a few
##         birch stands (BIRCH_STANDS);
##       bank: along the stream's valley, birch, spruce and a willow, open
##         at the water;
##       edge: the margin (a width wandering along the shore, so the wood's
##         edge is ragged: bare grass in places, trees to the rim in
##         others), young spruce, some birch and juniper, lower toward the
##         rim;
##     and birch in the light at the glades' rims;
##   giants: redwoods standing well over the canopy on the high ground,
##     sometimes a grove of them (`grove` odds);
##   the canopy: a jittered grid (`step` m) taken at the odds of the cover
##     (clumps and gaps from a low noise, opening to nothing in a glade and
##     at the water), each tree kept off the others by its crown's reach,
##     its height from its zone, swelling and dipping over the land in a
##     slow wave (TALL) and stepping with its stand's age (AGE) so the
##     canopy rolls in big shapes of light and shadow; then a sparse
##     understory pass of small spruce and juniper under the crowns;
##   the floor: fern beds in the shade, fallen logs with mushrooms, stumps,
##     a snag or two on the high ground, shrubs at the glades' rims and the
##     wood's edge, reeds and stones in the stream.
## Heights are the trees' drawn heights (m), turned into record scales by
## each species' height at scale 1 (Woodland HEIGHT).

const Woodland = preload("res://scripts/woodland.gd")
const Stands = preload("res://scripts/tree_stands.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const IsletStream = preload("res://scripts/islet_stream.gd")

## The zones' pools (species: weight). Spruce is the mass everywhere but
## the stream's banks; birch an accent (a few stands of its own low down,
## the banks, the edge, the glades' rims), its bright leafy crown kept a
## small share so the wood never reads as broccoli from the air; no
## broadleaf at all. Juniper is costly for its size (near a birch's
## triangles), so the edge and the understory hold only a little.
const POOLS := {
	"high":{"tree":1.0,"redwood":0.03},
	"birch":{"birch":1.0,"tree":0.6},
	"mixed":{"tree":1.0,"birch":0.12,"layered_tree":0.03},
	"bank":{"birch":1.0,"tree":0.8,"willow":0.25},
	"edge":{"tree":1.0,"birch":0.25,"juniper":0.2},
	"under":{"tree":1.0,"juniper":0.12},
}
## The share of the low ground's stands that are birch stands (the rest
## mixed, mostly spruce), and the odds of a birch at a glade's rim (within
## RIM m of where its fade ends) off the high ground.
const BIRCH_STANDS := 0.12
const RIM := 3.0
const RIM_BIRCH := 0.35
## The zones' heights (m): the canopy's by zone (birch and mixed share
## `low`), the understory's, the giants'.
const HEIGHTS := {"high":Vector2(10.0,15.0),"low":Vector2(8.5,12.5),"bank":Vector2(5.5,8.0),"edge":Vector2(4.5,7.5),"under":Vector2(2.4,4.4)}
const GIANT := Vector2(20.0,27.0)
## Some species stand lower than their zone's canopy (share of it).
const LOWER := {"broadleaf":0.75,"layered_tree":0.85,"willow":0.7,"juniper":0.3}
## The stands: their size (m), a dominant's share, and the odds of a tree
## from the whole zone pool instead.
const STAND := 11.0
const PURITY := 0.78
const STRAY := 0.06
## The high zone's line (share of the land's height range), how far the
## stands push it about, and how much darker its spruces are.
const LINE := 0.5
const LINE_WANDER := 0.35
const HIGH_DIM := 0.85
## The canopy's slow swell: a noise (1/m) and how far it lifts or lowers
## the trees (share); and each stand's age, lifting or lowering all its
## trees together (share), so the canopy steps up and down at the stands'
## edges and catches the light and the shadow in big shapes.
const TALL_WAVE := 0.035
const TALL := 0.3
const AGE := 0.18
## The cover: clump noise (1/m), cover in a gap (share), the least cover
## for a tree, and how far crowns keep apart (share of the two reaches).
const CLUMP := 0.08
const GAP_COVER := 0.2
const WOODED := 0.25
const CROWN_KEEP := 0.55
const UNDER_KEEP := 0.5
## The understory: the share of the grid's points that try for one (few:
## under the closed canopy it hardly shows from the air).
const UNDER_SHARE := 0.2
## The edge's width (m in from the shore, wandering between these over
## EDGE_WAVE 1/m), and where it is widest, a bare grass margin up to
## MARGIN m.
const EDGE := Vector2(1.5,5.0)
const EDGE_WAVE := 0.07
const MARGIN := 3.0
const INSET := 0.35
const STEEP := 1.1
## The stream: trees keep this far off its water (m), its bank zone reaches
## this far (share of the valley's half width).
const WATER_KEEP := 1.5
const BANK_SHARE := 0.75
## Glades fade into the wood over this many metres past their radius.
const GLADE_EDGE := 2.4
## Giants keep this far apart (m); a grove's spread (m) and size.
const GIANT_APART := 7.0
const GROVE_SPREAD := 9.0
const GROVE_SIZE := Vector2i(3,5)
## The floor, a square metre: fern beds (and ferns a bed), logs, stumps;
## snags; shrubs a metre of a glade's rim or the shore.
const FERN_BEDS := 0.008
const FERN_BED := Vector2i(3,6)
const LOGS := 0.0025
const STUMPS := 0.0015
const SNAGS := Vector2i(1,3)
const SHRUBS := 0.12
## Stones in the stream and reeds along it, a metre of its course.
const STREAM_STONES := 0.12
const STREAM_REEDS := 0.18
## The floor under the crowns: its tone (linear), how far past a crown's
## reach its shade falls (share), and how far toward the tone the deepest
## shade goes.
const FLOOR := Color(0.03,0.06,0.028)
const SHADE_REACH := 1.4
const FLOOR_SHARE := 0.85
## The crowns' colours (sRGB hex: weight), the forest's own rather than the
## gardens' (Stands TREE_COLOURS, which a species missing here falls back
## to): deep spruce greens, some bluer, some olive, none of them lime; birch
## and willow a muted sage, lighter than the spruce so they show as
## accents but not yellow. One a species a stand, with the stand's light
## (FOREST_LIGHT) over it, so the canopy is a patchwork of darker and
## lighter stands.
const FOREST_COLOURS := {
	"tree":{"3a7244":1.0,"2f6440":0.8,"3f7062":0.45,"4b6c3c":0.4,"26553a":0.5,"335f4e":0.35},
	"birch":{"7a9450":1.0,"6c8a4c":0.8,"86955f":0.45,"62824a":0.5},
	"willow":{"72895a":1.0,"65805a":0.7},
	"juniper":{"466c52":1.0,"4c6b5c":0.6,"566d45":0.4},
}
const FOREST_LIGHT := Vector2(0.78,1.1)
const CLEARING_FLOWERS := {"oxeye_daisy":1.0,"buttercup":0.9,"lupine":0.7,"cosmos":0.4,"poppy":0.3}

## Plants the forest `shape.recipe.forest` asks for onto `shape`, keeping
## clear of `taken` (Vector3 x, z, radius) and adding its fallen wood to it.
static func plant(shape: RefCounted, rng: RandomNumberGenerator, taken: Array[Vector3]) -> void:
	var spec: Dictionary = shape.recipe.get("forest",{})
	var area: float = shape.land_area()
	var reach: float = shape.reach
	var seed_value: int = shape.seed
	var noise := func(salt: int, frequency: float) -> FastNoiseLite:
		var n := FastNoiseLite.new()
		n.seed = seed_value+salt
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = frequency
		n.fractal_octaves = 2
		return n
	var clump: FastNoiseLite = noise.call(101,float(spec.get("clump",CLUMP)))
	var tall_wave: FastNoiseLite = noise.call(103,TALL_WAVE)
	var edge_wave: FastNoiseLite = noise.call(107,EDGE_WAVE)
	var stands := FastNoiseLite.new()
	stands.seed = seed_value+109
	stands.noise_type = FastNoiseLite.TYPE_CELLULAR
	stands.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	stands.frequency = 1.0/float(spec.get("stand",STAND))
	stands.domain_warp_enabled = true
	stands.domain_warp_amplitude = 6.0
	stands.domain_warp_frequency = 0.05
	# The land's height range, for the zones.
	var low := INF
	var high := -INF
	for i in range(shape.points.size()):
		if shape.shore_distance[i] < 0.0: continue
		low = minf(low,shape.heights[i])
		high = maxf(high,shape.heights[i])
	var span := maxf(high-low,0.5)
	var has_stream: bool = not (shape.stream as Dictionary).is_empty()
	var valley: float = float(shape.stream.get("valley",0.0)) if has_stream else 0.0
	# The clearing and the glades.
	var glades: Array = []
	var avoid: Array = []
	if has_stream:
		var course: PackedVector2Array = shape.stream.course
		for k in range(0,course.size(),3): avoid.append(Vector3(course[k].x,course[k].y,valley*0.7))
	var clearing := Vector3.ZERO
	var sizes: Vector2 = spec.get("clearing",Vector2.ZERO)
	if sizes.y > 0.0:
		var r := rng.randf_range(sizes.x,sizes.y)
		var lean := Vector2.from_angle(rng.randf()*TAU)*float(shape.radius_of_land())*0.35
		var at: Variant = shape.find_spot(r,1.2,float(spec.get("clearing_flat",1.4)),avoid,{"near":lean,"near_weight":0.15,"middle":0.6})
		# Rough ground: a smaller clearing, levelled the more.
		if at == null:
			r *= 0.75
			at = shape.find_spot(r,0.6,float(spec.get("clearing_flat",1.4))*2.0,avoid,{"middle":0.6})
		if at != null:
			clearing = Vector3(at.x,at.y,r)
			shape.claim(at,r*0.75)
			glades.append(clearing)
	var count: Vector2i = spec.get("glades",Vector2i(1,2))
	var glade_size: Vector2 = spec.get("glade",Vector2(3.5,5.5))
	for g in range(rng.randi_range(count.x,count.y)):
		var r := rng.randf_range(glade_size.x,glade_size.y)
		var keep: Array = avoid.duplicate()
		for o: Vector3 in glades: keep.append(Vector3(o.x,o.y,o.z+r+6.0))
		var lean := Vector2.from_angle(rng.randf()*TAU)*float(shape.radius_of_land())*0.55
		var at: Variant = shape.find_spot(r*0.6,1.0,2.2,keep,{"near":lean,"near_weight":0.4})
		if at == null: continue
		glades.append(Vector3(at.x,at.y,r))
	shape.set_meta("glades",glades)
	shape.set_meta("clearing",clearing)
	# The ground's openness: clumps and gaps, the glades, the water.
	var open_at := func(p: Vector2) -> float:
		var open := 1.0
		for o: Vector3 in glades: open = minf(open,smoothstep(o.z,o.z+GLADE_EDGE,p.distance_to(Vector2(o.x,o.y))))
		if has_stream:
			var near: Dictionary = IsletStream._nearest(shape.stream,p)
			if not near.is_empty(): open = minf(open,smoothstep(float(near.half)+WATER_KEEP*0.5,float(near.half)+WATER_KEEP*2.0,float(near.distance)))
		return open
	# How near a point lies to a glade's rim, where the light gets in.
	var rim_at := func(p: Vector2) -> float:
		var rim := 0.0
		for o: Vector3 in glades:
			var d := p.distance_to(Vector2(o.x,o.y))-o.z-GLADE_EDGE
			rim = maxf(rim,1.0-smoothstep(0.0,RIM,absf(d)))
		return rim
	var cover := func(p: Vector2) -> float:
		var c := smoothstep(-0.4,0.3,clump.get_noise_2dv(p))
		return lerpf(float(spec.get("gap_cover",GAP_COVER)),1.0,c)*float(open_at.call(p))
	# The zone at a point.
	var line := float(spec.get("line",LINE))
	var zone_at := func(p: Vector2) -> String:
		var inland: float = shape.inland(p)
		var edge := lerpf(EDGE.x,EDGE.y,edge_wave.get_noise_2dv(p)*0.5+0.5)
		if inland < edge: return "edge"
		var stand := stands.get_noise_2dv(p)
		var a: float = (float(shape.ground_at(p))-low)/span
		if has_stream:
			var near: Dictionary = IsletStream._nearest(shape.stream,p)
			if not near.is_empty() and float(near.distance) < valley*BANK_SHARE and a < line+0.15: return "bank"
		if a+stand*LINE_WANDER > line: return "high"
		return "birch" if stand > 1.0-BIRCH_STANDS*2.0 else "mixed"
	# Trees: [x, z, reach, species, scale] in a coarse hash for keeping apart.
	var grid := {}
	var trees: Array = []
	var tints := {}
	var place := func(tree: String, p: Vector2, height: float, zone: String) -> void:
		var stand_id := int((stands.get_noise_2dv(p)+1.0)*500.0)
		var tint_key := "%s:%d" % [tree,stand_id]
		if not tints.has(tint_key): tints[tint_key] = _tint(tree,rng,HIGH_DIM if zone == "high" else 1.0)
		var size := height/float(Woodland.HEIGHT.get(tree,4.0))
		shape.add_record(tree,p,rng.randf()*TAU,size,tints[tint_key])
		var t := [p,height*float(Woodland.REACH.get(tree,0.2)),tree,size]
		trees.append(t)
		var cell := Vector2i((p/3.0).floor())
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(t)
		if not tree in shape.species: shape.species.append(tree)
	var crowded := func(p: Vector2, r: float, keep: float) -> bool:
		var cell := Vector2i((p/3.0).floor())
		for dx in range(-2,3):
			for dz in range(-2,3):
				for t: Array in grid.get(cell+Vector2i(dx,dz),[]):
					# A giant's crown stands over the rest: keep off its trunk.
					var other: float = t[1] if t[2] != "redwood" or float(t[3]) < 1.0 else 1.2
					if p.distance_to(t[0]) < (r+other)*keep: return true
		return false
	var ground_ok := func(p: Vector2) -> bool:
		return shape._ground_ok(p,INSET,STEEP,true) and not shape._near(p,taken,0.3)
	# Giants, and perhaps a grove of them, on the high ground.
	var giants: Vector2i = spec.get("giants",Vector2i(1,3))
	var standing: Array[Vector2] = []
	var want := rng.randi_range(giants.x,giants.y)
	var grove_at: Variant = null
	var grove := 0
	if rng.randf() < float(spec.get("grove",0.0)):
		for attempt in range(40):
			var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))*0.7
			if not ground_ok.call(p) or zone_at.call(p) != "high" or float(open_at.call(p)) < 1.0: continue
			grove_at = p
			break
		if grove_at != null: grove = rng.randi_range(GROVE_SIZE.x,GROVE_SIZE.y)
	for n in range(grove+want):
		var in_grove := n < grove
		for attempt in range(30):
			var p: Vector2
			if in_grove: p = (grove_at as Vector2)+Vector2(rng.randfn(0.0,1.0),rng.randfn(0.0,1.0))*GROVE_SPREAD*0.5
			else: p = Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
			if not ground_ok.call(p) or shape.inland(p) < 4.0 or float(open_at.call(p)) < 1.0: continue
			if not in_grove and zone_at.call(p) != "high": continue
			var apart := true
			for s in standing:
				if p.distance_to(s) < (GIANT_APART*0.55 if in_grove else GIANT_APART): apart = false
			if not apart: continue
			place.call("redwood",p,rng.randf_range(GIANT.x,GIANT.y),"high")
			standing.append(p)
			break
	# The canopy, then the understory, over a jittered grid.
	var step := float(spec.get("step",1.7))
	for pass_ in range(3):
		var x := -reach
		while x <= reach:
			var z := -reach
			while z <= reach:
				var p := Vector2(x,z)+Vector2(rng.randf_range(-0.5,0.5),rng.randf_range(-0.5,0.5))*step
				z += step
				var roll := rng.randf()
				var pick := rng.randf()
				var rare := rng.randf()
				var tall := rng.randf()
				if not ground_ok.call(p): continue
				var c: float = cover.call(p)
				var under := pass_ == 2
				if under:
					if roll > UNDER_SHARE or c < WOODED: continue
				elif c < WOODED+(roll-0.5)*0.3:
					continue
				var zone: String = zone_at.call(p)
				var inland: float = shape.inland(p)
				if zone == "edge" and not under:
					# Bare grass along the widest stretches of the margin.
					var bare := smoothstep(0.2,0.7,edge_wave.get_noise_2dv(p)*0.5+0.5)*MARGIN
					if inland < bare: continue
				var tree: String
				var h: float
				var keep := CROWN_KEEP
				if under:
					tree = _weighted(POOLS.under,pick)
					h = lerpf(HEIGHTS.under.x,HEIGHTS.under.y,tall)
					keep = UNDER_KEEP
				else:
					var pool: Dictionary = POOLS[zone]
					var stand := stands.get_noise_2dv(p)*0.5+0.5
					var dominant := _weighted(pool,fposmod(stand*7.31,1.0))
					var companion := _weighted(pool,fposmod(stand*13.7+0.37,1.0))
					tree = dominant if pick < PURITY else companion
					if rare < STRAY: tree = _weighted(pool,fposmod(rare*97.1,1.0))
					# Birch in the light at a glade's rim.
					if zone != "high" and fposmod(rare*31.7,1.0) < RIM_BIRCH*float(rim_at.call(p)): tree = "birch"
					var band: Vector2 = HEIGHTS["low" if zone in ["birch","mixed"] else zone]
					h = lerpf(band.x,band.y,tall)*float(LOWER.get(tree,1.0))
					h *= 1.0+TALL*tall_wave.get_noise_2dv(p)
					h *= 1.0+AGE*(fposmod(stand*53.9,1.0)*2.0-1.0)
					if zone == "edge": h *= lerpf(0.7,1.0,clampf(inland/EDGE.y,0.0,1.0))
				if tree == "juniper": h = minf(h,2.6)
				var r := h*float(Woodland.REACH.get(tree,0.2))
				if crowded.call(p,r,keep): continue
				place.call(tree,p,h,zone)
			x += step
	# The trunks stay out of `taken` (the islet rings what is taken with
	# tufts, and reads it one by one): the floor keeps off them through the
	# trees' hash instead.
	var clear := func(p: Vector2, room: float) -> bool:
		if shape._near(p,taken,room): return false
		var cell := Vector2i((p/3.0).floor())
		for dx in range(-1,2):
			for dz in range(-1,2):
				for t: Array in grid.get(cell+Vector2i(dx,dz),[]):
					var trunk: float = 0.45 if t[2] != "redwood" else 0.35+0.4*float(t[3])
					if p.distance_to(t[0]) < trunk+room: return false
		return true
	shape.set_meta("forest_trees",trees.size())
	_shade(shape,trees)
	_floor(shape,rng,taken,clear,spec,area,glades,clearing,cover,zone_at)

## The forest floor: ferns, logs and mushrooms, stumps, snags, shrubs, the
## clearing's and glades' flowers, the stream's stones and reeds.
static func _floor(shape: RefCounted, rng: RandomNumberGenerator, taken: Array[Vector3], clear: Callable, spec: Dictionary, area: float, glades: Array, clearing: Vector3, cover: Callable, zone_at: Callable) -> void:
	var floor_share := float(spec.get("floor",1.0))
	var shade := func(p: Vector2) -> bool: return float(cover.call(p)) > 0.5 and shape.inland(p) > 1.5
	for n in range(Woodland._count(rng,area*FERN_BEDS*floor_share)):
		var at: Variant = _spot(shape,rng,clear,0.15,shade)
		if at == null: continue
		for k in range(rng.randi_range(FERN_BED.x,FERN_BED.y)):
			var p: Vector2 = at+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,1.3)
			if shape._ground_ok(p,0.5,STEEP,true) and clear.call(p,0.1):
				shape.add_record("fern",p,rng.randf()*TAU,rng.randf_range(0.7,1.05))
	for n in range(Woodland._count(rng,area*LOGS*floor_share)):
		var at: Variant = _spot(shape,rng,clear,0.5,shade)
		if at == null: continue
		shape.add_record("log",at,rng.randf()*TAU,rng.randf_range(0.9,1.3))
		taken.append(Vector3(at.x,at.y,0.6))
		for k in range(rng.randi_range(1,4)):
			var p: Vector2 = at+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.5,0.9)
			if shape._ground_ok(p,0.4,STEEP,true): shape.add_record("mushroom",p,rng.randf()*TAU,rng.randf_range(0.7,1.2))
	for n in range(Woodland._count(rng,area*STUMPS*floor_share)):
		var at: Variant = _spot(shape,rng,clear,0.4,func(p: Vector2) -> bool: return true)
		if at == null: continue
		shape.add_record("stump",at,rng.randf()*TAU,rng.randf_range(0.8,1.2))
		taken.append(Vector3(at.x,at.y,0.4))
	for n in range(rng.randi_range(SNAGS.x,SNAGS.y)):
		var at: Variant = _spot(shape,rng,clear,0.4,func(p: Vector2) -> bool: return zone_at.call(p) == "high")
		if at == null: continue
		shape.add_record("snag",at,rng.randf()*TAU,rng.randf_range(2.6,3.6))
		taken.append(Vector3(at.x,at.y,0.3))
	# Shrubs where the light gets in: the glades' rims and the wood's edge.
	for n in range(Woodland._count(rng,TAU*float(shape.radius_of_land())*SHRUBS)):
		var at: Variant = _spot(shape,rng,clear,0.25,func(p: Vector2) -> bool: return shape.inland(p) < EDGE.y)
		if at != null: shape.add_record("shrub",at,rng.randf()*TAU,rng.randf_range(0.6,1.05))
	for o: Vector3 in glades:
		var middle := Vector2(o.x,o.y)
		for n in range(Woodland._count(rng,TAU*o.z*SHRUBS*2.0)):
			var p := middle+Vector2.from_angle(rng.randf()*TAU)*(o.z+rng.randf_range(-0.3,1.6))
			if shape._ground_ok(p,0.5,STEEP,true) and clear.call(p,0.2):
				shape.add_record("shrub",p,rng.randf()*TAU,rng.randf_range(0.6,1.0))
		# Flowers in the light: drifts, more in the clearing.
		var drifts := rng.randi_range(3,5) if o == clearing else rng.randi_range(1,2)
		for d in range(drifts):
			var flower := Woodland._weighted(CLEARING_FLOWERS,rng.randf())
			var tint := MeadowTypes.tint(flower,rng.randf())
			var at := middle+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.2,0.8)*o.z
			for k in range(rng.randi_range(8,18)):
				var p := at+Vector2(rng.randfn(0.0,1.2),rng.randfn(0.0,1.2))
				if p.distance_to(middle) > o.z or not shape._ground_ok(p,0.5,STEEP,true) or not clear.call(p,0.0): continue
				shape.add_record(flower,p,rng.randf()*TAU,rng.randf_range(0.8,1.1),tint)
			if not flower in shape.flowers: shape.flowers.append(flower)
	# The stream: stones in its bed, reeds and bank grass at its edges.
	if (shape.stream as Dictionary).is_empty(): return
	var course: PackedVector2Array = shape.stream.course
	var half: PackedFloat32Array = shape.stream.half
	var length := float(course.size())*IsletStream.STRIDE
	for n in range(Woodland._count(rng,length*STREAM_STONES)):
		var k := rng.randi_range(1,course.size()-3)
		var way := (course[k+1]-course[k]).normalized()
		var p := course[k]+Vector2(-way.y,way.x)*rng.randf_range(-0.8,0.8)*half[k]
		if shape.on_land(p): shape.add_record(Woodland._weighted({"boulder_1":1.0,"boulder_2":1.0,"boulder_3":0.8,"rock":0.6},rng.randf()),p,rng.randf()*TAU,rng.randf_range(0.3,0.7))
	for n in range(Woodland._count(rng,length*STREAM_REEDS)):
		var k := rng.randi_range(1,course.size()-3)
		var way := (course[k+1]-course[k]).normalized()
		var p := course[k]+Vector2(-way.y,way.x)*(1.0 if rng.randf() < 0.5 else -1.0)*half[k]*rng.randf_range(0.95,1.4)
		if shape.on_land(p) and shape.inland(p) > 0.4:
			shape.add_record("reeds" if rng.randf() < 0.5 else "bank_grass",p,rng.randf()*TAU,rng.randf_range(0.6,1.0))

## How shaded each grid point lies under the crowns (0 to 1), kept as meta
## "forest_shade" for the floor's tone (`floor_tone`): every crown darkens
## the points within SHADE_REACH of its reach, most at its trunk.
static func _shade(shape: RefCounted, trees: Array) -> void:
	var points: PackedVector2Array = shape.points
	var shade := PackedFloat32Array()
	shade.resize(points.size())
	var side: int = int(shape.cells)+1
	var step: float = shape.step
	var half: float = shape.half
	for t: Array in trees:
		var at: Vector2 = t[0]
		var r: float = float(t[1])*SHADE_REACH+0.6
		var lo := Vector2i(((at-Vector2.ONE*r+Vector2.ONE*half)/step).floor()).maxi(0)
		var hi := Vector2i(((at+Vector2.ONE*r+Vector2.ONE*half)/step).ceil()).mini(side-1)
		for j in range(lo.y,hi.y+1):
			for i in range(lo.x,hi.x+1):
				var k := j*side+i
				var d := points[k].distance_to(at)
				if d < r: shade[k] = minf(shade[k]+(1.0-d/r)*0.7,1.0)
	shape.set_meta("forest_shade",shade)

## The forest floor's tone for face `f` of `shape`'s top, from the grass
## tone it would have: darkened toward FLOOR under the crowns.
static func floor_tone(shape: RefCounted, f: int, tone: Color) -> Color:
	var shade: PackedFloat32Array = shape.get_meta("forest_shade",PackedFloat32Array())
	if shade.size() != (shape.points as PackedVector2Array).size(): return tone
	var ids: PackedInt32Array = shape.ids
	var s := (shade[ids[f*3]]+shade[ids[f*3+1]]+shade[ids[f*3+2]])/3.0
	if s <= 0.0: return tone
	return tone.lerp(FLOOR,s*FLOOR_SHARE)

## A seeded spot on the land that `ok` takes and `clear` keeps `room` m
## clear; null after a few tries (as Woodland `_spot`).
static func _spot(shape: RefCounted, rng: RandomNumberGenerator, clear: Callable, room: float, ok: Callable) -> Variant:
	var reach: float = shape.reach
	for attempt in range(20):
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		if not shape._ground_ok(p,0.6,STEEP,true) or not clear.call(p,room): continue
		if not ok.call(p): continue
		return p
	return null

static func _weighted(pool: Dictionary, roll: float) -> String:
	return Woodland._weighted(pool,roll)

## A crown colour for `tree` (FOREST_COLOURS, else Stands TREE_COLOURS),
## dimmed by `dim`, as a record tint.
static func _tint(tree: String, rng: RandomNumberGenerator, dim: float) -> String:
	if FOREST_COLOURS.has(tree):
		var own := Color(_weighted(FOREST_COLOURS[tree],rng.randf())).srgb_to_linear()*rng.randf_range(FOREST_LIGHT.x,FOREST_LIGHT.y)*dim
		return NativeObjectPose.encode_tint(Color(minf(own.r,1.0),minf(own.g,1.0),minf(own.b,1.0)))
	if not Stands.TREE_COLOURS.has(tree): return ""
	var options: Array = Stands.TREE_COLOURS[tree]
	var pool := {}
	for n in range(options.size()): pool[str(n)] = float(options[n][1])
	var pick := int(_weighted(pool,rng.randf()))
	var color := Color(options[pick][0]).srgb_to_linear()*rng.randf_range(Stands.TREE_BRIGHTNESS.x,Stands.TREE_BRIGHTNESS.y)*dim
	return NativeObjectPose.encode_tint(Color(minf(color.r,1.0),minf(color.g,1.0),minf(color.b,1.0)))
