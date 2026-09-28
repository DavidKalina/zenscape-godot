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
const WaterBrush = preload("res://scripts/water_brush.gd")
const Guidance = preload("res://scripts/quiet_guidance.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")
const Stands = preload("res://scripts/tree_stands.gd")

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
## Where emerged grass gives way to bare ground, in shares of the habitat's
## rock slope: full grass below .x, none above .y. Gentle hills stay green;
## only real steeps go bare (the plain's rock slope is 0.93).
const BARE_SLOPE := Vector2(0.9,1.15)
## Emerged plant sizes (record scale): trees and undergrowth draw from these
## ranges, and a kind's own factor brings the models into proportion with each
## other and with the creatures (scripts/life_models.gd: a deer stands about
## 1.2 m, a heron about 1.1 m). At scale 1 the layered broadleaf is 5.9 m tall
## and as wide, the spruce family 2.5-4.5 m, the hero oak 1.9 m, and the fern
## 1.6 m across. The birch (3.4 m), willow (2.7 m tall, 2.6 m across) and
## juniper (1.6 m tall, 2.9 m across) are sized in scripts/hero_trees.gd, so
## a birch tops the oaks and a juniper stands at a deer's shoulder; the
## willow's broad curtain reads large, so it grows a little under the oaks.
const TREE_SIZE := Vector2(0.65,1.0)
const SHRUB_SIZE := Vector2(0.5,0.9)
const KIND_SIZE := {"layered_tree":0.55,"broadleaf":1.45,"redwood":0.6,"fern":0.6,"birch":1.0,"willow":0.9,"juniper":1.0}
## Ferns read as dark spiders from above; woodland undergrowth takes few.
const FERN_WEIGHT := 0.3
## Plants stay inside the band the generator plants.
const PLATE := 11.0
## Metres² the generator's per-habitat tree counts are spread over.
const PLANTED_AREA := 462.0
## Tree species, crown colours and autumn come by stand (scripts/tree_stands.gd),
## shared with generated worlds.
const TREES := ["tree","layered_tree","broadleaf","redwood","joshua","cactus","birch","willow","juniper"]
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
## Sown forest (scripts/seed_handful.gd, docs/scenic/brushes.md "Seed
## sprinkle"). A sprinkle stroke's region carries its landed seeds. Each is a tree
## candidate of its own at its landing point, which comes up first: at
## SOWN_DELAY plus up to SOWN_STAGGER, taking at SOWN_TAKE (thinned on steep
## ground as any tree is). The region's lattice candidates then arrive by
## their distance from the nearest seed, SOWN_SPREAD m a second after
## SOWN_TREE_DELAY (trees) or SOWN_SHRUB_DELAY (shrubs), plus up to
## SOWN_JITTER, so the forest spreads out from where the seeds fell.
const SOWN_DELAY := 1.2
const SOWN_STAGGER := 2.0
const SOWN_TAKE := 0.8
const SOWN_TREE_DELAY := 4.0
const SOWN_SHRUB_DELAY := 7.0
const SOWN_SPREAD := 0.4
const SOWN_JITTER := 5.0
## Dead wood: a standing snag, a fallen log or a stump now and then takes a
## tree's place, so a wood reads old and lived-in. It goes by stand: DEAD_OLD
## of stands are old (more on high, dry ground), and a tree there comes up
## dead at DEAD_SHARE.y, a young stand's at DEAD_SHARE.x. Dry, high and steep
## ground lean it up to DEAD_HARSH times, a forest's dense core by DEAD_CORE,
## to DEAD_MAX at most; open meadow grows none. Pieces keep DEAD_GAP apart,
## and no more than DEAD_CLUSTER stand within DEAD_REACH, so none reads as a
## woodpile nor an old stand as a dead one; one without room stays a living
## tree. A painted forest whose stands all drew young names its eldest old (a
## stand counts from ELDER_MIN wished tree candidates), so every forest the
## player paints shows a few pieces.
const DEAD_KINDS := ["snag","log","stump"]
const DEAD_OLD := Vector2(0.25,0.55)
const DEAD_SHARE := Vector2(0.025,0.22)
const DEAD_HARSH := Vector2(0.6,1.7)
const DEAD_CORE := 0.6
const DEAD_MAX := 0.28
const DEAD_HABITAT := {"meadow":0.0,"wetland":0.4,"arid":0.25,"alpine":1.2}
const DEAD_GAP := 2.6
const DEAD_REACH := 5.0
const DEAD_CLUSTER := 3
const ELDER_MIN := 8
## Snag height and width, log length and girth, stump size (record scale);
## the emerged woods stand at about two thirds of the source's, but a snag
## keeps nearer its full height and some girth, so its grey pole and broken
## top stand clear of the crowns as a silhouette from the diorama camera.
const SNAG_SIZE := Vector4(2.3,3.3,1.2,1.55)
const LOG_SIZE := Vector4(1.1,1.9,0.75,1.0)
const STUMP_SIZE := Vector2(0.6,0.95)
## Weathered wood: gentle multipliers over the models' own browns (sRGB, so
## near white; a tint can only darken). The snag's own wood is already a
## pale warm grey (the source's LITTER_SILVER) and the sky's blue fill cools
## it, so a blue tint rendered lavender slate: these stay near neutral to
## read silver, or leave it grey-brown; never a fire's near-black.
const DEAD_COLOURS := {
	"snag":[["f4f2ee",1.0],["eef0f0",0.7],["f8f0e6",0.4]],
	"log":[["eef0f2",1.0],["f4ede4",0.8]],
	"stump":[["f4ede4",1.0],["e6ebf2",0.7]],
}
## Old and high stands let the spruce family's dead-top variant lean up to
## this share of their spruces (it is otherwise a 1 in 23 accent).
const DEAD_TOPS := 0.3

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
## Stands painted forests named old (`_elder`), by str(key); for probes.
var elders := {}
## Plan queued strokes on a worker, over a detached copy of the ground, and
## take the regions in on a later frame. The editor turns this on; probes that
## drive `advance` in a tight loop plan on the calling thread.
var plan_on_worker := false
## The editor sets this while a finished stroke's ground is still settling
## (land weathering on a worker); planning waits for it.
var ground_settling := false
var _plan_job: RefCounted
var _plan_generation := 0
## Main-thread planning time of the last plan (install only, when on a worker)
## and the worker's time, for profiles.
var last_plan_usec := {}
## Ponds a pour has just filled (`drown`), kept until a plan that saw them
## replaces the blend's pond raster: {"level", "cells", "rect", "record",
## "stamp"}. Until then `_wet` reads them too, so nothing arrives in them.
var _fresh_ponds: Array[Dictionary] = []
## Quiet guidance (scripts/quiet_guidance.gd): each plan reads its region's
## score and steers edges, lone trees, sightlines, sizes and spacing a
## little. Off with --no-guidance. `guided_usec` is the last plan's guide
## time, and `guided_sizes` how many sizes leaned up or down, for probes.
var guided: bool = Guidance.enabled
var guided_usec := 0
var guided_sizes := {"up":0,"down":0}
## A planner's plants near its rects (Guidance.plants), taken on the main
## thread; null on the main Emergence, which reads `data.objects`.
var _guide_plants: Variant = null

