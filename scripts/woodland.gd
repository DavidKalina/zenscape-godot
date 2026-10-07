extends RefCounted
## A woodland planted on an islet (scripts/sky_islet.gd, its recipe's
## `woodland`): a real wood, seen from the plane as one canopy and walked
## through on foot, where the islet's own planting spaces its trees out to
## read as separate ones. Static; called from the islet's `_plant` on a
## worker, after its stones and before its flowers, tufts and undergrowth
## (which the recipe turns down), with the records it already holds kept
## clear (`taken`).
##
## In order:
##   glades: clearings (`glades`, radius `glade` m), the first the hold's
##     when `hold` is set (near the middle, room for a hut); kept on the
##     islet as meta "glades" (Vector3 x, z, radius) for what stands in
##     them (scripts/forest_hold.gd);
##   giants: a few emergent redwoods (`giants`, GIANT m tall) standing
##     high over the canopy, well apart; with `hold`, the first stands at
##     the hold's glade edge for a platform in its boughs (meta
##     "hold_tree": Vector3 x, z, record scale);
##   the canopy: a jittered grid (`step` m) over the land, each point taken
##     at the odds of the cover there: clumps and gaps from a low noise
##     (CLUMP), opening to nothing in a glade over GLADE_EDGE m; each tree
##     kept off the others by its crown's reach (crowns just touching, so
##     the wood closes over), its layer drawn: the edge (within EDGE m of
##     the shore: birch, young spruce, juniper, lower so the wood domes up
##     from its margin), the understory (small spruce and juniper), or the
##     canopy (tall spruce, some birch, the odd young redwood), taller in a
##     clump's heart; one tint a species a clump, so stands read as stands;
##   the floor: ferns in the shade in little beds, fallen logs with
##     mushrooms by them, stumps, a standing snag or two, shrubs along the
##     glades' and the wood's edges, flowers in the glades.
## Heights are the trees' drawn heights (m), turned into record scales by
## each species' height at scale 1 (HEIGHT).

const Stands = preload("res://scripts/tree_stands.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")

## Each species' drawn height at record scale 1 (m): the catalog's.
const HEIGHT := {"tree":4.4,"birch":3.4,"redwood":14.9,"juniper":1.6,"broadleaf":3.0,"willow":2.7,"layered_tree":4.9}
## A crown's reach as a share of its height, by species.
const REACH := {"tree":0.16,"birch":0.2,"redwood":0.15,"juniper":0.7,"broadleaf":0.35,"willow":0.45,"layered_tree":0.4}
## The layers' heights (m): the canopy, the understory, the edge; the
## giants'. The canopy runs up to CLUMP_LIFT taller in a clump's heart, the
## edge's trees down to EDGE_LOW of their height at the shore.
const CANOPY := Vector2(5.4,7.6)
const UNDER := Vector2(2.4,3.8)
const MARGIN := Vector2(3.4,5.6)
const GIANT := Vector2(12.5,16.5)
const CLUMP_LIFT := 0.18
const EDGE_LOW := 0.72
## The edge's width (m in from the shore), trees' least inset (m) and the
## steepest ground they stand on.
const EDGE := 2.6
const INSET := 0.55
const STEEP := 0.85
## The cover: clump noise's frequency (1/m), the cover in a gap between
## clumps (share of a clump's), the understory's share of the trees, and
## how far a crown's reach keeps the next trunk (share of the two reaches).
const CLUMP := 0.12
const GAP_COVER := 0.22
const UNDER_SHARE := 0.3
const CROWN_KEEP := 0.95
## Ground is wooded where the cover passes WOODED (give or take half of
## WOODED_DITHER, so a wood's edge is ragged); wooded ground fills over
## PASSES of the grid, the last only with understory, which stands closer
## under the crowns (UNDER_KEEP).
const WOODED := 0.42
const WOODED_DITHER := 0.25
const PASSES := 3
const UNDER_KEEP := 0.7
## Glades fade into the wood over this many metres past their radius.
const GLADE_EDGE := 2.2
## Giants keep this far apart (m), and the canopy's trunks this far off a
## giant's (m).
const GIANT_APART := 7.0
const GIANT_ROOM := 1.6
## The floor: ferns a square metre of shade (in beds of FERN_BED), logs and
## stumps a square metre, snags, shrubs along an edge (a metre of it).
const FERNS := 0.09
const FERN_BED := Vector2i(2,5)
const LOGS := 0.008
const STUMPS := 0.006
const SNAGS := Vector2i(0,2)
const SHRUBS := 0.25
const GLADE_FLOWERS := {"oxeye_daisy":1.0,"buttercup":0.8,"lupine":0.7,"cosmos":0.3}

