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
		if _is_wet(p) or _is_salt(p) or _clearing(p): continue
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
	if int(genome.version)>=4: await _dress_places(work)
	data.objects_revision += 1
	data.discard_cache()

func _is_wet(p: Vector2) -> bool:
	if int(genome.version)>=4: return data._recipe.inland.sampler.wet(p)
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


func _clearing(p: Vector2) -> bool:
	for place: Dictionary in data._recipe.inland.sampler.places:
		if p.distance_to(place.center)<1.15: return true
	return false

func _dress_places(work: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(genome.plant_seed)+967
	var habitat: String = genome.habitat
	var palettes := {
		"woodland":["fern","mushroom","grass_tuft","fern"],
		"redwood":["fern","fern","mushroom","grass_tuft"],
		"alpine":["grass_tuft","rock","grass_tuft","grass_tuft"],
		"meadow":["daisy_flower","button_flower","spike_flower","grass_tuft"],
		"wetland":["bank_grass","reeds","rock","grass_tuft"],
		"arid":["rock","shrub","shrub","grass_tuft"]}
	# Fine ground cover binds the small props into patches instead of isolated dots.
	if habitat!="arid":
		for z in range(data.MEADOW_CELLS):
			if z%4==0: await work.checkpoint()
			for x in range(data.MEADOW_CELLS):
				var p := data.meadow_position(x,z)+Vector2.ONE*0.25
				if maxf(absf(p.x),absf(p.y))>11.0 or _is_wet(p): continue
				var near := false
				for place: Dictionary in data._recipe.inland.sampler.places:
					if p.distance_to(place.center)<float(place.radius)+1.8: near = true
				if not near or preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.65: continue
				data.blades[z*data.MEADOW_CELLS+x] = 0.35
				if habitat=="meadow": data.meadow[z*data.MEADOW_CELLS+x] = 0.16
	for place: Dictionary in data._recipe.inland.sampler.places:
		# A log, rock grouping or flower patch gives each clearing an edge;
		# the middle stays available for Bigfoot and the player's own objects.
		var cluster := Vector2.from_angle(rng.randf()*TAU)
		var anchor: Vector2 = place.center+cluster*1.45
		var focal := "log" if habitat in ["woodland","redwood"] and int(place.kind)==0 else "boulder_"+str(1+int(place.kind))
		if not _is_wet(anchor) and not _is_salt(anchor):
			data.place(focal,anchor,rng.randf()*TAU,0.55)
		var planted := 0
		for attempt in range(160):
			if attempt%16==0: await work.checkpoint()
			var p: Vector2 = anchor+Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*1.8
			if p.distance_to(place.center)<0.95 or _is_wet(p) or _is_salt(p): continue
			if preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.65: continue
			var choices: Array = palettes[habitat]
			var kind: String = choices[(planted+int(place.kind))%choices.size()]
			if data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.5,0.85))>=0: planted += 1
			if planted>=28: break