func _init(terrain: NativeTerrainData, world_salt := -1) -> void:
	data = terrain
	_fixed_salt = world_salt >= 0
	salt = world_salt if _fixed_salt else randi()
	intent = LandIntent.new(data)
	# Undo, load and new worlds replace the ground the plan was made for.
	data.state_restored.connect(func(_state: Dictionary) -> void: clear())

## Planned work still to come, for probes and UI.
func busy() -> bool:
	return not _regions.is_empty() or not _queued.is_empty() or _pending_refresh or _plan_job != null

func clear() -> void:
	_regions.clear()
	_queued.clear()
	elders.clear()
	_blend = null
	_pending_refresh = false
	# A plan still on its worker was made for the ground being left.
	_plan_generation += 1
	_plan_job = null
	_fresh_ponds.clear()

## Entry point for a finished stroke. `rect` is in plate metres. `source`
## "forest" is a forest brush stroke: it plans only what its wish asks for,
## leaves cover alone and does not replan other strokes' work. `sown` are a
## seed sprinkle's landed seeds (plate x, z), where its forest starts.
func on_region_changed(rect: Rect2, source := "", sown := PackedVector2Array()) -> void:
	if not enabled:
		return
	rect = rect.intersection(Rect2(-14,-14,28,28))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		_queued.append({"rect":rect,"born":_clock,"source":source,"sown":sown})

func _plan(rect: Rect2, born: float, source := "", sown := PackedVector2Array()) -> void:
	_refresh_blend([rect])
	# The blend's pond raster was just read from the live ground.
	_fresh_ponds.clear()
	_install(rect,source,_plan_region(rect,born,source,sown))

## Build the live blend, or re-read it under `rects`. The first build sets the
## salt: a generated world keys its life to its planting seed; a blank plain
## keeps the session's draw.
func _refresh_blend(rects: Array) -> void:
	if _blend == null:
		_blend = BiomeBlend.live(data)
		if not _fixed_salt and int(_blend._genome.plant_seed) != 0:
			salt = Variety.mix([int(_blend._genome.plant_seed),97])
		return
	for rect: Rect2 in rects: _blend.refresh_rect(rect)

## Take a planned region in. A newer stroke replans the ground it covers. A
## forest stroke only adds: a candidate planned twice lands once, the second
## is crowded out.
func _install(rect: Rect2, source: String, region: Dictionary) -> void:
	if source != "forest":
		for other in _regions:
			_forget(other,rect)
	_withdraw(rect)
	if region.has("elder"): elders[str(region.elder)] = true
	_regions.append(region)