## Plants the woodland `shape.recipe.woodland` asks for onto `shape`,
## keeping clear of `taken` (Vector3 x, z, radius) and adding its trunks
## and logs to it.
static func plant(shape: RefCounted, rng: RandomNumberGenerator, taken: Array[Vector3]) -> void:
	var spec: Dictionary = shape.recipe.get("woodland",{})
	var area: float = shape.land_area()
	var reach: float = shape.reach
	var noise := FastNoiseLite.new()
	noise.seed = int(shape.seed)+71
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(spec.get("clump",CLUMP))
	noise.fractal_octaves = 2
	# Glades.
	var glades: Array = []
	var count: Vector2i = spec.get("glades",Vector2i(0,1))
	var sizes: Vector2 = spec.get("glade",Vector2(4.0,6.0))
	var hold: bool = spec.get("hold",false)
	for g in range(rng.randi_range(count.x,count.y)):
		var r := rng.randf_range(sizes.x,sizes.y)*(1.0 if g == 0 else 0.7)
		var avoid: Array = []
		for o: Vector3 in glades: avoid.append(Vector3(o.x,o.y,o.z+r+3.0))
		var lean: Vector2 = Vector2.from_angle(rng.randf()*TAU)*float(shape.radius_of_land())*(0.2 if g == 0 and hold else 0.5)
		var prefer := {"near":lean,"near_weight":0.6,"middle":0.4 if g == 0 and hold else 0.0}
		var at: Variant = shape.find_spot(r*0.6,0.8,1.6,avoid,prefer)
		if at == null: continue
		glades.append(Vector3(at.x,at.y,r))
	shape.set_meta("glades",glades)
	var cover := func(p: Vector2) -> float:
		var c := smoothstep(-0.35,0.35,noise.get_noise_2dv(p))
		var open := 1.0
		for o: Vector3 in glades: open = minf(open,smoothstep(o.z,o.z+GLADE_EDGE,p.distance_to(Vector2(o.x,o.y))))
		return lerpf(float(spec.get("gap_cover",GAP_COVER)),1.0,c)*open
	# Trees: [x, z, reach] in a coarse hash for keeping apart.
	var grid := {}
	var trees: Array = []
	var tints := {}
	var place := func(tree: String, p: Vector2, height: float, clump: int) -> void:
		var tint_key := "%s:%d" % [tree,clump]
		if not tints.has(tint_key): tints[tint_key] = _tint(tree,rng)
		var size := height/float(HEIGHT.get(tree,4.0))
		shape.add_record(tree,p,rng.randf()*TAU,size,tints[tint_key])
		var r := height*float(REACH.get(tree,0.2))
		var t := [p,r,tree,size]
		trees.append(t)
		var cell := Vector2i((p/3.0).floor())
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(t)
		if not tree in shape.species: shape.species.append(tree)
	var crowded := func(p: Vector2, r: float, keep: float) -> bool:
		var cell := Vector2i((p/3.0).floor())
		for dx in range(-3,4):
			for dz in range(-3,4):
				for t: Array in grid.get(cell+Vector2i(dx,dz),[]):
					var other_r: float = t[1] if t[2] != "redwood" or float(t[3]) < 0.6 else GIANT_ROOM
					if p.distance_to(t[0]) < (r+other_r)*keep: return true
		return false
	# Giants, the hold's first at its glade's edge.
	var giants := Vector2i(spec.get("giants",Vector2i(0,0)))
	var want := rng.randi_range(giants.x,giants.y)
	var standing: Array[Vector2] = []
	if hold and not glades.is_empty() and want > 0:
		var g: Vector3 = glades[0]
		var best: Variant = null
		var best_in := -INF
		for k in range(16):
			var a := TAU*k/16.0+rng.randf()*0.2
			var p := Vector2(g.x,g.y)+Vector2.from_angle(a)*(g.z+0.6)
			if not shape._ground_ok(p,3.0,STEEP,true) or shape._near(p,taken,0.6): continue
			# Toward the middle of the land, where the wood is deepest.
			var score: float = shape.inland(p)+rng.randf()*0.5
			if score > best_in:
				best_in = score
				best = p
		if best != null:
			var h := rng.randf_range(lerpf(GIANT.x,GIANT.y,0.5),GIANT.y)
			place.call("redwood",best,h,-1)
			shape.set_meta("hold_tree",Vector3(best.x,best.y,h/float(HEIGHT.redwood)))
			standing.append(best)
			want -= 1
	for n in range(want):
		for attempt in range(24):
			var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
			if not shape._ground_ok(p,3.2,STEEP,true) or shape._near(p,taken,1.0): continue
			if cover.call(p) < 0.5: continue
			var apart := true
			for s in standing:
				if p.distance_to(s) < GIANT_APART: apart = false
			if not apart: continue
			place.call("redwood",p,rng.randf_range(GIANT.x,GIANT.y),-1)
			standing.append(p)
			break
	# The canopy, the understory and the edge, over a jittered grid.
	var step := float(spec.get("step",1.5))
	var fill := float(spec.get("fill",0.85))
	var canopy_pool: Dictionary = spec.get("canopy_pool",{"tree":1.0,"birch":0.2})
	var under_pool: Dictionary = spec.get("under_pool",{"tree":1.0,"juniper":0.5})
	var edge_pool: Dictionary = spec.get("edge_pool",{"birch":1.0,"tree":0.8,"juniper":0.5})
	for pass_ in range(PASSES):
		var x := -reach
		while x <= reach:
			var z := -reach
			while z <= reach:
				var p := Vector2(x,z)+Vector2(rng.randf_range(-0.5,0.5),rng.randf_range(-0.5,0.5))*step
				z += step
				var roll := rng.randf()
				var layer_roll := rng.randf()
				var pick := rng.randf()
				var tall := rng.randf()
				if not shape._ground_ok(p,INSET,STEEP,true) or shape._near(p,taken,0.3): continue
				var c: float = cover.call(p)
				# Wooded ground fills over the passes; a gap takes the odd
				# tree on the first.
				var wooded := c > WOODED+(roll-0.5)*WOODED_DITHER
				if not wooded and (pass_ > 0 or roll > float(spec.get("gap_cover",GAP_COVER))*fill): continue
				if wooded and pass_ == 0 and roll > fill: continue
				var inland: float = shape.inland(p)
				var clump := int(floorf(noise.get_noise_2d(p.x*0.5,p.y*0.5)*3.0+3.0))
				var tree: String
				var h: float
				var keep := CROWN_KEEP
				if inland < EDGE:
					tree = _weighted(edge_pool,pick)
					h = lerpf(MARGIN.x,MARGIN.y,tall)*lerpf(EDGE_LOW,1.0,inland/EDGE)
				elif layer_roll < UNDER_SHARE or pass_ == PASSES-1:
					tree = _weighted(under_pool,pick)
					h = lerpf(UNDER.x,UNDER.y,tall)
					keep = UNDER_KEEP
				else:
					tree = _weighted(canopy_pool,pick)
					h = lerpf(CANOPY.x,CANOPY.y,tall)*(1.0+CLUMP_LIFT*smoothstep(0.5,1.0,c))
					if tree == "redwood": h *= 1.15
				if tree == "juniper": h = minf(h,2.6)
				var r := h*float(REACH.get(tree,0.2))
				if crowded.call(p,r,keep): continue
				place.call(tree,p,h,clump)
			x += step
	for t: Array in trees:
		var trunk: float = 0.45 if t[2] != "redwood" else 0.35+0.6*float(t[3])
		taken.append(Vector3((t[0] as Vector2).x,(t[0] as Vector2).y,trunk))
	# The floor.
	var shade := func(p: Vector2) -> bool: return cover.call(p) > 0.45 and shape.inland(p) > 1.2
	for n in range(_count(rng,area*float(spec.get("ferns",FERNS))/3.5)):
		var at: Variant = _spot(shape,rng,taken,0.15,shade)
		if at == null: continue
		for k in range(rng.randi_range(FERN_BED.x,FERN_BED.y)):
			var p: Vector2 = at+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,1.1)
			if shape._ground_ok(p,0.5,STEEP,true) and not shape._near(p,taken,0.1):
				shape.add_record("fern",p,rng.randf()*TAU,rng.randf_range(0.6,0.95))
	for n in range(_count(rng,area*float(spec.get("logs",LOGS)))):
		var at: Variant = _spot(shape,rng,taken,0.5,shade)
		if at == null: continue
		shape.add_record("log",at,rng.randf()*TAU,rng.randf_range(0.85,1.2))
		taken.append(Vector3(at.x,at.y,0.6))
		# Mushrooms come up along it.
		for k in range(rng.randi_range(2,5)):
			var p: Vector2 = at+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.5,0.9)
			if shape._ground_ok(p,0.4,STEEP,true): shape.add_record("mushroom",p,rng.randf()*TAU,rng.randf_range(0.7,1.2))
	for n in range(_count(rng,area*STUMPS)):
		var at: Variant = _spot(shape,rng,taken,0.4,func(p: Vector2) -> bool: return true)
		if at == null: continue
		shape.add_record("stump",at,rng.randf()*TAU,rng.randf_range(0.8,1.15))
		taken.append(Vector3(at.x,at.y,0.4))
	for n in range(rng.randi_range(SNAGS.x,SNAGS.y)):
		var at: Variant = _spot(shape,rng,taken,0.4,shade)
		if at == null: continue
		shape.add_record("snag",at,rng.randf()*TAU,rng.randf_range(2.2,3.2))
		taken.append(Vector3(at.x,at.y,0.3))
	# Shrubs where the light gets in: the glades' rims and the wood's edge.
	var rims: Array = []
	for o: Vector3 in glades: rims.append([Vector2(o.x,o.y),o.z])
	var edge_shrubs := _count(rng,TAU*shape.radius_of_land()*SHRUBS*0.5)
	for n in range(edge_shrubs):
		var at: Variant = _spot(shape,rng,taken,0.25,func(p: Vector2) -> bool: return shape.inland(p) < EDGE+0.5)
		if at != null: shape.add_record("shrub",at,rng.randf()*TAU,rng.randf_range(0.6,1.0))
	for rim: Array in rims:
		var middle: Vector2 = rim[0]
		var r: float = rim[1]
		for n in range(_count(rng,TAU*r*SHRUBS)):
			var p := middle+Vector2.from_angle(rng.randf()*TAU)*(r+rng.randf_range(-0.2,1.4))
			if shape._ground_ok(p,0.5,STEEP,true) and not shape._near(p,taken,0.2):
				shape.add_record("shrub",p,rng.randf()*TAU,rng.randf_range(0.6,1.0))
		# Flowers in the glade's light, a drift or two.
		for d in range(rng.randi_range(1,2)):
			var flower := _weighted(GLADE_FLOWERS,rng.randf())
			var tint := MeadowTypes.tint(flower,rng.randf())
			var at := middle+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.3,0.75)*r
			for k in range(rng.randi_range(8,16)):
				var p := at+Vector2(rng.randfn(0.0,1.0),rng.randfn(0.0,1.0))
				if p.distance_to(middle) > r or not shape._ground_ok(p,0.5,STEEP,true) or shape._near(p,taken,0.0): continue
				shape.add_record(flower,p,rng.randf()*TAU,rng.randf_range(0.8,1.1),tint)
			if not flower in shape.flowers: shape.flowers.append(flower)

