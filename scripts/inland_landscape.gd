extends RefCounted
const Desert = preload("res://scripts/desert_landscape.gd")
var data: NativeTerrainData
var genome: Dictionary
func form(terrain: NativeTerrainData,settings: Dictionary,tree: SceneTree = null) -> void:
	data = terrain
	data.reset_flat()
	if not await data._set_recipe(settings,tree): return
	genome = data._recipe.inland.genome
	data.grass.fill(preload("res://scripts/native_formation_shape.gd").BIOMES[genome.habitat].grass)
	data.heights = data._recipe_heights.duplicate()
	data.ponds.assign(data._recipe.inland.ponds.duplicate(true))
	data.streams.assign(data._recipe.inland.streams.duplicate(true))
	var work = preload("res://scripts/frame_work_budget.gd").new(tree)
	# Flood connected pools once, including salt pans.
	if genome.composition in ["marsh","salt-basin"]:
		var masks: Array = []
		var unique: Array[Dictionary] = []
		for pond in data.ponds:
			await work.checkpoint()
			var field: Dictionary = NativeRecipeWater.field(data,pond)
			if field.is_empty() or field.wet in masks: continue
			masks.append(field.wet)
			unique.append(pond)
		data.ponds = unique
	# Independent planting stream; habitat changes cannot alter terrain or water.
	var rng := RandomNumberGenerator.new()
	rng.seed = genome.plant_seed
	var budget: int = {"alpine":int(genome.tree_count),"woodland":int(genome.tree_count)+int(genome.broadleaf_count),"meadow":0 if genome.composition == "meadow" else 15,"wetland":0,"arid":12,"redwood":70}[genome.habitat]
	budget = int(budget*float(genome.tree_density))
	var planted := 0
	var occupied: Array[Vector2] = []
	var habitat_noise := FastNoiseLite.new()
	habitat_noise.seed = genome.plant_seed
	habitat_noise.frequency = 0.22
	for i in range(1600 if budget>0 else 0):
		if i%16 == 0: await work.checkpoint()
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		var angle := rng.randf()*TAU
		var size := rng.randf_range(0.6,1.05)
		var pick := rng.randf()
		var h: float = data.ground_height(p)
		if _is_wet(p) or _is_salt(p): continue
		if preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.85: continue
		var treeline := float(genome.treeline) if genome.habitat == "alpine" else 10.0
		if h>treeline: continue
		if habitat_noise.get_noise_2d(p.x,p.y)<-0.15: continue
		var crowded := false
		for other in occupied:
			if other.distance_squared_to(p)<1.2: crowded = true; break
		if crowded: continue
		var kind: String = "tree"
		if genome.habitat == "woodland": kind = "layered_tree" if pick<0.15 else "broadleaf" if pick<0.6 else "tree"
		elif genome.habitat == "redwood": kind = "redwood"
		elif genome.habitat == "arid": kind = "cactus"
		elif genome.habitat == "wetland": kind = "reeds"
		if data.place(kind,p,angle,size)>=0:
			planted += 1
			occupied.append(p)
		if planted>=budget: break
	# Low cover gives marsh/meadow their own habitat beyond a palette swap.
	for i in range(25 if genome.habitat == "arid" else 620 if genome.habitat == "wetland" else 250):
		if i%16 == 0: await work.checkpoint()
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		if _is_salt(p): continue
		if (_is_wet(p) and not (genome.habitat == "wetland" and float(data.ground_height(p))>1.30)) or preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.6: continue
		if data.ground_height(p)>5.0: continue
		var kind: String = "reeds" if genome.habitat == "wetland" else ["daisy_flower","button_flower","spike_flower","grass_tuft"][i%4] if genome.habitat == "meadow" else "shrub" if genome.habitat == "arid" else "grass_tuft"
		if genome.habitat in ["woodland","redwood"]:
			if i%29 == 0: kind = "log"
			elif i%31 == 0: kind = "stump"
			elif i%37 == 0: kind = "snag"
			elif i%11 == 0: kind = "fern"
			elif i%13 == 0: kind = "mushroom"
		if genome.habitat == "wetland" and float(data.ground_height(p))>1.65: kind = "bank_grass"
		data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.5,0.9))
	data.objects_revision += 1
	data.discard_cache()

func _is_wet(p: Vector2) -> bool:
	for route in data.streams:
		for point in route.pts:
			if p.distance_squared_to(Vector2(point.x,point.z))<pow(float(route.width)*0.6+0.4,2.0): return true
	for pool: Dictionary in data.ponds:
		if genome.composition in ["marsh","salt-basin"]:
			if float(data.ground_height(p))<float(pool.level)+0.08: return true
		elif Vector2((p.x-pool.x)/pool.basin[0],(p.y-pool.z)/pool.basin[1]).length()<1.05: return true
	return false

func _is_salt(p: Vector2) -> bool:
	return genome.composition == "salt-basin" and Desert.field(genome,p).z>0.25