## Plan every queued stroke on a worker. The planner is a second Emergence
## over a detached copy of the ground: heights, provenance, water, the recipe
## settings and the forest wish as they stand now. It builds or refreshes a
## copy of the blend, so the live one stays readable here meanwhile. The
## regions, the blend and the salt come back together; `_install` runs here.
func _plan_async(queued: Array[Dictionary]) -> void:
	var began := Time.get_ticks_usec()
	var ground: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	ground.provenance = data.provenance.duplicate()
	ground.ponds.assign(data.ponds.duplicate(true))
	ground.streams.assign(data.streams.duplicate(true))
	ground.landscape_waterfall = data.landscape_waterfall
	ground._recipe_settings = data._recipe_settings.duplicate(true)
	ground._recipe_heights = data._recipe_heights.duplicate()
	ground._water_grid_h = data._water_grid_h.duplicate()
	ground._palette = data._palette
	# A recipe world's pond flood reads its impacts and ramp from the live
	# recipe; take them here, as GardenView's worker flood does.
	var recipe_water := {}
	if data._recipe != null and not data.ponds.is_empty():
		recipe_water = {"impacts":data.waterfall_impacts(),"ramp":NativeRecipeWater.water_ramp(data._recipe.source.g.get("water",{}))}
	var settings: Dictionary = BiomeBlend.live_settings(data) if _blend == null else {}
	var previous: RefCounted = _blend
	var planner = get_script().new(ground,salt)
	planner.intent.forest = intent.forest.duplicate()
	planner.guided = guided
	if guided:
		var reach: Rect2 = queued[0].rect
		for item: Dictionary in queued: reach = reach.merge(item.rect)
		planner._guide_plants = Guidance.plants(data.objects,reach,TREES)
	var fixed := _fixed_salt
	var jobs := queued.duplicate(true)
	_plan_generation += 1
	var generation := _plan_generation
	var job = preload("res://scripts/background_work.gd").new()
	_plan_job = job
	job.start(func() -> Dictionary:
		var worker_began := Time.get_ticks_usec()
		var rects := []
		for item: Dictionary in jobs: rects.append(item.rect)
		if previous == null:
			planner._blend = BiomeBlend.live_on(settings,ground,recipe_water)
			if not fixed and int(planner._blend._genome.plant_seed) != 0:
				planner.salt = Variety.mix([int(planner._blend._genome.plant_seed),97])
		else:
			planner._blend = previous.copy_onto(BiomeBlend.LiveGround.new(ground,recipe_water,false))
			for rect: Rect2 in rects: planner._blend.refresh_rect(rect)
		var regions := []
		for item: Dictionary in jobs: regions.append(planner._plan_region(item.rect,item.born,item.get("source",""),item.get("sown",PackedVector2Array())))
		return {"blend":planner._blend,"salt":planner.salt,"regions":regions,"usec":Time.get_ticks_usec()-worker_began,"guide_usec":planner.guided_usec})
	last_plan_usec = {"start":Time.get_ticks_usec()-began}
	# A superseded job still runs out here, so dropping it never blocks a frame.
	while not job.completed():
		await Engine.get_main_loop().process_frame
	began = Time.get_ticks_usec()
	var planned: Dictionary = job.finish()
	if generation != _plan_generation: return
	_plan_job = null
	_blend = planned.blend
	# The blend reads the live ground from here on; its pond raster stays the
	# one planned against until the next refresh, as before.
	_blend._sampler.data = data
	_blend._sampler.recipe_water = {}
	salt = planned.salt
	# Ponds poured after this plan began are not in its raster yet.
	_fresh_ponds = _fresh_ponds.filter(func(pond: Dictionary) -> bool: return int(pond.stamp) >= generation)
	for i in range(jobs.size()):
		_install(jobs[i].rect,jobs[i].get("source",""),planned.regions[i])
	last_plan_usec.worker = planned.usec
	last_plan_usec.install = Time.get_ticks_usec()-began
	last_plan_usec.guide = planned.guide_usec
	guided_usec = planned.guide_usec