## A seeded spot on the land that `ok` takes, clear of `taken` by `room`;
## null after a few tries.
static func _spot(shape: RefCounted, rng: RandomNumberGenerator, taken: Array, room: float, ok: Callable) -> Variant:
	var reach: float = shape.reach
	for attempt in range(20):
		var p := Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach,reach))
		if not shape._ground_ok(p,0.6,STEEP,true) or shape._near(p,taken,room): continue
		if not ok.call(p): continue
		return p
	return null

static func _count(rng: RandomNumberGenerator, mean: float) -> int:
	mean *= rng.randf_range(0.75,1.25)
	return int(mean)+(1 if rng.randf() < mean-floorf(mean) else 0)

static func _weighted(pool: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in pool: total += float(pool[k])
	roll *= total
	for k in pool:
		roll -= float(pool[k])
		if roll <= 0.0: return k
	return pool.keys()[0]

## A crown colour for `tree` (Stands TREE_COLOURS), as a record tint.
static func _tint(tree: String, rng: RandomNumberGenerator) -> String:
	if not Stands.TREE_COLOURS.has(tree): return ""
	var options: Array = Stands.TREE_COLOURS[tree]
	var pool := {}
	for n in range(options.size()): pool[str(n)] = float(options[n][1])
	var pick := int(_weighted(pool,rng.randf()))
	var color := Color(options[pick][0]).srgb_to_linear()*rng.randf_range(Stands.TREE_BRIGHTNESS.x,Stands.TREE_BRIGHTNESS.y)
	return NativeObjectPose.encode_tint(Color(minf(color.r,1.0),minf(color.g,1.0),minf(color.b,1.0)))
