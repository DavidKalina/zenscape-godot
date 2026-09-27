extends RefCounted
## Life arrives on the land you made, in its own time (docs/scenic/emergence.md).
##
## A finished stroke hands its dirty rect to `on_region_changed`. The region
## then runs a succession: grass creeps out from its wettest ground, shrubs
## follow, trees come last. Nothing is placed by the player; every plant is a
## lattice candidate whose jitter, kind and chance come from position hashes,
## tested against the live biome blend at the moment it arrives.
##
## Hand work wins. Cover cells marked hand and objects that are hand-placed,
## pinned or generated are never changed; emergence only adds, and withdraws
## only what it grew itself.
##
## `advance` applies changes in steps of `STEP` seconds and returns true when
## the caller should refresh the view once. Every arrival is stamped with its
## own birth on `time`, a little ahead of the step, and the shaders grow it in
## from there with the regrow pop, so arrivals rise one by one rather than
## switching on a step at a time. Plants that stood before carry no birth.
const Variety = preload("res://scripts/seeded_variety.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const Shape = preload("res://scripts/native_formation_shape.gd")
const LandIntent = preload("res://scripts/land_intent.gd")

## An emerged tree was placed at plate point `p`; it grows in from `born` on
## `time` over TREE_RISE. Stroke feedback sends a little gust to settle it.
signal tree_arrived(p: Vector2, born: float)

## Seconds after a stroke before the first grass shows.
const GRASS_DELAY := 1.5
## Metres per second the grass front creeps out from the wettest ground.
const GRASS_SPEED := 1.4
## Seconds one cell takes to fill once the front has reached it.
const GRASS_RISE := 2.5
## Shrubs and trees arrive over [DELAY, DELAY+SPREAD] seconds, nearer the
## wettest ground first, so a raised hill fills in from its foot.
const SHRUB_DELAY := 9.0
const SHRUB_SPREAD := 12.0
const TREE_DELAY := 18.0
const TREE_SPREAD := 20.0
## One view refresh per step; GardenView rebuilds the whole plate today.
const STEP := 0.75
## Seconds an arrival takes to rise from the ground and overshoot into place:
## the regrow pop (shaders/reference_surface.gdshader), run per plant at its
## own birth. Meadow tufts of the blades cover rise like shrubs, only quicker.
const TREE_RISE := 1.8
const SHRUB_RISE := 1.1
const TUFT_RISE := 0.8
## Dense grass (shaders/dense_grass.gdshader): a cell's new tufts start over
## COVER_CREEP seconds from its birth, each rising over COVER_RISE. The creep
## spans the cell's cover climb plus the grass mask's rebake.
const COVER_CREEP := 3.0
const COVER_RISE := 1.4
## Candidate lattices in metres, and the free ground each arrival needs.
const SHRUB_LATTICE := 0.9
const TREE_LATTICE := 1.3
const TREE_GAP := 1.1
const SHRUB_GAP := 0.45
## Plants stay inside the band the generator plants.
const PLATE := 11.0
## Metres² the generator's per-habitat tree counts are spread over.
const PLANTED_AREA := 462.0
const TREES := ["tree","layered_tree","broadleaf","redwood","joshua","cactus"]
## Forest intent (scripts/forest_brush.gd, docs/scenic/brushes.md). Where the
## forest brush wished for forest, shrubs and trees come sooner and the core
## fills first; a forest stroke plans only candidates inside its wish.
const FOREST_SHRUB_DELAY := 9.0
const FOREST_SHRUB_SPREAD := 14.0
const FOREST_TREE_DELAY := 5.0
const FOREST_TREE_SPREAD := 18.0
## Tree chance from the frayed edge of the wish to its core, and where along
## the frayed wish the edge starts and the core is reached.
const FOREST_EDGE_CHANCE := 0.1
const FOREST_CORE_CHANCE := 0.9
const FOREST_EDGE := Vector2(0.1,0.6)
## How far the edge frays, in wish units: per-candidate scatter and slow lobes
## (FOREST_LOBE_FREQUENCY, 1/m), so the outline is ragged rather than round.
const FOREST_RAGGED := 0.45
const FOREST_LOBES := 0.35
const FOREST_LOBE_FREQUENCY := 0.28
## Shrub chance along the margin (a band of the frayed wish), and under canopy.
const FOREST_MARGIN := Vector4(0.02,0.25,0.5,0.8)
const FOREST_MARGIN_SHRUBS := 0.45
const FOREST_UNDER_SHRUBS := 0.12

## The clock births are stamped on, published as `zs_emergence_time`. Shared
## and never reset, so a birth can never sit in a later world's future.
static var time := 0.0

var data: NativeTerrainData
## What the creation brushes asked of the ground (scripts/land_intent.gd).
var intent: RefCounted
var _lobes: FastNoiseLite
var _lobes_salt := 0
## World key for every hash. Two worlds with the same strokes differ by it.
var salt := 0
var _fixed_salt := false
var enabled := true
var _blend: RefCounted
var _regions: Array[Dictionary] = []
## Finished strokes wait here for the next step, so a stroke's release never
## pays for planning (the first plan on a world also builds the live blend).
var _queued: Array[Dictionary] = []
var _clock := 0.0
var _since_step := 0.0
var _pending_refresh := false
var _crowd := {}
var _crowd_built := false
## Why candidates did not take, by reason; for probes and tuning.
var refusals := {}

func _init(terrain: NativeTerrainData, world_salt := -1) -> void:
	data = terrain
	_fixed_salt = world_salt >= 0
	salt = world_salt if _fixed_salt else randi()
	intent = LandIntent.new(data)
	# Undo, load and new worlds replace the ground the plan was made for.
	data.state_restored.connect(func(_state: Dictionary) -> void: clear())

## Planned work still to come, for probes and UI.
func busy() -> bool:
	return not _regions.is_empty() or not _queued.is_empty() or _pending_refresh

func clear() -> void:
	_regions.clear()
	_queued.clear()
	_blend = null
	_pending_refresh = false

## Entry point for a finished stroke. `rect` is in plate metres. `source`
## "forest" is a forest brush stroke: it plans only what its wish asks for,
## leaves cover alone and does not replan other strokes' work.
func on_region_changed(rect: Rect2, source := "") -> void:
	if not enabled:
		return
	rect = rect.intersection(Rect2(-14,-14,28,28))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		_queued.append({"rect":rect,"born":_clock,"source":source})

func _plan(rect: Rect2, born: float, source := "") -> void:
	if _blend == null:
		_blend = BiomeBlend.live(data)
		# A generated world keys its life to its planting seed; a blank plain
		# keeps the session's draw.
		if not _fixed_salt and int(_blend._genome.plant_seed) != 0:
			salt = Variety.mix([int(_blend._genome.plant_seed),97])
	else:
		_blend.refresh_rect(rect)
	var forest := source == "forest"
	# A newer stroke replans the ground it covers. A forest stroke only adds:
	# a candidate planned twice lands once, the second is crowded out.
	if not forest:
		for region in _regions:
			_forget(region,rect)
	_withdraw(rect)
	var region := {"rect":rect,"born":born,"cells":PackedInt32Array(),"fronts":PackedFloat32Array(),"targets":PackedVector2Array(),"plants":[],"next":0}
	var origin := _origin(rect)
	var side := data.MEADOW_CELLS
	for z in range(side if not forest else 0):
		for x in range(side):
			var p := data.meadow_position(x,z)+Vector2.ONE*data.MEADOW_STEP*0.5
			if not rect.has_point(p):
				continue
			var index := z*side+x
			if data.provenance[index] == NativeTerrainData.SOURCE_HAND:
				continue
			var target := _cover_target(p)
			if target.x < 0.0:
				continue
			region.cells.append(index)
			region.targets.append(target)
			region.fronts.append(GRASS_DELAY+p.distance_to(origin)/GRASS_SPEED+Variety.unit([salt,11,index])*0.6)
	var reach := maxf(rect.size.length()*0.5,1.0)
	for layer in [["shrub",SHRUB_LATTICE,SHRUB_DELAY,SHRUB_SPREAD],["tree",TREE_LATTICE,TREE_DELAY,TREE_SPREAD]]:
		var lattice: float = layer[1]
		for j in range(floori(rect.position.y/lattice),ceili(rect.end.y/lattice)):
			for i in range(floori(rect.position.x/lattice),ceili(rect.end.x/lattice)):
				var key := [salt,layer[0].hash(),i,j]
				var p := (Vector2(i,j)+Vector2(Variety.unit(key+[1]),Variety.unit(key+[2])))*lattice
				if not rect.has_point(p) or maxf(absf(p.x),absf(p.y)) > PLATE:
					continue
				var wish: float = intent.forest_at(p)
				if forest and _frayed(p,key,wish) <= FOREST_MARGIN.x:
					continue
				var at: float = layer[2]+layer[3]*(0.55*clampf(p.distance_to(origin)/reach,0.0,1.0)+0.45*Variety.unit(key+[3]))
				if wish > 0.05:
					# Wished-for forest comes sooner, its core first.
					var tree: bool = layer[0] == "tree"
					at = (FOREST_TREE_DELAY if tree else FOREST_SHRUB_DELAY)+(FOREST_TREE_SPREAD if tree else FOREST_SHRUB_SPREAD)*(0.6*(1.0-wish)+0.4*Variety.unit(key+[3]))
				region.plants.append({"at":at,"layer":layer[0],"p":p,"key":key,"forest":forest})
	region.plants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	_regions.append(region)

## Seconds an emerged record of `asset` takes to grow in.
static func rise_seconds(asset: String) -> float:
	return TREE_RISE if asset in TREES else SHRUB_RISE

## Move world time on. True means cover or objects changed: refresh once.
## The clock runs even when idle, so the last arrivals finish growing.
func advance(seconds: float) -> bool:
	time += seconds
	RenderingServer.global_shader_parameter_set(&"zs_emergence_time",time)
	if not enabled or not busy():
		return false
	# Never write into an open stroke; its undo record must stay the player's.
	if not data._before.is_empty():
		return false
	_clock += seconds
	_since_step += seconds
	if _since_step < STEP:
		return false
	_since_step = 0.0
	var changed := _pending_refresh
	_pending_refresh = false
	_crowd.clear()
	_crowd_built = false
	for queued in _queued:
		_plan(queued.rect,queued.born,queued.get("source",""))
	_queued.clear()
	for r in range(_regions.size()-1,-1,-1):
		var region: Dictionary = _regions[r]
		var age: float = _clock-region.born
		if _grow_cover(region,age): changed = true
		while region.next < region.plants.size() and region.plants[region.next].at <= age:
			var plant: Dictionary = region.plants[region.next]
			# Born at its own moment one step on, so this step's arrivals rise
			# spread through the next step instead of all at once.
			if _arrive(plant,time+clampf(plant.at-age+STEP,0.0,STEP)): changed = true
			region.next += 1
		if region.cells.is_empty() and region.next >= region.plants.size():
			_regions.remove_at(r)
	_forget_grown_cover()
	return changed

func _grow_cover(region: Dictionary, age: float) -> bool:
	var changed := false
	var rate := STEP/GRASS_RISE
	var k := 0
	while k < region.cells.size():
		if age < region.fronts[k]:
			k += 1
			continue
		var index: int = region.cells[k]
		var target: Vector2 = region.targets[k]
		var done := true
		if data.provenance[index] != NativeTerrainData.SOURCE_HAND:
			# Generated cover only thickens; emerged cover follows its ground.
			var generated := data.provenance[index] == NativeTerrainData.SOURCE_GENERATED
			var grass := data.grass[index]
			var blades := data.blades[index]
			var next_grass := move_toward(grass,maxf(target.x,grass) if generated else target.x,rate)
			var next_blades := move_toward(blades,maxf(target.y,blades) if generated else target.y,rate*0.6)
			if absf(next_grass-grass) > 0.0005 or absf(next_blades-blades) > 0.0005:
				var tufts := int(data.grass_density(index)*8.0)
				data.grass[index] = next_grass
				data.blades[index] = next_blades
				data.provenance[index] = NativeTerrainData.SOURCE_EMERGED
				# The front reached this cell at its own moment; stamp that, one
				# step on, so the creep stays smooth between steps.
				_stamp_cover(index,grass,tufts,time+clampf(float(region.fronts[k])-age+STEP,0.0,STEP))
				changed = true
				done = false
		if done:
			region.cells.remove_at(k)
			region.fronts.remove_at(k)
			region.targets.remove_at(k)
		else:
			k += 1
	return changed

## Record a cover change's grow-in for the views (data.cover_births). A cell
## keeps its birth while it is still creeping in; a later change after that
## starts a new one over what then stands. Meadow tufts the change added are
## born through the next step; ones it took away lose their birth.
func _stamp_cover(index: int, prior: float, tufts_before: int, born: float) -> void:
	var birth: Dictionary = data.cover_births.get(index,{})
	if birth.is_empty() or time-float(birth.born) > COVER_CREEP+COVER_RISE:
		var kept: PackedFloat32Array = birth.get("tufts",PackedFloat32Array())
		if kept.is_empty():
			kept.resize(8)
			kept.fill(-1.0)
		birth = {"born":born,"prior":prior,"tufts":kept}
		data.cover_births[index] = birth
	var tufts: PackedFloat32Array = birth.tufts
	var after := mini(int(data.grass_density(index)*8.0),8)
	for i in range(mini(tufts_before,after),maxi(tufts_before,after)):
		tufts[i] = time+Variety.unit([salt,13,index,i])*STEP if after > tufts_before else -1.0
	birth.tufts = tufts
	data.cover_births_revision += 1

## Drop births that have finished growing, so the maps stay small.
func _forget_grown_cover() -> void:
	var settled := time-COVER_CREEP-COVER_RISE-1.0
	var forgot := false
	for index: int in data.cover_births.keys():
		var birth: Dictionary = data.cover_births[index]
		if float(birth.born) > settled: continue
		var growing := false
		for born in birth.tufts:
			if born > time-TUFT_RISE-1.0: growing = true
		if growing: continue
		data.cover_births.erase(index)
		forgot = true
	if forgot: data.cover_births_revision += 1

## Grass and standing-blade cover the ground asks for, or x < 0 to leave the
## cell alone (outside the land, or under water).
func _cover_target(p: Vector2) -> Vector2:
	var h: Variant = data.ground_height(p)
	if h == null or _wet(p):
		return Vector2(-1,-1)
	var biome: Dictionary = Shape.BIOMES[_blend.pick(p)]
	var snow := _snowline()
	var bare := smoothstep(float(biome.rock_slope)*0.75,float(biome.rock_slope)*1.1,_slope(p))
	var grass: float = _blend.cover(p)*(1.0-bare)*(1.0-smoothstep(snow-1.8,snow,float(h)))
	# Emerged cover is painted ground only, never standing blades: the
	# faceted green reads as the diorama's grass (user choice, 2026-09-26).
	return Vector2(grass,0.0)

func _arrive(plant: Dictionary, born: float) -> bool:
	var p: Vector2 = plant.p
	var h: Variant = data.ground_height(p)
	if h == null or _wet(p):
		return _refuse("water")
	var cell := Vector2i(((p+Vector2(14,14))/data.MEADOW_STEP).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(data.MEADOW_CELLS-1))
	if data.provenance[cell.y*data.MEADOW_CELLS+cell.x] == NativeTerrainData.SOURCE_HAND:
		return _refuse("hand")
	var habitat: String = _blend.pick(p)
	var biome: Dictionary = Shape.BIOMES[habitat]
	var slope := _slope(p)
	# Nothing takes on bare rock or snow.
	if slope > float(biome.rock_slope) or float(h) > _snowline()-1.8:
		return _refuse("rock or snow")
	var key: Array = plant.key
	var roll := Variety.unit(key+[4])
	var kind := ""
	var wish: float = intent.forest_at(p)
	var frayed := _frayed(p,key,wish)
	var only_wish: bool = plant.get("forest",false)
	if plant.layer == "tree":
		if float(h) > _treeline(habitat):
			return _refuse("treeline")
		var chance := float(biome.trees)/PLANTED_AREA*TREE_LATTICE*TREE_LATTICE*_tree_density()
		if habitat == "wetland": chance *= 0.3
		if wish > 0.0:
			# A dense core, thinning to scattered trees at the frayed edge.
			var wished := 0.0 if frayed < FOREST_EDGE.x else lerpf(FOREST_EDGE_CHANCE,FOREST_CORE_CHANCE,smoothstep(FOREST_EDGE.x,FOREST_EDGE.y,frayed))
			chance = wished if only_wish else maxf(chance,wished)
		elif wish < 0.0:
			chance *= 1.0+wish
		# Forests thin out as the ground steepens toward rock.
		chance *= 1.0-smoothstep(0.45,float(biome.rock_slope),slope)
		if roll >= minf(chance,0.85):
			return _refuse("thinned")
		kind = _tree_kind(habitat,Variety.unit(key+[5]))
	else:
		if slope > 0.6 or float(h) > _treeline(habitat)+1.5:
			return _refuse("steep or high")
		var chance: float = {"meadow":0.35,"woodland":0.22,"redwood":0.3,"alpine":0.14,"arid":0.1,"wetland":0.45}.get(habitat,0.2)
		if wish > 0.0:
			# Shrubs gather along the forest's margin, a few under its canopy.
			var margin := smoothstep(FOREST_MARGIN.x,FOREST_MARGIN.y,frayed)*(1.0-smoothstep(FOREST_MARGIN.z,FOREST_MARGIN.w,frayed))
			var wished := FOREST_MARGIN_SHRUBS*margin+FOREST_UNDER_SHRUBS*smoothstep(FOREST_MARGIN.z,FOREST_MARGIN.w,frayed)
			chance = wished if only_wish else maxf(chance,wished)
			if habitat == "meadow": habitat = "woodland"
		elif wish < 0.0:
			chance *= 1.0+wish
		if roll >= chance:
			return _refuse("thinned")
		kind = _shrub_kind(habitat,p,Variety.unit(key+[5]))
	if _crowded(p,plant.layer == "tree"):
		return _refuse("crowded")
	var size := lerpf(0.6,1.05,Variety.unit(key+[6])) if plant.layer == "tree" else lerpf(0.5,0.9,Variety.unit(key+[6]))
	var id := data.place(kind,p,Variety.unit(key+[7])*TAU,size)
	if id < 0:
		return false
	data.objects.back()["source"] = "emerged"
	data.objects.back()["born"] = born
	_crowd.get_or_add(Vector2i(p.floor()),[]).append(Vector3(p.x,p.y,1.0 if kind in TREES else 0.0))
	if kind in TREES: tree_arrived.emit(p,born)
	return true

## The forest wish at a candidate, frayed by its own scatter and slow lobes,
## so the forest's outline is ragged and its edge trees stand apart.
func _frayed(p: Vector2, key: Array, wish: float) -> float:
	if wish <= 0.0:
		return wish
	if _lobes == null or _lobes_salt != salt:
		_lobes_salt = salt
		_lobes = FastNoiseLite.new()
		_lobes.seed = salt
		_lobes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_lobes.frequency = FOREST_LOBE_FREQUENCY
	return wish+(Variety.unit(key+[8])-0.5)*FOREST_RAGGED+_lobes.get_noise_2d(p.x,p.y)*FOREST_LOBES

func _refuse(reason: String) -> bool:
	refusals[reason] = refusals.get(reason,0)+1
	return false

func _tree_kind(habitat: String, pick: float) -> String:
	match habitat:
		"woodland": return "layered_tree" if pick < 0.15 else "broadleaf" if pick < 0.6 else "tree"
		"redwood": return "redwood"
		"arid": return "joshua" if pick < 0.55 else "cactus"
		"meadow","wetland": return "broadleaf"
	return "tree"

func _shrub_kind(habitat: String, p: Vector2, pick: float) -> String:
	match habitat:
		"wetland": return "reeds" if _blend.water_distance(p) < 1.6 else "bank_grass"
		"meadow":
			var flowers := ["grass_tuft","daisy_flower","button_flower","spike_flower","umbel_flower"]
			var weights := [1.2,1.0,1.0,1.0,0.4]
			for n in range(flowers.size()): weights[n] *= Variety.lean(salt,flowers[n])
			return flowers[Variety.weighted(weights,pick)]
		"woodland","redwood":
			var kinds := ["fern","shrub","grass_tuft","mushroom"]
			var weights := [1.5 if habitat == "redwood" else 1.0,0.8,0.8,0.25]
			for n in range(kinds.size()): weights[n] *= Variety.lean(salt,kinds[n])
			return kinds[Variety.weighted(weights,pick)]
		"arid": return "shrub" if pick < 0.8 else "grass_tuft"
	return "grass_tuft"

func _crowded(p: Vector2, tree: bool) -> bool:
	if not _crowd_built:
		_crowd_built = true
		for item in data.objects:
			if item.asset == "waterfall": continue
			_crowd.get_or_add(Vector2i(floori(item.x),floori(item.z)),[]).append(Vector3(item.x,item.z,1.0 if item.asset in TREES else 0.0))
	var base := Vector2i(p.floor())
	for dz in range(-2,3):
		for dx in range(-2,3):
			for other: Vector3 in _crowd.get(base+Vector2i(dx,dz),[]):
				var gap := SHRUB_GAP
				if tree: gap = TREE_GAP if other.z > 0.5 else 0.6
				elif other.z > 0.5: gap = 0.6
				if p.distance_squared_to(Vector2(other.x,other.y)) < gap*gap:
					return true
	return false

## Withdraw emerged plants the new ground no longer supports: drowned, on bare
## rock or under snow. Hand, pinned and generated objects stay.
func _withdraw(rect: Rect2) -> void:
	var removed := false
	for index in range(data.objects.size()-1,-1,-1):
		var item: Dictionary = data.objects[index]
		var p := Vector2(item.x,item.z)
		if NativeTerrainData.object_source(item) != "emerged" or not rect.has_point(p):
			continue
		var h: Variant = data.ground_height(p)
		var biome: Dictionary = Shape.BIOMES[_blend.pick(p)]
		if h == null or _wet(p) or _slope(p) > float(biome.rock_slope)*1.1 or float(h) > _snowline()-1.0:
			data.objects.remove_at(index)
			removed = true
	if removed:
		data.objects_revision += 1
		_pending_refresh = true

## Grass spreads from the wettest ground in the region, lowest on a tie.
func _origin(rect: Rect2) -> Vector2:
	var best := rect.get_center()
	var score := -INF
	for z in range(ceili(rect.size.y)+1):
		for x in range(ceili(rect.size.x)+1):
			var p := (rect.position+Vector2(x,z)).clamp(rect.position,rect.end)
			if data.ground_height(p) == null: continue
			var value: float = _blend.moisture(p)-0.02*float(data.ground_height(p))
			if value > score:
				score = value
				best = p
	return best

## Carried-over work inside a newer stroke's rect is replanned by that stroke.
func _forget(region: Dictionary, rect: Rect2) -> void:
	var side := data.MEADOW_CELLS
	for k in range(region.cells.size()-1,-1,-1):
		var index: int = region.cells[k]
		if rect.has_point(data.meadow_position(index%side,index/side)+Vector2.ONE*data.MEADOW_STEP*0.5):
			region.cells.remove_at(k)
			region.fronts.remove_at(k)
			region.targets.remove_at(k)
	var kept: Array = region.plants.slice(region.next).filter(func(plant: Dictionary) -> bool: return not rect.has_point(plant.p))
	region.plants = kept
	region.next = 0

func _wet(p: Vector2) -> bool:
	return _blend._sampler.wet(p)

func _slope(p: Vector2) -> float:
	return preload("res://scripts/native_landscape_presets.gd")._slope(data,p)

func _snowline() -> float:
	return BiomeBlend.snowline(data._recipe_settings,data._palette.snowline)

func _treeline(habitat: String) -> float:
	if habitat == "alpine":
		return float(_blend._genome.get("treeline",Shape.BIOMES.alpine.treeline))
	return 10.0

func _tree_density() -> float:
	return float(_blend._genome.get("tree_density",1.0))