## The succession for one stroke's rect: cover cells with their fronts and
## targets, and the shrub and tree candidates in arrival order. Reads only
## `data`, the blend, the forest wish and the salt, so it runs on a planner.
func _plan_region(rect: Rect2, born: float, source := "", sown := PackedVector2Array()) -> Dictionary:
	var forest := source == "forest"
	var region := {"rect":rect,"born":born,"cells":PackedInt32Array(),"fronts":PackedFloat32Array(),"targets":PackedVector2Array(),"plants":[],"next":0}
	# Quiet guidance: the region's score and the fields its nudges read.
	var guide: RefCounted = null
	var known := PackedVector4Array()
	if guided:
		known = _guide_plants if _guide_plants != null else Guidance.plants(data.objects,rect,TREES)
		guide = Guidance.plan(self,rect,known)
		guided_usec = guide.usec
		region["score"] = guide.score
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
	# A guided forest's edge may bulge past the stroke's own bounds.
	var span := rect.grow(Guidance.WARP) if forest and guide != null else rect
	var wished := PackedVector2Array()
	for layer in [["shrub",SHRUB_LATTICE,SHRUB_DELAY,SHRUB_SPREAD],["tree",TREE_LATTICE,TREE_DELAY,TREE_SPREAD]]:
		var lattice: float = layer[1]
		for j in range(floori(span.position.y/lattice),ceili(span.end.y/lattice)):
			for i in range(floori(span.position.x/lattice),ceili(span.end.x/lattice)):
				var key := [salt,layer[0].hash(),i,j]
				var p := (Vector2(i,j)+Vector2(Variety.unit(key+[1]),Variety.unit(key+[2])))*lattice
				if not span.has_point(p) or maxf(absf(p.x),absf(p.y)) > PLATE:
					continue
				var wish := _wish_at(p,guide)
				if forest and _frayed(p,key,wish) <= FOREST_MARGIN.x:
					continue
				var at: float = layer[2]+layer[3]*(0.55*clampf(p.distance_to(origin)/reach,0.0,1.0)+0.45*Variety.unit(key+[3]))
				if wish > 0.05:
					# Wished-for forest comes sooner, its core first.
					var tree: bool = layer[0] == "tree"
					at = (FOREST_TREE_DELAY if tree else FOREST_SHRUB_DELAY)+(FOREST_TREE_SPREAD if tree else FOREST_SHRUB_SPREAD)*(0.6*(1.0-wish)+0.4*Variety.unit(key+[3]))
					# Sown forest spreads out from where its seeds fell.
					if not sown.is_empty():
						at = (SOWN_TREE_DELAY if tree else SOWN_SHRUB_DELAY)+_nearest(sown,p)/SOWN_SPREAD+SOWN_JITTER*Variety.unit(key+[3])
					if tree: wished.append(p)
				region.plants.append({"at":at,"layer":layer[0],"p":p,"key":key,"forest":forest,"guide":guide})
	# Each landed seed is a candidate of its own, first to come up.
	for k in range(sown.size()):
		var p: Vector2 = sown[k]
		if maxf(absf(p.x),absf(p.y)) > PLATE: continue
		var key := [salt,"sown".hash(),roundi(p.x*100.0),roundi(p.y*100.0)]
		region.plants.append({"at":SOWN_DELAY+SOWN_STAGGER*Variety.unit(key+[3]),"layer":"tree","p":p,"key":key,"forest":true,"guide":guide,"sown":true})
	if guide != null: _count_mates(region.plants,known)
	var elder := _elder(wished)
	if not elder.is_empty():
		region["elder"] = elder
		for plant: Dictionary in region.plants: plant["elder"] = elder
	region.plants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	return region

