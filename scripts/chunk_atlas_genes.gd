extends RefCounted
## What a chunk inherits when it is regenerated inside the atlas
## (scripts/chunk_atlas.gd, docs/chunk-atlas/DESIGN.md). The source's regional
## field and country (grid.js countryOf) make a plot read as part of the land
## around it; here the stored neighbours' terrain recipes vote on the new
## chunk's composition, habitat, relief and breadth, with a seeded drift and
## the odd surprise. Mountains carry on into mountains, forest into forest.

const Generator = preload("res://scripts/cozy_world_generator.gd")
const Genome = preload("res://scripts/inland_genome.gd")
const Beauty = preload("res://scripts/world_beauty.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const InlandWorld = preload("res://scripts/inland_world.gd")
const Atlas = preload("res://scripts/chunk_atlas.gd")

## Chance the new chunk ignores its neighbours' country and rolls its own.
const SURPRISE := 0.18
## Chance it keeps the parent's composition but takes its own habitat.
const HABITAT_DRIFT := 0.2
## Relief and breadth wander this far from the neighbours' weighted mean.
const DRIFT := 0.12
## Candidates scored from the overview camera, as Generator.sample does.
const CANDIDATES := 4
## A blank Genesis plain votes as gentle meadow country.
const PLAIN_VOTE := {"composition":"meadow","biome":"meadow","relief":0.7,"breadth":1.0}

## Each stored chunk around `slot` with its vote: orthogonal neighbours count
## 1, diagonal ones 0.5. A plain votes PLAIN_VOTE.
static func neighbours(atlas: Atlas, slot: Vector2i) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for dz in range(-1,2):
		for dx in range(-1,2):
			var next := slot+Vector2i(dx,dz)
			if next == slot or next == atlas.live and slot != atlas.live or not atlas.slots.has(next): continue
			var weight := 1.0 if dx == 0 or dz == 0 else 0.5
			var recipe: Variant = NativeTerrainRecipe.decode(atlas.slots[next].document.get("terrain_recipe",{}))
			var vote: Dictionary = PLAIN_VOTE.duplicate()
			if recipe is Dictionary and recipe.get("kind") == "inland": vote = recipe
			found.append({"slot":next,"weight":weight,"recipe":vote})
	return found

## A generated world for `seed_value` whose terrain continues `near` (from
## neighbours()). With no neighbours it is Generator.sample unchanged. The
## mood and visuals are Generator's but the atlas keeps one sky, so the
## caller does not apply them.
static func sample_near(seed_value: int, near: Array, previous: Dictionary = {}) -> Dictionary:
	var world: Dictionary = Generator.sample(seed_value,previous)
	if near.is_empty(): return world
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["atlas-genes",seed_value])
	if rng.randf() < SURPRISE:
		world["atlas_inherited"] = "surprise"
		return world
	var total := 0.0
	for item in near: total += float(item.weight)
	var roll := rng.randf()*total
	var parent: Dictionary = near[-1].recipe
	for item in near:
		roll -= float(item.weight)
		if roll <= 0.0:
			parent = item.recipe
			break
	var relief := 0.0
	var breadth := 0.0
	for item in near:
		relief += float(item.recipe.get("relief",1.0))*float(item.weight)/total
		breadth += float(item.recipe.get("breadth",1.0))*float(item.weight)/total
	var composition: String = parent.composition
	var habitat: String = parent.biome
	var best := {}
	var best_score := -1.0
	for attempt in range(CANDIDATES):
		var terrain_seed := rng.randi_range(0,999999)
		# Genome picks an archetype and landform that suit the composition.
		var g: Dictionary = Genome.sample(terrain_seed,{"composition":composition})
		var biome: String = habitat if rng.randf() >= HABITAT_DRIFT else str(g.habitat)
		if composition in preload("res://scripts/desert_landscape.gd").KINDS: biome = "arid"
		var recipe := {"kind":"inland","version":Genome.VERSION,"seed":terrain_seed,"composition":composition,"archetype":g.archetype,"landform":g.landform,"biome":biome,
			"relief":clampf(relief+rng.randf_range(-DRIFT,DRIFT),0.65,1.3),"breadth":clampf(breadth+rng.randf_range(-DRIFT,DRIFT),0.72,1.3)}
		var score: float = Beauty.score(InlandWorld.new(recipe,true).sampler).total
		if score > best_score:
			best_score = score
			best = recipe
	var blend: Array = BiomeBlend.plan(best,InlandWorld.new(best))
	if not blend.is_empty(): best["blend"] = blend
	best["variety"] = 1
	world.terrain = best
	world["atlas_inherited"] = composition
	return world

## sample_near on a worker, as Generator.sample_async does.
static func sample_near_async(seed_value: int, near: Array, previous: Dictionary, tree: SceneTree) -> Dictionary:
	var result: Array[Dictionary] = []
	var snapshot := previous.duplicate(true)
	var votes := near.duplicate(true)
	var task := WorkerThreadPool.add_task(func(): result.append(sample_near(seed_value,votes,snapshot)))
	while not WorkerThreadPool.is_task_completed(task): await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return result[0]