## Metres from `p` to the nearest of `points`.
static func _nearest(points: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for q in points: best = minf(best,p.distance_squared_to(q))
	return sqrt(best)

## The stand a painted forest names old when every stand it covers drew
## young: of those holding ELDER_MIN of its wished tree candidates, the one
## with the oldest draw. Empty when one of them is old already, or none is.
## It reads only the strokes and the salt, so a world replays the same.
func _elder(wished: PackedVector2Array) -> Array:
	var stands := {}
	for p in wished:
		var stand := _stand(p)
		stands.get_or_add(str(stand.key),[stand,0])[1] += 1
	var elder := []
	for entry: Array in stands.values():
		if entry[1] < ELDER_MIN: continue
		if old_stand(entry[0]): return []
		if elder.is_empty() or Variety.unit(entry[0].key+[40]) < Variety.unit(elder+[40]): elder = entry[0].key
	return elder

## Seconds an emerged record of `asset` takes to grow in.
static func rise_seconds(asset: String) -> float:
	return TREE_RISE if asset in TREES or asset == "snag" else SHRUB_RISE

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
	# Plans wait while the ground settles, and one plan runs at a time.
	if not _queued.is_empty() and not ground_settling and _plan_job == null:
		if plan_on_worker: _plan_async(_queued.duplicate())
		else:
			for queued in _queued:
				_plan(queued.rect,queued.born,queued.get("source",""),queued.get("sown",PackedVector2Array()))
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
	var bare := smoothstep(float(biome.rock_slope)*BARE_SLOPE.x,float(biome.rock_slope)*BARE_SLOPE.y,_slope(p))
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
	if slope > _rock_slope(habitat) or float(h) > _snowline()-1.8:
		return _refuse("rock or snow")
	var key: Array = plant.key
	var roll := Variety.unit(key+[4])
	var kind := ""
	# Quiet guidance for this candidate's region, or null (--no-guidance).
	var guide: RefCounted = plant.get("guide")
	var wish := _wish_at(p,guide)
	var frayed := _frayed(p,key,wish)
	var only_wish: bool = plant.get("forest",false)
	if plant.layer == "tree":
		if float(h) > _treeline(habitat):
			return _refuse("treeline")
		var sown: bool = plant.get("sown",false)
		var chance := SOWN_TAKE*(1.0-smoothstep(0.45,float(biome.rock_slope),slope)) if sown else _tree_chance(habitat,slope,wish,frayed,only_wish)
		if guide != null and not sown and (wish <= 0.0 or frayed < FOREST_EDGE.y):
			# Outside a forest's core, fewer trees stand in front of water.
			var kept: float = chance*guide.sight_keep(p)
			if roll >= minf(kept,0.85) and roll < minf(chance,0.85):
				return _refuse("sightline")
			chance = kept
		if roll >= minf(chance,0.85):
			return _refuse("thinned")
		# A tree alone in an ordinary spot reads as a stray; one on a knoll,
		# a shore or a third of the view reads as a feature and stays.
		if guide != null and wish <= 0.05 and not only_wish and int(plant.get("mates",1)) == 0 \
				and _near(p,Guidance.LONE_RADIUS,true) == 0 and guide.at(guide.feature,p) < Guidance.FEATURE_KEEP \
				and Variety.unit(key+[20]) < Guidance.LONE_DROP*float(guide.gain.lone):
			return _refuse("lone")
		kind = _tree_kind(habitat,p,Variety.unit(key+[5]),Variety.unit(key+[25]))
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
		# Undergrowth already crowded by its neighbours reads as noise.
		if guide != null and _near(p,Guidance.CLUTTER_RADIUS,false) >= Guidance.CLUTTER_MAX \
				and Variety.unit(key+[21]) < Guidance.CLUTTER_DROP*float(guide.gain.clutter):
			return _refuse("clutter")
		kind = _shrub_kind(habitat,p,Variety.unit(key+[5]))
	if _crowded(p,plant.layer == "tree"):
		return _refuse("crowded")
	var elder: Array = plant.get("elder",[])
	# A seed comes up living; dead wood is for the stands round it.
	if plant.layer == "tree" and not plant.get("sown",false) and _dead_wood(habitat,p,slope,wish,frayed,key,born,elder):
		return true
	if kind == "tree": p = _dead_top(p,key,elder)
	var span := TREE_SIZE if plant.layer == "tree" else SHRUB_SIZE
	var draw := Variety.unit(key+[6])
	if guide != null:
		# Larger on a feature spot, smaller in front of water.
		var leaned: float = guide.size_draw(p,draw,Variety.unit(key+[19]),plant.layer == "tree")
		if leaned > draw+0.001: guided_sizes.up += 1
		elif leaned < draw-0.001: guided_sizes.down += 1
		draw = leaned
	var size := lerpf(span.x,span.y,draw)*float(KIND_SIZE.get(kind,1.0))
	var id := data.place(kind,p,Variety.unit(key+[7])*TAU,size,{},_tree_tint(kind,p,key))
	if id < 0:
		return false
	data.objects.back()["source"] = "emerged"
	data.objects.back()["born"] = born
	if kind in TREES: data.objects.back()["autumn"] = _stand_autumn(p)
	_crowd.get_or_add(Vector2i(p.floor()),[]).append(Vector3(p.x,p.y,1.0 if kind in TREES else 0.0))
	if kind in TREES: tree_arrived.emit(p,born)
	return true

## A tree candidate that comes up as dead wood instead: true when a snag, log
## or stump was placed. With no room for one, the living tree stands.
func _dead_wood(habitat: String, p: Vector2, slope: float, wish: float, frayed: float, key: Array, born: float, elder: Array) -> bool:
	var stand := _stand(p)
	var core := smoothstep(FOREST_EDGE.y,1.2,frayed) if wish > 0.0 else 0.0
	if Variety.unit(key+[40]) >= _dead_share(habitat,stand,slope,wish,core,elder) or _near(p,DEAD_GAP,false,true) > 0 or _near(p,DEAD_REACH,false,true) >= DEAD_CLUSTER:
		return false
	var harsh := _harsh(stand,slope)
	# Snags stand on exposed ground, logs lie in the dense core, stumps at the
	# edge; snags lead, as the piece that reads from afar.
	var weights := [0.9+0.9*harsh,0.4+1.0*core,0.3+0.5*(1.0-core)]
	for n in range(weights.size()): weights[n] *= Variety.lean(salt,"dead:"+DEAD_KINDS[n])
	var kind: String = DEAD_KINDS[Variety.weighted(weights,Variety.unit(key+[41]))]
	var yaw := Variety.unit(key+[7])*TAU
	var a := Variety.unit(key+[42])
	var b := Variety.unit(key+[43])
	var pose := {}
	var size := lerpf(STUMP_SIZE.x,STUMP_SIZE.y,a)
	var footprint := PackedVector2Array([p])
	match kind:
		"snag":
			# Stunted where it is exposed, and leaning a little.
			size = lerpf(SNAG_SIZE.z,SNAG_SIZE.w,b)
			var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,Variety.unit(key+[44])*0.12)*Basis.from_scale(Vector3(size,lerpf(SNAG_SIZE.x,SNAG_SIZE.y,a)*(1.0-0.2*harsh),size))
			pose = NativeObjectPose.make(basis,-0.05)
		"log":
			# Lies along the ground clear of trunks, pitched to its slope, sunk
			# a little as the source's logs are (native_flora.gd).
			var length := lerpf(LOG_SIZE.x,LOG_SIZE.y,a)
			size = lerpf(LOG_SIZE.z,LOG_SIZE.w,b)
			var along := Vector2(cos(yaw),-sin(yaw))*length
			footprint = _log_points(p,along)
			for q in footprint:
				if data.ground_height(q) == null or _wet(q) or _near(q,0.8,true) > 0: return false
			var h1: float = data.sample(p-along*0.5,data.heights)
			var h2: float = data.sample(p+along*0.5,data.heights)
			for t in [-0.3,-0.15,0.15,0.3]:
				var off: float = (h1+h2)*0.5+(h2-h1)*t-float(data.sample(p+along*t,data.heights))
				if off > 0.06*size or off < -0.11*size: return false
			var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.BACK,atan2(h2-h1,length))*Basis.from_scale(Vector3(length,size,size))
			pose = NativeObjectPose.make(basis,(h1+h2)*0.5-float(data.sample(p,data.heights))+0.09*size)
	var id := data.place(kind,p,yaw,size,pose,_dead_tint(kind,stand,key))
	if id < 0:
		return false
	data.objects.back()["source"] = "emerged"
	data.objects.back()["born"] = born
	for q in footprint: _crowd.get_or_add(Vector2i(q.floor()),[]).append(Vector3(q.x,q.y,2.0))
	return true

## An old stand, drawn once per stand and likelier on high, dry ground, or
## the one its painted forest named (`_elder`).
func old_stand(stand: Dictionary, elder := []) -> bool:
	return stand.key == elder or Variety.unit(stand.key+[40]) < lerpf(DEAD_OLD.x,DEAD_OLD.y,_harsh(stand,0.0))

## How hard the ground is on trees, 0-1: the stand's height and dryness, and
## the steepness where it stands.
func _harsh(stand: Dictionary, slope: float) -> float:
	return clampf(0.45*float(stand.altitude)+0.4*(1.0-float(stand.moisture))+0.3*smoothstep(0.3,0.8,slope),0.0,1.0)

## Points along a log centred on `p` whose axis spans `along`, for crowding.
static func _log_points(p: Vector2, along: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for t in [-0.5,-0.25,0.0,0.25,0.5]: points.append(p+along*t)
	return points

## Weathered wood: one colour per kind and stand, with a little brightness play.
func _dead_tint(kind: String, stand: Dictionary, key: Array) -> String:
	var options: Array = DEAD_COLOURS[kind]
	var weights := []
	for option: Array in options: weights.append(float(option[1]))
	var color := Color(options[Variety.weighted(weights,Variety.unit(stand.key+[7,kind.hash()]))][0]).srgb_to_linear()*lerpf(0.9,1.0,Variety.unit(key+[22]))
	return NativeObjectPose.encode_tint(Color(minf(color.r,1.0),minf(color.g,1.0),minf(color.b,1.0)))

## In an old or high stand a spruce may grow the family's dead top. The variant
## is a hash of the record's id and centimetre position (hero_trees.gd
## spruce_index), so such a tree moves a few centimetres to a spot that draws
## it; saved worlds read back the same variant.
func _dead_top(p: Vector2, key: Array, elder: Array) -> Vector2:
	var stand := _stand(p)
	var lean := DEAD_TOPS*maxf(1.0 if old_stand(stand,elder) else 0.0,smoothstep(0.55,0.9,float(stand.altitude)))
	if Variety.unit(key+[45]) >= lean:
		return p
	var dead_top := -1
	for n in range(HeroTrees.SPRUCE.size()):
		if HeroTrees.SPRUCE[n][0] == "dead-top": dead_top = n
	var base := (p*100.0).round()
	for n in range(49):
		var q := (base+Vector2(n%7-3,n/7-3))/100.0
		if HeroTrees.spruce_index({"id":data.next_id,"x":q.x,"z":q.y}) == dead_top: return q
	return p

## The share of a stand's tree candidates that come up dead.
func _dead_share(habitat: String, stand: Dictionary, slope: float, wish: float, core: float, elder: Array) -> float:
	if wish < 0.0: return 0.0
	# A painted forest on meadow ground is woodland; open meadow grows none.
	var base: float = 1.0 if wish > 0.05 and habitat == "meadow" else DEAD_HABITAT.get(habitat,1.0)
	return minf(base*(DEAD_SHARE.y if old_stand(stand,elder) else DEAD_SHARE.x)*lerpf(DEAD_HARSH.x,DEAD_HARSH.y,_harsh(stand,slope))*(1.0+DEAD_CORE*core),DEAD_MAX)

## The forest wish a candidate reads. With a guide, the wish is sampled a
## little way off where its edge reads as a ruled line (Guide.warp), so the
## edge wanders into bays and bulges both ways.
func _wish_at(p: Vector2, guide: RefCounted) -> float:
	if guide == null: return intent.forest_at(p)
	return intent.forest_at((p+guide.warp(p)).clamp(Vector2(-13.99,-13.99),Vector2(13.99,13.99)))

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

## A tree candidate's chance before the roll: the habitat's density, the
## forest wish (a dense core thinning to scattered trees at the frayed edge,
## or a cleared wish), and thinning on steep ground.
func _tree_chance(habitat: String, slope: float, wish: float, frayed: float, only_wish: bool) -> float:
	var biome: Dictionary = Shape.BIOMES[habitat]
	var chance := float(biome.trees)/PLANTED_AREA*TREE_LATTICE*TREE_LATTICE*_tree_density()
	if habitat == "wetland": chance *= 0.3
	if wish > 0.0:
		var wished := 0.0 if frayed < FOREST_EDGE.x else lerpf(FOREST_EDGE_CHANCE,FOREST_CORE_CHANCE,smoothstep(FOREST_EDGE.x,FOREST_EDGE.y,frayed))
		chance = wished if only_wish else maxf(chance,wished)
	elif wish < 0.0:
		chance *= 1.0+wish
	# Forests thin out as the ground steepens toward rock.
	return chance*(1.0-smoothstep(0.45,float(biome.rock_slope),slope))

## Guidance, on the planner: for each tree candidate, how many other trees
## are likely within LONE_RADIUS — candidates whose roll would pass on the
## ground as planned, and trees already standing (`known`). A tree with none
## would stand alone (`_arrive`).
func _count_mates(plants: Array, known: PackedVector4Array) -> void:
	var likely := {}
	var trees: Array[Dictionary] = []
	for plant: Dictionary in plants:
		if plant.layer != "tree": continue
		trees.append(plant)
		var p: Vector2 = plant.p
		var h: Variant = data.ground_height(p)
		if h == null or _wet(p): continue
		var habitat: String = _blend.pick(p)
		var slope := _slope(p)
		if slope > _rock_slope(habitat) or float(h) > minf(_snowline()-1.8,_treeline(habitat)): continue
		var wish := _wish_at(p,plant.guide)
		var chance := _tree_chance(habitat,slope,wish,_frayed(p,plant.key,wish),plant.forest)
		if Variety.unit(plant.key+[4]) < minf(chance,0.85):
			likely.get_or_add(Vector2i(p.floor()),[]).append(p)
	for item in known:
		if item.z > 0.5: likely.get_or_add(Vector2i(floori(item.x),floori(item.y)),[]).append(Vector2(item.x,item.y))
	var reach := ceili(Guidance.LONE_RADIUS)
	var limit := Guidance.LONE_RADIUS*Guidance.LONE_RADIUS
	for plant in trees:
		var p: Vector2 = plant.p
		var base := Vector2i(p.floor())
		var mates := 0
		for dz in range(-reach,reach+1):
			for dx in range(-reach,reach+1):
				for other: Vector2 in likely.get(base+Vector2i(dx,dz),[]):
					if other != p and p.distance_squared_to(other) < limit: mates += 1
		plant["mates"] = mates

## Plants standing within `radius` of `p`: all, trees (with dead wood) only,
## or dead wood only.
func _near(p: Vector2, radius: float, trees_only: bool, dead_only := false) -> int:
	_build_crowd()
	var count := 0
	var reach := ceili(radius)
	var base := Vector2i(p.floor())
	for dz in range(-reach,reach+1):
		for dx in range(-reach,reach+1):
			for other: Vector3 in _crowd.get(base+Vector2i(dx,dz),[]):
				if (trees_only and other.z < 0.5) or (dead_only and other.z < 1.5): continue
				if p.distance_squared_to(Vector2(other.x,other.y)) < radius*radius: count += 1
	return count

func _refuse(reason: String) -> bool:
	refusals[reason] = refusals.get(reason,0)+1
	return false

func _tree_kind(habitat: String, p: Vector2, pick: float, bank_pick := 1.0) -> String:
	return Stands.tree_kind(habitat,p,pick,bank_pick,salt,_blend)

## An emerged tree's crown tint, or "" to keep the catalog colour.
func _tree_tint(kind: String, p: Vector2, key: Array) -> String:
	return Stands.tree_tint(kind,p,key,salt,_blend)

## A stand's autumn character, the tree record's `autumn` (Stands.autumn).
func _stand_autumn(p: Vector2) -> float:
	return Stands.autumn(p,salt,_blend)

## The stand a point belongs to (Stands.stand): its key, seed, moisture and altitude.
func _stand(p: Vector2) -> Dictionary:
	return Stands.stand(p,salt,_blend)

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
			var weights := [1.5 if habitat == "redwood" else FERN_WEIGHT,0.8,0.8,0.25]
			for n in range(kinds.size()): weights[n] *= Variety.lean(salt,kinds[n])
			return kinds[Variety.weighted(weights,pick)]
		"arid": return "shrub" if pick < 0.8 else "grass_tuft"
	return "grass_tuft"

func _build_crowd() -> void:
	if _crowd_built: return
	_crowd_built = true
	for item in data.objects:
		if item.asset == "waterfall": continue
		# Trees are 1, dead wood 2; a log crowds its whole length.
		var z := 2.0 if item.asset in DEAD_KINDS else 1.0 if item.asset in TREES else 0.0
		var points := PackedVector2Array([Vector2(item.x,item.z)])
		if item.asset == "log":
			var basis := NativeObjectPose.decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP,float(item.angle)).scaled(Vector3.ONE*float(item.scale))
			points = _log_points(points[0],Vector2(basis.x.x,basis.x.z))
		for q in points: _crowd.get_or_add(Vector2i(q.floor()),[]).append(Vector3(q.x,q.y,z))

func _crowded(p: Vector2, tree: bool) -> bool:
	_build_crowd()
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
		if h == null or _wet(p) or _slope(p) > _rock_slope(_blend.pick(p))*1.1 or float(h) > _snowline()-1.0:
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

## Whether a seed landing at `p` could take root now: on ground, not in
## water, not on hand-laid ground (a path), and below the rock slope, the snow
## and the treeline. Before the live blend is built only the ground counts.
func takes(p: Vector2) -> bool:
	var h: Variant = data.ground_height(p)
	if h == null: return false
	var cell := Vector2i(((p+Vector2(14,14))/data.MEADOW_STEP).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(data.MEADOW_CELLS-1))
	if data.provenance[cell.y*data.MEADOW_CELLS+cell.x] == NativeTerrainData.SOURCE_HAND: return false
	if _blend == null: return true
	if _wet(p): return false
	var habitat: String = _blend.pick(p)
	return _slope(p) <= _rock_slope(habitat) and float(h) <= minf(_snowline()-1.8,_treeline(habitat))

## The tree a handful gathered at `p` carries seed of (scripts/seed_handful.gd
## FAMILY): the dominant species of the stand there, or "" before the live
## blend is built.
func seed_family(p: Vector2) -> String:
	if _blend == null: return ""
	return _tree_kind(_blend.pick(p),p,0.0)

func _wet(p: Vector2) -> bool:
	return _blend._sampler.wet(p) or (not _fresh_ponds.is_empty() and _under_fresh_pond(p))

## A pour showed (native_chunk_editor.gd `_set_pour_water`), inside its open
## stroke so one undo brings the plants back with the ground. Withdraw the
## emerged plants whose base its new ponds and streams now cover, and refuse
## that water to arrivals until a plan that saw it takes over. `ponds` and
## `streams` are the water plan's `added` and `added_streams` entries. Hand,
## pinned and generated objects stay. True when anything was withdrawn.
func drown(ponds: Array, streams: Array) -> bool:
	for entry: Dictionary in ponds:
		if not entry.has("cells"): continue
		var cells := {}
		for k: int in entry.cells: cells[k] = true
		_fresh_ponds.append({"level":float(entry.record.level),"cells":cells,"rect":Rect2(entry.rect).grow(WaterBrush.GRID),"record":entry.record,"stamp":_plan_generation})
	var courses: Array = []
	for entry: Dictionary in streams: courses.append(entry.record)
	var removed := false
	for index in range(data.objects.size()-1,-1,-1):
		var item: Dictionary = data.objects[index]
		if NativeTerrainData.object_source(item) != "emerged": continue
		var p := Vector2(item.x,item.z)
		if _under_fresh_pond(p) or _in_courses(p,courses):
			data.objects.remove_at(index)
			removed = true
	if removed:
		data.objects_revision += 1
		_pending_refresh = true
	return removed

## Under a freshly poured pond: a planning cell at a corner of `p`'s grid
## square is flooded, and the ground at `p` lies below the pond's level.
func _under_fresh_pond(p: Vector2) -> bool:
	for pond: Dictionary in _fresh_ponds:
		if not pond.rect.has_point(p): continue
		var corner := ((p-Vector2.ONE*WaterBrush.ORIGIN)/WaterBrush.GRID).floor()
		var flooded := false
		for offset: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
			if pond.cells.has(WaterBrush.cell_of(Vector2.ONE*WaterBrush.ORIGIN+(corner+offset)*WaterBrush.GRID)):
				flooded = true
				break
		if not flooded: continue
		var h: Variant = data.ground_height(p)
		if h != null and float(h) < float(pond.level) and data.ponds.has(pond.record): return true
	return false

## Within a new stream's water: its half width of a course point.
static func _in_courses(p: Vector2, courses: Array) -> bool:
	for route: Dictionary in courses:
		var reach := pow(float(route.width)*0.5,2.0)
		for point: Dictionary in route.pts:
			if p.distance_squared_to(Vector2(point.x,point.z)) < reach: return true
	return false

## The slope above which a plant finds bare rock: the habitat's own rock
## slope, or the slope the terrain mesh paints rock above when that is gentler
## (its recipe biome's, else the palette's: 0.93 on the plain;
## NativeTerrainData and native_mesh_samples.gd). Without the second, a
## meadow's 1.3 let plants take on a raised peak's painted rock. Emergence
## only; generated worlds plant through their own generator.
func _rock_slope(habitat: String) -> float:
	var drawn: Dictionary = Shape.BIOMES.get(data._recipe_settings.get("biome",""),{})
	return minf(float(Shape.BIOMES[habitat].rock_slope),float(drawn.get("rock_slope",data._palette.rock_slope)))

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
